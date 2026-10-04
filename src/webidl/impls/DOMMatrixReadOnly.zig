//! Implementation for DOMMatrixReadOnly interface
//!
//! Geometry Interfaces 6: https://drafts.fxtf.org/geometry/#DOMMatrix
//!
//! A matrix's m11 to m44 elements and its "is 2D" flag are this interface's
//! internal member variables, kept in its State (a to f are aliases of m11,
//! m12, m21, m22, m41 and m42). DOMMatrix (which inherits them) reads them
//! through this interface's getters and sets them through
//! dom.geometry_storage, the step installed here; it also makes its
//! matrices from what this interface's constructor and static methods make,
//! so the argument conversions live here once. The abstract-matrix
//! algorithms are css.geometry's.
//!
//! Not yet: the transform methods (translate, scale, rotate, skew, multiply,
//! flip, inverse) and a DOMString `init`, which needs a CSS transform-list
//! parser.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const geometry = @import("css").geometry;
const geometry_storage = @import("dom").geometry_storage;
const DOMMatrixReadOnly = interfaces.DOMMatrixReadOnly;
const reflection = @import("reflection.zig");

pub const State = DOMMatrixReadOnly.State;

pub const ImplError = error{
    NotImplemented,
};

/// Implementation-specific data: none - the matrix is State's.
pub const InternalState = struct {};

/// The hooks this type owns (src/dom), installed once, at process start.
pub fn installHooks() void {
    geometry_storage.installMatrix(&setMatrix);
}

/// Initialize instance (creates the instance): the identity matrix, 2D,
/// until its maker sets one. DOMMatrix's state is made here too, through
/// this interface's initWithState.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    setMatrix(instance, geometry.Matrix.identity);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// dom.geometry_storage: set the matrix's elements and is 2D.
fn setMatrix(instance: *runtime.Instance, matrix: geometry.Matrix) void {
    const state = instance.getState(State);
    state.own.m11 = matrix.m[geometry.index(1, 1)];
    state.own.m12 = matrix.m[geometry.index(1, 2)];
    state.own.m13 = matrix.m[geometry.index(1, 3)];
    state.own.m14 = matrix.m[geometry.index(1, 4)];
    state.own.m21 = matrix.m[geometry.index(2, 1)];
    state.own.m22 = matrix.m[geometry.index(2, 2)];
    state.own.m23 = matrix.m[geometry.index(2, 3)];
    state.own.m24 = matrix.m[geometry.index(2, 4)];
    state.own.m31 = matrix.m[geometry.index(3, 1)];
    state.own.m32 = matrix.m[geometry.index(3, 2)];
    state.own.m33 = matrix.m[geometry.index(3, 3)];
    state.own.m34 = matrix.m[geometry.index(3, 4)];
    state.own.m41 = matrix.m[geometry.index(4, 1)];
    state.own.m42 = matrix.m[geometry.index(4, 2)];
    state.own.m43 = matrix.m[geometry.index(4, 3)];
    state.own.m44 = matrix.m[geometry.index(4, 4)];
    state.own.is2D = matrix.is_2d;
}

fn matrixOf(instance: *runtime.Instance) geometry.Matrix {
    const state = instance.getState(State);
    return .{ .m = .{
        state.own.m11,
        state.own.m12,
        state.own.m13,
        state.own.m14,
        state.own.m21,
        state.own.m22,
        state.own.m23,
        state.own.m24,
        state.own.m31,
        state.own.m32,
        state.own.m33,
        state.own.m34,
        state.own.m41,
        state.own.m42,
        state.own.m43,
        state.own.m44,
    }, .is_2d = state.own.is2D };
}

/// A new DOMMatrixReadOnly of `ctx` holding `matrix` - 6.3's "create a 2d
/// matrix" / "create a 3d matrix" of type DOMMatrixReadOnly, step 1 ("Let
/// matrix be a new instance of type") then the rest, which `matrix`
/// already holds.
fn create(ctx: runtime.Context, matrix: geometry.Matrix) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &DOMMatrixReadOnly.vtable, ctx);
    setMatrix(instance, matrix);
    return instance;
}

