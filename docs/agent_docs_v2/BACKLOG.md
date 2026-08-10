# Phase D backlog — briefs for task-2XX (自律化・自己更新)

Phase A〜C 完了後、プランナー agent が本ブリーフを `TASK_TEMPLATE.md` に従い
`tasks/task-2XX-*.md` へ展開する(展開規則は TASK_TEMPLATE.md「Drafting
rules」4-5)。**着手前提**: task-101〜106 マージ済み + `metrics.py summary` で
done rate を確認済み(pilot-before-scale)。設計スケッチは `DESIGN.md` §3。

順序は 201 → 202 → 203/204(並行可)→ 205 → 206。各タスクは自律性を
1 段階しか上げない。

## task-201: `--report-only` モード(L1 の入口)

- `loop.sh --report-only`: contract → plan → 診断レポート生成で終了。
  implement 以降を実行せず、リポジトリへの書込・worktree 作成・commit なし。
- レポートは `memory/runs/<id>/report.md` に保存し、herdr notification で通知。
- 用途: 新しいループパターンは必ずここから始める(suggest_v1 §3.5「新パターン
  は必ず L1 から」)。task-206 の自己更新ドラフトもこのモードで生成する。
- ゲート: GATE-1 のみ(plan の妥当性確認)。GATE-2 は書込がないため不要。

## task-202: systemd user timer によるスケジュール実行

- `systemd --user` の service + timer unit(例: 週 1 回)で
  `loop.sh --report-only` を起動する。**report-only 以外を schedule して
  はならない**(L2 のスケジュール化は task-203 のティア基準を満たすまで禁止)。
- 前提: LOOP.md(task-104)の予算値と DENYLIST(task-101)が有効であること。
- 失敗時(unit failure)は herdr notification で人間へ。無限リトライ禁止
  (`Restart=no`)。
- GitHub Actions 案は採らない理由: DESIGN.md §2.6。将来 pi-config をリモートで
  回す場合の代替として注記だけ残す。

## task-203: 自律ティア枠組み(LOOP.md 拡張)

- LOOP.md に `autonomy_tier: L1|L2` フィールドと昇格・降格基準を追記:
  - L1 → L2 昇格: L1 運用 2 週間 + false positive(metrics.py theater /
    review 指摘の誤り率)< 30%。
  - 降格(即時): 2 週連続 revert、または review-fail streak ≥ 3。
  - L3 は v2 では導入しない(suggest_v1 §3.8 限界の節)。
- ティアは「ループパターンごと」に持つ(将来複数パターンを回すときの単位)。

## task-204: verifier-theater イベントの記録フック

- マージ後に VERIFIERS が落ちた場合(= review PASS だったのに事後失敗)、
  `known-failures.md` へ `verifier-theater run=<id> review=PASS
  verify=FAIL-after-merge` を記録する仕組み。
- 実装候補: develop 側で VERIFIERS を回す軽いスクリプト
  (`tests/post_merge_check.sh`)を人間がマージ直後に叩く運用から始める
  (自動化はその後)。集計・閾値判定は task-105 の `metrics.py theater` が
  既に持っている。
- rate > 30% になったら review プロンプトを見直す(suggest_v1 §3.6)。

## task-205: 週次ダイジェスト(Comprehension Debt 対策)

- `metrics.py summary` + decisions-log + known-failures の直近 1 週間分を
  1 枚の Markdown(`memory/digests/<date>.md`)に集約するスクリプト。
- 内容: 実行した run、コスト合計、review 指摘の要点、教訓、未解決の
  エスカレーション。人間が 5 分で読める分量に制限。
- task-202 の timer から report-only と同周期で生成してよい(読み手は人間)。

## task-206: 自己更新ループ(最終目標の結線)

- 入力: 週次ダイジェスト(205)+ metrics(105)+ known-failures。
- report-only run(201)で「次にやるべき harness 改善」を TASK_TEMPLATE 準拠の
  **ドラフト task ファイル**として `tasks/drafts/` に生成する。
- 人間がドラフトを承認(GATE-0)して `tasks/` へ移動 → 通常の L2 ループ
  (GATE-1/GATE-2 付き)で実行 → マージ後 204 が事後検証を記録 → 次周期へ。
- これで「実行 → 証跡 → 評価 → 候補生成 → 外部評価 → 採否」の
  Harness Optimization ループが `~/.pi` 上で閉じる。人間は GATE-0/1/2 の
  3 点に残る(HITL は維持 — v2 では外さない)。

## 意図的に除外(v2 でもやらない)

- L3(denylist 外 auto-commit)・auto-merge・push の自動化
- Multi-loop 協調(`acting_on`・予算合算)— 複数ループ運用開始まで
- vector memory / 外部 DB — filesystem memory で足りなくなるまで
