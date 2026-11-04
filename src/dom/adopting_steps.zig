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
const hook = @import("hook.zig");
const runtime = @import("runtime");

/// The adopting steps of one node type: given the node, whose node document
/// is already the new one, and the old document (null when it had none). A
/// step for a type `node` is not returns at once.
pub const Steps = *const fn (node: *runtime.Instance, old_document: ?*runtime.Instance) void;

/// The types with adopting steps: the img element (HTML 4.8.4.3.2, "the
/// element's adopting steps are run" is a relevant mutation) - 1 at start
/// today. An install past the bound panics, naming it (hook.List): a type
/// whose steps were dropped would silently never run them.
pub const max_entries = 8;
// process-wide: function pointers element impls install once at process start (process_start.zig), the same for every Browser
var entries: hook.Hook(hook.List(Steps, max_entries)) = .init(.empty);

/// Install `steps`. Idempotent: installing the same steps again writes
/// nothing.
pub fn install(steps: Steps) void {
    const list = entries.installing();
    if (list.contains(steps)) return;
    list.append(steps);
}

/// How many types' steps the process start installed (the start-fits test).
pub fn installedCount() usize {
    return entries.read().len;
}

/// Run every installed type's adopting steps for `node`, adopted from
/// `old_document`.
pub fn run(node: *runtime.Instance, old_document: ?*runtime.Instance) void {
    for (entries.read().slice()) |steps| steps(node, old_document);
}

fn testSteps(_: *runtime.Instance, _: ?*runtime.Instance) void {}
fn otherTestSteps(_: *runtime.Instance, _: ?*runtime.Instance) void {}

test "installing the same adopting steps twice keeps one entry; different steps each get one" {
    const override = entries.overrideForTest(.empty);
    defer override.restore();
    install(&testSteps);
    install(&testSteps);
    try std.testing.expectEqual(@as(usize, 1), entries.read().len);
    install(&otherTestSteps);
    try std.testing.expectEqual(@as(usize, 2), entries.read().len);
    try std.testing.expect(entries.read().items[0] == &testSteps and entries.read().items[1] == &otherTestSteps);
}
