#!/usr/bin/env python3
"""team-tui: keys (g/G/Home/End, list scrolling), lazy bodies, caching, incremental sync. usage: python3 tests/test_tui.py
Drives the real ui() loop with a fake screen (tests/tui_harness.py)."""

import curses
import os
import re
import sys
import tempfile
import textwrap

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tui_harness as H

tt = H.load()


def fresh():
    tt._seen.clear()
    return tempfile.mkdtemp()


def ok(c, m):
    if not c:
        print("FAIL:", m)
        sys.exit(1)


def pos(s, i):  # position label after key i: "179-200/200 END"
    return H.footer(s, i + 1).split(" |")[0]


def texts(s, i):  # ticket pane text after key i
    return [r[50:].strip() for r in H.body_rows(s, i + 1) if r[50:].strip()]


def selected(s, i):  # the highlighted row of the ticket list after key i
    rows = [y for y, a in s.attrs[i + 1].items() if a >> 8 in (8, 9)]  # color pairs 8 / 9 = the selected row (grey, green when running)
    return s.frames[i + 1][rows[0]] if rows else ""


def ticket_ids(s, i):
    return [int(m.group(1)) for r in s.frames[i + 1].values() if (m := re.search(r"\[bug-(\d+)\]", r))]


# ---- g / G / Home / End inside a ticket: the position label says where you are ----
d = fresh()
H.write_log(d, "bug-1-demo", [H.ev(i, "note", f"line {i}") for i in range(100)])  # 200 timeline lines
s = H.run(tt, d, ["\n", "g", "G", "g", "j", curses.KEY_END, curses.KEY_HOME, "G", "k", "G"])
ok(pos(s, 0) == "179-200/200 END", f"open lands on the end: {pos(s, 0)}")
ok(pos(s, 1) == "1-22/200 TOP", f"g = top: {pos(s, 1)}")
ok(pos(s, 2) == "179-200/200 END" and texts(s, 2)[-1] == "line 99", f"G = end with the last line visible: {pos(s, 2)}")
ok(pos(s, 3) == "1-22/200 TOP", "g again")
ok(pos(s, 4) == "2-23/200", f"j moves one line: {pos(s, 4)}")
ok(pos(s, 5) == "179-200/200 END", "End key = G")
ok(pos(s, 6) == "1-22/200 TOP", "Home key = g")
ok(pos(s, 7) == "179-200/200 END", "G after Home")
ok(pos(s, 8) == "178-199/200", f"k leaves the end: {pos(s, 8)}")
ok(pos(s, 9) == "179-200/200 END", "G returns to the end")
s = H.run(tt, d, ["\n", "g", "\n", "l", curses.KEY_RIGHT])  # re-opening an open ticket must not throw the position away
ok(all(pos(s, i) == "1-22/200 TOP" for i in (1, 2, 3, 4)), "enter/l/right keep the position")

# ---- a new event while idle: follows when at the end, leaves the view alone when scrolled up ----
add = lambda: H.write_log(d, "bug-1-demo", [H.ev(101, "note", "freshly appended")])
s = H.run(tt, d, ["\n", add, -1])
ok(pos(s, 1) == "181-202/202 END" and texts(s, 1)[-1] == "freshly appended", f"at the end it follows: {pos(s, 1)}")
d2 = fresh()
H.write_log(d2, "bug-1-demo", [H.ev(i, "note", f"line {i}") for i in range(100)])
add2 = lambda: H.write_log(d2, "bug-1-demo", [H.ev(101, "note", "freshly appended")])
s = H.run(tt, d2, ["\n", "g", add2, -1])
ok(pos(s, 1) == "1-22/202 TOP" or pos(s, 2) == "1-22/202 TOP", f"scrolled up it stays put: {pos(s, 1)} / {pos(s, 2)}")

# ---- ticket list: g/G; a selection beyond the screen stays visible ----
d = fresh()
for n in range(40):  # newer ts = later number = listed first: bug-1039 ... bug-1000
    H.write_log(d, f"bug-{1000 + n}-t{n}", [H.ev(n, "note", "x")])
