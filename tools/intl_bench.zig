//! Intl Performance Benchmarks
//!
//! Benchmarking suite for the pure Zig internationalization library.
//! Measures performance of DateTimeFormat, NumberFormat, and Collator operations.
//!
//! ## Performance Targets (vs ICU)
//!
//! | Operation | Target | Acceptable |
//! |-----------|--------|------------|
//! | DateTimeFormat.format() | 1x ICU | 1.5x |
//! | NumberFormat.format() | 1x ICU | 1.5x |
//! | Object creation | 0.5x ICU | 1x |
//! | Memory usage | 0.8x ICU | 1x |
//!
//! ## Usage
//!
//! ```bash
//! zig build intl-bench
//! ./zig-out/bin/intl-bench
//! ```
//!
//! ## Output
//!
//! Results are printed in a human-readable format with:
//! - Operations per second
//! - Nanoseconds per operation
//! - Memory statistics (when applicable)
//!

const std = @import("std");

// Import CLDR data for benchmarking
const cldr = @import("intl").cldr;
const cldr_embedded = cldr.embedded;

// ============================================================================
// Benchmark Configuration
// ============================================================================

/// Number of warmup iterations before measurement
const WARMUP_ITERATIONS: usize = 1000;

/// Number of benchmark iterations for timing
const BENCH_ITERATIONS: usize = 10000;

/// Number of runs to average for stability
const NUM_RUNS: usize = 5;

// ============================================================================
// DateTime Helper (from intl_binding.zig)
// ============================================================================

