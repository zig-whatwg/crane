//! The platform protocol's contract, checked (docs/platform-protocol.md,
//! src/platform/protocol.zig).
//!
//! build.zig binds this file once per built-in platform (darwin, linux,
//! testing) with `platformProtocolBinding`, and once more with
//! `-Dplatform-without=camera,clipboard`; each binding compiles the facade, so
//! its comptime conformance check runs against that platform, and in a test
//! build every operation of the platform is compiled whole. The comparison
//! the check uses is a function, tested here on a matching, a mistyped and a
//! missing operation (a compile error cannot be a test's expected outcome).

const std = @import("std");
const platform = @import("platform");
const platform_options = @import("platform_options");

const testing = std.testing;

// ---------------------------------------------------------------------------
// The comparison the conformance check makes
// ---------------------------------------------------------------------------

fn expectedOf(comptime f: anytype) std.builtin.Type.Fn {
    return @typeInfo(@TypeOf(f)).@"fn";
}

const Fake = struct {
    pub fn monotonicNow() platform.Instant {
        return .{ .ns = 1 };
    }
    /// The parameter is `*const` where the protocol takes `*` - the drift Zig
    /// would convert implicitly at a call (the forwarding-facade lesson).
    pub fn destroyBrowserPlatform(browser: *const platform.BrowserPlatform) void {
        _ = browser;
    }
    /// A different return type.
    pub fn wallNow() platform.Instant {
        return .{ .ns = 1 };
    }
    pub const sleepThread: u32 = 0;
    pub fn fillRandom(bytes: anytype) void {
        _ = bytes;
    }
};

test "conformance: a function of exactly the protocol's type matches" {
    try testing.expectEqual(platform.Conformance.matches, comptime platform.conformance(Fake, "monotonicNow", expectedOf(platform.monotonicNow)));
}

test "conformance: a mistyped parameter or return type is mistyped" {
    try testing.expectEqual(platform.Conformance.mistyped, comptime platform.conformance(Fake, "destroyBrowserPlatform", expectedOf(platform.destroyBrowserPlatform)));
    try testing.expectEqual(platform.Conformance.mistyped, comptime platform.conformance(Fake, "wallNow", expectedOf(platform.wallNow)));
}

test "conformance: a generic function is mistyped" {
    try testing.expectEqual(platform.Conformance.mistyped, comptime platform.conformance(Fake, "fillRandom", expectedOf(platform.fillRandom)));
}

test "conformance: a missing operation is missing, a non-function is not a function" {
    try testing.expectEqual(platform.Conformance.missing, comptime platform.conformance(Fake, "spawnThread", expectedOf(platform.spawnThread)));
    try testing.expectEqual(platform.Conformance.not_a_function, comptime platform.conformance(Fake, "sleepThread", expectedOf(platform.sleepThread)));
}

test "conformance: the bound platform matches every operation" {
    @setEvalBranchQuota(100_000);
    comptime var count: usize = 0;
    inline for (@typeInfo(platform).@"struct".decls) |decl| {
        const T = @TypeOf(@field(platform, decl.name));
        if (@typeInfo(T) != .@"fn") continue;
        const f = @typeInfo(T).@"fn";
        if (f.calling_convention != .@"inline") continue;
        try testing.expectEqual(platform.Conformance.matches, comptime platform.conformance(platform.adapter, decl.name, f));
        count += 1;
    }
    // Every operation of the contract is declared (section 6): pin the count,
    // so an operation removed by accident shows here.
    try testing.expectEqual(@as(usize, 200), count);
}

// ---------------------------------------------------------------------------
// Capabilities and -Dplatform-without
// ---------------------------------------------------------------------------

