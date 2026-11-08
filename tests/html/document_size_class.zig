//! The size pin on Document's state, shared by af2_autofocus_test.zig and
//! leaks6_editing_state_leak_test.zig: Document's instance state is held to
//! 2,048 bytes (createHTMLDocument x10,000 went +4.58% when a field took it
//! past a power-of-two class; tmp/plans/feature-queue.md, PERFORMANCE).
//!
//! Since lane perf2 batch 5 the state arena's classes are exact to 16 bytes
//! up to 4 KiB, so a byte past 2,048 no longer doubles the block; the bound
//! stays as a budget. Since lane perf2 batch 7 (what few Documents set moved
//! to dom.document_rare_data) the state is under it in every build mode, the
//! std lists' safety lock words included (Zig 0.17's std.ArrayList carries
//! `pointer_stability`, one word per list under runtime safety): the
//! allowance this file made for those words (15 lists at the Zig 0.17 port)
//! is gone, so a new list's lock word counts like any other byte.

/// The bytes Document's state is held to.
pub const class_bytes = 2048;

/// The size `State` is held to `class_bytes` by: all of it, in every build
/// mode.
pub fn ownLayoutBytes(comptime State: type) usize {
    return @sizeOf(State);
}
