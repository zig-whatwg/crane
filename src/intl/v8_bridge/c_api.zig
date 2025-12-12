//! C-Compatible API for V8-Zig i18n Bridge
//!
//! This module provides C-compatible exports for the Zig i18n library,
//! allowing V8 (or any C/C++ code) to use our Intl implementations via FFI.
//!
//! ## Design Principles
//!
//! ### Memory Management (CRITICAL)
//! - V8 manages JS object lifecycle
//! - Zig manages i18n object lifecycle
//! - Every `*_create` has a corresponding `*_destroy`
//! - Use weak callbacks in V8 for automatic cleanup
//! - NO global caches (this is why we're replacing ICU!)
//!
//! ### Error Handling
//! - Return null/negative values for errors
//! - Use `intl_get_last_error()` for error details
//! - Errors are thread-local (no global error state)
//!
//! ### Thread Safety
//! - Each Intl object is independent (no shared mutable state)
//! - Safe to use from multiple V8 isolates concurrently
//! - Allocator is passed per-call, not stored globally
//!
//! ## Usage Pattern (C++ side)
//!
//! ```cpp
//! // Create formatter
//! auto* dtf = intl_datetime_format_create("en-US", options_json);
//! if (!dtf) {
//!     const char* err = intl_get_last_error();
//!     // Handle error
//! }
//!
//! // Format date
//! char buffer[256];
//! int32_t len = intl_datetime_format_format(dtf, timestamp_ms, buffer, sizeof(buffer));
//! if (len < 0) {
//!     // Handle error
//! }
//!
//! // Cleanup (typically in weak callback)
//! intl_datetime_format_destroy(dtf);
//! ```
//!
//! ## V8 Weak Callback Integration
//!
//! ```cpp
//! void CleanupCallback(const v8::WeakCallbackInfo<DateTimeFormat>& data) {
//!     intl_datetime_format_destroy(data.GetParameter());
//! }
//!
//! // When creating JS wrapper:
//! persistent.SetWeak(dtf, CleanupCallback, v8::WeakCallbackType::kParameter);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const datetime = @import("../datetime/datetime.zig");
const DateTime = datetime.DateTime;
const locale_mod = @import("../locale/root.zig");

// ============================================================================
// Allocator Management
// ============================================================================

/// Global allocator for C API calls.
/// In a real implementation, this should be configurable or use a custom
/// allocator that integrates with the host environment's memory management.
var global_allocator: std.mem.Allocator = std.heap.page_allocator;

/// Thread-local error message storage
threadlocal var last_error: ?[]const u8 = null;

/// Set the allocator used for all C API calls.
/// Must be called before any other C API functions.
/// The allocator must remain valid for the lifetime of the program.
export fn intl_set_allocator(alloc_ptr: ?*anyopaque, alloc_fn: ?*const fn (?*anyopaque, usize, u8, usize) callconv(.C) ?[*]u8, free_fn: ?*const fn (?*anyopaque, [*]u8, usize, u8, usize) callconv(.C) void) void {
    if (alloc_fn != null and free_fn != null) {
        global_allocator = std.mem.Allocator{
            .ptr = alloc_ptr,
            .vtable = &.{
                .alloc = @ptrCast(alloc_fn),
                .resize = null,
                .free = @ptrCast(free_fn),
            },
        };
    }
}

// ============================================================================
// Error Handling
// ============================================================================

/// Error codes returned by C API functions
pub const IntlError = enum(i32) {
    /// No error
    ok = 0,
    /// Memory allocation failed
    out_of_memory = -1,
    /// Invalid locale string
    invalid_locale = -2,
    /// Invalid options
    invalid_options = -3,
    /// Invalid timestamp
    invalid_timestamp = -4,
    /// Buffer too small
    buffer_too_small = -5,
    /// Invalid UTF-8 in input
    invalid_utf8 = -6,
    /// Null pointer argument
    null_pointer = -7,
    /// Internal error
    internal_error = -100,
};

fn setError(msg: []const u8) void {
    last_error = msg;
}

/// Get the last error message (if any).
/// Returns null if no error occurred.
/// The returned string is valid until the next C API call on this thread.
export fn intl_get_last_error() ?[*:0]const u8 {
    if (last_error) |err| {
        // Return as null-terminated string
        // Note: In a full implementation, we'd manage this memory better
        return @ptrCast(err.ptr);
    }
    return null;
}

/// Clear the last error.
export fn intl_clear_error() void {
    last_error = null;
}

