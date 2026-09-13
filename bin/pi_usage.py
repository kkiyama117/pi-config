#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Manual, local Pi usage accounting. No network access or model calls."""

import argparse
import hashlib
import json
import math
import os
import sqlite3
import sys
import time
from contextlib import closing
from pathlib import Path

TOKEN_FIELDS = ("input", "output", "cacheRead", "cacheWrite", "totalTokens")
COVERAGE = (
    "Estimates from recorded usage, not invoices or subscription quota. Zero cost does not prove free usage.",
    (
        "Only selected canonical sessions and */session.jsonl beneath their filename stems are scanned. "
        "Out-of-tree, sessionless, unreported tool/provider work is not included."
    ),
    "All recorded branches are counted; inherited fork entries and compaction retainedTail are not charged again.",
    "Task boundaries use observed completed records. End only after child work settles; late records remain unassigned.",
)


class LedgerError(Exception):
    pass


def encode(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, allow_nan=False)


def number(value, label, integer=False):
    if value is None:
        return None
    if (
        isinstance(value, bool)
        or not isinstance(value, (int, float))
        or not math.isfinite(value)
        or value < 0
    ):
        raise LedgerError(f"{label}: expected a finite nonnegative number")
    if integer and int(value) != value:
        raise LedgerError(f"{label}: expected whole tokens")
    return int(value) if integer else float(value)


def identity(entry):
    # Forks preserve entry IDs/timestamps but may sanitize content and rechain parentId.
    if (
        not isinstance(entry.get("id"), str)
        or not entry["id"]
        or not isinstance(entry.get("timestamp"), str)
    ):
        raise LedgerError("session entry requires id and timestamp")
    return entry["id"], entry["timestamp"]


