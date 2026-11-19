//! The SVG 2 longhands with grammars of their own (lane maj1):
//! stroke-miterlimit and stroke-dashoffset (Fill and Stroke 3 §§6.5, 7.3;
//! SVG 2 §13.5), the geometry properties x, y, cx, cy, r, rx and ry (SVG 2
//! §9.2 / §10.4), and paint-order (SVG 2 §13.7). The keyword-only ones
//! (fill-rule, stroke-linecap, ...) and the opacities use the shared
//! keyword and opacity grammars.
//!
//! Each grammar is the browsers' (wpt.fyi 2358bd4835, svg/painting/parsing,
//! svg/geometry/parsing: Chrome, Firefox and Safari pass, except where a
//! comment names the majority).
const std = @import("std");
const Allocator = std.mem.Allocator;
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const math_values = @import("math_values.zig");
const tokenizer = @import("tokenizer.zig");

const Value = values.Value;
const Longhand = properties.Longhand;

/// Fill and Stroke 3 §6.5 stroke-miterlimit: <number [0,∞]>
/// (stroke-miterlimit-valid.svg takes 0 and 0.5, -invalid.svg rejects -4).
pub fn parseMiterlimit(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    const token = stream.peek();
    if (math_values.isFunction(token)) return properties.mathValue(options, stream, .{ .kind = .number, .minimum = 0, .minimum_kind = .computation });
    if (token.token_type != .number) return null;
    const n = token.numeric_value orelse return null;
    if (!std.math.isFinite(n) or n < 0) return null;
    _ = stream.next();
    return .{ .number = n };
}

/// SVG 2 §13.5.7 stroke-dashoffset: <length-percentage> | <number>, any
/// sign; a number computes to px (cascade.zig). A zero stays a length, as
/// for stroke-width (svg_paint.parseStrokeWidth): Firefox and Safari read
/// "0" back as "0px" (stroke-dashoffset-valid.svg "0": Chrome alone keeps
/// the number).
pub fn parseDashoffset(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    const token = stream.peek();
    if (math_values.isFunction(token)) return properties.mathValue(options, stream, .{ .kind = .length_percentage_number });
    if (token.token_type == .number) {
        const n = token.numeric_value orelse return null;
        if (!std.math.isFinite(n)) return null;
        _ = stream.next();
        return if (n == 0) Value.px(0) else .{ .number = n };
    }
    return properties.lengthPercentage(options, stream, .{ .negative = true, .quirky = false });
}

/// SVG 2 §9.2 / §10.4: x, y, cx and cy are <length-percentage>, any sign;
/// r is <length-percentage [0,∞]>; rx and ry are auto | <length-percentage
/// [0,∞]>. A bare number is no length in a style sheet (x-invalid.svg "10"),
/// only in a presentation attribute (properties.lengthPercentage).
pub fn parseGeometry(options: properties.ParseOptions, l: Longhand, stream: *properties.Stream) Allocator.Error!?Value {
    switch (l) {
        .x, .y, .cx, .cy => return properties.lengthPercentage(options, stream, .{ .negative = true, .quirky = false }),
        .rx, .ry => {
            if (properties.takeKeyword(stream, &.{.auto})) |k| return Value.kw(k);
            return properties.lengthPercentage(options, stream, .{ .negative = false, .quirky = false });
        },
        else => return properties.lengthPercentage(options, stream, .{ .negative = false, .quirky = false }),
    }
}

/// SVG 2 §13.7 paint-order: normal | [ fill || stroke || markers ]. The
/// value serializes as its shortest equivalent: a component order that
/// matches the default order (fill, stroke, markers) for its unnamed
/// components is dropped from the end (paint-order-valid.svg: "fill stroke"
/// is "fill", "fill markers stroke" is "fill markers" - all three browsers).
pub fn parsePaintOrder(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    if (properties.takeKeyword(stream, &.{.normal})) |k| return Value.kw(k);
    var order: [3]values.Keyword = undefined;
    var n: usize = 0;
    while (n < 3) {
        const k = properties.takeKeyword(stream, &.{ .fill, .stroke, .markers }) orelse break;
        for (order[0..n]) |seen| if (seen == k) return null;
        order[n] = k;
        n += 1;
    }
    if (n == 0) return null;
    // Complete the order with the components not named, in the default
    // order, then drop the trailing ones the shorter form implies.
    for ([_]values.Keyword{ .fill, .stroke, .markers }) |k| {
        if (std.mem.indexOfScalar(values.Keyword, order[0..n], k) == null) {
            order[n] = k;
            n += 1;
        }
    }
    var kept: usize = 3;
    while (kept > 1) : (kept -= 1) {
        // The last kept component is implied when the components after the
        // first kept-1 are already in the default order.
        if (!impliedAfter(order[0 .. kept - 1], order[kept - 1 ..])) break;
    }
    if (kept == 1) return Value.kw(order[0]);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(options.allocator);
    for (order[0..kept], 0..) |k, i| {
        if (i != 0) try text.append(options.allocator, ' ');
        try text.appendSlice(options.allocator, k.name());
    }
    return .{ .text = try values.SharedText.create(options.allocator, text.items) };
}

/// Whether `rest`, the components after `named`, is the default order of
/// the components `named` leaves out - so naming `named` alone gives the
/// same order.
fn impliedAfter(named: []const values.Keyword, rest: []const values.Keyword) bool {
    var expected: [3]values.Keyword = undefined;
    var n: usize = 0;
    for ([_]values.Keyword{ .fill, .stroke, .markers }) |k| {
        if (std.mem.indexOfScalar(values.Keyword, named, k) == null) {
            expected[n] = k;
            n += 1;
        }
    }
    return std.mem.eql(values.Keyword, expected[0..n], rest);
}

test "paint-order keeps the shortest form" {
    const cases = [_][2][]const u8{
        .{ "fill stroke markers", "fill" },
        .{ "fill markers stroke", "fill markers" },
        .{ "stroke fill markers", "stroke" },
        .{ "markers stroke fill", "markers stroke" },
        .{ "markers", "markers" },
        .{ "stroke markers", "stroke markers" },
    };
    for (cases) |case| {
        var stream = properties.Stream.init(case[0]);
        const v = (try parsePaintOrder(.{ .allocator = std.testing.allocator }, &stream)).?;
        defer v.release();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(std.testing.allocator);
        try properties.serializeValue(.paint_order, v, &out, std.testing.allocator);
        try std.testing.expectEqualStrings(case[1], out.items);
    }
}
