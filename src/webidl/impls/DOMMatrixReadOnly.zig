//! Implementation for DOMMatrixReadOnly interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const DOMMatrixReadOnly = interfaces.DOMMatrixReadOnly;
const reflection = @import("reflection.zig");

pub const State = DOMMatrixReadOnly.State;

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

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context, init_data: webidl.Opt(runtime.JSValue)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &DOMMatrixReadOnly.vtable, ctx);
    errdefer deinit(instance);

    _ = init_data;
    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for a
pub fn get_a(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for b
pub fn get_b(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for c
pub fn get_c(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for d
pub fn get_d(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for e
pub fn get_e(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for f
pub fn get_f(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m11
pub fn get_m11(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m12
pub fn get_m12(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m13
pub fn get_m13(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m14
pub fn get_m14(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m21
pub fn get_m21(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m22
pub fn get_m22(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m23
pub fn get_m23(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m24
pub fn get_m24(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m31
pub fn get_m31(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m32
pub fn get_m32(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m33
pub fn get_m33(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m34
pub fn get_m34(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m41
pub fn get_m41(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m42
pub fn get_m42(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m43
pub fn get_m43(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m44
pub fn get_m44(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for is2D
pub fn get_is2D(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for isIdentity
pub fn get_isIdentity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: fromFloat32Array (static)
pub fn call_static_fromFloat32Array(instance: *runtime.Instance, array32: runtime.JSValue) anyerror!*runtime.Instance {
    _ = instance;
    _ = array32;
    return error.NotImplemented;
}

/// Operation: flipX
pub fn call_flipX(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: scale3d
pub fn call_scale3d(instance: *runtime.Instance, scale: webidl.Opt(f64), originX: webidl.Opt(f64), originY: webidl.Opt(f64), originZ: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = scale;
    _ = originX;
    _ = originY;
    _ = originZ;
    return error.NotImplemented;
}

/// Operation: fromFloat64Array (static)
pub fn call_static_fromFloat64Array(instance: *runtime.Instance, array64: runtime.JSValue) anyerror!*runtime.Instance {
    _ = instance;
    _ = array64;
    return error.NotImplemented;
}

/// Operation: fromMatrix (static)
pub fn call_static_fromMatrix(instance: *runtime.Instance, other: webidl.Opt(dictionaries.DOMMatrixInit)) anyerror!*runtime.Instance {
    _ = instance;
    _ = other;
    return error.NotImplemented;
}

/// Operation: rotateAxisAngle
pub fn call_rotateAxisAngle(instance: *runtime.Instance, x: webidl.Opt(f64), y: webidl.Opt(f64), z: webidl.Opt(f64), angle: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = x;
    _ = y;
    _ = z;
    _ = angle;
    return error.NotImplemented;
}

/// Operation: skewY
pub fn call_skewY(instance: *runtime.Instance, sy: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = sy;
    return error.NotImplemented;
}

/// Operation: rotate
pub fn call_rotate(instance: *runtime.Instance, rotX: webidl.Opt(f64), rotY: webidl.Opt(f64), rotZ: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = rotX;
    _ = rotY;
    _ = rotZ;
    return error.NotImplemented;
}

/// Operation: inverse
pub fn call_inverse(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: toFloat64Array
pub fn call_toFloat64Array(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: scale
pub fn call_scale(instance: *runtime.Instance, scaleX: webidl.Opt(f64), scaleY: webidl.Opt(f64), scaleZ: webidl.Opt(f64), originX: webidl.Opt(f64), originY: webidl.Opt(f64), originZ: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = scaleX;
    _ = scaleY;
    _ = scaleZ;
    _ = originX;
    _ = originY;
    _ = originZ;
    return error.NotImplemented;
}

/// Operation: translate
pub fn call_translate(instance: *runtime.Instance, tx: webidl.Opt(f64), ty: webidl.Opt(f64), tz: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = tx;
    _ = ty;
    _ = tz;
    return error.NotImplemented;
}

/// Operation: multiply
pub fn call_multiply(instance: *runtime.Instance, other: webidl.Opt(dictionaries.DOMMatrixInit)) anyerror!*runtime.Instance {
    _ = instance;
    _ = other;
    return error.NotImplemented;
}

/// Operation: transformPoint
pub fn call_transformPoint(instance: *runtime.Instance, point: webidl.Opt(dictionaries.DOMPointInit)) anyerror!*runtime.Instance {
    _ = instance;
    _ = point;
    return error.NotImplemented;
}

/// Operation: skewX
pub fn call_skewX(instance: *runtime.Instance, sx: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = sx;
    return error.NotImplemented;
}

/// Per WebIDL spec, [Default] toJSON returns an object with all exposed attributes.
pub fn call_toJSON(instance: *runtime.Instance) anyerror!interfaces.DOMMatrixReadOnly.DOMMatrixReadOnlyToJSON {
    const state = instance.getState(State);
    return .{
        .a = state.own.a,
        .b = state.own.b,
        .c = state.own.c,
        .d = state.own.d,
        .e = state.own.e,
        .f = state.own.f,
        .m11 = state.own.m11,
        .m12 = state.own.m12,
        .m13 = state.own.m13,
        .m14 = state.own.m14,
        .m21 = state.own.m21,
        .m22 = state.own.m22,
        .m23 = state.own.m23,
        .m24 = state.own.m24,
        .m31 = state.own.m31,
        .m32 = state.own.m32,
        .m33 = state.own.m33,
        .m34 = state.own.m34,
        .m41 = state.own.m41,
        .m42 = state.own.m42,
        .m43 = state.own.m43,
        .m44 = state.own.m44,
        .is2D = state.own.is2D,
        .isIdentity = state.own.isIdentity,
    };
}

/// Operation: scaleNonUniform
pub fn call_scaleNonUniform(instance: *runtime.Instance, scaleX: webidl.Opt(f64), scaleY: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = scaleX;
    _ = scaleY;
    return error.NotImplemented;
}

/// Operation: flipY
pub fn call_flipY(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: toFloat32Array
pub fn call_toFloat32Array(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: rotateFromVector
pub fn call_rotateFromVector(instance: *runtime.Instance, x: webidl.Opt(f64), y: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Stringifier - serialize method for toString
/// Spec: https://drafts.fxtf.org/geometry/#dommatrixreadonly-stringification-behavior
///
/// The result is the binding's to free - toString() is bound as an
/// operation - so it is allocated here. This returned the literal
/// "[object]", and `String(new DOMMatrix())` died in Allocator.free's memset
/// on the literal's read-only page.
pub fn serialize(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const elements = [16]f64{
        state.own.m11, state.own.m12, state.own.m13, state.own.m14,
        state.own.m21, state.own.m22, state.own.m23, state.own.m24,
        state.own.m31, state.own.m32, state.own.m33, state.own.m34,
        state.own.m41, state.own.m42, state.own.m43, state.own.m44,
    };
    // 1. If one or more of m11 element through m44 element are a non-finite
    //    value, then throw an "InvalidStateError" DOMException.
    for (elements) |element| {
        if (!std.math.isFinite(element)) return error.InvalidStateError;
    }
    // 2. Let string be the empty string.
    const allocator = instance.ctx.allocator;
    var string: std.ArrayListUnmanaged(u8) = .empty;
    errdefer string.deinit(allocator);
    // 3. If is 2D is true: "matrix(" m11, m12, m21, m22, m41, m42 ")" - a
    //    CSS <matrix()>. 4. Otherwise: "matrix3d(" and all sixteen elements
    //    in column-major order, then ")".
    const two_d = [_]usize{ 0, 1, 4, 5, 12, 13 };
    const all = [_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
    const order: []const usize = if (state.own.is2D) &two_d else &all;
    try string.appendSlice(allocator, if (state.own.is2D) "matrix(" else "matrix3d(");
    for (order, 0..) |index, i| {
        if (i > 0) try string.appendSlice(allocator, ", ");
        // ! ToString(element).
        var buffer: [32]u8 = undefined;
        try string.appendSlice(allocator, reflection.numberToString(&buffer, elements[index]));
    }
    try string.append(allocator, ')');
    return string.toOwnedSlice(allocator);
}
