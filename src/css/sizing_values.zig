//! CSS Sizing 4 values independent of layout: aspect-ratio (§4.1, with
//! Values 4 §5.7's <ratio>) and the contain-intrinsic-* longhands (§5.2).
//!
//! A multi-part value is a text_values.Components list, which computes and
//! combines component by component:
//! - aspect-ratio `<ratio>` is [a, b], `auto && <ratio>` is [auto, a, b]
//!   (canonical order: auto first), and `auto` alone is the keyword;
//! - contain-intrinsic-* `auto none` / `auto <length>` is [auto, none|length],
//!   and `none` or a <length> alone is that value. All four longhands keep
//!   their lists under contain-intrinsic-width, so the shorthand's two
//!   halves compare equal when their components do.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokenizer = @import("tokenizer.zig");
const math_values = @import("math_values.zig");
const Components = @import("text_values.zig").Components;
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Stream = properties.Stream;

fn ident(stream: *Stream, name: []const u8) bool {
    const token = stream.peek();
    if (token.token_type != .ident or !tokenizer.nameEql(token.value, name)) return false;
    _ = stream.next();
    return true;
}

/// <number [0,∞]>: a literal outside the range is invalid; a math function
/// is clamped when computed (Values 4 §10.12).
fn nonNegativeNumber(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    const token = stream.peek();
    if (math_values.isFunction(token)) return properties.mathValue(options, stream, .{ .kind = .number, .minimum = 0, .minimum_kind = .computation });
    if (token.token_type != .number) return null;
    const n = token.numeric_value orelse return null;
    if (n < 0) return null;
    _ = stream.next();
    return .{ .number = n };
}

/// Values 4 §5.7: <ratio> = <number [0,∞]> [ / <number [0,∞]> ]?, the
/// second defaulting to 1 ("<ratio> is always serialized with both
/// components").
fn ratio(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?[2]Value {
    const first = (try nonNegativeNumber(options, stream)) orelse return null;
    errdefer first.release();
    const slash = stream.peek();
    if (slash.token_type != .delim or !std.mem.eql(u8, slash.value, "/")) return .{ first, .{ .number = 1 } };
    _ = stream.next();
    const second = (try nonNegativeNumber(options, stream)) orelse {
        first.release();
        return null;
    };
    return .{ first, second };
}

/// Sizing 4 §4.1: auto || <ratio>.
pub fn parseAspectRatio(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    var auto = ident(stream, "auto");
    // A <ratio> that starts and then fails (`auto 16 /`) is invalid, not
    // `auto` followed by junk the caller would see as the end.
    const next = stream.peek();
    if (next.token_type != .number and !math_values.isFunction(next)) return if (auto) Value.kw(.auto) else null;
    const pair = (try ratio(options, stream)) orelse return null;
    defer for (pair) |v| v.release();
    if (!auto) auto = ident(stream, "auto");
    if (auto) return .{ .text_values = try Components.create(options.allocator, .aspect_ratio, &.{ Value.kw(.auto), pair[0], pair[1] }) };
    return .{ .text_values = try Components.create(options.allocator, .aspect_ratio, &pair) };
}

/// `[auto] a / b`.
pub fn serializeAspectRatio(items: []const Value, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    var pair = items;
    if (pair.len == 3) {
        try out.appendSlice(allocator, "auto ");
        pair = pair[1..];
    }
    try properties.serializeValue(.aspect_ratio, pair[0], out, allocator);
    try out.appendSlice(allocator, " / ");
    try properties.serializeValue(.aspect_ratio, pair[1], out, allocator);
}

/// The computed <ratio> of an aspect-ratio value and whether `auto` comes
/// with it; null for `auto` alone or a ratio not yet computed to numbers.
pub fn ratioParts(v: Value) ?struct { auto: bool, a: f64, b: f64 } {
    if (v != .text_values or v.text_values.property != .aspect_ratio) return null;
    const items = v.text_values.items;
    const pair = items[items.len - 2 ..];
    if (pair[0] != .number or pair[1] != .number) return null;
    return .{ .auto = items.len == 3, .a = pair[0].number, .b = pair[1].number };
}

/// Values 4 §5.7.1: two <ratio>s interpolate as the logarithms of a / b,
/// the result being `r / 1`; a degenerate ratio (a number 0 or infinite)
/// cannot be interpolated, and "addition of <ratio>s is not possible".
/// aspect-ratio's `auto` must match on both sides (Blink
/// CSSAspectRatioInterpolationType's InterpolableAspectRatio check; WPT
/// css/css-sizing/animation/aspect-ratio-interpolation.html, which Chrome,
/// Firefox and Safari pass). Null when the pair has no smooth combination.
pub fn mixRatios(allocator: Allocator, from: Value, to: Value, ka: f64, kb: f64) Allocator.Error!?Value {
    const x = ratioParts(from) orelse return null;
    const y = ratioParts(to) orelse return null;
    if (x.auto != y.auto or degenerate(x.a, x.b) or degenerate(y.a, y.b)) return null;
    const r: Value = .{ .number = @exp(@log(x.a / x.b) * ka + @log(y.a / y.b) * kb) };
    if (x.auto) return .{ .text_values = try Components.create(allocator, .aspect_ratio, &.{ Value.kw(.auto), r, .{ .number = 1 } }) };
    return .{ .text_values = try Components.create(allocator, .aspect_ratio, &.{ r, .{ .number = 1 } }) };
}

fn degenerate(a: f64, b: f64) bool {
    return a == 0 or b == 0 or std.math.isInf(a) or std.math.isInf(b);
}

/// Sizing 4 §5.2: auto? [ none | <length [0,∞]> ].
pub fn parseContainIntrinsic(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    const auto = ident(stream, "auto");
    const size: Value = if (ident(stream, "none"))
        Value.kw(.none)
    else
        (try properties.lengthPercentage(options, stream, .{ .negative = false, .percent = false, .quirky = false })) orelse return null;
    if (!auto) return size;
    defer size.release();
    return .{ .text_values = try Components.create(options.allocator, .contain_intrinsic_width, &.{ Value.kw(.auto), size }) };
}
