---
name: ui-guidelines
description: Self-check for UI you build - design system first, accessibility, focus, forms, motion, long content, copy and locale.
user-invocable: false
---
<!-- Adapted from vercel-labs/web-interface-guidelines (MIT, (c) 2025 Vercel Labs). Filtered for an i18n app with a design system. See THIRD_PARTY.md. -->
# UI guidelines (check before you hand back)

**Design system first.** Compose from the repo's existing components and tokens named in your brief; do not invent a primitive or restyle one.
Deviation is a `NEEDS_DECISION`. **Every user-facing string comes from the locale catalog**, in every shipped locale; never a literal in markup,
`aria-label`, `title`, `alt` or a toast. Format dates, numbers and relative times with the app's ACTIVE locale passed explicitly to `Intl`.

## Accessibility and focus
- `<button>` for actions, `<a>`/router link for navigation, never a clickable `<div>`. Semantic HTML before ARIA.
- Icon-only buttons have an accessible name; decorative icons are hidden from assistive tech; images have `alt` (empty if decorative).
- Every form control has a label. Async updates (toasts, validation) are announced (`aria-live="polite"`).
- Every interactive element has a visible focus style, using `:focus-visible`. Never remove the outline without a replacement.
- Overlays: focus moves in, Esc closes, focus returns to the trigger; sticky bars must not hide the focused element.

## Forms
- Correct input `type`/`inputmode` and `autocomplete`; never block paste. Errors inline next to the field and focus the first error on submit.
- Submit stays enabled until the request starts, then shows progress. Warn before leaving with unsaved changes.
- Destructive actions ask for confirmation or offer undo; they are never immediate.

## Motion
Respect `prefers-reduced-motion`. Animate only `transform` and `opacity`; never `transition: all`; animations stay interruptible.

## Long and empty content
Text containers handle long values (truncate/clamp with the repo's truncation component, `min-w-0` on flex children). Handle empty and very long
user input. Lists over ~50 rows are virtualised. Do not read layout (`getBoundingClientRect`, `offsetHeight`) during render.

## State in the URL
Filters, tabs, pagination and expanded panels that a user would share or reload belong in the URL. Links are real links (middle-click works).

## Touch
Gestures (drag, swipe) have a tap/click and keyboard alternative. `autoFocus` only on one primary desktop input.

## Copy
Active voice, specific labels ("Save API key", not "Continue"), numerals for counts, errors say what happened and what to do next. Wording and
casing follow the repo's glossary, not these rules.

## Flag in your own diff
`user-scalable=no`, `onPaste` + `preventDefault`, `outline-none` alone, `transition: all`, click handlers on `div`/`span`, images without width and
height, form fields without labels, hardcoded date/number formats, gesture-only actions.

## Report
In your `DONE` block add: `ui-guidelines: <n fixed | n/a>` and name anything you could not satisfy and why.
