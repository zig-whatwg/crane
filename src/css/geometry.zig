//! Geometry Interfaces Module Level 1: the abstract point and matrix
//! algorithms DOMPointReadOnly, DOMMatrixReadOnly and DOMMatrix share - "create
//! a 2d/3d matrix" (6.3), "validate and fixup" a DOMMatrixInit (6.1), the
//! is-2D rules of the element setters and isIdentity (6.4), and "transform a
//! point with a matrix" (2.1).
//!
//! Pure: numbers in, numbers out. The interfaces convert their arguments (a
//! DOMMatrixInit dictionary, a sequence, a Float32Array) to these plain types
//! and keep the results in their own state.
//!
//! Spec: https://drafts.fxtf.org/geometry/

const std = @import("std");

/// A point's x coordinate, y coordinate, z coordinate and w perspective.
pub const Point = struct {
    x: f64 = 0,
    y: f64 = 0,
    z: f64 = 0,
    w: f64 = 1,
};

/// A rectangle's x coordinate, y coordinate, width dimension and height
/// dimension.
pub const Rect = struct {
    x: f64 = 0,
    y: f64 = 0,
    width: f64 = 0,
    height: f64 = 0,

    /// "min(y coordinate, y coordinate + height dimension)" - the top
    /// attribute (Geometry 3); right, bottom and left are the same shape.
    /// NaN in either operand gives NaN, as ECMAScript's Math.min does.
    pub fn top(self: Rect) f64 {
        return jsMin(self.y, self.y + self.height);
    }
    pub fn right(self: Rect) f64 {
        return jsMax(self.x, self.x + self.width);
    }
    pub fn bottom(self: Rect) f64 {
        return jsMax(self.y, self.y + self.height);
    }
    pub fn left(self: Rect) f64 {
        return jsMin(self.x, self.x + self.width);
    }
};

/// ECMAScript Math.min of two numbers: NaN wins, and -0 is less than +0.
fn jsMin(a: f64, b: f64) f64 {
    if (std.math.isNan(a) or std.math.isNan(b)) return std.math.nan(f64);
    if (a == 0 and b == 0) return if (std.math.signbit(a)) a else b;
    return @min(a, b);
}

/// ECMAScript Math.max of two numbers: NaN wins, and +0 is greater than -0.
fn jsMax(a: f64, b: f64) f64 {
    if (std.math.isNan(a) or std.math.isNan(b)) return std.math.nan(f64);
    if (a == 0 and b == 0) return if (std.math.signbit(a)) b else a;
    return @max(a, b);
}

/// The element names in column-major order, the order of `Matrix.m`.
pub const element_names = [16][]const u8{
    "m11", "m12", "m13", "m14",
    "m21", "m22", "m23", "m24",
    "m31", "m32", "m33", "m34",
    "m41", "m42", "m43", "m44",
};

/// Index of an element in `Matrix.m`: m(1, 1) is 0, m(1, 2) 1, m(2, 1) 4.
pub fn index(comptime column: usize, comptime row: usize) usize {
    return (column - 1) * 4 + (row - 1);
}

