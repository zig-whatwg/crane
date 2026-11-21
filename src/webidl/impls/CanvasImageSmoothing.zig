//! Implementation for CanvasImageSmoothing interface
//!
//! HTML 4.12.5.1.18: imageSmoothingEnabled and imageSmoothingQuality of
//! whichever 2D context includes this mixin, in its drawing state.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const dom = @import("dom");
const CanvasImageSmoothing = interfaces.CanvasImageSmoothing;

pub const State = CanvasImageSmoothing.State;

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

/// Getter for imageSmoothingEnabled: "on getting, must return the last
/// value it was set to" (initially true).
pub fn get_imageSmoothingEnabled(instance: *runtime.Instance) anyerror!bool {
    return (try stateOf(instance)).drawing.image_smoothing_enabled;
}

/// Getter for imageSmoothingQuality: "on getting, must return the last
/// value it was set to" (initially "low").
pub fn get_imageSmoothingQuality(instance: *runtime.Instance) anyerror!enums.ImageSmoothingQuality {
    return (try stateOf(instance)).drawing.image_smoothing_quality;
}

/// Setter for imageSmoothingEnabled: "On setting, it must be set to the new
/// value."
pub fn set_imageSmoothingEnabled(instance: *runtime.Instance, value: bool) anyerror!void {
    (try stateOf(instance)).drawing.image_smoothing_enabled = value;
}

/// Setter for imageSmoothingQuality: "On setting, it must be set to the new
/// value."
pub fn set_imageSmoothingQuality(instance: *runtime.Instance, value: enums.ImageSmoothingQuality) anyerror!void {
    (try stateOf(instance)).drawing.image_smoothing_quality = value;
}
