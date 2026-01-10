///! TestRunner API for WPT (Web Platform Tests)
///!
///! This implements the testRunner API that Chromium's content_shell provides.
///! The testRunner object is injected into the JavaScript global scope and provides
///! methods for test harnesses (like testharness.js) to communicate with the browser.
///!
///! Key methods:
///! - waitUntilDone(): Signal that the test is async and shouldn't exit on page load
///! - notifyDone(): Signal that the test has completed
///! - dumpAsText(): Request text output mode (for testharness.js)
///!
///! Reference: Chromium's content/web_test/renderer/test_runner.cc
const std = @import("std");
const Allocator = std.mem.Allocator;

/// Test result status codes (matches testharness.js)
pub const TestStatus = enum(u8) {
    pass = 0,
    fail = 1,
    timeout = 2,
    not_run = 3,
    precondition_failed = 4,
};

/// Individual test result
pub const TestResult = struct {
    name: []const u8,
    status: TestStatus,
    message: ?[]const u8,
    stack: ?[]const u8,
    duration: ?u64,
};

/// Harness-level status
pub const HarnessStatus = struct {
    status: TestStatus,
    message: ?[]const u8,
};

/// TestRunner state machine
pub const TestRunner = struct {
    allocator: Allocator,

    /// Set by waitUntilDone() - if true, don't complete until notifyDone() is called
    wait_until_done: bool = false,

    /// Set by notifyDone() - signals test completion
    done: bool = false,

    /// Set by dumpAsText() - request text output
    dump_as_text: bool = false,

    /// Collected test results
    results: std.ArrayList(TestResult),

    /// Harness-level status (set when all tests complete)
    harness_status: ?HarnessStatus = null,

    /// Callback to signal completion to the browser
    completion_callback: ?*const fn (*TestRunner) void = null,

    pub fn init(allocator: Allocator) !*TestRunner {
        const self = try allocator.create(TestRunner);
        self.* = .{
            .allocator = allocator,
            .results = std.ArrayList(TestResult).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *TestRunner) void {
        for (self.results.items) |result| {
            self.allocator.free(result.name);
            if (result.message) |msg| self.allocator.free(msg);
            if (result.stack) |stack| self.allocator.free(stack);
        }
        self.results.deinit();
        self.allocator.destroy(self);
    }

    // ========================================================================
    // JavaScript API methods (called from JS bindings)
    // ========================================================================

    /// Called by testharness.js to signal the test is async
    /// The browser should NOT consider the test complete until notifyDone() is called
    pub fn waitUntilDone(self: *TestRunner) void {
        self.wait_until_done = true;
    }

    /// Called by testharness.js when the test is complete
    /// This signals to the browser that it can collect results and exit
    pub fn notifyDone(self: *TestRunner) void {
        self.done = true;
        if (self.completion_callback) |callback| {
            callback(self);
        }
    }

    /// Called by testharness.js to request text output mode
    /// In Chromium, this affects how the page is rendered for comparison
    pub fn dumpAsText(self: *TestRunner) void {
        self.dump_as_text = true;
    }

    /// Add a test result (called by testharnessreport.js via __wpt_report_result)
    pub fn addResult(
        self: *TestRunner,
        name: []const u8,
        status: TestStatus,
        message: ?[]const u8,
        stack: ?[]const u8,
        duration: ?u64,
    ) !void {
        const result = TestResult{
            .name = try self.allocator.dupe(u8, name),
            .status = status,
            .message = if (message) |m| try self.allocator.dupe(u8, m) else null,
            .stack = if (stack) |s| try self.allocator.dupe(u8, s) else null,
            .duration = duration,
        };
        try self.results.append(result);
    }

    /// Set harness status (called when all tests complete)
    pub fn setHarnessStatus(self: *TestRunner, status: TestStatus, message: ?[]const u8) !void {
        self.harness_status = .{
            .status = status,
            .message = if (message) |m| try self.allocator.dupe(u8, m) else null,
        };
    }

    // ========================================================================
    // Browser-side query methods
    // ========================================================================

    /// Check if the test is complete
    /// A test is complete when:
    /// 1. If waitUntilDone() was NOT called: immediately after page load
    /// 2. If waitUntilDone() WAS called: after notifyDone() is called
    pub fn isComplete(self: *const TestRunner) bool {
        if (self.wait_until_done) {
            return self.done;
        }
        // If waitUntilDone wasn't called, we need external signal
        // (e.g., page load complete + no pending work)
        return self.done;
    }

    /// Get pass/fail counts
    pub fn getCounts(self: *const TestRunner) struct { passed: usize, failed: usize, total: usize } {
        var passed: usize = 0;
        var failed: usize = 0;
        for (self.results.items) |result| {
            if (result.status == .pass) {
                passed += 1;
            } else {
                failed += 1;
            }
        }
        return .{ .passed = passed, .failed = failed, .total = self.results.items.len };
    }

    /// Format results as JSON (for output)
    pub fn formatResultsJson(self: *const TestRunner, allocator: Allocator) ![]const u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        const writer = buffer.writer();

        try writer.writeAll("[");

        // Harness status
        if (self.harness_status) |hs| {
            try writer.print("null,{d},", .{@intFromEnum(hs.status)});
            if (hs.message) |msg| {
                try writer.print("\"{s}\",", .{msg});
            } else {
                try writer.writeAll("null,");
            }
        } else {
            try writer.writeAll("null,0,null,");
        }

        try writer.writeAll("null,[");

        // Individual results
        for (self.results.items, 0..) |result, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.print("[\"{s}\",{d},", .{ result.name, @intFromEnum(result.status) });
            if (result.message) |msg| {
                try writer.print("\"{s}\",", .{msg});
            } else {
                try writer.writeAll("null,");
            }
            try writer.writeAll("null]");
        }

        try writer.writeAll("]]");

        return buffer.toOwnedSlice();
    }
};

