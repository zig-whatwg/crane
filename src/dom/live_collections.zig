//! HTMLCollection's live filters, as the seam other impls create them through.
//!
//! `children` is ParentNode's attribute, but what it returns - "an
//! HTMLCollection collection rooted at this matching only element children" -
//! is a collection HTMLCollection maintains: it re-reads the tree whenever the
//! tree has changed since its last read. ParentNode may not reach into
//! HTMLCollection's impl to set that up, so HTMLCollection installs its filters
//! here when it creates a collection - necessarily before anyone holds one to
//! make live - and ParentNode asks for the one it needs. The same shape as
//! `abort_algorithms.zig`.
//!
//! lint-impls: hook for HTMLCollection

const runtime = @import("runtime");

/// What the HTMLCollection impl supplies.
pub const Implementation = struct {
    /// Make `collection` live over `root`'s element children, in tree order.
    element_children: *const fn (collection: *runtime.Instance, root: *runtime.Instance) void,
};

/// Per thread, like the collections themselves.
threadlocal var implementation: ?Implementation = null;

/// Called by the HTMLCollection impl. Idempotent.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// Make `collection` - just created, empty - the live collection of `root`'s
/// element children.
pub fn elementChildren(collection: *runtime.Instance, root: *runtime.Instance) !void {
    const impl = implementation orelse return error.NotSupported;
    impl.element_children(collection, root);
}

test "elementChildren without an installed implementation reports NotSupported" {
    const std = @import("std");
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation the call does not reach it.
    var object: runtime.Instance = undefined;
    try std.testing.expectError(error.NotSupported, elementChildren(&object, &object));
}
