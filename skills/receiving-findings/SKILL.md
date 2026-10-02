---
name: receiving-findings
description: How a builder handles review findings or fix instructions - verify first, one item at a time, push back with evidence.
user-invocable: false
---
<!-- Adapted from superpowers/receiving-code-review (MIT, (c) 2025 Jesse Vincent). Condensed; escalation goes to the master via NEEDS_DECISION. See THIRD_PARTY.md. -->
# Receiving findings

When the master sends review findings, a QA failure or fix instructions: technical evaluation, not agreement.
**Verify before implementing. Ask before assuming.**

## Pattern
1. READ all items without reacting.
2. UNDERSTAND each: restate it in your own words.
3. VERIFY against the code: grep/read; is it true here, and does it break something?
4. EVALUATE: right for THIS codebase and the approved contract?
5. IMPLEMENT one item at a time, test each, check for regressions.
6. REPORT per item.

## Unclear items
If ANY item is unclear, implement none of the items that may be related. Return `NEEDS_DECISION` listing which items you understood and
which you need answered (they may depend on each other).

## Order
Blockers (breakage, security), then simple fixes, then complex ones.

## Push back, with evidence
Push back when the suggestion breaks existing behaviour, the reviewer lacked context, it is unused code (grep for callers first: "nothing calls
this, remove it?"), it is wrong for this stack, or it contradicts the approved contract.
- State the technical reason with file:line or test output. Never silently skip an item.
- Stay inside your TERRITORY. A change outside it is not yours to make: report it, the master rules.

## Style
No thanks, no "you're right", no "great catch". Say what changed: `Fixed: <what> in <file:line>`. If you pushed back and were wrong, say so
in one factual line and fix it.

## Report (one line per item)
`<item> | fixed | disputed | needs decision | <evidence: file:line, command -> exit code, counts>`
Say what failed last time and what you changed this time, so the retry is not a repeat.
