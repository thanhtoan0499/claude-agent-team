---
name: test-gap-analysis
description: Map each acceptance criterion to a test, find behavioural gaps (errors, boundaries, async), report them as blocker or major.
user-invocable: false
---
<!-- Adapted from pr-review-toolkit/pr-test-analyzer (Apache-2.0, Anthropic; changed: condensed, rating scale replaced by blocker/major). See THIRD_PARTY.md. -->
# Test gap analysis

Judge **behavioural** coverage, not line coverage: would the tests fail if the behaviour broke? Be pragmatic: tests that prevent real bugs, not
completeness for its own sake.

## Procedure
1. List the acceptance criteria (AC) from the brief or contract. Read the diff to know what changed.
2. Build the map, one row per AC: `AC-n | implementing file:line | test file::name | covered | weak | gap`.
   `weak` = the test exists but would still pass if the behaviour broke (see the test-quality rules), or only asserts implementation details.
3. Hunt for gaps on every changed branch:
   - error and failure paths, especially ones that could fail silently (swallowed exception, default returned);
   - boundaries: empty, zero, one, max, duplicate, malformed, unauthorised, other tenant/user;
   - negative cases for every validation rule;
   - business branches (each `if` that changes an outcome);
   - async and concurrent behaviour: run twice, retry, race, ordering.
4. Before reporting a gap, check whether a test at another tier already covers it (unit vs api vs integration vs E2E per the repo's rules).
   Do not ask for tests of trivial getters or pure forwarding.
5. For a bug fix: confirm a test fails on the base code. `git stash push -- <source files only>`, run that test, `git stash pop` at once, and confirm
   `git diff --stat` is what it was. A test that passes on base does not prove the fix: report it.

## Severity
- **blocker**: an AC with no test; an untested security, data-loss or error path; a fix test that passes on base; a test that cannot fail.
- **major**: missing negative/boundary/async case for changed logic; tests coupled to implementation so a safe refactor would break them.
- Everything else is dropped, not reported. Never pad with praise.

## Output
Each gap: `blocker|major | file:line (code) | what is untested | the failure it would catch | test to add (name + what it asserts)`.
Start the report with `VERDICT: PASS|FAIL|BLOCKED` and the AC map. A claim of "covered" cites the test name; a test you did not run is
`not run: <reason>`.
