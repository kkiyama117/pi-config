# pi-config

Stable pi resources shared by dotfiles3.

This repository contains reviewable configuration only:

- `agent/settings.json`
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
