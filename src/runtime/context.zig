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
//! - Engine Interface: Abstract interface to JS engine (V8, JSC, etc.)
//! - Engine Context: Opaque pointer to engine-specific context
//! - Allocator: For memory management
//!
//! By using a pointer (`*ContextData`), we keep the Context small (8 bytes)
//! which is important for passing through generated code.
//!
//! ## Engine Abstraction
//!
//! The context holds an optional `EngineInterface` pointer which provides
//! engine-agnostic operations like wrapping async iterators, creating promises,
//! etc. This allows impl files to work with any JS engine without direct imports.
//!
//! ## Usage
//!
//! ```zig
//! const runtime = @import("runtime");
//!
//! // Create context with logger (no engine)
//! var ctx_data = try runtime.ContextData.init(allocator, .{
//!     .colored = true,
//! });
//! defer ctx_data.deinit();
//!
//! const ctx: runtime.Context = &ctx_data;
//!
//! // Use in namespace operations
//! console.log(ctx, "Hello from WebIDL!");
//!
//! // For engine operations, check if engine is available
//! if (ctx.getEngine()) |engine| {
//!     const wrapped = try engine.wrapAsyncIterator(ctx.engine_ctx.?, iterator);
//! }
//! ```

const std = @import("std");
const Logger = @import("logger.zig").Logger;
const LoggerConfig = @import("logger.zig").LoggerConfig;
const EngineInterface = @import("engine_interface.zig").EngineInterface;
const infra = @import("infra");

// Import event loop for streams and async operations
// Note: This is an optional dependency - event_loop is only needed for async features
const event_loop_mod = @import("event_loop");

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

    /// Abstract engine interface (provides engine-agnostic operations)
    engine: ?*const EngineInterface,

    /// Engine-specific opaque context (V8 Isolate, JSC VM, etc.)
    engine_ctx: ?*anyopaque,

    console_state: ConsoleState,

    /// Event loop for async operations (streams, promises, etc.)
    /// Optional - only needed for async features like ReadableStream
    event_loop: ?event_loop_mod.EventLoop,

    /// Internal: Engine-created event loop storage (if created during init)
    /// This is owned by the context and must be cleaned up via engine interface
    _engine_event_loop_storage: ?*anyopaque,

    const Self = @This();

    /// Context initialization options
    pub const Options = struct {
        /// Logger configuration
        colored: bool = true,
        show_timestamp: bool = false,
        show_labels: bool = false,

        /// Abstract engine interface
        /// Provides engine-agnostic operations (async iterators, promises, etc.)
        engine: ?*const EngineInterface = null,

        /// JS engine context (V8 Isolate, JSC VM, etc.)
        /// This is an opaque pointer to the engine-specific context
        engine_ctx: ?*anyopaque = null,

        /// Event loop for async operations
        /// Optional - only needed for async features like streams, promises
        /// If not provided and engine supports it, engine will create one
        /// If not provided and no engine, async operations will fail with error.NoEventLoop
        event_loop: ?event_loop_mod.EventLoop = null,
    };

    /// Initialize a new runtime context
    pub fn init(allocator: std.mem.Allocator, options: Options) !Self {
        const logger = Logger.init(allocator, .{
            .colored = options.colored,
            .show_timestamp = options.show_timestamp,
            .show_labels = options.show_labels,
        });

        // Determine event loop:
        // 1. If event_loop provided explicitly → use it
        // 2. If engine can create one → use engine's event loop
        // 3. Otherwise → no event loop (async operations will fail)
        var engine_event_loop_storage: ?*anyopaque = null;
        const ev_loop: ?event_loop_mod.EventLoop = if (options.event_loop) |el|
            el
        else if (options.engine) |engine| blk: {
            if (engine.createEventLoop) |create_fn| {
                if (options.engine_ctx) |engine_ctx| {
                    const loop_ptr = create_fn(engine_ctx, allocator) catch break :blk null;
                    engine_event_loop_storage = loop_ptr;
                    // Engine must provide a way to get EventLoop from its storage
                    // For now, we assume the engine stores it and we query later
                    break :blk null; // TODO: Engine should return EventLoop directly
                }
            }
            break :blk null;
        } else null;

        return .{
            .allocator = allocator,
            .logger = logger,
            .engine = options.engine,
            .engine_ctx = options.engine_ctx,
            .console_state = ConsoleState.init(allocator),
            .event_loop = ev_loop,
            ._engine_event_loop_storage = engine_event_loop_storage,
        };
    }

    /// Deinitialize context and cleanup resources
    pub fn deinit(self: *Self) void {
        // Clean up engine-created event loop if we have one
        if (self._engine_event_loop_storage) |loop_storage| {
            if (self.engine) |engine| {
                if (engine.destroyEventLoop) |destroy_fn| {
                    destroy_fn(loop_storage, self.allocator);
                }
            }
        }

        self.console_state.deinit(self.allocator);
        self.logger.deinit();
    }

    /// Check if this context has a JS engine
    pub fn hasEngine(self: *const Self) bool {
        return self.engine != null and self.engine_ctx != null;
    }

    /// Get the abstract engine interface
    pub fn getEngine(self: *const Self) ?*const EngineInterface {
        return self.engine;
    }

    /// Get the JS engine context (opaque pointer to V8 Isolate, JSC VM, etc.)
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
    const stub = @import("engine_interface.zig").stub_engine;
    var dummy_engine: u32 = 42;
    var ctx_data = try ContextData.init(testing.allocator, .{
        .engine = &stub,
        .engine_ctx = @ptrCast(&dummy_engine),
    });
    defer ctx_data.deinit();

    try testing.expect(ctx_data.hasEngine());
    const engine_ctx = ctx_data.getEngineContext();
    try testing.expect(engine_ctx != null);
    const engine = ctx_data.getEngine();
    try testing.expect(engine != null);
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
