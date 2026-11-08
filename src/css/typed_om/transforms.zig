//! CSS Typed OM 1 sections 4.4, 5.8 and 6.6: the pure part of the transform
//! family. A <transform-function> reifies as one CSSTransformComponent - a
//! CSSTranslate, CSSRotate, CSSScale, CSSSkew, CSSSkewX, CSSSkewY,
//! CSSPerspective or CSSMatrixComponent - whose slots are the function's
//! arguments with the implicit ones filled in (5.8), and whose is2D says
//! which of the 2D and 3D functions it stands for. The objects themselves
//! (their CSSNumericValue slots, toMatrix()'s DOMMatrix) are
//! dom.style.typed_om's; this file only answers questions about values.
//!
//! Design reference: Blink's CSSTransformComponent::FromCSSValue and the
//! CSSTranslate/CSSRotate/CSSScale/CSSSkew*/CSSPerspective/CSSMatrixComponent
//! classes (third_party/blink/renderer/core/css/cssom/), designs only.
const std = @import("std");
const values = @import("../style_values.zig");
const functions = @import("../transform_functions.zig");
const box_transform_values = @import("../box_transform_values.zig");
const math = @import("../math_values.zig");
const Number = @import("../numeric_values.zig").Number;
const Allocator = std.mem.Allocator;

pub const Function = functions.Function;
pub const Kind = functions.Kind;
/// Column-major 4x4: column c, row r at c * 4 + r (box_transform_values).
pub const Matrix = box_transform_values.Matrix;

/// The <transform-function>s of a transform value; null when it is not a
/// <transform-list> (`none` is a keyword, a pending value is unparsed).
pub fn listOf(value: values.Value) ?[]const Function {
    return switch (value) {
        .transform_list => |list| list.items,
        else => null,
    };
}

/// The productions the transform components' slots match (4.3.2 "match").
pub const Production = enum { length, length_percentage, angle, number };

/// Typed OM 4.3.2: whether a CSSNumericValue of type `t` matches
/// `production` in a component slot. A <length> or <angle> slot allows no
/// percentage, so its percent hint must be null; <length-percentage> is
/// <length> (hint null or length) or <percentage> (hint null or percent);
/// <number> has no non-zero entry and, with no percentage allowed, a null
/// hint.
pub fn matches(t: math.Type, production: Production) bool {
    return switch (production) {
        .length => only(t, .length) and t.hint == null,
        .angle => only(t, .angle) and t.hint == null,
        .number => only(t, null) and t.hint == null,
        .length_percentage => (only(t, .length) and (t.hint == null or t.hint.? == .length)) or
            (only(t, .percent) and (t.hint == null or t.hint.? == .percent)),
    };
}

/// Whether `base` (or nothing, for null) is `t`'s only non-zero entry, with
/// a power of 1.
fn only(t: math.Type, base: ?math.Base) bool {
    for (t.powers, 0..) |power, i| {
        const expected: i32 = if (base != null and i == @backingInt(base.?)) 1 else 0;
        if (power != expected) return false;
    }
    return true;
}

/// The CSSTransformComponent subclass a function reifies as (5.8).
pub const Component = enum { translate, rotate, scale, skew, skew_x, skew_y, perspective, matrix };

pub fn componentOf(kind: Kind) Component {
    return switch (kind) {
        .translate, .translateX, .translateY, .translateZ, .translate3d => .translate,
        .rotate, .rotateX, .rotateY, .rotateZ, .rotate3d => .rotate,
        .scale, .scaleX, .scaleY, .scaleZ, .scale3d => .scale,
        .skew => .skew,
        .skewX => .skew_x,
        .skewY => .skew_y,
        .perspective => .perspective,
        .matrix, .matrix3d => .matrix,
    };
}

/// 5.8: is2D is true for translate(), translateX(), translateY(), scale(),
/// scaleX(), scaleY(), rotate(), matrix() and the skews; false for the 3D
/// functions and perspective().
pub fn is2d(kind: Kind) bool {
    return switch (kind) {
        .translate, .translateX, .translateY, .scale, .scaleX, .scaleY, .rotate, .matrix, .skew, .skewX, .skewY => true,
        .translateZ, .translate3d, .scaleZ, .scale3d, .rotateX, .rotateY, .rotateZ, .rotate3d, .matrix3d, .perspective => false,
    };
}

