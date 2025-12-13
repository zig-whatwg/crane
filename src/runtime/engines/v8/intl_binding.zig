//! V8 Binding for Pure Zig Intl API
//!
//! This module wires the pure Zig internationalization library to V8,
//! creating the `Intl` global object with `DateTimeFormat` and other formatters.
//!
//! ## Design
//!
//! - Creates `Intl` namespace object on global
//! - `Intl.DateTimeFormat` is a constructor function
//! - Uses CLDR data from src/intl/cldr/embedded_data.zig for 30 locales
//! - NO global caches - each instance is independent (prevents ICU OOM bug)
//!
//! ## Supported Locales (Tier 1)
//!
//! en, en-GB, en-AU, en-CA, de, de-AT, de-CH, fr, fr-CA, es, es-MX,
//! it, pt, pt-PT, zh, zh-Hans, zh-Hant, ja, ko, ar, ar-SA, ar-EG,
//! ru, nl, pl, tr, vi, th, id, hi
//!
//! ## Usage
//!
//! ```javascript
//! const dtf = new Intl.DateTimeFormat('en-US', { dateStyle: 'full' });
//! console.log(dtf.format(new Date())); // "Thursday, December 12, 2024"
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");
const conv = @import("conversions.zig");

// Import CLDR data via intl module
const intl = @import("intl");
const cldr = intl.cldr;
const cldr_embedded = cldr.embedded;

// ============================================================================
// DateTime Helper (simplified from src/intl/datetime/datetime.zig)
// ============================================================================

/// Simple DateTime struct for formatting
const DateTime = struct {
    year: i32,
    month: u8, // 1-12
    day: u8, // 1-31
    hour: u8, // 0-23
    minute: u8, // 0-59
    second: u8, // 0-59
    nanosecond: u32 = 0,

    /// Create DateTime from Unix timestamp in milliseconds
    fn fromTimestampMillis(ts: i64) DateTime {
        const ns = @as(i128, ts) * std.time.ns_per_ms;
        var remaining_ns = ns;
        var year: i32 = 1970;

        // Calculate year
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

        // Calculate month
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

    /// Get day of week (0 = Sunday, 6 = Saturday)
    fn dayOfWeek(self: DateTime) u8 {
        // Zeller's congruence (modified for 0-indexed Sunday)
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
        // Convert from Zeller (0=Saturday) to 0=Sunday
        return @intCast(@mod(h + 6, 7));
    }
};

// ============================================================================
// DateTimeFormat Instance Storage
// ============================================================================

/// Style enums matching ECMA-402
const DateStyle = enum { full, long, medium, short };
const TimeStyle = enum { full, long, medium, short };

/// Internal storage for DateTimeFormat instances
const DateTimeFormatRegistry = struct {
    const Entry = struct {
        locale: []const u8,
        locale_data: ?*const cldr.LocaleData,
        date_style: ?DateStyle,
        time_style: ?TimeStyle,
        allocator: std.mem.Allocator,

        fn deinit(self: *Entry) void {
            self.allocator.free(self.locale);
        }
    };

    entries: std.ArrayList(?Entry) = .{},
    free_list: std.ArrayList(usize) = .{},
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex = .{},

    fn init(allocator: std.mem.Allocator) DateTimeFormatRegistry {
        return .{
            .allocator = allocator,
        };
    }

    fn deinit(self: *DateTimeFormatRegistry) void {
        for (self.entries.items) |*entry_opt| {
            if (entry_opt.*) |*entry| {
                entry.deinit();
            }
        }
        self.entries.deinit(self.allocator);
        self.free_list.deinit(self.allocator);
    }

    fn register(self: *DateTimeFormatRegistry, entry: Entry) !usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.free_list.items.len > 0) {
            const idx = self.free_list.pop().?;
            self.entries.items[idx] = entry;
            return idx;
        }

        const idx = self.entries.items.len;
        try self.entries.append(self.allocator, entry);
        return idx;
    }

    fn get(self: *DateTimeFormatRegistry, idx: usize) ?*Entry {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (idx >= self.entries.items.len) return null;
        if (self.entries.items[idx]) |*entry| {
            return entry;
        }
        return null;
    }

    fn remove(self: *DateTimeFormatRegistry, idx: usize) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (idx >= self.entries.items.len) return;
        if (self.entries.items[idx]) |*entry| {
            entry.deinit();
            self.entries.items[idx] = null;
            self.free_list.append(self.allocator, idx) catch {};
        }
    }
};

var dtf_registry: ?DateTimeFormatRegistry = null;

fn getOrInitRegistry() *DateTimeFormatRegistry {
    if (dtf_registry == null) {
        dtf_registry = DateTimeFormatRegistry.init(std.heap.page_allocator);
    }
    return &dtf_registry.?;
}

// ============================================================================
// Locale Resolution
// ============================================================================

/// Find the best matching locale from CLDR data
fn resolveLocale(locale_tag: []const u8) ?*const cldr.LocaleData {
    // Try exact match first
    if (cldr_embedded.getLocale(locale_tag)) |data| {
        return data;
    }

    // Try normalizing (replace _ with -)
    var normalized: [64]u8 = undefined;
    var norm_len: usize = 0;
    for (locale_tag) |c| {
        if (norm_len >= normalized.len) break;
        normalized[norm_len] = if (c == '_') '-' else c;
        norm_len += 1;
    }
    if (cldr_embedded.getLocale(normalized[0..norm_len])) |data| {
        return data;
    }

    // Try base language (e.g., "en-US" -> "en")
    if (std.mem.indexOf(u8, locale_tag, "-")) |idx| {
        if (cldr_embedded.getLocale(locale_tag[0..idx])) |data| {
            return data;
        }
    }

    // Default to English
    return cldr_embedded.getLocale("en");
}

// ============================================================================
// CLDR Pattern Formatting
// ============================================================================

/// Format DateTime using CLDR pattern
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
            // Quoted literal
            pat_idx += 1;
            if (pat_idx < pattern.len and pattern[pat_idx] == '\'') {
                // Escaped quote ''
                if (out_idx < buf.len) {
                    buf[out_idx] = '\'';
                    out_idx += 1;
                }
                pat_idx += 1;
            } else {
                // Find closing quote
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
            // Count consecutive pattern characters
            const start = pat_idx;
            while (pat_idx < pattern.len and pattern[pat_idx] == c) : (pat_idx += 1) {}
            const count = pat_idx - start;

            out_idx = formatField(buf, out_idx, c, count, dt, locale_data);
        } else {
            // Literal character
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
            // Year
            const abs_year: u32 = @intCast(if (dt.year < 0) -dt.year else dt.year);
            if (count == 2) {
                // Two-digit year
                const yy = @mod(abs_year, 100);
                idx = writeNumber(buf, idx, yy, 2);
            } else {
                // Full year
                idx = writeNumber(buf, idx, abs_year, 4);
            }
        },
        'M', 'L' => {
            // Month
            if (count == 1) {
                idx = writeNumber(buf, idx, dt.month, 1);
            } else if (count == 2) {
                idx = writeNumber(buf, idx, dt.month, 2);
            } else if (count == 3) {
                // Abbreviated
                if (dt.month >= 1 and dt.month <= 12) {
                    idx = writeString(buf, idx, locale_data.months.abbreviated[dt.month - 1]);
                }
            } else if (count == 4) {
                // Wide
                if (dt.month >= 1 and dt.month <= 12) {
                    idx = writeString(buf, idx, locale_data.months.wide[dt.month - 1]);
                }
            } else {
                // Narrow
                if (dt.month >= 1 and dt.month <= 12) {
                    idx = writeString(buf, idx, locale_data.months.narrow[dt.month - 1]);
                }
            }
        },
        'd' => {
            // Day
            if (count >= 2) {
                idx = writeNumber(buf, idx, dt.day, 2);
            } else {
                idx = writeNumber(buf, idx, dt.day, 1);
            }
        },
        'E', 'e', 'c' => {
            // Weekday
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
            // AM/PM
            if (dt.hour < 12) {
                idx = writeString(buf, idx, locale_data.day_periods.am);
            } else {
                idx = writeString(buf, idx, locale_data.day_periods.pm);
            }
        },
        'h' => {
            // Hour 1-12
            var h = dt.hour;
            if (h == 0) h = 12 else if (h > 12) h -= 12;
            if (count >= 2) {
                idx = writeNumber(buf, idx, h, 2);
            } else {
                idx = writeNumber(buf, idx, h, 1);
            }
        },
        'H' => {
            // Hour 0-23
            if (count >= 2) {
                idx = writeNumber(buf, idx, dt.hour, 2);
            } else {
                idx = writeNumber(buf, idx, dt.hour, 1);
            }
        },
        'k' => {
            // Hour 1-24
            var h = dt.hour;
            if (h == 0) h = 24;
            if (count >= 2) {
                idx = writeNumber(buf, idx, h, 2);
            } else {
                idx = writeNumber(buf, idx, h, 1);
            }
        },
        'K' => {
            // Hour 0-11
            const h = if (dt.hour >= 12) dt.hour - 12 else dt.hour;
            if (count >= 2) {
                idx = writeNumber(buf, idx, h, 2);
            } else {
                idx = writeNumber(buf, idx, h, 1);
            }
        },
        'm' => {
            // Minute
            if (count >= 2) {
                idx = writeNumber(buf, idx, dt.minute, 2);
            } else {
                idx = writeNumber(buf, idx, dt.minute, 1);
            }
        },
        's' => {
            // Second
            if (count >= 2) {
                idx = writeNumber(buf, idx, dt.second, 2);
            } else {
                idx = writeNumber(buf, idx, dt.second, 1);
            }
        },
        'z', 'Z' => {
            // Time zone (UTC for now)
            idx = writeString(buf, idx, "UTC");
        },
        'G' => {
            // Era
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
// V8 String Helpers
// ============================================================================

fn readV8String(str: ?*v8.String, context: *v8.Context, buf: []u8) ?[]const u8 {
    if (str) |s| {
        const len = v8.v8_String_Utf8Length(s);
        if (len > 0 and len < buf.len) {
            const written = v8.v8_String_WriteUtf8(s, buf.ptr, @intCast(buf.len));
            // V8's WriteUtf8 includes null terminator in count
            if (written > 1) {
                return buf[0..@intCast(written - 1)];
            } else if (written == 1) {
                return "";
            }
        }
    }
    _ = context;
    return null;
}

// ============================================================================
// DateTimeFormat Constructor Callback
// ============================================================================

/// Callback for `new Intl.DateTimeFormat(locales, options)`
fn dateTimeFormatConstructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    // Get locale argument
    var locale_buf: [64]u8 = undefined;
    var locale: []const u8 = "en";

    if (info.length() > 0) {
        const locale_arg = info.get(0);
        if (v8.v8_Value_IsString(locale_arg)) {
            const str = v8.v8_Value_ToString(locale_arg, context);
            if (readV8String(str, context, &locale_buf)) |loc| {
                locale = loc;
            }
        }
    }

    // Parse options
    var date_style: ?DateStyle = null;
    var time_style: ?TimeStyle = null;

    if (info.length() > 1) {
        const options_arg = info.get(1);
        if (v8.v8_Value_IsObject(options_arg)) {
            const options_obj: *v8.Object = @ptrCast(options_arg);

            // dateStyle
            const date_style_key = v8.v8_String_NewFromUtf8(isolate, "dateStyle", 9);
            if (date_style_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v| {
                    if (v8.v8_Value_IsString(v)) {
                        var ds_buf: [16]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v, context), context, &ds_buf)) |ds| {
                            if (std.mem.eql(u8, ds, "full")) date_style = .full else if (std.mem.eql(u8, ds, "long")) date_style = .long else if (std.mem.eql(u8, ds, "medium")) date_style = .medium else if (std.mem.eql(u8, ds, "short")) date_style = .short;
                        }
                    }
                }
            }

            // timeStyle
            const time_style_key = v8.v8_String_NewFromUtf8(isolate, "timeStyle", 9);
            if (time_style_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v| {
                    if (v8.v8_Value_IsString(v)) {
                        var ts_buf: [16]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v, context), context, &ts_buf)) |ts| {
                            if (std.mem.eql(u8, ts, "full")) time_style = .full else if (std.mem.eql(u8, ts, "long")) time_style = .long else if (std.mem.eql(u8, ts, "medium")) time_style = .medium else if (std.mem.eql(u8, ts, "short")) time_style = .short;
                        }
                    }
                }
            }
        }
    }

    // Resolve locale
    const locale_data = resolveLocale(locale);

    // Create entry in registry
    const registry = getOrInitRegistry();
    const allocator = std.heap.page_allocator;

    const locale_copy = allocator.dupe(u8, locale) catch {
        conv.throwTypeError(isolate, "Out of memory");
        return;
    };

    const entry = DateTimeFormatRegistry.Entry{
        .locale = locale_copy,
        .locale_data = locale_data,
        .date_style = date_style,
        .time_style = time_style,
        .allocator = allocator,
    };

    const idx = registry.register(entry) catch {
        allocator.free(locale_copy);
        conv.throwTypeError(isolate, "Failed to register DateTimeFormat");
        return;
    };

    // Create the result object
    const result = v8.v8_Object_New(isolate) orelse {
        registry.remove(idx);
        conv.throwTypeError(isolate, "Failed to create DateTimeFormat object");
        return;
    };

    // Store the registry index (hidden property)
    const idx_key = v8.v8_String_NewFromUtf8(isolate, "__dtf_idx__", 11) orelse {
        registry.remove(idx);
        conv.throwTypeError(isolate, "Failed to create index key");
        return;
    };
    const idx_value = v8.v8_Number_New(isolate, @floatFromInt(idx));
    _ = v8.v8_Object_Set(result, context, @ptrCast(idx_key), @ptrCast(idx_value));

    // Add methods
    addMethod(isolate, context, result, "format", dateTimeFormatFormatCallback, registry, idx) catch {
        registry.remove(idx);
        return;
    };
    addMethod(isolate, context, result, "formatToParts", dateTimeFormatToPartsCallback, registry, idx) catch {
        registry.remove(idx);
        return;
    };
    addMethod(isolate, context, result, "resolvedOptions", dateTimeFormatResolvedOptionsCallback, registry, idx) catch {
        registry.remove(idx);
        return;
    };

    info.setReturnValue(@ptrCast(result));
}

