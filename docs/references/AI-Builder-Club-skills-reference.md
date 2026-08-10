# AI Builder Club Skills — Reference Notes

Source: https://github.com/AI-Builder-Club/skills (Claude Code plugin marketplace, "loop engineer" skills — agents that run autonomously, ship code, verify it, and log learnings into a shared file-based knowledge base).

Reviewed: 2025-08-10. 10 skills: `new-loop`, `setup-codebase-harness`, `dev-local-setup`, `e2e-setup`, `crabbox-setup`, `verifier-setup`, `open-agent-teams`, `agent-context-audit`, `seo-growth`, `visual-flow-gif`.

---

## 1. Skill repository / plugin structure

- **Marketplace + plugin packaging** — `.claude-plugin/marketplace.json` (name, owner, metadata, plugins pointing at `./`) + `plugin.json` (description, version, author, license, keywords). Clean template for shipping a multi-skill plugin.
- **Per-skill layout convention** — `SKILL.md` + `assets/` (templates, spec JSONs, Dockerfile) + `references/` (deep-dive docs) + `scripts/` (the `tdel` helper). SKILL.md stays a focused orchestrator; depth lives in references loaded on demand.
- **README as a "when to use which" table** — one row per skill with a trigger-phrase description. Very scannable.

## 2. SKILL.md authoring patterns

