//! Mock WorkerGlobalScope for Service Workers
//!
//! TODO(html-spec): Replace this mock with real HTML WorkerGlobalScope
//! when the HTML specification workers section is implemented.
//! See: https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope
//!
//! WorkerGlobalScope is the base interface for all worker global scopes.
//! ServiceWorkerGlobalScope extends this interface.
//!
//! WebIDL:
//! ```idl
//! [Exposed=Worker]
//! interface WorkerGlobalScope : EventTarget {
//!   readonly attribute WorkerGlobalScope self;
//!   readonly attribute WorkerLocation location;
//!   readonly attribute WorkerNavigator navigator;
//!   undefined importScripts((TrustedScriptURL or USVString)... urls);
//!
//!   attribute OnErrorEventHandler onerror;
//!   attribute EventHandler onlanguagechange;
//!   attribute EventHandler onoffline;
//!   attribute EventHandler ononline;
//!   attribute EventHandler onrejectionhandled;
//!   attribute EventHandler onunhandledrejection;
//! };
//!
//! WorkerGlobalScope includes WindowOrWorkerGlobalScope;
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

const WorkerLocation = @import("worker_location.zig").WorkerLocation;
const WorkerNavigator = @import("worker_navigator.zig").WorkerNavigator;
const WorkerEventLoop = @import("worker_event_loop.zig").WorkerEventLoop;
const TaskSource = @import("worker_event_loop.zig").TaskSource;
const ScriptEvaluator = @import("script_evaluation.zig").ScriptEvaluator;
const MessagePort = @import("message_port.zig").MessagePort;
const EnvironmentSettingsObject = @import("environment.zig").EnvironmentSettingsObject;

/// Event handler type for worker events.
pub const EventHandler = ?*const fn (ctx: ?*anyopaque) void;

/// Error event handler type.
pub const OnErrorEventHandler = ?*const fn (
    message: []const u8,
    filename: []const u8,
    lineno: u32,
    colno: u32,
    error_obj: ?*anyopaque,
) bool;

