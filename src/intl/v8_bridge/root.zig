//! V8-Zig i18n Bridge Layer
//!
//! This module provides the integration layer between V8 and the Zig i18n library.
//! It exports a C-compatible API that V8 extensions can call via FFI.
//!
//! ## Architecture
//!
//! ```
//! JavaScript (V8)
//!     ↓ V8 Extension (C++)
//! C API (this module)
//!     ↓
//! Zig i18n Library
//! ```
//!
//! ## Usage
//!
//! The C API is exported for use by V8 extensions. See `c_api.zig` for the
//! full API surface and documentation.
//!
//! ## Memory Management
//!
//! - All Intl objects are opaque handles
//! - Every create function has a corresponding destroy function
//! - V8 should use weak callbacks to clean up Zig objects when JS objects are GC'd
//! - NO global caches (critical for avoiding ICU's OOM bug)
//!
//! ## Thread Safety
//!
//! - Each Intl object is independent
//! - No global mutable state
//! - Safe to use from multiple V8 isolates concurrently

pub const c_api = @import("c_api.zig");

// Re-export types for Zig usage
pub const DateTimeFormatHandle = c_api.DateTimeFormatHandle;
pub const NumberFormatHandle = c_api.NumberFormatHandle;
pub const CollatorHandle = c_api.CollatorHandle;
pub const PluralRulesHandle = c_api.PluralRulesHandle;
pub const LocaleHandle = c_api.LocaleHandle;
pub const IntlError = c_api.IntlError;

// Re-export C API functions for Zig usage (non-exported versions)
// These can be used directly from Zig code without going through C ABI

const std = @import("std");

/// Create a DateTimeFormat for Zig usage (returns proper Zig error)
pub fn createDateTimeFormat(
    allocator: std.mem.Allocator,
    locale: []const u8,
    options_json: ?[]const u8,
) !*DateTimeFormatHandle {
    _ = allocator; // Will be used when we have proper allocator integration

    // Create null-terminated copies for C API
    var locale_buf: [256]u8 = undefined;
    if (locale.len >= locale_buf.len) return error.LocaleTooLong;
    @memcpy(locale_buf[0..locale.len], locale);
    locale_buf[locale.len] = 0;

    var options_buf: [4096]u8 = undefined;
    const options_ptr: ?[*:0]const u8 = if (options_json) |json| blk: {
        if (json.len >= options_buf.len) return error.OptionsTooLong;
        @memcpy(options_buf[0..json.len], json);
        options_buf[json.len] = 0;
        break :blk @ptrCast(&options_buf);
    } else null;

    const result = c_api.intl_datetime_format_create(
        @ptrCast(&locale_buf),
        options_ptr,
    );

    return result orelse error.CreateFailed;
}

/// Format a timestamp using DateTimeFormat
pub fn formatDateTime(
    dtf: *DateTimeFormatHandle,
    timestamp_ms: i64,
    allocator: std.mem.Allocator,
) ![]u8 {
    // First, get required size
    const size = c_api.intl_datetime_format_format(dtf, timestamp_ms, null, 0);
    if (size < 0) {
        return switch (@as(IntlError, @enumFromInt(size))) {
            .out_of_memory => error.OutOfMemory,
            .null_pointer => error.NullPointer,
            .invalid_timestamp => error.InvalidTimestamp,
            else => error.FormatFailed,
        };
    }

    // Allocate buffer
    const buffer = try allocator.alloc(u8, @intCast(size + 1));
    errdefer allocator.free(buffer);

    // Format into buffer
    const len = c_api.intl_datetime_format_format(
        dtf,
        timestamp_ms,
        buffer.ptr,
        buffer.len,
    );
    if (len < 0) {
        return error.FormatFailed;
    }

    return buffer[0..@intCast(len)];
}

test {
    _ = c_api;
}