test "withoutCapabilities forces exactly the named capabilities unsupported" {
    const without = comptime blk: {
        var all_native: platform.Capabilities = undefined;
        for (@typeInfo(platform.Capabilities).@"struct".fields) |field| @field(all_native, field.name) = .native;
        break :blk platform.withoutCapabilities(all_native, &.{ "camera", "clipboard" });
    };
    try testing.expectEqual(platform.Support.unsupported, without.camera);
    try testing.expectEqual(platform.Support.unsupported, without.clipboard);
    try testing.expectEqual(platform.Support.native, without.microphone);
    try testing.expectEqual(platform.Support.native, without.layout);
}

test "every capability -Dplatform-without names is unsupported in this build" {
    inline for (platform_options.platform_without) |name| {
        try testing.expectEqual(platform.Support.unsupported, @field(platform.capabilities, name));
    }
}

test "-Dplatform-without=camera: camera is unsupported" {
    const asked = comptime for (platform_options.platform_without) |name| {
        if (std.mem.eql(u8, name, "camera")) break true;
    } else false;
    if (!asked) return error.SkipZigTest;
    try testing.expectEqual(platform.Support.unsupported, platform.capabilities.camera);
}

test "the platform's declarations: name, identity, browser options" {
    try testing.expect(platform.name.len > 0);
    try testing.expect(platform.identity.native_line_ending.len > 0);
    const options: platform.PlatformBrowserOptions = .{};
    _ = options;
}

// ---------------------------------------------------------------------------
// The OS services every platform provides (today's behaviour, through the
// protocol)
// ---------------------------------------------------------------------------

test "the monotonic clock never goes backwards and the wall clock is near now" {
    var previous = platform.monotonicNow().ns;
    for (0..10_000) |_| {
        const now = platform.monotonicNow().ns;
        try testing.expect(now >= previous);
        previous = now;
    }
    const seconds = platform.wallSeconds();
    try testing.expect(seconds > 1_577_836_800 and seconds < 4_102_444_800);
    var watch = platform.Stopwatch.start();
    platform.sleepThread(std.time.ns_per_ms);
    try testing.expect(watch.lap() >= std.time.ns_per_ms / 2);
}

test "fillRandom fills, and two draws differ" {
    var a = [_]u8{0} ** 64;
    var b = [_]u8{0} ** 64;
    platform.fillRandom(&a);
    platform.fillRandom(&b);
    try testing.expect(!std.mem.eql(u8, &a, &b));
}

fn bump(context: ?*anyopaque) callconv(.c) void {
    const counter: *std.atomic.Value(u32) = @ptrCast(@alignCast(context.?));
    _ = counter.fetchAdd(1, .seq_cst);
}

test "a spawned thread runs and joins" {
    var counter: std.atomic.Value(u32) = .init(0);
    const thread = try platform.spawnThread(.{ .name = platform.Str.from("platform-test") }, bump, &counter);
    platform.joinThread(thread);
    try testing.expectEqual(@as(u32, 1), counter.load(.seq_cst));
    try testing.expect(platform.logicalProcessorCount() >= 1);
}

test "files: write atomically, read, stat, list and delete a tree" {
    const allocator = testing.allocator;
    var nonce: [8]u8 = undefined;
    platform.fillRandom(&nonce);
    const root = try std.fmt.allocPrint(allocator, "tmp/platform-test-{x}", .{std.mem.readInt(u64, &nonce, .little)});
    defer allocator.free(root);
    const file = try std.fmt.allocPrint(allocator, "{s}/a/b.txt", .{root});
    defer allocator.free(file);
    const dir = try std.fmt.allocPrint(allocator, "{s}/a", .{root});
    defer allocator.free(dir);

    try platform.makeDirectoryPath(platform.Str.from(dir));
    defer platform.deleteTree(platform.Str.from(root)) catch {};
    try platform.writeFileAtomic(platform.Str.from(file), platform.Bytes.from("hello"));
    const bytes = try platform.readFile(allocator, platform.Str.from(file), 1024);
    defer allocator.free(bytes);
    try testing.expectEqualStrings("hello", bytes);
    const info = try platform.fileInfo(platform.Str.from(file));
    try testing.expectEqual(@as(u64, 5), info.size);
    try testing.expectEqual(platform.FileKind.file, info.kind);
    const entries = try platform.listDirectory(allocator, platform.Str.from(dir));
    defer {
        for (entries) |entry| allocator.free(entry.name.slice());
        allocator.free(entries);
    }
    try testing.expectEqual(@as(usize, 1), entries.len);
    try testing.expectEqualStrings("b.txt", entries[0].name.slice());
    try testing.expectError(error.NotFound, platform.fileInfo(platform.Str.from("tmp/platform-test-does-not-exist")));
    try platform.deleteTree(platform.Str.from(root));
    try testing.expectError(error.NotFound, platform.fileInfo(platform.Str.from(file)));
}

