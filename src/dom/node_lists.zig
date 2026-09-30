//! Static NodeLists, as the seam other impls fill them through.
//!
//! A labelable element's `labels` is a NodeList of label elements; NodeList
//! is not an ancestor of the elements that return one, so they may not reach
//! into NodeList's impl to fill it. They create the list through its
//! interface - NodeList's init installs the implementation, so the list
//! exists before anyone asks - and hand it the nodes here. The same shape as
//! `live_collections.zig`.
//!
//! lint-impls: hook for NodeList

const runtime = @import("runtime");

/// What the NodeList impl supplies.
pub const Implementation = struct {
    /// Make `list` - just created, empty - the static list of `nodes`, in
    /// order.
    set_static: *const fn (list: *runtime.Instance, nodes: []const *runtime.Instance) anyerror!void,
};

/// Per thread, like the lists themselves.
threadlocal var implementation: ?Implementation = null;

/// Called by the NodeList impl. Idempotent.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// Make `list` - a NodeList just created, empty - the static list of
/// `nodes`, in order.
pub fn setStatic(list: *runtime.Instance, nodes: []const *runtime.Instance) !void {
    const impl = implementation orelse return error.NotSupported;
    try impl.set_static(list, nodes);
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
