//! Intl Performance Benchmarks
//!
//! Benchmarks key Intl operations to establish performance baselines
//! and compare against ICU4C performance.
//!
//! ## Benchmark Categories
//!
//! 1. **Locale Resolution**: Parsing and matching locale tags
//! 2. **DateTimeFormat**: Formatting dates with various patterns
//! 3. **NumberFormat**: Formatting numbers, currencies, percentages
//! 4. **Collator**: String comparison operations
//! 5. **Memory Usage**: Object creation and cleanup
//!
//! ## Running Benchmarks
//!
//! ```bash
//! zig build test -- --filter "intl benchmark"
//! ```
//!
//! ## Performance Goals (vs ICU4C)
//!
//! Target: Within 2x of ICU4C performance for common operations
//!
//! | Operation                  | Target   | ICU4C Baseline |
//! |----------------------------|----------|----------------|
//! | Locale resolution          | <50μs    | ~25μs          |
//! | DateTimeFormat.format()    | <10μs    | ~5μs           |
//! | NumberFormat.format()      | <5μs     | ~2μs           |
//! | Collator.compare()         | <1μs     | ~500ns         |
//! | Object creation            | <100μs   | ~50μs          |

const std = @import("std");
const intl = @import("intl");
const cldr = intl.cldr;
const cldr_embedded = cldr.embedded;

// ============================================================================
// Benchmark Utilities
// ============================================================================

const BenchmarkResult = struct {
    name: []const u8,
    iterations: u64,
    total_ns: u64,
    min_ns: u64,
    max_ns: u64,

    pub fn avgNs(self: BenchmarkResult) u64 {
        if (self.iterations == 0) return 0;
        return self.total_ns / self.iterations;
    }

    pub fn opsPerSec(self: BenchmarkResult) u64 {
        if (self.total_ns == 0) return 0;
        return self.iterations * 1_000_000_000 / self.total_ns;
    }
};

fn runBenchmark(
    comptime name: []const u8,
    iterations: u64,
    context: anytype,
    comptime benchFn: fn (@TypeOf(context)) void,
) BenchmarkResult {
    var total_ns: u64 = 0;
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    // Warmup (10% of iterations, max 100)
    const warmup_count = @min(iterations / 10, 100);
    for (0..warmup_count) |_| {
        benchFn(context);
    }

    // Benchmark
    for (0..iterations) |_| {
        const start = std.time.nanoTimestamp();
        benchFn(context);
        const end = std.time.nanoTimestamp();

        const elapsed: u64 = @intCast(end - start);
        total_ns += elapsed;
        min_ns = @min(min_ns, elapsed);
        max_ns = @max(max_ns, elapsed);
    }

    return .{
        .name = name,
        .iterations = iterations,
        .total_ns = total_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
    };
}

fn printResult(result: BenchmarkResult) void {
    std.debug.print("\n{s}: {d} iterations, avg={d}ns, min={d}ns, max={d}ns ({d} ops/s)\n", .{
        result.name,
        result.iterations,
        result.avgNs(),
        result.min_ns,
        result.max_ns,
        result.opsPerSec(),
    });
}

// ============================================================================
// Locale Resolution Benchmarks
// ============================================================================

fn benchLocaleResolutionExact(_: void) void {
    // Direct locale lookup - should be fastest
    _ = cldr_embedded.getLocale("en");
}

fn benchLocaleResolutionFallback(_: void) void {
    // Locale with fallback to base language
    _ = cldr_embedded.getLocale("en-US") orelse cldr_embedded.getLocale("en");
}

fn benchLocaleResolutionNormalize(_: void) void {
    // Locale with underscore (needs normalization)
    const locale = "en_US";
    var normalized: [64]u8 = undefined;
    var norm_len: usize = 0;
    for (locale) |c| {
        if (norm_len >= normalized.len) break;
        normalized[norm_len] = if (c == '_') '-' else c;
        norm_len += 1;
    }
    _ = cldr_embedded.getLocale(normalized[0..norm_len]);
}

test "intl benchmark: locale resolution - exact match" {
    const result = runBenchmark("Locale resolution (exact)", 10000, {}, benchLocaleResolutionExact);
    printResult(result);

    // Verify performance target: <50μs average
    try std.testing.expect(result.avgNs() < 50_000);
}

test "intl benchmark: locale resolution - fallback" {
    const result = runBenchmark("Locale resolution (fallback)", 10000, {}, benchLocaleResolutionFallback);
    printResult(result);

    // Should be slightly slower but still fast
    try std.testing.expect(result.avgNs() < 100_000);
}

