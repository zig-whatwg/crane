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
    inline for (@typeInfo(platform).@"struct".decl_names) |decl_name| {
        const T = @TypeOf(@field(platform, decl_name));
        if (@typeInfo(T) != .@"fn") continue;
        const f = @typeInfo(T).@"fn";
        if (f.attrs.@"callconv" != .@"inline") continue;
        try testing.expectEqual(platform.Conformance.matches, comptime platform.conformance(platform.adapter, decl_name, f));
        count += 1;
    }
    // Every operation of the contract is declared (section 6): pin the count,
    // so an operation removed by accident shows here. 221 since D3 (the user,
    // 2026-11-09 22:21 UTC) removed replacedElementBox; 228 since lane h1
    // added the address-space group (6.11: pageSize, reserveAddressSpace,
    // labelAddressSpace, commitPages, decommitPages, protectPages,
    // releaseAddressSpace); 230 since lane tls1 added a thread's alternate
    // signal stack (6.4: attachSignalStack, detachSignalStack); 232 since
    // lane quick1 added image encoding (imageEncodingMimeTypeSupported,
    // encodeImage).
    try testing.expectEqual(@as(usize, 232), count);
}

test "address space (6.11): this platform reserves, commits, decommits and releases" {
    // Every built-in platform has it; the platform-specific behaviour is
    // tests/platform/h1_address_space_test.zig's, on each host OS.
    if (comptime platform.capabilities.address_space == .unsupported) return error.SkipZigTest;
    const page = platform.pageSize();
    const range = try platform.reserveAddressSpace(8 * page, 4 * page, 0, .objects);
    defer platform.releaseAddressSpace(range);
    try testing.expectEqual(@as(usize, 0), range.base % (4 * page));
    platform.labelAddressSpace(range, 0, 4 * page, .node_cage);
    try platform.commitPages(range, 0, 2 * page);
    const p: *volatile u8 = @ptrFromInt(range.base + page);
    p.* = 0xa5;
    try testing.expectEqual(@as(u8, 0xa5), p.*);
    try platform.decommitPages(range, 0, 2 * page);
    try platform.protectPages(range, 0, 2 * page, .none);
}

// ---------------------------------------------------------------------------
// Capabilities and -Dplatform-without
// ---------------------------------------------------------------------------

