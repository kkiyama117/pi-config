# Reference Classification — `miyake-ken/prompts` export

Classification of the 94 articles (89 X/Twitter posts + 5 non-X links) from
`#hermes_home` (2026-07-22 → 2026-08-09). Files are organized into category
subdirectories under `classified_v1/miyake-ken-prompts/articles/`. The taxonomy
is **AI agent engineering first**; non-agent topics are grouped into secondary
buckets. Non-article media (video, repos) is kept separate — see
`classified_v1/miyake-ken-prompts/video/` and `.../repos/`.

Data lineage (source of truth): every article derives from a Slack post in
`slack-messages/`. See `README.md` for the full pipeline.

## Taxonomy overview

| Category | Count | Scope |
|----------|-------|-------|
| `agent-config` | 7 | AGENTS.md / CLAUDE.md, model tuning, instruction docs |
| `agent-memory` | 6 | Memory systems, memory agents, knowledge bases |
| `multi-agent-orchestration` | 5 | Coordinating multiple agents / agent teams |
| `agent-skills` | 4 | SKILL.md, skill packs, cross-harness skills |
| `loop-engineering` | 5 | Goal-based loops, loop frameworks |
| `agent-workflows` | 4 | Personal/org workflows, research automation |
| `graph-engineering` | 3 | Agent graphs (chain/diamond/router/cycle) |
| `harness-engineering` | 4 | Agent harness design (internal/external) |
| `self-improving-agents` | 4 | RL training, self-improvement, auto-research |
| `agent-search-rag` | 3 | Search-engine integration, RAG |
| `agentic-ai-education` | 3 | Learning paths, project lists, books |
| `software-factories` | 3 | Production reality, org adoption, business value |
| `eval-engineering` | 2 | LLM-as-judge, evaluation harnesses, test generation |
| `agent-infrastructure` | 1 | Cloud VMs, sandboxes, agent runtime infra |
| `mcp-protocols` | 1 | MCP protocol updates |
| `llm-fundamentals` | 6 | Model training (RLHF/RLVR), model behavior, theory |
| `dev-tools` | 10 | Editors, terminal, local LLM tools, PDF/parsing tools |
| `rust-systems` | 4 | Rust libraries, performance |
| `misc` | 4 | Personal notes, science news, link-only |
| `ml-theory-math` | 3 | GNN, Hodge decomposition, formal spec languages |
| `security` | 2 | Pwn, web app security |
| `empty` | 3 | No text content |
| `game-dev` | 1 | Game/networking dev |
| `hardware-eda` | 1 | Hardware design automation |
| **Total** | **89** | |

---

## AI Agent Engineering (primary focus)

### `agent-config/` — AGENTS.md, model tuning, instruction docs (6)

| ID | Author | Summary |
|----|--------|---------|
| 2065068565720649775 | @Neetfujisub | Full prompt for Claude fable5 to produce a `refactor-instructions.md` handoff doc for an implementer model (Codex/Opus) |
| 2080539722456383874 | @odiak_ | AGENTS.md instruction from @kenn: "Do not write overly defensive code. Prefer simplicity over pathological complexity" |
| 2081158883662524923 | @u1 | Article on "tuning" Opus 5 as a main coding partner (shallow thinking complaints) |
| 2084097212850839893 | @0xcherry | AGENTS.md practices for long-horizon dev: PLANS.md, DOCS.md, spec indexes, north-star metric, /goal or /loop |
| 2085268284837175595 | @takoidet | "The instruction doc looks like this" (companion to an AGENTS.md post) |
| 2085283330090758257 | @rmanzoku | Public article on writing a practical AGENTS.md for cross-session work |
| 2085860526052315310 | @voidwarriorchan | "BFV Kernel": AGENTS.md execution rules to curb over-implementation and endless improvement loops (define completion conditions first; justify every change) |

### `agent-memory/` — memory systems, memory agents, knowledge bases (5)

