//! The WPT runner's media backend: what the runner, as a host, really
//! decodes. Crane builds in no decoder (the user, 2026-10-08: "Host decoders
//! only"); a host supplies one through BrowserConfig.media_backend
//! (src/platform/media_backend.zig), and the runner supplies two:
//! - WAV linear PCM (wav_backend.zig), and
//! - WebM with VP8 or VP9 video and Vorbis or Opus audio (webm_backend.zig).
//!
//! `backend` puts them behind one MediaBackend: canPlayType asks both (their
//! types do not overlap); a decoder hands the resource to the one whose
//! signature its first bytes carry - "RIFF" for WAV, the EBML magic
//! 1A 45 DF A3 for WebM - the way the media element decides a resource's
//! format by sniffing it, whatever its Content-Type says.
//!
//! Also the root of the runner's media test step in build.zig: every media
//! file of the runner is reached from here, so its tests run in
//! `zig build test`.
const std = @import("std");
const media = @import("platform").media_backend;
pub const wav_backend = @import("wav_backend.zig");
pub const webm_demuxer = @import("webm_demuxer.zig");
pub const webm_frames = @import("webm_frames.zig");
pub const webm_backend = @import("webm_backend.zig");

/// Stateless: one backend serves every Browser and thread.
pub const backend: media.MediaBackend = .{ .ptr = null, .vtable = &.{ .can_play_type = canPlayType, .open = open } };

const hosts = [_]media.MediaBackend{ wav_backend.backend, webm_backend.backend };

fn canPlayType(_: ?*anyopaque, mime: []const u8) media.Support {
    var best: media.Support = .unsupported;
    for (hosts) |host| best = @enumFromInt(@max(@intFromEnum(best), @intFromEnum(host.canPlayType(mime))));
    return best;
}

fn open(_: ?*anyopaque, allocator: std.mem.Allocator, _: []const u8) anyerror!media.Decoder {
    const decoder = try allocator.create(Decoder);
    decoder.* = .{ .allocator = allocator };
    return .{ .ptr = decoder, .vtable = &.{ .push = Decoder.push, .deinit = Decoder.deinit, .video_size_at = Decoder.videoSizeAt } };
}

/// The signatures, each as many bytes as `signature_length`.
const Format = enum { wav, webm };
const signature_length = 4;
fn formatOf(prefix: []const u8) ?Format {
    if (std.mem.eql(u8, prefix, "RIFF")) return .wav;
    if (std.mem.eql(u8, prefix, &.{ 0x1A, 0x45, 0xDF, 0xA3 })) return .webm;
    return null;
}

