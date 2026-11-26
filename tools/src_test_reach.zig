//! Which src/ test blocks no test step runs (lane core1, 2026-11-24).
//!
//! `zig test` collects the test blocks of its ROOT module's files only, and
//! only from a file something analyzes. A test in a module no step roots, or
//! in a file reached only through a declaration nothing analyzes, compiles
//! nowhere and passes nothing: html_core's 320 never ran, and one of them pinned
//! the double free flk4 found by other means
//! (docs/lessons/testing-a-test-block-in-a-module-no-step-roots-never-runs.md).
//! Following imports cannot tell which files are analyzed; the executables
//! can. So this reads the binaries, not the imports:
//!
//! - build.zig hands it every test executable rooted in src/, as `--suite=
//!   <root's directory>=<file>`, where the file holds the executable's test
//!   names (`test_launcher <exe> --list`, one per line). A name is the test's
//!   file, its path under the root's directory with '/' as '.' and no `.zig`,
//!   then `.test.<name>`, `.test_<n>` (an unnamed block) or `.decltest.<name>`;
//!   a block inside a container puts the container's name before that.
//! - It counts every file's test blocks under src/ (std.zig.Tokenizer: never
//!   one in a comment or a string), except under each `--not-built=<dir>`, a
//!   directory this configuration compiles nothing of (-Dcdp=false's
//!   src/devtools).
//! - A file has unrun blocks when fewer of its tests are listed than it has
//!   blocks, in every suite. Each one fails unless tools/src_test_reach_baseline.txt
//!   records it with its count and why. The baseline only goes down: a count
//!   that rises fails, and so does one that fell. `-- --update` records the
//!   lower counts, and refuses a new file or a rise.

const std = @import("std");

/// The baseline, relative to the repository root.
pub const baseline_path = "tools/src_test_reach_baseline.txt";

/// The test declarations in `source`: `test "name" {`, `test name {` and
/// `test {` - at any depth, as Zig collects them. `test` is a keyword, so a
/// token of it is a test declaration's.
pub fn countTestBlocks(source: [:0]const u8) u32 {
    var n: u32 = 0;
    var tokenizer = std.zig.Tokenizer.init(source);
    while (true) {
        const token = tokenizer.next();
        if (token.tag == .eof) return n;
        if (token.tag == .keyword_test) n += 1;
    }
}

/// The test-name prefix of the file `path` in an executable rooted in
/// `root_dir`: "src/html/parser/tokenizer.zig" in "src/html" is
/// "parser.tokenizer". Null when `path` is not a .zig file under `root_dir`.
pub fn filePrefix(gpa: std.mem.Allocator, root_dir: []const u8, path: []const u8) !?[]u8 {
    if (!std.mem.endsWith(u8, path, ".zig")) return null;
    if (!std.mem.startsWith(u8, path, root_dir) or path.len <= root_dir.len + 1 or path[root_dir.len] != '/') return null;
    const prefix = try gpa.dupe(u8, path[root_dir.len + 1 .. path.len - ".zig".len]);
    std.mem.replaceScalar(u8, prefix, '/', '.');
    return prefix;
}

/// Where a test's namespace ends in its name: ".test.", ".test_<n>" and
/// ".decltest.".
const markers = [_][]const u8{ ".test.", ".test_", ".decltest." };

/// The file prefix, among `known` (prefix -> path), whose test `name` is: the
/// longest one that is the name's namespace or a dotted start of it (a
/// container's test). Null when none is. A marker can also sit inside a
/// file's prefix (a file named test.zig) or a test's own name, so each is
/// tried from the left until a namespace before it is known.
pub fn attribute(name: []const u8, known: *const std.StringHashMapUnmanaged([]const u8)) ?[]const u8 {
    var at: usize = 0;
    while (at < name.len) {
        // The leftmost marker at or after `at`.
        var cut: ?usize = null;
        for (markers) |marker| if (std.mem.indexOfPos(u8, name, at, marker)) |i| {
            if (cut == null or i < cut.?) cut = i;
        };
        const end = cut orelse return null;
        // The namespace, then each dotted start of it, longest first.
        var namespace = name[0..end];
        while (true) {
            if (known.getKey(namespace)) |key| return key;
            const dot = std.mem.lastIndexOfScalar(u8, namespace, '.') orelse break;
            namespace = namespace[0..dot];
        }
        at = end + 1;
    }
    return null;
}

