//! What build.zig would ask the machine, asked at make time.
//!
//! Zig 0.17 caches build.zig's configuration: it configures again only when
//! an input it tracks changes - build.zig and what it imports, the command
//! line, and the files and directories the configure declared it read. A
//! program's answer is none of those, so a configure that runs a program
//! must poison the cache, and then every `zig build` configures afresh (1.1 s
//! on Linux, 1.6 s on macOS, against 0.03 s and 0.085 s cached: lanes impls9
//! and cfg1, 2026-11-17). Each question build.zig used to ask at configure
//! time is asked here instead, by a Run step of the build - so the
//! configuration never depends on the answer, and the answer is fresh on
//! every build that needs it:
//!
//!     build_probe curl-websockets
//!         -Dsystem-curl: warn when the system libcurl lacks WebSockets
//!         (`curl-config --features`). A warning, never a failure: the
//!         option is a legitimate shortcut for work that opens no WebSocket.
//!     build_probe sdk-root --sdk=<name> --option=<build option> <out dir>
//!         The root of the named SDK (`xcrun --sdk <name> --show-sdk-path`),
//!         linked as <out dir>/root: the build hands modules paths under it.
//!         No such SDK fails the step, saying which option names the root.
//!     build_probe verify-base --ref=<ref> --zig=<zig> -- <zig build arguments>
//!         -Dverify-base: the *_test.zig files under tests/ that `git diff
//!         <ref>...HEAD` adds or changes (the WPT checkout's excepted), then
//!         `zig build test-verify -Dverify-files=<them> <arguments>`. Which
//!         test executables test-verify builds depends on the list, so the
//!         list is that build's command line, not this configuration's.
//!
//! std-only; `zig build test` runs its tests (tools-build_probe).

const std = @import("std");

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;

    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();
    _ = args.next();
    const mode = args.next() orelse usage();
    var rest: std.ArrayList([]const u8) = .empty;
    while (args.next()) |arg| try rest.append(arena, try arena.dupe(u8, arg));

    if (std.mem.eql(u8, mode, "curl-websockets")) {
        if (rest.items.len != 0) usage();
        return curlWebSockets(arena, io);
    }
    if (std.mem.eql(u8, mode, "sdk-root")) {
        var sdk: ?[]const u8 = null;
        var option: ?[]const u8 = null;
        var out: ?[]const u8 = null;
        for (rest.items) |arg| {
            if (std.mem.startsWith(u8, arg, "--sdk=")) {
                sdk = arg["--sdk=".len..];
            } else if (std.mem.startsWith(u8, arg, "--option=")) {
                option = arg["--option=".len..];
            } else if (out == null) {
                out = arg;
            } else usage();
        }
        return sdkRoot(arena, io, sdk orelse usage(), option orelse usage(), out orelse usage());
    }
    if (std.mem.eql(u8, mode, "verify-base")) {
        var ref: ?[]const u8 = null;
        var zig: ?[]const u8 = null;
        var passthrough: []const []const u8 = &.{};
        for (rest.items, 0..) |arg, i| {
            if (std.mem.startsWith(u8, arg, "--ref=")) {
                ref = arg["--ref=".len..];
            } else if (std.mem.startsWith(u8, arg, "--zig=")) {
                zig = arg["--zig=".len..];
            } else if (std.mem.eql(u8, arg, "--")) {
                passthrough = rest.items[i + 1 ..];
                break;
            } else usage();
        }
        return verifyBase(arena, io, ref orelse usage(), zig orelse usage(), passthrough);
    }
    usage();
}

fn usage() noreturn {
    std.debug.print(
        \\usage: build_probe curl-websockets
        \\       build_probe sdk-root --sdk=<name> --option=<build option> <out dir>
        \\       build_probe verify-base --ref=<ref> --zig=<zig> -- <zig build arguments>
        \\
    , .{});
    std.process.exit(2);
}

