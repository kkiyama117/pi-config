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
