//! WPT Result Reporter
//!
//! Generates wptreport.json output in the standard format for wpt.fyi compatibility.
//! This format allows results to be uploaded to wpt.fyi for comparison with browser
//! implementations.
//!
//! ## wptreport.json Format
//!
//! ```json
//! {
//!   "run_info": {
//!     "product": "whatwg-zig",
//!     "browser_version": "1.0.0",
//!     "os": "darwin",
//!     "os_version": "14.0.0",
//!     "processor": "aarch64",
//!     "revision": "abc123"
//!   },
//!   "time_start": 1699000000000,
//!   "time_end": 1699000100000,
//!   "results": [
//!     {
//!       "test": "/url/url-constructor.any.js",
//!       "status": "OK",
//!       "message": null,
//!       "duration": 1234,
//!       "subtests": [
//!         {
//!           "name": "URL constructor, empty string",
//!           "status": "PASS",
//!           "message": null
//!         }
//!       ]
//!     }
//!   ]
//! }
//! ```

const std = @import("std");
const builtin = @import("builtin");
const test_harness = @import("test_harness.zig");
const config = @import("config.zig");

/// Escape a string for JSON output
fn writeJsonString(writer: anytype, str: []const u8) !void {
    try writer.writeByte('"');
    for (str) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            // Other control characters (0x00-0x08, 0x0B, 0x0C, 0x0E-0x1F)
            0x00...0x08, 0x0B, 0x0C, 0x0E...0x1F => {
                try writer.print("\\u{x:0>4}", .{c});
            },
            else => try writer.writeByte(c),
        }
    }
    try writer.writeByte('"');
}

/// Run information for the test report
pub const RunInfo = struct {
    /// Product name (e.g., "whatwg-zig")
    product: []const u8 = "whatwg-zig",
    /// Version of the browser/engine
    browser_version: []const u8 = "0.1.0",
    /// Operating system name
    os: []const u8,
    /// OS version
    os_version: []const u8 = "",
    /// CPU architecture
    processor: []const u8,
    /// Git revision/commit hash
    revision: []const u8 = "",

    pub fn getDefault() RunInfo {
        const os_name = switch (builtin.os.tag) {
            .macos => "darwin",
            .linux => "linux",
            .windows => "windows",
            else => "unknown",
        };

        const processor = switch (builtin.cpu.arch) {
            .x86_64 => "x86_64",
            .aarch64 => "aarch64",
            .x86 => "x86",
            .arm => "arm",
            else => "unknown",
        };

        return RunInfo{
            .os = os_name,
            .processor = processor,
        };
    }

    /// Create RunInfo with git revision detected from repository
    pub fn getWithRevision(allocator: std.mem.Allocator) RunInfo {
        var info = getDefault();

        // Try to get git revision
        const git_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "git", "rev-parse", "--short", "HEAD" },
            .cwd = null,
            .expand_arg0 = .no_expand,
        }) catch {
            return info;
        };
        defer allocator.free(git_result.stdout);
        defer allocator.free(git_result.stderr);

        if (git_result.term.Exited == 0 and git_result.stdout.len > 0) {
            const revision = std.mem.trim(u8, git_result.stdout, &std.ascii.whitespace);
            if (revision.len > 0) {
                info.revision = revision;
            }
        }

        return info;
    }
};

