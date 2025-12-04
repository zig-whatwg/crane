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
    message: ?[]const u8 = null,
    /// Stack trace for failures (null if passed)
    stack: ?[]const u8 = null,
    /// Duration in milliseconds
    duration_ms: u64 = 0,

    pub fn deinit(self: *SubtestResult, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        if (self.message) |msg| allocator.free(msg);
        if (self.stack) |stk| allocator.free(stk);
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
        }
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
    \\
    \\(function() {
    \\  'use strict';
    \\
    \\  // Native function for reporting individual test results
    \\  // Signature: __wpt_report_result(name, status, message, stack, duration)
    \\  // status: 0=PASS, 1=FAIL, 2=TIMEOUT, 3=NOTRUN, 4=PRECONDITION_FAILED
    \\
    \\  // Native function for reporting test completion
    \\  // Signature: __wpt_report_completion(status, message)
    \\  // status: 0=OK, 1=ERROR, 2=TIMEOUT
    \\
    \\  // Register callback for individual test results
    \\  add_result_callback(function(test) {
    \\    if (typeof __wpt_report_result === 'function') {
    \\      __wpt_report_result(
    \\        test.name || '',
    \\        test.status,
    \\        test.message || null,
    \\        test.stack || null,
    \\        test.duration || 0
    \\      );
    \\    }
    \\  });
    \\
    \\  // Register callback for test completion
    \\  add_completion_callback(function(tests, harness_status) {
    \\    if (typeof __wpt_report_completion === 'function') {
    \\      __wpt_report_completion(
    \\        harness_status.status,
    \\        harness_status.message || null
    \\      );
    \\    }
    \\  });
    \\
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
