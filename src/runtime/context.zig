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

/// Runtime context data structure
///
/// This struct contains all runtime services: logging, memory management,
/// and JS engine integration.
pub const ContextData = struct {
    allocator: std.mem.Allocator,
    logger: Logger,
    engine_ctx: ?*anyopaque,

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
    };

    /// Initialize a new runtime context
    pub fn init(allocator: std.mem.Allocator, options: Options) !Self {
        const logger = Logger.init(allocator, .{
            .colored = options.colored,
            .show_timestamp = options.show_timestamp,
            .show_labels = options.show_labels,
        });

        return .{
            .allocator = allocator,
            .logger = logger,
            .engine_ctx = options.engine_ctx,
        };
    }

    /// Deinitialize context and cleanup resources
    pub fn deinit(self: *Self) void {
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