| ID | Author | Summary |
|----|--------|---------|
| 2080306769755242957 | @cipepser | Knowledge-base construction writeup; Slack ingestion params praised as concrete |
| 2080678034093252935 | @itarutomy | Paper: "behavioral state decay" in long-running agents; parallel memory agent that decides when to speak vs stay silent (Terminal-Bench 2.0 +8.3pt) |
| 2080873079467802750 | @connect24h | Training a memory-agent role (SFT + RL) on Qwen3.5; Terminal-Bench 2.0 37.6% → 41.1% |
| 2085174124146827611 | @yibie | Survey of 16 recent Agent Memory papers: static GraphRAG → self-evolving memory subsystems (SAGE, MAGMA, Mnemis, RecMem, TiMem…) |
| 2085206477908713666 | @Trtd6Trtd | Reddit thread on agent memory layers; preference for deterministic (SQLite/FAISS) over LLM-dependent memory |
| 2085787859680637092 | @beamnxw | Paper formalizing filesystem-based memory (markdown memory trees) as long-term storage for autonomous agents; roughly halves retrieval cost on large contexts |

### `multi-agent-orchestration/` — agent teams & coordination (5)

| ID | Author | Summary |
|----|--------|---------|
| 2079083609416409397 | @horatjp | herdr × agmsg: multiple AI agents developing multiple projects simultaneously |
| 2083910690134475039 | @Gorden_Sun | CodexLoom (ex-Manus author): organizing Codex conversations into an Agent Team |
| 2084256883431665718 | @CycleDecoded | HKU AutoAgent: zero-code natural-language multi-agent workflow assembly |
| 2084361778377404715 | @dotey | Practical Fable 5 (plan) → Codex (execute) → Fable 5 (verify) workflow with /compact and doc handoffs |
| 2084406102633124127 | @connect24h | herdr v0.7.5: 21 agent kinds in real PTY, named sessions, git worktrees, agent-driven orchestration |

### `agent-skills/` — SKILL.md & skill packs (4)

| ID | Author | Summary |
|----|--------|---------|
| 2080214550868365718 | @ytakanoster | `rust_skills`: Rust skill suite for coding agents (coverage, C++→Rust porting, FFI) |
| 2080922847690854892 | @hirokaji_ | Agent Skills standardization across Claude Code / Codex / Grok: what's shared vs divergent; "Author once, adapt per harness, verify per runtime" |
| 2081761224241627420 | @Suryanshti777 | 22 Claude Code skills worth adding (superpowers, gstack, caveman, ui-ux-pro-max…) |
| 2085199193334014060 | @iwashi86 | `adlc-team-skills`: feeding team tacit knowledge to coding agents per session as skills |

### `loop-engineering/` — goal-based loops (4)

| ID | Author | Summary |
|----|--------|---------|
| 2081249303620890982 | @shio_shoppaize | Loop engineering for non-coders: research, docs, inbox, meeting prep on Claude Code loops for 6 months |
| 2081708840622379222 | @polydao | "Run your whole workday on loops": full loop-engineering directory taxonomy (contracts, loop types, triggers, verifiers, skills, graphs, budget, memory, hooks) |
| 2084040134266404999 | @yifanxu_ephai | LoopX: lightweight state kernel for 200+ hour agent runs (Goal/Todo/Gate/Evidence/Authority/Handoff as executable control plane) |
| 2085025878631932063 | @huang_chao4969 | DeepCode v2: open-source coding agent with loop engineering, verified delivery, personalized automations |
| 2085759371355525610 | @paper2parasol | HITL → HOTL (Human on the Loop): shift from per-decision human judgment to humans on the loop; token-cost tradeoff (AIE2026 speakerdeck) |

### `graph-engineering/` — agent graphs (3)

