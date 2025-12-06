//! Browser Adapter for WPT Runner
//!
//! This module adapts the new Browser module (src/browser/) to work with
//! the existing WPT test runner infrastructure. It provides:
//!
//! - Single Browser instance that persists across all tests
//! - Per-test navigation that creates new V8 contexts
//! - Integration with testharness.js result collection
//!
//! ## Migration Path
//!
//! The existing browser_context.zig creates a new V8 isolate per test, which is slow.
//! This adapter uses the Browser module which maintains a single isolate and creates
//! cheap (~1-5ms) contexts per navigation.
//!
//! ## Usage
//!
//! ```zig
//! const adapter = @import("browser_adapter.zig");
//!
//! // Create once at runner startup
//! var browser = try adapter.BrowserAdapter.init(allocator, wpt_root);
//! defer browser.deinit();
//!
//! // For each test
//! const result = try browser.runTest(test_path, test_content, timeout);
//! ```

const std = @import("std");
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;
const Context = browser_mod.Context;

const config = @import("config.zig");
const test_parser = @import("test_parser.zig");
const test_harness = @import("test_harness.zig");

// V8 and Runtime imports
const v8 = @import("v8");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const namespaces = @import("namespaces");

/// Adapter that wraps Browser for WPT test execution
pub const BrowserAdapter = struct {
    allocator: std.mem.Allocator,
    /// Single browser instance (maintained across all tests)
    browser: *Browser,
    /// WPT root directory
    wpt_root: []const u8,
    /// Result collector for current test
    result_collector: test_harness.ResultCollector,
    /// Testharness.js content (cached)
    testharness_content: ?[]const u8,
    /// Whether testharness.js has been loaded
    testharness_loaded: bool,

    /// Initialize the browser adapter
    ///
    /// Creates a single Browser instance that will be reused for all tests.
    pub fn init(allocator: std.mem.Allocator, wpt_root: []const u8) !*BrowserAdapter {
        const adapter = try allocator.create(BrowserAdapter);
        errdefer allocator.destroy(adapter);

        // Create browser with memory-only storage (no persistence needed for tests)
        const browser = try Browser.init(allocator, .{
            .persist_storage = false,
        });
        errdefer browser.deinit();

        adapter.* = BrowserAdapter{
            .allocator = allocator,
            .browser = browser,
            .wpt_root = try allocator.dupe(u8, wpt_root),
            .result_collector = test_harness.ResultCollector.init(allocator),
            .testharness_content = null,
            .testharness_loaded = false,
        };

        // Pre-load testharness.js content
        try adapter.loadTestharnessContent();

        return adapter;
    }

    /// Cleanup the adapter
    pub fn deinit(self: *BrowserAdapter) void {
        self.result_collector.deinit();
        if (self.testharness_content) |content| {
            self.allocator.free(content);
        }
        self.allocator.free(self.wpt_root);
        self.browser.deinit();
        self.allocator.destroy(self);
    }

    /// Load testharness.js content from disk
    fn loadTestharnessContent(self: *BrowserAdapter) !void {
        const harness_path = try std.fs.path.join(self.allocator, &.{ self.wpt_root, "resources", "testharness.js" });
        defer self.allocator.free(harness_path);

        const file = try std.fs.cwd().openFile(harness_path, .{});
        defer file.close();

        self.testharness_content = try file.readToEndAlloc(self.allocator, 10 * 1024 * 1024);
    }

    /// Run a single WPT test
    ///
    /// Navigates to a test URL, executes the test, and returns results.
    pub fn runTest(
        self: *BrowserAdapter,
        test_path: []const u8,
        test_content: []const u8,
        timeout: config.Timeout,
    ) !test_harness.TestResult {
        // Reset result collector for new test
        self.result_collector.completion_signaled = false;
        self.result_collector.completed = false;

        // Start tracking results for this test
        try self.result_collector.startTest(test_path);

        // Navigate to a blank page to create new context
        const test_url = try std.fmt.allocPrint(self.allocator, "http://web-platform.test:8000/{s}", .{test_path});
        defer self.allocator.free(test_url);

        try self.browser.navigate(test_url);

        // Get current context
        const ctx = self.browser.current_context orelse return error.NoContext;

        // Register WPT result callbacks on this context
        try self.registerWptCallbacks(ctx);

        // Load testharness.js
        if (self.testharness_content) |harness| {
            _ = try ctx.evaluateScript(harness);
        }

        // Load testharnessreport.js
        _ = try ctx.evaluateScript(test_harness.testharnessreport_js);

        // Execute the test content
        _ = try ctx.evaluateScript(test_content);

        // Trigger testharness completion
        try self.triggerTestHarnessCompletion(ctx);

        // Run event loop until completion or timeout
        const timeout_ms = timeout.toMillis();
        try self.runUntilComplete(timeout_ms);

        // Finalize and return results
        return self.result_collector.finalize(self.allocator, test_path);
    }

    /// Register WPT result callbacks (__wpt_report_result, __wpt_report_completion)
    fn registerWptCallbacks(self: *BrowserAdapter, ctx: *Context) !void {
        const isolate = ctx.isolate;
        const v8_ctx = ctx.v8_context orelse return error.NotInitialized;
        const global_obj = v8.ffi.v8_Context_Global(v8_ctx) orelse return error.NoGlobal;

        // Store collector pointer for callbacks
        setResultCollector(&self.result_collector);

        // Register __wpt_report_result callback
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, wptReportResultCallback, null) orelse return error.FunctionTemplateCreateFailed;
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "__wpt_report_result", 19) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }

        // Register __wpt_report_completion callback
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, wptReportCompletionCallback, null) orelse return error.FunctionTemplateCreateFailed;
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "__wpt_report_completion", 23) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }
    }

    /// Trigger testharness.js completion
    fn triggerTestHarnessCompletion(self: *BrowserAdapter, ctx: *Context) !void {
        _ = self;
        const completion_script =
            \\(function() {
            \\  if (typeof test_environment !== 'undefined') {
            \\    test_environment.all_loaded = true;
            \\  }
            \\  if (typeof done === 'function') {
            \\    setTimeout(function() { done(); }, 0);
            \\  }
            \\})();
        ;
        _ = try ctx.evaluateScript(completion_script);
    }

    /// Run event loop until completion or timeout
    fn runUntilComplete(self: *BrowserAdapter, timeout_ms: u64) !void {
        const event_loop = self.browser.event_loop orelse return error.NotInitialized;
        const start_time = std.time.milliTimestamp();

        while (true) {
            // Run one iteration
            _ = event_loop.eventLoop().runOnce();

            // Check if completion callback has been called
            if (self.result_collector.completed) {
                return;
            }

            // Check timeout
            const now = std.time.milliTimestamp();
            const elapsed: u64 = @intCast(now - start_time);
            if (elapsed > timeout_ms) {
                try self.result_collector.finishTest(.timeout, "Test timed out", elapsed);
                return;
            }

            // Short sleep
            std.Thread.sleep(1 * std.time.ns_per_ms);
        }
    }
};