/// A baseline line: a file's unrun blocks, and why they are allowed.
pub const Entry = struct {
    unrun: u32,
    reason: []const u8,
};

/// The baseline: `<path>\t<unrun blocks>\t<why>` per line, `#` comments.
pub const Baseline = struct {
    entries: std.StringArrayHashMapUnmanaged(Entry) = .empty,

    pub fn parse(arena: std.mem.Allocator, text: []const u8) !Baseline {
        var b: Baseline = .{};
        var lines = std.mem.splitScalar(u8, text, '\n');
        while (lines.next()) |raw| {
            const line = std.mem.trimEnd(u8, raw, "\r");
            if (line.len == 0 or line[0] == '#') continue;
            var fields = std.mem.splitScalar(u8, line, '\t');
            const path = fields.next() orelse return error.BadBaselineLine;
            const count = fields.next() orelse return error.BadBaselineLine;
            const reason = fields.rest();
            if (path.len == 0 or reason.len == 0) return error.BadBaselineLine;
            const unrun = std.fmt.parseUnsigned(u32, count, 10) catch return error.BadBaselineLine;
            try b.entries.put(arena, path, .{ .unrun = unrun, .reason = reason });
        }
        return b;
    }
};

/// A file some of whose test blocks no executable lists.
pub const Unrun = struct {
    path: []const u8,
    blocks: u32,
    unrun: u32,
};

/// What the baseline says about the files with unrun blocks.
pub const Problem = union(enum) {
    /// A file the baseline does not name.
    new: Unrun,
    /// More unrun blocks than the baseline allows.
    rose: struct { now: Unrun, was: u32 },
    /// Fewer unrun blocks than the baseline records (0: all run now).
    fell: struct { path: []const u8, now: u32, was: u32 },
};