// ============================================================================
// DateTimeFormat C API
// ============================================================================

/// Opaque handle to a DateTimeFormat instance.
/// The actual type is not exposed to C code for safety.
pub const DateTimeFormatHandle = opaque {};

/// Internal DateTimeFormat wrapper that holds all state
const DateTimeFormatInternal = struct {
    allocator: Allocator,
    locale_tag: []const u8,
    // Parsed options (placeholder - will be expanded)
    time_zone: ?[]const u8,
    hour_cycle: ?locale_mod.HourCycle,
    // Cached pattern (placeholder)
    pattern: ?[]const u8,

    fn deinit(self: *DateTimeFormatInternal) void {
        if (self.locale_tag.len > 0) {
            self.allocator.free(self.locale_tag);
        }
        if (self.time_zone) |tz| {
            self.allocator.free(tz);
        }
        if (self.pattern) |p| {
            self.allocator.free(p);
        }
        self.allocator.destroy(self);
    }
};

/// Create a new DateTimeFormat instance.
///
/// ## Parameters
/// - `locale`: Null-terminated BCP 47 locale string (e.g., "en-US")
/// - `options_json`: Null-terminated JSON string with options, or null for defaults
///
/// ## Returns
/// - Opaque handle to the DateTimeFormat, or null on error
/// - On error, call `intl_get_last_error()` for details
///
/// ## Options JSON Format
/// ```json
/// {
///     "timeZone": "America/New_York",
///     "hourCycle": "h12",
///     "dateStyle": "full",
///     "timeStyle": "long",
///     "weekday": "long",
///     "year": "numeric",
///     "month": "long",
///     "day": "numeric",
///     "hour": "numeric",
///     "minute": "2-digit",
///     "second": "2-digit"
/// }
/// ```
///
/// ## Memory
/// The returned handle must be freed with `intl_datetime_format_destroy()`.
export fn intl_datetime_format_create(
    locale: ?[*:0]const u8,
    options_json: ?[*:0]const u8,
) ?*DateTimeFormatHandle {
    intl_clear_error();

    // Validate locale
    const locale_str = if (locale) |l| std.mem.span(l) else {
        setError("locale cannot be null");
        return null;
    };

    if (locale_str.len == 0) {
        setError("locale cannot be empty");
        return null;
    }

    // Allocate internal structure
    const internal = global_allocator.create(DateTimeFormatInternal) catch {
        setError("out of memory");
        return null;
    };

    // Copy locale string
    const locale_copy = global_allocator.dupe(u8, locale_str) catch {
        global_allocator.destroy(internal);
        setError("out of memory");
        return null;
    };

    internal.* = .{
        .allocator = global_allocator,
        .locale_tag = locale_copy,
        .time_zone = null,
        .hour_cycle = null,
        .pattern = null,
    };

    // Parse options JSON if provided
    if (options_json) |json| {
        const json_str = std.mem.span(json);
        if (json_str.len > 0) {
            // TODO: Parse JSON options
            // For now, just validate it looks like JSON
            if (json_str[0] != '{') {
                internal.deinit();
                setError("options must be a JSON object");
                return null;
            }
        }
    }

    return @ptrCast(internal);
}