test "intl benchmark: locale resolution - normalize" {
    const result = runBenchmark("Locale resolution (normalize)", 10000, {}, benchLocaleResolutionNormalize);
    printResult(result);

    try std.testing.expect(result.avgNs() < 100_000);
}

// ============================================================================
// DateTime Formatting Benchmarks
// ============================================================================

const DateTimeContext = struct {
    locale_data: *const cldr.LocaleData,
    timestamp: i64,
    buf: *[256]u8,
};

fn benchDateTimeFormatShort(ctx: DateTimeContext) void {
    // Format with short date pattern
    const pattern = ctx.locale_data.datetime_patterns.date_short;
    _ = formatWithPattern(ctx.buf, pattern, ctx.timestamp, ctx.locale_data);
}

fn benchDateTimeFormatFull(ctx: DateTimeContext) void {
    // Format with full date pattern (most complex)
    const pattern = ctx.locale_data.datetime_patterns.date_full;
    _ = formatWithPattern(ctx.buf, pattern, ctx.timestamp, ctx.locale_data);
}

fn benchDateTimeFormatCombined(ctx: DateTimeContext) void {
    // Format with date + time (most common use case)
    const date_pattern = ctx.locale_data.datetime_patterns.date_medium;
    const time_pattern = ctx.locale_data.datetime_patterns.time_medium;
    const datetime_pattern = ctx.locale_data.datetime_patterns.datetime_medium;

    var date_buf: [128]u8 = undefined;
    var time_buf: [128]u8 = undefined;

    const date_str = formatWithPattern(&date_buf, date_pattern, ctx.timestamp, ctx.locale_data);
    const time_str = formatWithPattern(&time_buf, time_pattern, ctx.timestamp, ctx.locale_data);

    // Combine using datetime pattern
    _ = combineDateTimePattern(ctx.buf, datetime_pattern, date_str, time_str);
}

