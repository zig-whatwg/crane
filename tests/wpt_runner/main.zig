//! WPT Test Runner Entry Point
//!
//! Main entry point for the WPT (Web Platform Tests) test runner.
//! Parses command-line arguments, discovers tests, executes them,
//! and generates the wptreport.json output.
//!
//! ## Usage
//!
//! ```bash
//! # Run all in-scope tests
//! zig build wpt
//!
//! # Run specific categories
//! zig build wpt -- url/
//! zig build wpt -- url/ encoding/
//!
//! # Run specific test file
//! zig build wpt -- url/url-constructor.any.js
//! ```
//!
//! ## Options
//!
//! Build-time options (passed before `--`):
//! - `-Dwpt-debug=true` - Enable debug log output (std.log.debug statements)
//! - `-Dwpt-verbose=true` - Show verbose output for each test
//!
//! Runtime options (passed after `--`):
//! - `--output=path` - Output directory for results (default: wpt-results/)
//! - `--quiet` or `-q` - Minimal output (progress bar only, no individual tests)
//! - `--parallel=N` - Number of parallel test runners
//! - `--limit=N` - Run only the first N test files (useful for quick iteration)
//! - `--pattern=GLOB` - Only run tests matching glob pattern (e.g., "*constructor*")
//! - `--legacy-scan` - Discover by walking the filesystem instead of MANIFEST.json
//! - `--discover-only` - Report what would run, then stop
//! - `--worklist-out=path` - Write the discovered sources, one per line
//!
//! Crash-tolerant runs:
//! - `--supervise` - Discover, then respawn this binary past any test that
//!   kills the process, until the worklist is exhausted. Writes
//!   `<output>/worklist.txt` and `<output>/journal.jsonl`.
//!
//! Child-process options, set by the supervisor (rarely used directly):
//! - `--from-file=path` - Run the paths in this worklist instead of discovering
//! - `--start-index=N` - Begin at this worklist index
//! - `--journal=path` - Append a JSONL record per completed test file

const std = @import("std");
const config = @import("config.zig");
const test_parser = @import("test_parser.zig");
const test_harness = @import("test_harness.zig");
const browser_adapter = @import("browser_adapter.zig");
const result_reporter = @import("result_reporter.zig");
const wpt_server = @import("wpt_server.zig");
const wpt_manifest = @import("manifest.zig");
const selection = @import("selection.zig");
const journal = @import("journal.zig");
const options_mod = @import("options.zig");
const discovery_mod = @import("discovery.zig");
const wpt_options = @import("wpt_options");

/// Thread-local verbose flag for log filtering
var verbose_mode: bool = false;

/// Custom log function that suppresses error logs in non-verbose mode.
/// This prevents V8 engine errors from cluttering the test output.
pub const std_options: std.Options = .{
    // Control log level based on -Dwpt-debug build flag
    // When debug is disabled (default), only show warnings and errors
    // When debug is enabled, show all log levels including debug
    .log_level = if (wpt_options.debug_enabled) .debug else .warn,
    .logFn = wptLogFn,
};

fn wptLogFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    // In non-verbose mode, suppress error-level logs from v8_engine
    // These are expected during test execution (test failures cause JS errors)
    if (!verbose_mode and level == .err and scope == .v8_engine) {
        return;
    }

    // Use default implementation for everything else
    std.log.defaultLog(level, scope, format, args);
}

// The runner's command-line surface and test discovery live in their own
// modules so `zig build test` can cover them. main.zig links V8 and libuv and
// is only ever built as an executable, which means any test block in this file
// is never compiled, let alone run.
pub const Options = options_mod.Options;
pub const parseArgs = options_mod.parseArgs;
const isTestFile = options_mod.isTestFile;

pub const TestFile = discovery_mod.TestFile;
pub const SkippedEntry = discovery_mod.SkippedEntry;
pub const DiscoveryResult = discovery_mod.DiscoveryResult;
pub const discoverTests = discovery_mod.discoverTests;

/// Stored failure detail for final report
const FailureDetail = struct {
    test_path: []const u8,
    context: ?[]const u8,
    status: test_harness.HarnessStatus,
    message: ?[]const u8,
    duration_ms: u64,
    subtests: std.ArrayList(SubtestFailure),

    const SubtestFailure = struct {
        name: []const u8,
        status: test_harness.TestStatus,
        message: ?[]const u8,
        stack: ?[]const u8,
    };

    fn deinit(self: *FailureDetail, allocator: std.mem.Allocator) void {
        allocator.free(self.test_path);
        if (self.context) |ctx| allocator.free(ctx);
        if (self.message) |msg| allocator.free(msg);
        for (self.subtests.items) |*sub| {
            allocator.free(sub.name);
            if (sub.message) |msg| allocator.free(msg);
            if (sub.stack) |stk| allocator.free(stk);
        }
        self.subtests.deinit(allocator);
    }
};

