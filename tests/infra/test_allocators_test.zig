//! Every allocator a test checks memory with poisons what it frees (lane
//! poison2; tests/test_runner/poisoning.zig). std.testing.allocator does by
//! itself - the Crane test runner makes it with SafeAllocator's
//! `check_write_after_free` - but a bare std.heap.DebugAllocator neither
//! reuses nor writes a freed slot, so a read after a free through it finds
//! the old bytes and the test passes. A test's own allocator (a Browser per
//! thread in a race test) is `@import("root").poisoning.DebugAllocator`
//! instead, a drop-in with the same `.init`, `allocator()` and `deinit()`.
//!
//! This check reads every Zig file of tests/ and src/ and fails on a bare
//! one, so a new test poisons too. An executable's allocator is not a
//! test's - Crane's library, its tools and hosts keep theirs - and is listed
//! in `executables`, with what it is.

const std = @import("std");

/// The files that may make a bare std.heap.DebugAllocator: not tests.
const executables = [_]struct { path: []const u8, why: []const u8 }{
    .{ .path = "src/webidl/parser/main.zig", .why = "the WebIDL parser's command-line tool, an executable" },
    .{ .path = "tests/test_runner/poisoning.zig", .why = "defines the drop-in, around std's DebugAllocator, and tests std's alone" },
};

/// tests/ directories the check does not read: not Crane's tests.
const skipped_test_dirs = [_][]const u8{
    // Upstream WPT and its tools (and Crane tests, which are not Zig).
    "wpt",
    // The WPT runner: an executable whose sweep allocator is
    // runner_allocator.zig's DebugAllocator with Poisoning in front.
    "wpt_runner",
};

/// The lines of `source` that make a bare std.heap.DebugAllocator - outside
/// a comment or a multiline string.
fn bareLines(source: []const u8, out: *std.ArrayList(usize), gpa: std.mem.Allocator) !void {
    // Spelled in two pieces, so this file, which the check reads too, makes
    // none of its own.
    const needle = "std.heap." ++ "DebugAllocator(";
    var lines = std.mem.splitScalar(u8, source, '\n');
    var number: usize = 0;
    while (lines.next()) |line| {
        number += 1;
        const at = std.mem.indexOf(u8, line, needle) orelse continue;
        const trimmed = std.mem.trimStart(u8, line, " \t");
        if (std.mem.startsWith(u8, trimmed, "\\\\")) continue;
        if (std.mem.indexOf(u8, line[0..at], "//")) |_| continue;
        try out.append(gpa, number);
    }
}

test "the bare-DebugAllocator check finds a declaration, never a comment or a string" {
    const gpa = std.testing.allocator;
    var found: std.ArrayList(usize) = .empty;
    defer found.deinit(gpa);
    const bare = "std.heap." ++ "DebugAllocator(";
    try bareLines(
        "    var gpa: " ++ bare ++ ".{ .stack_trace_frames = 0 }) = .init;\n" ++
            "    // a " ++ bare ++ ".{}) in a comment\n" ++
            "    \\\\" ++ bare ++ ".{}) in a string\n" ++
            "    debug: " ++ bare ++ ".{}) = .init, // a field\n" ++
            "    var ok: @import(\"root\").poisoning.DebugAllocator(.{}) = .init;\n",
        &found,
        gpa,
    );
    try std.testing.expectEqualSlices(usize, &.{ 1, 4 }, found.items);
}

/// Checks every Zig file under `top/sub` (`sub` empty: all of `top`), and
/// counts the files and the bare lines.
fn checkTree(top: []const u8, sub: []const u8, files: *usize, wrong: *usize) !void {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    const root = if (sub.len == 0) try gpa.dupe(u8, top) else try std.fmt.allocPrint(gpa, "{s}/{s}", .{ top, sub });
    defer gpa.free(root);
    var dir = try std.Io.Dir.cwd().openDir(io, root, .{ .iterate = true });
    defer dir.close(io);
    var walker = try dir.walk(gpa);
    defer walker.deinit();
    walk: while (try walker.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.path, ".zig")) continue;
        const path = try std.fmt.allocPrint(gpa, "{s}/{s}", .{ root, entry.path });
        defer gpa.free(path);
        for (executables) |e| if (std.mem.eql(u8, e.path, path)) continue :walk;
        files.* += 1;
        const source = try dir.readFileAlloc(io, entry.path, gpa, .limited(64 << 20));
        defer gpa.free(source);
        var found: std.ArrayList(usize) = .empty;
        defer found.deinit(gpa);
        try bareLines(source, &found, gpa);
        for (found.items) |line| {
            wrong.* += 1;
            std.debug.print("{s}:{d}: a bare std.heap.DebugAllocator keeps a freed slot's bytes, so a read after a free passes: make a test's own allocator `@import(\"root\").poisoning.DebugAllocator(...)` (tests/test_runner/poisoning.zig; same .init, allocator() and deinit()); an executable's allocator is listed in tests/infra/test_allocators_test.zig `executables`, with what it is\n", .{ path, line });
        }
    }
}

test "no test makes a bare std.heap.DebugAllocator: a test's own allocator is poisoning.DebugAllocator, which poisons what it frees" {
    const io = std.testing.io;
    var files: usize = 0;
    var wrong: usize = 0;
    try checkTree("src", "", &files, &wrong);
    // tests/, each directory but the skipped ones, and its own files.
    var tests_dir = try std.Io.Dir.cwd().openDir(io, "tests", .{ .iterate = true });
    defer tests_dir.close(io);
    var it = tests_dir.iterate();
    top: while (try it.next(io)) |entry| {
        switch (entry.kind) {
            .directory => {
                for (skipped_test_dirs) |skip| if (std.mem.eql(u8, skip, entry.name)) continue :top;
                try checkTree("tests", entry.name, &files, &wrong);
            },
            .file => if (std.mem.endsWith(u8, entry.name, ".zig")) {
                files += 1;
                const gpa = std.testing.allocator;
                const source = try tests_dir.readFileAlloc(io, entry.name, gpa, .limited(64 << 20));
                defer gpa.free(source);
                var found: std.ArrayList(usize) = .empty;
                defer found.deinit(gpa);
                try bareLines(source, &found, gpa);
                for (found.items) |line| {
                    wrong += 1;
                    std.debug.print("tests/{s}:{d}: a bare std.heap.DebugAllocator: make it `@import(\"root\").poisoning.DebugAllocator(...)`\n", .{ entry.name, line });
                }
            },
            else => {},
        }
    }
    // Both trees are there: thousands of files.
    try std.testing.expect(files > 1000);
    try std.testing.expectEqual(@as(usize, 0), wrong);
}

test "every listed executable is still there and still makes one" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    for (executables) |e| {
        const source = std.Io.Dir.cwd().readFileAlloc(io, e.path, gpa, .limited(64 << 20)) catch |err| {
            std.debug.print("{s}: listed in `executables` ({s}) but cannot be read: {t} - remove it from the list\n", .{ e.path, e.why, err });
            return err;
        };
        defer gpa.free(source);
        var found: std.ArrayList(usize) = .empty;
        defer found.deinit(gpa);
        try bareLines(source, &found, gpa);
        if (found.items.len == 0) {
            std.debug.print("{s}: listed in `executables` ({s}) but makes no bare std.heap.DebugAllocator - remove it from the list\n", .{ e.path, e.why });
            return error.TestUnexpectedResult;
        }
    }
}
