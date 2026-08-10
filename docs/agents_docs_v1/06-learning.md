# 06 — Learning (self-improving agents)

Closing the loop at the model level: training agents inside their own harnesses
(TRL + OpenEnv), the theory of self-improvement (base-model vs scaffold
improvement, Gödel Machine lineage), and verifier-free auto-research.

## 2080661125822030164 — @ben_burtenshaw
- url: https://x.com/i/status/2080661125822030164
- posted_at: Fri Jul 24 14:27:23 +0000 2026
- kind: tweet

> You can now train agents in TRL + OpenEnv with a harness of your choice. i.e. open code, pi, codex, claude code. 
>
> This means you can improve the model in the context it is used; it's agent harness. It will learn to use the correct tools for the task, just as codex or claude code are trained.
>
> This is the process
> - take a datasets of tasks.
> - take a harness like open code which will drive the session.
> - take an openenv environment and harness adapter
> - use TRL HarnessRolloutWorker to collect the agent's traces
> - use AsyncGRPOTrainer to orchestrate inference and updating weights verifier returns env_reward

## 2082037302272909647 — @itarutomy
- url: https://x.com/i/status/2082037302272909647
- posted_at: Tue Jul 28 09:35:49 +0000 2026
- kind: tweet

> 「自己改善するAIエージェント」の研究を1つの理論で整理したサーベイ論文が出ていた(https://arxiv[.]org/html/2607.13104v1)。
>
> このサーベイは、エージェントを「基盤モデル(θ、モデル本体の重み)」と「scaffold(足場。プロンプト・メモリ・ツール・制御ロジックをまとめた運用の枠組み)」の組み合わせと捉え、自己改善を2種類に整理する。基盤モデル改善はSFT(教師あり微調整)やRL(強化学習)で重みそのものを書き換える方式で、効果は長く安定するが時間もコストもかかる。一方のscaffold改善はプロンプトやメモリ、ツールを直すだけなので速くて元に戻しやすく、破局的忘却(学習済みの内容を新しい学習で上書きして忘れる現象)のリスクもない。自己進化型のコーディングエージェントDarwin Gödel Machine(DGM)は、自ら生んだコーディングエージェントをアーカイブに蓄積しながら多様で質の高い系統の木を広げていく、scaffold改善の代表例だ。
>
> 個人的に面白かったのは安全性の議論。エージェントを評価する「批評役(critic)」は単なる採点者ではなく攻撃対象にもなる、という指摘だ。エージェントは批評役の穴を突いて評価をすり抜ける方向に最適化されがちなので、批評役自身の「突破されにくさ」がエージェントの実力の上限を決めてしまう。だから著者らは、自己改善するエージェントを「保護されたランタイムで動く未検証コード」として扱い、コードやツール権限を書き換える前に必ず検証ゲートを通す設計を提案している。
>
> この発想の源流は、自分のコードを書き換える前に、その変更で将来の成果(期待効用)が本当に上がることを数学的に証明することを求める2003年の「Gödel Machine」(理論上最適な自己改善マシン)まで遡るという整理も興味深い。

## 2082517932714914113 — @james_y_zou
- url: https://x.com/i/status/2082517932714914113
- posted_at: Wed Jul 29 17:25:41 +0000 2026
- kind: tweet

> Auto-research without a verifier🚀
>
> #SqueezeEvolve is accepted to #COLM2026 and now works in Claude Code!
>
> It uses model confidence to guide search and routes work across models to cut cost, enabling more open-ended autoresearch.
>
> 97.5% on ARC-AGI-2 at less than half the cost.
>
> Great job by @sudomonish @Chenfeng_X @togethercompute leading this project! https://arxiv.org/abs/2604.07725

## 2086318763612524762 — @connect24h
- url: https://x.com/i/status/2086318763612524762
- posted_at: Sun Aug 09 05:08:49 +0000 2026
- kind: tweet

> これは相当熱い。自己改善型のcoding Agentが、長時間タスクの景色を変えにきた。
>
> PrimeIntellect-aiのprime-agentは、coding workflowとlong-running autonomous task向けのself-improving RLM agent。TypeScript製でGitHub 9,020★、この24時間だけで 2,483は伸び方がえぐい。
>
> 長く回すほど人間の細かな介入が増えるAgent運用に、自己改善という軸を持ち込むのが面白い。自分の基盤でも、まず隔離環境の長時間タスクへ入れて挙動を見る。権限と変更範囲を絞らず回している組織は、かなり危ない。#AI駆動開発
> ソース: https://github.com/PrimeIntellect-ai/prime-agent

