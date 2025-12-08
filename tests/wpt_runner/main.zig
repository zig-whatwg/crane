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
const browser_adapter = @import("browser_adapter.zig");
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
    /// Specific test files to run (overrides directory filters)
    specific_files: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) Options {
        return Options{
            .filters = .{},
            .specific_files = .{},
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
        } else if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
            options.verbose = true;
        } else if (std.mem.startsWith(u8, arg, "--parallel=")) {
            const value = arg["--parallel=".len..];
            options.parallel = std.fmt.parseInt(u32, value, 10) catch 0;
        } else if (std.mem.startsWith(u8, arg, "--wpt-root=")) {
            options.wpt_root = arg["--wpt-root=".len..];
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

        try scanDirectory(allocator, &result, options.wpt_root, full_path, clean_dir);
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
            try scanDirectory(allocator, result, wpt_root, full_entry_path, entry_path);
        } else if (entry.kind == .file) {
            // Check if this is a test file
            const file_type = config.FileType.fromPath(entry.name);
            if (file_type == .unknown) continue;

            // Check if excluded
            if (config.isExcluded(entry_path)) {
                try result.addSkipped(entry_path, "excluded by pattern");
                continue;
            }

            // Add to results
            try result.addTestFile(entry_path, file_type);
        }
    }
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
        self.completed += 1;

        // Count by test status
        switch (result.status) {
            .ok => {},
            .@"error" => self.errors += 1,
            .timeout => self.timeouts += 1,
        }

        // Count subtests and optionally print failures in verbose mode
        for (result.subtests.items) |sub| {
            switch (sub.status) {
                .pass => self.passed += 1,
                .fail => {
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
                },
                .timeout => self.timeouts += 1,
                else => {},
            }
        }
    }

    pub fn printProgress(self: *ProgressTracker, current_test: []const u8) void {
        if (self.verbose) {
            print("[{d}/{d}] {s}\n", .{ self.completed, self.total, current_test });
        } else {
            // Print progress bar on same line
            const percent = if (self.total > 0) (self.completed * 100) / self.total else 0;
            const elapsed = self.getElapsedTime();

            // Truncate test path if too long
            const max_path_len: usize = 50;
            const display_path = if (current_test.len > max_path_len)
                current_test[current_test.len - max_path_len ..]
            else
                current_test;

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
        const total_subtests = self.passed + self.failed + self.timeouts;

        print("\n================================\n", .{});
        print("WPT Test Results\n", .{});
        print("================================\n", .{});
        print("Test files: {d}\n", .{self.total});
        print("  Completed: {d}\n", .{self.completed});
        print("  Errors:    {d}\n", .{self.errors});
        print("  Timeouts:  {d}\n", .{self.timeouts});
        print("\n", .{});
        print("Subtests:   {d}\n", .{total_subtests});
        if (total_subtests > 0) {
            const pass_rate = @as(f64, @floatFromInt(self.passed)) / @as(f64, @floatFromInt(total_subtests)) * 100.0;
            print("  Passed:   {d} ({d:.1}%)\n", .{ self.passed, pass_rate });
        } else {
            print("  Passed:   {d}\n", .{self.passed});
        }
        print("  Failed:   {d}\n", .{self.failed});
        print("  Timeout:  {d}\n", .{self.timeouts});
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

/// Execute all discovered tests
pub fn executeTests(
    allocator: std.mem.Allocator,
    discovery: DiscoveryResult,
    options: Options,
    report: *result_reporter.WptReport,
) !void {
    const total = discovery.test_files.items.len;
    print("\nRunning {d} test files...\n\n", .{total});

    // Create a single BrowserAdapter for all tests (single V8 isolate, new context per navigation)
    // This is much more efficient than creating a new isolate per test (~1-5ms vs ~50-100ms)
    var browser = try browser_adapter.BrowserAdapter.init(allocator, options.wpt_root);
    defer browser.deinit();

    var progress = ProgressTracker.init(allocator, total, options.verbose);
    defer progress.deinit();

    for (discovery.test_files.items) |test_file| {
        // Execute single test file
        const test_result = executeTestFile(allocator, options, test_file, browser) catch |err| {
            // Create error result with stack trace
            var error_result = try test_harness.TestResult.init(allocator, test_file.path);
            error_result.status = .@"error";

            // Capture and print full stack trace for debugging
            const trace = @errorReturnTrace();
            if (trace) |t| {
                std.debug.print("\n=== ERROR in test: {s} ===\n", .{test_file.path});
                std.debug.print("Error: {}\n", .{err});
                std.debug.dumpStackTrace(t.*);
                std.debug.print("=== END ERROR ===\n\n", .{});
            } else {
                std.debug.print("\n=== ERROR in test: {s} ===\n", .{test_file.path});
                std.debug.print("Error: {} (no stack trace available)\n", .{err});
                std.debug.print("=== END ERROR ===\n\n", .{});
            }

            error_result.message = try std.fmt.allocPrint(allocator, "Execution error: {}", .{err});

            progress.recordResult(test_file.path, error_result);
            progress.printProgress(test_file.path);

            try report.addResult(error_result);
            error_result.deinit(allocator);
            continue;
        };

        progress.recordResult(test_file.path, test_result);
        progress.printProgress(test_file.path);

        try report.addResult(test_result);

        // Clean up the test result (addResult copies the data)
        var mutable_result = test_result;
        mutable_result.deinit(allocator);
    }

    // Generate output path
    const output_path = try std.fs.path.join(allocator, &.{ options.output_dir, "wptreport.json" });
    defer allocator.free(output_path);

    progress.printSummary(output_path);
}

/// Execute a single test file using the shared BrowserAdapter
fn executeTestFile(
    allocator: std.mem.Allocator,
    options: Options,
    test_file: TestFile,
    browser: *browser_adapter.BrowserAdapter,
) !test_harness.TestResult {
    // Read test file content
    const full_path = try std.fs.path.join(allocator, &.{ options.wpt_root, test_file.path });
    defer allocator.free(full_path);

    const content = try std.fs.cwd().readFileAlloc(allocator, full_path, 10 * 1024 * 1024);
    defer allocator.free(content);

    // Parse test file
    var parsed = try test_parser.parseTestFile(allocator, test_file.path, content);
    defer parsed.deinit();

    // Build test content to execute
    // For HTML files, we need to concatenate inline scripts
    // For JS files, we execute the content directly
    var test_content: []const u8 = undefined;
    var test_content_owned: ?[]u8 = null;
    defer if (test_content_owned) |owned| allocator.free(owned);

    if (test_file.file_type == .html) {
        // For HTML files, we need to load external scripts first, then inline scripts
        // Scripts are processed in document order (external and inline interleaved)
        var all_scripts: std.ArrayListUnmanaged([]const u8) = .{};
        defer all_scripts.deinit(allocator);
        var scripts_to_free: std.ArrayListUnmanaged([]const u8) = .{};
        defer {
            for (scripts_to_free.items) |s| allocator.free(s);
            scripts_to_free.deinit(allocator);
        }

        for (parsed.metadata.scripts.items) |script| {
            if (script.inline_script) {
                // Inline script - content is already in script.path
                try all_scripts.append(allocator, script.path);
            } else {
                // External script - load from file
                // Skip testharness.js and testharnessreport.js (already loaded by browser context)
                if (std.mem.endsWith(u8, script.path, "testharness.js") or
                    std.mem.endsWith(u8, script.path, "testharnessreport.js"))
                {
                    continue;
                }

                // Resolve the script path FIRST so we can use the absolute path as cache key
                var script_path: []u8 = undefined;
                if (std.mem.startsWith(u8, script.path, "/")) {
                    // Absolute path from WPT root (e.g., "/common/subset-tests.js")
                    script_path = try std.fs.path.join(allocator, &.{ options.wpt_root, script.path[1..] });
                } else {
                    // Relative path from test file
                    const test_dir = if (std.mem.lastIndexOf(u8, test_file.path, "/")) |pos|
                        test_file.path[0..pos]
                    else
                        "";
                    script_path = try std.fs.path.join(allocator, &.{ options.wpt_root, test_dir, script.path });
                }
                defer allocator.free(script_path);

                // Skip scripts that have already been loaded in this context
                // This prevents "const already declared" errors when running
                // multiple tests that share the same helper scripts
                // Use the resolved absolute path as the cache key to correctly handle
                // relative paths from different directories
                if (browser.isScriptLoaded(script_path)) {
                    continue;
                }

                // Read the script file
                const script_content = std.fs.cwd().readFileAlloc(allocator, script_path, 10 * 1024 * 1024) catch |err| {
                    // Skip missing scripts with a warning
                    std.debug.print("Warning: Could not load script {s}: {}\n", .{ script.path, err });
                    continue;
                };
                try all_scripts.append(allocator, script_content);
                try scripts_to_free.append(allocator, script_content);

                // Mark script as loaded so we don't reload it for subsequent tests
                try browser.markScriptLoaded(script_path);
            }
        }

        if (all_scripts.items.len == 0) {
            // No scripts - nothing to test
            return test_harness.TestResult.init(allocator, test_file.path);
        }

        // Calculate total length
        var total_len: usize = 0;
        for (all_scripts.items) |s| {
            total_len += s.len + 2; // +2 for ";\n" separator
        }

        // Concatenate all scripts
        const combined = try allocator.alloc(u8, total_len);
        test_content_owned = combined;

        var offset: usize = 0;
        for (all_scripts.items) |s| {
            @memcpy(combined[offset .. offset + s.len], s);
            offset += s.len;
            combined[offset] = ';';
            combined[offset + 1] = '\n';
            offset += 2;
        }

        test_content = combined;
    } else {
        // For JS files, we need to load META scripts first, then the test content
        // META scripts are specified like: // META: script=/common/subset-tests-by-key.js
        var all_scripts: std.ArrayListUnmanaged([]const u8) = .{};
        defer all_scripts.deinit(allocator);

        // Load external META scripts first
        for (parsed.metadata.scripts.items) |script| {
            if (!script.inline_script) {
                // Resolve the script path FIRST so we can use the absolute path as cache key
                var script_path: []u8 = undefined;
                if (std.mem.startsWith(u8, script.path, "/")) {
                    // Absolute path from WPT root (e.g., "/common/subset-tests-by-key.js")
                    script_path = try std.fs.path.join(allocator, &.{ options.wpt_root, script.path[1..] });
                } else {
                    // Relative path from test file
                    const test_dir = if (std.mem.lastIndexOf(u8, test_file.path, "/")) |pos|
                        test_file.path[0..pos]
                    else
                        "";
                    script_path = try std.fs.path.join(allocator, &.{ options.wpt_root, test_dir, script.path });
                }
                defer allocator.free(script_path);

                // Skip scripts that have already been loaded in this context
                // This prevents "const already declared" errors when running
                // multiple tests that share the same helper scripts
                // Use the resolved absolute path as the cache key
                if (browser.isScriptLoaded(script_path)) {
                    continue;
                }

                // Read the script file
                const script_content = std.fs.cwd().readFileAlloc(allocator, script_path, 10 * 1024 * 1024) catch |err| {
                    // Skip missing scripts with a warning
                    std.debug.print("Warning: Could not load META script {s}: {}\n", .{ script.path, err });
                    continue;
                };
                try all_scripts.append(allocator, script_content);

                // Mark script as loaded so we don't reload it for subsequent tests
                try browser.markScriptLoaded(script_path);
            }
        }

        // Add the main test content
        const test_content_copy = try allocator.dupe(u8, parsed.content);
        try all_scripts.append(allocator, test_content_copy);

        // Calculate total length
        var total_len: usize = 0;
        for (all_scripts.items) |s| {
            total_len += s.len + 2; // +2 for ";\n" separator
        }

        // Concatenate all scripts
        const combined = try allocator.alloc(u8, total_len);
        test_content_owned = combined;

        var offset: usize = 0;
        for (all_scripts.items) |s| {
            @memcpy(combined[offset .. offset + s.len], s);
            offset += s.len;
            combined[offset] = ';';
            combined[offset + 1] = '\n';
            offset += 2;
            allocator.free(s);
        }

        test_content = combined;
    }

    // Execute the test using the BrowserAdapter
    // The browser maintains a single V8 isolate and creates a new context per navigation
    const result = try browser.runTest(test_file.path, test_content, parsed.metadata.timeout);
    return result;
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

    // Execute tests (prints progress and summary)
    try executeTests(allocator, discovery, options, &report);

    // Finish and write report
    report.finish();

    const output_path = try std.fs.path.join(allocator, &.{ options.output_dir, "wptreport.json" });
    defer allocator.free(output_path);

    try report.writeToFile(output_path);
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
