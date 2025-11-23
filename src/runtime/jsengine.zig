//! Abstract JS Engine Interface
//!
//! NOTE: This abstraction layer is currently UNUSED.
//! V8 engine implementation is in src/runtime/engines/v8/ but is imported
//! as a SEPARATE module (@import("v8")) to avoid circular dependencies.
//!
//! The "engine selection" abstraction was created for potential multi-engine
//! support (JSC, SpiderMonkey), but only V8 exists and it uses its own module.
//!
//! ## Current Architecture
//!
//! ```
//! WebIDL Runtime (@import("runtime"))
//!       |
//!       | separate from
//!       v
//! V8 Bindings (@import("v8"))
//!   Located in: src/runtime/engines/v8/
//!   Imported as: separate module
//! ```
//!
//! ## Future: If We Add More Engines
//!
//! - Create src/runtime/engines/jsc/ → @import("jsc") module
//! - Create src/runtime/engines/spidermonkey/ → @import("spidermonkey") module
//! - Keep each engine as a separate module
//!
//! The comptime reflection system in V8 makes this abstraction unnecessary.

const std = @import("std");

/// Available JS engine implementations
///
/// NOTE: This enum is currently unused. V8 is imported directly as @import("v8").
pub const EngineType = enum {
    // v8,  // V8 is in src/runtime/engines/v8/ but imported as separate module @import("v8")
    // Future engines would follow the same pattern:
    // jsc,  // Would be @import("jsc")
    // spidermonkey,  // Would be @import("spidermonkey")
};

/// Select JS engine implementation at compile time
///
/// NOTE: This function is currently UNUSED.
/// Use @import("v8") directly instead of jsengine.select(.v8).
///
/// This abstraction was created for multi-engine support but is not needed
/// with Zig's module system - each engine is its own module.
pub fn select(comptime engine: EngineType) type {
    _ = engine;
    @compileError("Use @import(\"v8\") instead of jsengine.select(.v8). Engine selection abstraction is deprecated.");
}

/// Abstract interfaces that all engines must implement
///
/// See examples/engine_implementation/ for interface definitions and implementation guide.
pub const interfaces = struct {
    // Interface definitions are in examples/engine_implementation/
    // Each engine must implement:
    // - types/ (Value type, type conversions)
    // - errors/ (Exception types, DOMException)
    // - callbacks/ (Constructor, Getter, Setter, Method callbacks)
};

/// Engine capabilities and requirements
///
/// Each engine implementation should provide this metadata.
pub const EngineInfo = struct {
    name: []const u8,
    version: []const u8,
    supports_jit: bool,
    supports_modules: bool,
    supports_workers: bool,
};

/// Abstract Context interface
///
/// All engines must provide a Context type that implements these operations.
pub const ContextInterface = struct {
    /// Initialize engine context
    init: *const fn (allocator: std.mem.Allocator) anyerror!*anyopaque,

    /// Cleanup engine context
    deinit: *const fn (self: *anyopaque) void,

    /// Map WebIDL instance to JS object
    setObject: *const fn (self: *anyopaque, instance: *anyopaque, handle: usize) anyerror!void,

    /// Get JS object for WebIDL instance
    getObject: *const fn (self: *anyopaque, instance: *anyopaque) ?usize,

    /// Get WebIDL instance for JS object
    getInstance: *const fn (self: *anyopaque, handle: usize) ?*anyopaque,
};

/// Abstract Template interface
///
/// All engines must provide template building for WebIDL interfaces.
pub const TemplateInterface = struct {
    /// Initialize template builder
    init: *const fn (allocator: std.mem.Allocator, ctx: *anyopaque) anyerror!*anyopaque,

    /// Cleanup template builder
    deinit: *const fn (self: *anyopaque) void,

    /// Add attribute to template
    addAttribute: *const fn (self: *anyopaque, name: []const u8, getter: ?*const anyopaque, setter: ?*const anyopaque) anyerror!void,

    /// Add method to template
    addMethod: *const fn (self: *anyopaque, name: []const u8, callback: *const anyopaque, arg_count: usize) anyerror!void,

    /// Build final template
    build: *const fn (self: *anyopaque) anyerror!*anyopaque,
};

/// Abstract Persistent Handle interface
///
/// All engines must provide persistent handles for long-lived objects.
pub const PersistentInterface = struct {
    /// Create persistent handle
    create: *const fn (allocator: std.mem.Allocator, handle: usize, instance: *anyopaque) anyerror!usize,

    /// Get persistent handle by ID
    get: *const fn (handle_id: usize) ?*anyopaque,

    /// Destroy persistent handle
    destroy: *const fn (handle_id: usize) void,

    /// Make handle weak (allow GC)
    makeWeak: *const fn (handle_id: usize) void,

    /// Make handle strong (prevent GC)
    makeStrong: *const fn (handle_id: usize) void,
};

/// Abstract EventListener interface
///
/// All engines must provide event listener management.
pub const EventListenerInterface = struct {
    /// Add event listener
    addEventListener: *const fn (
        instance: *anyopaque,
        event_type: []const u8,
        callback: *anyopaque,
        options: *const anyopaque,
    ) anyerror!void,

    /// Remove event listener
    removeEventListener: *const fn (
        instance: *anyopaque,
        event_type: []const u8,
        callback: *anyopaque,
    ) void,

    /// Dispatch event
    dispatchEvent: *const fn (
        instance: *anyopaque,
        event: *const anyopaque,
    ) void,
};