/// A sequence<unrestricted double> as it converts (WebIDL 3.2.21), item by
/// item; a sequence longer than 16 is no matrix whatever its tail, so the
/// rest is converted (it may run script) but not kept.
const NumberSequence = struct {
    realm: runtime.Context,
    values: [16]f64 = undefined,
    len: usize = 0,

    fn each(data: ?*anyopaque, item: runtime.JSValue) engine.Error!void {
        const self: *NumberSequence = @ptrCast(@alignCast(data.?));
        const number = try engine.convertToUnrestrictedDouble(self.realm, item);
        if (self.len < self.values.len) self.values[self.len] = number;
        self.len += 1;
    }
};

/// Geometry 6.3, the DOMMatrixReadOnly(init) and DOMMatrix(init)
/// constructors, for `init` a (DOMString or sequence<unrestricted double>):
/// the abstract matrix they make.
fn matrixFromInit(ctx: runtime.Context, init_data: webidl.Opt(runtime.JSValue)) !geometry.Matrix {
    // If init is omitted: a 2d matrix with the sequence [1, 0, 0, 1, 0, 0].
    if (!init_data.was_passed or engine.typeOf(ctx, init_data.value) == .undefined) return geometry.Matrix.identity;
    const value = init_data.value;
    // WebIDL 3.2.24: an object with @@iterator is the sequence member.
    if (engine.typeOf(ctx, value) == .object) {
        var sequence: NumberSequence = .{ .realm = ctx };
        if (try engine.iterate(ctx, value, NumberSequence.each, &sequence)) {
            // If init is a sequence with 6 elements: create a 2d matrix; with
            // 16 elements: create a 3d matrix. Otherwise throw a TypeError.
            if (sequence.len > sequence.values.len) return error.TypeError;
            return geometry.Matrix.fromSequence(sequence.values[0..sequence.len]);
        }
    }
    // Otherwise it is the DOMString member.
    const text = try engine.convertToDOMString(ctx, value, ctx.allocator);
    defer ctx.allocator.free(text);
    // 1. If current global object is not a Window object, then throw a
    //    TypeError exception.
    if (!ctx.isWindow()) return error.TypeError;
    // 2. Parse init into an abstract matrix (6.2): step 1 makes the empty
    //    string "matrix(1, 0, 0, 1, 0, 0)", and the keyword none is the
    //    identity matrix (step 3).
    if (text.len == 0 or std.ascii.eqlIgnoreCase(std.mem.trim(u8, text, " \t\n\r\x0c"), "none")) return geometry.Matrix.identity;
    // TODO(geometry): parse a CSS <transform-list> (6.2 steps 2-6). Crane has
    // no transform-function parser yet; until it does, every other string
    // is reported as NotSupportedError rather than misread as invalid
    // (whose answer would be a SyntaxError).
    return error.NotSupportedError;
}

/// Geometry 6.3, the DOMMatrixReadOnly(init) constructor.
pub fn call_constructor(ctx: runtime.Context, init_data: webidl.Opt(runtime.JSValue)) !*runtime.Instance {
    return create(ctx, try matrixFromInit(ctx, init_data));
}

/// Getter for a: an alias of m11 - the m11 element (Geometry 6.4).
pub fn get_a(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m11;
}

/// Getter for b: an alias of m12 - the m12 element (Geometry 6.4).
pub fn get_b(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m12;
}

/// Getter for c: an alias of m21 - the m21 element (Geometry 6.4).
pub fn get_c(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m21;
}

/// Getter for d: an alias of m22 - the m22 element (Geometry 6.4).
pub fn get_d(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m22;
}

/// Getter for e: an alias of m41 - the m41 element (Geometry 6.4).
pub fn get_e(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m41;
}

/// Getter for f: an alias of m42 - the m42 element (Geometry 6.4).
pub fn get_f(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m42;
}

/// Getter for m11: the m11 element (Geometry 6.4).
pub fn get_m11(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m11;
}

/// Getter for m12: the m12 element (Geometry 6.4).
pub fn get_m12(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m12;
}

/// Getter for m13: the m13 element (Geometry 6.4).
pub fn get_m13(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m13;
}

/// Getter for m14: the m14 element (Geometry 6.4).
pub fn get_m14(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m14;
}

/// Getter for m21: the m21 element (Geometry 6.4).
pub fn get_m21(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m21;
}

/// Getter for m22: the m22 element (Geometry 6.4).
pub fn get_m22(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m22;
}

