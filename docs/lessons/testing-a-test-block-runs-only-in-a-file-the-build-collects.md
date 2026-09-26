# Testing: A test block runs only in a file the build collects

**Date**: 2026-08-16, updated 2026-09-25
**Lesson**: `zig build test` runs the test blocks of `tests/**/*_test.zig` and of the std-only runner modules listed in `harness_sources` in `build.zig` - nothing else. A `test { }` block anywhere else is never run, and often never compiled.

**Why**: Zig compiles and runs test blocks only in targets made with `b.addTest`, and only in their root module. `tests/wpt_runner/main.zig` links V8 and is built only by `b.addExecutable`, so every test block in it is dead. The same goes for test blocks inside `src/` files that no test target roots.

**What Happened**: twice. The runner's logic kept being extracted into std-only modules (manifest, config, selection, journal, options, discovery, wpt_server, baseline, test_parser, output, stall_watchdog) precisely because their tests in `main.zig` never ran. And on 2026-09-25 `src/runtime/instance_lifecycle.zig`'s own test asserted that `isCleanedUp` holds after `markCleanupComplete`, which the implementation (removing the record) could never satisfy - the test had simply never run, and the behaviour it described was the fix for a double deinit (2dbbe4895).

**Fix**: put tests in `tests/<area>/<topic>_test.zig`. A new std-only runner module goes into `harness_sources`, or its tests silently never run. For a fast loop on one runner module, run it directly with its two imports:

```bash
zig test -lc --dep clock --dep host -Mroot=tests/wpt_runner/journal.zig \
  -Mclock=src/platform/clock.zig -Mhost=src/platform/host.zig --cache-dir /tmp/crane-z16-cache
```

**Takeaway**: **Before trusting a test block, name the build target that runs it. See it fail once - a red test you have never seen go red is not a test.**
