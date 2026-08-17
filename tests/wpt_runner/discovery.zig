//! Deciding which WPT tests a run covers.
//!
//! Split out of main.zig so it can be tested. This is where the scoreboard's
//! denominator comes from - how many tests exist, how many are in scope, how
//! many the checkout is actually missing - and none of it needs a browser, so
//! none of it should need V8 linked to verify.
//!
//! Three sources of work, in the order discoverTests considers them:
//!
//! 1. A worklist file, when a supervisor spawned this process. Taken verbatim.
//! 2. Explicit paths on the command line, resolved through MANIFEST.json so a
//!    virtual URL like `url/x.any.html` finds its `url/x.any.js` source.
//! 3. MANIFEST.json's `items.testharness`, filtered to the in-scope categories.
//!    The legacy filesystem walk is an escape hatch for a checkout with no
//!    usable manifest; it cannot report a denominator.

const std = @import("std");
const config = @import("config.zig");
const selection = @import("selection.zig");
const wpt_manifest = @import("manifest.zig");
const Options = @import("options.zig").Options;

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
    /// Manifest test URLs in scope for this run - the scoreboard denominator.
    /// Zero when discovery did not consult the manifest.
    total_in_scope_urls: usize = 0,
    /// Manifest test URLs in the whole testharness corpus, in scope or not.
    total_manifest_urls: usize = 0,
    /// Sources the manifest lists but that are absent from our checkout.
    missing_sources: usize = 0,
    /// Worklist index of `test_files[0]`. Non-zero only for a resumed child;
    /// journal indices are `base_index + i` so they stay comparable across the
    /// several processes a supervised run is made of.
    base_index: usize = 0,

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