/// Print to stderr, where a Run step's output reaches the person building.
fn say(io: std.Io, comptime format: []const u8, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    var writer = std.Io.File.stderr().writerStreaming(io, &buffer);
    writer.interface.print(format, args) catch {};
    writer.interface.flush() catch {};
}

// ============================================================================
// curl-websockets
// ============================================================================

/// Whether `features`, `curl-config --features`' output (one feature a
/// line), names `feature`, case ignored. No other curl feature's name
/// contains "WebSockets", but a whole token is required all the same.
pub fn hasFeature(features: []const u8, feature: []const u8) bool {
    var it = std.mem.tokenizeAny(u8, features, " \t\r\n");
    while (it.next()) |token| {
        if (std.ascii.eqlIgnoreCase(token, feature)) return true;
    }
    return false;
}

/// `curl_ws_send`/`curl_ws_recv` have been declared since libcurl 7.86, so a
/// libcurl built without WebSockets links and returns
/// CURLE_UNSUPPORTED_PROTOCOL at run time - after which a failing WebSocket
/// looks like a Crane bug. macOS ships 8.7.1, whose feature list has no
/// WebSockets; the vendored curl (8.18.0) has it compiled in.
fn curlWebSockets(arena: std.mem.Allocator, io: std.Io) void {
    const features = std.process.run(arena, io, .{ .argv = &.{ "curl-config", "--features" } }) catch null;
    if (features == null or !features.?.term.success()) {
        say(io,
            \\warning: -Dsystem-curl is set, but `curl-config --features` would not run, so the system libcurl's WebSocket support is unverified.
            \\         If WebSockets fail at runtime, omit -Dsystem-curl to build the vendored curl 8.18.0.
            \\
        , .{});
        return;
    }
    if (hasFeature(features.?.stdout, "WebSockets")) return;
    const version: []const u8 = if (std.process.run(arena, io, .{ .argv = &.{ "curl-config", "--version" } })) |run|
        std.mem.trim(u8, run.stdout, " \t\r\n")
    else |_|
        "";
    say(io,
        \\warning: -Dsystem-curl is set and the system {s} lacks WebSocket support (`curl-config --features` lists no `WebSockets`).
        \\         src/websocket links that libcurl, so `curl_ws_send` resolves at link time and returns CURLE_UNSUPPORTED_PROTOCOL at run time: every WebSocket connection fails,
        \\         and the WebSocket tests with it. Omit -Dsystem-curl to build the vendored curl 8.18.0, which has WebSockets compiled in.
        \\
    , .{if (version.len != 0) version else "libcurl"});
}

// ============================================================================
// sdk-root
// ============================================================================

/// The SDK root in `xcrun --show-sdk-path`'s output, or null when it names
/// none.
pub fn sdkRootFrom(output: []const u8) ?[]const u8 {
    const path = std.mem.trim(u8, output, " \t\r\n");
    return if (path.len == 0) null else path;
}

/// <out dir>/root, a link to the SDK root `sdk`.
pub fn linkSdkRoot(io: std.Io, out_dir: []const u8, sdk: []const u8) !void {
    try std.Io.Dir.cwd().createDirPath(io, out_dir);
    var dir = try std.Io.Dir.cwd().openDir(io, out_dir, .{});
    defer dir.close(io);
    dir.deleteFile(io, "root") catch |err| switch (err) {
        error.FileNotFound => {},
        else => |e| return e,
    };
    try dir.symLink(io, sdk, "root", .{ .is_directory = true });
}

fn sdkRoot(arena: std.mem.Allocator, io: std.Io, sdk: []const u8, option: []const u8, out_dir: []const u8) !void {
    const found: ?[]const u8 = if (std.process.run(arena, io, .{ .argv = &.{ "xcrun", "--sdk", sdk, "--show-sdk-path" } })) |run|
        if (run.term.success()) sdkRootFrom(run.stdout) else null
    else |_|
        null;
    const root = found orelse {
        say(io, "error: no {s} SDK: `xcrun --sdk {s} --show-sdk-path` named none. Pass its root as -D{s}=<path>.\n", .{ sdk, sdk, option });
        std.process.exit(1);
    };
    try linkSdkRoot(io, out_dir, root);
}

