//! Combining computed transform lists (the `transform` property and the
//! registered `<transform-list>` / `<transform-function>` syntaxes):
//! - interpolation, CSS Transforms 1 section 9 with CSS Transforms 2 section
//!   14: pad the shorter list with identity functions, combine pairs that
//!   share a name or a primitive, then interpolate the remaining functions
//!   of each list as two matrices (Transforms 2 section 13: decomposition,
//!   interpolation of the decomposed values with a quaternion slerp, and
//!   recomposition; Transforms 1 11.2 when both matrices are 2D);
//! - addition, Transforms 2 section 15: V_b appended to V_a;
//! - accumulation, Transforms 2 section 15: as interpolation, with each
//!   parameter added, one-based parameters (scale factors, m11/m22/m33/m44)
//!   as a + b - 1.
//!
//! Matrices are built by box_transform_values' own CTM composition (the one
//! getComputedStyle uses), never by a second product (lesson
//! spec-compliance-transform-composition-after-overflow). A list whose
//! matrix needs the reference box (a translate percentage) cannot be
//! decomposed without layout: Blink keeps an InterpolatedTransformOperation
//! and Gecko an interpolatematrix() until used-value time; Crane has no
//! layout, so such a pair combines discretely (geometry, outside 0.1).
//!
//! Engines (designs only): Blink TransformOperations::Blend and
//! BlendRemainingByUsingMatrixInterpolation, TransformOperation::
//! CommonPrimitiveForInterpolation, gfx::DecomposeTransform /
//! BlendDecomposedTransforms / Quaternion::Slerp; Gecko servo
//! style/values/animated/transform.rs (MatrixDecomposed2D/3D, Quaternion);
//! WebKit TransformOperations::blend, TransformationMatrix::decompose2/4.
//!
//! Every result is OWNED by the caller; inputs are borrowed. Null means the
//! pair has no smooth combination: the caller combines discretely.
//!
//! Spec: https://drafts.csswg.org/css-transforms-1/#interpolation-of-transforms
//! Spec: https://drafts.csswg.org/css-transforms-2/#interpolation-of-transform-functions
const std = @import("std");
const values = @import("style_values.zig");
const math = @import("math_values.zig");
const functions = @import("transform_functions.zig");
const box_transform_values = @import("box_transform_values.zig");
const Number = @import("numeric_values.zig").Number;
const interpolation = @import("interpolation.zig");

const Allocator = std.mem.Allocator;
const Value = values.Value;
const Function = functions.Function;
const Kind = functions.Kind;
const List = box_transform_values.List;
/// Column-major: element (column c, row r) is m[c * 4 + r].
const Matrix = box_transform_values.Matrix;

pub const Op = enum { interpolate, accumulate };

/// The functions of a computed transform value; `none` is the empty list.
pub fn listOf(v: Value) ?[]const Function {
    return switch (v) {
        .keyword => |k| if (k == .none) &.{} else null,
        .transform_list => |l| l.items,
        else => null,
    };
}

/// Interpolation (at `p`) or accumulation of two computed transform values.
/// OWNED; null for a pair that combines discretely.
pub fn combine(allocator: Allocator, a: Value, b: Value, p: f64, op: Op) Allocator.Error!?Value {
    const la = listOf(a) orelse return null;
    const lb = listOf(b) orelse return null;
    // Transforms 1 9: "If both Va and Vb are none: Vresult is none."
    if (la.len == 0 and lb.len == 0) return Value.kw(.none);
    // Values 4 3: "p = 0 produces V_A". With layout the interpolated list and
    // V_A resolve to one matrix; a list that needs the reference box (a
    // translate percentage) keeps its typed form here instead, where the
    // padding identities would show (`translateY(70%) scaleZ(1)` for
    // translateY(70%): WPT transform-interpolation-003 at 0, which Chrome,
    // Firefox and Safari pass).
    if (op == .interpolate and p == 0 and (box_transform_values.matrixOf(la) == null or box_transform_values.matrixOf(lb) == null)) {
        a.retain();
        return a;
    }
    const items = (try combineFunctions(allocator, la, lb, p, op)) orelse return null;
    return try listValue(allocator, items);
}

/// Transforms 2 section 15 addition: "Vresult is equal to Vb appended to
/// Va". OWNED; null when either is not a transform value.
pub fn add(allocator: Allocator, a: Value, b: Value) Allocator.Error!?Value {
    const la = listOf(a) orelse return null;
    const lb = listOf(b) orelse return null;
    if (la.len + lb.len == 0) return Value.kw(.none);
    const items = try allocator.alloc(Function, la.len + lb.len);
    var made: usize = 0;
    var copied = false;
    defer if (!copied) {
        for (items[0..made]) |*f| f.deinit();
        allocator.free(items);
    };
    for ([_][]const Function{ la, lb }) |list| for (list) |f| {
        items[made] = try copyFunction(allocator, f);
        made += 1;
    };
    // listValue takes `items` even when it fails.
    copied = true;
    return try listValue(allocator, items);
}

/// A transform_list value owning `items` (taken even on failure).
fn listValue(allocator: Allocator, items: []Function) Allocator.Error!Value {
    const list = allocator.create(List) catch |err| {
        for (items) |*f| f.deinit();
        allocator.free(items);
        return err;
    };
    list.* = .{ .allocator = allocator, .items = items };
    return .{ .transform_list = list };
}