fn addMethod(
    isolate: *v8.Isolate,
    context: *v8.Context,
    obj: *v8.Object,
    name: []const u8,
    callback: *const fn (*const v8.FunctionCallbackInfo) callconv(.c) void,
    registry: *DateTimeFormatRegistry,
    idx: usize,
) !void {
    _ = registry;
    _ = idx;
    const fn_template = v8.v8_FunctionTemplate_New(isolate, callback, @ptrCast(obj)) orelse return error.Failed;
    const fn_obj = v8.v8_FunctionTemplate_GetFunction(fn_template, context) orelse return error.Failed;
    const key = v8.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse return error.Failed;
    _ = v8.v8_Object_Set(obj, context, @ptrCast(key), @ptrCast(fn_obj));
}

/// Get the DateTimeFormat registry index from an object
fn getDateTimeFormatIndex(isolate: *v8.Isolate, context: *v8.Context, obj: *v8.Object) ?usize {
    const idx_key = v8.v8_String_NewFromUtf8(isolate, "__dtf_idx__", 11) orelse return null;
    const idx_value = v8.v8_Object_Get(obj, context, @ptrCast(idx_key)) orelse return null;

    if (!v8.v8_Value_IsNumber(idx_value)) return null;

    const num = v8.v8_Value_NumberValue(idx_value, context);
    if (num < 0) return null;
    return @intFromFloat(num);
}

// ============================================================================
// DateTimeFormat.format() Callback
// ============================================================================

/// Callback for `dtf.format(date)`
fn dateTimeFormatFormatCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    const this_obj = info.getThis();
    const idx = getDateTimeFormatIndex(isolate, context, this_obj) orelse {
        conv.throwTypeError(isolate, "Invalid DateTimeFormat object");
        return;
    };

    const registry = getOrInitRegistry();
    const entry = registry.get(idx) orelse {
        conv.throwTypeError(isolate, "DateTimeFormat not found in registry");
        return;
    };

    // Get timestamp
    var timestamp_ms: i64 = std.time.milliTimestamp();
    if (info.length() > 0) {
        const date_arg = info.get(0);
        if (v8.v8_Value_IsNumber(date_arg)) {
            timestamp_ms = @intFromFloat(v8.v8_Value_NumberValue(date_arg, context));
        }
    }

    // Format using CLDR patterns
    const dt = DateTime.fromTimestampMillis(timestamp_ms);
    var buf: [256]u8 = undefined;

    const locale_data = entry.locale_data orelse cldr_embedded.getLocale("en").?;

    // Format based on options
    const formatted = formatDateTime(&buf, dt, locale_data, entry.date_style, entry.time_style);

    // Create V8 string result
    const result_str = v8.v8_String_NewFromUtf8(isolate, formatted.ptr, @intCast(formatted.len)) orelse {
        conv.throwTypeError(isolate, "Failed to create result string");
        return;
    };

    info.setReturnValue(@ptrCast(result_str));
}

/// Format DateTime with combined date and time styles
fn formatDateTime(
    buf: []u8,
    dt: DateTime,
    locale_data: *const cldr.LocaleData,
    date_style: ?DateStyle,
    time_style: ?TimeStyle,
) []const u8 {
    // Both date and time - need to combine using datetime pattern
    if (date_style != null and time_style != null) {
        // Get the datetime combination pattern (e.g., "{1}, {0}")
        const datetime_pattern = switch (date_style.?) {
            .full => locale_data.datetime_patterns.datetime_full,
            .long => locale_data.datetime_patterns.datetime_long,
            .medium => locale_data.datetime_patterns.datetime_medium,
            .short => locale_data.datetime_patterns.datetime_short,
        };

        // Get individual date and time patterns
        const date_pattern = getDatePattern(locale_data, date_style.?);
        const time_pattern = getTimePattern(locale_data, time_style.?);

        // Format date and time separately
        var date_buf: [128]u8 = undefined;
        var time_buf: [128]u8 = undefined;
        const date_str = formatWithPattern(&date_buf, date_pattern, dt, locale_data);
        const time_str = formatWithPattern(&time_buf, time_pattern, dt, locale_data);

        // Replace {0} with time and {1} with date in the datetime pattern
        return combineDateTimePattern(buf, datetime_pattern, date_str, time_str);
    }

    // Date only
    if (date_style) |ds| {
        const pattern = getDatePattern(locale_data, ds);
        return formatWithPattern(buf, pattern, dt, locale_data);
    }

    // Time only
    if (time_style) |ts| {
        const pattern = getTimePattern(locale_data, ts);
        return formatWithPattern(buf, pattern, dt, locale_data);
    }

    // Default: medium date
    return formatWithPattern(buf, locale_data.datetime_patterns.date_medium, dt, locale_data);
}

fn getDatePattern(locale_data: *const cldr.LocaleData, style: DateStyle) []const u8 {
    return switch (style) {
        .full => locale_data.datetime_patterns.date_full,
        .long => locale_data.datetime_patterns.date_long,
        .medium => locale_data.datetime_patterns.date_medium,
        .short => locale_data.datetime_patterns.date_short,
    };
}

fn getTimePattern(locale_data: *const cldr.LocaleData, style: TimeStyle) []const u8 {
    return switch (style) {
        .full => locale_data.datetime_patterns.time_full,
        .long => locale_data.datetime_patterns.time_long,
        .medium => locale_data.datetime_patterns.time_medium,
        .short => locale_data.datetime_patterns.time_short,
    };
}

/// Combine date and time strings using a datetime pattern like "{1}, {0}"
fn combineDateTimePattern(
    buf: []u8,
    pattern: []const u8,
    date_str: []const u8,
    time_str: []const u8,
) []const u8 {
    var idx: usize = 0;
    var pat_idx: usize = 0;

    while (pat_idx < pattern.len and idx < buf.len - 1) {
        // Check for placeholders
        if (pat_idx + 2 < pattern.len and pattern[pat_idx] == '{' and pattern[pat_idx + 2] == '}') {
            const placeholder = pattern[pat_idx + 1];
            if (placeholder == '0') {
                // {0} = time
                for (time_str) |c| {
                    if (idx >= buf.len) break;
                    buf[idx] = c;
                    idx += 1;
                }
                pat_idx += 3;
                continue;
            } else if (placeholder == '1') {
                // {1} = date
                for (date_str) |c| {
                    if (idx >= buf.len) break;
                    buf[idx] = c;
                    idx += 1;
                }
                pat_idx += 3;
                continue;
            }
        }

        // Regular character
        buf[idx] = pattern[pat_idx];
        idx += 1;
        pat_idx += 1;
    }

    return buf[0..idx];
}

// ============================================================================
// DateTimeFormat.formatToParts() Callback
// ============================================================================

