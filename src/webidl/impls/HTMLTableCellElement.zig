//! Implementation for HTMLTableCellElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLTableCellElement = interfaces.HTMLTableCellElement;

pub const State = HTMLTableCellElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

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
    // HTMLTableCellElement has no additional initialization
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // HTMLTableCellElement has no additional cleanup
    // Chain to parent class
    interfaces.HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLTableCellElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for cellIndex
pub fn get_cellIndex(instance: *runtime.Instance) anyerror!i32 {
    // HTML 4.9.9: index among HTML td/th children of the parent tr.
    const parent = (try interfaces.Node.get_parentNode(instance)) orelse return -1;
    if (parent.stateAs(interfaces.HTMLTableRowElement.State) == null) return -1;
    return @import("html").tables.indexOf(parent, .row_cells, instance);
}

/// Getter for scope
pub fn get_scope(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // HTML 4.9.11: reflect scope, limited to only known values.
    // HTML 2.6.1: missing/invalid values return the empty string; recognized
    // keywords return their canonical case, without changing the attribute.
    const attribute = (try interfaces.Element.call_getAttribute(instance, runtime.DOMString.initInterned("scope"))) orelse return runtime.DOMString.initEmpty();
    inline for (.{ "row", "col", "rowgroup", "colgroup" }) |keyword| {
        if (std.ascii.eqlIgnoreCase(attribute.asSlice(), keyword)) return runtime.DOMString.initInterned(keyword);
    }
    return runtime.DOMString.initEmpty();
}

/// Setter for scope
pub fn set_scope(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // HTML 2.6.1 string reflection setter: set the supplied value verbatim.
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("scope"), .{ .domstring = value });
}
