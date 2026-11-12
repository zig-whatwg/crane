//! CSS Borders 4 §3.7 <corner-shape-value> and §3.9.6 its interpolation.
//!
//! <corner-shape-value> = round | scoop | bevel | notch | square | squircle |
//!                        superellipse( <number> | infinity | -infinity )
//!
//! The specified value is the keyword, or the superellipse() parameter K
//! (a number, or a math function until it computes). The computed value is
//! "the corresponding superellipse() value": K as a number, which the
//! property's serialization wraps in superellipse() (corner-shape-computed.html:
//! `round` reads back as `superellipse(1)`, `square` as
//! `superellipse(infinity)` - Chrome 38/38, the one browser shipping it).
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokenizer = @import("tokenizer.zig");
const math_values = @import("math_values.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Keyword = values.Keyword;
const Stream = properties.Stream;

const keywords = [_]Keyword{ .round, .scoop, .bevel, .notch, .square, .squircle };

pub fn parse(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    const token = stream.peek();
    if (token.token_type == .ident) {
        for (keywords) |k| if (tokenizer.nameEql(token.value, k.name())) {
            _ = stream.next();
            return Value.kw(k);
        };
        return null;
    }
    if (token.token_type != .function or !tokenizer.nameEql(token.value, "superellipse")) return null;
    _ = stream.next();
    if (stream.next().token_type != .left_paren) return null;
    const argument = stream.peek();
    const k: Value = switch (argument.token_type) {
        .ident => blk: {
            const infinite: f64 = if (tokenizer.nameEql(argument.value, "infinity"))
                std.math.inf(f64)
            else if (tokenizer.nameEql(argument.value, "-infinity"))
                -std.math.inf(f64)
            else
                return null;
            _ = stream.next();
            break :blk .{ .number = infinite };
        },
        .number => blk: {
            _ = stream.next();
            break :blk .{ .number = argument.numeric_value orelse return null };
        },
        .function => if (math_values.isFunction(argument))
            (try properties.mathValue(options, stream, .{ .kind = .number })) orelse return null
        else
            return null,
        else => return null,
    };
    if (stream.next().token_type != .right_paren) {
        k.release();
        return null;
    }
    return k;
}

/// The superellipse parameter K a keyword stands for (§3.7: round is
/// superellipse(1), squircle 2, square infinity, bevel 0, scoop -1, notch
/// -infinity).
pub fn parameter(k: Keyword) ?f64 {
    return switch (k) {
        .round => 1,
        .squircle => 2,
        .square => std.math.inf(f64),
        .bevel => 0,
        .scoop => -1,
        .notch => -std.math.inf(f64),
        else => null,
    };
}

/// `superellipse(K)`, K a number (infinity and -infinity by name) or the
/// math function it was specified as.
pub fn serialize(v: Value, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    try out.appendSlice(allocator, "superellipse(");
    switch (v) {
        .number => |n| if (std.math.isInf(n))
            try out.appendSlice(allocator, if (n > 0) "infinity" else "-infinity")
        else
            try values.appendNumber(n, out, allocator),
        .calculation => |c| try c.serialize(out, allocator),
        else => unreachable,
    }
    try out.append(allocator, ')');
}

/// §3.9.6 "normalized superellipse half corner" of K.
fn halfCorner(k: f64) f64 {
    if (k == -std.math.inf(f64)) return 0;
    if (k == std.math.inf(f64)) return 1;
    // 1. Let n be 2^abs(K). 2. Let convexHalfCorner be 0.5^(1/n).
    const n = std.math.pow(f64, 2, @abs(k));
    const convex = std.math.pow(f64, 0.5, 1 / n);
    // 3. If K is less than 0, return 1 - convexHalfCorner. 4. Return it.
    return if (k < 0) 1 - convex else convex;
}

/// §3.9.6: the superellipse parameter of an interpolation value in [0, 1].
fn fromHalfCorner(value: f64) f64 {
    if (value <= 0) return -std.math.inf(f64);
    if (value >= 1) return std.math.inf(f64);
    // bevel, within the error of two half corners' sum (scoop to round).
    if (@abs(value - 0.5) < 1e-12) return 0;
    // 1-2. convexHalfCorner is the value, or 1 - value below 0.5.
    const convex = if (value < 0.5) 1 - value else value;
    // 3. Let n be ln(0.5) / ln(convexHalfCorner). 4. Let K be log2(n).
    const k = std.math.log2(@log(0.5) / @log(convex));
    // 5-6. Negative below 0.5.
    return if (value < 0.5) -k else k;
}

/// §3.9.6: interpolating two <corner-shape-value>s "is done by
/// interpolating the superellipse parameter itself" in the normalized
/// half-corner space, whose result lies in [0, 1] (an extrapolation beyond
/// square or notch is square or notch: corner-shape-interpolation.html
/// expects `square` at 1.5 from bevel to square). The parameters are
/// computed values (numbers); null otherwise.
pub fn interpolate(from: Value, to: Value, p: f64) ?Value {
    if (from != .number or to != .number) return null;
    const a = halfCorner(from.number);
    const b = halfCorner(to.number);
    const mixed = std.math.clamp(a + (b - a) * p, 0, 1);
    return .{ .number = fromHalfCorner(mixed) };
}

test "the normalized half corner round-trips the keywords' parameters" {
    for ([_]f64{ -2, -1, 0, 1, 2, 5 }) |k| try std.testing.expectApproxEqAbs(k, fromHalfCorner(halfCorner(k)), 1e-9);
    try std.testing.expectEqual(std.math.inf(f64), fromHalfCorner(halfCorner(std.math.inf(f64))));
    try std.testing.expectEqual(-std.math.inf(f64), fromHalfCorner(halfCorner(-std.math.inf(f64))));
    // corner-shape-interpolation.html: round to bevel at 0.6 is 0.36.
    const v = interpolate(.{ .number = 1 }, .{ .number = 0 }, 0.6).?;
    try std.testing.expectApproxEqAbs(@as(f64, 0.36), v.number, 0.005);
}
