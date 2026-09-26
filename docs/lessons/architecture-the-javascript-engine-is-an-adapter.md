# Architecture: Crane's JavaScript engine is an adapter

**Date**: 2026-09-26
**Lesson**: V8 is one implementation of Crane's engine seam, and its types and calls belong in `src/runtime/engines/v8/` only; everything else reaches the engine through runtime's engine-neutral surface and the Engine table.

**Why**: Crane ships where V8 cannot follow cheaply. On desktop and server V8 is statically linked; on iOS Crane will dynamically link the system JavaScriptCore - which runs interpreted there either way, removes V8's binary from the app, and tracks the device's iOS version. That needs a second adapter, and an adapter can only be swapped at a seam the rest of the engine respects.

**What Happened**: The architecture always expected this - `build.zig` has `-Dengine=v8|jsc|quickjs`, the generated interfaces are engine-neutral tables that `V8Interface` consumes, and `engine_interface.zig` defines an Engine function table - but nothing held the seam. Impls, the HTML layer, streams, the browser and the tools reached into V8 directly whenever it was the quickest route: when the lint was written, 4,515 references in 90 files outside the adapter (1,390 per-file keys), led by `src/browser/Context.zig` (717), `src/html/worker_v8_context.zig` (437), `Worker.zig` (269), `HTMLIFrameElement.zig` (182) and `observable_array_exotic.zig` (141). Each such file is work a second adapter has to undo first, and every lane commit was adding more. The same pattern produced the impls-boundary debt: a rule with no check.

**Fix**: "The engine boundary" in AGENTS.md, held by `tools/lint_engine_boundary.zig` in `zig build test` - a per-file, per-name ratchet over `tools/engine_boundary_baseline.txt` that only goes down. New code adds nothing; engine needs become Engine operations named after spec concepts, each with a V8 implementation and an explicit NotSupported entry for the other engines; files are paid down as they are edited. At zero, "v8" leaves the non-adapter modules' imports in build.zig.

**Takeaway**: **An engine reached from everywhere cannot be swapped anywhere; hold the seam with a ratchet before the coupling grows.** Grow the seam from real call sites - name each operation after what the spec does, not after the V8 call that happens to implement it.