/// Format a timestamp using the DateTimeFormat.
///
/// ## Parameters
/// - `dtf`: Handle from `intl_datetime_format_create()`
/// - `timestamp_ms`: Unix timestamp in milliseconds (JavaScript style)
/// - `out_buffer`: Buffer to receive the formatted string (UTF-8)
/// - `buffer_len`: Size of the buffer in bytes
///
/// ## Returns
/// - On success: Number of bytes written (not including null terminator)
/// - On error: Negative IntlError code
///
/// ## Notes
/// - The output is null-terminated if buffer is large enough
/// - If buffer is too small, returns IntlError.buffer_too_small
/// - The actual required size can be obtained by calling with buffer_len=0
export fn intl_datetime_format_format(
    dtf: ?*DateTimeFormatHandle,
    timestamp_ms: i64,
    out_buffer: ?[*]u8,
    buffer_len: usize,
) i32 {
    intl_clear_error();

    if (dtf == null) {
        setError("DateTimeFormat handle is null");
        return @intFromEnum(IntlError.null_pointer);
    }

    const internal: *DateTimeFormatInternal = @ptrCast(@alignCast(dtf));

    // Convert timestamp to DateTime
    const dt = DateTime.fromTimestampMillis(timestamp_ms);

    // Format to ISO 8601 as a placeholder
    // TODO: Use actual CLDR patterns based on locale and options
    const iso = dt.toIso8601();

    // Calculate required length (excluding trailing zeros from nanoseconds for cleaner output)
    // For now, use a simplified format: "YYYY-MM-DD HH:MM:SS"
    const formatted = std.fmt.allocPrint(internal.allocator, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{
        dt.year,
        dt.month,
        dt.day,
        dt.hour,
        dt.minute,
        dt.second,
    }) catch {
        setError("out of memory during formatting");
        return @intFromEnum(IntlError.out_of_memory);
    };
    defer internal.allocator.free(formatted);

    const required_len = formatted.len;

    // If buffer_len is 0, just return required size
    if (buffer_len == 0) {
        return @intCast(required_len);
    }

    // Check if buffer is large enough
    if (out_buffer == null) {
        setError("output buffer is null");
        return @intFromEnum(IntlError.null_pointer);
    }

    if (buffer_len < required_len + 1) {
        setError("buffer too small");
        return @intFromEnum(IntlError.buffer_too_small);
    }

    // Copy to output buffer
    const buf = out_buffer.?[0..buffer_len];
    @memcpy(buf[0..required_len], formatted);
    buf[required_len] = 0; // Null terminate

    _ = iso;
    return @intCast(required_len);
}

/// Format a timestamp to parts.
///
/// Returns a JSON array of parts, each with "type" and "value" fields.
///
/// ## Parameters
/// - `dtf`: Handle from `intl_datetime_format_create()`
/// - `timestamp_ms`: Unix timestamp in milliseconds
/// - `out_buffer`: Buffer to receive the JSON string
/// - `buffer_len`: Size of the buffer in bytes
///
/// ## Returns
/// - On success: Number of bytes written
/// - On error: Negative IntlError code
///
/// ## Output Format
/// ```json
/// [
///     {"type": "weekday", "value": "Monday"},
///     {"type": "literal", "value": ", "},
///     {"type": "month", "value": "January"},
///     {"type": "literal", "value": " "},
///     {"type": "day", "value": "1"},
///     {"type": "literal", "value": ", "},
///     {"type": "year", "value": "2024"}
/// ]
/// ```
export fn intl_datetime_format_format_to_parts(
    dtf: ?*DateTimeFormatHandle,
    timestamp_ms: i64,
    out_buffer: ?[*]u8,
    buffer_len: usize,
) i32 {
    intl_clear_error();

    if (dtf == null) {
        setError("DateTimeFormat handle is null");
        return @intFromEnum(IntlError.null_pointer);
    }

    const internal: *DateTimeFormatInternal = @ptrCast(@alignCast(dtf));

    // Convert timestamp to DateTime
    const dt = DateTime.fromTimestampMillis(timestamp_ms);

    // Build JSON parts array
    // TODO: Use actual CLDR patterns for proper part breakdown
    const parts_json = std.fmt.allocPrint(internal.allocator,
        \\[{{"type":"year","value":"{d}"}},{{"type":"literal","value":"-"}},{{"type":"month","value":"{d:0>2}"}},{{"type":"literal","value":"-"}},{{"type":"day","value":"{d:0>2}"}},{{"type":"literal","value":" "}},{{"type":"hour","value":"{d:0>2}"}},{{"type":"literal","value":":"}},{{"type":"minute","value":"{d:0>2}"}},{{"type":"literal","value":":"}},{{"type":"second","value":"{d:0>2}"}}]
    , .{
        dt.year,
        dt.month,
        dt.day,
        dt.hour,
        dt.minute,
        dt.second,
    }) catch {
        setError("out of memory during formatting");
        return @intFromEnum(IntlError.out_of_memory);
    };
    defer internal.allocator.free(parts_json);

    const required_len = parts_json.len;

    if (buffer_len == 0) {
        return @intCast(required_len);
    }

    if (out_buffer == null) {
        setError("output buffer is null");
        return @intFromEnum(IntlError.null_pointer);
    }

    if (buffer_len < required_len + 1) {
        setError("buffer too small");
        return @intFromEnum(IntlError.buffer_too_small);
    }

    const buf = out_buffer.?[0..buffer_len];
    @memcpy(buf[0..required_len], parts_json);
    buf[required_len] = 0;

    return @intCast(required_len);
}

