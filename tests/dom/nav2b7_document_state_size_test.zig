//! Document's state is allocated from the arena's power-of-two classes
//! (runtime.InstanceRegistry -> arena.create(InternalState)); one byte past a
//! class doubles every Document's block (feature queue, PERFORMANCE,
//! 2026-10-18: createHTMLDocument x10,000 went +4.58% when row 76 crossed
//! 2048). Measured by lane nav2 batch 7: 2168 bytes at 0f7c8a5f49e and with
//! `load_aborted` (the bool fills padding) - already in the 4096-byte class.
//! This pins the class.
const std = @import("std");
const document_state = @import("dom").document_state;

test "Document's state stays inside the arena's 4096-byte class" {
    try std.testing.expect(@sizeOf(document_state.InternalState) <= 4096);
}
