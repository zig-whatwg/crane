//! Static NodeLists, as the seam other impls fill them through.
//!
//! A labelable element's `labels` is a NodeList of label elements; NodeList
//! is not an ancestor of the elements that return one, so they may not reach
//! into NodeList's impl to fill it. They create the list through its
//! interface - NodeList installs the implementation at process start - and
//! hand it the nodes here. The same shape as
//! `live_collections.zig`.
//!
//! lint-impls: hook for NodeList
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

/// What the NodeList impl supplies.
pub const Implementation = struct {
    /// Make `list` - just created, empty - the static list of `nodes`, in
    /// order, which it holds (src/dom/node_holds.zig). `within`: a node
    /// every one of them is a descendant of (querySelectorAll's receiver),
    /// whose tree's root they share - found once, not once per node.
    set_static: *const fn (list: *runtime.Instance, nodes: []const *runtime.Instance, within: ?*runtime.Instance) anyerror!void,
    labels: *const fn (list: *runtime.Instance, element: *runtime.Instance) anyerror!void,
    named_controls: *const fn (*runtime.Instance, *runtime.Instance, []const u8) anyerror!void,
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: ?Implementation = null;

/// Called by NodeList's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// Make `list` - a NodeList just created, empty - the static list of
/// `nodes`, in order.
pub fn setStatic(list: *runtime.Instance, nodes: []const *runtime.Instance) !void {
    const impl = implementation orelse return error.NotSupported;
    try impl.set_static(list, nodes, null);
}

/// `setStatic`, for nodes that are all descendants of `within`.
pub fn setStaticWithin(list: *runtime.Instance, nodes: []const *runtime.Instance, within: *runtime.Instance) !void {
    const impl = implementation orelse return error.NotSupported;
    try impl.set_static(list, nodes, within);
}

pub fn labels(list: *runtime.Instance, element: *runtime.Instance) !void {
    try (implementation orelse return error.NotSupported).labels(list, element);
}

pub fn namedControls(list: *runtime.Instance, collection: *runtime.Instance, name: []const u8) !void {
    try (implementation orelse return error.NotSupported).named_controls(list, collection, name);
}

test "setStatic without an installed implementation reports NotSupported" {
    const std = @import("std");
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation the call does not reach it.
    var list: runtime.Instance = undefined;
    try std.testing.expectError(error.NotSupported, setStatic(&list, &.{}));
}
