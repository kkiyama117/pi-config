# Pi Global Agent Contract

This file is small on purpose. It holds only (1) the meta-rule for how rules
are organized, (2) universal rules that apply to every task, and (3) the index
of domain rule files. Everything domain-specific lives in
`~/.pi/agent/rules/<domain>.md` — never inline here.

## 0. How rules are organized (meta-rule — read this before adding any rule)

- **One domain = one file**: `~/.pi/agent/rules/<domain>.md`.
- Every domain file **starts with a `Read when:` line** stating its trigger
  condition. Before starting work that matches a trigger, read that file
  first (progressive disclosure: this index → domain file → linked doctrine).
- **Adding a rule**: put it in the matching domain file and make sure the
  index row below is accurate. If no domain fits, create
  `rules/<new-domain>.md` (with a `Read when:` line) and add an index row.
  Never append domain rules to this file.
- **Anti-bloat**: when a domain file outgrows ~150 lines, split it into
  sub-files and turn the domain file into an index of them (a second-level
  index). No single rule file may grow without bound.
- **Keep the why**: rules born from violations must record what failure
  produced them, so they are not "simplified" away later.
- **Lifecycles differ**: rules and docs are durable (never deleted, only
  reorganized); plans/task notes are ephemeral (delete when done; git log is
  the record). Do not mix the two in one file.

## 1. Universal rules (every task, every domain)

1. **Fix the completion condition first.** For every proposed change ask:
   "can completion still be proven if this is omitted?" If yes, omit it.
2. Keep changes **small and revertable**; no unrelated refactors, drive-by
   formatting, or scope creep.
3. **Stop and ask** when correctness cannot be derived from the code, spec,
   or task — never guess on public APIs, schemas, auth, billing, or data.
4. IMPORTANT: Do not write overly defensive code. Always prefer simplicity
   over pathological complexity.
5. **Verify deterministically** (tests, linters, `bash -n`,
   `git diff --check`, …) and report the commands run and their actual
   results — failures included, never embellished.

## 2. Domain rule index

| Domain | File | Read when |
|--------|------|-----------|
| Orchestration | `rules/orchestration.md` | Launching/steering agent work, calling a wiser model (Fable/Opus), multi-agent phases |

Candidate future domains (create the file when the first rule arrives):
verification, memory, isolation/worktrees, budget/cost, stop-conditions.
