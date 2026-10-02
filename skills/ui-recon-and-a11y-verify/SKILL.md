---
name: ui-recon-and-a11y-verify
description: Verify UI behaviour on a live stack - look before you click, auto-waiting assertions, keyboard and state checks, evidence.
user-invocable: false
---
<!-- Adapted from anthropics/skills/webapp-testing (Apache-2.0, Anthropic; changed: rewritten as a method, scripts and server helper dropped). See THIRD_PARTY.md. -->
# Verifying UI on a live stack

Use the repo's existing E2E setup (test runner, config, how the stack starts) as named in your brief or CLAUDE.md. Extend an existing spec before
creating new tooling. You observe and test; you do not fix product code. Needs a login or credentials you were not given: return `BLOCKED` with
a `NEEDS_DECISION`; never fake it.

## Look before you act
1. Open the page, wait for a visible element or state (not a fixed sleep), then take a screenshot and/or read the rendered DOM.
2. Choose selectors from that rendered state. Prefer role + accessible name, label, then text; test ids last. A role/name locator that fails is
   often an accessibility defect: report it as one.
3. Assert with the runner's auto-waiting assertions. Never wait for "network idle" on an app that streams (SSE/websocket): wait for the element
   or text that proves the state. Never add a bare sleep; a flaky wait is a defect to report.
4. Headless; close the browser; leave no dev server you started running.

## Checks for every changed screen
- **States**: loading, empty, error, disabled and success are each reachable and asserted; an error says what happened and what to do.
- **Keyboard only**: Tab order follows the visual order; focus is visible; Esc closes overlays and focus returns to the trigger; no trap.
- **Names and errors**: every control has an accessible name; a field error is tied to its field and announced.
- **Languages**: if the app has a locale catalog, assert the text in each shipped locale, not only English.
- **Responsive**: check the narrow width the brief names.
- Console errors and failed requests during the flow are findings (capture the URL and status).

## Evidence
Per acceptance criterion: `AC-n | PASS|FAIL | what you did | screenshot path / console excerpt / DOM snippet`.
If a screenshot is unusable (blank, locked display), assert on DOM text, state or the API response and **say you did**.
Never report PASS from a run that errored before the assertion; a crashed run is `BLOCKED`, with the error.
