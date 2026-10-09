//! The host supplies media decoding (the user, 2026-10-08: "Host decoders
//! only"). A Browser borrows the backend its host passes in BrowserConfig and
//! keeps it on its BrowserScope (docs/instances.md rule 2); every realm of the
//! Browser - a page, its frames - answers canPlayType and opens decoders
//! through it. With none passed, the default is no_decoder and the honest
//! answer is "".
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const html = @import("html");
const media = @import("platform").media_backend;

/// A host backend that answers only for its own made-up type, and counts how
/// often Crane asked it.
const FakeHost = struct {
    asked: usize = 0,
    fn canPlay(ptr: ?*anyopaque, mime: []const u8) media.Support {
        const self: *FakeHost = @ptrCast(@alignCast(ptr.?));
        self.asked += 1;
        return if (std.mem.eql(u8, mime, "audio/x-hostmedia")) .maybe else .unsupported;
    }
    fn open(_: ?*anyopaque, _: std.mem.Allocator, _: []const u8) anyerror!media.Decoder {
        return error.NotSupported;
    }
    fn backend(self: *FakeHost) media.MediaBackend {
        return .{ .ptr = self, .vtable = &.{ .can_play_type = canPlay, .open = open } };
    }
};

/// Run `body` on a thread of its own: a Browser needs a fresh per-thread
/// engine state, and this directory's other files share the process.
fn onThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            body() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

test "a realm with no browser scope gets no decoder" {
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    try testing.expect(ctx.browser_scope == null);
    try testing.expectEqual(media.Support.unsupported, html.media_runtime.forRealm(&ctx).canPlayType("audio/wav"));
}

test "a realm reads the media backend from its browser scope's host supplement" {
    var scope = runtime.BrowserScope.init(testing.allocator);
    defer scope.deinit();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    ctx.browser_scope = &scope;
    // A scope whose Browser installed nothing: still no decoder, and asking
    // does not make the supplement.
    try testing.expectEqual(media.Support.unsupported, html.media_runtime.forRealm(&ctx).canPlayType("audio/x-hostmedia"));
    try testing.expect(scope.existing(html.media_runtime.MediaHost) == null);
    var host: FakeHost = .{};
    (try scope.of(html.media_runtime.MediaHost)).backend = host.backend();
    try testing.expectEqual(media.Support.maybe, html.media_runtime.forRealm(&ctx).canPlayType("audio/x-hostmedia"));
    try testing.expectEqual(media.Support.unsupported, html.media_runtime.forRealm(&ctx).canPlayType("audio/wav"));
    try testing.expectEqual(@as(usize, 2), host.asked);
}

test "the default: a Browser made with no media backend answers \"\" for audio/wav" {
    try onThread(struct {
        fn body() !void {
            const browser = try @import("browser").Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
            defer browser.deinit();
            const page = browser.current_context orelse return error.TestUnexpectedResult;
            try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "https://example.test/" });
            try page.runScript(
                \\for (const tag of ['audio', 'video']) {
                \\  const element = document.createElement(tag);
                \\  for (const type of ['audio/wav', 'audio/wav; codecs="1"', 'audio/x-hostmedia'])
                \\    if (element.canPlayType(type) !== '') throw new Error(tag + ' answered "' + element.canPlayType(type) + '" for ' + type);
                \\}
            );
        }
    }.body);
}

test "a Browser's host backend answers in its page and in a frame's realm" {
    try onThread(struct {
        fn body() !void {
            var host: FakeHost = .{};
            const browser = try @import("browser").Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "", .media_backend = host.backend() });
            defer browser.deinit();
            const page = browser.current_context orelse return error.TestUnexpectedResult;
            try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "https://example.test/" });
            try page.runScript(
                \\const audio = document.createElement('audio');
                \\if (audio.canPlayType('audio/x-hostmedia') !== 'maybe') throw new Error('page: ' + audio.canPlayType('audio/x-hostmedia'));
                \\if (audio.canPlayType('audio/wav') !== '') throw new Error('page answered for a type the host does not decode');
                \\const frame = document.createElement('iframe');
                \\document.body.append(frame);
                \\const inner = frame.contentDocument.createElement('video');
                \\if (inner.canPlayType('audio/x-hostmedia') !== 'maybe') throw new Error('frame: ' + inner.canPlayType('audio/x-hostmedia'));
            );
            try testing.expectEqual(@as(usize, 3), host.asked);
        }
    }.body);
}

test "a Browser's backend ends with it: the next Browser on the thread has its own" {
    try onThread(struct {
        fn body() !void {
            var host: FakeHost = .{};
            {
                const first = try @import("browser").Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "", .media_backend = host.backend() });
                defer first.deinit();
                const page = first.current_context orelse return error.TestUnexpectedResult;
                try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "https://example.test/" });
                try page.runScript(
                    \\if (document.createElement('audio').canPlayType('audio/x-hostmedia') !== 'maybe') throw new Error('first Browser lost its backend');
                );
            }
            const second = try @import("browser").Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
            defer second.deinit();
            const page = second.current_context orelse return error.TestUnexpectedResult;
            try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "https://example.test/" });
            try page.runScript(
                \\if (document.createElement('audio').canPlayType('audio/x-hostmedia') !== '') throw new Error('second Browser answered with the first one\'s backend');
            );
            try testing.expectEqual(@as(usize, 1), host.asked);
        }
    }.body);
}
