# Testing: A dom unit test that reaches an engine operation cannot link

**Date**: 2026-10-04
**Lesson**: The `dom` module's test binary links no JavaScript engine. A test block in a src/dom file that calls a function which (transitively) calls an `engine.*` operation pulls the V8 adapter into analysis and the binary fails to link with hundreds of `undefined symbol: _v8_...` errors - in a test step whose name says nothing about the file.

**Why**: Zig analyses what a test reaches. `engine.traceChild`, `engine.invokeCallbackFunction`, `engine.keepPlatformObjectAlive` resolve to the V8 adapter, whose functions call the C++ wrapper; the dom test binary is built without libv8. Other src/dom hook modules keep their tests to pure logic, so nothing had hit it.

**What Happened**: `performance_timeline.zig`'s first unit test called `observe()`, which registers the observer (`keepPlatformObjectAlive`) and queues the observer task (`invokeCallbackFunction` downstream). `zig build test` reported "compile test Debug native 294 errors", all `_v8_` symbols, referenced from `interface.V8Interface`, `conversions`, `protocol`.

**Fix**: Test the pure step alone: the entry-type reduction became `supportedAmong(identifiers)`, tested directly; the engine-reaching paths are covered by WPT and Crane tests. Fake entries for the filter tests are found from the instance with `@fieldParentPtr`, not from a file-scope table (a test struct's `var`s count as global state).

**Takeaway**: **Keep src/dom unit tests to logic that reaches no `engine.*` operation; split the pure step out and test it, and read "N undefined _v8_ symbols" in a dom test step as "a test reached the engine".**
