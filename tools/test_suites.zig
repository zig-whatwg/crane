//! Which tests/<dir>/ directories hold Zig tests, and which of them no suite
//! in build.zig runs.
//!
//! `zig build test` compiles a directory's `*_test.zig` files only when
//! build.zig makes that directory a suite (`addTestFilesFromDir`, or a root it
//! wires by hand). A directory it never names is never compiled, and nothing
//! says so: tests/infra/font_case_folding_test.zig sat there from its commit
//! (633a1e91df4) until lane flakes2 wired the directory. So build.zig fails
//! its configuration on any such directory (`checkEveryTestDirectoryIsASuite`,
//! which calls `missing` over `dirsWithTests`), and these functions are
//! std-only so that `zig build test` pins them.

const std = @import("std");

/// tests/ entries never scanned, with why: the WPT checkout is upstream's
/// tree (tens of thousands of files, none of them Crane's Zig tests), and
/// walking it at every configuration would cost more than the check.
pub const not_scanned = [_][]const u8{"wpt"};

/// Whether `name`, a file name, is a test file a suite collects.
pub fn isTestFile(name: []const u8) bool {
    return std.mem.endsWith(u8, name, "_test.zig") and name.len > "_test.zig".len;
}

/// The immediate subdirectories of `tests` (opened with iteration) that hold
/// a test file at any depth, as "<prefix>/<name>", sorted - except
/// `not_scanned`. Files directly in `tests` belong to no directory and are
/// not reported. Free with `freeList`.
pub fn dirsWithTests(allocator: std.mem.Allocator, io: std.Io, tests: std.Io.Dir, prefix: []const u8) ![][]u8 {
    var found: std.ArrayList([]u8) = .empty;
    // Deferred first, so it runs last: the strings go before the list.
    defer found.deinit(allocator);
    errdefer freeList(allocator, found.items);

    var it = tests.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .directory) continue;
        if (isNotScanned(entry.name)) continue;
        var sub = try tests.openDir(io, entry.name, .{ .iterate = true });
        defer sub.close(io);
        if (!try holdsTestFile(allocator, io, sub)) continue;
        const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ prefix, entry.name });
        errdefer allocator.free(path);
        try found.append(allocator, path);
    }
    std.mem.sort([]u8, found.items, {}, struct {
        fn lessThan(_: void, a: []u8, b: []u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);
    return found.toOwnedSlice(allocator);
}

/// The entries of `dirs` that `suites` lacks, in `dirs`' order. A trailing
/// "/" on either side does not count. The slice is the caller's to free;
/// its strings are `dirs`'.
pub fn missing(allocator: std.mem.Allocator, dirs: []const []const u8, suites: []const []const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    errdefer out.deinit(allocator);
    outer: for (dirs) |dir| {
        for (suites) |suite| {
            if (std.mem.eql(u8, trimSlash(dir), trimSlash(suite))) continue :outer;
        }
        try out.append(allocator, dir);
    }
    return out.toOwnedSlice(allocator);
}

pub fn freeList(allocator: std.mem.Allocator, list: []const []u8) void {
    for (list) |item| allocator.free(item);
}

fn isNotScanned(name: []const u8) bool {
    for (not_scanned) |skipped| if (std.mem.eql(u8, name, skipped)) return true;
    return false;
}

fn holdsTestFile(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir) !bool {
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind == .file and isTestFile(entry.basename)) return true;
    }
    return false;
}

fn trimSlash(path: []const u8) []const u8 {
    return std.mem.trimEnd(u8, path, "/");
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "a test file is a *_test.zig file, not the suffix alone" {
    try testing.expect(isTestFile("font_case_folding_test.zig"));
    try testing.expect(!isTestFile("http_mock_server.zig"));
    try testing.expect(!isTestFile("_test.zig"));
    try testing.expect(!isTestFile("helper_test.zig.orig"));
}

test "a directory no suite names is missing; a named one is not, with or without a trailing slash" {
    const dirs = [_][]const u8{ "tests/dom", "tests/infra", "tests/v8" };
    const suites = [_][]const u8{ "tests/dom", "tests/v8/" };
    const out = try missing(testing.allocator, &dirs, &suites);
    defer testing.allocator.free(out);
    try testing.expectEqual(@as(usize, 1), out.len);
    try testing.expectEqualStrings("tests/infra", out[0]);
}

test "every directory a suite: nothing missing" {
    const dirs = [_][]const u8{ "tests/a", "tests/b" };
    const suites = [_][]const u8{ "tests/b", "tests/a", "tests/c" };
    const out = try missing(testing.allocator, &dirs, &suites);
    defer testing.allocator.free(out);
    try testing.expectEqual(@as(usize, 0), out.len);
}

test "the directories with a test file at any depth, sorted; not the WPT checkout, not top-level files" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    // Holds a test file directly.
    try tmp.dir.createDirPath(io, "zeta");
    try tmp.dir.writeFile(io, .{ .sub_path = "zeta/x_test.zig", .data = "test {}\n" });
    // Holds one two levels down only.
    try tmp.dir.createDirPath(io, "alpha/sub/deeper");
    try tmp.dir.writeFile(io, .{ .sub_path = "alpha/sub/deeper/y_test.zig", .data = "test {}\n" });
    // Zig sources but no test file (a fixture directory such as tests/support).
    try tmp.dir.createDirPath(io, "support");
    try tmp.dir.writeFile(io, .{ .sub_path = "support/loopback_listener.zig", .data = "" });
    // Empty.
    try tmp.dir.createDirPath(io, "empty");
    // The WPT checkout, even with a file that looks like a test.
    try tmp.dir.createDirPath(io, "wpt/crane");
    try tmp.dir.writeFile(io, .{ .sub_path = "wpt/crane/z_test.zig", .data = "" });
    // A test file directly in tests/ belongs to no directory.
    try tmp.dir.writeFile(io, .{ .sub_path = "top_test.zig", .data = "test {}\n" });

    const found = try dirsWithTests(testing.allocator, io, tmp.dir, "tests");
    defer {
        freeList(testing.allocator, found);
        testing.allocator.free(found);
    }
    try testing.expectEqual(@as(usize, 2), found.len);
    try testing.expectEqualStrings("tests/alpha", found[0]);
    try testing.expectEqualStrings("tests/zeta", found[1]);
}

test "dirsWithTests frees what it made when an allocation fails" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "a");
    try tmp.dir.writeFile(io, .{ .sub_path = "a/a_test.zig", .data = "" });
    try tmp.dir.createDirPath(io, "b");
    try tmp.dir.writeFile(io, .{ .sub_path = "b/b_test.zig", .data = "" });
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn run(allocator: std.mem.Allocator, dir: std.Io.Dir) !void {
            const found = try dirsWithTests(allocator, testing.io, dir, "tests");
            freeList(allocator, found);
            allocator.free(found);
        }
    }.run, .{tmp.dir});
}
