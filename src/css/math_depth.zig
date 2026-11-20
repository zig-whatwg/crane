//! MathML Core §3.1 math-depth: auto-add | add(<integer>) | <integer>
//! (lane maj1). Specified, add(<integer>) is kept as its canonical text
//! "add(N)"; the computed value is an integer, from the inherited
//! math-depth (and math-style for auto-add) - see `compute`.
//!
//! The browsers agree (wpt.fyi 2358bd4835, mathml/relations/css-styling/
//! parsing/math-depth-{valid,invalid,computed}.html: Chrome, Firefox and
//! Safari pass all).
const std = @import("std");
const Allocator = std.mem.Allocator;
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const math_values = @import("math_values.zig");
const tokenizer = @import("tokenizer.zig");

const Value = values.Value;

pub fn parse(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    if (properties.takeKeyword(stream, &.{.auto_add})) |k| return Value.kw(k);
    const token = stream.peek();
    if (token.token_type == .function and tokenizer.nameEql(token.value, "add")) {
        // add(<integer>): one integer token, whitespace around it allowed.
        _ = stream.next();
        if (stream.next().token_type != .left_paren) return null;
        const n = integerToken(stream) orelse return null;
        if (stream.next().token_type != .right_paren) return null;
        var text: [32]u8 = undefined;
        return .{ .text = try values.SharedText.create(options.allocator, std.fmt.bufPrint(&text, "add({d})", .{n}) catch unreachable) };
    }
    if (math_values.isFunction(token)) return properties.mathValue(options, stream, .{ .kind = .integer, .minimum = std.math.minInt(i32), .maximum = std.math.maxInt(i32), .minimum_kind = .representation, .maximum_kind = .representation });
    const n = integerToken(stream) orelse return null;
    return .{ .integer = n };
}

/// An <integer> token, consumed, clamped to the i32 range.
fn integerToken(stream: *properties.Stream) ?i32 {
    const token = stream.peek();
    if (token.token_type != .number or !token.is_integer) return null;
    const n = token.numeric_value orelse return null;
    _ = stream.next();
    return @intFromFloat(std.math.clamp(n, @as(f64, std.math.minInt(i32)), @as(f64, std.math.maxInt(i32))));
}

/// MathML Core §3.1, the computed value: "If the specified value of
/// math-depth is auto-add and the inherited value of math-style is compact
/// then the computed value of math-depth of the element is its inherited
/// value plus one"; auto-add otherwise is the inherited value; "If the
/// specified value of math-depth is of the form add(<integer>) then the
/// computed value of math-depth of the element is its inherited value plus
/// the specified integer"; "If the specified value of math-depth is of the
/// form <integer> then the computed value of math-depth of the element is
/// the specified integer." Null for a value of another kind.
pub fn compute(specified: Value, inherited_depth: i32, inherited_compact: bool) ?i32 {
    switch (specified) {
        .keyword => |k| if (k == .auto_add) return if (inherited_compact) inherited_depth +| 1 else inherited_depth,
        .integer => |n| return n,
        .text => |t| if (std.mem.startsWith(u8, t.bytes, "add(") and t.bytes.len > 5) {
            const n = std.fmt.parseInt(i32, t.bytes[4 .. t.bytes.len - 1], 10) catch return null;
            return inherited_depth +| n;
        },
        else => {},
    }
    return null;
}

test "math-depth computes from the inherited depth and style" {
    try std.testing.expectEqual(@as(?i32, 3), compute(Value.kw(.auto_add), 2, true));
    try std.testing.expectEqual(@as(?i32, 2), compute(Value.kw(.auto_add), 2, false));
    try std.testing.expectEqual(@as(?i32, 5), compute(.{ .integer = 5 }, 2, true));
}