/// Mock WorkerGlobalScope.
///
/// This is the base class for all worker global scopes including:
/// - DedicatedWorkerGlobalScope
/// - SharedWorkerGlobalScope
/// - ServiceWorkerGlobalScope
///
/// Each worker has its own global scope instance.
pub const WorkerGlobalScope = struct {
    allocator: Allocator,

    /// Self reference (per spec: "self" returns the global scope).
    /// This is set after construction.
    self_ref: ?*WorkerGlobalScope = null,

    /// The worker's location.
    location: *WorkerLocation,

    /// The worker's navigator.
    navigator: *WorkerNavigator,

    /// The event loop for this worker.
    event_loop: *WorkerEventLoop,

    /// Script evaluator for importScripts and worker script.
    script_evaluator: *ScriptEvaluator,

    /// Environment settings object.
    environment: ?*EnvironmentSettingsObject = null,

    /// Origin (from WindowOrWorkerGlobalScope mixin).
    origin: []const u8,

    /// Is this a secure context? (from WindowOrWorkerGlobalScope mixin).
    is_secure_context: bool = true,

    /// Cross-origin isolated capability (from WindowOrWorkerGlobalScope mixin).
    cross_origin_isolated: bool = false,

    // === Event Handlers ===

    /// Error handler.
    onerror: OnErrorEventHandler = null,

    /// Language change handler.
    onlanguagechange: EventHandler = null,

    /// Offline handler.
    onoffline: EventHandler = null,

    /// Online handler.
    ononline: EventHandler = null,

    /// Rejection handled handler.
    onrejectionhandled: EventHandler = null,

    /// Unhandled rejection handler.
    onunhandledrejection: EventHandler = null,

    // === Internal State ===

    /// Whether the worker is closing.
    closing: bool = false,

    /// Worker type (classic or module).
    worker_type: WorkerType = .classic,

    /// Message ports for this worker.
    ports: std.ArrayList(*MessagePort),

    const Self = @This();

    /// Worker type enum.
    pub const WorkerType = enum {
        classic,
        module,
    };

    /// Create a new WorkerGlobalScope.
    ///
    /// Parameters:
    /// - allocator: Memory allocator
    /// - script_url: URL of the worker script
    /// - worker_type: Classic or module worker
    pub fn init(
        allocator: Allocator,
        script_url: []const u8,
        worker_type: WorkerType,
    ) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Create location from script URL
        const location = try WorkerLocation.init(allocator, script_url);
        errdefer location.deinit();

        // Create navigator
        const navigator = try WorkerNavigator.init(allocator);
        errdefer navigator.deinit();

        // Create event loop
        const event_loop = try WorkerEventLoop.init(allocator);
        errdefer event_loop.deinit();

        // Create script evaluator
        const script_evaluator = try ScriptEvaluator.init(allocator);
        errdefer script_evaluator.deinit();

        // Extract origin from location
        const origin = try allocator.dupe(u8, location.origin);
        errdefer allocator.free(origin);

        self.* = .{
            .allocator = allocator,
            .location = location,
            .navigator = navigator,
            .event_loop = event_loop,
            .script_evaluator = script_evaluator,
            .origin = origin,
            .worker_type = worker_type,
            .ports = std.ArrayList(*MessagePort).init(allocator),
        };

        // Set self reference
        self.self_ref = self;

        return self;
    }

    pub fn deinit(self: *Self) void {
        // Close all ports
        for (self.ports.items) |port| {
            port.deinit();
        }
        self.ports.deinit();

        self.allocator.free(self.origin);
        self.script_evaluator.deinit();
        self.event_loop.deinit();
        self.navigator.deinit();
        self.location.deinit();

        if (self.environment) |env| {
            env.deinit();
        }

        self.allocator.destroy(self);
    }

    // === WebIDL Attributes ===

    /// Get self (the global scope).
    pub fn getSelf(self: *Self) *Self {
        return self.self_ref orelse self;
    }

    /// Get location.
    pub fn getLocation(self: *Self) *WorkerLocation {
        return self.location;
    }

    /// Get navigator.
    pub fn getNavigator(self: *Self) *WorkerNavigator {
        return self.navigator;
    }

    /// Get origin (from WindowOrWorkerGlobalScope).
    pub fn getOrigin(self: *const Self) []const u8 {
        return self.origin;
    }

    /// Get isSecureContext (from WindowOrWorkerGlobalScope).
    pub fn getIsSecureContext(self: *const Self) bool {
        return self.is_secure_context;
    }

    /// Get crossOriginIsolated (from WindowOrWorkerGlobalScope).
    pub fn getCrossOriginIsolated(self: *const Self) bool {
        return self.cross_origin_isolated;
    }

    // === WebIDL Methods ===

    /// Import scripts (classic workers only).
    ///
    /// Per HTML spec:
    /// - Fetches each URL synchronously
    /// - Evaluates scripts in order
    /// - Throws if any script fails
    ///
    /// Note: This is only valid for classic workers, not module workers.
    pub fn importScripts(self: *Self, urls: []const []const u8) !void {
        if (self.worker_type == .module) {
            return error.InvalidStateError; // importScripts not allowed in module workers
        }

        if (self.closing) {
            return; // Per spec, do nothing if closing
        }

        try self.script_evaluator.importScripts(urls);
    }

    // === WindowOrWorkerGlobalScope Methods ===

    /// Report an error.
    pub fn reportError(self: *Self, err: anyerror) void {
        _ = self;
        _ = err;
        // Mock: would fire error event in real implementation
    }

    /// btoa - encode to base64.
    pub fn btoa(self: *Self, data: []const u8) ![]const u8 {
        const encoder = std.base64.standard.Encoder;
        const size = encoder.calcSize(data.len);
        const buffer = try self.allocator.alloc(u8, size);
        _ = encoder.encode(buffer, data);
        return buffer;
    }

    /// atob - decode from base64.
    pub fn atob(self: *Self, data: []const u8) ![]const u8 {
        const decoder = std.base64.standard.Decoder;
        const size = try decoder.calcSizeForSlice(data);
        const buffer = try self.allocator.alloc(u8, size);
        try decoder.decode(buffer, data);
        return buffer;
    }

    /// Queue a microtask.
    pub fn queueMicrotask(self: *Self, callback: *const fn (?*anyopaque) void, context: ?*anyopaque) void {
        _ = self.event_loop.queueMicrotask(callback, context);
    }

    /// Set timeout (returns timer ID).
    pub fn setTimeout(
        self: *Self,
        callback: *const fn (?*anyopaque) void,
        timeout_ms: i32,
        context: ?*anyopaque,
    ) u64 {
        _ = timeout_ms; // Mock doesn't actually delay
        return self.event_loop.queueTask(.timer, callback, context);
    }

    /// Clear timeout.
    pub fn clearTimeout(self: *Self, id: u64) void {
        _ = self.event_loop.cancelTask(id);
    }

    /// Set interval (returns timer ID).
    /// Note: Mock doesn't actually repeat, just queues once.
    pub fn setInterval(
        self: *Self,
        callback: *const fn (?*anyopaque) void,
        interval_ms: i32,
        context: ?*anyopaque,
    ) u64 {
        _ = interval_ms;
        return self.event_loop.queueTask(.timer, callback, context);
    }

    /// Clear interval.
    pub fn clearInterval(self: *Self, id: u64) void {
        _ = self.event_loop.cancelTask(id);
    }

    // === Internal Methods ===

    /// Close the worker (internal).
    pub fn close(self: *Self) void {
        self.closing = true;
        self.event_loop.terminate();
    }

    /// Check if the worker is closing.
    pub fn isClosing(self: *const Self) bool {
        return self.closing;
    }

    /// Run the event loop (for testing).
    pub fn runEventLoop(self: *Self) void {
        self.event_loop.runAllTasks();
    }

    /// Queue a task on this worker's event loop.
    pub fn queueTask(
        self: *Self,
        source: TaskSource,
        callback: *const fn (?*anyopaque) void,
        context: ?*anyopaque,
    ) u64 {
        return self.event_loop.queueTask(source, callback, context);
    }

    /// Add a message port to this worker.
    pub fn addPort(self: *Self, port: *MessagePort) !void {
        try self.ports.append(port);
    }

    /// Dispatch an error.
    pub fn dispatchError(
        self: *Self,
        message: []const u8,
        filename: []const u8,
        lineno: u32,
        colno: u32,
    ) void {
        if (self.onerror) |handler| {
            _ = handler(message, filename, lineno, colno, null);
        }
    }
};

