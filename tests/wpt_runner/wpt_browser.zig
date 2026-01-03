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

// ============================================================================
// Thread-local storage for WPT browser instance (for native callbacks)
// ============================================================================

threadlocal var current_wpt_browser: ?*WptBrowser = null;

/// Set the current WPT browser instance for native callbacks
pub fn setCurrentWptBrowser(wpt_browser: *WptBrowser) void {
    current_wpt_browser = wpt_browser;
}

/// Get the current WPT browser instance (for native callbacks)
pub fn getCurrentWptBrowser() ?*WptBrowser {
    return current_wpt_browser;
}

/// Clear the WPT browser instance reference
pub fn clearCurrentWptBrowser() void {
    current_wpt_browser = null;
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
    /// CA bundle path for HTTPS cert validation (freed in deinit)
    ca_bundle_path: ?[]const u8,
    /// Number of tests run
    tests_run: usize,
    /// Test completion state - set by native __wpt_report_completion()
    test_complete: bool,
    /// Test status - set by native __wpt_report_result()
    test_status: ?test_harness.HarnessStatus,
    /// Test message - set by native __wpt_report_result()
    test_message: ?[]const u8,
    /// Whether test_message was allocated (vs string literal)
    test_message_owned: bool,
    /// Stored subtests - parsed from __wpt_report_result() callback
    stored_subtests: std.ArrayList(test_harness.SubtestResult),

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
            .test_complete = false,
            .test_status = null,
            .test_message = null,
            .test_message_owned = false,
            .stored_subtests = .{},
            .ca_bundle_path = null,
        };

        // Load WPT self-signed certificates for HTTPS tests
        WptBrowser.loadWptCertificates(browser_instance, wpt_root, allocator) catch |err| {
            std.debug.print("[WPT] Warning: Failed to load WPT certificates: {}\n", .{err});
            // Continue without certs - HTTPS tests may fail but HTTP tests will work
        };

        // Pre-load testharness.js for efficiency
        self.testharness_js = self.loadWptScript("resources/testharness.js") catch null;
        self.testharnessreport_js = self.loadWptScript("resources/testharnessreport.js") catch null;

        return self;
    }

    /// Load WPT self-signed certificates for HTTPS testing.
    ///
    /// WPT tests use self-signed certificates on HTTPS ports 8443, 8445, 8446.
    /// This function loads the WPT CA certificate and registers it for all
    /// relevant hosts so that HTTPS tests can run without certificate errors.
    ///
    /// The CA certificate is located at: wpt/tools/certs/cacert.pem
    fn loadWptCertificates(browser_instance: *Browser, wpt_root: []const u8, allocator: std.mem.Allocator) !void {
        // Build path to WPT CA certificate
        const ca_cert_path = try std.fs.path.join(allocator, &.{ wpt_root, "tools", "certs", "cacert.pem" });
        defer allocator.free(ca_cert_path);

        // Check if the certificate file exists
        std.fs.cwd().access(ca_cert_path, .{}) catch |err| {
            std.debug.print("[WPT] CA certificate not found at {s}: {}\n", .{ ca_cert_path, err });
            return err;
        };

        // WPT HTTPS ports: 8443 (main), 8445 (alternate), 8446 (alternate)
        // Host patterns to trust for these ports
        const wpt_https_hosts = [_][]const u8{
            // localhost variants
            "localhost:8443",
            "localhost:8445",
            "localhost:8446",
            // 127.0.0.1 variants
            "127.0.0.1:8443",
            "127.0.0.1:8445",
            "127.0.0.1:8446",
            // web-platform.test domain (WPT's default test domain)
            "web-platform.test:8443",
            "web-platform.test:8445",
            "web-platform.test:8446",
            // Subdomains of web-platform.test
            "www.web-platform.test:8443",
            "www1.web-platform.test:8443",
            "www2.web-platform.test:8443",
            "xn--n3h.web-platform.test:8443",
            "xn--lve-6lad.web-platform.test:8443",
        };

        var loaded_count: usize = 0;
        for (wpt_https_hosts) |host| {
            browser_instance.addTrustedCertificateFromFile(host, ca_cert_path) catch |err| {
                std.debug.print("[WPT] Warning: Failed to add WPT cert for {s}: {}\n", .{ host, err });
                continue;
            };
            loaded_count += 1;
        }

        if (loaded_count > 0) {
            std.debug.print("[WPT] Loaded CA certificate for {d} hosts from {s}\n", .{ loaded_count, ca_cert_path });

            // Generate CA bundle file for curl to use
            // This sets up the trust store so fetch requests can validate the certs
            const trust_store = browser_instance.getCertificateTrustStore();

            // Generate CA bundle in a temporary location
            const bundle_path = trust_store.generateCaBundleFile("/tmp") catch |err| {
                std.debug.print("[WPT] Warning: Failed to generate CA bundle: {}\n", .{err});
                return;
            };
            // Don't free bundle_path here - it's needed for the lifetime of the WptBrowser
            // Store it via the trust_store for later cleanup

            // Set the CA bundle path so curl uses it
            trust_store.setCaBundlePath(bundle_path) catch |err| {
                std.debug.print("[WPT] Warning: Failed to set CA bundle path: {}\n", .{err});
                allocator.free(bundle_path);
                return;
            };

            // setCaBundlePath duplicates the path internally, so we free the original
            allocator.free(bundle_path);
        }
    }

    /// Cleanup
    pub fn deinit(self: *WptBrowser) void {
        clearCurrentWptBrowser();
        if (self.testharness_js) |js| {
            self.allocator.free(js);
        }
        if (self.testharnessreport_js) |js| {
            self.allocator.free(js);
        }
        // Clean up stored subtests
        for (self.stored_subtests.items) |subtest| {
            self.allocator.free(subtest.name);
            if (subtest.message) |msg| self.allocator.free(msg);
        }
        self.stored_subtests.deinit(self.allocator);
        // Clean up test_message only if we allocated it
        if (self.test_message_owned) {
            if (self.test_message) |msg| {
                self.allocator.free(msg);
            }
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
            // Worklet variants
            .audio_worklet => .audio_worklet,
            .paint_worklet => .paint_worklet,
            .animation_worklet => .animation_worklet,
            .layout_worklet => .layout_worklet,
            // ShadowRealm variants all map to shadow_realm context
            .shadowrealm,
            .shadowrealm_in_window,
            .shadowrealm_in_dedicatedworker,
            .shadowrealm_in_sharedworker,
            .shadowrealm_in_shadowrealm,
            .shadowrealm_in_audioworklet,
            .shadowrealm_in_serviceworker,
            => .shadow_realm,
        };

        // Build test URL
        const test_url = try self.buildTestUrl(test_path);
        defer self.allocator.free(test_url);

        // Navigate to create fresh context
        try self.browser.navigate(test_url, ctx_type);

        // Get the context
        const ctx = self.browser.current_context orelse return error.NoContext;

        // Register native functions BEFORE loading testharness/scripts
        setCurrentWptBrowser(self);
        try self.registerWptNativeFunctions(ctx);

        // For serviceworker context, inject mock navigator.serviceWorker
        // testharness.js uses this as messagePort for result communication
        std.debug.print("[WPT] Context type: {s}\n", .{@tagName(ctx_type)});
        if (ctx_type == .service_worker) {
            std.debug.print("[WPT] Injecting ServiceWorker mock...\n", .{});
            try self.injectServiceWorkerMock(ctx);
        }

        // Load testharness.js
        try self.loadTestHarness(ctx);

        // For serviceworker context, dispatch synthetic install event
        // to trigger ServiceWorkerTestEnvironment.on_all_loaded()
        if (ctx_type == .service_worker) {
            _ = ctx.evaluateScript(
                \\// Dispatch install event to trigger testharness SW environment
                \\self.dispatchEvent(new ExtendableEvent('install'));
            ) catch {};
        }

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
        // Use skip_load: true since we already have html_content - don't fetch it again
        try self.browser.navigateWithOptions(base_url, context_type, .{ .skip_load = true });

        // Get the context
        const ctx = self.browser.current_context orelse return error.NoContext;

        // Register native functions BEFORE loading HTML/scripts
        // This ensures __wpt_report_completion exists when scripts run
        setCurrentWptBrowser(self);
        try self.registerWptNativeFunctions(ctx);

        // Let the browser handle ALL script loading naturally via HTTP
        // No pre-loading, no script interception - this is how a real browser works
        ctx.loadHTML(html_content, .{
            .base_url = base_url,
            .scripting_enabled = true,
            .trust_store = self.browser.getCertificateTrustStore(),
            // No script_loader - browser fetches scripts via HTTP
        }) catch |err| {
            var result = try test_harness.TestResult.init(self.allocator, test_path);
            result.status = .@"error";
            result.message = try std.fmt.allocPrint(self.allocator, "HTML parse error: {}", .{err});
            return result;
        };

        // Inject completion hook JS to capture results
        // testharness.js should now be loaded and its globals available
        try self.injectCompletionHook(ctx);

        // Run event loop until test completes or timeout
        const result = try self.waitForCompletion(ctx, timeout_ms, test_path);

        self.tests_run += 1;
        return result;
    }

    /// Native callback for __wpt_report_completion()
    fn wptReportCompletionCallback(info: *const @import("v8").ffi.FunctionCallbackInfo) callconv(.c) void {
        _ = info; // Parameter not used in this simple callback

        if (getCurrentWptBrowser()) |wpt_browser| {
            wpt_browser.test_complete = true;
            std.debug.print("[WPT] Test completion reported via native function\n", .{});
        }
    }

    /// Native callback for __wpt_report_result()
    /// Called from JavaScript with: __wpt_report_result({tests: [...], status: {status: number, message: string}})
    fn wptReportResultCallback(info: *const @import("v8").ffi.FunctionCallbackInfo) callconv(.c) void {
        const v8 = @import("v8");

        const wpt_browser = getCurrentWptBrowser() orelse {
            std.debug.print("[WPT] Error: No WPT browser instance available\n", .{});
            return;
        };

        // Get the first argument (the results object) using inline methods
        const arg_count = info.length();
        if (arg_count < 1) {
            std.debug.print("[WPT] Error: __wpt_report_result called with no arguments\n", .{});
            wpt_browser.test_status = .@"error";
            wpt_browser.test_message = "No arguments provided to __wpt_report_result";
            return;
        }

        const results_value: *v8.ffi.Value = info.get(0);

        // Get the V8 context using inline methods
        const isolate = info.getIsolate();
        const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
            std.debug.print("[WPT] Error: Could not get V8 context\n", .{});
            wpt_browser.test_status = .@"error";
            wpt_browser.test_message = "Could not get V8 context";
            return;
        };

        // Convert the results object to JSON string using V8's JSON.stringify
        // Use a stack buffer for small results, dynamically allocate for large ones
        var stack_buffer: [256 * 1024]u8 = undefined; // 256KB stack buffer
        const json_len = v8.ffi.v8_JSON_Stringify_ToBuffer(context, results_value, &stack_buffer, stack_buffer.len);

        if (json_len < 0) {
            std.debug.print("[WPT] Error: Failed to stringify results to JSON\n", .{});
            wpt_browser.test_status = .@"error";
            wpt_browser.test_message = "Failed to stringify results to JSON";
            return;
        }

        const json_len_usize: usize = @intCast(json_len);
        var heap_buffer: ?[]u8 = null;
        defer if (heap_buffer) |buf| wpt_browser.allocator.free(buf);

        const json_str = if (json_len_usize <= stack_buffer.len)
            stack_buffer[0..json_len_usize]
        else blk: {
            // Result is larger than stack buffer - allocate on heap and retry
            std.debug.print("[WPT] Large result ({d} bytes), using heap allocation\n", .{json_len});
            heap_buffer = wpt_browser.allocator.alloc(u8, json_len_usize) catch {
                std.debug.print("[WPT] Error: Failed to allocate {d} bytes for JSON\n", .{json_len});
                wpt_browser.test_status = .@"error";
                wpt_browser.test_message = "Out of memory for large test results";
                return;
            };
            const retry_len = v8.ffi.v8_JSON_Stringify_ToBuffer(context, results_value, heap_buffer.?.ptr, @intCast(heap_buffer.?.len));
            if (retry_len < 0 or @as(usize, @intCast(retry_len)) != json_len_usize) {
                std.debug.print("[WPT] Error: JSON stringify retry failed\n", .{});
                wpt_browser.test_status = .@"error";
                wpt_browser.test_message = "Failed to stringify large results";
                return;
            }
            break :blk heap_buffer.?;
        };
        // Parse the JSON to extract test results
        wpt_browser.parseAndStoreResults(json_str) catch |err| {
            std.debug.print("[WPT] Error parsing results: {}\n", .{err});
            wpt_browser.test_status = .@"error";
            wpt_browser.test_message = "Failed to parse test results";
            return;
        };

        std.debug.print("[WPT] Test results reported via native function\n", .{});
    }

    /// Parse JSON results and store in WptBrowser
    fn parseAndStoreResults(self: *WptBrowser, json_str: []const u8) !void {
        // Parse JSON
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, json_str, .{}) catch {
            self.test_status = .@"error";
            self.test_message = "Failed to parse JSON";
            return error.JsonParseError;
        };
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) {
            // Skip non-object values (e.g., test name announcements as strings)
            // These are intermediate callbacks, not final results
            return;
        }

        // Get harness status from status.status (nested object)
        var harness_status: test_harness.HarnessStatus = .ok;
        var harness_message: ?[]const u8 = null;

        if (root.object.get("status")) |status_obj| {
            if (status_obj == .object) {
                // status is an object with {status: number, message: string}
                if (status_obj.object.get("status")) |s| {
                    const status_num: i64 = switch (s) {
                        .integer => s.integer,
                        .float => @intFromFloat(s.float),
                        else => 1, // Error
                    };
                    harness_status = switch (status_num) {
                        0 => .ok,
                        1 => .@"error",
                        2 => .timeout,
                        else => .@"error",
                    };
                }
                if (status_obj.object.get("message")) |m| {
                    if (m == .string) {
                        harness_message = try self.allocator.dupe(u8, m.string);
                    }
                }
            } else if (status_obj == .integer or status_obj == .float) {
                // status is directly a number (legacy format)
                const status_num: i64 = switch (status_obj) {
                    .integer => status_obj.integer,
                    .float => @intFromFloat(status_obj.float),
                    else => 1,
                };
                harness_status = switch (status_num) {
                    0 => .ok,
                    1 => .@"error",
                    2 => .timeout,
                    else => .@"error",
                };
            }
        }

        self.test_status = harness_status;
        // Free previous test_message if we allocated it
        if (self.test_message_owned) {
            if (self.test_message) |old_msg| {
                self.allocator.free(old_msg);
            }
        }
        self.test_message = harness_message;
        self.test_message_owned = (harness_message != null); // Only owned if we allocated it

        // Clear any existing subtests
        for (self.stored_subtests.items) |subtest| {
            self.allocator.free(subtest.name);
            if (subtest.message) |msg| self.allocator.free(msg);
        }
        self.stored_subtests.clearRetainingCapacity();

        // Parse tests array
        if (root.object.get("tests")) |tests| {
            if (tests == .array) {
                for (tests.array.items) |test_item| {
                    if (test_item == .object) {
                        const name = if (test_item.object.get("name")) |n| switch (n) {
                            .string => try self.allocator.dupe(u8, n.string),
                            else => try self.allocator.dupe(u8, "<unknown>"),
                        } else try self.allocator.dupe(u8, "<unknown>");

                        const test_status_num: i64 = if (test_item.object.get("status")) |s| switch (s) {
                            .integer => s.integer,
                            .float => @intFromFloat(s.float),
                            else => 1,
                        } else 1;

                        const test_status: test_harness.TestStatus = switch (test_status_num) {
                            0 => .pass,
                            1 => .fail,
                            2 => .timeout,
                            3 => .notrun,
                            4 => .precondition_failed,
                            else => .fail,
                        };

                        const test_message = if (test_item.object.get("message")) |m| switch (m) {
                            .string => try self.allocator.dupe(u8, m.string),
                            else => null,
                        } else null;

                        try self.stored_subtests.append(self.allocator, .{
                            .name = name,
                            .status = test_status,
                            .message = test_message,
                        });
                    }
                }
            }
        }

        std.debug.print("[WPT] Parsed {d} subtests, harness status: {s}\n", .{
            self.stored_subtests.items.len,
            harness_status.toString(),
        });
    }

    /// Parse test results from JSON string
    fn parseTestResultsFromJson(self: *WptBrowser, json_str: []const u8, test_path: []const u8) !test_harness.TestResult {
        // Parse JSON
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, json_str, .{}) catch {
            var result = try test_harness.TestResult.init(self.allocator, test_path);
            result.status = .@"error";
            result.message = try self.allocator.dupe(u8, "Failed to parse test results JSON");
            return result;
        };
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) {
            var result = try test_harness.TestResult.init(self.allocator, test_path);
            result.status = .@"error";
            result.message = try self.allocator.dupe(u8, "Invalid test results format");
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

        // Get subtests
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
        return result;
    }

    /// Inject completion hook JS to capture results
    /// testharness.js should have been loaded by the HTML parser via HTTP
    fn injectCompletionHook(self: *WptBrowser, ctx: *Context) !void {
        _ = self; // Not used in this implementation (stored_subtests populated by native callback)

        // Set up completion callback to capture results
        // This runs after testharness.js has been loaded by the HTML parser
        const setup_script =
            \\(function() {
            \\  // Check if testharness.js was loaded
            \\  if (typeof add_completion_callback !== 'function') {
            \\    console.log('[WPT] testharness.js not loaded - skipping completion callback setup');
            \\    __wpt_report_result({ status: 2, message: 'testharness.js not loaded', tests: [] });
            \\    __wpt_report_completion();
            \\    return;
            \\  }
            \\  
            \\  console.log('[WPT] Setting up completion callback...');
            \\  
            \\  // Register completion callback
            \\  add_completion_callback(function(tests, harness_status) {
            \\    console.log('[WPT] Completion callback invoked!');
            \\    console.log('[WPT] tests count: ' + tests.length);
            \\    console.log('[WPT] harness_status.status: ' + harness_status.status);
            \\    var results = {
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
            \\    __wpt_report_result(results);
            \\    __wpt_report_completion();
            \\    console.log('[WPT] Native functions called');
            \\  });
            \\  
            \\  console.log('[WPT] Completion callback registered');
            \\})();
        ;
        _ = try ctx.evaluateScript(setup_script);
    }

    /// Inject mock navigator.serviceWorker for SW context
    /// testharness.js uses navigator.serviceWorker as messagePort for result communication
    fn injectServiceWorkerMock(self: *WptBrowser, ctx: *Context) !void {
        _ = self;
        const mock_script =
            \\(function() {
            \\  // Create mock ServiceWorkerContainer for testharness.js
            \\  // testharness.js uses navigator.serviceWorker as messagePort
            \\  if (typeof navigator === 'undefined') {
            \\    self.navigator = {};
            \\  }
            \\  
            \\  // Message handlers registered by testharness.js
            \\  var messageHandlers = [];
            \\  
            \\  navigator.serviceWorker = {
            \\    // Called by testharness.js to send messages
            \\    postMessage: function(data) {
            \\      console.log('[WPT-SW-Mock] postMessage:', JSON.stringify(data));
            \\      // If this is a result message, report it directly
            \\      if (data && data.type === 'complete') {
            \\        __wpt_report_result(data);
            \\        __wpt_report_completion();
            \\      }
            \\    },
            \\    // Called by testharness.js to listen for messages
            \\    addEventListener: function(type, handler) {
            \\      console.log('[WPT-SW-Mock] addEventListener:', type);
            \\      if (type === 'message') {
            \\        messageHandlers.push(handler);
            \\        // Immediately send a "connect" response to unblock testharness.js
            \\        setTimeout(function() {
            \\          handler({ data: { type: 'connect' } });
            \\        }, 0);
            \\      }
            \\    },
            \\    removeEventListener: function() {},
            \\    controller: null,
            \\    ready: Promise.resolve({
            \\      active: { postMessage: function() {} }
            \\    }),
            \\    // SW registration methods needed by tests
            \\    getRegistration: function(scope) {
            \\      console.log('[WPT-SW-Mock] getRegistration:', scope);
            \\      return Promise.resolve(undefined);
            \\    },
            \\    getRegistrations: function() {
            \\      console.log('[WPT-SW-Mock] getRegistrations');
            \\      return Promise.resolve([]);
            \\    },
            \\    register: function(url, options) {
            \\      console.log('[WPT-SW-Mock] register:', url);
            \\      return Promise.resolve({
            \\        scope: options && options.scope || '/',
            \\        active: { postMessage: function() {} },
            \\        installing: null,
            \\        waiting: null,
            \\        unregister: function() { return Promise.resolve(true); }
            \\      });
            \\    }
            \\  };
            \\  
            \\  console.log('[WPT-SW-Mock] navigator.serviceWorker mock installed');
            \\})();
        ;
        _ = try ctx.evaluateScript(mock_script);
    }

    /// Register native WPT functions on the global object
    fn registerWptNativeFunctions(self: *WptBrowser, ctx: *Context) !void {
        _ = self; // Not used in this simple implementation
        const v8 = @import("v8");
        const isolate = ctx.isolate;
        const v8_ctx = ctx.v8_context orelse return error.NoContext;
        const global = v8.ffi.v8_Context_Global(v8_ctx) orelse return error.NoGlobal;

        // Register __wpt_report_completion
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, wptReportCompletionCallback, null) orelse return error.FunctionTemplateCreateFailed;
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "__wpt_report_completion", 23) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global, v8_ctx, @ptrCast(key), @ptrCast(func));
        }

        // Register __wpt_report_result
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, wptReportResultCallback, null) orelse return error.FunctionTemplateCreateFailed;
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "__wpt_report_result", 19) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global, v8_ctx, @ptrCast(key), @ptrCast(func));
        }
    }

    /// Wait for test completion by checking the native completion flag
    fn waitForCompletion(self: *WptBrowser, ctx: *Context, timeout_ms: u64, test_path: []const u8) !test_harness.TestResult {
        _ = ctx; // Not used since we now use native callbacks
        const start_time = std.time.milliTimestamp();
        const deadline = start_time + @as(i64, @intCast(timeout_ms));

        while (std.time.milliTimestamp() < deadline) {
            // Run event loop for a short period
            self.browser.runEventLoop(10) catch {};

            // Check if test is complete (set by native callback)
            if (self.test_complete) {
                // Terminate all workers immediately to avoid lingering threads
                // This is critical for performance - workers use EventWakeup.wait()
                // which will block until signaled by terminateAllWorkers()
                html.workers.ThreadedWorkerRegistry.terminateAllWorkers();

                // Collect results (now from our stored result)
                return try self.getStoredResults(start_time, test_path);
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

    /// Get stored test results
    fn getStoredResults(self: *WptBrowser, start_time: i64, test_path: []const u8) !test_harness.TestResult {
        const duration = @as(u64, @intCast(std.time.milliTimestamp() - start_time));

        if (self.test_status) |status| {
            // We have test results - construct the TestResult
            var result = try test_harness.TestResult.init(self.allocator, test_path);
            result.status = status;
            if (self.test_message) |msg| {
                result.message = try self.allocator.dupe(u8, msg);
            }
            result.duration_ms = duration;

            // Copy stored subtests to result
            for (self.stored_subtests.items) |subtest| {
                try result.subtests.append(self.allocator, .{
                    .name = try self.allocator.dupe(u8, subtest.name),
                    .status = subtest.status,
                    .message = if (subtest.message) |m| try self.allocator.dupe(u8, m) else null,
                });
            }

            return result;
        } else {
            // No results stored - this shouldn't happen with proper native function calls
            var result = try test_harness.TestResult.init(self.allocator, test_path);
            result.status = .@"error";
            result.message = try self.allocator.dupe(u8, "Test completed but no results were reported");
            result.duration_ms = duration;
            return result;
        }
    }

    /// Run a crashtest
    ///
    /// Crashtests are simple: load the page and see if it crashes.
    /// They pass if:
    /// 1. The page loads successfully (no parse errors)
    /// 2. The page reaches the "painted" state
    /// 3. If test-wait class is on root, wait for it to be removed
    ///
    /// This function does NOT wait for testharness.js callbacks since
    /// crashtests don't use testharness.js.
    pub fn runCrashTest(
        self: *WptBrowser,
        test_path: []const u8,
        html_content: []const u8,
        base_url: []const u8,
        timeout_ms: u64,
    ) !test_harness.TestResult {
        const start_time = std.time.milliTimestamp();

        // Navigate to create fresh context
        self.browser.navigate(base_url, .window) catch |err| {
            const duration = @as(u64, @intCast(std.time.milliTimestamp() - start_time));
            var result = try test_harness.TestResult.createCrashTest(self.allocator, test_path, false, duration);
            if (result.message) |msg| self.allocator.free(msg);
            result.message = try std.fmt.allocPrint(self.allocator, "Failed to navigate: {}", .{err});
            return result;
        };

        // Get the context
        const ctx = self.browser.current_context orelse {
            const duration = @as(u64, @intCast(std.time.milliTimestamp() - start_time));
            return test_harness.TestResult.createCrashTest(self.allocator, test_path, false, duration);
        };

        // Load the HTML - don't inject testharness hooks
        ctx.loadHTML(html_content, .{
            .base_url = base_url,
            .scripting_enabled = true,
        }) catch |err| {
            // Parse/load error counts as a crash failure
            const duration = @as(u64, @intCast(std.time.milliTimestamp() - start_time));
            var result = try test_harness.TestResult.createCrashTest(self.allocator, test_path, false, duration);
            if (result.message) |msg| self.allocator.free(msg);
            result.message = try std.fmt.allocPrint(self.allocator, "Failed to load HTML: {}", .{err});
            return result;
        };

        // Check for test-wait class on root element and wait if needed
        const has_test_wait = self.checkTestWaitClass(ctx) catch false;

        if (has_test_wait) {
            // Wait for test-wait to be removed (up to timeout)
            self.waitForTestWaitRemoval(ctx, timeout_ms, start_time) catch |err| {
                const duration = @as(u64, @intCast(std.time.milliTimestamp() - start_time));
                var result = try test_harness.TestResult.createCrashTest(self.allocator, test_path, false, duration);
                if (result.message) |msg| self.allocator.free(msg);
                result.message = try std.fmt.allocPrint(self.allocator, "test-wait timeout: {}", .{err});
                result.status = .timeout;
                return result;
            };
        } else {
            // Wait briefly for paint (requestAnimationFrame simulation)
            self.waitForPaint(ctx) catch {};
        }

        // Terminate workers to clean up
        html.workers.ThreadedWorkerRegistry.terminateAllWorkers();

        const duration = @as(u64, @intCast(std.time.milliTimestamp() - start_time));

        // If we got here without crashing, the test passed
        return test_harness.TestResult.createCrashTest(self.allocator, test_path, true, duration);
    }

    /// Check if the root element has class="test-wait"
    fn checkTestWaitClass(self: *WptBrowser, ctx: *Context) !bool {
        _ = self;
        const check_script =
            \\(function() {
            \\  return document.documentElement && 
            \\         document.documentElement.classList &&
            \\         document.documentElement.classList.contains('test-wait');
            \\})();
        ;

        const result = ctx.evaluateScript(check_script) catch return false;
        // Check if result is truthy (V8 returns a Value)
        return result != null;
    }

    /// Wait for test-wait class to be removed from root element
    fn waitForTestWaitRemoval(self: *WptBrowser, ctx: *Context, timeout_ms: u64, start_time: i64) !void {
        const deadline = start_time + @as(i64, @intCast(timeout_ms));

        while (std.time.milliTimestamp() < deadline) {
            // Run event loop briefly
            self.browser.runEventLoop(50) catch {};

            // Check if test-wait was removed
            if (!try self.checkTestWaitClass(ctx)) {
                // test-wait removed - now wait for paint
                self.waitForPaint(ctx) catch {};
                return;
            }
        }

        return error.Timeout;
    }

    /// Wait for paint barrier (run event loop briefly to allow rendering)
    fn waitForPaint(self: *WptBrowser, ctx: *Context) !void {
        _ = ctx;
        // Run event loop briefly to allow any pending paint operations
        // In a real browser, we'd wait for requestAnimationFrame callbacks
        // For MVP, just run the event loop for a short time
        self.browser.runEventLoop(50) catch {};
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

    /// Build test URL from path, respecting WPT file name flags
    fn buildTestUrl(self: *WptBrowser, test_path: []const u8) ![]const u8 {
        const file_flags = @import("file_flags.zig");
        const flags = file_flags.FileFlags.parse(test_path);

        // Build URL with correct scheme, host, and port based on file flags
        const url = try std.fmt.allocPrint(
            self.allocator,
            "{s}://{s}:{d}/{s}",
            .{ flags.getScheme(), flags.getHost(), flags.getPort(), test_path },
        );

        // Debug: show URL being used for HTTPS tests
        if (flags.https or flags.h2) {
            std.debug.print("DEBUG: HTTPS test URL = {s}\n", .{url});
        }

        return url;
    }
};
