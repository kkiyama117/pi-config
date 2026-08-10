# 00 — References

Memo of every source used to build `docs/agents_docs_v1/` (created 2026-08-09).

## Primary corpus

All 30 articles were extracted verbatim from the classified reference corpus:

```
docs/references/classified_v1/miyake-ken-prompts/
├── articles/<category>/*.toml     ← the 30 articles (see tables below)
├── slack-messages/                ← source of truth (95 posts at conversion)
├── manifest.toml                  ← conversion metadata + path index
└── (sources consolidated into docs/references/SOURCES.md)
```

Lineage: each tweet/non-X link derives from a Slack post in `#hermes_home`
(channel id `C0BBHF3REDS`, repo github.com/miyake-ken/prompts, converted
2026-08-08). Verified: all article status IDs/URLs trace back to
`slack-messages/`. See `docs/references/README.md` for the full pipeline.

## Stage → article mapping

### 01-environment.md (harness & infrastructure)

| Article | Author | URL | Source file |
|---|---|---|---|
| 2084983059330515216 | しまぶー (@shimabu_it) | https://x.com/i/status/2084983059330515216 | articles/agent-infrastructure/2084983059330515216.toml |
| 2081355365481075098 | Iaiso (@laiso) | https://x.com/i/status/2081355365481075098 | articles/harness-engineering/2081355365481075098.toml |
| 2084286415404458414 | micah (@micahomnd) | https://x.com/i/status/2084286415404458414 | articles/harness-engineering/2084286415404458414.toml |
| 2082340541015154808 | AlexZ 🦀 (@blackanger) | https://x.com/i/status/2082340541015154808 | articles/harness-engineering/2082340541015154808.toml |
| 2086074146623312020 | Naoto Iwase (@naoto_iwase) | https://x.com/i/status/2086074146623312020 | articles/harness-engineering/2086074146623312020.toml |

### 02-contract.md (agent configuration)

| Article | Author | URL | Source file |
|---|---|---|---|
| 2084097212850839893 | 车厘子 (@0xcherry) | https://x.com/i/status/2084097212850839893 | articles/agent-config/2084097212850839893.toml |
| 2065068565720649775 | フジ AI開発 (@Neetfujisub) | https://x.com/i/status/2065068565720649775 | articles/agent-config/2065068565720649775.toml |
| 2085283330090758257 | Ryo Manzoku (@rmanzoku) | https://x.com/i/status/2085283330090758257 | articles/agent-config/2085283330090758257.toml |
| 2080539722456383874 | Kaido (@odiak_) | https://x.com/i/status/2080539722456383874 | articles/agent-config/2080539722456383874.toml |
| 2081158883662524923 | Yuichi Uemura (@u1) | https://x.com/i/status/2081158883662524923 | articles/agent-config/2081158883662524923.toml |
| 2085268284837175595 | 小出 孝雄 (@takoidet) | https://x.com/i/status/2085268284837175595 | articles/agent-config/2085268284837175595.toml |
| 2085860526052315310 | Void戦士ちゃん💜 (@voidwarriorchan) | https://x.com/i/status/2085860526052315310 | articles/agent-config/2085860526052315310.toml |

### 03-loop.md (loop & graph engineering, memory, skills)

| Article | Author | URL | Source file |
|---|---|---|---|
| 2081708840622379222 | Mr. Buzzoni (@polydao) | https://x.com/i/status/2081708840622379222 | articles/loop-engineering/2081708840622379222.toml |
| 2081249303620890982 | おしお (@shio_shoppaize) | https://x.com/i/status/2081249303620890982 | articles/loop-engineering/2081249303620890982.toml |
| 2084040134266404999 | Yifan Xu (@yifanxu_ephai) | https://x.com/i/status/2084040134266404999 | articles/loop-engineering/2084040134266404999.toml |
| 2085025878631932063 | Chao Huang (@huang_chao4969) | https://x.com/i/status/2085025878631932063 | articles/loop-engineering/2085025878631932063.toml |
| 2081017726261199185 | Codez (@0xCodez) | https://x.com/i/status/2081017726261199185 | articles/graph-engineering/2081017726261199185.toml |
| 2081076728126968237 | Anatoli Kopadze (@AnatoliKopadze) | https://x.com/i/status/2081076728126968237 | articles/graph-engineering/2081076728126968237.toml |
| 2080678034093252935 | Itaru Tomita (@itarutomy) | https://x.com/i/status/2080678034093252935 | articles/agent-memory/2080678034093252935.toml |
| 2080922847690854892 | hirokaji (@hirokaji_) | https://x.com/i/status/2080922847690854892 | articles/agent-skills/2080922847690854892.toml |
| 2085759371355525610 | じょーし (@paper2parasol) | https://x.com/i/status/2085759371355525610 | articles/loop-engineering/2085759371355525610.toml |
| 2085787859680637092 | beamnxw (@beamnxw) | https://x.com/i/status/2085787859680637092 | articles/agent-memory/2085787859680637092.toml |

