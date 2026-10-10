//! Implementation for HTMLTableElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLTableElement = interfaces.HTMLTableElement;
const tables = @import("html").tables;
const dom = @import("dom");

pub const State = HTMLTableElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {
    rows: tables.Collection = .{},
    bodies: tables.Collection = .{},
};

fn internalState(instance: *runtime.Instance) !*InternalState {
    const state = instance.getState(State);
    if (state.own._internal) |internal| return internal;
    const internal = try instance.ctx.allocator.create(InternalState);
    internal.* = .{};
    state.own._internal = internal;
    return internal;
}

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement -> Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to parent class (HTMLElement)
    const instance = try interfaces.HTMLElement.initWithState(allocator, StateType, vtable, ctx);
    // HTMLTableElement has no additional initialization
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.rows.deinit(instance, "rows");
        internal.bodies.deinit(instance, "tBodies");
        instance.ctx.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLTableElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for caption
pub fn get_caption(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    // HTML 4.9.1: the first matching HTML element child, or null.
    return tables.firstChildNamed(instance, "caption");
}

/// Getter for tHead
pub fn get_tHead(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    // HTML 4.9.1: the first matching HTML element child, or null.
    return tables.firstChildNamed(instance, "thead");
}

/// Getter for tFoot
pub fn get_tFoot(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    // HTML 4.9.1: the first matching HTML element child, or null.
    return tables.firstChildNamed(instance, "tfoot");
}

/// Getter for tBodies
pub fn get_tBodies(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return (try internalState(instance)).bodies.get(instance, .bodies, "tBodies");
}

/// Getter for rows
pub fn get_rows(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return (try internalState(instance)).rows.get(instance, .table_rows, "rows");
}

/// Setter for caption
pub fn set_caption(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    // Until the binding emits interface-typed argument brand checks (CE2-M1).
    if (value) |v| if (v.stateAs(interfaces.HTMLTableCaptionElement.State) == null) return error.TypeError;
    // HTML 4.9.1: remove the first existing child, then insert the value.
    try tables.removeFirst(instance, "caption");
    if (value) |child| try tables.insert(instance, child, try interfaces.Node.get_firstChild(instance));
}

/// Setter for tHead
pub fn set_tHead(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    // Until the binding emits interface-typed argument brand checks (CE2-M1).
    if (value) |v| if (v.stateAs(interfaces.HTMLTableSectionElement.State) == null) return error.TypeError;
    // Step 1: validate before removing the old section.
    if (value) |section| if (!tables.isNamed(section, "thead")) return error.HierarchyRequestError;
    // HTML 4.9.1: remove the first existing child, then insert the value.
    try tables.removeFirst(instance, "thead");
    if (value) |child| try tables.insert(instance, child, try tables.headInsertionPoint(instance));
}

/// Setter for tFoot
pub fn set_tFoot(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    // Until the binding emits interface-typed argument brand checks (CE2-M1).
    if (value) |v| if (v.stateAs(interfaces.HTMLTableSectionElement.State) == null) return error.TypeError;
    // Step 1: validate before removing the old section.
    if (value) |section| if (!tables.isNamed(section, "tfoot")) return error.HierarchyRequestError;
    // HTML 4.9.1: remove the first existing child, then insert the value.
    try tables.removeFirst(instance, "tfoot");
    if (value) |child| try tables.insert(instance, child, null);
}

/// Operation: createTFoot
pub fn call_createTFoot(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // HTML 4.9.1 createTFoot, steps 1–4.
    if (try tables.firstChildNamed(instance, "tfoot")) |existing| return existing;
    const child = try tables.createElement(instance, "tfoot");
    errdefer dom.node_creation.destroyUninserted(child);
    try tables.insert(instance, child, null);
    return child;
}

/// Operation: deleteTHead
pub fn call_deleteTHead(instance: *runtime.Instance) anyerror!void {
    // HTML 4.9.1: remove only the first matching child.
    try tables.removeFirst(instance, "thead");
}

/// Operation: createCaption
pub fn call_createCaption(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // HTML 4.9.1 createCaption, steps 1–4.
    if (try tables.firstChildNamed(instance, "caption")) |existing| return existing;
    const child = try tables.createElement(instance, "caption");
    errdefer dom.node_creation.destroyUninserted(child);
    try tables.insert(instance, child, try interfaces.Node.get_firstChild(instance));
    return child;
}

/// Operation: insertRow
pub fn call_insertRow(instance: *runtime.Instance, index: webidl.Opt(i32)) anyerror!*runtime.Instance {
    return tables.insertRow(instance, if (index.wasPassed()) index.value else -1);
}

/// Operation: createTBody
pub fn call_createTBody(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // HTML 4.9.1 createTBody, steps 1–3: insert after the last body,
    // or append when no body exists. Unlike the other creators, always new.
    const body = try tables.createElement(instance, "tbody");
    errdefer dom.node_creation.destroyUninserted(body);
    var child = try interfaces.Node.get_lastChild(instance);
    var before: ?*runtime.Instance = null;
    while (child) |current| : (child = try interfaces.Node.get_previousSibling(current)) {
        if (tables.isNamed(current, "tbody")) {
            before = try interfaces.Node.get_nextSibling(current);
            break;
        }
    }
    try tables.insert(instance, body, before);
    return body;
}

/// Operation: createTHead
pub fn call_createTHead(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // HTML 4.9.1 createTHead, steps 1–4.
    if (try tables.firstChildNamed(instance, "thead")) |existing| return existing;
    const child = try tables.createElement(instance, "thead");
    errdefer dom.node_creation.destroyUninserted(child);
    try tables.insert(instance, child, try tables.headInsertionPoint(instance));
    return child;
}

/// Operation: deleteRow
pub fn call_deleteRow(instance: *runtime.Instance, index: i32) anyerror!void {
    try tables.deleteChild(instance, .table_rows, index);
}

/// Operation: deleteCaption
pub fn call_deleteCaption(instance: *runtime.Instance) anyerror!void {
    // HTML 4.9.1: remove only the first matching child.
    try tables.removeFirst(instance, "caption");
}

/// Operation: deleteTFoot
pub fn call_deleteTFoot(instance: *runtime.Instance) anyerror!void {
    // HTML 4.9.1: remove only the first matching child.
    try tables.removeFirst(instance, "tfoot");
}
