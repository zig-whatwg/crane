//! Abstract JS Engine Interface
//!
//! Defines the bridge between WebIDL runtime and JS engine implementations.
//! Each engine (V8, JSC, SpiderMonkey) provides concrete implementations.
//!
//! ## Architecture: Bridge Pattern
//!
//! ```
//! WebIDL Runtime (Abstraction)
//!       |
//!       | uses
//!       v
//!   JSEngine Interface (this file)
//!       |
//!       | implemented by
//!       v
//! V8Engine / JSCEngine / SpiderMonkeyEngine (Implementations)
//! ```
//!
//! ## Usage
//!
//! ```zig
//! const jsengine = @import("runtime").jsengine;
//!
//! // Select engine at compile time
//! const Engine = jsengine.select(.v8);
//!
//! // Use engine-agnostic interface
//! const ctx = try Engine.Context.init(allocator);
//! defer ctx.deinit();
//!
//! const value = try Engine.types.toJS(allocator, 42);
//! ```

const std = @import("std");

/// Available JS engine implementations
pub const EngineType = enum {
    v8,
    // Future engines:
    // jsc,
    // spidermonkey,
};

/// Select JS engine implementation at compile time
///
/// Returns the module for the selected engine.
/// All engines must implement the same interface defined in this file.
pub fn select(comptime engine: EngineType) type {
    return switch (engine) {
        .v8 => @import("engines/v8/engine.zig"),
        // .jsc => @import("engines/jsc/engine.zig"),
        // .spidermonkey => @import("engines/spidermonkey/engine.zig"),
    };
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
