//! Associating a DOMTokenList with an element and an attribute, as the seam
//! code outside DOMTokenList does it through.
//!
//! HTML 2.6.1: the getter of a reflected IDL attribute of type DOMTokenList
//! returns "a DOMTokenList object whose associated element is this and
//! associated attribute's local name is the reflected content attribute
//! name" - DOM's "associated element" and "associated attribute", which no IDL
//! member sets. So DOMTokenList installs the step here when it creates a list
//! - necessarily before anyone holds one to associate - and the generated
//! reflection (`src/webidl/impls/reflection.zig`) creates a list through
//! `interfaces.DOMTokenList.init` and asks for it to be associated. The same
//! shape as `live_collections.zig`.
//!
//! lint-impls: hook for DOMTokenList

const runtime = @import("runtime");

/// What the DOMTokenList impl supplies.
pub const Implementation = struct {
    /// Make `list` - just created, empty - `element`'s token list for its
    /// `local_name` attribute (null namespace): its token set is that
    /// attribute's value parsed, and changing the set updates the attribute.
    associate: *const fn (list: *runtime.Instance, element: *runtime.Instance, local_name: []const u8) anyerror!void,
};

/// Per thread, like the lists themselves.
threadlocal var implementation: ?Implementation = null;

/// Called by the DOMTokenList impl. Idempotent.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// Make `list` - a DOMTokenList just created through its interface, which
/// installed the implementation - `element`'s list for `local_name`. The
/// name is copied.
pub fn associate(list: *runtime.Instance, element: *runtime.Instance, local_name: []const u8) !void {
    const impl = implementation orelse return error.NotSupported;
    try impl.associate(list, element, local_name);
}

test "associate without an installed implementation reports NotSupported" {
    const std = @import("std");
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation the call does not reach it.
    var object: runtime.Instance = undefined;
    try std.testing.expectError(error.NotSupported, associate(&object, &object, "rel"));
}
