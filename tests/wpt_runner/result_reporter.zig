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

// =============================================================================
// Lone Surrogate Sanitization
// =============================================================================

/// Sanitize lone surrogate characters (U+D800-U+DFFF) in strings for JSON safety.
/// Lone surrogates are replaced with "U+XXXX" notation.
/// This is necessary because lone surrogates are invalid in UTF-8 and can cause
/// JSON encoding issues or display problems in test output.
pub fn sanitizeLoneSurrogates(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    // Fast path: if no multi-byte sequences that could be surrogates, return as-is
    var has_potential_surrogates = false;
    for (input) |c| {
        if (c >= 0xED) {
            has_potential_surrogates = true;
            break;
        }
    }
    if (!has_potential_surrogates) {
        return try allocator.dupe(u8, input);
    }

    var result: std.ArrayList(u8) = .{};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        const byte = input[i];
        // Check if this is the start of a multi-byte sequence
        if (byte < 0x80) {
            // ASCII character
            try result.append(allocator, byte);
            i += 1;
        } else if (byte < 0xC0) {
            // Continuation byte without a start byte - invalid, copy as-is
            try result.append(allocator, byte);
            i += 1;
        } else {
            // Multi-byte sequence start
            const seq_len: usize = if (byte < 0xE0) 2 else if (byte < 0xF0) 3 else 4;

            if (i + seq_len > input.len) {
                // Truncated sequence - copy remaining bytes as-is
                try result.appendSlice(allocator, input[i..]);
                break;
            }

            // Check if this is a valid UTF-8 sequence for a surrogate (U+D800-U+DFFF)
            // Surrogates are encoded as ED A0 80 to ED BF BF in (invalid) UTF-8
            if (seq_len == 3 and byte == 0xED and input[i + 1] >= 0xA0 and input[i + 1] <= 0xBF) {
                // This is a lone surrogate - decode and replace
                const high_bits = @as(u21, input[i + 1] & 0x3F) << 6;
                const low_bits = @as(u21, input[i + 2] & 0x3F);
                const codepoint: u21 = 0xD800 + (high_bits - 0x800) + low_bits;

                // Replace with U+XXXX notation
                var buf: [8]u8 = undefined;
                const notation = std.fmt.bufPrint(&buf, "U+{X:0>4}", .{codepoint}) catch unreachable;
                try result.appendSlice(allocator, notation);
                i += 3;
            } else {
                // Valid UTF-8 sequence - copy as-is
                try result.appendSlice(allocator, input[i .. i + seq_len]);
                i += seq_len;
            }
        }
    }

    return try result.toOwnedSlice(allocator);
}

// =============================================================================
// Expected Failure (XFAIL) Metadata Support
// =============================================================================

/// Expected status for a test or subtest
pub const ExpectedStatus = enum {
    pass,
    fail,
    timeout,
    notrun,
    @"error",

    pub fn fromString(str: []const u8) ?ExpectedStatus {
        const trimmed = std.mem.trim(u8, str, &std.ascii.whitespace);
        if (std.ascii.eqlIgnoreCase(trimmed, "PASS")) return .pass;
        if (std.ascii.eqlIgnoreCase(trimmed, "FAIL")) return .fail;
        if (std.ascii.eqlIgnoreCase(trimmed, "TIMEOUT")) return .timeout;
        if (std.ascii.eqlIgnoreCase(trimmed, "NOTRUN")) return .notrun;
        if (std.ascii.eqlIgnoreCase(trimmed, "ERROR")) return .@"error";
        return null;
    }

    pub fn toString(self: ExpectedStatus) []const u8 {
        return switch (self) {
            .pass => "PASS",
            .fail => "FAIL",
            .timeout => "TIMEOUT",
            .notrun => "NOTRUN",
            .@"error" => "ERROR",
        };
    }

    /// Check if the actual status matches this expected status
    pub fn matches(self: ExpectedStatus, actual_status: []const u8) bool {
        return std.ascii.eqlIgnoreCase(self.toString(), actual_status);
    }
};