/// Getter for m23: the m23 element (Geometry 6.4).
pub fn get_m23(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m23;
}

/// Getter for m24: the m24 element (Geometry 6.4).
pub fn get_m24(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m24;
}

/// Getter for m31: the m31 element (Geometry 6.4).
pub fn get_m31(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m31;
}

/// Getter for m32: the m32 element (Geometry 6.4).
pub fn get_m32(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m32;
}

/// Getter for m33: the m33 element (Geometry 6.4).
pub fn get_m33(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m33;
}

/// Getter for m34: the m34 element (Geometry 6.4).
pub fn get_m34(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m34;
}

/// Getter for m41: the m41 element (Geometry 6.4).
pub fn get_m41(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m41;
}

/// Getter for m42: the m42 element (Geometry 6.4).
pub fn get_m42(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m42;
}

/// Getter for m43: the m43 element (Geometry 6.4).
pub fn get_m43(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m43;
}

/// Getter for m44: the m44 element (Geometry 6.4).
pub fn get_m44(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.m44;
}

/// Getter for is2D: the is 2D flag (Geometry 6.4).
pub fn get_is2D(instance: *runtime.Instance) anyerror!bool {
    return instance.getState(State).own.is2D;
}

/// Getter for isIdentity (Geometry 6.4): true when m12, m13, m14, m21, m23,
/// m24, m31, m32, m34, m41, m42 and m43 are 0 or -0 and m11, m22, m33 and
/// m44 are 1.
pub fn get_isIdentity(instance: *runtime.Instance) anyerror!bool {
    return matrixOf(instance).isIdentity();
}

/// The elements of a Float32Array or Float64Array argument, as numbers;
/// TypeError for any other value (the IDL type is the typed array).
fn floatArrayElements(ctx: runtime.Context, value: runtime.JSValue, comptime Float: type, values: *[16]f64) !usize {
    const view_type: runtime.arraybuffer_view.ViewType = if (Float == f32) .float32_array else .float64_array;
    const description = engine.describeArrayBufferView(ctx, value) orelse return error.TypeError;
    if (description.view_type != view_type) return error.TypeError;
    const bytes = (try engine.getCopyOfBufferSourceBytes(ctx, value, ctx.allocator)) orelse return error.TypeError;
    defer ctx.allocator.free(bytes);
    const count = bytes.len / @sizeOf(Float);
    // Neither 6 nor 16 elements: fromSequence's TypeError.
    if (count != 6 and count != 16) return error.TypeError;
    for (0..count) |i| {
        const bits = std.mem.readInt(std.meta.Int(.unsigned, @bitSizeOf(Float)), bytes[i * @sizeOf(Float) ..][0..@sizeOf(Float)], .little);
        values[i] = @floatCast(@as(Float, @bitCast(bits)));
    }
    return count;
}

/// Geometry 6.3, DOMMatrixReadOnly.fromFloat32Array(array32): 6 elements
/// make a 2d matrix, 16 a 3d matrix, in the provided order; otherwise a
/// TypeError.
pub fn call_static_fromFloat32Array(instance: *runtime.Instance, array32: runtime.JSValue) anyerror!*runtime.Instance {
    var values: [16]f64 = undefined;
    const count = try floatArrayElements(instance.ctx, array32, f32, &values);
    return create(instance.ctx, try geometry.Matrix.fromSequence(values[0..count]));
}

/// Geometry 6.3, DOMMatrixReadOnly.fromFloat64Array(array64): as
/// fromFloat32Array.
pub fn call_static_fromFloat64Array(instance: *runtime.Instance, array64: runtime.JSValue) anyerror!*runtime.Instance {
    var values: [16]f64 = undefined;
    const count = try floatArrayElements(instance.ctx, array64, f64, &values);
    return create(instance.ctx, try geometry.Matrix.fromSequence(values[0..count]));
}

/// Geometry 6.3, DOMMatrixReadOnly.fromMatrix(other): create a
/// DOMMatrixReadOnly from the dictionary other -
/// 1. Validate and fixup other.
/// 2. is2D true: create a 2d matrix from m11, m12, m21, m22, m41, m42;
///    otherwise a 3d matrix from all sixteen.
pub fn call_static_fromMatrix(instance: *runtime.Instance, other: webidl.Opt(dictionaries.DOMMatrixInit)) anyerror!*runtime.Instance {
    const dict = if (other.was_passed) other.value else dictionaries.DOMMatrixInit{ .base = .{} };
    return create(instance.ctx, try geometry.fromDictionary(geometry.matrixInitFrom(dict)));
}

