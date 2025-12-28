//! WPT Browser Adapter
//!
//! This module wraps the production Browser API from `src/browser/` and adds
//! WPT-specific functionality like testharness.js loading and test completion detection.
//!
//! ## Architecture
//!
//! ```
//! WptBrowser (this file)
//!     │
//!     ├── Uses Browser (src/browser/Browser.zig) for:
//!     │   - V8 isolate management (single isolate, multiple contexts)
//!     │   - Context creation with proper WebIDL bindings
//!     │   - Event loop with libuv timers
//!     │   - HTML parsing with script execution
//!     │
//!     └── Adds WPT-specific:
//!         - testharness.js loading
//!         - Test completion detection via add_completion_callback
//!         - Test result collection
//!         - Script loading from WPT root
//! ```
//!
//! ## Why This Exists
//!
//! The Browser API in `src/browser/` is a general-purpose headless browser.
//! WPT tests need additional functionality:
//! - Loading testharness.js before each test
//! - Detecting when tests complete (via completion callbacks)
//! - Collecting test results in a specific format
//! - Loading scripts relative to WPT root
//!
//! This adapter provides that functionality while delegating core browser
//! behavior to the production Browser implementation.

const std = @import("std");
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;
const Context = browser_mod.Context;
const html = @import("html");

const test_harness = @import("test_harness.zig");
const test_parser = @import("test_parser.zig");
const config = @import("config.zig");

/// Apply WPT URL rewrites (matching wpt serve behavior from tools/serve/serve.py)
/// These rewrites map friendly URLs to the actual file locations
fn applyWptRewrites(url: []const u8) []const u8 {
    // WebIDLParser.js -> webidl2.js (the actual file location)
    if (std.mem.eql(u8, url, "/resources/WebIDLParser.js")) {
        return "/resources/webidl2/lib/webidl2.js";
    }
    // Add more rewrites here as needed (from tools/serve/serve.py and tools/wpt/testfiles.py)
    return url;
}

