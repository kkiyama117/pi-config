#!/usr/bin/env python3
"""pi_usage.py — parse pi --mode json NDJSON streams for agent-loop.

Subcommands (all read a JSONL file path as the last argument):

  status <jsonl>   Print "ok" or "error:<reason>". Success requires the final
                   assistant message_end to have stopReason == "stop".
                   Terminal states aborted/length/toolUse/error are failures.

  usage <jsonl>    Print "input output cacheRead cacheWrite totalTokens costTotal".
                   Provider-aware aggregation:
                   - cursor* providers report CUMULATIVE usage per event -> use
                     the LAST assistant message_end's usage.
                   - all other providers report PER-TURN usage -> SUM the usage
                     of every assistant message_end.
                   Tolerant: malformed/truncated lines are skipped; the last
                   complete assistant message_end(s) still count. If no valid
                   usage is found, exit 1 with a message on stderr.

  text <jsonl>     Print the final assistant text (last text content block).
                   Exit 1 if there is no text or it is whitespace-only.

Uses only the Python 3 standard library (no jq, no pip installs).
"""

import json
import sys


def load_events(path):
    """Yield parsed events; skip malformed lines (tolerant parsing)."""
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue  # truncated tail line — ignore, keep earlier events


def assistant_message_ends(path):
    return [
        e for e in load_events(path)
        if e.get("type") == "message_end"
        and isinstance(e.get("message"), dict)
        and e["message"].get("role") == "assistant"
    ]


def cmd_status(path):
    ends = assistant_message_ends(path)
    if not ends:
        print("error:no assistant message_end events")
        return 1
    last = ends[-1]["message"]
    reason = last.get("stopReason")
    if last.get("errorMessage"):
        print(f"error:{last['errorMessage']}")
        return 1
    if reason != "stop":
        print(f"error:terminal stopReason is {reason!r}, expected 'stop'")
        return 1
    print("ok")
    return 0


def cmd_usage(path):
    ends = assistant_message_ends(path)
    if not ends:
        print("error:no assistant message_end events", file=sys.stderr)
        return 1

    # Provider detection: cursor reports cumulative totals, others per-turn.
    provider = ""
    for e in load_events(path):
        if isinstance(e.get("message"), dict) and e["message"].get("provider"):
            provider = e["message"]["provider"]
            break

    usages = []
    for e in ends:
        u = e["message"].get("usage")
        if not isinstance(u, dict):
            continue
        fields = ("input", "output", "cacheRead", "cacheWrite", "totalTokens")
        if not all(isinstance(u.get(f), (int, float)) for f in fields):
            continue
        cost = u.get("cost")
        if not isinstance(cost, dict) or not isinstance(cost.get("total"), (int, float)):
            continue
        usages.append(u)

    if not usages:
        print("error:no valid usage object on assistant message_end", file=sys.stderr)
        return 1

    if provider.startswith("cursor"):
        u = usages[-1]  # cumulative — the last event holds the call total
    else:
        u = {
            "input": sum(x["input"] for x in usages),
            "output": sum(x["output"] for x in usages),
            "cacheRead": sum(x["cacheRead"] for x in usages),
            "cacheWrite": sum(x["cacheWrite"] for x in usages),
            "totalTokens": sum(x["totalTokens"] for x in usages),
            "cost": {"total": sum(x["cost"]["total"] for x in usages)},
        }

    print(f"{u['input']} {u['output']} {u['cacheRead']} {u['cacheWrite']} "
          f"{u['totalTokens']} {u['cost']['total']}")
    return 0


def cmd_text(path):
    ends = assistant_message_ends(path)
    texts = []
    for e in ends:
        content = e["message"].get("content")
        if not isinstance(content, list):
            continue
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                texts.append(block.get("text", ""))
    final = texts[-1].strip() if texts else ""
    if not final:
        print("error:no non-whitespace assistant text", file=sys.stderr)
        return 1
    print(final)
    return 0


def main():
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    cmd, path = sys.argv[1], sys.argv[2]
    try:
        if cmd == "status":
            return cmd_status(path)
        if cmd == "usage":
            return cmd_usage(path)
        if cmd == "text":
            return cmd_text(path)
    except OSError as exc:
        print(f"error:{exc}", file=sys.stderr)
        return 1
    print(f"error:unknown subcommand {cmd!r}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
