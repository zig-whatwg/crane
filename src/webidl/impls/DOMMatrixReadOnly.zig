//! Implementation for DOMMatrixReadOnly interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const DOMMatrixReadOnly = interfaces.DOMMatrixReadOnly;

pub const State = DOMMatrixReadOnly.State;

pub const ImplError = error{
    NotImplemented,
};

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
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: *const anyopaque) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &DOMMatrixReadOnly.vtable, ctx);
    errdefer deinit(instance);

    _ = init_data;
    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for a
pub fn get_a(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for b
pub fn get_b(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for c
pub fn get_c(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for d
pub fn get_d(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for e
pub fn get_e(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for f
pub fn get_f(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m11
pub fn get_m11(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m12
pub fn get_m12(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m13
pub fn get_m13(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m14
pub fn get_m14(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m21
pub fn get_m21(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m22
pub fn get_m22(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m23
pub fn get_m23(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m24
pub fn get_m24(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m31
pub fn get_m31(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m32
pub fn get_m32(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m33
pub fn get_m33(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m34
pub fn get_m34(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m41
pub fn get_m41(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m42
pub fn get_m42(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m43
pub fn get_m43(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for m44
pub fn get_m44(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for is2D
pub fn get_is2D(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for isIdentity
pub fn get_isIdentity(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: fromFloat32Array
pub fn call_fromFloat32Array(instance: *runtime.Instance, array32: *const anyopaque) ImplError!interfaces.DOMMatrixReadOnly {
    _ = instance;
    _ = array32;
    return error.NotImplemented;
}

/// Operation: flipX
pub fn call_flipX(instance: *runtime.Instance) ImplError!interfaces.DOMMatrix {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: scale3d
pub fn call_scale3d(instance: *runtime.Instance, scale: f64, originX: f64, originY: f64, originZ: f64) ImplError!interfaces.DOMMatrix {
    _ = instance;
    _ = scale;
    _ = originX;
    _ = originY;
    _ = originZ;
    return error.NotImplemented;
}

/// Operation: fromFloat64Array
pub fn call_fromFloat64Array(instance: *runtime.Instance, array64: *const anyopaque) ImplError!interfaces.DOMMatrixReadOnly {
    _ = instance;
    _ = array64;
    return error.NotImplemented;
}

/// Operation: fromMatrix
pub fn call_fromMatrix(instance: *runtime.Instance, other: dictionaries.DOMMatrixInit) ImplError!interfaces.DOMMatrixReadOnly {
    _ = instance;
    _ = other;
    return error.NotImplemented;
}

/// Operation: rotateAxisAngle
pub fn call_rotateAxisAngle(instance: *runtime.Instance, x: f64, y: f64, z: f64, angle: f64) ImplError!interfaces.DOMMatrix {
    _ = instance;
    _ = x;
    _ = y;
    _ = z;
    _ = angle;
    return error.NotImplemented;
}

/// Operation: skewY
pub fn call_skewY(instance: *runtime.Instance, sy: f64) ImplError!interfaces.DOMMatrix {
    _ = instance;
    _ = sy;
    return error.NotImplemented;
}

/// Operation: rotate
pub fn call_rotate(instance: *runtime.Instance, rotX: f64, rotY: f64, rotZ: f64) ImplError!interfaces.DOMMatrix {
    _ = instance;
    _ = rotX;
    _ = rotY;
    _ = rotZ;
    return error.NotImplemented;
}

/// Operation: inverse
pub fn call_inverse(instance: *runtime.Instance) ImplError!interfaces.DOMMatrix {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: toFloat64Array
pub fn call_toFloat64Array(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: scale
pub fn call_scale(instance: *runtime.Instance, scaleX: f64, scaleY: f64, scaleZ: f64, originX: f64, originY: f64, originZ: f64) ImplError!interfaces.DOMMatrix {
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
pub fn call_translate(instance: *runtime.Instance, tx: f64, ty: f64, tz: f64) ImplError!interfaces.DOMMatrix {
    _ = instance;
    _ = tx;
    _ = ty;
    _ = tz;
    return error.NotImplemented;
}

/// Operation: multiply
pub fn call_multiply(instance: *runtime.Instance, other: dictionaries.DOMMatrixInit) ImplError!interfaces.DOMMatrix {
    _ = instance;
    _ = other;
    return error.NotImplemented;
}

/// Operation: transformPoint
pub fn call_transformPoint(instance: *runtime.Instance, point: dictionaries.DOMPointInit) ImplError!interfaces.DOMPoint {
    _ = instance;
    _ = point;
    return error.NotImplemented;
}

/// Operation: skewX
pub fn call_skewX(instance: *runtime.Instance, sx: f64) ImplError!interfaces.DOMMatrix {
    _ = instance;
    _ = sx;
    return error.NotImplemented;
}

/// Operation: toJSON
pub fn call_toJSON(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: scaleNonUniform
pub fn call_scaleNonUniform(instance: *runtime.Instance, scaleX: f64, scaleY: f64) ImplError!interfaces.DOMMatrix {
    _ = instance;
    _ = scaleX;
    _ = scaleY;
    return error.NotImplemented;
}

/// Operation: flipY
pub fn call_flipY(instance: *runtime.Instance) ImplError!interfaces.DOMMatrix {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: toFloat32Array
pub fn call_toFloat32Array(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: rotateFromVector
pub fn call_rotateFromVector(instance: *runtime.Instance, x: f64, y: f64) ImplError!interfaces.DOMMatrix {
    _ = instance;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

