//! Runtime Context for WebIDL operations
//!
//! Context is passed to all namespace operations and stored in instances.
//! It provides access to the JavaScript execution environment, logging,
//! and other runtime services.
//!
//! ## Design
//!
//! The Context is a pointer to a ContextData struct that contains:
//! - Logger: For console output (console.log, console.error, etc.)
//! - Engine Context: Optional pointer to JS engine context (V8, JSC, etc.)
//! - Allocator: For memory management
//!
//! By using a pointer (`*ContextData`), we keep the Context small (8 bytes)
//! which is important for passing through generated code.
//!
//! ## Usage
//!
//! ```zig
//! const runtime = @import("runtime");
//!
//! // Create context with logger
//! var ctx_data = try runtime.ContextData.init(allocator, .{
//!     .colored = true,
//! });
//! defer ctx_data.deinit();
//!
//! const ctx: runtime.Context = &ctx_data;
//!
//! // Use in namespace operations
//! console.log(ctx, "Hello from WebIDL!");
//! ```

const std = @import("std");
const Logger = @import("logger.zig").Logger;
const LoggerConfig = @import("logger.zig").LoggerConfig;
const infra = @import("infra");

// Import event loop for streams and async operations
// Note: This is an optional dependency - event_loop is only needed for async features
const event_loop_mod = @import("event_loop");

// Import V8 event loop for auto-detection
const v8 = @import("v8");

/// Console state for console namespace operations
///
/// This state is per-context (one instance per ContextData).
/// Stores count maps, timers, and group stack for console operations.
pub const ConsoleState = struct {
    /// Map of labels to counts (for console.count/console.countReset)
    count_map: std.StringHashMap(u32),

    /// Map of labels to start times (for console.time/console.timeLog/console.timeEnd)
    timer_table: std.StringHashMap(i64),

    /// Stack of active groups (for console.group/console.groupCollapsed/console.groupEnd)
    /// Stores indent level as u32
    group_stack: std.ArrayList(u32),

    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .count_map = std.StringHashMap(u32).init(allocator),
            .timer_table = std.StringHashMap(i64).init(allocator),
            .group_stack = .{}, // ArrayList has default empty initialization
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        // Free all keys in count_map
        var count_iter = self.count_map.keyIterator();
        while (count_iter.next()) |key| {
            allocator.free(key.*);
        }
        self.count_map.deinit();

        // Free all keys in timer_table
        var timer_iter = self.timer_table.keyIterator();
        while (timer_iter.next()) |key| {
            allocator.free(key.*);
        }
        self.timer_table.deinit();

        self.group_stack.deinit(allocator);
    }

    /// Get current indent level based on group stack depth
    pub fn getIndentLevel(self: *const Self) u32 {
        return @intCast(self.group_stack.items.len);
    }
};

