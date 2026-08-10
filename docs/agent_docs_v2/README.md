# agent_docs_v2 — agent-loop v1 → v2 実行計画

- 作成: 2026-08-10
- 正本(提案元): `~/.pi/suggest_v1.md`(三記事統合 + P0/P1/P2 ギャップ提案)
- 本ディレクトリ = その提案を**実行可能なタスク群**に落とした計画。設計判断と
  suggest_v1 からの変更点は `DESIGN.md` に記載。
- 最終目標: **`~/.pi`(および pi/herdr 等のツール)が、人間を要所ゲートに残した
  まま自分自身を更新できる状態**にする(Phase D)。2026-08-10 にゴール拡張:
  Phase E(外部スキル取込基盤)/ Phase F(他プロジェクト適用)を追加
  (`BACKLOG_PHASE_EF.md`)。

## このディレクトリの使い方

| ファイル | 対象読者 | 内容 |
|---|---|---|
| `README.md`(本書) | 人間 / オーケストレータ | 索引・ロードマップ・実行プロトコル |
| `DESIGN.md` | 人間 / プランナー | v2 設計、suggest_v1 との差分と根拠 |
| `TASK_TEMPLATE.md` | タスク起草者(人間 or プランナー agent) | v2 タスクの必須構造(採否規則を含む) |
| `tasks/task-1XX-*.md` | worker / reviewer モデル | loop.sh がそのまま読む契約形式タスク(英語) |
| `BACKLOG.md` | プランナー agent | Phase D のブリーフ。TASK_TEMPLATE に従い task-2XX に展開する |
| `BACKLOG_PHASE_EF.md` | プランナー agent | Phase E/F のブリーフ。task-3XX / task-4XX に展開する |

言語規約: 人間向けドキュメントは日本語、モデルが直接消費するタスクファイルと
テンプレートは英語(v1 の task-001..004 と同じ)。

## ロードマップ

| Phase | 内容 | タスク | suggest_v1 対応 |
|---|---|---|---|
| **A: 構造的安全** | denylist 強制・ステージタイムアウト | task-101, task-102 | P0-1, P0-2 |
| **B: 予算と停止** | コスト/トークンガード・LOOP.md(停止条件の正本) | task-103, task-104 | P1-1, P1-2 |
| **C: メタループ厳密化** | 集計器・worktree 掃除(採否規則はテンプレートに組込済) | task-105, task-106 | P2-1〜P2-3 |
| **D: 自律化(v2 本体)** | report-only モード → systemd timer → ティア → 自己更新ループ | BACKLOG(task-2XX) | §8 v2 候補 |
| **E: スキル取込** | 外部スキル/プロンプトの台帳・採用ルーブリック・移植規約・パイロット取込 | BACKLOG_PHASE_EF(task-3XX) | —(ゴール拡張 2026-08-10) |
| **F: 他プロジェクト適用** | repo プロファイル・成果物別受入条件・dotfiles3 パイロット・汎化手順 | BACKLOG_PHASE_EF(task-4XX) | —(ゴール拡張 2026-08-10) |

順序: **101 → 102 → 103 → 104 → 105 → 106**。
104 は 102/103 の実装値を文書化するため後。106 は 101 以降ならいつでも可。
Phase D は Phase A〜C 完了かつ 105 の指標で成功率を確認してから着手する
(pilot-before-scale)。
Phase E は Phase A〜C 完了後、Phase D と並行可。Phase F は Phase E の
パイロット取込(task-304)と task-201(report-only)完了後
(前提の詳細: `BACKLOG_PHASE_EF.md` 冒頭)。

## タスク索引と状態

状態はループブランチを develop にマージした後、**オーケストレータ(または人間)が
この表を更新する**。worker の diff に状態更新を含めない(1 タスク 1 機能の原則)。

| タスク | 内容 | 状態 |
|---|---|---|
| [task-101](tasks/task-101-denylist.md) | DENYLIST の構造的強制(verify_repo) | 未着手 |
| [task-102](tasks/task-102-stage-timeout.md) | STAGE_TIMEOUT_S 既定 900s 有効化 | 未着手 |
| [task-103](tasks/task-103-cost-guard.md) | コスト/トークンガード(80% 警告 + 超過 abort) | 未着手 |
| [task-104](tasks/task-104-loop-md.md) | LOOP.md 停止条件チャーター + 同期チェック | 未着手 |
| [task-105](tasks/task-105-metrics.md) | metrics.py(run 集計・成功率・コスト比較) | 未着手 |
| [task-106](tasks/task-106-worktree-cleanup.md) | 成功時の worktree 自動クリーンアップ | 未着手 |
| task-2XX | Phase D(BACKLOG.md のブリーフから展開) | 未起草 |
| task-3XX | Phase E(BACKLOG_PHASE_EF.md のブリーフから展開) | 未起草 |
| task-4XX | Phase F(BACKLOG_PHASE_EF.md のブリーフから展開) | 未起草 |

## 実行プロトコル(サブエージェント向け)

### 第一経路: agent-loop-v1 自身で実行する(推奨・dogfooding)

harness の変更を harness 自身のループで行う。task-001..004 で実証済みの経路。

```bash
# herdr pane 内、~/.pi は develop ブランチで clean な状態で:
cd /home/kiyama/.pi
./agent-loop-v1/loop.sh --repo /home/kiyama/.pi \
  --task-file docs/agent_docs_v2/tasks/task-101-denylist.md
# GATE-1(plan)と GATE-2(apply)は人間が応答する
# 成功後: loop/<run-id> ブランチを develop に手動マージ
```

### 第二経路: サブエージェント(sonnet / deepseek 等)が直接実行する

loop.sh を使わない場合でも、タスクファイルは自己完結の契約として読める。
その場合は次を厳守する:

1. `Completion condition` を唯一の完了定義とする(BFV Kernel: 省いても完了を
   証明できる変更は入れない)
2. `Non-negotiables` / `Out of scope` / `Stop-and-ask` に必ず従う。曖昧さは
   推測せず停止して人間に聞く
3. 実装後、リポジトリの `VERIFIERS` 全行とタスク内の regression test を実行し、
   結果を報告する(実行せずに PASS を主張しない)
4. `Acceptance rules` の各項目を自己チェックし、判定は人間ゲートに委ねる
   (自己承認しない)
5. コミットは loop ブランチ(`loop/<id>` 相当)にのみ行い、`main` には触れない。
   merge/push はしない

### 完了後の記録

- 各タスクの教訓(レビュー指摘・バグ・回帰テスト)は v1 の慣行どおり
  `agent-loop-v1/DESIGN.md` の実装履歴表と `QUESTIONS.md` に追記する
- 本 README の状態表を更新する(オーケストレータ)

## 参照

- `~/.pi/suggest_v1.md` — 提案の正本(P0/P1/P2 の根拠と本文)
- `~/.pi/agent-loop-v1/DESIGN.md` — v1 設計と実装履歴(task-001..004)
- `~/.pi/agent-loop-v1/README.md` — v1 運用手順・telemetry 仕様
- `~/.pi/docs/agents_docs_v1/` — 元コーパス(loop/contract/verification)
- `~/.pi/merged-agent-loop-docs.md` — 三記事統合ノート
