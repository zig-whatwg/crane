//! WebIDL File Discovery
//!
//! This module provides functions for discovering and processing WebIDL (.idl) files.

const std = @import("std");

/// Find all WebIDL (.idl) files in a directory
///
/// Returns an allocated list of file paths. Caller owns the returned slice
/// and all paths within it.
///
/// Example:
/// ```zig
/// const files = try findIDLFiles(allocator, "idl/specs");
/// defer {
///     for (files) |path| allocator.free(path);
///     allocator.free(files);
/// }
/// ```
pub fn findIDLFiles(allocator: std.mem.Allocator, dir_path: []const u8) ![][]const u8 {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var files: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (files.items) |path| allocator.free(path);
        files.deinit(allocator);
    }

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;

        // Only accept .idl files
        if (!std.mem.endsWith(u8, entry.name, ".idl")) continue;

        // Build full path
        const full_path = try std.fs.path.join(allocator, &.{ dir_path, entry.name });
        errdefer allocator.free(full_path);

        try files.append(allocator, full_path);
    }

    return files.toOwnedSlice(allocator);
}

/// Extract namespace from IDL filename
///
/// Example:
/// - "dom.idl" -> "dom"
/// - "fetch.idl" -> "fetch"
/// - "specs/html.idl" -> "html"
///
/// Returns a slice into the basename (no allocation).
pub fn getNamespace(file_path: []const u8) []const u8 {
    const basename = std.fs.path.basename(file_path);

    // Find the last '.' to strip extension
    if (std.mem.lastIndexOfScalar(u8, basename, '.')) |dot_index| {
        return basename[0..dot_index];
    }

    return basename;
}

// Unit tests
const testing = std.testing;

test "getNamespace extracts name from simple path" {
    const result = getNamespace("dom.idl");
    try testing.expectEqualStrings("dom", result);
}

test "getNamespace extracts name from path with directory" {
    const result = getNamespace("specs/fetch.idl");
    try testing.expectEqualStrings("fetch", result);
}

test "getNamespace handles file without extension" {
    const result = getNamespace("somefile");
    try testing.expectEqualStrings("somefile", result);
}

test "getNamespace handles multiple dots" {
    const result = getNamespace("file.test.idl");
    try testing.expectEqualStrings("file.test", result);
}

test "findIDLFiles discovers only idl files" {
    const allocator = testing.allocator;

    // Create a temporary directory
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    // Create some test files
    try tmp_dir.dir.writeFile(.{ .sub_path = "dom.json", .data = "{}" });
    try tmp_dir.dir.writeFile(.{ .sub_path = "fetch.idl", .data = "interface Foo {};" });
    try tmp_dir.dir.writeFile(.{ .sub_path = "readme.txt", .data = "test" });
    try tmp_dir.dir.writeFile(.{ .sub_path = "html.xml", .data = "{}" });
    try tmp_dir.dir.writeFile(.{ .sub_path = "console.idl", .data = "interface Bar {};" });

    // Find IDL files
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const files = try findIDLFiles(allocator, tmp_path);
    defer {
        for (files) |path| allocator.free(path);
        allocator.free(files);
    }

    // Should find only 2 .idl files
    try testing.expectEqual(@as(usize, 2), files.len);

    // Verify all files end with .idl
    for (files) |file| {
        try testing.expect(std.mem.endsWith(u8, file, ".idl"));
    }
}

test "findIDLFiles handles empty directory" {
    const allocator = testing.allocator;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const files = try findIDLFiles(allocator, tmp_path);
    defer allocator.free(files);

    try testing.expectEqual(@as(usize, 0), files.len);
}

test "findIDLFiles handles directory with no idl files" {
    const allocator = testing.allocator;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    try tmp_dir.dir.writeFile(.{ .sub_path = "readme.txt", .data = "test" });
    try tmp_dir.dir.writeFile(.{ .sub_path = "data.xml", .data = "<test/>" });
    try tmp_dir.dir.writeFile(.{ .sub_path = "spec.json", .data = "{}" });

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const files = try findIDLFiles(allocator, tmp_path);
    defer allocator.free(files);

    try testing.expectEqual(@as(usize, 0), files.len);
}
