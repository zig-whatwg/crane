# Architecture: A setter borrows an `any` and takes a callback - on every path

**Date**: 2026-10-15
**Lesson**: Decide who releases an attribute setter's argument handle by what the conversion and the protocol say about its type, and apply it on the error paths too: a borrowed value goes back to the binding whatever the setter did; a handed-over one belongs to its receiver even when the receiver fails.

**Why**: `v8_FunctionCallbackInfo_GetArgument` allocates a `Global<Value>` for the setter's value, and the binding owns it. Three kinds of type meet it. A copied type (strings, numbers, Instances) was always released. An `any` (`runtime.JSValue`, `?runtime.JSValue`) converts an object to a `.handle` over that very Global, which the impl BORROWS for the call (engine protocol: "A `JSValue` parameter is BORROWED"). A callback (EventHandler) adopts the Global outright: the event handler map keeps it. The setter binding treated the `any` like the callback - "handed over" - so nobody released it: 16 B per assignment for the agent's life. Each kept handle also rooted its object, so every `internals.ariaControlsElements = [el]` rooted its input array for good.

**What Happened**: Codex row 39 (ElementInternals ARIA arrays) made the leak hot, and correctly refused to dispose the borrowed JSValue in the impl. `leaks --atExit` on crane/stl-any-setter-release.html (five loops of 1,000 assignments: ElementInternals arrays, a [LegacyLenientSetter], HTMLElement.hidden, a throwing valueAsDate, a throwing iterable) read 5,002 leaks / 2,783,392 B: 5,000 x 16 B GetArgument plus the 2 startup roots. The operations had the same leak once and were fixed by `releaseAnyArgument` after an audit of 422 `any` parameters; the setters had been left out "until their keepers are read the same way".

The fix had two halves:
1. Read the keepers. All 110 generated `any` setters were classified: 39 [Replaceable] (engine.defineOwnProperty makes its own Global), 6 [LegacyLenientSetter] no-ops, and 65 impl delegations - one keeper that already retains its own hold (ShadowRoot.adoptedStyleSheets), five that borrow through protocol operations (the ElementInternals arrays, HTMLElement.hidden, HTMLInputElement.valueAsDate, Window.opener), and the rest no-ops or NotImplemented stubs.
2. Release on every path. `setterValueIsBorrowed(T)` (an allowlist, `anyHandleIsKeptOnlyAsHandle`) makes the binding never hand such a value over, so its existing `defer` releases it after the setter returned, after it failed, and after a failed conversion.

The same lane looked at a throwing EventHandler setter (review-codex-timing F2: Performance.onresourcetimingbufferfull's NotImplemented stub leaks its function) and found the opposite rule. A type-level "release a callback when the setter fails" is unsafe: EventTarget.setEventHandler takes ownership even when it fails - it releases the handler itself on OutOfMemory, and keeps it in the map when activateEventHandler fails after the store. Releasing it in the binding would free it twice or free it while the map still holds it. Only its InvalidStateError path (no EventTarget state) and the 231 impl stubs that `_ = value; return error.X` drop it, and those are bugs of the receivers.

**Fix**:
- An `any` setter value: borrowed. `setterValueIsBorrowed` in src/runtime/engines/v8/interface.zig, its default (false) pinned in tests/v8/retention_predicate_test.zig, per-call counts in tests/v8/per_call_handle_test.zig. An impl that keeps one takes `engine.retainValue`.
- A callback setter value: taken on every path. A receiver that fails releases what it was handed (as setEventHandler's OOM paths do); a stub that drops it leaks. Fix the receiver, never the binding.
- While there: `throwMemberError` throws nothing over `ExceptionPending`, so an impl's own conversion (an iterator, a toString) reaches script as script's own object.

**Takeaway**: **Ownership of an argument is decided once, by its conversion, and holds on the error path too: release what the callee borrows whatever it returned, and leave what it takes to the taker even when it fails.**