fn px(value: f64) Number {
    return .{ .literal = .{ .value = value, .unit = .px } };
}
fn plain(value: f64) Number {
    return .{ .literal = .{ .value = value, .unit = .number } };
}
fn deg(value: f64) Number {
    return .{ .literal = .{ .value = value, .unit = .deg } };
}

/// A scale argument as the <number> its CSSScale slot holds: Transforms 2
/// 12.2 "a percentage is equivalent to a number" (50% is 0.5). A calc()
/// stays as it is.
fn scaleNumber(n: Number) Number {
    if (n == .literal and n.literal.unit == .percent) return plain(n.literal.value / 100);
    return n;
}

/// The slots of the component `function` reifies as (5.8), BORROWING its
/// arguments: translate x, y, z ("the specified x/y/z offsets, or ... 0px
/// if not specified"); scale x, y, z (1 if not specified - a one-argument
/// scale() is scale(x, x), Transforms 2 12.2, as Blink's CSSScale and the
/// WPT transform-interpolation-computed-value "scale(1.5, 1.5)" read it);
/// rotate x, y, z, angle (the implicit axis of rotate(), rotateX/Y/Z());
/// skew ax, ay (0deg); skewX ax; skewY ay; perspective its length (none:
/// no slot). A matrix's sixteen entries are matrixEntries'.
pub const Slots = struct {
    numbers: [4]Number = undefined,
    len: usize = 0,

    pub fn items(self: *const Slots) []const Number {
        return self.numbers[0..self.len];
    }

    /// Fill from a tuple of Numbers (no temporary array outlives a switch).
    fn put(self: *Slots, tuple: anytype) void {
        inline for (tuple, 0..) |n, i| self.numbers[i] = n;
        self.len = tuple.len;
    }
};

pub fn slotsOf(function: Function) Slots {
    const a = function.arguments;
    var s: Slots = .{};
    switch (function.kind) {
        .translate => s.put(.{ a[0], if (a.len > 1) a[1] else px(0), px(0) }),
        .translateX => s.put(.{ a[0], px(0), px(0) }),
        .translateY => s.put(.{ px(0), a[0], px(0) }),
        .translateZ => s.put(.{ px(0), px(0), a[0] }),
        .translate3d => s.put(.{ a[0], a[1], a[2] }),
        .scale => s.put(.{ scaleNumber(a[0]), scaleNumber(if (a.len > 1) a[1] else a[0]), plain(1) }),
        .scaleX => s.put(.{ scaleNumber(a[0]), plain(1), plain(1) }),
        .scaleY => s.put(.{ plain(1), scaleNumber(a[0]), plain(1) }),
        .scaleZ => s.put(.{ plain(1), plain(1), scaleNumber(a[0]) }),
        .scale3d => s.put(.{ scaleNumber(a[0]), scaleNumber(a[1]), scaleNumber(a[2]) }),
        .rotate, .rotateZ => s.put(.{ plain(0), plain(0), plain(1), a[0] }),
        .rotateX => s.put(.{ plain(1), plain(0), plain(0), a[0] }),
        .rotateY => s.put(.{ plain(0), plain(1), plain(0), a[0] }),
        .rotate3d => s.put(.{ a[0], a[1], a[2], a[3] }),
        .skew => s.put(.{ a[0], if (a.len > 1) a[1] else deg(0) }),
        .skewX, .skewY => s.put(.{a[0]}),
        .perspective => if (a.len > 0) s.put(.{a[0]}),
        .matrix, .matrix3d => {},
    }
    return s;
}

/// The 4x4 entries of matrix() or matrix3d() (5.8: "a 4x4 matrix
/// representing the same information"), null when an entry is not a plain
/// number (a calc() that did not compute).
pub fn matrixEntries(function: Function) ?Matrix {
    var numbers: [16]f64 = undefined;
    for (function.arguments, 0..) |n, i| {
        if (n != .literal or n.literal.unit != .number) return null;
        numbers[i] = n.literal.value;
    }
    if (function.kind == .matrix) {
        const e = numbers[0..6];
        return .{ e[0], e[1], 0, 0, e[2], e[3], 0, 0, 0, 0, 1, 0, e[4], e[5], 0, 1 };
    }
    return numbers;
}

