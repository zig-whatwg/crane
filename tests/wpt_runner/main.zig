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
//! Regression gating:
//! - `--baseline=path` - Compare the finished run against recorded
//!   expectations. Exits nonzero if anything regressed.
//! - `--update-baseline` - Rewrite that file from this run instead.
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
const baseline = @import("baseline.zig");
const options_mod = @import("options.zig");
const discovery_mod = @import("discovery.zig");
const output = @import("output.zig");
const stall_watchdog = @import("stall_watchdog.zig");
const wpt_options = @import("wpt_options");
const clock = @import("clock");
const host = @import("host");
/// Phase 5 measuring instrument. The runner both reports its process-wide totals
/// at the end and writes per-file deltas into the journal, so a sharded run can
/// be added back up by the supervisor.
const isolate_ownership = @import("v8").isolate_ownership;

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
            .start_time = clock.monotonicMillis(),
            .verbose = verbose,
            .failures_by_category = std.StringHashMap(usize).init(allocator),
            .failure_details = .empty,
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
        var failure_subtests: std.ArrayList(FailureDetail.SubtestFailure) = .empty;

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

        // One test file is the unit of crash recovery in this runner - the
        // journal restarts at a file boundary - so it is also the point at
        // which buffered output has to become visible. A segfault in the next
        // file cannot then swallow the report for this one.
        flushOutput();
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

        // This bar rewrites one line with \r and is the only output in quiet
        // mode, so it has to reach the terminal as it is written. It is one
        // flush per test file, not per subtest, which is the cost this module
        // was buffered to avoid.
        flushOutput();
    }

    pub fn getElapsedTime(self: *ProgressTracker) []const u8 {
        const elapsed_ms: u64 = @intCast(clock.monotonicMillis() - self.start_time);
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

        // Isolate ownership (Phase 5). Reported as violations/checks rather than
        // violations alone: 0 violations out of 0 checks means the instrument never
        // ran, which is NOT the same as the invariant holding, and the two are
        // indistinguishable if only violations are shown.
        if (isolate_ownership.mode != .off) {
            const v = isolate_ownership.violations();
            const c = isolate_ownership.checks();
            if (c == 0) {
                print("  🔒 Isolate ownership: not measured (0 checks ran)\n", .{});
            } else {
                print("  🔒 Isolate ownership: {d} violation(s) in {d} checks\n", .{ v, c });
            }
        }

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

/// Calculate the total number of test runs, accounting for multi-context and
/// multi-variant execution.
///
/// A test file may run several times: once per implemented global it declares,
/// times once per `<meta name="variant">` it declares. Only contexts that are
/// actually implemented (window, worker) are counted, because the unimplemented
/// ones are skipped rather than run - counting them would leave the progress
/// bar short of its own total on every multi-global file.
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

        // Once per implemented context, times once per declared variant. The
        // rule lives on the metadata so it can be tested against the same
        // parser the execution loop runs on; see `TestMetadata.runCount`.
        total += parsed.metadata.runCount();
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
    // Calculate total accounting for multi-context and multi-variant execution.
    // This requires parsing all files upfront, but gives accurate progress
    // tracking - and it is what makes this number comparable to the "Scope:"
    // line printed above it, which counts manifest URLs.
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
    // done, so a supervisor can tell which test never reported. A supervised
    // child joins the ledger already in progress; anyone else starts a fresh
    // one, so a baseline comparison reads this run and not the last one too.
    const journal_path = try options.journalPath(allocator);
    defer if (journal_path) |p| allocator.free(p);
    var run_journal: ?journal.Journal = if (journal_path) |p|
        if (options.appendsToJournal())
            try journal.Journal.append(allocator, p)
        else
            try journal.Journal.create(allocator, p)
    else
        null;
    defer if (run_journal) |*j| j.deinit();

    for (discovery.test_files.items, 0..) |test_file, file_offset| {
        var tally: FileTally = FileTally.start();
        tally.index = discovery.base_index + file_offset;

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

            // ...and once per variant within each of them. The two axes
            // multiply, and MANIFEST.json lists every combination as its own
            // test URL, so this loop is what makes the runner's numerator count
            // in the same unit as the scoreboard's denominator. A file with no
            // variants iterates exactly once, over a single empty string.
            for (parsed.metadata.variantsOrDefault()) |variant| {
                // How this run is named in the results. Owned rather than
                // borrowed: a run told apart by both axes at once has no static
                // string to point at.
                const context_name: ?[]const u8 = try test_parser.runLabel(
                    allocator,
                    global_context,
                    parsed.metadata.globals.items.len,
                    variant,
                );
                defer if (context_name) |n| allocator.free(n);

                // Execute test in this context
                const test_result = executeTestFileInContext(
                    allocator,
                    test_file,
                    browser,
                    global_context,
                    &parsed,
                    context_name,
                    variant,
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
                        // 0.16 split the two StackTrace types: @errorReturnTrace()
                        // yields std.builtin.StackTrace {index, instruction_addresses}
                        // while dumpStackTrace now takes *const std.debug.StackTrace
                        // {return_addresses, skipped}. Convert rather than cast - the
                        // valid entries are instruction_addresses[0..index], and index
                        // exceeding the buffer means the trace wrapped.
                        const valid = @min(t.index, t.instruction_addresses.len);
                        const dbg_trace: std.debug.StackTrace = .{
                            .return_addresses = t.instruction_addresses[0..valid],
                            .skipped = @enumFromInt(t.index - valid),
                        };
                        std.debug.dumpStackTrace(&dbg_trace);
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
        }

        // Every run of this file reported - every global, times every variant -
        // so the file is done. Journal it before starting the next one:
        // anything after this point that kills the process must not be blamed
        // on this test.
        if (run_journal) |*j| try tally.record(j, test_file.path);

        // Reset HTTP connection pool between test files to prevent connection exhaustion
        // This ensures each test file starts with a fresh connection pool
        const fetch_mod = @import("fetch");
        fetch_mod.network.resetGlobalPool();
    }

    // Generate output path
    const output_path = try options.reportPath(allocator);
    defer allocator.free(output_path);

    // Write the report NOW, before this function's deferred `browser.deinit()`
    // runs. Browser teardown sweeps every DOM registry and can crash on its own
    // - custom-elements/connected-callbacks.html died in that sweep after all
    // its tests had run - and `run()` only writes the report after we return,
    // so a teardown crash used to erase a finished run and leave "NO REPORT"
    // in its place. `finish()` just stamps time_end and `run()`'s later write
    // overwrites this file with the same results, so writing twice is safe.
    report.finish();
    report.writeToFile(output_path) catch |err| {
        print("warning: could not write early report to {s}: {}\n", .{ output_path, err });
    };

    progress.printSummary(output_path);
}

/// Per-file totals accumulated across the runs a test file fans out into - one
/// per implemented global, times one per declared variant.
///
/// The journal records one line per *file*, not per run. Neither a global nor a
/// variant is a resumable unit: a supervisor can only restart at a file
/// boundary, so a half-finished file has to look unfinished, which means no
/// record until every run of it has reported.
const FileTally = struct {
    index: usize,
    status: journal.Status = .ok,
    passed: usize = 0,
    failed: usize = 0,
    timed_out: usize = 0,
    notrun: usize = 0,
    duration_ms: u64 = 0,
    nav_ms: u64 = 0,
    load_ms: u64 = 0,
    /// How many (global, variant) pairs reported into this tally.
    runs: usize = 0,
    /// Wall clock across everything this file cost, started at the top of the
    /// loop so loading and parsing are inside it. `duration_ms` cannot serve
    /// this purpose: it only covers the wait for `__wpt_complete`, and a page
    /// whose subtests are synchronous has already run them all before that wait
    /// begins - so the most expensive files in the corpus score near zero on it.
    timer: ?clock.Timer = null,

    /// Phase 5 isolate-ownership counters as they stood BEFORE this file ran.
    ///
    /// The instrument's counters are process-global and monotonic, so the number
    /// belonging to one file is a delta. Snapshotting here rather than resetting
    /// keeps the running total intact for `printSummary`, which reports the whole
    /// process - both readings come from the same source and cannot disagree.
    ownership_checks_at_start: usize = 0,
    ownership_violations_at_start: usize = 0,

    fn start() FileTally {
        return .{
            .index = 0,
            .timer = clock.Timer.start(),
            .ownership_checks_at_start = isolate_ownership.checks(),
            .ownership_violations_at_start = isolate_ownership.violations(),
        };
    }

    fn wallMs(self: *const FileTally) u64 {
        var t = self.timer orelse return 0;
        return t.read() / std.time.ns_per_ms;
    }

    fn add(self: *FileTally, result: test_harness.TestResult) void {
        self.runs += 1;
        self.duration_ms += result.duration_ms;
        self.nav_ms += result.nav_ms;
        self.load_ms += result.load_ms;

        // Worst status across runs wins - a file that errored in one global or
        // one variant has not passed, however well it did in the others.
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
            .nav_ms = self.nav_ms,
            .load_ms = self.load_ms,
            .wall_ms = self.wallMs(),
            .ownership_checks = isolate_ownership.checks() -| self.ownership_checks_at_start,
            .ownership_violations = isolate_ownership.violations() -| self.ownership_violations_at_start,
        });
    }
};

