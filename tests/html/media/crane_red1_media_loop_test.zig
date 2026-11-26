//! Lane crane-red1: HTMLMediaElement loop playback at end of media resource.
//!
//! HTML 4.8.11.8 ("When the current playback position reaches the end of the
//! media resource when the direction of playback is forwards"): step 1 seeks
//! to the earliest possible position when `loop` is set. Because `reachedEnd()`
//! runs inside `advanceClock()`, seeking from `reachedEnd()` must not re-enter
//! `advanceClock()` before `beginSeek(0)` moves the position off `duration`
//! (otherwise nanosecond monotonic clocks recurse infinitely -> stack overflow).
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");

/// 50 ms of 8 kHz mono 8-bit PCM: 44-byte RIFF/WAVE header + 400 silent samples.
const wav_50ms: []const u8 =
    "RIFF\xb4\x01\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00\x40\x1f\x00\x00\x40\x1f\x00\x00\x01\x00\x08\x00data\x90\x01\x00\x00" ++
    &@as([400]u8, @splat(0x80));

fn wavDataUrl(allocator: std.mem.Allocator) ![]u8 {
    const prefix = "data:audio/wav;base64,";
    const encoded_len = std.base64.standard.Encoder.calcSize(wav_50ms.len);
    const out = try allocator.alloc(u8, prefix.len + encoded_len);
    @memcpy(out[0..prefix.len], prefix);
    _ = std.base64.standard.Encoder.encode(out[prefix.len..], wav_50ms);
    return out;
}

fn runLoopScript(script_template: []const u8) !void {
    const Run = struct {
        script_template: []const u8,
        failure: ?anyerror = null,

        fn thread(self: *@This()) void {
            self.body() catch |err| {
                self.failure = err;
            };
        }

        fn body(self: *@This()) !void {
            const url = try wavDataUrl(testing.allocator);
            defer testing.allocator.free(url);

            const script = try std.mem.replaceOwned(u8, testing.allocator, self.script_template, "__WAV_URL__", url);
            defer testing.allocator.free(script);

            var browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
            defer browser.deinit();
            try browser.navigate("about:blank", .window);
            const page = browser.current_context orelse return error.TestUnexpectedResult;
            try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "https://example.test/" });

            try page.runScript(script);
            var waits: usize = 0;
            while (true) : (waits += 1) {
                _ = try browser.runEventLoopBlocking(25);
                const pending = try page.evaluateScriptToString("String(globalThis.pending === true)", testing.allocator);
                defer testing.allocator.free(pending);
                if (!std.mem.eql(u8, pending, "true")) break;
                if (waits == 250) {
                    std.debug.print("crane-red1 loop test never settled\n", .{});
                    return error.TestUnexpectedResult;
                }
            }
            const failed = try page.evaluateScriptToString("String(globalThis.failed || '')", testing.allocator);
            defer testing.allocator.free(failed);
            if (failed.len != 0) {
                std.debug.print("crane-red1 loop check failed: {s}\n", .{failed});
                return error.TestUnexpectedResult;
            }
        }
    };
    var run: Run = .{ .script_template = script_template };
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

test "crane-red1: looping media seeks back to start at end without recursing" {
    try runLoopScript(
        \\globalThis.pending = true;
        \\globalThis.failed = '';
        \\const audio = document.createElement('audio');
        \\audio.loop = true;
        \\let seeked = 0;
        \\let ended = 0;
        \\audio.addEventListener('ended', () => { ended++; });
        \\audio.addEventListener('error', () => {
        \\  globalThis.failed = 'unexpected error ' + (audio.error && audio.error.code);
        \\  globalThis.pending = false;
        \\});
        \\audio.addEventListener('seeked', () => {
        \\  seeked++;
        \\  if (seeked >= 2) {
        \\    if (ended !== 0) globalThis.failed = 'ended fired ' + ended + ' times while looping';
        \\    else if (audio.ended) globalThis.failed = 'audio.ended was true while looping';
        \\    else if (audio.paused) globalThis.failed = 'audio.paused was true while looping';
        \\    audio.pause();
        \\    audio.removeAttribute('src');
        \\    audio.load();
        \\    globalThis.pending = false;
        \\  }
        \\});
        \\audio.addEventListener('canplaythrough', () => {
        \\  audio.play().catch(e => {
        \\    globalThis.failed = 'play rejected: ' + e;
        \\    globalThis.pending = false;
        \\  });
        \\}, { once: true });
        \\document.body.appendChild(audio);
        \\audio.src = '__WAV_URL__';
    );
}