/// Expected result for a specific subtest
pub const ExpectedSubtest = struct {
    name: []const u8,
    expected: ExpectedStatus,

    pub fn deinit(self: *ExpectedSubtest, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

/// Expected results parsed from a .ini metadata file
pub const ExpectedResults = struct {
    allocator: std.mem.Allocator,
    /// Expected status for the test file itself (if specified)
    test_expected: ?ExpectedStatus = null,
    /// Expected status for specific subtests (by name)
    subtest_expected: std.StringHashMap(ExpectedStatus),

    pub fn init(allocator: std.mem.Allocator) ExpectedResults {
        return ExpectedResults{
            .allocator = allocator,
            .subtest_expected = std.StringHashMap(ExpectedStatus).init(allocator),
        };
    }

    pub fn deinit(self: *ExpectedResults) void {
        var iter = self.subtest_expected.keyIterator();
        while (iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.subtest_expected.deinit();
    }

    /// Get expected status for a subtest by name
    pub fn getExpectedForSubtest(self: *const ExpectedResults, name: []const u8) ?ExpectedStatus {
        return self.subtest_expected.get(name);
    }

    /// Check if test is in expected-fail directory (simpler approach)
    pub fn isExpectedFailDirectory(test_path: []const u8) bool {
        return std.mem.indexOf(u8, test_path, "expected-fail/") != null;
    }
};

/// Parse a WPT .ini metadata file
/// Format:
/// [test-file.html]
///   [Subtest name]
///     expected: FAIL
pub fn parseIniMetadata(allocator: std.mem.Allocator, content: []const u8) !ExpectedResults {
    var results = ExpectedResults.init(allocator);
    errdefer results.deinit();

    var current_subtest: ?[]const u8 = null;
    var lines = std.mem.splitScalar(u8, content, '\n');

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len == 0) continue;
        if (trimmed[0] == '#') continue; // Comment

        // Check for section header [name]
        if (trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']') {
            const section_name = trimmed[1 .. trimmed.len - 1];

            // Check indentation to determine if this is test or subtest
            const indent = std.mem.indexOfNone(u8, line, " \t") orelse 0;
            if (indent == 0) {
                // Top-level section (test file name) - reset subtest
                current_subtest = null;
            } else {
                // Indented section (subtest name)
                current_subtest = section_name;
            }
        } else if (std.mem.indexOf(u8, trimmed, "expected:")) |_| {
            // Parse expected: VALUE
            if (std.mem.indexOf(u8, trimmed, ":")) |colon_pos| {
                const value = std.mem.trim(u8, trimmed[colon_pos + 1 ..], &std.ascii.whitespace);
                if (ExpectedStatus.fromString(value)) |status| {
                    if (current_subtest) |subtest_name| {
                        // Store expected status for this subtest
                        const key = try allocator.dupe(u8, subtest_name);
                        try results.subtest_expected.put(key, status);
                    } else {
                        // Test-level expected status
                        results.test_expected = status;
                    }
                }
            }
        }
    }

    return results;
}

/// Load expected results for a test file
/// Looks for metadata at:
/// - tests/wpt/infrastructure/metadata/<test-path>.ini
/// - Or detects expected-fail/ directory
pub fn loadExpectedResults(allocator: std.mem.Allocator, wpt_root: []const u8, test_path: []const u8) !?ExpectedResults {
    // Check if in expected-fail directory (simpler approach)
    if (ExpectedResults.isExpectedFailDirectory(test_path)) {
        // All tests in expected-fail should fail
        var results = ExpectedResults.init(allocator);
        results.test_expected = .fail;
        return results;
    }

    // Try to load .ini metadata file
    // WPT infrastructure tests use: infrastructure/metadata/<path>.ini
    const metadata_paths = [_][]const u8{
        "infrastructure/metadata/",
    };

    for (metadata_paths) |prefix| {
        const ini_path = try std.fmt.allocPrint(allocator, "{s}/{s}{s}.ini", .{ wpt_root, prefix, test_path });
        defer allocator.free(ini_path);

        const file = std.fs.cwd().openFile(ini_path, .{}) catch continue;
        defer file.close();

        const content = file.readToEndAlloc(allocator, 1024 * 1024) catch continue;
        defer allocator.free(content);

        return try parseIniMetadata(allocator, content);
    }

    return null;
}

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
        try self.addResultWithExpected(harness_result, null);
    }

    /// Add a test result with optional expected results metadata (for XFAIL tracking)
    pub fn addResultWithExpected(self: *WptReport, harness_result: test_harness.TestResult, expected: ?*const ExpectedResults) !void {
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
            // Check if this subtest has expected status from metadata
            var expected_status: ?[]const u8 = null;
            if (expected) |exp| {
                // Check for subtest-specific expected status
                if (exp.getExpectedForSubtest(sub.name)) |exp_status| {
                    expected_status = try self.allocator.dupe(u8, exp_status.toString());
                } else if (exp.test_expected) |test_exp| {
                    // Fall back to test-level expected status (e.g., expected-fail directory)
                    if (test_exp == .fail) {
                        expected_status = try self.allocator.dupe(u8, test_exp.toString());
                    }
                }
            }

            try result.subtests.append(self.allocator, SubtestResultJson{
                .name = try self.allocator.dupe(u8, sub.name),
                .status = sub.status.toString(),
                .message = if (sub.message) |m| try self.allocator.dupe(u8, m) else null,
                .expected = expected_status,
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
            try result.writeJson(writer, "    ", self.allocator);
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

    pub fn writeJson(self: TestResultJson, writer: anytype, indent: []const u8, allocator: std.mem.Allocator) !void {
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
            try sub.writeJson(writer, indent, allocator);
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
    /// Expected status (if different from default PASS)
    expected: ?[]const u8 = null,

    pub fn deinit(self: *SubtestResultJson, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        if (self.message) |m| allocator.free(m);
        if (self.expected) |e| allocator.free(e);
    }

    pub fn writeJson(self: SubtestResultJson, writer: anytype, indent: []const u8, allocator: std.mem.Allocator) !void {
        try writer.print("{s}    {{\"name\": ", .{indent});

        // Sanitize name for lone surrogates
        const sanitized_name = try sanitizeLoneSurrogates(allocator, self.name);
        defer allocator.free(sanitized_name);
        try writeJsonString(writer, sanitized_name);

        try writer.writeAll(", \"status\": ");
        try writeJsonString(writer, self.status);
        if (self.message) |msg| {
            try writer.writeAll(", \"message\": ");
            // Sanitize message for lone surrogates
            const sanitized_msg = try sanitizeLoneSurrogates(allocator, msg);
            defer allocator.free(sanitized_msg);
            try writeJsonString(writer, sanitized_msg);
        } else {
            try writer.writeAll(", \"message\": null");
        }

        // Include expected field if status differs from expected (for XFAIL tracking)
        if (self.expected) |exp| {
            try writer.writeAll(", \"expected\": ");
            try writeJsonString(writer, exp);
        }

        try writer.writeAll("}");
    }

    /// Check if this result is an expected failure (XFAIL)
    pub fn isExpectedFailure(self: SubtestResultJson) bool {
        if (self.expected) |exp| {
            return std.mem.eql(u8, self.status, exp);
        }
        return false;
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

// =============================================================================
// Lone Surrogate Sanitization Tests
// =============================================================================

test "sanitizeLoneSurrogates - no surrogates" {
    const allocator = std.testing.allocator;

    // ASCII string - no changes
    const result1 = try sanitizeLoneSurrogates(allocator, "hello world");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("hello world", result1);

    // Valid UTF-8 with non-surrogate codepoints - no changes
    const result2 = try sanitizeLoneSurrogates(allocator, "Hello 世界 🌍");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("Hello 世界 🌍", result2);
}

test "sanitizeLoneSurrogates - lone surrogate U+D800" {
    const allocator = std.testing.allocator;

    // U+D800 is encoded as ED A0 80 in (invalid) UTF-8
    const input = "test \xED\xA0\x80 name";
    const result = try sanitizeLoneSurrogates(allocator, input);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("test U+D800 name", result);
}

test "sanitizeLoneSurrogates - lone surrogate U+DFFF" {
    const allocator = std.testing.allocator;

    // U+DFFF is encoded as ED BF BF in (invalid) UTF-8
    const input = "test \xED\xBF\xBF name";
    const result = try sanitizeLoneSurrogates(allocator, input);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("test U+DFFF name", result);
}

test "sanitizeLoneSurrogates - multiple surrogates" {
    const allocator = std.testing.allocator;

    // Multiple surrogates in sequence
    const input = "\xED\xA0\x80\xED\xBF\xBF";
    const result = try sanitizeLoneSurrogates(allocator, input);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("U+D800U+DFFF", result);
}

test "sanitizeLoneSurrogates - mixed content" {
    const allocator = std.testing.allocator;

    // Mix of valid UTF-8 and lone surrogates
    const input = "Start \xED\xA0\x80 middle \xED\xB0\x80 end";
    const result = try sanitizeLoneSurrogates(allocator, input);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Start U+D800 middle U+DC00 end", result);
}

// =============================================================================
// Expected Failure (XFAIL) Metadata Tests
// =============================================================================

test "ExpectedStatus.fromString" {
    try std.testing.expectEqual(ExpectedStatus.pass, ExpectedStatus.fromString("PASS").?);
    try std.testing.expectEqual(ExpectedStatus.fail, ExpectedStatus.fromString("FAIL").?);
    try std.testing.expectEqual(ExpectedStatus.fail, ExpectedStatus.fromString("fail").?);
    try std.testing.expectEqual(ExpectedStatus.fail, ExpectedStatus.fromString("Fail").?);
    try std.testing.expectEqual(ExpectedStatus.timeout, ExpectedStatus.fromString("TIMEOUT").?);
    try std.testing.expectEqual(ExpectedStatus.notrun, ExpectedStatus.fromString("NOTRUN").?);
    try std.testing.expectEqual(@as(?ExpectedStatus, null), ExpectedStatus.fromString("INVALID"));
}

test "ExpectedStatus.matches" {
    try std.testing.expect(ExpectedStatus.fail.matches("FAIL"));
    try std.testing.expect(!ExpectedStatus.fail.matches("PASS"));
    try std.testing.expect(ExpectedStatus.pass.matches("PASS"));
}

test "parseIniMetadata - basic" {
    const allocator = std.testing.allocator;

    const ini_content =
        \\[failing-test.html]
        \\  [Failing test]
        \\    expected: FAIL
    ;

    var results = try parseIniMetadata(allocator, ini_content);
    defer results.deinit();

    // Should have one subtest expected result
    try std.testing.expectEqual(@as(usize, 1), results.subtest_expected.count());
    try std.testing.expectEqual(ExpectedStatus.fail, results.subtest_expected.get("Failing test").?);
}

test "parseIniMetadata - multiple subtests" {
    const allocator = std.testing.allocator;

    const ini_content =
        \\[lone-surrogates.html]
        \\  [failing test with lone surrogate in assert]
        \\    expected: FAIL
        \\
        \\  [failing test with lone surrogate U+d800 in name]
        \\    expected: FAIL
    ;

    var results = try parseIniMetadata(allocator, ini_content);
    defer results.deinit();

    try std.testing.expectEqual(@as(usize, 2), results.subtest_expected.count());
    try std.testing.expectEqual(ExpectedStatus.fail, results.subtest_expected.get("failing test with lone surrogate in assert").?);
    try std.testing.expectEqual(ExpectedStatus.fail, results.subtest_expected.get("failing test with lone surrogate U+d800 in name").?);
}

test "ExpectedResults.isExpectedFailDirectory" {
    // Tests in expected-fail directory should be marked as expected failures
    try std.testing.expect(ExpectedResults.isExpectedFailDirectory("infrastructure/expected-fail/failing-test.html"));
    try std.testing.expect(ExpectedResults.isExpectedFailDirectory("infrastructure/expected-fail/timeout.html"));
    try std.testing.expect(!ExpectedResults.isExpectedFailDirectory("infrastructure/testharness/basic.html"));
    try std.testing.expect(!ExpectedResults.isExpectedFailDirectory("url/url-constructor.any.js"));
}

test "SubtestResultJson.isExpectedFailure" {
    const allocator = std.testing.allocator;

    // Test with expected failure
    var sub1 = SubtestResultJson{
        .name = try allocator.dupe(u8, "Failing test"),
        .status = "FAIL",
        .expected = try allocator.dupe(u8, "FAIL"),
    };
    defer sub1.deinit(allocator);
    try std.testing.expect(sub1.isExpectedFailure());

    // Test with unexpected failure
    var sub2 = SubtestResultJson{
        .name = try allocator.dupe(u8, "Should pass"),
        .status = "FAIL",
        .expected = null,
    };
    defer sub2.deinit(allocator);
    try std.testing.expect(!sub2.isExpectedFailure());

    // Test with expected pass that passed
    var sub3 = SubtestResultJson{
        .name = try allocator.dupe(u8, "Passing test"),
        .status = "PASS",
        .expected = try allocator.dupe(u8, "PASS"),
    };
    defer sub3.deinit(allocator);
    try std.testing.expect(sub3.isExpectedFailure());
}

test "WptReport addResultWithExpected" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var report = WptReport.init(allocator);
    defer report.deinit();

    // Create expected results for expected-fail test
    var expected = ExpectedResults.init(allocator);
    defer expected.deinit();
    expected.test_expected = .fail;

    // Create a mock test result
    var harness_result = try test_harness.TestResult.init(allocator, "infrastructure/expected-fail/failing-test.html");
    defer harness_result.deinit(allocator);

    harness_result.status = .ok;
    harness_result.duration_ms = 100;

    const subtest = test_harness.SubtestResult{
        .name = try allocator.dupe(u8, "Failing test"),
        .status = .fail,
        .duration_ms = 50,
    };
    try harness_result.addSubtest(subtest);

    try report.addResultWithExpected(harness_result, &expected);
    report.finish();

    try testing.expectEqual(@as(usize, 1), report.results.items.len);
    try testing.expectEqual(@as(usize, 1), report.results.items[0].subtests.items.len);

    // The subtest should have expected=FAIL
    const sub = report.results.items[0].subtests.items[0];
    try testing.expect(sub.expected != null);
    try testing.expectEqualStrings("FAIL", sub.expected.?);
    try testing.expect(sub.isExpectedFailure());
}