/// Execute a single test file in a specific context and variant using the shared
/// BrowserAdapter.
///
/// This function is called once per (context, variant) pair for each test file -
/// e.g. window and worker, times each `<meta name="variant">` the file declares.
/// File content and parsed metadata are passed in to avoid re-loading/re-parsing.
/// context_name is the string to include in results (null when the file runs
/// only once and there is nothing to tell apart); `variant` goes into the URL,
/// not into `test_path`, which stays the bare source path everything else keys
/// off.
fn executeTestFileInContext(
    allocator: std.mem.Allocator,
    test_file: TestFile,
    browser: *browser_adapter.BrowserAdapter,
    context: test_parser.GlobalType,
    parsed: *test_parser.ParsedTest,
    context_name: ?[]const u8,
    variant: []const u8,
    server: *wpt_server.WptServer,
) !test_harness.TestResult {
    // For HTML files, fetch from HTTP server and let the browser handle it properly
    // This enables proper resource loading via wpt serve (URL rewrites, headers, etc.)
    if (test_file.file_type == .html) {
        // Build HTTP URL for this test
        const test_url = try server.buildTestUrl(allocator, test_file.path, .window, variant);
        defer allocator.free(test_url);

        // Fetch and run from HTTP URL
        // The wpt serve handles proper resource serving (testharness.js, etc.)
        var result = try browser.runTestFromUrl(test_url, test_file.path, parsed.metadata.timeout, .window);

        // HTML tests have a single global, so context_name is set only when the
        // file declares variants - the label is then the variant alone.
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
    const test_url = try server.buildTestUrl(allocator, test_file.path, context, variant);
    defer allocator.free(test_url);

    // Fetch and run from HTTP URL
    var result = try browser.runTestFromUrl(test_url, test_file.path, parsed.metadata.timeout, context);

    // Set the label for tests that run more than once
    if (context_name) |ctx| {
        result.context = try allocator.dupe(u8, ctx);
    }

    return result;
}

/// Load test file content from disk
fn loadTestContent(allocator: std.mem.Allocator, options: Options, test_file: TestFile) ![]u8 {
    const full_path = try std.fs.path.join(allocator, &.{ options.wpt_root, test_file.path });
    defer allocator.free(full_path);

    return try host.cwd().readFileAlloc(host.io(), full_path, allocator, .limited(10 * 1024 * 1024));
}

/// Buffer behind `print`. Sized to hold a heavy test file's worth of subtest
/// lines - `encoding/legacy-mb-korean/euckr-encode-href-errors-han.html` alone
/// emits about 11,000 - so a whole file usually drains in a handful of writes
/// rather than one per line. See output.zig for the measurements.
var stderr_buffer: [256 * 1024]u8 = undefined;
var stderr_writer: std.Io.File.Writer = undefined;
var stderr_sink: output.Sink = undefined;

/// One-shot initialisation of `stderr_sink`.
///
/// Zig 0.16 removed `std.once`, so this open-codes the same contract: the
/// winner of the compare-and-swap runs `initStderrSink`, and every other caller
/// blocks until it is `done` rather than reading a half-built sink. A plain
/// bool would not do - `print` is reached from V8's worker threads as well as
/// the runner's main loop. `std.Io.Mutex` would not do either, because this can
/// run before the process `Io` is up.
const OnceState = enum(u8) { uninitialized, initializing, done };
var stderr_state: std.atomic.Value(OnceState) = .init(.uninitialized);

fn initStderrSink() void {
    stderr_writer = std.Io.File.stderr().writer(host.io(), &stderr_buffer);
    stderr_sink = .{ .w = &stderr_writer.interface };
}

fn sink() *output.Sink {
    if (stderr_state.load(.acquire) != .done) {
        if (stderr_state.cmpxchgStrong(.uninitialized, .initializing, .acq_rel, .acquire) == null) {
            initStderrSink();
            stderr_state.store(.done, .release);
        } else {
            while (stderr_state.load(.acquire) != .done) std.atomic.spinLoopHint();
        }
    }
    return &stderr_sink;
}

/// Output helper. Buffered, so a subtest line costs a memcpy rather than a
/// syscall; `flushOutput` marks the points where that buffer has to reach the
/// terminal - after each test file, and before anything that could end the
/// process. Diagnostics that must survive a crash belong in journal.zig, which
/// writes straight through for exactly that reason.
fn print(comptime fmt: []const u8, args: anytype) void {
    sink().print(fmt, args);
}

/// Pushes buffered output to stderr.
fn flushOutput() void {
    sink().flush();
}

/// Main entry point.
///
/// A regression has to make the process exit nonzero - that is the whole point
/// of a baseline, and it is what lets a CI job go red. Returning an error from
/// main would do it too, but it would print a stack trace, and a run that
/// correctly detected a regression is not a crash.
pub fn main(init: std.process.Init) !void {
    // Adopt the Io std.start already built rather than letting host.io() build a
    // second one. A self-built Io.Threaded starts with an EMPTY environment, so
    // every std.process.spawn through it - notably `wpt serve` - would run with no
    // PATH at all. See src/platform/host.zig.
    host.adopt(init.io);

    // Neither path out of here runs deferred code: std.process.exit does not,
    // and an error return prints a trace and exits. So the flush is explicit on
    // both, or the tail of a run - including its summary - is lost.
    const code = run(init) catch |err| {
        flushOutput();
        return err;
    };
    flushOutput();
    if (code != 0) std.process.exit(code);
}

/// The runner's allocator, chosen at startup.
///
/// `init.gpa` is a `DebugAllocator(.{})`, whose Debug-mode default is
/// `stack_trace_frames = 6`: every allocation AND every free captures a
/// six-frame trace, and Zig 0.16's unwinder parses DWARF CFI byte-by-byte to do
/// it. Teardown of one test page frees hundreds of thousands of objects, so a
/// two-subtest page took 37 SECONDS to exit - measured, and the same on a
/// binary built before today's changes, so it was never new. The whole time
/// was `Io.Reader.takeLeb128` under `captureCurrentStackTrace`, at 99% CPU,
/// after the test had finished in 50ms.
///
/// Zero frames keeps leak DETECTION (the count and the addresses) and drops the
/// per-operation unwinding. `CRANE_LEAK_TRACES=1` restores the six-frame
/// allocator for a run where the traces are the point; that is what named the
/// `setTimeoutCallback` and `ProgressEvent` leaks, so it stays reachable.
var gpa_fast: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .{};
var gpa_traced: std.heap.DebugAllocator(.{}) = .{};

fn run(init: std.process.Init) !u8 {
    // 0.16 removed std.process.argsAlloc - arguments are no longer process-global.
    // std.process.Init carries them and a process-lifetime arena. Its gpa is not
    // used: see `gpa_fast` above for why the runner owns its allocator.
    const want_traces = if (init.minimal.environ.getPosix("CRANE_LEAK_TRACES")) |v| (v.len != 0 and v[0] != '0') else false;
    const allocator = if (want_traces) gpa_traced.allocator() else gpa_fast.allocator();
    defer {
        // Leak detection still runs; only the traces are gone in the fast case.
        if (want_traces) {
            _ = gpa_traced.deinit();
        } else {
            _ = gpa_fast.deinit();
        }
    }

    const args = try init.minimal.args.toSlice(init.arena.allocator());

    var options = try parseArgs(allocator, args[1..]);
    defer options.deinit();

    // Set verbose mode for log filtering
    verbose_mode = options.verbose;

    // Check WPT submodule exists
    const harness_path = try std.fs.path.join(allocator, &.{ options.wpt_root, "resources", "testharness.js" });
    defer allocator.free(harness_path);

    host.cwd().access(host.io(), harness_path, .{}) catch {
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
        return 0;
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
        return 0;
    }

    if (options.wantsSupervisor()) {
        return supervise(allocator, init.io, options, discovery);
    }

    // Create report
    var report = result_reporter.WptReport.init(allocator);
    defer report.deinit();

    // Start WPT server (provides URL rewrites and proper resource serving).
    // Under --supervise the parent already started one and this adopts it,
    // which is what keeps a restart from fighting over the ports.
    const server = try wpt_server.WptServer.init(allocator, options.wpt_root);
    defer server.deinit();
    try server.start();
    const base_url = try server.getBaseUrl(allocator);
    defer allocator.free(base_url);
    print("\nwpt serve {s} at {s} (TLS on :{d})\n", .{
        if (server.we_spawned) "started" else "adopted",
        base_url,
        server.https_port,
    });

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

    const selected = try selectedPaths(allocator, discovery);
    defer allocator.free(selected);
    return settleBaseline(allocator, options, selected);
}

/// The paths this run set out to cover. Borrows from `discovery`.
fn selectedPaths(
    allocator: std.mem.Allocator,
    discovery: DiscoveryResult,
) ![]const []const u8 {
    const paths = try allocator.alloc([]const u8, discovery.test_files.items.len);
    for (discovery.test_files.items, 0..) |tf, i| paths[i] = tf.path;
    return paths;
}

/// Compare the finished run against its baseline, or rewrite the baseline from
/// it. Returns the process exit code: nonzero means something regressed.
///
/// Reads the journal rather than the in-memory results because a supervised run
/// is several processes and the journal is the only place all of them meet.
///
/// `selected` is what this run set out to do, and scopes the comparison to it:
/// a run of url/ must not be told that every dom/ expectation went missing.
/// Recording reaches the same end by merging rather than by scoping, so that a
/// run of url/ does not delete them either.
fn settleBaseline(
    allocator: std.mem.Allocator,
    options: Options,
    selected: []const []const u8,
) !u8 {
    const baseline_path = options.baseline_path orelse return 0;

    const journal_path = (try options.journalPath(allocator)) orelse return 0;
    defer allocator.free(journal_path);

    var log = try journal.read(allocator, journal_path);
    defer log.deinit();

    var current = try baseline.fromLog(allocator, log);
    defer current.deinit();

    if (options.update_baseline) {
        // Fold into whatever is already recorded, so recording a subset keeps
        // the rest. An absent file starts from nothing, which is the same
        // thing with an empty baseline.
        var previous = baseline.read(allocator, baseline_path) catch |err| switch (err) {
            error.FileNotFound => baseline.Set{ .allocator = allocator, .entries = &.{} },
            else => return err,
        };
        defer previous.deinit();

        var updated = try baseline.merge(allocator, previous, current);
        defer updated.deinit();

        try baseline.writeToFile(baseline_path, updated);
        print("\nRecorded {d} of {d} expectations in {s}\n", .{
            current.entries.len,
            updated.entries.len,
            baseline_path,
        });
        return 0;
    }

    var recorded = baseline.read(allocator, baseline_path) catch |err| switch (err) {
        // Not "nothing is expected, so nothing can regress" - a comparison with
        // no baseline has checked nothing, and reporting that as a pass is the
        // one answer a gate must never give.
        error.FileNotFound => {
            print("\nNo baseline at {s}. Record one with --update-baseline.\n", .{baseline_path});
            return 1;
        },
        else => return err,
    };
    defer recorded.deinit();

    var expected = try baseline.restrictTo(allocator, recorded, selected);
    defer expected.deinit();

    if (expected.entries.len < recorded.entries.len) {
        print("\nComparing {d} of {d} recorded expectations (this run's selection).\n", .{
            expected.entries.len,
            recorded.entries.len,
        });
    }

    var d = try baseline.diff(allocator, expected, current);
    defer d.deinit();

    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    try baseline.report(&out.writer, d, 40);
    print("{s}", .{out.written()});

    return if (d.ok()) 0 else 1;
}

/// Write the discovered sources as a worklist file.
fn writeWorklistFile(
    allocator: std.mem.Allocator,
    path: []const u8,
    discovery: DiscoveryResult,
) !void {
    const io = host.io();
    if (std.fs.path.dirname(path)) |dir| {
        host.cwd().createDirPath(io, dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
    }

    var paths = try allocator.alloc([]const u8, discovery.test_files.items.len);
    defer allocator.free(paths);
    for (discovery.test_files.items, 0..) |tf, i| paths[i] = tf.path;

    var file = try host.cwd().createFile(io, path, .{});
    defer file.close(io);
    var buf: [4096]u8 = undefined;
    var file_writer = file.writer(io, &buf);
    try selection.writeWorklist(&file_writer.interface, paths);
    try file_writer.interface.flush();
}

/// Write the subset of `discovery` named by `indices` as its own worklist.
///
/// A shard gets a private worklist rather than a stride over the shared one so
/// that its indices stay contiguous from zero. The resume-past-a-crash loop is
/// built on "the first index nobody journalled", which only means anything if
/// the indices a process runs are the indices it counts.
fn writeShardWorklist(
    allocator: std.mem.Allocator,
    path: []const u8,
    discovery: DiscoveryResult,
    indices: []const usize,
) !void {
    const io = host.io();
    if (std.fs.path.dirname(path)) |dir| {
        host.cwd().createDirPath(io, dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
    }

    var paths = try allocator.alloc([]const u8, indices.len);
    defer allocator.free(paths);
    for (indices, 0..) |global, local| paths[local] = discovery.test_files.items[global].path;

    var file = try host.cwd().createFile(io, path, .{});
    defer file.close(io);
    var buf: [4096]u8 = undefined;
    var file_writer = file.writer(io, &buf);
    try selection.writeWorklist(&file_writer.interface, paths);
    try file_writer.interface.flush();
}

/// Everything one shard's restart loop needs. A shard is a worklist file, a
/// journal to write, and the paths in that worklist so a crash can be named.
const Shard = struct {
    allocator: std.mem.Allocator,
    /// The process Io. Carried on the shard rather than reached for globally so
    /// it travels with the shard into its worker thread; 0.16 needs one to spawn
    /// and wait on the child process.
    io: std.Io,
    options: *const Options,
    self_exe: []const u8,
    worklist_path: []const u8,
    journal_path: []const u8,
    /// Shard-local order, so `paths[i]` is the test at local index `i`.
    paths: []const []const u8,
    /// Prefix for this shard's progress lines. Null when there is only one
    /// shard and the output needs no disambiguating.
    label: ?[]const u8,
};

/// Run one shard's worklist to exhaustion, respawning past each crash.
///
/// This is the original single-process supervise loop with the worklist and
/// journal made parameters. Nothing about it is aware of other shards: they
/// share the server and nothing else, so each one's resume point is its own.
fn runShard(allocator: std.mem.Allocator, shard: Shard) !void {
    const total = shard.paths.len;
    if (total == 0) return;

    const options = shard.options;
    var attempt: usize = 0;

    while (true) {
        // Each restart consumes exactly one worklist entry, so this can only
        // spin as many times as there are tests. The bound is a backstop
        // against a bug in that reasoning, not part of the design.
        attempt += 1;
        if (attempt > total + 1) {
            print("{s}giving up after {d} restarts\n", .{ shard.label orelse "Supervisor: ", attempt - 1 });
            break;
        }

        var log = try journal.read(allocator, shard.journal_path);
        const next = log.nextIndex();
        log.deinit();

        if (next >= total) break;

        const start_arg = try std.fmt.allocPrint(allocator, "--start-index={d}", .{next});
        defer allocator.free(start_arg);
        const from_arg = try std.fmt.allocPrint(allocator, "--from-file={s}", .{shard.worklist_path});
        defer allocator.free(from_arg);
        const journal_arg = try std.fmt.allocPrint(allocator, "--journal={s}", .{shard.journal_path});
        defer allocator.free(journal_arg);
        const root_arg = try std.fmt.allocPrint(allocator, "--wpt-root={s}", .{options.wpt_root});
        defer allocator.free(root_arg);
        const out_arg = try std.fmt.allocPrint(allocator, "--output={s}", .{options.output_dir});
        defer allocator.free(out_arg);

        var argv: std.ArrayList([]const u8) = .empty;
        defer argv.deinit(allocator);
        try argv.appendSlice(allocator, &.{ shard.self_exe, from_arg, start_arg, journal_arg, root_arg, out_arg });
        if (!options.verbose) try argv.append(allocator, "--quiet");

        print("{s}running tests {d}..{d}\n", .{ shard.label orelse "--> ", next, total });

        // The child writes to this same stderr. Anything still sitting in our
        // buffer has to go out first or it would surface after the child's
        // output and misreport the order of the run.
        flushOutput();

        // 0.16: Child.init + spawnAndWait become std.process.spawn(io, options)
        // followed by wait(io). Behaviour is unchanged - still a blocking wait for
        // this one shard - and Term's union tags are lowercase now.
        var child = try std.process.spawn(shard.io, .{ .argv = argv.items });

        // The per-file ceiling only bounds the wait for `__wpt_complete`. The
        // navigation, the parse and every script the parser runs are unbounded,
        // and `fetch()` is synchronous down to `curl_easy_perform`, so a page
        // that polls in a loop never returns to the ceiling at all. This wait
        // is the only place left that can end it. See stall_watchdog.zig.
        var watchdog: stall_watchdog.Watchdog = .{
            .journal_path = shard.journal_path,
            // A spawned child always has an id; a null one means there is
            // nothing to watch, and a zero pid would name our own group.
            .child_id = child.id orelse 0,
            .stall_limit_ms = if (child.id == null) 0 else options.stall_limit_ms,
        };
        try watchdog.start();

        const term = try child.wait(shard.io);
        watchdog.stop();

        if (watchdog.killedChild()) {
            // A hang is not a crash: nothing faulted, the file simply never
            // finished. Recording it as one would put it in the crash column,
            // which gates, and would say the process was unsound when it was
            // the test that would not end.
            var after = try journal.read(allocator, shard.journal_path);
            const hung = after.nextIndex();
            after.deinit();

            if (hung >= total) break;

            const path = shard.paths[hung];
            print("\n{s}!!! hung on [{d}] {s} (no progress for {d}ms; killed)\n\n", .{
                shard.label orelse "", hung, path, options.stall_limit_ms,
            });

            var j = try journal.Journal.append(allocator, shard.journal_path);
            defer j.deinit();
            const message = try std.fmt.allocPrint(
                allocator,
                "supervisor killed a child that made no progress for {d}ms",
                .{options.stall_limit_ms},
            );
            defer allocator.free(message);
            try j.record(.{
                .index = hung,
                .path = path,
                .status = .timeout,
                .message = message,
            });
            continue;
        }

        const clean = switch (term) {
            .exited => |code| code == 0,
            else => false,
        };
        if (clean) {
            // A clean exit that did not finish the worklist means the child
            // stopped for a reason of its own. Looping again would either
            // repeat that or spin, so stop and let the journal speak.
            var after = try journal.read(allocator, shard.journal_path);
            defer after.deinit();
            if (after.nextIndex() >= total) break;
            if (after.nextIndex() <= next) {
                print("{s}child exited cleanly without running anything; stopping\n", .{shard.label orelse "Supervisor: "});
                break;
            }
            continue;
        }

        // Abnormal exit. Everything before the crashing test wrote its record,
        // so the first unreported index is the culprit.
        var after = try journal.read(allocator, shard.journal_path);
        const crashed = after.nextIndex();
        after.deinit();

        if (crashed >= total) break;

        const path = shard.paths[crashed];
        print("\n{s}!!! crashed on [{d}] {s} ({any})\n\n", .{ shard.label orelse "", crashed, path, term });

        var j = try journal.Journal.append(allocator, shard.journal_path);
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
}

/// A shard whose loop runs on its own thread, plus what it needs to be merged
/// back into the run afterwards.
const ShardRun = struct {
    shard: Shard,
    /// Shard-local index -> global worklist index.
    indices: []usize,
    thread: std.Thread = undefined,
    /// Set by the thread. Threads cannot propagate errors, so the failure is
    /// carried here and re-raised on the joining side.
    failure: ?anyerror = null,

    fn entry(self: *ShardRun) void {
        runShard(self.shard.allocator, self.shard) catch |err| {
            self.failure = err;
        };
    }
};

/// Run `shard_count` shards concurrently, then fold their journals into one.
///
/// Sharding at the process level rather than inside the browser is deliberate.
/// A test file costs about 4s of overhead beyond its own runtime - roughly
/// 1.7s to tear down the previous V8 context and build a new one, 1.6s to fetch
/// and parse the page - and that cost is per file no matter how fast the test
/// is. It is not going away by making any one step cheaper, but it does divide.
fn runShardsInParallel(
    allocator: std.mem.Allocator,
    io: std.Io,
    options: Options,
    discovery: DiscoveryResult,
    self_exe: []const u8,
    journal_path: []const u8,
    shard_count: usize,
) !void {
    const total = discovery.test_files.items.len;

    const runs = try allocator.alloc(ShardRun, shard_count);
    defer allocator.free(runs);

    // Allocated up front so the cleanup below can free unconditionally.
    var built: usize = 0;
    defer {
        for (runs[0..built]) |*r| {
            allocator.free(r.indices);
            allocator.free(r.shard.paths);
            allocator.free(r.shard.worklist_path);
            allocator.free(r.shard.journal_path);
            allocator.free(r.shard.label.?);
        }
    }

    while (built < shard_count) : (built += 1) {
        const i = built;
        const indices = try selection.shardIndices(allocator, total, shard_count, i);
        const paths = try allocator.alloc([]const u8, indices.len);
        for (indices, 0..) |global, local| paths[local] = discovery.test_files.items[global].path;

        const wl = try std.fmt.allocPrint(allocator, "{s}/worklist.shard{d}.txt", .{ options.output_dir, i });
        const jl = try std.fmt.allocPrint(allocator, "{s}/journal.shard{d}.jsonl", .{ options.output_dir, i });
        const label = try std.fmt.allocPrint(allocator, "[shard {d}] ", .{i});

        try writeShardWorklist(allocator, wl, discovery, indices);
        // Start each shard from an empty ledger, for the same reason the whole
        // run does: a stale journal resumes at indices that mean nothing now.
        {
            var fresh = try journal.Journal.create(allocator, jl);
            fresh.deinit();
        }

        runs[i] = .{
            .shard = .{
                .allocator = allocator,
                .io = io,
                .options = &options,
                .self_exe = self_exe,
                .worklist_path = wl,
                .journal_path = jl,
                .paths = paths,
                .label = label,
            },
            .indices = indices,
        };
    }

    print("Sharding {d} files across {d} parallel runners\n\n", .{ total, shard_count });

    for (runs) |*r| r.thread = try std.Thread.spawn(.{}, ShardRun.entry, .{r});
    for (runs) |*r| r.thread.join();

    // Fold the shards back into the run's journal, translating each record's
    // shard-local index to its global worklist position. Without that the
    // report and the baseline would see a dozen index 0s.
    var merged = try journal.Journal.append(allocator, journal_path);
    defer merged.deinit();

    for (runs) |*r| {
        var log = try journal.read(allocator, r.shard.journal_path);
        defer log.deinit();
        for (log.records) |rec| {
            var out = rec;
            out.index = if (rec.index < r.indices.len) r.indices[rec.index] else rec.index;
            try merged.record(out);
        }
    }

    for (runs) |*r| {
        if (r.failure) |err| return err;
    }
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
    io: std.Io,
    options: Options,
    discovery: DiscoveryResult,
) !u8 {
    const total = discovery.test_files.items.len;
    if (total == 0) return 0;

    host.cwd().createDirPath(host.io(), options.output_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    const worklist_path = try std.fs.path.join(allocator, &.{ options.output_dir, "worklist.txt" });
    defer allocator.free(worklist_path);
    try writeWorklistFile(allocator, worklist_path, discovery);

    // Same path settleBaseline will read afterwards, so a `--journal=` override
    // does not leave the comparison reading a file nobody wrote.
    const journal_path = (try options.journalPath(allocator)) orelse
        try std.fs.path.join(allocator, &.{ options.output_dir, "journal.jsonl" });
    defer allocator.free(journal_path);

    // Start from an empty ledger. Resuming an old journal against a worklist
    // that may have been regenerated would resume at meaningless indices.
    {
        var fresh = try journal.Journal.create(allocator, journal_path);
        fresh.deinit();
    }

    const self_exe = try std.process.executablePathAlloc(host.io(), allocator);
    defer allocator.free(self_exe);

    // The supervisor owns the server for the whole run; children adopt it
    // through the lockfile and leave it alone. Letting each child spawn its
    // own would pay the startup cost once per crash, and a child killed
    // mid-run would orphan the server it was holding.
    const server = try wpt_server.WptServer.init(allocator, options.wpt_root);
    defer server.deinit();
    try server.start();
    const base_url = try server.getBaseUrl(allocator);
    defer allocator.free(base_url);
    print("\nwpt serve {s} at {s} (TLS on :{d})\n", .{
        if (server.we_spawned) "started" else "adopted",
        base_url,
        server.https_port,
    });

    print("\nSupervising {d} test files\n", .{total});
    print("  worklist: {s}\n", .{worklist_path});
    print("  journal:  {s}\n\n", .{journal_path});

    const shard_count = selection.resolveShardCount(
        options.shardRequest(),
        total,
        std.Thread.getCpuCount() catch 1,
    );

    if (shard_count > 1) {
        try runShardsInParallel(allocator, io, options, discovery, self_exe, journal_path, shard_count);
    } else {
        const worklist_paths = try allocator.alloc([]const u8, total);
        defer allocator.free(worklist_paths);
        for (discovery.test_files.items, 0..) |f, i| worklist_paths[i] = f.path;

        try runShard(allocator, .{
            .allocator = allocator,
            .io = io,
            .options = &options,
            .self_exe = self_exe,
            .worklist_path = worklist_path,
            .journal_path = journal_path,
            .paths = worklist_paths,
            .label = null,
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

    // Phase 5. The supervisor's own counters are meaningless - it runs no tests -
    // so this is summed out of the journal, which is the only place the children's
    // numbers survive their exit. Printed as a pair because `0 violations` from an
    // instrument that never executed is indistinguishable from a clean run.
    if (s.ownership_checks == 0) {
        print("Isolate ownership: not measured (0 checks across {d} records)\n", .{log.records.len});
    } else {
        print("Isolate ownership: {d} violation(s) in {d} checks\n", .{
            s.ownership_violations,
            s.ownership_checks,
        });
    }

    print("\nJournal: {s}\n", .{journal_path});

    const selected = try selectedPaths(allocator, discovery);
    defer allocator.free(selected);
    return settleBaseline(allocator, options, selected);
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
    var results: std.ArrayListUnmanaged(test_harness.TestResult) = .empty;
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

// `calculateTotalTests` used to be covered by a test here that re-implemented
// its counting inline rather than calling it. Two things were wrong with that:
// test blocks in main.zig are not part of `harness_sources` and so never run,
// and the copy drifted - it still asserted the dedicated worker was
// unimplemented long after it started running. The rule now lives in
// `TestMetadata.runCount`, in a module the test step actually compiles, and is
// covered there by the `runCount:` tests.