// Thread-local storage for result collector
threadlocal var current_result_collector: ?*test_harness.ResultCollector = null;

fn setResultCollector(collector: *test_harness.ResultCollector) void {
    current_result_collector = collector;
}

fn getResultCollector() ?*test_harness.ResultCollector {
    return current_result_collector;
}

/// WPT result reporting callback
fn wptReportResultCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };

    const collector = getResultCollector() orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };

    const arg_count = info.v8_FunctionCallbackInfo_Length();
    if (arg_count < 2) {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Arg 0: name
    const name_value = info.get(0);
    const name_str = extractString(allocator, isolate, context, name_value) catch {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };
    defer allocator.free(name_str);

    // Arg 1: status
    const status_value = info.get(1);
    const status_num: u8 = if (v8.ffi.v8_Value_IsNumber(status_value))
        @intFromFloat(v8.ffi.v8_Value_NumberValue(status_value, context))
    else
        1;
    const status = test_harness.TestStatus.fromInt(status_num);

    // Arg 2: message (optional)
    var message_str: ?[]const u8 = null;
    var message_owned: ?[]u8 = null;
    if (arg_count > 2) {
        const msg_value = info.get(2);
        if (!v8.ffi.v8_Value_IsNull(msg_value) and !v8.ffi.v8_Value_IsUndefined(msg_value)) {
            message_owned = extractString(allocator, isolate, context, msg_value) catch null;
            message_str = message_owned;
        }
    }
    defer if (message_owned) |m| allocator.free(m);

    // Arg 3: stack (optional)
    var stack_str: ?[]const u8 = null;
    var stack_owned: ?[]u8 = null;
    if (arg_count > 3) {
        const stack_value = info.get(3);
        if (!v8.ffi.v8_Value_IsNull(stack_value) and !v8.ffi.v8_Value_IsUndefined(stack_value)) {
            stack_owned = extractString(allocator, isolate, context, stack_value) catch null;
            stack_str = stack_owned;
        }
    }
    defer if (stack_owned) |s| allocator.free(s);

    // Arg 4: duration
    var duration_ms: u64 = 0;
    if (arg_count > 4) {
        const duration_value = info.get(4);
        if (v8.ffi.v8_Value_IsNumber(duration_value)) {
            const duration_float = v8.ffi.v8_Value_NumberValue(duration_value, context);
            duration_ms = @intFromFloat(@max(0.0, duration_float));
        }
    }

    // Create subtest result
    const subtest = test_harness.SubtestResult{
        .name = collector.allocator.dupe(u8, name_str) catch {
            if (v8.ffi.v8_Undefined(isolate)) |undef| {
                info.setReturnValue(undef);
            }
            return;
        },
        .status = status,
        .message = if (message_str) |m| collector.allocator.dupe(u8, m) catch null else null,
        .stack = if (stack_str) |s| collector.allocator.dupe(u8, s) catch null else null,
        .duration_ms = duration_ms,
    };

    collector.addResult(subtest) catch {};

    if (v8.ffi.v8_Undefined(isolate)) |undef| {
        info.setReturnValue(undef);
    }
}