/// Get resolved options as JSON.
///
/// ## Parameters
/// - `dtf`: Handle from `intl_datetime_format_create()`
/// - `out_buffer`: Buffer to receive the JSON string
/// - `buffer_len`: Size of the buffer in bytes
///
/// ## Returns
/// - On success: Number of bytes written
/// - On error: Negative IntlError code
export fn intl_datetime_format_resolved_options(
    dtf: ?*DateTimeFormatHandle,
    out_buffer: ?[*]u8,
    buffer_len: usize,
) i32 {
    intl_clear_error();

    if (dtf == null) {
        setError("DateTimeFormat handle is null");
        return @intFromEnum(IntlError.null_pointer);
    }

    const internal: *DateTimeFormatInternal = @ptrCast(@alignCast(dtf));

    // Build resolved options JSON
    const options_json = std.fmt.allocPrint(internal.allocator,
        \\{{"locale":"{s}","calendar":"gregory","numberingSystem":"latn","timeZone":"UTC"}}
    , .{internal.locale_tag}) catch {
        setError("out of memory");
        return @intFromEnum(IntlError.out_of_memory);
    };
    defer internal.allocator.free(options_json);

    const required_len = options_json.len;

    if (buffer_len == 0) {
        return @intCast(required_len);
    }

    if (out_buffer == null) {
        setError("output buffer is null");
        return @intFromEnum(IntlError.null_pointer);
    }

    if (buffer_len < required_len + 1) {
        setError("buffer too small");
        return @intFromEnum(IntlError.buffer_too_small);
    }

    const buf = out_buffer.?[0..buffer_len];
    @memcpy(buf[0..required_len], options_json);
    buf[required_len] = 0;

    return @intCast(required_len);
}

/// Destroy a DateTimeFormat instance and free all associated memory.
///
/// ## Parameters
/// - `dtf`: Handle from `intl_datetime_format_create()`, or null (no-op)
///
/// ## Notes
/// - Safe to call with null (no-op)
/// - Must not be called twice on the same handle
/// - Typically called from V8 weak callback
export fn intl_datetime_format_destroy(dtf: ?*DateTimeFormatHandle) void {
    if (dtf) |handle| {
        const internal: *DateTimeFormatInternal = @ptrCast(@alignCast(handle));
        internal.deinit();
    }
}

// ============================================================================
// NumberFormat C API (Placeholder)
// ============================================================================

/// Opaque handle to a NumberFormat instance.
pub const NumberFormatHandle = opaque {};

/// Create a new NumberFormat instance.
export fn intl_number_format_create(
    locale: ?[*:0]const u8,
    options_json: ?[*:0]const u8,
) ?*NumberFormatHandle {
    _ = locale;
    _ = options_json;
    setError("NumberFormat not yet implemented");
    return null;
}

/// Format a number.
export fn intl_number_format_format(
    nf: ?*NumberFormatHandle,
    value: f64,
    out_buffer: ?[*]u8,
    buffer_len: usize,
) i32 {
    _ = nf;
    _ = value;
    _ = out_buffer;
    _ = buffer_len;
    setError("NumberFormat not yet implemented");
    return @intFromEnum(IntlError.internal_error);
}

/// Destroy a NumberFormat instance.
export fn intl_number_format_destroy(nf: ?*NumberFormatHandle) void {
    _ = nf;
}

// ============================================================================
// Collator C API (Placeholder)
// ============================================================================

/// Opaque handle to a Collator instance.
pub const CollatorHandle = opaque {};

/// Create a new Collator instance.
export fn intl_collator_create(
    locale: ?[*:0]const u8,
    options_json: ?[*:0]const u8,
) ?*CollatorHandle {
    _ = locale;
    _ = options_json;
    setError("Collator not yet implemented");
    return null;
}

/// Compare two strings.
/// Returns: -1 (a < b), 0 (a == b), 1 (a > b), or negative error code
export fn intl_collator_compare(
    col: ?*CollatorHandle,
    str_a: ?[*:0]const u8,
    str_b: ?[*:0]const u8,
) i32 {
    _ = col;
    _ = str_a;
    _ = str_b;
    setError("Collator not yet implemented");
    return @intFromEnum(IntlError.internal_error);
}

/// Destroy a Collator instance.
export fn intl_collator_destroy(col: ?*CollatorHandle) void {
    _ = col;
}

// ============================================================================
// PluralRules C API (Placeholder)
// ============================================================================

/// Opaque handle to a PluralRules instance.
pub const PluralRulesHandle = opaque {};