/// Geometry 6.5, transformPoint(point): "1. Let pointObject be the result of
/// invoking create a DOMPoint from the dictionary point. 2. Return the
/// result of invoking transform a point with a matrix, given pointObject
/// and the current matrix. The passed argument does not get modified."
pub fn call_transformPoint(instance: *runtime.Instance, point: webidl.Opt(dictionaries.DOMPointInit)) anyerror!*runtime.Instance {
    // 1. (pointObject is never seen by script: its variables stand in.)
    const point_object = geometry.pointFrom(if (point.was_passed) point.value else dictionaries.DOMPointInit{});
    // 2. Geometry 2.1: a new DOMPoint with the transformed vector.
    const transformed = matrixOf(instance).transformPoint(point_object);
    return interfaces.DOMPoint.call_constructor(
        instance.ctx,
        webidl.Opt(f64).passed(transformed.x),
        webidl.Opt(f64).passed(transformed.y),
        webidl.Opt(f64).passed(transformed.z),
        webidl.Opt(f64).passed(transformed.w),
    );
}

/// The matrix's elements in column-major order as a new typed array of
/// `view_type` in the matrix's relevant realm.
fn toFloatArray(instance: *runtime.Instance, comptime Float: type) !runtime.JSValue {
    const matrix = matrixOf(instance);
    var bytes: [16 * @sizeOf(Float)]u8 = undefined;
    for (matrix.m, 0..) |element, i| {
        const narrowed: Float = @floatCast(element);
        std.mem.writeInt(std.meta.Int(.unsigned, @bitSizeOf(Float)), bytes[i * @sizeOf(Float) ..][0..@sizeOf(Float)], @bitCast(narrowed), .little);
    }
    const buffer = try engine.createArrayBuffer(instance.ctx, &bytes);
    defer buffer.release();
    const view_type: runtime.arraybuffer_view.ViewType = if (Float == f32) .float32_array else .float64_array;
    return (try engine.createArrayBufferView(instance.ctx, view_type, buffer.borrow(), 0, 16)).take();
}

/// Geometry 6.5, toFloat32Array(): the 16 elements m11 to m44, in
/// column-major order, as a new Float32Array.
pub fn call_toFloat32Array(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return toFloatArray(instance, f32);
}

/// Geometry 6.5, toFloat64Array(): as toFloat32Array, a Float64Array.
pub fn call_toFloat64Array(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return toFloatArray(instance, f64);
}

/// Per WebIDL spec, [Default] toJSON returns an object with all exposed attributes.
pub fn call_toJSON(instance: *runtime.Instance) anyerror!interfaces.DOMMatrixReadOnly.DOMMatrixReadOnlyToJSON {
    const matrix = matrixOf(instance);
    const m = matrix.m;
    return .{
        .a = m[geometry.index(1, 1)],
        .b = m[geometry.index(1, 2)],
        .c = m[geometry.index(2, 1)],
        .d = m[geometry.index(2, 2)],
        .e = m[geometry.index(4, 1)],
        .f = m[geometry.index(4, 2)],
        .m11 = m[geometry.index(1, 1)],
        .m12 = m[geometry.index(1, 2)],
        .m13 = m[geometry.index(1, 3)],
        .m14 = m[geometry.index(1, 4)],
        .m21 = m[geometry.index(2, 1)],
        .m22 = m[geometry.index(2, 2)],
        .m23 = m[geometry.index(2, 3)],
        .m24 = m[geometry.index(2, 4)],
        .m31 = m[geometry.index(3, 1)],
        .m32 = m[geometry.index(3, 2)],
        .m33 = m[geometry.index(3, 3)],
        .m34 = m[geometry.index(3, 4)],
        .m41 = m[geometry.index(4, 1)],
        .m42 = m[geometry.index(4, 2)],
        .m43 = m[geometry.index(4, 3)],
        .m44 = m[geometry.index(4, 4)],
        .is2D = matrix.is_2d,
        .isIdentity = matrix.isIdentity(),
    };
}

