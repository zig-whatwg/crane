//! DateTime struct for date/time representation and manipulation.
//!
//! Represents a calendar date and time with nanosecond precision.
//! Used as the core type for all date/time operations in the i18n library.
//!
//! ## Design Principles
//! - No global state - all data is per-instance
//! - Proper memory management with allocator threading
//! - Thread-safe (no shared mutable state)

const std = @import("std");

/// DateTime represents a calendar date and time.
///
/// Fields use natural ranges (month 1-12, day 1-31) rather than
/// zero-indexed ranges for clarity and consistency with ECMA-402.
pub const DateTime = struct {
    /// Year (can be negative for BCE dates)
    year: i32,
    /// Month of year (1-12)
    month: u8,
    /// Day of month (1-31)
    day: u8,
    /// Hour of day (0-23)
    hour: u8,
    /// Minute of hour (0-59)
    minute: u8,
    /// Second of minute (0-59, can be 60 for leap seconds)
    second: u8,
    /// Nanosecond of second (0-999999999)
    nanosecond: u32,

    /// Days per month for non-leap years
    const days_per_month = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

    /// Unix epoch as DateTime (1970-01-01T00:00:00Z)
    pub const unix_epoch = DateTime{
        .year = 1970,
        .month = 1,
        .day = 1,
        .hour = 0,
        .minute = 0,
        .second = 0,
        .nanosecond = 0,
    };

    /// Create a DateTime from a Unix timestamp (seconds since 1970-01-01T00:00:00Z)
    pub fn fromTimestamp(ts: i64) DateTime {
        return fromTimestampNanos(ts * std.time.ns_per_s);
    }

    /// Create a DateTime from a Unix timestamp in milliseconds
    pub fn fromTimestampMillis(ts: i64) DateTime {
        return fromTimestampNanos(ts * std.time.ns_per_ms);
    }

    /// Create a DateTime from a Unix timestamp in nanoseconds
    pub fn fromTimestampNanos(ts: i128) DateTime {
        // Handle negative timestamps (dates before 1970)
        var remaining_ns = ts;
        var year: i32 = 1970;

        // Calculate year
        if (remaining_ns >= 0) {
            // Forward from 1970
            while (true) {
                const days_in_year: i128 = if (isLeapYear(year)) 366 else 365;
                const ns_in_year = days_in_year * std.time.ns_per_day;
                if (remaining_ns < ns_in_year) break;
                remaining_ns -= ns_in_year;
                year += 1;
            }
        } else {
            // Backward from 1970
            while (remaining_ns < 0) {
                year -= 1;
                const days_in_year: i128 = if (isLeapYear(year)) 366 else 365;
                const ns_in_year = days_in_year * std.time.ns_per_day;
                remaining_ns += ns_in_year;
            }
        }

        // Calculate month and day
        var month: u8 = 1;
        while (month <= 12) : (month += 1) {
            const days_in_month = daysInMonthForYear(month, year);
            const ns_in_month: i128 = @as(i128, days_in_month) * std.time.ns_per_day;
            if (remaining_ns < ns_in_month) break;
            remaining_ns -= ns_in_month;
        }

        const day: u8 = @intCast(@divFloor(remaining_ns, std.time.ns_per_day) + 1);
        remaining_ns = @mod(remaining_ns, std.time.ns_per_day);

        const hour: u8 = @intCast(@divFloor(remaining_ns, std.time.ns_per_hour));
        remaining_ns = @mod(remaining_ns, std.time.ns_per_hour);

        const minute: u8 = @intCast(@divFloor(remaining_ns, std.time.ns_per_min));
        remaining_ns = @mod(remaining_ns, std.time.ns_per_min);

        const second: u8 = @intCast(@divFloor(remaining_ns, std.time.ns_per_s));
        remaining_ns = @mod(remaining_ns, std.time.ns_per_s);

        return DateTime{
            .year = year,
            .month = month,
            .day = day,
            .hour = hour,
            .minute = minute,
            .second = second,
            .nanosecond = @intCast(remaining_ns),
        };
    }

    /// Convert DateTime to Unix timestamp (seconds since epoch)
    pub fn toTimestamp(self: DateTime) i64 {
        return @intCast(@divFloor(self.toTimestampNanos(), std.time.ns_per_s));
    }

    /// Convert DateTime to Unix timestamp in milliseconds
    pub fn toTimestampMillis(self: DateTime) i64 {
        return @intCast(@divFloor(self.toTimestampNanos(), std.time.ns_per_ms));
    }

    /// Convert DateTime to Unix timestamp in nanoseconds
    pub fn toTimestampNanos(self: DateTime) i128 {
        // Calculate days from year
        var days: i64 = 0;

        if (self.year >= 1970) {
            var y: i32 = 1970;
            while (y < self.year) : (y += 1) {
                days += if (isLeapYear(y)) 366 else 365;
            }
        } else {
            var y: i32 = 1969;
            while (y >= self.year) : (y -= 1) {
                days -= if (isLeapYear(y)) 366 else 365;
            }
        }

        // Add days from months
        var m: u8 = 1;
        while (m < self.month) : (m += 1) {
            days += daysInMonthForYear(m, self.year);
        }

        // Add days (1-indexed to 0-indexed)
        days += self.day - 1;

        // Convert to nanoseconds
        var nanos: i128 = @as(i128, days) * std.time.ns_per_day;
        nanos += @as(i128, self.hour) * std.time.ns_per_hour;
        nanos += @as(i128, self.minute) * std.time.ns_per_min;
        nanos += @as(i128, self.second) * std.time.ns_per_s;
        nanos += self.nanosecond;

        return nanos;
    }

    /// Check if a year is a leap year (Gregorian calendar)
    pub fn isLeapYear(year: i32) bool {
        if (@mod(year, 400) == 0) return true;
        if (@mod(year, 100) == 0) return false;
        if (@mod(year, 4) == 0) return true;
        return false;
    }

    /// Get number of days in a month for a given year
    pub fn daysInMonthForYear(month: u8, year: i32) u8 {
        if (month < 1 or month > 12) return 0;
        if (month == 2 and isLeapYear(year)) return 29;
        return days_per_month[month - 1];
    }

    /// Get number of days in this DateTime's month
    pub fn daysInMonth(self: DateTime) u8 {
        return daysInMonthForYear(self.month, self.year);
    }

    /// Get day of week (0 = Sunday, 1 = Monday, ..., 6 = Saturday)
    /// Uses Zeller's congruence algorithm
    pub fn dayOfWeek(self: DateTime) u8 {
        var y = self.year;
        var m = self.month;

        // Adjust for Zeller's formula (March = 1, February = 12 of previous year)
        if (m < 3) {
            m += 12;
            y -= 1;
        }

        const q: i32 = self.day;
        const k: i32 = @mod(y, 100);
        const j: i32 = @divFloor(y, 100);

        // Zeller's congruence for Gregorian calendar
        const h = @mod(q + @divFloor(13 * (m + 1), 5) + k + @divFloor(k, 4) + @divFloor(j, 4) - 2 * j, 7);

        // Convert from Zeller's result (0 = Saturday) to 0 = Sunday
        return @intCast(@mod(h + 6, 7));
    }

    /// Get ISO day of week (1 = Monday, 7 = Sunday)
    pub fn isoDayOfWeek(self: DateTime) u8 {
        const dow = self.dayOfWeek();
        return if (dow == 0) 7 else dow;
    }

    /// Get day of year (1-366)
    pub fn dayOfYear(self: DateTime) u16 {
        var day: u16 = self.day;
        var m: u8 = 1;
        while (m < self.month) : (m += 1) {
            day += daysInMonthForYear(m, self.year);
        }
        return day;
    }

    /// Get ISO week number (1-53)
    pub fn isoWeekNumber(self: DateTime) u8 {
        // ISO week date algorithm
        const jan4 = DateTime{ .year = self.year, .month = 1, .day = 4, .hour = 0, .minute = 0, .second = 0, .nanosecond = 0 };
        const jan4_dow = jan4.isoDayOfWeek();

        // Day of year adjusted for week start
        const doy = self.dayOfYear();
        const self_dow = self.isoDayOfWeek();

        // Calculate week number
        const week: i32 = @divFloor(@as(i32, doy) - @as(i32, self_dow) + 10, 7);

        if (week < 1) {
            // Last week of previous year
            const prev_year_last = DateTime{ .year = self.year - 1, .month = 12, .day = 31, .hour = 0, .minute = 0, .second = 0, .nanosecond = 0 };
            return prev_year_last.isoWeekNumber();
        } else if (week > 52) {
            // Check if it's week 53 or week 1 of next year
            const dec31 = DateTime{ .year = self.year, .month = 12, .day = 31, .hour = 0, .minute = 0, .second = 0, .nanosecond = 0 };
            const dec31_dow = dec31.isoDayOfWeek();
            if (dec31_dow < 4) {
                return 1; // Week 1 of next year
            }
            return @intCast(week);
        }

        _ = jan4_dow;
        return @intCast(week);
    }

    /// Get ISO week year (can differ from calendar year for dates near year boundaries)
    pub fn isoWeekYear(self: DateTime) i32 {
        const week = self.isoWeekNumber();
        if (self.month == 1 and week >= 52) {
            return self.year - 1;
        } else if (self.month == 12 and week == 1) {
            return self.year + 1;
        }
        return self.year;
    }

    /// Add days to the DateTime
    pub fn addDays(self: DateTime, days: i32) DateTime {
        const nanos = self.toTimestampNanos() + @as(i128, days) * std.time.ns_per_day;
        return fromTimestampNanos(nanos);
    }

    /// Add hours to the DateTime
    pub fn addHours(self: DateTime, hours: i32) DateTime {
        const nanos = self.toTimestampNanos() + @as(i128, hours) * std.time.ns_per_hour;
        return fromTimestampNanos(nanos);
    }

    /// Add minutes to the DateTime
    pub fn addMinutes(self: DateTime, minutes: i32) DateTime {
        const nanos = self.toTimestampNanos() + @as(i128, minutes) * std.time.ns_per_min;
        return fromTimestampNanos(nanos);
    }

    /// Add seconds to the DateTime
    pub fn addSeconds(self: DateTime, seconds: i64) DateTime {
        const nanos = self.toTimestampNanos() + @as(i128, seconds) * std.time.ns_per_s;
        return fromTimestampNanos(nanos);
    }

    /// Compare two DateTimes
    pub fn compare(self: DateTime, other: DateTime) std.math.Order {
        const self_ns = self.toTimestampNanos();
        const other_ns = other.toTimestampNanos();
        return std.math.order(self_ns, other_ns);
    }

    /// Check if two DateTimes are equal
    pub fn eql(self: DateTime, other: DateTime) bool {
        return self.compare(other) == .eq;
    }

    /// Format DateTime as ISO 8601 string (YYYY-MM-DDTHH:MM:SS.sssssssssZ)
    /// Returns a stack-allocated fixed-size buffer
    pub fn toIso8601(self: DateTime) [30]u8 {
        var buf: [30]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.{d:0>9}Z", .{
            self.year,
            self.month,
            self.day,
            self.hour,
            self.minute,
            self.second,
            self.nanosecond,
        }) catch unreachable;
        return buf;
    }
};

