//! HTML §3.2.3, the host's HTMLConstructor steps, in the two parts
//! engine.HostHooks.htmlConstructor gives: `resolve` (steps 2-8) before the
//! engine's Get(NewTarget, "prototype") (steps 10-11), `finish` (step 9, or
//! steps 12, 13 and 15) after it - so a prototype getter runs after the
//! checks, as the spec orders them. Neither part runs script.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const core = @import("html_core");
const dom = @import("dom");
const ce = dom.custom_elements;
const creation = @import("creation.zig");
const driver = @import("driver.zig");

/// What an agent's host installs as engine.HostHooks.htmlConstructor.
pub const hooks: engine.HTMLConstructorHooks = .{ .resolve = resolve, .finish = finish };

/// The current global object's associated Document (steps 4 and 9.2).
fn currentDocument(realm: runtime.Context) engine.Error!*runtime.Instance {
    if (!realm.hasEngine()) return error.OperationFailed;
    const record = realm.getRealm() orelse return error.OperationFailed;
    const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return error.OperationFailed));
    return interfaces.Window.get_document(window) catch return error.OperationFailed;
}

/// Steps 2-8.
fn resolve(_: ?*anyopaque, realm: runtime.Context, new_target: runtime.JSValue, interface: []const u8) engine.Error!engine.HTMLConstructorResolution {
    const document = try currentDocument(realm);
    // Steps 2-4. The explicit constructor-map override wins over the current
    // global document's registry, including recursive construction.
    const registry = driver.activeRegistry(realm, new_target) orelse
        (interfaces.Document.get_customElementRegistry(document) catch return error.OperationFailed) orelse
        return error.TypeError;
    // Step 5.
    const definition = ce.definitionForConstructor(registry, realm, new_target) orelse return error.TypeError;

    // Steps 6-8: the active function object's interface must implement this
    // definition's element, including all aliases of a built-in interface.
    const autonomous = std.mem.eql(u8, definition.name, definition.local_name);
    const expected = if (autonomous) "HTMLElement" else @tagName(core.element_interface.forLocalName(definition.local_name));
    if (!std.mem.eql(u8, interface, expected)) return error.TypeError;
    return .{ .registry = registry, .definition = definition };
}

/// Step 9, or steps 12, 13 and 15 - after the engine's steps 10-11.
fn finish(_: ?*anyopaque, realm: runtime.Context, resolution: engine.HTMLConstructorResolution, _: []const u8) engine.Error!engine.HTMLConstructed {
    const registry: *runtime.Instance = @ptrCast(@alignCast(resolution.registry));
    const definition: *ce.Definition = @ptrCast(@alignCast(resolution.definition));
    const autonomous = std.mem.eql(u8, definition.name, definition.local_name);
    // Steps 12, 13 and 15, when the construction stack has an entry: no
    // script runs between reading the entry and marking it.
    if (try definition.takeConstructionElement()) |element| return .{ .upgrading = element };
    // Step 9: a new element of the current global's document (9.2), with
    // the definition's local name, registry and is value (9.3-9.9).
    const document = try currentDocument(realm);
    const element = creation.createInternal(.{
        .document = document,
        .local_name = definition.local_name,
        .namespace = creation.html_namespace,
        .is_value = if (autonomous) null else definition.name,
        .registry = .{ .explicit = registry },
    }, .custom, if (autonomous) .autonomous else .appropriate) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.OperationFailed,
    };
    // Step 9.8 sets the element's custom element definition.
    ce.setDefinition(element, definition);
    return .{ .created = element };
}
