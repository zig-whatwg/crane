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
//! Options are passed after `--` to zig build wpt:
//! - `--output=path` - Output directory for results (default: wpt-results/)
//! - `--log-mach` - Show failure details (WPT-compatible verbose mode)
//! - `--log-mach-verbose` - Same as --log-mach
//! - `-v` or `--verbose` - Same as --log-mach
//! - `--parallel=N` - Number of parallel test runners
//! - `--limit=N` - Run only the first N test files (useful for quick iteration)
//! - `--pattern=GLOB` - Only run tests matching glob pattern (e.g., "*constructor*")
//! - `--timeout-multiplier=N` - Multiply all timeouts by N (e.g., 2.0 for slow CI)
//! - `--exclude=PATTERN` - Exclude tests matching glob pattern (can be used multiple times)

const std = @import("std");
const config = @import("config.zig");
const test_parser = @import("test_parser.zig");
const test_harness = @import("test_harness.zig");
const browser_adapter = @import("browser_adapter.zig");
const result_reporter = @import("result_reporter.zig");
const wpt_server = @import("wpt_server.zig");
const parallel = @import("parallel.zig");

/// Thread-local verbose flag for log filtering
var verbose_mode: bool = false;

/// Custom log function that suppresses error logs in non-verbose mode.
/// This prevents V8 engine errors from cluttering the test output.
pub const std_options: std.Options = .{
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

/// Output format options
pub const OutputFormat = enum {
    json, // wptreport.json (default)
    xunit, // xunit.xml (JUnit-compatible)
    both, // Generate both formats

    pub fn fromString(str: []const u8) ?OutputFormat {
        if (std.mem.eql(u8, str, "json")) return .json;
        if (std.mem.eql(u8, str, "xunit")) return .xunit;
        if (std.mem.eql(u8, str, "both")) return .both;
        return null;
    }
};

/// Command-line options
pub const Options = struct {
    /// Directory filters (empty = all in-scope categories)
    filters: std.ArrayList([]const u8),
    /// Allocator for managing memory
    allocator: std.mem.Allocator,
    /// Output directory for results
    output_dir: []const u8 = "wpt-results",
    /// Verbose output (--log-mach or -v)
    verbose: bool = false,
    /// Number of parallel runners (0 = auto)
    parallel: u32 = 0,
    /// WPT root directory
    wpt_root: []const u8 = "tests/wpt",
    /// Specific test files to run (overrides directory filters)
    specific_files: std.ArrayList([]const u8),
    /// Maximum number of test files to run (0 = no limit)
    limit: usize = 0,
    /// Glob pattern to filter test names (e.g., "*constructor*")
    pattern: ?[]const u8 = null,
    /// Timeout multiplier (1.0 = normal, 2.0 = double, etc.)
    timeout_multiplier: f32 = 1.0,
    /// Exclusion patterns (applied after includes)
    excludes: std.ArrayList([]const u8),
    /// Output format (json, xunit, both)
    output_format: OutputFormat = .json,
    /// Run each test N times (default 1)
    repeat: u32 = 1,
    /// Retry unexpected failures up to N times (default 0)
    retry_unexpected: u32 = 0,

    pub fn init(allocator: std.mem.Allocator) Options {
        return Options{
            .filters = .{},
            .specific_files = .{},
            .excludes = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Options) void {
        for (self.filters.items) |f| {
            self.allocator.free(f);
        }
        self.filters.deinit(self.allocator);
        for (self.specific_files.items) |f| {
            self.allocator.free(f);
        }
        self.specific_files.deinit(self.allocator);
        for (self.excludes.items) |e| {
            self.allocator.free(e);
        }
        self.excludes.deinit(self.allocator);
    }

    /// Get adjusted timeout in milliseconds based on timeout_multiplier
    pub fn getAdjustedTimeout(self: Options, base_timeout: config.Timeout) u64 {
        const base_ms: f64 = @floatFromInt(base_timeout.toMillis());
        const adjusted: u64 = @intFromFloat(base_ms * self.timeout_multiplier);
        return if (adjusted > 0) adjusted else 1; // Minimum 1ms
    }

    /// Check if a path matches any exclusion pattern
    pub fn isExcluded(self: Options, test_path: []const u8) bool {
        for (self.excludes.items) |exclude_pattern| {
            if (globMatch(test_path, exclude_pattern) or globMatch(std.fs.path.basename(test_path), exclude_pattern)) {
                return true;
            }
        }
        return false;
    }

    /// Check if a test path matches the filters
    pub fn matchesFilter(self: Options, test_path: []const u8) bool {
        // If specific files are specified, only those match
        if (self.specific_files.items.len > 0) {
            for (self.specific_files.items) |file| {
                if (std.mem.eql(u8, test_path, file)) {
                    return true;
                }
            }
            return false;
        }

        // If no filters, everything matches
        if (self.filters.items.len == 0) {
            return true;
        }

        // Check if path starts with any filter
        for (self.filters.items) |filter| {
            const clean_filter = std.mem.trimRight(u8, filter, "/");
            if (std.mem.startsWith(u8, test_path, clean_filter)) {
                // Make sure it's a proper prefix (followed by / or end of string)
                if (test_path.len == clean_filter.len) return true;
                if (test_path.len > clean_filter.len and test_path[clean_filter.len] == '/') return true;
            }
        }
        return false;
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

/// Skipped file entry with reason
pub const SkippedEntry = struct {
    path: []const u8,
    reason: []const u8,

    pub fn deinit(self: *SkippedEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        // reason is a static string, don't free
    }
};

/// Discovery result
pub const DiscoveryResult = struct {
    allocator: std.mem.Allocator,
    /// Discovered test files
    test_files: std.ArrayList(TestFile),
    /// Count by file type
    by_type: std.AutoHashMap(config.FileType, usize),
    /// Count by category (first path component)
    by_category: std.StringHashMap(usize),
    /// Skipped paths with reasons
    skipped: std.ArrayList(SkippedEntry),
    /// Total directories scanned
    directories_scanned: usize = 0,

    pub fn init(allocator: std.mem.Allocator) DiscoveryResult {
        return DiscoveryResult{
            .allocator = allocator,
            .test_files = .{},
            .by_type = std.AutoHashMap(config.FileType, usize).init(allocator),
            .by_category = std.StringHashMap(usize).init(allocator),
            .skipped = .{},
        };
    }

    pub fn deinit(self: *DiscoveryResult) void {
        for (self.test_files.items) |*tf| {
            tf.deinit(self.allocator);
        }
        self.test_files.deinit(self.allocator);
        self.by_type.deinit();
        // Free the duped category keys
        var cat_iter = self.by_category.keyIterator();
        while (cat_iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.by_category.deinit();
        for (self.skipped.items) |*s| {
            s.deinit(self.allocator);
        }
        self.skipped.deinit(self.allocator);
    }

    pub fn addTestFile(self: *DiscoveryResult, path: []const u8, file_type: config.FileType) !void {
        try self.test_files.append(self.allocator, TestFile{
            .path = try self.allocator.dupe(u8, path),
            .file_type = file_type,
        });

        // Count by type
        const type_entry = try self.by_type.getOrPut(file_type);
        if (!type_entry.found_existing) {
            type_entry.value_ptr.* = 0;
        }
        type_entry.value_ptr.* += 1;

        // Count by category (first path component)
        if (std.mem.indexOf(u8, path, "/")) |sep_pos| {
            const category = path[0..sep_pos];
            // Check if this category already exists first (avoid duplicate key issue)
            if (self.by_category.getPtr(category)) |count| {
                count.* += 1;
            } else {
                // Need to dupe the key since path will be freed
                const duped_key = try self.allocator.dupe(u8, category);
                try self.by_category.put(duped_key, 1);
            }
        }
    }

    pub fn addSkipped(self: *DiscoveryResult, path: []const u8, reason: []const u8) !void {
        try self.skipped.append(self.allocator, SkippedEntry{
            .path = try self.allocator.dupe(u8, path),
            .reason = reason,
        });
    }

    /// Get total count of discovered tests
    pub fn totalCount(self: DiscoveryResult) usize {
        return self.test_files.items.len;
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
        } else if (std.mem.eql(u8, arg, "--log-mach") or
            std.mem.startsWith(u8, arg, "--log-mach=") or
            std.mem.eql(u8, arg, "--log-mach-verbose") or
            std.mem.eql(u8, arg, "--verbose") or
            std.mem.eql(u8, arg, "-v"))
        {
            // WPT-compatible: --log-mach enables human-readable output with failure details
            options.verbose = true;
        } else if (std.mem.startsWith(u8, arg, "--parallel=")) {
            const value = arg["--parallel=".len..];
            options.parallel = std.fmt.parseInt(u32, value, 10) catch 0;
        } else if (std.mem.startsWith(u8, arg, "--wpt-root=")) {
            options.wpt_root = arg["--wpt-root=".len..];
        } else if (std.mem.startsWith(u8, arg, "--limit=")) {
            const value = arg["--limit=".len..];
            options.limit = std.fmt.parseInt(usize, value, 10) catch 0;
        } else if (std.mem.startsWith(u8, arg, "--pattern=")) {
            options.pattern = arg["--pattern=".len..];
        } else if (std.mem.startsWith(u8, arg, "--timeout-multiplier=")) {
            const value = arg["--timeout-multiplier=".len..];
            options.timeout_multiplier = std.fmt.parseFloat(f32, value) catch 1.0;
        } else if (std.mem.startsWith(u8, arg, "--exclude=")) {
            const pattern = arg["--exclude=".len..];
            try options.excludes.append(allocator, try allocator.dupe(u8, pattern));
        } else if (std.mem.startsWith(u8, arg, "--output-format=")) {
            const value = arg["--output-format=".len..];
            if (OutputFormat.fromString(value)) |format| {
                options.output_format = format;
            } else {
                print("Warning: Unknown output format '{s}', using default 'json'\n", .{value});
            }
        } else if (std.mem.startsWith(u8, arg, "--repeat=")) {
            const value = arg["--repeat=".len..];
            options.repeat = std.fmt.parseInt(u32, value, 10) catch 1;
            if (options.repeat == 0) options.repeat = 1; // Minimum 1
        } else if (std.mem.startsWith(u8, arg, "--retry-unexpected=")) {
            const value = arg["--retry-unexpected=".len..];
            options.retry_unexpected = std.fmt.parseInt(u32, value, 10) catch 0;
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            // Directory or file filter
            // Check if it's a specific file (has extension) or a directory
            if (isTestFile(arg)) {
                try options.specific_files.append(allocator, try allocator.dupe(u8, arg));
            } else {
                try options.filters.append(allocator, try allocator.dupe(u8, arg));
            }
        }
    }

    return options;
}

/// Check if a path looks like a test file
fn isTestFile(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".any.js") or
        std.mem.endsWith(u8, path, ".window.js") or
        std.mem.endsWith(u8, path, ".worker.js") or
        std.mem.endsWith(u8, path, ".html") or
        std.mem.endsWith(u8, path, ".htm");
}

/// Discover test files in WPT tree
pub fn discoverTests(allocator: std.mem.Allocator, options: Options) !DiscoveryResult {
    var result = DiscoveryResult.init(allocator);
    errdefer result.deinit();

    // If specific files are specified, just verify they exist and return them
    if (options.specific_files.items.len > 0) {
        for (options.specific_files.items) |file_path| {
            const full_path = try std.fs.path.join(allocator, &.{ options.wpt_root, file_path });
            defer allocator.free(full_path);

            // Check if file exists
            std.fs.cwd().access(full_path, .{}) catch {
                print("Warning: Test file not found: {s}\n", .{file_path});
                continue;
            };

            const file_type = config.FileType.fromPath(file_path);
            if (file_type == .unknown) {
                print("Warning: Unknown test file type: {s}\n", .{file_path});
                continue;
            }

            try result.addTestFile(file_path, file_type);
        }
        return result;
    }

    // Determine which directories to scan
    var owns_dirs = false;
    var default_dirs: std.ArrayList([]const u8) = .{};
    defer if (owns_dirs) default_dirs.deinit(allocator);

    const dirs_to_scan = if (options.filters.items.len > 0)
        options.filters.items
    else blk: {
        // Default: all in-scope categories
        owns_dirs = true;
        for (config.in_scope_categories) |cat| {
            try default_dirs.append(allocator, cat.name);
        }
        break :blk default_dirs.items;
    };

    // Validate directories exist before scanning
    for (dirs_to_scan) |dir| {
        const clean_dir = std.mem.trimRight(u8, dir, "/");
        const full_path = try std.fs.path.join(allocator, &.{ options.wpt_root, clean_dir });
        defer allocator.free(full_path);

        std.fs.cwd().access(full_path, .{}) catch {
            print("Warning: Directory not found: {s}\n", .{clean_dir});
            print("  Available categories: ", .{});
            for (config.in_scope_categories, 0..) |cat, i| {
                if (i > 0) print(", ", .{});
                print("{s}", .{cat.name});
            }
            print("\n", .{});
            continue;
        };
    }

    // Scan each directory
    for (dirs_to_scan) |dir| {
        // Handle both "url/" and "url" formats
        const clean_dir = std.mem.trimRight(u8, dir, "/");
        const full_path = try std.fs.path.join(allocator, &.{ options.wpt_root, clean_dir });
        defer allocator.free(full_path);

        try scanDirectory(allocator, &result, options.wpt_root, full_path, clean_dir, options.pattern, options);

        // Check if we've hit the limit
        if (options.limit > 0 and result.test_files.items.len >= options.limit) {
            break;
        }
    }

    // Apply limit after scanning (in case pattern filtered some out)
    if (options.limit > 0 and result.test_files.items.len > options.limit) {
        // Free excess test files
        for (result.test_files.items[options.limit..]) |*tf| {
            tf.deinit(allocator);
        }
        result.test_files.shrinkRetainingCapacity(options.limit);
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
    pattern: ?[]const u8,
    options: Options,
) !void {
    var dir = std.fs.cwd().openDir(full_path, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) {
            // Directory doesn't exist, skip silently
            return;
        }
        return err;
    };
    defer dir.close();

    result.directories_scanned += 1;

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const entry_path = try std.fs.path.join(allocator, &.{ relative_path, entry.name });
        defer allocator.free(entry_path);

        const full_entry_path = try std.fs.path.join(allocator, &.{ wpt_root, entry_path });
        defer allocator.free(full_entry_path);

        if (entry.kind == .directory) {
            // Skip excluded directories
            if (config.isExcluded(entry_path)) {
                try result.addSkipped(entry_path, "excluded directory");
                continue;
            }

            // Recurse into subdirectory
            try scanDirectory(allocator, result, wpt_root, full_entry_path, entry_path, pattern, options);
        } else if (entry.kind == .file) {
            // Check if this is a test file
            const file_type = config.FileType.fromPath(entry.name);
            if (file_type == .unknown) continue;

            // Check if excluded by config patterns
            if (config.isExcluded(entry_path)) {
                try result.addSkipped(entry_path, "excluded by pattern");
                continue;
            }

            // Check if excluded by CLI --exclude patterns
            if (options.isExcluded(entry_path)) {
                try result.addSkipped(entry_path, "excluded by --exclude");
                continue;
            }

            // Check if matches pattern filter (if specified)
            if (pattern) |p| {
                if (!globMatch(entry_path, p) and !globMatch(entry.name, p)) {
                    try result.addSkipped(entry_path, "pattern mismatch");
                    continue;
                }
            }

            // Add to results
            try result.addTestFile(entry_path, file_type);
        }
    }
}

/// Simple glob matching supporting * wildcards
/// Matches patterns like "*constructor*", "url-*", etc.
fn globMatch(str: []const u8, pattern: []const u8) bool {
    var s_idx: usize = 0;
    var p_idx: usize = 0;
    var star_idx: ?usize = null;
    var match_idx: usize = 0;

    while (s_idx < str.len) {
        if (p_idx < pattern.len and (pattern[p_idx] == '?' or pattern[p_idx] == str[s_idx])) {
            // Characters match or pattern has ?
            s_idx += 1;
            p_idx += 1;
        } else if (p_idx < pattern.len and pattern[p_idx] == '*') {
            // Star matches zero or more characters
            star_idx = p_idx;
            match_idx = s_idx;
            p_idx += 1;
        } else if (star_idx) |si| {
            // Mismatch, but we have a star to backtrack to
            p_idx = si + 1;
            match_idx += 1;
            s_idx = match_idx;
        } else {
            // No match
            return false;
        }
    }

    // Check remaining pattern characters (must all be *)
    while (p_idx < pattern.len and pattern[p_idx] == '*') {
        p_idx += 1;
    }

    return p_idx == pattern.len;
}

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
    skipped: usize = 0,
    flaky: usize = 0,
    start_time: i64,
    verbose: bool,
    /// Failures by category for summary
    failures_by_category: std.StringHashMap(usize),

    pub fn init(allocator: std.mem.Allocator, total: usize, verbose: bool) ProgressTracker {
        return ProgressTracker{
            .allocator = allocator,
            .total = total,
            .start_time = std.time.milliTimestamp(),
            .verbose = verbose,
            .failures_by_category = std.StringHashMap(usize).init(allocator),
        };
    }

    pub fn deinit(self: *ProgressTracker) void {
        self.failures_by_category.deinit();
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

        // Count by test status (only count as error if not expected)
        switch (result.status) {
            .ok => {},
            .@"error" => {
                if (!is_expected_error) {
                    self.errors += 1;
                }
            },
            .timeout => self.timeouts += 1,
            .skip => self.skipped += 1,
        }

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
                .pass => self.passed += 1,
                .fail => {
                    if (is_expected_fail) {
                        // Expected failure counts as pass
                        self.passed += 1;
                    } else {
                        self.failed += 1;
                        // Track failures by category
                        if (std.mem.indexOf(u8, test_path, "/")) |sep_pos| {
                            const category = test_path[0..sep_pos];
                            const entry = self.failures_by_category.getOrPut(category) catch continue;
                            if (!entry.found_existing) {
                                entry.value_ptr.* = 0;
                            }
                            entry.value_ptr.* += 1;
                        }
                        // Print failure details in verbose mode
                        if (self.verbose) {
                            print("\n  ✗ FAIL: {s}\n", .{sub.name});
                            if (sub.message) |msg| {
                                print("    Message: {s}\n", .{msg});
                            }
                            if (sub.stack) |stack| {
                                // Print first 3 lines of stack
                                var line_count: usize = 0;
                                var iter = std.mem.splitScalar(u8, stack, '\n');
                                while (iter.next()) |line| {
                                    if (line_count >= 3) {
                                        print("    ...\n", .{});
                                        break;
                                    }
                                    if (line.len > 0) {
                                        print("    {s}\n", .{line});
                                        line_count += 1;
                                    }
                                }
                            }
                        }
                    }
                },
                .timeout => self.timeouts += 1,
                .notrun, .precondition_failed => self.notrun += 1,
            }
        }
    }

    /// Print progress with optional context suffix
    /// For single-context tests: [X/Y] path/test.any.js
    /// For multi-context tests: [X/Y] path/test.any.js [worker]
    pub fn printProgress(self: *ProgressTracker, current_test: []const u8) void {
        self.printProgressWithContext(current_test, null);
    }

    /// Print progress with explicit context
    pub fn printProgressWithContext(self: *ProgressTracker, current_test: []const u8, context: ?[]const u8) void {
        // Build display name with context suffix if present
        var display_buf: [256]u8 = undefined;
        const display_name = if (context) |ctx| blk: {
            const len = std.fmt.bufPrint(&display_buf, "{s} [{s}]", .{ current_test, ctx }) catch current_test;
            break :blk len;
        } else current_test;

        if (self.verbose) {
            print("[{d}/{d}] {s}\n", .{ self.completed, self.total, display_name });
        } else {
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

        print("\n================================\n", .{});
        print("WPT Test Results\n", .{});
        print("================================\n", .{});
        print("Test files: {d}\n", .{self.total});
        print("  Completed: {d}\n", .{self.completed});
        print("  Errors:    {d}\n", .{self.errors});
        print("  Timeouts:  {d}\n", .{self.timeouts});
        if (self.skipped > 0) {
            print("  Skipped:   {d} (reftests/not implemented)\n", .{self.skipped});
        }
        print("\n", .{});
        print("Subtests:   {d} / {d}\n", .{ self.passed, total_subtests });
        if (total_subtests > 0) {
            const pass_rate = @as(f64, @floatFromInt(self.passed)) / @as(f64, @floatFromInt(total_subtests)) * 100.0;
            print("  Passed:   {d} ({d:.1}%)\n", .{ self.passed, pass_rate });
        } else {
            print("  Passed:   {d}\n", .{self.passed});
        }
        print("  Failed:   {d}\n", .{self.failed});
        print("  Timeout:  {d}\n", .{self.timeouts});
        if (self.notrun > 0) {
            print("  Not Run:  {d}\n", .{self.notrun});
        }
        if (self.flaky > 0) {
            print("  Flaky:    {d}\n", .{self.flaky});
        }
        print("\n", .{});
        print("Duration:   {s}\n", .{elapsed});

        // Top failing categories
        if (self.failures_by_category.count() > 0) {
            print("\nTop Failing Categories:\n", .{});

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
            for (entries[0..to_print]) |entry| {
                print("  {s}/: {d} failures\n", .{ entry.cat, entry.count });
            }
        }

        print("\nResults written to: {s}\n", .{output_path});
        print("================================\n", .{});
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

        // Multiply by variant count (each context runs once per variant)
        const variant_count = if (parsed.metadata.variants.items.len > 0)
            parsed.metadata.variants.items.len
        else
            1;

        // If no implemented contexts, we still count it as 1 (will skip execution)
        const effective_count = if (context_count > 0) context_count * variant_count else 1;
        total += effective_count;
    }

    return total;
}

