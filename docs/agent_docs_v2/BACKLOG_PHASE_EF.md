# Phase E/F backlog — 外部スキル取込と他プロジェクト汎化(必要事項リスト)

- 作成: 2026-08-10
- 位置づけ: BACKLOG.md(Phase D)と同格のブリーフ集。ゴール拡張に伴い
  v2 計画に**不足しているもの**を洗い出したリスト。タスク化は TASK_TEMPLATE
  に従いプランナー agent が行う(Phase E = task-3XX、Phase F = task-4XX)。
- ゴール階層(拡張後):
  1. Phase A〜C: ループ自体の安全装置・予算・計測(既存計画)
  2. Phase D: `~/.pi` の自己更新ループ(既存計画)
  3. **Phase E: 外部スキル/プロンプトの評価・つまみ食い取込**(本書)
  4. **Phase F: 他プロジェクトへの適用**(本書。`/data/dotfiles3` がパイロット)
- 前提: Phase E/F とも Phase A〜C 完了が着手条件。特に DENYLIST(101)と
  コスト/トークンガード(103)は**他リポジトリへ書き込む前の必須安全装置**。
  Phase D と E は並行可(独立)。F は E の最初の取込 1 件と D の report-only
  (task-201)完了後(pilot-before-scale)。

## 0. 既存文書への反映(タスク化不要、オーケストレータ作業)

- [ ] README.md: ロードマップ表に Phase E/F 行を追加、使い方表に本書を追記
- [ ] DESIGN.md: 最終目標の記述を「`~/.pi` 自己更新」から「自己更新 →
      スキル基盤 → 他プロジェクト適用」の 3 段に拡張(§1 差分表にも行追加)
- [ ] TASK_TEMPLATE.md Drafting rules 4: 番号帯に 3XX(Phase E)/
      4XX(Phase F)を追記

## Phase E — 外部スキル/プロンプトの取込基盤

### task-301: スキルソース台帳(SKILL_SOURCES.md)

- `docs/references/SOURCES.md` の慣行に合わせ、取込候補コーパスの台帳を作る:
  - ECC(`~/.config/claude` 配下のルール群 + ecc プラグイン)
  - superpowers(brainstorming / systematic-debugging / writing-plans 等)
  - addyosmani/agent-skills(24 skills、ライフサイクル網羅型)
  - mattpocock/skills(失敗モード対策型、user-invoked / model-invoked 二層)
  - my-take-dev/inspired-mino-design-skills(上流設計特化、v0.9 実験段階)
  - `docs/references/classified_v1/` の agent-skills / loop-engineering 記事群
- 各ソースに記録: 形式(SKILL.md / plugin / rules)、license、成熟度、
  既存 v1 原則(BFV・決定的検証・HITL)との重複領域。
- 重複の予備判定を含める: TDD・検証・レビュー系は v1 が既に持つため
  **取込対象は「持っていない層」に絞る**(例: mino の上流設計、mattpocock の
  /grill-me 系要件尋問、addyosmani の anti-rationalization 表現)。

### task-302: 採用ルーブリック(skill intake の Acceptance rules)

- 「つまみ食い」を場当たりにしないための事前決定規則。候補スキル 1 件ごとに:
  1. 非重複: 既存の loop.sh / タスク契約 / memory 慣行でカバー済みでないこと
  2. 検証可能性: 効果が決定的チェックか人間ゲートの判断材料に落ちること
  3. 移植コスト: pi harness で動く形に <1 タスクで変換できること
  4. license 適合と provenance 記録が可能なこと
- 判定結果は `memory/decisions-log.md` に adopt / reject / defer で記録。
- 成果物: TASK_TEMPLATE の変種「評価タスクテンプレート」(diff でなく
  判定文書が成果物になるタスクの Completion condition / verify の書き方)。

### task-303: 移植規約と置き場所("Author once, adapt per harness")

- Claude Code SKILL.md / ECC rules → pi 用プロンプト・契約への変換規則:
  - 置き場所(例: `~/.pi/skills/<name>/`)、命名規約
  - provenance ヘッダ必須(出典 URL・取得 commit・license・改変概要)
  - pi に存在しない機構(Skill ツール、hooks)への依存の除去方法
- 構造 lint(ヘッダ存在・必須節)を VERIFIERS に足せる形で定義。
- 参照: classified_v1/agent-skills の @hirokaji_ 記事(cross-harness 標準化)。

