# suggest_v1 — エージェントループ統合ガイド + agent-loop-v1 ギャップ解消提案

- 作成: 2026-08-10
- 内容 1: 三記事の統合（エージェントループの仕組み × Loop Engineering × Harness Optimization）
- 内容 2: `agent-loop-v1` の現状評価とギャップを埋める提案（P0/P1/P2）

---

# Part 1: 三記事の統合ガイド

## 1. はじめに: 三つの文書は「ループの三層」を描いている

| 層 | 文書 | 対象 | 問い |
|---|---|---|---|
| **内側のループ** | Agent SDK ドキュメント | 1 エージェント内のターン・メッセージ・ツール実行・コンテキスト | ループの中で何が起きているか |
| **外側のループ** | Loop Engineering（Zenn） | ループを自律的に起動・統治するシステム全体（スケジュール・状態・ゲート） | 誰がエージェントをプロンプトするのか |
| **メタループ** | Harness Optimization（iwase） | ループの実行系（harness）そのものを実行記録と評価から改善する仕組み | どうやって harness 自体を良くしていくか |

要約: **内側のループを「ループ設計」が束ね、その実行系を「ハーネス最適化」が証跡と評価に基づいて更新する**。

## 2. 内側のループ — エージェントループの仕組み（Claude Agent SDK）

### 2.1 ループの概要（全セッション共通の 5 サイクル）

1. **プロンプトを受け取る** — プロンプト・システムプロンプト・ツール定義・会話履歴。SDK は `subtype: "init"` の `SystemMessage` を生成
2. **評価して応答する** — テキスト / 1 つ以上のツール呼び出し / 両方。SDK は `AssistantMessage` を生成
3. **ツールを実行する** — 各ツールを実行し結果を収集。結果は次の決定へフィードバック。hooks で傍受・変更・ブロック可能
4. **繰り返す** — ステップ 2+3 がサイクルとして反復。各完全サイクル = 1 ターン。ツール呼び出しのない応答まで継続
5. **結果を返す** — 最終 `AssistantMessage`（テキストのみ）→ テキスト・トークン使用量・コスト・セッション ID を含む `ResultMessage`

### 2.2 ターンとメッセージ

- ターン = ループ内の 1 往復（コードに制御を戻さない）
- `max_turns` / `maxTurns`: ツール使用ターンのみカウント
- `max_budget_usd` / `maxBudgetUsd`: 支出しきい値でキャップ
- **制限なし = オープンエンドプロンプトで長時間実行のリスク。予算設定は本番エージェントの良いデフォルト**

### 2.3 メッセージタイプ（5 つのコアタイプ）

| タイプ | 内容 |
|---|---|
| `SystemMessage` | セッションライフサイクル。`subtype`: `"init"` / `"compact_boundary"`（圧縮後）/ `"informational"` / `"worker_shutting_down"` |
| `AssistantMessage` | 各 Claude 応答後。テキスト + ツール呼び出しブロック |
| `UserMessage` | 各ツール実行後のツール結果 |
| `StreamEvent` | 部分メッセージ有効時のみ。生 API ストリーミングイベント |
| `ResultMessage` | ループ終了。最終テキスト・使用量・コスト・セッション ID。`subtype` で成功/制限到達を判断 |

処理: 最終結果のみ → `ResultMessage` / 進捗 → `AssistantMessage` / ライブ → `StreamEvent`。タイプチェックは Python `isinstance()`、TS `message.type === "result"`。

### 2.4 ツール実行

**組み込みツール:** ファイル操作（`Read`/`Edit`/`Write`）、検索（`Glob`/`Grep`）、実行（`Bash`）、Web（`WebSearch`/`WebFetch`）、検出（`ToolSearch`）、オーケストレーション（`Agent`/`Skill`/`AskUserQuestion`/`TaskCreate`/`TaskUpdate`）。加えて MCP 接続・カスタムツール・スキルロード。

**権限（3 オプション連携）:**
- `allowed_tools`: 自動承認。リスト外は権限が必要
- `disallowed_tools`: 他設定に関係なくブロック
- `permission_mode`: 未カバーのツールの扱い（`"default"` / `"acceptEdits"` / `"plan"` / `"dontAsk"` / `"auto"` / `"bypassPermissions"`）

**並列実行:** 読み取り専用ツールは同時、状態変更ツールは順序実行。カスタムツールの並列化は `readOnlyHint`。

