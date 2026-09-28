# Architecture: A realm's end can reach its own end

**Date**: 2026-09-27
**Lesson**: Tearing a realm down frees the objects its wrapper cache holds, and one of them can own the realm - so the teardown re-enters itself, and must be a no-op the second time.

**Why**: Ownership in this engine runs through wrappers. An iframe element wrapped only in its FRAME's realm (`frames[0].frameElement` from the parent makes that wrapper) and removed from the tree is kept by that wrapper alone. When the frame's realm ends, its wrapper cache frees the element; the element's deinit ends its integration; the integration's cleanup is "end the navigable's realm" - the realm already ending.

**What Happened**: `execution-timing/101.html` crashed with SIGABRT (a misaligned load in `v8_Context_DetachGlobal`) in every sweep, and never alone. The prefix bisected to one file before it, `084.html`, which removes a frame it reached through `frames[0].frameElement`. The crash was in the *next* navigation's `Context.deinit`: `destroyWindowRealm(page)` ended its child frame realm, whose `context_manager.removeContext` freed the element, whose `iframeContextCleanup` called `destroyWindowRealm(frame)` again. The inner call found no realm state (the outer had taken it), treated the realm as foreign, and released its context; the outer call's next step read the released handle.

`context_manager.destroyChildContext` had a `destroying` flag for exactly this. The realm migration onto `engine.createWindowRealm`/`destroyWindowRealm` replaced that path and did not carry the guard over.

**Fix**: `destroyWindowRealm` keeps a threadlocal stack of the realms whose end is under way (one node per call, on the call's own stack frame) and returns at once for one already on it (4faa9b94f). Blink's `LocalWindowProxy::DisposeContext` does the same: it returns unless its lifecycle is still `kContextIsInitialized`. The regression test is a `test-browser` case that loads 084's markup and navigates.

**Takeaway**: **Any teardown that frees wrapped objects can be re-entered by one of them. When you replace a teardown path, carry its re-entrancy guard over - and when a crash only happens after another file in a sweep, bisect the prefix before reading the crashing file.**
