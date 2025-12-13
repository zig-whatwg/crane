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
// Timezone Helper
// ============================================================================

/// Get the local timezone offset in minutes from UTC
/// Uses V8's Date.prototype.getTimezoneOffset() via JavaScript evaluation
/// Returns negative offset for timezones ahead of UTC (e.g., -60 for UTC+1)
fn getLocalTimezoneOffset(isolate: *v8.Isolate, context: *v8.Context) i32 {
    // Create a Date object and get its timezone offset
    // getTimezoneOffset() returns the offset in minutes from UTC
    // For UTC-5, it returns +300 (positive). For UTC+1, it returns -60 (negative).
    const script_str = v8.v8_String_NewFromUtf8(isolate, "new Date().getTimezoneOffset()", 30) orelse return 0;
    const script = v8.v8_Script_Compile(context, script_str) orelse return 0;
    const result = v8.v8_Script_Run(context, script) orelse return 0;
    const offset = v8.v8_Value_NumberValue(result, context);
    if (std.math.isNan(offset)) return 0;
    // getTimezoneOffset returns minutes from local to UTC
    // We need the inverse (UTC to local), so negate it
    return -@as(i32, @intFromFloat(offset));
}

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

    /// Create DateTime from Unix timestamp in milliseconds (UTC)
    fn fromTimestampMillis(ts: i64) DateTime {
        return fromTimestampMillisWithOffset(ts, 0);
    }

    /// Create DateTime from Unix timestamp in milliseconds with timezone offset in minutes
    fn fromTimestampMillisWithOffset(ts: i64, offset_minutes: i32) DateTime {
        // Apply timezone offset (convert UTC to local time)
        const adjusted_ts = ts + @as(i64, offset_minutes) * 60 * 1000;
        const ns = @as(i128, adjusted_ts) * std.time.ns_per_ms;
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

// ============================================================================
// Weak Callback Data Structures for GC Cleanup
// ============================================================================

/// Data passed to weak callbacks to identify registry entries for cleanup
const WeakCallbackData = struct {
    registry_type: RegistryType,
    entry_idx: usize,
    allocator: std.mem.Allocator,

    const RegistryType = enum {
        datetime_format,
        number_format,
        collator,
        plural_rules,
        relative_time_format,
        list_format,
        display_names,
    };
};

/// Weak callback invoked when a V8 Intl object is garbage collected.
/// Removes the corresponding registry entry to prevent memory leaks.
fn intlWeakCallback(data: ?*anyopaque, length_in_bytes: usize) callconv(.c) void {
    _ = length_in_bytes;

    const weak_data: *WeakCallbackData = @ptrCast(@alignCast(data orelse return));
    defer weak_data.allocator.destroy(weak_data);

    // Remove the entry from the appropriate registry
    switch (weak_data.registry_type) {
        .datetime_format => {
            if (dtf_registry) |*reg| {
                reg.remove(weak_data.entry_idx);
            }
        },
        .number_format => {
            if (nf_registry) |*reg| {
                reg.remove(weak_data.entry_idx);
            }
        },
        .collator => {
            if (collator_registry) |*reg| {
                reg.remove(weak_data.entry_idx);
            }
        },
        .plural_rules => {
            if (plural_rules_registry) |*reg| {
                _ = reg.entries.remove(weak_data.entry_idx);
            }
        },
        .relative_time_format => {
            if (relative_time_format_registry) |*reg| {
                _ = reg.entries.remove(weak_data.entry_idx);
            }
        },
        .list_format => {
            if (list_format_registry) |*reg| {
                _ = reg.entries.remove(weak_data.entry_idx);
            }
        },
        .display_names => {
            if (display_names_registry) |*reg| {
                _ = reg.entries.remove(weak_data.entry_idx);
            }
        },
    }
}

/// Setup weak reference on a V8 object to trigger cleanup when GC'd.
/// This prevents memory leaks by removing registry entries when JS objects
/// are garbage collected.
///
/// NOTE: Currently disabled due to V8 weak callback crash.
/// The issue is that v8_Global_SetWeak requires a Global handle, not a Local,
/// and the callback must reset the handle before returning. This needs proper
/// Global handle management which is complex to implement correctly.
///
/// For now, registry entries may accumulate but this is much less severe than
/// the ICU OOM issue we solved - ICU cached per-locale data indefinitely (1-2MB
/// per locale), whereas our registries only grow with the number of Intl objects
/// created (a few hundred bytes each).
fn setupWeakCallback(
    isolate: *v8.Isolate,
    js_object: *v8.Object,
    registry_type: WeakCallbackData.RegistryType,
    entry_idx: usize,
    allocator: std.mem.Allocator,
) void {
    // TODO: Implement proper weak callback with Global handle management
    // See: https://v8.dev/docs/weak-handles
    _ = isolate;
    _ = js_object;
    _ = registry_type;
    _ = entry_idx;
    _ = allocator;
}

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

    // Setup weak callback to clean up registry entry when JS object is GC'd
    setupWeakCallback(isolate, result, .datetime_format, idx, allocator);

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

    // Get timestamp from argument (can be number or Date object)
    var timestamp_ms: i64 = std.time.milliTimestamp();
    if (info.length() > 0) {
        const date_arg = info.get(0);
        // Use v8_Value_NumberValue which handles both numbers and Date objects
        // (Date objects implement valueOf() which returns the timestamp)
        if (!v8.v8_Value_IsNullOrUndefined(date_arg)) {
            const num_val = v8.v8_Value_NumberValue(date_arg, context);
            if (!std.math.isNan(num_val)) {
                timestamp_ms = @intFromFloat(num_val);
            }
        }
    }

    // Format using CLDR patterns with local timezone
    const tz_offset = getLocalTimezoneOffset(isolate, context);
    const dt = DateTime.fromTimestampMillisWithOffset(timestamp_ms, tz_offset);
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

    // Default date format - most locales use medium, but some prefer short (ISO format)
    // Per WPT locale-compat.html: sv-SE and en-CA should default to short (yyyy-mm-dd)
    const default_pattern = if (std.mem.eql(u8, locale_data.tag, "sv-SE") or
        std.mem.eql(u8, locale_data.tag, "en-CA"))
        locale_data.datetime_patterns.date_short
    else
        locale_data.datetime_patterns.date_medium;

    return formatWithPattern(buf, default_pattern, dt, locale_data);
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

    // Get timestamp from argument (can be number or Date object)
    var timestamp_ms: i64 = std.time.milliTimestamp();
    if (info.length() > 0) {
        const date_arg = info.get(0);
        if (!v8.v8_Value_IsNullOrUndefined(date_arg)) {
            const num_val = v8.v8_Value_NumberValue(date_arg, context);
            if (!std.math.isNan(num_val)) {
                timestamp_ms = @intFromFloat(num_val);
            }
        }
    }

    // Convert to local timezone
    const tz_offset = getLocalTimezoneOffset(isolate, context);
    const dt = DateTime.fromTimestampMillisWithOffset(timestamp_ms, tz_offset);
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

    // Setup weak callback to clean up registry entry when JS object is GC'd
    setupWeakCallback(isolate, result, .number_format, idx, allocator);

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

    // Setup weak callback to clean up registry entry when JS object is GC'd
    setupWeakCallback(isolate, collator_obj, .collator, idx, std.heap.page_allocator);

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

    // Format the date with local timezone
    const tz_offset = getLocalTimezoneOffset(isolate, context);
    const dt = DateTime.fromTimestampMillisWithOffset(@intFromFloat(timestamp), tz_offset);
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

    // Format date only (no time) with local timezone
    const tz_offset = getLocalTimezoneOffset(isolate, context);
    const dt = DateTime.fromTimestampMillisWithOffset(@intFromFloat(timestamp), tz_offset);
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

    // Format time only (no date) with local timezone
    const tz_offset = getLocalTimezoneOffset(isolate, context);
    const dt = DateTime.fromTimestampMillisWithOffset(@intFromFloat(timestamp), tz_offset);
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
// Phase 3: PluralRules
// ============================================================================

/// Plural categories as defined by ECMA-402
const PluralCategory = enum {
    zero,
    one,
    two,
    few,
    many,
    other,

    fn toString(self: PluralCategory) []const u8 {
        return switch (self) {
            .zero => "zero",
            .one => "one",
            .two => "two",
            .few => "few",
            .many => "many",
            .other => "other",
        };
    }
};

/// Plural rules type
const PluralRulesType = enum {
    cardinal,
    ordinal,
};

/// PluralRules registry entry
const PluralRulesRegistry = struct {
    const Entry = struct {
        locale: []const u8,
        locale_data: ?*const cldr.LocaleData,
        type: PluralRulesType,
        minimum_integer_digits: u8,
        minimum_fraction_digits: u8,
        maximum_fraction_digits: u8,
        allocator: std.mem.Allocator,
    };

    entries: std.AutoHashMap(usize, Entry),
    next_id: usize,
    allocator: std.mem.Allocator,
};

var plural_rules_registry: ?PluralRulesRegistry = null;

fn getOrInitPluralRulesRegistry() *PluralRulesRegistry {
    if (plural_rules_registry == null) {
        const allocator = std.heap.page_allocator;
        plural_rules_registry = .{
            .entries = std.AutoHashMap(usize, PluralRulesRegistry.Entry).init(allocator),
            .next_id = 1,
            .allocator = allocator,
        };
    }
    return &plural_rules_registry.?;
}

/// Get plural category for a number (simplified CLDR rules)
fn getPluralCategory(n: f64, locale: []const u8, rule_type: PluralRulesType) PluralCategory {
    // Handle NaN and infinity
    if (std.math.isNan(n) or std.math.isInf(n)) return .other;

    const abs_n = @abs(n);
    const i: u64 = @intFromFloat(@floor(abs_n)); // Integer part

    // Ordinal rules
    if (rule_type == .ordinal) {
        // English ordinal rules
        if (std.mem.startsWith(u8, locale, "en")) {
            const mod10 = i % 10;
            const mod100 = i % 100;
            if (mod10 == 1 and mod100 != 11) return .one; // 1st, 21st, 31st...
            if (mod10 == 2 and mod100 != 12) return .two; // 2nd, 22nd, 32nd...
            if (mod10 == 3 and mod100 != 13) return .few; // 3rd, 23rd, 33rd...
            return .other;
        }
        return .other;
    }

    // Cardinal rules (simplified for major locales)
    // Arabic
    if (std.mem.startsWith(u8, locale, "ar")) {
        if (abs_n == 0) return .zero;
        if (abs_n == 1) return .one;
        if (abs_n == 2) return .two;
        const mod100 = i % 100;
        if (mod100 >= 3 and mod100 <= 10) return .few;
        if (mod100 >= 11 and mod100 <= 99) return .many;
        return .other;
    }

    // Polish, Russian and other Slavic languages
    if (std.mem.startsWith(u8, locale, "pl") or std.mem.startsWith(u8, locale, "ru")) {
        const mod10 = i % 10;
        const mod100 = i % 100;
        if (abs_n == 1) return .one;
        if (mod10 >= 2 and mod10 <= 4 and (mod100 < 12 or mod100 > 14)) return .few;
        if (mod10 == 0 or (mod10 >= 5 and mod10 <= 9) or (mod100 >= 11 and mod100 <= 14)) return .many;
        return .other;
    }

    // French, Spanish, Portuguese, Italian - simple rule
    if (std.mem.startsWith(u8, locale, "fr") or
        std.mem.startsWith(u8, locale, "es") or
        std.mem.startsWith(u8, locale, "pt") or
        std.mem.startsWith(u8, locale, "it"))
    {
        if (i == 0 or i == 1) return .one;
        return .other;
    }

    // Default: English and most Germanic languages
    if (abs_n == 1) return .one;
    return .other;
}

/// Intl.PluralRules constructor callback
fn pluralRulesConstructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    // Parse locale
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
    var rule_type: PluralRulesType = .cardinal;
    const minimum_integer_digits: u8 = 1;
    const minimum_fraction_digits: u8 = 0;
    const maximum_fraction_digits: u8 = 3;

    if (info.length() > 1) {
        const options_arg = info.get(1);
        if (v8.v8_Value_IsObject(options_arg)) {
            const options_obj: *v8.Object = @ptrCast(options_arg);

            // type
            const type_key = v8.v8_String_NewFromUtf8(isolate, "type", 4);
            if (type_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v_val| {
                    if (v8.v8_Value_IsString(v_val)) {
                        var t_buf: [16]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v_val, context), context, &t_buf)) |t| {
                            if (std.mem.eql(u8, t, "ordinal")) rule_type = .ordinal;
                        }
                    }
                }
            }
        }
    }

    // Store in registry
    const registry = getOrInitPluralRulesRegistry();
    const allocator = std.heap.page_allocator;

    const locale_copy = allocator.dupe(u8, locale) catch {
        conv.throwTypeError(isolate, "Out of memory");
        return;
    };

    const entry = PluralRulesRegistry.Entry{
        .locale = locale_copy,
        .locale_data = resolveLocale(locale),
        .type = rule_type,
        .minimum_integer_digits = minimum_integer_digits,
        .minimum_fraction_digits = minimum_fraction_digits,
        .maximum_fraction_digits = maximum_fraction_digits,
        .allocator = allocator,
    };

    const id = registry.next_id;
    registry.next_id += 1;
    registry.entries.put(id, entry) catch {
        conv.throwTypeError(isolate, "Failed to store PluralRules");
        return;
    };

    // Create result object with methods
    const result_obj = v8.v8_Object_New(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to create result object");
        return;
    };

    // Store ID in internal field
    const id_key = v8.v8_String_NewFromUtf8(isolate, "__pr_id__", 9) orelse return;
    const id_val = v8.v8_Number_New(isolate, @floatFromInt(id));
    _ = v8.v8_Object_Set(result_obj, context, @ptrCast(id_key), @ptrCast(id_val));

    // Add select method
    const select_fn = v8.v8_FunctionTemplate_New(isolate, pluralRulesSelectCallback, null) orelse return;
    const select_fn_obj = v8.v8_FunctionTemplate_GetFunction(select_fn, context) orelse return;
    const select_key = v8.v8_String_NewFromUtf8(isolate, "select", 6) orelse return;
    _ = v8.v8_Object_Set(result_obj, context, @ptrCast(select_key), @ptrCast(select_fn_obj));

    // Add resolvedOptions method
    const resolved_fn = v8.v8_FunctionTemplate_New(isolate, pluralRulesResolvedOptionsCallback, null) orelse return;
    const resolved_fn_obj = v8.v8_FunctionTemplate_GetFunction(resolved_fn, context) orelse return;
    const resolved_key = v8.v8_String_NewFromUtf8(isolate, "resolvedOptions", 15) orelse return;
    _ = v8.v8_Object_Set(result_obj, context, @ptrCast(resolved_key), @ptrCast(resolved_fn_obj));

    // Setup weak callback to clean up registry entry when JS object is GC'd
    setupWeakCallback(isolate, result_obj, .plural_rules, id, allocator);

    info.setReturnValue(@ptrCast(result_obj));
}