fn lessThanPath(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

/// Every problem, in path order: the files of `unrun` (each once) against
/// `baseline`.
pub fn judge(arena: std.mem.Allocator, unrun: []const Unrun, baseline: *const Baseline) ![]Problem {
    var problems: std.ArrayList(Problem) = .empty;
    var by_path: std.StringHashMapUnmanaged(Unrun) = .empty;
    var paths: std.ArrayList([]const u8) = .empty;
    for (unrun) |u| {
        try by_path.put(arena, u.path, u);
        try paths.append(arena, u.path);
    }
    for (baseline.entries.keys()) |path| if (!by_path.contains(path)) try paths.append(arena, path);
    std.mem.sort([]const u8, paths.items, {}, lessThanPath);
    for (paths.items) |path| {
        const now = by_path.get(path);
        if (baseline.entries.get(path)) |was| {
            const now_count = if (now) |n| n.unrun else 0;
            if (now_count > was.unrun) {
                try problems.append(arena, .{ .rose = .{ .now = now.?, .was = was.unrun } });
            } else if (now_count < was.unrun) {
                try problems.append(arena, .{ .fell = .{ .path = path, .now = now_count, .was = was.unrun } });
            }
        } else if (now) |n| try problems.append(arena, .{ .new = n });
    }
    return problems.items;
}

/// The baseline file's opening comment, which `--update` writes.
const baseline_header =
    \\# tools/src_test_reach.zig: src/ files with test blocks no test step runs, each with its
    \\# count of unrun blocks and why. Only goes down: `zig build check-src-tests -j2 -- --update`
    \\# after wiring or deleting some refuses a new file or a rise. A new line's reason is the
    \\# integrator's to review.
    \\
;

/// The baseline `--update` writes: each file's lower count, with its reason;
/// error.BaselineWouldRise on a new file or a rise.
pub fn updated(arena: std.mem.Allocator, unrun: []const Unrun, baseline: *const Baseline) ![]const u8 {
    var out: std.Io.Writer.Allocating = .init(arena);
    try out.writer.writeAll(baseline_header);
    const sorted = try arena.dupe(Unrun, unrun);
    std.mem.sort(Unrun, sorted, {}, struct {
        fn lessThan(_: void, a: Unrun, b: Unrun) bool {
            return std.mem.lessThan(u8, a.path, b.path);
        }
    }.lessThan);
    for (sorted) |u| {
        const was = baseline.entries.get(u.path) orelse return error.BaselineWouldRise;
        if (u.unrun > was.unrun) return error.BaselineWouldRise;
        try out.writer.print("{s}\t{d}\t{s}\n", .{ u.path, u.unrun, was.reason });
    }
    return out.written();
}

/// What the command line asks.
const Args = struct {
    suites: []const Suite = &.{},
    not_built: []const []const u8 = &.{},
    update: bool = false,
    list: bool = false,

    const Suite = struct { root_dir: []const u8, names_file: []const u8 };

    fn parse(arena: std.mem.Allocator, argv: []const []const u8) !Args {
        var a: Args = .{};
        var suites: std.ArrayList(Suite) = .empty;
        var not_built: std.ArrayList([]const u8) = .empty;
        for (argv) |arg| {
            if (std.mem.startsWith(u8, arg, "--suite=")) {
                const v = arg["--suite=".len..];
                const eq = std.mem.indexOfScalar(u8, v, '=') orelse return error.BadSuite;
                try suites.append(arena, .{ .root_dir = v[0..eq], .names_file = v[eq + 1 ..] });
            } else if (std.mem.startsWith(u8, arg, "--not-built=")) {
                try not_built.append(arena, std.mem.trimEnd(u8, arg["--not-built=".len..], "/"));
            } else if (std.mem.eql(u8, arg, "--update")) {
                a.update = true;
            } else if (std.mem.eql(u8, arg, "--list")) {
                a.list = true;
            } else return error.UnknownOption;
        }
        a.suites = suites.items;
        a.not_built = not_built.items;
        return a;
    }
};

/// Whether `path` is under one of `dirs`.
fn underAny(path: []const u8, dirs: []const []const u8) bool {
    for (dirs) |dir| if (std.mem.startsWith(u8, path, dir) and path.len > dir.len and path[dir.len] == '/') return true;
    return false;
}

/// Every src/ file (of `dir`) with test blocks no suite of `args` lists: its
/// blocks, and how many of them none lists. A file in several suites' modules
/// counts the suite that lists the most of it.
pub fn find(arena: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, args: Args) ![]Unrun {
    var blocks: std.StringArrayHashMapUnmanaged(u32) = .empty;
    var src = try dir.openDir(io, "src", .{ .iterate = true });
    defer src.close(io);
    var walker = try src.walk(arena);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.path, ".zig")) continue;
        const path = try std.fmt.allocPrint(arena, "src/{s}", .{entry.path});
        std.mem.replaceScalar(u8, path, '\\', '/');
        if (underAny(path, args.not_built)) continue;
        const source = try dir.readFileAllocOptions(io, path, arena, .limited(64 << 20), .of(u8), 0);
        const n = countTestBlocks(source);
        if (n != 0) try blocks.put(arena, path, n);
    }

    var listed: std.StringHashMapUnmanaged(u32) = .empty;
    for (args.suites) |suite| {
        var known: std.StringHashMapUnmanaged([]const u8) = .empty;
        for (blocks.keys()) |path| if (try filePrefix(arena, suite.root_dir, path)) |prefix| try known.put(arena, prefix, path);
        const names = try dir.readFileAlloc(io, suite.names_file, arena, .limited(256 << 20));
        var counts: std.StringHashMapUnmanaged(u32) = .empty;
        var lines = std.mem.splitScalar(u8, names, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            const prefix = attribute(line, &known) orelse continue;
            const gop = try counts.getOrPut(arena, known.get(prefix).?);
            gop.value_ptr.* = if (gop.found_existing) gop.value_ptr.* + 1 else 1;
        }
        var it = counts.iterator();
        while (it.next()) |e| {
            const gop = try listed.getOrPut(arena, e.key_ptr.*);
            if (!gop.found_existing or e.value_ptr.* > gop.value_ptr.*) gop.value_ptr.* = e.value_ptr.*;
        }
    }
    var unrun: std.ArrayList(Unrun) = .empty;
    for (blocks.keys(), blocks.values()) |path, n| {
        const ran = @min(listed.get(path) orelse 0, n);
        if (ran < n) try unrun.append(arena, .{ .path = path, .blocks = n, .unrun = n - ran });
    }
    // In path order. (Sorting the map's keys alone, as a first version did,
    // left each count with another file's path.)
    std.mem.sort(Unrun, unrun.items, {}, struct {
        fn lessThan(_: void, a: Unrun, b: Unrun) bool {
            return std.mem.lessThan(u8, a.path, b.path);
        }
    }.lessThan);
    return unrun.items;
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    const argv = try init.minimal.args.toSlice(arena);
    const args = try Args.parse(arena, argv[1..]);
    const cwd = std.Io.Dir.cwd();
    const unrun = try find(arena, io, cwd, args);
    const baseline_text = cwd.readFileAlloc(io, baseline_path, arena, .limited(16 << 20)) catch |err| switch (err) {
        error.FileNotFound => "",
        else => return err,
    };
    const baseline = try Baseline.parse(arena, baseline_text);

    if (args.list) {
        for (unrun) |u| try out.print("{s}: {d} of {d} test blocks run in no test step\n", .{ u.path, u.unrun, u.blocks });
        return;
    }
    if (args.update) {
        const text = updated(arena, unrun, &baseline) catch |err| switch (err) {
            error.BaselineWouldRise => {
                try out.print("check-src-tests: --update refuses: a file's unrun test blocks rose, or a new file has some (run it without --update to see which); the baseline only goes down\n", .{});
                try out.flush();
                std.process.exit(1);
            },
            else => return err,
        };
        try cwd.writeFile(io, .{ .sub_path = baseline_path, .data = text });
        try out.print("check-src-tests: {s} records {d} file(s)\n", .{ baseline_path, unrun.len });
        return;
    }
    const problems = try judge(arena, unrun, &baseline);
    for (problems) |p| switch (p) {
        .new => |u| try out.print("{s}: error: {d} of its {d} test blocks run in no test step - root its module in a test executable (build.zig addSuiteRun), or name the file in a test block its root analyzes (`_ = @import(...)`); a test that pins nothing else is deleted (docs/lessons/testing-a-test-block-in-a-module-no-step-roots-never-runs.md)\n", .{ u.path, u.unrun, u.blocks }),
        .rose => |r| try out.print("{s}: error: {d} of its {d} test blocks run in no test step; the baseline allows {d}, and only goes down\n", .{ r.now.path, r.now.unrun, r.now.blocks, r.was }),
        .fell => |f| try out.print("{s}: error: {d} test blocks run in no test step where the baseline records {d}: record the lower count (check-src-tests -- --update)\n", .{ f.path, f.now, f.was }),
    };
    if (problems.len != 0) {
        try out.print("\ncheck-src-tests: {d} problem(s) (tools/src_test_reach.zig; {s})\n", .{ problems.len, baseline_path });
        try out.flush();
        std.process.exit(1);
    }
    var allowed: u32 = 0;
    for (unrun) |u| allowed += u.unrun;
    try out.print("check-src-tests: every src/ test block runs in a test step, but the baseline's {d} in {d} file(s)\n", .{ allowed, unrun.len });
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "every form of test declaration counts, at any depth; the word in a comment or a string does not" {
    try testing.expectEqual(@as(u32, 5), countTestBlocks(
        \\const std = @import("std");
        \\// test "in a comment" {
        \\const text = "test \"in a string\" {";
        \\test "named" {}
        \\test decl_name {}
        \\test {
        \\    _ = text;
        \\}
        \\const Container = struct {
        \\    test "inside a container" {}
        \\};
        \\fn decl_name() void {}
        \\test "a name with test in it: .test. and test {" {}
    ));
    try testing.expectEqual(@as(u32, 0), countTestBlocks("const testing = @import(\"std\").testing;\n"));
}

