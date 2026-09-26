# Architecture: Named access on the Window object was dead three ways at once

**Date**: 2026-09-22
**Lesson**: `window.<id>`, a bare `<id>` identifier and `'<id>' in window` never
worked - not in top-level pages, not in iframes - although
`window_properties.zig` implemented WindowProperties, its interceptors and
`Window.getNamedProperty` correctly. Three independent defects each hid it on
its own, so fixing any one showed nothing.

**What Happened**: a four-subtest probe (`tests/wpt/crane/named-access-probe.html`)
and lldb found them in turn:

1. **The chain.** A [Global] object is an immutable prototype exotic object, so
   its [[Prototype]] is fixed at context creation. The snapshot's context is a
   plain `Context::New(isolate)`, so every restored global's prototype is V8's
   placeholder (an object holding only `constructor`, on Object.prototype).
   `SetPrototypeV2(global, Window.prototype)` in Context.zig and
   `context_manager.createChildContext` is refused with `kDontThrow` - no
   exception, no effect - so WindowProperties, inserted after Window.prototype,
   was never on the global's chain. The fix links the PLACEHOLDER (an ordinary
   object) to WindowProperties.
2. **The second child path.** `context_manager` creates child contexts in two
   functions; only `createWindowForExistingBrowsingContext` called
   `insertIntoPrototypeChain`. `createChildContext` - the one iframes take -
   never did.
3. **The name.** `String::WriteUtf8` writes a NUL and COUNTS it in its return
   value. `window_properties.nameToNative` sliced with that count, so every
   lookup searched for `"byId\0"`. `interface.zig` and
   `global_constructor_handler.zig` strip it; `context_manager` had the same
   copy of the bug. `helpers.writtenUtf8` / `helpers.nameToUtf8` are now the one
   place that does it, pinned by `tests/v8/written_utf8_test.zig`.

Two V8 contracts shaped the fix, both read in `jsengines/v8/v8/src/api/api.cc`
rather than guessed: the V1 `GetPrototype()` on a global proxy returns the
HIDDEN JSGlobalObject, and handing that to `SetPrototypeV2` is a CHECK failure
(`from_javascript implies !i::IsJSGlobalObject(*self)`), so the FFI gained
`v8_Object_GetPrototypeV2`.

**What it uncovered, not fixed**: linking the placeholder to Window.prototype
instead of WindowProperties made EVERY page error before its first script.
Setting `self` on the global walked to Window.prototype's `self` accessor, whose
setter dispatched to `MethodCallback("call_pauseTransformFeedback")` - a WebGL2
method - and threw NotEnoughArguments. Window.prototype's accessors are
mis-wired after a snapshot restore (a template or external-reference mismatch).
It went unnoticed because no global's chain ever reached Window.prototype.
Consequences today: `Object.getPrototypeOf(window) !== Window.prototype`, and
`window instanceof EventTarget` is still false. Fixing the snapshot's global to
be Window's InstanceTemplate needs those accessors sound first.

Also: `Context.evaluateScript` logged a host script's exception at `debug`, so
the runner reported a bare `error.RuntimeError` for a page that never loaded;
it logs at `warn` now.

**What working named access exposed**: tests that had been failing at their
first `frameW.x` now got further, to `iframe.remove()` followed by
`frameW.length` - a read of state the removal had freed. Two owners held one
`BrowsingContext` with no protocol between them:
`IFrameIntegration.onRemovedFromDocument` freed it, while the child Window
(iframes BORROW their context, `owns_browsing_context = false`) still pointed at
it, and `Window.get_length` panicked in an `@intCast` of a poisoned child
count. The fix: `BrowsingContext.discard` closes it, detaches it and drops
its children - so a held window reads `closed` true and `length` 0, as the
spec says - and, if a Window was ever active in it, RETIRES it instead of
freeing it; `freeRetired` frees the list at browser teardown, after the last
Window. The first attempt made the Window the new owner and had `Window.deinit`
read the context to decide - which reintroduced the bug from the other side:
a Window that outlives a context it borrows (browser teardown, a context
`cleanupRealmContext` skipped) then READ freed memory, and a sweep crashed in
unrelated places later in the process. A Window never touches a context it
does not own; retirement needs no reader to be told anything. Separately,
`destroyChildContext` now clears internal field 0 on the child's global and
WindowProperties (`window_properties.detachWindow`) before freeing the Window,
and WindowProperties no longer falls back to the CURRENT context's window when
its own field is empty - that would answer `frameW.x` from the parent.

The same sweep also moved `closed-attribute.window.js` and
`navigated-named-objects.window.js` from OK to TIMEOUT, and neither is a
regression: with `about:blank` as `location.href`, `new URL("support/x.html",
location.href)` had thrown at top level before their async tests were even
registered (2 subtests in 337ms). With real URLs those tests run, and wait on
cross-origin iframe messaging and cross-site navigation that do not exist yet.

**A regression table needs a second column: "was it ever really tested?"**
Check the old record's subtest COUNT before calling an OK -> TIMEOUT a
regression; a file that went from 2 subtests to 6 started running code it
never reached.

**Takeaway**: **When a feature is fully implemented and still does nothing, look
for more than one break in the path.** Each of these three was sufficient on its
own; lldb on the one callback that should have fired, plus a probe asserting the
chain itself, named them in sequence.
