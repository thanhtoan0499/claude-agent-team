---
name: test-quality
description: Rules that keep a test honest - name the break it catches, derive expectations independently, never assert on a mock.
user-invocable: false
---
<!-- Adapted from superpowers/test-driven-development/writing-good-tests (MIT, (c) 2025 Jesse Vincent). Condensed. See THIRD_PARTY.md. -->
# Writing tests that can fail

A test exists to catch a specific break. Two principles: every test **names the break it catches**, and every test **exercises the real thing**.
Tiers, file names and markers come from the repo's test rules named in your brief; they win over anything here.

## 1. Name the break
Before the body, answer: *which production change should make this test fail, and is that change a bug or a decision?* Cannot name one: redesign
around an observable behaviour.
- **Derive expected values independently**: literals or hand-checked fixtures, table-driven with literal `want` values. An expectation computed by
  the code under test (or its helpers) passes whatever that code does (a mirror assertion).
- **No change detectors**: if only an intentional decision can fail it (a constant's value, exact wording, private structure), it fires on
  redesign and sleeps through bugs. Test the behaviour that depends on the decision ("a failing call is retried 5 times, the 6th never happens").
- **Test your boundary, not the framework**: the route you register, the query you emit, the payload you produce. Do not test that the framework
  calls your handler. Constructors, getters and forwarding earn a test only if they validate, default, derive, enforce or have side effects.
- Do not assert on source text of a script or config; run it with controlled input and assert outputs, side effects or exit codes.

## 2. Exercise the real thing
- **The mock earns no assertions.** An assertion that passes because the mock exists tests nothing. Assert the real component; if the mock is what
  you check, unmock it or delete the assertion.
- **Mock at the right level**: learn every side effect of the real method first; mock the slow or external operation below it and keep what the
  test depends on real. If unsure, run against the real implementation first and observe.
- **Specific doubles**: when arguments, call counts or order are part of the contract, assert them. Give each branch (success, error, malformed)
  its own fixture so the wrong branch cannot satisfy the expectation. Mirror the complete real data structure, not just the fields you read.
- **Production classes carry production methods only**: cleanup only tests use belongs in test utilities.
- Mock setup bigger than the test, or you cannot say why a mock is needed: switch to an integration test with real components.

## Mutation check (before you finish)
Mentally mutate the production code; for each realistic mutation at least one test must fail: wrong constant or argument, wrong branch,
missing side effect or state change, empty/default return, missing validation for zero, empty, null, unauthorised or malformed input.
A mutation nothing catches means the behaviour is unprotected or the test is tautological: add or fix a test, or report the gap.

## Warning signs
Setup and assertion share one object; the test can fail only by crash or missing selector; it fails on every intentional change but never on
accidental breakage; expected values hidden behind loops or builders; it exists for coverage and checks no outcome; it asserts a `*-mock` id.
