//! Implementation for DOMRect interface
//!
//! CSSOM View Module - DOMRect
//! Spec: https://drafts.fxtf.org/geometry/#domrect
//!
//! Extends DOMRectReadOnly with mutable x, y, width, height properties.
//!
//! The rectangle's variables are DOMRectReadOnly's (Geometry 3): this impl
//! reads them through DOMRectReadOnly's getters and sets them through
//! dom.geometry_storage, which DOMRectReadOnly installs - so top, right,
//! bottom and left, DOMRectReadOnly's members, always see what a DOMRect's
//! setters wrote. DOMRect's own State slots for x, y, width and height
//! (codegen gives each `inherit attribute` one) are not used.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const geometry = @import("css").geometry;
const geometry_storage = @import("dom").geometry_storage;
const DOMRect = interfaces.DOMRect;

pub const State = DOMRect.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
};

/// Implementation-specific data: none - the rectangle is DOMRectReadOnly's.
pub const InternalState = struct {};

/// Initialize instance: a DOMRectReadOnly's state first, through its
/// interface (the rectangle (0, 0, 0, 0)).
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return interfaces.DOMRectReadOnly.initWithState(allocator, StateType, vtable, ctx);
}

/// A new DOMRect of `ctx` with the given variables.
fn initWithDimensions(ctx: runtime.Context, rect: geometry.Rect) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &DOMRect.vtable, ctx);
    const generation = runtime.SlabAllocator.generationOf(instance);
    errdefer instance.releaseIfUnwrapped(generation);
    try geometry_storage.setRect(instance, rect);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// The rectangle's variables, through DOMRectReadOnly's getters.
fn rectOf(instance: *runtime.Instance) !geometry.Rect {
    return .{
        .x = try interfaces.DOMRectReadOnly.get_x(instance),
        .y = try interfaces.DOMRectReadOnly.get_y(instance),
        .width = try interfaces.DOMRectReadOnly.get_width(instance),
        .height = try interfaces.DOMRectReadOnly.get_height(instance),
    };
}

/// Geometry 3, the DOMRect(x, y, width, height) constructor:
/// 1. Let rect be a new DOMRect object.
/// 2. Set rect's variables x coordinate to x, y coordinate to y, width
///    dimension to width and height dimension to height.
/// 3. Return rect.
pub fn call_constructor(ctx: runtime.Context, x: webidl.Opt(f64), y: webidl.Opt(f64), width: webidl.Opt(f64), height: webidl.Opt(f64)) !*runtime.Instance {
    return initWithDimensions(ctx, .{
        .x = if (x.was_passed) x.value else 0,
        .y = if (y.was_passed) y.value else 0,
        .width = if (width.was_passed) width.value else 0,
        .height = if (height.was_passed) height.value else 0,
    });
}

/// Getter for x: the x coordinate.
pub fn get_x(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMRectReadOnly.get_x(instance);
}

/// Setter for x: sets the x coordinate.
pub fn set_x(instance: *runtime.Instance, value: f64) anyerror!void {
    var rect = try rectOf(instance);
    rect.x = value;
    try geometry_storage.setRect(instance, rect);
}

/// Getter for y: the y coordinate.
pub fn get_y(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMRectReadOnly.get_y(instance);
}

/// Setter for y: sets the y coordinate.
pub fn set_y(instance: *runtime.Instance, value: f64) anyerror!void {
    var rect = try rectOf(instance);
    rect.y = value;
    try geometry_storage.setRect(instance, rect);
}

/// Getter for width: the width dimension.
pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMRectReadOnly.get_width(instance);
}

/// Setter for width: sets the width dimension.
pub fn set_width(instance: *runtime.Instance, value: f64) anyerror!void {
    var rect = try rectOf(instance);
    rect.width = value;
    try geometry_storage.setRect(instance, rect);
}

/// Getter for height: the height dimension.
pub fn get_height(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMRectReadOnly.get_height(instance);
}

/// Setter for height: sets the height dimension.
pub fn set_height(instance: *runtime.Instance, value: f64) anyerror!void {
    var rect = try rectOf(instance);
    rect.height = value;
    try geometry_storage.setRect(instance, rect);
}

/// Operation: fromRect (static)
/// Spec: https://drafts.fxtf.org/geometry/#dom-domrect-fromrect
/// Creates a new DOMRect from a DOMRectInit dictionary
pub fn call_static_fromRect(instance: *runtime.Instance, other: webidl.Opt(dictionaries.DOMRectInit)) anyerror!*runtime.Instance {
    const dict: dictionaries.DOMRectInit = if (other.was_passed) other.value else .{};
    return initWithDimensions(instance.ctx, .{
        .x = dict.x orelse 0,
        .y = dict.y orelse 0,
        .width = dict.width orelse 0,
        .height = dict.height orelse 0,
    });
}

// ============================================================================
// Serializable objects (HTML 2.7.1; Geometry 7: DOMRect is [Serializable])
// ============================================================================

/// Geometry 7, the serialization steps for DOMRectReadOnly and DOMRect: one
/// algorithm for both, DOMRectReadOnly's, run here for a DOMRect (its own
/// primary interface, HTML 2.7.1).
pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) !void {
    try interfaces.DOMRectReadOnly.serializationSteps(value, serialized);
}

/// Geometry 7, the deserialization steps for DOMRectReadOnly and DOMRect.
pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) !void {
    try interfaces.DOMRectReadOnly.deserializationSteps(serialized, value, target_realm);
}
