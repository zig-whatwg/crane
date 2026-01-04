//! Parallel Test Execution for WPT Runner
//!
//! This module provides thread pool based parallel execution of WPT tests.
//! Each worker thread has its own BrowserAdapter for complete isolation.
//!
//! ## Architecture
//!
//! ```
//! Main Thread                    Worker Threads
//!    │                           ┌─────────────┐
//!    │                           │ Worker 0    │
//!    │                           │  Browser    │
//!    │    ┌──────────────┐       │  Process    │
//!    ├───>│  Work Queue  │───────│  Tests      │
//!    │    └──────────────┘       └─────────────┘
//!    │                           ┌─────────────┐
//!    │                           │ Worker 1    │
//!    │                           │  Browser    │
//!    │    ┌──────────────┐       │  Process    │
//!    │<───│ Result Queue │<──────│  Tests      │
//!    │    └──────────────┘       └─────────────┘
//!    │                                ...
//! ```
//!
//! ## Thread Safety
//!
//! - Work queue uses mutex for thread-safe access
//! - Result queue uses mutex for result collection
//! - Atomic counters for progress tracking

const std = @import("std");
const browser_adapter = @import("browser_adapter.zig");
const test_harness = @import("test_harness.zig");
const test_parser = @import("test_parser.zig");
const result_reporter = @import("result_reporter.zig");
const wpt_server = @import("wpt_server.zig");
const config = @import("config.zig");

const main = @import("main.zig");
const TestFile = main.TestFile;
const Options = main.Options;

const MAX_WORKERS = 64;

/// A single work item: a test file + context + variant combination
pub const WorkItem = struct {
    test_file: TestFile,
    context: test_parser.GlobalType,
    context_name: ?[]const u8,
    parsed_content: []const u8,
    metadata: test_parser.TestMetadata,
    /// URL variant query string (e.g., "?no_flag" or "?wpt_flags=h2")
    variant: ?[]const u8 = null,
};

/// Thread-safe work queue
pub const WorkQueue = struct {
    mutex: std.Thread.Mutex,
    items: []WorkItem,
    index: usize,
    total: usize,

    pub fn init(items: []WorkItem) WorkQueue {
        return WorkQueue{
            .mutex = .{},
            .items = items,
            .index = 0,
            .total = items.len,
        };
    }

    /// Get the next work item, returns null when queue is empty
    pub fn getNext(self: *WorkQueue) ?*WorkItem {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.index >= self.items.len) {
            return null;
        }

        const item = &self.items[self.index];
        self.index += 1;
        return item;
    }

    /// Get the total number of items
    pub fn getTotal(self: *WorkQueue) usize {
        return self.total;
    }
};

/// Thread-safe result collection
pub const ResultQueue = struct {
    mutex: std.Thread.Mutex,
    results: std.ArrayList(test_harness.TestResult),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ResultQueue {
        return ResultQueue{
            .mutex = .{},
            .results = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ResultQueue) void {
        for (self.results.items) |*r| {
            r.deinit(self.allocator);
        }
        self.results.deinit(self.allocator);
    }

    /// Add a result (thread-safe)
    pub fn addResult(self: *ResultQueue, result: test_harness.TestResult) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.results.append(self.allocator, result);
    }
};

