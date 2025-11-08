//! WHATWG Infra Time Operations
//!
//! Spec: https://infra.spec.whatwg.org/#time
//! Reference: https://w3c.github.io/hr-time/
//!
//! WHATWG Infra Standard §4.7 lines 816-818
//!
//! Represent time using the moment and duration specification types from
//! the High Resolution Time specification.
//!
//! # Usage
//!
//! ```zig
//! const std = @import("std");
//! const time = @import("time.zig");
//!
//! // Create a moment (timestamp)
//! const now = time.Moment.now();
//!
//! // Create a duration (time span)
//! const duration = time.Duration.fromMilliseconds(1000);
//!
//! // Arithmetic with moments and durations
//! const future = now.add(duration);
//! const elapsed = future.since(now);
//! ```

const std = @import("std");

/// A moment represents a single point in time with high-resolution precision.
///
/// WHATWG Infra Standard §4.7 line 816-818
/// High Resolution Time: https://w3c.github.io/hr-time/#dfn-moment
///
/// A moment is an abstract representation of time, independent of timezone.
/// It represents the number of milliseconds since the Unix epoch
/// (1970-01-01T00:00:00.000Z) with sub-millisecond precision.
pub const Moment = struct {
    /// Milliseconds since Unix epoch with sub-millisecond precision
    timestamp_ms: f64,

    /// Create a moment from milliseconds since Unix epoch
    pub fn fromMilliseconds(ms: f64) Moment {
        return Moment{ .timestamp_ms = ms };
    }

    /// Get the current moment (now)
    pub fn now() Moment {
        const ns = std.time.nanoTimestamp();
        const ms = @as(f64, @floatFromInt(ns)) / 1_000_000.0;
        return Moment{ .timestamp_ms = ms };
    }

    /// Add a duration to this moment, returning a new moment
    pub fn add(self: Moment, duration: Duration) Moment {
        return Moment{ .timestamp_ms = self.timestamp_ms + duration.ms };
    }

    /// Subtract a duration from this moment, returning a new moment
    pub fn subtract(self: Moment, duration: Duration) Moment {
        return Moment{ .timestamp_ms = self.timestamp_ms - duration.ms };
    }

    /// Calculate the duration between two moments
    pub fn since(self: Moment, earlier: Moment) Duration {
        return Duration{ .ms = self.timestamp_ms - earlier.timestamp_ms };
    }

    /// Check if this moment is before another moment
    pub fn isBefore(self: Moment, other: Moment) bool {
        return self.timestamp_ms < other.timestamp_ms;
    }

    /// Check if this moment is after another moment
    pub fn isAfter(self: Moment, other: Moment) bool {
        return self.timestamp_ms > other.timestamp_ms;
    }

    /// Check if two moments are equal
    pub fn equals(self: Moment, other: Moment) bool {
        return self.timestamp_ms == other.timestamp_ms;
    }

    /// Compare two moments (for sorting)
    pub fn compare(self: Moment, other: Moment) std.math.Order {
        if (self.timestamp_ms < other.timestamp_ms) return .lt;
        if (self.timestamp_ms > other.timestamp_ms) return .gt;
        return .eq;
    }

    /// Get milliseconds since Unix epoch
    pub fn toMilliseconds(self: Moment) f64 {
        return self.timestamp_ms;
    }

    /// Get seconds since Unix epoch
    pub fn toSeconds(self: Moment) f64 {
        return self.timestamp_ms / 1000.0;
    }
};