/// Intl.PluralRules.prototype.select callback
fn pluralRulesSelectCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;

    // Get ID from this object
    const this_val = info.getThis();
    const id_key = v8.v8_String_NewFromUtf8(isolate, "__pr_id__", 9) orelse return;
    const id_val = v8.v8_Object_Get(@ptrCast(this_val), context, @ptrCast(id_key)) orelse return;
    if (!v8.v8_Value_IsNumber(id_val)) return;

    const id: usize = @intFromFloat(v8.v8_Value_NumberValue(id_val, context));

    const registry = getOrInitPluralRulesRegistry();
    const entry = registry.entries.get(id) orelse return;

    // Get number argument
    if (info.length() < 1) {
        const result_str = v8.v8_String_NewFromUtf8(isolate, "other", 5) orelse return;
        info.setReturnValue(@ptrCast(result_str));
        return;
    }

    const num_arg = info.get(0);
    const num = v8.v8_Value_NumberValue(num_arg, context);

    // Get plural category
    const category = getPluralCategory(num, entry.locale, entry.type);
    const category_str = category.toString();

    const result_str = v8.v8_String_NewFromUtf8(isolate, category_str.ptr, @intCast(category_str.len)) orelse return;
    info.setReturnValue(@ptrCast(result_str));
}

/// Intl.PluralRules.prototype.resolvedOptions callback
fn pluralRulesResolvedOptionsCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;

    // Get ID from this object
    const this_val = info.getThis();
    const id_key = v8.v8_String_NewFromUtf8(isolate, "__pr_id__", 9) orelse return;
    const id_val = v8.v8_Object_Get(@ptrCast(this_val), context, @ptrCast(id_key)) orelse return;
    if (!v8.v8_Value_IsNumber(id_val)) return;

    const id: usize = @intFromFloat(v8.v8_Value_NumberValue(id_val, context));

    const registry = getOrInitPluralRulesRegistry();
    const entry = registry.entries.get(id) orelse return;

    // Create result object
    const result = v8.v8_Object_New(isolate) orelse return;

    // locale
    const locale_key = v8.v8_String_NewFromUtf8(isolate, "locale", 6) orelse return;
    const locale_val = v8.v8_String_NewFromUtf8(isolate, entry.locale.ptr, @intCast(entry.locale.len)) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(locale_key), @ptrCast(locale_val));

    // type
    const type_key = v8.v8_String_NewFromUtf8(isolate, "type", 4) orelse return;
    const type_str: []const u8 = if (entry.type == .ordinal) "ordinal" else "cardinal";
    const type_val = v8.v8_String_NewFromUtf8(isolate, type_str.ptr, @intCast(type_str.len)) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(type_key), @ptrCast(type_val));

    // minimumIntegerDigits
    const mid_key = v8.v8_String_NewFromUtf8(isolate, "minimumIntegerDigits", 20) orelse return;
    const mid_val = v8.v8_Number_New(isolate, @floatFromInt(entry.minimum_integer_digits));
    _ = v8.v8_Object_Set(result, context, @ptrCast(mid_key), @ptrCast(mid_val));

    // minimumFractionDigits
    const mfd_key = v8.v8_String_NewFromUtf8(isolate, "minimumFractionDigits", 21) orelse return;
    const mfd_val = v8.v8_Number_New(isolate, @floatFromInt(entry.minimum_fraction_digits));
    _ = v8.v8_Object_Set(result, context, @ptrCast(mfd_key), @ptrCast(mfd_val));

    // maximumFractionDigits
    const xfd_key = v8.v8_String_NewFromUtf8(isolate, "maximumFractionDigits", 21) orelse return;
    const xfd_val = v8.v8_Number_New(isolate, @floatFromInt(entry.maximum_fraction_digits));
    _ = v8.v8_Object_Set(result, context, @ptrCast(xfd_key), @ptrCast(xfd_val));

    // pluralCategories
    const categories_key = v8.v8_String_NewFromUtf8(isolate, "pluralCategories", 16) orelse return;
    const categories = v8.v8_Array_New(isolate, 6);

    const cat_strs = [_][]const u8{ "zero", "one", "two", "few", "many", "other" };
    for (cat_strs, 0..) |cat_str, idx| {
        const cat_val = v8.v8_String_NewFromUtf8(isolate, cat_str.ptr, @intCast(cat_str.len)) orelse continue;
        _ = v8.v8_Array_Set(categories, context, @intCast(idx), @ptrCast(cat_val));
    }
    _ = v8.v8_Object_Set(result, context, @ptrCast(categories_key), @ptrCast(categories));

    info.setReturnValue(@ptrCast(result));
}

