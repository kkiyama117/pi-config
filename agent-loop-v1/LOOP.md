# LOOP.md — agent-loop stop-conditions charter (task-104)

単一正本としての停止条件。実装値は `loop.sh` の環境変数既定にあり、本ファイルは
それを文書化する(loop.sh は LOOP.md をパースしない — DESIGN.md §2.4)。

**Values mirror loop.sh env defaults; the sync check below fails if they
drift.** 同期チェック: `tests/test_loop_md_sync.sh`(VERIFIERS 経由で毎 run 実行)。

## Budget (task-102, task-103)

```
stage_timeout_s: 900
max_run_cost_usd: 2.0
max_run_tokens: 3000000
budget_warn_pct: 80
```

- `stage_timeout_s` = `STAGE_TIMEOUT_S`。0 = 無効(coreutils `timeout 0` の意味論)。
- `max_run_cost_usd` / `max_run_tokens` = `MAX_RUN_COST_USD` / `MAX_RUN_TOKENS`。
  0 = 無効。cursor 系モデルは cost 0 を報告するため token 側が実質の後ろ盾。
- `budget_warn_pct` = `BUDGET_WARN_PCT`。種類ごとに 1 回だけ警告 + herdr notify、
  100% 到達で abort(`run budget exceeded: ... — stop and ask`)。abort 時も
  EXIT trap の cost summary は出力される。

## Cycles (v1 決定 Q11 / DESIGN.md)

```
max_cycles: 3
max_escalations: 2
```

- `max_cycles` = `MAX_CYCLES`。満了時は強制 human escalation(`die`)。成功
  commit 済みの run は DONE フラグで区別される(task-003 教訓)。
- `max_escalations` = `MAX_ESCALATIONS`。verify/review 失敗で worker を強化
  (normal → thinking)、共有キャップ。

## Kill criteria (human-executed, documented not automated)

```
kill_on_review_fail_streak: 3
kill_on_cost_inversion_runs: 3
```

- `kill_on_review_fail_streak: 3` — 同一タスクファイルでレビュー失敗が 3 連続したら
  タスクファイルを中断・再設計する(人間が実行。自動化しない)。
- `kill_on_cost_inversion_runs: 3` — 変更の価値を超えるコストの run が 3 連続したら
  停止する(人間の判断。decisions-log.md に記録)。
- 自動化は Phase D(metrics.py の消費者、task-2XX)で行う。

## Refusal-to-start conditions (stage_contract_check の現行動作)

- 対象リポジトリが dirty(`git status --porcelain` が空でない)
- ベースライン検証が失敗する(verify_repo が非ゼロ終了 = 赤いツリー)
- 完了条件 / タスク記述が欠けている
- 現在のブランチが `main` / `master`(保護ブランチ)

## Escalation channel

- ゲート待ちと予算警告は herdr pane + `herdr notification show`(notify)。
  ゲートは人間の応答を無期限に待つ(v1 決定 Q6)。

## Sync check (regression test)

- `tests/test_loop_md_sync.sh` は上記 6 キー(max_cycles, max_escalations,
  stage_timeout_s, max_run_cost_usd, max_run_tokens, budget_warn_pct)の
  loop.sh 既定値と本ファイルの値を照合し、乖離時にキー名を添えて非ゼロ終了。
- 両方向の乖離(loop.sh のみ変更 / LOOP.md のみ変更)を自己テストする。
