//! Browser Adapter for WPT Runner
//!
//! This module provides browser-like test execution for WPT tests.
//! Following the official WPT runner behavior, each test runs in a FRESH
//! browsing context (new V8 context) for complete isolation.
//!
//! ## Browser-Aligned Behavior
//!
//! Real browsers and the official wptrunner create a new window/tab for each test:
//! - Complete JavaScript isolation between tests
//! - No shared global state
//! - Fresh testharness.js for each test
//!
//! This matches the default behavior of `wpt run` (without --reuse-window flag).
//!
//! ## Usage
//!
//! ```zig
//! const adapter = @import("browser_adapter.zig");
//!
//! // Create adapter at runner startup
//! var browser = try adapter.BrowserAdapter.init(allocator, wpt_root);
//! defer browser.deinit();
//!
//! // For each test (creates fresh context)
//! const result = try browser.runTest(test_path, test_content, timeout);
//! ```

const std = @import("std");
const browser_context = @import("browser_context.zig");
const BrowserContext = browser_context.BrowserContext;

const config = @import("config.zig");
const test_parser = @import("test_parser.zig");
const test_harness = @import("test_harness.zig");

// Browser module for HTTP navigation
const browser = @import("browser");
const navigation = browser.navigation;

/// Adapter that provides browser-aligned WPT test execution
/// with fresh context per test (matching real browser behavior)
pub const BrowserAdapter = struct {
    allocator: std.mem.Allocator,
    /// WPT root directory
    wpt_root: []const u8,
    /// Number of tests run (for stats)
    tests_run: usize,

    /// Initialize the browser adapter
    pub fn init(allocator: std.mem.Allocator, wpt_root: []const u8) !*BrowserAdapter {
        const adapter = try allocator.create(BrowserAdapter);
        errdefer allocator.destroy(adapter);

        adapter.* = BrowserAdapter{
            .allocator = allocator,
            .wpt_root = try allocator.dupe(u8, wpt_root),
            .tests_run = 0,
        };

        return adapter;
    }

    /// Cleanup the adapter
    pub fn deinit(self: *BrowserAdapter) void {
        self.allocator.free(self.wpt_root);
        self.allocator.destroy(self);
    }

    /// Check if a script has already been loaded in this context
    /// With fresh contexts per test, scripts are never "already loaded"
    pub fn isScriptLoaded(self: *BrowserAdapter, script_path: []const u8) bool {
        _ = self;
        _ = script_path;
        // Fresh context per test - nothing is pre-loaded
        return false;
    }

    /// Mark a script as loaded (no-op with fresh contexts)
    pub fn markScriptLoaded(self: *BrowserAdapter, script_path: []const u8) !void {
        _ = self;
        _ = script_path;
        // No-op: each test gets a fresh context
    }

    /// Run a single WPT test (JavaScript content)
    ///
    /// Creates a FRESH V8 context for each test, matching real browser behavior.
    /// This provides complete JavaScript isolation between tests.
    ///
    /// Flow:
    /// 1. Create new BrowserContext (new V8 isolate + context)
    /// 2. Load testharness.js
    /// 3. Execute test script
    /// 4. Wait for completion
    /// 5. Cleanup context
    pub fn runTest(
        self: *BrowserAdapter,
        test_path: []const u8,
        test_content: []const u8,
        timeout: config.Timeout,
        context_type: test_parser.GlobalType,
    ) !test_harness.TestResult {
        // Map GlobalType (from test_parser) to ContextType (from browser_context)
        const ctx_type: browser_context.ContextType = switch (context_type) {
            .window => .window,
            .worker => .worker,
            .sharedworker => .shared_worker,
            .serviceworker => .service_worker,
            // ShadowRealm variants map to window for now (not implemented)
            .shadowrealm,
            .shadowrealm_in_window,
            .shadowrealm_in_dedicatedworker,
            .shadowrealm_in_sharedworker,
            .shadowrealm_in_shadowrealm,
            .shadowrealm_in_audioworklet,
            .shadowrealm_in_serviceworker,
            => .window,
        };

        // Create fresh browser context for this test with the specified context type
        var ctx = try BrowserContext.init(self.allocator, ctx_type, self.wpt_root);
        defer ctx.deinit();

        // Initialize V8 isolate and context
        try ctx.initialize();

        // Load testharness.js
        try ctx.loadTestHarness();

        // Execute the test
        const result = try ctx.executeTest(test_path, test_content, timeout);

        self.tests_run += 1;
        return result;
    }

    /// Run an HTML WPT test
    ///
    /// For .html tests, this method:
    /// 1. Creates a fresh V8 context
    /// 2. Loads testharness.js
    /// 3. Parses the HTML content and builds a real DOM tree
    /// 4. Scripts execute during parsing (in document order)
    /// 5. Fires DOMContentLoaded after parsing
    /// 6. Waits for test completion
    ///
    /// This enables tests that use document.querySelector() to find
    /// elements that were parsed from the HTML.
    pub fn runHTMLTest(
        self: *BrowserAdapter,
        test_path: []const u8,
        html_content: []const u8,
        timeout: config.Timeout,
        context_type: test_parser.GlobalType,
    ) !test_harness.TestResult {
        // Map GlobalType (from test_parser) to ContextType (from browser_context)
        // HTML tests typically run in window context, but we support the parameter for consistency
        const ctx_type: browser_context.ContextType = switch (context_type) {
            .window => .window,
            .worker => .worker,
            .sharedworker => .shared_worker,
            .serviceworker => .service_worker,
            // ShadowRealm variants map to window for now (not implemented)
            .shadowrealm,
            .shadowrealm_in_window,
            .shadowrealm_in_dedicatedworker,
            .shadowrealm_in_sharedworker,
            .shadowrealm_in_shadowrealm,
            .shadowrealm_in_audioworklet,
            .shadowrealm_in_serviceworker,
            => .window,
        };

        // Create fresh browser context for this test with the specified context type
        var ctx = try BrowserContext.init(self.allocator, ctx_type, self.wpt_root);
        defer ctx.deinit();

        // Initialize V8 isolate and context
        try ctx.initialize();

        // NOTE: We do NOT pre-load testharness.js here.
        // The HTML test file will load it via <script src="/resources/testharness.js">.
        // Our script loader intercepts /resources/testharnessreport.js and returns
        // our custom version that registers the result callbacks.
        // This ensures callbacks are registered with the correct testharness.js instance.

        // Start tracking results for this test file
        try ctx.result_collector.startTest(test_path);

        // Set result collector for V8 callbacks
        browser_context.setResultCollector(&ctx.result_collector);
        defer browser_context.clearResultCollector();

        // Set WPT root, test path, and base URL for URL resolution
        browser_context.setWptRoot(self.wpt_root);
        browser_context.setCurrentTestPath(test_path);
        browser_context.setCurrentBaseUrl(test_path);

        // Parse HTML and build DOM - scripts execute during parsing
        // DOMContentLoaded is fired by the parser after deferred scripts execute
        // (per HTML Standard §13.2.7 "The end")
        ctx.loadHTMLDocument(html_content, test_path) catch |err| {
            std.debug.print("HTML parse error for {s}: {}\n", .{ test_path, err });
            // Return a failed result
            var result = try test_harness.TestResult.init(self.allocator, test_path);
            result.status = .@"error";
            result.message = "HTML parsing failed";
            return result;
        };

        // Trigger testharness.js completion
        try ctx.triggerTestHarnessCompletion();

        // Run event loop until completion or timeout
        const timeout_ms = timeout.toMillis();
        try ctx.runEventLoop(timeout_ms);

        // Collect and return results
        const result = ctx.result_collector.finalize(self.allocator, test_path);

        self.tests_run += 1;
        return result;
    }

    /// Run an HTML WPT test with an explicit base URL
    ///
    /// This variant allows specifying the base URL for resolving relative script URLs.
    /// Used when tests are fetched from HTTP and we need proper URL resolution.
    pub fn runHTMLTestWithBaseUrl(
        self: *BrowserAdapter,
        test_path: []const u8,
        html_content: []const u8,
        timeout: config.Timeout,
        context_type: test_parser.GlobalType,
        base_url: []const u8,
    ) !test_harness.TestResult {
        // Map GlobalType (from test_parser) to ContextType (from browser_context)
        // HTML tests typically run in window context, but we support the parameter for consistency
        const ctx_type: browser_context.ContextType = switch (context_type) {
            .window => .window,
            .worker => .worker,
            .sharedworker => .shared_worker,
            .serviceworker => .service_worker,
            // ShadowRealm variants map to window for now (not implemented)
            .shadowrealm,
            .shadowrealm_in_window,
            .shadowrealm_in_dedicatedworker,
            .shadowrealm_in_sharedworker,
            .shadowrealm_in_shadowrealm,
            .shadowrealm_in_audioworklet,
            .shadowrealm_in_serviceworker,
            => .window,
        };

        // Create fresh browser context for this test with the specified context type
        var ctx = try BrowserContext.init(self.allocator, ctx_type, self.wpt_root);
        defer ctx.deinit();

        // Initialize V8 isolate and context
        try ctx.initialize();

        // NOTE: We do NOT pre-load testharness.js here.
        // The HTML test file will load it via <script src="/resources/testharness.js">.
        // Our script loader intercepts /resources/testharnessreport.js and returns
        // our custom version that registers the result callbacks.
        // This ensures callbacks are registered with the correct testharness.js instance.

        // Start tracking results for this test file
        try ctx.result_collector.startTest(test_path);

        // Set result collector for V8 callbacks
        browser_context.setResultCollector(&ctx.result_collector);
        defer browser_context.clearResultCollector();

        // Set WPT root, test path, and base URL for URL resolution
        browser_context.setWptRoot(self.wpt_root);
        browser_context.setCurrentTestPath(test_path);
        browser_context.setCurrentBaseUrl(base_url);

        // Parse HTML and build DOM - scripts execute during parsing
        // DOMContentLoaded is fired by the parser after deferred scripts execute
        // (per HTML Standard §13.2.7 "The end")
        ctx.loadHTMLDocument(html_content, base_url) catch |err| {
            std.debug.print("HTML parse error for {s}: {}\n", .{ test_path, err });
            // Return a failed result
            var result = try test_harness.TestResult.init(self.allocator, test_path);
            result.status = .@"error";
            result.message = "HTML parsing failed";
            return result;
        };

        // Trigger testharness.js completion
        try ctx.triggerTestHarnessCompletion();

        // Run event loop until completion or timeout
        const timeout_ms = timeout.toMillis();
        try ctx.runEventLoop(timeout_ms);

        // Collect and return results
        const result = ctx.result_collector.finalize(self.allocator, test_path);

        self.tests_run += 1;
        return result;
    }

    /// Run a WPT test by fetching it from an HTTP URL
    ///
    /// This method:
    /// 1. Fetches the test HTML from the WPT server via HTTP
    /// 2. Creates a fresh V8 context (always window context for HTML parsing)
    /// 3. Parses and executes the fetched HTML
    /// 4. Waits for test completion
    ///
    /// For .any.js tests, the WPT server generates HTML wrappers:
    /// - test.any.html - runs test directly in window
    /// - test.any.worker.html - creates a Worker that runs the test
    ///
    /// In both cases, we parse HTML in window context. The worker variant
    /// works by the HTML spawning a Worker object, not by us running
    /// in worker context directly.
    pub fn runTestFromUrl(
        self: *BrowserAdapter,
        test_url: []const u8,
        test_path: []const u8,
        timeout: config.Timeout,
        context_type: test_parser.GlobalType,
    ) !test_harness.TestResult {
        _ = context_type; // URL already encodes the context (e.g., .any.worker.html)

        // Fetch the test HTML from the WPT server
        var fetch_result = navigation.fetchUrl(self.allocator, test_url, .{}) catch |err| {
            var result = try test_harness.TestResult.init(self.allocator, test_path);
            result.status = .@"error";
            result.message = try std.fmt.allocPrint(self.allocator, "Failed to fetch test from {s}: {}", .{ test_url, err });
            return result;
        };
        defer fetch_result.deinit();

        // Check for successful response
        if (fetch_result.status_code >= 400) {
            var result = try test_harness.TestResult.init(self.allocator, test_path);
            result.status = .@"error";
            result.message = try std.fmt.allocPrint(self.allocator, "HTTP {d} fetching {s}", .{ fetch_result.status_code, test_url });
            return result;
        }

        // Always parse HTML in window context - the URL determines the actual test context
        // (e.g., .any.worker.html will spawn a Worker internally)
        // Pass the full URL as base_url so relative script URLs can be resolved
        std.log.debug("runTestFromUrl: parsing HTML ({d} bytes) from {s}", .{ fetch_result.body.len, test_url });
        return self.runHTMLTestWithBaseUrl(test_path, fetch_result.body, timeout, .window, test_url);
    }
};
