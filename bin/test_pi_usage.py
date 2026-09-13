#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Offline accounting/lifecycle regression tests: uv run bin/test_pi_usage.py."""

import io
import json
import sqlite3
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch

import pi_usage as ledger

UNSET = object()


def usage(cost=0.02):
    return {
        "input": 100,
        "output": 10,
        "cacheRead": 20,
        "cacheWrite": 5,
        "totalTokens": 135,
        "reasoning": 3,
        "cost": {"total": cost},
    }


def entry(key, role="assistant", data=UNSET):
    message = {
        "role": role,
        "provider": "test-provider",
        "model": "test-model",
        "content": [{"type": "text", "text": "PRIVATE_PROMPT_NEVER_STORE"}],
    }
    if data is UNSET:
        data = usage()
    if data is not None:
        message["usage"] = data
    return {
        "type": "message",
        "id": key,
        "timestamp": f"2026-09-13T00:00:{key}Z",
        "message": message,
    }


def write_session(path, session_id, entries, parent=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    header = {
        "type": "session",
        "version": 3,
        "id": session_id,
        "timestamp": "2026-09-13T00:00:00Z",
    }
    if parent:
        header["parentSession"] = str(parent)
    path.write_text("".join(json.dumps(e) + "\n" for e in [header, *entries]))


def append(path, value):
    with path.open("a") as stream:
        stream.write(json.dumps(value) + "\n")


class LedgerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.session = self.root / "parent.jsonl"
        self.db_path = self.root / "state/ledger.sqlite3"
        self.db = ledger.connect(self.db_path)
        self.addCleanup(self.db.close)
        write_session(self.session, "parent", [entry("01")])
        self.roots = [self.session]

    def test_reimports_forks_sanitized_content_and_copies(self):
        inherited = entry("01")
        inherited["message"][
            "content"
        ] = []  # fork sanitization must not change accounting identity
        inherited["parentId"] = None
        child = self.root / "parent/child/run-0/session.jsonl"
        write_session(child, "child", [inherited, entry("02")], self.session)
        clone = self.root / "parent/clone/run-0/session.jsonl"
        write_session(clone, "clone", [inherited, entry("02"), entry("03")], child)
        self.assertEqual(ledger.collect(self.db, self.roots)["inserted_events"], 3)
        self.assertEqual(ledger.collect(self.db, self.roots)["inserted_events"], 0)
        row = ledger.report(self.db)["by_model"][0]
        self.assertEqual(row["total_tokens"], 405)
        self.assertEqual(row["input"], 300)
        self.assertEqual(row["cache_read"], 60)
        self.assertAlmostEqual(row["cost_usd"], 0.06)
        # The same canonical session copied to a different path is not another bill.
        alias = self.root / "alias.jsonl"
        alias.write_bytes(self.session.read_bytes())
        self.assertEqual(ledger.collect(self.db, [alias])["inserted_events"], 0)

    def test_import_fork_alone_excludes_inherited_prefix(self):
        child = self.root / "fork.jsonl"
        write_session(child, "fork", [entry("01"), entry("02")], self.session)
        self.assertEqual(ledger.collect(self.db, [child])["inserted_events"], 1)
        row = self.db.execute("SELECT session_id, entry_id FROM events").fetchone()
        self.assertEqual(tuple(row), ("fork", "02"))

    def test_missing_or_cyclic_ancestry_fails(self):
        fork = self.root / "fork.jsonl"
        write_session(fork, "fork", [entry("02")], self.root / "missing.jsonl")
        with self.assertRaises(OSError):
            ledger.collect(self.db, [fork])
        write_session(fork, "fork", [entry("02")], fork)
        with self.assertRaisesRegex(ledger.LedgerError, "Cyclic"):
            ledger.collect(self.db, [fork])
        self.assertEqual(
            self.db.execute("SELECT COUNT(*) FROM events").fetchone()[0], 0
        )

    def test_task_baseline_mid_collect_and_new_child(self):
        with patch.object(ledger.time, "time", return_value=100):
            ledger.start(
                self.db, "task-1", self.roots, "implementation", "cheap-plus-review"
            )
        append(self.session, entry("02"))
        ledger.collect(self.db, self.roots)  # Must not steal usage from task end.
        child = self.root / "parent/new/run-0/session.jsonl"
        write_session(
            child, "new", [entry("01"), entry("02"), entry("03")], self.session
        )
        with patch.object(ledger.time, "time", return_value=120):
            result = ledger.end(self.db, "task-1", "blocked", 1)
        self.assertEqual(result["by_model"][0]["events"], 2)
        self.assertEqual(result["by_model"][0]["total_tokens"], 270)
        self.assertEqual(result["task"]["outcome"], "blocked")
        self.assertEqual(result["task"]["elapsed_seconds"], 20)
        self.assertEqual(result["task"]["rework"], 1)
        append(self.session, entry("04"))  # Late completions stay unassigned.
        ledger.collect(self.db, self.roots)
        self.assertEqual(ledger.report(self.db, "task-1")["by_model"][0]["events"], 2)
        self.assertEqual(ledger.report(self.db)["unassigned_events"], 2)
        ledger.start(self.db, "task-2", self.roots, "research")
        append(self.session, entry("05"))
        self.assertEqual(
            ledger.end(self.db, "task-2", "success")["by_model"][0]["events"], 1
        )

    def test_task_lifecycle_and_scope_overlap(self):
        ledger.start(self.db, "one", self.roots, "research")
        for roots in (self.roots, [self.root / "parent/future/run-0/session.jsonl"]):
            with self.assertRaisesRegex(ledger.LedgerError, "active task"):
                ledger.start(self.db, "two", roots, "research")
        with self.assertRaisesRegex(ledger.LedgerError, "already exists"):
            ledger.start(self.db, "one", self.roots, "research")
        with self.assertRaisesRegex(ledger.LedgerError, "Unknown task"):
            ledger.end(self.db, "missing", "failed")
        with self.assertRaises(ledger.LedgerError):
            ledger.end(self.db, "one", "success", -1)
        with self.assertRaises(ledger.LedgerError):
            ledger.end(self.db, "one", "complete")
        self.assertFalse(ledger.report(self.db, "one")["task"]["usage_finalized"])
        ledger.end(self.db, "one", "cancelled")
        with self.assertRaisesRegex(ledger.LedgerError, "already ended"):
            ledger.end(self.db, "one", "success")

    def test_summaries_retained_tail_and_tool_aggregates(self):
        summary = {
            "type": "compaction",
            "id": "02",
            "timestamp": "stamp02",
            "usage": usage(),
            "retainedTail": [entry("01")["message"]],
            "summary": "PRIVATE_PROMPT_NEVER_STORE",
        }
        branch = {
            "type": "branch_summary",
            "id": "03",
            "timestamp": "stamp03",
            "usage": usage(),
        }
        tool = entry("04", role="toolResult")
        tool["message"]["toolName"] = "subagent"
        other = entry("05", role="toolResult")
        other["message"]["toolName"] = "web_search"
        for item in (summary, branch, tool, other):
            append(self.session, item)
        result = ledger.collect(self.db, self.roots)
        self.assertEqual(result["inserted_events"], 3)
        self.assertTrue(
            any("Tool-reported usage excluded" in w for w in result["warnings"])
        )
        by_model = ledger.report(self.db)["by_model"]
        self.assertEqual(sum(row["events"] for row in by_model), 3)
        self.assertEqual(
            by_model[1]["provider"], "unknown"
        )  # No guessed summary model.
        self.assertNotIn(b"PRIVATE_PROMPT_NEVER_STORE", self.db_path.read_bytes())

    def test_missing_zero_and_partial_usage(self):
        write_session(
            self.session,
            "parent",
            [
                entry("01", data=None),
                entry("02", data=usage(0)),
                entry("03", data={"input": 5}),
            ],
        )
        ledger.collect(self.db, self.roots)
        row = ledger.report(self.db)["by_model"][0]
        self.assertEqual(row["missing_cost_usd_events"], 2)
        self.assertEqual(row["zero_cost_events"], 1)
        self.assertEqual(row["cost_usd"], 0)
        self.assertEqual(row["input"], 105)
        self.assertEqual(row["missing_input_events"], 1)
        self.assertEqual(row["missing_total_tokens_events"], 2)

    def test_all_missing_cost_remains_unknown(self):
        write_session(self.session, "parent", [entry("01", data={"input": 5})])
        ledger.collect(self.db, self.roots)
        row = ledger.report(self.db)["by_model"][0]
        self.assertIsNone(row["cost_usd"])
        self.assertEqual(row["missing_cost_usd_events"], 1)
        self.assertEqual(row["zero_cost_events"], 0)

    def test_numeric_validation_and_atomic_end(self):
        ledger.start(self.db, "one", self.roots, "research")
        for bad in (-1, float("nan"), float("inf"), True, "10", 1.5):
            data = usage()
            data["input"] = bad
            write_session(self.session, "parent", [entry("01"), entry("02", data=data)])
            with self.assertRaises(ledger.LedgerError):
                ledger.end(self.db, "one", "success")
            self.assertIsNone(
                self.db.execute("SELECT ended_at FROM tasks").fetchone()[0]
            )
            self.assertEqual(
                self.db.execute("SELECT COUNT(*) FROM events").fetchone()[0], 1
            )
        write_session(self.session, "parent", [entry("01"), entry("02")])
        self.assertEqual(
            ledger.end(self.db, "one", "success")["by_model"][0]["events"], 1
        )

    def test_partial_tail_and_completed_malformed_record(self):
        with self.session.open("a") as stream:
            stream.write('{"type":')
        result = ledger.collect(self.db, self.roots)
        self.assertEqual(result["inserted_events"], 1)
        self.assertTrue(any("Incomplete trailing" in w for w in result["warnings"]))
        with self.session.open("a") as stream:
            stream.write("\n")
        with self.assertRaisesRegex(ledger.LedgerError, "Invalid JSON"):
            ledger.collect(self.db, self.roots)
        invalid = self.root / "transcript.jsonl"
        invalid.write_text(json.dumps(entry("01")) + "\n")
        with self.assertRaisesRegex(ledger.LedgerError, "Not canonical"):
            ledger.collect(self.db, [invalid])

    def test_changed_import_is_not_silently_overwritten(self):
        ledger.collect(self.db, self.roots)
        changed = entry("01", data=usage(0.5))
        write_session(self.session, "parent", [changed, entry("02")])
        with self.assertRaisesRegex(
            ledger.LedgerError, "Previously imported usage changed"
        ):
            ledger.collect(self.db, self.roots)
        self.assertEqual(
            self.db.execute("SELECT COUNT(*) FROM events").fetchone()[0], 1
        )
        self.assertAlmostEqual(ledger.report(self.db)["by_model"][0]["cost_usd"], 0.02)

    def test_all_branches_and_model_switches(self):
        second = entry("02")
        second["parentId"] = None  # Not on the same active branch.
        second["message"]["model"] = "other-model"
        append(self.session, second)
        ledger.collect(self.db, self.roots)
        rows = ledger.report(self.db)["by_model"]
        self.assertEqual({r["model"] for r in rows}, {"test-model", "other-model"})
        self.assertEqual(sum(r["events"] for r in rows), 2)

    def test_cli_task_commands(self):
        prefix = ["--db", str(self.db_path)]
        with redirect_stdout(io.StringIO()):
            self.assertEqual(
                ledger.main(
                    prefix
                    + [
                        "start",
                        "cli-task",
                        "--session",
                        str(self.session),
                        "--category",
                        "bugfix",
                        "--strategy",
                        "astra-alone",
                    ]
                ),
                0,
            )
        append(self.session, entry("02"))
        with redirect_stdout(io.StringIO()):
            self.assertEqual(
                ledger.main(
                    prefix + ["end", "cli-task", "--outcome", "failed", "--rework", "2"]
                ),
                0,
            )
        output = io.StringIO()
        with redirect_stdout(output):
            self.assertEqual(ledger.main(prefix + ["report", "--task", "cli-task"]), 0)
        result = json.loads(output.getvalue())
        self.assertEqual(result["task"]["outcome"], "failed")
        self.assertEqual(result["by_model"][0]["events"], 1)
        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            ledger.main(prefix + ["end", "cli-task"])

    def test_cli_and_private_storage(self):
        output = io.StringIO()
        with redirect_stdout(output):
            code = ledger.main(
                ["--db", str(self.db_path), "collect", "--session", str(self.session)]
            )
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(output.getvalue())["inserted_events"], 1)
        self.assertEqual(self.db_path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.db_path.parent.stat().st_mode & 0o777, 0o700)
        with redirect_stderr(io.StringIO()):
            self.assertEqual(
                ledger.main(
                    [
                        "--db",
                        str(self.db_path),
                        "collect",
                        "--session",
                        str(self.root / "missing.jsonl"),
                    ]
                ),
                1,
            )
        # All data remains queryable after a failed import.
        with sqlite3.connect(self.db_path) as other:
            self.assertEqual(
                other.execute("SELECT COUNT(*) FROM events").fetchone()[0], 1
            )


if __name__ == "__main__":
    unittest.main()