/// Create a new PluralRules instance.
export fn intl_plural_rules_create(
    locale: ?[*:0]const u8,
    options_json: ?[*:0]const u8,
) ?*PluralRulesHandle {
    _ = locale;
    _ = options_json;
    setError("PluralRules not yet implemented");
    return null;
}

/// Select plural category for a number.
/// Writes category name to buffer: "zero", "one", "two", "few", "many", or "other"
export fn intl_plural_rules_select(
    pr: ?*PluralRulesHandle,
    value: f64,
    out_buffer: ?[*]u8,
    buffer_len: usize,
) i32 {
    _ = pr;
    _ = value;
    _ = out_buffer;
    _ = buffer_len;
    setError("PluralRules not yet implemented");
    return @intFromEnum(IntlError.internal_error);
}

/// Destroy a PluralRules instance.
export fn intl_plural_rules_destroy(pr: ?*PluralRulesHandle) void {
    _ = pr;
}

// ============================================================================
// Locale C API
// ============================================================================

/// Opaque handle to a Locale instance.
pub const LocaleHandle = opaque {};

/// Parse a BCP 47 locale tag and create a Locale handle.
export fn intl_locale_create(
    tag: ?[*:0]const u8,
    options_json: ?[*:0]const u8,
) ?*LocaleHandle {
    _ = tag;
    _ = options_json;
    setError("Locale parsing not yet fully implemented");
    return null;
}

/// Get the base name of the locale (language-script-region).
export fn intl_locale_base_name(
    loc: ?*LocaleHandle,
    out_buffer: ?[*]u8,
    buffer_len: usize,
) i32 {
    _ = loc;
    _ = out_buffer;
    _ = buffer_len;
    setError("Locale not yet implemented");
    return @intFromEnum(IntlError.internal_error);
}

/// Maximize locale subtags (add likely subtags).
export fn intl_locale_maximize(
    loc: ?*LocaleHandle,
    out_buffer: ?[*]u8,
    buffer_len: usize,
) i32 {
    _ = loc;
    _ = out_buffer;
    _ = buffer_len;
    setError("Locale maximize not yet implemented");
    return @intFromEnum(IntlError.internal_error);
}

/// Minimize locale subtags (remove likely subtags).
export fn intl_locale_minimize(
    loc: ?*LocaleHandle,
    out_buffer: ?[*]u8,
    buffer_len: usize,
) i32 {
    _ = loc;
    _ = out_buffer;
    _ = buffer_len;
    setError("Locale minimize not yet implemented");
    return @intFromEnum(IntlError.internal_error);
}

/// Destroy a Locale instance.
export fn intl_locale_destroy(loc: ?*LocaleHandle) void {
    _ = loc;
}

// ============================================================================
// Utility Functions
// ============================================================================

/// Get list of supported locales for a specific Intl constructor.
/// Returns JSON array of locale strings.
///
/// ## Parameters
/// - `constructor_name`: "DateTimeFormat", "NumberFormat", "Collator", etc.
/// - `out_buffer`: Buffer to receive JSON array
/// - `buffer_len`: Size of buffer
///
/// ## Returns
/// - On success: Number of bytes written
/// - On error: Negative error code
export fn intl_get_supported_locales(
    constructor_name: ?[*:0]const u8,
    out_buffer: ?[*]u8,
    buffer_len: usize,
) i32 {
    _ = constructor_name;

    // For now, return a minimal list
    const locales_json = "[\"en\",\"en-US\"]";

    if (buffer_len == 0) {
        return @intCast(locales_json.len);
    }

    if (out_buffer == null) {
        setError("output buffer is null");
        return @intFromEnum(IntlError.null_pointer);
    }

    if (buffer_len < locales_json.len + 1) {
        setError("buffer too small");
        return @intFromEnum(IntlError.buffer_too_small);
    }

    const buf = out_buffer.?[0..buffer_len];
    @memcpy(buf[0..locales_json.len], locales_json);
    buf[locales_json.len] = 0;

    return @intCast(locales_json.len);
}

