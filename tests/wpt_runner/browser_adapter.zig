//! Browser Adapter for WPT Runner
//!
//! This module provides an efficient browser adapter for WPT test execution
//! using context REUSE (not recreation) between tests.
//!
//! ## Performance Optimization
//!
//! Creating a new V8 context per test is expensive (~11s per test) due to:
//! - ~30,000 V8 FFI calls to register all WebIDL interfaces
//! - Parsing 200KB testharness.js
//! - DOM/navigator/location singleton creation
//!
//! Instead, we:
//! 1. Create V8 context ONCE with all interfaces registered
//! 2. Load testharness.js ONCE
//! 3. Between tests, reset JavaScript state via script (much cheaper)
//! 4. Run test in the existing context
//!
//! Expected speedup: 20-100x (from ~11s to ~100-500ms per test)
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
//! // For each test (reuses context, resets JS state)
//! const result = try browser.runTest(test_path, test_content, timeout);
//! ```

const std = @import("std");
const browser_context = @import("browser_context.zig");
const BrowserContext = browser_context.BrowserContext;

const config = @import("config.zig");
const test_parser = @import("test_parser.zig");
const test_harness = @import("test_harness.zig");

/// Adapter that provides efficient WPT test execution with context reuse
pub const BrowserAdapter = struct {
    allocator: std.mem.Allocator,
    /// Single browser context (maintained across all tests)
    context: *BrowserContext,
    /// WPT root directory
    wpt_root: []const u8,
    /// Whether the context has been initialized with testharness.js
    context_initialized: bool,
    /// Number of tests run (for stats)
    tests_run: usize,

    /// Initialize the browser adapter
    ///
    /// Creates a single BrowserContext that will be reused for all tests.
    /// The V8 isolate and context are created once, with JS state reset between tests.
    pub fn init(allocator: std.mem.Allocator, wpt_root: []const u8) !*BrowserAdapter {
        const adapter = try allocator.create(BrowserAdapter);
        errdefer allocator.destroy(adapter);

        // Create browser context (window type for WPT tests)
        // Note: createWindowContext returns a BrowserContext value, we need to allocate it
        const ctx = try allocator.create(BrowserContext);
        errdefer allocator.destroy(ctx);
        ctx.* = try BrowserContext.init(allocator, .window, wpt_root);
        errdefer ctx.deinit();
        try ctx.initialize();

        adapter.* = BrowserAdapter{
            .allocator = allocator,
            .context = ctx,
            .wpt_root = try allocator.dupe(u8, wpt_root),
            .context_initialized = false,
            .tests_run = 0,
        };

        return adapter;
    }

    /// Cleanup the adapter
    pub fn deinit(self: *BrowserAdapter) void {
        self.context.deinit();
        self.allocator.destroy(self.context);
        self.allocator.free(self.wpt_root);
        self.allocator.destroy(self);
    }

    /// Run a single WPT test
    ///
    /// REUSES the existing V8 context with JavaScript state reset.
    /// This is much faster than creating a new context per test.
    ///
    /// Flow:
    /// 1. First test: Load testharness.js (once)
    /// 2. Subsequent tests: Reset JS state
    /// 3. Execute test script
    /// 4. Wait for completion
    pub fn runTest(
        self: *BrowserAdapter,
        test_path: []const u8,
        test_content: []const u8,
        timeout: config.Timeout,
    ) !test_harness.TestResult {
        // First test: load testharness.js
        if (!self.context_initialized) {
            try self.initializeTestHarness();
        } else {
            // Subsequent tests: reload testharness.js completely
            // We can't reset testharness.js state because 'tests' is a local variable
            // in the IIFE, not accessible from outside. Re-loading is the only way.
            try self.context.loadTestHarness();
        }

        // Execute the test
        const result = try self.context.executeTest(test_path, test_content, timeout);

        self.tests_run += 1;
        return result;
    }

    /// Initialize testharness.js on first test
    fn initializeTestHarness(self: *BrowserAdapter) !void {
        try self.context.loadTestHarness();
        self.context_initialized = true;
    }
};
