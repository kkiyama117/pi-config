# 04 — Orchestration (multi-agent)

Coordinating multiple agents: plan-agent → execute-agent → verify-agent
handoffs via documents, agent teams built on Codex, 4-thread design
(orchestration/implementation/review), and terminal workspace managers (herdr)
that let agents hand work to each other with `--wait` chaining.

## 2084361778377404715 — @dotey
- url: https://x.com/i/status/2084361778377404715
- posted_at: Mon Aug 03 19:32:28 +0000 2026
- kind: tweet

> 现在我很多复杂一点的任务都是 Fable 5 写方案，Codex 去执行，Fable 5 验收，相对来说可以做出比较靠谱的方案，以及兼顾性价比。具体是这么做的：
>
> 1. Fable 5 的产出是技术方案文档（图1）
>
> 一方面文档方便批注修改，另一方面文档方便其他 Agent 快速上手
>
> 2. 文档确认后在当前先 /compact 一次
>
> 这一步不是必要的，但是有好处，因为后续还要在同一会话去验证，/compact 压缩后，节约后续的上下文空间，之所以讨论方案就马上发送 /compact，因为这时候 Prompt Caching 还在，成本低，后面缓存过期了 compact 要贵一点。
>
> 3. 把文档交给 Codex （GPT-5.6 Sol xhigh）去执行（图2）
>
> 如果任务明显比较复杂，我一般会加上 /goal，这样中间就不需要反复去 continue，一次性把任务完成
>
> 4. Codex 完成后让 Fable 验证（图3）
>
> 直接告诉 Fable 其他 Agent 已经实施了，让它确认有没有遗漏，或者方向有无偏离。
>
> 如果有些遗漏之类的，把 Fable 的反馈发回给 Codex（图4），不需要新开会话，在同一个 Codex 会话，Codex 会根据反馈继续完善。
>
> ---
>
> 如果用 Opus 5 替代 GPT 5.6 也可以，做法上可以跟上面一样新开会话，用文档传递上下文。
>
> 也可以直接让 Fable 5 开 SubAgent 并指定用 Opus 5 模型，并且要求在 SubAgent 完成任务后验证。
>
> 但是我执行下来 Opus 5 不如 GPT 5.6 Sol 稳定，也不如 GPT 5.6 Token 耐用，所以宁愿麻烦一点。

## 002-zenn-devjtechjapan — (Zenn article, non-x-url)
- url: https://zenn.dev/jtechjapan_pub/articles/intent-cli-herdr-orchestration
- posted_at: 2026-08-06 06:27:45 UTC
- kind: non-x-url

> *(No text content in the source TOML — URL-only record.)*

Note: the linked Zenn article (jtechjapan_pub, 2026-08-03) describes running
4 AI agents daily — design / orchestration / implementation / review threads
coordinated through GitHub Issues and PRs on top of Intent CLI (intent-system),
plus the "herdr-only" mode that drops agmsg from the dependency chain.

## 2084406102633124127 — @connect24h
- url: https://x.com/i/status/2084406102633124127
- posted_at: Mon Aug 03 22:28:35 +0000 2026
- kind: tweet

> うちの環境もtmuxが、体に合わなくてherderに移行しました。そしたら、コピーペーストのルールがいちいち変わらないので、非常に快適(レベルが低い　
>
> 2026/07/21のherdr v0.7.5はClaude Code、Codex、Gemini、Grokなど21のAgent kindをreal PTYで束ね、状態監視、named session、Git worktree、prompt送信と完了待ちまでCLIで回せる。タブを並べるだけのmultiplexerではない。
>
> 刺さったのは、Agent自身にherdrを操作させ、別Agentへ仕事を投げて`--wait`後に次工程へ進ませるところ。さらに`worktree.created`をevent hookにしたPluginまで自作できる。一部、agmsgと機能がかぶるんだけど、サブエージェントのメッセージやり取りはagmsgのままにしている。履歴ちゃんと追えるしね。
>
> 複数Agentを目視巡回しているなら、この実践記事は読んだ方が良い。
>
> #AI駆動開発
> ソース: https://blog.techscore.com/entry/2026/08/03/080000

## 2083910690134475039 — @Gorden_Sun
- url: https://x.com/i/status/2083910690134475039
- posted_at: Sun Aug 02 13:40:00 +0000 2026
- kind: tweet

> 来自前Manus大佬的一篇超长的文章，讲他做CodexLoom的Agent Team实践经验。
> CodexLoom基于Codex，让Codex的对话组织成Agent Team。
>
> CodexLoom开源，Github：https://github.com/yan5xu/codexloom
