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
const navigation = browser_mod.navigation;

// File module for blob URL store access
const file = @import("file");

// HTML workers module for blob resolver registration
const html = @import("html");
const workers = html.workers;

const test_harness = @import("test_harness.zig");
const test_parser = @import("test_parser.zig");
const config = @import("config.zig");

/// WPT test origin - all tests run on this origin
const WPT_ORIGIN = "http://web-platform.test:8000";

/// Blob URL resolver callback for Web Workers.
/// This function is registered with the workers module to resolve blob: URLs
/// when Workers are created with blob URLs (e.g., new Worker(URL.createObjectURL(blob))).
///
/// Per HTML spec, blob URLs are same-origin with their creating context.
/// This resolver accesses the global BlobURLStore to look up blobs.
fn resolveBlobUrl(_: std.mem.Allocator, url: []const u8, origin: []const u8) ?workers.BlobResolveResult {
    // Get the global blob URL store
    const store = file.getGlobalBlobURLStore() orelse {
        std.debug.print("resolveBlobUrl: No global blob URL store available\n", .{});
        return null;
    };

    // Resolve the blob URL (handles same-origin validation)
    const blob_data = store.resolve(url, origin) orelse {
        std.debug.print("resolveBlobUrl: Blob not found for URL: {s} (origin: {s})\n", .{ url, origin });
        return null;
    };

    // Return the blob data without copying (BlobData is persistent)
    // Note: BlobData uses mime_type field (not content_type)
    return .{
        .bytes = blob_data.bytes,
        .content_type = blob_data.mime_type,
        .owns_bytes = false, // BlobURLStore owns the data
    };
}

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

        // Register the blob URL resolver for Web Workers.
        // This allows Workers created with blob URLs (new Worker(URL.createObjectURL(blob)))
        // to resolve their script content from the BlobURLStore.
        workers.setBlobResolver(resolveBlobUrl);

        // Pre-load testharness.js for efficiency
        self.testharness_js = self.loadWptScript("resources/testharness.js") catch null;
        self.testharnessreport_js = self.loadWptScript("resources/testharnessreport.js") catch null;

        return self;
    }

    /// Cleanup
    pub fn deinit(self: *WptBrowser) void {
        // Clear the blob resolver and document origin registrations
        workers.clearBlobResolver();
        workers.clearDocumentOrigin();
        file.clearDocumentOrigin();

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
        const script_file = std.fs.cwd().openFile(full_path, .{}) catch |err| {
            std.debug.print("Failed to open WPT script: {s} - {}\n", .{ full_path, err });
            return err;
        };
        defer script_file.close();

        const stat = try script_file.stat();
        const content = try self.allocator.alloc(u8, stat.size);
        errdefer self.allocator.free(content);

        const bytes_read = try script_file.readAll(content);
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

        // Set the document origin for blob URL operations.
        // Both URL.createObjectURL (to store blobs with the correct origin)
        // and Workers (to resolve blob URLs with same-origin validation)
        // need to know the current document origin.
        file.setDocumentOrigin(WPT_ORIGIN);
        workers.setDocumentOrigin(WPT_ORIGIN);

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

    /// Run an HTML test via HTTP navigation
    ///
    /// Navigates to the test URL, fetches via HTTP, parses HTML, and executes scripts.
    /// This mimics real browser behavior where all content is fetched over the network.
    pub fn runHTMLTest(
        self: *WptBrowser,
        test_path: []const u8,
        test_url: []const u8,
        timeout_ms: u64,
        context_type: browser_mod.ContextType,
    ) !test_harness.TestResult {
        // Create script loader context for external script loading
        const loader_ctx = ScriptLoaderContext{
            .wpt_browser = self,
            .test_path = test_path,
        };

        // Navigate to test URL with skip_load so we can inject testharness first
        try self.browser.navigateWithOptions(test_url, context_type, .{
            .skip_load = true,
        });

        // Get the context
        const ctx = self.browser.current_context orelse return error.NoContext;

        // Set the document origin for blob URL operations.
        // Both URL.createObjectURL (to store blobs with the correct origin)
        // and Workers (to resolve blob URLs with same-origin validation)
        // need to know the current document origin.
        file.setDocumentOrigin(WPT_ORIGIN);
        workers.setDocumentOrigin(WPT_ORIGIN);

        // Load testharness.js BEFORE loading the page
        // This ensures testharness globals are available when scripts in HTML execute
        try self.loadTestHarness(ctx);

        // Now load the page via HTTP - this will fetch, parse HTML, and execute scripts
        // The script loader handles external script loading (also via HTTP for absolute URLs)
        ctx.loadPageWithOptions(.{
            .script_loader = .{
                .context = @ptrCast(@constCast(&loader_ctx)),
                .loadScript = scriptLoaderCallback,
            },
        }) catch |err| {
            var result = try test_harness.TestResult.init(self.allocator, test_path);
            result.status = .@"error";
            result.message = try std.fmt.allocPrint(self.allocator, "Page load error: {}", .{err});
            return result;
        };

        // Run event loop until test completes or timeout
        const result = try self.waitForCompletion(ctx, timeout_ms, test_path);

        self.tests_run += 1;
        return result;
    }

    /// Script loader context for HTML parsing
    const ScriptLoaderContext = struct {
        wpt_browser: *WptBrowser,
        test_path: []const u8,
    };

    /// Callback for loading external scripts during HTML parsing
    ///
    /// Fetches scripts via HTTP, mimicking real browser behavior.
    fn scriptLoaderCallback(ctx_ptr: *anyopaque, url: []const u8) ?[]const u8 {
        const loader_ctx: *const ScriptLoaderContext = @ptrCast(@alignCast(ctx_ptr));
        const self = loader_ctx.wpt_browser;

        std.debug.print("scriptLoaderCallback: url='{s}'\n", .{url});

        // Skip testharness.js and testharnessreport.js - they're already loaded
        // via loadTestHarness() before HTML parsing starts. Loading them again
        // would reinitialize the Tests object and lose our completion callback.
        if (std.mem.eql(u8, url, "/resources/testharness.js") or
            std.mem.eql(u8, url, "/resources/testharnessreport.js"))
        {
            std.debug.print("scriptLoaderCallback: SKIPPING {s} (already loaded)\n", .{url});
            // Return empty script to prevent double-loading
            return self.allocator.dupe(u8, "// Already loaded by WPT runner") catch null;
        }

        // Apply WPT URL rewrites (matching wpt serve behavior)
        const rewritten_url = applyWptRewrites(url);

        // Build full HTTP URL and fetch via HTTP
        const http_url = blk: {
            if (std.mem.startsWith(u8, url, "http://") or std.mem.startsWith(u8, url, "https://")) {
                // Already a full URL
                break :blk self.allocator.dupe(u8, url) catch return null;
            } else if (std.mem.startsWith(u8, rewritten_url, "/")) {
                // Absolute path from WPT root - build full URL
                break :blk std.fmt.allocPrint(
                    self.allocator,
                    "http://web-platform.test:8000{s}",
                    .{rewritten_url},
                ) catch return null;
            } else {
                // Relative path - resolve relative to test path
                const test_dir = std.fs.path.dirname(loader_ctx.test_path) orelse "";
                if (test_dir.len > 0) {
                    break :blk std.fmt.allocPrint(
                        self.allocator,
                        "http://web-platform.test:8000/{s}/{s}",
                        .{ test_dir, url },
                    ) catch return null;
                } else {
                    break :blk std.fmt.allocPrint(
                        self.allocator,
                        "http://web-platform.test:8000/{s}",
                        .{url},
                    ) catch return null;
                }
            }
        };
        defer self.allocator.free(http_url);

        std.debug.print("scriptLoaderCallback: fetching HTTP URL '{s}'\n", .{http_url});

        // Fetch the script via HTTP
        const result = navigation.fetchUrl(self.allocator, http_url, .{}) catch |err| {
            std.debug.print("scriptLoaderCallback: HTTP fetch failed: {}\n", .{err});
            return null;
        };
        defer {
            self.allocator.free(result.content_type);
            self.allocator.free(result.final_url);
        }

        // Check for success
        if (result.status_code >= 400) {
            std.debug.print("scriptLoaderCallback: HTTP {d} for {s}\n", .{ result.status_code, http_url });
            self.allocator.free(result.body);
            return null;
        }

        std.debug.print("scriptLoaderCallback: loaded {d} bytes from {s}\n", .{ result.body.len, http_url });

        // Return the body - caller owns this memory
        return result.body;
    }

    /// Load testharness.js and testharnessreport.js into the context
    fn loadTestHarness(self: *WptBrowser, ctx: *Context) !void {
        _ = ctx.v8_context; // Suppress unused warning

        // CRITICAL CHECK: Verify no state leaked from previous context
        // If any of these exist, we have a state leak!
        const leak_check =
            \\(function() {
            \\  var leaks = [];
            \\  if (typeof window.__wpt_complete !== 'undefined') leaks.push('__wpt_complete=' + window.__wpt_complete);
            \\  if (typeof window.__wpt_results !== 'undefined') leaks.push('__wpt_results exists');
            \\  if (typeof test === 'function') leaks.push('test() already defined');
            \\  if (typeof Tests !== 'undefined') leaks.push('Tests object exists');
            \\  if (leaks.length > 0) {
            \\    console.log('[LEAK DETECTED] Previous test state found: ' + leaks.join(', '));
            \\    return 'LEAKED: ' + leaks.join(', ');
            \\  }
            \\  return 'CLEAN';
            \\})();
        ;
        const leak_result = ctx.evaluateScript(leak_check) catch |err| {
            std.debug.print("[loadTestHarness] Leak check error: {}\n", .{err});
            return err;
        };
        if (leak_result) |val| {
            const leak_str = self.v8StringToZig(val) catch null;
            if (leak_str) |s| {
                defer self.allocator.free(s);
                // Only print if there's a leak
                if (!std.mem.eql(u8, s, "CLEAN")) {
                    std.debug.print("[loadTestHarness] !!! STATE LEAK DETECTED: {s} !!!\n", .{s});
                }
            }
        }

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

        // Verify testharness.js loaded correctly by checking for globals
        // This catches cases where testharness.js execution fails silently
        const verify_script =
            \\if (typeof test !== 'function' || typeof async_test !== 'function' ||
            \\    typeof promise_test !== 'function' || typeof setup !== 'function') {
            \\  throw new Error('testharness.js failed to load: globals not defined. ' +
            \\    'test=' + typeof test + ', async_test=' + typeof async_test +
            \\    ', promise_test=' + typeof promise_test + ', setup=' + typeof setup);
            \\}
            \\'GLOBALS_VERIFIED';
        ;
        _ = ctx.evaluateScript(verify_script) catch |err| {
            std.debug.print("ERROR: testharness.js verification failed: {}\n", .{err});
            return error.TestHarnessLoadFailed;
        };

        // Set up completion callback to capture results
        const setup_script =
            \\(function() {
            \\  // Store test results for collection
            \\  window.__wpt_results = null;
            \\  window.__wpt_complete = false;
            \\
            \\  // Register completion callback
            \\  add_completion_callback(function(tests, harness_status) {
            \\    try {
            \\      window.__wpt_results = {
            \\        status: harness_status ? harness_status.status : 0,
            \\        message: harness_status ? (harness_status.message || null) : null,
            \\        tests: (tests || []).map(function(t) {
            \\          return {
            \\            name: t.name,
            \\            status: t.status,
            \\            message: t.message || null
            \\          };
            \\        })
            \\      };
            \\    } catch (e) {
            \\      window.__wpt_results = { status: 1, message: e.toString(), tests: [] };
            \\    }
            \\    window.__wpt_complete = true;
            \\  });
            \\})();
        ;
        _ = try ctx.evaluateScript(setup_script);
    }

    /// Wait for test completion with proper blocking.
    ///
    /// This uses the new blocking event loop to efficiently wait for test completion.
    /// The test signals completion by setting `window.__wpt_complete = true`.
    ///
    /// @param ctx The browser context
    /// @param timeout_ms Maximum time to wait for completion
    /// @param test_path Test path for error reporting
    /// @return TestResult with test results or timeout status
    fn waitForCompletion(self: *WptBrowser, ctx: *Context, timeout_ms: u64, test_path: []const u8) !test_harness.TestResult {
        const start_time = std.time.milliTimestamp();
        const deadline = start_time + @as(i64, @intCast(timeout_ms));

        // Polling interval for completion check
        // With proper blocking, we can use a longer interval while still being responsive
        // to timer events (blocking wakes on timer fire)
        const check_interval_ms: u64 = 50;

        while (true) {
            const now = std.time.milliTimestamp();
            if (now >= deadline) {
                break;
            }

            // Calculate how long to block
            const remaining: u64 = @intCast(deadline - now);
            const wait_time = @min(remaining, check_interval_ms);

            // Block on event loop - this runs timer callbacks, I/O, etc.
            // Uses efficient libuv blocking, waking when timers fire
            _ = self.browser.runEventLoopBlocking(wait_time) catch {};

            // Check if test is complete
            const complete_result = ctx.evaluateScript("window.__wpt_complete") catch continue;
            if (complete_result) |val| {
                // Check if it's true
                if (self.isV8True(val)) {
                    // Collect results
                    return try self.collectResults(ctx, start_time, test_path);
                }
            }
        }

        // Timeout
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
