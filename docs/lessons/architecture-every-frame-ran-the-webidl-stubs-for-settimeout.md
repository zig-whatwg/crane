# Architecture: Every frame ran the WebIDL stubs for setTimeout, rAF and fetch

**Date**: 2026-09-24
**Lesson**: `context_manager` has a hook for exactly this - `setChildContextGlobalsCallback`, "the browser layer sets a callback that registers setTimeout, setInterval, etc." - and nothing had installed it since a sync commit dropped the call on 2026-01-13.

**Why**: The natives live on the top-level global only (`Context.registerCommonGlobals`). A child context gets the WebIDL operations registered as own properties, and `call_setTimeout`, `call_setInterval`, `call_clearTimeout`, `call_fetch`, `call_atob` and `call_btoa` are all `error.NotImplemented`.

**What Happened**: Every iframe and every popup threw NotSupportedError from `setTimeout`. It surfaced through window.open: a popup's `sendCoordinates` calls `setTimeout(..., 300)` before posting to its opener, so the opener waited out the whole test. `crane/iframe-timers.html` is 0/6 at the commit before the fix.

**Fix**: One table, `window_native_globals`, installed on the top-level global and on every child (`registerChildContextGlobals`). Each timer and animation-frame entry carries the realm that made it, so `clearTimeout` and `cancelAnimationFrame` reach only their own window's map. A second hook, `setChildWindowCleanupCallback`, clears a frame's timers and animation frames when its document is destroyed: from `destroyChildContext`, and from the iframe's removing steps, because removal keeps the context alive while script holds the window.

**Takeaway**: **A hook with no installer is a feature with no caller.** Grep the setter's call sites before trusting a `*_callback` that "the browser layer sets".
