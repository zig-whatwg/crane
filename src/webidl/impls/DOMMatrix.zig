//! Implementation for DOMMatrix interface
//!
//! Geometry Interfaces 6: https://drafts.fxtf.org/geometry/#DOMMatrix
//!
//! A DOMMatrix is a DOMMatrixReadOnly whose elements can be set. They are
//! DOMMatrixReadOnly's: this impl reads them through DOMMatrixReadOnly's
//! getters and sets them through dom.geometry_storage, which
//! DOMMatrixReadOnly installs. Its constructor and static methods convert
//! their arguments as DOMMatrixReadOnly's do - by making a DOMMatrixReadOnly
//! through that interface and taking its matrix - so each conversion is
//! written once. DOMMatrix's own State slots (codegen gives each `inherit
//! attribute` one) are not used.
//!
//! Not yet: the mutable transform methods (multiplySelf, translateSelf, ...)
//! and setMatrixValue, which needs a CSS transform-list parser.

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
const DOMMatrix = interfaces.DOMMatrix;

pub const State = DOMMatrix.State;

pub const ImplError = error{
    NotImplemented,
};

/// Implementation-specific data: none - the matrix is DOMMatrixReadOnly's.
pub const InternalState = struct {};

/// Initialize instance: a DOMMatrixReadOnly's state first, through its
/// interface (the identity matrix, 2D).
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return interfaces.DOMMatrixReadOnly.initWithState(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// `instance`'s matrix (a DOMMatrix or DOMMatrixReadOnly), through
/// DOMMatrixReadOnly's getters.
fn matrixOf(instance: *runtime.Instance) !geometry.Matrix {
    var matrix: geometry.Matrix = .{ .m = undefined, .is_2d = try interfaces.DOMMatrixReadOnly.get_is2D(instance) };
    inline for (geometry.element_names, 0..) |name, i| {
        matrix.m[i] = try @field(interfaces.DOMMatrixReadOnly, "get_" ++ name)(instance);
    }
    return matrix;
}

/// A new DOMMatrix of `ctx` holding `matrix` (6.3 "create a 2d/3d matrix"
/// of type DOMMatrix).
fn create(ctx: runtime.Context, matrix: geometry.Matrix) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &DOMMatrix.vtable, ctx);
    const generation = runtime.SlabAllocator.generationOf(instance);
    errdefer instance.releaseIfUnwrapped(generation);
    try geometry_storage.setMatrix(instance, matrix);
    return instance;
}

/// A new DOMMatrix with the matrix of `made`, a DOMMatrixReadOnly
/// DOMMatrixReadOnly's constructor or static method just made from the same
/// arguments; `made` is released (script never saw it).
fn createFrom(ctx: runtime.Context, made: *runtime.Instance) !*runtime.Instance {
    const generation = runtime.SlabAllocator.generationOf(made);
    defer made.releaseIfUnwrapped(generation);
    return create(ctx, try matrixOf(made));
}

/// Geometry 6.4: set one element of the matrix, with the is-2D rule of its
/// setter (css.geometry.Matrix.setElement).
fn setElement(instance: *runtime.Instance, i: usize, value: f64) !void {
    var matrix = try matrixOf(instance);
    matrix.setElement(i, value);
    try geometry_storage.setMatrix(instance, matrix);
}

/// Geometry 6.3, the DOMMatrix(init) constructor: as DOMMatrixReadOnly's,
/// of type DOMMatrix.
pub fn call_constructor(ctx: runtime.Context, init_data: webidl.Opt(runtime.JSValue)) !*runtime.Instance {
    return createFrom(ctx, try interfaces.DOMMatrixReadOnly.call_constructor(ctx, init_data));
}

/// Geometry 6.3, DOMMatrix.fromMatrix(other): create a DOMMatrix from the
/// dictionary other.
pub fn call_static_fromMatrix(instance: *runtime.Instance, other: webidl.Opt(dictionaries.DOMMatrixInit)) anyerror!*runtime.Instance {
    return createFrom(instance.ctx, try interfaces.DOMMatrixReadOnly.call_static_fromMatrix(instance, other));
}

/// Geometry 6.3, DOMMatrix.fromFloat32Array(array32).
pub fn call_static_fromFloat32Array(instance: *runtime.Instance, array32: runtime.JSValue) anyerror!*runtime.Instance {
    return createFrom(instance.ctx, try interfaces.DOMMatrixReadOnly.call_static_fromFloat32Array(instance, array32));
}

/// Geometry 6.3, DOMMatrix.fromFloat64Array(array64).
pub fn call_static_fromFloat64Array(instance: *runtime.Instance, array64: runtime.JSValue) anyerror!*runtime.Instance {
    return createFrom(instance.ctx, try interfaces.DOMMatrixReadOnly.call_static_fromFloat64Array(instance, array64));
}