/// Full WPT report structure
pub const WptReport = struct {
    allocator: std.mem.Allocator,
    /// Run environment information
    run_info: RunInfo,
    /// Start time (epoch milliseconds)
    time_start: i64,
    /// End time (epoch milliseconds)
    time_end: i64 = 0,
    /// Test results
    results: std.ArrayList(TestResultJson),

    pub fn init(allocator: std.mem.Allocator) WptReport {
        return WptReport{
            .allocator = allocator,
            .run_info = RunInfo.getDefault(),
            .time_start = std.time.milliTimestamp(),
            .results = .{},
        };
    }

    pub fn deinit(self: *WptReport) void {
        for (self.results.items) |*result| {
            result.deinit(self.allocator);
        }
        self.results.deinit(self.allocator);
    }

    /// Mark the end of the test run
    pub fn finish(self: *WptReport) void {
        self.time_end = std.time.milliTimestamp();
    }

    /// Add a test result from the harness collector
    /// For multi-context tests (e.g., .any.js), the context is appended to the test path
    /// in the format "path/test.any.js [context]" to distinguish different executions.
    pub fn addResult(self: *WptReport, harness_result: test_harness.TestResult) !void {
        // Build test path with context suffix for multi-context tests
        const test_path = if (harness_result.context) |ctx|
            try std.fmt.allocPrint(self.allocator, "{s} [{s}]", .{ harness_result.test_path, ctx })
        else
            try self.allocator.dupe(u8, harness_result.test_path);

        var result = TestResultJson{
            .test_path = test_path,
            .status = harness_result.status.toString(),
            .message = if (harness_result.message) |m| try self.allocator.dupe(u8, m) else null,
            .duration = harness_result.duration_ms,
            .subtests = .{},
        };

        for (harness_result.subtests.items) |sub| {
            try result.subtests.append(self.allocator, SubtestResultJson{
                .name = try self.allocator.dupe(u8, sub.name),
                .status = sub.status.toString(),
                .message = if (sub.message) |m| try self.allocator.dupe(u8, m) else null,
            });
        }

        try self.results.append(self.allocator, result);
    }

    /// Convert to JSON and write to file
    pub fn writeToFile(self: *WptReport, path: []const u8) !void {
        // Ensure output directory exists
        const dir_path = std.fs.path.dirname(path);
        if (dir_path) |dir| {
            std.fs.cwd().makePath(dir) catch |err| {
                if (err != error.PathAlreadyExists) return err;
            };
        }

        // Build JSON string first, then write to file
        var json_buf: std.ArrayList(u8) = .{};
        defer json_buf.deinit(self.allocator);

        try self.writeJsonToArrayList(&json_buf);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        _ = try file.writeAll(json_buf.items);
    }

    /// Write JSON to an ArrayList buffer
    fn writeJsonToArrayList(self: *WptReport, buf: *std.ArrayList(u8)) !void {
        var writer = buf.writer(self.allocator);
        try self.writeJsonInner(&writer);
    }

    /// Write JSON to any writer
    fn writeJsonInner(self: *WptReport, writer: anytype) !void {
        try writer.writeAll("{\n");

        // run_info
        try writer.writeAll("  \"run_info\": {\n");
        try writer.writeAll("    \"product\": ");
        try writeJsonString(writer, self.run_info.product);
        try writer.writeAll(",\n");
        try writer.writeAll("    \"browser_version\": ");
        try writeJsonString(writer, self.run_info.browser_version);
        try writer.writeAll(",\n");
        try writer.writeAll("    \"os\": ");
        try writeJsonString(writer, self.run_info.os);
        try writer.writeAll(",\n");
        try writer.writeAll("    \"os_version\": ");
        try writeJsonString(writer, self.run_info.os_version);
        try writer.writeAll(",\n");
        try writer.writeAll("    \"processor\": ");
        try writeJsonString(writer, self.run_info.processor);
        try writer.writeAll(",\n");
        try writer.writeAll("    \"revision\": ");
        try writeJsonString(writer, self.run_info.revision);
        try writer.writeAll("\n");
        try writer.writeAll("  },\n");

        // timestamps
        try writer.print("  \"time_start\": {d},\n", .{self.time_start});
        try writer.print("  \"time_end\": {d},\n", .{self.time_end});

        // results
        try writer.writeAll("  \"results\": [\n");
        for (self.results.items, 0..) |result, i| {
            try result.writeJson(writer, "    ");
            if (i < self.results.items.len - 1) {
                try writer.writeAll(",");
            }
            try writer.writeAll("\n");
        }
        try writer.writeAll("  ]\n");

        try writer.writeAll("}\n");
    }

    /// Get summary statistics
    pub fn getSummary(self: WptReport) Summary {
        var summary = Summary{};

        for (self.results.items) |result| {
            summary.total_tests += 1;

            // Map status string back to enum (strings are uppercase)
            if (std.mem.eql(u8, result.status, "OK")) {
                // ok - do nothing
            } else if (std.mem.eql(u8, result.status, "ERROR")) {
                summary.error_tests += 1;
            } else if (std.mem.eql(u8, result.status, "TIMEOUT")) {
                summary.timeout_tests += 1;
            }

            for (result.subtests.items) |sub| {
                summary.total_subtests += 1;

                // Map subtest status string back
                if (std.mem.eql(u8, sub.status, "PASS")) {
                    summary.passed_subtests += 1;
                } else if (std.mem.eql(u8, sub.status, "FAIL")) {
                    summary.failed_subtests += 1;
                } else if (std.mem.eql(u8, sub.status, "TIMEOUT")) {
                    summary.timeout_subtests += 1;
                } else {
                    summary.notrun_subtests += 1;
                }
            }
        }

        return summary;
    }
};