// Tests
test "DateTime - Unix epoch" {
    const epoch = DateTime.fromTimestamp(0);
    try std.testing.expectEqual(@as(i32, 1970), epoch.year);
    try std.testing.expectEqual(@as(u8, 1), epoch.month);
    try std.testing.expectEqual(@as(u8, 1), epoch.day);
    try std.testing.expectEqual(@as(u8, 0), epoch.hour);
    try std.testing.expectEqual(@as(u8, 0), epoch.minute);
    try std.testing.expectEqual(@as(u8, 0), epoch.second);
}

test "DateTime - fromTimestamp roundtrip" {
    const timestamps = [_]i64{
        0, // Unix epoch
        86400, // 1970-01-02
        31536000, // 1971-01-01
        1609459200, // 2021-01-01
        -86400, // 1969-12-31
        -31536000, // 1969-01-01
        1700000000, // 2023-11-14
    };

    for (timestamps) |ts| {
        const dt = DateTime.fromTimestamp(ts);
        const roundtrip = dt.toTimestamp();
        try std.testing.expectEqual(ts, roundtrip);
    }
}

test "DateTime - specific dates" {
    // 2023-11-14 12:30:45
    const ts: i64 = 1699964445;
    const dt = DateTime.fromTimestamp(ts);

    try std.testing.expectEqual(@as(i32, 2023), dt.year);
    try std.testing.expectEqual(@as(u8, 11), dt.month);
    try std.testing.expectEqual(@as(u8, 14), dt.day);
    try std.testing.expectEqual(@as(u8, 12), dt.hour);
    try std.testing.expectEqual(@as(u8, 30), dt.minute);
    try std.testing.expectEqual(@as(u8, 45), dt.second);
}