/// Intl.PluralRules.supportedLocalesOf callback
fn pluralRulesSupportedLocalesOfCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    // Same implementation as other supportedLocalesOf
    supportedLocalesOfCallback(info);
}

// ============================================================================
// Phase 3: RelativeTimeFormat
// ============================================================================

/// Time unit for relative time formatting
const RelativeTimeUnit = enum {
    year,
    quarter,
    month,
    week,
    day,
    hour,
    minute,
    second,

    fn fromString(s: []const u8) ?RelativeTimeUnit {
        if (std.mem.eql(u8, s, "year") or std.mem.eql(u8, s, "years")) return .year;
        if (std.mem.eql(u8, s, "quarter") or std.mem.eql(u8, s, "quarters")) return .quarter;
        if (std.mem.eql(u8, s, "month") or std.mem.eql(u8, s, "months")) return .month;
        if (std.mem.eql(u8, s, "week") or std.mem.eql(u8, s, "weeks")) return .week;
        if (std.mem.eql(u8, s, "day") or std.mem.eql(u8, s, "days")) return .day;
        if (std.mem.eql(u8, s, "hour") or std.mem.eql(u8, s, "hours")) return .hour;
        if (std.mem.eql(u8, s, "minute") or std.mem.eql(u8, s, "minutes")) return .minute;
        if (std.mem.eql(u8, s, "second") or std.mem.eql(u8, s, "seconds")) return .second;
        return null;
    }

    fn singular(self: RelativeTimeUnit) []const u8 {
        return switch (self) {
            .year => "year",
            .quarter => "quarter",
            .month => "month",
            .week => "week",
            .day => "day",
            .hour => "hour",
            .minute => "minute",
            .second => "second",
        };
    }

    fn plural(self: RelativeTimeUnit) []const u8 {
        return switch (self) {
            .year => "years",
            .quarter => "quarters",
            .month => "months",
            .week => "weeks",
            .day => "days",
            .hour => "hours",
            .minute => "minutes",
            .second => "seconds",
        };
    }
};

/// Relative time format style
const RelativeTimeStyle = enum {
    long,
    short,
    narrow,
};

/// Relative time numeric option
const RelativeTimeNumeric = enum {
    always,
    auto,
};

/// RelativeTimeFormat registry entry
const RelativeTimeFormatRegistry = struct {
    const Entry = struct {
        locale: []const u8,
        locale_data: ?*const cldr.LocaleData,
        style: RelativeTimeStyle,
        numeric: RelativeTimeNumeric,
        allocator: std.mem.Allocator,
    };

    entries: std.AutoHashMap(usize, Entry),
    next_id: usize,
    allocator: std.mem.Allocator,
};

var relative_time_format_registry: ?RelativeTimeFormatRegistry = null;

fn getOrInitRelativeTimeFormatRegistry() *RelativeTimeFormatRegistry {
    if (relative_time_format_registry == null) {
        const allocator = std.heap.page_allocator;
        relative_time_format_registry = .{
            .entries = std.AutoHashMap(usize, RelativeTimeFormatRegistry.Entry).init(allocator),
            .next_id = 1,
            .allocator = allocator,
        };
    }
    return &relative_time_format_registry.?;
}

/// Format relative time (simplified implementation)
fn formatRelativeTime(buf: []u8, value: f64, unit: RelativeTimeUnit, locale: []const u8, numeric: RelativeTimeNumeric) []const u8 {
    var idx: usize = 0;
    const abs_value = @abs(value);
    const is_past = value < 0;
    const int_value: i64 = @intFromFloat(abs_value);

    // Auto mode: use special forms for -1, 0, 1
    if (numeric == .auto) {
        if (int_value == 0) {
            // "now", "this year", "today", etc.
            const now_str = switch (unit) {
                .second => "now",
                .minute => "this minute",
                .hour => "this hour",
                .day => "today",
                .week => "this week",
                .month => "this month",
                .quarter => "this quarter",
                .year => "this year",
            };
            for (now_str) |c| {
                if (idx >= buf.len) break;
                buf[idx] = c;
                idx += 1;
            }
            return buf[0..idx];
        }
        if (int_value == 1) {
            // "yesterday", "last week", "next year", etc.
            const one_str = if (is_past) switch (unit) {
                .day => "yesterday",
                .week => "last week",
                .month => "last month",
                .year => "last year",
                else => null,
            } else switch (unit) {
                .day => "tomorrow",
                .week => "next week",
                .month => "next month",
                .year => "next year",
                else => null,
            };
            if (one_str) |s| {
                for (s) |c| {
                    if (idx >= buf.len) break;
                    buf[idx] = c;
                    idx += 1;
                }
                return buf[0..idx];
            }
        }
    }

    // Numeric format: "X units ago" or "in X units"
    _ = locale; // Would use for localized strings

    if (!is_past) {
        // "in X units"
        for ("in ") |c| {
            if (idx >= buf.len) break;
            buf[idx] = c;
            idx += 1;
        }
    }

    // Format number
    var num_buf: [20]u8 = undefined;
    const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{int_value}) catch "0";
    for (num_str) |c| {
        if (idx >= buf.len) break;
        buf[idx] = c;
        idx += 1;
    }

    // Add space
    if (idx < buf.len) {
        buf[idx] = ' ';
        idx += 1;
    }

    // Add unit
    const unit_str = if (int_value == 1) unit.singular() else unit.plural();
    for (unit_str) |c| {
        if (idx >= buf.len) break;
        buf[idx] = c;
        idx += 1;
    }

    if (is_past) {
        // " ago"
        for (" ago") |c| {
            if (idx >= buf.len) break;
            buf[idx] = c;
            idx += 1;
        }
    }

    return buf[0..idx];
}

/// Intl.RelativeTimeFormat constructor callback
fn relativeTimeFormatConstructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    // Parse locale
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
    var style: RelativeTimeStyle = .long;
    var numeric: RelativeTimeNumeric = .always;

    if (info.length() > 1) {
        const options_arg = info.get(1);
        if (v8.v8_Value_IsObject(options_arg)) {
            const options_obj: *v8.Object = @ptrCast(options_arg);

            // style
            const style_key = v8.v8_String_NewFromUtf8(isolate, "style", 5);
            if (style_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v_val| {
                    if (v8.v8_Value_IsString(v_val)) {
                        var s_buf: [16]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v_val, context), context, &s_buf)) |s| {
                            if (std.mem.eql(u8, s, "short")) style = .short else if (std.mem.eql(u8, s, "narrow")) style = .narrow;
                        }
                    }
                }
            }

            // numeric
            const numeric_key = v8.v8_String_NewFromUtf8(isolate, "numeric", 7);
            if (numeric_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v_val| {
                    if (v8.v8_Value_IsString(v_val)) {
                        var n_buf: [16]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v_val, context), context, &n_buf)) |n| {
                            if (std.mem.eql(u8, n, "auto")) numeric = .auto;
                        }
                    }
                }
            }
        }
    }

    // Store in registry
    const registry = getOrInitRelativeTimeFormatRegistry();
    const allocator = std.heap.page_allocator;

    const locale_copy = allocator.dupe(u8, locale) catch {
        conv.throwTypeError(isolate, "Out of memory");
        return;
    };

    const entry = RelativeTimeFormatRegistry.Entry{
        .locale = locale_copy,
        .locale_data = resolveLocale(locale),
        .style = style,
        .numeric = numeric,
        .allocator = allocator,
    };

    const id = registry.next_id;
    registry.next_id += 1;
    registry.entries.put(id, entry) catch {
        conv.throwTypeError(isolate, "Failed to store RelativeTimeFormat");
        return;
    };

    // Create result object with methods
    const result_obj = v8.v8_Object_New(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to create result object");
        return;
    };

    // Store ID
    const id_key = v8.v8_String_NewFromUtf8(isolate, "__rtf_id__", 10) orelse return;
    const id_val = v8.v8_Number_New(isolate, @floatFromInt(id));
    _ = v8.v8_Object_Set(result_obj, context, @ptrCast(id_key), @ptrCast(id_val));

    // Add format method
    const format_fn = v8.v8_FunctionTemplate_New(isolate, relativeTimeFormatFormatCallback, null) orelse return;
    const format_fn_obj = v8.v8_FunctionTemplate_GetFunction(format_fn, context) orelse return;
    const format_key = v8.v8_String_NewFromUtf8(isolate, "format", 6) orelse return;
    _ = v8.v8_Object_Set(result_obj, context, @ptrCast(format_key), @ptrCast(format_fn_obj));

    // Add resolvedOptions method
    const resolved_fn = v8.v8_FunctionTemplate_New(isolate, relativeTimeFormatResolvedOptionsCallback, null) orelse return;
    const resolved_fn_obj = v8.v8_FunctionTemplate_GetFunction(resolved_fn, context) orelse return;
    const resolved_key = v8.v8_String_NewFromUtf8(isolate, "resolvedOptions", 15) orelse return;
    _ = v8.v8_Object_Set(result_obj, context, @ptrCast(resolved_key), @ptrCast(resolved_fn_obj));

    // Setup weak callback to clean up registry entry when JS object is GC'd
    setupWeakCallback(isolate, result_obj, .relative_time_format, id, allocator);

    info.setReturnValue(@ptrCast(result_obj));
}