class SessionScan:
    def __init__(self):
        self.files = {}
        self.loading = set()
        self.warnings = []

    def load(self, path):
        if path in self.files:
            return self.files[path]
        if path in self.loading:
            raise LedgerError(f"Cyclic parentSession ancestry: {path}")
        self.loading.add(path)
        records = []
        lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
        for index, line in enumerate(lines):
            if not line.strip():
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError as exc:
                if index == len(lines) - 1 and not line.endswith("\n") and records:
                    self.warnings.append(f"Incomplete trailing record skipped: {path}")
                    break
                raise LedgerError(f"Invalid JSON at {path}:{index + 1}") from exc
            if not isinstance(record, dict):
                raise LedgerError(f"Expected JSON object at {path}:{index + 1}")
            records.append(record)
        if (
            not records
            or records[0].get("type") != "session"
            or not isinstance(records[0].get("id"), str)
            or not records[0]["id"]
        ):
            raise LedgerError(f"Not canonical Pi session JSONL: {path}")
        header, entries = records[0], records[1:]
        inherited = set()
        if header.get("parentSession"):
            parent = Path(header["parentSession"]).expanduser()
            if not parent.is_absolute():
                parent = path.parent / parent
            # Missing ancestry fails instead of silently charging an inherited prefix.
            _, parent_entries, ancestors = self.load(parent.resolve())
            inherited = ancestors | {identity(e) for e in parent_entries}
        for entry in entries:
            if not isinstance(entry.get("type"), str) or entry["type"] == "session":
                raise LedgerError(f"Invalid session entry in {path}")
            identity(entry)
        result = header, entries, inherited
        self.files[path] = result
        self.loading.remove(path)
        return result

    def events(self, roots):
        paths = set(roots)
        for root in roots:
            paths.update(root.with_suffix("").glob("**/session.jsonl"))
        result = {}
        for path in sorted(paths):
            header, entries, inherited = self.load(path)
            for entry in entries:
                if identity(entry) in inherited:
                    continue
                event = self.event(header, entry, path)
                if event is not None:
                    if (
                        event["event_id"] in result
                        and result[event["event_id"]] != event
                    ):
                        # Same session copied to another path has the same accounting identity.
                        old = {
                            k: v
                            for k, v in result[event["event_id"]].items()
                            if k != "source"
                        }
                        new = {k: v for k, v in event.items() if k != "source"}
                        if old != new:
                            raise LedgerError(
                                f"Conflicting usage entry: {path}:{entry['id']}"
                            )
                    result.setdefault(event["event_id"], event)
        return result

    def event(self, header, entry, path):
        kind = entry["type"]
        payload = entry
        if kind == "message":
            payload = entry.get("message")
            if not isinstance(payload, dict):
                raise LedgerError(f"Invalid message in {path}:{entry['id']}")
            role = payload.get("role")
            if role == "toolResult":
                if payload.get("toolName") in ("subagent", "bg_wait"):
                    return None  # Aggregate child usage is not another charge.
                if payload.get("usage") is not None:
                    self.warnings.append(
                        f"Tool-reported usage excluded (avoid opaque nested duplication): {path}:{entry['id']}"
                    )
                return None
            if role != "assistant":
                return None
            kind = "assistant"
        elif kind not in ("compaction", "branch_summary"):
            return None
        usage = payload.get("usage")
        if usage is None:
            self.warnings.append(f"Usage missing: {path}:{entry['id']}")
            usage = {}
        if not isinstance(usage, dict):
            raise LedgerError(f"Invalid usage: {path}:{entry['id']}")
        tokens = {
            key: number(usage.get(key), key, integer=True) for key in TOKEN_FIELDS
        }
        if tokens["totalTokens"] is None and all(
            tokens[k] is not None for k in TOKEN_FIELDS[:4]
        ):
            tokens["totalTokens"] = sum(
                v for k in TOKEN_FIELDS[:4] if (v := tokens[k]) is not None
            )
        # Reasoning may be a subset of output; never add it again.
        cost = usage.get("cost")
        if isinstance(cost, dict):
            cost = cost.get("total")
        cost = number(cost, "cost.total")
        provider = payload.get("provider") or "unknown"
        model = payload.get("model") or "unknown"
        if not isinstance(provider, str) or not isinstance(model, str):
            raise LedgerError(f"Invalid model attribution: {path}:{entry['id']}")
        key = hashlib.sha256(
            encode([header["id"], *identity(entry)]).encode()
        ).hexdigest()
        return {
            "event_id": key,
            "session_id": header["id"],
            "entry_id": entry["id"],
            "source": str(path),
            "timestamp": entry["timestamp"],
            "kind": kind,
            "provider": provider,
            "model": model,
            "input": tokens["input"],
            "output": tokens["output"],
            "cache_read": tokens["cacheRead"],
            "cache_write": tokens["cacheWrite"],
            "total_tokens": tokens["totalTokens"],
            "cost_usd": cost,
        }


def roots_from(paths):
    return sorted({Path(p).expanduser().resolve() for p in paths})


def overlaps(left, right):
    return any(
        a == b or a.with_suffix("") in b.parents or b.with_suffix("") in a.parents
        for a in left
        for b in right
    )


def connect(path):
    path = Path(path).expanduser()
    old_mask = os.umask(0o077)
    try:
        path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        db = sqlite3.connect(path)
        path.chmod(0o600)
    finally:
        os.umask(old_mask)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys = ON")
    db.executescript("""
        CREATE TABLE IF NOT EXISTS tasks (
            task_id TEXT PRIMARY KEY, category TEXT NOT NULL, strategy TEXT,
            roots TEXT NOT NULL, baseline TEXT NOT NULL, started_at REAL NOT NULL,
            ended_at REAL, outcome TEXT, rework INTEGER, warnings TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS events (
            event_id TEXT PRIMARY KEY, session_id TEXT NOT NULL, entry_id TEXT NOT NULL,
            source TEXT NOT NULL, timestamp TEXT NOT NULL, kind TEXT NOT NULL,
            provider TEXT NOT NULL, model TEXT NOT NULL,
            input INTEGER, output INTEGER, cache_read INTEGER, cache_write INTEGER,
            total_tokens INTEGER, cost_usd REAL, task_id TEXT REFERENCES tasks(task_id)
        );
        CREATE TABLE IF NOT EXISTS scans (
            root TEXT PRIMARY KEY, collected_at REAL NOT NULL, warnings TEXT NOT NULL
        );
    """)
    return db


