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
//! Options are passed via -D flags to zig build:
//! - `-Dwpt-output=path` - Output directory for results (default: wpt-results/)
//! - `-Dwpt-verbose` - Show each test as it runs
//! - `-Dwpt-parallel=N` - Number of parallel test runners

const std = @import("std");
const config = @import("config.zig");
const test_parser = @import("test_parser.zig");
const test_harness = @import("test_harness.zig");
const browser_context = @import("browser_context.zig");
const result_reporter = @import("result_reporter.zig");

/// Command-line options
pub const Options = struct {
    /// Directory filters (empty = all in-scope categories)
    filters: std.ArrayList([]const u8),
    /// Allocator for managing memory
    allocator: std.mem.Allocator,
    /// Output directory for results
    output_dir: []const u8 = "wpt-results",
    /// Verbose output
    verbose: bool = false,
    /// Number of parallel runners (0 = auto)
    parallel: u32 = 0,
    /// WPT root directory
    wpt_root: []const u8 = "tests/wpt",

    pub fn init(allocator: std.mem.Allocator) Options {
        return Options{
            .filters = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Options) void {
        self.filters.deinit(self.allocator);
    }
};

/// Discovered test file
pub const TestFile = struct {
    /// Path relative to WPT root
    path: []const u8,
    /// File type
    file_type: config.FileType,

    pub fn deinit(self: *TestFile, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
    }
};

/// Discovery result
pub const DiscoveryResult = struct {
    allocator: std.mem.Allocator,
    /// Discovered test files
    test_files: std.ArrayList(TestFile),
    /// Count by file type
    by_type: std.AutoHashMap(config.FileType, usize),
    /// Skipped paths with reasons
    skipped: std.ArrayList(struct { path: []const u8, reason: []const u8 }),

    pub fn init(allocator: std.mem.Allocator) DiscoveryResult {
        return DiscoveryResult{
            .allocator = allocator,
            .test_files = .{},
            .by_type = std.AutoHashMap(config.FileType, usize).init(allocator),
            .skipped = .{},
        };
    }

    pub fn deinit(self: *DiscoveryResult) void {
        for (self.test_files.items) |*tf| {
            tf.deinit(self.allocator);
        }
        self.test_files.deinit(self.allocator);
        self.by_type.deinit();
        for (self.skipped.items) |s| {
            self.allocator.free(s.path);
        }
        self.skipped.deinit(self.allocator);
    }

    pub fn addTestFile(self: *DiscoveryResult, path: []const u8, file_type: config.FileType) !void {
        try self.test_files.append(self.allocator, TestFile{
            .path = try self.allocator.dupe(u8, path),
            .file_type = file_type,
        });

        const entry = try self.by_type.getOrPut(file_type);
        if (!entry.found_existing) {
            entry.value_ptr.* = 0;
        }
        entry.value_ptr.* += 1;
    }
};

/// Parse command-line arguments
pub fn parseArgs(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    var options = Options.init(allocator);
    errdefer options.deinit();

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.startsWith(u8, arg, "--output=")) {
            options.output_dir = arg["--output=".len..];
        } else if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
            options.verbose = true;
        } else if (std.mem.startsWith(u8, arg, "--parallel=")) {
            const value = arg["--parallel=".len..];
            options.parallel = std.fmt.parseInt(u32, value, 10) catch 0;
        } else if (std.mem.startsWith(u8, arg, "--wpt-root=")) {
            options.wpt_root = arg["--wpt-root=".len..];
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            // Directory/file filter
            try options.filters.append(allocator, arg);
        }
    }

    return options;
}

/// Discover test files in WPT tree
pub fn discoverTests(allocator: std.mem.Allocator, options: Options) !DiscoveryResult {
    var result = DiscoveryResult.init(allocator);
    errdefer result.deinit();

    // Determine which directories to scan
    const dirs_to_scan = if (options.filters.items.len > 0)
        options.filters.items
    else blk: {
        // Default: all in-scope categories
        var default_dirs: std.ArrayList([]const u8) = .{};
        for (config.in_scope_categories) |cat| {
            try default_dirs.append(allocator, cat.name);
        }
        break :blk default_dirs.items;
    };

    // Scan each directory
    for (dirs_to_scan) |dir| {
        const full_path = try std.fs.path.join(allocator, &.{ options.wpt_root, dir });
        defer allocator.free(full_path);

        try scanDirectory(allocator, &result, options.wpt_root, full_path, dir);
    }

    return result;
}

/// Recursively scan a directory for test files
fn scanDirectory(
    allocator: std.mem.Allocator,
    result: *DiscoveryResult,
    wpt_root: []const u8,
    full_path: []const u8,
    relative_path: []const u8,
) !void {
    var dir = std.fs.cwd().openDir(full_path, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) {
            // Directory doesn't exist, skip silently
            return;
        }
        return err;
    };
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const entry_path = try std.fs.path.join(allocator, &.{ relative_path, entry.name });
        defer allocator.free(entry_path);

        const full_entry_path = try std.fs.path.join(allocator, &.{ wpt_root, entry_path });
        defer allocator.free(full_entry_path);

        if (entry.kind == .directory) {
            // Skip excluded directories
            if (config.isExcluded(entry_path)) continue;

            // Recurse into subdirectory
            try scanDirectory(allocator, result, wpt_root, full_entry_path, entry_path);
        } else if (entry.kind == .file) {
            // Check if this is a test file
            const file_type = config.FileType.fromPath(entry.name);
            if (file_type == .unknown) continue;

            // Check if excluded
            if (config.isExcluded(entry_path)) continue;

            // Add to results
            try result.addTestFile(entry_path, file_type);
        }
    }
}