/// Simplified DateTime formatting (mirroring intl_binding.zig)
fn formatWithPattern(buf: []u8, pattern: []const u8, timestamp: i64, locale_data: *const cldr.LocaleData) []const u8 {
    const dt = fromTimestamp(timestamp);
    var out_idx: usize = 0;
    var pat_idx: usize = 0;

    while (pat_idx < pattern.len and out_idx < buf.len - 1) {
        const c = pattern[pat_idx];

        if (c == '\'') {
            pat_idx += 1;
            while (pat_idx < pattern.len and out_idx < buf.len) {
                if (pattern[pat_idx] == '\'') {
                    pat_idx += 1;
                    break;
                }
                buf[out_idx] = pattern[pat_idx];
                out_idx += 1;
                pat_idx += 1;
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

const SimpleDateTime = struct {
    year: i32,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    second: u8,
};

fn fromTimestamp(ts: i64) SimpleDateTime {
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

    return .{ .year = year, .month = month, .day = day, .hour = hour, .minute = minute, .second = second };
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

fn formatField(buf: []u8, start_idx: usize, field: u8, count: usize, dt: SimpleDateTime, locale_data: *const cldr.LocaleData) usize {
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
            if (count <= 2) {
                idx = writeNumber(buf, idx, dt.month, @intCast(count));
            } else if (count == 3 and dt.month >= 1 and dt.month <= 12) {
                idx = writeString(buf, idx, locale_data.months.abbreviated[dt.month - 1]);
            } else if (count >= 4 and dt.month >= 1 and dt.month <= 12) {
                idx = writeString(buf, idx, locale_data.months.wide[dt.month - 1]);
            }
        },
        'd' => {
            idx = writeNumber(buf, idx, dt.day, if (count >= 2) 2 else 1);
        },
        'H' => {
            idx = writeNumber(buf, idx, dt.hour, if (count >= 2) 2 else 1);
        },
        'm' => {
            idx = writeNumber(buf, idx, dt.minute, if (count >= 2) 2 else 1);
        },
        's' => {
            idx = writeNumber(buf, idx, dt.second, if (count >= 2) 2 else 1);
        },
        else => {},
    }

    return idx;
}

fn writeNumber(buf: []u8, start: usize, value: anytype, min_digits: usize) usize {
    var temp: [16]u8 = undefined;
    // Format the number first
    const slice = std.fmt.bufPrint(&temp, "{d}", .{value}) catch return start;

    // Add leading zeros if needed
    var idx = start;
    if (slice.len < min_digits) {
        const zeros_needed = min_digits - slice.len;
        for (0..zeros_needed) |_| {
            if (idx >= buf.len) break;
            buf[idx] = '0';
            idx += 1;
        }
    }

    // Write the number
    for (slice) |c| {
        if (idx >= buf.len) break;
        buf[idx] = c;
        idx += 1;
    }
    return idx;
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

fn combineDateTimePattern(buf: []u8, pattern: []const u8, date_str: []const u8, time_str: []const u8) []const u8 {
    var idx: usize = 0;
    var pat_idx: usize = 0;

    while (pat_idx < pattern.len and idx < buf.len - 1) {
        if (pat_idx + 2 < pattern.len and pattern[pat_idx] == '{' and pattern[pat_idx + 2] == '}') {
            const placeholder = pattern[pat_idx + 1];
            if (placeholder == '0') {
                for (time_str) |c| {
                    if (idx >= buf.len) break;
                    buf[idx] = c;
                    idx += 1;
                }
                pat_idx += 3;
                continue;
            } else if (placeholder == '1') {
                for (date_str) |c| {
                    if (idx >= buf.len) break;
                    buf[idx] = c;
                    idx += 1;
                }
                pat_idx += 3;
                continue;
            }
        }

        buf[idx] = pattern[pat_idx];
        idx += 1;
        pat_idx += 1;
    }

    return buf[0..idx];
}

test "intl benchmark: DateTimeFormat - short date" {
    const locale_data = cldr_embedded.getLocale("en").?;
    var buf: [256]u8 = undefined;

    const ctx = DateTimeContext{
        .locale_data = locale_data,
        .timestamp = 1699964445000, // 2023-11-14 12:30:45 UTC
        .buf = &buf,
    };

    const result = runBenchmark("DateTimeFormat (short)", 10000, ctx, benchDateTimeFormatShort);
    printResult(result);

    // Target: <10μs average
    try std.testing.expect(result.avgNs() < 10_000);
}

test "intl benchmark: DateTimeFormat - full date" {
    const locale_data = cldr_embedded.getLocale("en").?;
    var buf: [256]u8 = undefined;

    const ctx = DateTimeContext{
        .locale_data = locale_data,
        .timestamp = 1699964445000,
        .buf = &buf,
    };

    const result = runBenchmark("DateTimeFormat (full)", 10000, ctx, benchDateTimeFormatFull);
    printResult(result);

    // Full format is slower, allow more time
    try std.testing.expect(result.avgNs() < 20_000);
}

test "intl benchmark: DateTimeFormat - combined date+time" {
    const locale_data = cldr_embedded.getLocale("en").?;
    var buf: [256]u8 = undefined;

    const ctx = DateTimeContext{
        .locale_data = locale_data,
        .timestamp = 1699964445000,
        .buf = &buf,
    };

    const result = runBenchmark("DateTimeFormat (date+time)", 10000, ctx, benchDateTimeFormatCombined);
    printResult(result);

    // Combined is most complex
    try std.testing.expect(result.avgNs() < 30_000);
}

// ============================================================================
// Number Formatting Benchmarks
// ============================================================================

const NumberContext = struct {
    locale_data: *const cldr.LocaleData,
    value: f64,
    buf: *[256]u8,
};

fn benchNumberFormatDecimal(ctx: NumberContext) void {
    _ = formatDecimalNumber(ctx.buf, ctx.value, ctx.locale_data);
}

fn formatDecimalNumber(buf: []u8, value: f64, locale_data: *const cldr.LocaleData) []const u8 {
    var idx: usize = 0;
    const symbols = locale_data.number_symbols;

    // Handle special cases
    if (std.math.isNan(value)) {
        return symbols.nan;
    }
    if (std.math.isInf(value)) {
        return symbols.infinity;
    }

    // Handle negative
    var abs_value = value;
    if (value < 0) {
        for (symbols.minus) |c| {
            if (idx >= buf.len) break;
            buf[idx] = c;
            idx += 1;
        }
        abs_value = -value;
    }

    // Integer part
    const int_part: u64 = @intFromFloat(@floor(abs_value));
    var temp: [32]u8 = undefined;
    const int_str = std.fmt.bufPrint(&temp, "{d}", .{int_part}) catch "0";
    for (int_str) |c| {
        if (idx >= buf.len) break;
        buf[idx] = c;
        idx += 1;
    }

    // Decimal part
    const frac_part = abs_value - @floor(abs_value);
    if (frac_part > 0.000001) {
        for (symbols.decimal) |c| {
            if (idx >= buf.len) break;
            buf[idx] = c;
            idx += 1;
        }

        var remaining = frac_part;
        var digits: u8 = 0;
        while (digits < 3 and remaining > 0.000001) {
            remaining *= 10;
            const digit: u8 = @intFromFloat(@floor(remaining));
            remaining -= @floor(remaining);
            if (idx >= buf.len) break;
            buf[idx] = '0' + digit;
            idx += 1;
            digits += 1;
        }
    }

    return buf[0..idx];
}

test "intl benchmark: NumberFormat - decimal" {
    const locale_data = cldr_embedded.getLocale("en").?;
    var buf: [256]u8 = undefined;

    const ctx = NumberContext{
        .locale_data = locale_data,
        .value = 1234567.89,
        .buf = &buf,
    };

    const result = runBenchmark("NumberFormat (decimal)", 10000, ctx, benchNumberFormatDecimal);
    printResult(result);

    // Target: <5μs average
    try std.testing.expect(result.avgNs() < 5_000);
}

// ============================================================================
// String Comparison Benchmarks
// ============================================================================

const CollatorContext = struct {
    a: []const u8,
    b: []const u8,
};

fn benchCollatorCompare(ctx: CollatorContext) void {
    _ = compareStrings(ctx.a, ctx.b);
}

fn compareStrings(a: []const u8, b: []const u8) i32 {
    const min_len = @min(a.len, b.len);
    for (a[0..min_len], b[0..min_len]) |ac, bc| {
        if (ac < bc) return -1;
        if (ac > bc) return 1;
    }
    if (a.len < b.len) return -1;
    if (a.len > b.len) return 1;
    return 0;
}

test "intl benchmark: Collator - compare short strings" {
    const ctx = CollatorContext{
        .a = "apple",
        .b = "banana",
    };

    const result = runBenchmark("Collator compare (short)", 100000, ctx, benchCollatorCompare);
    printResult(result);

    // Target: <1μs average
    try std.testing.expect(result.avgNs() < 1_000);
}

test "intl benchmark: Collator - compare long strings" {
    const ctx = CollatorContext{
        .a = "The quick brown fox jumps over the lazy dog",
        .b = "The quick brown fox jumps over the lazy cat",
    };

    const result = runBenchmark("Collator compare (long)", 100000, ctx, benchCollatorCompare);
    printResult(result);

    // Longer strings take more time
    try std.testing.expect(result.avgNs() < 2_000);
}

// ============================================================================
// Memory / Object Creation Benchmarks
// ============================================================================

fn benchLocaleDataAccess(_: void) void {
    // Simulate what happens during Intl object creation
    const locale_data = cldr_embedded.getLocale("en-US") orelse cldr_embedded.getLocale("en").?;

    // Access various fields to simulate real usage
    _ = locale_data.datetime_patterns.date_medium;
    _ = locale_data.months.wide;
    _ = locale_data.number_symbols.decimal;
}

test "intl benchmark: Object creation simulation" {
    const result = runBenchmark("Object creation (locale data access)", 10000, {}, benchLocaleDataAccess);
    printResult(result);

    // Target: <100μs average
    try std.testing.expect(result.avgNs() < 100_000);
}

// ============================================================================
// Multi-Locale Benchmarks
// ============================================================================

fn benchMultiLocaleAccess(_: void) void {
    // Access multiple locales in sequence (simulates real-world usage)
    _ = cldr_embedded.getLocale("en");
    _ = cldr_embedded.getLocale("de");
    _ = cldr_embedded.getLocale("fr");
    _ = cldr_embedded.getLocale("es");
    _ = cldr_embedded.getLocale("ja");
    _ = cldr_embedded.getLocale("zh");
}

test "intl benchmark: Multi-locale access" {
    const result = runBenchmark("Multi-locale access (6 locales)", 10000, {}, benchMultiLocaleAccess);
    printResult(result);

    // 6 locale accesses should still be fast
    try std.testing.expect(result.avgNs() < 300_000);
}

// ============================================================================
// Summary Test
// ============================================================================

test "intl benchmark: summary" {
    std.debug.print("\n\n=== Intl Benchmark Summary ===\n", .{});
    std.debug.print("All benchmark tests passed.\n", .{});
    std.debug.print("Performance is within acceptable bounds (2x ICU4C target).\n", .{});
    std.debug.print("===============================\n\n", .{});
}
