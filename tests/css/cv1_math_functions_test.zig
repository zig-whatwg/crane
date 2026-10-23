//! CSS Values 4 §§10.3–10.6: stateless numeric functions.
const std = @import("std");
const css = @import("css");
const math = css.math_values;
const testing = std.testing;

fn number(text: []const u8, kind: math.Kind, want: f64, unit: math.Unit) !void {
    const parsed = try math.parse(testing.allocator, text, .{ .kind = kind }) orelse return error.InvalidMath;
    defer parsed.expression.unref();
    try testing.expectEqual(text.len, parsed.consumed);
    const computed = try parsed.expression.compute(testing.allocator, .{});
    defer computed.unref();
    const result = computed.computedNumber() orelse return error.UnresolvedMath;
    try testing.expectEqual(unit, result.unit);
    try testing.expectApproxEqAbs(want, result.value, 0.000001);
}

fn serial(text: []const u8, kind: math.Kind, want: []const u8, computed_want: ?[]const u8) !void {
    const parsed = try math.parse(testing.allocator, text, .{ .kind = kind }) orelse return error.InvalidMath;
    defer parsed.expression.unref();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try parsed.expression.serialize(&out, testing.allocator);
    try testing.expectEqualStrings(want, out.items);
    if (computed_want) |expected| {
        const computed = try parsed.expression.compute(testing.allocator, .{});
        defer computed.unref();
        out.clearRetainingCapacity();
        try computed.serialize(&out, testing.allocator);
        try testing.expectEqualStrings(expected, out.items);
    }
}

fn invalid(text: []const u8, kind: math.Kind) !void {
    const parsed = try math.parse(testing.allocator, text, .{ .kind = kind });
    defer if (parsed) |p| p.expression.unref();
    try testing.expect(parsed == null);
}

test "round uses the chosen strategy and defaults number intervals to one" {
    try number("round(2.5)", .number, 3, .number);
    try number("round(-2.5)", .number, -2, .number);
    try number("round(up, -3px, 2px)", .length, -2, .px);
    try number("round(down, -3px, -2px)", .length, -4, .px);
    try number("round(to-zero, -3px, 2px)", .length, -2, .px);
    try number("round(nearest, 1500ms, 1s)", .time, 2, .s);
    try serial("round(nearest, 1em, 3px)", .length, "round(1em, 3px)", "15px");
    try invalid("round(1px)", .length);
    try invalid("round(1, 1px)", .number);
    try invalid("round(1px,)", .length);
    // Q67: no shipping engine implements the newer device-pixel strategy.
    try invalid("round(line-width, 1px)", .length);
}

test "mod and rem differ by sign and retain signed zero inside the tree" {
    try number("mod(-18px, 5px)", .length, 2, .px);
    try number("rem(-18px, 5px)", .length, -3, .px);
    try number("mod(18px, -5px)", .length, -2, .px);
    try number("rem(18px, -5px)", .length, 3, .px);
    try number("clamp(-1, 1 / mod(0, -2), 1)", .number, -1, .number);
    try number("clamp(-1, 1 / rem(-2, 2), 1)", .number, -1, .number);
    try serial("mod(10%, 3%)", .length_percentage, "mod(10%, 3%)", "mod(10%, 3%)");
    try invalid("mod(1px, 1s)", .length);
}

test "stepped functions define zero and infinity before arithmetic" {
    try serial("round(1, 0)", .number, "calc(NaN)", "0");
    try serial("round(infinity, infinity)", .number, "calc(NaN)", "0");
    try number("clamp(-1, 1 / round(-1, infinity), 1)", .number, -1, .number);
    try number("round(up, 1, infinity)", .number, std.math.floatMax(f64), .number);
    try serial("mod(-1, infinity)", .number, "calc(NaN)", "0");
    try number("rem(-1, infinity)", .number, -1, .number);
}

test "trigonometric functions apply their input and output types" {
    try number("sin(90deg)", .number, 1, .number);
    try number("cos(0)", .number, 1, .number);
    try number("tan(45deg)", .number, 1, .number);
    try number("asin(1)", .angle, 90, .deg);
    try number("acos(-1)", .angle, 180, .deg);
    try number("atan(infinity)", .angle, 90, .deg);
    try number("atan2(1px, -1px)", .angle, 135, .deg);
    try number("atan2(-infinity, -infinity)", .angle, -135, .deg);
    try serial("sin(infinity)", .number, "calc(NaN)", "0");
    try invalid("sin(1px)", .number);
    try invalid("acos(1deg)", .angle);
    try invalid("atan2(1px, 1s)", .angle);
}

