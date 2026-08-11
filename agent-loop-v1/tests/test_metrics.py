#!/usr/bin/env python3
"""Regression test for metrics.py (task-105): synthetic fixture memory dirs.

Run: python3 tests/test_metrics.py
"""

import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import metrics  # noqa: E402


def write(dirpath, name, text):
    with open(os.path.join(dirpath, name), "w", encoding="utf-8") as fh:
        fh.write(text)


class MetricsTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.addCleanup(lambda: shutil.rmtree(self.dir, ignore_errors=True))

    def test_summary_and_malformed_tolerance(self):
        write(self.dir, "cost-log.md", (
            "- 2026-08-10T00:00:00+09:00 run=20260810-000001 stage=plan model=m tokens=1000 cost=0.01\n"
            "- 2026-08-10T00:00:01+09:00 run=20260810-000001 stage=implement model=m tokens=2000 cost=0.02\n"
            "- 2026-08-10T00:00:02+09:00 run=20260810-000002 stage=plan model=m tokens=3000 cost=0.03\n"
            "- 2026-08-10T00:00:03+09:00 run=20260810-000003 stage=plan model=m tokens=4000 cost=0.04\n"
            "- 2026-08-10T00:00:04+09:00 run=20260810-000003 stage=review model=m tokens=5000 cost=0.05\n"
            "- MALFORMED LINE WITHOUT RUN ID\n"
            "- 2026-08-10T00:00:05+09:00 run=20260810-000003 tokens=abc cost=xyz\n"
        ))
        write(self.dir, "past-runs.md", (
            "- 2026-08-10T00:00:00+09:00 start run=20260810-000001 repo=x task=y\n"
            "- 2026-08-10T00:00:02+09:00 done run=20260810-000001 branch=loop/x cycles=1\n"
            "- 2026-08-10T00:00:03+09:00 start run=20260810-000002 repo=x task=y\n"
            "- 2026-08-10T00:00:04+09:00 done run=20260810-000002 branch=loop/x cycles=1\n"
            "- 2026-08-10T00:00:05+09:00 start run=20260810-000003 repo=x task=y\n"
            "- 2026-08-10T00:00:06+09:00 run=20260810-000003 total_tokens=9000 total_cost=0.090000 calls=2\n"
        ))
        write(self.dir, "known-failures.md", (
            "- 2026-08-10T00:00:06+09:00 run=20260810-000003 review-fail run=20260810-000003 cycle=1\n"
        ))
        rc, out = metrics.cmd_summary(self.dir)
        self.assertEqual(rc, 0)
        self.assertIn(
            "run=20260810-000001 calls=2 tokens=3000 cost=0.03 "
            "verify_fails=0 review_fails=0 outcome=done\n", out)
        self.assertIn(
            "run=20260810-000002 calls=1 tokens=3000 cost=0.03 "
            "verify_fails=0 review_fails=0 outcome=done\n", out)
        self.assertIn(
            "run=20260810-000003 calls=2 tokens=9000 cost=0.09 "
            "verify_fails=0 review_fails=1 outcome=aborted\n", out)
        self.assertIn("total_runs=3 done_rate=66.7% review_fail_rate=33.3% "
                      "escalated_runs=1\n", out)

    def test_check_cost(self):
        write(self.dir, "cost-log.md", (
            "- 2026-08-10T00:00:00+09:00 run=20260810-000001 stage=plan model=m tokens=1000 cost=0.03\n"
            "- 2026-08-10T00:00:01+09:00 run=20260810-000002 stage=plan model=m tokens=1000 cost=0.03\n"
            "- 2026-08-10T00:00:02+09:00 run=20260810-000003 stage=plan model=m tokens=1000 cost=0.045\n"
            "- 2026-08-10T00:00:03+09:00 run=20260810-000004 stage=plan model=m tokens=1000 cost=0.10\n"
        ))
        write(self.dir, "past-runs.md", (
            "- 2026-08-10T00:00:00+09:00 done run=20260810-000001 branch=loop/x cycles=1\n"
            "- 2026-08-10T00:00:01+09:00 done run=20260810-000002 branch=loop/x cycles=1\n"
            "- 2026-08-10T00:00:02+09:00 done run=20260810-000003 branch=loop/x cycles=1\n"
        ))
        write(self.dir, "known-failures.md", (
            "- 2026-08-10T00:00:03+09:00 run=20260810-000004 verify-fail run=20260810-000004 cycle=1\n"
        ))
        rc, out = metrics.cmd_check_cost(self.dir, "20260810-000003", 1.5)
        self.assertEqual(rc, 0, out)   # 0.045 <= 1.5 x median(0.03, 0.03)
        self.assertIn("median_prior_done=0.03 limit=0.045", out)
        rc, out = metrics.cmd_check_cost(self.dir, "20260810-000004", 3.0)
        self.assertNotEqual(rc, 0, out)  # 0.10 > 3 x median 0.03
        self.assertIn("cost=0.1", out)
        rc, out = metrics.cmd_check_cost(self.dir, "20260810-000002", 2.0)
        self.assertEqual(rc, 0, out)   # only 1 prior done run -> no baseline
        self.assertIn("no baseline", out)
        rc, out = metrics.cmd_check_cost(self.dir, "20260810-999999", 2.0)
        self.assertNotEqual(rc, 0, out)
        self.assertIn("not found", out)

    def test_theater_thresholds(self):
        write(self.dir, "past-runs.md", "".join(
            f"- 2026-08-10T00:00:0{i}+09:00 done run=20260810-00000{i} branch=loop/x cycles=1\n"
            for i in range(1, 5)))
        write(self.dir, "known-failures.md", (
            "- 2026-08-10T00:00:06+09:00 run=20260810-000002 verifier-theater run=20260810-000002 cycle=1\n"
            "- 2026-08-10T00:00:07+09:00 run=20260810-000004 verifier-theater run=20260810-000004 cycle=1\n"
        ))
        rc, out = metrics.cmd_theater(self.dir, 30.0)
        self.assertNotEqual(rc, 0, out)   # 2 of 4 = 50% > 30%
        self.assertIn("theater=2 reviewed_pass=4 rate=50.0%", out)
        rc, out = metrics.cmd_theater(self.dir, 60.0)
        self.assertEqual(rc, 0, out)      # under a raised threshold
        empty = os.path.join(self.dir, "empty")
        os.makedirs(empty)
        rc, out = metrics.cmd_theater(empty, 30.0)
        self.assertEqual(rc, 0, out)      # no entries -> rate=0, exit 0
        self.assertIn("theater=0 reviewed_pass=0 rate=0.0%", out)


if __name__ == "__main__":
    unittest.main()
