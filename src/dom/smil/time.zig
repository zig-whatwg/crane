//! SMIL time values: a moment or a duration on an SVG document fragment's
//! timeline, in whole microseconds, with the timing model's special values.
//!
//! SMIL Animation 3.6.8 ("Startup - getting the first interval"): a Time
//! "can be a resolved numeric value, the special value INDEFINITE (only
//! used with end), and it can be the special value UNRESOLVED. Indefinite
//! compares "greater than" all resolved values, and UNRESOLVED is "greater
//! than" both resolved values and INDEFINITE." So the special values are the
//! top of the range and the plain integer order is the spec's order:
//!
//!   earliest < every resolved time < latest < indefinite < unresolved
//!
//! Integer microseconds rather than floating seconds, as Blink's SMILTime
//! (core/svg/animation/smil_time.h: a base::TimeDelta) and Gecko's
//! SMILTime (int64 milliseconds) keep them: interval ends compare exactly,
//! so an interval that ends where the next one begins is a restart, not a
//! one-microsecond gap.
//!
//! Spec: https://www.w3.org/TR/2001/REC-smil-animation-20010904/#Timing-EvaluationOfBeginEndTimeLists
const std = @import("std");

pub const Time = struct {
    us: i64,

    pub const unresolved: Time = .{ .us = std.math.maxInt(i64) };
    pub const indefinite: Time = .{ .us = std.math.maxInt(i64) - 1 };
    /// The latest resolved time: what a clamped presentation time reaches.
    pub const latest: Time = .{ .us = std.math.maxInt(i64) - 2 };
    pub const earliest: Time = .{ .us = std.math.minInt(i64) };
    /// The smallest step between two resolved times.
    pub const epsilon: Time = .{ .us = 1 };
    pub const zero: Time = .{ .us = 0 };

    pub fn fromSeconds(value: f64) Time {
        if (std.math.isNan(value)) return unresolved;
        const us = value * std.time.us_per_s;
        if (us >= @as(f64, @floatFromInt(latest.us))) return latest;
        if (us <= @as(f64, @floatFromInt(earliest.us + 1))) return .{ .us = earliest.us + 1 };
        return .{ .us = @intFromFloat(@round(us)) };
    }

    pub fn fromMilliseconds(ms: f64) Time {
        return fromSeconds(ms / std.time.ms_per_s);
    }

    pub fn seconds(self: Time) f64 {
        return @as(f64, @floatFromInt(self.us)) / std.time.us_per_s;
    }

    pub fn isUnresolved(self: Time) bool {
        return self.us == unresolved.us;
    }

    pub fn isIndefinite(self: Time) bool {
        return self.us == indefinite.us;
    }

    /// A resolved time: neither indefinite nor unresolved.
    pub fn isFinite(self: Time) bool {
        return self.us < indefinite.us;
    }

    pub fn eql(a: Time, b: Time) bool {
        return a.us == b.us;
    }

    pub fn lessThan(a: Time, b: Time) bool {
        return a.us < b.us;
    }

    /// `lessThan` in std.mem.sort's shape.
    pub fn sortLessThan(_: void, a: Time, b: Time) bool {
        return a.us < b.us;
    }

    pub fn min(a: Time, b: Time) Time {
        return if (a.us <= b.us) a else b;
    }

    pub fn max(a: Time, b: Time) Time {
        return if (a.us >= b.us) a else b;
    }

    /// a + b: a special value stays itself (the larger one when both are),
    /// and a resolved sum saturates at `latest`.
    pub fn add(a: Time, b: Time) Time {
        if (!a.isFinite() or !b.isFinite()) return max(a, b);
        const sum = @addWithOverflow(a.us, b.us);
        if (sum[1] != 0) return if (b.us > 0) latest else .{ .us = earliest.us + 1 };
        return clamp(sum[0]);
    }

    /// a - b: an indefinite or unresolved `a` stays itself; a resolved `a`
    /// less a special `b` has no resolved answer (unresolved).
    pub fn sub(a: Time, b: Time) Time {
        if (!a.isFinite()) return a;
        if (!b.isFinite()) return unresolved;
        const diff = @subWithOverflow(a.us, b.us);
        if (diff[1] != 0) return if (b.us < 0) latest else .{ .us = earliest.us + 1 };
        return clamp(diff[0]);
    }

    pub fn negate(self: Time) Time {
        if (!self.isFinite()) return self;
        return .{ .us = -self.us };
    }

    /// A resolved time divided by a resolved, non-zero duration: the whole
    /// number of times it fits (rounded toward negative infinity).
    pub fn intDiv(self: Time, divisor: Time) i64 {
        std.debug.assert(self.isFinite() and divisor.isFinite() and divisor.us != 0);
        return @divFloor(self.us, divisor.us);
    }

    /// What is left of a resolved time once whole `divisor`s are taken out,
    /// in [0, divisor).
    pub fn rem(self: Time, divisor: Time) Time {
        std.debug.assert(self.isFinite() and divisor.isFinite() and divisor.us != 0);
        return .{ .us = @mod(self.us, divisor.us) };
    }

    /// The duration `count` iterations of a simple duration take (SMIL
    /// Animation 3.3.4: "repeatCount*d"): indefinite for an indefinite count,
    /// unresolved for none.
    pub fn repeat(self: Time, count: RepeatCount) Time {
        return switch (count) {
            .unspecified => unresolved,
            .indefinite => indefinite,
            .numeric => |n| blk: {
                if (!self.isFinite()) break :blk self;
                break :blk fromSeconds(self.seconds() * n);
            },
        };
    }

    fn clamp(us: i64) Time {
        if (us >= latest.us) return latest;
        if (us <= earliest.us) return .{ .us = earliest.us + 1 };
        return .{ .us = us };
    }
};

/// The repeatCount attribute's value (SMIL Animation 3.3.1).
pub const RepeatCount = union(enum) {
    unspecified,
    indefinite,
    /// "A (base 10) floating point numeric value ... Values must be greater
    /// than 0."
    numeric: f64,
};

/// An interval: a begin and an (active) end, both in the fragment's
/// document time (SMIL Animation 3.6.8). Unresolved when there is none.
pub const Interval = struct {
    begin: Time,
    end: Time,

    pub const unresolved: Interval = .{ .begin = .unresolved, .end = .unresolved };

    pub fn isResolved(self: Interval) bool {
        return !self.begin.isUnresolved();
    }

    pub fn eql(a: Interval, b: Interval) bool {
        return a.begin.eql(b.begin) and a.end.eql(b.end);
    }

    pub fn beginsAfter(self: Interval, time: Time) bool {
        return time.lessThan(self.begin);
    }

    pub fn endsAfter(self: Interval, time: Time) bool {
        return time.lessThan(self.end);
    }

    pub fn endsBefore(self: Interval, time: Time) bool {
        return !self.endsAfter(time);
    }

    /// begin <= time < end: the interval is playing at `time`.
    pub fn contains(self: Interval, time: Time) bool {
        return !self.beginsAfter(time) and self.endsAfter(time);
    }
};
