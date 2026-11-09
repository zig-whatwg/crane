//! A media element decodes through its Browser's platform (protocol 6.10.5,
//! `media_decoding`; lane wptcfg D4, the user 2026-11-09: the platform
//! compiled in decides whether its decoders are built in or link out). No
//! host passes a decoder in any more: every realm of a Browser - a page, its
//! frames - reaches its Browser's platform state (html.platform_state), and
//! the testing platform, like darwin and linux, builds in kit/media_decoding
//! (WAV linear PCM). A realm with no Browser platform state decodes nothing:
//! canPlayType answers "" and every resource is unsupported.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const html = @import("html");
const decoding = html.media_runtime.decoding;

/// Half a second of 8 kHz mono 8-bit PCM: a 44-byte header, 4,000 samples.
const wav: []const u8 = "RIFF\xc4\x0f\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00\x40\x1f\x00\x00\x40\x1f\x00\x00\x01\x00\x08\x00data\xa0\x0f\x00\x00" ++ &@as([4000]u8, @splat(0x80));

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

test "a realm with no Browser decodes nothing: canPlayType \"\", every resource unsupported" {
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    try testing.expect(ctx.browser_scope == null);
    try testing.expectEqual(decoding.Support.unsupported, decoding.canPlayType(&ctx, "audio/wav"));
    var decoder = try decoding.Decoder.open(&ctx, "audio/wav");
    defer decoder.deinit();
    try testing.expectEqual(decoding.Result.unsupported, decoder.push(wav, true));
    try testing.expectEqual(@as(?decoding.VideoSize, null), decoder.videoSizeAt(0));
}

test "a realm decodes through its Browser scope's platform state, once there is one" {
    var scope = runtime.BrowserScope.init(testing.allocator);
    defer scope.deinit();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    ctx.browser_scope = &scope;
    // A scope with no platform state yet: nothing, and asking makes none.
    try testing.expectEqual(decoding.Support.unsupported, decoding.canPlayType(&ctx, "audio/wav"));
    try testing.expect(scope.existing(html.platform_state.PlatformState) == null);
    try html.platform_state.create(&scope);
    try testing.expectEqual(decoding.Support.maybe, decoding.canPlayType(&ctx, "audio/wav"));
    try testing.expectEqual(decoding.Support.probably, decoding.canPlayType(&ctx, "audio/wav; codecs=\"1\""));
    try testing.expectEqual(decoding.Support.unsupported, decoding.canPlayType(&ctx, "video/webm"));
    var decoder = try decoding.Decoder.open(&ctx, "");
    defer decoder.deinit();
    try testing.expectEqual(decoding.Result.need_more, decoder.push(wav[0..40], false));
    const metadata = decoder.push(wav[40..44], false);
    try testing.expect(metadata == .metadata);
    try testing.expectEqual(@as(f64, 0.5), metadata.metadata.duration);
    const data = decoder.push(wav[44..], true);
    try testing.expect(data == .current_data);
    try testing.expectEqual(decoding.Metadata{ .duration = 0.5 }, data.current_data);
    // Audio only: no frame size.
    try testing.expectEqual(@as(?decoding.VideoSize, null), decoder.videoSizeAt(0.25));
}

test "a Browser's page and its frame answer canPlayType from the platform's decoder" {
    try onThread(struct {
        fn body() !void {
            const browser = try @import("browser").Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
            defer browser.deinit();
            const page = browser.current_context orelse return error.TestUnexpectedResult;
            try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "https://example.test/" });
            try page.runScript(
                \\const audio = document.createElement('audio');
                \\if (audio.canPlayType('audio/wav') !== 'maybe') throw new Error('page: audio/wav ' + audio.canPlayType('audio/wav'));
                \\if (audio.canPlayType('video/webm') !== '') throw new Error('page answered for WebM, which nothing decodes');
                \\const frame = document.createElement('iframe');
                \\document.body.append(frame);
                \\const inner = frame.contentDocument.createElement('video');
                \\if (inner.canPlayType('audio/wav; codecs="1"') !== 'probably') throw new Error('frame: ' + inner.canPlayType('audio/wav; codecs="1"'));
            );
        }
    }.body);
}
