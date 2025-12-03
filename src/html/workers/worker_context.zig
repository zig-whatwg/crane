//! Worker Context Isolation
//!
//! Spec: HTML Standard § 10.1.4 Worker Event Loops
//! https://html.spec.whatwg.org/#worker-event-loop
//!
//! This module provides context isolation for workers. Each worker runs in
//! its own context, ensuring:
//! - Variables don't leak between workers and main thread
//! - Workers can't access main thread DOM
//! - Each worker has its own global scope (WorkerGlobalScope)
//!
//! ## Architecture
//!
//! Phase A: Same-thread isolation (implemented here)
//! - Create new execution context for each worker
//! - Set up WorkerGlobalScope as global object
//! - Run worker event loop interleaved with main
//!
//! Phase B: True threading (future)
//! - Create new isolate per worker
//! - Run on separate OS thread
//!
//! ## Design Note
//!
//! This module is part of html_core and cannot directly import runtime.
//! V8 integration is handled externally - the worker_context provides
//! the infrastructure for context isolation, and V8 context creation
//! happens through the full html module which has access to runtime.

const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const WorkerType = types.WorkerType;

// Platform and event loop
const platform_mod = @import("platform");
const timer_backend = platform_mod.timer_backend;
const TimerBackend = timer_backend.TimerBackend;

const event_loop_mod = @import("../event_loop/event_loop.zig");
const EventLoop = event_loop_mod.EventLoop;

/// Opaque engine context pointer
/// This is set by external code (html module) that has access to V8
const EngineContext = opaque {};

/// Engine callback interface
/// These function pointers are set by the html module to provide V8 integration
pub const EngineCallbacks = struct {
    /// Compile and run a script, returns result value pointer
    compileAndRunScript: ?*const fn (
        engine_ctx: *EngineContext,
        source: []const u8,
        source_url: []const u8,
    ) anyerror!?*anyopaque = null,

    /// Compile and run a module
    compileAndRunModule: ?*const fn (
        engine_ctx: *EngineContext,
        source: []const u8,
        source_url: []const u8,
    ) anyerror!void = null,

    /// Run microtask checkpoint
    runMicrotasks: ?*const fn (engine_ctx: *EngineContext) void = null,

    /// Dispose engine context
    disposeContext: ?*const fn (engine_ctx: *EngineContext) void = null,
};