| ID | Author | Summary |
|----|--------|---------|
| 2079573722537836677 | @todesking | Commentary on the "next is graphs" hype in the agent industry |
| 2081017726261199185 | @0xCodez | Anthropic engineer's 2-hour Graph Engineering workshop (state, nodes, feedback loops, agentic RAG, evals) |
| 2081076728126968237 | @AnatoliKopadze | The four graph shapes: chain, diamond, router, cycle — when each fits |

### `harness-engineering/` — agent harness design (3)

| ID | Author | Summary |
|----|--------|---------|
| 2081355365481075098 | @laiso | fukabori.fm #138: internal vs external agent harnesses — "groundbreaking" framing |
| 2082340541015154808 | @blackanger | Pi design philosophy: minimal core, externalized capabilities (human-controllable complexity) |
| 2084286415404458414 | @micahomnd | Lilian Weng on Harness Engineering: harness design patterns, workflow automation, persistent memory via filesystems |
| 2086074146623312020 | @naoto_iwase | "Harness Optimization" survey: keep LLM weights fixed, improve agent via prompt/tool/workflow/runtime updates; eval challenges (JP/EN notes) |

### `self-improving-agents/` — RL training & self-improvement (3)

| ID | Author | Summary |
|----|--------|---------|
| 2080661125822030164 | @ben_burtenshaw | Train agents in TRL + OpenEnv with any harness (open code, pi, codex, claude code); HarnessRolloutWorker + AsyncGRPOTrainer |
| 2082037302272909647 | @itarutomy | Survey unifying self-improving agents: base-model (SFT/RL) vs scaffold improvement; Gödel Machine lineage; critic-as-attack-surface |
| 2082517932714914113 | @james_y_zou | SqueezeEvolve (COLM2026): auto-research without a verifier, confidence-guided search, 97.5% ARC-AGI-2 at half cost |
| 2086318763612524762 | @connect24h | PrimeIntellect prime-agent: self-improving RLM coding agent for long-running autonomous tasks (TypeScript, ~9k★ in 24h) |

### `agent-search-rag/` — search & RAG (3)

| ID | Author | Summary |
|----|--------|---------|
| 2080519398323003515 | @iwashi86 | "Read later": speakerdeck on search for AI agents |
| 2084357787274891502 | @championswimmer | Hook agents to proper search engines (Exa/Parallel) instead of bundled web search |
| 2084452140404347298 | @at_sushi_ | Cerebras knowledge management: RAG on plain Postgres, no dedicated vector DB |

### `agentic-ai-education/` — learning paths & project lists (3)

| ID | Author | Summary |
|----|--------|---------|
| 2080596193844076884 | @cosmos_hzokujin | "AI Agents in Depth" textbook; AI fixed 30+ bugs in the book's samples in one day |
| 2084255462615109666 | @suraj_sharma14 | 12-stage roadmap to become an Agentic AI Engineer (async → LLM → tools → memory → multi-agent → HITL → evals → observability → security → prod) |
| 2084542353344282850 | @suraj_sharma14 | 18 projects to prove production AI engineering (RAG w/ citations, model router, multi-agent research, eval harness…) |

### `software-factories/` — production reality & org adoption (3)

| ID | Author | Summary |
|----|--------|---------|
| 2080597715457908865 | @HedgehogPython | Introducing AI-DLC V2 and optimizing its components for an organization |
| 2082028299275149685 | @Xudong07452910 | "Why Software Factories Fail": agents pass tests but codebases degrade; 2–3× efficiency over 10–100× hype |
| 2084835898613727522 | @kobenisikakatan | Before harness/loop code-gen methodology, be able to talk business value; code without business value shouldn't be written |

### `eval-engineering/` — evaluation & judging (2)

| ID | Author | Summary |
|----|--------|---------|
| 2082193490956476521 | @Argona0x | Eval engineering: LLM judges disagree with themselves 13.6%, prefer first-seen answer 72%; calibration rules for agent evals |
| 2084768844615413960 | @iwashi86 | COBOL→Java migration via "Locksmith Loop": AI agent test generation reaching 91.9% branch coverage |

