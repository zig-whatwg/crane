//! WPT testharness.js Integration
//!
//! This module provides the bridge between testharness.js (the WPT test framework)
//! and our Zig-based test runner. It collects test results from JavaScript and
//! converts them to our internal format.
//!
//! ## testharness.js Overview
//!
//! testharness.js provides these test types:
//! - `test(fn, name)` - Synchronous test
//! - `async_test(fn, name)` - Async test with explicit done()
//! - `promise_test(fn, name)` - Promise-based async test
//!
//! And these assertion functions:
//! - `assert_equals(actual, expected, description)`
//! - `assert_true(value, description)`
//! - `assert_false(value, description)`
//! - `assert_throws_js(constructor, fn, description)`
//! - And many more...
//!
//! ## Result Collection
//!
//! We inject a custom testharnessreport.js that calls into Zig via FFI:
//! - `add_result_callback` - Called for each test/subtest result
//! - `add_completion_callback` - Called when all tests complete

const std = @import("std");

/// WPT test status values (match testharness.js)
pub const TestStatus = enum(u8) {
    /// Test passed all assertions
    pass = 0,
    /// Test failed one or more assertions
    fail = 1,
    /// Test timed out
    timeout = 2,
    /// Test was not run (e.g., precondition failed)
    notrun = 3,
    /// Precondition for test was not met
    precondition_failed = 4,

    pub fn fromInt(value: u8) TestStatus {
        return switch (value) {
            0 => .pass,
            1 => .fail,
            2 => .timeout,
            3 => .notrun,
            4 => .precondition_failed,
            else => .fail,
        };
    }

    pub fn toString(self: TestStatus) []const u8 {
        return switch (self) {
            .pass => "PASS",
            .fail => "FAIL",
            .timeout => "TIMEOUT",
            .notrun => "NOTRUN",
            .precondition_failed => "PRECONDITION_FAILED",
        };
    }
};

/// Test file level status (different from subtest status)
pub const HarnessStatus = enum(u8) {
    /// Test file completed successfully
    ok = 0,
    /// Test file had an error (script error, etc.)
    @"error" = 1,
    /// Test file timed out
    timeout = 2,

    pub fn fromInt(value: u8) HarnessStatus {
        return switch (value) {
            0 => .ok,
            1 => .@"error",
            2 => .timeout,
            else => .@"error",
        };
    }

    pub fn toString(self: HarnessStatus) []const u8 {
        return switch (self) {
            .ok => "OK",
            .@"error" => "ERROR",
            .timeout => "TIMEOUT",
        };
    }
};

/// Result of a single subtest (assertion) within a test file
pub const SubtestResult = struct {
    /// Name/description of the test
    name: []const u8,
    /// Test status (PASS, FAIL, etc.)
    status: TestStatus,
    /// Failure message (null if passed)
    /// For assertion failures, this contains the formatted message from testharness.js
    /// which includes expected/actual values (e.g., "assert_equals: expected 1 but got 2")
    message: ?[]const u8 = null,
    /// Stack trace for failures (null if passed)
    /// Contains V8 stack trace with file:line information
    stack: ?[]const u8 = null,
    /// Duration in milliseconds
    duration_ms: u64 = 0,

    pub fn deinit(self: *SubtestResult, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        if (self.message) |msg| allocator.free(msg);
        if (self.stack) |stk| allocator.free(stk);
    }

    /// Check if this result represents a failure
    pub fn isFailed(self: SubtestResult) bool {
        return self.status != .pass;
    }

    /// Get a summary string for this result
    pub fn getSummary(self: SubtestResult, allocator: std.mem.Allocator) ![]u8 {
        if (self.message) |msg| {
            return std.fmt.allocPrint(allocator, "{s}: {s} - {s}", .{
                self.status.toString(),
                self.name,
                msg,
            });
        } else {
            return std.fmt.allocPrint(allocator, "{s}: {s}", .{
                self.status.toString(),
                self.name,
            });
        }
    }

    /// Extract the first line from a stack trace (typically the most relevant location)
    pub fn getStackLocation(self: SubtestResult) ?[]const u8 {
        if (self.stack) |stack| {
            // Stack traces from V8 look like:
            // "    at Test.<anonymous> (test.js:10:5)\n    at ..."
            // Find the first line after "at "
            if (std.mem.indexOf(u8, stack, "at ")) |at_pos| {
                const after_at = stack[at_pos..];
                if (std.mem.indexOf(u8, after_at, "\n")) |newline_pos| {
                    return after_at[0..newline_pos];
                }
                return after_at;
            }
        }
        return null;
    }
};

