const std = @import("std");
const testing = std.testing;
const crash_handler = @import("crash_handler");
const cli_fixtures = @import("cli_fixtures");

test "crash_handler: formats panic header with version, sha, build info, and message" {
    var out: std.Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();

    const info: crash_handler.BuildInfo = .{
        .version = "0.1.0",
        .git_sha = "8e14eb4dc",
        .build_mode = "ReleaseSafe",
        .os = "macos",
        .arch = "aarch64",
        .zig_version = "0.17.1-dev",
    };

    try crash_handler.writeHeader(&out.writer, info, .{ .panic = "index out of bounds" });
    const text = out.written();

    try testing.expect(std.mem.indexOf(u8, text, "Crane crashed") != null);
    try testing.expect(std.mem.indexOf(u8, text, "0.1.0") != null);
    try testing.expect(std.mem.indexOf(u8, text, "8e14eb4dc") != null);
    try testing.expect(std.mem.indexOf(u8, text, "ReleaseSafe") != null);
    try testing.expect(std.mem.indexOf(u8, text, "macos") != null);
    try testing.expect(std.mem.indexOf(u8, text, "aarch64") != null);
    try testing.expect(std.mem.indexOf(u8, text, "0.17.1-dev") != null);
    try testing.expect(std.mem.indexOf(u8, text, "index out of bounds") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Stack trace:") != null);
}

test "crash_handler: formats signal header with address and without address" {
    var out1: std.Io.Writer.Allocating = .init(testing.allocator);
    defer out1.deinit();

    const info: crash_handler.BuildInfo = .{
        .version = "0.1.0",
        .git_sha = "abc1234",
        .build_mode = "ReleaseSafe",
        .os = "linux",
        .arch = "x86_64",
        .zig_version = "0.17.1-dev",
    };

    try crash_handler.writeHeader(&out1.writer, info, .{ .signal = .{ .name = "SIGSEGV (Segmentation fault)", .addr = 0x1234 } });
    const text1 = out1.written();
    try testing.expect(std.mem.indexOf(u8, text1, "SIGSEGV (Segmentation fault)") != null);
    try testing.expect(std.mem.indexOf(u8, text1, "0x1234") != null);

    var out2: std.Io.Writer.Allocating = .init(testing.allocator);
    defer out2.deinit();
    try crash_handler.writeHeader(&out2.writer, info, .{ .signal = .{ .name = "SIGABRT (Aborted)", .addr = null } });
    const text2 = out2.written();
    try testing.expect(std.mem.indexOf(u8, text2, "SIGABRT (Aborted)") != null);
    try testing.expect(std.mem.indexOf(u8, text2, "0x") == null);
}

test "crash_handler: footer contains GitHub issue URL and 4-item report checklist" {
    var out: std.Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();

    try crash_handler.writeFooter(&out.writer);
    const text = out.written();

    try testing.expect(std.mem.indexOf(u8, text, "https://github.com/zig-whatwg/crane/issues/new") != null);
    try testing.expect(std.mem.indexOf(u8, text, "1.") != null);
    try testing.expect(std.mem.indexOf(u8, text, "2.") != null);
    try testing.expect(std.mem.indexOf(u8, text, "3.") != null);
    try testing.expect(std.mem.indexOf(u8, text, "4.") != null);
    try testing.expect(std.mem.indexOf(u8, text, "version") != null);
    try testing.expect(std.mem.indexOf(u8, text, "command") != null);
    try testing.expect(std.mem.indexOf(u8, text, "URL") != null);
    try testing.expect(std.mem.indexOf(u8, text, "stack trace") != null);
}

test "crash_handler: real panic subprocess prints banner, version, stack trace, and GitHub issue URL" {
    const res = try std.process.run(testing.allocator, testing.io, .{
        .argv = &.{ cli_fixtures.crash_fixture, "panic" },
    });
    defer testing.allocator.free(res.stdout);
    defer testing.allocator.free(res.stderr);
    errdefer std.debug.print("\npanic stderr:\n{s}\n", .{res.stderr});

    // Must terminate abnormally (signal or non-zero exit).
    switch (res.term) {
        .exited => |code| try testing.expect(code != 0),
        .signal => {},
        else => {},
    }

    try testing.expect(std.mem.indexOf(u8, res.stderr, "Crane crashed") != null);
    try testing.expect(std.mem.indexOf(u8, res.stderr, "0.1.0-test") != null);
    try testing.expect(std.mem.indexOf(u8, res.stderr, "deadbeef0") != null);
    try testing.expect(std.mem.indexOf(u8, res.stderr, "intentional crash fixture panic") != null);
    try testing.expect(std.mem.indexOf(u8, res.stderr, "https://github.com/zig-whatwg/crane/issues/new") != null);
    try testing.expect(std.mem.indexOf(u8, res.stderr, "1.") != null);
    try testing.expect(std.mem.indexOf(u8, res.stderr, "4.") != null);
    // Symbolized stack trace must reference triggerPanic or crash_fixture.zig.
    try testing.expect(std.mem.indexOf(u8, res.stderr, "triggerPanic") != null or
        std.mem.indexOf(u8, res.stderr, "crash_fixture.zig") != null);
}

test "crash_handler: real SIGABRT subprocess prints signal banner, stack trace, and GitHub issue URL" {
    const res = try std.process.run(testing.allocator, testing.io, .{
        .argv = &.{ cli_fixtures.crash_fixture, "abort" },
    });
    defer testing.allocator.free(res.stdout);
    defer testing.allocator.free(res.stderr);
    errdefer std.debug.print("\nabort stderr:\n{s}\n", .{res.stderr});

    switch (res.term) {
        .exited => |code| try testing.expect(code != 0),
        .signal => {},
        else => {},
    }

    try testing.expect(std.mem.indexOf(u8, res.stderr, "Crane crashed") != null);
    try testing.expect(std.mem.indexOf(u8, res.stderr, "0.1.0-test") != null);
    try testing.expect(std.mem.indexOf(u8, res.stderr, "SIGABRT") != null);
    try testing.expect(std.mem.indexOf(u8, res.stderr, "https://github.com/zig-whatwg/crane/issues/new") != null);
    try testing.expect(std.mem.indexOf(u8, res.stderr, "1.") != null);
    try testing.expect(std.mem.indexOf(u8, res.stderr, "4.") != null);
}