const Decoder = struct {
    allocator: std.mem.Allocator,
    /// The first bytes, until they name a format.
    prefix: [signature_length]u8 = undefined,
    prefix_len: usize = 0,
    inner: ?media.Decoder = null,
    /// Sticky: no signature this host knows.
    unsupported: bool = false,

    fn push(raw: ?*anyopaque, bytes: []const u8, end_of_stream: bool) media.Result {
        const self: *Decoder = @ptrCast(@alignCast(raw.?));
        if (self.unsupported) return .unsupported;
        if (self.inner) |inner| return inner.push(bytes, end_of_stream);
        const take = @min(signature_length - self.prefix_len, bytes.len);
        @memcpy(self.prefix[self.prefix_len..][0..take], bytes[0..take]);
        self.prefix_len += take;
        if (self.prefix_len < signature_length) {
            if (!end_of_stream) return .need_more;
            self.unsupported = true;
            return .unsupported;
        }
        const format = formatOf(&self.prefix) orelse {
            self.unsupported = true;
            return .unsupported;
        };
        const host = switch (format) {
            .wav => wav_backend.backend,
            .webm => webm_backend.backend,
        };
        // Each backend decides by the bytes too; neither reads the MIME type.
        const inner = host.open(self.allocator, "") catch {
            self.unsupported = true;
            return .decode_error;
        };
        self.inner = inner;
        const first = inner.push(&self.prefix, false);
        switch (first) {
            .unsupported, .decode_error => return first,
            else => {},
        }
        return inner.push(bytes[take..], end_of_stream);
    }

    fn deinit(raw: ?*anyopaque) void {
        const self: *Decoder = @ptrCast(@alignCast(raw.?));
        if (self.inner) |*inner| inner.deinit();
        self.allocator.destroy(self);
    }

    fn videoSizeAt(raw: ?*anyopaque, seconds: f64) ?media.VideoSize {
        const self: *Decoder = @ptrCast(@alignCast(raw.?));
        const inner = self.inner orelse return null;
        return inner.videoSizeAt(seconds);
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test {
    std.testing.refAllDecls(@This());
    _ = wav_backend;
    _ = webm_demuxer;
    _ = webm_frames;
    _ = webm_backend;
}

test "canPlayType answers for WAV and WebM alike, and for nothing else" {
    try testing.expectEqual(media.Support.maybe, backend.canPlayType("audio/wav"));
    try testing.expectEqual(media.Support.probably, backend.canPlayType("audio/wav; codecs=1"));
    try testing.expectEqual(media.Support.maybe, backend.canPlayType("video/webm"));
    try testing.expectEqual(media.Support.probably, backend.canPlayType("video/webm; codecs=\"vp9, opus\""));
    try testing.expectEqual(media.Support.probably, backend.canPlayType("audio/webm; codecs=vorbis"));
    for ([_][]const u8{ "video/mp4", "audio/ogg", "audio/mpeg", "video/ogg; codecs=theora", "audio/wav; codecs=vorbis", "audio/webm; codecs=1" }) |mime| {
        try testing.expectEqual(media.Support.unsupported, backend.canPlayType(mime));
    }
}

test "a decoder plays a WebM resource whatever its Content-Type, in pieces" {
    const file = try webm_demuxer.readFixture(testing.allocator, "movie_5.webm");
    defer testing.allocator.free(file);
    for ([_][]const u8{ "video/webm", "audio/wav", "", "application/octet-stream" }) |mime| {
        var decoder = try backend.open(testing.allocator, mime);
        defer decoder.deinit();
        // The signature split across pushes.
        try testing.expectEqual(media.Result.need_more, decoder.push(file[0..1], false));
        try testing.expectEqual(media.Result.need_more, decoder.push(file[1..3], false));
        const outcome = decoder.push(file[3..], true);
        try testing.expect(outcome == .current_data);
        try testing.expectApproxEqAbs(@as(f64, 5.008), outcome.current_data.duration, 0.001);
        try testing.expectEqual(media.VideoSize{ .width = 320, .height = 240 }, decoder.videoSizeAt(1).?);
    }
}

test "a decoder plays a WAV resource; it has no frame size" {
    // A 44-byte PCM header, 8 kHz mono 8-bit, and 8 sample frames.
    const wav = "RIFF\x2c\x00\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00\x40\x1f\x00\x00\x40\x1f\x00\x00\x01\x00\x08\x00data\x08\x00\x00\x00\x80\x80\x80\x80\x80\x80\x80\x80";
    var decoder = try backend.open(testing.allocator, "audio/wav");
    defer decoder.deinit();
    const outcome = decoder.push(wav, true);
    try testing.expect(outcome == .current_data);
    try testing.expectEqual(@as(f64, 0.001), outcome.current_data.duration);
    try testing.expectEqual(@as(?media.VideoSize, null), decoder.videoSizeAt(0));
}

test "no known signature, or too few bytes to tell: unsupported, and it stays so" {
    for ([_][]const u8{ "OggS\x00\x02", "ID3\x04\x00", "\x00\x00\x00\x18ftypmp42", "RIF" }) |bytes| {
        var decoder = try backend.open(testing.allocator, "video/webm");
        defer decoder.deinit();
        try testing.expectEqual(media.Result.unsupported, decoder.push(bytes, true));
        try testing.expectEqual(media.Result.unsupported, decoder.push("RIFF", true));
        try testing.expectEqual(@as(?media.VideoSize, null), decoder.videoSizeAt(0));
    }
    // A broken WebM after its signature is the WebM decoder's verdict.
    var decoder = try backend.open(testing.allocator, "video/webm");
    defer decoder.deinit();
    try testing.expectEqual(media.Result.unsupported, decoder.push("\x1a\x45\xdf\xa3\x84\x42\x82\x81x", true));
}