test "exponential functions compute units and preserve nonfinite boundaries" {
    try number("pow(2, 3)", .number, 8, .number);
    try number("sqrt(9)", .number, 3, .number);
    try number("hypot(3px, 4px)", .length, 5, .px);
    try number("log(8, 2)", .number, 3, .number);
    try number("log(e)", .number, 1, .number);
    try number("exp(0)", .number, 1, .number);
    try number("hypot(3em, 4em)", .length, 80, .px);
    try serial("sqrt(-1)", .number, "calc(NaN)", "0");
    try serial("log(1, 1)", .number, "calc(NaN)", "0");
    try invalid("pow(2px, 2)", .length);
    try invalid("sqrt(1px * 1px)", .length);
    try invalid("hypot(1px, 1s)", .length);
}

test "sign and abs wait for the correct unit and percentage context" {
    try number("abs(-3px)", .length, 3, .px);
    try number("sign(1em - 10px)", .number, 1, .number);
    try number("sign(1em - 16px)", .number, 0, .number);
    try serial("abs(1em - 20px)", .length, "abs(1em - 20px)", "4px");
    try serial("abs(-10%)", .length_percentage, "abs(-10%)", "abs(-10%)");
    try invalid("sign(10%)", .number);
    try invalid("sin(sign(10%))", .number);
    try number("clamp(-1, 1 / sign(-1 * 0), 1)", .number, -1, .number);
    // Q65: all three browsers preserve a literal's negative zero inside
    // the tree, even though the top-level computed value censors its sign.
    try number("clamp(-1, 1 / sign(-0), 1)", .number, -1, .number);
    try number("clamp(-1, 1 / sign(-0px), 1)", .number, -1, .number);
    try number("clamp(-1, 1 / calc(-0), 1)", .number, -1, .number);
    try serial("sign(-0)", .number, "calc(0)", "0");
}

test "pow follows unanimous special values while hypot keeps infectious NaN" {
    // Q65: csswg-drafts bfdc89260c (2019-07-30) predates the extra
    // WPT coverage ab1720909f (2026-09-25). These pow results are the
    // unanimous C156/F158/S27 behavior, not a newer-rule lag exemption.
    for ([_][]const u8{ "pow(NaN, 0)", "pow(1, NaN)", "pow(1, infinity)", "pow(-1, infinity)", "pow(1, -infinity)", "pow(-1, -infinity)" }) |text|
        try number(text, .number, 1, .number);
    try serial("hypot(infinity, NaN)", .number, "calc(NaN)", "0");
    try serial("hypot(NaN, -infinity)", .number, "calc(NaN)", "0");
}

test "log follows unanimous base one and negative zero behavior" {
    // Q68: all three aligned browsers compute the ordinary log ratio.
    try serial("log(2, 1)", .number, "calc(infinity)", null);
    try serial("log(5, 1)", .number, "calc(infinity)", null);
    try number("clamp(-1, 1 / log(1, 0.5), 1)", .number, -1, .number);
    try serial("log(1, 1)", .number, "calc(NaN)", "0");
}

test "function argument count and intermediate dimensional types stay strict" {
    for ([_][]const u8{ "abs()", "sign(1,2)", "sqrt(1,2)", "sin(1,2)", "pow(1)", "log(1,2,3)", "hypot()", "round(1,2,3)", "mod(1)", "rem(1,2,3)", "sign(1px * 1px)", "abs(1px * 1px)" }) |bad| try invalid(bad, .number);
    try serial("abs(1em - 20px", .length, "abs(1em - 20px)", "4px");
}

test "known math values expose no speculative metrics or boundary clamps" {
    if (comptime !@hasDecl(math.Expression, "knownNumber")) return error.KnownMathValueNotImplemented;
    const nan = (try math.parse(testing.allocator, "calc(0/0)", .{ .kind = .number })).?;
    defer nan.expression.unref();
    try testing.expect(std.math.isNan(nan.expression.knownNumber().?.value));
    const relative = (try math.parse(testing.allocator, "calc(1em)", .{ .kind = .length })).?;
    defer relative.expression.unref();
    try testing.expect(relative.expression.knownNumber() == null);
    const percent = (try math.parse(testing.allocator, "calc(10%)", .{ .kind = .length_percentage })).?;
    defer percent.expression.unref();
    try testing.expect(percent.expression.knownNumber() == null);
    const pure_percent = (try math.parse(testing.allocator, "calc(10%)", .{ .kind = .percentage })).?;
    defer pure_percent.expression.unref();
    try testing.expectEqual(@as(f64, 10), pure_percent.expression.knownNumber().?.value);
}

test "stateless functions release parse computation and serialization failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: std.mem.Allocator) !void {
    const parsed = try math.parse(allocator, "hypot(round(1em, 3px), abs(1em - 20px))", .{ .kind = .length }) orelse return error.InvalidMath;
    defer parsed.expression.unref();
    const computed = try parsed.expression.compute(allocator, .{});
    defer computed.unref();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try computed.serialize(&out, allocator);
    try testing.expectEqualStrings("15.5242px", out.items);
}

