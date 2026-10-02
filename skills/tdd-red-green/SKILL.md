---
name: tdd-red-green
description: Test first, watch it fail for the right reason, write minimal code, run the whole suite.
user-invocable: false
---
<!-- Adapted from superpowers/test-driven-development (MIT, (c) 2025 Jesse Vincent). Condensed; human-partner steps replaced by NEEDS_DECISION. See THIRD_PARTY.md. -->
# Test first: red, green, refactor

**No production code without a failing test first.** If you did not watch the test fail, you do not know it tests the right thing.
Applies to features, bug fixes and behaviour changes. A bug fix always starts with a test that reproduces the bug.

Pure config, generated code or a throwaway spike may skip it: write `TDD skipped: <reason>` in your report. If unsure, return `NEEDS_DECISION`.

## Cycle
1. **RED** - one test, one behaviour, a name that says the behaviour, real code (a mock only when unavoidable).
2. **Verify RED** (mandatory) - run only that test with the repo's command (from CLAUDE.md, the Makefile or the brief). It must
   FAIL, not error; with the message you expect; because the behaviour is missing, not because of a typo. Passes at once = you test
   existing behaviour, fix the test. Record `command -> exit code, failure message` in your evidence.
3. **GREEN** - the simplest code that passes. No extra features, no refactor of other code, no "while I'm here".
4. **Verify GREEN** - the test passes AND the project's suite passes in the scope the brief names (the right test tier). A green run
   of your own test is not a green suite. Any failure you see, even one you did not cause, goes in the report by name.
5. **REFACTOR** - only when green; remove duplication, improve names; add no behaviour; stay green.

## Code already written before its test
Do not delete someone's working change. Write the test now, then temporarily revert the production change (`git stash` the source
file only), watch the test fail, restore, watch it pass. That is the same proof.

## When stuck
| Problem | Do |
|---|---|
| Do not know how to test it | Write the API you wish existed, write the assertion first. Still unclear: `NEEDS_DECISION`. |
| Test setup is huge | Extract helpers; still huge means the design is too coupled, say so in the report. |
| Must mock everything | Code is too coupled; inject the dependency. |
| Test is hard to write | The interface is hard to use; propose a simpler one. |

## Done checklist
- Every new behaviour has a test and you watched each fail first, for the expected reason.
- Minimal code; whole suite green; output has no new errors or warnings.
- Tests use real code, cover the edge and error cases, and sit in the right tier and file name per the repo rules.
