//! The allocation-class pin on Document's state, shared by
//! af2_autofocus_test.zig and leaks6_editing_state_leak_test.zig: Document's
//! instance state must stay in the 2,048-byte allocation class, or every
//! document made zeroes a 4,096-byte block (createHTMLDocument x10,000 went
//! +4.58% when a field did that; tmp/plans/feature-queue.md, PERFORMANCE).

const std = @import("std");

/// The allocation class Document's state is held to.
pub const class_bytes = 2048;

/// The inline std lists Document's state reaches, counted at 98c951c9fec (the
/// Zig 0.17 port). Zig 0.17's std.ArrayList carries `pointer_stability`, a
/// std.debug.SafetyLock: one word per list under runtime safety (Debug,
/// ReleaseSafe) and nothing otherwise (ReleaseFast is unchanged). A FIXED
/// count, so a new list still trips the pin: its own bytes and its lock word
/// are not covered.
///
/// So in Debug and ReleaseSafe builds Document's state is really 2,160 B, in
/// the 4,096-byte class. That cost is not hidden here: it goes to the
/// post-port performance analysis (lane zig017port's handoff), measured with
/// createHTMLDocument's cost page. This pin keeps Crane's OWN layout in the
/// class.
pub const document_state_std_lists = 15;

/// Crane's own layout of `State`: its size, less the std lists' safety lock
/// words under runtime safety; its size as it is without runtime safety.
pub fn ownLayoutBytes(comptime State: type) usize {
    if (!std.debug.runtime_safety) return @sizeOf(State);
    return @sizeOf(State) - document_state_std_lists * @sizeOf(std.debug.SafetyLock);
}