/// Result of an entire test file
pub const TestResult = struct {
    /// Path to test file (relative to WPT root)
    test_path: []const u8,
    /// Execution context (e.g., "window", "worker"). Null for single-context tests.
    context: ?[]const u8 = null,
    /// Overall test file status
    status: HarnessStatus,
    /// Individual subtest results
    subtests: std.ArrayList(SubtestResult),
    /// Allocator for managing memory
    allocator: std.mem.Allocator,
    /// Overall message (error message if status is ERROR)
    message: ?[]const u8 = null,
    /// Milliseconds spent waiting for the page to signal `__wpt_complete`.
    ///
    /// A page whose scripts are all synchronous has already finished by the
    /// time this clock starts, so this being near zero says nothing about how
    /// long the file took. See `nav_ms` and `load_ms` for the rest of it.
    duration_ms: u64 = 0,
    /// Milliseconds spent creating the V8 context and installing testharness.js.
    nav_ms: u64 = 0,
    /// Milliseconds spent fetching the page, parsing it, and running its
    /// scripts to the end of the document.
    load_ms: u64 = 0,
    /// A WPT crashtest's run (wpt_browser.zig `runCrashtest`): it has no
    /// subtests, and its OK is wptreport's PASS.
    crashtest: bool = false,

    pub fn init(allocator: std.mem.Allocator, test_path: []const u8) !TestResult {
        return TestResult{
            .test_path = try allocator.dupe(u8, test_path),
            .status = .ok,
            .subtests = .empty,
            .allocator = allocator,
        };
    }

    /// Initialize with a context (for multi-context tests like .any.js)
    pub fn initWithContext(allocator: std.mem.Allocator, test_path: []const u8, context: ?[]const u8) !TestResult {
        return TestResult{
            .test_path = try allocator.dupe(u8, test_path),
            .context = if (context) |ctx| try allocator.dupe(u8, ctx) else null,
            .status = .ok,
            .subtests = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TestResult, allocator: std.mem.Allocator) void {
        allocator.free(self.test_path);
        if (self.context) |ctx| allocator.free(ctx);
        if (self.message) |msg| allocator.free(msg);
        for (self.subtests.items) |*subtest| {
            subtest.deinit(allocator);
        }
        self.subtests.deinit(allocator);
    }

    /// Get the display name including context suffix if present.
    /// For single-context tests: "url/test.any.js"
    /// For multi-context tests: "url/test.any.js [worker]"
    pub fn getDisplayName(self: TestResult, allocator: std.mem.Allocator) ![]const u8 {
        if (self.context) |ctx| {
            return std.fmt.allocPrint(allocator, "{s} [{s}]", .{ self.test_path, ctx });
        }
        return allocator.dupe(u8, self.test_path);
    }

    pub fn addSubtest(self: *TestResult, subtest: SubtestResult) !void {
        try self.subtests.append(self.allocator, subtest);
    }

    /// Count passed subtests
    pub fn passedCount(self: TestResult) usize {
        var count: usize = 0;
        for (self.subtests.items) |sub| {
            if (sub.status == .pass) count += 1;
        }
        return count;
    }

    /// Count failed subtests
    pub fn failedCount(self: TestResult) usize {
        var count: usize = 0;
        for (self.subtests.items) |sub| {
            if (sub.status == .fail) count += 1;
        }
        return count;
    }
};

/// Collects results from multiple test files
pub const ResultCollector = struct {
    allocator: std.mem.Allocator,
    results: std.ArrayList(TestResult),
    current_test: ?*TestResult = null,
    completion_signaled: bool = false,
    /// Whether the test has completed (alias for completion_signaled)
    completed: bool = false,

    pub fn init(allocator: std.mem.Allocator) ResultCollector {
        return ResultCollector{
            .allocator = allocator,
            .results = .empty,
        };
    }

    pub fn deinit(self: *ResultCollector) void {
        for (self.results.items) |*result| {
            result.deinit(self.allocator);
        }
        self.results.deinit(self.allocator);
    }

    /// Start collecting results for a new test file
    pub fn startTest(self: *ResultCollector, test_path: []const u8) !void {
        const result = try TestResult.init(self.allocator, test_path);
        try self.results.append(self.allocator, result);
        self.current_test = &self.results.items[self.results.items.len - 1];
        self.completion_signaled = false;
        self.completed = false;
    }

    /// Add a subtest result to the current test
    pub fn addResult(self: *ResultCollector, subtest: SubtestResult) !void {
        if (self.current_test) |current| {
            try current.addSubtest(subtest);
        }
    }

    /// Mark the current test as complete
    pub fn finishTest(self: *ResultCollector, status: HarnessStatus, message: ?[]const u8, duration_ms: u64) !void {
        if (self.current_test) |current| {
            current.status = status;
            current.duration_ms = duration_ms;
            if (message) |msg| {
                current.message = try self.allocator.dupe(u8, msg);
            }
            self.completion_signaled = true;
            self.completed = true;
        }
    }

    /// Finalize and return a test result for the given path
    pub fn finalize(self: *ResultCollector, allocator: std.mem.Allocator, test_path: []const u8) !TestResult {
        // If we have a current test, finalize it
        if (self.current_test) |current| {
            // Already has subtests collected
            var result = TestResult{
                .test_path = try allocator.dupe(u8, test_path),
                .status = current.status,
                .subtests = .empty,
                .allocator = allocator,
                .message = if (current.message) |msg| try allocator.dupe(u8, msg) else null,
                .duration_ms = current.duration_ms,
            };

            // Copy subtests
            for (current.subtests.items) |sub| {
                try result.subtests.append(allocator, SubtestResult{
                    .name = try allocator.dupe(u8, sub.name),
                    .status = sub.status,
                    .message = if (sub.message) |msg| try allocator.dupe(u8, msg) else null,
                    .stack = if (sub.stack) |stk| try allocator.dupe(u8, stk) else null,
                    .duration_ms = sub.duration_ms,
                });
            }

            return result;
        }

        // No results - return empty result
        return TestResult.init(allocator, test_path);
    }

    /// Get total counts across all test files
    pub fn getTotals(self: ResultCollector) struct { passed: usize, failed: usize, timeout: usize, error_count: usize } {
        var passed: usize = 0;
        var failed: usize = 0;
        var timeout: usize = 0;
        var error_count: usize = 0;

        for (self.results.items) |result| {
            for (result.subtests.items) |sub| {
                switch (sub.status) {
                    .pass => passed += 1,
                    .fail => failed += 1,
                    .timeout => timeout += 1,
                    else => error_count += 1,
                }
            }
        }

        return .{ .passed = passed, .failed = failed, .timeout = timeout, .error_count = error_count };
    }
};

/// Custom testharnessreport.js content
/// This JavaScript file is loaded after testharness.js and registers callbacks
/// that call into Zig via native functions we expose.
pub const testharnessreport_js =
    \\// Custom testharnessreport.js for WPT runner
    \\// Bridges testharness.js results to Zig test runner
    \\//
    \\// This file replaces the standard WPT testharnessreport.js to route
    \\// test results to our native callbacks for collection.
    \\
    \\(function() {
    \\  'use strict';
    \\
    \\  // Check if testharness.js has been loaded
    \\  if (typeof add_result_callback !== 'function') {
    \\    return;
    \\  }
    \\
    \\  // Verify native functions are available
    \\  if (typeof __wpt_report_result !== 'function' ||
    \\      typeof __wpt_report_completion !== 'function') {
    \\    return;
    \\  }
    \\
    \\  // Configure testharness.js with explicit timeout (we handle timeout ourselves)
    \\  if (typeof setup === 'function') {
    \\    setup({ explicit_timeout: true });
    \\  }
    \\
    \\  // Register callback for individual test results
    \\  add_result_callback(function(test) {
    \\    __wpt_report_result(
    \\      test.name || '',
    \\      test.status,
    \\      test.message || null,
    \\      test.stack || null,
    \\      test.duration || 0
    \\    );
    \\  });
    \\
    \\  // Register callback for test completion
    \\  add_completion_callback(function(tests, harness_status) {
    \\    __wpt_report_completion(
    \\      harness_status.status,
    \\      harness_status.message || null
    \\    );
    \\  });
    \\})();
;

// ============================================================================
// Where the harness loads
// ============================================================================

/// Where a run's testharness.js loads (wpt_browser.zig `runHTMLTest`).
pub const HarnessLoad = enum {
    /// Where the page includes it, as in a browser - upstream wptrunner's
    /// model: the page's own includes load the harness and the runner's
    /// report.
    at_include,
    /// Before the page: one whose source names no testharness.js.
    before_page,
};

/// Where the harness loads for the test at `test_path` (relative to the WPT
/// root, with any variant query), given the source of its file - null when
/// the file could not be read.
///
/// A JavaScript test (`.any.js`, `.window.js`, `.worker.js`) runs in the
/// page wpt serve wraps it in, which includes testharness.js and
/// testharnessreport.js before the test's scripts (tools/serve/serve.py,
/// the wrapper handlers). A document includes it when its source names it;
/// one that merely names it without including it has the harness installed
/// after the page. A file the runner cannot read is left to its includes.
pub fn harnessLoadFor(test_path: []const u8, source: ?[]const u8) HarnessLoad {
    if (std.mem.endsWith(u8, sourcePathOf(test_path), ".js")) return .at_include;
    const text = source orelse return .at_include;
    return if (namesHarness(text)) .at_include else .before_page;
}

/// The file of `test_path`: without a variant's query or a fragment, and
/// relative to the WPT root.
pub fn sourcePathOf(test_path: []const u8) []const u8 {
    const end = std.mem.indexOfAny(u8, test_path, "?#") orelse test_path.len;
    return std.mem.trimStart(u8, test_path[0..end], "/");
}

/// Whether `source` names testharness.js: in ASCII, or in UTF-16 of either
/// byte order (a page encoded so, as the css-syntax/charset pages are).
pub fn namesHarness(source: []const u8) bool {
    const name = "testharness.js";
    if (std.mem.indexOf(u8, source, name) != null) return true;
    inline for (.{ false, true }) |big_endian| {
        const wide = comptime blk: {
            var units: [name.len * 2]u8 = undefined;
            for (name, 0..) |c, i| {
                units[i * 2 + @intFromBool(big_endian)] = c;
                units[i * 2 + @intFromBool(!big_endian)] = 0;
            }
            break :blk units;
        };
        if (std.mem.indexOf(u8, source, &wide) != null) return true;
    }
    return false;
}

test "harnessLoadFor: a page that includes the harness loads it at its include" {
    const page =
        \\<!doctype html>
        \\<script>var early = typeof async_test;</script>
        \\<script src=/resources/testharness.js></script>
        \\<script src=/resources/testharnessreport.js></script>
    ;
    try std.testing.expectEqual(HarnessLoad.at_include, harnessLoadFor("content-security-policy/generic/generic-0_8_1.sub.html", page));
    try std.testing.expectEqual(HarnessLoad.at_include, harnessLoadFor("dom/nodes/x.html?a=1", "<script src='../../resources/testharness.js'></script>"));
}

test "harnessLoadFor: a page that names no harness gets it before the page" {
    const page = "<!doctype html><script>test(() => {}, 'inline');</script>";
    try std.testing.expectEqual(HarnessLoad.before_page, harnessLoadFor("crane/no-include.html", page));
}

test "harnessLoadFor: a JavaScript test runs in a wrapper that includes it, whatever its source" {
    try std.testing.expectEqual(HarnessLoad.at_include, harnessLoadFor("streams/readable-streams/from.any.js", "promise_test(async () => {});"));
    try std.testing.expectEqual(HarnessLoad.at_include, harnessLoadFor("/url/a.window.js?b", null));
}

test "harnessLoadFor: an unreadable file is left to its includes" {
    try std.testing.expectEqual(HarnessLoad.at_include, harnessLoadFor("css/x.html", null));
}

test "namesHarness: UTF-16 sources of either byte order" {
    const le = "<\x00s\x00 \x00t\x00e\x00s\x00t\x00h\x00a\x00r\x00n\x00e\x00s\x00s\x00.\x00j\x00s\x00";
    const be = "\x00<\x00s\x00 \x00t\x00e\x00s\x00t\x00h\x00a\x00r\x00n\x00e\x00s\x00s\x00.\x00j\x00s";
    try std.testing.expect(namesHarness(le));
    try std.testing.expect(namesHarness(be));
    try std.testing.expect(!namesHarness("t\x00e\x00s\x00t\x00"));
    try std.testing.expect(!namesHarness("testharness.jsx"[0..13]));
}

test "sourcePathOf drops a variant's query, a fragment and a leading slash" {
    try std.testing.expectEqualStrings("a/b.html", sourcePathOf("/a/b.html?x=1#y"));
    try std.testing.expectEqualStrings("a/b.any.js", sourcePathOf("a/b.any.js"));
}

test "TestStatus.fromInt" {
    const testing = std.testing;

    try testing.expectEqual(TestStatus.pass, TestStatus.fromInt(0));
    try testing.expectEqual(TestStatus.fail, TestStatus.fromInt(1));
    try testing.expectEqual(TestStatus.timeout, TestStatus.fromInt(2));
    try testing.expectEqual(TestStatus.notrun, TestStatus.fromInt(3));
    try testing.expectEqual(TestStatus.fail, TestStatus.fromInt(255)); // Invalid maps to fail
}

test "ResultCollector basic usage" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var collector = ResultCollector.init(allocator);
    defer collector.deinit();

    try collector.startTest("url/url-constructor.any.js");

    const subtest = SubtestResult{
        .name = try allocator.dupe(u8, "URL constructor, basic"),
        .status = .pass,
        .duration_ms = 5,
    };
    try collector.addResult(subtest);

    try collector.finishTest(.ok, null, 100);

    try testing.expectEqual(@as(usize, 1), collector.results.items.len);
    const totals = collector.getTotals();
    try testing.expectEqual(@as(usize, 1), totals.passed);
}