/// Progress tracker for test execution
pub const ProgressTracker = struct {
    allocator: std.mem.Allocator,
    total: usize,
    completed: usize = 0,
    passed: usize = 0,
    failed: usize = 0,
    errors: usize = 0,
    timeouts: usize = 0,
    notrun: usize = 0,
    start_time: i64,
    verbose: bool,
    /// Failures by category for summary
    failures_by_category: std.StringHashMap(usize),
    /// Detailed failure records for final report
    failure_details: std.ArrayList(FailureDetail),

    pub fn init(allocator: std.mem.Allocator, total: usize, verbose: bool) ProgressTracker {
        return ProgressTracker{
            .allocator = allocator,
            .total = total,
            .start_time = std.time.milliTimestamp(),
            .verbose = verbose,
            .failures_by_category = std.StringHashMap(usize).init(allocator),
            .failure_details = .{},
        };
    }

    pub fn deinit(self: *ProgressTracker) void {
        self.failures_by_category.deinit();
        for (self.failure_details.items) |*detail| {
            detail.deinit(self.allocator);
        }
        self.failure_details.deinit(self.allocator);
    }

    pub fn recordResult(self: *ProgressTracker, test_path: []const u8, result: test_harness.TestResult) void {
        self.recordResultWithExpected(test_path, result, null);
    }

    pub fn recordResultWithExpected(self: *ProgressTracker, test_path: []const u8, result: test_harness.TestResult, expected: ?*const result_reporter.ExpectedResults) void {
        self.completed += 1;

        // Check if this test is expected to fail/error
        const is_expected_error = if (expected) |exp| blk: {
            if (exp.test_expected) |test_exp| {
                break :blk test_exp == .fail or test_exp == .@"error";
            }
            break :blk false;
        } else false;

        // In verbose mode, always show the test file being run with its status
        if (self.verbose) {
            const status_icon = switch (result.status) {
                .ok => "✅",
                .@"error" => "💥",
                .timeout => "⏰",
            };
            print("\n[{d}/{d}] {s} {s}", .{ self.completed, self.total, status_icon, test_path });
            if (result.context) |ctx| {
                print(" [{s}]", .{ctx});
            }
            print(" ({d}ms)\n", .{result.duration_ms});

            // Show error message at test level
            if (result.status == .@"error") {
                if (result.message) |msg| {
                    print("  💬 Error: {s}\n", .{msg});
                }
            }

            // Show timeout message at test level
            if (result.status == .timeout) {
                if (result.message) |msg| {
                    print("  💬 {s}\n", .{msg});
                } else {
                    print("  💬 Test timed out\n", .{});
                }
            }
        }

        // Count by test status (only count as error if not expected)
        switch (result.status) {
            .ok => {},
            .@"error" => {
                if (!is_expected_error) {
                    self.errors += 1;
                }
            },
            .timeout => self.timeouts += 1,
        }

        // Track if this test has any failures for the final report
        var has_failures = result.status != .ok;
        var failure_subtests: std.ArrayList(FailureDetail.SubtestFailure) = .{};

        // Count ALL subtests including notrun/precondition_failed
        for (result.subtests.items) |sub| {
            // Check if this is an expected failure
            const is_expected_fail = if (expected) |exp| blk: {
                // Sanitize name for lookup (matches result_reporter logic)
                const sanitized_name = result_reporter.sanitizeLoneSurrogates(self.failures_by_category.allocator, sub.name) catch sub.name;
                defer if (sanitized_name.ptr != sub.name.ptr) self.failures_by_category.allocator.free(sanitized_name);

                // Check if expected to fail
                if (exp.getExpectedForSubtest(sanitized_name)) |exp_status| {
                    break :blk exp_status == .fail;
                } else if (exp.getExpectedForSubtestCaseInsensitive(sanitized_name)) |exp_status| {
                    break :blk exp_status == .fail;
                } else if (exp.test_expected) |test_exp| {
                    break :blk test_exp == .fail;
                }
                break :blk false;
            } else false;

            switch (sub.status) {
                .pass => {
                    self.passed += 1;
                    // In verbose mode, show passing subtests too
                    if (self.verbose) {
                        print("  ├── ✅ {s}\n", .{sub.name});
                    }
                },
                .fail => {
                    if (is_expected_fail) {
                        // Expected failure counts as pass
                        self.passed += 1;
                        if (self.verbose) {
                            print("  ├── ✅ (expected fail) {s}\n", .{sub.name});
                        }
                    } else {
                        self.failed += 1;
                        has_failures = true;

                        // Store failure for final report
                        failure_subtests.append(self.allocator, .{
                            .name = self.allocator.dupe(u8, sub.name) catch sub.name,
                            .status = sub.status,
                            .message = if (sub.message) |msg| self.allocator.dupe(u8, msg) catch null else null,
                            .stack = if (sub.stack) |stk| self.allocator.dupe(u8, stk) catch null else null,
                        }) catch {};

                        // Track failures by category
                        if (std.mem.indexOf(u8, test_path, "/")) |sep_pos| {
                            const category = test_path[0..sep_pos];
                            const entry = self.failures_by_category.getOrPut(category) catch continue;
                            if (!entry.found_existing) {
                                entry.value_ptr.* = 0;
                            }
                            entry.value_ptr.* += 1;
                        }
                        // Always print failure details in verbose mode
                        if (self.verbose) {
                            print("  ├── ❌ {s}\n", .{sub.name});
                            if (sub.message) |msg| {
                                print("  │      📝 {s}\n", .{msg});
                            }
                            if (sub.stack) |stack| {
                                // Print full stack trace
                                print("  │      📍 Stack:\n", .{});
                                var iter = std.mem.splitScalar(u8, stack, '\n');
                                while (iter.next()) |line| {
                                    if (line.len > 0) {
                                        print("  │         {s}\n", .{line});
                                    }
                                }
                            }
                        }
                    }
                },
                .timeout => {
                    self.timeouts += 1;
                    has_failures = true;

                    // Store timeout for final report
                    failure_subtests.append(self.allocator, .{
                        .name = self.allocator.dupe(u8, sub.name) catch sub.name,
                        .status = sub.status,
                        .message = if (sub.message) |msg| self.allocator.dupe(u8, msg) catch null else null,
                        .stack = null,
                    }) catch {};

                    if (self.verbose) {
                        print("  ├── ⏰ {s}\n", .{sub.name});
                        if (sub.message) |msg| {
                            print("  │      📝 {s}\n", .{msg});
                        }
                    }
                },
                .notrun, .precondition_failed => {
                    self.notrun += 1;
                    if (self.verbose) {
                        print("  ├── ⚪ ({s}) {s}\n", .{ sub.status.toString(), sub.name });
                    }
                },
            }
        }

        // Store failure detail for final report (if there were any failures)
        if (has_failures) {
            self.failure_details.append(self.allocator, .{
                .test_path = self.allocator.dupe(u8, test_path) catch test_path,
                .context = if (result.context) |ctx| self.allocator.dupe(u8, ctx) catch null else null,
                .status = result.status,
                .message = if (result.message) |msg| self.allocator.dupe(u8, msg) catch null else null,
                .duration_ms = result.duration_ms,
                .subtests = failure_subtests,
            }) catch {
                // If we can't store, at least clean up subtests
                for (failure_subtests.items) |*sub| {
                    self.allocator.free(sub.name);
                    if (sub.message) |msg| self.allocator.free(msg);
                    if (sub.stack) |stk| self.allocator.free(stk);
                }
                failure_subtests.deinit(self.allocator);
            };
        } else {
            // No failures, clean up the empty list
            failure_subtests.deinit(self.allocator);
        }
    }

    /// Print progress with optional context suffix
    /// For single-context tests: [X/Y] path/test.any.js
    /// For multi-context tests: [X/Y] path/test.any.js [worker]
    pub fn printProgress(self: *ProgressTracker, current_test: []const u8) void {
        self.printProgressWithContext(current_test, null);
    }

    /// Print progress with explicit context
    /// In verbose mode, this is a no-op since recordResultWithExpected prints detailed output
    pub fn printProgressWithContext(self: *ProgressTracker, current_test: []const u8, context: ?[]const u8) void {
        // In verbose mode, don't print progress here - it's done in recordResultWithExpected
        if (self.verbose) {
            return;
        }

        // Build display name with context suffix if present
        var display_buf: [256]u8 = undefined;
        const display_name = if (context) |ctx| blk: {
            const len = std.fmt.bufPrint(&display_buf, "{s} [{s}]", .{ current_test, ctx }) catch current_test;
            break :blk len;
        } else current_test;

        // Print progress bar on same line
        const percent = if (self.total > 0) (self.completed * 100) / self.total else 0;
        const elapsed = self.getElapsedTime();

        // Truncate test path if too long
        const max_path_len: usize = 50;
        const display_path = if (display_name.len > max_path_len)
            display_name[display_name.len - max_path_len ..]
        else
            display_name;

        print("\r[{d}/{d}] {d}% | Pass: {d} | Fail: {d} | Time: {s} | {s}   ", .{
            self.completed,
            self.total,
            percent,
            self.passed,
            self.failed,
            elapsed,
            display_path,
        });
    }

    pub fn getElapsedTime(self: *ProgressTracker) []const u8 {
        const elapsed_ms: u64 = @intCast(std.time.milliTimestamp() - self.start_time);
        const seconds = (elapsed_ms / 1000) % 60;
        const minutes = (elapsed_ms / 60000) % 60;
        const hours = elapsed_ms / 3600000;

        // Use a static buffer for the formatted time
        const Static = struct {
            var buf: [20]u8 = undefined;
        };

        const len = std.fmt.bufPrint(&Static.buf, "{d:0>2}:{d:0>2}:{d:0>2}", .{ hours, minutes, seconds }) catch return "??:??:??";
        return len;
    }

    pub fn printSummary(self: *ProgressTracker, output_path: []const u8) void {
        // Clear progress line
        if (!self.verbose) {
            print("\r{s: <80}\r", .{""});
        }

        const elapsed = self.getElapsedTime();
        const total_subtests = self.passed + self.failed + self.timeouts + self.notrun;

        // Print detailed failure report first (before summary)
        if (self.failure_details.items.len > 0) {
            print("\n", .{});
            print("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\n", .{});
            print("┃  ❌ FAILURE REPORT                                                           ┃\n", .{});
            print("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\n", .{});

            for (self.failure_details.items, 0..) |detail, idx| {
                // Test file header
                const status_icon = switch (detail.status) {
                    .ok => "✅",
                    .@"error" => "💥",
                    .timeout => "⏰",
                };

                print("\n┌─ {d}. {s} {s}", .{ idx + 1, status_icon, detail.test_path });
                if (detail.context) |ctx| {
                    print(" [{s}]", .{ctx});
                }
                print(" ({d}ms)\n", .{detail.duration_ms});

                // Show test-level error message
                if (detail.message) |msg| {
                    print("│  💬 {s}\n", .{msg});
                }

                // Show failed/timed-out subtests
                if (detail.subtests.items.len > 0) {
                    for (detail.subtests.items, 0..) |sub, sub_idx| {
                        const is_last = sub_idx == detail.subtests.items.len - 1;
                        const prefix = if (is_last) "└" else "├";
                        const cont = if (is_last) " " else "│";

                        const sub_icon = switch (sub.status) {
                            .pass => "✅",
                            .fail => "❌",
                            .timeout => "⏰",
                            .notrun, .precondition_failed => "⚪",
                        };
                        print("│  {s}── {s} {s}\n", .{ prefix, sub_icon, sub.name });

                        // Show assertion message
                        if (sub.message) |msg| {
                            print("│  {s}      📝 {s}\n", .{ cont, msg });
                        }

                        // Show full stack trace for failures
                        if (sub.stack) |stack| {
                            print("│  {s}      📍 Stack trace:\n", .{cont});
                            var iter = std.mem.splitScalar(u8, stack, '\n');
                            while (iter.next()) |line| {
                                if (line.len > 0) {
                                    print("│  {s}         {s}\n", .{ cont, line });
                                }
                            }
                        }
                    }
                }
                print("│\n", .{});
            }
        }

        // Summary section
        print("\n", .{});
        print("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\n", .{});
        print("┃  📊 WPT TEST RESULTS                                                         ┃\n", .{});
        print("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\n", .{});
        print("\n", .{});

        // Test files section
        print("  📁 Test Files\n", .{});
        print("  ├── Total:     {d}\n", .{self.total});
        print("  ├── Completed: {d}\n", .{self.completed});
        print("  ├── Errors:    {d}\n", .{self.errors});
        print("  └── Timeouts:  {d}\n", .{self.timeouts});
        print("\n", .{});

        // Subtests section
        print("  🧪 Subtests\n", .{});
        if (total_subtests > 0) {
            const pass_rate = @as(f64, @floatFromInt(self.passed)) / @as(f64, @floatFromInt(total_subtests)) * 100.0;

            // Create a simple progress bar
            const bar_width: usize = 20;
            const filled = @as(usize, @intFromFloat(@as(f64, @floatFromInt(bar_width)) * pass_rate / 100.0));
            var bar_buf: [20]u8 = undefined;
            for (0..bar_width) |bi| {
                bar_buf[bi] = if (bi < filled) '#' else '-';
            }

            print("  ├── Progress:  [{s}] {d:.1}%\n", .{ bar_buf[0..bar_width], pass_rate });
            print("  ├── ✅ Passed:  {d}\n", .{self.passed});
            print("  ├── ❌ Failed:  {d}\n", .{self.failed});
            print("  ├── ⏰ Timeout: {d}\n", .{self.timeouts});
            if (self.notrun > 0) {
                print("  ├── ⚪ Not Run: {d}\n", .{self.notrun});
            }
            print("  └── Total:     {d}\n", .{total_subtests});
        } else {
            print("  └── No subtests executed\n", .{});
        }
        print("\n", .{});

        // Duration
        print("  ⏱️  Duration: {s}\n", .{elapsed});

        // Top failing categories
        if (self.failures_by_category.count() > 0) {
            print("\n  📉 Top Failing Categories\n", .{});

            // Collect and sort by failure count
            var iter = self.failures_by_category.iterator();
            var entries: [20]struct { cat: []const u8, count: usize } = undefined;
            var entry_count: usize = 0;
            while (iter.next()) |entry| {
                if (entry_count < 20) {
                    entries[entry_count] = .{ .cat = entry.key_ptr.*, .count = entry.value_ptr.* };
                    entry_count += 1;
                }
            }

            // Simple bubble sort (small array)
            var i: usize = 0;
            while (i < entry_count) : (i += 1) {
                var j: usize = i + 1;
                while (j < entry_count) : (j += 1) {
                    if (entries[j].count > entries[i].count) {
                        const tmp = entries[i];
                        entries[i] = entries[j];
                        entries[j] = tmp;
                    }
                }
            }

            // Print top 5
            const to_print = @min(entry_count, 5);
            for (entries[0..to_print], 0..) |entry, ei| {
                const prefix = if (ei == to_print - 1) "└" else "├";
                print("  {s}── {s}/: {d} failures\n", .{ prefix, entry.cat, entry.count });
            }
        }

        print("\n  📄 Results written to: {s}\n", .{output_path});
        print("\n", .{});
    }
};

