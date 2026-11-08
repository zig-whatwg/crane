//! Lane anim1 batch 5 (item 3): css.typed_om.transforms, the pure part of
//! the CSS Typed OM transform family - 5.8's implicit slots, 4.4's
//! component matrices and the 2D flattening, post-multiplication.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const transforms = css.typed_om.transforms;
const Number = css.numeric_values.Number;
const Function = transforms.Function;
const Kind = transforms.Kind;
const Matrix = transforms.Matrix;
const slotsOf = transforms.slotsOf;
const is2d = transforms.is2d;
const componentMatrix = transforms.componentMatrix;
const matrixEntries = transforms.matrixEntries;
const flatten2d = transforms.flatten2d;
const multiply = transforms.multiply;
const identity = transforms.identity;

fn px(value: f64) Number {
    return .{ .literal = .{ .value = value, .unit = .px } };
}
fn plain(value: f64) Number {
    return .{ .literal = .{ .value = value, .unit = .number } };
}
fn deg(value: f64) Number {
    return .{ .literal = .{ .value = value, .unit = .deg } };
}

fn makeFunction(kind: Kind, args: []Number) Function {
    return .{ .allocator = testing.allocator, .kind = kind, .arguments = args, .computed = true };
}

test "5.8: implicit slots fill in, and a one-argument scale() is scale(x, x)" {
    var a = [_]Number{px(25)};
    const t = slotsOf(makeFunction(.translate, &a));
    try testing.expectEqual(@as(usize, 3), t.len);
    try testing.expectEqual(@as(f64, 0), t.numbers[1].literal.value);
    try testing.expectEqual(css.math_values.Unit.px, t.numbers[2].literal.unit);
    var s = [_]Number{plain(1.5)};
    const scale = slotsOf(makeFunction(.scale, &s));
    try testing.expectEqual(@as(f64, 1.5), scale.numbers[1].literal.value);
    try testing.expectEqual(@as(f64, 1), scale.numbers[2].literal.value);
    var p = [_]Number{.{ .literal = .{ .value = 50, .unit = .percent } }};
    try testing.expectEqual(@as(f64, 0.5), slotsOf(makeFunction(.scaleY, &p)).numbers[1].literal.value);
    var r = [_]Number{deg(30)};
    const rotate_x = slotsOf(makeFunction(.rotateX, &r));
    try testing.expectEqual(@as(f64, 1), rotate_x.numbers[0].literal.value);
    try testing.expectEqual(@as(f64, 30), rotate_x.numbers[3].literal.value);
    try testing.expect(!is2d(.rotateZ));
    try testing.expect(is2d(.rotate));
    try testing.expectEqual(@as(usize, 0), slotsOf(makeFunction(.perspective, &.{})).len);
}

test "4.4 toMatrix(): a 2D translate ignores z, a 3D one keeps it" {
    const flat = componentMatrix(.translate, true, &.{ 10, 20, 30 });
    try testing.expectEqual(@as(f64, 10), flat[12]);
    try testing.expectEqual(@as(f64, 20), flat[13]);
    try testing.expectEqual(@as(f64, 0), flat[14]);
    const deep = componentMatrix(.translate, false, &.{ 10, 20, 30 });
    try testing.expectEqual(@as(f64, 30), deep[14]);
    // scale(2, 3): the diagonal.
    const scale = componentMatrix(.scale, true, &.{ 2, 3, 4 });
    try testing.expectEqual(@as(f64, 2), scale[0]);
    try testing.expectEqual(@as(f64, 3), scale[5]);
    try testing.expectEqual(@as(f64, 1), scale[10]);
    // rotate(90deg): exact quadrant values.
    const rotate = componentMatrix(.rotate, true, &.{ 0, 0, 1, 90 });
    try testing.expectEqual(@as(f64, 0), rotate[0]);
    try testing.expectEqual(@as(f64, 1), rotate[1]);
    try testing.expectEqual(@as(f64, -1), rotate[4]);
    // perspective(none) is the identity; perspective(100px) sets m34.
    try testing.expectEqualSlices(f64, &identity, &componentMatrix(.perspective, false, &.{}));
    try testing.expectEqual(@as(f64, -0.01), componentMatrix(.perspective, false, &.{100})[11]);
}

test "matrix() entries and the 2D flattening" {
    var e = [_]Number{ plain(2), plain(0), plain(0), plain(2), plain(10), plain(30) };
    const m = matrixEntries(makeFunction(.matrix, &e)).?;
    try testing.expectEqual(@as(f64, 10), m[12]);
    try testing.expectEqual(@as(f64, 30), m[13]);
    try testing.expectEqual(@as(f64, 1), m[15]);
    var three: Matrix = identity;
    three[14] = 5;
    three[2] = 7;
    const flat = flatten2d(three);
    try testing.expectEqual(@as(f64, 0), flat[14]);
    try testing.expectEqual(@as(f64, 0), flat[2]);
    // Post-multiplication: translate then scale applies the scale first to
    // points, so the translation is unscaled.
    const product = multiply(componentMatrix(.translate, true, &.{ 10, 0, 0 }), componentMatrix(.scale, true, &.{ 2, 2, 1 }));
    try testing.expectEqual(@as(f64, 10), product[12]);
    try testing.expectEqual(@as(f64, 2), product[0]);
}
