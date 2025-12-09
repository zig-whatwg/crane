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
    /// Overall test file status
    status: HarnessStatus,
    /// Individual subtest results
    subtests: std.ArrayList(SubtestResult),
    /// Allocator for managing memory
    allocator: std.mem.Allocator,
    /// Overall message (error message if status is ERROR)
    message: ?[]const u8 = null,
    /// Duration in milliseconds
    duration_ms: u64 = 0,

    pub fn init(allocator: std.mem.Allocator, test_path: []const u8) !TestResult {
        return TestResult{
            .test_path = try allocator.dupe(u8, test_path),
            .status = .ok,
            .subtests = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TestResult, allocator: std.mem.Allocator) void {
        allocator.free(self.test_path);
        if (self.message) |msg| allocator.free(msg);
        for (self.subtests.items) |*subtest| {
            subtest.deinit(allocator);
        }
        self.subtests.deinit(allocator);
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
            .results = .{},
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
                .subtests = .{},
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
