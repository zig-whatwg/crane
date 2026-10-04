//! Implementation for DOMPointReadOnly interface
//!
//! Geometry Interfaces 2: https://drafts.fxtf.org/geometry/#DOMPoint
//!
//! A point's x coordinate, y coordinate, z coordinate and w perspective are
//! this interface's internal member variables, kept in its State. DOMPoint
//! (which inherits them) reads them through this interface's getters and
//! sets them through dom.geometry_storage, the step installed here.

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
const DOMPointReadOnly = interfaces.DOMPointReadOnly;

pub const State = DOMPointReadOnly.State;

pub const ImplError = error{
    NotImplemented,
};

/// Implementation-specific data: none - the point's variables are State's.
pub const InternalState = struct {};

/// The hooks this type owns (src/dom), installed once, at process start.
pub fn installHooks() void {
    geometry_storage.installPoint(&setPoint);
}

/// Initialize instance (creates the instance): the point (0, 0, 0, 1) until
/// its maker sets one. DOMPoint's state is made here too, through this
/// interface's initWithState.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    setPoint(instance, .{});
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// dom.geometry_storage: set the point's variables.
fn setPoint(instance: *runtime.Instance, point: geometry.Point) void {
    const state = instance.getState(State);
    state.own.x = point.x;
    state.own.y = point.y;
    state.own.z = point.z;
    state.own.w = point.w;
}

fn pointOf(instance: *runtime.Instance) geometry.Point {
    const state = instance.getState(State);
    return .{ .x = state.own.x, .y = state.own.y, .z = state.own.z, .w = state.own.w };
}

/// Geometry 2, the DOMPointReadOnly(x, y, z, w) constructor:
/// 1. Let point be a new DOMPointReadOnly object.
/// 2. Set point's variables x coordinate to x, y coordinate to y, z
///    coordinate to z and w perspective to w.
/// 3. Return point.
pub fn call_constructor(ctx: runtime.Context, x: webidl.Opt(f64), y: webidl.Opt(f64), z: webidl.Opt(f64), w: webidl.Opt(f64)) !*runtime.Instance {
    // 1.
    const instance = try init(ctx.allocator, State, &DOMPointReadOnly.vtable, ctx);
    // 2. (The arguments' defaults: x, y and z 0, w 1.)
    setPoint(instance, .{
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
    return instance.getState(State).own.x;
}

/// Getter for y: the y coordinate.
pub fn get_y(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.y;
}

/// Getter for z: the z coordinate.
pub fn get_z(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.z;
}

/// Getter for w: the w perspective.
pub fn get_w(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.w;
}

/// Per WebIDL spec, [Default] toJSON returns an object with all exposed attributes.
pub fn call_toJSON(instance: *runtime.Instance) anyerror!interfaces.DOMPointReadOnly.DOMPointReadOnlyToJSON {
    const point = pointOf(instance);
    return .{ .x = point.x, .y = point.y, .z = point.z, .w = point.w };
}

/// Geometry 2, matrixTransform(matrix):
/// 1. Let matrixObject be the result of invoking create a DOMMatrix from the
///    dictionary matrix.
/// 2. Return the result of invoking transform a point with a matrix, given
///    the current point and matrixObject. The current point does not get
///    modified.
///
/// matrixObject is never seen by script, so its abstract matrix stands in
/// for it (geometry.fromDictionary throws the same TypeError).
pub fn call_matrixTransform(instance: *runtime.Instance, matrix: webidl.Opt(dictionaries.DOMMatrixInit)) anyerror!*runtime.Instance {
    // 1.
    const matrix_object = try geometry.fromDictionary(geometry.matrixInitFrom(if (matrix.was_passed) matrix.value else dictionaries.DOMMatrixInit{ .base = .{} }));
    // 2. Geometry 2.1 steps 1-6, then 7-12: a new DOMPoint with the
    //    transformed vector's elements.
    const transformed = matrix_object.transformPoint(pointOf(instance));
    return interfaces.DOMPoint.call_constructor(
        instance.ctx,
        webidl.Opt(f64).passed(transformed.x),
        webidl.Opt(f64).passed(transformed.y),
        webidl.Opt(f64).passed(transformed.z),
        webidl.Opt(f64).passed(transformed.w),
    );
}

/// Geometry 2, DOMPointReadOnly.fromPoint(other): create a
/// DOMPointReadOnly from the dictionary other -
/// 1. Let point be a new DOMPointReadOnly.
/// 2. Set its variables from other's x, y, z and w members.
/// 3. Return point.
pub fn call_static_fromPoint(instance: *runtime.Instance, other: webidl.Opt(dictionaries.DOMPointInit)) anyerror!*runtime.Instance {
    const ctx = instance.ctx;
    // 1.
    const point = try init(ctx.allocator, State, &DOMPointReadOnly.vtable, ctx);
    // 2.
    setPoint(point, geometry.pointFrom(if (other.was_passed) other.value else dictionaries.DOMPointInit{}));
    // 3.
    return point;
}

// ============================================================================
// Serializable objects (HTML 2.7.1; Geometry 7: DOMPointReadOnly is
// [Serializable])
// ============================================================================

/// Geometry 7, the serialization steps for DOMPointReadOnly and DOMPoint,
/// given `value` and `serialized`:
/// 1. Set serialized.[[X]] to value's x coordinate.
/// 2. Set serialized.[[Y]] to value's y coordinate.
/// 3. Set serialized.[[Z]] to value's z coordinate.
/// 4. Set serialized.[[W]] to value's w perspective.
pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) !void {
    const point = pointOf(value);
    try serialized.writeDouble(point.x);
    try serialized.writeDouble(point.y);
    try serialized.writeDouble(point.z);
    try serialized.writeDouble(point.w);
}

/// Geometry 7, the deserialization steps for DOMPointReadOnly and DOMPoint,
/// given `serialized` and `value`:
/// 1. Set value's x coordinate to serialized.[[X]].
/// 2. Set value's y coordinate to serialized.[[Y]].
/// 3. Set value's z coordinate to serialized.[[Z]].
/// 4. Set value's w perspective to serialized.[[W]].
pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) !void {
    _ = target_realm;
    var point: geometry.Point = undefined;
    point.x = try serialized.readDouble();
    point.y = try serialized.readDouble();
    point.z = try serialized.readDouble();
    point.w = try serialized.readDouble();
    setPoint(value, point);
}