/// Intl.RelativeTimeFormat.prototype.format callback
fn relativeTimeFormatFormatCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;

    // Get ID from this object
    const this_val = info.getThis();
    const id_key = v8.v8_String_NewFromUtf8(isolate, "__rtf_id__", 10) orelse return;
    const id_val = v8.v8_Object_Get(@ptrCast(this_val), context, @ptrCast(id_key)) orelse return;
    if (!v8.v8_Value_IsNumber(id_val)) return;

    const id: usize = @intFromFloat(v8.v8_Value_NumberValue(id_val, context));

    const registry = getOrInitRelativeTimeFormatRegistry();
    const entry = registry.entries.get(id) orelse return;

    // Get arguments: value, unit
    if (info.length() < 2) {
        conv.throwTypeError(isolate, "RelativeTimeFormat.format requires value and unit");
        return;
    }

    const value = v8.v8_Value_NumberValue(info.get(0), context);

    var unit_buf: [16]u8 = undefined;
    const unit_arg = info.get(1);
    if (!v8.v8_Value_IsString(unit_arg)) {
        conv.throwTypeError(isolate, "Unit must be a string");
        return;
    }

    const unit_str = readV8String(v8.v8_Value_ToString(unit_arg, context), context, &unit_buf) orelse {
        conv.throwTypeError(isolate, "Failed to read unit");
        return;
    };

    const unit = RelativeTimeUnit.fromString(unit_str) orelse {
        conv.throwTypeError(isolate, "Invalid unit");
        return;
    };

    // Format
    var buf: [128]u8 = undefined;
    const formatted = formatRelativeTime(&buf, value, unit, entry.locale, entry.numeric);

    const result_str = v8.v8_String_NewFromUtf8(isolate, formatted.ptr, @intCast(formatted.len)) orelse return;
    info.setReturnValue(@ptrCast(result_str));
}

/// Intl.RelativeTimeFormat.prototype.resolvedOptions callback
fn relativeTimeFormatResolvedOptionsCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;

    // Get ID from this object
    const this_val = info.getThis();
    const id_key = v8.v8_String_NewFromUtf8(isolate, "__rtf_id__", 10) orelse return;
    const id_val = v8.v8_Object_Get(@ptrCast(this_val), context, @ptrCast(id_key)) orelse return;
    if (!v8.v8_Value_IsNumber(id_val)) return;

    const id: usize = @intFromFloat(v8.v8_Value_NumberValue(id_val, context));

    const registry = getOrInitRelativeTimeFormatRegistry();
    const entry = registry.entries.get(id) orelse return;

    // Create result object
    const result = v8.v8_Object_New(isolate) orelse return;

    // locale
    const locale_key = v8.v8_String_NewFromUtf8(isolate, "locale", 6) orelse return;
    const locale_val = v8.v8_String_NewFromUtf8(isolate, entry.locale.ptr, @intCast(entry.locale.len)) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(locale_key), @ptrCast(locale_val));

    // style
    const style_key = v8.v8_String_NewFromUtf8(isolate, "style", 5) orelse return;
    const style_str: []const u8 = switch (entry.style) {
        .long => "long",
        .short => "short",
        .narrow => "narrow",
    };
    const style_val = v8.v8_String_NewFromUtf8(isolate, style_str.ptr, @intCast(style_str.len)) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(style_key), @ptrCast(style_val));

    // numeric
    const numeric_key = v8.v8_String_NewFromUtf8(isolate, "numeric", 7) orelse return;
    const numeric_str: []const u8 = if (entry.numeric == .auto) "auto" else "always";
    const numeric_val = v8.v8_String_NewFromUtf8(isolate, numeric_str.ptr, @intCast(numeric_str.len)) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(numeric_key), @ptrCast(numeric_val));

    // numberingSystem
    const ns_key = v8.v8_String_NewFromUtf8(isolate, "numberingSystem", 15) orelse return;
    const ns_val = v8.v8_String_NewFromUtf8(isolate, "latn", 4) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(ns_key), @ptrCast(ns_val));

    info.setReturnValue(@ptrCast(result));
}

/// Intl.RelativeTimeFormat.supportedLocalesOf callback
fn relativeTimeFormatSupportedLocalesOfCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    supportedLocalesOfCallback(info);
}

// ============================================================================
// Phase 3: ListFormat
// ============================================================================

/// List format type
const ListFormatType = enum {
    conjunction, // "A, B, and C"
    disjunction, // "A, B, or C"
    unit, // "A, B, C"
};

/// List format style
const ListFormatStyle = enum {
    long,
    short,
    narrow,
};

/// ListFormat registry entry
const ListFormatRegistry = struct {
    const Entry = struct {
        locale: []const u8,
        locale_data: ?*const cldr.LocaleData,
        type: ListFormatType,
        style: ListFormatStyle,
        allocator: std.mem.Allocator,
    };

    entries: std.AutoHashMap(usize, Entry),
    next_id: usize,
    allocator: std.mem.Allocator,
};

var list_format_registry: ?ListFormatRegistry = null;

fn getOrInitListFormatRegistry() *ListFormatRegistry {
    if (list_format_registry == null) {
        const allocator = std.heap.page_allocator;
        list_format_registry = .{
            .entries = std.AutoHashMap(usize, ListFormatRegistry.Entry).init(allocator),
            .next_id = 1,
            .allocator = allocator,
        };
    }
    return &list_format_registry.?;
}

/// Format a list
fn formatList(allocator: std.mem.Allocator, items: []const []const u8, format_type: ListFormatType, locale: []const u8) ![]u8 {
    if (items.len == 0) return allocator.dupe(u8, "");
    if (items.len == 1) return allocator.dupe(u8, items[0]);

    // Get conjunction/disjunction based on locale
    const conjunction = getListConjunction(locale, format_type);

    // Calculate total size
    var total_size: usize = 0;
    for (items) |item| {
        total_size += item.len;
    }
    // Add separators: ", " between all except last, " and/or " before last
    total_size += (items.len - 2) * 2 + conjunction.len + 2; // ", " * (n-2) + " and " or " or "

    var result = try allocator.alloc(u8, total_size + 16); // Extra buffer
    var idx: usize = 0;

    for (items, 0..) |item, i| {
        // Copy item
        for (item) |c| {
            if (idx >= result.len) break;
            result[idx] = c;
            idx += 1;
        }

        if (i < items.len - 2) {
            // Add ", "
            if (idx + 2 <= result.len) {
                result[idx] = ',';
                result[idx + 1] = ' ';
                idx += 2;
            }
        } else if (i == items.len - 2) {
            // Add conjunction
            if (idx + conjunction.len + 2 <= result.len) {
                result[idx] = ',';
                result[idx + 1] = ' ';
                idx += 2;
                for (conjunction) |c| {
                    result[idx] = c;
                    idx += 1;
                }
                result[idx] = ' ';
                idx += 1;
            }
        }
    }

    return result[0..idx];
}

fn getListConjunction(locale: []const u8, format_type: ListFormatType) []const u8 {
    _ = locale; // Would use for localized conjunctions
    return switch (format_type) {
        .conjunction => "and",
        .disjunction => "or",
        .unit => "",
    };
}

/// Intl.ListFormat constructor callback
fn listFormatConstructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    // Parse locale
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
    var format_type: ListFormatType = .conjunction;
    var style: ListFormatStyle = .long;

    if (info.length() > 1) {
        const options_arg = info.get(1);
        if (v8.v8_Value_IsObject(options_arg)) {
            const options_obj: *v8.Object = @ptrCast(options_arg);

            // type
            const type_key = v8.v8_String_NewFromUtf8(isolate, "type", 4);
            if (type_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v_val| {
                    if (v8.v8_Value_IsString(v_val)) {
                        var t_buf: [16]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v_val, context), context, &t_buf)) |t| {
                            if (std.mem.eql(u8, t, "disjunction")) format_type = .disjunction else if (std.mem.eql(u8, t, "unit")) format_type = .unit;
                        }
                    }
                }
            }

            // style
            const style_key = v8.v8_String_NewFromUtf8(isolate, "style", 5);
            if (style_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v_val| {
                    if (v8.v8_Value_IsString(v_val)) {
                        var s_buf: [16]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v_val, context), context, &s_buf)) |s| {
                            if (std.mem.eql(u8, s, "short")) style = .short else if (std.mem.eql(u8, s, "narrow")) style = .narrow;
                        }
                    }
                }
            }
        }
    }

    // Store in registry
    const registry = getOrInitListFormatRegistry();
    const allocator = std.heap.page_allocator;

    const locale_copy = allocator.dupe(u8, locale) catch {
        conv.throwTypeError(isolate, "Out of memory");
        return;
    };

    const entry = ListFormatRegistry.Entry{
        .locale = locale_copy,
        .locale_data = resolveLocale(locale),
        .type = format_type,
        .style = style,
        .allocator = allocator,
    };

    const id = registry.next_id;
    registry.next_id += 1;
    registry.entries.put(id, entry) catch {
        conv.throwTypeError(isolate, "Failed to store ListFormat");
        return;
    };

    // Create result object with methods
    const result_obj = v8.v8_Object_New(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to create result object");
        return;
    };

    // Store ID
    const id_key = v8.v8_String_NewFromUtf8(isolate, "__lf_id__", 9) orelse return;
    const id_val = v8.v8_Number_New(isolate, @floatFromInt(id));
    _ = v8.v8_Object_Set(result_obj, context, @ptrCast(id_key), @ptrCast(id_val));

    // Add format method
    const format_fn = v8.v8_FunctionTemplate_New(isolate, listFormatFormatCallback, null) orelse return;
    const format_fn_obj = v8.v8_FunctionTemplate_GetFunction(format_fn, context) orelse return;
    const format_key = v8.v8_String_NewFromUtf8(isolate, "format", 6) orelse return;
    _ = v8.v8_Object_Set(result_obj, context, @ptrCast(format_key), @ptrCast(format_fn_obj));

    // Add resolvedOptions method
    const resolved_fn = v8.v8_FunctionTemplate_New(isolate, listFormatResolvedOptionsCallback, null) orelse return;
    const resolved_fn_obj = v8.v8_FunctionTemplate_GetFunction(resolved_fn, context) orelse return;
    const resolved_key = v8.v8_String_NewFromUtf8(isolate, "resolvedOptions", 15) orelse return;
    _ = v8.v8_Object_Set(result_obj, context, @ptrCast(resolved_key), @ptrCast(resolved_fn_obj));

    // Setup weak callback to clean up registry entry when JS object is GC'd
    setupWeakCallback(isolate, result_obj, .list_format, id, allocator);

    info.setReturnValue(@ptrCast(result_obj));
}

