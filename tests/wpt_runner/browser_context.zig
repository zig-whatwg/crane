//! WPT Browser Context Setup
//!
//! This module creates and manages browser-like execution contexts for WPT tests.
//! It sets up Window/WorkerGlobalScope as the global object in V8 and registers
//! all required browser globals (document, navigator, location, history, etc.).
//!
//! ## Context Types
//!
//! - `WindowContext` - For .window.js and .html tests
//!   - window, document, self, globalThis
//!   - navigator, location, history
//!   - console, setTimeout, setInterval
//!
//! - `WorkerContext` - For .worker.js tests
//!   - self (WorkerGlobalScope)
//!   - navigator, location
//!   - postMessage, close, importScripts
//!
//! ## Usage
//!
//! ```zig
//! var ctx = try BrowserContext.initWindow(allocator);
//! defer ctx.deinit();
//!
//! try ctx.loadScript("/resources/testharness.js");
//! try ctx.loadScript("/resources/testharnessreport.js");
//! const result = try ctx.executeTest(test_content);
//! ```

const std = @import("std");
const config = @import("config.zig");
const test_parser = @import("test_parser.zig");
const test_harness = @import("test_harness.zig");

/// Execution context type
pub const ContextType = enum {
    /// Window/document context (for .window.js, .html tests)
    window,
    /// Dedicated worker context (for .worker.js tests)
    worker,
    /// Shared worker context
    shared_worker,
    /// Service worker context
    service_worker,
};

/// Browser-like execution context for WPT tests
pub const BrowserContext = struct {
    allocator: std.mem.Allocator,
    context_type: ContextType,
    /// Result collector for this context
    result_collector: test_harness.ResultCollector,
    /// WPT root directory
    wpt_root: []const u8,
    /// Current test URL (for location object)
    test_url: []const u8,
    /// Whether context is ready for execution
    initialized: bool = false,

    // TODO: Add V8 isolate and context handles
    // v8_isolate: ?*v8.Isolate = null,
    // v8_context: ?*v8.Context = null,

    pub fn init(allocator: std.mem.Allocator, context_type: ContextType, wpt_root: []const u8) !BrowserContext {
        return BrowserContext{
            .allocator = allocator,
            .context_type = context_type,
            .result_collector = test_harness.ResultCollector.init(allocator),
            .wpt_root = try allocator.dupe(u8, wpt_root),
            .test_url = try allocator.dupe(u8, "about:blank"),
        };
    }

    pub fn deinit(self: *BrowserContext) void {
        self.result_collector.deinit();
        self.allocator.free(self.wpt_root);
        self.allocator.free(self.test_url);

        // TODO: Clean up V8 context
        // if (self.v8_context) |ctx| ctx.dispose();
        // if (self.v8_isolate) |isolate| isolate.dispose();
    }

    /// Initialize the V8 context with browser globals
    pub fn initialize(self: *BrowserContext) !void {
        // TODO: Implement V8 context setup
        //
        // 1. Create V8 isolate (or reuse)
        // 2. Create V8 context with global object template
        // 3. Set up global object based on context_type:
        //    - Window: window, document, self, globalThis, navigator, location, history
        //    - Worker: self, navigator, location, postMessage, close
        // 4. Register native callbacks for __wpt_report_result and __wpt_report_completion
        // 5. Set up console, setTimeout, setInterval
        //
        // Reference: src/runtime/engines/v8/ for V8 integration patterns
        // Reference: tools/repl.zig for global registration

        self.initialized = true;
    }

    /// Set the test URL (updates location object)
    pub fn setTestUrl(self: *BrowserContext, url: []const u8) !void {
        self.allocator.free(self.test_url);
        self.test_url = try self.allocator.dupe(u8, url);

        // TODO: Update location object in V8 context
    }

    /// Load and execute a script file
    pub fn loadScript(self: *BrowserContext, script_path: []const u8) !void {
        _ = self;
        _ = script_path;
        // TODO: Implement script loading
        //
        // 1. Resolve script path (absolute vs relative)
        // 2. Read script content from file
        // 3. Compile and execute in V8 context
        // 4. Handle script errors
    }

    /// Load testharness.js and testharnessreport.js
    pub fn loadTestHarness(self: *BrowserContext) !void {
        const harness_path = try std.fs.path.join(self.allocator, &.{ self.wpt_root, "resources", "testharness.js" });
        defer self.allocator.free(harness_path);

        try self.loadScript(harness_path);

        // Load our custom testharnessreport.js content (inline)
        try self.executeScript(test_harness.testharnessreport_js);
    }

    /// Execute inline script content
    pub fn executeScript(self: *BrowserContext, content: []const u8) !void {
        _ = self;
        _ = content;
        // TODO: Implement script execution
        //
        // 1. Compile script in V8 context
        // 2. Execute script
        // 3. Handle exceptions
        // 4. Run microtasks
    }

    /// Execute a test and wait for completion
    pub fn executeTest(self: *BrowserContext, test_content: []const u8, timeout: config.Timeout) !test_harness.TestResult {
        _ = self;
        _ = test_content;
        _ = timeout;
        // TODO: Implement test execution
        //
        // 1. Execute test script
        // 2. Run event loop until completion callback fires
        // 3. Handle timeout (watchdog timer)
        // 4. Collect and return results
        //
        // Return placeholder for now
        return error.NotImplemented;
    }

    /// Run event loop until completion or timeout
    pub fn runEventLoop(self: *BrowserContext, timeout_ms: u64) !void {
        _ = self;
        _ = timeout_ms;
        // TODO: Implement event loop
        //
        // 1. Process pending tasks
        // 2. Run V8 microtasks
        // 3. Process timers (setTimeout, setInterval)
        // 4. Check for completion callback
        // 5. Check for timeout
    }

    /// Register native callback functions for test result reporting
    fn registerNativeCallbacks(self: *BrowserContext) !void {
        _ = self;
        // TODO: Register __wpt_report_result and __wpt_report_completion
        //
        // These functions are called by testharnessreport.js to report results
        // back to Zig. They should update self.result_collector.
    }
};

