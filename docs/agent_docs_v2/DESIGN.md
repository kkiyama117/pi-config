# agent-loop v2 — 設計(suggest_v1 の実行計画化と修正点)

- 作成: 2026-08-10
- 前提: `~/.pi/suggest_v1.md` Part 2(P0/P1/P2 提案)を採用する。本書は
  「何をどの順で、どこを直して」実行するかを確定し、提案のうち**そのまま
  実装すると壊れる箇所の修正**と**運用に必要な追加**を記録する。
- v1 の設計原則(HITL・BFV 契約・決定的検証優先・有界サイクル・filesystem
  memory)は変更しない。v2 はその上に「構造的制限・予算・指標・自律化の段階」
  を足す。

## 1. v1 → v2 の差分サマリ

| 領域 | v1(現状) | v2(本計画) |
|---|---|---|
| パス制限 | ソフトな指示文(Non-negotiables)のみ | `DENYLIST`(ERE)を verify_repo で構造強制(task-101) |
| ステージ時間 | `STAGE_TIMEOUT_S=0`(無効) | 既定 900s + timeout(124)の識別ログ(task-102) |
| 予算 | 記録のみ、ガードなし | コスト + トークンの二重ガード、80% 警告 / 超過 abort(task-103) |
| 停止条件 | DESIGN/QUESTIONS に散在 | `LOOP.md` に集約 + loop.sh 既定値との同期チェック(task-104) |
| 評価指標 | cost-log 等の生ログのみ | `metrics.py` で run 集計・成功率・コスト比較(task-105) |
| 採否規則 | ゲートは場当たりの人間判断 | **全タスクに Acceptance rules 節**(TASK_TEMPLATE で必須化) |
| worktree | 成功後も残置(手動削除) | commit 後に自動 remove、branch は保持(task-106) |
| 自律ティア | 固定 L2 形状 | L1 report-only → スケジュール → ティア枠組み → 自己更新(Phase D) |

## 2. suggest_v1 からの変更点(better way)と根拠

実装指示は各タスクファイルが正本。ここには**なぜ提案どおりにしないか**だけを書く。

### 2.1 P2-1(採否規則)は Phase C ではなく初日に — TASK_TEMPLATE へ組込

suggest_v1 は採否規則の形式化を P2(最後)に置くが、採否規則は「これから行う
全 harness 変更の受け入れ条件」なので、**最初のタスク(task-101)から適用しないと
Phase A/B 自体が場当たりゲートで進む**ことになる。よって独立タスクにせず、
`TASK_TEMPLATE.md` の必須節にした。これで Harness Optimization の条件 3
(evaluator 分離 + 事前決定規則)は v2 の全タスクで最初から満たされる。

### 2.2 P0-1(DENYLIST)の実装例には 2 つの欠陥がある

suggest_v1 §8 のスニペットをそのまま実装してはならない(task-101 に修正済み仕様):

1. **未追跡ファイルの見落とし**: worker は commit しない設計なので、新規作成
   ファイルは常に untracked。`git diff --name-only` は untracked を含まないため、
   `agent/auth.json` の変更は捕まえても `agent/auth.json.bak` の新規作成は素通り
   する。検出は `git status --porcelain`(untracked 含む)ベースにする。
2. **パターン文法の混在**: 例示の `**/.env` は glob だが、判定は `grep -Ef`
   (POSIX ERE)。glob をそのまま ERE として食わせると意図と違うマッチになる。
   DENYLIST は「1 行 1 ERE、repo 相対パスに対して照合」と文法を固定し、
   ファイル先頭コメントに文法を明記する。

### 2.3 P1-1(コストガード)にはトークン上限を併設する

実測(QUESTIONS.md「Observed costs」)で cursor 系モデルはコスト 0 を報告する。
コストのみのガードは cursor 主体の run(escalation 後は worker=gpt-5.6)で
無力化する。よって `MAX_RUN_COST_USD` に加えて `MAX_RUN_TOKENS` を同じ機構で
併設する(task-004 の 1.16M トークン事例は token 側でしか捕まらない)。
また die 一発ではなく **80% で一度だけ警告 + notify、超過で abort** とし、
Loop Engineering の Slow Down / Pause / Kill 3 段階に対応させる。

### 2.4 LOOP.md は「正本」だが実装は環境変数のまま(パーサを書かない)

停止条件の値を LOOP.md からパースして loop.sh に注入する案は却下(YAGNI +
パーサ自体が新たな故障点)。実装値は loop.sh の環境変数既定のまま、LOOP.md は
値を文書化する正本とし、**両者の一致を決定的チェック(テストスクリプト)で
強制する**(task-104)。乖離したら verify が落ちる。