test "DateTime - leap years" {
    try std.testing.expect(DateTime.isLeapYear(2000)); // Divisible by 400
    try std.testing.expect(!DateTime.isLeapYear(1900)); // Divisible by 100 but not 400
    try std.testing.expect(DateTime.isLeapYear(2004)); // Divisible by 4
    try std.testing.expect(!DateTime.isLeapYear(2001)); // Not divisible by 4
}

test "DateTime - days in month" {
    try std.testing.expectEqual(@as(u8, 31), DateTime.daysInMonthForYear(1, 2023)); // January
    try std.testing.expectEqual(@as(u8, 28), DateTime.daysInMonthForYear(2, 2023)); // February (non-leap)
    try std.testing.expectEqual(@as(u8, 29), DateTime.daysInMonthForYear(2, 2024)); // February (leap)
    try std.testing.expectEqual(@as(u8, 30), DateTime.daysInMonthForYear(4, 2023)); // April
    try std.testing.expectEqual(@as(u8, 31), DateTime.daysInMonthForYear(12, 2023)); // December
}

test "DateTime - day of week" {
    // 2023-11-14 is a Tuesday
    const tuesday = DateTime{ .year = 2023, .month = 11, .day = 14, .hour = 0, .minute = 0, .second = 0, .nanosecond = 0 };
    try std.testing.expectEqual(@as(u8, 2), tuesday.dayOfWeek()); // 2 = Tuesday

    // 1970-01-01 was a Thursday
    const epoch = DateTime.unix_epoch;
    try std.testing.expectEqual(@as(u8, 4), epoch.dayOfWeek()); // 4 = Thursday

    // 2024-01-01 is a Monday
    const monday = DateTime{ .year = 2024, .month = 1, .day = 1, .hour = 0, .minute = 0, .second = 0, .nanosecond = 0 };
    try std.testing.expectEqual(@as(u8, 1), monday.dayOfWeek()); // 1 = Monday
}