/// Discover test files
///
/// Uses the official WPT MANIFEST.json to resolve test URLs to source files.
/// This follows the standard WPT approach where virtual test URLs like
/// "url/url-searchparams.any.html" are mapped to their source files like
/// "url/url-searchparams.any.js" through the manifest.
pub fn discoverTests(allocator: std.mem.Allocator, options: Options) !DiscoveryResult {
    var result = DiscoveryResult.init(allocator);
    errdefer result.deinit();

    // A supervised child takes its work from the worklist its parent wrote, not
    // from a fresh discovery. Nothing here filters: the parent already decided
    // what runs, and dropping an entry would shift every index after it out of
    // step with the journal.
    if (options.from_file) |worklist_path| {
        var worklist = try selection.readWorklist(allocator, worklist_path);
        defer worklist.deinit();

        result.base_index = options.start_index;
        if (options.start_index >= worklist.paths.len) return result;

        for (worklist.paths[options.start_index..]) |path| {
            try result.addTestFile(path, config.FileType.fromPath(path));
            if (options.limit > 0 and result.test_files.items.len >= options.limit) break;
        }
        return result;
    }

    // If specific files are specified, resolve them through the manifest
    if (options.specific_files.items.len > 0) {
        // Load the WPT manifest for URL resolution
        var manifest = try wpt_manifest.loadManifest(allocator, options.wpt_root);
        defer manifest.deinit();

        for (options.specific_files.items) |file_path| {
            const full_path = try std.fs.path.join(allocator, &.{ options.wpt_root, file_path });
            defer allocator.free(full_path);

            // First, check if the file exists directly (source file or real HTML)
            if (std.fs.cwd().access(full_path, .{})) |_| {
                const file_type = config.FileType.fromPath(file_path);
                if (file_type == .unknown) {
                    print("Warning: Unknown test file type: {s}\n", .{file_path});
                    continue;
                }
                try result.addTestFile(file_path, file_type);
            } else |_| {
                // File doesn't exist - check if it's a virtual test URL in the manifest
                // WPT generates virtual URLs like .any.html from .any.js source files
                if (manifest.resolveUrlToSource(file_path)) |source_path| {
                    // Verify the source file exists
                    const source_full_path = try std.fs.path.join(allocator, &.{ options.wpt_root, source_path });
                    defer allocator.free(source_full_path);

                    std.fs.cwd().access(source_full_path, .{}) catch {
                        print("Warning: Source file not found: {s} (for test URL: {s})\n", .{ source_path, file_path });
                        continue;
                    };

                    const file_type = config.FileType.fromPath(source_path);
                    if (file_type == .unknown) {
                        print("Warning: Unknown test file type: {s}\n", .{source_path});
                        continue;
                    }

                    // Use the source file path
                    try result.addTestFile(source_path, file_type);
                    print("Resolved test URL '{s}' to source file '{s}'\n", .{ file_path, source_path });
                } else {
                    print("Warning: Test file not found: {s}\n", .{file_path});
                    print("  (Not in MANIFEST.json - run 'wpt manifest' to update)\n", .{});
                }
            }
        }
        return result;
    }

    // Enumerate from MANIFEST.json rather than the filesystem.
    //
    // The manifest partitions every file in the tree by harness type, so
    // items.testharness is exactly the set of tests we are trying to pass -
    // no guessing from filenames which .html files are tests, references or
    // support files. It also gives the scoreboard a denominator: how many
    // tests exist, not just how many we happened to find.
    if (!options.legacy_scan) {
        var manifest = try wpt_manifest.loadManifest(allocator, options.wpt_root);
        defer manifest.deinit();

        var sel = try selection.selectInScope(allocator, &manifest, options.filters.items);
        defer sel.deinit();

        result.total_in_scope_urls = sel.url_count;
        result.total_manifest_urls = manifest.urlCount();

        for (sel.sources) |source_path| {
            if (options.pattern) |pat| {
                if (std.mem.indexOf(u8, source_path, pat) == null) continue;
            }

            const file_type = config.FileType.fromPath(source_path);
            if (file_type == .unknown) continue;

            // The manifest describes the upstream tree; our checkout may be
            // sparse, so a listed source is not guaranteed to be on disk.
            const full_path = try std.fs.path.join(allocator, &.{ options.wpt_root, source_path });
            defer allocator.free(full_path);
            std.fs.cwd().access(full_path, .{}) catch {
                result.missing_sources += 1;
                continue;
            };

            try result.addTestFile(source_path, file_type);

            if (options.limit > 0 and result.test_files.items.len >= options.limit) break;
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

        try scanDirectory(allocator, &result, options.wpt_root, full_path, clean_dir, options.pattern);

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
            try scanDirectory(allocator, result, wpt_root, full_entry_path, entry_path, pattern);
        } else if (entry.kind == .file) {
            // Check if this is a test file
            const file_type = config.FileType.fromPath(entry.name);
            if (file_type == .unknown) continue;

            // Check if excluded
            if (config.isExcluded(entry_path)) {
                try result.addSkipped(entry_path, "excluded by pattern");
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
pub fn globMatch(str: []const u8, pattern: []const u8) bool {
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

/// Output helper - uses std.debug.print for standalone compatibility
fn print(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// Build Options for a test, with `filters`/`specific_files` left empty.
fn testOptions(allocator: std.mem.Allocator) Options {
    return Options.init(allocator);
}

test "DiscoveryResult counts by type and category" {
    const allocator = testing.allocator;

    var result = DiscoveryResult.init(allocator);
    defer result.deinit();

    try result.addTestFile("url/a.any.js", .any_js);
    try result.addTestFile("url/b.any.js", .any_js);
    try result.addTestFile("dom/c.html", .html);

    try testing.expectEqual(@as(usize, 3), result.totalCount());
    try testing.expectEqual(@as(usize, 2), result.by_type.get(.any_js).?);
    try testing.expectEqual(@as(usize, 1), result.by_type.get(.html).?);
    try testing.expectEqual(@as(usize, 2), result.by_category.get("url").?);
    try testing.expectEqual(@as(usize, 1), result.by_category.get("dom").?);
}

test "a worklist is taken verbatim from start_index" {
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(.{
        .sub_path = "worklist.txt",
        .data = "a/one.any.js\nb/two.html\nc/three.window.js\nd/four.html\n",
    });
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);
    const worklist_path = try std.fs.path.join(allocator, &.{ dir_path, "worklist.txt" });
    defer allocator.free(worklist_path);

    var options = testOptions(allocator);
    defer options.deinit();
    options.from_file = worklist_path;
    options.start_index = 2;

    var result = try discoverTests(allocator, options);
    defer result.deinit();

    // Nothing is filtered here: dropping an entry would shift every index after
    // it out of step with the journal the supervisor resumes against.
    try testing.expectEqual(@as(usize, 2), result.test_files.items.len);
    try testing.expectEqual(@as(usize, 2), result.base_index);
    try testing.expectEqualStrings("c/three.window.js", result.test_files.items[0].path);
    try testing.expectEqualStrings("d/four.html", result.test_files.items[1].path);
    try testing.expectEqual(config.FileType.window_js, result.test_files.items[0].file_type);
}

test "a worklist past its end yields no work" {
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(.{ .sub_path = "worklist.txt", .data = "a/one.html\n" });
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);
    const worklist_path = try std.fs.path.join(allocator, &.{ dir_path, "worklist.txt" });
    defer allocator.free(worklist_path);

    var options = testOptions(allocator);
    defer options.deinit();
    options.from_file = worklist_path;
    options.start_index = 9;

    var result = try discoverTests(allocator, options);
    defer result.deinit();

    // A supervisor restarting past the last test must terminate, not wrap.
    try testing.expectEqual(@as(usize, 0), result.test_files.items.len);
}

test "a worklist honours the limit" {
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(.{
        .sub_path = "worklist.txt",
        .data = "a.html\nb.html\nc.html\nd.html\n",
    });
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);
    const worklist_path = try std.fs.path.join(allocator, &.{ dir_path, "worklist.txt" });
    defer allocator.free(worklist_path);

    var options = testOptions(allocator);
    defer options.deinit();
    options.from_file = worklist_path;
    options.start_index = 1;
    options.limit = 2;

    var result = try discoverTests(allocator, options);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.test_files.items.len);
    try testing.expectEqualStrings("b.html", result.test_files.items[0].path);
    try testing.expectEqualStrings("c.html", result.test_files.items[1].path);
}

test "the legacy scan walks the filesystem and honours exclusions" {
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makePath("url/resources");
    try tmp.dir.writeFile(.{ .sub_path = "url/a.any.js", .data = "" });
    try tmp.dir.writeFile(.{ .sub_path = "url/b.html", .data = "" });
    try tmp.dir.writeFile(.{ .sub_path = "url/notes.md", .data = "" });
    // Named like a test but living under resources/, so only the path-based
    // exclusion can catch it. The exclusion pattern is "/resources/" with both
    // slashes, which the directory entry "url/resources" does not match - the
    // walk descends and rejects the file on its full path instead.
    try tmp.dir.writeFile(.{ .sub_path = "url/resources/helper.any.js", .data = "" });

    const root = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);

    var options = testOptions(allocator);
    defer options.deinit();
    options.legacy_scan = true;
    options.wpt_root = root;
    try options.filters.append(allocator, try allocator.dupe(u8, "url/"));

    var result = try discoverTests(allocator, options);
    defer result.deinit();

    // notes.md is not a test file at all, so it is dropped without comment;
    // the helper under resources/ is a test-shaped path, so it is recorded as
    // a deliberate skip rather than silently vanishing.
    try testing.expectEqual(@as(usize, 2), result.test_files.items.len);
    try testing.expectEqual(@as(usize, 1), result.skipped.items.len);
    try testing.expectEqualStrings("url/resources/helper.any.js", result.skipped.items[0].path);
    try testing.expectEqualStrings("excluded by pattern", result.skipped.items[0].reason);
}

test "globMatch" {
    try testing.expect(globMatch("url-constructor.any.js", "*constructor*"));
    try testing.expect(globMatch("url-origin.any.js", "url-*"));
    try testing.expect(globMatch("abc", "a?c"));
    try testing.expect(globMatch("abc", "*"));
    try testing.expect(globMatch("abc", "abc"));
    try testing.expect(!globMatch("abc", "abcd"));
    try testing.expect(!globMatch("url-origin.any.js", "*constructor*"));
}

test "globMatch backtracks past a false start" {
    // A naive matcher commits to the first place the star could end and then
    // fails; "*ab" has to give up its first guess at "ab" to reach the second.
    try testing.expect(globMatch("xabyab", "*ab"));
    try testing.expect(globMatch("aaa", "*a"));
    try testing.expect(!globMatch("xabyabz", "*ab"));
}
