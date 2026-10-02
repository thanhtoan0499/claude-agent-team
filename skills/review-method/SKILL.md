---
name: review-method
description: Read-only review method - contract gate first, behaviour trace, blocker/major severity, verdict-first report with coverage.
user-invocable: false
---
<!-- Adapted from superpowers/requesting-code-review/code-reviewer (MIT, (c) 2025 Jesse Vincent); structure also informed by this team's repo review skills. Condensed. See THIRD_PARTY.md. -->
# Review method

You find REAL issues. You do not edit, commit, check out another revision in this checkout, or dispatch anyone. Inspect with `git diff`,
`git show`, `git log` and read-only commands. The brief names the diff range, the contract/acceptance criteria and the repo rule files; the repo's
own checklists and rules win for repo rules (map their severities onto the two below).

## Scope
`git diff --stat <base>...HEAD`, then read the diff ONE FILE AT A TIME together with the contract section that governs it. Never swallow a huge
diff at once; use a whole-picture pass only for a narrow question over 2-3 files. Every changed file is read: no sampling. Over ~50 files: say so
and review in passes by subtree. Skip lockfiles and generated files, and say which.

## Order
1. **Contract gate (first).** Table `AC-n -> implementing file:line -> covering test`. An AC with no implementation, or code that serves no AC, is a
   finding. A change that matches a contract that is itself wrong for the business must FAIL here.
2. **Behaviour trace.** For each changed function, find its callers (code-search tool, else grep) and check each still holds. For each new or
   changed condition try: empty/None, duplicates, run twice or retry, concurrent request, another tenant or user. For each value newly stored or
   returned follow source to sink and check it respects visibility filters.
3. **Fix proof.** For a bug fix, confirm a test exercises the faulty path. You cannot revert the fix (read-only): if you cannot confirm it fails on
   the base, report `unverified` and hand it to qa.
4. **Repo rules.** Sweep the diff against the rule files the brief names. Read the rule before flagging it.
5. **Spec silence is not permission.** For behaviour the spec does not mention, judge by what a reasonable user would expect, and grade by the
   effect on that person.

## Severity (two levels, nothing else is reported)
- **blocker**: a concrete input leads to a wrong result, crash, data loss or cross-tenant/user exposure; an AC unmet; a rule marked mandatory is
  violated; a test the change breaks; a fix that is not proven. Every blocker states the input and the wrong result.
- **major**: should be fixed but does not fail the verdict (missing negative test, fragile design, unclear error).
- Style, naming, praise and "consider" remarks are dropped. A suspected blocker you can neither confirm nor refute stays a blocker titled
  `(unverified)` with what would settle it. Problem already on the base branch: not a blocker; mention once as `pre-existing`
  (check `git show <base>:<file>`; "introduced" means absent on base, present at HEAD).

## Report
```
VERDICT: PASS|FAIL|BLOCKED          (FAIL if any blocker; never PASS for something you did not check)
Coverage: files read n/n | rules swept: <files> | contract rows n/n | not run: <what, why>
Declined to judge: <behaviour you set aside as out of scope, one line each with the reason, or "none">
blocker | file:line | issue; input -> wrong result | fix
major   | file:line | issue | fix
evidence: <command -> exit code, counts>
```
On FAIL name who must fix each blocker (backend, frontend, qa, or the contract itself) so the master re-dispatches only that owner.