/// The function a component with `is_2d` stands for (4.4: "When
/// stringified ... translate(10px, 0px) or translate3d(10px, 0px, 0px),
/// depending on whether its is2D internal slot is true or false").
pub fn kindFor(component: Component, is_2d: bool) Kind {
    return switch (component) {
        .translate => if (is_2d) .translate else .translate3d,
        .rotate => if (is_2d) .rotate else .rotate3d,
        .scale => if (is_2d) .scale else .scale3d,
        .skew => .skew,
        .skew_x => .skewX,
        .skew_y => .skewY,
        .perspective => .perspective,
        .matrix => if (is_2d) .matrix else .matrix3d,
    };
}

/// 4.4 toMatrix() step 1: "this's equivalent 4x4 transform matrix, as
/// defined in CSS Transforms 1 12", for a component whose slots are
/// `numbers` in px, deg and plain numbers (the caller has converted them,
/// throwing a TypeError for a length it cannot express in px) and whose
/// is2D is `is_2d` - a 2D component ignores its z slots. A perspective with
/// no length (none) is the identity. Transforms 1 12 / 2 12 through
/// box_transform_values.matrixOf, the one composition getComputedStyle
/// uses.
pub fn componentMatrix(component: Component, is_2d: bool, numbers: []const f64) Matrix {
    var s: Slots = .{};
    switch (component) {
        .translate => if (is_2d) s.put(.{ px(numbers[0]), px(numbers[1]) }) else s.put(.{ px(numbers[0]), px(numbers[1]), px(numbers[2]) }),
        .rotate => if (is_2d) s.put(.{deg(numbers[3])}) else s.put(.{ plain(numbers[0]), plain(numbers[1]), plain(numbers[2]), deg(numbers[3]) }),
        .scale => if (is_2d) s.put(.{ plain(numbers[0]), plain(numbers[1]) }) else s.put(.{ plain(numbers[0]), plain(numbers[1]), plain(numbers[2]) }),
        .skew => s.put(.{ deg(numbers[0]), deg(numbers[1]) }),
        .skew_x, .skew_y => s.put(.{deg(numbers[0])}),
        .perspective => if (numbers.len > 0) s.put(.{px(numbers[0])}),
        .matrix => unreachable, // the caller reads a matrix component's DOMMatrix
    }
    // matrixOf reads only kind and arguments; this Function is never freed,
    // so its allocator is one that holds nothing.
    var nothing: [0]u8 = .{};
    var unused = std.heap.FixedBufferAllocator.init(&nothing);
    const function: Function = .{ .allocator = unused.allocator(), .kind = kindFor(component, is_2d), .arguments = s.numbers[0..s.len], .computed = true };
    // Every argument is a literal in the unit matrixOf expects, so no
    // reference-box percentage can make it fail.
    return box_transform_values.matrixOf(&.{function}).?;
}

/// A 4x4 matrix as the 2D matrix a 2D CSSMatrixComponent stands for:
/// a, b, c, d, e, f kept, every other entry the identity's (Blink
/// CSSMatrixComponent::ToMatrix makes a 2D DOMMatrix from those six).
pub fn flatten2d(m: Matrix) Matrix {
    return .{ m[0], m[1], 0, 0, m[4], m[5], 0, 0, 0, 0, 1, 0, m[12], m[13], 0, 1 };
}

/// `left` post-multiplied by `right` (4.4 CSSTransformValue toMatrix() step
/// 2.2, "multiplying matrix and the matrix represented by funcMatrix").
pub fn multiply(left: Matrix, right: Matrix) Matrix {
    var result: Matrix = @splat(0);
    for (0..4) |column| for (0..4) |row| {
        for (0..4) |k| result[column * 4 + row] += left[k * 4 + row] * right[column * 4 + k];
    };
    return result;
}

pub const identity: Matrix = .{ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 };

/// The opening of a component's serialization (6.6): the function name,
/// by the component and its is2D.
pub fn serializationName(component: Component, is_2d: bool) []const u8 {
    return @tagName(kindFor(component, is_2d));
}
