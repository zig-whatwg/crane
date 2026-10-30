//! Easing functions (CSS Easing 2) as Web Animations evaluates them: an
//! effect's easing function (Web Animations 4.6.11, 4.7.7) and a keyframe's.
//!
//! Parsing and serialization are the CSS module's (css.easing_values, the
//! <easing-function> grammar the `easing` members use, Web Animations 6.5.1);
//! this file turns a parsed value into a function of the input progress and
//! the before flag.
//!
//! Spec: https://drafts.csswg.org/css-easing-2/#easing-functions
const std = @import("std");
const css = @import("css");

const Allocator = std.mem.Allocator;
const CssEasing = css.easing_values.Easing;

/// One point of a linear() easing function: its input and output.
pub const Point = struct { input: f64, output: f64 };

/// The step position of a steps() easing function (CSS Easing 2 3.3).
pub const StepPosition = enum { jump_start, jump_end, jump_none, jump_both };

/// An easing function, ready to evaluate.
pub const Function = union(enum) {
    linear,
    cubic: [4]f64,
    steps: struct { count: u32, position: StepPosition },
    /// linear(): its points after canonicalization, OWNED by the Easing that
    /// made them.
    points: []const Point,
};

/// A parsed easing: the CSS value (for serialization) and its function.
pub const Easing = struct {
    /// The specified value as parsed; null for the default `linear`.
    value: ?*CssEasing = null,
    function: Function = .linear,
    /// The serialization `getTiming()` and `getKeyframes()` return: OWNED
    /// when `value` is set.
    text: []const u8 = "linear",

    pub fn deinit(self: *Easing, allocator: Allocator) void {
        if (self.value) |value| {
            value.unref();
            allocator.free(self.text);
        }
        if (self.function == .points) allocator.free(self.function.points);
        self.* = .{};
    }

    /// A second owner of the same easing.
    pub fn clone(self: *const Easing, allocator: Allocator) Allocator.Error!Easing {
        if (self.value == null) return .{};
        const text = try allocator.dupe(u8, self.text);
        errdefer allocator.free(text);
        var copy: Easing = .{ .value = self.value, .function = self.function, .text = text };
        if (copy.function == .points) copy.function = .{ .points = try allocator.dupe(Point, self.function.points) };
        copy.value.?.ref();
        return copy;
    }

    /// The serialization `getTiming()` and `getKeyframes()` return.
    pub fn serialize(self: *const Easing, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        try out.appendSlice(allocator, self.text);
    }

    /// Evaluate at `input` (CSS Easing 2: the input progress value) with the
    /// before flag.
    pub fn evaluate(self: *const Easing, input: f64, before_flag: bool) f64 {
        return evaluateFunction(self.function, input, before_flag);
    }
};

/// Parse `text` with the <easing-function> production (Web Animations 6.5.4
/// step 4): null when it does not parse - the caller's TypeError.
pub fn parse(allocator: Allocator, text: []const u8) Allocator.Error!?Easing {
    var stream = css.properties.Stream.init(text);
    const value = (try CssEasing.consume(.{ .allocator = allocator }, &stream)) orelse return null;
    errdefer value.unref();
    if (stream.next().token_type != .eof) {
        value.unref();
        return null;
    }
    // A keyword stays as written; the rest compute (calc() resolved, linear()
    // canonicalized) for evaluation, as the browsers do at computed time.
    const computed = try value.compute(allocator, .{});
    defer computed.unref();
    const function = try functionOf(allocator, computed);
    errdefer if (function == .points) allocator.free(function.points);
    var serialized: std.ArrayList(u8) = .empty;
    errdefer serialized.deinit(allocator);
    try value.serialize(&serialized, allocator);
    return .{ .value = value, .function = function, .text = try serialized.toOwnedSlice(allocator) };
}