/// Combines two function lists (Transforms 1 section 9). OWNED; null for a
/// discrete pair.
pub fn combineFunctions(allocator: Allocator, a: []const Function, b: []const Function, p: f64, op: Op) Allocator.Error!?[]Function {
    const n = @max(a.len, b.len);
    var out: std.ArrayList(Function) = .empty;
    var done = false;
    defer if (!done) {
        for (out.items) |*f| f.deinit();
        out.deinit(allocator);
    };
    var i: usize = 0;
    while (i < n) : (i += 1) {
        // "extend the shorter list to the length of the longer list,
        // setting the function at each additional position to the identity
        // transform function matching the function at the corresponding
        // position in the longer list".
        var pad: ?Function = null;
        defer if (pad) |*f| f.deinit();
        if (i >= a.len) pad = try identityFunction(allocator, b[i]) else if (i >= b.len) pad = try identityFunction(allocator, a[i]);
        const x = if (i < a.len) a[i] else pad.?;
        const y = if (i < b.len) b[i] else pad.?;
        // "While the functions have either the same name, or are
        // derivatives of the same primitive transform function, interpolate
        // the corresponding pair of functions ..."
        if (!sharePrimitive(x.kind, y.kind)) break;
        const f = (try combinePair(allocator, x, y, p, op)) orelse return null;
        out.append(allocator, f) catch |err| {
            var owned = f;
            owned.deinit();
            return err;
        };
    }
    if (i < n) {
        // "If the pair do not have a common name or primitive transform
        // function, post-multiply the remaining transform functions in each
        // of Va and Vb respectively to produce two 4x4 matrices. Interpolate
        // these two matrices ..., append the result to Vresult, and cease
        // iterating". Padding identities change no matrix, so the remaining
        // functions are the lists' own.
        const ma = box_transform_values.matrixOf(if (i < a.len) a[i..] else &.{}) orelse return null;
        const mb = box_transform_values.matrixOf(if (i < b.len) b[i..] else &.{}) orelse return null;
        const f = (try combineMatrices(allocator, ma, mb, p, op)) orelse return null;
        out.append(allocator, f) catch |err| {
            var owned = f;
            owned.deinit();
            return err;
        };
    }
    const owned = try out.toOwnedSlice(allocator);
    done = true;
    return owned;
}

// ============================================================================
// Primitives (Transforms 2 12.3 and section 14)
// ============================================================================

const Family = enum { translate, scale, rotate, skew, matrix, matrix3d, perspective };

fn family(kind: Kind) Family {
    return switch (kind) {
        .translate, .translateX, .translateY, .translateZ, .translate3d => .translate,
        .scale, .scaleX, .scaleY, .scaleZ, .scale3d => .scale,
        .rotate, .rotateX, .rotateY, .rotateZ, .rotate3d => .rotate,
        .skew, .skewX, .skewY => .skew,
        .matrix => .matrix,
        .matrix3d => .matrix3d,
        .perspective => .perspective,
    };
}

/// The same name, or derivatives of one primitive. Only translate(),
/// scale() and rotate() have derivatives (Transforms 1 7.2, Transforms 2
/// 12.3): skewX(), skewY() and skew() share no primitive, nor do matrix(),
/// matrix3d() and perspective() (WPT transform-interpolation-verify-
/// reftests: skewX(0deg) rotate(0deg) to skewY(0deg) rotate(360deg) is the
/// identity at 0.5 in Chrome, Firefox and Safari - a matrix pair).
fn sharePrimitive(a: Kind, b: Kind) bool {
    return switch (family(a)) {
        .translate, .scale, .rotate => family(a) == family(b),
        else => a == b,
    };
}

/// Whether `kind` is a 3D transform function (Transforms 2 section 12:
/// translateZ, translate3d, scaleZ, scale3d, rotateX, rotateY, rotateZ,
/// rotate3d, matrix3d, perspective).
fn threeDimensional(kind: Kind) bool {
    return switch (kind) {
        .translateZ, .translate3d, .scaleZ, .scale3d, .rotateX, .rotateY, .rotateZ, .rotate3d, .matrix3d, .perspective => true,
        else => false,
    };
}

/// One pair of functions sharing a primitive (section 14). OWNED.
fn combinePair(allocator: Allocator, x: Function, y: Function, p: f64, op: Op) Allocator.Error!?Function {
    switch (family(x.kind)) {
        // Two perspective() functions: the matrix interpolation of the spec
        // text changes only m34 = -1/d, linearly, so the result is the
        // perspective whose 1/d interpolates - which Chrome and Safari keep
        // as a perspective() function (Blink PerspectiveTransformOperation::
        // Blend; WPT transform-interpolation-computed-value expects
        // perspective(4px) between 10px and 2.5px, and Chrome 157 and Safari
        // 27.2 pass it; Firefox has no computedStyleMap). The matrix the
        // property resolves to is the same either way.
        .perspective => if (op == .interpolate) return try combinePerspectives(allocator, x, y, p),
        else => {},
    }
    switch (family(x.kind)) {
        // "The transform functions matrix(), matrix3d() and perspective()
        // get converted into 4x4 matrices first and interpolated as defined
        // in section Interpolation of Matrices afterwards."
        .matrix, .matrix3d, .perspective => {
            const ma = box_transform_values.matrixOf(&.{x}) orelse return null;
            const mb = box_transform_values.matrixOf(&.{y}) orelse return null;
            return try combineMatrices(allocator, ma, mb, p, op);
        },
        .rotate => return try combineRotations(allocator, x, y, p, op),
        else => {},
    }
    // "Two transform functions with the same name and the same number of
    // arguments are interpolated numerically without a former conversion."
    if (x.kind == y.kind and x.arguments.len == y.arguments.len) return try combineArguments(allocator, x.kind, x.arguments, y.arguments, p, op);
    // "Both transform functions need a former conversion to the common
    // primitive first ... If both transform functions share a primitive in
    // the two-dimensional space, both ... get converted to the
    // two-dimensional primitive. If one or both ... are three-dimensional
    // ..., the common three-dimensional primitive is used."
    const three_d = threeDimensional(x.kind) or threeDimensional(y.kind);
    var px = try primitive(allocator, x, three_d);
    defer px.deinit();
    var py = try primitive(allocator, y, three_d);
    defer py.deinit();
    return try combineArguments(allocator, px.kind, px.arguments, py.arguments, p, op);
}