pub fn call_flipX(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

pub fn call_scale3d(instance: *runtime.Instance, scale: webidl.Opt(f64), originX: webidl.Opt(f64), originY: webidl.Opt(f64), originZ: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = scale;
    _ = originX;
    _ = originY;
    _ = originZ;
    return error.NotImplemented;
}

pub fn call_rotateAxisAngle(instance: *runtime.Instance, x: webidl.Opt(f64), y: webidl.Opt(f64), z: webidl.Opt(f64), angle: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = x;
    _ = y;
    _ = z;
    _ = angle;
    return error.NotImplemented;
}

pub fn call_skewY(instance: *runtime.Instance, sy: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = sy;
    return error.NotImplemented;
}

pub fn call_rotate(instance: *runtime.Instance, rotX: webidl.Opt(f64), rotY: webidl.Opt(f64), rotZ: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = rotX;
    _ = rotY;
    _ = rotZ;
    return error.NotImplemented;
}

pub fn call_inverse(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

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

pub fn call_translate(instance: *runtime.Instance, tx: webidl.Opt(f64), ty: webidl.Opt(f64), tz: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = tx;
    _ = ty;
    _ = tz;
    return error.NotImplemented;
}

pub fn call_multiply(instance: *runtime.Instance, other: webidl.Opt(dictionaries.DOMMatrixInit)) anyerror!*runtime.Instance {
    _ = instance;
    _ = other;
    return error.NotImplemented;
}

pub fn call_skewX(instance: *runtime.Instance, sx: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = sx;
    return error.NotImplemented;
}

pub fn call_scaleNonUniform(instance: *runtime.Instance, scaleX: webidl.Opt(f64), scaleY: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = scaleX;
    _ = scaleY;
    return error.NotImplemented;
}

pub fn call_flipY(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

pub fn call_rotateFromVector(instance: *runtime.Instance, x: webidl.Opt(f64), y: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

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

// ============================================================================
// Serializable objects (HTML 2.7.1; Geometry 7: DOMMatrixReadOnly is
// [Serializable])
// ============================================================================

/// Geometry 7, the serialization steps for DOMMatrixReadOnly and DOMMatrix,
/// given `value` and `serialized`:
/// 1. If value's is 2D is true: set serialized.[[M11]], [[M12]], [[M21]],
///    [[M22]], [[M41]] and [[M42]] to value's m11, m12, m21, m22, m41 and
///    m42 elements, and serialized.[[Is2D]] to true. (A 2D matrix's other
///    elements, -0 included, are not kept.)
/// 2. Otherwise: set serialized.[[M11]] to [[M44]] to value's m11 to m44
///    elements, and serialized.[[Is2D]] to false.
pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) !void {
    const matrix = matrixOf(value);
    try serialized.writeBool(matrix.is_2d);
    if (matrix.is_2d) {
        // Step 1.1-1.7.
        for ([_]usize{ geometry.index(1, 1), geometry.index(1, 2), geometry.index(2, 1), geometry.index(2, 2), geometry.index(4, 1), geometry.index(4, 2) }) |i| {
            try serialized.writeDouble(matrix.m[i]);
        }
    } else {
        // Step 2.1-2.17.
        for (matrix.m) |element| try serialized.writeDouble(element);
    }
}

/// Geometry 7, the deserialization steps for DOMMatrixReadOnly and
/// DOMMatrix, given `serialized` and `value`:
/// 1. If serialized.[[Is2D]] is true: set value's m11, m12, m21, m22, m41
///    and m42 elements to serialized's, m13, m14, m23, m24, m31, m32, m34
///    and m43 to 0, m33 and m44 to 1, and is 2D to true.
/// 2. Otherwise: set value's m11 to m44 elements to serialized's, and is 2D
///    to false.
pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) !void {
    _ = target_realm;
    if (try serialized.readBool()) {
        var six: [6]f64 = undefined;
        for (&six) |*element| element.* = try serialized.readDouble();
        setMatrix(value, geometry.Matrix.create2d(six));
    } else {
        var sixteen: [16]f64 = undefined;
        for (&sixteen) |*element| element.* = try serialized.readDouble();
        setMatrix(value, geometry.Matrix.create3d(sixteen));
    }
}
