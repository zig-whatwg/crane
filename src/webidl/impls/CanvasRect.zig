//! Implementation for CanvasRect interface
//!
//! HTML 4.12.5.1.14: clearRect, fillRect and strokeRect on the output
//! bitmap of whichever 2D context includes this mixin (dom.canvas_2d).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasRect = interfaces.CanvasRect;
const dom = @import("dom");

pub const State = CanvasRect.State;

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

/// The 2D context's state; an InvalidStateError for one whose state is gone.
fn stateOf(instance: *runtime.Instance) !*dom.canvas_2d.Context2D {
    return dom.canvas_2d.stateOf(instance) orelse error.InvalidStateError;
}

fn finite(values: [4]f64) bool {
    for (values) |value| if (!std.math.isFinite(value)) return false;
    return true;
}

/// Operation: clearRect (HTML 4.12.5.1.14).
/// 1. "If any of the arguments are infinite or NaN, then return."
/// 2. "Let pixels be the set of pixels in the specified rectangle that also
///    intersect the current clipping region."
/// 3. "Clear the pixels in pixels to a transparent black, erasing any
///    previous image."
pub fn call_clearRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
    const state = try stateOf(instance);
    if (!finite(.{ x, y, w, h })) return;
    dom.canvas_2d.clearRect(state, x, y, w, h);
}

/// Operation: fillRect (HTML 4.12.5.1.14).
/// 1. "If any of the arguments are infinite or NaN, then return."
/// 2. "Paint the specified rectangular area on this's output bitmap, using
///    this's fill style."
pub fn call_fillRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
    const state = try stateOf(instance);
    if (!finite(.{ x, y, w, h })) return;
    dom.canvas_2d.fillRect(state, x, y, w, h);
}

/// Operation: strokeRect (HTML 4.12.5.1.14).
/// 1. "If any of the arguments are infinite or NaN, then return."
/// 2. "Take the result of tracing the path described below, using the
///    CanvasPathDrawingStyles interface's line styles, and fill it with
///    this's stroke style."
pub fn call_strokeRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
    const state = try stateOf(instance);
    if (!finite(.{ x, y, w, h })) return;
    dom.canvas_2d.strokeRect(state, x, y, w, h);
}
