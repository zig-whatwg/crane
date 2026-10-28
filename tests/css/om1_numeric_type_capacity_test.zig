//! Q84 Chrome156/Safari27 probe,2026-10-27: full32-bit numeric types.
//! Before H-MATH-TYPE-EXPONENT-WIDTH, measure these existing native types.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;
const Type = css.math_values.Type;
const Node = @typeInfo(@TypeOf(@as(css.math_values.Expression, undefined).root)).pointer.child;

test "Q84 measures shared type node and expression sizes before widening" {
    std.debug.print("om1 numeric layout: Type={d} Node={d} Expression={d}\n", .{ @sizeOf(Type), @sizeOf(Node), @sizeOf(css.math_values.Expression) });
    const value: Type = .{};
    try std.testing.expect(@TypeOf(value.powers[0]) == i32);
}

fn powers(count: usize, expected: i32, inverse_expected: i32) !void {
    if (comptime !@hasDecl(css.typed_om.numeric, "multiplyTypes")) return std.testing.expect(false);
    const numeric = css.typed_om.numeric;
    var value: Type = .{};
    value.powers[0] = 1;
    for (0..count) |_| value = try numeric.multiplyTypes(value, value);
    try std.testing.expectEqual(expected, value.powers[0]);
    const inverse = try numeric.invertType(value);
    try std.testing.expectEqual(inverse_expected, inverse.powers[0]);
}
test "Q84 type exponent32768 is representable" {
    try powers(15, 32768, -32768);
}
test "Q84 type exponent65536 is representable" {
    try powers(16, 65536, -65536);
}
test "Q84 type exponent2pow30 is representable" {
    try powers(30, 1073741824, -1073741824);
}
test "Q84 type exponent2pow31 and inverse wrap without trapping" {
    try powers(31, -2147483648, -2147483648);
}
test "Q84 type exponent2pow32 wraps to zero" {
    try powers(32, 0, 0);
}

test "Q84 ordinary shared math parser control serializations stay unchanged" {
    const cases = .{
        .{ "calc(1px + 1in)", "calc(97px)" },
        .{ "calc(9em - 8px + 1vh)", "calc(9em - 8px + 1vh)" },
        .{ "min(1px, 2px)", "calc(1px)" },
        .{ "max(1px, 2px)", "calc(2px)" },
        .{ "clamp(1px, 9px, 3px)", "calc(3px)" },
    };
    inline for (cases) |case| {
        const parsed = (try css.math_values.parse(a, case[0], .{ .kind = .length_percentage })) orelse return error.TestUnexpectedResult;
        defer parsed.expression.unref();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(a);
        try parsed.expression.serialize(&out, a);
        try std.testing.expectEqualStrings(case[1], out.items);
    }
}