/// Get the canonical locale name for a locale string.
export fn intl_get_canonical_locales(
    locale: ?[*:0]const u8,
    out_buffer: ?[*]u8,
    buffer_len: usize,
) i32 {
    intl_clear_error();

    if (locale == null) {
        setError("locale cannot be null");
        return @intFromEnum(IntlError.null_pointer);
    }

    const locale_str = std.mem.span(locale.?);

    // For now, just normalize case: language lowercase, region uppercase
    // TODO: Full canonicalization per BCP 47
    var canonical = global_allocator.alloc(u8, locale_str.len) catch {
        setError("out of memory");
        return @intFromEnum(IntlError.out_of_memory);
    };
    defer global_allocator.free(canonical);

    var in_region = false;
    for (locale_str, 0..) |c, i| {
        if (c == '-' or c == '_') {
            canonical[i] = '-';
            in_region = true;
        } else if (in_region and locale_str.len - i == 2) {
            // Region code - uppercase
            canonical[i] = std.ascii.toUpper(c);
        } else {
            // Language/script - lowercase
            canonical[i] = std.ascii.toLower(c);
        }
    }

    if (buffer_len == 0) {
        return @intCast(canonical.len);
    }

    if (out_buffer == null) {
        setError("output buffer is null");
        return @intFromEnum(IntlError.null_pointer);
    }

    if (buffer_len < canonical.len + 1) {
        setError("buffer too small");
        return @intFromEnum(IntlError.buffer_too_small);
    }

    const buf = out_buffer.?[0..buffer_len];
    @memcpy(buf[0..canonical.len], canonical);
    buf[canonical.len] = 0;

    return @intCast(canonical.len);
}

// ============================================================================
// Version Information
// ============================================================================

/// Get library version string.
export fn intl_get_version() [*:0]const u8 {
    return "0.1.0";
}

/// Get CLDR version used by the library.
export fn intl_get_cldr_version() [*:0]const u8 {
    return "44.0"; // Will be updated when CLDR data is integrated
}

// ============================================================================
// Tests
// ============================================================================

test "DateTimeFormat create/destroy" {
    const dtf = intl_datetime_format_create("en-US", null);
    try std.testing.expect(dtf != null);
    intl_datetime_format_destroy(dtf);
}

test "DateTimeFormat format basic" {
    const dtf = intl_datetime_format_create("en-US", null);
    try std.testing.expect(dtf != null);
    defer intl_datetime_format_destroy(dtf);

    var buffer: [256]u8 = undefined;
    const len = intl_datetime_format_format(dtf, 0, &buffer, buffer.len);
    try std.testing.expect(len > 0);

    const formatted = buffer[0..@intCast(len)];
    try std.testing.expectEqualStrings("1970-01-01 00:00:00", formatted);
}

test "DateTimeFormat format_to_parts" {
    const dtf = intl_datetime_format_create("en-US", null);
    try std.testing.expect(dtf != null);
    defer intl_datetime_format_destroy(dtf);

    var buffer: [512]u8 = undefined;
    const len = intl_datetime_format_format_to_parts(dtf, 0, &buffer, buffer.len);
    try std.testing.expect(len > 0);

    // Should be valid JSON
    const json = buffer[0..@intCast(len)];
    try std.testing.expect(json[0] == '[');
}

test "DateTimeFormat resolved_options" {
    const dtf = intl_datetime_format_create("en-US", null);
    try std.testing.expect(dtf != null);
    defer intl_datetime_format_destroy(dtf);

    var buffer: [256]u8 = undefined;
    const len = intl_datetime_format_resolved_options(dtf, &buffer, buffer.len);
    try std.testing.expect(len > 0);

    const json = buffer[0..@intCast(len)];
    try std.testing.expect(std.mem.indexOf(u8, json, "\"locale\":\"en-US\"") != null);
}

test "DateTimeFormat null handling" {
    // Null handle should return error
    var buffer: [256]u8 = undefined;
    const result = intl_datetime_format_format(null, 0, &buffer, buffer.len);
    try std.testing.expectEqual(@intFromEnum(IntlError.null_pointer), result);
}

test "DateTimeFormat empty locale" {
    const dtf = intl_datetime_format_create("", null);
    try std.testing.expect(dtf == null);
}

test "intl_get_canonical_locales" {
    var buffer: [64]u8 = undefined;

    // Test basic canonicalization
    const len = intl_get_canonical_locales("EN-us", &buffer, buffer.len);
    try std.testing.expect(len > 0);
    try std.testing.expectEqualStrings("en-US", buffer[0..@intCast(len)]);
}

test "intl_get_supported_locales" {
    var buffer: [256]u8 = undefined;
    const len = intl_get_supported_locales("DateTimeFormat", &buffer, buffer.len);
    try std.testing.expect(len > 0);

    const json = buffer[0..@intCast(len)];
    try std.testing.expect(json[0] == '[');
}

test "intl_get_version" {
    const version = intl_get_version();
    try std.testing.expect(std.mem.len(version) > 0);
}
