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
//! ## Architecture
//!
//! BrowserAdapter -> WptBrowser -> Browser (src/browser/)
//!
//! - BrowserAdapter: WPT runner integration (test discovery, result collection)
//! - WptBrowser: WPT-specific functionality (testharness.js, script loading)
//! - Browser: Production browser core (V8, DOM, timers, events)
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
const WptBrowser = @import("wpt_browser.zig").WptBrowser;

const config = @import("config.zig");
const test_parser = @import("test_parser.zig");
const test_harness = @import("test_harness.zig");

// Browser module for context type mapping
const browser = @import("browser");

/// Adapter that provides browser-aligned WPT test execution
/// with fresh context per test (matching real browser behavior)
pub const BrowserAdapter = struct {
    allocator: std.mem.Allocator,
    /// WPT root directory
    wpt_root: []const u8,
    /// Number of tests run (for stats)
    tests_run: usize,
    /// WPT browser wrapper (wraps core Browser with WPT-specific functionality)
    wpt_browser: *WptBrowser,

    /// Initialize the browser adapter
    pub fn init(allocator: std.mem.Allocator, wpt_root: []const u8) !*BrowserAdapter {
        const adapter = try allocator.create(BrowserAdapter);
        errdefer allocator.destroy(adapter);

        // Create WptBrowser (wraps core Browser with WPT functionality)
        const wpt_browser = try WptBrowser.init(allocator, wpt_root);
        errdefer wpt_browser.deinit();

        adapter.* = BrowserAdapter{
            .allocator = allocator,
            .wpt_root = try allocator.dupe(u8, wpt_root),
            .tests_run = 0,
            .wpt_browser = wpt_browser,
        };

        return adapter;
    }

    /// Cleanup the adapter
    pub fn deinit(self: *BrowserAdapter) void {
        self.wpt_browser.deinit();
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

    /// Map GlobalType (from test_parser) to ContextType (from browser)
    fn mapContextType(context_type: test_parser.GlobalType) browser.ContextType {
        return switch (context_type) {
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
    }

    /// Run a single WPT test (JavaScript content)
    ///
    /// Creates a FRESH V8 context for each test, matching real browser behavior.
    /// This provides complete JavaScript isolation between tests.
    ///
    /// Flow:
    /// 1. Create new context (reuses V8 isolate for performance)
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
        const result = self.wpt_browser.runTest(
            test_path,
            test_content,
            timeout,
            context_type,
        ) catch |err| {
            // Convert error to TestResult
            var error_result = try test_harness.TestResult.init(self.allocator, test_path);
            error_result.status = .@"error";
            error_result.message = try std.fmt.allocPrint(self.allocator, "Test execution failed: {}", .{err});
            return error_result;
        };

        self.tests_run += 1;
        return result;
    }

    /// Run an HTML WPT test via HTTP navigation
    ///
    /// For .html tests, this method:
    /// 1. Builds HTTP URL from test_path
    /// 2. Creates a fresh V8 context (navigates to URL)
    /// 3. Loads testharness.js
    /// 4. Fetches test HTML via HTTP
    /// 5. Parses the HTML content and builds a real DOM tree
    /// 6. Scripts execute during parsing (in document order)
    /// 7. Waits for test completion
    ///
    /// This mimics real browser behavior where all content is fetched over the network.
    pub fn runHTMLTest(
        self: *BrowserAdapter,
        test_path: []const u8,
        timeout: config.Timeout,
        context_type: test_parser.GlobalType,
    ) !test_harness.TestResult {
        _ = context_type; // URL determines context type

        // Build HTTP URL from test path
        const test_url = try std.fmt.allocPrint(self.allocator, "http://web-platform.test:8000/{s}", .{test_path});
        defer self.allocator.free(test_url);

        const timeout_ms = timeout.toMillis();

        // Use window context for HTML parsing - test URL determines actual execution context
        // (e.g., .any.worker.html spawns a Worker internally)
        const result = self.wpt_browser.runHTMLTest(
            test_path,
            test_url,
            timeout_ms,
            .window,
        ) catch |err| {
            // Convert error to TestResult
            var error_result = try test_harness.TestResult.init(self.allocator, test_path);
            error_result.status = .@"error";
            error_result.message = try std.fmt.allocPrint(self.allocator, "HTML test execution failed: {}", .{err});
            return error_result;
        };

        self.tests_run += 1;
        return result;
    }

    /// Run an HTML WPT test with an explicit HTTP URL
    ///
    /// This variant allows specifying the full HTTP URL for fetching the test.
    /// Used when running tests via runTestFromUrl.
    pub fn runHTMLTestWithUrl(
        self: *BrowserAdapter,
        test_path: []const u8,
        test_url: []const u8,
        timeout: config.Timeout,
    ) !test_harness.TestResult {
        const timeout_ms = timeout.toMillis();

        const result = self.wpt_browser.runHTMLTest(
            test_path,
            test_url,
            timeout_ms,
            .window,
        ) catch |err| {
            // Convert error to TestResult
            var error_result = try test_harness.TestResult.init(self.allocator, test_path);
            error_result.status = .@"error";
            error_result.message = try std.fmt.allocPrint(self.allocator, "HTML test execution failed: {}", .{err});
            return error_result;
        };

        self.tests_run += 1;
        return result;
    }

    /// Run a WPT test via HTTP URL
    ///
    /// This method:
    /// 1. Navigates browser to test URL
    /// 2. Browser fetches test HTML via HTTP
    /// 3. Loads testharness.js
    /// 4. Parses and executes the fetched HTML
    /// 5. Waits for test completion
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

        // Delegate to runHTMLTestWithUrl - browser handles the HTTP fetch
        return self.runHTMLTestWithUrl(test_path, test_url, timeout);
    }
};