### task-304: 最初のつまみ食い 1 件(パイロット取込)

- task-302 のルーブリックを 1 件の実スキルに適用し、task-303 の規約で移植
  して loop の run で使ってみる(report-only で可)。
- 候補(302 で正式判定): mattpocock の grill 系(契約起草の質問攻め)は
  loop の contract ステージと相性がよい。mino の problem-framing も
  タスク起草(GATE-0 前段)に適合。
- 効果測定は数値化を求めない(YAGNI): decisions-log に採用理由と
  観察を残す運用から始め、metrics.py 連携は効果が疑わしくなってから。

## Phase F — 他プロジェクト適用(dotfiles3 パイロット)

### task-401: リポジトリプロファイル形式 + dotfiles3 プロファイル

- 対象リポジトリごとの前提を 1 ファイルに固定する形式を定義
  (例: `docs/agent_docs_v2/repos/<name>.md`):
  - 対象パス / DENYLIST(repo 固有。secrets・鍵・履歴系は既定 deny)
  - VERIFIERS の所在と実行方法(なければ「作るところから」がタスクになる)
  - ブランチ規約、merge 権限(人間)、予算上限(LOOP.md の repo 版)
- 最初の具体例として `/data/dotfiles3` のプロファイルを書く。
- 確認事項: loop.sh `--repo` の多リポジトリ動作(memory/ の run 記録に
  repo 識別が残るか、locks が repo 単位か)を文書化し、欠けていれば
  別タスクに切る。

### task-402: 成果物別の受け入れ条件カタログ

- 他プロジェクトで作る成果物は diff の性質が違うため、種類ごとに
  Acceptance rules の既定セットを定義:
  - `AGENTS.md` / `AGENT.md` / CLAUDE.md: 構造 lint + 対象 harness での
    dry-run(report-only で実タスクに使わせて観察)
  - harness 設定(hooks / permissions): 既存動作の回帰テスト
  - Containerfile 等のプログラム: `podman build`(または repo の build
    コマンド)成功を verifier にする
- スキル選択ロジックの初期形: タスク種別 → 注入するスキル(Phase E の
  取込済みセットから)の対応表。最初は人間が選ぶ。自動選択は
  report-only の提案(task-206 相当)に載せてから。

### task-403: dotfiles3 パイロット run(report-only → L2)

- 手順: ① report-only(201 の機構)で dotfiles3 の AGENTS.md / harness /
  Containerfile の改善提案レポートを生成 → ② 人間が 1 件をタスク承認
  (GATE-0)→ ③ 通常の L2 ループで実行 → ④ 結果と教訓を known-failures /
  decisions-log に記録。
- ここまでで「pi loop が外部リポジトリを安全に改善できる」ことの実証が完了。
  2 例目以降のリポジトリは task-401 のプロファイル追加だけで回るのが合格線。

### task-404: 汎化の文書化(他プロジェクトへの展開手順)

- 403 の教訓を反映し、「新しいプロジェクトに loop を適用する手順」を
  1 枚の運用文書にする(プロファイル作成 → VERIFIERS 確認 → report-only →
  承認 → L2)。README のロードマップ完了条件に相当。

## 方針決定が必要な事項(Stop-and-ask、着手前に人間が決める)

1. **ECC / superpowers の改変方式**: 両者は `~/.claude` 配下の外部管理
   プラグイン。選択肢は (a) pi 側へ抽出・再構成(既定候補。上流は触らない)、
   (b) fork して vendored copy、(c) 上流へ PR。Phase E は (a) 前提で書いて
   あるが、確定は人間判断。
2. **skills の置き場所**: `~/.pi/skills/` を新設するか、既存 `agent/` /
   `providers/` 配下に置くか。
3. **dotfiles3 の DENYLIST 初期値**: dotfiles には秘匿情報が混じりやすい。
   プロファイル起草時に人間がレビューする。

## 意図的に除外(v2 では やらない)

- スキルの自動取込(クロール・自動評価)— 台帳とルーブリックは人間ゲート付き
- 複数プロジェクト同時 run(Multi-loop 協調の除外を継続)
- スキル効果の定量 A/B 測定 — decisions-log の定性記録で始める
- 3 リポジトリ(addyosmani 等)の全量取込 — つまみ食いのみ
