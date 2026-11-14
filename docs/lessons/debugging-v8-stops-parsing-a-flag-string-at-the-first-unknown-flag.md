# Debugging: V8 stops parsing a flag string at the first flag it does not know

**Date**: 2026-11-10
**Lesson**: `V8::SetFlagsFromString` prints `Error: unrecognized flag <arg>` to stderr and ignores every flag after the first one it does not know. It returns nothing, so the caller cannot tell.

**Why**: `FlagList::SetFlagsFromString` calls `SetFlagsFromCommandLine(&argc, argv, /*remove_flags=*/false)`, and with `remove_flags` false an unknown name sets `return_code = j` and `break`s out of the loop (src/flags/flags.cc:632 at 13.1.203, :771 at 15.7.112.23). V8 deletes a feature's `--js-*` / `--experimental-wasm-*` flag some releases after the feature ships.

**What Happened**: Lane v8up batch 1 checked Crane's `RUNTIME_V8_FLAGS` (src/runtime/engines/v8/snapshot_loader.zig) against V8 15.7.112.23: `--harmony-shadow-realm --js-float16array --experimental-wasm-memory64 --experimental-wasm-exnref --experimental-wasm-jspi`. Only the first still exists (feature-flags.h); the other four shipped and lost their flags. Had `--harmony-shadow-realm` come after `--js-float16array`, the upgrade would have removed ShadowRealm with no error but one stderr line.

**Fix**: When the engine changes, check every flag Crane sets against the new version's flag-definitions.h and feature-flags.h, and drop the retired ones in the same change. Give each flag a test of its EFFECT in a started isolate (ShadowRealm is a function; WebAssembly.Suspending exists), so a flag V8 skipped fails a test instead of a stderr line nobody reads. tests/v8/v8_flags_test.zig today checks only that each flag's TEXT is in the string - it would stay green through exactly this failure.

**Takeaway**: **A V8 flag string is all-or-the-prefix: one retired flag silently drops every flag after it, so test each flag's effect, not the call that set it.**