fn functionOf(allocator: Allocator, value: *const CssEasing) Allocator.Error!Function {
    switch (value.kind) {
        .keyword => {
            const name = value.keyword;
            if (std.mem.eql(u8, name, "ease")) return .{ .cubic = .{ 0.25, 0.1, 0.25, 1 } };
            if (std.mem.eql(u8, name, "ease-in")) return .{ .cubic = .{ 0.42, 0, 1, 1 } };
            if (std.mem.eql(u8, name, "ease-out")) return .{ .cubic = .{ 0, 0, 0.58, 1 } };
            if (std.mem.eql(u8, name, "ease-in-out")) return .{ .cubic = .{ 0.42, 0, 0.58, 1 } };
            return .linear;
        },
        .cubic => {
            var points: [4]f64 = .{ 0, 0, 1, 1 };
            for (value.terms.items[0..4], 0..) |term, i| points[i] = if (term.known()) |known| known.value else points[i];
            return .{ .cubic = points };
        },
        .steps => {
            const known = if (value.terms.items[0].known()) |n| n.value else 1;
            const count: u32 = if (std.math.isFinite(known) and known >= 1) @intFromFloat(@min(known, @as(f64, std.math.maxInt(u32)))) else 1;
            const position: StepPosition = switch (value.jump) {
                .start, .jump_start => .jump_start,
                .end, .jump_end => .jump_end,
                .jump_none => .jump_none,
                .jump_both => .jump_both,
            };
            return .{ .steps = .{ .count = count, .position = position } };
        },
        .linear => {
            const stops = value.stops.items;
            const points = try allocator.alloc(Point, stops.len);
            for (stops, 0..) |stop, i| {
                const output = if (value.terms.items[stop.output].known()) |n| n.value else 0;
                const input = if (stop.first) |index| (if (value.terms.items[index].known()) |n| n.value / 100 else 0) else 0;
                points[i] = .{ .input = input, .output = output };
            }
            return .{ .points = points };
        },
    }
}

/// CSS Easing 2: the output progress value of `function` for `input`.
pub fn evaluateFunction(function: Function, input: f64, before_flag: bool) f64 {
    return switch (function) {
        .linear => input,
        .cubic => |p| cubicBezier(p, input),
        .steps => |s| steps(s.count, s.position, input, before_flag),
        .points => |points| linearPoints(points, input),
    };
}

/// CSS Easing 2 3.3, steps(): the output progress value.
fn steps(count: u32, position: StepPosition, input: f64, before_flag: bool) f64 {
    const n: f64 = @floatFromInt(count);
    // 1. "Calculate the current step as floor(input progress value × steps)."
    var current = @floor(input * n);
    // 2. "If the step position property is one of jump-start or jump-both,
    // increment current step by one."
    if (position == .jump_start or position == .jump_both) current += 1;
    // 3. "If both the before flag is set and input progress value × steps mod
    // 1 equals zero, decrement current step by one."
    if (before_flag and @mod(input * n, 1) == 0) current -= 1;
    // 4. "If input progress value ≥ 0 and current step < 0, let current step
    // be zero."
    if (input >= 0 and current < 0) current = 0;
    // 5. The number of jumps.
    const jumps: f64 = switch (position) {
        .jump_start, .jump_end => n,
        .jump_none => n - 1,
        .jump_both => n + 1,
    };
    // 6. "If input progress value ≤ 1 and current step > jumps, let current
    // step be jumps."
    if (input <= 1 and current > jumps) current = jumps;
    // 7. "The output progress value is current step / jumps."
    return current / jumps;
}

/// CSS Easing 2 2.2, linear(): the output progress value for `input`.
fn linearPoints(points: []const Point, input: f64) f64 {
    if (points.len == 0) return input;
    if (points.len == 1) return points[0].output;
    // 1. "Let pointAIndex be the index of the last point whose input is less
    // than or equal to input progress value, or 0 if there is none."
    var a: usize = 0;
    for (points, 0..) |point, i| {
        if (point.input <= input) a = i;
    }
    // 2. "If pointAIndex is equal to points's size minus 1, decrement
    // pointAIndex by 1." (So there is always a point B.)
    if (a == points.len - 1) a -= 1;
    const point_a = points[a];
    const point_b = points[a + 1];
    // 5. "If pointA's input is equal to pointB's input, return pointB's
    // output."
    if (point_a.input == point_b.input) return point_b.output;
    // 6-7. Interpolate (or extrapolate, outside the first and last points).
    const progress = (input - point_a.input) / (point_b.input - point_a.input);
    return point_a.output + (point_b.output - point_a.output) * progress;
}