/// Build work items for parallel execution
/// Each work item is a test file + context combination
fn buildWorkItems(
    allocator: std.mem.Allocator,
    discovery: DiscoveryResult,
    options: Options,
) ![]parallel.WorkItem {
    var items: std.ArrayList(parallel.WorkItem) = .{};
    errdefer {
        for (items.items) |*item| {
            allocator.free(item.parsed_content);
            item.metadata.deinit();
        }
        items.deinit(allocator);
    }

    for (discovery.test_files.items) |test_file| {
        // Load content
        const content = loadTestContent(allocator, options, test_file) catch |err| {
            std.debug.print("Warning: Failed to load {s}: {}\n", .{ test_file.path, err });
            continue;
        };
        errdefer allocator.free(content);

        // Parse to get metadata
        var parsed = test_parser.parseTestFile(allocator, test_file.path, content) catch |err| {
            std.debug.print("Warning: Failed to parse {s}: {}\n", .{ test_file.path, err });
            allocator.free(content);
            continue;
        };

        // Create work item for each implemented context and variant combination
        // If no variants specified, run once with null variant
        const variants_to_run = if (parsed.metadata.variants.items.len > 0)
            parsed.metadata.variants.items
        else
            @as([]const []const u8, &.{});

        for (parsed.metadata.globals.items) |ctx| {
            if (!ctx.isImplemented()) continue;

            const context_name: ?[]const u8 = if (parsed.metadata.globals.items.len > 1)
                ctx.toString()
            else
                null;

            // If we have variants, create a work item for each variant
            // Otherwise, create a single work item with null variant
            const variant_count = if (variants_to_run.len > 0) variants_to_run.len else 1;

            for (0..variant_count) |variant_idx| {
                const variant: ?[]const u8 = if (variants_to_run.len > 0)
                    variants_to_run[variant_idx]
                else
                    null;

                // Clone metadata for this work item
                var cloned_metadata = test_parser.TestMetadata.init(allocator);
                cloned_metadata.timeout = parsed.metadata.timeout;
                for (parsed.metadata.globals.items) |g| {
                    try cloned_metadata.globals.append(allocator, g);
                }
                for (parsed.metadata.scripts.items) |s| {
                    try cloned_metadata.scripts.append(allocator, test_parser.ScriptRef{
                        .path = try allocator.dupe(u8, s.path),
                        .inline_script = s.inline_script,
                        .script_type = if (s.script_type) |t| try allocator.dupe(u8, t) else null,
                    });
                }

                try items.append(allocator, parallel.WorkItem{
                    .test_file = test_file,
                    .context = ctx,
                    .context_name = context_name,
                    .parsed_content = try allocator.dupe(u8, content),
                    .metadata = cloned_metadata,
                    .variant = if (variant) |v| try allocator.dupe(u8, v) else null,
                });
            }
        }

        // Free original content and parsed (we duped what we need)
        allocator.free(content);
        parsed.deinit();
    }

    return items.toOwnedSlice(allocator);
}

