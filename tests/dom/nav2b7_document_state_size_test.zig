//! Document's state is allocated from the arena's 2048-byte class
//! (runtime.InstanceRegistry -> arena.create(InternalState)); one byte past it
//! doubles every Document's block to 4096 (feature queue, PERFORMANCE,
//! 2026-10-18: createHTMLDocument x10,000 went +4.58% when row 76 crossed it).
//! Lane nav2 batch 7 added `load_aborted`; this pins the class.
const std = @import("std");
const document_state = @import("dom").document_state;

test "Document's state stays inside the arena's 2048-byte class" {
    const size = @sizeOf(document_state.InternalState);
    std.debug.print("document_state.InternalState: {d} bytes\n", .{size});
    try std.testing.expect(size <= 2048);
}