/// Test result in JSON format
pub const TestResultJson = struct {
    /// Test path (e.g., "/url/url-constructor.any.js")
    test_path: []const u8,
    /// Overall test status ("OK", "ERROR", "TIMEOUT")
    status: []const u8,
    /// Error message (null if OK)
    message: ?[]const u8 = null,
    /// Duration in milliseconds
    duration: u64 = 0,
    /// Subtest results
    subtests: std.ArrayList(SubtestResultJson),

    pub fn deinit(self: *TestResultJson, allocator: std.mem.Allocator) void {
        allocator.free(self.test_path);
        if (self.message) |m| allocator.free(m);
        for (self.subtests.items) |*sub| {
            sub.deinit(allocator);
        }
        self.subtests.deinit(allocator);
    }

    pub fn writeJson(self: TestResultJson, writer: anytype, indent: []const u8) !void {
        try writer.print("{s}{{\n", .{indent});
        try writer.print("{s}  \"test\": ", .{indent});
        try writeJsonString(writer, self.test_path);
        try writer.writeAll(",\n");
        try writer.print("{s}  \"status\": ", .{indent});
        try writeJsonString(writer, self.status);
        try writer.writeAll(",\n");

        if (self.message) |msg| {
            try writer.print("{s}  \"message\": ", .{indent});
            try writeJsonString(writer, msg);
            try writer.writeAll(",\n");
        } else {
            try writer.print("{s}  \"message\": null,\n", .{indent});
        }

        try writer.print("{s}  \"duration\": {d},\n", .{ indent, self.duration });

        try writer.print("{s}  \"subtests\": [\n", .{indent});
        for (self.subtests.items, 0..) |sub, i| {
            try sub.writeJson(writer, indent);
            if (i < self.subtests.items.len - 1) {
                try writer.writeAll(",");
            }
            try writer.writeAll("\n");
        }
        try writer.print("{s}  ]\n", .{indent});

        try writer.print("{s}}}", .{indent});
    }
};

/// Subtest result in JSON format
pub const SubtestResultJson = struct {
    /// Subtest name
    name: []const u8,
    /// Status ("PASS", "FAIL", "TIMEOUT", "NOTRUN", "PRECONDITION_FAILED")
    status: []const u8,
    /// Failure message (null if passed)
    message: ?[]const u8 = null,

    pub fn deinit(self: *SubtestResultJson, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        if (self.message) |m| allocator.free(m);
    }

    pub fn writeJson(self: SubtestResultJson, writer: anytype, indent: []const u8) !void {
        try writer.print("{s}    {{\"name\": ", .{indent});
        try writeJsonString(writer, self.name);
        try writer.writeAll(", \"status\": ");
        try writeJsonString(writer, self.status);
        if (self.message) |msg| {
            try writer.writeAll(", \"message\": ");
            try writeJsonString(writer, msg);
        } else {
            try writer.writeAll(", \"message\": null");
        }
        try writer.writeAll("}");
    }
};

