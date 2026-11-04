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

/// The test files directly in `tests` (opened with iteration), as
/// "<prefix>/<name>", sorted. No suite collects one: a suite is a directory,
/// so a test file has to live in one (tests/<dir>/) to be compiled - sixteen
/// sat at the top of tests/ compiled by nothing, some since 2025-11, until
/// lane testfix2 (docs/lessons/testing-a-test-file-at-the-top-of-tests-is-
/// never-built.md). Free with `freeList`.
pub fn topLevelTestFiles(allocator: std.mem.Allocator, io: std.Io, tests: std.Io.Dir, prefix: []const u8) ![][]u8 {
    var found: std.ArrayList([]u8) = .empty;
    // Deferred first, so it runs last: the strings go before the list.
    defer found.deinit(allocator);
    errdefer freeList(allocator, found.items);

    var it = tests.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!isTestFile(entry.name)) continue;
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
// The one test executable (build.zig -Dtest-binaries=v8, lanes onebin1 and onebin2)
// ============================================================================

/// One import of a suite's test root: its name and the module it names,
/// as an opaque key (build.zig passes the module's address).
pub const Import = struct { name: []const u8, key: usize };

/// The name prefix a tests/<dir>/ suite's tests carry in the one executable:
/// its directory under tests/, '/' as '.', then '.' ("tests/html" ->
/// "html."). Zig names a test by its file's path from the root module's
/// directory, and the one executable's root is tests/.all_tests.zig.
pub fn memberPrefix(allocator: std.mem.Allocator, dir_path: []const u8) ![]u8 {
    const under = "tests/";
    const rel = trimSlash(dir_path);
    if (!std.mem.startsWith(u8, rel, under) or rel.len == under.len) return error.NotUnderTests;
    const out = try std.fmt.allocPrint(allocator, "{s}.", .{rel[under.len..]});
    std.mem.replaceScalar(u8, out, '/', '.');
    return out;
}