/// Getter for a: an alias of m11, DOMMatrixReadOnly's.
pub fn get_a(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m11(instance);
}

/// Setter for a: sets the m11 element (Geometry 6.4).
pub fn set_a(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(1, 1), value);
}

/// Getter for b: an alias of m12, DOMMatrixReadOnly's.
pub fn get_b(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m12(instance);
}

/// Setter for b: sets the m12 element (Geometry 6.4).
pub fn set_b(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(1, 2), value);
}

/// Getter for c: an alias of m21, DOMMatrixReadOnly's.
pub fn get_c(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m21(instance);
}

/// Setter for c: sets the m21 element (Geometry 6.4).
pub fn set_c(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(2, 1), value);
}

/// Getter for d: an alias of m22, DOMMatrixReadOnly's.
pub fn get_d(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m22(instance);
}

/// Setter for d: sets the m22 element (Geometry 6.4).
pub fn set_d(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(2, 2), value);
}

/// Getter for e: an alias of m41, DOMMatrixReadOnly's.
pub fn get_e(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m41(instance);
}

/// Setter for e: sets the m41 element (Geometry 6.4).
pub fn set_e(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(4, 1), value);
}

/// Getter for f: an alias of m42, DOMMatrixReadOnly's.
pub fn get_f(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m42(instance);
}

/// Setter for f: sets the m42 element (Geometry 6.4).
pub fn set_f(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(4, 2), value);
}

/// Getter for m11: the m11 element, DOMMatrixReadOnly's.
pub fn get_m11(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m11(instance);
}

/// Setter for m11: sets the m11 element (Geometry 6.4).
pub fn set_m11(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(1, 1), value);
}

/// Getter for m12: the m12 element, DOMMatrixReadOnly's.
pub fn get_m12(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m12(instance);
}

/// Setter for m12: sets the m12 element (Geometry 6.4).
pub fn set_m12(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(1, 2), value);
}

/// Getter for m13: the m13 element, DOMMatrixReadOnly's.
pub fn get_m13(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m13(instance);
}

/// Setter for m13: sets the m13 element (Geometry 6.4), and clears is 2D unless the new value is 0 or -0.
pub fn set_m13(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(1, 3), value);
}

/// Getter for m14: the m14 element, DOMMatrixReadOnly's.
pub fn get_m14(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m14(instance);
}

/// Setter for m14: sets the m14 element (Geometry 6.4), and clears is 2D unless the new value is 0 or -0.
pub fn set_m14(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(1, 4), value);
}

/// Getter for m21: the m21 element, DOMMatrixReadOnly's.
pub fn get_m21(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m21(instance);
}

/// Setter for m21: sets the m21 element (Geometry 6.4).
pub fn set_m21(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(2, 1), value);
}

/// Getter for m22: the m22 element, DOMMatrixReadOnly's.
pub fn get_m22(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m22(instance);
}

/// Setter for m22: sets the m22 element (Geometry 6.4).
pub fn set_m22(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(2, 2), value);
}

/// Getter for m23: the m23 element, DOMMatrixReadOnly's.
pub fn get_m23(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m23(instance);
}

/// Setter for m23: sets the m23 element (Geometry 6.4), and clears is 2D unless the new value is 0 or -0.
pub fn set_m23(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(2, 3), value);
}

/// Getter for m24: the m24 element, DOMMatrixReadOnly's.
pub fn get_m24(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m24(instance);
}

/// Setter for m24: sets the m24 element (Geometry 6.4), and clears is 2D unless the new value is 0 or -0.
pub fn set_m24(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(2, 4), value);
}

/// Getter for m31: the m31 element, DOMMatrixReadOnly's.
pub fn get_m31(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m31(instance);
}

/// Setter for m31: sets the m31 element (Geometry 6.4), and clears is 2D unless the new value is 0 or -0.
pub fn set_m31(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(3, 1), value);
}

/// Getter for m32: the m32 element, DOMMatrixReadOnly's.
pub fn get_m32(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m32(instance);
}

/// Setter for m32: sets the m32 element (Geometry 6.4), and clears is 2D unless the new value is 0 or -0.
pub fn set_m32(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(3, 2), value);
}

/// Getter for m33: the m33 element, DOMMatrixReadOnly's.
pub fn get_m33(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m33(instance);
}

/// Setter for m33: sets the m33 element (Geometry 6.4), and clears is 2D unless the new value is 1.
pub fn set_m33(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(3, 3), value);
}

/// Getter for m34: the m34 element, DOMMatrixReadOnly's.
pub fn get_m34(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m34(instance);
}

