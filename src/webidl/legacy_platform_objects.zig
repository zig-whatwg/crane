//! WebIDL Legacy Platform Objects
//!
//! Spec: https://webidl.spec.whatwg.org/#js-legacy-platform-objects
//!
//! Legacy platform objects are JavaScript objects that expose indexed and/or
//! named properties in a legacy manner, for compatibility with older Web APIs.
//!
//! # What are Legacy Platform Objects?
//!
//! Legacy platform objects provide array-like or object-like property access:
//!
//! - **Indexed properties**: obj[0], obj[1], obj[2], ...
//! - **Named properties**: obj["foo"], obj["bar"], ...
//!
//! Examples from Web APIs:
//! - HTMLCollection (indexed + named)
//! - NodeList (indexed)
//! - DOMStringList (indexed)
//! - Storage (named)
//!
//! # JavaScript Binding Requirements
//!
//! Legacy platform objects require custom [[GetOwnProperty]], [[Set]],
//! [[Delete]], and [[OwnPropertyKeys]] internal methods that:
//!
//! 1. Check supported property indices/names
//! 2. Expose properties that might not actually exist on the object
//! 3. Handle property enumeration specially
//! 4. Integrate with prototype chain lookup
//!
//! This requires deep JS engine integration to override object internal methods.
//!
//! # Implementation Strategy
//!
//! For V8 integration:
//!
//! 1. Use v8::IndexedPropertyHandlerConfiguration for indexed properties
//! 2. Use v8::NamedPropertyHandlerConfiguration for named properties
//! 3. Implement getter, setter, deleter, enumerator, definer callbacks
//! 4. Connect to platform object's storage (backing list/map)
//!
//! # Current Status
//!
//! This module provides the conceptual framework and type definitions.
//! The actual implementation will be in zig-js-runtime when V8 bindings are ready.
//!
//! TODO(zig-js-runtime): Implement IndexedPropertyHandler
//! TODO(zig-js-runtime): Implement NamedPropertyHandler
//! TODO(zig-js-runtime): Implement [[GetOwnProperty]] override
//! TODO(zig-js-runtime): Implement [[Set]] override
//! TODO(zig-js-runtime): Implement [[Delete]] override
//! TODO(zig-js-runtime): Implement [[OwnPropertyKeys]] override
//! TODO(zig-js-runtime): Implement [LegacyUnenumerableNamedProperties]
//! TODO(zig-js-runtime): Implement [LegacyOverrideBuiltIns]

const std = @import("std");

/// Indexed property descriptor
///
/// Spec: § 3.9.1 Indexed properties
///
/// Describes how indexed properties (e.g., obj[0]) are exposed on a
/// legacy platform object.
pub const IndexedPropertyDescriptor = struct {
    /// Check if an index is supported
    is_supported: *const fn (index: u32) bool,

    /// Get value at index (returns null if not supported)
    get: *const fn (index: u32) ?[]const u8,

    /// Set value at index (returns error if not supported or read-only)
    set: ?*const fn (index: u32, value: []const u8) anyerror!void,

    /// Get the length (number of indexed properties)
    length: *const fn () u32,
};

/// Named property descriptor
///
/// Spec: § 3.9.2 Named properties
///
/// Describes how named properties (e.g., obj["foo"]) are exposed on a
/// legacy platform object.
pub const NamedPropertyDescriptor = struct {
    /// Check if a name is supported
    is_supported: *const fn (name: []const u8) bool,

    /// Get value for name (returns null if not supported)
    get: *const fn (name: []const u8) ?[]const u8,

    /// Set value for name (returns error if not supported or read-only)
    set: ?*const fn (name: []const u8, value: []const u8) anyerror!void,

    /// Delete property (returns error if not supported or not deletable)
    delete: ?*const fn (name: []const u8) anyerror!void,

    /// Get all supported property names
    enumerate: *const fn (allocator: std.mem.Allocator) anyerror![][]const u8,
};

/// Legacy platform object configuration
///
/// Combines indexed and named property descriptors for a legacy platform object.
pub const LegacyPlatformObjectConfig = struct {
    indexed: ?IndexedPropertyDescriptor = null,
    named: ?NamedPropertyDescriptor = null,

    /// Whether named properties override built-ins
    /// Spec: [LegacyOverrideBuiltIns]
    override_builtins: bool = false,

    /// Whether named properties are unenumerable
    /// Spec: [LegacyUnenumerableNamedProperties]
    unenumerable_named: bool = false,
};

/// Create a legacy platform object (stub for V8 integration)
///
/// TODO(zig-js-runtime): Implement with V8 object templates
pub fn createLegacyPlatformObject(config: LegacyPlatformObjectConfig) !void {
    _ = config;
    return error.NotImplemented;
}

const testing = std.testing;

test "LegacyPlatformObjectConfig - basic structure" {
    // Simple smoke test to verify types compile
    const config = LegacyPlatformObjectConfig{
        .override_builtins = true,
        .unenumerable_named = false,
    };

    try testing.expect(config.override_builtins);
    try testing.expect(!config.unenumerable_named);
}

test "createLegacyPlatformObject - not yet implemented" {
    const config = LegacyPlatformObjectConfig{};

    // Will work once V8 integration is complete
    try testing.expectError(error.NotImplemented, createLegacyPlatformObject(config));
}
