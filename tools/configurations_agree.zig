//! A fact of the configured build that must not depend on a flag, checked on
//! the configurations themselves: `configurations_agree` counts a text in the
//! binary build configuration of several configures of one build root, and
//! fails unless every count is the same and none is zero.
//!
//! Why it exists (lane build3, 2026-11-13): build.zig tells each test
//! executable whether it links the engine, in a generated suite.zig. It
//! decided that by looking for the engine adapter's C++ source among the
//! executable's own sources - and under -Dsanitize-thread the adapter
//! compiles that source apart, into a library beside the executable. So in a
//! ThreadSanitizer build 9 of the 10 engine-running test executables were
//! told they had no engine: no engine start before the first thread, no
//! engine counters in the process-state check, no busy Browser under
//! -Dmany-browsers. Nothing failed; a gate was testing less than it said.
//! Whether an executable links the engine is now the build's own record of
//! what it linked, and this check holds the result: the number of suite.zig
//! files that import the engine (or the browser module) is the same with and
//! without the sanitizer. A generated file's text is in the binary
//! configuration (a WriteFile step's contents), so a configure is enough:
//! nothing is built.
//!
//! build.zig runs it over configures it makes itself (`zig build
//! --print-configuration-path <flags>`, each one's printed path captured in a
//! file):
//!
//!     configurations_agree --what=<what is counted> --needle=<text>
//!         --name=<flags, for the report> <file holding a configuration's path>
//!         --name=<flags> <file> ...
//!
//! std-only; `zig build test` runs its tests (tools-configurations_agree).

const std = @import("std");
// stdout as a stream: Zig 0.17's positional File.writer overwrites a shared log.
const stdout_stream = @import("stdout_stream.zig");

/// One configuration: what the report calls it, and how often it holds the
/// needle.
pub const Counted = struct {
    name: []const u8,
    count: usize,
};

/// What a set of counts says.
pub const Verdict = enum {
    /// Every configuration holds the needle the same number of times, at
    /// least once.
    agree,
    /// Two configurations hold it a different number of times.
    differ,
    /// Every count is zero: the check is looking for a text the build no
    /// longer writes, and would pass whatever the build did.
    absent,
    /// Fewer than two configurations: nothing to compare.
    too_few,
};

/// The argument this tool is given its needle in. A configuration that holds
/// the check holds that argument too - a Run step's arguments are in the
/// configuration - so the needle after this prefix is the check's own, not
/// the fact it counts.
const needle_flag = "--needle=";

/// How often `needle` occurs in `configuration`, a binary build
/// configuration's bytes - not counting this check's own argument.
pub fn countOf(configuration: []const u8, needle: []const u8) usize {
    var count: usize = 0;
    var from: usize = 0;
    while (std.mem.indexOfPos(u8, configuration, from, needle)) |at| : (from = at + needle.len) {
        if (!std.mem.endsWith(u8, configuration[0..at], needle_flag)) count += 1;
    }
    return count;
}

pub fn verdictOf(counted: []const Counted) Verdict {
    if (counted.len < 2) return .too_few;
    const first = counted[0].count;
    for (counted[1..]) |c| if (c.count != first) return .differ;
    return if (first == 0) .absent else .agree;
}

/// The path `zig build --print-configuration-path` printed, from the file its
/// output was captured in: the text without the line's end.
pub fn pathIn(captured: []const u8) []const u8 {
    return std.mem.trim(u8, captured, " \t\r\n");
}

fn usage() noreturn {
    std.debug.print("usage: configurations_agree --what=<what is counted> --needle=<text> --name=<flags> <file holding a configuration's path> --name=<flags> <file> ...\n", .{});
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;

    var what: ?[]const u8 = null;
    var needle: ?[]const u8 = null;
    var name: ?[]const u8 = null;
    var named: std.ArrayList(struct { name: []const u8, capture: []const u8 }) = .empty;
    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--what=")) {
            what = try arena.dupe(u8, arg["--what=".len..]);
        } else if (std.mem.startsWith(u8, arg, needle_flag)) {
            needle = try arena.dupe(u8, arg[needle_flag.len..]);
        } else if (std.mem.startsWith(u8, arg, "--name=")) {
            name = try arena.dupe(u8, arg["--name=".len..]);
        } else {
            try named.append(arena, .{ .name = name orelse usage(), .capture = try arena.dupe(u8, arg) });
            name = null;
        }
    }
    if (what == null or needle == null or needle.?.len == 0 or name != null) usage();

    var counted: std.ArrayList(Counted) = .empty;
    for (named.items) |n| {
        const captured = try std.Io.Dir.cwd().readFileAlloc(io, n.capture, arena, .limited(1 << 16));
        const configuration = try std.Io.Dir.cwd().readFileAlloc(io, pathIn(captured), arena, .limited(256 << 20));
        try counted.append(arena, .{ .name = n.name, .count = countOf(configuration, needle.?) });
    }

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = stdout_stream.writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    const verdict = verdictOf(counted.items);
    try out.print("configurations agree: {s}: {s}\n", .{ what.?, switch (verdict) {
        .agree => "the same in every configuration",
        .differ => "DIFFERS between configurations",
        .absent => "NOT FOUND in any configuration",
        .too_few => "fewer than two configurations to compare",
    } });
    for (counted.items) |c| try out.print("  {s}: {d}\n", .{ if (c.name.len == 0) "(no flag)" else c.name, c.count });
    switch (verdict) {
        .agree => return,
        .differ => try out.print(
            \\
            \\The build writes this text for a fact that these flags must not change.
            \\A count that differs means build.zig decided the fact from something a
            \\flag changes - how a source is compiled, which module it lands on -
            \\and not from what the build itself did.
            \\
        , .{}),
        .absent => try out.print(
            \\
            \\No configuration holds the text: build.zig no longer writes it as this
            \\check spells it, so the check would pass whatever the build did. Give
            \\the check the text the build writes now.
            \\
        , .{}),
        .too_few => {},
    }
    try out.flush();
    std.process.exit(1);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

