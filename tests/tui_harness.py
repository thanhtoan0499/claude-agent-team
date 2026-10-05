"""Headless driver for team-tui's curses loop: a fake screen fed a scripted key list, one snapshot per getch().
Shared by tests/test_tui.py and usable by hand: python3 -i tests/tui_harness.py"""

import curses
import importlib.machinery
import importlib.util
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))


def load(path=None):
    path = path or os.path.join(HERE, "..", "bin", "team-tui")
    ld = importlib.machinery.SourceFileLoader("tt", path)
    m = importlib.util.module_from_spec(importlib.util.spec_from_loader("tt", ld))
    ld.exec_module(m)
    return m


for _name in ("curs_set", "use_default_colors", "init_pair"):
    setattr(curses, _name, lambda *a, **k: None)
curses.color_pair = lambda n: n << 8  # like the real one: the pair number lives in bits 8+
curses.COLORS = 256


class Scr:
    """keys: chars / curses codes / -1 (idle tick) / callables (run before the next key, e.g. append to the log).
    Every getch() records the frame drawn since the previous one; running out of keys sends q.
    frames[i] is what was on screen BEFORE key i was handled, so the effect of key i is frames[i + 1]."""

    def __init__(s, h, w, keys):
        s.h, s.w, s.keys = h, w, list(keys)
        s.frames, s.attrs, s.rows, s.row_attr = [], [], {}, {}

    def getmaxyx(s):
        return s.h, s.w

    def timeout(s, ms):
        pass

    def clear(s):
        pass

    def refresh(s):
        pass

    def erase(s):
        s.rows, s.row_attr = {}, {}

    def addstr(s, y, x, text, attr=0):
        row = s.rows.get(y, " " * s.w)
        s.rows[y] = (row[:x] + text + row[x + len(text) :])[: s.w]
        if x == 0:
            s.row_attr[y] = attr

    def getch(s):
        s.frames.append(dict(s.rows))
        s.attrs.append(dict(s.row_attr))
        while s.keys and callable(s.keys[0]):
            s.keys.pop(0)()
        if not s.keys:
            return ord("q")
        k = s.keys.pop(0)
        return ord(k) if isinstance(k, str) else k


def write_log(d, feature, events):
    os.makedirs(os.path.join(d, feature), exist_ok=True)
    with open(os.path.join(d, feature, "events.ndjson"), "a", encoding="utf-8") as fh:
        fh.writelines(json.dumps(e, ensure_ascii=False) + "\n" for e in events)


def ev(i, type="note", body="", **kw):
    return {"ts": f"2026-10-02T09:{i // 60:02d}:{i % 60:02d}Z", "type": type, "from": "master", "body": body, **kw}


def run(tt, d, keys, h=24, w=120):
    scr = Scr(h, w, keys)
    con = tt.open_db(os.path.join(d, "team.db"))
    tt.sync(con, [d])
    tt.ui(scr, con, lambda: [d])
    return scr


def footer(scr, i):
    return scr.frames[i][scr.h - 1].strip()


def body_rows(scr, i):
    return [scr.frames[i].get(r, "") for r in range(1, scr.h - 1)]
