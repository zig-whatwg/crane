//! Implementation for DOMPoint interface
//!
//! Geometry Interfaces 2: https://drafts.fxtf.org/geometry/#DOMPoint
//!
//! A DOMPoint is a DOMPointReadOnly whose variables can be set. They are
//! DOMPointReadOnly's ("DOMPointReadOnly as well as the inheriting interface
//! DOMPoint must be able to access and set the value of these variables"):
//! this impl reads them through DOMPointReadOnly's getters and sets them
//! through dom.geometry_storage, which DOMPointReadOnly installs. DOMPoint's
//! own State slots for x, y, z and w (codegen gives each `inherit attribute`
//! one) are not used.

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
const DOMPoint = interfaces.DOMPoint;

pub const State = DOMPoint.State;

pub const ImplError = error{
    NotImplemented,
};

/// Implementation-specific data: none - the point is DOMPointReadOnly's.
pub const InternalState = struct {};

/// Initialize instance: a DOMPointReadOnly's state first, through its
/// interface (the point (0, 0, 0, 1)).
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return interfaces.DOMPointReadOnly.initWithState(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// The point's variables, through DOMPointReadOnly's getters.
fn pointOf(instance: *runtime.Instance) !geometry.Point {
    return .{
        .x = try interfaces.DOMPointReadOnly.get_x(instance),
        .y = try interfaces.DOMPointReadOnly.get_y(instance),
        .z = try interfaces.DOMPointReadOnly.get_z(instance),
        .w = try interfaces.DOMPointReadOnly.get_w(instance),
    };
}

/// Geometry 2, the DOMPoint(x, y, z, w) constructor:
/// 1. Let point be a new DOMPoint object.
/// 2. Set point's variables x coordinate to x, y coordinate to y, z
///    coordinate to z and w perspective to w.
/// 3. Return point.
pub fn call_constructor(ctx: runtime.Context, x: webidl.Opt(f64), y: webidl.Opt(f64), z: webidl.Opt(f64), w: webidl.Opt(f64)) !*runtime.Instance {
    // 1.
    const instance = try init(ctx.allocator, State, &DOMPoint.vtable, ctx);
    const generation = runtime.SlabAllocator.generationOf(instance);
    errdefer instance.releaseIfUnwrapped(generation);
    // 2. (The arguments' defaults: x, y and z 0, w 1.)
    try geometry_storage.setPoint(instance, .{
        .x = if (x.was_passed) x.value else 0,
        .y = if (y.was_passed) y.value else 0,
        .z = if (z.was_passed) z.value else 0,
        .w = if (w.was_passed) w.value else 1,
    });
    // 3.
    return instance;
}

/// Getter for x: the x coordinate.
pub fn get_x(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMPointReadOnly.get_x(instance);
}

/// Getter for y: the y coordinate.
pub fn get_y(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMPointReadOnly.get_y(instance);
}

/// Getter for z: the z coordinate.
pub fn get_z(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMPointReadOnly.get_z(instance);
}

/// Getter for w: the w perspective.
pub fn get_w(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMPointReadOnly.get_w(instance);
}

/// Setter for x: "setting the x attribute must set the x coordinate to the
/// new value".
pub fn set_x(instance: *runtime.Instance, value: f64) anyerror!void {
    var point = try pointOf(instance);
    point.x = value;
    try geometry_storage.setPoint(instance, point);
}

/// Setter for y: sets the y coordinate.
pub fn set_y(instance: *runtime.Instance, value: f64) anyerror!void {
    var point = try pointOf(instance);
    point.y = value;
    try geometry_storage.setPoint(instance, point);
}

/// Setter for z: sets the z coordinate.
pub fn set_z(instance: *runtime.Instance, value: f64) anyerror!void {
    var point = try pointOf(instance);
    point.z = value;
    try geometry_storage.setPoint(instance, point);
}

/// Setter for w: sets the w perspective.
pub fn set_w(instance: *runtime.Instance, value: f64) anyerror!void {
    var point = try pointOf(instance);
    point.w = value;
    try geometry_storage.setPoint(instance, point);
}

/// Geometry 2, DOMPoint.fromPoint(other): create a DOMPoint from the
/// dictionary other -
/// 1. Let point be a new DOMPoint.
/// 2. Set its variables from other's x, y, z and w members.
/// 3. Return point.
pub fn call_static_fromPoint(instance: *runtime.Instance, other: webidl.Opt(dictionaries.DOMPointInit)) anyerror!*runtime.Instance {
    const ctx = instance.ctx;
    // 1.
    const point = try init(ctx.allocator, State, &DOMPoint.vtable, ctx);
    const generation = runtime.SlabAllocator.generationOf(point);
    errdefer point.releaseIfUnwrapped(generation);
    // 2.
    try geometry_storage.setPoint(point, geometry.pointFrom(if (other.was_passed) other.value else dictionaries.DOMPointInit{}));
    // 3.
    return point;
}

// ============================================================================
// Serializable objects (HTML 2.7.1; Geometry 7: DOMPoint is [Serializable])
// ============================================================================

/// Geometry 7, the serialization steps for DOMPointReadOnly and DOMPoint: one
/// algorithm for both, DOMPointReadOnly's, run here for a DOMPoint (its own
/// primary interface, HTML 2.7.1).
pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) !void {
    try interfaces.DOMPointReadOnly.serializationSteps(value, serialized);
}

/// Geometry 7, the deserialization steps for DOMPointReadOnly and DOMPoint.
pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) !void {
    try interfaces.DOMPointReadOnly.deserializationSteps(serialized, value, target_realm);
}