/// Execute all discovered tests
pub fn executeTests(
    allocator: std.mem.Allocator,
    discovery: DiscoveryResult,
    options: Options,
    report: *result_reporter.WptReport,
    server: *wpt_server.WptServer,
) !void {
    // Use parallel execution if requested
    if (options.parallel > 0 or options.parallel == 0) {
        // Build work items
        const work_items = try buildWorkItems(allocator, discovery, options);
        defer {
            for (work_items) |*item| {
                var mutable_item = item.*;
                allocator.free(mutable_item.parsed_content);
                mutable_item.metadata.deinit();
            }
            allocator.free(work_items);
        }

        if (work_items.len == 0) {
            print("No tests to run.\n", .{});
            return;
        }

        // Only use parallel execution if explicitly requested (parallel > 0)
        if (options.parallel > 0) {
            return parallel.executeTestsParallel(allocator, work_items, options, report, server);
        }
    }

    // Sequential execution (default)
    // Calculate total accounting for multi-context execution
    // This requires parsing all files upfront, but gives accurate progress tracking
    const total = try calculateTotalTests(allocator, discovery, options);
    const file_count = discovery.test_files.items.len;
    print("\nRunning {d} test files ({d} total test runs)...\n\n", .{ file_count, total });

    // Create a single BrowserAdapter for all tests (single V8 isolate, new context per navigation)
    // This is much more efficient than creating a new isolate per test (~1-5ms vs ~50-100ms)
    var browser = try browser_adapter.BrowserAdapter.init(allocator, options.wpt_root);
    defer browser.deinit();

    var progress = ProgressTracker.init(allocator, total, options.verbose);
    defer progress.deinit();

    for (discovery.test_files.items) |test_file| {
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

            // Calculate adjusted timeout based on multiplier
            const timeout_ms = options.getAdjustedTimeout(parsed.metadata.timeout);

            // Execute test with retry support
            // --repeat=N: run N times (report final result, track flakiness)
            // --retry-unexpected=N: retry on failure up to N times (for CI stability)
            var final_result: ?test_harness.TestResult = null;
            var total_runs: u32 = 0;
            var failures_before_pass: u32 = 0;
            var had_execution_error = false;

            repeat_loop: for (0..options.repeat) |_| {
                // Reset for retry loop within each repeat iteration
                var retry_count: u32 = 0;

                retry_loop: while (true) {
                    total_runs += 1;

                    // Execute test in this context
                    const test_result = executeTestFileInContext(
                        allocator,
                        test_file,
                        browser,
                        global_context,
                        context_name,
                        server,
                        timeout_ms,
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

                        // Check if we should retry
                        if (retry_count < options.retry_unexpected) {
                            retry_count += 1;
                            failures_before_pass += 1;
                            error_result.deinit(allocator);
                            if (options.verbose) {
                                print("  Retrying ({d}/{d})...\n", .{ retry_count, options.retry_unexpected });
                            }
                            continue :retry_loop;
                        }

                        // No more retries, record as final result
                        had_execution_error = true;
                        if (final_result) |*prev| {
                            prev.deinit(allocator);
                        }
                        final_result = error_result;
                        break :repeat_loop;
                    };

                    // Check if test passed or if we should retry
                    if (test_result.hasUnexpectedFailures() and retry_count < options.retry_unexpected) {
                        retry_count += 1;
                        failures_before_pass += 1;
                        var mutable = test_result;
                        mutable.deinit(allocator);
                        if (options.verbose) {
                            print("  Retrying ({d}/{d})...\n", .{ retry_count, options.retry_unexpected });
                        }
                        continue :retry_loop;
                    }

                    // Update final result (keep the last one)
                    if (final_result) |*prev| {
                        prev.deinit(allocator);
                    }
                    final_result = test_result;
                    break :retry_loop;
                }
            }

            // Process final result
            if (final_result) |test_result| {
                // Record result with expected status metadata for proper counting
                if (expected_results) |*exp| {
                    progress.recordResultWithExpected(test_file.path, test_result, exp);
                } else {
                    progress.recordResult(test_file.path, test_result);
                }
                progress.printProgressWithContext(test_file.path, context_name);

                // Add result with retry metadata
                if (expected_results) |*exp| {
                    try report.addResultWithExpectedAndRetry(test_result, exp, total_runs, failures_before_pass);
                } else {
                    try report.addResultWithRetry(test_result, total_runs, failures_before_pass);
                }

                // Clean up the test result (addResult copies the data)
                var mutable_result = test_result;
                mutable_result.deinit(allocator);
            } else if (had_execution_error) {
                // Error case already handled above
            }
        }
    }

    // Generate output path
    const output_path = try std.fs.path.join(allocator, &.{ options.output_dir, "wptreport.json" });
    defer allocator.free(output_path);

    progress.printSummary(output_path);
}