fn ignoreEvent(context: ?*anyopaque, event: *const platform.PlatformEvent) callconv(.c) void {
    _ = .{ context, event };
}

const no_events: platform.EventSink = .{ .context = null, .post = ignoreEvent };

test "the storage engine: ordered keys, snapshot reads, commit and abort" {
    const allocator = testing.allocator;
    const browser = try platform.createBrowserPlatform(allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    const store = try platform.openStore(browser, platform.Str.from("db"), .{});
    defer platform.closeStore(store);

    const write = try platform.beginTransaction(store, .write);
    try platform.storePut(write, platform.Bytes.from("b"), platform.Bytes.from("2"));
    try platform.storePut(write, platform.Bytes.from("a"), platform.Bytes.from("1"));
    try platform.storePut(write, platform.Bytes.from("\xff"), platform.Bytes.from("3"));
    // One writer at a time.
    try testing.expectError(error.Conflict, platform.beginTransaction(store, .write));
    // A reader started now does not see uncommitted writes.
    const before = try platform.beginTransaction(store, .read);
    try testing.expectEqual(@as(?[]u8, null), try platform.storeGet(before, allocator, platform.Bytes.from("a")));
    platform.abortTransaction(before);
    try platform.commitTransaction(write);

    const read = try platform.beginTransaction(store, .read);
    defer platform.abortTransaction(read);
    const value = (try platform.storeGet(read, allocator, platform.Bytes.from("a"))).?;
    defer allocator.free(value);
    try testing.expectEqualStrings("1", value);

    // Unsigned byte order, both directions, and an open bound.
    for ([_]platform.CursorDirection{ .forward, .reverse }) |direction| {
        const cursor = try platform.openCursor(read, .{ .lower = platform.Bytes.from("a"), .has_lower = true, .lower_open = true }, direction);
        defer platform.closeCursor(cursor);
        var keys: [2][]const u8 = undefined;
        for (&keys) |*key| {
            const pair = (try platform.cursorNext(cursor, allocator)).?;
            defer allocator.free(pair.value.slice());
            key.* = pair.key.slice();
        }
        defer for (keys) |key| allocator.free(key);
        try testing.expectEqual(@as(?platform.KeyValue, null), try platform.cursorNext(cursor, allocator));
        const expected: [2][]const u8 = if (direction == .forward) .{ "b", "\xff" } else .{ "\xff", "b" };
        try testing.expectEqualStrings(expected[0], keys[0]);
        try testing.expectEqualStrings(expected[1], keys[1]);
    }

    const aborted = try platform.beginTransaction(store, .write);
    try platform.storeDeleteRange(aborted, .all);
    platform.abortTransaction(aborted);
    try testing.expect(try platform.storeSize(store) > 0);
    try platform.deleteStore(browser, platform.Str.from("db"));
    try testing.expectError(error.NotFound, platform.deleteStore(browser, platform.Str.from("db")));
}

test "the event-loop port: a wait ends at its deadline and on a wake" {
    const allocator = testing.allocator;
    const browser = try platform.createBrowserPlatform(allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    const port = try platform.createEventLoopPort(allocator, browser);
    defer platform.destroyEventLoopPort(port);
    try testing.expect(!platform.pollEventLoopPort(port));
    const start = platform.monotonicNow().ns;
    platform.waitEventLoopPort(port, .{ .ns = start + 2 * std.time.ns_per_ms });
    // A wake that came before the wait still ends it promptly (spurious
    // returns are allowed; the deadline bounds the rest).
    platform.wakeEventLoopPort(port);
    platform.waitEventLoopPort(port, .{ .ns = platform.monotonicNow().ns + 5 * std.time.ns_per_s });
    try testing.expect(platform.monotonicNow().ns - start < 5 * std.time.ns_per_s);
}

test "crypto primitives: SHA-256 and HMAC known answers" {
    const allocator = testing.allocator;
    const sha = try platform.digest(allocator, .sha256, platform.Bytes.from("abc"));
    defer allocator.free(sha);
    var hex: [64]u8 = undefined;
    _ = try std.fmt.bufPrint(&hex, "{x}", .{sha});
    try testing.expectEqualStrings("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", &hex);
    // RFC 4231 test case 2.
    const mac = try platform.hmacSign(allocator, .sha256, platform.Bytes.from("Jefe"), platform.Bytes.from("what do ya want for nothing?"));
    defer allocator.free(mac);
    _ = try std.fmt.bufPrint(&hex, "{x}", .{mac});
    try testing.expectEqualStrings("5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843", &hex);
    try testing.expect(platform.hmacVerify(.sha256, platform.Bytes.from("Jefe"), platform.Bytes.from(mac), platform.Bytes.from("what do ya want for nothing?")));
}

fn keepUnit(context: *anyopaque, value: *const platform.Unit) callconv(.c) void {
    _ = value;
    const flag: *u8 = @ptrCast(context);
    flag.* = 1;
}

fn dropped(context: *anyopaque) callconv(.c) void {
    const flag: *u8 = @ptrCast(context);
    flag.* = 2;
}

const ReadBack = struct {
    text: [16]u8 = undefined,
    len: usize = 0,
    outcome: u8 = 0,

    fn deliver(context: *anyopaque, items: *const platform.ClipboardItems) callconv(.c) void {
        const self: *ReadBack = @ptrCast(@alignCast(context));
        self.outcome = 1;
        const data = items.ptr[0].ptr[0].data.slice();
        @memcpy(self.text[0..data.len], data);
        self.len = data.len;
    }

    fn drop(context: *anyopaque) callconv(.c) void {
        const self: *ReadBack = @ptrCast(@alignCast(context));
        self.outcome = 2;
    }
};

test "the clipboard, where the platform has one, round-trips through a Reply" {
    if (platform.capabilities.clipboard != .unsupported) {
        const allocator = testing.allocator;
        const browser = try platform.createBrowserPlatform(allocator, &.{}, no_events);
        defer platform.destroyBrowserPlatform(browser);
        const requester: platform.Requester = .{ .request_id = 1, .tab = 1, .frame = 1, .origin = .{}, .top_level_origin = .{}, .secure_context = true, .transient_activation = true };
        const representations = [_]platform.ClipboardRepresentation{.{ .mime_type = platform.Str.from("text/plain"), .data = platform.Bytes.from("copied") }};
        const item = [_]platform.ClipboardEntry{.{ .ptr = &representations, .len = 1 }};
        var written: u8 = 0;
        platform.writeClipboard(browser, &requester, &.{ .ptr = &item, .len = 1 }, .{ .context = &written, .deliver = keepUnit, .drop = dropped });
        try testing.expectEqual(@as(u8, 1), written);
        var back: ReadBack = .{};
        platform.readClipboard(browser, &requester, &.{platform.Str.from("text/plain")}, .{ .context = &back, .deliver = ReadBack.deliver, .drop = ReadBack.drop });
        try testing.expectEqual(@as(u8, 1), back.outcome);
        try testing.expectEqualStrings("copied", back.text[0..back.len]);
    } else {
        // Clipboard API: read and write reject with NotAllowedError - nothing
        // to call.
        try testing.expect(true);
    }
}