/// `f` converted to its family's 2D or 3D primitive (Transforms 2 12.3):
/// translate(x, y) / translate3d(x, y, z), scale(sx, sy) / scale3d(sx, sy,
/// sz), skew(ax, ay), rotate3d(x, y, z, a). OWNED.
fn primitive(allocator: Allocator, f: Function, three_d: bool) Allocator.Error!Function {
    const zero_px: Number = .{ .literal = .{ .value = 0, .unit = .px } };
    const zero_deg: Number = .{ .literal = .{ .value = 0, .unit = .deg } };
    const one = Number.scalar(1);
    const zero = Number.scalar(0);
    const arg = f.arguments;
    var args: [4]Number = undefined;
    var count: usize = 0;
    var kind: Kind = f.kind;
    switch (family(f.kind)) {
        .translate => {
            kind = if (three_d) .translate3d else .translate;
            const xyz: [3]Number = switch (f.kind) {
                .translateX => .{ arg[0], zero_px, zero_px },
                .translateY => .{ zero_px, arg[0], zero_px },
                .translateZ => .{ zero_px, zero_px, arg[0] },
                .translate => .{ arg[0], if (arg.len > 1) arg[1] else zero_px, zero_px },
                else => .{ arg[0], arg[1], arg[2] },
            };
            count = if (three_d) 3 else 2;
            @memcpy(args[0..count], xyz[0..count]);
        },
        .scale => {
            kind = if (three_d) .scale3d else .scale;
            const xyz: [3]Number = switch (f.kind) {
                .scaleX => .{ arg[0], one, one },
                .scaleY => .{ one, arg[0], one },
                .scaleZ => .{ one, one, arg[0] },
                .scale => .{ arg[0], if (arg.len > 1) arg[1] else arg[0], one },
                else => .{ arg[0], arg[1], arg[2] },
            };
            count = if (three_d) 3 else 2;
            @memcpy(args[0..count], xyz[0..count]);
        },
        .skew => {
            kind = .skew;
            const xy: [2]Number = switch (f.kind) {
                .skewX => .{ arg[0], zero_deg },
                .skewY => .{ zero_deg, arg[0] },
                else => .{ arg[0], if (arg.len > 1) arg[1] else zero_deg },
            };
            count = 2;
            @memcpy(args[0..2], &xy);
        },
        .rotate => {
            kind = .rotate3d;
            const axis_angle: [4]Number = switch (f.kind) {
                .rotate, .rotateZ => .{ zero, zero, one, arg[0] },
                .rotateX => .{ one, zero, zero, arg[0] },
                .rotateY => .{ zero, one, zero, arg[0] },
                else => .{ arg[0], arg[1], arg[2], arg[3] },
            };
            count = 4;
            args = axis_angle;
        },
        .matrix, .matrix3d, .perspective => unreachable,
    }
    const owned = try allocator.dupe(Number, args[0..count]);
    for (owned) |n| n.ref();
    return .{ .allocator = allocator, .kind = kind, .arguments = owned, .computed = true };
}

/// The arguments of two functions of one kind combined one by one: a * (1 -
/// p) + b * p, or for accumulation a + b (a one-based scale factor a + b -
/// 1). OWNED; null when an argument pair does not mix.
fn combineArguments(allocator: Allocator, kind: Kind, a: []const Number, b: []const Number, p: f64, op: Op) Allocator.Error!?Function {
    std.debug.assert(a.len == b.len);
    const ka: f64, const kb: f64 = if (op == .interpolate) .{ 1 - p, p } else .{ 1, 1 };
    const one_based = op == .accumulate and family(kind) == .scale;
    const arguments = try allocator.alloc(Number, a.len);
    var made: usize = 0;
    var done = false;
    defer if (!done) {
        for (arguments[0..made]) |n| n.unref();
        allocator.free(arguments);
    };
    for (a, b, 0..) |x, y, index| {
        var mixed = (try interpolation.mixNumbers(allocator, x, ka, y, kb, argumentKind(kind, index))) orelse return null;
        if (one_based) if (literalOf(mixed)) |n| {
            mixed.unref();
            mixed = .{ .literal = .{ .value = n.value - 1, .unit = n.unit } };
        };
        arguments[made] = mixed;
        made += 1;
    }
    done = true;
    return .{ .allocator = allocator, .kind = kind, .arguments = arguments, .computed = true };
}

/// A transform function argument's numeric kind (Transforms 1 7, 2 12).
fn argumentKind(kind: Kind, index: usize) math.Kind {
    return switch (kind) {
        .translate, .translateX, .translateY => .length_percentage,
        .translateZ, .perspective => .length,
        .translate3d => if (index == 2) .length else .length_percentage,
        .scale, .scaleX, .scaleY, .scaleZ, .scale3d => .number_percentage,
        .rotate, .rotateX, .rotateY, .rotateZ, .skew, .skewX, .skewY => .angle,
        .rotate3d => if (index == 3) .angle else .number,
        .matrix, .matrix3d => .number,
    };
}

fn literalOf(n: Number) ?math.Numeric {
    return switch (n) {
        .literal => |l| l,
        .calculation => |c| c.computedNumber(),
    };
}

fn degreesOf(n: Number) ?f64 {
    const l = literalOf(n) orelse return null;
    return switch (l.unit) {
        .deg => l.value,
        .rad => l.value * 180 / std.math.pi,
        .grad => l.value * 0.9,
        .turn => l.value * 360,
        .number => if (l.value == 0) 0 else null,
        else => null,
    };
}

/// perspective(d) interpolated through 1/d (`none` is an infinite d, 1/d
/// = 0); a result whose 1/d is not positive is perspective(none). The used
/// depth's 1px floor (Transforms 2 12.3) applies at matrix time, as for any
/// perspective(). OWNED; null for a depth that is not a literal length.
fn combinePerspectives(allocator: Allocator, x: Function, y: Function, p: f64) Allocator.Error!?Function {
    const ix = inverseDepth(x) orelse return null;
    const iy = inverseDepth(y) orelse return null;
    const inverse_depth = ix * (1 - p) + iy * p;
    if (!(inverse_depth > 0)) return .{ .allocator = allocator, .kind = .perspective, .arguments = &.{}, .computed = true };
    const arguments = try allocator.alloc(Number, 1);
    arguments[0] = .{ .literal = .{ .value = 1 / inverse_depth, .unit = .px } };
    return .{ .allocator = allocator, .kind = .perspective, .arguments = arguments, .computed = true };
}

