//! Final teardown's sweeps of per-type side tables.
//!
//! A node in its document when its realm ends is torn down by the realm's
//! tree walk, through its own deinit (Node.deinitNodeByType dispatches on
//! the vtable). What reaches the browser's end is what no exit reached: a
//! node removed from its tree while script held no wrapper of it, or whose
//! wrapper was collected while it was still in a tree - nothing frees such an
//! orphan (node lifetime: the tree traced both ways is the fix). By then its
//! realm is gone, so `impls/cleanup.zig` frees the node registries wholesale,
//! never through a deinit, which would read the instance's freed context. A
//! type that keeps state of its own outside those registries installs a sweep
//! here (once, at process start: its installHooks) and cleanup runs every
//! installed sweep; cleanup never imports the type.
//!
//! The sweeps installed, and why (counted at leaks3's tip over the forms,
//! dom/ranges and one-in-four-sample files, 2,881, 2026-10-05):
//! - ProcessingInstruction: an orphaned PI's target (17 freed).
//! - HTMLTextAreaElement, HTMLOptionElement: their state maps fill lazily and
//!   their init frees an entry it finds at the new address, so no entry may
//!   outlive its browser - the allocator its values came from goes with it
//!   (0 entries left at the end: the boundary, not a leak).
//! HTMLInputElement's sweep retired with the vtable dispatch: an input in a
//! document is deinit'd by its tree, and none was left at the end (0 of 0).
//!
//! lint-impls: hook for HTMLTextAreaElement, HTMLOptionElement, ProcessingInstruction

const std = @import("std");
const process_start = @import("process_start.zig");

/// Frees every entry of one type's side table.
pub const Sweep = *const fn () void;

const max_sweeps = 16;
var sweeps: [max_sweeps]Sweep = undefined;
var count: usize = 0;

/// Install `sweep`. Idempotent: the same function installs once.
pub fn install(sweep: Sweep) void {
    process_start.assertInstalling();
    for (sweeps[0..count]) |existing| {
        if (existing == sweep) return;
    }
    if (count == max_sweeps) return;
    sweeps[count] = sweep;
    count += 1;
}

/// Run every installed sweep, in installation order.
pub fn runAll() void {
    for (sweeps[0..count]) |sweep| sweep();
}

var test_sweeps: usize = 0;
fn testSweep() void {
    test_sweeps += 1;
}

test "an installed sweep runs once per runAll, however often it was installed" {
    const saved = count;
    defer count = saved;
    count = 0;
    runAll();
    try std.testing.expectEqual(@as(usize, 0), test_sweeps);
    install(&testSweep);
    install(&testSweep);
    runAll();
    try std.testing.expectEqual(@as(usize, 1), test_sweeps);
}
