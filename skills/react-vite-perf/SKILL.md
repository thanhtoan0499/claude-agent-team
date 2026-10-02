---
name: react-vite-perf
description: React performance rules for a Vite SPA - waterfalls, bundle size, re-renders - applied to the code you write or change.
user-invocable: false
---
<!-- Adapted from vercel-labs/agent-skills/react-best-practices (MIT, Vercel; per skill frontmatter). Rules paraphrased and filtered for a client-only SPA. See THIRD_PARTY.md. -->
# React performance for a client-side app

Apply to code you write or change, in your TERRITORY. Highest impact first. Fix on a hot path or when measured; do not micro-optimise untouched
code. Server components, SSR/hydration and framework-specific rules do not apply to this app.

## 1. Waterfalls (biggest win)
- Independent requests run in parallel (`Promise.all`, parallel queries), never one `await` after another.
- Move an `await` into the branch that needs it; check cheap synchronous conditions before awaiting a flag or remote value.

## 2. Bundle size
- Heavy components and routes load lazily (`React.lazy` + `Suspense`); load a module only when its feature is activated.
- Analytics and logging load after first render. Preload a lazy chunk on hover or focus of the control that needs it.
- Import directly from a library's subpath when a barrel pulls in the whole package (matters most for dev-server speed).

## 3. Client data
- One cache for server state (the repo's query library): same key = one request. Do not fetch the same data in several components.
- Register global listeners once; use passive listeners for scroll and touch. Version and minimise what you put in `localStorage`.

## 4. Re-renders
- Derive values during render. An effect that only sets state from props/state is a bug waiting to happen.
- Interaction logic goes in event handlers, not in effects that watch state.
- Never define a component inside another component (it remounts every render).
- Do not subscribe to state you read only inside a callback; read it in the callback.
- Effect dependencies should be primitives; split a hook whose parts depend on different inputs.
- Use the functional form `setX(prev => ...)` for stable callbacks; pass a function to `useState` for expensive initial values.
- Hoist default non-primitive props (`[]`, `{}`) out of the component so memoised children keep working.
- Non-urgent updates: `startTransition` / `useDeferredValue`. Frequent transient values (mouse position, timers): a ref, not state.
- `memo` only to isolate expensive work; skip it for cheap primitives.

## 5. Rendering
- Conditional render with a ternary, not `&&`, when the left side can be `0` or `""` (it renders the text).
- Long lists: `content-visibility: auto` or virtualisation. Hoist static JSX out of the component.
- Use `useTransition` for a pending state instead of a manual loading flag.

## 6. Plain JS (low)
Build a `Map`/`Set` for repeated lookups; combine chained `filter().map()` into one pass; return early; hoist `RegExp` out of loops.

## Report
In your `DONE` block add one line: `perf: <what you applied or "n/a">`. A performance claim needs a measurement or a reasoned hot path.