fn inverseDepth(f: Function) ?f64 {
    if (f.arguments.len == 0) return 0;
    const l = literalOf(f.arguments[0]) orelse return null;
    if (l.unit != .px) return null;
    return 1 / @max(l.value, 1);
}

/// The rotate family (section 14): two functions of the same name and
/// argument count other than rotate3d() interpolate their angle; otherwise
/// both convert to rotate3d() and "the direction vectors of the transform
/// functions get normalized first. If the normalized vectors are not equal
/// and both rotation angles are non-zero the transform functions get
/// converted into 4x4 matrices first and interpolated as defined in section
/// Interpolation of Matrices afterwards. Otherwise the rotation angle gets
/// interpolated numerically and the rotation vector of the non-zero angle is
/// used or (0, 0, 1) if both angles are zero."
fn combineRotations(allocator: Allocator, x: Function, y: Function, p: f64, op: Op) Allocator.Error!?Function {
    if (x.kind == y.kind and x.kind != .rotate3d) return try combineArguments(allocator, x.kind, x.arguments, y.arguments, p, op);
    var px = try primitive(allocator, x, true);
    defer px.deinit();
    var py = try primitive(allocator, y, true);
    defer py.deinit();
    const va = axisOf(px) orelse return null;
    const vb = axisOf(py) orelse return null;
    const angle_a = degreesOf(px.arguments[3]) orelse return null;
    const angle_b = degreesOf(py.arguments[3]) orelse return null;
    const same_axis = va[0] == vb[0] and va[1] == vb[1] and va[2] == vb[2];
    if (!same_axis and angle_a != 0 and angle_b != 0) {
        const ma = box_transform_values.matrixOf(&.{x}) orelse return null;
        const mb = box_transform_values.matrixOf(&.{y}) orelse return null;
        return try combineMatrices(allocator, ma, mb, p, op);
    }
    const axis: [3]f64 = if (angle_a != 0) va else if (angle_b != 0) vb else .{ 0, 0, 1 };
    const angle = switch (op) {
        .interpolate => angle_a * (1 - p) + angle_b * p,
        .accumulate => angle_a + angle_b,
    };
    // About a principal axis the result is rotateX/Y/Z() - the function of
    // the side whose angle is used, as Blink's RotateTransformOperation::
    // Blend keeps its type - so whole turns compose exactly
    // (box_transform_values' non-arbitrary rotation); otherwise rotate3d().
    const principal: ?Kind = if (axis[0] == 1 and axis[1] == 0 and axis[2] == 0) .rotateX else if (axis[0] == 0 and axis[1] == 1 and axis[2] == 0) .rotateY else if (axis[0] == 0 and axis[1] == 0 and axis[2] == 1) .rotateZ else null;
    if (principal) |kind| {
        const arguments = try allocator.alloc(Number, 1);
        arguments[0] = .{ .literal = .{ .value = angle, .unit = .deg } };
        return .{ .allocator = allocator, .kind = kind, .arguments = arguments, .computed = true };
    }
    const arguments = try allocator.alloc(Number, 4);
    for (arguments[0..3], axis) |*n, v| n.* = Number.scalar(v);
    arguments[3] = .{ .literal = .{ .value = angle, .unit = .deg } };
    return .{ .allocator = allocator, .kind = .rotate3d, .arguments = arguments, .computed = true };
}

/// A rotate3d() primitive's normalized direction vector; null for one that
/// is not literal or has no direction (the zero vector).
fn axisOf(f: Function) ?[3]f64 {
    var v: [3]f64 = undefined;
    for (&v, f.arguments[0..3]) |*out, n| {
        const l = literalOf(n) orelse return null;
        out.* = l.value;
    }
    const length = @sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    if (length == 0) return null;
    for (&v) |*c| c.* /= length;
    return v;
}

/// Transforms 2 12.3 "identity transform function": the function of
/// `like`'s kind that changes nothing - zero translations, rotations and
/// skews, unit scales, rotate3d() about the same axis by 0, the identity
/// matrix, and perspective(none). OWNED.
pub fn identityFunction(allocator: Allocator, like: Function) Allocator.Error!Function {
    if (like.kind == .perspective) return .{ .allocator = allocator, .kind = .perspective, .arguments = &.{}, .computed = true };
    const arguments = try allocator.alloc(Number, like.arguments.len);
    const zero_deg: Number = .{ .literal = .{ .value = 0, .unit = .deg } };
    const px: Number = .{ .literal = .{ .value = 0, .unit = .px } };
    for (arguments, 0..) |*argument, index| {
        argument.* = switch (like.kind) {
            .translate, .translateX, .translateY, .translateZ, .translate3d => px,
            .scale, .scaleX, .scaleY, .scaleZ, .scale3d => Number.scalar(1),
            .rotate, .rotateX, .rotateY, .rotateZ, .skew, .skewX, .skewY => zero_deg,
            .rotate3d => if (index < 3) blk: {
                like.arguments[index].ref();
                break :blk like.arguments[index];
            } else zero_deg,
            // matrix(1, 0, 0, 1, 0, 0) and the 4x4 identity.
            .matrix => Number.scalar(if (index == 0 or index == 3) 1 else 0),
            .matrix3d => Number.scalar(if (index % 5 == 0) 1 else 0),
            .perspective => unreachable,
        };
    }
    return .{ .allocator = allocator, .kind = like.kind, .arguments = arguments, .computed = true };
}

pub fn copyFunction(allocator: Allocator, f: Function) Allocator.Error!Function {
    const arguments = try allocator.dupe(Number, f.arguments);
    for (arguments) |argument| argument.ref();
    return .{ .allocator = allocator, .kind = f.kind, .arguments = arguments, .computed = f.computed };
}

// ============================================================================
// Matrices (Transforms 1 11.2, Transforms 2 section 13)
// ============================================================================

fn is2d(m: Matrix) bool {
    return m[2] == 0 and m[3] == 0 and m[6] == 0 and m[7] == 0 and m[8] == 0 and m[9] == 0 and
        m[10] == 1 and m[11] == 0 and m[14] == 0 and m[15] == 1;
}