/// A 4x4 abstract matrix and its "is 2D" flag.
pub const Matrix = struct {
    /// m11 element to m44 element, column-major (m11, m12, m13, m14, m21, ...).
    m: [16]f64,
    is_2d: bool,

    pub const identity: Matrix = create2d(.{ 1, 0, 0, 1, 0, 0 });

    /// 6.3 "create a 2d matrix" with a sequence `init` of 6 elements:
    /// 2. Set m11, m12, m21, m22, m41 and m42 to init's values in order.
    /// 3. Set m13, m14, m23, m24, m31, m32, m34 and m43 to 0.
    /// 4. Set m33 and m44 to 1.
    /// 5. Set is 2D to true.
    pub fn create2d(init: [6]f64) Matrix {
        var m = [_]f64{0} ** 16;
        m[index(1, 1)] = init[0];
        m[index(1, 2)] = init[1];
        m[index(2, 1)] = init[2];
        m[index(2, 2)] = init[3];
        m[index(4, 1)] = init[4];
        m[index(4, 2)] = init[5];
        m[index(3, 3)] = 1;
        m[index(4, 4)] = 1;
        return .{ .m = m, .is_2d = true };
    }

    /// 6.3 "create a 3d matrix" with a sequence `init` of 16 elements:
    /// 2. Set m11 element to m44 element to init's values in column-major
    ///    order.
    /// 3. Set is 2D to false.
    pub fn create3d(init: [16]f64) Matrix {
        return .{ .m = init, .is_2d = false };
    }

    /// The constructors' and fromFloat32Array/fromFloat64Array's choice: a
    /// sequence of 6 elements makes a 2d matrix, of 16 a 3d matrix;
    /// anything else is a TypeError.
    pub fn fromSequence(values: []const f64) error{TypeError}!Matrix {
        return switch (values.len) {
            6 => create2d(values[0..6].*),
            16 => create3d(values[0..16].*),
            else => error.TypeError,
        };
    }

    /// 6.4 isIdentity: m12, m13, m14, m21, m23, m24, m31, m32, m34, m41, m42
    /// and m43 are 0 or -0, and m11, m22, m33 and m44 are 1.
    pub fn isIdentity(self: Matrix) bool {
        for (self.m, 0..) |value, i| {
            const diagonal = i % 5 == 0;
            if (value != @as(f64, if (diagonal) 1 else 0)) return false;
        }
        return true;
    }

    /// 6.4, DOMMatrix's element setters: "set the mNN element to the new
    /// value and, if the new value is not 0 or -0 [m33, m44: not 1], set is
    /// 2D to false". m11, m12, m21, m22, m41 and m42 leave is 2D as it is.
    pub fn setElement(self: *Matrix, i: usize, value: f64) void {
        self.m[i] = value;
        switch (i) {
            index(1, 1), index(1, 2), index(2, 1), index(2, 2), index(4, 1), index(4, 2) => {},
            index(3, 3), index(4, 4) => if (value != 1) {
                self.is_2d = false;
            },
            else => if (value != 0) {
                self.is_2d = false;
            },
        }
    }

    /// 2.1 "transform a point with a matrix": the point's column vector
    /// (x, y, z, w), pre-multiplied by the matrix (matrix . vector).
    pub fn transformPoint(self: Matrix, point: Point) Point {
        const v = [4]f64{ point.x, point.y, point.z, point.w };
        var out: [4]f64 = undefined;
        for (0..4) |row| {
            var sum: f64 = 0;
            for (0..4) |column| sum += self.m[column * 4 + row] * v[column];
            out[row] = sum;
        }
        return .{ .x = out[0], .y = out[1], .z = out[2], .w = out[3] };
    }
};

/// A DOMMatrixInit (6.1), as plain optionals: the 2D members a-f, m11, m12,
/// m21, m22, m41 and m42 and is2D may be absent; the others have defaults.
/// A DOMMatrix2DInit is one whose 3D members keep their defaults.
pub const MatrixInit = struct {
    a: ?f64 = null,
    b: ?f64 = null,
    c: ?f64 = null,
    d: ?f64 = null,
    e: ?f64 = null,
    f: ?f64 = null,
    m11: ?f64 = null,
    m12: ?f64 = null,
    m21: ?f64 = null,
    m22: ?f64 = null,
    m41: ?f64 = null,
    m42: ?f64 = null,
    m13: f64 = 0,
    m14: f64 = 0,
    m23: f64 = 0,
    m24: f64 = 0,
    m31: f64 = 0,
    m32: f64 = 0,
    m33: f64 = 1,
    m34: f64 = 0,
    m43: f64 = 0,
    m44: f64 = 1,
    is2D: ?bool = null,
};

/// A DOMMatrixInit or DOMMatrix2DInit as a binding converts it (its 2D
/// members, in `base` for a DOMMatrixInit, and its 3D members as optionals)
/// as a MatrixInit: a 3D member left out takes its IDL default.
pub fn matrixInitFrom(dict: anytype) MatrixInit {
    const T = @TypeOf(dict);
    const two_d = if (@hasField(T, "base")) dict.base else dict;
    var out: MatrixInit = .{};
    inline for (.{ "a", "b", "c", "d", "e", "f", "m11", "m12", "m21", "m22", "m41", "m42" }) |name| {
        @field(out, name) = @field(two_d, name);
    }
    if (@hasField(T, "base")) {
        inline for (.{ "m13", "m14", "m23", "m24", "m31", "m32", "m33", "m34", "m43", "m44" }) |name| {
            if (@field(dict, name)) |value| @field(out, name) = value;
        }
        out.is2D = dict.is2D;
    }
    return out;
}

/// A DOMPointInit as a binding converts it (members as optionals) as a
/// Point: a member left out takes its IDL default (x, y, z 0; w 1).
pub fn pointFrom(dict: anytype) Point {
    return .{ .x = dict.x orelse 0, .y = dict.y orelse 0, .z = dict.z orelse 0, .w = dict.w orelse 1 };
}

/// ECMAScript SameValueZero for numbers: NaN equals NaN, 0 equals -0.
fn sameValueZero(a: f64, b: f64) bool {
    if (std.math.isNan(a) and std.math.isNan(b)) return true;
    return a == b;
}