/// The one executable's root file, tests/<root_name>: a test block that
/// imports each member's own root by its path under tests/.
pub fn oneBinaryRoot(allocator: std.mem.Allocator, dir_paths: []const []const u8, root_name: []const u8) ![]u8 {
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    try out.writer.writeAll(
        \\//! Generated by build.zig (finishOneBinary, -Dtest-binaries=v8): the
        \\//! test directories `zig build test` runs that link V8, compiled as
        \\//! ONE test executable. Gitignored and rewritten when the list changes - do not
        \\//! edit.
        \\
        \\test {
        \\
    );
    for (dir_paths) |dir| {
        const rel = trimSlash(dir);
        if (!std.mem.startsWith(u8, rel, "tests/")) return error.NotUnderTests;
        try out.writer.print("    _ = @import(\"{s}/{s}\");\n", .{ rel["tests/".len..], root_name });
    }
    try out.writer.writeAll("}\n");
    return out.toOwnedSlice();
}

/// The one executable's import table: each name takes the module most
/// members give it, the first given on a tie (`members` in build.zig's
/// order). Free with `deinit(allocator)`; its names are `members`'.
pub fn importTable(allocator: std.mem.Allocator, members: []const []const Import) !std.StringArrayHashMapUnmanaged(usize) {
    const Vote = struct { key: usize, count: u32 };
    var votes: std.StringArrayHashMapUnmanaged(std.ArrayList(Vote)) = .empty;
    defer {
        for (votes.values()) |*list| list.deinit(allocator);
        votes.deinit(allocator);
    }
    for (members) |imports| for (imports) |imp| {
        const entry = try votes.getOrPut(allocator, imp.name);
        if (!entry.found_existing) entry.value_ptr.* = .empty;
        for (entry.value_ptr.items) |*vote| {
            if (vote.key == imp.key) {
                vote.count += 1;
                break;
            }
        } else try entry.value_ptr.append(allocator, .{ .key = imp.key, .count = 1 });
    };
    var table: std.StringArrayHashMapUnmanaged(usize) = .empty;
    errdefer table.deinit(allocator);
    for (votes.keys(), votes.values()) |name, list| {
        var best = list.items[0];
        for (list.items[1..]) |vote| {
            if (vote.count > best.count) best = vote;
        }
        try table.put(allocator, name, best.key);
    }
    return table;
}

/// Whether every import of a member names the module `table` gives its
/// name - so the member can join the one executable. A name the table lacks
/// does not agree.
pub fn agrees(table: *const std.StringArrayHashMapUnmanaged(usize), imports: []const Import) bool {
    for (imports) |imp| {
        const key = table.get(imp.name) orelse return false;
        if (key != imp.key) return false;
    }
    return true;
}

/// `inner_root`'s path from the directory of `outer_root`, when it lies in
/// that directory or below it (both repository-relative, '/'-separated):
/// the path `outer_root` would `@import` it by as a file. Null otherwise.
pub fn pathFrom(outer_root: []const u8, inner_root: []const u8) ?[]const u8 {
    const dir = std.fs.path.dirnamePosix(outer_root) orelse return null;
    if (!std.mem.startsWith(u8, inner_root, dir) or inner_root.len <= dir.len + 1 or inner_root[dir.len] != '/') return null;
    if (std.mem.eql(u8, inner_root, outer_root)) return null;
    return inner_root[dir.len + 1 ..];
}

/// Whether `source`, a module's root file, imports `rel` as a file
/// (`@import("rel")`). A file belongs to one module per compile, so when a
/// module's root imports another module's root file, the two cannot meet in
/// one executable once anything reaches that declaration: src/webidl/
/// root.zig's `pub const codegen = @import("codegen/root.zig")` against the
/// `codegen` module tests/codegen imports ("file exists in modules 'codegen'
/// and 'webidl'", lane onebin1's first one-binary build).
pub fn importsAsFile(source: []const u8, rel: []const u8) bool {
    var rest = source;
    const open = "@import(\"";
    while (std.mem.indexOf(u8, rest, open)) |at| {
        const after = rest[at + open.len ..];
        if (std.mem.startsWith(u8, after, rel) and after.len > rel.len and after[rel.len] == '"') return true;
        rest = after;
    }
    return false;
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

test "the test files directly in tests/, sorted: not those in a directory, not other files" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "zeta_test.zig", .data = "test {}\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "alpha_test.zig", .data = "test {}\n" });
    // Not test files: a fixture, the suffix alone, a renamed-away test.
    try tmp.dir.writeFile(io, .{ .sub_path = "helper.zig", .data = "" });
    try tmp.dir.writeFile(io, .{ .sub_path = "_test.zig", .data = "" });
    try tmp.dir.writeFile(io, .{ .sub_path = "old_test.zig.skip", .data = "" });
    // In a directory: its suite's.
    try tmp.dir.createDirPath(io, "dom");
    try tmp.dir.writeFile(io, .{ .sub_path = "dom/x_test.zig", .data = "test {}\n" });
    // A directory whose name looks like a test file is not a file.
    try tmp.dir.createDirPath(io, "odd_test.zig");

    const found = try topLevelTestFiles(testing.allocator, io, tmp.dir, "tests");
    defer {
        freeList(testing.allocator, found);
        testing.allocator.free(found);
    }
    try testing.expectEqual(@as(usize, 2), found.len);
    try testing.expectEqualStrings("tests/alpha_test.zig", found[0]);
    try testing.expectEqualStrings("tests/zeta_test.zig", found[1]);
}

test "no test file directly in tests/: an empty list" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "infra");
    try tmp.dir.writeFile(io, .{ .sub_path = "infra/y_test.zig", .data = "test {}\n" });
    const found = try topLevelTestFiles(testing.allocator, io, tmp.dir, "tests");
    defer testing.allocator.free(found);
    try testing.expectEqual(@as(usize, 0), found.len);
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

test "a member's prefix is its directory under tests/, dotted" {
    const a = testing.allocator;
    const html = try memberPrefix(a, "tests/html");
    defer a.free(html);
    try testing.expectEqualStrings("html.", html);
    const runner = try memberPrefix(a, "tests/wpt_runner/");
    defer a.free(runner);
    try testing.expectEqualStrings("wpt_runner.", runner);
    const nested = try memberPrefix(a, "tests/a/b");
    defer a.free(nested);
    try testing.expectEqualStrings("a.b.", nested);
    try testing.expectError(error.NotUnderTests, memberPrefix(a, "src/dom"));
    try testing.expectError(error.NotUnderTests, memberPrefix(a, "tests/"));
}

