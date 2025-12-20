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

const test_harness = @import("test_harness.zig");
const test_parser = @import("test_parser.zig");
const config = @import("config.zig");

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
        const browser_instance = try Browser.init(allocator);
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

        const file = try std.fs.openFileAbsolute(full_path, .{});
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
        const ctx = self.browser.context orelse return error.NoContext;

        // Load testharness.js
        try self.loadTestHarness(ctx);

        // Execute the test script
        _ = ctx.evaluateScript(test_content) catch |err| {
            return test_harness.TestResult{
                .status = .error_status,
                .message = try std.fmt.allocPrint(self.allocator, "Script execution error: {}", .{err}),
                .subtests = &[_]test_harness.SubtestResult{},
                .duration_ms = 0,
            };
        };

        // Run event loop until test completes or timeout
        const timeout_ms = timeout.toMilliseconds();
        const result = try self.waitForCompletion(ctx, timeout_ms);

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
        timeout: config.Timeout,
    ) !test_harness.TestResult {
        // Build test URL
        const test_url = try self.buildTestUrl(test_path);
        defer self.allocator.free(test_url);

        // Navigate to create fresh context
        try self.browser.navigate(test_url, .window);

        // Get the context
        const ctx = self.browser.context orelse return error.NoContext;

        // Load testharness.js BEFORE parsing HTML
        // This ensures testharness globals are available when scripts in HTML execute
        try self.loadTestHarness(ctx);

        // Create script loader that loads from WPT root
        const loader_ctx = ScriptLoaderContext{
            .wpt_browser = self,
            .test_path = test_path,
        };

        // Load HTML with script execution
        ctx.loadHTML(html_content, .{
            .base_url = test_url,
            .scripting_enabled = true,
            .script_loader = .{
                .context = @ptrCast(@constCast(&loader_ctx)),
                .loadScript = scriptLoaderCallback,
            },
        }) catch |err| {
            return test_harness.TestResult{
                .status = .error_status,
                .message = try std.fmt.allocPrint(self.allocator, "HTML parse error: {}", .{err}),
                .subtests = &[_]test_harness.SubtestResult{},
                .duration_ms = 0,
            };
        };

        // Run event loop until test completes or timeout
        const timeout_ms = timeout.toMilliseconds();
        const result = try self.waitForCompletion(ctx, timeout_ms);

        self.tests_run += 1;
        return result;
    }

    /// Script loader context for HTML parsing
    const ScriptLoaderContext = struct {
        wpt_browser: *WptBrowser,
        test_path: []const u8,
    };

    /// Callback for loading external scripts during HTML parsing
    fn scriptLoaderCallback(ctx_ptr: *anyopaque, url: []const u8) ?[]const u8 {
        const loader_ctx: *const ScriptLoaderContext = @ptrCast(@alignCast(ctx_ptr));
        const self = loader_ctx.wpt_browser;

        // Resolve URL relative to test path or WPT root
        if (std.mem.startsWith(u8, url, "/")) {
            // Absolute path from WPT root
            const relative = url[1..]; // Remove leading /
            return self.loadWptScript(relative) catch null;
        } else if (std.mem.startsWith(u8, url, "http://") or std.mem.startsWith(u8, url, "https://")) {
            // External URL - not supported in WPT runner
            return null;
        } else {
            // Relative to test file
            const test_dir = std.fs.path.dirname(loader_ctx.test_path) orelse "";
            const full_path = std.fs.path.join(self.allocator, &.{ self.wpt_root, test_dir, url }) catch return null;
            defer self.allocator.free(full_path);

            const file = std.fs.openFileAbsolute(full_path, .{}) catch return null;
            defer file.close();

            const stat = file.stat() catch return null;
            const content = self.allocator.alloc(u8, stat.size) catch return null;

            const bytes_read = file.readAll(content) catch {
                self.allocator.free(content);
                return null;
            };

            if (bytes_read != stat.size) {
                self.allocator.free(content);
                return null;
            }

            return content;
        }
    }

    /// Load testharness.js and testharnessreport.js into the context
    fn loadTestHarness(self: *WptBrowser, ctx: *Context) !void {
        // Load testharness.js
        if (self.testharness_js) |js| {
            _ = try ctx.evaluateScript(js);
        } else {
            return error.TestHarnessNotFound;
        }

        // Load testharnessreport.js
        if (self.testharnessreport_js) |js| {
            _ = try ctx.evaluateScript(js);
        }

        // Set up completion callback to capture results
        const setup_script =
            \\(function() {
            \\  // Store test results for collection
            \\  window.__wpt_results = null;
            \\  window.__wpt_complete = false;
            \\  
            \\  // Register completion callback
            \\  add_completion_callback(function(tests, harness_status) {
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
            \\  });
            \\})();
        ;
        _ = try ctx.evaluateScript(setup_script);
    }

    /// Wait for test completion by polling __wpt_complete
    fn waitForCompletion(self: *WptBrowser, ctx: *Context, timeout_ms: u64) !test_harness.TestResult {
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
                    // Collect results
                    return try self.collectResults(ctx, start_time);
                }
            }
        }

        // Timeout
        const duration = @as(u64, @intCast(std.time.milliTimestamp() - start_time));
        return test_harness.TestResult{
            .status = .timeout,
            .message = try std.fmt.allocPrint(self.allocator, "Test timed out after {}ms", .{timeout_ms}),
            .subtests = &[_]test_harness.SubtestResult{},
            .duration_ms = duration,
        };
    }

    /// Check if a V8 value is true
    fn isV8True(self: *WptBrowser, val: *anyopaque) bool {
        _ = self;
        // Use V8 FFI to check if value is true
        const v8 = @import("v8");
        const value: *v8.ffi.Value = @ptrCast(val);
        return v8.ffi.v8_Value_IsTrue(value);
    }

    /// Collect test results from window.__wpt_results
    fn collectResults(self: *WptBrowser, ctx: *Context, start_time: i64) !test_harness.TestResult {
        const duration = @as(u64, @intCast(std.time.milliTimestamp() - start_time));

        // Get results JSON
        const json_script =
            \\JSON.stringify(window.__wpt_results)
        ;
        const json_result = ctx.evaluateScript(json_script) catch {
            return test_harness.TestResult{
                .status = .error_status,
                .message = try self.allocator.dupe(u8, "Failed to collect test results"),
                .subtests = &[_]test_harness.SubtestResult{},
                .duration_ms = duration,
            };
        };

        if (json_result) |val| {
            // Convert V8 string to Zig string
            const json_str = self.v8StringToZig(val) catch {
                return test_harness.TestResult{
                    .status = .error_status,
                    .message = try self.allocator.dupe(u8, "Failed to convert results to string"),
                    .subtests = &[_]test_harness.SubtestResult{},
                    .duration_ms = duration,
                };
            };
            defer if (json_str) |s| self.allocator.free(s);

            if (json_str) |str| {
                return try self.parseTestResults(str, duration);
            }
        }

        return test_harness.TestResult{
            .status = .error_status,
            .message = try self.allocator.dupe(u8, "No test results available"),
            .subtests = &[_]test_harness.SubtestResult{},
            .duration_ms = duration,
        };
    }

    /// Convert V8 string value to Zig string
    fn v8StringToZig(self: *WptBrowser, val: *anyopaque) !?[]const u8 {
        const v8 = @import("v8");
        const value: *v8.ffi.Value = @ptrCast(val);

        if (!v8.ffi.v8_Value_IsString(value)) {
            return null;
        }

        const str: *v8.ffi.String = @ptrCast(value);
        const len = v8.ffi.v8_String_Utf8Length(str, null);
        if (len <= 0) {
            return null;
        }

        const buffer = try self.allocator.alloc(u8, @intCast(len));
        errdefer self.allocator.free(buffer);

        const written = v8.ffi.v8_String_WriteUtf8(str, null, buffer.ptr, @intCast(len), null);
        if (written <= 0) {
            self.allocator.free(buffer);
            return null;
        }

        return buffer[0..@intCast(written)];
    }

    /// Parse JSON test results into TestResult struct
    fn parseTestResults(self: *WptBrowser, json_str: []const u8, duration: u64) !test_harness.TestResult {
        // Parse JSON
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, json_str, .{}) catch {
            return test_harness.TestResult{
                .status = .error_status,
                .message = try self.allocator.dupe(u8, "Failed to parse test results JSON"),
                .subtests = &[_]test_harness.SubtestResult{},
                .duration_ms = duration,
            };
        };
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) {
            return test_harness.TestResult{
                .status = .error_status,
                .message = try self.allocator.dupe(u8, "Invalid test results format"),
                .subtests = &[_]test_harness.SubtestResult{},
                .duration_ms = duration,
            };
        }

        // Get harness status
        const status_num = if (root.object.get("status")) |s| switch (s) {
            .integer => @as(i64, s.integer),
            .float => @as(i64, @intFromFloat(s.float)),
            else => 2, // Error
        } else 2;

        const harness_status: test_harness.TestStatus = switch (status_num) {
            0 => .ok,
            1 => .error_status,
            2 => .timeout,
            else => .error_status,
        };

        // Get message
        const message = if (root.object.get("message")) |m| switch (m) {
            .string => try self.allocator.dupe(u8, m.string),
            else => null,
        } else null;

        // Get subtests
        var subtests = std.ArrayList(test_harness.SubtestResult).init(self.allocator);
        defer subtests.deinit();

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

                        const test_status: test_harness.SubtestStatus = switch (test_status_num) {
                            0 => .pass,
                            1 => .fail,
                            2 => .timeout,
                            3 => .not_run,
                            else => .fail,
                        };

                        const test_message = if (test_item.object.get("message")) |m| switch (m) {
                            .string => try self.allocator.dupe(u8, m.string),
                            else => null,
                        } else null;

                        try subtests.append(.{
                            .name = name,
                            .status = test_status,
                            .message = test_message,
                        });
                    }
                }
            }
        }

        return test_harness.TestResult{
            .status = harness_status,
            .message = message,
            .subtests = try subtests.toOwnedSlice(),
            .duration_ms = duration,
        };
    }

    /// Build test URL from path
    fn buildTestUrl(self: *WptBrowser, test_path: []const u8) ![]const u8 {
        // Create a file:// URL or http://web-platform.test URL
        return try std.fmt.allocPrint(self.allocator, "http://web-platform.test:8000/{s}", .{test_path});
    }
};
