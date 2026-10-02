---
name: plan-writing
description: How to write a plan builders can execute with zero context - file map, right-sized tasks, exact interfaces, no placeholders, self-review.
user-invocable: false
---
<!-- Adapted from superpowers/writing-plans (MIT, (c) 2025 Jesse Vincent). Condensed; execution handoff, commits and sub-skill references removed. See THIRD_PARTY.md. -->
# Writing a plan

The builders get your plan and nothing else: no conversation, no context. Write so a skilled engineer who has never seen this repo can execute it.
You are read-only: describe code precisely (signatures, test names, commands), do not write files.

## 1. Scope and constraints
- If the request spans independent subsystems, say so and split it into separate plans, each shippable and testable alone.
- **Global constraints**: the ticket's project-wide requirements (versions, dependency limits, naming and copy rules, platform), one line each, with
  exact values taken verbatim from the ticket or repo rules. Every task implicitly includes them.

## 2. File map first
List every file to create or modify and its one responsibility before listing tasks. Files that change together live together; follow the
existing patterns of the repo (do not restructure unilaterally; propose a split only for a file already unwieldy). Territories of different
owners must not overlap.

## 3. Tasks
A task is the smallest unit that carries its own test cycle and could be accepted or rejected on its own. Fold setup, config and docs into the task
that needs them. For a bug, **task 0 is the failing test that reproduces it**. Each task has:
- **Owner**: backend | frontend | designer | qa.
- **Files**: `Create: path`, `Modify: path:lines`, `Test: path`. This is the builder's TERRITORY.
- **Interfaces**: *Consumes* (exact signatures from earlier tasks) and *Produces* (exact names, parameter and return types that later tasks rely on).
  A builder sees only its own task, so this block is how it learns its neighbours' names.
- **Acceptance**: the ticket's criteria as `AC-n`, each testable.
- **Tests**: the test names and what each asserts, the exact command to run one, and the expected first failure message.
- **Verify**: the command and expected result that proves the task done.
Steps stay small enough that a failure points to one place: no step touches more than 3 files, and "create" and "integrate" are separate.

## 4. No placeholders
Never write: "TBD", "TODO", "implement later", "add appropriate error handling / validation / handle edge cases" without saying which, "write tests
for the above" without naming them, "similar to task N" (repeat it, tasks are read out of order), or a type/function no task defines.

## 5. Self-review before you answer
1. **Spec coverage**: point to a task for every acceptance criterion; list the gaps.
2. **Placeholder scan**: search your plan for the patterns above and fix them.
3. **Type consistency**: names and signatures in later tasks match earlier ones (`clearLayers()` in task 3 is not `clearFullLayers()` in task 7).
4. **Review focus**: list up to five input classes or failure modes the ticket implies but no task's tests exercise (empty, huge, duplicate, other
   tenant, retry), most likely first, and add the test for each to the task that owns the code.
5. Only flag problems that would cause real rework; do not pad.
