# エージェントループの統合ガイド

**— ループの仕組み × Loop Engineering × Harness Optimization —**

三つの資料を統合したノート:

1. [Claude Agent SDK: エージェントループの仕組み](https://code.claude.com/docs/ja/agent-sdk/agent-loop)
2. [Loop Engineering 入門: AI コーディングエージェントを動かすシステムを設計する](https://zenn.dev/suwash/articles/loop-engineering_20260610)（諏訪真一）
3. [Harness Optimization 概要](https://notes.iwase.dev/ja/harness-optimization/overview)（岩瀬）

---

## はじめに: 三つの文書は「ループの三層」を描いている

三つの文書は、同じ「エージェントループ」を異なる解像度で扱っている。

| 層 | 文書 | 対象 | 問い |
|---|---|---|---|
| **内側のループ** | Agent SDK ドキュメント | 1 エージェント内のターン・メッセージ・ツール実行・コンテキスト | ループの中で何が起きているか |
| **外側のループ** | Loop Engineering（Zenn） | ループを自律的に起動・統治するシステム全体（スケジュール・状態・ゲート） | 誰がエージェントをプロンプトするのか |
| **メタループ** | Harness Optimization（iwase） | ループの実行系（harness）そのものを実行記録と評価から改善する仕組み | どうやって harness 自体を良くしていくか |

まとめると: **内側のループを「ループ設計」が束ね、その実行系を「ハーネス最適化」が証跡と評価に基づいて更新する**。

---

# 第 1 部: エージェントループの仕組み（内側のループ）

*出典: Claude Agent SDK — エージェントループの仕組み*

## 1.1 ループの概要

Agent SDK を使うと、Claude Code の自律型エージェントループを独自アプリケーションに組み込める。SDK はスタンドアロンパッケージで、ツール・権限・コスト制限・出力をプログラムで制御できる（Claude Code CLI のインストールは不要）。

すべてのエージェントセッションは同じサイクルに従う:

1. **プロンプトを受け取る。** Claude はプロンプト・システムプロンプト・ツール定義・会話履歴とともに受け取る。SDK はセッションメタデータを含む `subtype: "init"` の `SystemMessage` を生成する。
2. **評価して応答する。** Claude は現在の状態を評価し、テキスト応答・1 つ以上のツール呼び出し・その両方を返す。SDK は `AssistantMessage` を生成する。
3. **ツールを実行する。** SDK は要求された各ツールを実行し、結果を収集。結果の各セットは次の決定のために Claude にフィードバックされる。hooks で実行前に傍受・変更・ブロックできる。
4. **繰り返す。** ステップ 2 と 3 がサイクルとして繰り返される。各完全なサイクルは 1 ターン。ツール呼び出しのない応答を生成するまで続く。
5. **結果を返す。** SDK は最終 `AssistantMessage`（テキストのみ）を生成し、続けて最終テキスト・トークン使用量・コスト・セッション ID を含む `ResultMessage` を生成する。

単純な質問は 1〜2 ターン、複雑なタスク（リファクタ＋テスト更新）は数十のツール呼び出しをチェーンする。

## 1.2 ターンとメッセージ

ターン = ループ内の 1 往復。Claude がツール呼び出しを含む出力を生成 → SDK が実行 → 結果が自動フィードバック（コードに制御を戻さない）。

例:「Fix the failing tests in auth.ts」

1. **ターン 1:** `Bash` で `npm test`（3 失敗）→ `UserMessage` 生成
2. **ターン 2:** `Read` で `auth.ts` / `auth.test.ts` を読み取り
3. **ターン 3:** `Edit` で修正 + `Bash` で `npm test` 再実行（全成功）
4. **最終ターン:** ツール呼び出しなしのテキストのみ応答 → 最終 `AssistantMessage` → `ResultMessage`

**制限:**
- `max_turns` / `maxTurns`: ツール使用ターンのみをカウント
- `max_budget_usd` / `maxBudgetUsd`: 支出しきい値でターンをキャップ
- 制限なしだとオープンエンドプロンプトで長時間実行されうる → **予算設定は本番エージェントの良いデフォルト**

## 1.3 メッセージタイプ（5 つのコアタイプ）

| タイプ | 内容 |
|---|---|
| **`SystemMessage`** | セッションライフサイクルイベント。`subtype` で区別: `"init"`（セッションメタデータ）、`"compact_boundary"`（圧縮後）、`"informational"`（ステータスバナー）、`"worker_shutting_down"`（ホスト終了/Remote Control 切断） |
| **`AssistantMessage`** | 各 Claude 応答の後。テキストコンテンツブロックとツール呼び出しブロックを含む |
| **`UserMessage`** | 各ツール実行後、Claude に返されるツール結果。ループ中盤のストリーミングユーザー入力にも使われる |
| **`StreamEvent`** | 部分メッセージ有効時のみ。生の API ストリーミングイベント（テキストデルタ、ツール入力チャンク） |
| **`ResultMessage`** | ループ終了をマーク。最終テキスト・トークン使用量・コスト・セッション ID。`subtype` で成功か制限到達かを判断。`prompt_suggestion` などの末尾イベントが後続しうるため、結果で中断せずストリームを完了まで反復処理する |

TypeScript SDK は追加の観測可能性イベント（フックイベント・ツール進捗・レート制限・タスク通知）も生成するが、ループ駆動には必須でない。

**メッセージの処理:**
- 最終結果のみ → `ResultMessage` を処理
- 進捗更新 → `AssistantMessage` を処理
- ライブストリーミング → `include_partial_messages` / `includePartialMessages` で `StreamEvent` を取得

**タイプチェック:** Python は `isinstance(message, ResultMessage)`、TypeScript は `message.type === "result"`。TS では `AssistantMessage`/`UserMessage` が生 API メッセージを `.message` フィールドでラップするため、コンテンツブロックは `message.message.content` にある。

## 1.4 ツール実行

**組み込みツール**（Claude Code と同じ）:

| カテゴリ | ツール | 機能 |
|---|---|---|
| ファイル操作 | `Read`, `Edit`, `Write` | 読み取り・変更・作成 |
| 検索 | `Glob`, `Grep` | パターン検索・正規表現検索 |
| 実行 | `Bash` | シェルコマンド・スクリプト・git |
| Web | `WebSearch`, `WebFetch` | Web 検索・ページ取得 |
| 検出 | `ToolSearch` | オンデマンドでツールを動的検索・ロード |
| オーケストレーション | `Agent`, `Skill`, `AskUserQuestion`, `TaskCreate`, `TaskUpdate` | サブエージェント・スキル・ユーザー質問・タスク追跡 |

加えて MCP サーバー接続・カスタムツール定義・プロジェクトスキルロードが可能。

**ツール権限**（3 オプションが連携して実行可否を決定）:
- `allowed_tools` / `allowedTools`: リストされたツールを自動承認（例: 読み取り専用エージェント）。リスト外は利用可能だが権限が必要
- `disallowed_tools` / `disallowedTools`: 他設定に関係なくブロック
- `permission_mode` / `permissionMode`: カバーされていないツールの扱いを制御

`"Bash(npm *)"` のようなルールで個別ツールをスコープ可能。拒否された場合、Claude は拒否メッセージをツール結果として受け取り、別アプローチを試みる。

**並列ツール実行:** 読み取り専用ツール（`Read`, `Glob`, `Grep`、readOnly マークの MCP ツール）は同時実行。状態変更ツール（`Edit`, `Write`, `Bash`）は競合回避のため順序実行。カスタムツールはデフォルト順序実行、並列化には注釈で `readOnlyHint` を設定。

## 1.5 ループの実行方法を制御する

すべて `ClaudeAgentOptions`（Python）/ `Options`（TypeScript）のフィールド。

**ターンと予算:** 最大ターン（デフォルト制限なし）、最大予算（デフォルト制限なし）。制限到達時は `error_max_turns` / `error_max_budget_usd` サブタイプの `ResultMessage`。ストリーミング入力使用時、ターン実行中に送ったメッセージはキューに入り、独自のターンを開始する（v2.1.205 より前は消失しうった）。

**努力レベル（`effort`）:**

| レベル | 動作 | 用途 |
|---|---|---|
| `"low"` | 最小限の推論・高速 | ファイル検索、ディレクトリ一覧 |
| `"medium"` | バランス | ルーチン編集、標準タスク |
| `"high"` | 徹底的 | リファクタリング、デバッグ |
| `"xhigh"` | 拡張推論深度 | agentic coding（Fable 5、Opus 4.7+、Sonnet 5 推奨） |
| `"max"` | 最大推論深度 | 複数ステップの深い分析 |

`effort` はレイテンシとトークンコストをトレードオフ。拡張思考（thinking blocks）とは独立した機能。未設定ならモデルデフォルトに委譲。`AgentDefinition.effort` でサブエージェントごとに上書き可能。

**権限モード（`permission_mode` / `permissionMode`）:**

| モード | 動作 |
|---|---|
| `"default"` | 許可ルール未カバーのツールは承認コールバックをトリガー。コールバックなしなら拒否 |
| `"acceptEdits"` | ファイル編集と一般ファイルシステムコマンドを自動承認。他 Bash はデフォルトルール |
| `"plan"` | ソース編集なしで探索・計画。編集は `canUseTool` コールバック経由 |
| `"dontAsk"` | プロンプトしない。事前承認のみ実行、他は拒否 |
| `"auto"` | モデル分類器で各呼び出しを承認/拒否 |
| `"bypassPermissions"` | 明示的 `ask` ルール・`requiresUserInteraction` ツール以外を無条件実行。Unix ルート実行不可・隔離環境専用 |

推奨: インタラクティブ UI → `"default"` + 承認コールバック。開発マシン上の自律エージェント → `"acceptEdits"`。CI/コンテナ → `"bypassPermissions"`。

**モデル:** 未設定なら Claude Code デフォルト。小さいモデルを明示指定でコスト削減（例: `model="claude-sonnet-5"`）。

## 1.6 コンテキストウィンドウ

コンテキストはセッション中ずっと蓄積（システムプロンプト、ツール定義、会話履歴、ツール入出力）。ターン間で同じ内容（システムプロンプト、ツール定義、CLAUDE.md）は自動的にプロンプトキャッシュされ、繰り返しプリフィックスのコスト・レイテンシを削減。

**コンテキストを消費するもの:**

| ソース | ロード時期 | 影響 |
|---|---|---|
| システムプロンプト | 全リクエスト | 小さい固定コスト |
| CLAUDE.md | セッション開始時 | 全リクエストで完全コンテンツ（ただしキャッシュされるため初回のみフルコスト） |
| ツール定義 | 全リクエスト（MCP はデフォルト遅延） | 組み込みツールは全リクエスト。ToolSearch は MCP スキーマを遅延ロード |
| 会話履歴 | ターン間で蓄積 | 各ターンで増加 |
| スキル説明 | セッション開始時 | 短い要約のみ、呼び出し時フルロード |

**自動圧縮:** 制限が近づくと SDK が会話を自動圧縮（古い履歴を要約に置き換え、最新の交換と重要決定を保持）。`compact_boundary` メッセージをストリームで発行。初期の特定指示は保持されない可能性がある → **永続ルールは初期プロンプトではなく CLAUDE.md に置く**（全リクエストで再注入されるため）。

圧縮のカスタマイズ:
- CLAUDE.md に「要約指示」セクション（保持すべき内容: タスク目的・受入基準、読み書きしたファイルパス、テスト結果・エラー、決定と理由）
- `PreCompact` フックで圧縮前に完全トランスクリプトをアーカイブ
- `/compact` をプロンプト文字列として送信し手動圧縮

**コンテキストを効率的に保つ:**
- **サブエージェント**: 新しい会話で開始（親の履歴なし、最終応答のみ親に返る）→ 親コンテキストは要約のみで増加
- **ツールを選別**: `AgentDefinition.tools` でサブエージェントを最小セットにスコープ
- **MCP サーバーコスト監視**: ツール検索オフ・Agent Platform・非ファーストパーティ `ANTHROPIC_BASE_URL` では全スキーマが全リクエストに載る
- **ルーチンタスクに低い effort**

## 1.7 セッションと継続性

`ResultMessage.session_id` からセッション ID をキャプチャして再開可能。再開すると以前のターンからの完全コンテキストが復元（読み取ったファイル・実行した分析・アクション）。セッションをフォークして別アプローチに分岐も可能。Python の `ClaudeSDKClient` は複数呼び出し間でセッション ID を自動処理。

## 1.8 結果を処理する

`ResultMessage.subtype` が終了状態の主な判定手段:

| サブタイプ | 意味 | `result` フィールド |
|---|---|---|
| `success` | 通常完了 | あり |
| `error_max_turns` | ターン制限到達 | なし |
| `error_max_budget_usd` | 予算制限到達 | なし |
| `error_during_execution` | エラーで中断（API 障害・キャンセル） | なし |
| `error_max_structured_output_retries` | 構造化出力の再試行制限超過 | なし |

`result` は `success` のみ。全サブタイプが `total_cost_usd`・`usage`・`num_turns`・`session_id` を持つ（エラー後でも再開可能）。

- 単一ショット `query()` はエラー結果生成後に例外を投げる → try ブロックでラップ
- ストリーミング入力セッションはエラー後も生存してメッセージ送信可能
- `stop_reason`（`end_turn` / `max_tokens` / `refusal`）でモデルが停止した理由を確認。拒否検出は `stop_reason === "refusal"`

## 1.9 Hooks

ループの特定ポイントで発火するコールバック。**アプリケーションプロセスで実行されるためコンテキストを消費しない**。ループをショートサーキットできる（`PreToolUse` での拒否はツール実行を防ぐ）。

| フック | 発火時期 | 一般的な用途 |
|---|---|---|
| `PreToolUse` | ツール実行前 | 入力検証、危険コマンドのブロック |
| `PostToolUse` | ツール戻り後 | 出力監査、副作用トリガー |
| `UserPromptSubmit` | プロンプト送信時 | 追加コンテキスト注入 |
| `Stop` | エージェント終了時 | 結果検証、セッション状態保存 |
| `SubagentStart` / `SubagentStop` | サブエージェント生成/完了時 | 並列タスク結果の追跡・集約 |
| `PreCompact` | 圧縮前 | 要約前の完全トランスクリプトアーカイブ |

## 1.10 すべてをまとめる（実装例の要点）

失敗するテストを修正する単一エージェントの構成例:

```python
async for message in query(
    prompt="Find and fix the bug causing test failures in the auth module",
    options=ClaudeAgentOptions(
        allowed_tools=["Read", "Edit", "Bash", "Glob", "Grep"],  # 自動承認
        setting_sources=["project"],        # CLAUDE.md, skills, hooks をロード
        max_turns=30,                       # 暴走防止
        effort="high",                      # 複雑なデバッグ用の徹底的推論
    ),
):
    if isinstance(message, ResultMessage):
        session_id = message.session_id      # 再開用に保存
        if message.subtype == "success":
            print(f"Done: {message.result}")
        elif message.subtype == "error_max_turns":
            print(f"Hit turn limit. Resume session {session_id} to continue.")
        # ... error_max_budget_usd, total_cost_usd ...
```

次のステップ: クイックスタート → プロジェクトフック（CLAUDE.md/skills）→ ストリーミング UI → 権限ロックダウン → サブエージェントへのオフロード。

---

# 第 2 部: Loop Engineering（外側のループ）

*出典: 諏訪真一「Loop Engineering 入門」（2026-06-10 調査、cobusgreyling/loop-engineering、Addy Osmani 起点記事）*

## 2.1 概要

Loop engineering は、設計対象を「個々のプロンプト」から「ループ（システム）」へ移行させる方法論。**エンジニアがエージェントへ毎ターン指示するのではなく、エージェントへ指示するシステムそのものを設計する**。

ループ = ゴール達成または人間へのハンドオフまで反復する制御単位。AI がサブエージェント・検証・外部状態を組み合わせ、目的を満たすまで自律的に回す。

> Boris Cherny（Anthropic, Head of Claude Code）: "I don't prompt Claude anymore. I have loops running that prompt Claude and figuring out what to do. My job is to write loops."
>
> Peter Steinberger: "You shouldn't be prompting coding agents anymore. You should be designing loops that prompt your agents."

体系化: Addy Osmani（Google）が 2026-06-07 の記事 "Loop Engineering" で普及。Cobus Greyling が実践リファレンスリポジトリ（パターン集・チェックリスト・CLI ツール）を提供。

**なぜ今登場したか:**

| 段階 | 説明 |
|---|---|
| オートコンプリート 2023 | 補完ベース支援 |
| プロンプトでコード生成 2024 | 人間が逐次プロンプト |
| 並列エージェント実行 2025 | 複数エージェントを手動管理 |
| 自己プロンプトループ 2026 | システムがエージェントを自律プロンプト |

単一セッションで完結しない複雑タスク（CI 監視・依存関係管理・PR レビュー等）では逐次プロンプトは非効率。ループ設計によりスケジューリング・状態管理・検証・エスカレーションを人間の介在なしに実行。

**ReAct との違い:** ReAct（2022, Yao ら）は「一回のエージェント推論サイクル」を定義。SWE-agent / Devin 等は単一タスクの自律解決。loop engineering は「複数の自律ループを協調・統治するメタ設計」に焦点。

**Prompt / Context / Loop Engineering の比較:**

| 観点 | Prompt Engineering | Context Engineering | Loop Engineering |
|---|---|---|---|
| 設計対象 | 個々のプロンプト文 | モデルウィンドウの中身 | ループ全体の制御システム |
| 介入タイミング | ターンごとに人間が入力 | 各レスポンス前にコンテキスト整備 | スケジュール駆動で自律実行 |
| 成果物 | 最適化されたプロンプト文 | コンテキスト管理の仕組み | ゴール達成まで自走するシステム |
| 人間の関与 | ターンごとに必須 | レスポンスごとに必須 | 例外・承認ゲートのみ |
| 状態管理 | なし（ステートレス） | セッション内のみ | 外部永続化（セッション横断） |
| 自律性 | なし | なし | スケジュールから完全自律まで段階的 |
| スタック関係 | 基盤層 | 中間層 | 最上位層（両方を包含） |

**注意:** 層は相互排他でなく積み重なる。ループ内のずさんなプロンプトは「ずさんな作業を速く生産する」だけ。

## 2.2 7 つの特徴

1. **再帰的ゴール（Recursive Goal）** — ゴールを定義し、検証条件を満たすまで自律反復。複数サイクルにわたる収束が前提。
2. **自己プロンプト（Self-Prompting）** — 人間ではなくシステム（オートメーション）が「何をいつプロンプトするか」を決定。これがループをエンジニアリングの対象にする本質。
3. **Maker-Checker 分離（Sub-agents）** — 実装エージェント（Maker/Implementer）と検証エージェント（Checker/Verifier）を分離し、自己評価バイアスを構造的に排除。
4. **段階的自律（L1 → L2 → L3）** — L1 Report（人間レビュー、自動修正なし、コスト最小）/ L2 Assisted（修正案を提示、人間がゲート通過）/ L3 Unattended（拒否リスト制約内で完全自律）。
5. **外部状態管理（Memory / State）** — セッション間で記憶を持たない。Markdown ファイル・課題トラッカー・永続ストアに状態を書き出し、次サイクルが読み込む。
6. **トークンコストの増大** — 高頻度・高自律ループはトークン消費を増大（PR Babysitter の常時監視 > Daily Triage の日次）。設計段階でコストと自律レベルのトレードオフを計画。
7. **Comprehension Debt（理解負債）** — ループの生成速度がコードレビュー速度を上回るとコードベースの実理解が追いつかない。自動化はジャッジメントを削除せず、レバレッジポイントを移動させる。

## 2.3 構造（C4 モデル読み替え）

**システムコンテキスト図:**
- アクター: 開発者（ループの目的・スキル・状態スキーマを設計）、SRE（トークン予算・スケジュール・停止基準）、レビュアー（ヒューマンゲート最終承認）
- 外部システム: CI/CD 基盤、Git ホスト、チケット管理、MCP 連携先、LLM プロバイダ

**コンテナ図（6 つのプリミティブ）:**
- Automations / Scheduling（定期・条件トリガー）
- Worktrees（並列実行の隔離コピー作業空間）
- Skills（再利用可能な知識単位）
- Plugins / Connectors – MCP（外部接続統合レイヤ）
- Sub-agents（Implementer / Verifier の役割分離）
- Memory / State（セッション横断の外部永続ストア）

**コンポーネント図（実行フロー）:**

```
Schedule / Automation → Triage Skill → Read/Write State → Isolated Worktree
  → Implementer Sub-agent → Verifier Sub-agent → MCP/Git/Tickets
  → Human Gate → (Auto-commit / PR) | (Escalate to Human)
```

- **Human Gate は自律度ティアで構成が変わる:**
  - L1: Implementer/Verifier を起動しない。Triage が状態を書き、全判断を人間に委ねる（Gate 自体なし）
  - L2: Implementer + Verifier 起動。テスト通過でも PR 作成までで停止、マージは人間
  - L3: denylist 外の変更のみ Auto-commit まで自動実行。denylist 内は人間キューへ昇格
- **Maker-Checker と Human Gate の構造的役割:** Implementer と Verifier は同一エージェントにしない（自己採点はエラー見逃し確率を上げる）。Human Gate は path allowlist と denylist の両方で危険度判定。L3 では allowlist 内かつ denylist 非該当のみ自動適用。大規模リファクタ・新パターン追加は人間レビューへ。

## 2.4 データモデル

**概念モデル:** Loop, Automations/Scheduling, Worktree, Skill, Plugins and Connectors, Sub-agent, Memory/State, Autonomy Tier, Human Gate, Denylist, Artifact, State, Pattern。

**情報モデル（抜粋）:**
- `Loop.cadence`（実行間隔: `1d`, `5-15m`）、`Loop.risk_level`（L1/L2）、`Loop.autonomy_tier`（L1-L3）、`Loop.handoff_trigger`、`Loop.token_cost`（Low/Medium/High/Very High）
- `AutonomyTier.level/label/description`
- `Primitive.type/job/storage_format/invocation_method`
- `Skill.file_format`（`SKILL.md`）、`Skill.storage_scope`（project/user）
- `Worktree.lifecycle`（1 実験ごと生成・REJECT で破棄）、`Worktree.thread_model`
- `SubAgent.role`（Maker/Checker/Triage）、`SubAgent.model`
- `State.readiness_score` / `update_trigger` / `recent_noise` / `acting_on`（Multi-loop 衝突検出でピア間照合）
- `Artifact.type`、`Pattern.gate_condition` / `overlap_rule`
- `HumanGate.trigger_condition` / `escalation_context`、`Denylist.entries` / `scope`

## 2.5 構築方法

**前提条件:** git ホスト（GitHub, GitHub Actions 前提）、Node.js（CLI 実行）、エージェントランタイム（Claude Code / Codex / Grok）、MCP（任意、L1 では省略可）。概念前提: STATE.md 設計・SKILL.md による規約文書化・maker/checker 分離・worktree 隔離の理解。

**loop-audit（レディネス評価）:**

```bash
npx @cobusgreyling/loop-audit /path/to/your/repo            # スコアリング
npx @cobusgreyling/loop-audit /path/to/your/repo --suggest  # 改善提案付き
npx @cobusgreyling/loop-audit /path/to/your/repo --json     # CI 用 JSON
```

exit code: スコア 40 以上で 0 / 40 未満で 2 / 実行エラーで 1。

| レベル | 基準 | 内容 |
|---|---|---|
| L0 | スコア 38 未満 | 導入前。SKILL.md・STATE.md を先に整備 |
| L1 | 38 以上 + state file | レポートのみ運用 |
| L2 | 58 以上 + triage skill | 小規模自動修正を検証付きで |
| L3 | 78 以上 + verifier + state file | 明示的ゲート付き無人実行 |

**loop-init（scaffolding）:**

```bash
npx @cobusgreyling/loop-init . --pattern daily-triage --tool grok   # / claude / codex
```

生成物: `STATE.md`（High Priority / Watch List セクション）、トリアージスキル、検証者サブエージェント定義、`LOOP.md`（ループ設計の正本）。

**pattern-picker（パターン選択）:**

| パターン | 推奨 cadence | 初期ティア | トークンコスト |
|---|---|---|---|
| Daily Triage | 1 日 - 2 時間 | L1 | 低 |
| PR Babysitter | 5-15 分 | L1 → L2 | 高 |
| CI Sweeper | 5-15 分 | L2 | 非常に高 |
| Dependency Sweeper | 6 時間 - 1 日 | L2 | 中 |
| Post-Merge Cleanup | 1 日 - 6 時間 | L1 | 低 |
| Changelog Drafter | 1 日 / タグトリガー | L1 | 低 |

迷ったら **Daily Triage の L1 から**（state discipline を学べ、auto-merge リスクなし）。

**最初の L1 ループ立ち上げ:** `STATE.md` 作成 → トリアージスキル配置（`.claude/skills/loop-triage/SKILL.md`）→ `loop-audit . --suggest` で L1 ゲート確認。

## 2.6 利用方法

**必須パラメータ:** cadence / risk level / gating / verifier / denylist（auth・payment・secrets・インフラ）/ state file / max attempts（例: 3 回）。

**skill / starter の使い方（Claude Code `/loop`）:**

- L1 レポートのみ: `/loop 1d Run $loop-triage. Read STATE.md. Merge findings into High Priority and Watch List. Update Last run. Do not edit code.`
- L2 自動修正: `/loop 1d Run $loop-triage. For high-priority items that are single-file bugfixes: spawn implementer in worktree, then verifier agent. Update STATE.md. Escalate ambiguous items.`
- CI Sweeper: `/loop 15m $ci-triage — classify failures first. Fix only clear regressions in a worktree with verifier. Max 3 attempts. Escalate infra and security test failures.`
- PR Babysitter: `/loop 5m For each open PR: triage CI and reviews. Propose minimal fixes in worktree. Verifier must approve before commenting. Max 3 attempts per PR.`
- ワンショット実行は `/goal`（例: `/goal PR #1234 has green CI, no blocking review comments, and is rebased on main`）

**worktree 隔離（L2 以上で必須）:** subagent フロントマターに `isolation: worktree`。1 アイテム = 1 worktree。verifier が REJECT または人間がエスカレーションしたら破棄。LOOP.md のルール: unattended のコード変更実験はすべて isolated worktree、タスク完了/エスカレーション後に削除。

**GitHub Actions による定期起動:** エージェントランタイムが常時起動しない環境でループ継続。`schedule` cron（例: `0 8 * * 1-5`）+ `workflow_dispatch`。CI Sweeper は `workflow_run` の失敗をトリガーに起動。エージェント起動の 3 方式: (1) Codex CLI headless を CI 内で直接実行、(2) `repository_dispatch` で外部ランナー（Grok/Claude）を呼ぶ、(3) 自前スクリプト（ルールベース triage のみ、L0 限定）。

**maker / checker サブエージェント構成:**

```markdown
# 実装者（isolation: worktree）
You are an implementer sub-agent for loop-engineering.
Apply only the specific fix described in the task.
Do not self-merge. Signal the verifier when done.

# 検証者（fresh context）
You are an adversarial reviewer.
Run the test suite, check the diff against CONVENTIONS.md,
and reject anything that is not verifiably done.
Use a fresh context — do not share memory with the implementer.
Report APPROVE or REJECT with reasons.
```

設計原則: 実装者は自分の成果物を承認できない / 検証者は独立したテスト実行で確認（実装者のセッションを再利用しない）/ 検証者には強力なモデルを推奨 / stop condition の評価にも fresh model。

**自律ティアを上げる手順:**

| ティア | 内容 | 維持期間目安 |
|---|---|---|
| L1 | レポートと STATE.md 更新のみ。人間が毎回確認 | 1-2 週間 |
| L2 | worktree 修正 + verifier 承認時のみ PR。auto-merge は allowlist 限定。試行上限 3 回 | 安定後に L3 検討 |
| L3 | denylist・予算上限・人間ゲート確認後に移行。観測性強化 | 条件達成後のみ |

**L1 → L2 移行チェックリスト:** state 設計（スキーマ文書化）/ スキル整備（SKILL.md に build・test コマンド）/ maker-checker 別セッション / denylist（auth・payments・secrets・インフラ）/ auto-merge allowlist / コスト上限（日次トークン上限・最大サブエージェント数）/ ログ（run start / findings / actions / escalations）。

## 2.7 運用

**稼働中ループの監視（4 軸）:**

| 軸 | 計測値 | 警戒閾値 |
|---|---|---|
| トークンコスト | token-per-task | ベースライン 2 倍超 |
| 実行回数 | loop iterations | 同一対象 3 回超 |
| 成功率 | completion / false positive rate | false positive 30% 超 |
| コンテキスト利用率 | context window 占有率 | 85% 超 |

各実行時ログ: `run_id / pattern / duration_sec / findings / actions / escalations / token_estimate / outcome`。

トークンコストは二次関数的に拡大しがち（naive に毎ステップ全会話履歴を再送すると累積は約 N(N+1)/2 倍。context reset・要約・prompt caching で緩和）。

**STATE.md の週次レビュー:** STATE.md はループの外部記憶（durable spine）。放置すると state rot（クローズ済みチケットへの参照蓄積）。手順: (1) 全アイテムをライブ API で実在確認 (2) クローズ済みを削除 or `done` へ (3) 48h 以内 2 回以上エスカレーションされたものを人手インボックスへ (4) LOOP.md と cadence・停止条件の実態照合 (5) 週次サマリ追記。

**ループの停止と再開（3 段階）:**
- Slow Down: 予算 80% 超 / false positive 30% 超 / リリースフリーズ
- Pause: 本番インシデント / 破壊的スキーママイグレーション / auto-merge 有効でレビュアー不在
- Kill: S2 以上の障害反復 / 2 週連続コスト対価値比逆転 / 代替手段登場

停止基準は LOOP.md に明記: `token_daily_budget / pause_at_budget_pct / kill_on_consecutive_s2_failures / kill_on_cost_inversion_weeks`。

**Autonomy Tier の昇降:** 昇格は慎重に・降格は即座に。L1→L2: 1-2 週間の安定稼働・triage 精度測定済み。L2→L3: verifier 設置・path denylist・token 予算・人手ゲートすべて済み。**新しいパターンは必ず L1 から**（既存ループが L3 でも新機能は L1）。

**Multi-loop の協調（5 原則）:** (1) ブランチ排他所有 (2) 状態ファイルの分離（`state-triage.md` 等） (3) 役割の分離（Triage は L1 レポートのみ、Action ループは独立） (4) 統一 denylist (5) 予算の合算管理。

衝突検出は `acting_on` フィールドでピア確認:

```bash
grep -h "acting_on:" state-*.md | sort | uniq -d   # 重複検出
```

優先順位: CI 失敗 → アクティブ PR → 依存関係 → クリーンアップ → レポート。推奨開始構成: Daily Triage / PR Babysitter / Post-Merge Cleanup。

**人手ゲートの運用:** 設ける目安 = medium-risk 変更（security / schema / public API）/ verifier 拒否 / 2 回目以上のエスカレーション / auto-merge 有効パスへの変更。通知は Slack / Linear への Ping、`human_inbox` セクションに待機アイテム列挙。**ゲート応答なしでも無限待機せずスキップして次サイクルへ。**

## 2.8 ベストプラクティス

- **段階的ロールアウト:** Week 1-2: L1（triage 精度計測、false positive < 30% 目標）→ Week 3-4: L2（verifier + worktree + 小規模修正）→ Week 5+: L2+ Connectors → Month 2+: L3（条件達成後のみ）。
- **Maker-Checker（Verifier 必須）:** 単一エージェントの自己検証は確証バイアス。Verifier はデフォルト「拒否」姿勢、プロンプトに CI テスト出力と lint 結果を含める、モデルは実行エージェントより強力 or 別系統。**Verifier Theater**（verifier 承認なのに CI 失敗）= プロンプト曖昧 or テスト実行省略。
- **停止条件を First-Class に:** ループを作るより先に止め方を設計。「停止条件なしに L3 を起動してはならない」を不変ルールに。
- **Token 予算管理:** 日次上限 + 80% で一時停止 / 安価モデルで triage、処理すべきアイテムがある時のみサブエージェント起動 / 空のウォッチリストは早期終了（最大のコスト削減機会）/ phase 境界ごとに会話履歴リセット。

コスト圧縮パターン効果（参考値）: スコープ限定（サブエージェント分離）約 40% / コーディネーター・スペシャリスト分離 約 54% / 文脈トリミング（10-15 呼び出しごと）約 23% / Prompt caching（固定系）固定部のみ最大 90%。

- **Denylist / MCP スコープ制約:** MCP は最小権限（`read: [repo, issues, pulls]`, `write: [pull_request_comments]`, `deny: [branch_protection, secrets, admin]`）。path_denylist 例: `.env`, `credentials*`, `secrets*`, `migration/*.sql`, `infrastructure/**`。L1: read-only + PR コメント書き込みのみ / L2: 承認済み path への limited write + branch 作成 / L3: allowlist 内パスへの write、auto-merge は allowlist 必須。**denylist は全ループで共有**。
- **Security（最小権限化）:** クレデンシャル・`.env`・シークレットを denylist へ / ログへのシークレット漏洩防止 / allowlist 外変更は人手レビュー必須 / 依存関係の初回更新は auto-merge しない（supply chain attack 対策）/ コネクタートークンは短命・タスクスコープ型。
- **Comprehension Debt の管理:** 放置すると Cognitive Surrender（チームがループ出力をそのまま受け入れる）。対策: 週次ダイジェスト義務化 / medium-risk 以上は人手ゲート / 「チームがループを使って解決した」姿勢 / KPI を処理量でなく品質に。判定基準: auto-merge 変更を自分の言葉で要約できるか / 意図と根拠をループ出力に頼らず説明できるか / 2 週連続の後追い Revert があれば L2 へ降格。

## 2.9 トラブルシューティング（頻出 Failure Mode）

| 症状 | 原因 | 対処 |
|---|---|---|
| 同一 PR に 5 回以上自動修正 | Verifier 弱い / 根本原因診断ミス（Infinite Fix Loop） | リトライ上限 3 回、強力モデルで Verifier 交換 |
| CI 通らないのに Verifier 承認 | プロンプト曖昧 / テスト実行省略（Verifier Theater） | 「拒否する理由を探す」フレーミング、テスト/lint 出力必須化 |
| STATE.md にクローズ済みチケット増殖 | pruning なし / 複数ループが同一ファイル書き込み（State Rot） | 実行ごとに削除、ループごとにファイル分離 |
| 変更意図が理解されない | auto-merge 拡大 / 週次レビュー省略（Comprehension Debt Spiral） | 週次ダイジェスト義務化、medium-risk を人手ゲートへ |
| チームが「ループが何とかする」 | 品質指標なしの量的指標優先（Cognitive Surrender） | KPI を品質に紐付け、人手ゲート追加 |
| マージコンフリクト多発 | worktree 分離なし / 同一ブランチ操作（Parallel Collision） | `isolation: worktree`、`acting_on` ピア確認 |
| 無限リトライして通知なし | attempt cap なし / サイレントエスカレーション（Escalation Failure） | cap 3、escalation 時 Slack/Linear Ping |
| 予算超過 | 低コスト triage パスなし / 空ウォッチリスト継続（Token Burn） | triage-first、早期終了、80% で一時停止 |
| 無関係なファイル変更 | path denylist なし（Over-Reach） | denylist 即時設定、verifier で確認 |
| コンテキスト肥大で品質劣化 | 履歴が無制限蓄積（Context Rot） | phase 境界でリセット、10-15 呼び出しごとにトリミング |
| 通知が多すぎて無視される | 不要更新も全件通知（Notification Fatigue） | 人手アクションが必要な時のみ通知、報告はバッチ化 |

**限界と適用条件:** 無人ループは無人ミスも生む / ループは良い判断も悪い判断も増幅する（verifier が弱ければ速度が上がるほど被害が拡大）/ Verification は人間の責任 / Comprehension Debt は静かに蓄積 / コストは予測通りにいかない（二次関数的性質を前提に設計）/ **L3 は目標でなく条件が揃ったときの選択肢。多くのパターンは L2 で十分な価値**。

---

# 第 3 部: Harness Optimization（メタループ）

*出典: 岩瀬「Harness Optimization 概要」*

## 3.1 定義

同じ model を使っていても、prompt、tool の見せ方、workflow、memory、失敗時の recovery が違えば agent の結果は変わる。**Harness optimization は、model weight を固定したまま、この周囲の実行系（harness）を agent の実行記録と評価から更新する問題**。

例: agent が tool の結果を確認せずに回答した。修正候補 = 指示を変える / 確認 step を追加する / 回答前に validator を置く。ただし候補を作っただけでは改善とは言えない。**現行版と同じ条件で比較し、採用した変更を次の task へ残す**必要がある。

**Harness に含まれるもの（Weng 2026）:** system prompt、context assembly、retrieval、durable memory、tool mediation、workflow、verification、retry、rollback。

## 3.2 何を Harness Optimization と呼ぶか（三条件）

1. 実行から得た**記録や評価が更新を駆動する**
2. 更新後の harness が**version として保存され、将来の task へ持ち越される**
3. **Optimizer から分離した evaluator** が現行版と更新候補を測り、事前に決めた**採否規則**が次 version を選ぶ

三つ目の条件がなければ、optimizer は harness と一緒に「何を改善と数えるか」まで変更できる。**候補を作る仕組みと、候補を採用する仕組みは分離する**。

**対象範囲:**

| 変更 | 扱い |
|---|---|
| Prompt、tool policy、workflow、memory policy を評価後に保存 | 含める |
| Memory へ通常の実行記録を追加 | State 更新。それだけでは最適化と呼ばない |
| 一回の task で sample 数や reflection 回数を増やす | 次回へ変更が残らない test-time scaling。含めない |
| Fine-tuning や RL で model weight を変える | Model optimization。別に扱う |

「Autonomous research」「self-evolving agent」という名前だけでは対象に含めない。三条件を満たす harness 更新 loop があるかで判断。

**境界例:** Reflexion は失敗後の reflection を同じ task 内の次の試行で利用（task-local な state 更新）。独立した将来 task へ version として持ち越す persistent harness update とは分ける。Harness-R1 は target model を固定し、別の editor が更新候補を生成（学習するのは editor だが、更新対象は harness）。

## 3.3 更新候補を作り、外部で採否を決める

現行版（incumbent）を H_t、更新候補（candidate）を H'_t とする。Target agent A_{θ,H_t} の θ は固定 model parameter。実行すると実行記録 τ_t と評価 y_t が得られ、optimizer O が更新候補を作る:

```
H'_t = O(H_t, τ_t, y_t)
H_{t+1} = H'_t  (V(H'_t, H_t) = accept のとき)  それ以外は H_t
```

- 採否規則 V は、**外部 evaluator** が作った現行版と更新候補の評価記録を比較する
- Optimizer は候補を提案できるが、evaluator や V は変更できない
- Target model と environment も原則として固定。変更する場合は別 version として比較

## 3.4 更新 loop 全体を比較する

個別の model 名や agent framework ではなく、次の更新 loop 全体を比較する:

```
Current harness → Execution → Evidence → Candidate generation
→ External evaluation → Acceptance / rollback → Next version
```

同じ prompt optimizer でも、training example だけで候補を選ぶ方法と、未使用 task で確認する方法では「改善」という主張の強さが異なる。同じ workflow editor でも、対象の失敗だけを直す方法と、既存の成功や安全性まで確認する方法は分けて考える。

**比較できる実験にするため開始前に固定する五点:**

1. **変更範囲** — 変更可能な file、hook、prompt、tool schema
2. **固定条件** — API、権限、timeout、出力 schema
3. **保存する状態** — task をまたいで残るもの
4. **評価指標** — quality、cost、応答時間、failure rate の集計方法
5. **採否規則** — 採用・棄却し、必要なら元へ戻す条件

例: 「pre-action hook は変更可、evaluator と tool 権限は変更不可」と書ける状態にする。**この境界が曖昧だと、性能差が harness の変更によるものか、条件の違いによるものか分からない**。

---

# 第 4 部: 統合 — 三層を一つのシステムとして設計する

## 4.1 三層の対応関係

| SDK（内側のループ） | Loop Engineering（外側のループ） | Harness Optimization（メタループ） |
|---|---|---|
| ターン・メッセージ・ツール実行 | スケジュール・自己プロンプト | 実行記録 τ_t の収集元 |
| `max_turns` / `max_budget_usd` | token 予算・attempt cap・停止条件 | 評価指標（cost、failure rate） |
| `allowed_tools` / `permission_mode` | denylist / allowlist / Human Gate | 変更範囲の固定条件（tool policy） |
| Hooks（PreToolUse 等） | Triage Skill / Verifier 分離 | harness の変更可能点（hook は変更可） |
| 自動圧縮 / コンテキスト管理 | Context Rot 対策（phase 境界リセット） | context assembly の改善対象 |
| `session_id` 再開・フォーク | 外部状態（STATE.md）・worktree | 保存する状態（version として持ち越す） |
| `ResultMessage.subtype` | loop-run-log / 4 軸監視 | 評価 y_t の入力 |
| サブエージェント（fresh context） | Maker / Checker 分離 | verifier 分離と同型のバイアス排除 |

## 4.2 統合された設計原則

1. **ループの解剖学を共通言語にする。** どの層でも「実行 → 証跡（Evidence）→ 判断 → 次の実行」が基本形。SDK のターン、loop engineering のサイクル、harness optimization の更新 loop はすべてこの形。
2. **判断を自動化する前に、判断の品質を構造で保証する。** Maker/Checker 分離・外部 evaluator・Human Gate は、いずれも「評価者と被評価者を分ける」という同じ原理。自己採点はどこでも禁止。
3. **状態は外部に永続化する。** セッションは忘れる。STATE.md / memory ファイル / セッション ID 再開 / version として保存された harness が、層をまたいで連続性を支える。
4. **止め方を先に設計する。** ターン・予算上限（SDK）、停止条件と Kill スイッチ（LOOP.md）、採否規則と rollback（harness optimization）— 三層すべてで「いつ止めるか」が First-Class。
5. **コストは二次関数的。** 毎ステップの全文脈再送を避け、triage-first（安価モデル）→ action（強力モデル）の二段構造、prompt caching、phase 境界のリセット、空ウォッチリストの早期終了で抑える。
6. **改善は証跡と外部評価で駆動する。** 直感で harness を変えず、現行版 vs 候補を同一条件で比較し、採用した変更だけを version として次へ残す。変更範囲・固定条件・評価指標・採否規則を事前に明文化する。
7. **自律性は段階的に上げ、リスクで下げる。** L1 → L2 → L3 の順で必ず進み、昇格は測定後・降格は即座。L3 は目標でなく条件が揃ったときの選択肢。
8. **人間の理解を維持する。** Comprehension Debt と Cognitive Surrender への対策（週次ダイジェスト・人手ゲート・品質 KPI）は、どの層の自動化でも省略しない。

## 4.3 三層をつなぐ運用ループの例

```
[外側] Schedule (GitHub Actions / cron)
  → [外側] Triage Skill（安価モデル、STATE.md 更新、空なら早期終了）
  → [内側] サブエージェント（Implementer, worktree 隔離, max_turns 設定）
  → [内側] Verifier（fresh context、強力モデル、デフォルト拒否）
  → [外側] Human Gate（denylist/allowlist 判定 → auto-PR または escalate）
  → [メタ] 実行記録 τ_t と評価 y_t を収集（run-log、token-per-task、false positive）
  → [メタ] 外部 evaluator が現行版 harness と候補を比較
  → [メタ] 採否規則 V が次 version を選び、採用分を将来の task へ持ち越す
```

この全体が一つの「harness」であり、三条件（記録駆動・version 保存・evaluator 分離）を満たせば、そのループ自体が harness optimization の対象になる。

---

# 参考文献

1. Anthropic. [エージェントループの仕組み — Claude Agent SDK](https://code.claude.com/docs/ja/agent-sdk/agent-loop)
2. 諏訪真一. [Loop Engineering 入門: AI コーディングエージェントを動かすシステムを設計する](https://zenn.dev/suwash/articles/loop-engineering_20260610)。調査対象: cobusgreyling/loop-engineering。起点: Addy Osmani "Loop Engineering"（2026-06-07）
3. 岩瀬. [Harness Optimization 概要](https://notes.iwase.dev/ja/harness-optimization/overview)。引用文献: Weng, Lilian. *Harness Engineering for Self-Improvement* (2026) / Shinn et al. *Reflexion* (2023) / Shao et al. *Harness-R1* (2026)