test "a file's prefix is its path under the root's directory, dotted, without .zig" {
    const gpa = testing.allocator;
    const a = (try filePrefix(gpa, "src/html", "src/html/parser/tokenizer.zig")).?;
    defer gpa.free(a);
    try testing.expectEqualStrings("parser.tokenizer", a);
    const b = (try filePrefix(gpa, "src/html", "src/html/full.zig")).?;
    defer gpa.free(b);
    try testing.expectEqualStrings("full", b);
    try testing.expect((try filePrefix(gpa, "src/html", "src/htmlx/a.zig")) == null);
    try testing.expect((try filePrefix(gpa, "src/html", "src/dom/a.zig")) == null);
    try testing.expect((try filePrefix(gpa, "src/html", "src/html/notes.md")) == null);
}

test "a test name belongs to the longest file prefix its namespace starts with, past a marker inside the name" {
    var known: std.StringHashMapUnmanaged([]const u8) = .empty;
    defer known.deinit(testing.allocator);
    try known.put(testing.allocator, "root", "src/x/root.zig");
    try known.put(testing.allocator, "parser", "src/x/parser.zig");
    try known.put(testing.allocator, "parser.tokenizer", "src/x/parser/tokenizer.zig");
    try known.put(testing.allocator, "unit.test", "src/x/unit/test.zig");
    try testing.expectEqualStrings("parser.tokenizer", attribute("parser.tokenizer.test.self-closing tag", &known).?);
    try testing.expectEqualStrings("parser", attribute("parser.test.a test.with dots", &known).?);
    try testing.expectEqualStrings("root", attribute("root.test_0", &known).?);
    try testing.expectEqualStrings("parser", attribute("parser.decltest.parse", &known).?);
    // A container's test: the file is the longest known start of the namespace.
    try testing.expectEqualStrings("parser.tokenizer", attribute("parser.tokenizer.State.test.reset", &known).?);
    // A file named test.zig: the first ".test." is part of its prefix.
    try testing.expectEqualStrings("unit.test", attribute("unit.test.test.runs", &known).?);
    try testing.expect(attribute("elsewhere.test.x", &known) == null);
    try testing.expect(attribute("no marker at all", &known) == null);
}

