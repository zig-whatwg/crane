//! Implementation for HTMLTableRowElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLTableRowElement = interfaces.HTMLTableRowElement;
const tables = @import("html").tables;

pub const State = HTMLTableRowElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {
    cells: tables.Collection = .{},
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
    // HTMLTableRowElement has no additional initialization
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.cells.deinit(instance, "cells");
        instance.ctx.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLTableRowElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for rowIndex
pub fn get_rowIndex(instance: *runtime.Instance) anyerror!i32 {
    // HTML 4.9.8: only a table child or a row of a table's direct section.
    var parent = (try interfaces.Node.get_parentNode(instance)) orelse return -1;
    if (parent.stateAs(interfaces.HTMLTableSectionElement.State) != null) {
        parent = (try interfaces.Node.get_parentNode(parent)) orelse return -1;
    }
    if (parent.stateAs(interfaces.HTMLTableElement.State) == null) return -1;
    return tables.indexOf(parent, .table_rows, instance);
}

/// Getter for sectionRowIndex
pub fn get_sectionRowIndex(instance: *runtime.Instance) anyerror!i32 {
    // A direct table child is indexed in table.rows, not just its direct rows.
    const parent = (try interfaces.Node.get_parentNode(instance)) orelse return -1;
    if (parent.stateAs(interfaces.HTMLTableElement.State) != null) return tables.indexOf(parent, .table_rows, instance);
    if (parent.stateAs(interfaces.HTMLTableSectionElement.State) != null) return tables.indexOf(parent, .section_rows, instance);
    return -1;
}

/// Getter for cells
pub fn get_cells(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return (try internalState(instance)).cells.get(instance, .row_cells, "cells");
}

/// Operation: insertCell
pub fn call_insertCell(instance: *runtime.Instance, index: webidl.Opt(i32)) anyerror!*runtime.Instance {
    return tables.insertChild(instance, .row_cells, "td", if (index.wasPassed()) index.value else -1);
}

/// Operation: deleteCell
pub fn call_deleteCell(instance: *runtime.Instance, index: i32) anyerror!void {
    try tables.deleteChild(instance, .row_cells, index);
}