/// Atomic progress counters
pub const ProgressCounters = struct {
    completed: std.atomic.Value(usize),
    passed: std.atomic.Value(usize),
    failed: std.atomic.Value(usize),
    errors: std.atomic.Value(usize),
    timeouts: std.atomic.Value(usize),

    pub fn init() ProgressCounters {
        return ProgressCounters{
            .completed = std.atomic.Value(usize).init(0),
            .passed = std.atomic.Value(usize).init(0),
            .failed = std.atomic.Value(usize).init(0),
            .errors = std.atomic.Value(usize).init(0),
            .timeouts = std.atomic.Value(usize).init(0),
        };
    }

    pub fn incrementCompleted(self: *ProgressCounters) void {
        _ = self.completed.fetchAdd(1, .monotonic);
    }

    pub fn incrementPassed(self: *ProgressCounters, count: usize) void {
        _ = self.passed.fetchAdd(count, .monotonic);
    }

    pub fn incrementFailed(self: *ProgressCounters, count: usize) void {
        _ = self.failed.fetchAdd(count, .monotonic);
    }

    pub fn incrementErrors(self: *ProgressCounters) void {
        _ = self.errors.fetchAdd(1, .monotonic);
    }

    pub fn incrementTimeouts(self: *ProgressCounters) void {
        _ = self.timeouts.fetchAdd(1, .monotonic);
    }

    pub fn getCompleted(self: *ProgressCounters) usize {
        return self.completed.load(.monotonic);
    }

    pub fn getPassed(self: *ProgressCounters) usize {
        return self.passed.load(.monotonic);
    }

    pub fn getFailed(self: *ProgressCounters) usize {
        return self.failed.load(.monotonic);
    }
};

/// Worker thread context
const WorkerContext = struct {
    id: usize,
    allocator: std.mem.Allocator,
    work_queue: *WorkQueue,
    result_queue: *ResultQueue,
    progress: *ProgressCounters,
    wpt_root: []const u8,
    server: *wpt_server.WptServer,
    timeout_multiplier: f32,
};

/// Worker thread function
fn workerFn(ctx: *WorkerContext) void {
    // Create browser adapter for this worker
    var browser = browser_adapter.BrowserAdapter.init(ctx.allocator, ctx.wpt_root) catch |err| {
        std.debug.print("Worker {d}: Failed to initialize browser: {}\n", .{ ctx.id, err });
        return;
    };
    defer browser.deinit();

    // Process work items until queue is empty
    while (ctx.work_queue.getNext()) |item| {
        // Execute the test
        const result = executeWorkItem(ctx.allocator, browser, item, ctx.server, ctx.timeout_multiplier) catch |err| {
            // Create error result
            var error_result = test_harness.TestResult.init(ctx.allocator, item.test_file.path) catch continue;
            error_result.status = .@"error";
            error_result.message = std.fmt.allocPrint(ctx.allocator, "Worker error: {}", .{err}) catch null;

            ctx.result_queue.addResult(error_result) catch {};
            ctx.progress.incrementCompleted();
            ctx.progress.incrementErrors();
            continue;
        };

        // Count results
        var passed: usize = 0;
        var failed: usize = 0;
        for (result.subtests.items) |sub| {
            switch (sub.status) {
                .pass => passed += 1,
                .fail => failed += 1,
                .timeout => {},
                else => {},
            }
        }

        ctx.result_queue.addResult(result) catch {};
        ctx.progress.incrementCompleted();
        ctx.progress.incrementPassed(passed);
        ctx.progress.incrementFailed(failed);

        if (result.status == .@"error") {
            ctx.progress.incrementErrors();
        } else if (result.status == .timeout) {
            ctx.progress.incrementTimeouts();
        }
    }
}

/// Execute a single work item
fn executeWorkItem(
    allocator: std.mem.Allocator,
    browser: *browser_adapter.BrowserAdapter,
    item: *WorkItem,
    server: *wpt_server.WptServer,
    timeout_multiplier: f32,
) !test_harness.TestResult {
    // Build test URL
    const test_url = try server.buildTestUrl(allocator, item.test_file.path, item.context, item.variant);
    defer allocator.free(test_url);

    // Calculate adjusted timeout
    const base_ms: f64 = @floatFromInt(item.metadata.timeout.toMillis());
    const adjusted_ms: u64 = @intFromFloat(base_ms * timeout_multiplier);
    const timeout_ms = if (adjusted_ms > 0) adjusted_ms else 1; // Minimum 1ms

    // Run test from URL
    var result = try browser.runTestFromUrl(test_url, item.test_file.path, timeout_ms, item.context);

    // Set context name for multi-context tests
    if (item.context_name) |ctx_name| {
        result.context = try allocator.dupe(u8, ctx_name);
    }

    return result;
}

