---
name: evidence-before-claims
description: Team rule - no PASS/done claim without a command run this turn; report format for every agent report.
user-invocable: false
---
<!-- Adapted from superpowers/verification-before-completion (MIT, (c) 2025 Jesse Vincent). Condensed; team report contract added. See THIRD_PARTY.md. -->
# Evidence before claims

**No completion or PASS claim without fresh evidence from a command you ran in this turn.** A claim without evidence is
"unknown", never PASS. Violating the letter of this rule violates its spirit.

## Gate (before you write "done", "fixed", "passes", or hand work back)
1. IDENTIFY the command that proves the claim.
2. RUN it in full (not a subset, not a previous run).
3. READ the whole output: exit code, failure count, warnings.
4. Only then claim, and quote the evidence.

| Claim | Needs | Not enough |
|---|---|---|
| Tests pass | test command output, 0 failures | an earlier run, "should pass" |
| Lint / types clean | that tool's own output, 0 errors | a different tool passing |
| Build works | build command, exit 0 | lint passing |
| Bug fixed | the original symptom re-checked, passes | "code changed" |
| Requirement met | line-by-line check against the acceptance criteria | "tests pass" |

A test that guards a fix needs red-green proof: write it, see it pass, revert the fix, see it FAIL, restore, see it pass.
Never use "should", "probably", "seems to" about status. No "Done!" before the evidence is in hand.

## Checking other agents' work
An agent's report of success is a claim. Check the diff (`git diff --stat`, the changed files) and rerun the key command.

## Report contract (every final report)
- qa and reviewer: line 1 is `VERDICT: PASS|FAIL|BLOCKED`. Builders end with the team's `DONE` block.
- Add an `evidence:` block, one line per check: `<command> -> exit <n>, <x> passed / <y> failed`.
- A check you did not run is written `not run: <reason>`. It is never silently omitted and never counted as PASS.
- A red test you saw and did not cause still goes in the report, by name.
- If you cannot verify something and it blocks the work, end with the `NEEDS_DECISION` block instead of guessing.
