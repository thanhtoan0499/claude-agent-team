---
name: stack-checks
description: Reviewer checks for authorisation and injection, async Python/FastAPI/SQL pitfalls, and React/TanStack Query pitfalls.
user-invocable: false
---
<!-- Adapted from awesome-skills/code-review-skill (MIT, (c) 2025 awesome-skills): security, SQL-injection, FastAPI, React references. Condensed. See THIRD_PARTY.md. -->
# Stack checks (apply the parts the diff touches)

The repo's own rule files (named in the brief) are stricter and win. Do not copy example code that commits a transaction inside a handler if the
repo says otherwise.

## Authorisation and data
- **Authenticated is not authorised.** Every read or write by id also scopes by owner/tenant, in the same query (`WHERE id = :id AND tenant = :t`).
  An unpredictable id (UUID) is not access control. Missing scope = **blocker**.
- Errors returned to clients carry no stack, query text or internal ids; secrets, tokens and personal data are never logged.
- **SSRF**: a user-influenced URL is validated at the point of use (allowlist, redirects included), not only when it was saved.
- **Injection**: values are bound parameters, never f-string/`.format`/`%`/concatenation into SQL (`text(f"...")` is the escape hatch to grep for).
  Dynamic identifiers (ORDER BY column, table) need an allowlist, because placeholders bind values only. No `shell=True` with input; no `eval`.

## Python / FastAPI / SQLAlchemy async
- Blocking calls inside `async def` (`requests`, `time.sleep`, sync DB or file I/O) freeze every concurrent request: **blocker** on a hot path.
- A coroutine that is never awaited, or fire-and-forget work with no error handling.
- Separate input and output models; never return the ORM object (leaks fields). Validate at the boundary before the DB write.
- N+1: relationship access inside a loop without eager loading. List endpoints paginated with a cap. Group/count/sum in SQL, not Python loops.
- One request-scoped session via dependency, not a module-level session. Failure paths (4xx/5xx) have tests.

## React 19 / TanStack Query v5
- Effects: dependency array complete; cleanup for subscriptions, timers and requests; no effect to compute derived state (compute in render);
  side effects of a user action belong in the handler. No component defined inside another component.
- An error boundary around Suspense. Large lists virtualised.
- Query keys contain every parameter the query function uses (otherwise changes do not refetch). Set `staleTime` deliberately. v5: `isPending` means
  no data yet, `isLoading` is pending and fetching; `useSuspenseQuery` takes no `enabled`. Mutations invalidate or update the affected keys.
- Do not report memoisation or component size as findings unless there is a measured problem.
