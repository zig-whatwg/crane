//! The "adopting steps" other specifications define for nodes (DOM 4.2.4,
//! "adopt" step 3.4: "Run the adopting steps with inclusiveDescendant and
//! oldDocument"), run once a node's node document has changed.
//!
//! An element type's adopting steps read and write that type's state, so its
//! impl installs them here, once, at process start (its installHooks), and
//! the DOM's adopt calls them without importing the impl - the shape of
//! `attribute_change_steps.zig`. Each installed step checks the node is its
//! own type and returns otherwise: few types have adopting steps, and the
//! check is a vtable comparison.
//!
//! A template's adopting steps (its contents follow it, HTML 4.12.3) stay in
//! `template_contents.zig`, whose adopt step DOM calls separately.
//!
//! Spec: https://dom.spec.whatwg.org/#concept-node-adopt-ext
//!
//! lint-impls: hook for HTMLImageElement, ShadowRoot
const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");

/// The adopting steps of one node type: given the node, whose node document
/// is already the new one, and the old document (null when it had none). A
/// step for a type `node` is not returns at once.
pub const Steps = *const fn (node: *runtime.Instance, old_document: ?*runtime.Instance) void;

/// The types with adopting steps: the img element (HTML 4.8.4.3.2, "the
/// element's adopting steps are run" is a relevant mutation). The bound stays
/// above the count; an entry dropped here is a type whose steps never run.
const max_entries = 8;
// process-wide: function pointers element impls install once at process start (process_start.zig), the same for every Browser
var entries: [max_entries]Steps = undefined;
// process-wide: the number of `entries` installed at process start, the same for every Browser
var count: usize = 0;

/// Install `steps`. Idempotent: installing the same steps again changes
/// nothing.
pub fn install(steps: Steps) void {
    process_start.assertInstalling();
    for (entries[0..count]) |entry| {
        if (entry == steps) return;
    }
    std.debug.assert(count < max_entries);
    if (count == max_entries) return;
    entries[count] = steps;
    count += 1;
}

/// Run every installed type's adopting steps for `node`, adopted from
/// `old_document`.
pub fn run(node: *runtime.Instance, old_document: ?*runtime.Instance) void {
    for (entries[0..count]) |steps| steps(node, old_document);
}

fn testSteps(_: *runtime.Instance, _: ?*runtime.Instance) void {}
fn otherTestSteps(_: *runtime.Instance, _: ?*runtime.Instance) void {}

test "installing the same adopting steps twice keeps one entry; different steps each get one" {
    const saved_count = count;
    const saved_entries = entries;
    defer {
        count = saved_count;
        entries = saved_entries;
    }
    count = 0;
    install(&testSteps);
    install(&testSteps);
    try std.testing.expectEqual(@as(usize, 1), count);
    install(&otherTestSteps);
    try std.testing.expectEqual(@as(usize, 2), count);
    try std.testing.expect(entries[0] == &testSteps and entries[1] == &otherTestSteps);
}