/// Worker Context - Provides isolated execution environment for a worker
///
/// Spec: HTML Standard § 10.1.4
/// "A dedicated worker agent, shared worker agent, or service worker agent is
/// an agent whose [[CanBlock]] is true."
///
/// Each worker context has:
/// - Its own event loop
/// - Its own engine context (may be null if engine not available)
/// - Its own global scope (WorkerGlobalScope)
pub const WorkerContext = struct {
    /// Worker event loop
    event_loop: EventLoop,

    /// Engine context (opaque, managed by external code)
    /// This is a V8 Context pointer when V8 is available
    engine_ctx: ?*EngineContext,

    /// Engine callbacks (set by external code for V8 integration)
    callbacks: EngineCallbacks,

    /// Worker script URL
    script_url: []const u8,

    /// Worker type (classic or module)
    worker_type: WorkerType,

    /// Worker name (for debugging)
    name: []const u8,

    /// Is the worker closing
    closing: bool,

    /// Allocator
    allocator: Allocator,

    /// Platform timer backend
    platform: TimerBackend,

    /// Initialize a new worker context
    ///
    /// Creates a new execution context for the worker.
    /// Engine context must be set separately via setEngineContext.
    ///
    /// Spec: HTML Standard § 10.2.5 step 12
    /// "Let realm be a new Realm Record."
    pub fn init(
        allocator: Allocator,
        platform: TimerBackend,
        script_url: []const u8,
        worker_type: WorkerType,
        name: []const u8,
    ) !*WorkerContext {
        const ctx = try allocator.create(WorkerContext);
        errdefer allocator.destroy(ctx);

        // Copy strings
        const url_copy = try allocator.dupe(u8, script_url);
        errdefer allocator.free(url_copy);

        const name_copy = if (name.len > 0)
            try allocator.dupe(u8, name)
        else
            "";
        errdefer if (name_copy.len > 0) allocator.free(name_copy);

        // Create event loop for worker
        const event_loop = try EventLoop.init(allocator, .worker, platform);
        errdefer event_loop.deinit();

        ctx.* = .{
            .event_loop = event_loop,
            .engine_ctx = null,
            .callbacks = .{},
            .script_url = url_copy,
            .worker_type = worker_type,
            .name = name_copy,
            .closing = false,
            .allocator = allocator,
            .platform = platform,
        };

        return ctx;
    }

    /// Free all resources
    pub fn deinit(self: *WorkerContext) void {
        // Dispose engine context if present
        if (self.engine_ctx) |engine_ctx| {
            if (self.callbacks.disposeContext) |dispose_fn| {
                dispose_fn(engine_ctx);
            }
        }

        // Clean up event loop
        self.event_loop.deinit();

        // Free strings
        self.allocator.free(self.script_url);
        if (self.name.len > 0) {
            self.allocator.free(self.name);
        }

        self.allocator.destroy(self);
    }

    /// Set the engine context (V8 context)
    ///
    /// Called by external code that creates the V8 context.
    pub fn setEngineContext(
        self: *WorkerContext,
        engine_ctx: *EngineContext,
        callbacks: EngineCallbacks,
    ) void {
        self.engine_ctx = engine_ctx;
        self.callbacks = callbacks;
    }

    /// Execute a script in this worker's context
    ///
    /// Compiles and runs the provided JavaScript source code.
    ///
    /// Spec: HTML Standard § 10.2.5 step 24
    /// "Run the classic script scriptOrModule."
    pub fn executeScript(self: *WorkerContext, source: []const u8) !?*anyopaque {
        const engine_ctx = self.engine_ctx orelse return error.NoEngineContext;
        const compile_fn = self.callbacks.compileAndRunScript orelse return error.EngineNotConfigured;

        return try compile_fn(engine_ctx, source, self.script_url);
    }

    /// Execute a module in this worker's context
    ///
    /// Compiles, instantiates, and evaluates an ES module.
    ///
    /// Spec: HTML Standard § 10.2.5 step 24 (for type: "module")
    /// "Run the module script scriptOrModule."
    pub fn executeModule(self: *WorkerContext, source: []const u8) !void {
        const engine_ctx = self.engine_ctx orelse return error.NoEngineContext;
        const compile_fn = self.callbacks.compileAndRunModule orelse return error.EngineNotConfigured;

        try compile_fn(engine_ctx, source, self.script_url);
    }

    /// Run a single iteration of the worker's event loop
    ///
    /// Processes pending tasks and microtasks.
    ///
    /// Spec: HTML Standard § 10.1.4
    /// "Run the responsible event loop specified by inside settings."
    pub fn spin(self: *WorkerContext) !void {
        if (self.closing) {
            return;
        }

        // Run event loop iteration
        try self.event_loop.spin();

        // Run engine microtasks if available
        if (self.engine_ctx) |engine_ctx| {
            if (self.callbacks.runMicrotasks) |microtask_fn| {
                microtask_fn(engine_ctx);
            }
        }
    }

    /// Run the worker's event loop until stopped
    pub fn run(self: *WorkerContext) !void {
        while (!self.closing) {
            try self.spin();
        }
    }

    /// Close the worker context
    ///
    /// Spec: HTML Standard § 10.2.4.1
    /// "To close a worker, given a WorkerGlobalScope object workerGlobal"
    pub fn close(self: *WorkerContext) void {
        self.closing = true;
        self.event_loop.stop();
    }

    /// Check if the context has an engine context
    pub fn hasEngineContext(self: *const WorkerContext) bool {
        return self.engine_ctx != null;
    }

    /// Check if the worker is closing
    pub fn isClosing(self: *const WorkerContext) bool {
        return self.closing;
    }

    /// Get a pointer to the event loop.
    ///
    /// Used to wire up timer APIs in WorkerGlobalScope.
    /// The caller should pass this to WorkerGlobalScope.setEventLoop().
    pub fn getEventLoop(self: *WorkerContext) *EventLoop {
        return &self.event_loop;
    }
};

/// Worker Context Error types
pub const WorkerContextError = error{
    NoEngineContext,
    EngineNotConfigured,
    CompilationFailed,
    ModuleCompilationFailed,
    OutOfMemory,
};

// ============================================================================
// Tests
// ============================================================================

test "WorkerContext - init and deinit" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const ctx = try WorkerContext.init(
        allocator,
        mock.backend(),
        "https://example.com/worker.js",
        .classic,
        "test-worker",
    );
    defer ctx.deinit();

    try std.testing.expectEqualStrings("https://example.com/worker.js", ctx.script_url);
    try std.testing.expectEqualStrings("test-worker", ctx.name);
    try std.testing.expectEqual(WorkerType.classic, ctx.worker_type);
    try std.testing.expect(!ctx.closing);
    try std.testing.expect(!ctx.hasEngineContext());
}

test "WorkerContext - lifecycle" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const ctx = try WorkerContext.init(
        allocator,
        mock.backend(),
        "https://example.com/worker.js",
        .module,
        "",
    );
    defer ctx.deinit();

    try std.testing.expectEqual(WorkerType.module, ctx.worker_type);

    // Close
    ctx.close();
    try std.testing.expect(ctx.isClosing());
}

test "WorkerContext - empty name" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const ctx = try WorkerContext.init(
        allocator,
        mock.backend(),
        "https://example.com/worker.js",
        .classic,
        "",
    );
    defer ctx.deinit();

    try std.testing.expectEqualStrings("", ctx.name);
}

test "WorkerContext - executeScript without engine returns error" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const ctx = try WorkerContext.init(
        allocator,
        mock.backend(),
        "https://example.com/worker.js",
        .classic,
        "",
    );
    defer ctx.deinit();

    // Without engine context, should return error
    try std.testing.expectError(error.NoEngineContext, ctx.executeScript("console.log('test')"));
}
