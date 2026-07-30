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