/// WPT Browser - wraps Browser API with WPT-specific functionality
pub const WptBrowser = struct {
    allocator: std.mem.Allocator,
    /// Underlying browser instance (manages V8 isolate and event loop)
    browser: *Browser,
    /// WPT root directory for loading scripts
    wpt_root: []const u8,
    /// Cached testharness.js content
    testharness_js: ?[]const u8,
    /// Cached testharnessreport.js content
    testharnessreport_js: ?[]const u8,
    /// Number of tests run
    tests_run: usize,

    /// Initialize WptBrowser with a fresh Browser instance
    pub fn init(allocator: std.mem.Allocator, wpt_root: []const u8) !*WptBrowser {
        const self = try allocator.create(WptBrowser);
        errdefer allocator.destroy(self);

        // Create the underlying browser (manages V8 isolate)
        const browser_instance = try Browser.init(allocator, .{
            .log_performance = true,
        });
        errdefer browser_instance.deinit();

        self.* = WptBrowser{
            .allocator = allocator,
            .browser = browser_instance,
            .wpt_root = try allocator.dupe(u8, wpt_root),
            .testharness_js = null,
            .testharnessreport_js = null,
            .tests_run = 0,
        };

        // Pre-load testharness.js for efficiency
        self.testharness_js = self.loadWptScript("resources/testharness.js") catch null;
        self.testharnessreport_js = self.loadWptScript("resources/testharnessreport.js") catch null;

        return self;
    }

    /// Cleanup
    pub fn deinit(self: *WptBrowser) void {
        if (self.testharness_js) |js| {
            self.allocator.free(js);
        }
        if (self.testharnessreport_js) |js| {
            self.allocator.free(js);
        }
        self.allocator.free(self.wpt_root);
        self.browser.deinit();
        self.allocator.destroy(self);
    }

    /// Load a script from WPT root
    fn loadWptScript(self: *WptBrowser, relative_path: []const u8) ![]const u8 {
        const full_path = try std.fs.path.join(self.allocator, &.{ self.wpt_root, relative_path });
        defer self.allocator.free(full_path);

        // Use cwd-relative open since wpt_root may not be absolute
        const file = std.fs.cwd().openFile(full_path, .{}) catch |err| {
            std.debug.print("Failed to open WPT script: {s} - {}\n", .{ full_path, err });
            return err;
        };
        defer file.close();

        const stat = try file.stat();
        const content = try self.allocator.alloc(u8, stat.size);
        errdefer self.allocator.free(content);

        const bytes_read = try file.readAll(content);
        if (bytes_read != stat.size) {
            return error.IncompleteRead;
        }

        return content;
    }

    /// Run a JavaScript test
    ///
    /// Creates a fresh context, loads testharness.js, executes the test,
    /// and waits for completion.
    pub fn runTest(
        self: *WptBrowser,
        test_path: []const u8,
        test_content: []const u8,
        timeout: config.Timeout,
        context_type: test_parser.GlobalType,
    ) !test_harness.TestResult {
        // Map GlobalType to Context.ContextType
        const ctx_type: Context.ContextType = switch (context_type) {
            .window => .window,
            .worker => .worker,
            .sharedworker => .shared_worker,
            .serviceworker => .service_worker,
            // ShadowRealm variants map to window for now
            else => .window,
        };

        // Build test URL
        const test_url = try self.buildTestUrl(test_path);
        defer self.allocator.free(test_url);

        // Navigate to create fresh context
        try self.browser.navigate(test_url, ctx_type);

        // Get the context
        const ctx = self.browser.current_context orelse return error.NoContext;

        // Load testharness.js
        try self.loadTestHarness(ctx);

        // Execute the test script
        _ = ctx.evaluateScript(test_content) catch |err| {
            return test_harness.TestResult{
                .status = .@"error",
                .message = try std.fmt.allocPrint(self.allocator, "Script execution error: {}", .{err}),
                .subtests = .{},
                .duration_ms = 0,
            };
        };

        // Run event loop until test completes or timeout
        const timeout_ms = timeout.toMillis();
        const result = try self.waitForCompletion(ctx, timeout_ms, test_path);

        self.tests_run += 1;
        return result;
    }

    /// Run an HTML test
    ///
    /// Parses HTML, executes scripts during parsing, and waits for completion.
    pub fn runHTMLTest(
        self: *WptBrowser,
        test_path: []const u8,
        html_content: []const u8,
        base_url: []const u8,
        timeout_ms: u64,
        context_type: browser_mod.ContextType,
    ) !test_harness.TestResult {
        // Navigate to create fresh context with the specified context type
        try self.browser.navigate(base_url, context_type);

        // Get the context
        const ctx = self.browser.current_context orelse return error.NoContext;

        // Let the browser handle ALL script loading naturally via HTTP
        // No pre-loading, no script interception - this is how a real browser works
        ctx.loadHTML(html_content, .{
            .base_url = base_url,
            .scripting_enabled = true,
            // No script_loader - browser fetches scripts via HTTP
        }) catch |err| {
            var result = try test_harness.TestResult.init(self.allocator, test_path);
            result.status = .@"error";
            result.message = try std.fmt.allocPrint(self.allocator, "HTML parse error: {}", .{err});
            return result;
        };

        // Set up completion callback AFTER HTML parsing
        // testharness.js should now be loaded and its globals available
        try self.setupCompletionCallback(ctx);

        // Run event loop until test completes or timeout
        const result = try self.waitForCompletion(ctx, timeout_ms, test_path);

        self.tests_run += 1;
        return result;
    }

    /// Set up completion callback AFTER HTML parsing
    /// testharness.js should have been loaded by the HTML parser via HTTP
    fn setupCompletionCallback(self: *WptBrowser, ctx: *Context) !void {
        _ = self;

        // Set up completion callback to capture results
        // This runs after testharness.js has been loaded by the HTML parser
        const setup_script =
            \\(function() {
            \\  // Check if testharness.js was loaded
            \\  if (typeof add_completion_callback !== 'function') {
            \\    console.log('[WPT] testharness.js not loaded - skipping completion callback setup');
            \\    window.__wpt_complete = true;  // Mark as complete to avoid timeout
            \\    window.__wpt_results = { status: 2, message: 'testharness.js not loaded', tests: [] };
            \\    return;
            \\  }
            \\  
            \\  console.log('[WPT] Setting up completion callback...');
            \\  
            \\  // Store test results for collection
            \\  window.__wpt_results = null;
            \\  window.__wpt_complete = false;
            \\  
            \\  // Register completion callback
            \\  add_completion_callback(function(tests, harness_status) {
            \\    console.log('[WPT] Completion callback invoked!');
            \\    console.log('[WPT] tests count: ' + tests.length);
            \\    console.log('[WPT] harness_status.status: ' + harness_status.status);
            \\    window.__wpt_results = {
            \\      status: harness_status.status,
            \\      message: harness_status.message || null,
            \\      tests: tests.map(function(t) {
            \\        return {
            \\          name: t.name,
            \\          status: t.status,
            \\          message: t.message || null
            \\        };
            \\      })
            \\    };
            \\    window.__wpt_complete = true;
            \\    console.log('[WPT] __wpt_complete set to true');
            \\  });
            \\  
            \\  console.log('[WPT] Completion callback registered');
            \\})();
        ;
        _ = try ctx.evaluateScript(setup_script);
    }

    /// Wait for test completion by polling __wpt_complete
    fn waitForCompletion(self: *WptBrowser, ctx: *Context, timeout_ms: u64, test_path: []const u8) !test_harness.TestResult {
        const start_time = std.time.milliTimestamp();
        const deadline = start_time + @as(i64, @intCast(timeout_ms));

        while (std.time.milliTimestamp() < deadline) {
            // Run event loop for a short period
            self.browser.runEventLoop(10) catch {};

            // Check if test is complete
            const complete_result = ctx.evaluateScript("window.__wpt_complete") catch continue;
            if (complete_result) |val| {
                // Check if it's true
                if (self.isV8True(val)) {
                    // Terminate all workers immediately to avoid lingering threads
                    // This is critical for performance - workers use EventWakeup.wait()
                    // which will block until signaled by terminateAllWorkers()
                    html.workers.ThreadedWorkerRegistry.terminateAllWorkers();

                    // Collect results
                    return try self.collectResults(ctx, start_time, test_path);
                }
            }
        }

        // Timeout - also terminate workers to clean up
        html.workers.ThreadedWorkerRegistry.terminateAllWorkers();

        const duration = @as(u64, @intCast(std.time.milliTimestamp() - start_time));
        var result = try test_harness.TestResult.init(self.allocator, test_path);
        result.status = .timeout;
        result.message = try std.fmt.allocPrint(self.allocator, "Test timed out after {}ms", .{timeout_ms});
        result.duration_ms = duration;
        return result;
    }

    /// Check if a V8 value is true
    fn isV8True(self: *WptBrowser, val: *anyopaque) bool {
        // Use V8 FFI to check if value is truthy
        const v8 = @import("v8");
        const value: *v8.ffi.Value = @ptrCast(val);
        // Check if it's a boolean and get its value
        if (v8.ffi.v8_Value_IsBoolean(value)) {
            const isolate = self.browser.isolate orelse return false;
            return v8.ffi.v8_Value_BooleanValue(value, isolate);
        }
        return false;
    }

    /// Collect test results from window.__wpt_results
    fn collectResults(self: *WptBrowser, ctx: *Context, start_time: i64, test_path: []const u8) !test_harness.TestResult {
        const duration = @as(u64, @intCast(std.time.milliTimestamp() - start_time));

        // Get results JSON
        const json_script =
            \\JSON.stringify(window.__wpt_results)
        ;
        const json_result = ctx.evaluateScript(json_script) catch {
            var result = try test_harness.TestResult.init(self.allocator, test_path);
            result.status = .@"error";
            result.message = try self.allocator.dupe(u8, "Failed to collect test results");
            result.duration_ms = duration;
            return result;
        };

        if (json_result) |val| {
            // Convert V8 string to Zig string
            const json_str = self.v8StringToZig(val) catch {
                var result = try test_harness.TestResult.init(self.allocator, test_path);
                result.status = .@"error";
                result.message = try self.allocator.dupe(u8, "Failed to convert results to string");
                result.duration_ms = duration;
                return result;
            };
            defer if (json_str) |s| self.allocator.free(s);

            if (json_str) |str| {
                return try self.parseTestResults(str, duration, test_path);
            }
        }

        var result = try test_harness.TestResult.init(self.allocator, test_path);
        result.status = .@"error";
        result.message = try self.allocator.dupe(u8, "No test results available");
        result.duration_ms = duration;
        return result;
    }

    /// Convert V8 string value to Zig string
    fn v8StringToZig(self: *WptBrowser, val: *anyopaque) !?[]const u8 {
        const v8 = @import("v8");
        const value: *v8.ffi.Value = @ptrCast(val);

        if (!v8.ffi.v8_Value_IsString(value)) {
            return null;
        }

        const str: *v8.ffi.String = @ptrCast(value);
        const len = v8.ffi.v8_String_Utf8Length(str);
        if (len <= 0) {
            return null;
        }

        const buffer = try self.allocator.alloc(u8, @intCast(len));
        errdefer self.allocator.free(buffer);

        const written = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
        if (written <= 0) {
            self.allocator.free(buffer);
            return null;
        }

        return buffer[0..@intCast(written)];
    }

    /// Parse JSON test results into TestResult struct
    fn parseTestResults(self: *WptBrowser, json_str: []const u8, duration: u64, test_path: []const u8) !test_harness.TestResult {
        // Parse JSON
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, json_str, .{}) catch {
            var result = try test_harness.TestResult.init(self.allocator, test_path);
            result.status = .@"error";
            result.message = try self.allocator.dupe(u8, "Failed to parse test results JSON");
            result.duration_ms = duration;
            return result;
        };
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) {
            var result = try test_harness.TestResult.init(self.allocator, test_path);
            result.status = .@"error";
            result.message = try self.allocator.dupe(u8, "Invalid test results format");
            result.duration_ms = duration;
            return result;
        }

        // Get harness status
        const status_num = if (root.object.get("status")) |s| switch (s) {
            .integer => @as(i64, s.integer),
            .float => @as(i64, @intFromFloat(s.float)),
            else => 2, // Error
        } else 2;

        const harness_status: test_harness.HarnessStatus = switch (status_num) {
            0 => .ok,
            1 => .@"error",
            2 => .timeout,
            else => .@"error",
        };

        // Get message
        const message = if (root.object.get("message")) |m| switch (m) {
            .string => try self.allocator.dupe(u8, m.string),
            else => null,
        } else null;

        // Get subtests (Zig 0.15 ArrayList is unmanaged by default)
        // Note: We don't defer deinit here because ownership transfers to result
        var subtests: std.ArrayList(test_harness.SubtestResult) = .{};
        errdefer subtests.deinit(self.allocator);

        if (root.object.get("tests")) |tests| {
            if (tests == .array) {
                for (tests.array.items) |test_item| {
                    if (test_item == .object) {
                        const name = if (test_item.object.get("name")) |n| switch (n) {
                            .string => try self.allocator.dupe(u8, n.string),
                            else => try self.allocator.dupe(u8, "<unknown>"),
                        } else try self.allocator.dupe(u8, "<unknown>");

                        const test_status_num = if (test_item.object.get("status")) |s| switch (s) {
                            .integer => @as(i64, s.integer),
                            .float => @as(i64, @intFromFloat(s.float)),
                            else => 2,
                        } else 2;

                        const test_status: test_harness.TestStatus = switch (test_status_num) {
                            0 => .pass,
                            1 => .fail,
                            2 => .timeout,
                            3 => .notrun,
                            else => .fail,
                        };

                        const test_message = if (test_item.object.get("message")) |m| switch (m) {
                            .string => try self.allocator.dupe(u8, m.string),
                            else => null,
                        } else null;

                        try subtests.append(self.allocator, .{
                            .name = name,
                            .status = test_status,
                            .message = test_message,
                        });
                    }
                }
            }
        }

        var result = try test_harness.TestResult.init(self.allocator, test_path);
        result.status = harness_status;
        result.message = message;
        result.subtests = subtests;
        result.duration_ms = duration;
        return result;
    }

    /// Build test URL from path
    fn buildTestUrl(self: *WptBrowser, test_path: []const u8) ![]const u8 {
        // Create a file:// URL or http://web-platform.test URL
        return try std.fmt.allocPrint(self.allocator, "http://web-platform.test:8000/{s}", .{test_path});
    }
};