def import_events(db, roots):
    scan = SessionScan()
    events = scan.events(roots)
    inserted = 0
    for event in events.values():
        existing = db.execute(
            "SELECT * FROM events WHERE event_id = ?", (event["event_id"],)
        ).fetchone()
        if existing:
            if any(
                existing[key] != value
                for key, value in event.items()
                if key != "source"
            ):
                raise LedgerError(
                    f"Previously imported usage changed: {event['source']}:{event['entry_id']}"
                )
            continue
        db.execute(
            """INSERT INTO events
            (event_id, session_id, entry_id, source, timestamp, kind, provider, model,
             input, output, cache_read, cache_write, total_tokens, cost_usd)
            VALUES (:event_id, :session_id, :entry_id, :source, :timestamp, :kind, :provider, :model,
                    :input, :output, :cache_read, :cache_write, :total_tokens, :cost_usd)""",
            event,
        )
        inserted += 1
    for root in roots:
        db.execute(
            "INSERT OR REPLACE INTO scans VALUES (?, ?, ?)",
            (str(root), time.time(), encode(scan.warnings)),
        )
    return events, inserted, scan.warnings


def collect(db, roots):
    with db:
        db.execute("BEGIN IMMEDIATE")
        _, inserted, warnings = import_events(db, roots)
    return {"inserted_events": inserted, "warnings": warnings, "coverage": COVERAGE}


def start(db, task_id, roots, category, strategy=None):
    if not task_id.strip() or not category.strip():
        raise LedgerError("Task ID and category must not be empty")
    with db:
        db.execute("BEGIN IMMEDIATE")
        if db.execute("SELECT 1 FROM tasks WHERE task_id = ?", (task_id,)).fetchone():
            raise LedgerError(f"Task already exists: {task_id}")
        for task in db.execute(
            "SELECT task_id, roots FROM tasks WHERE ended_at IS NULL"
        ):
            if overlaps(roots, roots_from(json.loads(task["roots"]))):
                raise LedgerError(
                    f"Session scope already has active task: {task['task_id']}"
                )
        events, _, warnings = import_events(db, roots)
        db.execute(
            "INSERT INTO tasks VALUES (?, ?, ?, ?, ?, ?, NULL, NULL, NULL, ?)",
            (
                task_id,
                category,
                strategy,
                encode([str(p) for p in roots]),
                encode(sorted(events)),
                time.time(),
                encode(warnings),
            ),
        )
    return {
        "task_id": task_id,
        "state": "active",
        "baseline_events": len(events),
        "warnings": warnings,
    }


def end(db, task_id, outcome, rework=0):
    if outcome not in ("success", "failed", "blocked", "cancelled") or rework < 0:
        raise LedgerError("Explicit valid outcome and nonnegative rework are required")
    with db:
        db.execute("BEGIN IMMEDIATE")
        task = db.execute(
            "SELECT * FROM tasks WHERE task_id = ?", (task_id,)
        ).fetchone()
        if task is None:
            raise LedgerError(f"Unknown task: {task_id}")
        if task["ended_at"] is not None:
            raise LedgerError(f"Task already ended: {task_id}")
        events, _, warnings = import_events(db, roots_from(json.loads(task["roots"])))
        new_ids = events.keys() - set(json.loads(task["baseline"]))
        for key in new_ids:
            owner = db.execute(
                "SELECT task_id FROM events WHERE event_id = ?", (key,)
            ).fetchone()[0]
            if owner is not None and owner != task_id:
                raise LedgerError(f"Usage already belongs to task: {owner}")
            db.execute(
                "UPDATE events SET task_id = ? WHERE event_id = ?", (task_id, key)
            )
        db.execute(
            "UPDATE tasks SET ended_at = ?, outcome = ?, rework = ?, warnings = ? WHERE task_id = ?",
            (time.time(), outcome, rework, encode(warnings), task_id),
        )
    return report(db, task_id)


