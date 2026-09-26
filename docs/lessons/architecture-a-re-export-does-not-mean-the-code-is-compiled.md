# Architecture: A re-export does not mean the code is compiled

**Date**: 2026-09-21
**Lesson**: `pub const x = @import("y.zig")` does not force semantic analysis of `y.zig`.

**Why**: Zig analyses what is *referenced*, not what is imported. A module can
re-export a namespace, and every declaration inside it stays unanalysed until
something actually calls one. `std.testing.refAllDecls(@This())` does not
recurse into imported namespaces either, so the usual "reference everything"
trick does not close the gap.

**What Happened**: `src/websocket/root.zig` imports and re-exports
`events.zig` and `send_buffer.zig`, and `connection.zig` re-implements
`buffered_amount` inline rather than using `SendBuffer`. So nothing referenced
either file, and **both sat out the entire Zig 0.16 migration** - still calling
`std.ArrayList(T).init(allocator)` - while `zig build` stayed green. Wiring
`tests/websocket/` into the build surfaced 14 compile errors at once, and a
real allocation-size bug in `curl_backend.zig` behind them.

**Fix**: Wire every directory into `zig build test`. An unreferenced module is
untested *and* untypechecked, which are not the same failure but arrive
together.

**Takeaway**: **In a tree with this many re-export roots, "it compiles" means
only "something referenced it".** If you cannot name the test target that
compiles a file, assume it does not compile.