- **Frontmatter `description` = trigger phrases** ("Use when…", "when the user says…") so the model routes correctly.
- **"When to use / don't use" sections** (e.g. `new-loop`: *"Don't use for a one-off task"*; `seo-growth`: *"NOT for writing an article"*).
- **Setup skills vs run skills separation** — repeated principle: *"The output is a skill, not a run"* (`verifier-setup` scaffolds `/verify`; `/verify` runs it). Same for dev-local: *"Generate, syntax-check, hand off — never run the servers yourself."*
- **Inventories before creating** — Step 0 "look for the capability, not a specific filename; reuse-as-is / adapt-extend / create-fresh; never clobber working setup."
- **Discover, don't guess** — ports/commands/auth come from the repo, never convention.
- **Gotchas sections with the cost attached** ("each cost a debugging round" — e.g. Daytona 60s exec cap, docker 27.0.3 pin, busy-pane signatures).
- **Anti-patterns lists** (`agent-context-audit`: "every finding must be actionable as written").
- **Scope honesty** (`seo-growth`: what was tested, what transfers, what deliberately isn't covered).

## 3. File-based knowledge base architecture (`new-loop` references) — the strongest part

- **Two-idea model** — artifacts global foldered by *kind* (`signals/` evidence, `docs/` knowledge) with `domain:` as a *frontmatter field, not a folder*; domains (`domains/*/`) are loops whose README holds live state and *links* artifacts but never contains them.
- **"Earn a new kind" rule** — add a kind only when it has its own status machine + queryable fields + distinct body shape. Deferred-features table with explicit triggers ("add only when the need is real, do NOT pre-build").
- **Two-layer body convention** — main body = *what's true now*; append-only `## Timeline` = *what happened*. Frequency counting for deduped signals.
- **`LOG.md` strict entry grammar** (`## YYYY-MM-DD · title · #tags` + `What:`/`Refs:`), newest at the bottom, with grep/awk retrieval recipes.
- **Folder READMEs are the schema** — the schema lives in the folder itself.
- **`ARCHITECTURE.md` decision doc** — includes "options considered and why not" (folder-by-domain, pure DB, heavy taxonomy…) — great pattern for keeping the model intentional.
- **CLAUDE.md knowledge-base section** as a generic appendable block with `{{PLACEHOLDER}}`s; "reuse before creating."

## 4. Codebase harness concepts

- **Legible / Executable / Verifiable** framework; *"when the agent struggles, the fix is almost never 'try harder' — ask what capability is missing."*
- **Map, not manual** — shrink root agent doc to a ~100-line TOC (overview, tree, golden rules, "where to look"), depth moves to `docs/` system-of-record.
- **Lints with remediation** — promote prose rules into mechanical checks; *"write the error message to inject the fix"* so the remediation lands in agent context.
- **dev-local** — one tmux session, one window per long-lived server, idempotent, preflight fails fast, right-sized ("a single Vite app needs ~30 lines").
- **e2e practices** — real flow not bypass (read real OTP from Mailpit, never hardcode); *"verify auth ITSELF once; bypass it everywhere else"* (session helper); layered client→server→product assertions; triage-before-fixing (real bug / stale test / flaky); never weaken an assertion to go green; sandbox-mode guard with live-key refusal.
- **Verify-before-ship loop** (`verify.template.md`) — *subjective task verification → independent read-only verifier subagent* driving the real app; *objective checks → you run*; cap ~3 fix rounds; PR body leads with embedded screenshot proof — "Proof, not claims."
- **Parallel isolation** — one cloud box per agent (crabbox/Daytona) since worktrees still share the host; secrets via `env.allow`, never through sync/broker.

## 5. Multi-agent delegation (`open-agent-teams` + `tdel`)

- **File-sentinel done protocol over `tmux wait-for`** — *"a `wait-for -S` with no waiter is silently lost; files never race and allow timeouts."* Done-file + result-file; each `send` = new turn with its own sentinels (no cross-talk).
- **Wait via background task** so you get woken, never poll/block; exit 124 = timeout with pane peek for diagnosis.
- **Self-contained flattened prompts** (executor can't see your conversation; newlines break TUI input boxes — put big specs in a file).
- **`ROLE: EXECUTOR` marker** + coordinator/executor delegation template — delegate: implementation, refactors, read-heavy exploration, git mechanics; keep: design/architecture/naming, the land decision, pre-land gates, review of all executor output (*never delegated, never skipped*). Heuristic: *"prompt reads as a work order → delegate; writing it forces decisions → coordinator."*
- **Harness comparison table** for claude/codex/grok/pi/opencode — launch cmd, busy-pane signature, exit, interrupt key; plus trust-dialog and slash-popup hazards per harness.
- **`tdel` script quality** — resolves the *real* tmux binary past shims, owns its socket dir (`TMUX_TMPDIR` isolation), one task per session.

## 6. Context engineering (`agent-context-audit`)

- **Six-shift rubric** (map findings to numbered shifts):
  1. **Rules → Judgment** — keep hard rules only where violation is genuinely costly (security, prod data, irreversible, legal/billing).
  2. **Examples → Interface design** — an enum teaches more than three worked examples.
  3. **Upfront context → Progressive disclosure** — CLAUDE.md is loaded every session; it carries only what every session needs.
  4. **Repetition → Single home** — the same instruction in CLAUDE.md *and* a skill *and* a tool description is a bug; copies drift.
  5. **Manual memory → Automatic memory** — flag content that is really *memory* (per-user, per-incident, time-bound) rather than *repo truth*.
  6. **Simple specs → Rich references** — `@`-referenced source files, test suites, HTML mockups; code-based specs beat prose paraphrases.
- **Cross-cutting failure modes** — conflicts across layers (highest value); staleness (map ≠ territory — verify every concrete claim); missing unknown-knowns (the non-obvious gotchas CLAUDE.md is *for*).
- **Audit-first-fix-second** + **unknowns probe** — blind-spot pass over the territory; 5–10-question "knowledge quiz" answered only from docs (unanswerable = gap, wrong answer = stale doc); `git log` staleness check.
- **Severity grading** (high/medium/low) and "lead with the top 3–5 changes, don't bury a layer conflict under twenty style nits."

## 7. Operations / process insights

- **Operationalize** — *"do not automate a stage you have never run by hand."*
- **Four loop roles, never one loop** — Scout / Engine / Enrichment / Scorecard; *"the scorecard never ships anything"* (mixing measurement with action means one bad week rewrites the strategy).
- **Hard carve-outs** — every page belongs to exactly one loop; two loops editing one page destroys attribution.
- **Durable state file** — Spec / Current understanding / ledger of applied changes — "where the compounding lives," not the automation.
- **Loop design** — charter + cadence + test-run-before-declaring-setup (*"prove the loop actually runs, not just that the folder exists"*); don't gold-plate the scaffold.

---

## Bottom line — most reusable pieces

1. Knowledge-base / `ARCHITECTURE.md` model (kinds, domains, two-layer body, earned structure)
2. Verify-before-ship template (independent verifier + embedded proof in PR)
3. File-sentinel tmux delegation protocol (`tdel`)
4. Six-shift context-audit rubric
5. Setup-skill vs run-skill authoring pattern with assets/references/scripts layout
