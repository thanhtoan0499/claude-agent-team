---
name: a11y-acceptance
description: Accessibility spec per control and per page, the high-frequency WCAG 2.2 items, and testable acceptance wording.
user-invocable: false
---
<!-- Adapted from aditya-ariosity/ux-ui-skills/handoff-to-dev (MIT, (c) 2026 Aditya Sharma): accessibility-qa-and-acceptance reference. Condensed. See THIRD_PARTY.md. -->
# Accessibility in the spec

Prefer native elements. A custom widget follows the matching WAI-ARIA Authoring Practices pattern, and the implemented output is tested.

## Per interactive pattern
`Native element | accessible name | role | state/value | relationships | keyboard model | focus | announcement | touch/pointer | alternative`

## Per page or screen
Title and language; heading and landmark structure and reading order; where focus goes on entry, on a route change, on an error, when an overlay
opens/closes, and on completion; visible instructions tied to fields programmatically; error summary plus inline error and how to correct;
announcement of async status; timeouts and session expiry; reduced motion; zoom, reflow and text scaling.

## High-frequency WCAG 2.2 items to specify
Text and non-text contrast; colour never the only cue; text resize and reflow; keyboard operability, logical order, no trap, visible focus; focus not
hidden by sticky or overlay content; an alternative to dragging; target size (WCAG minimum 24x24 CSS px is not the same as the 44pt / 48dp platform
guidance: state which baseline you use); labels, instructions, error identification and suggestions; no redundant re-entry; accessible
authentication; name, role, state, value and status messages.
Do not claim conformance from a spec. Automated checks catch only part of the barriers; qa tests keyboard-only and screen-reader paths.

## Acceptance wording
Each criterion names the trigger, the observable behaviour, the retained state and the recovery.
- Strong: "Given validation errors after submit, focus moves to the error summary; each summary link focuses its invalid control; valid inputs stay unchanged."
- Strong: "When the modal closes by Save, Cancel or Escape, focus returns to the control that opened it, unless that control no longer exists."
- Weak, never use: "Accessible.", "Passes WCAG.", "Matches the design.", "Works with screen readers.", "Responsive on all devices."
