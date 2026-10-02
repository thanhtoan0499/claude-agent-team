---
name: plan-completeness
description: Gate a plan for integration gaps (endpoints, auth, state flow, wiring, verification) and freeze the contract with traceability.
user-invocable: false
---
<!-- Distilled from the AIQuinta repo's own plan-quality-gate skill (project-owned); repo-specific checks (proxy, SSO, package aliases) left in the repo. -->
# Plan completeness and the frozen contract

Plans usually say WHAT to build but not HOW it connects, and the rework shows up later as a wrong path, a missing token or a view that never
renders. Run these checks on your own plan before answering; score each PASS / FAIL / N/A. Details specific to this repo (dev proxy, auth mode,
package aliases) come from the repo files named in your brief.

| # | Check | Must be in the plan | FAIL when |
|---|---|---|---|
| 1 | Endpoint contract | method + path, request and response shape, error responses | "connect to the API" with no exact endpoint |
| 2 | Network path | how the caller reaches the service in dev and prod (proxy, CORS, streaming transport) | a new endpoint with no routing/config mention |
| 3 | Auth | token source, where it is attached, expiry; the tenant/owner scoping of every query | an authenticated endpoint with no auth handling |
| 4 | State flow | data entry -> transform -> render target -> loading and error states | "display X" without saying where X comes from |
| 5 | Dependency wiring | import paths, new packages, cross-package aliases | shared code created without how it is imported |
| 6 | Verification | concrete observable steps: URL/command, interaction, expected result | "tests pass" as the only check for a UI change |
| 7 | Step granularity | each step <= 3 files, create separate from integrate, own verification | a step like "implement the page" |

Verdict line: `READY` or `NEEDS REVISION (n failures)`. Fix a FAIL yourself when the repo answers it. A FAIL that only a person can answer becomes
an `OPEN_QUESTIONS` item (blocking or not, with your recommendation and default), never a silent guess.

## The frozen contract (this is what builders and reviewers compare against)
1. **Wire shapes**: every request/response/event with exact field names and casing as serialised, types, nullability, enums, wrapped vs bare
   (`{items: []}` vs `[]`), pagination, and immediate vs final shapes for async or streaming results.
2. **Traceability**: `AC-n -> RULE-n (the behaviour) -> test`. Every AC maps to at least one rule, every rule to at least one test. An AC that
   maps to nothing, or a rule that serves no AC, is a gap to resolve now.
3. **Behaviour table**: for each rule the inputs and expected result, including the boundary and error cases.
4. **Assumptions and open decisions**: what you assumed to proceed, and what only a person can answer, each one line.
5. **Compatibility**: what existing callers or data this changes, and the migration or rollback if it is irreversible.
If the contract is ambiguous or silent on something a consumer needs, say so; do not fill the gap by guessing.
