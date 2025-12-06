//! Engine Configuration Module
//!
//! Provides comptime information about the currently configured JavaScript engine.
//! The engine is selected at build time via `-Dengine=<engine>`.
//!
//! ## Usage
//!
//! ```zig
//! const engine_config = @import("engine_config.zig");
//!
//! // Check current engine
//! if (engine_config.current_engine == .v8) {
//!     // V8-specific code path
//! }
//!
//! // Check engine capabilities
//! if (engine_config.has_snapshot_support) {
//!     // Use snapshot-based initialization
//! }
//! ```
//!
//! ## Available Engines
//!
//! - `v8`: Google V8 (fully implemented)
//! - `jsc`: JavaScriptCore (partial)
//! - `quickjs`: QuickJS (partial)

const std = @import("std");
const build_options = @import("build_options");

/// JavaScript engine types
pub const Engine = enum {
    v8,
    jsc,
    quickjs,
};

/// Currently configured engine (comptime constant)
pub const current_engine: Engine = blk: {
    const name = build_options.engine_name;
    if (std.mem.eql(u8, name, "v8")) break :blk .v8;
    if (std.mem.eql(u8, name, "jsc")) break :blk .jsc;
    if (std.mem.eql(u8, name, "quickjs")) break :blk .quickjs;
    @compileError("Unknown engine: " ++ name);
};

/// Engine name as a string
pub const engine_name: []const u8 = build_options.engine_name;

/// Whether the current engine supports V8-style heap snapshots for fast startup.
/// - V8: true (snapshots reduce startup from ~40ms to <2ms)
/// - JSC: false
/// - QuickJS: false (but supports bytecode serialization)
pub const has_snapshot_support: bool = build_options.has_snapshot_support;

/// Whether the current engine uses the isolate-per-thread threading model.
/// - V8: true (each isolate is single-threaded, use Locker for multi-thread)
/// - JSC: false (uses different threading model)
/// - QuickJS: false (single-threaded by design)
pub const has_isolate_per_thread: bool = build_options.has_isolate_per_thread;

/// Get the engine-specific backend module type.
///
/// This enables comptime dispatch to the correct engine implementation:
/// ```zig
/// const Backend = engine_config.getBackend();
/// const engine = Backend.init(allocator);
/// ```
pub fn getBackend() type {
    return switch (current_engine) {
        .v8 => @import("engines/v8/engine.zig"),
        .jsc => @import("engines/jsc/engine.zig"),
        .quickjs => @import("engines/quickjs/engine.zig"),
    };
}

/// Check if the current engine is fully implemented.
/// Returns false for JSC and QuickJS until whatwg-qfv3a is complete.
pub fn isFullyImplemented() bool {
    return current_engine == .v8;
}

// ============================================================================
// Tests
// ============================================================================

test "engine_config - current engine is v8 by default" {
    // In test builds, v8 should be the default
    try std.testing.expectEqual(Engine.v8, current_engine);
}

test "engine_config - v8 has snapshot support" {
    if (current_engine == .v8) {
        try std.testing.expect(has_snapshot_support);
        try std.testing.expect(has_isolate_per_thread);
    }
}

test "engine_config - engine name matches" {
    try std.testing.expectEqualStrings(
        @tagName(current_engine),
        engine_name,
    );
}
