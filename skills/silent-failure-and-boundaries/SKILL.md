---
name: silent-failure-and-boundaries
description: Reviewer checklist for swallowed errors and hidden fallbacks, and for mismatches across API/UI/test boundaries.
user-invocable: false
---
<!-- Adapted from pr-review-toolkit/silent-failure-hunter (Apache-2.0, Anthropic; changed: condensed, project-specific names removed, severities remapped). See THIRD_PARTY.md. -->
# Silent failures and boundary mismatches

## A. Silent failures
Find every error-handling spot in the diff: try/except, `.catch`, error callbacks, fallback or default values used on failure, "log and
continue", `?.`/`??`/`or default` that may hide a missing required value, retries, and background tasks. For each, ask:
1. **Logged?** At the right level, with context (operation, ids), so someone can debug it in six months.
2. **Caller sees it?** The user or calling code gets an actionable error (what happened, what to do), not a generic one or nothing.
3. **Specific?** Catches only the expected error type. List what else it could hide (bug, timeout, auth, cancellation).
4. **Fallback justified?** Is it in the spec, and does the caller know it happened? A fallback that masks the problem is a defect.
5. **Propagates / cleans up?** Should it bubble up? Does catching here skip cleanup or leave half-done state?

Patterns to flag: empty catch; `except Exception: pass`/`return None`/`return []`; bare `except:`; `contextlib.suppress` on real work; catch that
only logs then carries on; default returned on error with no log; retry that gives up silently; `asyncio.create_task`/fire-and-forget whose failure
nobody observes; `gather(return_exceptions=True)` or `allSettled` with results unchecked; empty `.catch(() => {})`; a mock, stub or fake reachable
from production code; a test disabled or an error bypassed instead of fixed.
Severity: swallowed error / broad catch that hides failures = **blocker**; poor message or unjustified fallback = **major**; the rest dropped.

## B. Boundary mismatches
The contract is the one oracle. Compare EACH side to the contract (UI code <-> response model <-> implementation <-> tests), never one branch to
another. Matching labels are not a match; read the actual response model.
- **Field names and casing** as serialised (snake vs camel is not converted automatically; check aliases), types, nullability, enum/status values.
- **Wrapped vs bare**: `{ items: [...] }` vs a bare array; pagination fields; envelope on errors.
- **Immediate vs final**: 202/async/streaming terminal states, "awaiting input" vs "complete", a result rendered before the final one.
- **Errors**: status code to UI message mapping; every failure state the API can produce has a UI path.
- **Identifiers and units**: which id a field really carries, timezone, currency, units.
- Tests that re-implement the production logic locally and assert on their own result do not cover the boundary: flag as **blocker**.
A mismatch is a **blocker** (it breaks at runtime). Name the owner: contract (ambiguous or silent), backend, frontend or tests.