// =============================================================================
// Tests
// =============================================================================

test "WorkerGlobalScope.init and deinit" {
    const allocator = std.testing.allocator;

    const scope = try WorkerGlobalScope.init(
        allocator,
        "https://example.com/worker.js",
        .classic,
    );
    defer scope.deinit();

    try std.testing.expectEqualStrings("https://example.com", scope.getOrigin());
    try std.testing.expect(scope.getIsSecureContext());
}

test "WorkerGlobalScope.getSelf returns self" {
    const allocator = std.testing.allocator;

    const scope = try WorkerGlobalScope.init(
        allocator,
        "https://example.com/worker.js",
        .classic,
    );
    defer scope.deinit();

    try std.testing.expectEqual(scope, scope.getSelf());
}

test "WorkerGlobalScope.getLocation" {
    const allocator = std.testing.allocator;

    const scope = try WorkerGlobalScope.init(
        allocator,
        "https://example.com/worker.js",
        .classic,
    );
    defer scope.deinit();

    const loc = scope.getLocation();
    try std.testing.expectEqualStrings("https://example.com/worker.js", loc.href);
}

test "WorkerGlobalScope.getNavigator" {
    const allocator = std.testing.allocator;

    const scope = try WorkerGlobalScope.init(
        allocator,
        "https://example.com/worker.js",
        .classic,
    );
    defer scope.deinit();

    const nav = scope.getNavigator();
    try std.testing.expectEqualStrings("Mozilla", nav.getAppCodeName());
}