/// A duration represents a length of time with high-resolution precision.
///
/// WHATWG Infra Standard §4.7 line 816-818
/// High Resolution Time: https://w3c.github.io/hr-time/#dfn-duration
///
/// A duration represents a time span, independent of any specific moment.
/// It can be positive (future) or negative (past).
pub const Duration = struct {
    /// Duration in milliseconds (can be negative)
    ms: f64,

    /// Create a duration from milliseconds
    pub fn fromMilliseconds(milliseconds: f64) Duration {
        return Duration{ .ms = milliseconds };
    }

    /// Create a duration from seconds
    pub fn fromSeconds(seconds: f64) Duration {
        return Duration{ .ms = seconds * 1000.0 };
    }

    /// Create a duration from minutes
    pub fn fromMinutes(minutes: f64) Duration {
        return Duration{ .ms = minutes * 60.0 * 1000.0 };
    }

    /// Create a duration from hours
    pub fn fromHours(hours: f64) Duration {
        return Duration{ .ms = hours * 60.0 * 60.0 * 1000.0 };
    }

    /// Create a duration from days
    pub fn fromDays(days: f64) Duration {
        return Duration{ .ms = days * 24.0 * 60.0 * 60.0 * 1000.0 };
    }

    /// Create a zero duration
    pub fn zero() Duration {
        return Duration{ .ms = 0.0 };
    }

    /// Add two durations
    pub fn add(self: Duration, other: Duration) Duration {
        return Duration{ .ms = self.ms + other.ms };
    }

    /// Subtract two durations
    pub fn subtract(self: Duration, other: Duration) Duration {
        return Duration{ .ms = self.ms - other.ms };
    }

    /// Multiply duration by a scalar
    pub fn multiply(self: Duration, scalar: f64) Duration {
        return Duration{ .ms = self.ms * scalar };
    }

    /// Divide duration by a scalar
    pub fn divide(self: Duration, scalar: f64) Duration {
        return Duration{ .ms = self.ms / scalar };
    }

    /// Get absolute value of duration
    pub fn abs(self: Duration) Duration {
        return Duration{ .ms = @abs(self.ms) };
    }

    /// Negate duration
    pub fn negate(self: Duration) Duration {
        return Duration{ .ms = -self.ms };
    }

    /// Check if duration is zero
    pub fn isZero(self: Duration) bool {
        return self.ms == 0.0;
    }

    /// Check if duration is positive
    pub fn isPositive(self: Duration) bool {
        return self.ms > 0.0;
    }

    /// Check if duration is negative
    pub fn isNegative(self: Duration) bool {
        return self.ms < 0.0;
    }

    /// Compare two durations
    pub fn compare(self: Duration, other: Duration) std.math.Order {
        if (self.ms < other.ms) return .lt;
        if (self.ms > other.ms) return .gt;
        return .eq;
    }

    /// Convert to milliseconds
    pub fn toMilliseconds(self: Duration) f64 {
        return self.ms;
    }

    /// Convert to seconds
    pub fn toSeconds(self: Duration) f64 {
        return self.ms / 1000.0;
    }

    /// Convert to minutes
    pub fn toMinutes(self: Duration) f64 {
        return self.ms / (60.0 * 1000.0);
    }

    /// Convert to hours
    pub fn toHours(self: Duration) f64 {
        return self.ms / (60.0 * 60.0 * 1000.0);
    }

    /// Convert to days
    pub fn toDays(self: Duration) f64 {
        return self.ms / (24.0 * 60.0 * 60.0 * 1000.0);
    }
};

test "Moment - create from milliseconds" {
    const moment = Moment.fromMilliseconds(1000.0);
    try std.testing.expectEqual(@as(f64, 1000.0), moment.timestamp_ms);
}

test "Moment - add duration" {
    const start = Moment.fromMilliseconds(1000.0);
    const duration = Duration.fromMilliseconds(500.0);
    const result = start.add(duration);
    try std.testing.expectEqual(@as(f64, 1500.0), result.timestamp_ms);
}

test "Moment - subtract duration" {
    const start = Moment.fromMilliseconds(1000.0);
    const duration = Duration.fromMilliseconds(500.0);
    const result = start.subtract(duration);
    try std.testing.expectEqual(@as(f64, 500.0), result.timestamp_ms);
}

test "Moment - since" {
    const earlier = Moment.fromMilliseconds(1000.0);
    const later = Moment.fromMilliseconds(1500.0);
    const duration = later.since(earlier);
    try std.testing.expectEqual(@as(f64, 500.0), duration.ms);
}

test "Moment - isBefore" {
    const earlier = Moment.fromMilliseconds(1000.0);
    const later = Moment.fromMilliseconds(1500.0);
    try std.testing.expect(earlier.isBefore(later));
    try std.testing.expect(!later.isBefore(earlier));
}

test "Moment - isAfter" {
    const earlier = Moment.fromMilliseconds(1000.0);
    const later = Moment.fromMilliseconds(1500.0);
    try std.testing.expect(later.isAfter(earlier));
    try std.testing.expect(!earlier.isAfter(later));
}

test "Moment - equals" {
    const m1 = Moment.fromMilliseconds(1000.0);
    const m2 = Moment.fromMilliseconds(1000.0);
    const m3 = Moment.fromMilliseconds(2000.0);
    try std.testing.expect(m1.equals(m2));
    try std.testing.expect(!m1.equals(m3));
}

test "Moment - compare" {
    const m1 = Moment.fromMilliseconds(1000.0);
    const m2 = Moment.fromMilliseconds(1500.0);
    const m3 = Moment.fromMilliseconds(1000.0);
    try std.testing.expectEqual(std.math.Order.lt, m1.compare(m2));
    try std.testing.expectEqual(std.math.Order.gt, m2.compare(m1));
    try std.testing.expectEqual(std.math.Order.eq, m1.compare(m3));
}