### 2.5 ループ制御

- **努力レベル** `effort`: `"low"`（最小推論・高速）→ `"medium"` → `"high"`（リファクタ/デバッグ）→ `"xhigh"`（agentic coding）→ `"max"`（複数ステップ深解析）。拡張思考とは独立。サブエージェントごとに上書き可能
- **権限モード**: インタラクティブ UI → `"default"`+承認コールバック / 開発マシン自律 → `"acceptEdits"` / CI・コンテナ → `"bypassPermissions"`
- **モデル**: 未設定ならデフォルト。小さいモデル明示指定でコスト削減

### 2.6 コンテキストウィンドウ

- セッション中ずっと蓄積。ターン間で同一の内容（システムプロンプト・ツール定義・CLAUDE.md）はプロンプトキャッシュでコスト削減
- 消費源: システムプロンプト（小さい固定）/ CLAUDE.md（全リクエスト、キャッシュあり）/ ツール定義（MCP はデフォルト遅延）/ 会話履歴（蓄積）/ スキル説明（要約のみ）
- **自動圧縮**: 制限近接時に古い履歴を要約に置換（`compact_boundary` 発火）。初期の特定指示は失われる → **永続ルールは CLAUDE.md に置く**
- 効率化: サブエージェント（親コンテキストは要約のみ増加）/ ツール選別 / MCP 監視 / ルーチンに低 effort

### 2.7 セッションと結果処理

- `session_id` で再開（完全コンテキスト復元）・フォーク可能
- `ResultMessage.subtype`: `success`（result あり）/ `error_max_turns` / `error_max_budget_usd` / `error_during_execution` / `error_max_structured_output_retries`。全サブタイプが `total_cost_usd`・`usage`・`num_turns`・`session_id` を持つ
- `stop_reason`: `end_turn` / `max_tokens` / `refusal`（拒否検出）
- 単一ショット `query()` はエラー結果生成後に例外 → try ブロックでラップ

### 2.8 Hooks（コンテキストを消費しない。ループをショートサーキット可能）

| フック | 発火 | 用途 |
|---|---|---|
| `PreToolUse` | ツール実行前 | 入力検証、危険コマンドブロック |
| `PostToolUse` | ツール戻り後 | 出力監査、副作用 |
| `UserPromptSubmit` | プロンプト送信時 | 追加コンテキスト注入 |
| `Stop` | 終了時 | 結果検証、状態保存 |
| `SubagentStart`/`SubagentStop` | サブエージェント生成/完了 | 並列結果集約 |
| `PreCompact` | 圧縮前 | 完全トランスクリプトアーカイブ |

## 3. 外側のループ — Loop Engineering

### 3.1 概要

設計対象を「個々のプロンプト」から「ループ（システム）」へ。エージェントへ指示する**システムそのものを設計**する。

> Boris Cherny: "I don't prompt Claude anymore. I have loops running that prompt Claude... My job is to write loops"

進化: オートコンプリート 2023 → プロンプト生成 2024 → 並列エージェント 2025 → **自己プロンプトループ 2026**。ReAct が 1 回の推論サイクルを定義したのに対し、loop engineering は「複数ループを協調・統治するメタ設計」。

| 観点 | Prompt Eng | Context Eng | Loop Eng |
|---|---|---|---|
| 設計対象 | プロンプト文 | ウィンドウの中身 | ループ全体の制御システム |
| 介入 | ターンごと人間 | レスポンス前 | スケジュール駆動自律 |
| 状態管理 | なし | セッション内 | 外部永続化 |
| スタック | 基盤層 | 中間層 | 最上位層（包含） |

**注意: 層は積み重なる。ループ内のずさんなプロンプトはずさんな作業を速く生産するだけ。**

### 3.2 7 つの特徴

1. **再帰的ゴール** — 検証条件を満たすまで自律反復
2. **自己プロンプト** — システムが「何をいつプロンプトするか」を決定
3. **Maker-Checker 分離** — 実装者と検証者を分離し自己採点バイアスを排除
4. **段階的自律** — L1 Report / L2 Assisted / L3 Unattended
5. **外部状態管理** — セッション横断の永続ストア（Markdown 等）
6. **トークンコスト増大** — 設計段階でコストと自律レベルのトレードオフ計画
7. **Comprehension Debt** — 生成速度がレビュー速度を上回ると理解が追いつかない