/// CSS Easing 2 3.2, cubic-bezier(): the output progress value. Within
/// [0, 1] the curve is solved for x; outside it, the curve is extended by its
/// tangents at the end points (2.3 "for input progress values outside the
/// range [0, 1]").
fn cubicBezier(p: [4]f64, input: f64) f64 {
    const x1 = p[0];
    const y1 = p[1];
    const x2 = p[2];
    const y2 = p[3];
    // Outside [0, 1] the curve is extended by its tangent at the end point
    // (2.2.2 step 3). Where the spec text gives no tangent - a control
    // point coincident with the end point, or both - the browsers differ
    // from it: cubic-bezier(0, 0, 0, 0) below 0 and cubic-bezier(1, 1, 1, 1)
    // above 1 are linear, and a vertical tangent is slope 0. These are
    // Blink's end gradients (gfx::CubicBezier::InitGradients,
    // ui/gfx/geometry/cubic_bezier.cc), and Chrome 156, Firefox 159 and
    // Safari 27 all pass the WPT that pins the linear equivalence (wpt.fyi
    // stable 07ce6e987a: web-animations/animation-model/keyframe-effects/
    // effect-value-transformed-distance.html 28/28 each). Golden rule 2.
    if (input < 0) {
        const start_gradient: f64 = if (x1 > 0) y1 / x1 else if (y1 == 0 and x2 > 0) y2 / x2 else if (y1 == 0 and y2 == 0) 1 else 0;
        return start_gradient * input;
    }
    if (input > 1) {
        const end_gradient: f64 = if (x2 < 1) (y2 - 1) / (x2 - 1) else if (y2 == 1 and x1 < 1) (y1 - 1) / (x1 - 1) else if (y2 == 1 and y1 == 1) 1 else 0;
        return 1 + end_gradient * (input - 1);
    }
    if (input == 0 or input == 1) return input;
    const t = solveCurveX(x1, x2, input);
    return sampleCurve(y1, y2, t);
}

fn sampleCurve(a1: f64, a2: f64, t: f64) f64 {
    // B(t) = 3(1-t)^2 t a1 + 3(1-t) t^2 a2 + t^3, with P0 = 0 and P3 = 1.
    const c = 3 * a1;
    const b = 3 * (a2 - a1) - c;
    const a = 1 - c - b;
    return ((a * t + b) * t + c) * t;
}

fn sampleCurveDerivative(a1: f64, a2: f64, t: f64) f64 {
    const c = 3 * a1;
    const b = 3 * (a2 - a1) - c;
    const a = 1 - c - b;
    return (3 * a * t + 2 * b) * t + c;
}

/// The curve parameter t whose x is `x` (x1, x2 in [0, 1]: x is monotonic).
fn solveCurveX(x1: f64, x2: f64, x: f64) f64 {
    const epsilon = 1e-9;
    // Newton's method first; bisection where it does not converge.
    var t = x;
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        const error_x = sampleCurve(x1, x2, t) - x;
        if (@abs(error_x) < epsilon) return t;
        const derivative = sampleCurveDerivative(x1, x2, t);
        if (@abs(derivative) < 1e-6) break;
        t -= error_x / derivative;
    }
    var low: f64 = 0;
    var high: f64 = 1;
    t = x;
    i = 0;
    while (i < 64) : (i += 1) {
        const value = sampleCurve(x1, x2, t);
        if (@abs(value - x) < epsilon) return t;
        if (x > value) low = t else high = t;
        t = (high - low) / 2 + low;
    }
    return t;
}