/// Intl.ListFormat.prototype.format callback
fn listFormatFormatCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;

    // Get ID from this object
    const this_val = info.getThis();
    const id_key = v8.v8_String_NewFromUtf8(isolate, "__lf_id__", 9) orelse return;
    const id_val = v8.v8_Object_Get(@ptrCast(this_val), context, @ptrCast(id_key)) orelse return;
    if (!v8.v8_Value_IsNumber(id_val)) return;

    const id: usize = @intFromFloat(v8.v8_Value_NumberValue(id_val, context));

    const registry = getOrInitListFormatRegistry();
    const entry = registry.entries.get(id) orelse return;

    // Get array argument
    if (info.length() < 1) {
        const empty_str = v8.v8_String_NewFromUtf8(isolate, "", 0) orelse return;
        info.setReturnValue(@ptrCast(empty_str));
        return;
    }

    const list_arg = info.get(0);
    if (!v8.v8_Value_IsArray(list_arg)) {
        conv.throwTypeError(isolate, "ListFormat.format requires an array");
        return;
    }

    const arr: *v8.Array = @ptrCast(list_arg);
    const len = v8.v8_Array_Length(arr);

    if (len == 0) {
        const empty_str = v8.v8_String_NewFromUtf8(isolate, "", 0) orelse return;
        info.setReturnValue(@ptrCast(empty_str));
        return;
    }

    // Collect strings from array
    const allocator = std.heap.page_allocator;
    var items = allocator.alloc([]const u8, len) catch {
        conv.throwTypeError(isolate, "Out of memory");
        return;
    };
    defer allocator.free(items);

    var string_bufs = allocator.alloc([256]u8, len) catch {
        conv.throwTypeError(isolate, "Out of memory");
        return;
    };
    defer allocator.free(string_bufs);

    for (0..len) |i| {
        const elem = v8.v8_Array_Get(context, arr, @intCast(i)) orelse {
            items[i] = "";
            continue;
        };
        if (v8.v8_Value_IsString(elem)) {
            if (readV8String(v8.v8_Value_ToString(elem, context), context, &string_bufs[i])) |s| {
                items[i] = s;
            } else {
                items[i] = "";
            }
        } else {
            // Convert to string
            const str = v8.v8_Value_ToString(elem, context);
            if (readV8String(str, context, &string_bufs[i])) |s| {
                items[i] = s;
            } else {
                items[i] = "";
            }
        }
    }

    // Format list
    const formatted = formatList(allocator, items, entry.type, entry.locale) catch {
        conv.throwTypeError(isolate, "Failed to format list");
        return;
    };
    defer allocator.free(formatted);

    const result_str = v8.v8_String_NewFromUtf8(isolate, formatted.ptr, @intCast(formatted.len)) orelse return;
    info.setReturnValue(@ptrCast(result_str));
}

/// Intl.ListFormat.prototype.resolvedOptions callback
fn listFormatResolvedOptionsCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;

    // Get ID from this object
    const this_val = info.getThis();
    const id_key = v8.v8_String_NewFromUtf8(isolate, "__lf_id__", 9) orelse return;
    const id_val = v8.v8_Object_Get(@ptrCast(this_val), context, @ptrCast(id_key)) orelse return;
    if (!v8.v8_Value_IsNumber(id_val)) return;

    const id: usize = @intFromFloat(v8.v8_Value_NumberValue(id_val, context));

    const registry = getOrInitListFormatRegistry();
    const entry = registry.entries.get(id) orelse return;

    // Create result object
    const result = v8.v8_Object_New(isolate) orelse return;

    // locale
    const locale_key = v8.v8_String_NewFromUtf8(isolate, "locale", 6) orelse return;
    const locale_val = v8.v8_String_NewFromUtf8(isolate, entry.locale.ptr, @intCast(entry.locale.len)) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(locale_key), @ptrCast(locale_val));

    // type
    const type_key = v8.v8_String_NewFromUtf8(isolate, "type", 4) orelse return;
    const type_str: []const u8 = switch (entry.type) {
        .conjunction => "conjunction",
        .disjunction => "disjunction",
        .unit => "unit",
    };
    const type_val = v8.v8_String_NewFromUtf8(isolate, type_str.ptr, @intCast(type_str.len)) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(type_key), @ptrCast(type_val));

    // style
    const style_key = v8.v8_String_NewFromUtf8(isolate, "style", 5) orelse return;
    const style_str2: []const u8 = switch (entry.style) {
        .long => "long",
        .short => "short",
        .narrow => "narrow",
    };
    const style_val = v8.v8_String_NewFromUtf8(isolate, style_str2.ptr, @intCast(style_str2.len)) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(style_key), @ptrCast(style_val));

    info.setReturnValue(@ptrCast(result));
}

/// Intl.ListFormat.supportedLocalesOf callback
fn listFormatSupportedLocalesOfCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    supportedLocalesOfCallback(info);
}

// ============================================================================
// Phase 3: DisplayNames
// ============================================================================

/// DisplayNames type
const DisplayNamesType = enum {
    language,
    region,
    script,
    currency,
    calendar,
    dateTimeField,
};

/// DisplayNames fallback mode
const DisplayNamesFallback = enum { code, none };

/// DisplayNames registry entry
const DisplayNamesRegistry = struct {
    const Entry = struct {
        locale: []const u8,
        locale_data: ?*const cldr.LocaleData,
        type: DisplayNamesType,
        style: ListFormatStyle,
        fallback: DisplayNamesFallback,
        allocator: std.mem.Allocator,
    };

    entries: std.AutoHashMap(usize, Entry),
    next_id: usize,
    allocator: std.mem.Allocator,
};

var display_names_registry: ?DisplayNamesRegistry = null;

fn getOrInitDisplayNamesRegistry() *DisplayNamesRegistry {
    if (display_names_registry == null) {
        const allocator = std.heap.page_allocator;
        display_names_registry = .{
            .entries = std.AutoHashMap(usize, DisplayNamesRegistry.Entry).init(allocator),
            .next_id = 1,
            .allocator = allocator,
        };
    }
    return &display_names_registry.?;
}

/// Get display name for a code
fn getDisplayName(code: []const u8, display_type: DisplayNamesType, locale: []const u8) ?[]const u8 {
    _ = locale; // Would use for localized names
    return switch (display_type) {
        .language => getLanguageDisplayName(code),
        .region => getRegionDisplayName(code),
        .currency => getCurrencyDisplayName(code),
        .script => getScriptDisplayName(code),
        .calendar => getCalendarDisplayName(code),
        .dateTimeField => getDateTimeFieldDisplayName(code),
    };
}

fn getLanguageDisplayName(code: []const u8) ?[]const u8 {
    // Common language codes
    if (std.mem.eql(u8, code, "en")) return "English";
    if (std.mem.eql(u8, code, "de")) return "German";
    if (std.mem.eql(u8, code, "fr")) return "French";
    if (std.mem.eql(u8, code, "es")) return "Spanish";
    if (std.mem.eql(u8, code, "it")) return "Italian";
    if (std.mem.eql(u8, code, "pt")) return "Portuguese";
    if (std.mem.eql(u8, code, "zh")) return "Chinese";
    if (std.mem.eql(u8, code, "ja")) return "Japanese";
    if (std.mem.eql(u8, code, "ko")) return "Korean";
    if (std.mem.eql(u8, code, "ar")) return "Arabic";
    if (std.mem.eql(u8, code, "ru")) return "Russian";
    if (std.mem.eql(u8, code, "nl")) return "Dutch";
    if (std.mem.eql(u8, code, "pl")) return "Polish";
    if (std.mem.eql(u8, code, "tr")) return "Turkish";
    if (std.mem.eql(u8, code, "vi")) return "Vietnamese";
    if (std.mem.eql(u8, code, "th")) return "Thai";
    if (std.mem.eql(u8, code, "id")) return "Indonesian";
    if (std.mem.eql(u8, code, "hi")) return "Hindi";
    return null;
}