/// Callback for `dtf.formatToParts(date)`
fn dateTimeFormatToPartsCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    const this_obj = info.getThis();
    const idx = getDateTimeFormatIndex(isolate, context, this_obj) orelse {
        conv.throwTypeError(isolate, "Invalid DateTimeFormat object");
        return;
    };

    const registry = getOrInitRegistry();
    const entry = registry.get(idx) orelse {
        conv.throwTypeError(isolate, "DateTimeFormat not found");
        return;
    };

    // Get timestamp
    var timestamp_ms: i64 = std.time.milliTimestamp();
    if (info.length() > 0) {
        const date_arg = info.get(0);
        if (v8.v8_Value_IsNumber(date_arg)) {
            timestamp_ms = @intFromFloat(v8.v8_Value_NumberValue(date_arg, context));
        }
    }

    const dt = DateTime.fromTimestampMillis(timestamp_ms);
    const locale_data = entry.locale_data orelse cldr_embedded.getLocale("en").?;

    // Create parts array
    // For simplicity, we'll create a basic parts array
    const result_array = v8.v8_Array_New(isolate, 11);

    // Format individual components
    var year_buf: [8]u8 = undefined;
    var month_buf: [4]u8 = undefined;
    var day_buf: [4]u8 = undefined;
    var hour_buf: [4]u8 = undefined;
    var minute_buf: [4]u8 = undefined;
    var second_buf: [4]u8 = undefined;

    const year_str = std.fmt.bufPrint(&year_buf, "{d}", .{@as(u32, @intCast(if (dt.year < 0) -dt.year else dt.year))}) catch "0";
    const month_str = std.fmt.bufPrint(&month_buf, "{d:0>2}", .{dt.month}) catch "0";
    const day_str = std.fmt.bufPrint(&day_buf, "{d:0>2}", .{dt.day}) catch "0";
    const hour_str = std.fmt.bufPrint(&hour_buf, "{d:0>2}", .{dt.hour}) catch "0";
    const minute_str = std.fmt.bufPrint(&minute_buf, "{d:0>2}", .{dt.minute}) catch "0";
    const second_str = std.fmt.bufPrint(&second_buf, "{d:0>2}", .{dt.second}) catch "0";

    _ = locale_data;

    var part_idx: u32 = 0;
    addPart(isolate, context, result_array, &part_idx, "year", year_str);
    addPart(isolate, context, result_array, &part_idx, "literal", "-");
    addPart(isolate, context, result_array, &part_idx, "month", month_str);
    addPart(isolate, context, result_array, &part_idx, "literal", "-");
    addPart(isolate, context, result_array, &part_idx, "day", day_str);
    addPart(isolate, context, result_array, &part_idx, "literal", " ");
    addPart(isolate, context, result_array, &part_idx, "hour", hour_str);
    addPart(isolate, context, result_array, &part_idx, "literal", ":");
    addPart(isolate, context, result_array, &part_idx, "minute", minute_str);
    addPart(isolate, context, result_array, &part_idx, "literal", ":");
    addPart(isolate, context, result_array, &part_idx, "second", second_str);

    info.setReturnValue(@ptrCast(result_array));
}

fn addPart(
    isolate: *v8.Isolate,
    context: *v8.Context,
    arr: *v8.Array,
    idx: *u32,
    part_type: []const u8,
    value: []const u8,
) void {
    const part_obj = v8.v8_Object_New(isolate) orelse return;

    const type_key = v8.v8_String_NewFromUtf8(isolate, "type", 4) orelse return;
    const type_val = v8.v8_String_NewFromUtf8(isolate, part_type.ptr, @intCast(part_type.len)) orelse return;
    _ = v8.v8_Object_Set(part_obj, context, @ptrCast(type_key), @ptrCast(type_val));

    const value_key = v8.v8_String_NewFromUtf8(isolate, "value", 5) orelse return;
    const value_val = v8.v8_String_NewFromUtf8(isolate, value.ptr, @intCast(value.len)) orelse return;
    _ = v8.v8_Object_Set(part_obj, context, @ptrCast(value_key), @ptrCast(value_val));

    _ = v8.v8_Array_Set(arr, context, idx.*, @ptrCast(part_obj));
    idx.* += 1;
}

// ============================================================================
// DateTimeFormat.resolvedOptions() Callback
// ============================================================================

/// Callback for `dtf.resolvedOptions()`
fn dateTimeFormatResolvedOptionsCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    const this_obj = info.getThis();
    const idx = getDateTimeFormatIndex(isolate, context, this_obj) orelse {
        conv.throwTypeError(isolate, "Invalid DateTimeFormat object");
        return;
    };

    const registry = getOrInitRegistry();
    const entry = registry.get(idx) orelse {
        conv.throwTypeError(isolate, "DateTimeFormat not found");
        return;
    };

    // Create options object
    const result = v8.v8_Object_New(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to create options object");
        return;
    };

    // Set locale
    setStringProperty(isolate, context, result, "locale", entry.locale);
    setStringProperty(isolate, context, result, "calendar", "gregory");
    setStringProperty(isolate, context, result, "numberingSystem", "latn");
    setStringProperty(isolate, context, result, "timeZone", "UTC");

    // Set dateStyle if present
    if (entry.date_style) |ds| {
        const ds_str = switch (ds) {
            .full => "full",
            .long => "long",
            .medium => "medium",
            .short => "short",
        };
        setStringProperty(isolate, context, result, "dateStyle", ds_str);
    }

    // Set timeStyle if present
    if (entry.time_style) |ts| {
        const ts_str = switch (ts) {
            .full => "full",
            .long => "long",
            .medium => "medium",
            .short => "short",
        };
        setStringProperty(isolate, context, result, "timeStyle", ts_str);
    }

    info.setReturnValue(@ptrCast(result));
}

fn setStringProperty(isolate: *v8.Isolate, context: *v8.Context, obj: *v8.Object, key: []const u8, value: []const u8) void {
    const k = v8.v8_String_NewFromUtf8(isolate, key.ptr, @intCast(key.len)) orelse return;
    const v = v8.v8_String_NewFromUtf8(isolate, value.ptr, @intCast(value.len)) orelse return;
    _ = v8.v8_Object_Set(obj, context, @ptrCast(k), @ptrCast(v));
}

// ============================================================================
// Intl.DateTimeFormat.supportedLocalesOf() Callback
// ============================================================================

/// Callback for `Intl.DateTimeFormat.supportedLocalesOf(locales)`
fn supportedLocalesOfCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    // Return all supported locale tags
    const tags = cldr_embedded.locale_tags;
    const result = v8.v8_Array_New(isolate, @intCast(tags.len));

    for (tags, 0..) |tag, i| {
        const tag_str = v8.v8_String_NewFromUtf8(isolate, tag.ptr, @intCast(tag.len)) orelse continue;
        _ = v8.v8_Array_Set(result, context, @intCast(i), @ptrCast(tag_str));
    }

    info.setReturnValue(@ptrCast(result));
}

// ============================================================================
// NumberFormat Instance Storage
// ============================================================================

/// NumberFormat style enum
const NumberStyle = enum { decimal, currency, percent, unit };

/// NumberFormat notation enum
const NumberNotation = enum { standard, scientific, engineering, compact };

/// Internal storage for NumberFormat instances
const NumberFormatRegistry = struct {
    const Entry = struct {
        locale: []const u8,
        locale_data: ?*const cldr.LocaleData,
        style: NumberStyle,
        notation: NumberNotation,
        currency: ?[]const u8,
        minimum_integer_digits: u8,
        minimum_fraction_digits: u8,
        maximum_fraction_digits: u8,
        use_grouping: bool,
        allocator: std.mem.Allocator,

        fn deinit(self: *Entry) void {
            self.allocator.free(self.locale);
            if (self.currency) |c| self.allocator.free(c);
        }
    };

    entries: std.ArrayList(?Entry) = .{},
    free_list: std.ArrayList(usize) = .{},
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex = .{},

    fn init(allocator: std.mem.Allocator) NumberFormatRegistry {
        return .{
            .allocator = allocator,
        };
    }

    fn deinit(self: *NumberFormatRegistry) void {
        for (self.entries.items) |*entry_opt| {
            if (entry_opt.*) |*entry| {
                entry.deinit();
            }
        }
        self.entries.deinit(self.allocator);
        self.free_list.deinit(self.allocator);
    }

    fn register(self: *NumberFormatRegistry, entry: Entry) !usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.free_list.items.len > 0) {
            const idx = self.free_list.pop().?;
            self.entries.items[idx] = entry;
            return idx;
        }

        const idx = self.entries.items.len;
        try self.entries.append(self.allocator, entry);
        return idx;
    }

    fn get(self: *NumberFormatRegistry, idx: usize) ?*Entry {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (idx >= self.entries.items.len) return null;
        if (self.entries.items[idx]) |*entry| {
            return entry;
        }
        return null;
    }

    fn remove(self: *NumberFormatRegistry, idx: usize) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (idx >= self.entries.items.len) return;
        if (self.entries.items[idx]) |*entry| {
            entry.deinit();
            self.entries.items[idx] = null;
            self.free_list.append(self.allocator, idx) catch {};
        }
    }
};

var nf_registry: ?NumberFormatRegistry = null;

fn getOrInitNumberFormatRegistry() *NumberFormatRegistry {
    if (nf_registry == null) {
        nf_registry = NumberFormatRegistry.init(std.heap.page_allocator);
    }
    return &nf_registry.?;
}

// ============================================================================
// NumberFormat Constructor Callback
// ============================================================================