/// Execute a single test file in a specific context using the shared BrowserAdapter
/// This function is called once per context (e.g., window, worker) for each test file.
/// File content and parsed metadata are passed in to avoid re-loading/re-parsing.
/// context_name is the string to include in results (null for single-context tests).
/// timeout_ms is the adjusted timeout in milliseconds (after applying timeout_multiplier).
fn executeTestFileInContext(
    allocator: std.mem.Allocator,
    test_file: TestFile,
    browser: *browser_adapter.BrowserAdapter,
    context: test_parser.GlobalType,
    context_name: ?[]const u8,
    server: *wpt_server.WptServer,
    timeout_ms: u64,
) !test_harness.TestResult {
    // For HTML files, fetch from HTTP server and let the browser handle it properly
    // This enables proper resource loading via wpt serve (URL rewrites, headers, etc.)
    if (test_file.file_type == .html) {
        // Build HTTP URL for this test
        const test_url = try server.buildTestUrl(allocator, test_file.path, .window, null);
        defer allocator.free(test_url);

        // Fetch and run from HTTP URL
        // The wpt serve handles proper resource serving (testharness.js, etc.)
        var result = try browser.runTestFromUrl(test_url, test_file.path, timeout_ms, .window);

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
    const test_url = try server.buildTestUrl(allocator, test_file.path, context, null);
    defer allocator.free(test_url);

    // Fetch and run from HTTP URL
    var result = try browser.runTestFromUrl(test_url, test_file.path, timeout_ms, context);

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
    // Enable thread safety for multi-threaded worker execution.
    // Worker threads allocate messages using the main allocator, so it must be thread-safe.
    // Also enable safety checks for debugging.
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true, // CRITICAL: Workers use main allocator from separate threads
        .safety = true,
    }){};
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
        print("\nSkipped {d} items (use --verbose to see details)\n", .{discovery.skipped.items.len});
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

    // Clean up timer backend singleton
    const timer_backend = @import("platform").timer_backend;
    timer_backend.deinitDefault();

    // Finish and write report
    report.finish();

    // Write JSON output (default or if both)
    if (options.output_format == .json or options.output_format == .both) {
        const json_path = try std.fs.path.join(allocator, &.{ options.output_dir, "wptreport.json" });
        defer allocator.free(json_path);
        try report.writeToFile(json_path);
    }

    // Write xUnit XML output (if xunit or both)
    if (options.output_format == .xunit or options.output_format == .both) {
        const xunit_path = try std.fs.path.join(allocator, &.{ options.output_dir, "wptreport.xml" });
        defer allocator.free(xunit_path);
        var xunit_writer = result_reporter.XunitWriter.init(allocator);
        try xunit_writer.writeFromReport(&report, xunit_path);
    }

    // CI exit code enforcement: fail if tests were skipped due to scope issues on implemented scopes
    // This ensures we catch regressions where previously working scope routing breaks
    const summary = report.getSummary();
    if (summary.skipped_scope_unsupported > 0) {
        print("\n⚠️  WARNING: {d} tests skipped due to unsupported global scope\n", .{summary.skipped_scope_unsupported});
        print("   These scopes should be implemented. Check GlobalType.isImplemented()\n", .{});
    }
    if (summary.skipped_feature_unsupported > 0) {
        print("\n📋 INFO: {d} tests skipped due to unsupported features\n", .{summary.skipped_feature_unsupported});
    }

    // BSCOPE-23: CI MUST fail if implemented scopes have skipped tests
    // This catches regressions where previously working scope routing breaks
    if (summary.hasScopeSkipsForImplementedScopes()) {
        print("\n❌ CI FAILURE: Tests were skipped for implemented scopes\n", .{});
        print("   {d} tests skipped due to unsupported scope on implemented GlobalType\n", .{summary.skipped_scope_unsupported});
        print("   Fix the scope routing or mark the scope as unimplemented\n", .{});
        std.process.exit(1);
    }
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