// ============================================================================
// JavaScript Binding Helpers
// ============================================================================

/// Generate the JavaScript code to inject the testRunner object
/// This creates a global testRunner object that calls back to Zig
pub fn generateTestRunnerScript() []const u8 {
    return 
    \\// testRunner API - Chromium-compatible test harness interface
    \\var testRunner = {
    \\    _waitUntilDone: false,
    \\    _done: false,
    \\    _dumpAsText: false,
    \\    _results: [],
    \\    _harnessStatus: null,
    \\
    \\    // Signal that test is async - don't exit on page load
    \\    waitUntilDone: function() {
    \\        this._waitUntilDone = true;
    \\        if (typeof __testRunner_waitUntilDone === 'function') {
    \\            __testRunner_waitUntilDone();
    \\        }
    \\    },
    \\
    \\    // Signal test completion
    \\    notifyDone: function() {
    \\        console.log("NOTIFY_DONE: testRunner.notifyDone() called!");
    \\        this._done = true;
    \\        if (typeof __testRunner_notifyDone === 'function') {
    \\            __testRunner_notifyDone();
    \\        }
    \\    },
    \\
    \\    // Request text output mode
    \\    dumpAsText: function() {
    \\        this._dumpAsText = true;
    \\        if (typeof __testRunner_dumpAsText === 'function') {
    \\            __testRunner_dumpAsText();
    \\        }
    \\    },
    \\
    \\    // For compatibility - some tests check this
    \\    isChromiumDumpRenderTree: function() { return true; },
    \\    
    \\    // For async tests that use testRunner.wait/resume pattern
    \\    wait: function() { this.waitUntilDone(); },
    \\    resume: function() { this.notifyDone(); },
    \\
    \\    // Chromium testharnessreport.js compatibility stubs
    \\    setPopupBlockingEnabled: function(enabled) { /* stub */ },
    \\    setDumpJavaScriptDialogs: function(enabled) { /* stub */ },
    \\    setDumpConsoleMessages: function(enabled) { /* stub */ },
    \\    overridePreference: function(key, value) { /* stub */ },
    \\    setCloseRemainingWindowsWhenComplete: function(enabled) { /* stub */ },
    \\    setPrinting: function() { /* stub */ },
    \\    setShouldStayOnPageAfterHandlingBeforeUnload: function(enabled) { /* stub */ },
    \\};
    \\
    \\// Also expose on window for scripts that use window.testRunner
    \\window.testRunner = testRunner;
    \\
    \\// WPT-specific reporting functions that testharnessreport.js expects
    \\var __wpt_results = [];
    \\var __wpt_completed = false;
    \\var __wpt_harness_status = null;
    \\
    \\var __wpt_report_result = function(name, status, message, stack, duration) {
    \\    __wpt_results.push({name: name, status: status, message: message, stack: stack, duration: duration});
    \\    testRunner._results.push({name: name, status: status, message: message, stack: stack});
    \\};
    \\
    \\var __wpt_report_completion = function(harness_status) {
    \\    __wpt_completed = true;
    \\    __wpt_harness_status = harness_status;
    \\    testRunner._harnessStatus = harness_status;
    \\    
    \\    // Output results
    \\    var status = harness_status || {status: 0};
    \\    var results = __wpt_results || [];
    \\    var passed = 0;
    \\    for (var i = 0; i < results.length; i++) {
    \\        if (results[i].status === 0) passed++;
    \\    }
    \\    console.log("CRANE_WPT_RESULT: " + passed + "/" + results.length + " passed");
    \\    
    \\    // Signal completion via testRunner
    \\    testRunner.notifyDone();
    \\};
    \\
    \\// Expose on window too
    \\window.__wpt_results = __wpt_results;
    \\window.__wpt_completed = __wpt_completed;
    \\window.__wpt_harness_status = __wpt_harness_status;
    \\window.__wpt_report_result = __wpt_report_result;
    \\window.__wpt_report_completion = __wpt_report_completion;
    \\
    \\// Hook into testharness.js callbacks when it loads
    \\// This needs to run AFTER testharness.js is loaded
    \\window.__crane_register_wpt_callbacks = function() {
    \\    if (typeof add_result_callback === 'function') {
    \\        add_result_callback(function(test) {
    \\            console.log("CRANE_RESULT_CB: " + test.name + " - status=" + test.status);
    \\            __wpt_report_result(test.name, test.status, test.message, test.stack, test.duration);
    \\        });
    \\        console.log("CRANE_SETUP: Registered add_result_callback");
    \\    }
    \\    if (typeof add_completion_callback === 'function') {
    \\        add_completion_callback(function(tests, harness_status) {
    \\            console.log("CRANE_COMPLETE_CB: " + tests.length + " tests, harness_status=" + JSON.stringify(harness_status));
    \\            __wpt_report_completion(harness_status);
    \\        });
    \\        console.log("CRANE_SETUP: Registered add_completion_callback");
    \\    }
    \\};
    ;
}

test "TestRunner basic functionality" {
    const allocator = std.testing.allocator;

    const runner = try TestRunner.init(allocator);
    defer runner.deinit();

    // Initially not complete
    try std.testing.expect(!runner.isComplete());

    // After waitUntilDone, still not complete
    runner.waitUntilDone();
    try std.testing.expect(!runner.isComplete());

    // After notifyDone, complete
    runner.notifyDone();
    try std.testing.expect(runner.isComplete());
}

test "TestRunner results collection" {
    const allocator = std.testing.allocator;

    const runner = try TestRunner.init(allocator);
    defer runner.deinit();

    try runner.addResult("test1", .pass, null, null, 100);
    try runner.addResult("test2", .fail, "assertion failed", null, 50);
    try runner.addResult("test3", .pass, null, null, 75);

    const counts = runner.getCounts();
    try std.testing.expectEqual(@as(usize, 2), counts.passed);
    try std.testing.expectEqual(@as(usize, 1), counts.failed);
    try std.testing.expectEqual(@as(usize, 3), counts.total);
}