/// Callback for `new Intl.NumberFormat(locales, options)`
fn numberFormatConstructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    // Get locale argument
    var locale_buf: [64]u8 = undefined;
    var locale: []const u8 = "en";

    if (info.length() > 0) {
        const locale_arg = info.get(0);
        if (v8.v8_Value_IsString(locale_arg)) {
            const str = v8.v8_Value_ToString(locale_arg, context);
            if (readV8String(str, context, &locale_buf)) |loc| {
                locale = loc;
            }
        }
    }

    // Parse options
    var style: NumberStyle = .decimal;
    var notation: NumberNotation = .standard;
    var currency: ?[]const u8 = null;
    const minimum_integer_digits: u8 = 1; // TODO: parse from options
    var minimum_fraction_digits: u8 = 0;
    var maximum_fraction_digits: u8 = 3;
    var use_grouping: bool = true;

    if (info.length() > 1) {
        const options_arg = info.get(1);
        if (v8.v8_Value_IsObject(options_arg)) {
            const options_obj: *v8.Object = @ptrCast(options_arg);

            // style
            const style_key = v8.v8_String_NewFromUtf8(isolate, "style", 5);
            if (style_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v| {
                    if (v8.v8_Value_IsString(v)) {
                        var s_buf: [16]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v, context), context, &s_buf)) |s| {
                            if (std.mem.eql(u8, s, "decimal")) style = .decimal else if (std.mem.eql(u8, s, "currency")) style = .currency else if (std.mem.eql(u8, s, "percent")) style = .percent else if (std.mem.eql(u8, s, "unit")) style = .unit;
                        }
                    }
                }
            }

            // notation
            const notation_key = v8.v8_String_NewFromUtf8(isolate, "notation", 8);
            if (notation_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v| {
                    if (v8.v8_Value_IsString(v)) {
                        var n_buf: [16]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v, context), context, &n_buf)) |n| {
                            if (std.mem.eql(u8, n, "standard")) notation = .standard else if (std.mem.eql(u8, n, "scientific")) notation = .scientific else if (std.mem.eql(u8, n, "engineering")) notation = .engineering else if (std.mem.eql(u8, n, "compact")) notation = .compact;
                        }
                    }
                }
            }

            // currency
            const currency_key = v8.v8_String_NewFromUtf8(isolate, "currency", 8);
            if (currency_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v| {
                    if (v8.v8_Value_IsString(v)) {
                        var c_buf: [8]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v, context), context, &c_buf)) |c| {
                            currency = std.heap.page_allocator.dupe(u8, c) catch null;
                        }
                    }
                }
            }

            // useGrouping
            const grouping_key = v8.v8_String_NewFromUtf8(isolate, "useGrouping", 11);
            if (grouping_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v| {
                    if (v8.v8_Value_IsBoolean(v)) {
                        use_grouping = v8.v8_Value_BooleanValue(v, isolate);
                    }
                }
            }

            // minimumFractionDigits
            const min_frac_key = v8.v8_String_NewFromUtf8(isolate, "minimumFractionDigits", 21);
            if (min_frac_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v| {
                    if (v8.v8_Value_IsNumber(v)) {
                        const num = v8.v8_Value_NumberValue(v, context);
                        if (num >= 0 and num <= 20) {
                            minimum_fraction_digits = @intFromFloat(num);
                        }
                    }
                }
            }

            // maximumFractionDigits
            const max_frac_key = v8.v8_String_NewFromUtf8(isolate, "maximumFractionDigits", 21);
            if (max_frac_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v| {
                    if (v8.v8_Value_IsNumber(v)) {
                        const num = v8.v8_Value_NumberValue(v, context);
                        if (num >= 0 and num <= 20) {
                            maximum_fraction_digits = @intFromFloat(num);
                        }
                    }
                }
            }
        }
    }

    // Set defaults based on style
    if (style == .currency) {
        minimum_fraction_digits = 2;
        maximum_fraction_digits = 2;
    } else if (style == .percent) {
        maximum_fraction_digits = 0;
    }

    // Resolve locale
    const locale_data = resolveLocale(locale);

    // Create entry in registry
    const registry = getOrInitNumberFormatRegistry();
    const allocator = std.heap.page_allocator;

    const locale_copy = allocator.dupe(u8, locale) catch {
        conv.throwTypeError(isolate, "Out of memory");
        return;
    };

    const entry = NumberFormatRegistry.Entry{
        .locale = locale_copy,
        .locale_data = locale_data,
        .style = style,
        .notation = notation,
        .currency = currency,
        .minimum_integer_digits = minimum_integer_digits,
        .minimum_fraction_digits = minimum_fraction_digits,
        .maximum_fraction_digits = maximum_fraction_digits,
        .use_grouping = use_grouping,
        .allocator = allocator,
    };

    const idx = registry.register(entry) catch {
        allocator.free(locale_copy);
        if (currency) |c| allocator.free(c);
        conv.throwTypeError(isolate, "Failed to register NumberFormat");
        return;
    };

    // Create the result object
    const result = v8.v8_Object_New(isolate) orelse {
        registry.remove(idx);
        conv.throwTypeError(isolate, "Failed to create NumberFormat object");
        return;
    };

    // Store the registry index
    const idx_key = v8.v8_String_NewFromUtf8(isolate, "__nf_idx__", 10) orelse {
        registry.remove(idx);
        conv.throwTypeError(isolate, "Failed to create index key");
        return;
    };
    const idx_value = v8.v8_Number_New(isolate, @floatFromInt(idx));
    _ = v8.v8_Object_Set(result, context, @ptrCast(idx_key), @ptrCast(idx_value));

    // Add methods
    addNumberFormatMethod(isolate, context, result, "format", numberFormatFormatCallback) catch {
        registry.remove(idx);
        return;
    };
    addNumberFormatMethod(isolate, context, result, "formatToParts", numberFormatToPartsCallback) catch {
        registry.remove(idx);
        return;
    };
    addNumberFormatMethod(isolate, context, result, "resolvedOptions", numberFormatResolvedOptionsCallback) catch {
        registry.remove(idx);
        return;
    };

    info.setReturnValue(@ptrCast(result));
}

fn addNumberFormatMethod(
    isolate: *v8.Isolate,
    context: *v8.Context,
    obj: *v8.Object,
    name: []const u8,
    callback: *const fn (*const v8.FunctionCallbackInfo) callconv(.c) void,
) !void {
    const fn_template = v8.v8_FunctionTemplate_New(isolate, callback, @ptrCast(obj)) orelse return error.Failed;
    const fn_obj = v8.v8_FunctionTemplate_GetFunction(fn_template, context) orelse return error.Failed;
    const key = v8.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse return error.Failed;
    _ = v8.v8_Object_Set(obj, context, @ptrCast(key), @ptrCast(fn_obj));
}

/// Get the NumberFormat registry index from an object
fn getNumberFormatIndex(isolate: *v8.Isolate, context: *v8.Context, obj: *v8.Object) ?usize {
    const idx_key = v8.v8_String_NewFromUtf8(isolate, "__nf_idx__", 10) orelse return null;
    const idx_value = v8.v8_Object_Get(obj, context, @ptrCast(idx_key)) orelse return null;

    if (!v8.v8_Value_IsNumber(idx_value)) return null;

    const num = v8.v8_Value_NumberValue(idx_value, context);
    if (num < 0) return null;
    return @intFromFloat(num);
}

// ============================================================================
// NumberFormat.format() Callback
// ============================================================================

/// Format a number with locale-specific formatting
fn formatNumber(
    buf: []u8,
    value: f64,
    entry: *const NumberFormatRegistry.Entry,
) []const u8 {
    const locale_data = entry.locale_data orelse cldr_embedded.getLocale("en").?;
    const symbols = locale_data.number_symbols;

    var idx: usize = 0;

    // Handle special cases
    if (std.math.isNan(value)) {
        idx = writeSliceTo(buf, idx, symbols.nan);
        return buf[0..idx];
    }
    if (std.math.isInf(value)) {
        if (value < 0) {
            idx = writeSliceTo(buf, idx, symbols.minus);
        }
        idx = writeSliceTo(buf, idx, symbols.infinity);
        return buf[0..idx];
    }

    // Handle negative numbers
    var abs_value = value;
    if (value < 0) {
        idx = writeSliceTo(buf, idx, symbols.minus);
        abs_value = -value;
    }

    // Handle percent
    if (entry.style == .percent) {
        abs_value *= 100;
    }

    // Add currency symbol (prepend)
    if (entry.style == .currency) {
        if (entry.currency) |curr| {
            const currency_symbol = getCurrencySymbol(curr);
            idx = writeSliceTo(buf, idx, currency_symbol);
        }
    }

    // Format the number
    const formatted = formatDecimalNumber(
        buf[idx..],
        abs_value,
        entry.minimum_fraction_digits,
        entry.maximum_fraction_digits,
        entry.use_grouping,
        symbols.decimal,
        symbols.group,
    );
    idx += formatted.len;

    // Add percent sign
    if (entry.style == .percent) {
        idx = writeSliceTo(buf, idx, symbols.percent);
    }

    return buf[0..idx];
}

fn writeSliceTo(buf: []u8, start: usize, s: []const u8) usize {
    var idx = start;
    for (s) |c| {
        if (idx >= buf.len) break;
        buf[idx] = c;
        idx += 1;
    }
    return idx;
}

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

    // Split into integer and fractional parts
    const int_part: u64 = @intFromFloat(@floor(value));
    var frac_part = value - @floor(value);

    // Format integer part with grouping
    var int_buf: [32]u8 = undefined;
    const int_str = std.fmt.bufPrint(&int_buf, "{d}", .{int_part}) catch "0";

    if (use_grouping and int_str.len > 3) {
        // Insert group separators
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

    // Format fractional part
    if (max_frac > 0 or min_frac > 0) {
        // Round to max_frac digits
        var multiplier: f64 = 1;
        for (0..max_frac) |_| multiplier *= 10;
        frac_part = @round(frac_part * multiplier) / multiplier;

        if (frac_part > 0 or min_frac > 0) {
            for (decimal_sep) |c| {
                if (idx >= buf.len) break;
                buf[idx] = c;
                idx += 1;
            }

            // Output fractional digits
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

fn getCurrencySymbol(currency_code: []const u8) []const u8 {
    // Common currency symbols
    if (std.mem.eql(u8, currency_code, "USD")) return "$";
    if (std.mem.eql(u8, currency_code, "EUR")) return "€";
    if (std.mem.eql(u8, currency_code, "GBP")) return "£";
    if (std.mem.eql(u8, currency_code, "JPY")) return "¥";
    if (std.mem.eql(u8, currency_code, "CNY")) return "¥";
    if (std.mem.eql(u8, currency_code, "KRW")) return "₩";
    if (std.mem.eql(u8, currency_code, "INR")) return "₹";
    if (std.mem.eql(u8, currency_code, "RUB")) return "₽";
    if (std.mem.eql(u8, currency_code, "BRL")) return "R$";
    if (std.mem.eql(u8, currency_code, "CAD")) return "CA$";
    if (std.mem.eql(u8, currency_code, "AUD")) return "A$";
    if (std.mem.eql(u8, currency_code, "CHF")) return "CHF";
    if (std.mem.eql(u8, currency_code, "MXN")) return "MX$";
    // Default to currency code
    return currency_code;
}

/// Callback for `nf.format(number)`
fn numberFormatFormatCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    const this_obj = info.getThis();
    const idx = getNumberFormatIndex(isolate, context, this_obj) orelse {
        conv.throwTypeError(isolate, "Invalid NumberFormat object");
        return;
    };

    const registry = getOrInitNumberFormatRegistry();
    const entry = registry.get(idx) orelse {
        conv.throwTypeError(isolate, "NumberFormat not found in registry");
        return;
    };

    // Get number argument
    var value: f64 = 0;
    if (info.length() > 0) {
        const num_arg = info.get(0);
        if (v8.v8_Value_IsNumber(num_arg)) {
            value = v8.v8_Value_NumberValue(num_arg, context);
        }
    }

    // Format the number
    var buf: [256]u8 = undefined;
    const formatted = formatNumber(&buf, value, entry);

    // Create V8 string result
    const result_str = v8.v8_String_NewFromUtf8(isolate, formatted.ptr, @intCast(formatted.len)) orelse {
        conv.throwTypeError(isolate, "Failed to create result string");
        return;
    };

    info.setReturnValue(@ptrCast(result_str));
}

// ============================================================================
// NumberFormat.formatToParts() Callback
// ============================================================================

/// Callback for `nf.formatToParts(number)`
fn numberFormatToPartsCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    const this_obj = info.getThis();
    const idx = getNumberFormatIndex(isolate, context, this_obj) orelse {
        conv.throwTypeError(isolate, "Invalid NumberFormat object");
        return;
    };

    const registry = getOrInitNumberFormatRegistry();
    const entry = registry.get(idx) orelse {
        conv.throwTypeError(isolate, "NumberFormat not found");
        return;
    };

    // Get number argument
    var value: f64 = 0;
    if (info.length() > 0) {
        const num_arg = info.get(0);
        if (v8.v8_Value_IsNumber(num_arg)) {
            value = v8.v8_Value_NumberValue(num_arg, context);
        }
    }

    const locale_data = entry.locale_data orelse cldr_embedded.getLocale("en").?;
    const symbols = locale_data.number_symbols;

    // Create parts array
    const result_array = v8.v8_Array_New(isolate, 10);
    var part_idx: u32 = 0;

    // Handle negative
    if (value < 0) {
        addPart(isolate, context, result_array, &part_idx, "minusSign", symbols.minus);
        value = -value;
    }

    // Handle percent
    if (entry.style == .percent) {
        value *= 100;
    }

    // Currency symbol
    if (entry.style == .currency) {
        if (entry.currency) |curr| {
            addPart(isolate, context, result_array, &part_idx, "currency", getCurrencySymbol(curr));
        }
    }

    // Integer part
    const int_part: u64 = @intFromFloat(@floor(value));
    var int_buf: [32]u8 = undefined;
    const int_str = std.fmt.bufPrint(&int_buf, "{d}", .{int_part}) catch "0";
    addPart(isolate, context, result_array, &part_idx, "integer", int_str);

    // Decimal and fraction
    const frac_part = value - @floor(value);
    if (entry.maximum_fraction_digits > 0 and (frac_part > 0.000001 or entry.minimum_fraction_digits > 0)) {
        addPart(isolate, context, result_array, &part_idx, "decimal", symbols.decimal);

        var frac_buf: [32]u8 = undefined;
        var frac_idx: usize = 0;
        var remaining = frac_part;
        var digits: u8 = 0;
        while (digits < entry.maximum_fraction_digits and (remaining > 0.000001 or digits < entry.minimum_fraction_digits)) {
            remaining *= 10;
            const digit: u8 = @intFromFloat(@floor(remaining));
            remaining -= @floor(remaining);
            frac_buf[frac_idx] = '0' + digit;
            frac_idx += 1;
            digits += 1;
        }
        addPart(isolate, context, result_array, &part_idx, "fraction", frac_buf[0..frac_idx]);
    }

    // Percent sign
    if (entry.style == .percent) {
        addPart(isolate, context, result_array, &part_idx, "percentSign", symbols.percent);
    }

    info.setReturnValue(@ptrCast(result_array));
}

// ============================================================================
// NumberFormat.resolvedOptions() Callback
// ============================================================================

/// Callback for `nf.resolvedOptions()`
fn numberFormatResolvedOptionsCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    const this_obj = info.getThis();
    const idx = getNumberFormatIndex(isolate, context, this_obj) orelse {
        conv.throwTypeError(isolate, "Invalid NumberFormat object");
        return;
    };

    const registry = getOrInitNumberFormatRegistry();
    const entry = registry.get(idx) orelse {
        conv.throwTypeError(isolate, "NumberFormat not found");
        return;
    };

    // Create options object
    const result = v8.v8_Object_New(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to create options object");
        return;
    };

    // Set properties
    setStringProperty(isolate, context, result, "locale", entry.locale);
    setStringProperty(isolate, context, result, "numberingSystem", "latn");

    const style_str = switch (entry.style) {
        .decimal => "decimal",
        .currency => "currency",
        .percent => "percent",
        .unit => "unit",
    };
    setStringProperty(isolate, context, result, "style", style_str);

    const notation_str = switch (entry.notation) {
        .standard => "standard",
        .scientific => "scientific",
        .engineering => "engineering",
        .compact => "compact",
    };
    setStringProperty(isolate, context, result, "notation", notation_str);

    if (entry.currency) |curr| {
        setStringProperty(isolate, context, result, "currency", curr);
    }

    // Set numeric properties
    setNumberProperty(isolate, context, result, "minimumIntegerDigits", entry.minimum_integer_digits);
    setNumberProperty(isolate, context, result, "minimumFractionDigits", entry.minimum_fraction_digits);
    setNumberProperty(isolate, context, result, "maximumFractionDigits", entry.maximum_fraction_digits);

    // Set useGrouping
    const grouping_key = v8.v8_String_NewFromUtf8(isolate, "useGrouping", 11) orelse return;
    const grouping_val = v8.v8_Boolean_New(isolate, entry.use_grouping);
    _ = v8.v8_Object_Set(result, context, @ptrCast(grouping_key), @ptrCast(grouping_val));

    info.setReturnValue(@ptrCast(result));
}