/// Calculate the total number of test runs, accounting for multi-context execution.
/// Each test file may run multiple times if it specifies multiple globals.
/// Only counts contexts that are actually implemented (window, worker).
fn calculateTotalTests(
    allocator: std.mem.Allocator,
    discovery: DiscoveryResult,
    options: Options,
) !usize {
    var total: usize = 0;

    for (discovery.test_files.items) |test_file| {
        // Load and parse each test file to get its globals
        const content = loadTestContent(allocator, options, test_file) catch {
            // If we can't load the file, count it as 1 (will be an error)
            total += 1;
            continue;
        };
        defer allocator.free(content);

        var parsed = test_parser.parseTestFile(allocator, test_file.path, content) catch {
            // If we can't parse the file, count it as 1 (will be an error)
            total += 1;
            continue;
        };
        defer parsed.deinit();

        // Count only implemented contexts
        var context_count: usize = 0;
        for (parsed.metadata.globals.items) |ctx| {
            if (ctx.isImplemented()) {
                context_count += 1;
            }
        }

        // If no implemented contexts, we still count it as 1 (will skip execution)
        total += if (context_count > 0) context_count else 1;
    }

    return total;
}

/// Execute all discovered tests
pub fn executeTests(
    allocator: std.mem.Allocator,
    discovery: DiscoveryResult,
    options: Options,
    report: *result_reporter.WptReport,
    server: *wpt_server.WptServer,
) !void {
    // Calculate total accounting for multi-context execution
    // This requires parsing all files upfront, but gives accurate progress tracking
    const total = try calculateTotalTests(allocator, discovery, options);
    const file_count = discovery.test_files.items.len;
    print("\nRunning {d} test files ({d} total test runs)...\n\n", .{ file_count, total });

    // Create BrowserAdapter for tests. Following Chromium's approach:
    // - Single V8 isolate per browser instance
    // - New V8 context per test (navigation)
    // Context isolation is handled by the browser, not the test runner
    var browser = try browser_adapter.BrowserAdapter.init(allocator, options.wpt_root);
    defer browser.deinit();

    var progress = ProgressTracker.init(allocator, total, options.verbose);
    defer progress.deinit();

    // The journal is what lets a run survive a segfault: one record per test
    // file, written straight to the file descriptor as soon as the file is
    // done, so a supervisor can tell which test never reported.
    var run_journal: ?journal.Journal = if (options.journal_path) |p|
        try journal.Journal.append(allocator, p)
    else
        null;
    defer if (run_journal) |*j| j.deinit();

    for (discovery.test_files.items, 0..) |test_file, file_offset| {
        var tally: FileTally = .{ .index = discovery.base_index + file_offset };

        // Load content once per test file (still needed for parsing metadata)
        const content = loadTestContent(allocator, options, test_file) catch |err| {
            // Create error result for load failure
            var error_result = try test_harness.TestResult.init(allocator, test_file.path);
            error_result.status = .@"error";
            error_result.message = try std.fmt.allocPrint(allocator, "Failed to load test file: {}", .{err});

            progress.recordResult(test_file.path, error_result);
            progress.printProgress(test_file.path);

            try report.addResult(error_result);
            error_result.deinit(allocator);

            tally.status = .@"error";
            if (run_journal) |*j| try tally.record(j, test_file.path);
            continue;
        };
        defer allocator.free(content);

        // Parse once per test file (to get metadata like globals and timeout)
        var parsed = test_parser.parseTestFile(allocator, test_file.path, content) catch |err| {
            // Create error result for parse failure
            var error_result = try test_harness.TestResult.init(allocator, test_file.path);
            error_result.status = .@"error";
            error_result.message = try std.fmt.allocPrint(allocator, "Failed to parse test file: {}", .{err});

            progress.recordResult(test_file.path, error_result);
            progress.printProgress(test_file.path);

            try report.addResult(error_result);
            error_result.deinit(allocator);

            tally.status = .@"error";
            if (run_journal) |*j| try tally.record(j, test_file.path);
            continue;
        };
        defer parsed.deinit();

        // Load expected results metadata for this test (XFAIL support)
        var expected_results = result_reporter.loadExpectedResults(allocator, options.wpt_root, test_file.path) catch null;
        defer if (expected_results) |*e| e.deinit();

        // Execute for each global context specified in metadata
        // For .any.js files, this might be [window, worker]
        // For .window.js files, this will be [window]
        // For .worker.js files, this will be [worker]
        for (parsed.metadata.globals.items) |global_context| {
            // Skip unimplemented contexts (sharedworker, serviceworker, shadowrealm, etc.)
            if (!global_context.isImplemented()) {
                continue;
            }

            // Determine context name for multi-context tests
            // For .any.js tests with multiple globals, include context suffix
            // For single-context tests (.window.js, .worker.js), context is null
            const context_name: ?[]const u8 = if (parsed.metadata.globals.items.len > 1)
                global_context.toString()
            else
                null;

            // Execute test in this context
            const test_result = executeTestFileInContext(
                allocator,
                test_file,
                browser,
                global_context,
                &parsed,
                context_name,
                server,
            ) catch |err| {
                // Create error result with stack trace and context
                var error_result = try test_harness.TestResult.initWithContext(allocator, test_file.path, context_name);
                error_result.status = .@"error";

                // Capture and print full stack trace for debugging
                const trace = @errorReturnTrace();
                if (trace) |t| {
                    std.debug.print("\n=== ERROR in test: {s} ({s}) ===\n", .{ test_file.path, global_context.toString() });
                    std.debug.print("Error: {}\n", .{err});
                    std.debug.dumpStackTrace(t.*);
                    std.debug.print("=== END ERROR ===\n\n", .{});
                } else {
                    std.debug.print("\n=== ERROR in test: {s} ({s}) ===\n", .{ test_file.path, global_context.toString() });
                    std.debug.print("Error: {} (no stack trace available)\n", .{err});
                    std.debug.print("=== END ERROR ===\n\n", .{});
                }

                error_result.message = try std.fmt.allocPrint(allocator, "Execution error in {s} context: {}", .{ global_context.toString(), err });

                // Record with expected status so expected-fail tests don't increment error count
                if (expected_results) |*exp| {
                    progress.recordResultWithExpected(test_file.path, error_result, exp);
                } else {
                    progress.recordResult(test_file.path, error_result);
                }
                progress.printProgressWithContext(test_file.path, context_name);

                try report.addResult(error_result);
                tally.add(error_result);
                error_result.deinit(allocator);
                continue;
            };

            // Record result with expected status metadata for proper counting
            if (expected_results) |*exp| {
                progress.recordResultWithExpected(test_file.path, test_result, exp);
            } else {
                progress.recordResult(test_file.path, test_result);
            }
            progress.printProgressWithContext(test_file.path, context_name);

            // Add result with expected status metadata (for XFAIL tracking)
            if (expected_results) |*exp| {
                try report.addResultWithExpected(test_result, exp);
            } else {
                try report.addResult(test_result);
            }

            tally.add(test_result);

            // Clean up the test result (addResult copies the data)
            var mutable_result = test_result;
            mutable_result.deinit(allocator);
        }

        // Every context of this file reported, so the file is done. Journal it
        // before starting the next one: anything after this point that kills
        // the process must not be blamed on this test.
        if (run_journal) |*j| try tally.record(j, test_file.path);

        // Reset HTTP connection pool between test files to prevent connection exhaustion
        // This ensures each test file starts with a fresh connection pool
        const fetch_mod = @import("fetch");
        fetch_mod.network.resetGlobalPool();
    }

    // Generate output path
    const output_path = try options.reportPath(allocator);
    defer allocator.free(output_path);

    progress.printSummary(output_path);
}

