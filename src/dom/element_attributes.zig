//! DOM § 4.9 an element's attribute list, as the hook the rest of the engine
//! reaches it through where no IDL member fits.
//!
//! The list lives in the Element impl's state. "Clone a single node" - in the
//! Node impl, an ancestor of Element - must copy it exactly: namespace,
//! prefix, local name and value, with none of the validation or lowercasing
//! that `setAttribute` and `setAttributeNS` apply to script's input, which
//! would reject or alter names the list legitimately holds (`setAttribute`
//! stores "a:b" as a local name; `setAttributeNS(null, "FOO", v)` keeps its
//! case). Node may not call into the Element impl, so the Element impl
//! installs the implementation here in its `init`, which runs before any
//! element exists.
//!
//! lint-impls: hook for Element

const runtime = @import("runtime");

pub const Error = error{ InvalidStateError, OutOfMemory };

/// One attribute of a list. Borrowed from it: valid until the list changes.
pub const Attribute = struct {
    namespace: ?[]const u8,
    prefix: ?[]const u8,
    local_name: []const u8,
    value: []const u8,
};

/// What the Element impl supplies.
pub const Implementation = struct {
    at: *const fn (element: *runtime.Instance, index: usize) ?Attribute,
    append: *const fn (element: *runtime.Instance, attribute: Attribute) Error!void,
};

/// Per thread, like the elements it serves.
threadlocal var implementation: ?Implementation = null;

/// Called by the Element impl. Idempotent: every call installs the same one.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// The attribute at `index` in `element`'s attribute list, in order; null
/// past the end, or for a node that is not an element.
pub fn at(element: *runtime.Instance, index: usize) ?Attribute {
    const impl = implementation orelse return null;
    return impl.at(element, index);
}

/// DOM "append an attribute": a new attribute with exactly these fields,
/// appended to `element` - "handle attribute changes" and all.
pub fn append(element: *runtime.Instance, attribute: Attribute) Error!void {
    const impl = implementation orelse return error.InvalidStateError;
    return impl.append(element, attribute);
}

test "without an installed implementation there is nothing to read or append to" {
    const std = @import("std");
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation the calls do not reach it.
    var element: runtime.Instance = undefined;
    try std.testing.expect(at(&element, 0) == null);
    try std.testing.expectError(error.InvalidStateError, append(&element, .{
        .namespace = null,
        .prefix = null,
        .local_name = "a",
        .value = "",
    }));
}