/// Two matrices interpolated (or accumulated) through their decompositions,
/// as a matrix() function when both are 2D (Transforms 1 11.2) and a
/// matrix3d() otherwise (Transforms 2 13.1). Null when either cannot be
/// decomposed: "If one of the matrices for interpolation is non-invertible,
/// the used animation function must fall back to a discrete animation"
/// (Transforms 1 section 11). OWNED.
pub fn combineMatrices(allocator: Allocator, a: Matrix, b: Matrix, p: f64, op: Op) Allocator.Error!?Function {
    if (is2d(a) and is2d(b)) {
        var da = decompose2d(a) orelse return null;
        var db = decompose2d(b) orelse return null;
        const d = switch (op) {
            .interpolate => interpolate2d(&da, &db, p),
            .accumulate => accumulate2d(da, db),
        };
        const m = recompose2d(d);
        return try matrixFunction(allocator, .matrix, &.{ m[0], m[1], m[4], m[5], m[12], m[13] });
    }
    const da = decompose3d(a) orelse return null;
    const db = decompose3d(b) orelse return null;
    const d = switch (op) {
        .interpolate => interpolate3d(da, db, p),
        .accumulate => accumulate3d(da, db),
    };
    const m = recompose3d(d);
    return try matrixFunction(allocator, .matrix3d, &m);
}

fn matrixFunction(allocator: Allocator, kind: Kind, entries: []const f64) Allocator.Error!Function {
    const arguments = try allocator.alloc(Number, entries.len);
    for (arguments, entries) |*n, v| n.* = Number.scalar(v);
    return .{ .allocator = allocator, .kind = kind, .arguments = arguments, .computed = true };
}

fn identity() Matrix {
    return .{ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 };
}

/// a * b (column-major).
fn multiply(a: Matrix, b: Matrix) Matrix {
    var r: Matrix = @splat(0);
    for (0..4) |c| for (0..4) |row| {
        for (0..4) |k| r[c * 4 + row] += a[k * 4 + row] * b[c * 4 + k];
    };
    return r;
}

// --- 2D (Transforms 1 11.2) ------------------------------------------------

const Decomposed2d = struct {
    translate: [2]f64,
    scale: [2]f64,
    angle: f64,
    m11: f64,
    m12: f64,
    m21: f64,
    m22: f64,
};

/// Transforms 1 11.2.1 "Decomposing a 2D matrix" (unmatrix).
fn decompose2d(m: Matrix) ?Decomposed2d {
    var row0x = m[0];
    var row0y = m[1];
    var row1x = m[4];
    var row1y = m[5];
    var d: Decomposed2d = .{ .translate = .{ m[12], m[13] }, .scale = undefined, .angle = 0, .m11 = 1, .m12 = 0, .m21 = 0, .m22 = 1 };
    d.scale = .{ @sqrt(row0x * row0x + row0y * row0y), @sqrt(row1x * row1x + row1y * row1y) };
    // If determinant is negative, one axis was flipped.
    const det = row0x * row1y - row0y * row1x;
    // A singular matrix cannot be decomposed (Transforms 1 section 11).
    if (det == 0) return null;
    if (det < 0) {
        // Flip axis with minimum unit vector dot product.
        if (row0x < row1y) d.scale[0] = -d.scale[0] else d.scale[1] = -d.scale[1];
    }
    // Renormalize matrix to remove scale.
    if (d.scale[0] != 0) {
        row0x *= 1 / d.scale[0];
        row0y *= 1 / d.scale[0];
    }
    if (d.scale[1] != 0) {
        row1x *= 1 / d.scale[1];
        row1y *= 1 / d.scale[1];
    }
    // Compute rotation and renormalize matrix.
    var angle = std.math.atan2(row0y, row0x);
    if (angle != 0) {
        const sn = -row0y;
        const cs = row0x;
        const m11 = row0x;
        const m12 = row0y;
        const m21 = row1x;
        const m22 = row1y;
        row0x = cs * m11 + sn * m21;
        row0y = cs * m12 + sn * m22;
        row1x = -sn * m11 + cs * m21;
        row1y = -sn * m12 + cs * m22;
    }
    d.m11 = row0x;
    d.m12 = row0y;
    d.m21 = row1x;
    d.m22 = row1y;
    // Convert into degrees because our rotation functions expect it.
    angle = angle * 180 / std.math.pi;
    d.angle = angle;
    return d;
}

/// Transforms 1 11.2.2: the angle and flip fix-ups, then every component
/// interpolated linearly.
fn interpolate2d(a: *Decomposed2d, b: *Decomposed2d, p: f64) Decomposed2d {
    // If x-axis of one is flipped, and y-axis of the other, convert to an
    // unflipped rotation.
    if ((a.scale[0] < 0 and b.scale[1] < 0) or (a.scale[1] < 0 and b.scale[0] < 0)) {
        a.scale[0] = -a.scale[0];
        a.scale[1] = -a.scale[1];
        a.angle += if (a.angle < 0) 180 else -180;
    }
    // Don't rotate the long way around.
    if (a.angle == 0) a.angle = 360;
    if (b.angle == 0) b.angle = 360;
    if (@abs(a.angle - b.angle) > 180) {
        if (a.angle > b.angle) a.angle -= 360 else b.angle -= 360;
    }
    return .{
        .translate = .{ lerp(a.translate[0], b.translate[0], p), lerp(a.translate[1], b.translate[1], p) },
        .scale = .{ lerp(a.scale[0], b.scale[0], p), lerp(a.scale[1], b.scale[1], p) },
        .angle = lerp(a.angle, b.angle, p),
        .m11 = lerp(a.m11, b.m11, p),
        .m12 = lerp(a.m12, b.m12, p),
        .m21 = lerp(a.m21, b.m21, p),
        .m22 = lerp(a.m22, b.m22, p),
    };
}

