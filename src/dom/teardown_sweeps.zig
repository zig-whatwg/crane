//! Final teardown's sweeps of per-type side tables.
//!
//! An element still alive when the browser ends is never deinit'd one by
//! one: `impls/cleanup.zig` sweeps the node registries wholesale instead. A
//! type that keeps state of its own outside those registries - an input's
//! dirty value, a textarea's raw value - leaks it unless it is swept too. The
//! state is the type's own, so its impl installs the sweep here (once, at
//! process start: its installHooks) and cleanup runs every installed sweep; cleanup never imports
//! the type.
//!
//! lint-impls: hook for HTMLInputElement, HTMLTextAreaElement, ProcessingInstruction

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