test "parseArgs with specific file" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const args = [_][]const u8{"url/url-constructor.any.js"};
    var options = try parseArgs(allocator, &args);
    defer options.deinit();

    try testing.expectEqual(@as(usize, 0), options.filters.items.len);
    try testing.expectEqual(@as(usize, 1), options.specific_files.items.len);
    try testing.expectEqualStrings("url/url-constructor.any.js", options.specific_files.items[0]);
}

test "parseArgs with timeout-multiplier" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const args = [_][]const u8{ "--timeout-multiplier=2.5", "url/" };
    var options = try parseArgs(allocator, &args);
    defer options.deinit();

    try testing.expectEqual(@as(f32, 2.5), options.timeout_multiplier);
    try testing.expectEqual(@as(usize, 1), options.filters.items.len);

    // Test getAdjustedTimeout
    const normal_timeout = options.getAdjustedTimeout(.normal); // 10000ms * 2.5 = 25000ms
    try testing.expectEqual(@as(u64, 25000), normal_timeout);

    const long_timeout = options.getAdjustedTimeout(.long); // 60000ms * 2.5 = 150000ms
    try testing.expectEqual(@as(u64, 150000), long_timeout);
}

test "parseArgs with exclude patterns" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const args = [_][]const u8{ "--exclude=*-manual*", "--exclude=*/slow/*", "url/" };
    var options = try parseArgs(allocator, &args);
    defer options.deinit();

    try testing.expectEqual(@as(usize, 2), options.excludes.items.len);
    try testing.expectEqualStrings("*-manual*", options.excludes.items[0]);
    try testing.expectEqualStrings("*/slow/*", options.excludes.items[1]);

    // Test isExcluded
    try testing.expect(options.isExcluded("url/test-manual.html"));
    try testing.expect(options.isExcluded("url/slow/test.html"));
    try testing.expect(!options.isExcluded("url/test.any.js"));
}

