//! HTML §3.2.3, the host's HTMLConstructor steps. The engine's HostHooks
//! contract completes prototype access before entering this non-script call.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const core = @import("html_core");
const dom = @import("dom");
const ce = dom.custom_elements;
const creation = @import("creation.zig");
const driver = @import("driver.zig");

pub fn construct(_: ?*anyopaque, realm: runtime.Context, new_target: runtime.JSValue, interface: []const u8) engine.Error!engine.HTMLConstructed {
    if (!realm.hasEngine()) return error.OperationFailed;
    const record = realm.getRealm() orelse return error.OperationFailed;
    const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return error.OperationFailed));
    const document = interfaces.Window.get_document(window) catch return error.OperationFailed;
    // Steps 2–5. The explicit constructor-map override wins over the current
    // global document's registry, including recursive construction.
    const registry = driver.activeRegistry(realm, new_target) orelse
        (interfaces.Document.get_customElementRegistry(document) catch return error.OperationFailed) orelse
        return error.TypeError;
    const definition = ce.definitionForConstructor(registry, realm, new_target) orelse return error.TypeError;

    // Steps 6–8: the active function object's interface must implement this
    // definition's element, including all aliases of a built-in interface.
    const autonomous = std.mem.eql(u8, definition.name, definition.local_name);
    const expected = if (autonomous) "HTMLElement" else @tagName(core.element_interface.forLocalName(definition.local_name));
    if (!std.mem.eql(u8, interface, expected)) return error.TypeError;

    // Steps 9, 12–13 and 15. The hook performs no script between looking up
    // the entry and marking it. The engine applies its resolved prototype to
    // the returned ordinary wrapper under the HostHooks.htmlConstructor contract.
    if (try definition.takeConstructionElement()) |element| return .{ .upgrading = element };
    const element = creation.createInternal(.{
        .document = document,
        .local_name = definition.local_name,
        .namespace = creation.html_namespace,
        .is_value = if (autonomous) null else definition.name,
    }, .custom, if (autonomous) .autonomous else .appropriate) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.OperationFailed,
    };
    // Step 9.6's scoped registry association is deferred. The definition is
    // independently retained by the element, even after its registry dies.
    ce.setDefinition(element, definition);
    return .{ .created = element };
}