### `agent-infrastructure/` — runtime infra (1)

| ID | Author | Summary |
|----|--------|---------|
| 2084983059330515216 | @shimabu_it | Running Cursor/Claude Code in vendor-managed VMs (parallel, state mgmt, secrets, streaming, egress, multi-repo) is a different league from self-hosted EC2 |

### `mcp-protocols/` — MCP (1)

| ID | Author | Summary |
|----|--------|---------|
| 2082164248697069935 | @ClaudeDevs | MCP 2026-07-28: largest update since launch — stateless, easier remote server deploy/scale |

### `agent-workflows/` — personal & org workflows (4)

| ID | Author | Summary |
|----|--------|---------|
| 2080602949932478666 | @AM09_21 | "Boss AI" pattern; self-driven supervisor + arXiv/X/RSS external context |
| 2081267484913790988 | @takutoda13 | End-of-task-assignment dev article; relevance to DS org future |
| 2081281598876762247 | @ryuhokataoka | "I had AI do research and write a paper" |
| 2084812103706427629 | @ai_ai_ailover | "An amazing AI employee appeared" (client-visible AI worker) |

---

## Secondary topics (non-agent-engineering)

### `llm-fundamentals/` — model training, behavior, theory (6)

| ID | Author | Summary |
|----|--------|---------|
| 2079723345717891468 | @ayousanz | arXiv paper (2509.23938) — Japanese model built from it |
| 2080638632420049234 | @K_Ryuichirou | AI practice lecture: MLOps, gen-AI usage, AI safety, governance; TPS/DevOps/MLOps commonality |
| 2081004600203886603 | @igshrmshk | Essay: "What are we talking about when we talk about language models?" |
| 2081128869851959365 | @santtiagom_ | (ES) 2-hour talk on how LLMs work — highly recommended |
| 2081560205804920836 | @iwashi86 | "A lot of content, read later": AI engineering lecture deck |
| 2084004473408753833 | @kunchenguid | RLHF vs RLVR: why newer models are worse to talk to; alignment tax; machines vs humanity |

### `dev-tools/` — editors, terminal, local LLM, parsing (10)

| ID | Author | Summary |
|----|--------|---------|
| 2079878241813491961 | @zztkm | oMLX — MLX-based local LLM tooling |
| 2080208599431950701 | @mizchi | Why Tabularis runs on Tauri |
| 2080447479947116624 | @delphinus35 | neovim: flash.nvim alternative with migemo (fast regex) |
| 2081182901060902958 | @zztkm | plannotator.ai + pi-cursor-sdk |
| 2081547228972478613 | @zztkm | ast-grep prompting with AI tools (for pi / AGENTS.md) |
| 2082655936129425559 | @vaaaaanquish | Consolidating on Raycast |
| 2082690348418273695 | @minpeter | et + herdr + durk + omo terminal stack |
| 2084279898655375650 | @jetbrains | KotlinLLM open source: delegate logic to an LLM as persistent Kotlin code |
| 2084729105342500911 | @voidwarriorchan | diffs.com — OSS diff tool |
| 2085191633637880120 | @opensourcelab9 | Firecrawl pdf-inspector: 200-page PDF parsed in 0.47s, Rust, MIT |

### `rust-systems/` — Rust & performance (3)

| ID | Author | Summary |
|----|--------|---------|
| 2079839244793880881 | @voluntas | shiguredo/container-rs: lightweight containers in Rust, Apple Container support |
| 2082192309592916252 | @letsgetrusty | Rust's new borrow checker (video) |
| 2083955764188627166 | @letsgetrusty | How unsafe Rust made Polars 30× faster than Pandas (video) |
| 2085934922934763812 | @yasuo_ozu | safegraph v0.2.0: petgraph-speed, zero-overhead safe graph library for Rust (no invalid references) |

