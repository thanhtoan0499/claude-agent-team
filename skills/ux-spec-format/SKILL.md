---
name: ux-spec-format
description: Format of a UI spec the frontend can build without guessing - flow, component map, state matrix, copy keys, acceptance criteria.
user-invocable: false
---
<!-- Adapted from aditya-ariosity/ux-ui-skills/handoff-to-dev (MIT, (c) 2026 Aditya Sharma). Condensed; telemetry, rollout and design-tool material removed. See THIRD_PARTY.md. -->
# UI spec for hand-off

Specify intent, behaviour, states and verification so implementation needs no hidden product decision. You are read-only: the spec is your report.
Unresolved product, data or security decisions are listed as open decisions (`NEEDS_DECISION`), never disguised as visual notes.

## 1. Scope
Flows included and excluded, platforms and widths, locales, the design-system components and versions to use, permissions and data sources.

## 2. Flow
`Entry -> Preconditions -> User action -> System response -> Branches -> Recovery -> Completion -> Return`. Cover deep link, refresh, back, cancel,
interruption, duplicate submit, expired session and partial completion; say what state is retained.

## 3. Map to the design system (grep the repo for the real components)
`Region | existing component | variant | tokens | content/data | event | gap`. Use existing component and token names, never raw colours or pixel
values. A new component or variant is marked NEW with a reason; no silent one-offs.

## 4. State matrix (the part builders miss most)
Cover each layer on its own: component (hover, focus, disabled, read-only, loading, error, success, expanded), page/task (first use, no data,
draft, blocked, conflict), data (initial load, background refresh, stale, partial, timeout, offline, retry), identity (signed out, expired,
permission missing, record unavailable vs not found). One generic empty state is wrong: valid zero, no filter match, missing data, no permission
and source failure are different states. For each consequential state:
`Trigger | what the user must understand | visible response | semantics and announcement | actions | retained data | exit`.
State the precedence when states overlap (stale data while a refresh fails: keep the data, add the error and retry).

## 5. Responsive and complex content
Per region: priority, what must stay visible, the content/width trigger, layout change, order, overflow. Base it on content, not device names.
Tables: say scroll with sticky identity column, prioritised columns or row detail (do not auto-collapse a comparison table into cards). Forms:
field order, grouping, error summary, saved progress. Overlays: modal vs drawer vs route, and focus/back behaviour.
Fixtures to design for: shortest and longest labels, translated text (Vietnamese grows), zero/one/many rows, slow/partial/offline/error responses,
permission denied, 200% text size, keyboard-only.

## 6. Copy keys
Every string is a catalog key in each shipped locale, never a literal: `key | en | vi | where | note`. Reuse existing keys first; follow the
repo's glossary. Text the model reads (tool results, agent config) is not translated.

## 7. Acceptance criteria
`AC-n: Given ... when ... then ...`, observable and testable, covering behaviour, states, responsive, accessibility and recovery. Never "matches the
design", "looks right" or "works on mobile". qa maps each AC-n to a test, so number them.

## 8. Open decisions
`Question | why it matters | owner | blocking? | your recommendation and default`. A non-blocking item proceeds on the default and is listed as an assumption.
