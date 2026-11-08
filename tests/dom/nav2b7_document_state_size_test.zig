//! Document's state is allocated from the state arena
//! (runtime.InstanceRegistry -> arena.create(InternalState)). Its classes were
//! powers of two, and one byte past a class doubled every Document's block
//! (feature queue, PERFORMANCE, 2026-10-18: createHTMLDocument x10,000 went
//! +4.58% when row 76 crossed 2048); lane nav2 batch 7 measured 2168 bytes, in
//! the 4096-byte class. Since lane perf2 batch 5 the classes are exact to 16
//! bytes up to 4 KiB: the block holds the state with less than 16 bytes to
//! spare (2,176), and this pins it there and under 4 KiB.
const std = @import("std");
const runtime = @import("runtime");
const document_state = @import("dom").document_state;

test "Document's state stays inside the arena's exact classes, its block within 16 bytes of it" {
    const size = @sizeOf(document_state.InternalState);
    try std.testing.expect(size <= 4096);
    try std.testing.expect(runtime.ArenaAllocator.heldBytes(size, @alignOf(document_state.InternalState)) - size < 16);
}