def report(db, task_id=None):
    task = None
    if task_id is not None:
        row = db.execute("SELECT * FROM tasks WHERE task_id = ?", (task_id,)).fetchone()
        if row is None:
            raise LedgerError(f"Unknown task: {task_id}")
        task = {
            key: row[key]
            for key in (
                "task_id",
                "category",
                "strategy",
                "started_at",
                "ended_at",
                "outcome",
                "rework",
            )
        }
        task["elapsed_seconds"] = (row["ended_at"] or time.time()) - row["started_at"]
        task["warnings"] = json.loads(row["warnings"])
        task["usage_finalized"] = row["ended_at"] is not None
    columns = (
        "input",
        "output",
        "cache_read",
        "cache_write",
        "total_tokens",
        "cost_usd",
    )
    sums = ", ".join(
        f"SUM({c}) AS {c}, SUM({c} IS NULL) AS missing_{c}_events" for c in columns
    )
    where, args = ("WHERE task_id = ?", (task_id,)) if task_id is not None else ("", ())
    rows = db.execute(
        f"SELECT provider, model, COUNT(*) AS events, {sums}, "
        f"SUM(CASE WHEN cost_usd = 0 THEN 1 ELSE 0 END) AS zero_cost_events "
        f"FROM events {where} GROUP BY provider, model ORDER BY provider, model",
        args,
    )
    result = {
        "task": task,
        "by_model": [dict(row) for row in rows],
        "coverage": COVERAGE,
    }
    if task_id is None:
        result["tasks"] = [
            dict(row)
            for row in db.execute(
                "SELECT task_id, category, strategy, outcome, rework, started_at, ended_at FROM tasks ORDER BY started_at"
            )
        ]
        result["unassigned_events"] = db.execute(
            "SELECT COUNT(*) FROM events WHERE task_id IS NULL"
        ).fetchone()[0]
        result["scans"] = [
            {
                "root": row["root"],
                "collected_at": row["collected_at"],
                "warnings": json.loads(row["warnings"]),
            }
            for row in db.execute("SELECT * FROM scans ORDER BY root")
        ]
    return result


def main(argv=None):
    state_home = Path(
        os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))
    )
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--db",
        default=str(state_home / "pi-usage/ledger.sqlite3"),
        help="local ledger path",
    )
    commands = parser.add_subparsers(dest="command", required=True)
    collecting = commands.add_parser(
        "collect", help="manually import session usage, idempotently"
    )
    starting = commands.add_parser(
        "start", help="mark a task baseline before doing work"
    )
    for command in (collecting, starting):
        command.add_argument(
            "--session",
            action="append",
            required=True,
            help="canonical JSONL path; repeatable; child sessions included",
        )
    starting.add_argument("task_id")
    starting.add_argument("--category", required=True)
    starting.add_argument("--strategy", help="e.g. astra-alone or cheap-plus-review")
    ending = commands.add_parser(
        "end", help="collect new usage and record explicit task outcome"
    )
    ending.add_argument("task_id")
    ending.add_argument(
        "--outcome",
        required=True,
        choices=("success", "failed", "blocked", "cancelled"),
    )
    ending.add_argument(
        "--rework", type=int, default=0, help="manually recorded correction rounds"
    )
    reporting = commands.add_parser(
        "report", help="show stored usage; does not rescan sessions"
    )
    reporting.add_argument(
        "--task", help="one task; active task usage is finalized only at end"
    )
    args = parser.parse_args(argv)
    try:
        with closing(connect(args.db)) as db:
            if args.command == "collect":
                result = collect(db, roots_from(args.session))
            elif args.command == "start":
                result = start(
                    db,
                    args.task_id,
                    roots_from(args.session),
                    args.category,
                    args.strategy,
                )
            elif args.command == "end":
                result = end(db, args.task_id, args.outcome, args.rework)
            else:
                result = report(db, args.task)
            print(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False))
        return 0
    except (
        LedgerError,
        OSError,
        UnicodeError,
        sqlite3.Error,
        TypeError,
        ValueError,
        OverflowError,
    ) as exc:
        print(f"pi-usage: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