test "the one executable's root imports each member's root by its path under tests/" {
    const root = try oneBinaryRoot(testing.allocator, &.{ "tests/dom", "tests/html/" }, ".all_tests.zig");
    defer testing.allocator.free(root);
    try testing.expect(std.mem.indexOf(u8, root, "test {\n    _ = @import(\"dom/.all_tests.zig\");\n    _ = @import(\"html/.all_tests.zig\");\n}\n") != null);
    try testing.expect(std.mem.startsWith(u8, root, "//! Generated by build.zig"));
    try testing.expectError(error.NotUnderTests, oneBinaryRoot(testing.allocator, &.{"src/dom"}, ".all_tests.zig"));
}

test "the import table: each name takes the module most members give it, the first on a tie" {
    // tests/runtime's engine-less tier (runtime 9, engine 8) against three
    // members that use the testing graph's (runtime 1, engine 2).
    const html = [_]Import{ .{ .name = "runtime", .key = 1 }, .{ .name = "engine", .key = 2 }, .{ .name = "html", .key = 3 } };
    const v8 = [_]Import{ .{ .name = "runtime", .key = 1 }, .{ .name = "engine", .key = 2 } };
    const runtime = [_]Import{ .{ .name = "runtime", .key = 9 }, .{ .name = "engine", .key = 8 } };
    const dom = [_]Import{.{ .name = "runtime", .key = 1 }};
    var table = try importTable(testing.allocator, &.{ &runtime, &html, &v8, &dom });
    defer table.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 3), table.count());
    try testing.expectEqual(@as(usize, 1), table.get("runtime").?);
    try testing.expectEqual(@as(usize, 2), table.get("engine").?);
    try testing.expectEqual(@as(usize, 3), table.get("html").?);
    try testing.expect(agrees(&table, &html));
    try testing.expect(agrees(&table, &dom));
    try testing.expect(!agrees(&table, &runtime));
    // One of two names disagreeing is enough; a name the table lacks too.
    try testing.expect(!agrees(&table, &.{ .{ .name = "runtime", .key = 1 }, .{ .name = "engine", .key = 8 } }));
    try testing.expect(!agrees(&table, &.{.{ .name = "browser", .key = 4 }}));
    // A tie: the first given.
    var tie = try importTable(testing.allocator, &.{ &.{.{ .name = "x", .key = 7 }}, &.{.{ .name = "x", .key = 5 }} });
    defer tie.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 7), tie.get("x").?);
}

test "importTable frees what it made when an allocation fails" {
    const a = [_]Import{ .{ .name = "runtime", .key = 1 }, .{ .name = "engine", .key = 2 } };
    const b = [_]Import{ .{ .name = "runtime", .key = 9 }, .{ .name = "html", .key = 3 } };
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn run(allocator: std.mem.Allocator, members: []const []const Import) !void {
            var table = try importTable(allocator, members);
            table.deinit(allocator);
        }
    }.run, .{@as([]const []const Import, &.{ &a, &b })});
}

test "a module root's path from another's directory: below it or beside it, never itself or outside" {
    try testing.expectEqualStrings("codegen/root.zig", pathFrom("src/webidl/root.zig", "src/webidl/codegen/root.zig").?);
    try testing.expectEqualStrings("core.zig", pathFrom("src/html/full.zig", "src/html/core.zig").?);
    try testing.expectEqual(@as(?[]const u8, null), pathFrom("src/webidl/root.zig", "src/webidl/root.zig"));
    try testing.expectEqual(@as(?[]const u8, null), pathFrom("src/webidl/root.zig", "src/dom/root.zig"));
    // A directory whose name starts with the other's is not inside it.
    try testing.expectEqual(@as(?[]const u8, null), pathFrom("src/web/root.zig", "src/webidl/root.zig"));
    try testing.expectEqual(@as(?[]const u8, null), pathFrom("root.zig", "src/x.zig"));
}

test "a root that imports another module's root as a file is found; a module import or a longer path is not" {
    const webidl_root =
        \\pub const Opt = wrappers.Opt;
        \\/// WebIDL codegen API
        \\pub const codegen = @import("codegen/root.zig");
        \\const dom = @import("dom");
    ;
    try testing.expect(importsAsFile(webidl_root, "codegen/root.zig"));
    try testing.expect(!importsAsFile(webidl_root, "root.zig"));
    try testing.expect(!importsAsFile(webidl_root, "codegen/root"));
    try testing.expect(!importsAsFile(webidl_root, "odegen/root.zig"));
    try testing.expect(!importsAsFile("const c = @import(\"codegen/root.zig.bak\");", "codegen/root.zig"));
    try testing.expect(!importsAsFile("", "codegen/root.zig"));
}
