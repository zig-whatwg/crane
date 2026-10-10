//! Implementation for HTMLTableSectionElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLTableSectionElement = interfaces.HTMLTableSectionElement;
const tables = @import("html").tables;

pub const State = HTMLTableSectionElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {
    rows: tables.Collection = .{},
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
    // HTMLTableSectionElement has no additional initialization
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.rows.deinit(instance, "rows");
        instance.ctx.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLTableSectionElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for rows
pub fn get_rows(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return (try internalState(instance)).rows.get(instance, .section_rows, "rows");
}

/// Operation: deleteRow
pub fn call_deleteRow(instance: *runtime.Instance, index: i32) anyerror!void {
    try tables.deleteChild(instance, .section_rows, index);
}

/// Operation: insertRow
pub fn call_insertRow(instance: *runtime.Instance, index: webidl.Opt(i32)) anyerror!*runtime.Instance {
    return tables.insertChild(instance, .section_rows, "tr", if (index.wasPassed()) index.value else -1);
}