s = H.run(tt, d, ["G", "g", "G", "k"], h=12)  # 12 rows: 1 header + 9 tickets + request line + footer
ok("[bug-1000]" in selected(s, 0), f"G selects the last ticket: {selected(s, 0)!r}")
ok(ticket_ids(s, 0) == list(range(1008, 999, -1)), f"window scrolled to the end: {ticket_ids(s, 0)}")
ok("[bug-1039]" in selected(s, 1) and ticket_ids(s, 1) == list(range(1039, 1030, -1)), "g selects the first ticket")
ok("[bug-1001]" in selected(s, 3) and 1001 in ticket_ids(s, 3), "k keeps the selection on screen")
s = H.run(tt, d, ["j"] * 15, h=12)  # walk past the 9th row
ok("[bug-1024]" in selected(s, 14) and 1024 in ticket_ids(s, 14), f"j past the window scrolls it: {selected(s, 14)!r}")
ok(len(ticket_ids(s, 14)) == 9, "window stays 9 rows")

# ---- lazy bodies: long body collapses, o expands only what is on screen, copy/dump stay complete ----
d = fresh()
big = "\n".join(f"row {i}" for i in range(80))
H.write_log(
    d, "bug-2-long", [H.ev(0, "note", "short"), H.ev(1, "worker_done", big, agent_id="a1"), H.ev(2, "note", "tail")]
)
con = tt.open_db(os.path.join(d, "team.db"))
tt.sync(con, [d])
F2 = (d, "bug-2-long")
collapsed = [t.strip() for t, _ in tt.Timeline(F2, 100).update(con)]
full = [t.strip() for t, _ in tt.timeline(con, F2, 100)]
ok("row 19" in collapsed and "row 20" not in collapsed, "preview = first 20 body lines")
ok("… +60 more lines  (o: expand)" in collapsed, "marker counts the hidden source lines")
ok(
    full.count("row 79") == 1 and "row 0" in full and not any("more lines" in t for t in full),
    "full timeline has every row",
)
dump = os.popen(f"TEAM_LOG_DIR={d} python3 {H.HERE}/../bin/team-tui --dump bug-2-long").read()
ok("row 79" in dump and "more lines" not in dump, "--dump prints the whole body")

s = H.run(tt, d, ["\n"], h=30)
ok(pos(s, 0) == "all 26", f"26 lines fit in 28 rows: {pos(s, 0)}")
s = H.run(tt, d, ["\n", "o", "G"], h=30)
ok(pos(s, 1) == "1-28/85 TOP", f"o expands in place, view stays: {pos(s, 1)}")
ok(
    "row 24" in texts(s, 1) and not any("more lines" in t for t in texts(s, 1)),
    "expanded body starts right under its header",
)
ok("row 79" in texts(s, 2) and pos(s, 2).endswith("END"), "G reaches the end of the expanded body")
s = H.run(tt, d, ["\n", "g", "o"], h=10)  # 8 visible rows, marker is below the fold
ok("nothing collapsed on screen" in H.footer(s, 3), f"o without a visible marker says so: {H.footer(s, 3)[-50:]}")
s = H.run(tt, d, ["\n", "O", "O"], h=30)
ok(pos(s, 1) == "1-28/85 TOP" and pos(s, 2) == "all 26", f"O expands all, O again collapses: {pos(s, 1)} / {pos(s, 2)}")

# ---- a keypress wraps nothing and builds no Timeline; an idle tick draws nothing ----
d = fresh()
H.write_log(d, "bug-3-perf", [H.ev(i, "note", "word " * 200) for i in range(300)])
built, wraps = [], []
init, wrap = tt.Timeline.__init__, textwrap.wrap
tt.Timeline.__init__ = lambda self, *a, **k: (built.append(1), init(self, *a, **k))[1]
textwrap.wrap = lambda *a, **k: (wraps.append(1), wrap(*a, **k))[1]
try:
    s = H.run(tt, d, ["\n"] + ["j"] * 60 + ["k"] * 30 + [" ", "b", "g", "G"])
finally:
    tt.Timeline.__init__, textwrap.wrap = init, wrap
ok(len(built) == 1, f"one Timeline for 94 scroll keys, built {len(built)}")
ok(len(wraps) == 300, f"each event wrapped exactly once, at open (got {len(wraps)} wrap calls)")


def addstr_count(keys):
    n, orig = [], H.Scr.addstr
    H.Scr.addstr = lambda self, *a, **k: (n.append(1), orig(self, *a, **k))[1]
    try:
        H.run(tt, d, keys)
    finally:
        H.Scr.addstr = orig
    return len(n)


