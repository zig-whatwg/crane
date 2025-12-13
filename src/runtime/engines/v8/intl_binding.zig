//! V8 Binding for Pure Zig Intl API
//!
//! This module wires the pure Zig internationalization library to V8,
//! creating the `Intl` global object with `DateTimeFormat` and other formatters.
//!
//! ## Design
//!
//! - Creates `Intl` namespace object on global
//! - `Intl.DateTimeFormat` is a constructor function
//! - DateTimeFormat instances are stored via V8 internal fields
//! - Memory is managed via weak callbacks (GC triggers Zig deinit)
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

// ============================================================================
// DateTime Helper (inlined to avoid module dependency)
// ============================================================================

/// Simple DateTime struct for formatting
const DateTime = struct {
    year: i32,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    second: u8,

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
};

// ============================================================================
// DateTimeFormat Instance Storage
// ============================================================================

/// Internal storage for DateTimeFormat instances
/// We use a simple handle-based system where V8 objects store an index
/// into this registry.
const DateTimeFormatRegistry = struct {
    const Entry = struct {
        locale: []const u8,
        options_json: ?[]const u8,
        allocator: std.mem.Allocator,

        fn deinit(self: *Entry) void {
            self.allocator.free(self.locale);
            if (self.options_json) |json| {
                self.allocator.free(json);
            }
        }
    };

    // Zig 0.15: ArrayList is unmanaged by default
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
// DateTimeFormat Constructor Callback
// ============================================================================

/// Callback for `new Intl.DateTimeFormat(locales, options)`
fn dateTimeFormatConstructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };

    // Get locale argument (required for now, defaults to 'en-US')
    var locale_buf: [64]u8 = undefined;
    var locale: []const u8 = "en-US";

    if (info.length() > 0) {
        const locale_arg = info.get(0);
        if (v8.v8_Value_IsString(locale_arg)) {
            const str = v8.v8_Value_ToString(locale_arg, context);
            if (str) |s| {
                const len = v8.v8_String_Utf8Length(s);
                if (len > 0 and len < locale_buf.len) {
                    const written = v8.v8_String_WriteUtf8(s, &locale_buf, @intCast(locale_buf.len));
                    // V8's WriteUtf8 includes null terminator in count, subtract 1
                    if (written > 1) {
                        locale = locale_buf[0..@intCast(written - 1)];
                    } else if (written == 1) {
                        // Empty string with just null terminator
                        locale = "";
                    }
                }
            }
        }
    }

    // Get options argument (optional)
    // TODO: Serialize options object to JSON for CLDR pattern selection
    const options_json: ?[]const u8 = null;

    // Create entry in registry
    const registry = getOrInitRegistry();
    const allocator = std.heap.page_allocator;

    const locale_copy = allocator.dupe(u8, locale) catch {
        conv.throwTypeError(isolate, "Out of memory");
        return;
    };

    const entry = DateTimeFormatRegistry.Entry{
        .locale = locale_copy,
        .options_json = options_json,
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

    // Store the registry index in the object
    // We use a hidden property for this
    const idx_key = v8.v8_String_NewFromUtf8(isolate, "__dtf_idx__", 11) orelse {
        registry.remove(idx);
        conv.throwTypeError(isolate, "Failed to create index key");
        return;
    };
    const idx_value = v8.v8_Number_New(isolate, @floatFromInt(idx));
    _ = v8.v8_Object_Set(result, context, @ptrCast(idx_key), @ptrCast(idx_value));

    // Add format method
    const format_fn = v8.v8_FunctionTemplate_New(isolate, dateTimeFormatFormatCallback, @ptrCast(result)) orelse {
        registry.remove(idx);
        conv.throwTypeError(isolate, "Failed to create format function");
        return;
    };
    const format_fn_obj = v8.v8_FunctionTemplate_GetFunction(format_fn, context) orelse {
        registry.remove(idx);
        conv.throwTypeError(isolate, "Failed to get format function");
        return;
    };
    const format_key = v8.v8_String_NewFromUtf8(isolate, "format", 6) orelse {
        registry.remove(idx);
        conv.throwTypeError(isolate, "Failed to create format key");
        return;
    };
    _ = v8.v8_Object_Set(result, context, @ptrCast(format_key), @ptrCast(format_fn_obj));

    // Add formatToParts method
    const parts_fn = v8.v8_FunctionTemplate_New(isolate, dateTimeFormatToPartsCallback, @ptrCast(result)) orelse {
        registry.remove(idx);
        return;
    };
    const parts_fn_obj = v8.v8_FunctionTemplate_GetFunction(parts_fn, context) orelse {
        registry.remove(idx);
        return;
    };
    const parts_key = v8.v8_String_NewFromUtf8(isolate, "formatToParts", 13) orelse {
        registry.remove(idx);
        return;
    };
    _ = v8.v8_Object_Set(result, context, @ptrCast(parts_key), @ptrCast(parts_fn_obj));

    // Add resolvedOptions method
    const opts_fn = v8.v8_FunctionTemplate_New(isolate, dateTimeFormatResolvedOptionsCallback, @ptrCast(result)) orelse {
        registry.remove(idx);
        return;
    };
    const opts_fn_obj = v8.v8_FunctionTemplate_GetFunction(opts_fn, context) orelse {
        registry.remove(idx);
        return;
    };
    const opts_key = v8.v8_String_NewFromUtf8(isolate, "resolvedOptions", 15) orelse {
        registry.remove(idx);
        return;
    };
    _ = v8.v8_Object_Set(result, context, @ptrCast(opts_key), @ptrCast(opts_fn_obj));

    // Return the DateTimeFormat object
    info.setReturnValue(@ptrCast(result));
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

    // Get `this` object to find the registry index
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

    // Get the date argument
    // Note: V8 Date functions not available in FFI yet, so we only accept timestamps
    // In JavaScript, use: dtf.format(date.getTime()) or dtf.format(Date.now())
    var timestamp_ms: i64 = 0;
    if (info.length() > 0) {
        const date_arg = info.get(0);
        if (v8.v8_Value_IsNumber(date_arg)) {
            timestamp_ms = @intFromFloat(v8.v8_Value_NumberValue(date_arg, context));
        } else {
            // Use current time for non-numeric input
            timestamp_ms = std.time.milliTimestamp();
        }
    } else {
        // No argument - use current time
        timestamp_ms = std.time.milliTimestamp();
    }

    // Format using the Zig intl library
    const dt = DateTime.fromTimestampMillis(timestamp_ms);

    // Build a simple formatted string based on locale
    // TODO: Use actual CLDR patterns based on locale and options
    var buf: [128]u8 = undefined;

    // Check locale to determine format
    // For now: en-US uses M/D/YYYY, others use YYYY-MM-DD
    const is_us_format = std.mem.startsWith(u8, entry.locale, "en-US") or
        std.mem.startsWith(u8, entry.locale, "en_US");

    const formatted = if (is_us_format)
        std.fmt.bufPrint(&buf, "{d}/{d}/{d}, {d}:{d:0>2}:{d:0>2} {s}", .{
            dt.month,
            dt.day,
            @as(u32, @intCast(dt.year)),
            if (dt.hour == 0) @as(u8, 12) else if (dt.hour > 12) dt.hour - 12 else dt.hour,
            dt.minute,
            dt.second,
            if (dt.hour < 12) "AM" else "PM",
        }) catch {
            conv.throwTypeError(isolate, "Format buffer overflow");
            return;
        }
    else
        std.fmt.bufPrint(&buf, "{d}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{
            @as(u32, @intCast(dt.year)),
            dt.month,
            dt.day,
            dt.hour,
            dt.minute,
            dt.second,
        }) catch {
            conv.throwTypeError(isolate, "Format buffer overflow");
            return;
        };

    // Create V8 string result
    const result_str = v8.v8_String_NewFromUtf8(isolate, formatted.ptr, @intCast(formatted.len)) orelse {
        conv.throwTypeError(isolate, "Failed to create result string");
        return;
    };

    info.setReturnValue(@ptrCast(result_str));
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

    // Get `this` object
    const this_obj = info.getThis();
    const idx = getDateTimeFormatIndex(isolate, context, this_obj) orelse {
        conv.throwTypeError(isolate, "Invalid DateTimeFormat object");
        return;
    };

    const registry = getOrInitRegistry();
    _ = registry.get(idx) orelse {
        conv.throwTypeError(isolate, "DateTimeFormat not found");
        return;
    };

    // Get the date argument
    // Note: V8 Date functions not available in FFI yet, so we only accept timestamps
    var timestamp_ms: i64 = 0;
    if (info.length() > 0) {
        const date_arg = info.get(0);
        if (v8.v8_Value_IsNumber(date_arg)) {
            timestamp_ms = @intFromFloat(v8.v8_Value_NumberValue(date_arg, context));
        } else {
            timestamp_ms = std.time.milliTimestamp();
        }
    } else {
        timestamp_ms = std.time.milliTimestamp();
    }

    const dt = DateTime.fromTimestampMillis(timestamp_ms);

    // Create array of parts
    // TODO: Use actual CLDR patterns for proper part breakdown
    const result_array = v8.v8_Array_New(isolate, 11);

    // Helper to add a part
    const Part = struct {
        fn add(iso: *v8.Isolate, ctx: *v8.Context, arr: *v8.Array, index: u32, part_type: []const u8, value: []const u8) void {
            const part_obj = v8.v8_Object_New(iso) orelse return;

            const type_key = v8.v8_String_NewFromUtf8(iso, "type", 4) orelse return;
            const type_val = v8.v8_String_NewFromUtf8(iso, part_type.ptr, @intCast(part_type.len)) orelse return;
            _ = v8.v8_Object_Set(part_obj, ctx, @ptrCast(type_key), @ptrCast(type_val));

            const value_key = v8.v8_String_NewFromUtf8(iso, "value", 5) orelse return;
            const value_val = v8.v8_String_NewFromUtf8(iso, value.ptr, @intCast(value.len)) orelse return;
            _ = v8.v8_Object_Set(part_obj, ctx, @ptrCast(value_key), @ptrCast(value_val));

            _ = v8.v8_Array_Set(arr, ctx, index, @ptrCast(part_obj));
        }
    };

    var year_buf: [8]u8 = undefined;
    var month_buf: [4]u8 = undefined;
    var day_buf: [4]u8 = undefined;
    var hour_buf: [4]u8 = undefined;
    var minute_buf: [4]u8 = undefined;
    var second_buf: [4]u8 = undefined;

    const year_str = std.fmt.bufPrint(&year_buf, "{d}", .{dt.year}) catch "0";
    const month_str = std.fmt.bufPrint(&month_buf, "{d:0>2}", .{dt.month}) catch "0";
    const day_str = std.fmt.bufPrint(&day_buf, "{d:0>2}", .{dt.day}) catch "0";
    const hour_str = std.fmt.bufPrint(&hour_buf, "{d:0>2}", .{dt.hour}) catch "0";
    const minute_str = std.fmt.bufPrint(&minute_buf, "{d:0>2}", .{dt.minute}) catch "0";
    const second_str = std.fmt.bufPrint(&second_buf, "{d:0>2}", .{dt.second}) catch "0";

    Part.add(isolate, context, result_array, 0, "year", year_str);
    Part.add(isolate, context, result_array, 1, "literal", "-");
    Part.add(isolate, context, result_array, 2, "month", month_str);
    Part.add(isolate, context, result_array, 3, "literal", "-");
    Part.add(isolate, context, result_array, 4, "day", day_str);
    Part.add(isolate, context, result_array, 5, "literal", " ");
    Part.add(isolate, context, result_array, 6, "hour", hour_str);
    Part.add(isolate, context, result_array, 7, "literal", ":");
    Part.add(isolate, context, result_array, 8, "minute", minute_str);
    Part.add(isolate, context, result_array, 9, "literal", ":");
    Part.add(isolate, context, result_array, 10, "second", second_str);

    info.setReturnValue(@ptrCast(result_array));
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

    // Get `this` object
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
    const locale_key = v8.v8_String_NewFromUtf8(isolate, "locale", 6) orelse return;
    const locale_val = v8.v8_String_NewFromUtf8(isolate, entry.locale.ptr, @intCast(entry.locale.len)) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(locale_key), @ptrCast(locale_val));

    // Set calendar (default: gregory)
    const cal_key = v8.v8_String_NewFromUtf8(isolate, "calendar", 8) orelse return;
    const cal_val = v8.v8_String_NewFromUtf8(isolate, "gregory", 7) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(cal_key), @ptrCast(cal_val));

    // Set numberingSystem (default: latn)
    const num_key = v8.v8_String_NewFromUtf8(isolate, "numberingSystem", 15) orelse return;
    const num_val = v8.v8_String_NewFromUtf8(isolate, "latn", 4) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(num_key), @ptrCast(num_val));

    // Set timeZone (default: UTC)
    const tz_key = v8.v8_String_NewFromUtf8(isolate, "timeZone", 8) orelse return;
    const tz_val = v8.v8_String_NewFromUtf8(isolate, "UTC", 3) orelse return;
    _ = v8.v8_Object_Set(result, context, @ptrCast(tz_key), @ptrCast(tz_val));

    info.setReturnValue(@ptrCast(result));
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

    // For now, return a simple array with supported locales
    // TODO: Actually filter based on input locales
    const result = v8.v8_Array_New(isolate, 2);

    const en = v8.v8_String_NewFromUtf8(isolate, "en", 2) orelse return;
    const en_us = v8.v8_String_NewFromUtf8(isolate, "en-US", 5) orelse return;

    _ = v8.v8_Array_Set(result, context, 0, @ptrCast(en));
    _ = v8.v8_Array_Set(result, context, 1, @ptrCast(en_us));

    info.setReturnValue(@ptrCast(result));
}