fn setNumberProperty(isolate: *v8.Isolate, context: *v8.Context, obj: *v8.Object, key: []const u8, value: u8) void {
    const k = v8.v8_String_NewFromUtf8(isolate, key.ptr, @intCast(key.len)) orelse return;
    const v = v8.v8_Number_New(isolate, @floatFromInt(value));
    _ = v8.v8_Object_Set(obj, context, @ptrCast(k), @ptrCast(v));
}

// ============================================================================
// Intl.NumberFormat.supportedLocalesOf() Callback
// ============================================================================

/// Callback for `Intl.NumberFormat.supportedLocalesOf(locales)`
fn numberFormatSupportedLocalesOfCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    // Return all supported locale tags (same as DateTimeFormat)
    const tags = cldr_embedded.locale_tags;
    const result = v8.v8_Array_New(isolate, @intCast(tags.len));

    for (tags, 0..) |tag, i| {
        const tag_str = v8.v8_String_NewFromUtf8(isolate, tag.ptr, @intCast(tag.len)) orelse continue;
        _ = v8.v8_Array_Set(result, context, @intCast(i), @ptrCast(tag_str));
    }

    info.setReturnValue(@ptrCast(result));
}

// ============================================================================
// Collator Instance Storage
// ============================================================================

/// Collator usage enum
const CollatorUsage = enum { sort, search };

/// Collator sensitivity enum
const CollatorSensitivity = enum { base, accent, case, variant };

/// Collator caseFirst enum
const CollatorCaseFirst = enum { upper, lower, false };

/// Internal storage for Collator instances
const CollatorRegistry = struct {
    const Entry = struct {
        locale: []const u8,
        usage: CollatorUsage,
        sensitivity: CollatorSensitivity,
        ignore_punctuation: bool,
        numeric: bool,
        case_first: CollatorCaseFirst,
        allocator: std.mem.Allocator,

        fn deinit(self: *Entry) void {
            self.allocator.free(self.locale);
        }
    };

    entries: std.ArrayList(?Entry) = .{},
    free_list: std.ArrayList(usize) = .{},
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex = .{},

    fn init(allocator: std.mem.Allocator) CollatorRegistry {
        return .{
            .allocator = allocator,
        };
    }

    fn deinit(self: *CollatorRegistry) void {
        for (self.entries.items) |*entry_opt| {
            if (entry_opt.*) |*entry| {
                entry.deinit();
            }
        }
        self.entries.deinit(self.allocator);
        self.free_list.deinit(self.allocator);
    }

    fn register(self: *CollatorRegistry, entry: Entry) !usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.free_list.items.len > 0) {
            const idx = self.free_list.pop().?;
            self.entries.items[idx] = entry;
            return idx;
        }

        const idx = self.entries.items.len;
        try self.entries.append(self.allocator, entry);
        return idx;
    }

    fn get(self: *CollatorRegistry, idx: usize) ?*Entry {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (idx >= self.entries.items.len) return null;
        if (self.entries.items[idx]) |*entry| {
            return entry;
        }
        return null;
    }

    fn remove(self: *CollatorRegistry, idx: usize) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (idx >= self.entries.items.len) return;
        if (self.entries.items[idx]) |*entry| {
            entry.deinit();
            self.entries.items[idx] = null;
            self.free_list.append(self.allocator, idx) catch {};
        }
    }
};

var collator_registry: ?CollatorRegistry = null;

fn getOrInitCollatorRegistry() *CollatorRegistry {
    if (collator_registry == null) {
        collator_registry = CollatorRegistry.init(std.heap.page_allocator);
    }
    return &collator_registry.?;
}

// ============================================================================
// Collator Constructor Callback
// ============================================================================

/// Callback for `new Intl.Collator(locales, options)`
fn collatorConstructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    // Get locale argument
    var locale_buf: [64]u8 = undefined;
    var locale: []const u8 = "en";

    if (info.length() > 0) {
        const locale_arg = info.get(0);
        if (v8.v8_Value_IsString(locale_arg)) {
            const str = v8.v8_Value_ToString(locale_arg, context);
            if (readV8String(str, context, &locale_buf)) |loc| {
                locale = loc;
            }
        }
    }

    // Parse options
    var usage: CollatorUsage = .sort;
    var sensitivity: CollatorSensitivity = .variant;
    var ignore_punctuation: bool = false;
    var numeric: bool = false;
    var case_first: CollatorCaseFirst = .false;

    if (info.length() > 1) {
        const options_arg = info.get(1);
        if (v8.v8_Value_IsObject(options_arg)) {
            const options_obj: *v8.Object = @ptrCast(options_arg);

            // usage
            const usage_key = v8.v8_String_NewFromUtf8(isolate, "usage", 5);
            if (usage_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v| {
                    if (v8.v8_Value_IsString(v)) {
                        var u_buf: [16]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v, context), context, &u_buf)) |u| {
                            if (std.mem.eql(u8, u, "sort")) usage = .sort else if (std.mem.eql(u8, u, "search")) usage = .search;
                        }
                    }
                }
            }

            // sensitivity
            const sens_key = v8.v8_String_NewFromUtf8(isolate, "sensitivity", 11);
            if (sens_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v| {
                    if (v8.v8_Value_IsString(v)) {
                        var s_buf: [16]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v, context), context, &s_buf)) |s| {
                            if (std.mem.eql(u8, s, "base")) sensitivity = .base else if (std.mem.eql(u8, s, "accent")) sensitivity = .accent else if (std.mem.eql(u8, s, "case")) sensitivity = .case else if (std.mem.eql(u8, s, "variant")) sensitivity = .variant;
                        }
                    }
                }
            }

            // ignorePunctuation
            const punct_key = v8.v8_String_NewFromUtf8(isolate, "ignorePunctuation", 17);
            if (punct_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v| {
                    if (v8.v8_Value_IsBoolean(v)) {
                        ignore_punctuation = v8.v8_Value_BooleanValue(v, isolate);
                    }
                }
            }

            // numeric
            const numeric_key = v8.v8_String_NewFromUtf8(isolate, "numeric", 7);
            if (numeric_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v| {
                    if (v8.v8_Value_IsBoolean(v)) {
                        numeric = v8.v8_Value_BooleanValue(v, isolate);
                    }
                }
            }

            // caseFirst
            const case_first_key = v8.v8_String_NewFromUtf8(isolate, "caseFirst", 9);
            if (case_first_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v| {
                    if (v8.v8_Value_IsString(v)) {
                        var cf_buf: [16]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v, context), context, &cf_buf)) |cf| {
                            if (std.mem.eql(u8, cf, "upper")) case_first = .upper else if (std.mem.eql(u8, cf, "lower")) case_first = .lower else if (std.mem.eql(u8, cf, "false")) case_first = .false;
                        }
                    }
                }
            }
        }
    }

    // Create and register collator entry
    const registry = getOrInitCollatorRegistry();
    const entry = CollatorRegistry.Entry{
        .locale = std.heap.page_allocator.dupe(u8, locale) catch {
            conv.throwTypeError(isolate, "Failed to allocate locale");
            return;
        },
        .usage = usage,
        .sensitivity = sensitivity,
        .ignore_punctuation = ignore_punctuation,
        .numeric = numeric,
        .case_first = case_first,
        .allocator = std.heap.page_allocator,
    };

    const idx = registry.register(entry) catch {
        conv.throwTypeError(isolate, "Failed to register Collator");
        return;
    };

    // Create the Collator object
    const collator_obj = v8.v8_Object_New(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to create Collator object");
        return;
    };

    // Store the index
    const idx_key = v8.v8_String_NewFromUtf8(isolate, "__collatorIdx", 13) orelse return;
    const idx_val = v8.v8_Integer_New(isolate, @intCast(idx));
    _ = v8.v8_Object_Set(collator_obj, context, @ptrCast(idx_key), @ptrCast(idx_val));

    // Add compare method (uses 'this' to get the collator object)
    const compare_key = v8.v8_String_NewFromUtf8(isolate, "compare", 7) orelse return;
    const compare_fn = v8.v8_FunctionTemplate_New(isolate, collatorCompareCallback, null) orelse return;
    const compare_fn_obj = v8.v8_FunctionTemplate_GetFunction(compare_fn, context) orelse return;
    _ = v8.v8_Object_Set(collator_obj, context, @ptrCast(compare_key), @ptrCast(compare_fn_obj));

    // Add resolvedOptions method (uses 'this' to get the collator object)
    const opts_key = v8.v8_String_NewFromUtf8(isolate, "resolvedOptions", 15) orelse return;
    const opts_fn = v8.v8_FunctionTemplate_New(isolate, collatorResolvedOptionsCallback, null) orelse return;
    const opts_fn_obj = v8.v8_FunctionTemplate_GetFunction(opts_fn, context) orelse return;
    _ = v8.v8_Object_Set(collator_obj, context, @ptrCast(opts_key), @ptrCast(opts_fn_obj));

    info.setReturnValue(@ptrCast(collator_obj));
}