test "parseArgs with output-format" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Test json format
    {
        const args = [_][]const u8{ "--output-format=json", "url/" };
        var options = try parseArgs(allocator, &args);
        defer options.deinit();
        try testing.expectEqual(OutputFormat.json, options.output_format);
    }

    // Test xunit format
    {
        const args = [_][]const u8{ "--output-format=xunit", "url/" };
        var options = try parseArgs(allocator, &args);
        defer options.deinit();
        try testing.expectEqual(OutputFormat.xunit, options.output_format);
    }

    // Test both format
    {
        const args = [_][]const u8{ "--output-format=both", "url/" };
        var options = try parseArgs(allocator, &args);
        defer options.deinit();
        try testing.expectEqual(OutputFormat.both, options.output_format);
    }

    // Test default format (json)
    {
        const args = [_][]const u8{"url/"};
        var options = try parseArgs(allocator, &args);
        defer options.deinit();
        try testing.expectEqual(OutputFormat.json, options.output_format);
    }
}

test "OutputFormat.fromString" {
    try std.testing.expectEqual(OutputFormat.json, OutputFormat.fromString("json").?);
    try std.testing.expectEqual(OutputFormat.xunit, OutputFormat.fromString("xunit").?);
    try std.testing.expectEqual(OutputFormat.both, OutputFormat.fromString("both").?);
    try std.testing.expectEqual(@as(?OutputFormat, null), OutputFormat.fromString("invalid"));
}