// ============================================================================
// Public API
// ============================================================================

/// Register the Intl global object with V8
///
/// Creates the `Intl` namespace with:
/// - `Intl.DateTimeFormat` constructor
/// - `Intl.DateTimeFormat.supportedLocalesOf()` static method
///
/// ## Usage
///
/// ```zig
/// intl_binding.registerGlobal(isolate, context);
/// // Now JavaScript has access to Intl.DateTimeFormat
/// ```
pub fn registerGlobal(isolate: *v8.Isolate, context: *v8.Context) void {
    // Create Intl namespace object
    const intl_obj = v8.v8_Object_New(isolate) orelse return;

    // Create DateTimeFormat constructor
    const dtf_template = v8.v8_FunctionTemplate_New(isolate, dateTimeFormatConstructorCallback, null) orelse return;
    const dtf_constructor = v8.v8_FunctionTemplate_GetFunction(dtf_template, context) orelse return;

    // Add supportedLocalesOf static method to DateTimeFormat
    const supported_fn = v8.v8_FunctionTemplate_New(isolate, supportedLocalesOfCallback, null) orelse return;
    const supported_fn_obj = v8.v8_FunctionTemplate_GetFunction(supported_fn, context) orelse return;
    const supported_key = v8.v8_String_NewFromUtf8(isolate, "supportedLocalesOf", 18) orelse return;
    _ = v8.v8_Object_Set(@ptrCast(dtf_constructor), context, @ptrCast(supported_key), @ptrCast(supported_fn_obj));

    // Add DateTimeFormat to Intl object
    const dtf_key = v8.v8_String_NewFromUtf8(isolate, "DateTimeFormat", 14) orelse return;
    _ = v8.v8_Object_Set(intl_obj, context, @ptrCast(dtf_key), @ptrCast(dtf_constructor));

    // Add Intl to global object
    const global = v8.v8_Context_Global(context) orelse return;
    const intl_key = v8.v8_String_NewFromUtf8(isolate, "Intl", 4) orelse return;

    // Per spec, Intl should be writable, non-enumerable, configurable
    _ = v8.v8_Object_DefineProperty(
        global,
        context,
        @ptrCast(intl_key),
        @ptrCast(intl_obj),
        true, // writable
        false, // enumerable (false per spec)
        true, // configurable
    );
}

/// Register external references for V8 snapshots
///
/// Must be called before creating a V8 snapshot.
pub fn registerExternalReferences() void {
    const ext_refs = @import("external_references.zig");

    ext_refs.registerCallbackRuntime(dateTimeFormatConstructorCallback);
    ext_refs.registerCallbackRuntime(dateTimeFormatFormatCallback);
    ext_refs.registerCallbackRuntime(dateTimeFormatToPartsCallback);
    ext_refs.registerCallbackRuntime(dateTimeFormatResolvedOptionsCallback);
    ext_refs.registerCallbackRuntime(supportedLocalesOfCallback);
}

// ============================================================================
// Tests
// ============================================================================

test "intl_binding compiles" {
    const testing = std.testing;
    testing.refAllDecls(@This());
}