// ============================================================================
// Collator.prototype.compare
// ============================================================================

/// Compare two strings with locale awareness
fn collatorCompare(entry: *const CollatorRegistry.Entry, a: []const u8, b: []const u8) i32 {
    // For base sensitivity, we only compare the base characters (ignore case and accents)
    // For now, use a simple comparison with sensitivity handling

    switch (entry.sensitivity) {
        .base => {
            // Case-insensitive, accent-insensitive comparison
            // Simple ASCII case-folding for now
            return compareIgnoreCase(a, b);
        },
        .accent => {
            // Case-insensitive but accent-sensitive
            // For now, just do case-insensitive
            return compareIgnoreCase(a, b);
        },
        .case => {
            // Case-sensitive but accent-insensitive
            return compareBytes(a, b);
        },
        .variant => {
            // Full comparison (case and accent sensitive)
            return compareBytes(a, b);
        },
    }
}

fn compareBytes(a: []const u8, b: []const u8) i32 {
    const min_len = @min(a.len, b.len);
    for (a[0..min_len], b[0..min_len]) |ac, bc| {
        if (ac < bc) return -1;
        if (ac > bc) return 1;
    }
    if (a.len < b.len) return -1;
    if (a.len > b.len) return 1;
    return 0;
}

fn compareIgnoreCase(a: []const u8, b: []const u8) i32 {
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

/// Callback for `collator.compare(a, b)`
fn collatorCompareCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        info.setReturnValue(@ptrCast(v8.v8_Integer_New(isolate, 0)));
        return;
    };

    // Get the collator object (this)
    const this_obj: *v8.Object = @ptrCast(info.getThis());

    // Get the collator index
    const idx_key = v8.v8_String_NewFromUtf8(isolate, "__collatorIdx", 13) orelse {
        info.setReturnValue(@ptrCast(v8.v8_Integer_New(isolate, 0)));
        return;
    };

    const idx_val = v8.v8_Object_Get(this_obj, context, @ptrCast(idx_key)) orelse {
        info.setReturnValue(@ptrCast(v8.v8_Integer_New(isolate, 0)));
        return;
    };

    if (!v8.v8_Value_IsNumber(idx_val)) {
        info.setReturnValue(@ptrCast(v8.v8_Integer_New(isolate, 0)));
        return;
    }

    const idx: usize = @intFromFloat(v8.v8_Value_NumberValue(idx_val, context));

    const registry = getOrInitCollatorRegistry();
    const entry = registry.get(idx) orelse {
        info.setReturnValue(@ptrCast(v8.v8_Integer_New(isolate, 0)));
        return;
    };

    // Get the two string arguments
    if (info.length() < 2) {
        info.setReturnValue(@ptrCast(v8.v8_Integer_New(isolate, 0)));
        return;
    }

    var a_buf: [1024]u8 = undefined;
    var b_buf: [1024]u8 = undefined;

    const a_arg = info.get(0);
    const b_arg = info.get(1);

    var a_str: []const u8 = "";
    var b_str: []const u8 = "";

    if (v8.v8_Value_IsString(a_arg)) {
        if (readV8String(v8.v8_Value_ToString(a_arg, context), context, &a_buf)) |s| {
            a_str = s;
        }
    }

    if (v8.v8_Value_IsString(b_arg)) {
        if (readV8String(v8.v8_Value_ToString(b_arg, context), context, &b_buf)) |s| {
            b_str = s;
        }
    }

    // Compare the strings
    const result = collatorCompare(entry, a_str, b_str);
    info.setReturnValue(@ptrCast(v8.v8_Integer_New(isolate, result)));
}

// ============================================================================
// Collator.prototype.resolvedOptions
// ============================================================================

/// Callback for `collator.resolvedOptions()`
fn collatorResolvedOptionsCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    // Get the collator object (this)
    const this_obj: *v8.Object = @ptrCast(info.getThis());

    // Get the collator index
    const idx_key = v8.v8_String_NewFromUtf8(isolate, "__collatorIdx", 13) orelse return;
    const idx_val = v8.v8_Object_Get(this_obj, context, @ptrCast(idx_key)) orelse return;

    if (!v8.v8_Value_IsNumber(idx_val)) return;

    const idx: usize = @intFromFloat(v8.v8_Value_NumberValue(idx_val, context));

    const registry = getOrInitCollatorRegistry();
    const entry = registry.get(idx) orelse return;

    // Create result object
    const result = v8.v8_Object_New(isolate) orelse return;

    // locale
    const locale_key = v8.v8_String_NewFromUtf8(isolate, "locale", 6) orelse return;
    const locale_val = v8.v8_String_NewFromUtf8(isolate, entry.locale.ptr, @intCast(entry.locale.len)) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(locale_key), @ptrCast(locale_val));

    // usage
    const usage_key = v8.v8_String_NewFromUtf8(isolate, "usage", 5) orelse return;
    const usage_str = switch (entry.usage) {
        .sort => "sort",
        .search => "search",
    };
    const usage_val = v8.v8_String_NewFromUtf8(isolate, usage_str.ptr, @intCast(usage_str.len)) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(usage_key), @ptrCast(usage_val));

    // sensitivity
    const sens_key = v8.v8_String_NewFromUtf8(isolate, "sensitivity", 11) orelse return;
    const sens_str = switch (entry.sensitivity) {
        .base => "base",
        .accent => "accent",
        .case => "case",
        .variant => "variant",
    };
    const sens_val = v8.v8_String_NewFromUtf8(isolate, sens_str.ptr, @intCast(sens_str.len)) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(sens_key), @ptrCast(sens_val));

    // ignorePunctuation
    const punct_key = v8.v8_String_NewFromUtf8(isolate, "ignorePunctuation", 17) orelse return;
    const punct_val = v8.v8_Boolean_New(isolate, entry.ignore_punctuation);
    _ = v8.v8_Object_Set(result, context, @ptrCast(punct_key), @ptrCast(punct_val));

    // numeric
    const numeric_key = v8.v8_String_NewFromUtf8(isolate, "numeric", 7) orelse return;
    const numeric_val = v8.v8_Boolean_New(isolate, entry.numeric);
    _ = v8.v8_Object_Set(result, context, @ptrCast(numeric_key), @ptrCast(numeric_val));

    // caseFirst
    const case_first_key = v8.v8_String_NewFromUtf8(isolate, "caseFirst", 9) orelse return;
    const case_first_str = switch (entry.case_first) {
        .upper => "upper",
        .lower => "lower",
        .false => "false",
    };
    const case_first_val = v8.v8_String_NewFromUtf8(isolate, case_first_str.ptr, @intCast(case_first_str.len)) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(case_first_key), @ptrCast(case_first_val));

    // collation
    const collation_key = v8.v8_String_NewFromUtf8(isolate, "collation", 9) orelse return;
    const collation_val = v8.v8_String_NewFromUtf8(isolate, "default", 7) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(collation_key), @ptrCast(collation_val));

    info.setReturnValue(@ptrCast(result));
}

// ============================================================================
// Collator.supportedLocalesOf
// ============================================================================

/// Callback for `Intl.Collator.supportedLocalesOf(locales)`
fn collatorSupportedLocalesOfCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    // Return all supported locale tags (same as other Intl objects)
    const tags = cldr_embedded.locale_tags;
    const result = v8.v8_Array_New(isolate, @intCast(tags.len));

    for (tags, 0..) |tag, i| {
        const tag_str = v8.v8_String_NewFromUtf8(isolate, tag.ptr, @intCast(tag.len)) orelse continue;
        _ = v8.v8_Array_Set(result, context, @intCast(i), @ptrCast(tag_str));
    }

    info.setReturnValue(@ptrCast(result));
}

// ============================================================================
// toLocaleString Methods
// ============================================================================

/// Format a number for toLocaleString (standalone, doesn't require registry entry)
fn formatNumberForLocale(
    buf: []u8,
    value: f64,
    style: NumberStyle,
    currency: ?[]const u8,
    use_grouping: bool,
    min_frac: u8,
    max_frac: u8,
    locale_data: *const cldr.LocaleData,
) []const u8 {
    const symbols = locale_data.number_symbols;
    var idx: usize = 0;

    // Handle special cases
    if (std.math.isNan(value)) {
        idx = writeSliceTo(buf, idx, symbols.nan);
        return buf[0..idx];
    }
    if (std.math.isInf(value)) {
        if (value < 0) {
            idx = writeSliceTo(buf, idx, symbols.minus);
        }
        idx = writeSliceTo(buf, idx, symbols.infinity);
        return buf[0..idx];
    }

    // Handle negative numbers
    var abs_value = value;
    if (value < 0) {
        idx = writeSliceTo(buf, idx, symbols.minus);
        abs_value = -value;
    }

    // Handle percent
    if (style == .percent) {
        abs_value *= 100;
    }

    // Add currency symbol (prepend)
    if (style == .currency) {
        if (currency) |curr| {
            const currency_symbol = getCurrencySymbol(curr);
            idx = writeSliceTo(buf, idx, currency_symbol);
        }
    }

    // Format the number
    const formatted = formatDecimalNumber(
        buf[idx..],
        abs_value,
        min_frac,
        max_frac,
        use_grouping,
        symbols.decimal,
        symbols.group,
    );
    idx += formatted.len;

    // Add percent sign
    if (style == .percent) {
        idx = writeSliceTo(buf, idx, symbols.percent);
    }

    return buf[0..idx];
}

