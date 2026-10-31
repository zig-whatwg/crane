//! The style engine is embedded by value in Document's state, and Document's
//! instance allocation sits just under a power-of-two size class (2,040 of
//! 2,048 bytes on 2026-10-18; tmp/plans/feature-queue.md, PERFORMANCE): ONE
//! more word crosses into the 4,096-byte class and zeroes the larger block on
//! every document made (createHTMLDocument x10,000 went +4.58% when a field
//! did that). So StyleEngine's size is pinned here.
//!
//! When this fails because StyleEngine grew: do not just update the number.
//! Put the new state in a byte of existing padding (the engine's tail after
//! `resolving` holds the page's color schemes that way), or in the lazily
//! allocated `StyleEngine.Rare` when it is cold - WebKit's DocumentRareData
//! pattern - and measure document creation before and after if the struct
//! really has to grow. When it fails because it shrank, record the smaller
//! size.

const std = @import("std");
const dom = @import("dom");

test "StyleEngine's size is pinned: it is embedded in Document's state" {
    // Zig 0.17's std.ArrayList carries a `pointer_stability` SafetyLock, a
    // word under runtime safety (Debug, ReleaseSafe) and nothing otherwise.
    // StyleEngine holds four lists (owners; Active's sheets, scopes and
    // watched), so a safe build is four words over Crane's own 248 - and
    // Document's state with it (lane zig017port's handoff: the post-port
    // performance analysis measures what that does to the size class).
    try std.testing.expectEqual(@as(usize, 248) + 4 * @sizeOf(std.debug.SafetyLock), @sizeOf(dom.style.StyleEngine));
}