/// WPT completion callback
fn wptReportCompletionCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };

    const collector = getResultCollector() orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };

    const arg_count = info.v8_FunctionCallbackInfo_Length();

    // Arg 0: status
    var harness_status = test_harness.HarnessStatus.ok;
    if (arg_count > 0) {
        const status_value = info.get(0);
        if (v8.ffi.v8_Value_IsNumber(status_value)) {
            const status_num: u8 = @intFromFloat(v8.ffi.v8_Value_NumberValue(status_value, context));
            harness_status = test_harness.HarnessStatus.fromInt(status_num);
        }
    }

    // Arg 1: message (optional)
    if (arg_count > 1) {
        const msg_value = info.get(1);
        if (!v8.ffi.v8_Value_IsNull(msg_value) and !v8.ffi.v8_Value_IsUndefined(msg_value)) {
            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            const allocator = gpa.allocator();
            defer _ = gpa.deinit();

            if (extractString(allocator, isolate, context, msg_value)) |msg_str| {
                defer allocator.free(msg_str);
                collector.finishTest(harness_status, msg_str, 0) catch {};
                if (v8.ffi.v8_Undefined(isolate)) |undef| {
                    info.setReturnValue(undef);
                }
                return;
            } else |_| {}
        }
    }

    collector.finishTest(harness_status, null, 0) catch {};

    if (v8.ffi.v8_Undefined(isolate)) |undef| {
        info.setReturnValue(undef);
    }
}

/// Helper to extract string from V8 value
fn extractString(allocator: std.mem.Allocator, isolate: *v8.ffi.Isolate, context: *v8.ffi.Context, value: *v8.ffi.Value) ![]u8 {
    _ = isolate;
    const str = v8.ffi.v8_Value_ToString(value, context) orelse return error.StringConversionFailed;
    const len = v8.ffi.v8_String_Utf8Length(str);
    if (len <= 0) return allocator.dupe(u8, "");

    const buffer = try allocator.alloc(u8, @intCast(len));
    errdefer allocator.free(buffer);

    const written = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
    if (written <= 0) {
        allocator.free(buffer);
        return error.StringWriteFailed;
    }

    return buffer[0..@intCast(written)];
}