/// Execute all discovered tests
pub fn executeTests(
    allocator: std.mem.Allocator,
    discovery: DiscoveryResult,
    options: Options,
    report: *result_reporter.WptReport,
) !void {
    if (options.verbose) {
        print("Running {d} test files...\n\n", .{discovery.test_files.items.len});
    }

    var completed: usize = 0;
    const total = discovery.test_files.items.len;

    for (discovery.test_files.items) |test_file| {
        completed += 1;

        if (options.verbose) {
            print("[{d}/{d}] {s}\n", .{ completed, total, test_file.path });
        }

        // Execute single test file
        const test_result = executeTestFile(allocator, options, test_file) catch |err| {
            // Create error result
            var error_result = try test_harness.TestResult.init(allocator, test_file.path);
            error_result.status = .@"error";
            error_result.message = try std.fmt.allocPrint(allocator, "Execution error: {}", .{err});
            try report.addResult(error_result);
            error_result.deinit(allocator);
            continue;
        };

        try report.addResult(test_result);
    }
}

/// Execute a single test file
fn executeTestFile(
    allocator: std.mem.Allocator,
    options: Options,
    test_file: TestFile,
) !test_harness.TestResult {
    // Read test file content
    const full_path = try std.fs.path.join(allocator, &.{ options.wpt_root, test_file.path });
    defer allocator.free(full_path);

    const content = try std.fs.cwd().readFileAlloc(allocator, full_path, 10 * 1024 * 1024);
    defer allocator.free(content);

    // Parse test file
    var parsed = try test_parser.parseTestFile(allocator, test_file.path, content);
    defer parsed.deinit();

    // Execute in appropriate context(s)
    // For .any.js files, may need to run in multiple contexts
    for (parsed.metadata.globals.items) |global| {
        var ctx = try browser_context.createContextForTest(allocator, options.wpt_root, global);
        defer ctx.deinit();

        // Set test URL
        const test_url = try std.fmt.allocPrint(allocator, "http://web-platform.test:8000/{s}", .{test_file.path});
        defer allocator.free(test_url);
        try ctx.setTestUrl(test_url);

        // Load test harness
        try ctx.loadTestHarness();

        // Load additional scripts
        for (parsed.metadata.scripts.items) |script| {
            if (!script.inline_script) {
                const script_path = try test_parser.resolveScriptPath(
                    allocator,
                    options.wpt_root,
                    test_file.path,
                    script.path,
                );
                defer allocator.free(script_path);
                try ctx.loadScript(script_path);
            }
        }

        // Execute test
        const result = try ctx.executeTest(parsed.content, parsed.metadata.timeout);
        return result;
    }

    // If we get here, no globals were specified (shouldn't happen)
    return error.NoGlobalsSpecified;
}

/// Print progress bar (simplified version using debug.print)
/// TODO: Use proper terminal control codes when integrated with build.zig
fn printProgress(
    current: usize,
    total: usize,
    passed: usize,
    failed: usize,
) void {
    const percent = if (total > 0) (current * 100) / total else 0;
    print("\r[{d}/{d}] {d}% | Pass: {d} | Fail: {d}      ", .{ current, total, percent, passed, failed });
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

    print("Found {d} test files\n", .{discovery.test_files.items.len});

    if (discovery.test_files.items.len == 0) {
        print("No tests found. Check your filter paths.\n", .{});
        return;
    }

    // Print breakdown by type
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

    // Create report
    var report = result_reporter.WptReport.init(allocator);
    defer report.deinit();

    // Execute tests
    print("\nExecuting tests...\n", .{});
    try executeTests(allocator, discovery, options, &report);

    // Finish and write report
    report.finish();

    const output_path = try std.fs.path.join(allocator, &.{ options.output_dir, "wptreport.json" });
    defer allocator.free(output_path);

    try report.writeToFile(output_path);

    // Print summary using debug.print for standalone compatibility
    const summary = report.getSummary();
    print("\n================================\n", .{});
    print("WPT Test Results\n", .{});
    print("================================\n", .{});
    print("Tests:     {d}\n", .{summary.total_tests});
    print("Subtests:  {d}\n", .{summary.total_subtests});
    print("  Passed:  {d} ({d:.1}%)\n", .{ summary.passed_subtests, summary.passRate() });
    print("  Failed:  {d}\n", .{summary.failed_subtests});
    print("  Timeout: {d}\n", .{summary.timeout_subtests});
    print("  NotRun:  {d}\n", .{summary.notrun_subtests});
    print("================================\n", .{});

    print("\nResults written to: {s}\n", .{output_path});
}

test "parseArgs basic" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const args = [_][]const u8{ "url/", "encoding/", "--verbose" };
    var options = try parseArgs(allocator, &args);
    defer options.deinit();

    try testing.expectEqual(@as(usize, 2), options.filters.items.len);
    try testing.expect(options.verbose);
}

test "parseArgs with options" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const args = [_][]const u8{ "--output=results", "--parallel=4", "url/" };
    var options = try parseArgs(allocator, &args);
    defer options.deinit();

    try testing.expectEqualStrings("results", options.output_dir);
    try testing.expectEqual(@as(u32, 4), options.parallel);
    try testing.expectEqual(@as(usize, 1), options.filters.items.len);
}