### 04-orchestration.md (multi-agent)

| Article | Author | URL | Source file |
|---|---|---|---|
| 2084361778377404715 | 宝玉 (@dotey) | https://x.com/i/status/2084361778377404715 | articles/multi-agent-orchestration/2084361778377404715.toml |
| zenn intent-cli-herdr | (Zenn, tomohisa) | https://zenn.dev/jtechjapan_pub/articles/intent-cli-herdr-orchestration | articles/multi-agent-orchestration/002-zenn-devjtechjapan-pub-articles-intent-cli-herdr-orchestrati.toml |
| 2084406102633124127 | connect24h (@connect24h) | https://x.com/i/status/2084406102633124127 | articles/multi-agent-orchestration/2084406102633124127.toml |
| 2083910690134475039 | Gorden Sun (@Gorden_Sun) | https://x.com/i/status/2083910690134475039 | articles/multi-agent-orchestration/2083910690134475039.toml |

### 05-verification.md (eval engineering)

| Article | Author | URL | Source file |
|---|---|---|---|
| 2082193490956476521 | Argona (@Argona0x) | https://x.com/i/status/2082193490956476521 | articles/eval-engineering/2082193490956476521.toml |
| 2084768844615413960 | iwashi (@iwashi86) | https://x.com/i/status/2084768844615413960 | articles/eval-engineering/2084768844615413960.toml |

### 06-learning.md (self-improving agents)

| Article | Author | URL | Source file |
|---|---|---|---|
| 2080661125822030164 | Ben Burtenshaw (@ben_burtenshaw) | https://x.com/i/status/2080661125822030164 | articles/self-improving-agents/2080661125822030164.toml |
| 2082037302272909647 | Itaru Tomita (@itarutomy) | https://x.com/i/status/2082037302272909647 | articles/self-improving-agents/2082037302272909647.toml |
| 2082517932714914113 | James Zou (@james_y_zou) | https://x.com/i/status/2082517932714914113 | articles/self-improving-agents/2082517932714914113.toml |
| 2086318763612524762 | connect24h (@connect24h) | https://x.com/i/status/2086318763612524762 | articles/self-improving-agents/2086318763612524762.toml |

### 07-reality-check.md (software factories)

| Article | Author | URL | Source file |
|---|---|---|---|
| 2082028299275149685 | Xudong Han (@Xudong07452910) | https://x.com/i/status/2082028299275149685 | articles/software-factories/2082028299275149685.toml |
| 2084835898613727522 | キタデ (@kobenisikakatan) | https://x.com/i/status/2084835898613727522 | articles/software-factories/2084835898613727522.toml |
| 2080597715457908865 | aki.ts🦔 (@HedgehogPython) | https://x.com/i/status/2080597715457908865 | articles/software-factories/2080597715457908865.toml |

## Supporting documents

| Document | Role |
|---|---|
| `docs/references/README.md` | Data lineage (slack-messages = source of truth) + corpus layout |
| `docs/references/CLASSIFICATION.md` | 24-category taxonomy with per-item summaries |
| `docs/references/SOURCES.md` | Original repo docs: export how-to, Composer prompt, processing script, repo README |
| `docs/references/classified_v1/miyake-ken-prompts/manifest.toml` | Path index + conversion counts |

## External links referenced by the articles

- Lilian Weng — Harness Engineering: https://lilianweng.github.io/posts/2026-07-04-harness/
- Anthropic Graph Engineering workshop: https://platform.claude.com/cookbook/
- LoopX (huangruiteng): https://github.com/huangruiteng/loopx
- DeepCode v2 (HKUDS): https://github.com/HKUDS/DeepCode
- SqueezeEvolve (COLM 2026): https://arxiv.org/abs/2604.07725
- TRL + OpenEnv training: https://arxiv.org/html/2607.13104v1 (self-improvement survey)
- fukabori.fm #138 (internal/external harness): https://fukabori.fm/episode/138
- intent-cli (intent-system) Zenn series: https://zenn.dev/jtechjapan_pub/articles/intent-cli-herdr-orchestration

## Scope note

`agents_docs_v1` v1 covered the 30 articles classified as of the initial cut
(commit `8849ae8`). Five of the six tweets added later by another session
(commit `863543a`, 2026-08-09) have since been folded into the stage docs
(01-environment +1, 02-contract +1, 03-loop +2, 06-learning +1) with verbatim
texts, bringing the total to **35 articles**.

The sixth tweet — safegraph v0.2.0 (@yasuo_ozu, `articles/rust-systems/`) — is
**out of scope**: it is a Rust graph library release, unrelated to the AI agent
coding loop, so it is intentionally not included. The corpus manifest now
counts 89 tweets / 101 slack messages.
