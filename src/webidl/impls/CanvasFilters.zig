//! Implementation for CanvasFilters interface
//!
//! HTML 4.12.5.1.20: the current filter of whichever 2D context includes
//! this mixin, a string in its drawing state. (Filters are not painted yet:
//! dom.canvas_2d.)

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const dom = @import("dom");
const CanvasFilters = interfaces.CanvasFilters;

pub const State = CanvasFilters.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// The 2D context's state; an InvalidStateError for one whose state is gone
/// (or an includer that keeps none - PaintRenderingContext2D, which no paint
/// worklet makes yet).
fn stateOf(instance: *runtime.Instance) !*dom.canvas_2d.Context2D {
    return dom.canvas_2d.stateOf(instance) orelse error.InvalidStateError;
}

/// Getter for filter: "return this's current filter" (initially "none").
pub fn get_filter(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = try stateOf(instance);
    const filter = state.drawing.filter orelse return runtime.DOMString.initInterned(dom.canvas_2d.DrawingState.initial_filter);
    return runtime.DOMString.initDupe(instance.ctx.allocator, filter);
}

/// Setter for filter: "1. If the given value is "none", then set this's
/// current filter to "none" and return. 2. Let parsedValue be the result of
/// parsing the given values as a <filter-value-list>. If any
/// property-independent style sheet syntax like 'inherit' or 'initial' is
/// present, then this parsing must return failure. 3. If parsedValue is
/// failure, then return. 4. Set this's current filter to the given value."
pub fn set_filter(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const state = try stateOf(instance);
    const text = value.asSlice();
    const initial = dom.canvas_2d.DrawingState.initial_filter;
    if (std.mem.eql(u8, text, initial)) return state.drawing.setText(state.allocator, "filter", initial, initial); // 1.
    if (!try dom.canvas_2d.isFilterValueList(state.allocator, text)) return; // 2-3.
    try state.drawing.setText(state.allocator, "filter", text, initial); // 4.
}