/// Transforms 2 section 15 for decomposed 2D values: components add, the
/// one-based ones (scales, m11, m22) as a + b - 1.
fn accumulate2d(a: Decomposed2d, b: Decomposed2d) Decomposed2d {
    return .{
        .translate = .{ a.translate[0] + b.translate[0], a.translate[1] + b.translate[1] },
        .scale = .{ a.scale[0] + b.scale[0] - 1, a.scale[1] + b.scale[1] - 1 },
        .angle = a.angle + b.angle,
        .m11 = a.m11 + b.m11 - 1,
        .m12 = a.m12 + b.m12,
        .m21 = a.m21 + b.m21,
        .m22 = a.m22 + b.m22 - 1,
    };
}

/// Transforms 1 11.2.3 "Recomposing to a 2D matrix": the 2x2 residual,
/// then the translation, rotation and scale post-multiplied.
fn recompose2d(d: Decomposed2d) Matrix {
    var m = identity();
    m[0] = d.m11;
    m[1] = d.m12;
    m[4] = d.m21;
    m[5] = d.m22;
    // Translate matrix. The spec text multiplies the translation by the
    // 2x2 residual; Chrome and Firefox keep it as decomposed (Gecko servo
    // MatrixDecomposed2D -> Matrix3D sets m41/m42 directly), and WPT
    // transform-interpolation-005's matrix(1, 0.36, 0, 1, 200, 200) pairs,
    // which both pass and Safari fails, need that.
    m[12] = d.translate[0];
    m[13] = d.translate[1];
    // Rotate matrix. Whole quarter turns are exact (the 0 -> 360 fix-up of
    // 11.2.2 must not leave sin(2pi)'s rounding in the result), as Crane's
    // transform functions compose them (box_transform_values, after
    // Chromium's SinCosDegrees).
    const sin_angle, const cos_angle = sinCosDegrees(d.angle);
    var rotate = identity();
    rotate[0] = cos_angle;
    rotate[1] = sin_angle;
    rotate[4] = -sin_angle;
    rotate[5] = cos_angle;
    m = multiply(m, rotate);
    // Scale matrix.
    m[0] *= d.scale[0];
    m[1] *= d.scale[0];
    m[4] *= d.scale[1];
    m[5] *= d.scale[1];
    return m;
}

/// (sin, cos) of `degrees`, exact at multiples of 90.
fn sinCosDegrees(degrees: f64) struct { f64, f64 } {
    const turn = @mod(degrees, 360);
    if (turn == 0) return .{ 0, 1 };
    if (turn == 90) return .{ 1, 0 };
    if (turn == 180) return .{ 0, -1 };
    if (turn == 270) return .{ -1, 0 };
    const radians = degrees * std.math.pi / 180;
    return .{ @sin(radians), @cos(radians) };
}

fn lerp(a: f64, b: f64, p: f64) f64 {
    return a + (b - a) * p;
}

// --- 3D (Transforms 2 13.1) ------------------------------------------------

const Decomposed3d = struct {
    translate: [3]f64,
    scale: [3]f64,
    skew: [3]f64,
    perspective: [4]f64,
    quaternion: [4]f64,
};

/// Transforms 2 13.1.1 "Decomposing a 3D matrix".
fn decompose3d(input: Matrix) ?Decomposed3d {
    // Normalize the matrix.
    if (input[15] == 0) return null;
    var m = input;
    for (&m) |*e| e.* /= input[15];
    // perspectiveMatrix is used to solve for perspective, but it also
    // provides an easy way to test for singularity of the upper 3x3
    // component.
    var perspective_matrix = m;
    for (0..3) |i| perspective_matrix[i * 4 + 3] = 0;
    perspective_matrix[15] = 1;
    if (determinant(perspective_matrix) == 0) return null;
    var d: Decomposed3d = undefined;
    // First, isolate perspective.
    if (m[3] != 0 or m[7] != 0 or m[11] != 0) {
        const rhs: [4]f64 = .{ m[3], m[7], m[11], m[15] };
        const inverse_perspective = inverse(perspective_matrix) orelse return null;
        const transposed = transpose(inverse_perspective);
        d.perspective = multVecMatrix(rhs, transposed);
    } else {
        d.perspective = .{ 0, 0, 0, 1 };
    }
    // Next take care of translation.
    for (0..3) |i| d.translate[i] = m[12 + i];
    // Now get scale and shear.
    var row: [3][3]f64 = undefined;
    for (0..3) |i| row[i] = .{ m[i * 4 + 0], m[i * 4 + 1], m[i * 4 + 2] };
    // Compute X scale factor and normalize first row.
    d.scale[0] = length3(row[0]);
    row[0] = normalize3(row[0]);
    // Compute XY shear factor and make 2nd row orthogonal to 1st.
    d.skew[0] = dot3(row[0], row[1]);
    row[1] = combine3(row[1], row[0], 1.0, -d.skew[0]);
    // Now, compute Y scale and normalize 2nd row.
    d.scale[1] = length3(row[1]);
    row[1] = normalize3(row[1]);
    d.skew[0] /= d.scale[1];
    // Compute XZ and YZ shears, orthogonalize 3rd row.
    d.skew[1] = dot3(row[0], row[2]);
    row[2] = combine3(row[2], row[0], 1.0, -d.skew[1]);
    d.skew[2] = dot3(row[1], row[2]);
    row[2] = combine3(row[2], row[1], 1.0, -d.skew[2]);
    // Next, get Z scale and normalize 3rd row.
    d.scale[2] = length3(row[2]);
    row[2] = normalize3(row[2]);
    d.skew[1] /= d.scale[2];
    d.skew[2] /= d.scale[2];
    // At this point, the matrix (in rows) is orthonormal. Check for a
    // coordinate system flip. If the determinant is -1, then negate the
    // matrix and the scaling factors.
    const pdum3 = cross3(row[1], row[2]);
    if (dot3(row[0], pdum3) < 0) {
        for (0..3) |i| {
            d.scale[i] *= -1;
            for (0..3) |j| row[i][j] *= -1;
        }
    }
    // Now, get the rotations out.
    d.quaternion[0] = 0.5 * @sqrt(@max(1 + row[0][0] - row[1][1] - row[2][2], 0));
    d.quaternion[1] = 0.5 * @sqrt(@max(1 - row[0][0] + row[1][1] - row[2][2], 0));
    d.quaternion[2] = 0.5 * @sqrt(@max(1 - row[0][0] - row[1][1] + row[2][2], 0));
    d.quaternion[3] = 0.5 * @sqrt(@max(1 + row[0][0] + row[1][1] + row[2][2], 0));
    if (row[2][1] > row[1][2]) d.quaternion[0] = -d.quaternion[0];
    if (row[0][2] > row[2][0]) d.quaternion[1] = -d.quaternion[1];
    if (row[1][0] > row[0][1]) d.quaternion[2] = -d.quaternion[2];
    return d;
}