test "the baseline is path, count and reason per line; comments and blank lines are skipped" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const b = try Baseline.parse(arena, "# tools/src_test_reach.zig: the src/ files whose test blocks no step runs.\n" ++
        "\n" ++
        "src/runtime/slab_allocator.zig\t10\truntime is wired after hard1 merges\n" ++
        "src/platform/clock.zig\t5\tthe platform block is wired after bp1 P4\n" ++
        "\n");
    try testing.expectEqual(@as(usize, 2), b.entries.count());
    try testing.expectEqual(@as(u32, 10), b.entries.get("src/runtime/slab_allocator.zig").?.unrun);
    try testing.expectEqualStrings("the platform block is wired after bp1 P4", b.entries.get("src/platform/clock.zig").?.reason);
    try testing.expectError(error.BadBaselineLine, Baseline.parse(arena, "src/a.zig\t3\n"));
    try testing.expectError(error.BadBaselineLine, Baseline.parse(arena, "src/a.zig\tthree\twhy\n"));
}

test "judge: a new file and a rise fail; a fall fails too until --update records it; an equal count passes" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const baseline = try Baseline.parse(arena, "src/a.zig\t2\twhy a\n" ++
        "src/b.zig\t3\twhy b\n" ++
        "src/c.zig\t1\twhy c\n" ++
        "src/d.zig\t4\twhy d\n" ++
        "\n");
    const unrun = [_]Unrun{
        .{ .path = "src/a.zig", .blocks = 2, .unrun = 2 },
        .{ .path = "src/b.zig", .blocks = 5, .unrun = 4 },
        .{ .path = "src/d.zig", .blocks = 4, .unrun = 1 },
        .{ .path = "src/e.zig", .blocks = 1, .unrun = 1 },
    };
    const problems = try judge(arena, &unrun, &baseline);
    try testing.expectEqual(@as(usize, 4), problems.len);
    try testing.expectEqual(@as(u32, 3), problems[0].rose.was);
    try testing.expectEqualStrings("src/b.zig", problems[0].rose.now.path);
    try testing.expectEqualStrings("src/c.zig", problems[1].fell.path);
    try testing.expectEqual(@as(u32, 0), problems[1].fell.now);
    try testing.expectEqualStrings("src/d.zig", problems[2].fell.path);
    try testing.expectEqual(@as(u32, 1), problems[2].fell.now);
    try testing.expectEqualStrings("src/e.zig", problems[3].new.path);
}