/// Per-file totals accumulated across the contexts a test file runs in.
///
/// The journal records one line per *file*, not per context. A context is not a
/// resumable unit: a supervisor can only restart at a file boundary, so a
/// half-finished file has to look unfinished, which means no record until every
/// context of it has reported.
const FileTally = struct {
    index: usize,
    status: journal.Status = .ok,
    passed: usize = 0,
    failed: usize = 0,
    timed_out: usize = 0,
    notrun: usize = 0,
    duration_ms: u64 = 0,
    contexts: usize = 0,

    fn add(self: *FileTally, result: test_harness.TestResult) void {
        self.contexts += 1;
        self.duration_ms += result.duration_ms;

        // Worst status across contexts wins - a file that errored in one global
        // has not passed, however well it did in the others.
        const status: journal.Status = switch (result.status) {
            .ok => .ok,
            .timeout => .timeout,
            else => .@"error",
        };
        if (status.severity() > self.status.severity()) self.status = status;

        for (result.subtests.items) |sub| {
            switch (sub.status) {
                .pass => self.passed += 1,
                .fail, .precondition_failed => self.failed += 1,
                .timeout => self.timed_out += 1,
                .notrun => self.notrun += 1,
            }
        }
    }

    fn record(self: *const FileTally, j: *journal.Journal, path: []const u8) !void {
        try j.record(.{
            .index = self.index,
            .path = path,
            .status = self.status,
            .passed = self.passed,
            .failed = self.failed,
            .timed_out = self.timed_out,
            .notrun = self.notrun,
            .duration_ms = self.duration_ms,
        });
    }
};