test "SubtestResult with assertion failure" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Simulate a testharness.js assertion failure message
    var subtest = SubtestResult{
        .name = try allocator.dupe(u8, "URL constructor should parse basic URL"),
        .status = .fail,
        .message = try allocator.dupe(u8, "assert_equals: expected \"https\" but got \"http\""),
        .stack = try allocator.dupe(u8, "    at Test.<anonymous> (url-constructor.any.js:10:5)\n    at Test.step_func"),
        .duration_ms = 15,
    };
    defer subtest.deinit(allocator);

    try testing.expect(subtest.isFailed());
    try testing.expectEqualStrings("FAIL", subtest.status.toString());

    // Test stack location extraction
    const location = subtest.getStackLocation();
    try testing.expect(location != null);
    try testing.expect(std.mem.indexOf(u8, location.?, "url-constructor.any.js:10:5") != null);

    // Test summary generation
    const summary = try subtest.getSummary(allocator);
    defer allocator.free(summary);
    try testing.expect(std.mem.indexOf(u8, summary, "FAIL") != null);
    try testing.expect(std.mem.indexOf(u8, summary, "assert_equals") != null);
}

test "SubtestResult with passing test" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var subtest = SubtestResult{
        .name = try allocator.dupe(u8, "Simple passing test"),
        .status = .pass,
        .duration_ms = 5,
    };
    defer subtest.deinit(allocator);

    try testing.expect(!subtest.isFailed());
    try testing.expectEqualStrings("PASS", subtest.status.toString());

    // No stack for passing tests
    try testing.expectEqual(@as(?[]const u8, null), subtest.getStackLocation());
}