### 3.3 構造

**コンテナ（6 プリミティブ）:** Automations/Scheduling、Worktrees、Skills、Plugins/Connectors（MCP）、Sub-agents（Implementer/Verifier）、Memory/State。

**コンポーネントフロー:**

```
Schedule → Triage Skill → Read/Write State → Isolated Worktree
  → Implementer → Verifier → MCP/Git/Tickets
  → Human Gate → (Auto-commit / PR) | (Escalate to Human)
```

**Human Gate は自律ティアで構成変更:**
- L1: レポートのみ。全判断を人間に委ねる（Gate なし）
- L2: Implementer+Verifier 起動。PR 作成までで停止、マージは人間
- L3: denylist 外のみ Auto-commit。denylist 内は人間キューへ昇格

**Maker-Checker 原則:** 同一エージェントにしない。検証者は独立テスト実行・強力モデル・デフォルト拒否姿勢。

### 3.4 データモデル（主要項目）

- `Loop.cadence` / `risk_level` / `autonomy_tier` / `handoff_trigger` / `token_cost`
- `SubAgent.role`（Maker/Checker/Triage）/ `model`
- `State.readiness_score` / `acting_on`（Multi-loop 衝突検出）
- `HumanGate.trigger_condition` / `escalation_context`
- `Denylist.entries` / `scope`
- `Pattern.gate_condition` / `overlap_rule`

### 3.5 構築・利用

- **loop-audit**: レディネススコア。L0（38 未満）/ L1（38+state file）/ L2（58+triage skill）/ L3（78+verifier）
- **loop-init**: `STATE.md`・トリアージスキル・検証者定義・`LOOP.md` を生成
- **パターン例**: Daily Triage（L1, 低コスト）/ PR Babysitter（L1→L2, 高）/ CI Sweeper（L2, 非常に高）/ Dependency Sweeper（L2, 中）。**迷ったら Daily Triage の L1 から**
- **worktree 隔離**: `isolation: worktree`、1 アイテム = 1 worktree、REJECT で破棄
- **GitHub Actions**: cron + `workflow_dispatch`。CI Sweeper は `workflow_run` 失敗トリガー。エージェント起動は (1) CLI headless (2) `repository_dispatch` (3) 自前スクリプト（L0 限定）
- **自律ティア昇格**: L1 を 1-2 週間 → 測定後に L2 → verifier・denylist・予算・ゲート確立後にのみ L3。**新パターンは必ず L1 から**

### 3.6 運用

- **監視 4 軸**: token-per-task（ベースライン 2 倍で警戒）/ loop iterations（同一対象 3 回超）/ false positive（30% 超）/ context 占有率（85% 超）
- **トークンコストは二次関数的**: naive 再送で累積 N(N+1)/2 倍。context reset・要約・prompt caching で緩和
- **STATE.md 週次レビュー**: 実在確認 → クローズ済み削除 → 2 回以上エスカレのもの人手へ → LOOP.md 照合（state rot 防止）
- **停止 3 段階**: Slow Down（予算 80% 超など）/ Pause（インシデント等）/ Kill（S2 反復・コスト逆転 2 週）。**停止基準は LOOP.md に明記**
- **Multi-loop 5 原則**: ブランチ排他所有 / 状態ファイル分離 / 役割分離 / 統一 denylist / 予算合算管理。衝突検出は `acting_on` でピア確認
- **人手ゲート**: medium-risk・verifier 拒否・2 回目以上のエスカレ・auto-merge 有効パスで発動。応答なしでも無限待機せずスキップ

### 3.7 ベストプラクティス

- **段階的ロールアウト**: 測定してから拡大。Week 1-2: L1（false positive < 30% 目標）→ Week 3-4: L2 → Week 5+: コネクタ → Month 2+: L3
- **Maker-Checker**: 自己検証は確証バイアス。Verifier はデフォルト拒否・CI 出力必須・実行系より強力なモデル。**Verifier Theater**（承認なのに CI 失敗）= プロンプト曖昧 or テスト省略
- **停止条件を First-Class に**: ループを作るより先に止め方を設計。「停止条件なしに L3 を起動してはならない」
- **Token 予算管理**: 日次上限 + 80% で一時停止 / 安価モデル triage → 必要時のみ強力モデル / 空ウォッチリストは早期終了（最大のコスト削減機会）/ phase 境界で履歴リセット
- コスト圧縮効果（参考値）: スコープ限定 約 40% / コーディネーター分離 約 54% / 文脈トリミング 約 23% / Prompt caching 最大 90%
- **Denylist/MCP**: 最小権限。`path_denylist` に `.env`・credentials・secrets・migration・infrastructure。L1 read-only / L2 limited write / L3 allowlist 内のみ。**denylist は全ループで共有**
- **Security**: クレデンシャルを denylist / ログ漏洩防止 / allowlist 外は人手 / 依存初回更新は auto-merge しない（supply chain）/ トークンは短命・タスクスコープ
- **Comprehension Debt**: 週次ダイジェスト義務化 / medium-risk 人手ゲート / 「チームがループを使って解決した」姿勢 / KPI は品質に。2 週連続 Revert があれば L2 降格

