//! The browser console plays WAV through its platform's media decoding
//! (lane wptcfg, D4: the user, 2026-11-09 - "our default platform for running
//! wpt should get its own implementation of these things ... The platform
//! itself that is compiled in will decide if these features are built within
//! the platform or dynamically link out"). Crane's default platforms - darwin,
//! linux and testing - compose the built-in WAV decoder (src/platform/kit/
//! media_decoding/) behind the media_decoding capability, and HTML's media
//! element reaches it through the protocol (mediaCanPlayType,
//! openMediaDecoder, pushMediaData), as a browser reaches its own decoders:
//! no host passes one in. There is no WebM decoder yet, so canPlayType
//! answers "" for WebM - as for every type the platform cannot play.
//!
//! The page is the local site's (site.zig): /a.html, and /tone.wav - half a
//! second of 8 kHz mono 8-bit PCM.
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;
const Console = @import("repl").Console;
const Site = @import("site.zig").Site;

/// A Browser on the local site's /a.html, and a console on it printing into
/// a buffer. Not moved once made.
const Fixture = struct {
    site: *Site,
    browser: *Browser,
    output: std.Io.Writer.Allocating,
    console: Console,

    fn init(self: *Fixture) !void {
        self.site = try Site.start(testing.allocator);
        errdefer self.site.stop();
        self.browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
        errdefer self.browser.deinit();
        self.output = .init(testing.allocator);
        errdefer self.output.deinit();
        self.console = Console.init(testing.allocator, self.browser, &self.output.writer);
        errdefer self.console.deinit();
        self.console.load_timeout_ms = 20_000;
        const page = try self.site.url(testing.allocator, "/a.html");
        defer testing.allocator.free(page);
        _ = try self.runf(".open {s}", .{page});
    }

    fn deinit(self: *Fixture) void {
        self.console.deinit();
        self.output.deinit();
        self.browser.deinit();
        self.site.stop();
    }

    /// Feed `line`: what the console printed for it.
    fn run(self: *Fixture, line: []const u8) ![]const u8 {
        self.output.clearRetainingCapacity();
        _ = try self.console.feedLine(line);
        return self.output.written();
    }

    fn runf(self: *Fixture, comptime format: []const u8, args: anytype) ![]const u8 {
        const line = try std.fmt.allocPrint(testing.allocator, format, args);
        defer testing.allocator.free(line);
        return self.run(line);
    }
};

test "canPlayType answers for WAV from the platform's decoder: maybe without codecs, probably for PCM" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try testing.expectEqualStrings("'maybe'\n", try f.run("document.createElement('audio').canPlayType('audio/wav')"));
    try testing.expectEqualStrings("'probably'\n", try f.run("document.createElement('video').canPlayType('audio/wav; codecs=\"1\"')"));
}

test "a WAV loads its metadata: loadedmetadata, with the duration its header gives" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try testing.expectEqualStrings("'loadedmetadata 0.5'\n", try f.run(
        "await new Promise((resolve) => { const a = document.createElement('audio'); " ++
            "a.onloadedmetadata = () => resolve('loadedmetadata ' + a.duration); " ++
            "a.onerror = () => resolve('error ' + a.error.code); a.src = '/tone.wav'; })",
    ));
}

test "a WAV plays to its end: play() resolves, then ended, paused at its duration" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try testing.expectEqualStrings("'played; ended true paused true at 0.5'\n", try f.run(
        "await new Promise((resolve) => { const a = document.createElement('audio'); let log = ''; " ++
            "a.onended = () => resolve(log + 'ended ' + a.ended + ' paused ' + a.paused + ' at ' + a.currentTime); " ++
            "a.onerror = () => resolve('error ' + a.error.code); a.src = '/tone.wav'; " ++
            "a.play().then(() => { log += 'played; '; }, (e) => resolve('play rejected: ' + e.name)); })",
    ));
}

test "no WebM, Ogg or MP4 decoder is built in: canPlayType answers \"\"" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try testing.expectEqualStrings("'||||||'\n", try f.run(
        "['video/webm', 'audio/webm', 'video/webm; codecs=\"vp9, opus\"', 'audio/webm; codecs=vorbis', 'audio/ogg', 'video/mp4', 'audio/mpeg']" ++
            ".map((type) => document.createElement('video').canPlayType(type)).join('|')",
    ));
}