const DateTime = struct {
    year: i32,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    second: u8,
    nanosecond: u32 = 0,

    fn fromTimestampMillis(ts: i64) DateTime {
        const ns = @as(i128, ts) * std.time.ns_per_ms;
        var remaining_ns = ns;
        var year: i32 = 1970;

        if (remaining_ns >= 0) {
            while (true) {
                const days_in_year: i128 = if (isLeapYear(year)) 366 else 365;
                const ns_in_year = days_in_year * std.time.ns_per_day;
                if (remaining_ns < ns_in_year) break;
                remaining_ns -= ns_in_year;
                year += 1;
            }
        } else {
            while (remaining_ns < 0) {
                year -= 1;
                const days_in_year: i128 = if (isLeapYear(year)) 366 else 365;
                const ns_in_year = days_in_year * std.time.ns_per_day;
                remaining_ns += ns_in_year;
            }
        }

        var month: u8 = 1;
        while (month <= 12) : (month += 1) {
            const days = daysInMonth(month, year);
            const ns_in_month: i128 = @as(i128, days) * std.time.ns_per_day;
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

        return .{
            .year = year,
            .month = month,
            .day = day,
            .hour = hour,
            .minute = minute,
            .second = second,
        };
    }

    fn isLeapYear(year: i32) bool {
        if (@mod(year, 400) == 0) return true;
        if (@mod(year, 100) == 0) return false;
        return @mod(year, 4) == 0;
    }

    fn daysInMonth(month: u8, year: i32) u8 {
        const days_per_month = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
        if (month == 2 and isLeapYear(year)) return 29;
        return days_per_month[month - 1];
    }

    fn dayOfWeek(self: DateTime) u8 {
        var y = self.year;
        var m = self.month;
        if (m < 3) {
            m += 12;
            y -= 1;
        }
        const q = self.day;
        const k = @mod(y, 100);
        const j = @divFloor(y, 100);

        const h_calc = @as(i32, q) + @divFloor((13 * (@as(i32, m) + 1)), 5) +
            @as(i32, @intCast(k)) + @divFloor(@as(i32, @intCast(k)), 4) +
            @divFloor(j, 4) - 2 * j;
        const h = @mod(h_calc, 7);
        return @intCast(@mod(h + 6, 7));
    }
};

// ============================================================================
// Pattern Formatting (simplified from intl_binding.zig)
// ============================================================================

fn formatWithPattern(
    buf: []u8,
    pattern: []const u8,
    dt: DateTime,
    locale_data: *const cldr.LocaleData,
) []const u8 {
    var out_idx: usize = 0;
    var pat_idx: usize = 0;

    while (pat_idx < pattern.len and out_idx < buf.len - 1) {
        const c = pattern[pat_idx];

        if (c == '\'') {
            pat_idx += 1;
            if (pat_idx < pattern.len and pattern[pat_idx] == '\'') {
                if (out_idx < buf.len) {
                    buf[out_idx] = '\'';
                    out_idx += 1;
                }
                pat_idx += 1;
            } else {
                while (pat_idx < pattern.len and out_idx < buf.len) {
                    if (pattern[pat_idx] == '\'') {
                        pat_idx += 1;
                        break;
                    }
                    buf[out_idx] = pattern[pat_idx];
                    out_idx += 1;
                    pat_idx += 1;
                }
            }
        } else if (isPatternChar(c)) {
            const start = pat_idx;
            while (pat_idx < pattern.len and pattern[pat_idx] == c) : (pat_idx += 1) {}
            const count = pat_idx - start;
            out_idx = formatField(buf, out_idx, c, count, dt, locale_data);
        } else {
            buf[out_idx] = c;
            out_idx += 1;
            pat_idx += 1;
        }
    }

    return buf[0..out_idx];
}

fn isPatternChar(c: u8) bool {
    return switch (c) {
        'y', 'Y', 'M', 'L', 'd', 'E', 'e', 'c', 'a', 'h', 'H', 'k', 'K', 'm', 's', 'S', 'z', 'Z', 'G' => true,
        else => false,
    };
}

fn formatField(
    buf: []u8,
    start_idx: usize,
    field: u8,
    count: usize,
    dt: DateTime,
    locale_data: *const cldr.LocaleData,
) usize {
    var idx = start_idx;

    switch (field) {
        'y', 'Y' => {
            const abs_year: u32 = @intCast(if (dt.year < 0) -dt.year else dt.year);
            if (count == 2) {
                const yy = @mod(abs_year, 100);
                idx = writeNumber(buf, idx, yy, 2);
            } else {
                idx = writeNumber(buf, idx, abs_year, 4);
            }
        },
        'M', 'L' => {
            if (count == 1) {
                idx = writeNumber(buf, idx, dt.month, 1);
            } else if (count == 2) {
                idx = writeNumber(buf, idx, dt.month, 2);
            } else if (count == 3) {
                if (dt.month >= 1 and dt.month <= 12) {
                    idx = writeString(buf, idx, locale_data.months.abbreviated[dt.month - 1]);
                }
            } else if (count == 4) {
                if (dt.month >= 1 and dt.month <= 12) {
                    idx = writeString(buf, idx, locale_data.months.wide[dt.month - 1]);
                }
            } else {
                if (dt.month >= 1 and dt.month <= 12) {
                    idx = writeString(buf, idx, locale_data.months.narrow[dt.month - 1]);
                }
            }
        },
        'd' => {
            if (count >= 2) {
                idx = writeNumber(buf, idx, dt.day, 2);
            } else {
                idx = writeNumber(buf, idx, dt.day, 1);
            }
        },
        'E', 'e', 'c' => {
            const dow = dt.dayOfWeek();
            if (count <= 3) {
                idx = writeString(buf, idx, locale_data.weekdays.abbreviated[dow]);
            } else if (count == 4) {
                idx = writeString(buf, idx, locale_data.weekdays.wide[dow]);
            } else if (count == 5) {
                idx = writeString(buf, idx, locale_data.weekdays.narrow[dow]);
            } else {
                idx = writeString(buf, idx, locale_data.weekdays.short[dow]);
            }
        },
        'a' => {
            if (dt.hour < 12) {
                idx = writeString(buf, idx, locale_data.day_periods.am);
            } else {
                idx = writeString(buf, idx, locale_data.day_periods.pm);
            }
        },
        'h' => {
            var h = dt.hour;
            if (h == 0) h = 12 else if (h > 12) h -= 12;
            if (count >= 2) {
                idx = writeNumber(buf, idx, h, 2);
            } else {
                idx = writeNumber(buf, idx, h, 1);
            }
        },
        'H' => {
            if (count >= 2) {
                idx = writeNumber(buf, idx, dt.hour, 2);
            } else {
                idx = writeNumber(buf, idx, dt.hour, 1);
            }
        },
        'm' => {
            if (count >= 2) {
                idx = writeNumber(buf, idx, dt.minute, 2);
            } else {
                idx = writeNumber(buf, idx, dt.minute, 1);
            }
        },
        's' => {
            if (count >= 2) {
                idx = writeNumber(buf, idx, dt.second, 2);
            } else {
                idx = writeNumber(buf, idx, dt.second, 1);
            }
        },
        'z', 'Z' => {
            idx = writeString(buf, idx, "UTC");
        },
        'G' => {
            const era_idx: usize = if (dt.year < 1) 0 else 1;
            if (count <= 3) {
                idx = writeString(buf, idx, locale_data.eras.abbreviated[era_idx]);
            } else if (count == 4) {
                idx = writeString(buf, idx, locale_data.eras.wide[era_idx]);
            } else {
                idx = writeString(buf, idx, locale_data.eras.narrow[era_idx]);
            }
        },
        else => {},
    }

    return idx;
}

fn writeNumber(buf: []u8, start: usize, value: anytype, comptime min_digits: usize) usize {
    var temp: [16]u8 = undefined;
    const slice = switch (min_digits) {
        1 => std.fmt.bufPrint(&temp, "{d}", .{value}) catch return start,
        2 => std.fmt.bufPrint(&temp, "{d:0>2}", .{value}) catch return start,
        3 => std.fmt.bufPrint(&temp, "{d:0>3}", .{value}) catch return start,
        4 => std.fmt.bufPrint(&temp, "{d:0>4}", .{value}) catch return start,
        else => std.fmt.bufPrint(&temp, "{d}", .{value}) catch return start,
    };
    return writeString(buf, start, slice);
}

fn writeString(buf: []u8, start: usize, s: []const u8) usize {
    var idx = start;
    for (s) |c| {
        if (idx >= buf.len) break;
        buf[idx] = c;
        idx += 1;
    }
    return idx;
}

// ============================================================================
// Number Formatting (simplified from intl_binding.zig)
// ============================================================================

fn formatDecimalNumber(
    buf: []u8,
    value: f64,
    min_frac: u8,
    max_frac: u8,
    use_grouping: bool,
    decimal_sep: []const u8,
    group_sep: []const u8,
) []const u8 {
    var idx: usize = 0;

    const int_part: u64 = @intFromFloat(@floor(value));
    var frac_part = value - @floor(value);

    var int_buf: [32]u8 = undefined;
    const int_str = std.fmt.bufPrint(&int_buf, "{d}", .{int_part}) catch "0";

    if (use_grouping and int_str.len > 3) {
        var pos: usize = 0;
        const first_group = int_str.len % 3;
        if (first_group > 0) {
            for (int_str[0..first_group]) |c| {
                if (idx >= buf.len) break;
                buf[idx] = c;
                idx += 1;
            }
            pos = first_group;
            if (pos < int_str.len) {
                for (group_sep) |c| {
                    if (idx >= buf.len) break;
                    buf[idx] = c;
                    idx += 1;
                }
            }
        }
        while (pos < int_str.len) {
            for (int_str[pos .. pos + 3]) |c| {
                if (idx >= buf.len) break;
                buf[idx] = c;
                idx += 1;
            }
            pos += 3;
            if (pos < int_str.len) {
                for (group_sep) |c| {
                    if (idx >= buf.len) break;
                    buf[idx] = c;
                    idx += 1;
                }
            }
        }
    } else {
        for (int_str) |c| {
            if (idx >= buf.len) break;
            buf[idx] = c;
            idx += 1;
        }
    }

    if (max_frac > 0 or min_frac > 0) {
        var multiplier: f64 = 1;
        for (0..max_frac) |_| multiplier *= 10;
        frac_part = @round(frac_part * multiplier) / multiplier;

        if (frac_part > 0 or min_frac > 0) {
            for (decimal_sep) |c| {
                if (idx >= buf.len) break;
                buf[idx] = c;
                idx += 1;
            }

            var frac_digits: u8 = 0;
            var remaining = frac_part;
            while (frac_digits < max_frac and (remaining > 0.000001 or frac_digits < min_frac)) {
                remaining *= 10;
                const digit: u8 = @intFromFloat(@floor(remaining));
                remaining -= @floor(remaining);
                if (idx >= buf.len) break;
                buf[idx] = '0' + digit;
                idx += 1;
                frac_digits += 1;
            }
        }
    }

    return buf[0..idx];
}

// ============================================================================
// Collation (simplified)
// ============================================================================

fn collatorCompare(a: []const u8, b: []const u8) i32 {
    const min_len = @min(a.len, b.len);
    for (a[0..min_len], b[0..min_len]) |ac, bc| {
        const ac_lower = if (ac >= 'A' and ac <= 'Z') ac + 32 else ac;
        const bc_lower = if (bc >= 'A' and bc <= 'Z') bc + 32 else bc;
        if (ac_lower < bc_lower) return -1;
        if (ac_lower > bc_lower) return 1;
    }
    if (a.len < b.len) return -1;
    if (a.len > b.len) return 1;
    return 0;
}

// ============================================================================
// Benchmark Results
// ============================================================================

const BenchmarkResult = struct {
    name: []const u8,
    iterations: usize,
    total_ns: u64,
    min_ns: u64,
    max_ns: u64,

    fn ns_per_op(self: BenchmarkResult) u64 {
        return self.total_ns / self.iterations;
    }

    fn ops_per_sec(self: BenchmarkResult) u64 {
        if (self.total_ns == 0) return 0;
        return (self.iterations * std.time.ns_per_s) / self.total_ns;
    }

    fn print(self: BenchmarkResult) void {
        const stdout = std.fs.File.stdout();
        var buffer: [4096]u8 = undefined;
        const ops = self.ops_per_sec();
        const ns = self.ns_per_op();

        const output = std.fmt.bufPrint(&buffer, "{s: <40} {d: >12} ops/s  {d: >8} ns/op  (min: {d}, max: {d})\n", .{
            self.name,
            ops,
            ns,
            self.min_ns,
            self.max_ns,
        }) catch return;
        stdout.writeAll(output) catch {};
    }
};

// ============================================================================
// Benchmarks
// ============================================================================

fn benchmarkDateTimeFormat() BenchmarkResult {
    const timestamp: i64 = 1699964445000; // 2023-11-14 12:30:45 UTC
    var buf: [256]u8 = undefined;

    // Get locale data
    const locale_data = cldr_embedded.getLocale("en") orelse unreachable;
    const pattern = locale_data.datetime_patterns.date_medium; // "MMM d, y"

    // Warmup
    for (0..WARMUP_ITERATIONS) |_| {
        const dt = DateTime.fromTimestampMillis(timestamp);
        _ = formatWithPattern(&buf, pattern, dt, locale_data);
    }

    // Benchmark runs
    var total_ns: u64 = 0;
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    for (0..NUM_RUNS) |_| {
        var timer = std.time.Timer.start() catch unreachable;

        for (0..BENCH_ITERATIONS) |_| {
            const dt = DateTime.fromTimestampMillis(timestamp);
            _ = formatWithPattern(&buf, pattern, dt, locale_data);
        }

        const elapsed = timer.read();
        total_ns += elapsed;
        const ns_per_iter = elapsed / BENCH_ITERATIONS;
        if (ns_per_iter < min_ns) min_ns = ns_per_iter;
        if (ns_per_iter > max_ns) max_ns = ns_per_iter;
    }

    return BenchmarkResult{
        .name = "DateTimeFormat.format(date_medium)",
        .iterations = BENCH_ITERATIONS * NUM_RUNS,
        .total_ns = total_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
    };
}

fn benchmarkDateTimeFormatFull() BenchmarkResult {
    const timestamp: i64 = 1699964445000;
    var buf: [256]u8 = undefined;

    const locale_data = cldr_embedded.getLocale("en") orelse unreachable;
    const pattern = locale_data.datetime_patterns.date_full; // "EEEE, MMMM d, y"

    // Warmup
    for (0..WARMUP_ITERATIONS) |_| {
        const dt = DateTime.fromTimestampMillis(timestamp);
        _ = formatWithPattern(&buf, pattern, dt, locale_data);
    }

    var total_ns: u64 = 0;
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    for (0..NUM_RUNS) |_| {
        var timer = std.time.Timer.start() catch unreachable;

        for (0..BENCH_ITERATIONS) |_| {
            const dt = DateTime.fromTimestampMillis(timestamp);
            _ = formatWithPattern(&buf, pattern, dt, locale_data);
        }

        const elapsed = timer.read();
        total_ns += elapsed;
        const ns_per_iter = elapsed / BENCH_ITERATIONS;
        if (ns_per_iter < min_ns) min_ns = ns_per_iter;
        if (ns_per_iter > max_ns) max_ns = ns_per_iter;
    }

    return BenchmarkResult{
        .name = "DateTimeFormat.format(date_full)",
        .iterations = BENCH_ITERATIONS * NUM_RUNS,
        .total_ns = total_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
    };
}

fn benchmarkDateTimeFormatWithTime() BenchmarkResult {
    const timestamp: i64 = 1699964445000;
    var buf: [256]u8 = undefined;

    const locale_data = cldr_embedded.getLocale("en") orelse unreachable;
    // Simulate combined date+time pattern
    const date_pattern = locale_data.datetime_patterns.date_medium;
    const time_pattern = locale_data.datetime_patterns.time_short;

    // Warmup
    for (0..WARMUP_ITERATIONS) |_| {
        const dt = DateTime.fromTimestampMillis(timestamp);
        _ = formatWithPattern(&buf, date_pattern, dt, locale_data);
        _ = formatWithPattern(&buf, time_pattern, dt, locale_data);
    }

    var total_ns: u64 = 0;
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    for (0..NUM_RUNS) |_| {
        var timer = std.time.Timer.start() catch unreachable;

        for (0..BENCH_ITERATIONS) |_| {
            const dt = DateTime.fromTimestampMillis(timestamp);
            const date_str = formatWithPattern(&buf, date_pattern, dt, locale_data);
            var time_buf: [64]u8 = undefined;
            const time_str = formatWithPattern(&time_buf, time_pattern, dt, locale_data);
            // Simulate combining (just access both results)
            _ = date_str.len + time_str.len;
        }

        const elapsed = timer.read();
        total_ns += elapsed;
        const ns_per_iter = elapsed / BENCH_ITERATIONS;
        if (ns_per_iter < min_ns) min_ns = ns_per_iter;
        if (ns_per_iter > max_ns) max_ns = ns_per_iter;
    }

    return BenchmarkResult{
        .name = "DateTimeFormat.format(date+time)",
        .iterations = BENCH_ITERATIONS * NUM_RUNS,
        .total_ns = total_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
    };
}

fn benchmarkDateTimeLocales() BenchmarkResult {
    const timestamp: i64 = 1699964445000;
    var buf: [256]u8 = undefined;

    // Test multiple locales
    const locales = [_][]const u8{ "en", "de", "fr", "ja", "ar", "zh" };

    // Warmup
    for (0..WARMUP_ITERATIONS / 10) |_| {
        for (locales) |locale_tag| {
            const locale_data = cldr_embedded.getLocale(locale_tag) orelse continue;
            const pattern = locale_data.datetime_patterns.date_medium;
            const dt = DateTime.fromTimestampMillis(timestamp);
            _ = formatWithPattern(&buf, pattern, dt, locale_data);
        }
    }

    var total_ns: u64 = 0;
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    for (0..NUM_RUNS) |_| {
        var timer = std.time.Timer.start() catch unreachable;

        for (0..BENCH_ITERATIONS) |_| {
            for (locales) |locale_tag| {
                const locale_data = cldr_embedded.getLocale(locale_tag) orelse continue;
                const pattern = locale_data.datetime_patterns.date_medium;
                const dt = DateTime.fromTimestampMillis(timestamp);
                _ = formatWithPattern(&buf, pattern, dt, locale_data);
            }
        }

        const elapsed = timer.read();
        total_ns += elapsed;
        const iterations_per_run = BENCH_ITERATIONS * locales.len;
        const ns_per_iter = elapsed / iterations_per_run;
        if (ns_per_iter < min_ns) min_ns = ns_per_iter;
        if (ns_per_iter > max_ns) max_ns = ns_per_iter;
    }

    return BenchmarkResult{
        .name = "DateTimeFormat.format(multi-locale)",
        .iterations = BENCH_ITERATIONS * NUM_RUNS * locales.len,
        .total_ns = total_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
    };
}

fn benchmarkNumberFormat() BenchmarkResult {
    var buf: [128]u8 = undefined;

    const locale_data = cldr_embedded.getLocale("en") orelse unreachable;
    const symbols = locale_data.number_symbols;
    const value: f64 = 1234567.89;

    // Warmup
    for (0..WARMUP_ITERATIONS) |_| {
        _ = formatDecimalNumber(&buf, value, 0, 2, true, symbols.decimal, symbols.group);
    }

    var total_ns: u64 = 0;
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    for (0..NUM_RUNS) |_| {
        var timer = std.time.Timer.start() catch unreachable;

        for (0..BENCH_ITERATIONS) |_| {
            _ = formatDecimalNumber(&buf, value, 0, 2, true, symbols.decimal, symbols.group);
        }

        const elapsed = timer.read();
        total_ns += elapsed;
        const ns_per_iter = elapsed / BENCH_ITERATIONS;
        if (ns_per_iter < min_ns) min_ns = ns_per_iter;
        if (ns_per_iter > max_ns) max_ns = ns_per_iter;
    }

    return BenchmarkResult{
        .name = "NumberFormat.format(decimal)",
        .iterations = BENCH_ITERATIONS * NUM_RUNS,
        .total_ns = total_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
    };
}

fn benchmarkNumberFormatCurrency() BenchmarkResult {
    var buf: [128]u8 = undefined;

    const locale_data = cldr_embedded.getLocale("en") orelse unreachable;
    const symbols = locale_data.number_symbols;
    const value: f64 = 1234.56;

    // Warmup
    for (0..WARMUP_ITERATIONS) |_| {
        var idx: usize = 0;
        buf[idx] = '$';
        idx += 1;
        _ = formatDecimalNumber(buf[idx..], value, 2, 2, true, symbols.decimal, symbols.group);
    }

    var total_ns: u64 = 0;
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    for (0..NUM_RUNS) |_| {
        var timer = std.time.Timer.start() catch unreachable;

        for (0..BENCH_ITERATIONS) |_| {
            var idx: usize = 0;
            buf[idx] = '$';
            idx += 1;
            _ = formatDecimalNumber(buf[idx..], value, 2, 2, true, symbols.decimal, symbols.group);
        }

        const elapsed = timer.read();
        total_ns += elapsed;
        const ns_per_iter = elapsed / BENCH_ITERATIONS;
        if (ns_per_iter < min_ns) min_ns = ns_per_iter;
        if (ns_per_iter > max_ns) max_ns = ns_per_iter;
    }

    return BenchmarkResult{
        .name = "NumberFormat.format(currency)",
        .iterations = BENCH_ITERATIONS * NUM_RUNS,
        .total_ns = total_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
    };
}

fn benchmarkCollatorCompare() BenchmarkResult {
    const strings = [_][]const u8{
        "apple",
        "Apple",
        "banana",
        "BANANA",
        "cherry",
        "Cherry",
        "date",
        "DATE",
    };

    // Warmup
    for (0..WARMUP_ITERATIONS) |_| {
        for (strings) |a| {
            for (strings) |b| {
                _ = collatorCompare(a, b);
            }
        }
    }

    var total_ns: u64 = 0;
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    for (0..NUM_RUNS) |_| {
        var timer = std.time.Timer.start() catch unreachable;

        for (0..BENCH_ITERATIONS) |_| {
            for (strings) |a| {
                for (strings) |b| {
                    _ = collatorCompare(a, b);
                }
            }
        }

        const elapsed = timer.read();
        total_ns += elapsed;
        const iterations_per_run = BENCH_ITERATIONS * strings.len * strings.len;
        const ns_per_iter = elapsed / iterations_per_run;
        if (ns_per_iter < min_ns) min_ns = ns_per_iter;
        if (ns_per_iter > max_ns) max_ns = ns_per_iter;
    }

    return BenchmarkResult{
        .name = "Collator.compare()",
        .iterations = BENCH_ITERATIONS * NUM_RUNS * strings.len * strings.len,
        .total_ns = total_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
    };
}

fn benchmarkLocaleResolution() BenchmarkResult {
    const locales = [_][]const u8{
        "en",
        "en-US",
        "en-GB",
        "de",
        "de-AT",
        "fr",
        "ja",
        "zh",
        "zh-Hans",
        "ar",
    };

    // Warmup
    for (0..WARMUP_ITERATIONS) |_| {
        for (locales) |tag| {
            _ = cldr_embedded.getLocale(tag);
        }
    }

    var total_ns: u64 = 0;
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    for (0..NUM_RUNS) |_| {
        var timer = std.time.Timer.start() catch unreachable;

        for (0..BENCH_ITERATIONS) |_| {
            for (locales) |tag| {
                _ = cldr_embedded.getLocale(tag);
            }
        }

        const elapsed = timer.read();
        total_ns += elapsed;
        const iterations_per_run = BENCH_ITERATIONS * locales.len;
        const ns_per_iter = elapsed / iterations_per_run;
        if (ns_per_iter < min_ns) min_ns = ns_per_iter;
        if (ns_per_iter > max_ns) max_ns = ns_per_iter;
    }

    return BenchmarkResult{
        .name = "Locale resolution (lookup)",
        .iterations = BENCH_ITERATIONS * NUM_RUNS * locales.len,
        .total_ns = total_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
    };
}

fn benchmarkTimestampConversion() BenchmarkResult {
    const timestamps = [_]i64{
        0, // 1970-01-01
        1699964445000, // 2023-11-14
        -86400000, // 1969-12-31
        2524608000000, // 2050-01-01
        946684800000, // 2000-01-01
    };

    // Warmup
    for (0..WARMUP_ITERATIONS) |_| {
        for (timestamps) |ts| {
            _ = DateTime.fromTimestampMillis(ts);
        }
    }

    var total_ns: u64 = 0;
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    for (0..NUM_RUNS) |_| {
        var timer = std.time.Timer.start() catch unreachable;

        for (0..BENCH_ITERATIONS) |_| {
            for (timestamps) |ts| {
                _ = DateTime.fromTimestampMillis(ts);
            }
        }

        const elapsed = timer.read();
        total_ns += elapsed;
        const iterations_per_run = BENCH_ITERATIONS * timestamps.len;
        const ns_per_iter = elapsed / iterations_per_run;
        if (ns_per_iter < min_ns) min_ns = ns_per_iter;
        if (ns_per_iter > max_ns) max_ns = ns_per_iter;
    }

    return BenchmarkResult{
        .name = "DateTime.fromTimestampMillis()",
        .iterations = BENCH_ITERATIONS * NUM_RUNS * timestamps.len,
        .total_ns = total_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
    };
}

// ============================================================================
// Memory Benchmarks
// ============================================================================

fn benchmarkMemoryUsage() void {
    const stdout = std.fs.File.stdout();

    // Calculate embedded data size
    var total_size: usize = 0;

    // For each locale, calculate approximate data size
    for (cldr_embedded.locale_tags) |tag| {
        const locale = cldr_embedded.getLocale(tag) orelse continue;

        // Tag
        total_size += tag.len;

        // Month names (12 * 3 forms)
        for (locale.months.wide) |m| total_size += m.len;
        for (locale.months.abbreviated) |m| total_size += m.len;
        for (locale.months.narrow) |m| total_size += m.len;

        // Weekday names (7 * 4 forms)
        for (locale.weekdays.wide) |w| total_size += w.len;
        for (locale.weekdays.abbreviated) |w| total_size += w.len;
        for (locale.weekdays.narrow) |w| total_size += w.len;
        for (locale.weekdays.short) |w| total_size += w.len;

        // Day periods
        total_size += locale.day_periods.am.len + locale.day_periods.pm.len;

        // Eras (2 * 3 forms)
        for (locale.eras.wide) |e| total_size += e.len;
        for (locale.eras.abbreviated) |e| total_size += e.len;
        for (locale.eras.narrow) |e| total_size += e.len;

        // Patterns (12)
        total_size += locale.datetime_patterns.date_full.len;
        total_size += locale.datetime_patterns.date_long.len;
        total_size += locale.datetime_patterns.date_medium.len;
        total_size += locale.datetime_patterns.date_short.len;
        total_size += locale.datetime_patterns.time_full.len;
        total_size += locale.datetime_patterns.time_long.len;
        total_size += locale.datetime_patterns.time_medium.len;
        total_size += locale.datetime_patterns.time_short.len;
        total_size += locale.datetime_patterns.datetime_full.len;
        total_size += locale.datetime_patterns.datetime_long.len;
        total_size += locale.datetime_patterns.datetime_medium.len;
        total_size += locale.datetime_patterns.datetime_short.len;

        // Number symbols (8)
        total_size += locale.number_symbols.decimal.len;
        total_size += locale.number_symbols.group.len;
        total_size += locale.number_symbols.percent.len;
        total_size += locale.number_symbols.minus.len;
        total_size += locale.number_symbols.plus.len;
        total_size += locale.number_symbols.exponential.len;
        total_size += locale.number_symbols.infinity.len;
        total_size += locale.number_symbols.nan.len;
    }

    var buffer: [256]u8 = undefined;
    const output = std.fmt.bufPrint(&buffer, "\nMemory Statistics:\n  Embedded CLDR data size: {d} KB ({d} locales)\n  Per-locale average: {d} bytes\n", .{
        total_size / 1024,
        cldr_embedded.locale_tags.len,
        total_size / cldr_embedded.locale_tags.len,
    }) catch return;
    stdout.writeAll(output) catch {};
}

// ============================================================================
// Main
// ============================================================================

pub fn main() !void {
    const stdout = std.fs.File.stdout();

    // Header
    try stdout.writeAll("\n");
    try stdout.writeAll("================================================================================\n");
    try stdout.writeAll("                    Pure Zig Intl Performance Benchmarks\n");
    try stdout.writeAll("================================================================================\n");
    try stdout.writeAll("\n");

    var config_buf: [256]u8 = undefined;
    const config = std.fmt.bufPrint(&config_buf, "Configuration: {d} warmup, {d} iterations, {d} runs\n\n", .{
        WARMUP_ITERATIONS,
        BENCH_ITERATIONS,
        NUM_RUNS,
    }) catch "Configuration error\n";
    try stdout.writeAll(config);

    // DateTimeFormat benchmarks
    try stdout.writeAll("--- DateTimeFormat Benchmarks ---\n\n");
    benchmarkDateTimeFormat().print();
    benchmarkDateTimeFormatFull().print();
    benchmarkDateTimeFormatWithTime().print();
    benchmarkDateTimeLocales().print();

    try stdout.writeAll("\n");

    // NumberFormat benchmarks
    try stdout.writeAll("--- NumberFormat Benchmarks ---\n\n");
    benchmarkNumberFormat().print();
    benchmarkNumberFormatCurrency().print();

    try stdout.writeAll("\n");

    // Collator benchmarks
    try stdout.writeAll("--- Collator Benchmarks ---\n\n");
    benchmarkCollatorCompare().print();

    try stdout.writeAll("\n");

    // Infrastructure benchmarks
    try stdout.writeAll("--- Infrastructure Benchmarks ---\n\n");
    benchmarkLocaleResolution().print();
    benchmarkTimestampConversion().print();

    // Memory statistics
    benchmarkMemoryUsage();

    try stdout.writeAll("\n");
    try stdout.writeAll("================================================================================\n");
    try stdout.writeAll("                            Benchmark Complete\n");
    try stdout.writeAll("================================================================================\n");
    try stdout.writeAll("\n");
}