### 3.8 トラブルシューティング（頻出 Failure Mode）

| 症状 | 原因 | 対処 |
|---|---|---|
| 同一 PR に 5 回以上自動修正 | Verifier 弱い（Infinite Fix Loop） | リトライ上限 3、強力モデル |
| CI 通らないのに承認 | テスト省略（Verifier Theater） | 拒否フレーミング、出力必須化 |
| 状態ファイルにクローズ済み増殖 | pruning なし（State Rot） | 実行ごと削除、ファイル分離 |
| 意図が理解されない | auto-merge 拡大（Comprehension Debt Spiral） | 週次ダイジェスト、人手ゲート |
| チームが丸投げ | 量的指標優先（Cognitive Surrender） | KPI を品質に |
| コンフリクト多発 | worktree なし（Parallel Collision） | `isolation: worktree`、`acting_on` |
| 無限リトライ・通知なし | cap なし（Escalation Failure） | cap 3、escalation 時 Ping |
| 予算超過 | triage なし（Token Burn） | triage-first、早期終了、80% 一時停止 |
| 無関係なファイル変更 | denylist なし（Over-Reach） | denylist 即時設定 |
| 品質劣化 | 履歴無制限蓄積（Context Rot） | phase 境界リセット、トリミング |
| 通知多すぎ | 不要更新も全件通知（Notification Fatigue） | 必要な時のみ通知 |

**限界:** 無人ループは無人ミスも生む / ループは良い判断も悪い判断も増幅 / Verification は人間の責任 / コストは予測不能（二次関数前提）/ **L3 は目標でなく条件が揃ったときの選択肢。多くのパターンは L2 で十分な価値**。

## 4. メタループ — Harness Optimization

### 4.1 定義

model weight を固定したまま、周囲の実行系（harness）を agent の実行記録と評価から更新する問題。

**Harness に含まれるもの:** system prompt、context assembly、retrieval、durable memory、tool mediation、workflow、verification、retry、rollback。

### 4.2 三条件

1. 実行から得た**記録や評価が更新を駆動する**
2. 更新後の harness が**version として保存され、将来の task へ持ち越される**
3. **Optimizer から分離した evaluator** が現行版と更新候補を測り、事前に決めた**採否規則**が次 version を選ぶ

**候補を作る仕組みと、候補を採用する仕組みは分離する。**

### 4.3 対象範囲

| 変更 | 扱い |
|---|---|
| Prompt、tool policy、workflow、memory policy を評価後に保存 | 含める |
| Memory への通常の実行記録追加 | State 更新（最適化と呼ばない） |
| sample 数・reflection 回数を増やす | test-time scaling（含めない） |
| Fine-tuning / RL | Model optimization（別扱い） |

### 4.4 現行版 vs 更新候補

```
H'_t = O(H_t, τ_t, y_t)
H_{t+1} = H'_t  (V(H'_t, H_t) = accept のとき)  それ以外は H_t
```

- 採否規則 V は外部 evaluator の評価記録を比較。Optimizer は evaluator や V を変更できない
- Target model と environment は原則固定。変更する場合は別 version として比較

### 4.5 更新ループ全体と五つの固定点

```
Current harness → Execution → Evidence → Candidate generation
→ External evaluation → Acceptance / rollback → Next version
```

比較可能な実験にするための五点:

1. **変更範囲** — 変更可能な file、hook、prompt、tool schema
2. **固定条件** — API、権限、timeout、出力 schema
3. **保存する状態** — task をまたいで残るもの
4. **評価指標** — quality、cost、応答時間、failure rate の集計方法
5. **採否規則** — 採用・棄却し、必要なら元へ戻す条件