/// Transforms 2 13.1.2: translation, scale, skew and perspective
/// linearly, the quaternions by Slerp.
fn interpolate3d(a: Decomposed3d, b: Decomposed3d, p: f64) Decomposed3d {
    var d: Decomposed3d = undefined;
    for (0..3) |i| {
        d.translate[i] = lerp(a.translate[i], b.translate[i], p);
        d.scale[i] = lerp(a.scale[i], b.scale[i], p);
        d.skew[i] = lerp(a.skew[i], b.skew[i], p);
    }
    for (0..4) |i| d.perspective[i] = lerp(a.perspective[i], b.perspective[i], p);
    d.quaternion = slerp(a.quaternion, b.quaternion, p);
    return d;
}

/// Transforms 2 section 15 for decomposed 3D values: translation, skew and
/// perspective add (perspective's w is one-based), scales as a + b - 1, and
/// the rotations compose - the quaternion product (Blink
/// AccumulateDecomposedTransforms; Gecko Quaternion::accumulate).
fn accumulate3d(a: Decomposed3d, b: Decomposed3d) Decomposed3d {
    var d: Decomposed3d = undefined;
    for (0..3) |i| {
        d.translate[i] = a.translate[i] + b.translate[i];
        d.scale[i] = a.scale[i] + b.scale[i] - 1;
        d.skew[i] = a.skew[i] + b.skew[i];
        d.perspective[i] = a.perspective[i] + b.perspective[i];
    }
    d.perspective[3] = a.perspective[3] + b.perspective[3] - 1;
    const x1, const y1, const z1, const w1 = a.quaternion;
    const x2, const y2, const z2, const w2 = b.quaternion;
    d.quaternion = .{
        w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
        w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
        w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2,
        w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2,
    };
    return d;
}

/// Transforms 2 13.1.2's Slerp. The equality test uses Chromium's epsilon
/// (gfx::Quaternion::Slerp, kEpsilon 1e-5): two quaternions that differ
/// only by rounding face the same direction.
fn slerp(qa: [4]f64, qb: [4]f64, t: f64) [4]f64 {
    var product = qa[0] * qb[0] + qa[1] * qb[1] + qa[2] * qb[2] + qa[3] * qb[3];
    // Clamp product to -1.0 <= product <= 1.0.
    product = std.math.clamp(product, -1.0, 1.0);
    const epsilon = 1e-5;
    if (@abs(product - 1.0) < epsilon or @abs(product + 1.0) < epsilon) return qa;
    const theta = std.math.acos(product);
    const w = @sin(t * theta) / @sqrt(1 - product * product);
    var out: [4]f64 = undefined;
    for (0..4) |i| out[i] = qa[i] * (@cos(t * theta) - product * w) + qb[i] * w;
    return out;
}

/// Transforms 2 13.1.3 "Recomposing to a 3D matrix".
fn recompose3d(d: Decomposed3d) Matrix {
    var m = identity();
    // apply perspective
    for (0..4) |i| m[i * 4 + 3] = d.perspective[i];
    // apply translation
    for (0..4) |i| for (0..3) |j| {
        m[12 + i] += d.translate[j] * m[j * 4 + i];
    };
    // apply rotation
    const x = d.quaternion[0];
    const y = d.quaternion[1];
    const z = d.quaternion[2];
    const w = d.quaternion[3];
    // The spec lists rotationMatrix[i][j] here as (row i, column j) -
    // the transpose of its own [column][row] convention elsewhere - which is
    // how Chromium's ComposeTransform builds it (set_rc) and the only
    // reading that recomposes 13.1.1's quaternion to the matrix it came from
    // (WPT transform-interpolation-001: rotate3d(1, 1, 0, 90deg) at 0).
    var rotation = identity();
    rotation[0] = 1 - 2 * (y * y + z * z);
    rotation[4] = 2 * (x * y - z * w);
    rotation[8] = 2 * (x * z + y * w);
    rotation[1] = 2 * (x * y + z * w);
    rotation[5] = 1 - 2 * (x * x + z * z);
    rotation[9] = 2 * (y * z - x * w);
    rotation[2] = 2 * (x * z - y * w);
    rotation[6] = 2 * (y * z + x * w);
    rotation[10] = 1 - 2 * (x * x + y * y);
    m = multiply(m, rotation);
    // apply skew
    var temp = identity();
    if (d.skew[2] != 0) {
        temp[2 * 4 + 1] = d.skew[2];
        m = multiply(m, temp);
    }
    if (d.skew[1] != 0) {
        temp[2 * 4 + 1] = 0;
        temp[2 * 4 + 0] = d.skew[1];
        m = multiply(m, temp);
    }
    if (d.skew[0] != 0) {
        temp[2 * 4 + 0] = 0;
        temp[1 * 4 + 0] = d.skew[0];
        m = multiply(m, temp);
    }
    // apply scale
    for (0..3) |i| for (0..4) |j| {
        m[i * 4 + j] *= d.scale[i];
    };
    return m;
}

fn length3(v: [3]f64) f64 {
    return @sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
}

fn normalize3(v: [3]f64) [3]f64 {
    const l = length3(v);
    if (l == 0) return v;
    return .{ v[0] / l, v[1] / l, v[2] / l };
}