test "WorkerGlobalScope.importScripts for classic worker" {
    const allocator = std.testing.allocator;

    const scope = try WorkerGlobalScope.init(
        allocator,
        "https://example.com/worker.js",
        .classic,
    );
    defer scope.deinit();

    const urls = [_][]const u8{"https://example.com/lib.js"};
    try scope.importScripts(&urls);

    try std.testing.expect(scope.script_evaluator.hasEvaluated("https://example.com/lib.js"));
}

test "WorkerGlobalScope.importScripts fails for module worker" {
    const allocator = std.testing.allocator;

    const scope = try WorkerGlobalScope.init(
        allocator,
        "https://example.com/worker.js",
        .module,
    );
    defer scope.deinit();

    const urls = [_][]const u8{"https://example.com/lib.js"};
    const result = scope.importScripts(&urls);

    try std.testing.expectError(error.InvalidStateError, result);
}

test "WorkerGlobalScope.queueTask and runEventLoop" {
    const allocator = std.testing.allocator;

    const scope = try WorkerGlobalScope.init(
        allocator,
        "https://example.com/worker.js",
        .classic,
    );
    defer scope.deinit();

    var executed = false;
    _ = scope.queueTask(.generic, struct {
        fn callback(ctx: ?*anyopaque) void {
            const ptr: *bool = @ptrCast(@alignCast(ctx.?));
            ptr.* = true;
        }
    }.callback, @ptrCast(&executed));

    scope.runEventLoop();
    try std.testing.expect(executed);
}

test "WorkerGlobalScope.setTimeout" {
    const allocator = std.testing.allocator;

    const scope = try WorkerGlobalScope.init(
        allocator,
        "https://example.com/worker.js",
        .classic,
    );
    defer scope.deinit();

    var executed = false;
    _ = scope.setTimeout(struct {
        fn callback(ctx: ?*anyopaque) void {
            const ptr: *bool = @ptrCast(@alignCast(ctx.?));
            ptr.* = true;
        }
    }.callback, 0, @ptrCast(&executed));

    scope.runEventLoop();
    try std.testing.expect(executed);
}

test "WorkerGlobalScope.clearTimeout cancels timer" {
    const allocator = std.testing.allocator;

    const scope = try WorkerGlobalScope.init(
        allocator,
        "https://example.com/worker.js",
        .classic,
    );
    defer scope.deinit();

    var executed = false;
    const id = scope.setTimeout(struct {
        fn callback(ctx: ?*anyopaque) void {
            const ptr: *bool = @ptrCast(@alignCast(ctx.?));
            ptr.* = true;
        }
    }.callback, 0, @ptrCast(&executed));

    scope.clearTimeout(id);
    scope.runEventLoop();
    try std.testing.expect(!executed);
}

test "WorkerGlobalScope.close" {
    const allocator = std.testing.allocator;

    const scope = try WorkerGlobalScope.init(
        allocator,
        "https://example.com/worker.js",
        .classic,
    );
    defer scope.deinit();

    try std.testing.expect(!scope.isClosing());

    scope.close();
    try std.testing.expect(scope.isClosing());
}

test "WorkerGlobalScope.btoa and atob" {
    const allocator = std.testing.allocator;

    const scope = try WorkerGlobalScope.init(
        allocator,
        "https://example.com/worker.js",
        .classic,
    );
    defer scope.deinit();

    const encoded = try scope.btoa("hello");
    defer allocator.free(encoded);

    try std.testing.expectEqualStrings("aGVsbG8=", encoded);

    const decoded = try scope.atob("aGVsbG8=");
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings("hello", decoded);
}