ok(addstr_count(["\n"] + [-1] * 20) == addstr_count(["\n"]), "20 idle ticks draw nothing")

# ---- incremental sync: only new bytes; follows appends; half-written tail; garbled line; truncated log ----
d = fresh()
H.write_log(d, "bug-4-live", [H.ev(i, "note", f"n{i}") for i in range(5)])
con = tt.open_db(os.path.join(d, "team.db"))
ok(tt.sync(con, [d]) == 5, "first sync ingests 5")
ok(tt.sync(con, [d]) == 0, "second sync ingests nothing")
tl = tt.Timeline((d, "bug-4-live"), 100)
n0 = len(tl.update(con))
H.write_log(d, "bug-4-live", [H.ev(5, "note", "n5")])
ok(
    tt.sync(con, [d]) == 1 and len(tl.update(con)) == n0 + 2,
    "an appended event reaches the existing Timeline (header + body)",
)
p = os.path.join(d, "bug-4-live", "events.ndjson")
count = lambda: con.execute("select count(*) from events").fetchone()[0]
with open(p, "a") as fh:
    fh.write('{"ts":"2026-10-02T09:00:09Z","type":"note","body":"half')
ok(tt.sync(con, [d]) == 0, "half-written tail is not ingested")
with open(p, "a") as fh:
    fh.write('"}\n')
ok(tt.sync(con, [d]) == 1 and count() == 7, "…and is picked up once finished")
with open(p, "a") as fh:
    fh.write('{"ts":"2026-10-02T09:00:10Z","type":"note","body":"no newline"}')
ok(tt.sync(con, [d]) == 1, "complete JSON without a newline is shown")
with open(p, "a") as fh:
    fh.write("\nnot json at all\n" + '{"ts":"2026-10-02T09:00:11Z","type":"note","body":"after garbage"}\n')
ok(tt.sync(con, [d]) == 1 and count() == 9, "garbled line is skipped, the next one is ingested")
ok(
    con.execute("select line from events where body='after garbage'").fetchone()[0] == 10,
    "…and numbering still counts the garbled line",
)
first = open(p).read().splitlines()[0] + "\n"
with open(p, "w") as fh:  # log replaced by a shorter one
    fh.write(first)
ok(tt.sync(con, [d]) == 1 and count() == 1, "truncated log is reindexed")
tt._seen.clear()
ok(tt.sync(tt.open_db(os.path.join(d, "team.db")), [d]) == 0, "a new process resumes after what the DB already holds")

# ---- shared index: every repo's tickets from anywhere, registry, --add, --query, same slug in two repos ----
import subprocess

def sh(cmd, cwd, env_extra=None, ok_rc=(0,)):
    env = {**os.environ, "TEAM_HOME": HOME, **(env_extra or {})}
    env.pop("TEAM_LOG_DIR", None)
    r = subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True)
    ok(r.returncode in ok_rc, f"{cmd} rc={r.returncode}: {r.stderr[-200:]}")
    return r.stdout

TUI = os.path.join(H.HERE, "..", "bin", "team-tui")
HOME = tempfile.mkdtemp()
def mkrepo(name, tickets):
    r = os.path.join(tempfile.mkdtemp(), name); os.makedirs(r)
    subprocess.run(["git", "init", "-q", r], check=True)
    for t, n in tickets:
        H.write_log(os.path.join(r, ".team-log"), t, [H.ev(i, "note", f"{name} {t} {i}", plugin_version="0.1.13") for i in range(n)])
    return r
