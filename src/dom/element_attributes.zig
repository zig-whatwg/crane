//! DOM § 4.9 an element's attribute list, as the hook the rest of the engine
//! reaches it through where no IDL member fits.
//!
//! The list is Element's state (its type is `dom.element_data.ElementData`,
//! which the tree reads in place). Every WRITE goes through here, into
//! Element, so that "handle attribute changes" runs for it: the mutation
//! record, the custom element reaction and the attribute change steps.
//! `set` and `remove` are DOM's "set an attribute value" and "remove an
//! attribute by namespace and local name" - the steps HTML's reflection
//! ("set / delete the content attribute", HTML 2.6.1) and other algorithms
//! name - so an algorithm calls them, not the [CEReactions] IDL members,
//! whose generated functions would open a reaction scope of their own inside
//! the outer algorithm (tmp/plans/impls-boundary-design.md 3.1).
//!
//! "Clone a single node" - in the Node impl, an ancestor of Element - must
//! copy the list exactly: namespace,
//! prefix, local name and value, with none of the validation or lowercasing
//! that `setAttribute` and `setAttributeNS` apply to script's input, which
//! would reject or alter names the list legitimately holds (`setAttribute`
//! stores "a:b" as a local name; `setAttributeNS(null, "FOO", v)` keeps its
//! case). An Attr node reads and changes its attribute here, and a
//! NamedNodeMap walks the list by index. None of them may call into the
//! Element impl, so the Element impl installs the implementation here once,
//! at process start (its installHooks).
//!
//! lint-impls: hook for Element
const process_start = @import("process_start.zig");

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
    count: *const fn (element: *runtime.Instance) usize,
    append: *const fn (element: *runtime.Instance, attribute: Attribute) Error!void,
    change: *const fn (element: *runtime.Instance, namespace: ?[]const u8, local_name: []const u8, value: []const u8) Error!void,
    set: *const fn (element: *runtime.Instance, local_name: []const u8, value: []const u8, prefix: ?[]const u8, namespace: ?[]const u8) Error!void,
    remove: *const fn (element: *runtime.Instance, namespace: ?[]const u8, local_name: []const u8) void,
    node_at: *const fn (element: *runtime.Instance, index: usize) Error!?*runtime.Instance,
    existing_node_at: *const fn (element: *runtime.Instance, index: usize) ?*runtime.Instance,
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: ?Implementation = null;

/// Called by Element's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// The attribute at `index` in `element`'s attribute list, in order; null
/// past the end, or for a node that is not an element.
pub fn at(element: *runtime.Instance, index: usize) ?Attribute {
    const impl = implementation orelse return null;
    return impl.at(element, index);
}

/// The number of attributes in `element`'s list; 0 for a non-element.
pub fn count(element: *runtime.Instance) usize {
    const impl = implementation orelse return 0;
    return impl.count(element);
}

/// DOM "append an attribute": a new attribute with exactly these fields,
/// appended to `element` - "handle attribute changes" and all.
pub fn append(element: *runtime.Instance, attribute: Attribute) Error!void {
    const impl = implementation orelse return error.InvalidStateError;
    return impl.append(element, attribute);
}

/// DOM "change an attribute": the one with this namespace and local name,
/// to `value` - "handle attribute changes" and all.
pub fn change(element: *runtime.Instance, namespace: ?[]const u8, local_name: []const u8, value: []const u8) Error!void {
    const impl = implementation orelse return error.InvalidStateError;
    return impl.change(element, namespace, local_name, value);
}

/// "Set an attribute value"'s optional arguments.
pub const SetOptions = struct {
    /// The prefix an attribute made for the value gets; null by default.
    prefix: ?[]const u8 = null,
    /// The attribute's namespace; null by default.
    namespace: ?[]const u8 = null,
};

/// DOM "set an attribute value": change the attribute with this namespace
/// and local name to `value`, or append a new one (with `options.prefix`)
/// when there is none - "handle attribute changes" and all. The setter steps
/// of a reflected content attribute (HTML 2.6.1 "set the content
/// attribute").
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-set-value
pub fn set(element: *runtime.Instance, local_name: []const u8, value: []const u8, options: SetOptions) Error!void {
    const impl = implementation orelse return error.InvalidStateError;
    return impl.set(element, local_name, value, options.prefix, options.namespace);
}

/// DOM "remove an attribute by namespace and local name" (a namespace of ""
/// is null): nothing when there is no such attribute. HTML's "delete the
/// content attribute" of a reflected attribute, with a null namespace.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-remove-by-namespace
pub fn remove(element: *runtime.Instance, namespace: ?[]const u8, local_name: []const u8) void {
    const impl = implementation orelse return;
    impl.remove(element, namespace, local_name);
}

/// The Attr node for the attribute at `index` - the same node every time -
/// or null past the end.
pub fn nodeAt(element: *runtime.Instance, index: usize) Error!?*runtime.Instance {
    const impl = implementation orelse return null;
    return impl.node_at(element, index);
}

/// The Attr node already made for the attribute at `index` - what script was
/// handed - or null when none was (or past the end). Never makes one: the
/// adopt steps set the node document of an element's Attr nodes through this,
/// and adopting a tree must not make an Attr for every attribute in it.
pub fn existingNodeAt(element: *runtime.Instance, index: usize) ?*runtime.Instance {
    const impl = implementation orelse return null;
    return impl.existing_node_at(element, index);
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
    try std.testing.expectError(error.InvalidStateError, set(&element, "a", "", .{}));
    remove(&element, null, "a");
}
