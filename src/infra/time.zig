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




