**境界が曖昧だと、性能差が harness の変更によるものか、条件の違いによるものか分からない。**

## 5. 統合 — 三層の対応関係

| SDK（内側） | Loop Engineering（外側） | Harness Optimization（メタ） |
|---|---|---|
| ターン・メッセージ・ツール実行 | スケジュール・自己プロンプト | 実行記録 τ_t の収集元 |
| `max_turns` / `max_budget_usd` | token 予算・attempt cap・停止条件 | 評価指標（cost, failure rate） |
| `allowed_tools` / `permission_mode` | denylist / allowlist / Human Gate | 変更範囲の固定条件 |
| Hooks | Triage Skill / Verifier 分離 | harness の変更可能点 |
| 自動圧縮 / コンテキスト管理 | Context Rot 対策 | context assembly の改善対象 |
| `session_id` 再開・フォーク | 外部状態（STATE.md）・worktree | 保存する状態 |
| `ResultMessage.subtype` | loop-run-log / 4 軸監視 | 評価 y_t の入力 |
| サブエージェント（fresh context） | Maker / Checker 分離 | verifier 分離と同型のバイアス排除 |

**統合された設計原則:**
1. 実行 → 証跡 → 判断 → 次の実行。三層すべてが同じ基本形
2. 評価者と被評価者はどこでも分離（自己採点禁止）
3. 状態は外部に永続化
4. 止め方を先に設計（ターン・予算・停止条件・採否規則）
5. コストは二次関数的（triage-first、キャッシュ、リセット、早期終了）
6. 改善は証跡と外部評価で駆動（現行版 vs 候補を同一条件で比較）
7. 自律性は段階的に上げ、リスクで下げる（L1→L2→L3、降格は即座）
8. 人間の理解を維持する（Comprehension Debt 対策は省略しない）

---

# Part 2: agent-loop-v1 現状評価とギャップ解消提案

## 6. 全体評価

L2 相当の HITL 実装。2 ゲート・maker/checker 分離・worktree 隔離・証跡記録を備え、統合ガイドの概念の約 6 割を実装済み。特筆すべきは **harness optimization を自己適用している**点（ループの改善をループ自身の実行で行い、人間 + レビュアーを分離された評価者とする）。

主要ギャップ: **構造的 denylist なし / 予算ガードなし / 評価指標・採否規則の非形式化 / スケジュール層なし**。

## 7. 三層マッピング（実装状況）

### 内側のループ

| 概念 | 状態 | 備考 |
|---|---|---|
| Terminal-stop 規律（`stopReason == "stop"`） | ✅ | `pi_usage.py` status — `ResultMessage.subtype` 相当 |
| phase 境界でのコンテキストリセット | ✅ | 各 stage は fresh な `pi -p` 単発呼び出し（Context Rot 対策が構造的に成立） |
| エージェント呼び出しごとのターン/予算制限 | ⚠️ | `MAX_CYCLES` はリトライサイクルの cap のみ。worker 呼び出し自体にターン/コスト予算なし（task-004 は 1 回の implement で 1.16M tokens）。`STAGE_TIMEOUT_S` は実装済みだが既定 0（無効） |
| コストガード | ❌ | 記録は ✅（cost-log, EXIT trap, provider-aware）だが予算超過 abort は未実装（Q12 で先送り） |

### 外側のループ

| 概念 | 状態 | 備考 |
|---|---|---|
| 再帰的ゴール（BFV 完了条件） | ✅ | task ファイルに完了条件 + Stop-And-Ask + Out-of-scope |
| 自己プロンプト | ✅ | loop.sh が全プロンプトを自動化 |
| Maker–Checker 分離 | ✅ | worker（deepseek）/ reviewer（gpt-5.6）。family 分離・fresh context・adversarial・worker 昇格時の reviewer fallback 切替 |
| Human Gate | ✅ | 2 ゲート + redirect ポリシー + redirect 再ゲート（教訓反映済み） |
| Worktree 隔離 | ✅ | branch-per-loop + worktree、rollback = branch 削除 |
| 外部状態 | ✅ | `memory/`（decisions-log, past-runs, known-failures, cost-log, runs/） |
| attempt cap + 昇格 | ✅ | 3 cycles / 2 escalations / DONE flag |
| **path denylist / allowlist** | ❌ | **worker が触れる範囲の構造的制限なし**。per-task の Non-negotiables（ソフトな指示文）と `git diff --check` のみ。ガイドの Over-Reach failure mode に該当 |
| 停止条件（kill/slowdown） | ⚠️ | 開始拒否条件 ✅ だが LOOP.md（`token_daily_budget` / `pause_at_budget_pct` / kill 基準）なし。コスト逆転検知なし |
| 自律ティア L1/L2/L3 | ⚠️ | 固定の L2 形状。レポートのみ（L1）モードなし、ティア枠組みなし |
| スケジュール（Automations） | ❌ | 手動起動のみ（v2 に意図的除外。pilot-before-scale として妥当） |
| Multi-loop 協調 | ⚠️ | flock = 1 loop/repo（ブランチ排他所有より強い）。`acting_on` なし、予算合算なし（単一ループでは無意味） |

