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

// Browser module for HTTP navigation
const browser = @import("browser");
const navigation = browser.navigation;
const Context = browser.Context;

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
    ///
    /// Uses the unified GlobalScopeKind mapping layer for consistent behavior.
    /// See src/runtime/realm.zig GlobalScopeKind for the authoritative mapping.
    fn mapContextType(context_type: test_parser.GlobalType) browser.ContextType {
        const scope_kind = context_type.toGlobalScopeKind();
        return switch (scope_kind) {
            .window => .window,
            .dedicated_worker => .worker,
            .shared_worker => .shared_worker,
            .service_worker => .service_worker,
            // Worklets and ShadowRealm are not yet implemented in browser module
            // Return window as fallback (tests will be skipped via isImplemented check)
            .audio_worklet,
            .paint_worklet,
            .animation_worklet,
            .layout_worklet,
            .shared_storage_worklet,
            .shadow_realm,
            .unknown,
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
        const ctx_type = mapContextType(context_type);
        const timeout_ms = timeout.toMillis();

        const result = self.wpt_browser.runHTMLTest(
            test_path,
            html_content,
            test_path, // Use test_path as base URL
            timeout_ms,
            ctx_type,
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

    /// Run an HTML WPT test with an explicit base URL
    ///
    /// This variant allows specifying the base URL for resolving relative script URLs.
    /// Used when tests are fetched from HTTP and we need proper URL resolution.
    pub fn runHTMLTestWithBaseUrl(
        self: *BrowserAdapter,
        test_path: []const u8,
        html_content: []const u8,
        timeout_ms: u64,
        context_type: test_parser.GlobalType,
        base_url: []const u8,
    ) !test_harness.TestResult {
        const ctx_type = mapContextType(context_type);

        const result = self.wpt_browser.runHTMLTest(
            test_path,
            html_content,
            base_url,
            timeout_ms,
            ctx_type,
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

    /// Run a WPT test by fetching it from an HTTP URL
    ///
    /// This method:
    /// 1. Fetches the test HTML from the WPT server via HTTP
    /// 2. Detects if it's a reftest (visual comparison test) and skips if so
    /// 3. Creates a fresh V8 context (always window context for HTML parsing)
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
        timeout_ms: u64,
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

        // Detect reftest reference files (*-ref.html, *-notref.html) - these are not tests
        if (test_parser.isReftestReference(test_path)) {
            var result = try test_harness.TestResult.init(self.allocator, test_path);
            result.status = .skip;
            result.message = try self.allocator.dupe(u8, "Reftest reference file - not a test");
            return result;
        }

        // Detect reftests (visual comparison tests) - they don't use testharness.js
        // and would timeout waiting for completion callback
        if (test_parser.isReftest(fetch_result.body)) {
            var result = try test_harness.TestResult.init(self.allocator, test_path);
            result.status = .skip;
            result.message = try self.allocator.dupe(u8, "Reftest (visual comparison) - not implemented");
            return result;
        }

        // Detect harnessless HTML tests (no testharness.js) - "smoke tests"
        // These just parse the HTML and complete immediately
        if (!test_parser.htmlUsesTestHarness(fetch_result.body)) {
            return test_harness.TestResult.createSmokeTest(self.allocator, test_path, 0);
        }

        // Always parse HTML in window context - the URL determines the actual test context
        // (e.g., .any.worker.html will spawn a Worker internally)
        // Pass the full URL as base_url so relative script URLs can be resolved
        return self.runHTMLTestWithBaseUrl(test_path, fetch_result.body, timeout_ms, .window, test_url);
    }
};
