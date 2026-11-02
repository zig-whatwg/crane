# Testing: Read the live counters after the test has ended its agent, not inside its window

**Date**: 2026-11-02
**Lesson**: A teardown path that leaks cannot be caught by a test that measures inside its own window: the Crane test runner compares a digest of the process taken before each test with one taken after it, once the test has ended its agent, and its first survey found a Global<Context> leaked by every host agent's end in 243 tests-v8 tests that each passed their own handle checks.

**Why**: Crane's leak tests count handles around the operation they test (context_counter_test, gc_bench's per-call columns), with the agent still alive. That is the right measurement for a per-call leak and the wrong one for the end: what the agent's teardown fails to release is released or leaked after the last count is read. Only a check that runs after the test, against the state before it, sees that - Chromium's base::TestSuite after-test checks, Blink's leak detector reading its instance counters after each test, SpiderMonkey's jsapi-tests asserting at exit.

**What Happened**: Lane tstate1 built tests/test_runner/, the runner every test executable now runs under. Around each test it digests the process: the start-up phase, the hook slots it can read, every lint-global-state inventory variable readable from outside its file, live BrowserScopes, the standalone slab's objects, and the engine's live counters (agents, Global handles by kind, weak-callback records, flag writes). Every suite was run at batch 1 in report mode. Every suite except tests-v8 had zero changes. In tests-v8:

- 243 tests ended with `engine.live_context_globals 0 -> 1` (or more). context_manager.getOrCreate gives each entry its own Global<Context> (`owns_v8_ctx`), and retireEntry disposes it, but `deinit` - the path a host agent's end takes through `cleanupAll` - destroys the entry without disposing it. tests/v8/test_process_test.zig shows the pair: a test that only opens and closes its agent is clean, and the one that also registers its context with the manager is not.
- Six wrapper_cache_gc tests left weak-callback records (0 -> 1000): their mock handles are never collected, so the armed record stayed in the adapter's process-wide map, keyed by an address the next allocation may reuse.
- 42 tests left platform objects in the standalone runtime's slab, and two left Global<Object> handles.

Two harness traps:

- A custom Zig test runner gets a copy of the root module's imports, so it can read the executable's own `dom` and `runtime`. But importing a module the tests never imported makes its root reachable, and src/webidl/root.zig imports `codegen/root.zig` as a file, which is also the `codegen` module's root. tests-codegen stopped compiling ("file exists in modules 'codegen' and 'webidl'") until the runner stopped reading any root whose directory holds another's.
- 265 of the 269 Zig variables in the inventory are private, and a private declaration cannot be read from another file (`@hasDecl` answers false). So the hook table is checkable only as far as its modules expose `isInstalled()`. A swap of one installed hook for another stays invisible until the slots have a readable shape (the integrator's planned Hook(T) with test-only scoped overrides).

**Fix**: tests/test_runner/ (state.zig, globals.zig, runner.zig), wired into every test executable by build.zig's `useCraneTestRunner`. A change is logged with `std.log.err` naming the field and its values, so the test that made it fails by name (`runtime.browsers: 0 -> 1`). `CRANE_TEST_STATE=report` plus `CRANE_TEST_STATE_REPORT_DIR` survey every suite without a rebuild. What the process start makes may appear once, from its initial value. A start left unfinished, or an ended process, is a change.

**Takeaway**: **Measure an end path after the end: diff the process's live counters from before the test to after it has ended its agent, so the test that leaks is named, not the later test that inherits the leak - and only state with a readable shape can be checked this way.**
