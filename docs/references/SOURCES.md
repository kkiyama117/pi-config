# Sources — `miyake-ken/prompts`

Original repository documents that describe the export pipeline and conversion
tooling. Consolidated from `classified_v1/miyake-ken-prompts/sources/` (4 files;
repo: <https://github.com/miyake-ken/prompts>, converted 2026-08-08).

Contents:

1. [Repository README](#1-repository-readme)
2. [How-to: Export `#hermes_home` X/Twitter post text](#2-how-to-export-hermes_home-xtwitter-post-text)
3. [Composer prompt: `#hermes_home` X post text export](#3-composer-prompt-hermes_home-x-post-text-export)
4. [Processing script: `process_hermes_home_slack.py`](#4-processing-script-process_hermes_home_slackpy)

---

## 1. Repository README

```markdown
# prompts

Reusable Cursor / Cloud Agent prompts and how-tos.

## Contents

| Path | Description |
|------|-------------|
| [`prompts/hermes-home-tweet-export.prompt.md`](prompts/hermes-home-tweet-export.prompt.md) | Copy-paste prompt to export X/Twitter post text from `#hermes_home` |
| [`docs/hermes-home-tweet-export.md`](docs/hermes-home-tweet-export.md) | Step-by-step how-to for the export flow |
| [`exports/hermes_home_latest_10_tweets.txt`](exports/hermes_home_latest_10_tweets.txt) | Sample export: latest 10 X posts from `#hermes_home` |
| [`exports/hermes_home_next_10_tweets.txt`](exports/hermes_home_next_10_tweets.txt) | Next batch: posts 11–20 from `#hermes_home` |
| [`exports/hermes_home_remaining_tweets.txt`](exports/hermes_home_remaining_tweets.txt) | Remaining batch: posts 21–83 (63 tweets) from latest 100 Slack messages |
| [`exports/hermes_home_non_x_urls.txt`](exports/hermes_home_non_x_urls.txt) | Non-X links (URL only; 8 unique URLs) |
| [`exports/hermes_home_messages_from_2026-06-22.txt`](exports/hermes_home_messages_from_2026-06-22.txt) | Message index from 2026-06-22 (oldest available: 2026-07-22) |
```

---

## 2. How-to: Export `#hermes_home` X/Twitter post text

> Source: `docs/hermes-home-tweet-export.md` (kind: howto)

This documents the flow used to list Slack posts in `#hermes_home`, extract X/Twitter URLs, fetch tweet text, and write it to a `.txt` file. Use it with a Cursor Composer / Cloud Agent that has Slack tools enabled.

### Goal

From `#hermes_home` (newest first):

1. List posts and extract **URLs only** (do not fetch linked page content yet).
2. For X/Twitter status links, fetch the **tweet text**.
3. Write results to a text file under `exports/`.
4. Start small (e.g. latest 10), then expand if asked.

### Prerequisites

- Cursor agent with **Cursor Slack Tools** MCP available.
- Bot must be a **member** of the target Slack channel (membership is required to read messages; channel listing alone is not enough).
- Outbound network access to fetch tweet text (e.g. `https://api.fxtwitter.com/`).

### Channel reference

| Name | ID |
|------|----|
| `#hermes_home` | `C0BBHF3REDS` |

Prefer the channel ID when calling `read_slack_messages`.

### Step-by-step flow

**1. Read recent channel posts**

Use Slack MCP:

- `list_slack_channels` (optional discovery)
- `read_slack_messages` with `channel: C0BBHF3REDS` and `limit` up to `100`

Messages come back **newest first**.

**2. Extract URLs from posts (not page contents)**

From each top-level message body, collect embedded URLs such as:

- Slack autolink: `<https://x.com/i/status/2085283330090758257>`
- Or markdown-style links for Zenn / GitHub / etc.

**Do this first.** Do not fetch or summarize the destination pages yet.

Typical X URL shapes:

- `https://x.com/i/status/<id>`
- `https://twitter.com/<user>/status/<id>`

Skip non-content noise when listing:

- bot join messages
- gateway shutdown notices
- agent conversation threads (unless the user asks for everything)

**3. Select the batch**

Default starter batch:

- Take the **latest 10 X/Twitter status posts**
- Skip non-X posts (Zenn, GitHub-only, plain text) unless the user asks for all post types

**4. Fetch tweet text**

For each status id, call FxTwitter (worked reliably in practice):

```bash
curl -fsSL "https://api.fxtwitter.com/status/<STATUS_ID>" -o "/tmp/tweets/<STATUS_ID>.json"
```

From the JSON, extract:

- author name / screen name
- created_at
- tweet text (`tweet.text`)

Other options if FxTwitter fails: Twitter oEmbed (`publish.twitter.com/oembed`) or another public unfurl API. Direct `x.com` HTML fetch is usually blocked/login-walled.

**5. Write a text file**

Recommended path in this repo:

```text
exports/hermes_home_latest_10_tweets.txt
```

Recommended record format:

```text
=== N. https://x.com/i/status/<STATUS_ID> ===
Author: <Name> (@<handle>)
Date: <created_at>

<tweet text>
```

Newest first. Separate entries with blank lines.

Optional: also copy to `/opt/cursor/artifacts/` for Cloud Agent artifact surfacing. Note that path is **on the agent VM**, not the user's laptop — paste contents into chat or commit the file if the user needs local access.

**6. Confirm with the user**

Report:

- file path
- how many tweets exported
- that non-X posts were skipped (if true)
- offer the next batch

### Constraints / gotchas

- Slack `read_slack_messages` max `limit` is **100** per call.
- Listing a channel in `list_slack_channels` does **not** guarantee read access; the bot must be invited.
- Many `#hermes_home` posts are only X links; a minority are Zenn / GitHub / YouTube / plain text.
- Do not invent tweet text. If a fetch fails, record the URL and the error, then continue.

### Ready-to-run prompt

Copy-paste prompt for Composer:

→ [Section 3](#3-composer-prompt-hermes_home-x-post-text-export) below

---

## 3. Composer prompt: `#hermes_home` X post text export

> Source: `prompts/hermes-home-tweet-export.prompt.md` (kind: prompt)

Copy everything below the line into Composer / a Cloud Agent chat.

---

You are exporting post text from Slack channel `#hermes_home` in the `miyake-ken/prompts` repo context.

### Task

1. Read recent messages from `#hermes_home` (channel id `C0BBHF3REDS`) using Cursor Slack Tools (`read_slack_messages`, prefer channel id, `limit` up to 100, newest first).
2. From each top-level post, extract **URLs only**. Do not fetch destination page contents in this step.
   - Example Slack autolink: `<https://x.com/i/status/2085283330090758257>`
3. Take the **latest 10 X/Twitter status posts** (`x.com/i/status/...` or `twitter.com/.../status/...`).
   - Skip non-X posts (Zenn, GitHub-only, YouTube, plain text) unless I say otherwise.
   - Skip bot join / gateway shutdown / unrelated agent chatter.
4. For each of those 10 status IDs, fetch tweet text with:

   ```bash
   curl -fsSL "https://api.fxtwitter.com/status/<STATUS_ID>" -o "/tmp/tweets/<STATUS_ID>.json"
   ```

   Extract author name, `@handle`, `created_at`, and tweet text.
5. Write results newest-first to:

   ```text
   exports/hermes_home_latest_10_tweets.txt
   ```

   Use this format per entry:

   ```text
   === N. https://x.com/i/status/<STATUS_ID> ===
   Author: <Name> (@<handle>)
   Date: <created_at>

   <full tweet text>
   ```

6. When done, reply with:
   - the output file path
   - count exported
   - which non-X posts were skipped in the window
   - offer to continue with the next batch

### Rules

- Do not invent tweet text. On fetch failure, keep the URL and note the error, then continue.
- Do not summarize tweets unless I ask; copy the text as-is.
- If Slack read fails because the bot is not in the channel, tell me to invite the bot to `#hermes_home`.
- Start with only the latest 10 X posts. Wait for my go-ahead before exporting more.
- Keep prompts/howtos in this repo; do not add them to unrelated repos (e.g. `vimrc`).

### Optional follow-ups I may ask

- "Paste the txt contents here"
- "Do the next 10"
- "Include non-X links too"
- "Export all available X posts from the latest 100 Slack messages"

---

## 4. Processing script: `process_hermes_home_slack.py`

> Source: `scripts/process_hermes_home_slack.py` (kind: script, language: python)

```python
#!/usr/bin/env python3
"""Parse #hermes_home Slack MCP output into export files."""

import re
import sys
from datetime import datetime, timezone
from pathlib import Path

BOT_IDS = {"U0BEF0AFNS2", "U0BBDR24W6N"}
X_STATUS = re.compile(
    r"https?://(?:x\.com/i/status/|twitter\.com/[^/\s<>]+/status/)([0-9]+)",
    re.I,
)
URL = re.compile(r"https?://[^\s<>|\]]+")
LINE = re.compile(
    r"^\[(?P<date>[^\]]+)\] \(ts: (?P<ts>[0-9.]+)\) <@(?P<user>[^>]+)>: (?P<body>.*)$"
)
FROM_DATE = datetime(2026, 6, 22, tzinfo=timezone.utc)


def is_x_url(url: str) -> bool:
    return bool(X_STATUS.search(url))


def classify(urls: list[str]) -> str:
    if not urls:
        return "text"
    if all(is_x_url(u) for u in urls):
        return "x"
    return "non-x"


def parse(raw: str) -> list[dict]:
    entries = []
    for line in raw.splitlines():
        m = LINE.match(line.strip())
        if not m:
            continue
        user = m.group("user")
        if user in BOT_IDS:
            continue
        dt = datetime.strptime(m.group("date"), "%Y-%m-%d %H:%M:%S UTC").replace(
            tzinfo=timezone.utc
        )
        if dt < FROM_DATE:
            continue
        body = m.group("body").strip()
        urls = URL.findall(body)
        # Drop trailing punctuation from markdown links
        urls = [u.rstrip(")") for u in urls]
        entries.append(
            {
                "date": m.group("date"),
                "ts": m.group("ts"),
                "user": user,
                "body": body,
                "urls": urls,
                "type": classify(urls),
            }
        )
    return entries


def write_non_x_urls(entries: list[dict], out: Path) -> int:
    seen = set()
    lines = [
        "Non-X URLs from #hermes_home (URL only; bot messages skipped)",
        f"Filtered from {FROM_DATE.date()} onward; source: latest Slack MCP window.",
        "",
    ]
    n = 0
    for e in entries:
        for url in e["urls"]:
            if is_x_url(url) or url in seen:
                continue
            seen.add(url)
            n += 1
            lines.append(f"=== {n}. [{e['date']}] ===")
            lines.append(url)
            lines.append("")
    out.write_text("\n".join(lines), encoding="utf-8")
    return n


def write_message_index(entries: list[dict], out: Path) -> int:
    oldest = entries[-1]["date"] if entries else "n/a"
    newest = entries[0]["date"] if entries else "n/a"
    lines = [
        "#hermes_home message index from 2026-06-22",
        "",
        "Bot messages skipped (join notices, gateway shutdown, etc.).",
        "Slack MCP currently returns the latest 100 channel messages only;",
        f"this index covers {oldest} through {newest}.",
        "Messages before the oldest available timestamp are not included.",
        "",
        f"Total entries: {len(entries)}",
        "",
    ]
    for i, e in enumerate(reversed(entries), 1):
        lines.append(f"=== {i}. [{e['date']}] (ts: {e['ts']}) ===")
        lines.append(f"Type: {e['type']}")
        if e["type"] == "x":
            for url in e["urls"]:
                lines.append(f"URL: {url}")
        elif e["type"] == "non-x":
            for url in e["urls"]:
                if not is_x_url(url):
                    lines.append(f"URL: {url}")
            # Mixed posts: also list X URLs if present
            for url in e["urls"]:
                if is_x_url(url):
                    lines.append(f"URL (x): {url}")
        else:
            lines.append(f"Text: {e['body']}")
        lines.append("")
    out.write_text("\n".join(lines), encoding="utf-8")
    return len(entries)


def main() -> None:
    raw = sys.stdin.read()
    entries = parse(raw)
    exports = Path(__file__).resolve().parents[1] / "exports"
    exports.mkdir(exist_ok=True)
    non_x_count = write_non_x_urls(entries, exports / "hermes_home_non_x_urls.txt")
    index_count = write_message_index(entries, exports / "hermes_home_messages_from_2026-06-22.txt")
    print(f"non_x_urls={non_x_count} index_entries={index_count}")


if __name__ == "__main__":
    main()
```