/// Summary statistics
pub const Summary = struct {
    total_tests: usize = 0,
    error_tests: usize = 0,
    timeout_tests: usize = 0,
    total_subtests: usize = 0,
    passed_subtests: usize = 0,
    failed_subtests: usize = 0,
    timeout_subtests: usize = 0,
    notrun_subtests: usize = 0,

    pub fn passRate(self: Summary) f64 {
        if (self.total_subtests == 0) return 0.0;
        return @as(f64, @floatFromInt(self.passed_subtests)) / @as(f64, @floatFromInt(self.total_subtests)) * 100.0;
    }

    pub fn print(self: Summary, writer: anytype) !void {
        try writer.writeAll("\n================================\n");
        try writer.writeAll("WPT Test Results\n");
        try writer.writeAll("================================\n");
        try writer.print("Tests:     {d}\n", .{self.total_tests});
        try writer.print("Subtests:  {d}\n", .{self.total_subtests});
        try writer.print("  Passed:  {d} ({d:.1}%)\n", .{ self.passed_subtests, self.passRate() });
        try writer.print("  Failed:  {d}\n", .{self.failed_subtests});
        try writer.print("  Timeout: {d}\n", .{self.timeout_subtests});
        try writer.print("  NotRun:  {d}\n", .{self.notrun_subtests});
        try writer.writeAll("================================\n");
    }
};

test "WptReport basic" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var report = WptReport.init(allocator);
    defer report.deinit();

    // Create a mock test result
    var harness_result = try test_harness.TestResult.init(allocator, "url/test.any.js");
    defer harness_result.deinit(allocator);

    harness_result.status = .ok;
    harness_result.duration_ms = 100;

    const subtest = test_harness.SubtestResult{
        .name = try allocator.dupe(u8, "basic test"),
        .status = .pass,
        .duration_ms = 50,
    };
    try harness_result.addSubtest(subtest);

    try report.addResult(harness_result);
    report.finish();

    try testing.expectEqual(@as(usize, 1), report.results.items.len);

    const summary = report.getSummary();
    try testing.expectEqual(@as(usize, 1), summary.total_tests);
    try testing.expectEqual(@as(usize, 1), summary.passed_subtests);
}

test "RunInfo default" {
    const info = RunInfo.getDefault();

    // Should have valid OS and processor
    try std.testing.expect(info.os.len > 0);
    try std.testing.expect(info.processor.len > 0);
}

test "WptReport with context" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var report = WptReport.init(allocator);
    defer report.deinit();

    // Create a test result with context (multi-context test)
    var harness_result = try test_harness.TestResult.initWithContext(allocator, "url/test.any.js", "worker");
    defer harness_result.deinit(allocator);

    harness_result.status = .ok;
    harness_result.duration_ms = 100;

    const subtest = test_harness.SubtestResult{
        .name = try allocator.dupe(u8, "basic test"),
        .status = .pass,
        .duration_ms = 50,
    };
    try harness_result.addSubtest(subtest);

    try report.addResult(harness_result);
    report.finish();

    try testing.expectEqual(@as(usize, 1), report.results.items.len);
    // The test path should include the context suffix
    try testing.expectEqualStrings("url/test.any.js [worker]", report.results.items[0].test_path);
}

test "WptReport multi-context same test" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var report = WptReport.init(allocator);
    defer report.deinit();

    // Create result for window context
    var window_result = try test_harness.TestResult.initWithContext(allocator, "url/test.any.js", "window");
    defer window_result.deinit(allocator);
    window_result.status = .ok;
    window_result.duration_ms = 100;

    // Create result for worker context
    var worker_result = try test_harness.TestResult.initWithContext(allocator, "url/test.any.js", "worker");
    defer worker_result.deinit(allocator);
    worker_result.status = .ok;
    worker_result.duration_ms = 150;

    try report.addResult(window_result);
    try report.addResult(worker_result);
    report.finish();

    // Should have two distinct entries
    try testing.expectEqual(@as(usize, 2), report.results.items.len);
    try testing.expectEqualStrings("url/test.any.js [window]", report.results.items[0].test_path);
    try testing.expectEqualStrings("url/test.any.js [worker]", report.results.items[1].test_path);
}

test "WptReport without context" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var report = WptReport.init(allocator);
    defer report.deinit();

    // Create a test result without context (single-context test like .window.js)
    var harness_result = try test_harness.TestResult.init(allocator, "url/test.window.js");
    defer harness_result.deinit(allocator);

    harness_result.status = .ok;
    harness_result.duration_ms = 100;

    try report.addResult(harness_result);
    report.finish();

    try testing.expectEqual(@as(usize, 1), report.results.items.len);
    // The test path should NOT have a context suffix
    try testing.expectEqualStrings("url/test.window.js", report.results.items[0].test_path);
}