test "ResultCollector with mixed results" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var collector = ResultCollector.init(allocator);
    defer collector.deinit();

    try collector.startTest("encoding/textdecoder.any.js");

    // Add passing test
    try collector.addResult(SubtestResult{
        .name = try allocator.dupe(u8, "TextDecoder constructor"),
        .status = .pass,
        .duration_ms = 3,
    });

    // Add failing test
    try collector.addResult(SubtestResult{
        .name = try allocator.dupe(u8, "TextDecoder decode UTF-8"),
        .status = .fail,
        .message = try allocator.dupe(u8, "assert_equals: expected decoded text"),
        .duration_ms = 5,
    });

    // Add timeout test
    try collector.addResult(SubtestResult{
        .name = try allocator.dupe(u8, "TextDecoder async decode"),
        .status = .timeout,
        .duration_ms = 10000,
    });

    try collector.finishTest(.ok, null, 10008);

    const totals = collector.getTotals();
    try testing.expectEqual(@as(usize, 1), totals.passed);
    try testing.expectEqual(@as(usize, 1), totals.failed);
    try testing.expectEqual(@as(usize, 1), totals.timeout);
}

test "TestResult with context" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Test initWithContext
    var result = try TestResult.initWithContext(allocator, "url/test.any.js", "worker");
    defer result.deinit(allocator);

    try testing.expectEqualStrings("url/test.any.js", result.test_path);
    try testing.expect(result.context != null);
    try testing.expectEqualStrings("worker", result.context.?);

    // Test getDisplayName with context
    const display_name = try result.getDisplayName(allocator);
    defer allocator.free(display_name);
    try testing.expectEqualStrings("url/test.any.js [worker]", display_name);
}

test "TestResult without context" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Test init (no context)
    var result = try TestResult.init(allocator, "url/test.window.js");
    defer result.deinit(allocator);

    try testing.expectEqualStrings("url/test.window.js", result.test_path);
    try testing.expectEqual(@as(?[]const u8, null), result.context);

    // Test getDisplayName without context
    const display_name = try result.getDisplayName(allocator);
    defer allocator.free(display_name);
    try testing.expectEqualStrings("url/test.window.js", display_name);
}

test "TestResult initWithContext null context" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Test initWithContext with null context
    var result = try TestResult.initWithContext(allocator, "url/test.window.js", null);
    defer result.deinit(allocator);

    try testing.expectEqualStrings("url/test.window.js", result.test_path);
    try testing.expectEqual(@as(?[]const u8, null), result.context);

    // Test getDisplayName without context
    const display_name = try result.getDisplayName(allocator);
    defer allocator.free(display_name);
    try testing.expectEqualStrings("url/test.window.js", display_name);
}