test "Moment - toSeconds" {
    const moment = Moment.fromMilliseconds(5000.0);
    try std.testing.expectEqual(@as(f64, 5.0), moment.toSeconds());
}

test "Duration - fromSeconds" {
    const duration = Duration.fromSeconds(5.0);
    try std.testing.expectEqual(@as(f64, 5000.0), duration.ms);
}

test "Duration - fromMinutes" {
    const duration = Duration.fromMinutes(1.0);
    try std.testing.expectEqual(@as(f64, 60000.0), duration.ms);
}

test "Duration - fromHours" {
    const duration = Duration.fromHours(1.0);
    try std.testing.expectEqual(@as(f64, 3600000.0), duration.ms);
}

test "Duration - fromDays" {
    const duration = Duration.fromDays(1.0);
    try std.testing.expectEqual(@as(f64, 86400000.0), duration.ms);
}

test "Duration - add" {
    const d1 = Duration.fromMilliseconds(1000.0);
    const d2 = Duration.fromMilliseconds(500.0);
    const result = d1.add(d2);
    try std.testing.expectEqual(@as(f64, 1500.0), result.ms);
}

test "Duration - subtract" {
    const d1 = Duration.fromMilliseconds(1000.0);
    const d2 = Duration.fromMilliseconds(500.0);
    const result = d1.subtract(d2);
    try std.testing.expectEqual(@as(f64, 500.0), result.ms);
}

test "Duration - multiply" {
    const duration = Duration.fromMilliseconds(100.0);
    const result = duration.multiply(5.0);
    try std.testing.expectEqual(@as(f64, 500.0), result.ms);
}

test "Duration - divide" {
    const duration = Duration.fromMilliseconds(1000.0);
    const result = duration.divide(4.0);
    try std.testing.expectEqual(@as(f64, 250.0), result.ms);
}

test "Duration - abs" {
    const negative = Duration.fromMilliseconds(-500.0);
    const result = negative.abs();
    try std.testing.expectEqual(@as(f64, 500.0), result.ms);
}

test "Duration - negate" {
    const positive = Duration.fromMilliseconds(500.0);
    const result = positive.negate();
    try std.testing.expectEqual(@as(f64, -500.0), result.ms);
}

test "Duration - isZero" {
    const zero = Duration.zero();
    const nonzero = Duration.fromMilliseconds(100.0);
    try std.testing.expect(zero.isZero());
    try std.testing.expect(!nonzero.isZero());
}

test "Duration - isPositive" {
    const positive = Duration.fromMilliseconds(100.0);
    const negative = Duration.fromMilliseconds(-100.0);
    const zero = Duration.zero();
    try std.testing.expect(positive.isPositive());
    try std.testing.expect(!negative.isPositive());
    try std.testing.expect(!zero.isPositive());
}

test "Duration - isNegative" {
    const positive = Duration.fromMilliseconds(100.0);
    const negative = Duration.fromMilliseconds(-100.0);
    const zero = Duration.zero();
    try std.testing.expect(negative.isNegative());
    try std.testing.expect(!positive.isNegative());
    try std.testing.expect(!zero.isNegative());
}

test "Duration - compare" {
    const d1 = Duration.fromMilliseconds(100.0);
    const d2 = Duration.fromMilliseconds(200.0);
    const d3 = Duration.fromMilliseconds(100.0);
    try std.testing.expectEqual(std.math.Order.lt, d1.compare(d2));
    try std.testing.expectEqual(std.math.Order.gt, d2.compare(d1));
    try std.testing.expectEqual(std.math.Order.eq, d1.compare(d3));
}

test "Duration - toSeconds" {
    const duration = Duration.fromMilliseconds(5000.0);
    try std.testing.expectEqual(@as(f64, 5.0), duration.toSeconds());
}

test "Duration - toMinutes" {
    const duration = Duration.fromSeconds(120.0);
    try std.testing.expectEqual(@as(f64, 2.0), duration.toMinutes());
}

test "Duration - toHours" {
    const duration = Duration.fromMinutes(120.0);
    try std.testing.expectEqual(@as(f64, 2.0), duration.toHours());
}

test "Duration - toDays" {
    const duration = Duration.fromHours(48.0);
    try std.testing.expectEqual(@as(f64, 2.0), duration.toDays());
}

test "Moment and Duration - real world scenario" {
    const start = Moment.now();
    const one_hour = Duration.fromHours(1.0);
    const future = start.add(one_hour);
    const elapsed = future.since(start);

    try std.testing.expectEqual(@as(f64, 3600000.0), elapsed.ms);
    try std.testing.expect(future.isAfter(start));
}