### メタループ

| 概念 | 状態 | 備考 |
|---|---|---|
| 証跡駆動の更新 | ✅ | runs/・cost-log・known-failures・decisions-log。task-002/003/004 は実行証跡（reviewer 指摘）から生成 |
| version 永続化 | ✅ | ループの変更はループ自身のコミットで develop へ（git 履歴で確認） |
| optimizer/evaluator 分離 | ✅ | worker+planner が提案、reviewer（fresh model）+ 人間ゲートが決定。人間 = 採否規則 V |
| harness 変更の回帰テスト | ✅ | DONE flag 修正を fake-pi stub で回帰テスト（真の候補 vs 現行版検証） |
| **五つの固定点** | ⚠️ | 変更範囲（Non-negotiables）✅ / 固定条件（model routing）✅ / 保存する状態（memory/）✅ / **評価指標 ❌** / **採否規則 ❌**（ゲートは場当たりの人間判断、事前定義なし） |
| 4 軸監視 | ⚠️ | token-per-task 部分（run summary）✅ / iterations ✅（loop.log）/ **成功率・false positive ❌**（review-fail は記録されるが集計・閾値なし）/ context 利用率 n/a |

## 8. 提案（優先度順）

### P0 — 構造的安全（最小コスト・最大効果）

**P0-1: per-repo `DENYLIST` ファイル + verify_repo での構造的強制**

`VERIFIERS` と同型の `DENYLIST` を target repo に置き、implement 後に `git diff --name-only` が拒否パスに触れていれば REJECT する。ソフトな「無関係なリファクタ禁止」指示を構造的判定に変える。

```bash
# 実装イメージ（verify_repo に追加）
if [[ -f "$repo/DENYLIST" ]]; then
  local denied
  denied="$(cd "$repo" && git diff --name-only | grep -Ef <(grep -v '^#' "$repo/DENYLIST") || true)"
  if [[ -n "$denied" ]]; then
    log "DENYLIST violation: $denied"
    return 1
  fi
fi
```

`DENYLIST` 例（target repo 側）:

```
# 自動変更禁止パス（agent-loop 用）
agent/auth.json
**/.env
**/credentials*
**/secrets*
**/intercom/**
providers/*/config.json   # 必要なら
```

**P0-2: per-stage の壁時計キャップ有効化（または worker へのターン予算付与）**

`STAGE_TIMEOUT_S` は配線済み（既定 0 = 無効）。既定値を設定するか（例: 900s）、`pi -p` にターン予算を渡す。task-004 の 1.16M token 実装呼び出しは Token Explosion failure mode の縮図。

```bash
STAGE_TIMEOUT_S="${STAGE_TIMEOUT_S:-900}"   # 既定値を有効化
```

### P1 — 予算と停止条件

**P1-1: コストガード（`MAX_RUN_COST_USD`）**

`RUN_TOTAL_COST` アキュムレータは既存。`pi_call` の記録後に超過チェックを追加（約 15 行）。

```bash
MAX_RUN_COST_USD="${MAX_RUN_COST_USD:-2.0}"
# record_usage_line の最後に:
if (( $(awk -v a="$RUN_TOTAL_COST" -v m="$MAX_RUN_COST_USD" 'BEGIN{print (a>m)}') )); then
  die "run cost $RUN_TOTAL_COST exceeds MAX_RUN_COST_USD=$MAX_RUN_COST_USD — stop and ask"
fi
```

**P1-2: `LOOP.md` の作成（停止条件の正本）**

