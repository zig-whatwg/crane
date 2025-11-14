//! WebIDL Extended Attributes
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-extended-attributes
//!
//! Extended attributes modify the behavior of WebIDL types and operations.
//! This module provides utilities and documentation for extended attribute
//! support in the WebIDL runtime.
//!
//! # Implemented Extended Attributes
//!
//! ## Type Conversion Modifiers
//!
//! **[Clamp]** - Clamps out-of-range integer values
//! - Applied to integer types (byte, octet, short, long, etc.)
//! - Out-of-range values are clamped to min/max instead of wrapping
//! - Uses banker's rounding (round half to even)
//! - Implementation: `primitives.toLongClamped()`, etc.
//!
//! **[EnforceRange]** - Throws TypeError on out-of-range values
//! - Applied to integer types
//! - Throws TypeError if value is out of range or NaN/Infinity
//! - Implementation: `primitives.toLongEnforceRange()`, etc.
//!
//! **[LegacyNullToEmptyString]** - Converts null to empty string
//! - Applied to DOMString types
//! - JavaScript null → "" instead of "null"
//! - Legacy compatibility for older APIs
//! - Implementation: `strings.toDOMStringLegacyNullToEmptyString()`
//!
//! ## Buffer Source Modifiers
//!
//! **[AllowShared]** - Allows SharedArrayBuffer
//! - Applied to buffer view types (TypedArray, DataView)
//! - Permits SharedArrayBuffer in addition to ArrayBuffer
//! - Used for concurrent access scenarios
//!
//! **[AllowResizable]** - Allows resizable buffers
//! - Applied to ArrayBuffer or buffer view types
//! - Permits resizable ArrayBuffer or growable SharedArrayBuffer
//! - Used when buffer size may change
//!
//! # Usage Examples
//!
//! ## [Clamp] Example
//!
//! ```zig
//! const primitives = @import("primitives.zig");
//!
//! // Without [Clamp]: wraps to -56
//! const wrapped = try primitives.toByte(JSValue{ .number = 200.0 });
//! // wrapped == -56 (200 mod 256 - 256)
//!
//! // With [Clamp]: clamps to 127
//! const clamped = primitives.toByteClamped(JSValue{ .number = 200.0 });
//! // clamped == 127 (clamped to i8 max)
//! ```
//!
//! ## [EnforceRange] Example
//!
//! ```zig
//! const primitives = @import("primitives.zig");
//!
//! // Without [EnforceRange]: wraps
//! const ok = try primitives.toLong(JSValue{ .number = 2147483648.0 });
//!
//! // With [EnforceRange]: throws
//! const err = primitives.toLongEnforceRange(JSValue{ .number = 2147483648.0 });
//! // Returns error.TypeError
//! ```
//!
//! ## [LegacyNullToEmptyString] Example
//!
//! ```zig
//! const strings = @import("strings.zig");
//! const allocator = std.heap.page_allocator;
//!
//! // Without [LegacyNullToEmptyString]: converts to "null"
//! const null_str = try strings.toDOMString(allocator, JSValue{ .null = {} });
//! defer allocator.free(null_str);
//! // null_str == "null" (4 code units)
//!
//! // With [LegacyNullToEmptyString]: converts to ""
//! const empty = try strings.toDOMStringLegacyNullToEmptyString(allocator, JSValue{ .null = {} });
//! defer allocator.free(empty);
//! // empty == "" (0 code units)
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Extended attribute that modifies integer type conversion behavior.
///
/// Usage in WebIDL:
/// ```webidl
/// interface Example {
///   undefined setColor([Clamp] octet red, [EnforceRange] octet green, octet blue);
/// };
/// ```
pub const IntegerExtAttr = enum {
    /// Default behavior: modulo wrapping
    none,

    /// [Clamp]: Clamp out-of-range values to min/max
    clamp,

    /// [EnforceRange]: Throw TypeError on out-of-range values
    enforce_range,
};

/// Extended attribute that modifies string type conversion behavior.
///
/// Usage in WebIDL:
/// ```webidl
/// interface Example {
///   attribute [LegacyNullToEmptyString] DOMString value;
/// };
/// ```
pub const StringExtAttr = enum {
    /// Default behavior: null → "null"
    none,

    /// [LegacyNullToEmptyString]: null → ""
    legacy_null_to_empty_string,
};

/// Extended attributes for buffer source types.
///
/// Usage in WebIDL:
/// ```webidl
/// interface Example {
///   undefined process([AllowShared] ArrayBufferView data);
///   undefined resize([AllowResizable] ArrayBuffer buffer);
/// };
/// ```
pub const BufferExtAttr = packed struct {
    /// [AllowShared]: Permits SharedArrayBuffer
    allow_shared: bool = false,

    /// [AllowResizable]: Permits resizable/growable buffers
    allow_resizable: bool = false,
};

/// Utility to check if a buffer is detached.
///
/// A detached ArrayBuffer cannot be accessed and will throw if used.
/// This occurs after transferring ownership to another context.
pub fn isBufferDetached(buffer: anytype) bool {
    // In a real implementation, this would check the [[ArrayBufferData]] internal slot
    // For now, this is a placeholder
    _ = buffer;
    return false;
}

/// Utility to check if a buffer is resizable.
///
/// Resizable ArrayBuffers and growable SharedArrayBuffers were added in ES2024.
pub fn isBufferResizable(buffer: anytype) bool {
    // In a real implementation, this would check [[ArrayBufferMaxByteLength]]
    _ = buffer;
    return false;
}

/// Utility to check if a buffer is shared (SharedArrayBuffer).
pub fn isBufferShared(buffer: anytype) bool {
    // In a real implementation, this would check if it's a SharedArrayBuffer
    _ = buffer;
    return false;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;




