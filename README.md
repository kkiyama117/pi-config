# pi-config

Stable pi resources shared by dotfiles3.

This repository contains reviewable configuration only:

- `agent/settings.json`
- `agent/intercom/config.json` (broker launch override for standalone `aqua:earendil-works/pi`; avoids orphan broker chains)
- `agent/models.json` (DeepSeek `apiKey` uses `$DEEPSEEK_API_KEY` env interpolation)
- `agent/ollama-cloud.json`
- `agent/cursor-sdk.json`
- `agent/cursor-sdk-context-windows.json`
- `agent/prompts/`
- `agent/skills/`
- `agent/extensions/`
- `agent/themes/`
- `providers/<id>/config.json` (per-provider user overrides; secret-free)

Do not commit pi runtime state such as auth files, trust decisions, sessions,
logs, package checkouts, or caches. Those belong under `~/.pi/agent` at
runtime and are intentionally unmanaged.

## pi-intercom broker launch (container / aqua pi)

The dotfiles container installs pi via mise as `aqua:earendil-works/pi`. In that
layout, pi-intercom's default broker auto-spawn uses `process.execPath` (the pi
binary) instead of Node, which can spawn recursive `pi/pi … broker.ts` orphans
when sessions exit.

`agent/intercom/config.json` overrides broker launch to `npx --yes tsx`, which
uses the generic spawn path and keeps broker startup on Node/npx. Runtime broker
state (`broker.sock`, `broker.pid`, locks, extension-state) stays gitignored under
`agent/intercom/`.

## Container image (podman / apptainer)

Every `pi-config-v*` tag push triggers `.github/workflows/release.yml`, which

1. creates a GitHub Release for the tag, and
2. builds a podman image of this environment (pi + config, packages from
   `agent/settings.json` pre-installed) and pushes it to
   `ghcr.io/kkiyama117/pi-config`, tagged with the git tag and `latest`.

The image is secret-free by design — pass provider API keys at runtime.

Pull and run with apptainer (no local podman needed):

```bash
apptainer pull docker://ghcr.io/kkiyama117/pi-config:pi-config-v2026-07-14-2
apptainer run --no-home \
  --env DEEPSEEK_API_KEY=... \
  pi-config_pi-config-v2026-07-14-2.sif
```

`--no-home` keeps apptainer from mounting your host `$HOME` over the image's
`/root/.pi` config; without it the image config is shadowed by your host `~/.pi`.

Local build and run with podman:

```bash
podman build -t ghcr.io/kkiyama117/pi-config:latest .
podman run --rm -it -e DEEPSEEK_API_KEY ghcr.io/kkiyama117/pi-config:latest
```

Pin the pi version at build time with `--build-arg PI_VERSION=0.84.0`.

## Manual usage ledger

`bin/pi_usage.py` reads existing Pi session logs into a local SQLite ledger.
It uses Python's standard library via `uv`; it makes no network/model calls,
installs no Pi extension, and adds no automatic hooks. Commands are shell CLI
commands, not Pi slash commands. Run from this repository, or use the absolute
script path.

Find the canonical JSONL session path with Pi's `/session`, then:

```bash
SESSION=/absolute/path/to/session.jsonl

# Import historical usage (safe to repeat; does not assign it to a task).
uv run bin/pi_usage.py collect --session "$SESSION"
uv run bin/pi_usage.py report

# Before beginning a new task: mark the existing usage as its baseline.
uv run bin/pi_usage.py start fix-auth --session "$SESSION" \
  --category bugfix --strategy cheap-plus-review

# Do the work, and wait for its subagents to finish. Record the actual outcome.
uv run bin/pi_usage.py end fix-auth --outcome success --rework 1
uv run bin/pi_usage.py report --task fix-auth

# Offline regression tests; all test ledgers and sessions are temporary.
uv run bin/test_pi_usage.py
```

- Default storage: `${XDG_STATE_HOME:-$HOME/.local/state}/pi-usage/ledger.sqlite3`.
  Override with `uv run bin/pi_usage.py --db /path/to/ledger.sqlite3 <command>`.
  New ledger directories use mode `0700`, database files `0600`. Do not commit
  runtime databases. No prompt, response, or tool-result bodies are stored.
- `--session` is repeatable. Each root also includes canonical `session.jsonl`
  files beneath the root's filename without `.jsonl` (Pi-subagents' usual child
  directory). It does not crawl all projects. Supply out-of-tree child paths
  explicitly at `collect`/`start`. Missing fork ancestors cause an error instead
  of charging inherited history again.
- `start` requires a unique task ID and category; strategy is an optional label.
  Overlapping session scopes cannot have concurrent active tasks. A task counts
  usage first observed between its start baseline and end snapshot, including
  newly discovered children. A mid-task `collect` does not affect attribution.
  `report` reads stored data only; task usage is finalized at `end`, not live.
- `end` requires `success`, `failed`, `blocked`, or `cancelled`. `--rework` records
  correction rounds manually. A normally exited process is not automatically a
  successful task. Task elapsed time includes human waits, not just model time.
  End only once all work has settled: late records stay unassigned unless they
  arrive during a later task. No automatic retroactive attribution is attempted.
- JSON reports group usage by provider/model, separating input, output and
  cache tokens. `cost_usd` is a **recorded estimate**, not an invoice or a measure
  of subscription quota. `missing_*_events` shows incomplete coverage; sums
  include known values only (`null` when none are known). `zero_cost_events`
  distinguishes recorded zero prices from missing prices; neither proves free
  usage. Reasoning tokens are not added again on top of output/total tokens.
- All recorded branches count as historical spend. Copied fork history,
  compaction `retainedTail`, and parent tool summaries of child usage are not
  charged twice. Compaction/branch-summary usage is counted, with `unknown`
  model attribution when the record does not identify a model. Other tools'
  nested usage is excluded with a warning; sessionless/external work and usage
  never reported by the provider are outside this first version's coverage.
- One incomplete trailing JSONL record is skipped with a warning for live
  sessions; complete malformed records fail the import. Imports and task
  closure are transactional. Rewritten usage on an imported event fails rather
  than silently changing old totals.

This is observational data, not a controlled model benchmark: compare similar
task categories and account for difficulty before changing model routing.
