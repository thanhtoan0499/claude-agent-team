#!/usr/bin/env python3
"""Per-frame cost of team-tui on a copy of a real log dir. usage: python3 tests/profile_tui.py <log dir copy>
Prints ms per call for the three things the UI loop does on EVERY keypress: sync, features, timeline."""

import importlib.machinery
import importlib.util
import os
import sys
import time

here = os.path.dirname(os.path.abspath(__file__))
ld = importlib.machinery.SourceFileLoader("tt", os.path.join(here, "..", "bin", "team-tui"))
tt = importlib.util.module_from_spec(importlib.util.spec_from_loader("tt", ld))
ld.exec_module(tt)
d = sys.argv[1]
con = tt.open_db(d)
tt.sync(con, d)


def T(label, fn, n=20):
    t = time.perf_counter()
    for _ in range(n):
        r = fn()
    print(f"{label:46s} {(time.perf_counter() - t) / n * 1000:8.2f} ms")
    return r


T("sync (nothing new)", lambda: tt.sync(con, d))
fs = T("features()", lambda: tt.features(con))
for f in fs:
    n = f["feature"]
    sz = con.execute("select coalesce(sum(length(body)),0) from events where feature=?", (n,)).fetchone()[0]
    T(f"timeline {n[:24]} ({f['n']}ev, {sz}B)", lambda: tt.timeline(con, n, 100))