/// Execute a single test file in a specific context using the shared BrowserAdapter
/// This function is called once per context (e.g., window, worker) for each test file.
/// File content and parsed metadata are passed in to avoid re-loading/re-parsing.
/// context_name is the string to include in results (null for single-context tests).
fn executeTestFileInContext(
    allocator: std.mem.Allocator,
    test_file: TestFile,
    browser: *browser_adapter.BrowserAdapter,
    context: test_parser.GlobalType,
    parsed: *test_parser.ParsedTest,
    context_name: ?[]const u8,
    server: *wpt_server.WptServer,
) !test_harness.TestResult {
    // For HTML files, fetch from HTTP server and let the browser handle it properly
    // This enables proper resource loading via wpt serve (URL rewrites, headers, etc.)
    if (test_file.file_type == .html) {
        // Build HTTP URL for this test
        const test_url = try server.buildTestUrl(allocator, test_file.path, .window);
        defer allocator.free(test_url);

        // Fetch and run from HTTP URL
        // The wpt serve handles proper resource serving (testharness.js, etc.)
        var result = try browser.runTestFromUrl(test_url, test_file.path, parsed.metadata.timeout, .window);

        // HTML tests are single-context, so context_name should be null
        // But if it's provided (shouldn't happen), we need to set it
        if (context_name) |ctx| {
            result.context = try allocator.dupe(u8, ctx);
        }
        return result;
    }

    // For JS files (.any.js, .window.js, .worker.js), fetch from HTTP server
    // The wpt serve generates proper HTML wrappers (e.g., test.any.html) that:
    // 1. Include testharness.js and testharnessreport.js
    // 2. Handle META: script directives automatically
    // 3. Apply URL rewrites (WebIDLParser.js -> webidl2.js, etc.)
    // This is the correct browser-like behavior
    const test_url = try server.buildTestUrl(allocator, test_file.path, context);
    defer allocator.free(test_url);

    // Fetch and run from HTTP URL
    var result = try browser.runTestFromUrl(test_url, test_file.path, parsed.metadata.timeout, context);

    // Set the context name for multi-context tests
    if (context_name) |ctx| {
        result.context = try allocator.dupe(u8, ctx);
    }

    return result;
}