const engine_line = "pub const engine: ?type = @import(\"engine\");";

/// A configuration's bytes as the check meets them: binary, with generated
/// files' texts inside.
fn configurationWith(comptime with_engine: usize, comptime without: usize) []const u8 {
    const with_text: []const u8 = "//! Generated by build.zig\npub const name = \"tests-dom\";\n" ++ engine_line ++ "\n\x00\x00";
    const without_text: []const u8 = "//! Generated by build.zig\npub const name = \"tests-url\";\npub const engine: ?type = null;\n\x00";
    comptime var bytes: []const u8 = "\x00\x01\x7f";
    inline for (0..with_engine) |_| bytes = bytes ++ with_text;
    inline for (0..without) |_| bytes = bytes ++ without_text;
    return bytes ++ "\xff\xfe";
}

test "a text is counted wherever it occurs in a configuration's bytes" {
    try testing.expectEqual(@as(usize, 10), countOf(configurationWith(10, 129), engine_line));
    try testing.expectEqual(@as(usize, 1), countOf(configurationWith(1, 138), engine_line));
    try testing.expectEqual(@as(usize, 0), countOf(configurationWith(0, 139), engine_line));
    try testing.expectEqual(@as(usize, 0), countOf("", engine_line));
}

test "the check's own argument, which every configuration that holds the check also holds, is not counted" {
    const own = "\x00" ++ needle_flag ++ engine_line ++ "\x00--name=-Dsanitize-thread\x00";
    try testing.expectEqual(@as(usize, 0), countOf(own, engine_line));
    try testing.expectEqual(@as(usize, 10), countOf(comptime configurationWith(10, 129) ++ own, engine_line));
    try testing.expectEqual(@as(usize, 10), countOf(comptime own ++ configurationWith(10, 129), engine_line));
    // Only that argument: the same text after anything else counts.
    try testing.expectEqual(@as(usize, 1), countOf("--needle " ++ engine_line, engine_line));
}

test "the counts agree when every configuration holds the text equally often" {
    try testing.expectEqual(Verdict.agree, verdictOf(&.{ .{ .name = "", .count = 10 }, .{ .name = "-Dsanitize-thread", .count = 10 } }));
    try testing.expectEqual(Verdict.agree, verdictOf(&.{ .{ .name = "a", .count = 3 }, .{ .name = "b", .count = 3 }, .{ .name = "c", .count = 3 } }));
}

test "the defect this check was written for: 10 engine-running test executables, 1 under the sanitizer" {
    // The counts of main 6bb5b7d2cd7, read from its configurations (the same
    // on Linux and macOS): default flags and -Dsanitize-thread.
    const counted = [_]Counted{
        .{ .name = "", .count = countOf(configurationWith(10, 129), engine_line) },
        .{ .name = "-Dsanitize-thread", .count = countOf(configurationWith(1, 138), engine_line) },
    };
    try testing.expectEqual(Verdict.differ, verdictOf(&counted));
}

test "any one configuration that differs is a difference, wherever it stands" {
    try testing.expectEqual(Verdict.differ, verdictOf(&.{ .{ .name = "a", .count = 3 }, .{ .name = "b", .count = 3 }, .{ .name = "c", .count = 2 } }));
    try testing.expectEqual(Verdict.differ, verdictOf(&.{ .{ .name = "a", .count = 0 }, .{ .name = "b", .count = 3 } }));
    try testing.expectEqual(Verdict.differ, verdictOf(&.{ .{ .name = "a", .count = 3 }, .{ .name = "b", .count = 0 } }));
}

test "a text no configuration holds is not agreement: the check would pass whatever the build did" {
    try testing.expectEqual(Verdict.absent, verdictOf(&.{ .{ .name = "", .count = 0 }, .{ .name = "-Dsanitize-thread", .count = 0 } }));
}

test "one configuration, or none, is nothing to compare" {
    try testing.expectEqual(Verdict.too_few, verdictOf(&.{}));
    try testing.expectEqual(Verdict.too_few, verdictOf(&.{.{ .name = "", .count = 10 }}));
}

test "the configuration's path is the captured line without its end" {
    try testing.expectEqualStrings("/home/u/crane-caches/x/c/0f3a/configuration", pathIn("/home/u/crane-caches/x/c/0f3a/configuration\n"));
    try testing.expectEqualStrings(".zig-cache/c/0f3a/configuration", pathIn(".zig-cache/c/0f3a/configuration\r\n"));
    try testing.expectEqualStrings("a path/with a space", pathIn("  a path/with a space \n"));
    try testing.expectEqualStrings("", pathIn("\n"));
}

test "a configuration read from a file through the path a capture holds" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "configuration", .data = configurationWith(2, 5) });
    try tmp.dir.writeFile(io, .{ .sub_path = "stdout", .data = "configuration\n" });

    const captured = try tmp.dir.readFileAlloc(io, "stdout", testing.allocator, .limited(1 << 16));
    defer testing.allocator.free(captured);
    const configuration = try tmp.dir.readFileAlloc(io, pathIn(captured), testing.allocator, .limited(1 << 20));
    defer testing.allocator.free(configuration);
    try testing.expectEqual(@as(usize, 2), countOf(configuration, engine_line));
}

test {
    _ = stdout_stream;
}