test "DateTime - day of year" {
    const jan1 = DateTime{ .year = 2023, .month = 1, .day = 1, .hour = 0, .minute = 0, .second = 0, .nanosecond = 0 };
    try std.testing.expectEqual(@as(u16, 1), jan1.dayOfYear());

    const dec31 = DateTime{ .year = 2023, .month = 12, .day = 31, .hour = 0, .minute = 0, .second = 0, .nanosecond = 0 };
    try std.testing.expectEqual(@as(u16, 365), dec31.dayOfYear());

    // Leap year
    const dec31_leap = DateTime{ .year = 2024, .month = 12, .day = 31, .hour = 0, .minute = 0, .second = 0, .nanosecond = 0 };
    try std.testing.expectEqual(@as(u16, 366), dec31_leap.dayOfYear());
}

test "DateTime - add operations" {
    const dt = DateTime{ .year = 2023, .month = 11, .day = 14, .hour = 12, .minute = 30, .second = 0, .nanosecond = 0 };

    // Add days
    const next_day = dt.addDays(1);
    try std.testing.expectEqual(@as(u8, 15), next_day.day);

    // Add across month boundary
    const next_month = dt.addDays(17);
    try std.testing.expectEqual(@as(u8, 12), next_month.month);
    try std.testing.expectEqual(@as(u8, 1), next_month.day);

    // Add hours
    const later = dt.addHours(2);
    try std.testing.expectEqual(@as(u8, 14), later.hour);
}