test "parseArgs with repeat" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const args = [_][]const u8{ "--repeat=5", "url/" };
    var options = try parseArgs(allocator, &args);
    defer options.deinit();

    try testing.expectEqual(@as(u32, 5), options.repeat);
}

test "parseArgs with retry-unexpected" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const args = [_][]const u8{ "--retry-unexpected=3", "url/" };
    var options = try parseArgs(allocator, &args);
    defer options.deinit();

    try testing.expectEqual(@as(u32, 3), options.retry_unexpected);
}

test "parseArgs with repeat and retry combined" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const args = [_][]const u8{ "--repeat=3", "--retry-unexpected=2", "url/" };
    var options = try parseArgs(allocator, &args);
    defer options.deinit();

    try testing.expectEqual(@as(u32, 3), options.repeat);
    try testing.expectEqual(@as(u32, 2), options.retry_unexpected);
}

test "parseArgs repeat minimum is 1" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const args = [_][]const u8{ "--repeat=0", "url/" };
    var options = try parseArgs(allocator, &args);
    defer options.deinit();

    try testing.expectEqual(@as(u32, 1), options.repeat);
}

test "isTestFile" {
    try std.testing.expect(isTestFile("url/test.any.js"));
    try std.testing.expect(isTestFile("dom/test.window.js"));
    try std.testing.expect(isTestFile("html/test.html"));
    try std.testing.expect(!isTestFile("url/"));
    try std.testing.expect(!isTestFile("dom"));
}

