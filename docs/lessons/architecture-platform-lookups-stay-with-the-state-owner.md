# Architecture: Platform lookups stay with the state owner

**Date**: 2026-10-26
**Lesson**: A DOM consumer can read host values through callbacks installed by the platform-state owner, without importing that owner's module or retaining its state.

**Why**: A helper's named imports come from its own module graph. The DOM module cannot name HTML's PlatformState merely because an interface implementation can. A relative import is not a substitute for the canonical module, and saving a BrowserPlatform pointer introduces a lifetime obligation.

**What Happened**: The CSS environment provider needed HTML's platform-state lookup. DOM imported html_core, while platform_state was exported only by the full HTML module. The integration also needed host revisions to reach the existing style invalidation hook. Adding another global callback table would raise the global-state ratchet.

**Fix**: Keep the value and revision callbacks in html/platform_state.zig, install them from browser/process.zig at process start, and store their immutable function pointers in the existing DOM style hook record. The DOM provider handles name/arity matching and owned token serialization; the HTML callbacks find the current document's Browser and call the platform protocol. No hook or no BrowserPlatform means absence and revision zero. Headless defaults come from the adapter, not a duplicate DOM table. Test both absence cases, and test a host-only value change against an already cached computed-style object.

**Takeaway**: **Install cross-layer callbacks from the state owner, keep host state with its Browser, and test the revision path separately from initial lookup.**
