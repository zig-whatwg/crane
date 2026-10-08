//! HTML 4.12.3 template ownership; each owner installs only its algorithms.
//! lint-impls: hook for Document, HTMLTemplateElement, DocumentFragment
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const process_start = @import("process_start.zig");

pub const Hooks = struct {
    owner_document: ?*const fn (*runtime.Instance) anyerror!*runtime.Instance = null,
    establish: ?*const fn (*runtime.Instance) anyerror!void = null,
    adopted: ?*const fn (*runtime.Instance) anyerror!void = null,
    set_host: ?*const fn (*runtime.Instance, *runtime.Instance) anyerror!void = null,
    host: ?*const fn (*runtime.Instance) ?*runtime.Instance = null,
};

// process-wide: owner algorithms are identical for every Browser and installed only at process start
var hooks: Hooks = .{};

pub fn install(owned: Hooks) void {
    process_start.assertInstalling();
    inline for (@typeInfo(Hooks).@"struct".fields) |field| {
        if (@field(owned, field.name)) |algorithm| @field(hooks, field.name) = algorithm;
    }
}

pub fn ownerDocument(document: *runtime.Instance) !*runtime.Instance {
    const algorithm = hooks.owner_document orelse return error.InvalidStateError;
    return algorithm(document);
}

/// Creation runs after the node's document has been assigned, before it is
/// exposed to script. Calling this again leaves its existing fragment alone.
pub fn establish(node: *runtime.Instance) !void {
    if (node.stateAs(interfaces.HTMLTemplateElement.State) == null) return;
    const algorithm = hooks.establish orelse return error.InvalidStateError;
    try algorithm(node);
}

/// HTML's adopting steps run after DOM changes the node document.
pub fn adopted(node: *runtime.Instance) !void {
    if (node.stateAs(interfaces.HTMLTemplateElement.State) == null) return;
    const algorithm = hooks.adopted orelse return error.InvalidStateError;
    try algorithm(node);
}

pub fn setHost(fragment: *runtime.Instance, element: *runtime.Instance) !void {
    const algorithm = hooks.set_host orelse return error.InvalidStateError;
    try algorithm(fragment, element);
}

pub fn host(fragment: *runtime.Instance) ?*runtime.Instance {
    if (fragment.stateAs(interfaces.ShadowRoot.State) != null)
        return interfaces.ShadowRoot.get_host(fragment) catch null;
    const algorithm = hooks.host orelse return null;
    return algorithm(fragment);
}

/// The parser and fragment serializer target a template's contents, while
/// ordinary DOM appendChild still targets the template element itself.
pub fn insertionTarget(node: *runtime.Instance) !*runtime.Instance {
    if (node.stateAs(interfaces.HTMLTemplateElement.State) != null)
        return interfaces.HTMLTemplateElement.get_content(node);
    return node;
}

test "an absent owner algorithm fails without dereferencing an instance" {
    const std = @import("std");
    const saved = hooks;
    defer hooks = saved;
    hooks = .{};
    var document: runtime.Instance = undefined;
    try std.testing.expectError(error.InvalidStateError, ownerDocument(&document));
    try std.testing.expectError(error.InvalidStateError, setHost(&document, &document));
}