test "Options.matchesFilter" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Test with directory filter
    {
        var options = Options.init(allocator);
        defer options.deinit();
        try options.filters.append(allocator, try allocator.dupe(u8, "url"));

        try testing.expect(options.matchesFilter("url/test.any.js"));
        try testing.expect(options.matchesFilter("url/subdir/test.html"));
        try testing.expect(!options.matchesFilter("encoding/test.any.js"));
    }

    // Test with no filter (matches all)
    {
        var options = Options.init(allocator);
        defer options.deinit();

        try testing.expect(options.matchesFilter("url/test.any.js"));
        try testing.expect(options.matchesFilter("anything/here.html"));
    }
}

// =============================================================================
// Multi-Context Integration Tests
// =============================================================================

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

    // Should have 2 results (window and worker are implemented, sharedworker is not)
    try std.testing.expectEqual(@as(usize, 2), results.items.len);

    // Verify contexts
    try std.testing.expectEqualStrings("window", results.items[0].context.?);
    try std.testing.expectEqualStrings("worker", results.items[1].context.?);
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

    // window, worker, sharedworker, and serviceworker are implemented
    try std.testing.expectEqual(@as(usize, 4), implemented_count);
    // shadowrealm is not implemented
    try std.testing.expectEqual(@as(usize, 1), skipped_count);
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
    // - .any.js with no META: defaults to window + worker, both implemented = 2
    // - .any.js with global=window: explicit window = 1
    // - .any.js with global=window,worker: both implemented = 2
    // - .any.js with global=window,worker,sharedworker: window + worker = 2
    // - .window.js: always window = 1
    // - .worker.js: always worker = 1 (worker is now implemented)

    const allocator = std.testing.allocator;

    // Test case 1: .any.js with no META defaults to window+worker, both implemented
    {
        const content = "test(() => {});";
        var parsed = try test_parser.parseTestFile(allocator, "test.any.js", content);
        defer parsed.deinit();

        var implemented_count: usize = 0;
        for (parsed.metadata.globals.items) |ctx| {
            if (ctx.isImplemented()) implemented_count += 1;
        }
        try std.testing.expectEqual(@as(usize, 2), implemented_count);
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
        // window and worker are implemented (sharedworker, serviceworker are not)
        try std.testing.expectEqual(@as(usize, 2), implemented_count);
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

    // Test case 5: .worker.js forces worker only (worker IS implemented)
    {
        const content = "test(() => {});";
        var parsed = try test_parser.parseTestFile(allocator, "test.worker.js", content);
        defer parsed.deinit();

        var implemented_count: usize = 0;
        for (parsed.metadata.globals.items) |ctx| {
            if (ctx.isImplemented()) implemented_count += 1;
        }
        // Worker is now implemented, so 1 context will execute
        try std.testing.expectEqual(@as(usize, 1), implemented_count);
        try std.testing.expectEqual(test_parser.GlobalType.worker, parsed.metadata.globals.items[0]);
    }
}