/// 6.1 "validate and fixup (2D)" `dict`.
pub fn validateAndFixup2d(dict: *MatrixInit) error{TypeError}!void {
    // 1. A member and its alias both present but not SameValueZero is a
    //    TypeError.
    const pairs = [_]struct { ?f64, ?f64 }{
        .{ dict.a, dict.m11 }, .{ dict.b, dict.m12 }, .{ dict.c, dict.m21 },
        .{ dict.d, dict.m22 }, .{ dict.e, dict.m41 }, .{ dict.f, dict.m42 },
    };
    for (pairs) |pair| {
        if (pair[0]) |alias| if (pair[1]) |element| {
            if (!sameValueZero(alias, element)) return error.TypeError;
        };
    }
    // 2-7. An element not present takes its alias, or its identity value.
    if (dict.m11 == null) dict.m11 = dict.a orelse 1;
    if (dict.m12 == null) dict.m12 = dict.b orelse 0;
    if (dict.m21 == null) dict.m21 = dict.c orelse 0;
    if (dict.m22 == null) dict.m22 = dict.d orelse 1;
    if (dict.m41 == null) dict.m41 = dict.e orelse 0;
    if (dict.m42 == null) dict.m42 = dict.f orelse 0;
}

/// Whether one of m13, m14, m23, m24, m31, m32, m34, m43 is other than 0 or
/// -0, or one of m33, m44 other than 1 (6.1 steps 2-3).
fn has3dComponent(dict: MatrixInit) bool {
    for ([_]f64{ dict.m13, dict.m14, dict.m23, dict.m24, dict.m31, dict.m32, dict.m34, dict.m43 }) |value| {
        if (value != 0) return true;
    }
    return dict.m33 != 1 or dict.m44 != 1;
}

/// 6.1 "validate and fixup" `dict`.
pub fn validateAndFixup(dict: *MatrixInit) error{TypeError}!void {
    // 1.
    try validateAndFixup2d(dict);
    // 2. is2D true with a 3D component is a TypeError.
    if (dict.is2D == true and has3dComponent(dict.*)) return error.TypeError;
    // 3. is2D absent with a 3D component: false.
    if (dict.is2D == null and has3dComponent(dict.*)) dict.is2D = false;
    // 4. Still absent: true.
    if (dict.is2D == null) dict.is2D = true;
}

/// 6.3 "create a DOMMatrix(ReadOnly) from a dictionary": the matrix it
/// makes (steps 1-2).
pub fn fromDictionary(other: MatrixInit) error{TypeError}!Matrix {
    var dict = other;
    // 1.
    try validateAndFixup(&dict);
    // 2.
    if (dict.is2D.?) return Matrix.create2d(.{ dict.m11.?, dict.m12.?, dict.m21.?, dict.m22.?, dict.m41.?, dict.m42.? });
    return Matrix.create3d(.{
        dict.m11.?, dict.m12.?, dict.m13, dict.m14,
        dict.m21.?, dict.m22.?, dict.m23, dict.m24,
        dict.m31,   dict.m32,   dict.m33, dict.m34,
        dict.m41.?, dict.m42.?, dict.m43, dict.m44,
    });
}

const testing = std.testing;

test "a 2d matrix keeps its six values and the identity elsewhere" {
    const matrix = Matrix.create2d(.{ 1, 2, 3, 4, 5, 6 });
    try testing.expect(matrix.is_2d);
    try testing.expectEqualSlices(f64, &.{ 1, 2, 0, 0, 3, 4, 0, 0, 0, 0, 1, 0, 5, 6, 0, 1 }, &matrix.m);
    try testing.expect(Matrix.identity.isIdentity());
    try testing.expect(!matrix.isIdentity());
}