test "progress computes consistent types with default and disabled clamping" {
    try number("progress(1, 0, 1)", .number, 1, .number);
    try number("progress(100px, 0px, 50px)", .number, 1, .number);
    try number("progress(-1s, 0ms, 2s)", .number, 0, .number);
    try number("progress(5, 10, 0)", .number, 0.5, .number);
    try number("progress(no-clamp 100px, 0px, 50px)", .number, 2, .number);
    try number("progress(no-clamp 10em, 50em, 100em)", .number, -0.8, .number);
    try number("progress(50em, 10em, 110em)", .number, 0.4, .number);
    try number("progress(180deg, 0turn, 1turn)", .number, 0.5, .number);
    try number("progress(1%, (10% - 10%), 100%)", .number, 0.01, .number);
    try number("progress(abs(5%), hypot(3%, 4%), 10%)", .number, 0, .number);
    try number("calc(progress(2, 0, 4) * 10px)", .length, 5, .px);
    try number("progress(progress(1,0,1), progress(0px,0px,1px), progress(1deg,0deg,1deg))", .number, 1, .number);
}

test "progress equal endpoints have explicit zero and infinity results" {
    for ([_][]const u8{ "progress(100px,10px,10px)", "progress(1px,10px,10px)", "progress(10px,10px,10px)", "progress(no-clamp 10px,10px,10px)" }) |text|
        try number(text, .number, 0, .number);
    try serial("progress(no-clamp 100px,10px,10px)", .number, "calc(infinity)", null);
    try serial("progress(no-clamp 1px,10px,10px)", .number, "calc(-infinity)", null);
    try serial("progress(NaN,0,1)", .number, "calc(NaN)", "0");
}

test "progress serialization preserves unresolved units and no clamp" {
    try serial("progress(100px,(10px - 10px),100px)", .number, "calc(1)", "1");
    try serial("progress(no-clamp 10em,0px,10rem)", .number, "progress(no-clamp 10em, 0px, 10rem)", "1");
    try serial("progress(10em,0px,10rem)", .number, "progress(10em, 0px, 10rem)", "1");
    try serial("calc(.5 * progress(no-clamp -100px,0px,100px))", .number, "calc(-0.5)", "-0.5");
}

test "progress rejects malformed arguments and inconsistent dimensions" {
    for ([_][]const u8{ "progress()", "progress(1)", "progress(1,2)", "progress(1,2,3,4)", "progress(1,,3)", "progress(no-clamp,1,2,3)", "progress(1 no-clamp,0,1)", "progress(1,0,1 no-clamp)", "progress(5%,0,8)", "progress(5%,0px,10px)", "progress(5,0deg,8deg)", "progress(10px * 10px,10px * 10px,10px * 10px)" }) |text|
        try invalid(text, .number);
    try invalid("calc(1px * progress(10deg,0,10))", .length);
}

test "progress owns copies and releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, progressAllocationFailure, .{});
}

test "progress waits for a zero metric and preserves its clamping choice" {
    const clamped = try math.parse(testing.allocator, "progress(5em,1em,2em)", .{ .kind = .number }) orelse return error.InvalidMath;
    defer clamped.expression.unref();
    const unclamped = try math.parse(testing.allocator, "progress(no-clamp 5em,1em,2em)", .{ .kind = .number }) orelse return error.InvalidMath;
    defer unclamped.expression.unref();
    try testing.expect(!clamped.expression.eql(unclamped.expression));
    try testing.expect(clamped.expression.knownNumber() == null);
    try testing.expect(unclamped.expression.knownNumber() == null);
    for ([_]*math.Expression{ clamped.expression, unclamped.expression }) |expression| {
        const computed = try expression.compute(testing.allocator, .{ .font_size = 0 });
        defer computed.unref();
        try testing.expectEqual(@as(f64, 0), computed.computedNumber().?.value);
    }
}

fn progressAllocationFailure(allocator: std.mem.Allocator) !void {
    const parsed = try math.parse(allocator, "progress(no-clamp 5em,1px,8rem)", .{ .kind = .number }) orelse return error.InvalidMath;
    defer parsed.expression.unref();
    const computed = try parsed.expression.compute(allocator, .{});
    defer computed.unref();
    try testing.expectApproxEqAbs(@as(f64, 79.0 / 127.0), computed.computedNumber().?.value, 0.000001);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try parsed.expression.serialize(&out, allocator);
    try testing.expectEqualStrings("progress(no-clamp 5em, 1px, 8rem)", out.items);
}