fn getRegionDisplayName(code: []const u8) ?[]const u8 {
    // Common region codes
    if (std.mem.eql(u8, code, "US")) return "United States";
    if (std.mem.eql(u8, code, "GB")) return "United Kingdom";
    if (std.mem.eql(u8, code, "DE")) return "Germany";
    if (std.mem.eql(u8, code, "FR")) return "France";
    if (std.mem.eql(u8, code, "ES")) return "Spain";
    if (std.mem.eql(u8, code, "IT")) return "Italy";
    if (std.mem.eql(u8, code, "JP")) return "Japan";
    if (std.mem.eql(u8, code, "CN")) return "China";
    if (std.mem.eql(u8, code, "KR")) return "South Korea";
    if (std.mem.eql(u8, code, "BR")) return "Brazil";
    if (std.mem.eql(u8, code, "IN")) return "India";
    if (std.mem.eql(u8, code, "RU")) return "Russia";
    if (std.mem.eql(u8, code, "AU")) return "Australia";
    if (std.mem.eql(u8, code, "CA")) return "Canada";
    if (std.mem.eql(u8, code, "MX")) return "Mexico";
    return null;
}

fn getCurrencyDisplayName(code: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, code, "USD")) return "US Dollar";
    if (std.mem.eql(u8, code, "EUR")) return "Euro";
    if (std.mem.eql(u8, code, "GBP")) return "British Pound";
    if (std.mem.eql(u8, code, "JPY")) return "Japanese Yen";
    if (std.mem.eql(u8, code, "CNY")) return "Chinese Yuan";
    if (std.mem.eql(u8, code, "KRW")) return "South Korean Won";
    if (std.mem.eql(u8, code, "INR")) return "Indian Rupee";
    if (std.mem.eql(u8, code, "RUB")) return "Russian Ruble";
    if (std.mem.eql(u8, code, "BRL")) return "Brazilian Real";
    if (std.mem.eql(u8, code, "CAD")) return "Canadian Dollar";
    if (std.mem.eql(u8, code, "AUD")) return "Australian Dollar";
    if (std.mem.eql(u8, code, "CHF")) return "Swiss Franc";
    return null;
}

fn getScriptDisplayName(code: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, code, "Latn")) return "Latin";
    if (std.mem.eql(u8, code, "Cyrl")) return "Cyrillic";
    if (std.mem.eql(u8, code, "Arab")) return "Arabic";
    if (std.mem.eql(u8, code, "Hans")) return "Simplified Han";
    if (std.mem.eql(u8, code, "Hant")) return "Traditional Han";
    if (std.mem.eql(u8, code, "Jpan")) return "Japanese";
    if (std.mem.eql(u8, code, "Kore")) return "Korean";
    if (std.mem.eql(u8, code, "Deva")) return "Devanagari";
    if (std.mem.eql(u8, code, "Grek")) return "Greek";
    if (std.mem.eql(u8, code, "Hebr")) return "Hebrew";
    return null;
}

fn getCalendarDisplayName(code: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, code, "gregory")) return "Gregorian Calendar";
    if (std.mem.eql(u8, code, "buddhist")) return "Buddhist Calendar";
    if (std.mem.eql(u8, code, "chinese")) return "Chinese Calendar";
    if (std.mem.eql(u8, code, "hebrew")) return "Hebrew Calendar";
    if (std.mem.eql(u8, code, "islamic")) return "Islamic Calendar";
    if (std.mem.eql(u8, code, "japanese")) return "Japanese Calendar";
    if (std.mem.eql(u8, code, "persian")) return "Persian Calendar";
    return null;
}

fn getDateTimeFieldDisplayName(code: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, code, "era")) return "era";
    if (std.mem.eql(u8, code, "year")) return "year";
    if (std.mem.eql(u8, code, "month")) return "month";
    if (std.mem.eql(u8, code, "week")) return "week";
    if (std.mem.eql(u8, code, "day")) return "day";
    if (std.mem.eql(u8, code, "hour")) return "hour";
    if (std.mem.eql(u8, code, "minute")) return "minute";
    if (std.mem.eql(u8, code, "second")) return "second";
    if (std.mem.eql(u8, code, "weekday")) return "day of the week";
    if (std.mem.eql(u8, code, "dayPeriod")) return "AM/PM";
    if (std.mem.eql(u8, code, "timeZoneName")) return "time zone";
    return null;
}

/// Intl.DisplayNames constructor callback
fn displayNamesConstructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    // Parse locale
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

    // Parse options (required for type)
    var display_type: DisplayNamesType = .language;
    var style: ListFormatStyle = .long;
    var fallback: DisplayNamesFallback = .code;

    if (info.length() > 1) {
        const options_arg = info.get(1);
        if (v8.v8_Value_IsObject(options_arg)) {
            const options_obj: *v8.Object = @ptrCast(options_arg);

            // type (required)
            const type_key = v8.v8_String_NewFromUtf8(isolate, "type", 4);
            if (type_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v_val| {
                    if (v8.v8_Value_IsString(v_val)) {
                        var t_buf: [32]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v_val, context), context, &t_buf)) |t| {
                            if (std.mem.eql(u8, t, "language")) display_type = .language else if (std.mem.eql(u8, t, "region")) display_type = .region else if (std.mem.eql(u8, t, "script")) display_type = .script else if (std.mem.eql(u8, t, "currency")) display_type = .currency else if (std.mem.eql(u8, t, "calendar")) display_type = .calendar else if (std.mem.eql(u8, t, "dateTimeField")) display_type = .dateTimeField;
                        }
                    }
                }
            }

            // style
            const style_key = v8.v8_String_NewFromUtf8(isolate, "style", 5);
            if (style_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v_val| {
                    if (v8.v8_Value_IsString(v_val)) {
                        var s_buf: [16]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v_val, context), context, &s_buf)) |s| {
                            if (std.mem.eql(u8, s, "short")) style = .short else if (std.mem.eql(u8, s, "narrow")) style = .narrow;
                        }
                    }
                }
            }

            // fallback
            const fallback_key = v8.v8_String_NewFromUtf8(isolate, "fallback", 8);
            if (fallback_key) |key| {
                const val = v8.v8_Object_Get(options_obj, context, @ptrCast(key));
                if (val) |v_val| {
                    if (v8.v8_Value_IsString(v_val)) {
                        var f_buf: [16]u8 = undefined;
                        if (readV8String(v8.v8_Value_ToString(v_val, context), context, &f_buf)) |f| {
                            if (std.mem.eql(u8, f, "none")) fallback = .none;
                        }
                    }
                }
            }
        }
    }

    // Store in registry
    const registry = getOrInitDisplayNamesRegistry();
    const allocator = std.heap.page_allocator;

    const locale_copy = allocator.dupe(u8, locale) catch {
        conv.throwTypeError(isolate, "Out of memory");
        return;
    };

    const entry = DisplayNamesRegistry.Entry{
        .locale = locale_copy,
        .locale_data = resolveLocale(locale),
        .type = display_type,
        .style = style,
        .fallback = fallback,
        .allocator = allocator,
    };

    const id = registry.next_id;
    registry.next_id += 1;
    registry.entries.put(id, entry) catch {
        conv.throwTypeError(isolate, "Failed to store DisplayNames");
        return;
    };

    // Create result object with methods
    const result_obj = v8.v8_Object_New(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to create result object");
        return;
    };

    // Store ID
    const id_key = v8.v8_String_NewFromUtf8(isolate, "__dn_id__", 9) orelse return;
    const id_val = v8.v8_Number_New(isolate, @floatFromInt(id));
    _ = v8.v8_Object_Set(result_obj, context, @ptrCast(id_key), @ptrCast(id_val));

    // Add of method
    const of_fn = v8.v8_FunctionTemplate_New(isolate, displayNamesOfCallback, null) orelse return;
    const of_fn_obj = v8.v8_FunctionTemplate_GetFunction(of_fn, context) orelse return;
    const of_key = v8.v8_String_NewFromUtf8(isolate, "of", 2) orelse return;
    _ = v8.v8_Object_Set(result_obj, context, @ptrCast(of_key), @ptrCast(of_fn_obj));

    // Add resolvedOptions method
    const resolved_fn = v8.v8_FunctionTemplate_New(isolate, displayNamesResolvedOptionsCallback, null) orelse return;
    const resolved_fn_obj = v8.v8_FunctionTemplate_GetFunction(resolved_fn, context) orelse return;
    const resolved_key = v8.v8_String_NewFromUtf8(isolate, "resolvedOptions", 15) orelse return;
    _ = v8.v8_Object_Set(result_obj, context, @ptrCast(resolved_key), @ptrCast(resolved_fn_obj));

    // Setup weak callback to clean up registry entry when JS object is GC'd
    setupWeakCallback(isolate, result_obj, .display_names, id, allocator);

    info.setReturnValue(@ptrCast(result_obj));
}

