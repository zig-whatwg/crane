# Workflow: Zig 0.17's Optimize fields are lowercase, and the old names are declarations

**Date**: 2026-11-11
**Lesson**: In the pinned Zig 0.17, `std.builtin.OptimizeMode` is `std.lang.Optimize` with fields `debug`, `safe`, `fast`, `small`; `.Debug` and `.ReleaseSafe` are deprecated declarations that work only where the result type is known.

**Why**: `.optimize = .ReleaseSafe` and an array of `OptimizeMode` values resolve the name as a declaration literal of the known type. A comparison has no result type for its right side: `mode == .Debug` looks for an enum FIELD and fails.

**What Happened**: build.zig's `if (mode == .Debug)` failed the whole configuration - `error: no field named 'Debug' in enum 'lang.Optimize'` - so every step of that pool job failed before compiling anything, the unrelated ones included (lane tls1). `zig ast-check` and `zig fmt` accept it; only running the build finds it.

**Fix**: Compare with the field (`mode == .debug`), and print a mode with `{t}` knowing it prints `debug` / `safe`.

**Takeaway**: **A build.zig edit is not checked until a build step runs it: run the cheapest step on the pool before queuing a long job on it, and compare optimize modes by their lowercase fields.**