test "DateTime - negative timestamps (before 1970)" {
    // 1969-12-31 23:59:59
    const ts: i64 = -1;
    const dt = DateTime.fromTimestamp(ts);
    try std.testing.expectEqual(@as(i32, 1969), dt.year);
    try std.testing.expectEqual(@as(u8, 12), dt.month);
    try std.testing.expectEqual(@as(u8, 31), dt.day);
    try std.testing.expectEqual(@as(u8, 23), dt.hour);
    try std.testing.expectEqual(@as(u8, 59), dt.minute);
    try std.testing.expectEqual(@as(u8, 59), dt.second);
}

test "DateTime - compare and eql" {
    const dt1 = DateTime{ .year = 2023, .month = 11, .day = 14, .hour = 12, .minute = 0, .second = 0, .nanosecond = 0 };
    const dt2 = DateTime{ .year = 2023, .month = 11, .day = 14, .hour = 12, .minute = 0, .second = 0, .nanosecond = 0 };
    const dt3 = DateTime{ .year = 2023, .month = 11, .day = 14, .hour = 13, .minute = 0, .second = 0, .nanosecond = 0 };

    try std.testing.expect(dt1.eql(dt2));
    try std.testing.expect(!dt1.eql(dt3));
    try std.testing.expectEqual(std.math.Order.lt, dt1.compare(dt3));
    try std.testing.expectEqual(std.math.Order.gt, dt3.compare(dt1));
}

test "DateTime - ISO week number" {
    // 2023-01-01 is in ISO week 52 of 2022
    const dt1 = DateTime{ .year = 2023, .month = 1, .day = 1, .hour = 0, .minute = 0, .second = 0, .nanosecond = 0 };
    try std.testing.expectEqual(@as(u8, 52), dt1.isoWeekNumber());
    try std.testing.expectEqual(@as(i32, 2022), dt1.isoWeekYear());

    // 2023-01-02 is in ISO week 1 of 2023
    const dt2 = DateTime{ .year = 2023, .month = 1, .day = 2, .hour = 0, .minute = 0, .second = 0, .nanosecond = 0 };
    try std.testing.expectEqual(@as(u8, 1), dt2.isoWeekNumber());
    try std.testing.expectEqual(@as(i32, 2023), dt2.isoWeekYear());
}

test "DateTime - milliseconds precision" {
    // Test timestamp with milliseconds (JavaScript style)
    const ts_ms: i64 = 1699964445123; // 2023-11-14 12:30:45.123
    const dt = DateTime.fromTimestampMillis(ts_ms);

    try std.testing.expectEqual(@as(i32, 2023), dt.year);
    try std.testing.expectEqual(@as(u8, 11), dt.month);
    try std.testing.expectEqual(@as(u8, 14), dt.day);
    try std.testing.expectEqual(@as(u8, 12), dt.hour);
    try std.testing.expectEqual(@as(u8, 30), dt.minute);
    try std.testing.expectEqual(@as(u8, 45), dt.second);
    try std.testing.expectEqual(@as(u32, 123000000), dt.nanosecond);

    // Roundtrip
    try std.testing.expectEqual(ts_ms, dt.toTimestampMillis());
}