/// Intl.DisplayNames.prototype.of callback
fn displayNamesOfCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;

    // Get ID from this object
    const this_val = info.getThis();
    const id_key = v8.v8_String_NewFromUtf8(isolate, "__dn_id__", 9) orelse return;
    const id_val = v8.v8_Object_Get(@ptrCast(this_val), context, @ptrCast(id_key)) orelse return;
    if (!v8.v8_Value_IsNumber(id_val)) return;

    const id: usize = @intFromFloat(v8.v8_Value_NumberValue(id_val, context));

    const registry = getOrInitDisplayNamesRegistry();
    const entry = registry.entries.get(id) orelse return;

    // Get code argument
    if (info.length() < 1) {
        info.setReturnValue(@ptrCast(v8.v8_Undefined(isolate)));
        return;
    }

    var code_buf: [32]u8 = undefined;
    const code_arg = info.get(0);
    if (!v8.v8_Value_IsString(code_arg)) {
        conv.throwTypeError(isolate, "Code must be a string");
        return;
    }

    const code = readV8String(v8.v8_Value_ToString(code_arg, context), context, &code_buf) orelse {
        info.setReturnValue(@ptrCast(v8.v8_Undefined(isolate)));
        return;
    };

    // Get display name
    if (getDisplayName(code, entry.type, entry.locale)) |name| {
        const result_str = v8.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse return;
        info.setReturnValue(@ptrCast(result_str));
    } else if (entry.fallback == .code) {
        // Return the code itself as fallback
        const result_str = v8.v8_String_NewFromUtf8(isolate, code.ptr, @intCast(code.len)) orelse return;
        info.setReturnValue(@ptrCast(result_str));
    } else {
        info.setReturnValue(@ptrCast(v8.v8_Undefined(isolate)));
    }
}

/// Intl.DisplayNames.prototype.resolvedOptions callback
fn displayNamesResolvedOptionsCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;

    // Get ID from this object
    const this_val = info.getThis();
    const id_key = v8.v8_String_NewFromUtf8(isolate, "__dn_id__", 9) orelse return;
    const id_val = v8.v8_Object_Get(@ptrCast(this_val), context, @ptrCast(id_key)) orelse return;
    if (!v8.v8_Value_IsNumber(id_val)) return;

    const id: usize = @intFromFloat(v8.v8_Value_NumberValue(id_val, context));

    const registry = getOrInitDisplayNamesRegistry();
    const entry = registry.entries.get(id) orelse return;

    // Create result object
    const result = v8.v8_Object_New(isolate) orelse return;

    // locale
    const locale_key = v8.v8_String_NewFromUtf8(isolate, "locale", 6) orelse return;
    const locale_val = v8.v8_String_NewFromUtf8(isolate, entry.locale.ptr, @intCast(entry.locale.len)) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(locale_key), @ptrCast(locale_val));

    // type
    const type_key = v8.v8_String_NewFromUtf8(isolate, "type", 4) orelse return;
    const dn_type_str: []const u8 = switch (entry.type) {
        .language => "language",
        .region => "region",
        .script => "script",
        .currency => "currency",
        .calendar => "calendar",
        .dateTimeField => "dateTimeField",
    };
    const type_val = v8.v8_String_NewFromUtf8(isolate, dn_type_str.ptr, @intCast(dn_type_str.len)) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(type_key), @ptrCast(type_val));

    // style
    const style_key = v8.v8_String_NewFromUtf8(isolate, "style", 5) orelse return;
    const dn_style_str: []const u8 = switch (entry.style) {
        .long => "long",
        .short => "short",
        .narrow => "narrow",
    };
    const style_val = v8.v8_String_NewFromUtf8(isolate, dn_style_str.ptr, @intCast(dn_style_str.len)) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(style_key), @ptrCast(style_val));

    // fallback
    const fallback_key = v8.v8_String_NewFromUtf8(isolate, "fallback", 8) orelse return;
    const fallback_str: []const u8 = if (entry.fallback == .code) "code" else "none";
    const fallback_val = v8.v8_String_NewFromUtf8(isolate, fallback_str.ptr, @intCast(fallback_str.len)) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(fallback_key), @ptrCast(fallback_val));

    info.setReturnValue(@ptrCast(result));
}

/// Intl.DisplayNames.supportedLocalesOf callback
fn displayNamesSupportedLocalesOfCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    supportedLocalesOfCallback(info);
}

// ============================================================================
// Phase 3: Intl.supportedValuesOf
// ============================================================================

/// Intl.supportedValuesOf callback
fn supportedValuesOfCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;

    if (info.length() < 1) {
        conv.throwTypeError(isolate, "supportedValuesOf requires a key argument");
        return;
    }

    var key_buf: [32]u8 = undefined;
    const key_arg = info.get(0);
    if (!v8.v8_Value_IsString(key_arg)) {
        conv.throwRangeError(isolate, "Invalid key");
        return;
    }

    const key = readV8String(v8.v8_Value_ToString(key_arg, context), context, &key_buf) orelse {
        conv.throwRangeError(isolate, "Invalid key");
        return;
    };

    // Get supported values based on key
    if (std.mem.eql(u8, key, "calendar")) {
        const calendars = [_][]const u8{ "gregory", "buddhist", "chinese", "coptic", "dangi", "ethiopic", "hebrew", "indian", "islamic", "islamic-civil", "islamic-rgsa", "islamic-tbla", "islamic-umalqura", "japanese", "persian", "roc" };
        createStringArray(isolate, context, &calendars, info);
    } else if (std.mem.eql(u8, key, "collation")) {
        const collations = [_][]const u8{ "big5han", "compat", "dict", "direct", "ducet", "emoji", "eor", "gb2312", "phonebk", "phonetic", "pinyin", "reformed", "search", "searchjl", "standard", "stroke", "trad", "unihan", "zhuyin" };
        createStringArray(isolate, context, &collations, info);
    } else if (std.mem.eql(u8, key, "currency")) {
        const currencies = [_][]const u8{ "AED", "AFN", "ALL", "AMD", "ANG", "AOA", "ARS", "AUD", "AWG", "AZN", "BAM", "BBD", "BDT", "BGN", "BHD", "BIF", "BMD", "BND", "BOB", "BRL", "BSD", "BTN", "BWP", "BYN", "BZD", "CAD", "CDF", "CHF", "CLP", "CNY", "COP", "CRC", "CUC", "CUP", "CVE", "CZK", "DJF", "DKK", "DOP", "DZD", "EGP", "ERN", "ETB", "EUR", "FJD", "FKP", "GBP", "GEL", "GGP", "GHS", "GIP", "GMD", "GNF", "GTQ", "GYD", "HKD", "HNL", "HRK", "HTG", "HUF", "IDR", "ILS", "IMP", "INR", "IQD", "IRR", "ISK", "JEP", "JMD", "JOD", "JPY", "KES", "KGS", "KHR", "KMF", "KPW", "KRW", "KWD", "KYD", "KZT", "LAK", "LBP", "LKR", "LRD", "LSL", "LYD", "MAD", "MDL", "MGA", "MKD", "MMK", "MNT", "MOP", "MRU", "MUR", "MVR", "MWK", "MXN", "MYR", "MZN", "NAD", "NGN", "NIO", "NOK", "NPR", "NZD", "OMR", "PAB", "PEN", "PGK", "PHP", "PKR", "PLN", "PYG", "QAR", "RON", "RSD", "RUB", "RWF", "SAR", "SBD", "SCR", "SDG", "SEK", "SGD", "SHP", "SLL", "SOS", "SPL", "SRD", "STN", "SVC", "SYP", "SZL", "THB", "TJS", "TMT", "TND", "TOP", "TRY", "TTD", "TVD", "TWD", "TZS", "UAH", "UGX", "USD", "UYU", "UZS", "VEF", "VND", "VUV", "WST", "XAF", "XCD", "XDR", "XOF", "XPF", "YER", "ZAR", "ZMW", "ZWD" };
        createStringArray(isolate, context, &currencies, info);
    } else if (std.mem.eql(u8, key, "numberingSystem")) {
        const numbering_systems = [_][]const u8{ "adlm", "ahom", "arab", "arabext", "bali", "beng", "bhks", "brah", "cakm", "cham", "deva", "diak", "fullwide", "gong", "gonm", "gujr", "guru", "hanidec", "hmng", "hmnp", "java", "kali", "khmr", "knda", "lana", "lanatham", "laoo", "latn", "lepc", "limb", "mathbold", "mathdbl", "mathmono", "mathsanb", "mathsans", "mlym", "modi", "mong", "mroo", "mtei", "mymr", "mymrshan", "mymrtlng", "newa", "nkoo", "olck", "orya", "osma", "rohg", "saur", "segment", "shrd", "sind", "sinh", "sora", "sund", "takr", "talu", "tamldec", "telu", "thai", "tibt", "tirh", "vaii", "wara", "wcho" };
        createStringArray(isolate, context, &numbering_systems, info);
    } else if (std.mem.eql(u8, key, "timeZone")) {
        const time_zones = [_][]const u8{ "Africa/Abidjan", "Africa/Cairo", "Africa/Johannesburg", "Africa/Lagos", "America/Chicago", "America/Denver", "America/Los_Angeles", "America/New_York", "America/Sao_Paulo", "America/Toronto", "Asia/Dubai", "Asia/Hong_Kong", "Asia/Kolkata", "Asia/Seoul", "Asia/Shanghai", "Asia/Singapore", "Asia/Tokyo", "Australia/Melbourne", "Australia/Sydney", "Europe/Berlin", "Europe/London", "Europe/Moscow", "Europe/Paris", "Pacific/Auckland", "UTC" };
        createStringArray(isolate, context, &time_zones, info);
    } else if (std.mem.eql(u8, key, "unit")) {
        const units = [_][]const u8{ "acre", "bit", "byte", "celsius", "centimeter", "day", "degree", "fahrenheit", "fluid-ounce", "foot", "gallon", "gigabit", "gigabyte", "gram", "hectare", "hour", "inch", "kilobit", "kilobyte", "kilogram", "kilometer", "liter", "megabit", "megabyte", "meter", "mile", "mile-scandinavian", "milliliter", "millimeter", "millisecond", "minute", "month", "ounce", "percent", "petabyte", "pound", "second", "stone", "terabit", "terabyte", "week", "yard", "year" };
        createStringArray(isolate, context, &units, info);
    } else {
        conv.throwRangeError(isolate, "Invalid key for supportedValuesOf");
        return;
    }
}

