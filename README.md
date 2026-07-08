# pi-config

Stable pi resources shared by dotfiles3.

This repository contains reviewable configuration only:

- `agent/settings.json`
- `agent/prompts/`
- `agent/skills/`
- `agent/extensions/`
- `agent/themes/`

Do not commit pi runtime state such as auth files, trust decisions, sessions,
logs, package checkouts, or caches. Those belong under `~/.pi/agent` at
runtime and are intentionally unmanaged.