// ============================================================================
// verify-base
// ============================================================================

/// The test files `git diff --name-only` output names that test-verify can
/// take: *_test.zig files, not the WPT checkout's. Strings are `output`'s.
pub fn verifyFiles(allocator: std.mem.Allocator, output: []const u8) ![]const []const u8 {
    var files: std.ArrayList([]const u8) = .empty;
    errdefer files.deinit(allocator);
    var lines = std.mem.tokenizeAny(u8, output, "\r\n");
    while (lines.next()) |file| {
        if (std.mem.endsWith(u8, file, "_test.zig") and !std.mem.startsWith(u8, file, "tests/wpt/")) try files.append(allocator, file);
    }
    return files.toOwnedSlice(allocator);
}

/// The command that verifies `files`: `<zig> build test-verify
/// -Dverify-files=<a,b,...> <passthrough>`.
pub fn verifyArgv(allocator: std.mem.Allocator, zig: []const u8, files: []const []const u8, passthrough: []const []const u8) ![]const []const u8 {
    const joined = try std.mem.join(allocator, ",", files);
    defer allocator.free(joined);
    const option = try std.fmt.allocPrint(allocator, "-Dverify-files={s}", .{joined});
    errdefer allocator.free(option);
    const argv = try allocator.alloc([]const u8, 4 + passthrough.len);
    argv[0] = zig;
    argv[1] = "build";
    argv[2] = "test-verify";
    argv[3] = option;
    @memcpy(argv[4..], passthrough);
    return argv;
}

fn verifyBase(arena: std.mem.Allocator, io: std.Io, ref: []const u8, zig: []const u8, passthrough: []const []const u8) !void {
    const range = try std.fmt.allocPrint(arena, "{s}...HEAD", .{ref});
    const diff = std.process.run(arena, io, .{ .argv = &.{ "git", "diff", "--name-only", "--diff-filter=AMR", range, "--", "tests/" } }) catch |err| {
        say(io, "test-verify: git diff {s} failed ({t}): no git checkout here? Pass -Dverify-files=<a,b,...> instead\n", .{ range, err });
        std.process.exit(1);
    };
    if (!diff.term.success()) {
        say(io, "test-verify: git diff {s} failed: {s}no git checkout here? Pass -Dverify-files=<a,b,...> instead\n", .{ range, diff.stderr });
        std.process.exit(1);
    }
    const files = try verifyFiles(arena, diff.stdout);
    if (files.len == 0) {
        say(io, "test-verify: git diff {s} adds or changes no test file under tests/: nothing to verify\n", .{range});
        return;
    }
    const argv = try verifyArgv(arena, zig, files, passthrough);
    var child = try std.process.spawn(io, .{ .argv = argv, .stdin = .ignore, .stdout = .inherit, .stderr = .inherit });
    const term = try child.wait(io);
    switch (term) {
        .exited => |code| if (code != 0) std.process.exit(code),
        else => std.process.exit(1),
    }
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "a feature is a whole token of curl-config's list, case ignored" {
    const listed = "AsynchDNS\nHSTS\nHTTP2\nIPv6\nLargefile\nlibz\nSSL\nUnixSockets\nWebSockets\n";
    try testing.expect(hasFeature(listed, "WebSockets"));
    try testing.expect(hasFeature("websockets", "WebSockets"));
    // macOS's 8.7.1: no WebSockets.
    try testing.expect(!hasFeature("AsynchDNS\nGSS-API\nIPv6\nKerberos\nLargefile\nlibz\nNTLM\nSSL\n", "WebSockets"));
    // A token that merely contains the name is not it.
    try testing.expect(!hasFeature("WebSocketsX\nXWebSockets\n", "WebSockets"));
    try testing.expect(!hasFeature("", "WebSockets"));
}

test "the SDK root is xcrun's output trimmed; an empty answer is none" {
    try testing.expectEqualStrings("/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk", sdkRootFrom("/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk\n").?);
    try testing.expectEqual(@as(?[]const u8, null), sdkRootFrom("\n"));
    try testing.expectEqual(@as(?[]const u8, null), sdkRootFrom(""));
}

test "the SDK root is linked as <out dir>/root, and linked again over an earlier link" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "sdk-a/usr/include");
    try tmp.dir.createDirPath(io, "sdk-b/usr/include");
    try tmp.dir.writeFile(io, .{ .sub_path = "sdk-b/usr/include/stdio.h", .data = "b\n" });
    var base_buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const base = base_buffer[0..try tmp.dir.realPath(io, &base_buffer)];
    const out = try std.fs.path.join(testing.allocator, &.{ base, "o", "sdk" });
    defer testing.allocator.free(out);
    const a = try std.fs.path.join(testing.allocator, &.{ base, "sdk-a" });
    defer testing.allocator.free(a);
    const b = try std.fs.path.join(testing.allocator, &.{ base, "sdk-b" });
    defer testing.allocator.free(b);

    try linkSdkRoot(io, out, a);
    var link_buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
    try testing.expectEqualStrings(a, link_buffer[0..try tmp.dir.readLink(io, "o/sdk/root", &link_buffer)]);
    // A rerun (the step runs on every build) replaces the link: Xcode moved.
    try linkSdkRoot(io, out, b);
    try testing.expectEqualStrings(b, link_buffer[0..try tmp.dir.readLink(io, "o/sdk/root", &link_buffer)]);
    const header = try tmp.dir.readFileAlloc(io, "o/sdk/root/usr/include/stdio.h", testing.allocator, .limited(64));
    defer testing.allocator.free(header);
    try testing.expectEqualStrings("b\n", header);
}

