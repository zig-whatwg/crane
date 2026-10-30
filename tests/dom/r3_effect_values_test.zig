//! Lane rendering3: the effect value of a keyframe effect (Web Animations 1
//! 5.3.4, Web Animations 2 3.2.1) over numbers - the pure core the style
//! engine drives with css.interpolation.
const std = @import("std");
const dom = @import("dom");
const ev = dom.animations.effect_values;
const easing_mod = dom.animations.easing;
const PropertyKeyframe = ev.PropertyKeyframe;
const Sample = ev.Sample;
const Options = ev.Options;
const effectValue = ev.effectValue;

const testing = std.testing;

const NumberOps = struct {
    pub fn interpolate(_: NumberOps, a: f64, b: f64, p: f64) !f64 {
        return a + (b - a) * p;
    }
    pub fn add(_: NumberOps, a: f64, b: f64) !f64 {
        return a + b;
    }
    pub fn accumulate(_: NumberOps, a: f64, b: f64) !f64 {
        return a + b;
    }
    pub fn retain(_: NumberOps, v: f64) f64 {
        return v;
    }
    pub fn release(_: NumberOps, _: f64) void {}
};

const NK = PropertyKeyframe(f64);

fn value(keyframes: []const NK, sample: Sample, options: Options, underlying: f64) !?f64 {
    return effectValue(f64, NumberOps{}, keyframes, sample, options, underlying);
}

test "5.3.4: unresolved progress applies nothing; no keyframes give the underlying value" {
    try testing.expectEqual(@as(?f64, null), try value(&.{.{ .offset = 0, .value = 1 }}, .{ .progress = null }, .{}, 5));
    try testing.expectEqual(@as(?f64, 5), try value(&.{}, .{ .progress = 0.5 }, .{}, 5));
}

test "5.3.4: two keyframes interpolate; missing ends take the underlying value" {
    const both = [_]NK{ .{ .offset = 0, .value = 10 }, .{ .offset = 1, .value = 20 } };
    try testing.expectEqual(@as(?f64, 15), try value(&both, .{ .progress = 0.5 }, .{}, 0));
    try testing.expectEqual(@as(?f64, 25), try value(&both, .{ .progress = 1.5 }, .{}, 0));
    const to_only = [_]NK{.{ .offset = 1, .value = 20 }};
    try testing.expectEqual(@as(?f64, 15), try value(&to_only, .{ .progress = 0.5 }, .{}, 10));
    const middle = [_]NK{.{ .offset = 0.5, .value = 20 }};
    try testing.expectEqual(@as(?f64, 15), try value(&middle, .{ .progress = 0.25 }, .{}, 10));
    try testing.expectEqual(@as(?f64, 15), try value(&middle, .{ .progress = 0.75 }, .{}, 10));
}

test "5.3.4: overlapping keyframes jump to the last; outside [0, 1] the outer ones hold" {
    const overlap = [_]NK{ .{ .offset = 0, .value = 0 }, .{ .offset = 0.5, .value = 10 }, .{ .offset = 0.5, .value = 20 }, .{ .offset = 1, .value = 30 } };
    try testing.expectEqual(@as(?f64, 25), try value(&overlap, .{ .progress = 0.75 }, .{}, 0));
    try testing.expectEqual(@as(?f64, 5), try value(&overlap, .{ .progress = 0.25 }, .{}, 0));
    const zeros = [_]NK{ .{ .offset = 0, .value = 1 }, .{ .offset = 0, .value = 2 }, .{ .offset = 1, .value = 3 } };
    try testing.expectEqual(@as(?f64, 1), try value(&zeros, .{ .progress = -1 }, .{}, 0));
    const ones = [_]NK{ .{ .offset = 0, .value = 1 }, .{ .offset = 1, .value = 2 }, .{ .offset = 1, .value = 3 } };
    try testing.expectEqual(@as(?f64, 3), try value(&ones, .{ .progress = 2 }, .{}, 0));
}

test "5.3.4 step 12.1 / 5.4.4: add and accumulate combine each endpoint with the underlying value" {
    const kf = [_]NK{ .{ .offset = 0, .value = 10 }, .{ .offset = 1, .value = 20 } };
    try testing.expectEqual(@as(?f64, 115), try value(&kf, .{ .progress = 0.5 }, .{ .composite = .add }, 100));
    // A keyframe's own composite wins over the effect's.
    const mixed = [_]NK{ .{ .offset = 0, .value = 10, .composite = .replace }, .{ .offset = 1, .value = 20 } };
    try testing.expectEqual(@as(?f64, 65), try value(&mixed, .{ .progress = 0.5 }, .{ .composite = .add }, 100));
}

test "WA2 3.2.1: iteration composite accumulate adds the final value per iteration" {
    const kf = [_]NK{ .{ .offset = 0, .value = 0 }, .{ .offset = 1, .value = 10 } };
    try testing.expectEqual(@as(?f64, 25), try value(&kf, .{ .progress = 0.5, .current_iteration = 2 }, .{ .iteration_accumulate = true }, 0));
    try testing.expectEqual(@as(?f64, 5), try value(&kf, .{ .progress = 0.5, .current_iteration = 2 }, .{}, 0));
}

test "5.3.4 step 15: the first endpoint's easing transforms the interval distance" {
    var steps: easing_mod.Easing = .{ .function = .{ .steps = .{ .count = 1, .position = .jump_end } } };
    const kf = [_]NK{ .{ .offset = 0, .value = 0, .easing = &steps }, .{ .offset = 1, .value = 10 } };
    try testing.expectEqual(@as(?f64, 0), try value(&kf, .{ .progress = 0.9 }, .{}, 0));
    try testing.expectEqual(@as(?f64, 10), try value(&kf, .{ .progress = 1 }, .{}, 0));
}