/// Load test file content from disk
fn loadTestContent(allocator: std.mem.Allocator, options: Options, test_file: TestFile) ![]u8 {
    const full_path = try std.fs.path.join(allocator, &.{ options.wpt_root, test_file.path });
    defer allocator.free(full_path);

    return try std.fs.cwd().readFileAlloc(allocator, full_path, 10 * 1024 * 1024);
}

/// Output helper - uses std.debug.print for standalone compatibility
/// TODO: When integrated with build.zig, use proper std.io.getStdOut()
fn print(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

/// Main entry point
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command-line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var options = try parseArgs(allocator, args[1..]);
    defer options.deinit();

    // Set verbose mode for log filtering
    verbose_mode = options.verbose;

    // Check WPT submodule exists
    const harness_path = try std.fs.path.join(allocator, &.{ options.wpt_root, "resources", "testharness.js" });
    defer allocator.free(harness_path);

    std.fs.cwd().access(harness_path, .{}) catch {
        print("Error: WPT submodule not found.\n", .{});
        print("Please initialize the submodule with:\n", .{});
        print("  git submodule update --init tests/wpt\n", .{});
        return error.WptNotFound;
    };

    // Discover tests
    print("Discovering tests...\n", .{});
    var discovery = try discoverTests(allocator, options);
    defer discovery.deinit();

    print("Found {d} test files in {d} directories\n", .{ discovery.test_files.items.len, discovery.directories_scanned });

    if (discovery.total_manifest_urls > 0) {
        const pct = 100.0 * @as(f64, @floatFromInt(discovery.total_in_scope_urls)) /
            @as(f64, @floatFromInt(discovery.total_manifest_urls));
        print("Scope: {d} of {d} testharness URLs ({d:.1}%), across {d} source files\n", .{
            discovery.total_in_scope_urls,
            discovery.total_manifest_urls,
            pct,
            discovery.test_files.items.len,
        });
        if (discovery.missing_sources > 0) {
            print("  ({d} manifest sources absent from this checkout)\n", .{discovery.missing_sources});
        }
    }

    if (discovery.test_files.items.len == 0) {
        print("No tests found. Check your filter paths.\n", .{});
        if (discovery.skipped.items.len > 0) {
            print("Skipped {d} items.\n", .{discovery.skipped.items.len});
        }
        return;
    }

    // Print breakdown by type
    print("\nBy file type:\n", .{});
    var type_iter = discovery.by_type.iterator();
    while (type_iter.next()) |entry| {
        const type_name = switch (entry.key_ptr.*) {
            .html => ".html",
            .any_js => ".any.js",
            .window_js => ".window.js",
            .worker_js => ".worker.js",
            .unknown => "unknown",
        };
        print("  {s}: {d}\n", .{ type_name, entry.value_ptr.* });
    }

    // Print breakdown by category
    print("\nBy category:\n", .{});
    var cat_iter = discovery.by_category.iterator();
    while (cat_iter.next()) |entry| {
        print("  {s}/: {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    if (discovery.skipped.items.len > 0) {
        print("\nSkipped {d} items\n", .{discovery.skipped.items.len});
    }

    if (options.worklist_out) |path| {
        try writeWorklistFile(allocator, path, discovery);
        print("\nWrote {d} paths to {s}\n", .{ discovery.test_files.items.len, path });
    }

    if (options.discover_only) {
        print("\n--discover-only: stopping before execution.\n", .{});
        return;
    }

    if (options.supervise) {
        return supervise(allocator, options, discovery);
    }

    // Create report
    var report = result_reporter.WptReport.init(allocator);
    defer report.deinit();

    // Start WPT server (provides URL rewrites and proper resource serving)
    print("\nStarting wpt serve...\n", .{});
    const server = try wpt_server.WptServer.init(allocator, options.wpt_root);
    defer server.deinit();
    try server.start();
    print("WPT server running at {s}\n", .{server.getBaseUrl()});

    // Execute tests (prints progress and summary)
    try executeTests(allocator, discovery, options, &report, server);

    // Clean up global storage resources
    const storage = @import("storage");
    storage.deinitGlobalStorageShed(allocator);

    // Clean up global blob URL store
    const file_mod = @import("file");
    file_mod.deinitGlobalBlobURLStore(allocator);

    // Clean up timer backend
    const platform_mod = @import("platform");
    platform_mod.timer_backend.deinitDefault();

    // Clean up global HTTP connection pool
    const fetch_mod = @import("fetch");
    fetch_mod.network.cleanupGlobalPool();

    // Finish and write report
    report.finish();

    const output_path = try options.reportPath(allocator);
    defer allocator.free(output_path);

    try report.writeToFile(output_path);
}

/// Write the discovered sources as a worklist file.
fn writeWorklistFile(
    allocator: std.mem.Allocator,
    path: []const u8,
    discovery: DiscoveryResult,
) !void {
    if (std.fs.path.dirname(path)) |dir| {
        std.fs.cwd().makePath(dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
    }

    var paths = try allocator.alloc([]const u8, discovery.test_files.items.len);
    defer allocator.free(paths);
    for (discovery.test_files.items, 0..) |tf, i| paths[i] = tf.path;

    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    var buf: [4096]u8 = undefined;
    var file_writer = file.writer(&buf);
    try selection.writeWorklist(&file_writer.interface, paths);
    try file_writer.interface.flush();
}

/// Run the whole worklist, restarting past anything that kills the process.
///
/// The runner executes every test in one process against one V8 isolate, so a
/// segfault anywhere ends the run. Without this, a single crashing test makes a
/// full-corpus number impossible to obtain - not "hard to obtain", impossible,
/// because the process never reaches the point where it writes a report.
///
/// Each iteration spawns this same binary over a slice of the worklist. When a
/// child dies abnormally, the journal's `nextIndex()` is by construction the
/// index of the test that never reported: every earlier test wrote a record
/// before the next one started. That index gets a CRASH record and the next
/// child starts one past it, so the loop always advances.
fn supervise(
    allocator: std.mem.Allocator,
    options: Options,
    discovery: DiscoveryResult,
) !void {
    const total = discovery.test_files.items.len;
    if (total == 0) return;

    std.fs.cwd().makePath(options.output_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    const worklist_path = try std.fs.path.join(allocator, &.{ options.output_dir, "worklist.txt" });
    defer allocator.free(worklist_path);
    try writeWorklistFile(allocator, worklist_path, discovery);

    const journal_path = try std.fs.path.join(allocator, &.{ options.output_dir, "journal.jsonl" });
    defer allocator.free(journal_path);

    // Start from an empty ledger. Resuming an old journal against a worklist
    // that may have been regenerated would resume at meaningless indices.
    {
        var fresh = try journal.Journal.create(allocator, journal_path);
        fresh.deinit();
    }

    const self_exe = try std.fs.selfExePathAlloc(allocator);
    defer allocator.free(self_exe);

    print("\nSupervising {d} test files\n", .{total});
    print("  worklist: {s}\n", .{worklist_path});
    print("  journal:  {s}\n\n", .{journal_path});

    var attempt: usize = 0;

    while (true) {
        // Each restart consumes exactly one worklist entry, so this can only
        // spin as many times as there are tests. The bound is a backstop
        // against a bug in that reasoning, not part of the design.
        attempt += 1;
        if (attempt > total + 1) {
            print("Supervisor: giving up after {d} restarts\n", .{attempt - 1});
            break;
        }

        var log = try journal.read(allocator, journal_path);
        const next = log.nextIndex();
        log.deinit();

        if (next >= total) break;

        const start_arg = try std.fmt.allocPrint(allocator, "--start-index={d}", .{next});
        defer allocator.free(start_arg);
        const from_arg = try std.fmt.allocPrint(allocator, "--from-file={s}", .{worklist_path});
        defer allocator.free(from_arg);
        const journal_arg = try std.fmt.allocPrint(allocator, "--journal={s}", .{journal_path});
        defer allocator.free(journal_arg);
        const root_arg = try std.fmt.allocPrint(allocator, "--wpt-root={s}", .{options.wpt_root});
        defer allocator.free(root_arg);
        const out_arg = try std.fmt.allocPrint(allocator, "--output={s}", .{options.output_dir});
        defer allocator.free(out_arg);

        var argv: std.ArrayList([]const u8) = .{};
        defer argv.deinit(allocator);
        try argv.appendSlice(allocator, &.{ self_exe, from_arg, start_arg, journal_arg, root_arg, out_arg });
        if (!options.verbose) try argv.append(allocator, "--quiet");

        print("--> running tests {d}..{d}\n", .{ next, total });

        var child = std.process.Child.init(argv.items, allocator);
        const term = try child.spawnAndWait();

        const clean = switch (term) {
            .Exited => |code| code == 0,
            else => false,
        };
        if (clean) {
            // A clean exit that did not finish the worklist means the child
            // stopped for a reason of its own. Looping again would either
            // repeat that or spin, so stop and let the journal speak.
            var after = try journal.read(allocator, journal_path);
            defer after.deinit();
            if (after.nextIndex() >= total) break;
            if (after.nextIndex() <= next) {
                print("Supervisor: child exited cleanly without running anything; stopping\n", .{});
                break;
            }
            continue;
        }

        // Abnormal exit. Everything before the crashing test wrote its record,
        // so the first unreported index is the culprit.
        var after = try journal.read(allocator, journal_path);
        const crashed = after.nextIndex();
        after.deinit();

        if (crashed >= total) break;

        const path = discovery.test_files.items[crashed].path;
        print("\n!!! crashed on [{d}] {s} ({any})\n\n", .{ crashed, path, term });

        var j = try journal.Journal.append(allocator, journal_path);
        defer j.deinit();
        const message = try std.fmt.allocPrint(allocator, "process terminated: {any}", .{term});
        defer allocator.free(message);
        try j.record(.{
            .index = crashed,
            .path = path,
            .status = .crash,
            .message = message,
        });
    }

    var log = try journal.read(allocator, journal_path);
    defer log.deinit();
    const s = log.summarize();

    print("\n=== Run complete ===\n", .{});
    print("Files:    {d} of {d} journalled\n", .{ log.records.len, total });
    print("  ok:      {d}\n", .{s.ok});
    print("  error:   {d}\n", .{s.errored});
    print("  timeout: {d}\n", .{s.timed_out});
    print("  crash:   {d}\n", .{s.crashed});
    print("Subtests: {d} passed, {d} failed, {d} timed out, {d} not run\n", .{
        s.subtests_passed,
        s.subtests_failed,
        s.subtests_timed_out,
        s.subtests_notrun,
    });
    print("\nJournal: {s}\n", .{journal_path});
}

// The tests below never run: main.zig is only ever built as an executable, so
// Zig neither compiles nor executes its test blocks. The argument-parsing,
// discovery and filtering tests that used to sit here now live in options.zig
// and discovery.zig, which `zig build test` does run. What remains covers the
// V8-dependent execution path and is kept until it can be given a home that
// runs too.
test "multi-context: TestResult can hold context information" {
    const allocator = std.testing.allocator;

    // Test that TestResult can be initialized with context
    var result = try test_harness.TestResult.initWithContext(allocator, "test.any.js", "worker");
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("worker", result.context.?);
    try std.testing.expectEqualStrings("test.any.js", result.test_path);
}

test "multi-context: TestResult display name includes context" {
    const allocator = std.testing.allocator;

    // Test with context
    {
        var result = try test_harness.TestResult.initWithContext(allocator, "url/test.any.js", "worker");
        defer result.deinit(allocator);

        const display_name = try result.getDisplayName(allocator);
        defer allocator.free(display_name);

        try std.testing.expectEqualStrings("url/test.any.js [worker]", display_name);
    }

    // Test without context (single-context test)
    {
        var result = try test_harness.TestResult.init(allocator, "url/test.window.js");
        defer result.deinit(allocator);

        const display_name = try result.getDisplayName(allocator);
        defer allocator.free(display_name);

        try std.testing.expectEqualStrings("url/test.window.js", display_name);
    }
}

test "multi-context: parsing and context iteration integration" {
    const allocator = std.testing.allocator;

    // Parse a multi-context test file
    const content =
        \\// META: global=window,worker,sharedworker
        \\test(() => { assert_true(true); });
    ;

    var parsed = try test_parser.parseTestFile(allocator, "encoding/test.any.js", content);
    defer parsed.deinit();

    // Simulate the execution loop that would run in each context
    var results: std.ArrayListUnmanaged(test_harness.TestResult) = .{};
    defer {
        for (results.items) |*r| r.deinit(allocator);
        results.deinit(allocator);
    }

    for (parsed.metadata.globals.items) |ctx| {
        if (ctx.isImplemented()) {
            // Create a result for this context
            var result = try test_harness.TestResult.initWithContext(
                allocator,
                parsed.path,
                ctx.toString(),
            );
            result.status = .ok;
            try results.append(allocator, result);
        }
    }

    // Should have 1 result (only window is implemented, worker/sharedworker are not)
    try std.testing.expectEqual(@as(usize, 1), results.items.len);

    // Verify contexts
    try std.testing.expectEqualStrings("window", results.items[0].context.?);
}

test "multi-context: GlobalType iteration for test execution" {
    // Test that we can iterate over parsed globals and filter by implementation status
    const globals = [_]test_parser.GlobalType{
        .window,
        .worker,
        .sharedworker,
        .serviceworker,
        .shadowrealm,
    };

    var implemented_count: usize = 0;
    var skipped_count: usize = 0;

    for (globals) |g| {
        if (g.isImplemented()) {
            implemented_count += 1;
        } else {
            skipped_count += 1;
        }
    }

    // only window is implemented (worker disabled due to missing fetch_tests_from_worker)
    try std.testing.expectEqual(@as(usize, 1), implemented_count);
    // worker, sharedworker, serviceworker, shadowrealm are not implemented
    try std.testing.expectEqual(@as(usize, 4), skipped_count);
}

test "multi-context: result collection per context" {
    const allocator = std.testing.allocator;

    // Simulate collecting results from multiple context executions
    var collector = test_harness.ResultCollector.init(allocator);
    defer collector.deinit();

    // Simulate window context execution
    try collector.startTest("test.any.js [window]");
    try collector.addResult(test_harness.SubtestResult{
        .name = try allocator.dupe(u8, "basic test"),
        .status = .pass,
        .duration_ms = 5,
    });
    try collector.finishTest(.ok, null, 10);

    // Simulate worker context execution
    try collector.startTest("test.any.js [worker]");
    try collector.addResult(test_harness.SubtestResult{
        .name = try allocator.dupe(u8, "basic test"),
        .status = .pass,
        .duration_ms = 8,
    });
    try collector.finishTest(.ok, null, 15);

    // Should have 2 test results (one per context)
    try std.testing.expectEqual(@as(usize, 2), collector.results.items.len);

    // Both should pass
    const totals = collector.getTotals();
    try std.testing.expectEqual(@as(usize, 2), totals.passed);
    try std.testing.expectEqual(@as(usize, 0), totals.failed);
}

test "calculateTotalTests counts implemented contexts" {
    // This test verifies that calculateTotalTests correctly counts
    // the total number of test executions (not files) when accounting
    // for multi-context execution.

    // Test the counting logic directly:
    // - .any.js with no META: defaults to window + worker, but only window is implemented = 1
    // - .any.js with global=window: explicit window = 1
    // - .any.js with global=window,worker: only window is implemented = 1
    // - .any.js with global=window,worker,sharedworker: only window is implemented = 1
    // - .window.js: always window = 1
    // - .worker.js: always worker = 0 (worker not implemented)

    const allocator = std.testing.allocator;

    // Test case 1: .any.js with no META defaults to window+worker, but only window implemented
    {
        const content = "test(() => {});";
        var parsed = try test_parser.parseTestFile(allocator, "test.any.js", content);
        defer parsed.deinit();

        var implemented_count: usize = 0;
        for (parsed.metadata.globals.items) |ctx| {
            if (ctx.isImplemented()) implemented_count += 1;
        }
        try std.testing.expectEqual(@as(usize, 1), implemented_count);
    }

    // Test case 2: explicit single context
    {
        const content =
            \\// META: global=window
            \\test(() => {});
        ;
        var parsed = try test_parser.parseTestFile(allocator, "test.any.js", content);
        defer parsed.deinit();

        var implemented_count: usize = 0;
        for (parsed.metadata.globals.items) |ctx| {
            if (ctx.isImplemented()) implemented_count += 1;
        }
        try std.testing.expectEqual(@as(usize, 1), implemented_count);
    }

    // Test case 3: mix of implemented and unimplemented contexts
    {
        const content =
            \\// META: global=window,worker,sharedworker,serviceworker
            \\test(() => {});
        ;
        var parsed = try test_parser.parseTestFile(allocator, "test.any.js", content);
        defer parsed.deinit();

        var implemented_count: usize = 0;
        for (parsed.metadata.globals.items) |ctx| {
            if (ctx.isImplemented()) implemented_count += 1;
        }
        // only window is implemented (worker, sharedworker, serviceworker are not)
        try std.testing.expectEqual(@as(usize, 1), implemented_count);
    }

    // Test case 4: .window.js forces window only
    {
        const content =
            \\// META: global=worker
            \\test(() => {});
        ;
        var parsed = try test_parser.parseTestFile(allocator, "test.window.js", content);
        defer parsed.deinit();

        var implemented_count: usize = 0;
        for (parsed.metadata.globals.items) |ctx| {
            if (ctx.isImplemented()) implemented_count += 1;
        }
        try std.testing.expectEqual(@as(usize, 1), implemented_count);
        try std.testing.expectEqual(test_parser.GlobalType.window, parsed.metadata.globals.items[0]);
    }

    // Test case 5: .worker.js forces worker only (but worker is not implemented)
    {
        const content = "test(() => {});";
        var parsed = try test_parser.parseTestFile(allocator, "test.worker.js", content);
        defer parsed.deinit();

        var implemented_count: usize = 0;
        for (parsed.metadata.globals.items) |ctx| {
            if (ctx.isImplemented()) implemented_count += 1;
        }
        // Worker is not implemented, so 0 contexts will execute
        try std.testing.expectEqual(@as(usize, 0), implemented_count);
        try std.testing.expectEqual(test_parser.GlobalType.worker, parsed.metadata.globals.items[0]);
    }
}