/// Callback for `Number.prototype.toLocaleString(locales, options)`
fn numberToLocaleStringCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    // Get the number value from 'this'
    // For Number.prototype methods, 'this' can be a primitive or boxed Number
    const this_val = info.getThis();
    const number = v8.v8_Value_NumberValue(@ptrCast(this_val), context);
    if (std.math.isNan(number)) {
        // If we got NaN and the original wasn't a number, return "NaN"
        const nan_str = v8.v8_String_NewFromUtf8(isolate, "NaN", 3) orelse return;
        info.setReturnValue(@ptrCast(nan_str));
        return;
    }

    // Get locale argument (optional)
    var locale_buf: [64]u8 = undefined;
    var locale: []const u8 = "en";

    if (info.length() > 0) {
        const locale_arg = info.get(0);
        if (v8.v8_Value_IsString(locale_arg)) {
            const str = v8.v8_Value_ToString(locale_arg, context);
            if (readV8String(str, context, &locale_buf)) |loc| {
                locale = loc;
            }
        }
    }

    // Get locale data (fallback to English if locale not found)
    const locale_data = resolveLocale(locale) orelse cldr_embedded.getLocale("en").?;

    // Parse options for style, currency, etc.
    var style: NumberStyle = .decimal;
    var currency: ?[]const u8 = null;
    var minimum_fraction_digits: u8 = 0;
    var maximum_fraction_digits: u8 = 3;
    const use_grouping: bool = true;

    if (info.length() > 1) {
        const options_arg = info.get(1);
        if (v8.v8_Value_IsObject(options_arg)) {
            const options_obj: *v8.Object = @ptrCast(options_arg);

            // style
            const style_key = v8.v8_String_NewFromUtf8(isolate, "style", 5);
            if (style_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v| {
                    if (v8.v8_Value_IsString(v)) {
                        var s_buf: [16]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v, context), context, &s_buf)) |s| {
                            if (std.mem.eql(u8, s, "currency")) {
                                style = .currency;
                                minimum_fraction_digits = 2;
                                maximum_fraction_digits = 2;
                            } else if (std.mem.eql(u8, s, "percent")) {
                                style = .percent;
                            }
                        }
                    }
                }
            }

            // currency
            const currency_key = v8.v8_String_NewFromUtf8(isolate, "currency", 8);
            if (currency_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v| {
                    if (v8.v8_Value_IsString(v)) {
                        var c_buf: [8]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v, context), context, &c_buf)) |c| {
                            currency = c;
                        }
                    }
                }
            }
        }
    }

    // Format the number
    var buf: [128]u8 = undefined;
    const formatted = formatNumberForLocale(&buf, number, style, currency, use_grouping, minimum_fraction_digits, maximum_fraction_digits, locale_data);

    const result_str = v8.v8_String_NewFromUtf8(isolate, formatted.ptr, @intCast(formatted.len)) orelse return;
    info.setReturnValue(@ptrCast(result_str));
}

/// Callback for `Date.prototype.toLocaleString(locales, options)`
fn dateToLocaleStringCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    // Get the date value from 'this'
    // Date objects have an internal [[DateValue]] accessible via valueOf()
    const this_val = info.getThis();
    const timestamp = v8.v8_Value_NumberValue(@ptrCast(this_val), context);
    if (std.math.isNan(timestamp)) {
        const invalid_str = v8.v8_String_NewFromUtf8(isolate, "Invalid Date", 12) orelse return;
        info.setReturnValue(@ptrCast(invalid_str));
        return;
    }

    // Get locale argument (optional)
    var locale_buf: [64]u8 = undefined;
    var locale: []const u8 = "en";

    if (info.length() > 0) {
        const locale_arg = info.get(0);
        if (v8.v8_Value_IsString(locale_arg)) {
            const str = v8.v8_Value_ToString(locale_arg, context);
            if (readV8String(str, context, &locale_buf)) |loc| {
                locale = loc;
            }
        }
    }

    // Get locale data (fallback to English if locale not found)
    const locale_data = resolveLocale(locale) orelse cldr_embedded.getLocale("en").?;

    // Parse options for dateStyle and timeStyle
    var date_style: ?DateStyle = .medium;
    var time_style: ?TimeStyle = .medium;

    if (info.length() > 1) {
        const options_arg = info.get(1);
        if (v8.v8_Value_IsObject(options_arg)) {
            const options_obj: *v8.Object = @ptrCast(options_arg);

            // dateStyle
            const date_style_key = v8.v8_String_NewFromUtf8(isolate, "dateStyle", 9);
            if (date_style_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v| {
                    if (v8.v8_Value_IsString(v)) {
                        var s_buf: [16]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v, context), context, &s_buf)) |s| {
                            if (std.mem.eql(u8, s, "full")) date_style = .full else if (std.mem.eql(u8, s, "long")) date_style = .long else if (std.mem.eql(u8, s, "medium")) date_style = .medium else if (std.mem.eql(u8, s, "short")) date_style = .short;
                        }
                    }
                }
            }

            // timeStyle
            const time_style_key = v8.v8_String_NewFromUtf8(isolate, "timeStyle", 9);
            if (time_style_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v| {
                    if (v8.v8_Value_IsString(v)) {
                        var s_buf: [16]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v, context), context, &s_buf)) |s| {
                            if (std.mem.eql(u8, s, "full")) time_style = .full else if (std.mem.eql(u8, s, "long")) time_style = .long else if (std.mem.eql(u8, s, "medium")) time_style = .medium else if (std.mem.eql(u8, s, "short")) time_style = .short;
                        }
                    }
                }
            }
        }
    }

    // Format the date
    const dt = DateTime.fromTimestampMillis(@intFromFloat(timestamp));
    var buf: [256]u8 = undefined;
    const formatted = formatDateTime(&buf, dt, locale_data, date_style, time_style);

    const result_str = v8.v8_String_NewFromUtf8(isolate, formatted.ptr, @intCast(formatted.len)) orelse return;
    info.setReturnValue(@ptrCast(result_str));
}

/// Callback for `Date.prototype.toLocaleDateString(locales, options)`
fn dateToLocaleDateStringCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    // Get the date value from 'this'
    const this_val = info.getThis();
    const timestamp = v8.v8_Value_NumberValue(@ptrCast(this_val), context);
    if (std.math.isNan(timestamp)) {
        const invalid_str = v8.v8_String_NewFromUtf8(isolate, "Invalid Date", 12) orelse return;
        info.setReturnValue(@ptrCast(invalid_str));
        return;
    }

    // Get locale argument (optional)
    var locale_buf: [64]u8 = undefined;
    var locale: []const u8 = "en";

    if (info.length() > 0) {
        const locale_arg = info.get(0);
        if (v8.v8_Value_IsString(locale_arg)) {
            const str = v8.v8_Value_ToString(locale_arg, context);
            if (readV8String(str, context, &locale_buf)) |loc| {
                locale = loc;
            }
        }
    }

    // Get locale data (fallback to English if locale not found)
    const locale_data = resolveLocale(locale) orelse cldr_embedded.getLocale("en").?;

    // Parse options for dateStyle (default to medium, no time)
    var date_style: ?DateStyle = .medium;

    if (info.length() > 1) {
        const options_arg = info.get(1);
        if (v8.v8_Value_IsObject(options_arg)) {
            const options_obj: *v8.Object = @ptrCast(options_arg);

            const date_style_key = v8.v8_String_NewFromUtf8(isolate, "dateStyle", 9);
            if (date_style_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v| {
                    if (v8.v8_Value_IsString(v)) {
                        var s_buf: [16]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v, context), context, &s_buf)) |s| {
                            if (std.mem.eql(u8, s, "full")) date_style = .full else if (std.mem.eql(u8, s, "long")) date_style = .long else if (std.mem.eql(u8, s, "medium")) date_style = .medium else if (std.mem.eql(u8, s, "short")) date_style = .short;
                        }
                    }
                }
            }
        }
    }

    // Format date only (no time)
    const dt = DateTime.fromTimestampMillis(@intFromFloat(timestamp));
    var buf: [256]u8 = undefined;
    const formatted = formatDateTime(&buf, dt, locale_data, date_style, null);

    const result_str = v8.v8_String_NewFromUtf8(isolate, formatted.ptr, @intCast(formatted.len)) orelse return;
    info.setReturnValue(@ptrCast(result_str));
}

/// Callback for `Date.prototype.toLocaleTimeString(locales, options)`
fn dateToLocaleTimeStringCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    // Get the date value from 'this'
    const this_val = info.getThis();
    const timestamp = v8.v8_Value_NumberValue(@ptrCast(this_val), context);
    if (std.math.isNan(timestamp)) {
        const invalid_str = v8.v8_String_NewFromUtf8(isolate, "Invalid Date", 12) orelse return;
        info.setReturnValue(@ptrCast(invalid_str));
        return;
    }

    // Get locale argument (optional)
    var locale_buf: [64]u8 = undefined;
    var locale: []const u8 = "en";

    if (info.length() > 0) {
        const locale_arg = info.get(0);
        if (v8.v8_Value_IsString(locale_arg)) {
            const str = v8.v8_Value_ToString(locale_arg, context);
            if (readV8String(str, context, &locale_buf)) |loc| {
                locale = loc;
            }
        }
    }

    // Get locale data (fallback to English if locale not found)
    const locale_data = resolveLocale(locale) orelse cldr_embedded.getLocale("en").?;

    // Parse options for timeStyle (default to medium, no date)
    var time_style: ?TimeStyle = .medium;

    if (info.length() > 1) {
        const options_arg = info.get(1);
        if (v8.v8_Value_IsObject(options_arg)) {
            const options_obj: *v8.Object = @ptrCast(options_arg);

            const time_style_key = v8.v8_String_NewFromUtf8(isolate, "timeStyle", 9);
            if (time_style_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v| {
                    if (v8.v8_Value_IsString(v)) {
                        var s_buf: [16]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v, context), context, &s_buf)) |s| {
                            if (std.mem.eql(u8, s, "full")) time_style = .full else if (std.mem.eql(u8, s, "long")) time_style = .long else if (std.mem.eql(u8, s, "medium")) time_style = .medium else if (std.mem.eql(u8, s, "short")) time_style = .short;
                        }
                    }
                }
            }
        }
    }

    // Format time only (no date)
    const dt = DateTime.fromTimestampMillis(@intFromFloat(timestamp));
    var buf: [256]u8 = undefined;
    const formatted = formatDateTime(&buf, dt, locale_data, null, time_style);

    const result_str = v8.v8_String_NewFromUtf8(isolate, formatted.ptr, @intCast(formatted.len)) orelse return;
    info.setReturnValue(@ptrCast(result_str));
}