test "verify-base takes the *_test.zig files git names, never the WPT checkout's" {
    const output =
        \\tests/dom/node_test.zig
        \\tests/dom/fixture.zig
        \\tests/wpt/crane/x_test.zig
        \\tests/html/navigation/nav_test.zig
        \\tests/_test.zig.orig
        \\
    ;
    const files = try verifyFiles(testing.allocator, output);
    defer testing.allocator.free(files);
    try testing.expectEqual(@as(usize, 2), files.len);
    try testing.expectEqualStrings("tests/dom/node_test.zig", files[0]);
    try testing.expectEqualStrings("tests/html/navigation/nav_test.zig", files[1]);
    const none = try verifyFiles(testing.allocator, "");
    defer testing.allocator.free(none);
    try testing.expectEqual(@as(usize, 0), none.len);
}

test "the verify command names the files and passes the build's arguments on" {
    const argv = try verifyArgv(testing.allocator, "/zig", &.{ "tests/a/x_test.zig", "tests/b/y_test.zig" }, &.{ "-Dsanitize-thread", "-j2" });
    defer {
        testing.allocator.free(argv[3]);
        testing.allocator.free(argv);
    }
    const want = [_][]const u8{ "/zig", "build", "test-verify", "-Dverify-files=tests/a/x_test.zig,tests/b/y_test.zig", "-Dsanitize-thread", "-j2" };
    try testing.expectEqual(want.len, argv.len);
    for (want, argv) |w, a| try testing.expectEqualStrings(w, a);
}

test "verifyFiles and verifyArgv free what they made when an allocation fails" {
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn run(allocator: std.mem.Allocator) !void {
            const files = try verifyFiles(allocator, "tests/a/x_test.zig\ntests/b/y_test.zig\n");
            defer allocator.free(files);
            const argv = try verifyArgv(allocator, "/zig", files, &.{"-j2"});
            allocator.free(argv[3]);
            allocator.free(argv);
        }
    }.run, .{});
}