ガイドの停止条件ブロックをループディレクトリに置く（現在は DESIGN.md/QUESTIONS.md に散在）:

```markdown
## 停止条件
- max_run_cost_usd: 2.0          # P1-1 と連動
- pause_at_cost_pct: 80          # 予算 80% 到達で一時停止検討
- max_cycles: 3                  # 実装済み
- max_escalations: 2             # 実装済み
- kill_on_review_fail_streak: 3  # 連続 review FAIL で kill
- kill_on_cost_inversion_runs: 3 # コスト対価値比が逆転した連続 run 数

## 人手インボックス
- escalation_channel: herdr pane（ゲート待ち通知）
```

### P2 — メタループの厳密化

**P2-1: 評価指標 + 採否規則の形式化（五つの固定点の残り 2 点）**

ループ自身（harness）を変更する task ファイルに、採否規則を明記する。タスクテンプレートに追加:

```markdown
## 採否規則（harness 変更の受け入れ条件）
- VERIFIERS 全チェック通過
- reviewer 判定 PASS（または指摘全件が次 cycle で解消）
- コスト ≤ 前回同種 task の 2 倍（cost-log ベースライン比）
- 既知 failure mode カテゴリの新規追加なし
- （該当時）fake-pi stub 等による回帰テスト通過
```

これでゲートが「場当たりの人間判断」から「事前定義された採否規則の執行」になり、ガイドの条件 3（evaluator 分離 + 事前決定規則）を満たす。

**P2-2: false positive 率の追跡（Verifier Theater 指標）**

- review PASS → その後の verify FAIL（同 cycle 内は無理だが、マージ後の VERIFIERS 失敗）を known-failures に記録
- 記録形式: `verifier-theater run=<id> review=PASS verify=FAIL-after-merge`
- 閾値: 30% 超で当該ループの review プロンプト見直し（ガイドの警戒閾値）

**P2-3: 成功 run 後の worktree 自動クリーンアップ**

現在は成功後も worktree が残り手動削除の案内のみ。commit 後に worktree を自動削除（branch は保持）:

```bash
# GATE-2 approve パスの commit 後:
( cd "$MAIN_REPO" && git worktree remove --force "$WT_DIR" ) || true
```

### v2 候補（ガイド準拠・意図的除外の継続）

- スケジューリング（cron / GitHub Actions。CI Sweeper は `workflow_run` 失敗トリガー）
- L1 レポート専用モード（`--report-only`）
- 自律ティア枠組み（パターンごとに L1 → L2 → L3 を段階適用）
- `acting_on` フィールドによる Multi-loop 衝突検出（複数ループ運用時に）
- 予算合算管理（複数ループ時）

## 9. 提案の根拠（ガイド参照箇所）

| 提案 | 根拠 |
|---|---|
| P0-1 DENYLIST | ガイド §3.7 Denylist/MCP スコープ制約、§3.8 Over-Reach failure mode、「denylist は全ループで共有」 |
| P0-2 ターン/時間予算 | §2.2 「予算設定は本番エージェントの良いデフォルト」、§3.8 Token Explosion |
| P1-1 コストガード | §3.7 Token 予算管理（日次上限 + 80% 一時停止）、§3.8 コスト暴走 |
| P1-2 LOOP.md | §3.6 停止 3 段階、「停止基準は LOOP.md に明記」「停止条件を First-Class に」 |
| P2-1 採否規則 | §4.2 三条件（特に条件 3）、§4.5 五つの固定点（評価指標・採否規則） |
| P2-2 false positive 追跡 | §3.6 監視 4 軸（成功率）、§3.8 Verifier Theater |
| P2-3 worktree クリーンアップ | §3.3 Worktree.lifecycle（1 実験ごと生成・検証 REJECT で破棄、タスク完了後に削除） |

## 10. 参考リンク

- [Claude Agent SDK: エージェントループの仕組み](https://code.claude.com/docs/ja/agent-sdk/agent-loop)
- [Loop Engineering 入門（諏訪真一 / Zenn）](https://zenn.dev/suwash/articles/loop-engineering_20260610)
- [Harness Optimization 概要（岩瀬）](https://notes.iwase.dev/ja/harness-optimization/overview)
- 統合ノート: `~/.pi/merged-agent-loop-docs.md`
- 実装: `~/.pi/agent-loop-v1/`（loop.sh / DESIGN.md / QUESTIONS.md / memory/）
