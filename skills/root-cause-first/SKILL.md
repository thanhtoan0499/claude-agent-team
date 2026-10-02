---
name: root-cause-first
description: Find the root cause before any fix; one hypothesis at a time; stop and report after three failed fixes.
user-invocable: false
---
<!-- Adapted from superpowers/systematic-debugging (MIT, (c) 2025 Jesse Vincent). Condensed; stop rule merged with team policy. See THIRD_PARTY.md. -->
# Root cause first

**No fix without a root cause.** Applies to any failing test, bug, build failure or unexpected behaviour, above all when you are
rushed, the fix looks obvious, or a previous fix did not work. Fixing a symptom is a failure, not progress.
If your role may not edit product code (qa), do phases 1-3 and report the root cause, evidence and where the fix belongs.

## Phase 1 - investigate (before any change)
- Read the whole error and stack trace: file, line, code. Do not skim.
- Reproduce reliably with exact steps. Cannot reproduce: gather more data, do not guess.
- Check what changed: `git diff`, `git log -5 -- <path>`, new dependencies, config.
- Several layers (router -> service -> store -> database, or UI -> API -> DB): log what enters and leaves each boundary, run once, see WHERE
  it breaks, then dig into that layer only. For Python use `pytest -s` or stderr output; captured logs can hide it.
- Trace backwards: where does the bad value start, who called with it? Use the code-search tool for callers. Fix at the source.

## Phase 2 - compare
Find similar working code in this repo. List EVERY difference from the broken code, however small. Read a reference completely, not by skimming.

## Phase 3 - one hypothesis
Write "I think X is the cause because Y". Test it with the smallest change, one variable at a time. Wrong: form a new hypothesis;
never stack fixes. "I do not understand X" is a valid thing to report.

## Phase 4 - fix
1. A failing test that reproduces it first (see the test-first rule).
2. One change that addresses the root cause. No bundled refactor.
3. Prove it: the test passes and the suite passes (see the evidence rule).

## Retries and the stop rule
Before every retry write: what failed, what you changed last time, what is different now.
**The same error three times, or three failed fixes: STOP.** Do not try a fourth. Return `NEEDS_DECISION` with: each attempt and what it
changed, what is ruled out, the evidence, and your suspicion about the design (shared state, coupling, a wrong pattern).

## Stop and restart at Phase 1 if you catch yourself
"Quick fix now, investigate later", "just try changing X", several changes at once, "probably X", proposing a fix before tracing the data
flow, or "one more attempt" after two failures.

## No root cause found
If it is truly environmental, timing-dependent or external: document what you investigated, add the right handling (retry, timeout, clear
error) and logging for next time. Most "no root cause" cases are an incomplete investigation, so check twice first.