fn dot3(a: [3]f64, b: [3]f64) f64 {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

fn combine3(a: [3]f64, b: [3]f64, ascl: f64, bscl: f64) [3]f64 {
    return .{ a[0] * ascl + b[0] * bscl, a[1] * ascl + b[1] * bscl, a[2] * ascl + b[2] * bscl };
}

fn cross3(a: [3]f64, b: [3]f64) [3]f64 {
    return .{ a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0] };
}

fn transpose(m: Matrix) Matrix {
    var r: Matrix = undefined;
    for (0..4) |c| for (0..4) |row| {
        r[c * 4 + row] = m[row * 4 + c];
    };
    return r;
}

/// The spec's multVecMatrix (Graphics Gems' V4MulPointByMatrix; WebKit
/// v4MulPointByMatrix): result[i] = sum over j of v[j] * matrix[j][i], with
/// matrix[j][i] the element in column j, row i.
fn multVecMatrix(v: [4]f64, m: Matrix) [4]f64 {
    var r: [4]f64 = undefined;
    for (0..4) |i| r[i] = v[0] * m[0 * 4 + i] + v[1] * m[1 * 4 + i] + v[2] * m[2 * 4 + i] + v[3] * m[3 * 4 + i];
    return r;
}

/// The 3x3 minor's determinant used by the 4x4 cofactor expansion.
fn determinant(m: Matrix) f64 {
    var result: f64 = 0;
    for (0..4) |c| result += m[c * 4] * cofactor(m, c, 0);
    return result;
}

/// The cofactor of element (column c, row r).
fn cofactor(m: Matrix, c: usize, r: usize) f64 {
    var minor: [9]f64 = undefined;
    var k: usize = 0;
    for (0..4) |cc| {
        if (cc == c) continue;
        for (0..4) |rr| {
            if (rr == r) continue;
            minor[k] = m[cc * 4 + rr];
            k += 1;
        }
    }
    const det3 = minor[0] * (minor[4] * minor[8] - minor[5] * minor[7]) -
        minor[3] * (minor[1] * minor[8] - minor[2] * minor[7]) +
        minor[6] * (minor[1] * minor[5] - minor[2] * minor[4]);
    return if ((c + r) % 2 == 0) det3 else -det3;
}

/// The inverse by the adjugate; null for a singular matrix.
fn inverse(m: Matrix) ?Matrix {
    const det = determinant(m);
    if (det == 0) return null;
    var r: Matrix = undefined;
    // inverse = adjugate / det, adjugate(c, r) = cofactor(r, c).
    for (0..4) |c| for (0..4) |row| {
        r[c * 4 + row] = cofactor(m, row, c) / det;
    };
    return r;
}

// ============================================================================
// The rotate property (Transforms 2 section 5: "as SLERP")
// ============================================================================

/// A rotation as an axis (any length) and an angle in degrees.
pub const AxisAngle = struct { axis: [3]f64, angle: f64 };

/// rotate's "as SLERP": two rotations about the same normalized axis (or
/// with one zero angle) interpolate their angle numerically, keeping whole
/// turns; otherwise both convert to unit quaternions, slerp (Transforms 2
/// 13.1.2), and convert back to an axis and an angle (Blink
/// RotateTransformOperation::Blend and gfx::Quaternion; Gecko
/// Rotate::animate). Null for an axis with no direction.
pub fn mixAxisAngle(a: AxisAngle, b: AxisAngle, p: f64) ?AxisAngle {
    const na = normalizeAxis(a.axis) orelse return null;
    const nb = normalizeAxis(b.axis) orelse return null;
    const same = na[0] == nb[0] and na[1] == nb[1] and na[2] == nb[2];
    if (same or a.angle == 0 or b.angle == 0) {
        const axis = if (same or a.angle != 0) a.axis else b.axis;
        return .{ .axis = axis, .angle = lerp(a.angle, b.angle, p) };
    }
    const q = slerp(quaternionOf(na, a.angle), quaternionOf(nb, b.angle), p);
    return axisAngleOf(q);
}

/// Addition of two rotations: the same axis adds the angles; otherwise the
/// rotations compose, `a` then `b` (the quaternion product; Blink
/// Rotation::Add).
pub fn addAxisAngle(a: AxisAngle, b: AxisAngle) ?AxisAngle {
    const na = normalizeAxis(a.axis) orelse return null;
    const nb = normalizeAxis(b.axis) orelse return null;
    const same = na[0] == nb[0] and na[1] == nb[1] and na[2] == nb[2];
    if (same or a.angle == 0 or b.angle == 0) {
        const axis = if (same or a.angle != 0) a.axis else b.axis;
        return .{ .axis = axis, .angle = a.angle + b.angle };
    }
    const x1, const y1, const z1, const w1 = quaternionOf(na, a.angle);
    const x2, const y2, const z2, const w2 = quaternionOf(nb, b.angle);
    return axisAngleOf(.{
        w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
        w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
        w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2,
        w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2,
    });
}

fn normalizeAxis(v: [3]f64) ?[3]f64 {
    const l = length3(v);
    if (l == 0) return null;
    return .{ v[0] / l, v[1] / l, v[2] / l };
}

/// The unit quaternion of a rotation by `angle` degrees about the unit
/// `axis`: (axis * sin(angle / 2), cos(angle / 2)).
fn quaternionOf(axis: [3]f64, angle: f64) [4]f64 {
    const half = angle * std.math.pi / 360;
    const s = @sin(half);
    return .{ axis[0] * s, axis[1] * s, axis[2] * s, @cos(half) };
}

/// A unit quaternion back to an axis and an angle in degrees; the identity
/// rotation is 0deg about z.
fn axisAngleOf(q: [4]f64) AxisAngle {
    const w = std.math.clamp(q[3], -1.0, 1.0);
    const angle = 2 * std.math.acos(w) * 180 / std.math.pi;
    const s = @sqrt(1 - w * w);
    if (s < 1e-8) return .{ .axis = .{ 0, 0, 1 }, .angle = 0 };
    return .{ .axis = .{ q[0] / s, q[1] / s, q[2] / s }, .angle = angle };
}
