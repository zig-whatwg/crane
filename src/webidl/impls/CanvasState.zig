//! Implementation for CanvasState interface
//!
//! HTML 4.12.5.1.3: the drawing state stack of whichever 2D context
//! includes this mixin (dom.canvas_2d.Context2D).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const dom = @import("dom");
const CanvasState = interfaces.CanvasState;

pub const State = CanvasState.State;

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

/// Operation: restore - "pop the top entry in the drawing state stack, and
/// reset the drawing state it describes. If there is no saved state, then
/// the method must do nothing."
pub fn call_restore(instance: *runtime.Instance) anyerror!void {
    (try stateOf(instance)).restore();
}

/// Operation: isContextLost - "return this's context lost".
pub fn call_isContextLost(instance: *runtime.Instance) anyerror!bool {
    return (try stateOf(instance)).context_lost;
}

/// Operation: reset - "reset the rendering context to its default state":
/// 1. clear the bitmap to transparent black; 2. empty the current default
/// path (not modelled); 3. clear the drawing state stack; 4. reset the
/// drawing state to its initial values.
pub fn call_reset(instance: *runtime.Instance) anyerror!void {
    const state = try stateOf(instance);
    state.clearBitmap(); // 1.
    state.reset(); // 3-4.
}

/// Operation: save - "push a copy of the current drawing state onto the
/// drawing state stack".
pub fn call_save(instance: *runtime.Instance) anyerror!void {
    try (try stateOf(instance)).save();
}
