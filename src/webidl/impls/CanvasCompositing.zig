//! Implementation for CanvasCompositing interface
//!
//! HTML 4.12.5.1.17: the global alpha and the current compositing and
//! blending operator of whichever 2D context includes this mixin, kept in
//! its drawing state (dom.canvas_2d.DrawingState).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const dom = @import("dom");
const CanvasCompositing = interfaces.CanvasCompositing;

pub const State = CanvasCompositing.State;

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

/// Getter for globalAlpha: "return this's global alpha" (initially 1.0).
pub fn get_globalAlpha(instance: *runtime.Instance) anyerror!f64 {
    return (try stateOf(instance)).drawing.global_alpha;
}

/// Getter for globalCompositeOperation: "return this's current compositing
/// and blending operator" (initially "source-over").
pub fn get_globalCompositeOperation(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = try stateOf(instance);
    return runtime.DOMString.initInterned(dom.canvas_2d.operators[state.drawing.composite_operator]);
}

/// Setter for globalAlpha: "1. If the given value is either infinite, NaN,
/// or not in the range 0.0 to 1.0, then return. 2. Otherwise, set this's
/// global alpha to the given value."
pub fn set_globalAlpha(instance: *runtime.Instance, value: f64) anyerror!void {
    const state = try stateOf(instance);
    if (!std.math.isFinite(value) or value < 0 or value > 1) return; // 1.
    state.drawing.global_alpha = value; // 2.
}

/// Setter for globalCompositeOperation: "1. If the given value is not
/// identical to any of the values that the <blend-mode> or the
/// <composite-mode> properties are defined to take, then return. 2.
/// Otherwise, set this's current compositing and blending operator to the
/// given value."
pub fn set_globalCompositeOperation(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const state = try stateOf(instance);
    for (dom.canvas_2d.operators, 0..) |operator, index| {
        if (std.mem.eql(u8, operator, value.asSlice())) {
            state.drawing.composite_operator = @intCast(index); // 2.
            return;
        }
    }
    // 1.
}