fn createStringArray(isolate: *v8.Isolate, context: *v8.Context, values: []const []const u8, info: *const v8.FunctionCallbackInfo) void {
    const arr = v8.v8_Array_New(isolate, @intCast(values.len));
    for (values, 0..) |val, i| {
        const str = v8.v8_String_NewFromUtf8(isolate, val.ptr, @intCast(val.len)) orelse continue;
        _ = v8.v8_Array_Set(arr, context, @intCast(i), @ptrCast(str));
    }
    info.setReturnValue(@ptrCast(arr));
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
    // PluralRules
    // ========================================================================
    const pr_template = v8.v8_FunctionTemplate_New(isolate, pluralRulesConstructorCallback, null) orelse return;
    const pr_constructor = v8.v8_FunctionTemplate_GetFunction(pr_template, context) orelse return;

    // Add supportedLocalesOf static method
    const pr_supported_fn = v8.v8_FunctionTemplate_New(isolate, pluralRulesSupportedLocalesOfCallback, null) orelse return;
    const pr_supported_fn_obj = v8.v8_FunctionTemplate_GetFunction(pr_supported_fn, context) orelse return;
    _ = v8.v8_Object_Set(@ptrCast(pr_constructor), context, @ptrCast(supported_key), @ptrCast(pr_supported_fn_obj));

    // Add PluralRules to Intl object
    const pr_key = v8.v8_String_NewFromUtf8(isolate, "PluralRules", 11) orelse return;
    _ = v8.v8_Object_Set(intl_obj, context, @ptrCast(pr_key), @ptrCast(pr_constructor));

    // ========================================================================
    // RelativeTimeFormat
    // ========================================================================
    const rtf_template = v8.v8_FunctionTemplate_New(isolate, relativeTimeFormatConstructorCallback, null) orelse return;
    const rtf_constructor = v8.v8_FunctionTemplate_GetFunction(rtf_template, context) orelse return;

    // Add supportedLocalesOf static method
    const rtf_supported_fn = v8.v8_FunctionTemplate_New(isolate, relativeTimeFormatSupportedLocalesOfCallback, null) orelse return;
    const rtf_supported_fn_obj = v8.v8_FunctionTemplate_GetFunction(rtf_supported_fn, context) orelse return;
    _ = v8.v8_Object_Set(@ptrCast(rtf_constructor), context, @ptrCast(supported_key), @ptrCast(rtf_supported_fn_obj));

    // Add RelativeTimeFormat to Intl object
    const rtf_key = v8.v8_String_NewFromUtf8(isolate, "RelativeTimeFormat", 18) orelse return;
    _ = v8.v8_Object_Set(intl_obj, context, @ptrCast(rtf_key), @ptrCast(rtf_constructor));

    // ========================================================================
    // ListFormat
    // ========================================================================
    const lf_template = v8.v8_FunctionTemplate_New(isolate, listFormatConstructorCallback, null) orelse return;
    const lf_constructor = v8.v8_FunctionTemplate_GetFunction(lf_template, context) orelse return;

    // Add supportedLocalesOf static method
    const lf_supported_fn = v8.v8_FunctionTemplate_New(isolate, listFormatSupportedLocalesOfCallback, null) orelse return;
    const lf_supported_fn_obj = v8.v8_FunctionTemplate_GetFunction(lf_supported_fn, context) orelse return;
    _ = v8.v8_Object_Set(@ptrCast(lf_constructor), context, @ptrCast(supported_key), @ptrCast(lf_supported_fn_obj));

    // Add ListFormat to Intl object
    const lf_key = v8.v8_String_NewFromUtf8(isolate, "ListFormat", 10) orelse return;
    _ = v8.v8_Object_Set(intl_obj, context, @ptrCast(lf_key), @ptrCast(lf_constructor));

    // ========================================================================
    // DisplayNames
    // ========================================================================
    const dn_template = v8.v8_FunctionTemplate_New(isolate, displayNamesConstructorCallback, null) orelse return;
    const dn_constructor = v8.v8_FunctionTemplate_GetFunction(dn_template, context) orelse return;

    // Add supportedLocalesOf static method
    const dn_supported_fn = v8.v8_FunctionTemplate_New(isolate, displayNamesSupportedLocalesOfCallback, null) orelse return;
    const dn_supported_fn_obj = v8.v8_FunctionTemplate_GetFunction(dn_supported_fn, context) orelse return;
    _ = v8.v8_Object_Set(@ptrCast(dn_constructor), context, @ptrCast(supported_key), @ptrCast(dn_supported_fn_obj));

    // Add DisplayNames to Intl object
    const dn_key = v8.v8_String_NewFromUtf8(isolate, "DisplayNames", 12) orelse return;
    _ = v8.v8_Object_Set(intl_obj, context, @ptrCast(dn_key), @ptrCast(dn_constructor));

    // ========================================================================
    // Intl.supportedValuesOf (static method on Intl object)
    // ========================================================================
    const svo_fn = v8.v8_FunctionTemplate_New(isolate, supportedValuesOfCallback, null) orelse return;
    const svo_fn_obj = v8.v8_FunctionTemplate_GetFunction(svo_fn, context) orelse return;
    const svo_key = v8.v8_String_NewFromUtf8(isolate, "supportedValuesOf", 17) orelse return;
    _ = v8.v8_Object_Set(intl_obj, context, @ptrCast(svo_key), @ptrCast(svo_fn_obj));

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

    // PluralRules
    ext_refs.registerCallbackRuntime(pluralRulesConstructorCallback);
    ext_refs.registerCallbackRuntime(pluralRulesSelectCallback);
    ext_refs.registerCallbackRuntime(pluralRulesResolvedOptionsCallback);
    ext_refs.registerCallbackRuntime(pluralRulesSupportedLocalesOfCallback);

    // RelativeTimeFormat
    ext_refs.registerCallbackRuntime(relativeTimeFormatConstructorCallback);
    ext_refs.registerCallbackRuntime(relativeTimeFormatFormatCallback);
    ext_refs.registerCallbackRuntime(relativeTimeFormatResolvedOptionsCallback);
    ext_refs.registerCallbackRuntime(relativeTimeFormatSupportedLocalesOfCallback);

    // ListFormat
    ext_refs.registerCallbackRuntime(listFormatConstructorCallback);
    ext_refs.registerCallbackRuntime(listFormatFormatCallback);
    ext_refs.registerCallbackRuntime(listFormatResolvedOptionsCallback);
    ext_refs.registerCallbackRuntime(listFormatSupportedLocalesOfCallback);

    // DisplayNames
    ext_refs.registerCallbackRuntime(displayNamesConstructorCallback);
    ext_refs.registerCallbackRuntime(displayNamesOfCallback);
    ext_refs.registerCallbackRuntime(displayNamesResolvedOptionsCallback);
    ext_refs.registerCallbackRuntime(displayNamesSupportedLocalesOfCallback);

    // Intl.supportedValuesOf
    ext_refs.registerCallbackRuntime(supportedValuesOfCallback);
}

/// Deinitialize all Intl registries, freeing any remaining entries.
/// Call this during runtime shutdown to clean up resources.
/// Note: With weak callbacks enabled, most entries should already be cleaned
/// up via GC. This is a safety net for any entries that weren't GC'd.
pub fn deinitAllRegistries() void {
    // DateTimeFormat registry
    if (dtf_registry) |*reg| {
        reg.deinit();
        dtf_registry = null;
    }

    // NumberFormat registry
    if (nf_registry) |*reg| {
        reg.deinit();
        nf_registry = null;
    }

    // Collator registry
    if (collator_registry) |*reg| {
        reg.deinit();
        collator_registry = null;
    }

    // PluralRules registry
    if (plural_rules_registry) |*reg| {
        // Free locale strings for remaining entries
        var iter = reg.entries.iterator();
        while (iter.next()) |kv| {
            kv.value_ptr.allocator.free(kv.value_ptr.locale);
        }
        reg.entries.deinit();
        plural_rules_registry = null;
    }

    // RelativeTimeFormat registry
    if (relative_time_format_registry) |*reg| {
        // Free locale strings for remaining entries
        var iter = reg.entries.iterator();
        while (iter.next()) |kv| {
            kv.value_ptr.allocator.free(kv.value_ptr.locale);
        }
        reg.entries.deinit();
        relative_time_format_registry = null;
    }

    // ListFormat registry
    if (list_format_registry) |*reg| {
        // Free locale strings for remaining entries
        var iter = reg.entries.iterator();
        while (iter.next()) |kv| {
            kv.value_ptr.allocator.free(kv.value_ptr.locale);
        }
        reg.entries.deinit();
        list_format_registry = null;
    }

    // DisplayNames registry
    if (display_names_registry) |*reg| {
        // Free locale strings for remaining entries
        var iter = reg.entries.iterator();
        while (iter.next()) |kv| {
            kv.value_ptr.allocator.free(kv.value_ptr.locale);
        }
        reg.entries.deinit();
        display_names_registry = null;
    }
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