/// Create a window context for .window.js and .html tests
pub fn createWindowContext(allocator: std.mem.Allocator, wpt_root: []const u8) !BrowserContext {
    var ctx = try BrowserContext.init(allocator, .window, wpt_root);
    errdefer ctx.deinit();

    try ctx.initialize();
    return ctx;
}

/// Create a worker context for .worker.js tests
pub fn createWorkerContext(allocator: std.mem.Allocator, wpt_root: []const u8) !BrowserContext {
    var ctx = try BrowserContext.init(allocator, .worker, wpt_root);
    errdefer ctx.deinit();

    try ctx.initialize();
    return ctx;
}

/// Create context appropriate for the test file type
pub fn createContextForTest(
    allocator: std.mem.Allocator,
    wpt_root: []const u8,
    global_type: test_parser.GlobalType,
) !BrowserContext {
    const context_type: ContextType = switch (global_type) {
        .window => .window,
        .worker => .worker,
        .sharedworker => .shared_worker,
        .serviceworker => .service_worker,
    };

    var ctx = try BrowserContext.init(allocator, context_type, wpt_root);
    errdefer ctx.deinit();

    try ctx.initialize();
    return ctx;
}

test "BrowserContext basic init" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var ctx = try BrowserContext.init(allocator, .window, "tests/wpt");
    defer ctx.deinit();

    try testing.expectEqual(ContextType.window, ctx.context_type);
    try testing.expectEqualStrings("tests/wpt", ctx.wpt_root);
}

test "createContextForTest" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var ctx = try createContextForTest(allocator, "tests/wpt", .worker);
    defer ctx.deinit();

    try testing.expectEqual(ContextType.worker, ctx.context_type);
}
