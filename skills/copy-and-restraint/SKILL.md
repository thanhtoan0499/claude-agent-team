---
name: copy-and-restraint
description: Design-system-first restraint and UI copy rules - plain words, specific actions, errors that say what to do, empty states that invite action.
user-invocable: false
---
<!-- Adapted from anthropics/skills/frontend-design (Apache-2.0, Anthropic; changed: the aesthetic-identity push removed, restraint and copy sections kept and reworded). See THIRD_PARTY.md. -->
# Restraint and copy

## Design system first
In an existing product the design system and the brief's own words win. Compose from existing components and tokens; do not invent a palette,
typeface or one-off component. Anything new is flagged as NEW with a reason or raised as a `NEEDS_DECISION`.

## Restraint
- Spend emphasis in one place; cut decoration that serves no purpose.
- Structure carries information: borders, dividers, numbering and labels must encode something. Number items only if the content really is a sequence.
- Motion answers a person's action (opening, confirming, showing what changed). No decorative entrance effects. Respect reduced motion.
- Quality floor on every screen: responsive, visible keyboard focus, accessible contrast, nothing relying on colour alone.

## Copy
Words are design content: they exist to make the screen easier to understand and use.
- Write from the user's view: name things by what they do for the person, not by how the system is built ("Manage notifications", not "Webhook config").
- Active voice, plain verbs, sentence case, no filler. Each text element does one job.
- A button says exactly what happens: "Save changes", not "Submit". An action keeps one name through the flow: the button "Publish" leads to a toast "Published".
- **Errors** say what went wrong and how to fix it, in the interface's voice. They do not apologise and are never vague.
- **Empty states** invite an action and say why it is empty (nothing yet / nothing matches / no access / failed to load).
- Be specific and legible to a new user before being clever.
All strings you propose are catalog keys with every shipped locale filled in; the repo's glossary overrides any wording habit above.