/// Setter for m34: sets the m34 element (Geometry 6.4), and clears is 2D unless the new value is 0 or -0.
pub fn set_m34(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(3, 4), value);
}

/// Getter for m41: the m41 element, DOMMatrixReadOnly's.
pub fn get_m41(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m41(instance);
}

/// Setter for m41: sets the m41 element (Geometry 6.4).
pub fn set_m41(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(4, 1), value);
}

/// Getter for m42: the m42 element, DOMMatrixReadOnly's.
pub fn get_m42(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m42(instance);
}

/// Setter for m42: sets the m42 element (Geometry 6.4).
pub fn set_m42(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(4, 2), value);
}

/// Getter for m43: the m43 element, DOMMatrixReadOnly's.
pub fn get_m43(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m43(instance);
}

/// Setter for m43: sets the m43 element (Geometry 6.4), and clears is 2D unless the new value is 0 or -0.
pub fn set_m43(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(4, 3), value);
}

/// Getter for m44: the m44 element, DOMMatrixReadOnly's.
pub fn get_m44(instance: *runtime.Instance) anyerror!f64 {
    return interfaces.DOMMatrixReadOnly.get_m44(instance);
}

/// Setter for m44: sets the m44 element (Geometry 6.4), and clears is 2D unless the new value is 1.
pub fn set_m44(instance: *runtime.Instance, value: f64) anyerror!void {
    try setElement(instance, geometry.index(4, 4), value);
}

pub fn call_scaleSelf(instance: *runtime.Instance, scaleX: webidl.Opt(f64), scaleY: webidl.Opt(f64), scaleZ: webidl.Opt(f64), originX: webidl.Opt(f64), originY: webidl.Opt(f64), originZ: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = scaleX;
    _ = scaleY;
    _ = scaleZ;
    _ = originX;
    _ = originY;
    _ = originZ;
    return error.NotImplemented;
}

pub fn call_rotateFromVectorSelf(instance: *runtime.Instance, x: webidl.Opt(f64), y: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

pub fn call_setMatrixValue(instance: *runtime.Instance, transformList: runtime.DOMString) anyerror!*runtime.Instance {
    _ = instance;
    _ = transformList;
    return error.NotImplemented;
}

pub fn call_rotateAxisAngleSelf(instance: *runtime.Instance, x: webidl.Opt(f64), y: webidl.Opt(f64), z: webidl.Opt(f64), angle: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = x;
    _ = y;
    _ = z;
    _ = angle;
    return error.NotImplemented;
}

pub fn call_scale3dSelf(instance: *runtime.Instance, scale: webidl.Opt(f64), originX: webidl.Opt(f64), originY: webidl.Opt(f64), originZ: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = scale;
    _ = originX;
    _ = originY;
    _ = originZ;
    return error.NotImplemented;
}

pub fn call_rotateSelf(instance: *runtime.Instance, rotX: webidl.Opt(f64), rotY: webidl.Opt(f64), rotZ: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = rotX;
    _ = rotY;
    _ = rotZ;
    return error.NotImplemented;
}

pub fn call_translateSelf(instance: *runtime.Instance, tx: webidl.Opt(f64), ty: webidl.Opt(f64), tz: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = tx;
    _ = ty;
    _ = tz;
    return error.NotImplemented;
}

pub fn call_multiplySelf(instance: *runtime.Instance, other: webidl.Opt(dictionaries.DOMMatrixInit)) anyerror!*runtime.Instance {
    _ = instance;
    _ = other;
    return error.NotImplemented;
}

pub fn call_skewXSelf(instance: *runtime.Instance, sx: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = sx;
    return error.NotImplemented;
}

pub fn call_skewYSelf(instance: *runtime.Instance, sy: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = sy;
    return error.NotImplemented;
}

pub fn call_invertSelf(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

pub fn call_preMultiplySelf(instance: *runtime.Instance, other: webidl.Opt(dictionaries.DOMMatrixInit)) anyerror!*runtime.Instance {
    _ = instance;
    _ = other;
    return error.NotImplemented;
}

// ============================================================================
// Serializable objects (HTML 2.7.1; Geometry 7: DOMMatrix is [Serializable])
// ============================================================================

/// Geometry 7, the serialization steps for DOMMatrixReadOnly and DOMMatrix:
/// one algorithm for both, DOMMatrixReadOnly's, run here for a DOMMatrix
/// (its own primary interface, HTML 2.7.1).
pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) !void {
    try interfaces.DOMMatrixReadOnly.serializationSteps(value, serialized);
}

/// Geometry 7, the deserialization steps for DOMMatrixReadOnly and DOMMatrix.
pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) !void {
    try interfaces.DOMMatrixReadOnly.deserializationSteps(serialized, value, target_realm);
}
