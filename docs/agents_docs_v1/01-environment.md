# 01 — Environment (harness & infrastructure)

The execution substrate the agent runs in: managed VMs with parallel execution,
state management, secrets, streaming and network control, plus the harness that
wraps the model with tools, memory and workflows. This is the layer that makes
everything downstream possible — and, per the corpus, the hardest to replicate.

## 2084983059330515216 — @shimabu_it
- url: https://x.com/i/status/2084983059330515216
- posted_at: Wed Aug 05 12:41:13 +0000 2026
- kind: tweet

> これ勘違いしている人が多いが、自分でEC2を立てて、そこでCursorやClaude CodeのCLIを動かすとは次元がまったく違う話だからね
>
> CursorやClaude Code側が用意しているVMで開発するという話だから
>
> 彼らレベルの環境を作れるなら別だけど普通に無理よ。そこらへんのエンジニアでできる次元じゃない。
>
> ・並列で動かせる
> ・エージェントの状態管理がされてる
> ・secrets管理ができる
> ・LLMのアウトプットをストリーミング配信している
> ・ローカルとクラウドを行き来できる
> ・ネットワークのegress設定ができる
> ・マルチリポジトリで動かせる
> ・環境をコードで定義できる
> ・Computer Useがある
> ・スマホアプリもある
>
> パッと挙げただけでこれ。他にも無限にある。
>
> これを1人で開発できるなら、CursorとかAnthropicに入社できるから早く面接に行った方が良い。年収5,000万円いける💰
>
> 次のフロンティアと思って彼らトップエンジニアたちが最新のモデルを無制限に使って作っているものですからね。そう簡単に作れるわけがない。

## 2081355365481075098 — @laiso
- url: https://x.com/i/status/2081355365481075098
- posted_at: Sun Jul 26 12:26:03 +0000 2026
- kind: tweet

> https://fukabori.fm/episode/138
> エージェント内部ハーネスと外部ハーネスに分けた説明が画期的

## 2084286415404458414 — @micahomnd
- url: https://x.com/i/status/2084286415404458414
- posted_at: Mon Aug 03 14:33:00 +0000 2026
- kind: tweet

> Lilian Weng  @ OpenAI on Harness Engineering
>
> a deep breakdown of harness design patterns,  workflow automation, persistent memory via file systems, and how modern agents like claude code actually work. the best blog post I've read all month.
>
> link: https://lilianweng.github.io/posts/2026-07-04-harness/

## 2082340541015154808 — @blackanger
- url: https://x.com/i/status/2082340541015154808
- posted_at: Wed Jul 29 05:40:47 +0000 2026
- kind: tweet

> 我们人类最喜欢的其实还是人类弱小的大脑可以掌控的东西。
>
> 就比如 Pi ，它的设计哲学就是，极简核心，能力外置。
>
> 这是我们大脑可以掌控的，用简洁降低复杂性。

## 2086074146623312020 — @naoto_iwase
- url: https://x.com/i/status/2086074146623312020
- posted_at: Sat Aug 08 12:56:48 +0000 2026
- kind: tweet

> LLMの重みを変えずに、prompt、tool、workflow、runtime codeなど周囲の実行系を更新し、agentの自己改善を目指す「Harness Optimization」について、最近の研究動向と評価上の課題をまとめました。
>
> 日本語: https://notes.iwase.dev/ja/harness-optimization/
> English: https://notes.iwase.dev/en/harness-optimization/