test "a sequence makes a 2d or 3d matrix, or a TypeError" {
    const values = [_]f64{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
    const three_d = try Matrix.fromSequence(&values);
    try testing.expect(!three_d.is_2d);
    try testing.expectEqualSlices(f64, &values, &three_d.m);
    try testing.expect((try Matrix.fromSequence(values[0..6])).is_2d);
    try testing.expectError(error.TypeError, Matrix.fromSequence(values[0..5]));
    try testing.expectError(error.TypeError, Matrix.fromSequence(&.{}));
}

test "isIdentity treats -0 as 0" {
    var matrix = Matrix.identity;
    matrix.m[index(4, 1)] = -0.0;
    try testing.expect(matrix.isIdentity());
}

test "an element setter clears is 2D only for a 3D component off its identity value" {
    var matrix = Matrix.identity;
    matrix.setElement(index(1, 1), 7);
    matrix.setElement(index(4, 2), 9);
    try testing.expect(matrix.is_2d);
    matrix.setElement(index(1, 3), -0.0);
    matrix.setElement(index(3, 3), 1);
    try testing.expect(matrix.is_2d);
    matrix.setElement(index(4, 4), 2);
    try testing.expect(!matrix.is_2d);
    var other = Matrix.identity;
    other.setElement(index(2, 3), 0.5);
    try testing.expect(!other.is_2d);
}

test "transform a point: scale by 2, then translate by 10 (Geometry 2's example)" {
    const matrix = Matrix.create2d(.{ 2, 0, 0, 2, 10, 10 });
    const point = matrix.transformPoint(.{ .x = 5, .y = 4 });
    try testing.expectEqual(@as(f64, 20), point.x);
    try testing.expectEqual(@as(f64, 18), point.y);
    try testing.expectEqual(@as(f64, 0), point.z);
    try testing.expectEqual(@as(f64, 1), point.w);
}

test "validate and fixup: aliases fill in, disagreeing aliases throw, NaN and -0 agree" {
    var dict: MatrixInit = .{ .a = 2, .f = 3 };
    try validateAndFixup(&dict);
    try testing.expectEqual(@as(f64, 2), dict.m11.?);
    try testing.expectEqual(@as(f64, 3), dict.m42.?);
    try testing.expectEqual(@as(f64, 1), dict.m22.?);
    try testing.expect(dict.is2D.?);

    var conflict: MatrixInit = .{ .b = 1, .m12 = 2 };
    try testing.expectError(error.TypeError, validateAndFixup(&conflict));
    var nan: MatrixInit = .{ .c = std.math.nan(f64), .m21 = std.math.nan(f64) };
    try validateAndFixup(&nan);
    var zeros: MatrixInit = .{ .e = -0.0, .m41 = 0 };
    try validateAndFixup(&zeros);
}

test "validate and fixup: is2D follows the 3D members" {
    var three_d: MatrixInit = .{ .m33 = 2 };
    try validateAndFixup(&three_d);
    try testing.expect(!three_d.is2D.?);
    var contradicts: MatrixInit = .{ .m13 = 1, .is2D = true };
    try testing.expectError(error.TypeError, validateAndFixup(&contradicts));
    var negative_zero: MatrixInit = .{ .m13 = -0.0, .is2D = true };
    try validateAndFixup(&negative_zero);
    try testing.expect(negative_zero.is2D.?);
}

test "a dictionary makes a 2d matrix from its six members, or a 3d one from all sixteen" {
    const two_d = try fromDictionary(.{ .a = 1, .b = 2, .c = 3, .d = 4, .e = 5, .f = 6 });
    try testing.expectEqualDeep(Matrix.create2d(.{ 1, 2, 3, 4, 5, 6 }), two_d);
    const three_d = try fromDictionary(.{ .m43 = 7 });
    try testing.expect(!three_d.is_2d);
    try testing.expectEqual(@as(f64, 7), three_d.m[index(4, 3)]);
}

test "a binding's dictionaries convert with their IDL defaults" {
    const TwoD = struct { a: ?f64 = null, b: ?f64 = null, c: ?f64 = null, d: ?f64 = null, e: ?f64 = null, f: ?f64 = null, m11: ?f64 = null, m12: ?f64 = null, m21: ?f64 = null, m22: ?f64 = null, m41: ?f64 = null, m42: ?f64 = null };
    const Full = struct { base: TwoD, m13: ?f64 = null, m14: ?f64 = null, m23: ?f64 = null, m24: ?f64 = null, m31: ?f64 = null, m32: ?f64 = null, m33: ?f64 = null, m34: ?f64 = null, m43: ?f64 = null, m44: ?f64 = null, is2D: ?bool = null };
    const full = matrixInitFrom(Full{ .base = .{ .a = 3 }, .m33 = 2 });
    try testing.expectEqual(@as(?f64, 3), full.a);
    try testing.expectEqual(@as(f64, 2), full.m33);
    try testing.expectEqual(@as(f64, 1), full.m44);
    try testing.expectEqual(@as(?bool, null), full.is2D);
    const two_d = matrixInitFrom(TwoD{ .m42 = 5 });
    try testing.expectEqual(@as(?f64, 5), two_d.m42);
    const PointInit = struct { x: ?f64 = null, y: ?f64 = null, z: ?f64 = null, w: ?f64 = null };
    try testing.expectEqualDeep(Point{ .x = 4 }, pointFrom(PointInit{ .x = 4 }));
}

test "a rectangle's edges follow negative dimensions and NaN" {
    const rect: Rect = .{ .x = 1, .y = 2, .width = -3, .height = 4 };
    try testing.expectEqual(@as(f64, -2), rect.left());
    try testing.expectEqual(@as(f64, 1), rect.right());
    try testing.expectEqual(@as(f64, 2), rect.top());
    try testing.expectEqual(@as(f64, 6), rect.bottom());
    const nan: Rect = .{ .x = std.math.nan(f64) };
    try testing.expect(std.math.isNan(nan.left()));
}