/// Runtime context data structure
///
/// This struct contains all runtime services: logging, memory management,
/// JS engine integration, and event loop for async operations.
pub const ContextData = struct {
    allocator: std.mem.Allocator,
    logger: Logger,
    engine_ctx: ?*anyopaque,
    console_state: ConsoleState,

    /// Event loop for async operations (streams, promises, etc.)
    /// Optional - only needed for async features like ReadableStream
    event_loop: ?event_loop_mod.EventLoop,

    /// Internal: V8EventLoop storage (if created during init)
    /// This is owned by the context and must be cleaned up
    _v8_event_loop_storage: ?*v8.V8EventLoop,

    const Self = @This();

    /// Context initialization options
    pub const Options = struct {
        /// Logger configuration
        colored: bool = true,
        show_timestamp: bool = false,
        show_labels: bool = false,

        /// JS engine context (V8, JSC, etc.)
        /// This is an opaque pointer to the engine-specific context
        engine_ctx: ?*anyopaque = null,

        /// Event loop for async operations
        /// Optional - only needed for async features like streams, promises
        /// If not provided, async operations will fail with error.NoEventLoop
        event_loop: ?event_loop_mod.EventLoop = null,
    };

    /// Initialize a new runtime context
    pub fn init(allocator: std.mem.Allocator, options: Options) !Self {
        const logger = Logger.init(allocator, .{
            .colored = options.colored,
            .show_timestamp = options.show_timestamp,
            .show_labels = options.show_labels,
        });

        // Auto-detect event loop:
        // 1. If engine_ctx provided (V8 isolate) → create V8EventLoop
        // 2. If event_loop provided explicitly → use it
        // 3. Otherwise → no event loop (async operations will fail)
        var v8_loop_storage: ?*v8.V8EventLoop = null;
        const ev_loop = if (options.engine_ctx) |engine_ctx| blk: {
            // V8 mode - create V8EventLoop wrapper
            const isolate: *v8.ffi.Isolate = @ptrCast(@alignCast(engine_ctx));
            const v8_loop_ptr = try allocator.create(v8.V8EventLoop);
            errdefer allocator.destroy(v8_loop_ptr);

            v8_loop_ptr.* = v8.V8EventLoop.init(isolate, allocator);
            v8_loop_storage = v8_loop_ptr;

            break :blk v8_loop_ptr.eventLoop();
        } else options.event_loop;

        return .{
            .allocator = allocator,
            .logger = logger,
            .engine_ctx = options.engine_ctx,
            .console_state = ConsoleState.init(allocator),
            .event_loop = ev_loop,
            ._v8_event_loop_storage = v8_loop_storage,
        };
    }

    /// Deinitialize context and cleanup resources
    pub fn deinit(self: *Self) void {
        // Clean up V8EventLoop if we created one
        if (self._v8_event_loop_storage) |v8_loop| {
            v8_loop.deinit();
            self.allocator.destroy(v8_loop);
        }

        self.console_state.deinit(self.allocator);
        self.logger.deinit();
    }

    /// Check if this context has a JS engine
    pub fn hasEngine(self: *const Self) bool {
        return self.engine_ctx != null;
    }

    /// Get the JS engine context (for V8 integration)
    pub fn getEngineContext(self: *const Self) ?*anyopaque {
        return self.engine_ctx;
    }

    /// Get the allocator for this context
    pub fn getAllocator(self: *const Self) std.mem.Allocator {
        return self.allocator;
    }

    /// Check if this context has an event loop
    pub fn hasEventLoop(self: *const Self) bool {
        return self.event_loop != null;
    }

    /// Get the event loop (returns error if not available)
    pub fn getEventLoop(self: *const Self) !event_loop_mod.EventLoop {
        return self.event_loop orelse error.NoEventLoop;
    }

    /// Get optional event loop
    pub fn getOptionalEventLoop(self: *const Self) ?event_loop_mod.EventLoop {
        return self.event_loop;
    }
};

/// Runtime context - pointer to ContextData
///
/// This is what gets passed to all namespace operations.
/// By keeping it as a simple pointer, we maintain small size and
/// compatibility with generated code.
pub const Context = *ContextData;

/// Null context helper for testing
///
/// Creates a minimal context without a JS engine.
/// Useful for testing WebIDL implementations in isolation.
pub fn createNullContext(allocator: std.mem.Allocator) !ContextData {
    return ContextData.init(allocator, .{
        .colored = false,
        .engine_ctx = null,
    });
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "ContextData - basic initialization" {
    var ctx_data = try ContextData.init(testing.allocator, .{});
    defer ctx_data.deinit();

    try testing.expectEqual(testing.allocator, ctx_data.allocator);
    try testing.expect(!ctx_data.hasEngine());
}

test "ContextData - with engine context" {
    var dummy_engine: u32 = 42;
    var ctx_data = try ContextData.init(testing.allocator, .{
        .engine_ctx = @ptrCast(&dummy_engine),
    });
    defer ctx_data.deinit();

    try testing.expect(ctx_data.hasEngine());
    const engine_ctx = ctx_data.getEngineContext();
    try testing.expect(engine_ctx != null);
}

test "Context - is a pointer" {
    var ctx_data = try ContextData.init(testing.allocator, .{});
    defer ctx_data.deinit();

    const ctx: Context = &ctx_data;
    try testing.expect(@TypeOf(ctx) == Context);
    try testing.expectEqual(@sizeOf(Context), @sizeOf(*ContextData));
}

test "Context - null context helper" {
    var ctx_data = try createNullContext(testing.allocator);
    defer ctx_data.deinit();

    try testing.expect(!ctx_data.hasEngine());
}

test "Context - logger is accessible" {
    var ctx_data = try ContextData.init(testing.allocator, .{ .colored = false });
    defer ctx_data.deinit();

    const ctx: Context = &ctx_data;

    // Should be able to log through context
    try ctx.logger.log("Test message", .{});
}