/// Execute tests in parallel using thread pool
pub fn executeTestsParallel(
    allocator: std.mem.Allocator,
    work_items: []WorkItem,
    options: Options,
    report: *result_reporter.WptReport,
    server: *wpt_server.WptServer,
) !void {
    // Determine number of workers
    const num_workers = if (options.parallel == 0)
        @min(std.Thread.getCpuCount() catch 4, MAX_WORKERS)
    else
        @min(@as(usize, options.parallel), MAX_WORKERS);

    std.debug.print("\nRunning {d} tests in parallel with {d} workers...\n\n", .{ work_items.len, num_workers });

    // Initialize queues
    var work_queue = WorkQueue.init(work_items);
    var result_queue = ResultQueue.init(allocator);
    defer result_queue.deinit();
    var progress = ProgressCounters.init();

    // Create worker contexts
    var worker_contexts: [MAX_WORKERS]WorkerContext = undefined;
    for (0..num_workers) |i| {
        worker_contexts[i] = WorkerContext{
            .id = i,
            .allocator = allocator,
            .work_queue = &work_queue,
            .result_queue = &result_queue,
            .progress = &progress,
            .wpt_root = options.wpt_root,
            .server = server,
            .timeout_multiplier = options.timeout_multiplier,
        };
    }

    // Spawn worker threads
    var threads: [MAX_WORKERS]std.Thread = undefined;
    var spawned: usize = 0;
    for (0..num_workers) |i| {
        threads[i] = std.Thread.spawn(.{}, workerFn, .{&worker_contexts[i]}) catch continue;
        spawned += 1;
    }

    // Progress reporting thread (simple periodic print)
    const total = work_queue.getTotal();
    const start_time = std.time.milliTimestamp();

    // Wait for workers while showing progress
    while (progress.getCompleted() < total) {
        std.Thread.sleep(500 * std.time.ns_per_ms);

        const completed = progress.getCompleted();
        const passed = progress.getPassed();
        const failed = progress.getFailed();
        const elapsed_ms: u64 = @intCast(std.time.milliTimestamp() - start_time);
        const elapsed_s = elapsed_ms / 1000;

        if (!options.verbose) {
            const percent = if (total > 0) (completed * 100) / total else 0;
            std.debug.print("\r[{d}/{d}] {d}% | Pass: {d} | Fail: {d} | Time: {d}s   ", .{
                completed,
                total,
                percent,
                passed,
                failed,
                elapsed_s,
            });
        }
    }

    // Wait for all threads to complete
    for (threads[0..spawned]) |t| {
        t.join();
    }

    // Clear progress line
    if (!options.verbose) {
        std.debug.print("\r{s: <80}\r", .{""});
    }

    // Sort results by test path for deterministic output
    std.mem.sort(test_harness.TestResult, result_queue.results.items, {}, struct {
        fn lessThan(_: void, a: test_harness.TestResult, b: test_harness.TestResult) bool {
            return std.mem.lessThan(u8, a.test_path, b.test_path);
        }
    }.lessThan);

    // Add all results to report
    for (result_queue.results.items) |result| {
        try report.addResult(result);
    }

    // Print summary
    const elapsed_ms: u64 = @intCast(std.time.milliTimestamp() - start_time);
    const passed = progress.getPassed();
    const failed = progress.getFailed();
    const errors = progress.errors.load(.monotonic);
    const timeouts = progress.timeouts.load(.monotonic);

    std.debug.print("\n================================\n", .{});
    std.debug.print("WPT Parallel Test Results\n", .{});
    std.debug.print("================================\n", .{});
    std.debug.print("Workers:    {d}\n", .{num_workers});
    std.debug.print("Tests:      {d}\n", .{total});
    std.debug.print("  Passed:   {d}\n", .{passed});
    std.debug.print("  Failed:   {d}\n", .{failed});
    std.debug.print("  Errors:   {d}\n", .{errors});
    std.debug.print("  Timeouts: {d}\n", .{timeouts});
    std.debug.print("Duration:   {d}ms\n", .{elapsed_ms});
    std.debug.print("================================\n", .{});
}