test "--update writes the lower counts with their reasons, drops what runs now, and refuses a rise or a new file" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const baseline = try Baseline.parse(arena, "src/a.zig\t2\twhy a\n" ++
        "src/c.zig\t1\twhy c\n" ++
        "src/d.zig\t4\twhy d\n" ++
        "\n");
    const lower = [_]Unrun{
        .{ .path = "src/a.zig", .blocks = 2, .unrun = 2 },
        .{ .path = "src/d.zig", .blocks = 4, .unrun = 1 },
    };
    const text = try updated(arena, &lower, &baseline);
    try testing.expect(std.mem.indexOf(u8, text, "src/a.zig\t2\twhy a\n") != null);
    try testing.expect(std.mem.indexOf(u8, text, "src/d.zig\t1\twhy d\n") != null);
    try testing.expect(std.mem.indexOf(u8, text, "src/c.zig") == null);
    const rose = [_]Unrun{.{ .path = "src/a.zig", .blocks = 3, .unrun = 3 }};
    try testing.expectError(error.BaselineWouldRise, updated(arena, &rose, &baseline));
    const new = [_]Unrun{.{ .path = "src/z.zig", .blocks = 1, .unrun = 1 }};
    try testing.expectError(error.BaselineWouldRise, updated(arena, &new, &baseline));
}

test "find: each file's own blocks against the tests listed for it, across suites, but for directories not built" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "src/mod/sub");
    try tmp.dir.createDirPath(io, "src/off");
    try tmp.dir.writeFile(io, .{ .sub_path = "src/mod/root.zig", .data = "test {\n    _ = @import(\"z.zig\");\n}\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "src/mod/z.zig", .data = "test \"one\" {}\ntest \"two\" {}\ntest \"three\" {}\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "src/mod/a.zig", .data = "test \"never collected\" {}\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "src/mod/sub/half.zig", .data = "test \"listed\" {}\ntest \"not\" {}\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "src/off/x.zig", .data = "test \"another target's\" {}\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "names.txt", .data = "root.test_0\nz.test.one\nz.test.two\nz.test.three\nsub.half.test.listed\n" });
    const unrun = try find(arena, io, tmp.dir, .{
        .suites = &.{.{ .root_dir = "src/mod", .names_file = "names.txt" }},
        .not_built = &.{"src/off"},
    });
    try testing.expectEqual(@as(usize, 2), unrun.len);
    try testing.expectEqualStrings("src/mod/a.zig", unrun[0].path);
    try testing.expectEqual(@as(u32, 1), unrun[0].blocks);
    try testing.expectEqual(@as(u32, 1), unrun[0].unrun);
    try testing.expectEqualStrings("src/mod/sub/half.zig", unrun[1].path);
    try testing.expectEqual(@as(u32, 2), unrun[1].blocks);
    try testing.expectEqual(@as(u32, 1), unrun[1].unrun);
}