test "withoutCapabilities forces exactly the named capabilities unsupported" {
    const without = comptime blk: {
        var all_native: platform.Capabilities = undefined;
        for (@typeInfo(platform.Capabilities).@"struct".field_names) |field_name| @field(all_native, field_name) = .native;
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
    var a = @as([64]u8, @splat(0));
    var b = @as([64]u8, @splat(0));
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

    // Ended before deleteStore below, which frees the store this transaction
    // points into (a deferred abort ran after it: a use-after-free that
    // Zig 0.17's std.testing.allocator, a SafeAllocator, turns into a fault).
    const read = try platform.beginTransaction(store, .read);
    var read_open = true;
    defer if (read_open) platform.abortTransaction(read);
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

    platform.abortTransaction(read);
    read_open = false;

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
    /// How many items the read delivered (0: an empty clipboard).
    items: usize = 0,
    outcome: u8 = 0,

    fn deliver(context: *anyopaque, items: *const platform.ClipboardItems) callconv(.c) void {
        const self: *ReadBack = @ptrCast(@alignCast(context));
        self.outcome = 1;
        self.items = items.len;
        if (items.len == 0 or items.ptr[0].len == 0) return;
        const data = items.ptr[0].ptr[0].data.slice();
        const kept = @min(data.len, self.text.len);
        @memcpy(self.text[0..kept], data[0..kept]);
        self.len = kept;
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

/// Whether -Dplatform-without names `capability` in this build.
fn compiledOut(comptime capability: []const u8) bool {
    return for (platform_options.platform_without) |name| {
        if (std.mem.eql(u8, name, capability)) break true;
    } else false;
}

const clipboard_requester: platform.Requester = .{ .request_id = 1, .tab = 1, .frame = 1, .origin = .{}, .top_level_origin = .{}, .secure_context = true, .transient_activation = true };

fn writeClipboardText(browser: *platform.BrowserPlatform, text: []const u8) !void {
    const representations = [_]platform.ClipboardRepresentation{.{ .mime_type = platform.Str.from("text/plain"), .data = platform.Bytes.from(text) }};
    const item = [_]platform.ClipboardEntry{.{ .ptr = &representations, .len = 1 }};
    var written: u8 = 0;
    platform.writeClipboard(browser, &clipboard_requester, &.{ .ptr = &item, .len = 1 }, .{ .context = &written, .deliver = keepUnit, .drop = dropped });
    try testing.expectEqual(@as(u8, 1), written);
}

fn readClipboardText(browser: *platform.BrowserPlatform) !ReadBack {
    var back: ReadBack = .{};
    platform.readClipboard(browser, &clipboard_requester, &.{platform.Str.from("text/plain")}, .{ .context = &back, .deliver = ReadBack.deliver, .drop = ReadBack.drop });
    try testing.expectEqual(@as(u8, 1), back.outcome);
    return back;
}

// The user's ruling D2 (2026-11-09): the production platforms, darwin and
// linux, answer the Clipboard API from an in-memory clipboard per Browser
// (kit/memory_clipboard), as the testing platform does - headless Chrome's
// own: components/headless/clipboard/headless_clipboard.cc, a
// ui::ClipboardNonBacked that headless/lib/browser/
// headless_browser_main_parts.cc installs. Every built-in platform this file
// is bound to declares it `.emulated` unless -Dplatform-without=clipboard.
test "every built-in platform has the in-memory clipboard unless it is compiled out" {
    const expected: platform.Support = if (comptime compiledOut("clipboard")) .unsupported else .emulated;
    try testing.expectEqual(expected, platform.capabilities.clipboard);
}

test "the in-memory clipboard is per Browser: two Browsers do not share it" {
    if (platform.capabilities.clipboard != .emulated) {
        // Only compiled out may a built-in platform lack it (pinned above).
        try testing.expect(comptime compiledOut("clipboard"));
    } else {
        const allocator = testing.allocator;
        const first = try platform.createBrowserPlatform(allocator, &.{}, no_events);
        defer platform.destroyBrowserPlatform(first);
        const second = try platform.createBrowserPlatform(allocator, &.{}, no_events);
        defer platform.destroyBrowserPlatform(second);

        // A fresh Browser's clipboard is empty.
        try testing.expectEqual(@as(usize, 0), (try readClipboardText(first)).items);

        try writeClipboardText(first, "first");
        // What one Browser copies, the other does not see...
        try testing.expectEqual(@as(usize, 0), (try readClipboardText(second)).items);
        // ...and the other's copy does not replace it.
        try writeClipboardText(second, "second");
        const from_first = try readClipboardText(first);
        try testing.expectEqual(@as(usize, 1), from_first.items);
        try testing.expectEqualStrings("first", from_first.text[0..from_first.len]);
        const from_second = try readClipboardText(second);
        try testing.expectEqual(@as(usize, 1), from_second.items);
        try testing.expectEqualStrings("second", from_second.text[0..from_second.len]);
    }
}

// The user's ruling D1 (2026-11-09), and the architecture of 21:09 UTC: "our
// default platform for running wpt should get its own implementation of these
// things ... The platform itself that is compiled in will decide if these
// features are built within the platform or dynamically link out to existing
// capabilities on the platform." Every built-in platform - darwin and linux,
// which Crane's own browser and the production WPT runner compile in, and
// testing - decodes PNG, BMP, GIF, JPEG and SVG with the kit's built-in
// decoders (kit/image_decoding) unless -Dplatform-without=image_decoding.
test "every built-in platform decodes images unless image_decoding is compiled out" {
    const expected: platform.Support = if (comptime compiledOut("image_decoding")) .unsupported else .native;
    try testing.expectEqual(expected, platform.capabilities.image_decoding);
}

// HTML 4.12.5.5 "User agents must support PNG": every built-in platform
// encodes it with kit/image_encoding unless -Dplatform-without=image_encoding
// (the integrator, 2026-11-12, D1's pattern), and its file decodes back
// through the bound platform's own decoder.
test "every built-in platform encodes PNG unless image_encoding is compiled out" {
    const expected: platform.Support = if (comptime compiledOut("image_encoding")) .unsupported else .native;
    try testing.expectEqual(expected, platform.capabilities.image_encoding);
    if (platform.capabilities.image_encoding == .unsupported) return;
    try testing.expect(platform.imageEncodingMimeTypeSupported(platform.Str.from("image/png")));
    try testing.expect(!platform.imageEncodingMimeTypeSupported(platform.Str.from("image/x-unknown")));
    const pixels = [_]u8{ 255, 0, 0, 255, 0, 255, 0, 128 };
    const file = try platform.encodeImage(testing.allocator, platform.Str.from("image/png"), .{ .width = 2, .height = 1, .pixels = platform.Bytes.from(&pixels) }, -1);
    defer testing.allocator.free(file.slice());
    try testing.expect(std.mem.startsWith(u8, file.slice(), "\x89PNG\r\n\x1a\n"));
    if (platform.capabilities.image_decoding == .unsupported) return;
    const image = try platform.decodeImage(testing.allocator, platform.Str.from("image/png"), file, image_limits);
    defer testing.allocator.free(image.pixels.slice());
    try testing.expectEqualSlices(u8, &pixels, image.pixels.slice());
}

const image_limits: platform.ImageLimits = .{ .max_dimension = 4096, .max_pixels = 4096 * 4096 };

fn expectDecodes(essence: []const u8, bytes: []const u8, width: u32, height: u32) !void {
    const image = try platform.decodeImage(testing.allocator, platform.Str.from(essence), platform.Bytes.from(bytes), image_limits);
    defer testing.allocator.free(image.pixels.slice());
    try testing.expectEqual(width, image.width);
    try testing.expectEqual(height, image.height);
    try testing.expectEqual(@as(usize, width) * height * 4, image.pixels.slice().len);
    try testing.expect(!image.empty);
}

test "image decoding: PNG, JPEG, GIF, BMP and SVG decode through the bound platform, which says which types it takes" {
    if (platform.capabilities.image_decoding == .unsupported) {
        // Only compiled out may a built-in platform lack it (pinned above).
        try testing.expect(comptime compiledOut("image_decoding"));
    } else {
        const allocator = testing.allocator;
        for ([_][]const u8{ "image/png", "image/apng", "image/jpeg", "image/gif", "image/bmp", "image/x-bmp", "image/x-ms-bmp", "image/svg+xml" }) |essence| {
            try testing.expect(platform.imageMimeTypeSupported(platform.Str.from(essence)));
        }
        try testing.expect(!platform.imageMimeTypeSupported(platform.Str.from("image/x-unknown")));
        try testing.expect(!platform.imageMimeTypeSupported(platform.Str.from("text/plain")));

        // Read from the repository root (build.zig sets this run's cwd).
        const Case = struct { essence: []const u8, path: []const u8, width: u32, height: u32 };
        const cases = [_]Case{
            .{ .essence = "image/png", .path = "tests/wpt/images/green.png", .width = 100, .height = 50 },
            .{ .essence = "image/jpeg", .path = "tests/wpt/html/semantics/embedded-content/the-img-element/3.jpg", .width = 650, .height = 470 },
            .{ .essence = "image/gif", .path = "tests/wpt/images/anim-gr.gif", .width = 100, .height = 50 },
            .{ .essence = "image/bmp", .path = "tests/platform/fixtures/image-py-28.bmp", .width = 28, .height = 28 },
        };
        for (cases) |case| {
            const bytes = try platform.readFile(allocator, platform.Str.from(case.path), 1 << 22);
            defer allocator.free(bytes);
            try expectDecodes(case.essence, bytes, case.width, case.height);
        }
        try expectDecodes("image/svg+xml", "<svg xmlns='http://www.w3.org/2000/svg' width='2' height='2'><rect width='2' height='2'/></svg>", 2, 2);
        // A type it does not take is UnsupportedFormat: the image is broken.
        try testing.expectError(error.UnsupportedFormat, platform.decodeImage(allocator, platform.Str.from("image/x-unknown"), platform.Bytes.from("bytes"), image_limits));
    }
}

// D3 (the user, 2026-11-09 22:21 UTC): geometry is a READ on whatever
// rendering engine the compiled-in platform plugs in (6.9: layoutBox,
// clientRects, hitTest, isRendered, forceLayout, invalidateLayout). Crane
// never computes a box itself, so the protocol has no operation that sizes a
// box from facts Crane hands over - decision 19b's replacedElementBox and its
// ReplacedElementFacts are gone - and no built-in platform plugs a renderer
// in yet: each answers layout as kit/headless does, with no box anywhere.
test "the protocol has no replaced-element box: geometry is only read from a renderer" {
    try testing.expect(!@hasDecl(platform, "replacedElementBox"));
    try testing.expect(!@hasDecl(platform, "ReplacedElementFacts"));
    try testing.expect(!@hasDecl(platform.adapter, "replacedElementBox"));
}

test "every built-in platform answers layout as headless does: no renderer, no box" {
    try testing.expectEqual(platform.Support.unsupported, platform.capabilities.layout);
    // The adapter's own answers, which the facade's gate keeps Crane from
    // asking while the capability is unsupported (CSSOM View's no-box
    // answers above the protocol).
    const allocator = testing.allocator;
    const browser = try platform.createBrowserPlatform(allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    const document: platform.LayoutNode = .{ .id = 1 };
    const node: platform.LayoutNode = .{ .id = 2 };
    platform.adapter.invalidateLayout(browser, document, node, .attribute);
    platform.adapter.forceLayout(browser, document);
    try testing.expectEqual(@as(?platform.BoxMetrics, null), platform.adapter.layoutBox(browser, document, node));
    const rects = try platform.adapter.clientRects(browser, document, node, allocator);
    defer allocator.free(rects);
    try testing.expectEqual(@as(usize, 0), rects.len);
    const hits = try platform.adapter.hitTest(browser, document, .{}, allocator);
    defer allocator.free(hits);
    try testing.expectEqual(@as(usize, 0), hits.len);
    try testing.expect(!platform.adapter.isRendered(browser, document, node));
    try testing.expect((try platform.adapter.renderedText(browser, document, node, allocator)) == null);
}