### 2.5 P2-2(false positive 率)は「集計器が先」

記録形式(`verifier-theater run=<id> ...`)を決めても、集計・閾値判定の道具が
なければ 30% 閾値は運用できない。また採否規則の「コスト ≤ 前回同種 task の
2 倍」も比較器がないと機械判定できない。よって `metrics.py`(task-105)を
Phase C の中心に置き、verifier-theater イベントの**記録側**(マージ後の
VERIFIERS 失敗を拾うフック)は Phase D(task-204)に送る。記録が始まる前に
報告側を用意しておく順序が正しい(集計器は空入力で 0 件と報告するだけ)。

### 2.6 スケジューラは GitHub Actions ではなく systemd user timer を第一候補に

対象はローカルの `~/.pi` と Manjaro 上のツール群で、実行主体はこのマシンの
`pi` CLI。GitHub Actions を第一候補にすると secrets・self-hosted runner・
リポジトリ公開範囲の問題を先に解くことになる。Phase D では
`systemd --user` timer(+ 失敗時 herdr notification)を第一候補、
GitHub Actions は pi-config をリモートで回す将来の選択肢として残す(task-202)。

### 2.7 その他の採用判断

- P0-2 の既定値 900s は採用。`timeout 0` = 無効という coreutils の意味論が
  現行コードの `timeout "$STAGE_TIMEOUT_S"` と整合するので、既定値の変更だけで
  済む(task-102)。timeout 発火(exit 124)は他の失敗と区別してログする。
- P2-3(worktree 掃除)は採用。ただし rollback 経路(既存の remove)と dry-run
  挙動は変更しない(task-106)。
- Multi-loop 協調(`acting_on`・予算合算)は suggest_v1 同様、複数ループ運用が
  始まるまで**意図的に除外**を継続。

## 3. Phase D — 自己更新ループの形(設計スケッチ)

最終目標「`~/.pi` が自分で自分を更新する」の v2 での到達形。詳細ブリーフは
`BACKLOG.md`、タスク化は TASK_TEMPLATE に従いプランナー agent が行う。

```
[systemd user timer(task-202)]
   → loop.sh --report-only(task-201: L1 = 計画と診断のみ、書込なし)
       入力: metrics.py サマリ(task-105)+ known-failures + 週次ダイジェスト(task-205)
       出力: 「次にやるべき harness 改善」のドラフト task ファイル(task-206)
   → 人間: ドラフト task を承認(= GATE-0。自己更新の唯一の新規ゲート)
   → 承認済み task を通常の L2 ループ(GATE-1/GATE-2 付き)で実行
   → merge 後: verifier-theater フック(task-204)が事後失敗を記録
   → metrics.py が成功率 / false positive / コストを更新 → 次周期の入力へ
```

- 自律ティアの扱い(task-203): 新パターンは必ず L1(report-only)から。
  L2 昇格は「L1 で false positive < 30% を 2 週間」、L3 は v2 でも導入しない
  (suggest_v1 §3.7「L3 は目標でなく条件が揃ったときの選択肢」)。
- 降格は即時: 2 週連続 revert または review-fail streak ≥ 3 で L1 へ戻す。
  基準は LOOP.md(task-104)に置く。

## 4. 五つの固定点(Harness Optimization)の v2 での充足

| 固定点 | v1 | v2 での担い手 |
|---|---|---|
| 変更範囲 | Non-negotiables(ソフト) | DENYLIST(task-101)+ Non-negotiables |
| 固定条件 | model routing | 同左 + STAGE_TIMEOUT_S / 予算(task-102/103) |
| 保存する状態 | memory/ | 同左 + LOOP.md(task-104) |
| 評価指標 | ❌ | metrics.py(task-105): 成功率・コスト・fail 率 |
| 採否規則 | ❌(場当たり) | TASK_TEMPLATE の Acceptance rules(全タスク) |

## 5. リスクと停止

- 本計画のタスクはすべて loop.sh / verify_repo / memory 周りの小 diff。
  各タスクに regression test(fake-pi stub / 一時 git repo)を必須化しており、
  マージ判断は VERIFIERS + Acceptance rules + 人間ゲートの三重。
- Phase A〜C の間、自律性は一切上げない(手動起動・2 ゲートのまま)。
  自律性を上げる変更(Phase D)は 1 タスク 1 段階でしか行わない。
- 計画自体の中止基準: Phase A〜C の実行で review-fail streak ≥ 3 の task が
  2 つ出たら、タスク粒度と worker モデル選定を見直すため一旦停止して人間へ。