### `ml-theory-math/` — theory, math, formal methods (3)

| ID | Author | Summary |
|----|--------|---------|
| 2081380665971675421 | @hdk78887151 | GNN layers (sheaves) in graph neural networks |
| 2082549894867480619 | @Kammaage_0414 | Hodge decomposition PDF (shared by a junior) |
| 2084961247964155965 | @mizchi | Quint formal spec language (TLA+ + z3 ergonomics) |

### `security/` — security (2)

| ID | Author | Summary |
|----|--------|---------|
| 2080929224060444811 | @hiro1noue | Interesting pwn video |
| 2081778471085478003 | @mizchi | Burp AT (PortSwigger) — read later |

### `game-dev/` — game development (1)

| ID | Author | Summary |
|----|--------|---------|
| 2084221982409883831 | @mizchi | Valve Source Multiplayer Networking wiki (for building online games with AI) |

### `hardware-eda/` — hardware design automation (1)

| ID | Author | Summary |
|----|--------|---------|
| 2081521345410797907 | @1amageek | Google XLS: hardware design automation |

### `misc/` — personal notes & science news (4)

| ID | Author | Summary |
|----|--------|---------|
| 2080490003780739385 | @k0mkc | "Everything is on my blog" (link only) |
| 2083854623753093187 | @takuya_fukatsu | Sharing a good comment with reply (note.com) |
| 2084918688332014073 | @dakaravaz | Essay: gap between self-driven learners and expected learners |
| 2085184815066997011 | @univkyoto | Kyoto Univ: first observation of anti-K meson nuclei with photon beams |

### `empty/` — no text content (3)

| ID | Author | Notes |
|----|--------|-------|
| 2080316615581688026 | @YKirin0418 | — |
| 2082446956710998379 | @claudecode_lab | — |
| 2083962166084804902 | @lemire | — |

---

# Non-X URL Classification

The 8 non-X links from `#hermes_home`. **Articles** (Zenn, blog, forum posts)
are classified into the same topic categories under `articles/`; **non-article
media** (video, GitHub repos) stay in their own top-level folders.

## Articles (classified into topic categories)

### `articles/agent-search-rag/`

| File | Source | Summary |
|------|--------|---------|
| 001-zenn-devknowledgesense | zenn.dev/knowledgesense | JP summary of Cerebras "How We Built Our Knowledge Base": production RAG on plain Postgres, 15k+ questions/day |

### `articles/multi-agent-orchestration/`

| File | Source | Summary |
|------|--------|---------|
| 002-zenn-devjtechjapan | zenn.dev/jtechjapan_pub | Herdr + intent-cli: 4-thread agent orchestration (design / orchestration / implementation / review) via GitHub Issues & PRs; herdr-only mode |

### `articles/ml-theory-math/`

| File | Source | Summary |
|------|--------|---------|
| 005-community-wolfram | community.wolfram.com | Jacobian conjecture counterexample by LLM (Wolfram Community discussion) |
| 006-zenn-devmtec | zenn.dev/mtec_blog | JSAI paper: sentence-length bias in Japanese embedding models (PCA, financial text) |
| 007-www-imperialviolet | imperialviolet.org | "We have proof automation now": dependent types (Coq/Rocq, Lean) and machine-checked invariants |

## Non-articles (kept separate)

### `video/`

| File | Source | Summary |
|------|--------|---------|
| 004-youtu-beffhlfbkvi30 | YouTube (devaslife) | "Effective Neovim setup for web development towards 2024" |

### `repos/`

| File | Source | Summary |
|------|--------|---------|
| 003-github-comsqueeze-evolve | github.com/squeeze-evolve | SqueezeEvolve [COLM 2026]: verifier-free evolutionary framework with multi-model orchestration |
| 008-github-comcursor-plugins | github.com/cursor | Cursor plugin specification and official plugins |