/// Register toLocaleString methods on built-in prototypes
pub fn registerToLocaleStringMethods(isolate: *v8.Isolate, context: *v8.Context) void {
    const global = v8.v8_Context_Global(context) orelse return;

    // ========================================================================
    // Number.prototype.toLocaleString
    // ========================================================================
    const number_key = v8.v8_String_NewFromUtf8(isolate, "Number", 6) orelse return;
    const number_constructor = v8.v8_Object_Get(global, context, @ptrCast(number_key)) orelse return;
    if (!v8.v8_Value_IsFunction(number_constructor)) return;

    const number_proto_key = v8.v8_String_NewFromUtf8(isolate, "prototype", 9) orelse return;
    const number_proto = v8.v8_Object_Get(@ptrCast(number_constructor), context, @ptrCast(number_proto_key)) orelse return;
    if (!v8.v8_Value_IsObject(number_proto)) return;

    const to_locale_string_key = v8.v8_String_NewFromUtf8(isolate, "toLocaleString", 14) orelse return;
    const num_locale_fn = v8.v8_FunctionTemplate_New(isolate, numberToLocaleStringCallback, null) orelse return;
    const num_locale_fn_obj = v8.v8_FunctionTemplate_GetFunction(num_locale_fn, context) orelse return;
    _ = v8.v8_Object_Set(@ptrCast(number_proto), context, @ptrCast(to_locale_string_key), @ptrCast(num_locale_fn_obj));

    // ========================================================================
    // Date.prototype.toLocaleString, toLocaleDateString, toLocaleTimeString
    // ========================================================================
    const date_key = v8.v8_String_NewFromUtf8(isolate, "Date", 4) orelse return;
    const date_constructor = v8.v8_Object_Get(global, context, @ptrCast(date_key)) orelse return;
    if (!v8.v8_Value_IsFunction(date_constructor)) return;

    const date_proto = v8.v8_Object_Get(@ptrCast(date_constructor), context, @ptrCast(number_proto_key)) orelse return;
    if (!v8.v8_Value_IsObject(date_proto)) return;

    // toLocaleString
    const date_locale_fn = v8.v8_FunctionTemplate_New(isolate, dateToLocaleStringCallback, null) orelse return;
    const date_locale_fn_obj = v8.v8_FunctionTemplate_GetFunction(date_locale_fn, context) orelse return;
    _ = v8.v8_Object_Set(@ptrCast(date_proto), context, @ptrCast(to_locale_string_key), @ptrCast(date_locale_fn_obj));

    // toLocaleDateString
    const to_locale_date_key = v8.v8_String_NewFromUtf8(isolate, "toLocaleDateString", 18) orelse return;
    const date_locale_date_fn = v8.v8_FunctionTemplate_New(isolate, dateToLocaleDateStringCallback, null) orelse return;
    const date_locale_date_fn_obj = v8.v8_FunctionTemplate_GetFunction(date_locale_date_fn, context) orelse return;
    _ = v8.v8_Object_Set(@ptrCast(date_proto), context, @ptrCast(to_locale_date_key), @ptrCast(date_locale_date_fn_obj));

    // toLocaleTimeString
    const to_locale_time_key = v8.v8_String_NewFromUtf8(isolate, "toLocaleTimeString", 18) orelse return;
    const date_locale_time_fn = v8.v8_FunctionTemplate_New(isolate, dateToLocaleTimeStringCallback, null) orelse return;
    const date_locale_time_fn_obj = v8.v8_FunctionTemplate_GetFunction(date_locale_time_fn, context) orelse return;
    _ = v8.v8_Object_Set(@ptrCast(date_proto), context, @ptrCast(to_locale_time_key), @ptrCast(date_locale_time_fn_obj));
}

// ============================================================================
// Public API
// ============================================================================

/// Register the Intl global object with V8
pub fn registerGlobal(isolate: *v8.Isolate, context: *v8.Context) void {
    // Create Intl namespace object
    const intl_obj = v8.v8_Object_New(isolate) orelse return;

    // ========================================================================
    // DateTimeFormat
    // ========================================================================
    const dtf_template = v8.v8_FunctionTemplate_New(isolate, dateTimeFormatConstructorCallback, null) orelse return;
    const dtf_constructor = v8.v8_FunctionTemplate_GetFunction(dtf_template, context) orelse return;

    // Add supportedLocalesOf static method
    const dtf_supported_fn = v8.v8_FunctionTemplate_New(isolate, supportedLocalesOfCallback, null) orelse return;
    const dtf_supported_fn_obj = v8.v8_FunctionTemplate_GetFunction(dtf_supported_fn, context) orelse return;
    const supported_key = v8.v8_String_NewFromUtf8(isolate, "supportedLocalesOf", 18) orelse return;
    _ = v8.v8_Object_Set(@ptrCast(dtf_constructor), context, @ptrCast(supported_key), @ptrCast(dtf_supported_fn_obj));

    // Add DateTimeFormat to Intl object
    const dtf_key = v8.v8_String_NewFromUtf8(isolate, "DateTimeFormat", 14) orelse return;
    _ = v8.v8_Object_Set(intl_obj, context, @ptrCast(dtf_key), @ptrCast(dtf_constructor));

    // ========================================================================
    // NumberFormat
    // ========================================================================
    const nf_template = v8.v8_FunctionTemplate_New(isolate, numberFormatConstructorCallback, null) orelse return;
    const nf_constructor = v8.v8_FunctionTemplate_GetFunction(nf_template, context) orelse return;

    // Add supportedLocalesOf static method
    const nf_supported_fn = v8.v8_FunctionTemplate_New(isolate, numberFormatSupportedLocalesOfCallback, null) orelse return;
    const nf_supported_fn_obj = v8.v8_FunctionTemplate_GetFunction(nf_supported_fn, context) orelse return;
    _ = v8.v8_Object_Set(@ptrCast(nf_constructor), context, @ptrCast(supported_key), @ptrCast(nf_supported_fn_obj));

    // Add NumberFormat to Intl object
    const nf_key = v8.v8_String_NewFromUtf8(isolate, "NumberFormat", 12) orelse return;
    _ = v8.v8_Object_Set(intl_obj, context, @ptrCast(nf_key), @ptrCast(nf_constructor));

    // ========================================================================
    // Collator
    // ========================================================================
    const col_template = v8.v8_FunctionTemplate_New(isolate, collatorConstructorCallback, null) orelse return;
    const col_constructor = v8.v8_FunctionTemplate_GetFunction(col_template, context) orelse return;

    // Add supportedLocalesOf static method
    const col_supported_fn = v8.v8_FunctionTemplate_New(isolate, collatorSupportedLocalesOfCallback, null) orelse return;
    const col_supported_fn_obj = v8.v8_FunctionTemplate_GetFunction(col_supported_fn, context) orelse return;
    _ = v8.v8_Object_Set(@ptrCast(col_constructor), context, @ptrCast(supported_key), @ptrCast(col_supported_fn_obj));

    // Add Collator to Intl object
    const col_key = v8.v8_String_NewFromUtf8(isolate, "Collator", 8) orelse return;
    _ = v8.v8_Object_Set(intl_obj, context, @ptrCast(col_key), @ptrCast(col_constructor));

    // ========================================================================
    // Add Intl to global object
    // ========================================================================
    const global = v8.v8_Context_Global(context) orelse return;
    const intl_key = v8.v8_String_NewFromUtf8(isolate, "Intl", 4) orelse return;

    _ = v8.v8_Object_DefineProperty(
        global,
        context,
        @ptrCast(intl_key),
        @ptrCast(intl_obj),
        true,
        false,
        true,
    );
}

/// Register external references for V8 snapshots
pub fn registerExternalReferences() void {
    const ext_refs = @import("external_references.zig");

    // DateTimeFormat
    ext_refs.registerCallbackRuntime(dateTimeFormatConstructorCallback);
    ext_refs.registerCallbackRuntime(dateTimeFormatFormatCallback);
    ext_refs.registerCallbackRuntime(dateTimeFormatToPartsCallback);
    ext_refs.registerCallbackRuntime(dateTimeFormatResolvedOptionsCallback);
    ext_refs.registerCallbackRuntime(supportedLocalesOfCallback);

    // NumberFormat
    ext_refs.registerCallbackRuntime(numberFormatConstructorCallback);
    ext_refs.registerCallbackRuntime(numberFormatFormatCallback);
    ext_refs.registerCallbackRuntime(numberFormatToPartsCallback);
    ext_refs.registerCallbackRuntime(numberFormatResolvedOptionsCallback);
    ext_refs.registerCallbackRuntime(numberFormatSupportedLocalesOfCallback);

    // Collator
    ext_refs.registerCallbackRuntime(collatorConstructorCallback);
    ext_refs.registerCallbackRuntime(collatorCompareCallback);
    ext_refs.registerCallbackRuntime(collatorResolvedOptionsCallback);
    ext_refs.registerCallbackRuntime(collatorSupportedLocalesOfCallback);

    // toLocaleString methods
    ext_refs.registerCallbackRuntime(numberToLocaleStringCallback);
    ext_refs.registerCallbackRuntime(dateToLocaleStringCallback);
    ext_refs.registerCallbackRuntime(dateToLocaleDateStringCallback);
    ext_refs.registerCallbackRuntime(dateToLocaleTimeStringCallback);
}

// ============================================================================
// Tests
// ============================================================================

test "DateTime.fromTimestampMillis" {
    const testing = std.testing;

    // 2023-11-14 12:30:45 UTC
    const dt = DateTime.fromTimestampMillis(1699964445000);
    try testing.expectEqual(@as(i32, 2023), dt.year);
    try testing.expectEqual(@as(u8, 11), dt.month);
    try testing.expectEqual(@as(u8, 14), dt.day);
    try testing.expectEqual(@as(u8, 12), dt.hour);
    try testing.expectEqual(@as(u8, 27), dt.minute); // Close to 30
}

test "resolveLocale" {
    const testing = std.testing;

    // Exact match
    const en = resolveLocale("en");
    try testing.expect(en != null);

    // With fallback
    const en_us = resolveLocale("en-US");
    try testing.expect(en_us != null);

    // Unknown locale falls back to en
    const unknown = resolveLocale("xx-YY");
    try testing.expect(unknown != null);
}

test "formatWithPattern" {
    const dt = DateTime{
        .year = 2024,
        .month = 12,
        .day = 13,
        .hour = 14,
        .minute = 30,
        .second = 45,
    };

    const locale_data = cldr_embedded.getLocale("en").?;
    var buf: [256]u8 = undefined;

    // Simple date pattern
    const result = formatWithPattern(&buf, "yyyy-MM-dd", dt, locale_data);
    const testing = std.testing;
    try testing.expectEqualStrings("2024-12-13", result);
}