A = mkrepo("alpha", [("bug-100-same-slug", 3), ("bug-101-only-a", 2)])
B = mkrepo("beta", [("bug-100-same-slug", 4)])
sh(["python3", TUI, "--add", B], "/")
ok(open(os.path.join(HOME, "repos")).read().strip() == os.path.join(B, ".team-log"), "--add registers the repo's .team-log")
out = sh(["python3", TUI, "--dump"], A)
ok(out.count("\n") == 3 and "alpha" in out and "beta" in out and "[bug-101]" in out, f"run in alpha: sees alpha AND beta:\n{out}")
ok(os.path.join(A, ".team-log") in open(os.path.join(HOME, "repos")).read().split(), "the repo you run in is registered automatically")
out = sh(["python3", TUI, "--dump"], tempfile.mkdtemp())  # outside any repo: still shows both
ok("alpha" in out and "beta" in out, "run from a folder that is not a repo still shows every registered repo")
one = sh(["python3", TUI, "--dump", "beta/bug-100-same-slug"], "/")
ok("beta bug-100-same-slug 3" in one and "alpha" not in one and "==" not in one, "repo/ticket selects one timeline")
both = sh(["python3", TUI, "--dump", "bug-100-same-slug"], "/")
ok("== alpha/bug-100-same-slug ==" in both and "== beta/bug-100-same-slug ==" in both, "a slug used in two repos prints both, headed")
nope = subprocess.run(["python3", TUI, "--dump", "nope"], env={**os.environ, "TEAM_HOME": HOME}, cwd="/", capture_output=True, text=True)
ok(nope.returncode != 0 and "no ticket" in nope.stderr, "unknown ticket is an error, not an empty success")
q = sh(["python3", TUI, "--query", "select repo, count(*) n, min(plugin_version) v from events group by repo order by repo"], "/")
ok(q.splitlines() == ["repo\tn\tv", "alpha\t5\t0.1.13", "beta\t4\t0.1.13"], f"--query: {q!r}")
bad = subprocess.run(["python3", TUI, "--query", "delete from events"], env={**os.environ, "TEAM_HOME": HOME}, cwd="/", capture_output=True, text=True)
ok(bad.returncode != 0 and "readonly" in bad.stderr.lower().replace(" ", ""), f"--query cannot write: {bad.stderr[-120:]}")
ok(sh(["python3", TUI, "--query", "select count(*) from events"], "/").split()[-1] == "9", "…and nothing was deleted")
# the index is disposable: delete it, it comes back identical
os.remove(os.path.join(HOME, "team.db"))
ok(sh(["python3", TUI, "--query", "select count(*) from events"], "/").split()[-1] == "9", "team.db rebuilt from the NDJSON files")
# new events from another repo show up in an open TUI on the next tick
scr_d = fresh(); H.write_log(scr_d, "bug-700-live", [H.ev(0, "note", "first")])
extra = tempfile.mkdtemp(); H.write_log(extra, "bug-800-late", [H.ev(1, "note", "second")])
srcs = [scr_d]
s = H.Scr(24, 120, [lambda: srcs.append(extra), -1])
tt.ui(s, tt.open_db(os.path.join(scr_d, "team.db")), lambda: list(srcs))
shown = " ".join(s.frames[-1].values())
ok("[bug-700]" in " ".join(s.frames[0].values()) and "[bug-800]" in shown, "a repo registered while the TUI is open appears on the next tick")

# ---- r: claude --resume <session> in the folder it ran in; refused with a reason otherwise ----
import stat, subprocess
curses.endwin = curses.reset_prog_mode = lambda: None
bindir = tempfile.mkdtemp(); out = os.path.join(bindir, "called")
with open(os.path.join(bindir, "claude"), "w") as fh: fh.write(f'#!/bin/sh\necho "$PWD $*" > {out}\n')
os.chmod(os.path.join(bindir, "claude"), 0o755)
work = tempfile.mkdtemp()
row = dict(src=os.path.join(work, ".team-log"), session="sess-1", cwd=work, st=1, en=1, fe=None, stl=1)
old_path = os.environ["PATH"]; os.environ["PATH"] = bindir + os.pathsep + old_path
ok(tt.resume(row) == "" and open(out).read().split() == [os.path.realpath(work), "--resume", "sess-1"], "r runs claude --resume <session> in the session's folder")
os.remove(out)
ok("running" in tt.resume({**row, "st": 2}) and not os.path.exists(out), "a running ticket is not resumed (its session is live elsewhere)")
ok(tt.resume({**row, "st": 2}, force=True) == "" and os.path.exists(out), "R resumes it anyway")
ok("no session" in tt.resume({**row, "session": None}), "a ticket without a logged session says so")
os.environ["PATH"] = "/nonexistent"
ok("PATH" in tt.resume(row), "no claude binary -> message, not a crash")
os.environ["PATH"] = old_path
d = fresh(); H.write_log(d, "bug-5-old", [H.ev(0, "note", "x")])
s = H.run(tt, d, ["r"])
ok("no session" in H.footer(s, 1), f"r on a ticket without a session: {H.footer(s, 1)!r}")
print("PASS")
