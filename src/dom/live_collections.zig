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
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

/// What the HTMLCollection impl supplies.
pub const Implementation = struct {
    /// Make `collection` live over `root`'s element children, in tree order.
    element_children: *const fn (collection: *runtime.Instance, root: *runtime.Instance) void,
    /// Make `collection` DOM's "list of elements with class names
    /// `class_names`" for `root` (a non-empty set of classes).
    class_names: *const fn (collection: *runtime.Instance, root: *runtime.Instance, class_names: []const u8) error{OutOfMemory}!void,
    form_controls: *const fn (*runtime.Instance, *runtime.Instance, bool) void,
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: ?Implementation = null;

/// Called by HTMLCollection's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// Make `collection` - just created, empty - the live collection of `root`'s
/// element children.
pub fn elementChildren(collection: *runtime.Instance, root: *runtime.Instance) !void {
    const impl = implementation orelse return error.NotSupported;
    impl.element_children(collection, root);
}

/// Make `collection` - just created, empty - DOM's "list of elements with
/// class names `class_names`" for `root`: live, over `root`'s descendant
/// elements that have every class in the set `class_names` names.
///
/// Spec: https://dom.spec.whatwg.org/#concept-getelementsbyclassname
pub fn elementsWithClassNames(collection: *runtime.Instance, root: *runtime.Instance, class_names: []const u8) !void {
    const impl = implementation orelse return error.NotSupported;
    try impl.class_names(collection, root, class_names);
}

pub fn formControls(collection: *runtime.Instance, root: *runtime.Instance, fieldset: bool) !void {
    (implementation orelse return error.NotSupported).form_controls(collection, root, fieldset);
}

test "elementChildren without an installed implementation reports NotSupported" {
    const std = @import("std");
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation the call does not reach it.
    var object: runtime.Instance = undefined;
    try std.testing.expectError(error.NotSupported, elementChildren(&object, &object));
    try std.testing.expectError(error.NotSupported, elementsWithClassNames(&object, &object, "a"));
}