test "steps() follows CSS Easing 2 3.3, before flag included" {
    // steps(2, jump-end): 0, 0, 0.5, 0.5, 1.
    try std.testing.expectEqual(@as(f64, 0), steps(2, .jump_end, 0, false));
    try std.testing.expectEqual(@as(f64, 0), steps(2, .jump_end, 0.49, false));
    try std.testing.expectEqual(@as(f64, 0.5), steps(2, .jump_end, 0.5, false));
    try std.testing.expectEqual(@as(f64, 1), steps(2, .jump_end, 1, false));
    // jump-start at 0 is the first step, unless the before flag is set.
    try std.testing.expectEqual(@as(f64, 0.5), steps(2, .jump_start, 0, false));
    try std.testing.expectEqual(@as(f64, 0), steps(2, .jump_start, 0, true));
    // jump-none and jump-both change the number of jumps.
    try std.testing.expectEqual(@as(f64, 0.5), steps(3, .jump_none, 0.5, false));
    try std.testing.expectEqual(@as(f64, 1.0 / 3.0), steps(2, .jump_both, 0.1, false));
}

test "cubic-bezier() solves for x and extrapolates by the end tangents" {
    const ease: [4]f64 = .{ 0.25, 0.1, 0.25, 1 };
    try std.testing.expectEqual(@as(f64, 0), cubicBezier(ease, 0));
    try std.testing.expectEqual(@as(f64, 1), cubicBezier(ease, 1));
    try std.testing.expectApproxEqAbs(@as(f64, 0.8024033877399112), cubicBezier(ease, 0.5), 1e-6);
    // Linear control points are the identity.
    try std.testing.expectApproxEqAbs(@as(f64, 0.3), cubicBezier(.{ 0.25, 0.25, 0.75, 0.75 }, 0.3), 1e-6);
    // Outside [0, 1]: the tangent through P1 (below) and P2 (above).
    try std.testing.expectApproxEqAbs(@as(f64, -0.4), cubicBezier(ease, -1), 1e-9);
    try std.testing.expectEqual(@as(f64, 1), cubicBezier(ease, 2));
    try std.testing.expectApproxEqAbs(@as(f64, 2.2), cubicBezier(.{ 0.25, 0.1, 1, 1 }, 2), 1e-9);
}

test "linear() interpolates between its points" {
    const points = [_]Point{ .{ .input = 0, .output = 0 }, .{ .input = 0.5, .output = 1 }, .{ .input = 1, .output = 0 } };
    try std.testing.expectEqual(@as(f64, 0.5), linearPoints(&points, 0.25));
    try std.testing.expectEqual(@as(f64, 0.5), linearPoints(&points, 0.75));
    try std.testing.expectEqual(@as(f64, -1), linearPoints(&points, 1.5));
}

test "parse accepts an <easing-function> and nothing else" {
    const allocator = std.testing.allocator;
    var ease = (try parse(allocator, " ease-in-out ")).?;
    defer ease.deinit(allocator);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), ease.evaluate(0.5, false), 1e-6);
    var stepped = (try parse(allocator, "steps(4, jump-start)")).?;
    defer stepped.deinit(allocator);
    try std.testing.expectEqual(@as(f64, 0.25), stepped.evaluate(0, false));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try stepped.serialize(&out, allocator);
    try std.testing.expectEqualStrings("steps(4, jump-start)", out.items);
    var points = (try parse(allocator, "linear(0, 1 50%, 0)")).?;
    defer points.deinit(allocator);
    try std.testing.expectEqual(@as(f64, 0.5), points.evaluate(0.25, false));
    try std.testing.expect((try parse(allocator, "")) == null);
    try std.testing.expect((try parse(allocator, "ease ease")) == null);
    try std.testing.expect((try parse(allocator, "initial")) == null);
    try std.testing.expect((try parse(allocator, "cubic-bezier(1.1, 0, 1, 1)")) == null);
}
