//! The WPT runner's WebM media backend: a host decoder for WebM with VP8 or
//! VP9 video and Vorbis or Opus audio, which plays what it really validates.
//!
//! Crane builds in no decoder (the user, 2026-10-08: "Host decoders only");
//! the runner is a host, and supplies this through BrowserConfig.media_backend
//! beside the WAV backend (host_media.zig). It decodes no pixels and no
//! samples: the runner has no output, so nothing observable depends on them.
//! What it answers for, it has read:
//! - canPlayType: the WebM MIME types and codecs strings the browsers accept,
//!   for the codecs this backend validates - "" for any other (AV1 among them);
//! - the decoder demuxes the stream (webm_demuxer.zig) and reports metadata
//!   once Tracks is read; current_data only once the first frame of every
//!   audio and video track - the frame at the playback position, the start -
//!   is in hand and is a real frame of its codec (webm_frames.zig).
//! A test that reads decoded content (pixels through a canvas) is not covered.
const std = @import("std");
const media = @import("platform").media_backend;
const mimesniff = @import("mimesniff");

/// Stateless: one backend serves every Browser and thread.
pub const backend: media.MediaBackend = .{ .ptr = null, .vtable = &.{ .can_play_type = canPlayType, .open = open } };

// ----------------------------------------------------------------------------
// canPlayType
// ----------------------------------------------------------------------------

/// "Can play type" for `mime`, a valid MIME type string or not.
/// - video/webm and audio/webm with no codecs parameter (or an empty one):
///   "maybe" - the container is known, the codecs are not (Chromium
///   media/base/mime_util_internal.cc IsSupportedMediaFormat answers
///   kMaybeSupported for a known container with no codecs; Gecko
///   WebMDecoder::IsSupportedType accepts an empty codecs list, and its
///   canPlayType reports that as "maybe").
/// - with codecs: "probably" when every entry is one this backend validates,
///   else "". audio/webm takes the audio codecs only - Chromium's
///   `AddContainerWithCodecs("audio/webm", webm_audio_codecs{OPUS, VORBIS})`,
///   Gecko's `isVideo` check - and video/webm takes both.
/// WPT html/semantics/embedded-content/media-elements/mime-types/canPlayType.html
/// pins these for audio/webm (opus, vorbis) and video/webm (opus, vorbis,
/// vp8, vp8.0, vp9, vp9.0); Chrome and Firefox return "probably" for each.
fn canPlayType(_: ?*anyopaque, mime: []const u8) media.Support {
    // The vtable has no allocator: a MIME type longer than this buffer holds
    // is no type this backend plays.
    var buffer: [16 * 1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buffer);
    var parsed = (mimesniff.parseMimeType(fixed.allocator(), mime) catch return .unsupported) orelse return .unsupported;
    defer parsed.deinit();
    if (!utf16Eql(parsed.subtype, "webm")) return .unsupported;
    const video = utf16Eql(parsed.type, "video");
    if (!video and !utf16Eql(parsed.type, "audio")) return .unsupported;
    const codecs = for (parsed.parameters.entries.items()) |entry| {
        if (utf16Eql(entry.key, "codecs")) break entry.value;
    } else return .maybe;
    if (codecs.len == 0) return .maybe;
    // RFC 6381: a comma-separated list; every entry must be one we validate.
    var entries = std.mem.splitScalar(u16, codecs, ',');
    while (entries.next()) |raw| {
        const entry = std.mem.trim(u16, raw, &.{ ' ', '\t', '\n', '\r' });
        var ascii: [64]u8 = undefined;
        if (entry.len > ascii.len) return .unsupported;
        for (entry, 0..) |unit, index| {
            if (unit > 0x7F) return .unsupported;
            ascii[index] = @intCast(unit);
        }
        if (!codecSupported(ascii[0..entry.len], video)) return .unsupported;
    }
    return .probably;
}

/// One codecs entry, case-sensitively, as Chromium's kStringToCodecMap and
/// Gecko's EqualsLiteral match them.
/// - "opus", "vorbis": both containers. (Chromium also maps "Opus"; Gecko
///   does not, so neither does this backend.)
/// - video/webm only: "vp8" and "vp8.0" (Chromium kStringToCodecMap; Gecko
///   IsVP8CodecString), "vp9" and "vp9.0" (Chromium ParseLegacyVp9CodecID,
///   "only valid with video/webm for legacy reasons"; Gecko
///   IsVP9CodecString), and the RFC-6381-style "vp09.PP.LL.DD[...]"
///   (newStyleVp9).
fn codecSupported(codec: []const u8, video: bool) bool {
    if (std.mem.eql(u8, codec, "opus") or std.mem.eql(u8, codec, "vorbis")) return true;
    if (!video) return false;
    for ([_][]const u8{ "vp8", "vp8.0", "vp9", "vp9.0" }) |name| {
        if (std.mem.eql(u8, codec, name)) return true;
    }
    return newStyleVp9(codec);
}

/// Chromium media/base/video_codec_string_parsers.cc ParseNewStyleVp9CodecID
/// (VP9 codec ISO-BMFF binding, "Codecs Parameter String"): "vp09" and 3 to 8
/// non-negative integer fields - profile 0-3, a VP9 level, bit depth 8, 10 or
/// 12, then optionally chroma subsampling 0-3, color primaries, transfer
/// characteristics, matrix coefficients (each one of ISO/IEC 23091-2's code
/// points Chromium's VideoColorSpace accepts) and the full-range flag 0-1.
fn newStyleVp9(codec: []const u8) bool {
    var fields = std.mem.splitScalar(u8, codec, '.');
    if (!std.mem.eql(u8, fields.first(), "vp09")) return false;
    var values: [8]u32 = undefined;
    var count: usize = 0;
    while (fields.next()) |field| {
        if (count == values.len or field.len == 0) return false;
        values[count] = std.fmt.parseUnsigned(u32, field, 10) catch return false;
        count += 1;
    }
    if (count < 3) return false;
    if (values[0] > 3) return false;
    switch (values[1]) {
        10, 11, 20, 21, 30, 31, 40, 41, 50, 51, 52, 60, 61, 62 => {},
        else => return false,
    }
    if (values[2] != 8 and values[2] != 10 and values[2] != 12) return false;
    if (count > 3 and values[3] > 3) return false;
    // VideoColorSpace::GetPrimaryID, GetTransferID, GetMatrixID.
    if (count > 4 and (values[4] < 1 or values[4] == 3 or (values[4] > 12 and values[4] != 22))) return false;
    if (count > 5 and (values[5] < 1 or values[5] == 3 or values[5] > 18)) return false;
    if (count > 6 and (values[6] == 3 or values[6] == 10 or values[6] > 11)) return false;
    if (count > 7 and values[7] > 1) return false;
    return true;
}

fn utf16Eql(units: []const u16, ascii: []const u8) bool {
    if (units.len != ascii.len) return false;
    for (units, ascii) |unit, byte| if (unit != byte) return false;
    return true;
}

// ----------------------------------------------------------------------------
// The decoder
// ----------------------------------------------------------------------------

/// A decoder for one resource. What it decodes is decided by the bytes (an
/// EBML header whose DocType is "webm"), the way the media element decides a
/// resource's format by sniffing it.
fn open(_: ?*anyopaque, allocator: std.mem.Allocator, _: []const u8) anyerror!media.Decoder {
    const decoder = try allocator.create(Decoder);
    decoder.* = .{ .allocator = allocator, .demuxer = demuxer_mod.Demuxer.init(allocator) };
    return .{ .ptr = decoder, .vtable = &.{ .push = Decoder.push, .deinit = Decoder.deinit, .video_size_at = Decoder.videoSizeAt } };
}

const demuxer_mod = @import("webm_demuxer.zig");
const frames = @import("webm_frames.zig");

/// A track this decoder plays: the first enabled video track and the first
/// enabled audio track (the ones a browser selects by default).
const Selected = struct {
    number: u64,
    codec: demuxer_mod.Codec,
    /// Its first frame - the one at the start of the timeline - has arrived
    /// and is a real frame of its codec.
    ready: bool = false,
};

/// A key frame whose size differs from the one before it.
const SizeChange = struct { time_ns: i64, size: frames.FrameSize };

pub const Decoder = struct {
    allocator: std.mem.Allocator,
    demuxer: demuxer_mod.Demuxer,
    /// A sticky outcome: once a resource is unsupported or broken, it stays so.
    failed: ?media.Result = null,
    tracks_read: bool = false,
    video: ?Selected = null,
    audio: ?Selected = null,
    /// The video track header's PixelWidth and PixelHeight.
    header_size: ?frames.FrameSize = null,
    /// The size of each video key frame that changed it, in stream order.
    sizes: std.ArrayList(SizeChange) = .empty,
    /// The end of the latest frame of a played track, for a stream that
    /// declares no duration.
    end_ns: i64 = 0,

    fn push(raw: ?*anyopaque, bytes: []const u8, end_of_stream: bool) media.Result {
        const self: *Decoder = @ptrCast(@alignCast(raw.?));
        return self.feed(bytes, end_of_stream);
    }

    fn deinit(raw: ?*anyopaque) void {
        const self: *Decoder = @ptrCast(@alignCast(raw.?));
        self.sizes.deinit(self.allocator);
        self.demuxer.deinit();
        self.allocator.destroy(self);
    }

    fn videoSizeAt(raw: ?*anyopaque, seconds: f64) ?media.VideoSize {
        const self: *Decoder = @ptrCast(@alignCast(raw.?));
        return self.sizeAt(seconds);
    }

    /// The size of the last key frame at or before `seconds`; before the
    /// first, the first's (HTML 4.8.8: a position before all of a track's
    /// data has "the same dimensions as the first frame for that track").
    pub fn sizeAt(self: *const Decoder, seconds: f64) ?media.VideoSize {
        if (self.sizes.items.len == 0) return null;
        var size = self.sizes.items[0].size;
        const at = seconds * std.time.ns_per_s;
        for (self.sizes.items[1..]) |change| {
            if (@as(f64, @floatFromInt(change.time_ns)) > at) break;
            size = change.size;
        }
        return .{ .width = size.width, .height = size.height };
    }

    pub fn feed(self: *Decoder, bytes: []const u8, end_of_stream: bool) media.Result {
        if (self.failed) |outcome| return outcome;
        self.demuxer.push(bytes) catch |err| return self.fail(failure(err));
        while (true) {
            const event = (self.demuxer.next() catch |err| return self.fail(failure(err))) orelse break;
            const outcome = switch (event) {
                .tracks => self.selectTracks(),
                .block => |block| self.onBlock(block),
            };
            if (outcome) |result_| return self.fail(result_);
        }
        if (end_of_stream) {
            self.demuxer.finish() catch |err| {
                // A stream that was never WebM is unsupported. One that ends
                // early still plays the frames it holds, if it holds any.
                if (err == error.NotWebM or !self.anyReady()) return self.fail(failure(err));
            };
        }
        return self.result(end_of_stream);
    }

    fn failure(err: demuxer_mod.Error) media.Result {
        return switch (err) {
            error.NotWebM => .unsupported,
            error.Corrupt, error.OutOfMemory => .decode_error,
        };
    }

    fn fail(self: *Decoder, outcome: media.Result) media.Result {
        self.failed = outcome;
        return outcome;
    }

    /// Tracks has been read: pick the tracks to play. A stream with an audio
    /// or video track this host does not validate is unsupported - a codec
    /// canPlayType answers "" for (AV1, say), or frames compressed or
    /// encrypted by ContentEncodings.
    fn selectTracks(self: *Decoder) ?media.Result {
        self.tracks_read = true;
        for (self.demuxer.tracks.items) |entry| {
            if (entry.kind == .other or !entry.enabled) continue;
            if (entry.codec == .other or entry.encoded) return .unsupported;
            const selected: Selected = .{ .number = entry.number, .codec = entry.codec };
            switch (entry.kind) {
                .video => if (self.video == null) {
                    if (entry.codec != .vp8 and entry.codec != .vp9) return .decode_error;
                    self.video = selected;
                    if (entry.pixel_width != 0 and entry.pixel_height != 0) self.header_size = .{ .width = entry.pixel_width, .height = entry.pixel_height };
                },
                .audio => if (self.audio == null) {
                    switch (entry.codec) {
                        .opus => _ = frames.opusHead(entry.codec_private) catch |err| return headerFailure(err),
                        .vorbis => _ = frames.vorbisHeaders(entry.codec_private) catch |err| return headerFailure(err),
                        else => return .decode_error,
                    }
                    self.audio = selected;
                },
                .other => unreachable,
            }
        }
        if (self.video == null and self.audio == null) return .unsupported;
        return null;
    }

    fn headerFailure(err: frames.Error) media.Result {
        return switch (err) {
            error.Invalid => .decode_error,
            error.Unsupported => .unsupported,
        };
    }

    fn onBlock(self: *Decoder, block: demuxer_mod.Block) ?media.Result {
        const entry = self.demuxer.trackNumbered(block.track) orelse return .decode_error;
        const is_video = if (self.video) |video| video.number == block.track else false;
        const is_audio = if (self.audio) |audio| audio.number == block.track else false;
        if (!is_video and !is_audio) return null;
        if (block.frames.len == 0 or block.frames[0].len == 0) return .decode_error;
        const duration: u64 = if (block.duration_ns != 0) block.duration_ns else entry.default_duration_ns * block.frames.len;
        self.end_ns = @max(self.end_ns, block.time_ns + @as(i64, @intCast(duration)));
        if (is_video) return self.onVideo(block);
        const audio = &self.audio.?;
        if (audio.ready) return null;
        // The first audio block: every packet in it is a packet of its codec.
        for (block.frames) |packet| {
            const valid = switch (audio.codec) {
                .opus => frames.opusPacket(packet),
                .vorbis => frames.vorbisAudioPacket(packet),
                else => unreachable,
            };
            valid catch return .decode_error;
        }
        audio.ready = true;
        return null;
    }

    fn onVideo(self: *Decoder, block: demuxer_mod.Block) ?media.Result {
        const video = &self.video.?;
        const parsed = switch (video.codec) {
            .vp8 => frames.vp8(block.frames[0]),
            .vp9 => frames.vp9(block.frames[0]),
            else => unreachable,
        } catch {
            // The frame at the start must be a frame; a later one is read
            // only for its size, and a decoder reaching a broken one is a
            // decode error then, not now.
            return if (video.ready) null else .decode_error;
        };
        if (!video.ready) {
            // Decoding starts at a key frame.
            if (!parsed.keyframe or parsed.size == null) return .decode_error;
            video.ready = true;
        }
        const size = parsed.size orelse return null;
        if (self.sizes.items.len != 0 and std.meta.eql(self.sizes.items[self.sizes.items.len - 1].size, size)) return null;
        self.sizes.append(self.allocator, .{ .time_ns = block.time_ns, .size = size }) catch return .decode_error;
        return null;
    }

    fn anyReady(self: *const Decoder) bool {
        return (if (self.video) |video| video.ready else false) or (if (self.audio) |audio| audio.ready else false);
    }

    fn allReady(self: *const Decoder) bool {
        return (if (self.video) |video| video.ready else true) and (if (self.audio) |audio| audio.ready else true);
    }

    /// What the decoder holds now.
    fn result(self: *Decoder, end_of_stream: bool) media.Result {
        if (!self.tracks_read) {
            if (!end_of_stream) return .need_more;
            // The stream ended before its Tracks.
            return self.fail(if (self.demuxer.header_seen) .decode_error else .unsupported);
        }
        const metadata = self.describe(end_of_stream);
        // The frame at the playback position, the start, of every played
        // track. At the end of the stream, a track that never delivered a
        // frame does not hold the others back.
        if (self.allReady() or (end_of_stream and self.anyReady())) return .{ .current_data = metadata };
        if (end_of_stream) return self.fail(.decode_error);
        return .{ .metadata = metadata };
    }

    fn describe(self: *const Decoder, end_of_stream: bool) media.Metadata {
        // A stream that declares no duration (a live stream) is unbounded
        // until it ends (HTML 4.8.11.5: "+Infinity" for an unbounded
        // resource); then it lasts until its last frame ends - or starts,
        // when no BlockDuration or DefaultDuration says how long it lasts.
        const duration = self.demuxer.declaredDuration() orelse if (end_of_stream)
            @as(f64, @floatFromInt(self.end_ns)) / std.time.ns_per_s
        else
            std.math.inf(f64);
        const size = if (self.sizes.items.len != 0) self.sizes.items[0].size else self.header_size orelse frames.FrameSize{ .width = 0, .height = 0 };
        return .{ .duration = duration, .width = size.width, .height = size.height };
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "canPlayType: the WebM containers, with and without codecs" {
    const maybe = [_][]const u8{ "video/webm", "audio/webm", "VIDEO/WEBM", "video/webm;", "video/webm;codecs", "video/webm;codecs=", "video/webm; codecs=\"\"", " audio/webm ; foo=bar" };
    for (maybe) |mime| try testing.expectEqual(media.Support.maybe, backend.canPlayType(mime));
    const probably = [_][]const u8{
        // WPT canPlayType.html's audio/webm and video/webm codecs.
        "audio/webm; codecs=\"opus\"",
        "audio/webm; codecs=\"vorbis\"",
        "video/webm; codecs=\"opus\"",
        "video/webm; codecs=\"vorbis\"",
        "video/webm; codecs=\"vp8\"",
        "video/webm; codecs=\"vp8.0\"",
        "video/webm; codecs=\"vp9\"",
        "video/webm; codecs=\"vp9.0\"",
        "video/webm; codecs=\"vp8, vorbis\"",
        "video/webm; codecs=\"vorbis, vp8\"",
        // common/media.js getVideoURI's probe.
        "video/webm; codecs=\"vp9, opus\"",
        "video/webm; codecs=vp8",
        "video/webm;codecs=\"vp09.00.10.08\"",
        "video/webm; codecs=\"vp09.02.10.10.01.09.16.09.01, opus\"",
        "video/webm; codecs=\"vp09.1.20.8\"",
    };
    for (probably) |mime| try testing.expectEqual(media.Support.probably, backend.canPlayType(mime));
    const unsupported = [_][]const u8{
        "",
        "video/webm; codecs=\"bogus\"",
        "audio/webm; codecs=\"bogus\"",
        // Video codecs in an audio container.
        "audio/webm; codecs=\"vp8\"",
        "audio/webm; codecs=\"vp9\"",
        "audio/webm; codecs=\"vp8, vorbis\"",
        "audio/webm; codecs=\"vp09.00.10.08\"",
        // Codecs this backend does not validate.
        "video/webm; codecs=\"av01.0.04M.08\"",
        "video/webm; codecs=\"vp8, flac\"",
        "video/webm; codecs=\"theora\"",
        "video/webm; codecs=\"avc1.42E01E\"",
        // Case-sensitive, as both engines match them.
        "video/webm; codecs=\"VP8\"",
        "audio/webm; codecs=\"Opus\"",
        // An empty entry.
        "video/webm; codecs=\"vp8,\"",
        // vp09 strings Chromium's parser refuses: too few fields, a bad
        // profile, level, bit depth, chroma, primaries, transfer, matrix,
        // range, an empty field, too many fields.
        "video/webm; codecs=\"vp09.00.10\"",
        "video/webm; codecs=\"vp09.04.10.08\"",
        "video/webm; codecs=\"vp09.00.12.08\"",
        "video/webm; codecs=\"vp09.00.10.09\"",
        "video/webm; codecs=\"vp09.00.10.08.04\"",
        "video/webm; codecs=\"vp09.00.10.08.01.03\"",
        "video/webm; codecs=\"vp09.00.10.08.01.01.19\"",
        "video/webm; codecs=\"vp09.00.10.08.01.01.01.10\"",
        "video/webm; codecs=\"vp09.00.10.08.01.01.01.01.02\"",
        "video/webm; codecs=\"vp09..10.08\"",
        "video/webm; codecs=\"vp09.00.10.08.01.01.01.01.00.00\"",
        "video/x-matroska",
        "video/mp4; codecs=\"vp09.00.10.08\"",
        "audio/wav",
        "application/octet-stream; codecs=\"vp8, vorbis\"",
        "video/webm2",
    };
    for (unsupported) |mime| {
        testing.expectEqual(media.Support.unsupported, backend.canPlayType(mime)) catch |err| {
            std.debug.print("canPlayType({s})\n", .{mime});
            return err;
        };
    }
}

const Expected = struct { name: []const u8, duration: f64, width: u32 = 0, height: u32 = 0 };

/// Every WebM file in tests/wpt/media, with ffprobe's duration and size.
const expectations = [_]Expected{
    .{ .name = "2x2-green.webm", .duration = 0.096, .width = 2, .height = 2 },
    .{ .name = "A4.webm", .duration = 3.049, .width = 320, .height = 240 },
    .{ .name = "counting.webm", .duration = 9.8, .width = 352, .height = 288 },
    .{ .name = "green-at-15.webm", .duration = 30.0, .width = 320, .height = 240 },
    .{ .name = "movie_300.webm", .duration = 300.041, .width = 320, .height = 240 },
    .{ .name = "movie_5.webm", .duration = 5.008, .width = 320, .height = 240 },
    .{ .name = "rgb100.webm", .duration = 0.6, .width = 100, .height = 100 },
    .{ .name = "test-1s.webm", .duration = 1.008, .width = 320, .height = 240 },
    .{ .name = "test-a-128k-44100Hz-1ch.webm", .duration = 2.023 },
    .{ .name = "test-av-384k-44100Hz-1ch-320x240-30fps-10kfr.webm", .duration = 2.023, .width = 320, .height = 240 },
    .{ .name = "test-v-128k-320x240-24fps-8kfr.webm", .duration = 2.0, .width = 320, .height = 240 },
    .{ .name = "test.webm", .duration = 6.035, .width = 320, .height = 240 },
    .{ .name = "video.webm", .duration = 0.966, .width = 352, .height = 288 },
    .{ .name = "white.webm", .duration = 10.0, .width = 320, .height = 240 },
};

fn openDecoder() !media.Decoder {
    return backend.open(testing.allocator, "video/webm");
}

test "every WPT media WebM file plays: current data, its duration and size" {
    for (expectations) |expected| {
        const file = try demuxer_mod.readFixture(testing.allocator, expected.name);
        defer testing.allocator.free(file);
        var decoder = try openDecoder();
        defer decoder.deinit();
        const outcome = decoder.push(file, true);
        testing.expect(outcome == .current_data) catch |err| {
            std.debug.print("{s}: {s}\n", .{ expected.name, @tagName(outcome) });
            return err;
        };
        try testing.expectApproxEqAbs(expected.duration, outcome.current_data.duration, 0.001);
        try testing.expectEqual(expected.width, outcome.current_data.width);
        try testing.expectEqual(expected.height, outcome.current_data.height);
    }
}

test "pushed in small pieces: need_more, then metadata, then current data - never earlier" {
    const file = try demuxer_mod.readFixture(testing.allocator, "movie_5.webm");
    defer testing.allocator.free(file);
    var decoder = try openDecoder();
    defer decoder.deinit();
    var seen_metadata = false;
    var seen_current = false;
    var offset: usize = 0;
    while (offset < file.len) : (offset += 97) {
        const piece = file[offset..@min(offset + 97, file.len)];
        const outcome = decoder.push(piece, offset + 97 >= file.len);
        switch (outcome) {
            .need_more => try testing.expect(!seen_metadata),
            .metadata => {
                try testing.expect(!seen_current);
                seen_metadata = true;
            },
            .current_data => |metadata| {
                // Metadata came first: Tracks precede the first cluster.
                try testing.expect(seen_metadata);
                try testing.expectEqual(@as(u32, 320), metadata.width);
                seen_current = true;
            },
            else => return error.TestUnexpectedResult,
        }
    }
    try testing.expect(seen_current);
}

test "a truncated file: before its first frames a decode error, after them it plays what it holds" {
    const file = try demuxer_mod.readFixture(testing.allocator, "test-v-128k-320x240-24fps-8kfr.webm");
    defer testing.allocator.free(file);
    // The first Cluster after Tracks (the SeekHead names the Cluster ID too).
    const cluster = std.mem.indexOfPos(u8, file, std.mem.indexOf(u8, file, "V_VP8").?, &.{ 0x1F, 0x43, 0xB6, 0x75 }).?;
    {
        var decoder = try openDecoder();
        defer decoder.deinit();
        try testing.expect(decoder.push(file[0..cluster], false) == .metadata);
        try testing.expectEqual(media.Result.decode_error, decoder.push("", true));
        // Sticky.
        try testing.expectEqual(media.Result.decode_error, decoder.push(file[cluster..], true));
    }
    {
        var decoder = try openDecoder();
        defer decoder.deinit();
        const outcome = decoder.push(file[0 .. file.len / 2], true);
        try testing.expect(outcome == .current_data);
        try testing.expectApproxEqAbs(@as(f64, 2.0), outcome.current_data.duration, 0.001);
    }
    {
        // Inside the EBML header: WebM never recognized.
        var decoder = try openDecoder();
        defer decoder.deinit();
        try testing.expectEqual(media.Result.unsupported, decoder.push(file[0..10], true));
    }
}

test "a corrupt first frame is a decode error, never current data" {
    const file = try demuxer_mod.readFixture(testing.allocator, "test-v-128k-320x240-24fps-8kfr.webm");
    defer testing.allocator.free(file);
    const copy = try testing.allocator.dupe(u8, file);
    defer testing.allocator.free(copy);
    // The first key frame's start code.
    const at = std.mem.indexOf(u8, copy, &.{ 0x9d, 0x01, 0x2a }).?;
    copy[at] = 0x9e;
    var decoder = try openDecoder();
    defer decoder.deinit();
    try testing.expectEqual(media.Result.decode_error, decoder.push(copy, true));

    // An Opus track whose OpusHead is broken.
    const movie = try demuxer_mod.readFixture(testing.allocator, "movie_5.webm");
    defer testing.allocator.free(movie);
    const head = std.mem.indexOf(u8, movie, "OpusHead").?;
    movie[head + 8] = 0x20; // major version 2
    var opus = try openDecoder();
    defer opus.deinit();
    try testing.expectEqual(media.Result.decode_error, opus.push(movie, true));
}

test "a codec this host does not validate, or another format, is unsupported" {
    const file = try demuxer_mod.readFixture(testing.allocator, "test-v-128k-320x240-24fps-8kfr.webm");
    defer testing.allocator.free(file);
    const copy = try testing.allocator.dupe(u8, file);
    defer testing.allocator.free(copy);
    const at = std.mem.indexOf(u8, copy, "V_VP8").?;
    @memcpy(copy[at..][0..5], "V_AV1");
    var decoder = try openDecoder();
    defer decoder.deinit();
    try testing.expectEqual(media.Result.unsupported, decoder.push(copy, true));

    for ([_][]const u8{ "RIFF\x24\x00\x00\x00WAVEfmt ", "OggS\x00\x02 an ogg file", "ID3\x04 an mp3" }) |bytes| {
        var other = try openDecoder();
        defer other.deinit();
        try testing.expectEqual(media.Result.unsupported, other.push(bytes, false));
    }
}

test "a live stream: unbounded until it ends; the frame size at each position" {
    const file = try demuxer_mod.readFixture(testing.allocator, "400x300-red-resize-200x150-green.webm");
    defer testing.allocator.free(file);
    var decoder = try openDecoder();
    defer decoder.deinit();
    const first = decoder.push(file[0 .. file.len / 3], false);
    try testing.expect(first == .current_data);
    try testing.expect(std.math.isPositiveInf(first.current_data.duration));
    try testing.expectEqual(@as(u32, 400), first.current_data.width);
    const last = decoder.push(file[file.len / 3 ..], true);
    try testing.expect(last == .current_data);
    // ffprobe: the last frame starts at 1.968 s; no block says how long it lasts.
    try testing.expectApproxEqAbs(@as(f64, 1.968), last.current_data.duration, 0.0005);
    // The size the first frame had, then the second key frame's from 0.986 s.
    try testing.expectEqual(media.VideoSize{ .width = 400, .height = 300 }, decoder.videoSizeAt(0).?);
    try testing.expectEqual(media.VideoSize{ .width = 400, .height = 300 }, decoder.videoSizeAt(0.98).?);
    try testing.expectEqual(media.VideoSize{ .width = 200, .height = 150 }, decoder.videoSizeAt(0.986).?);
    try testing.expectEqual(media.VideoSize{ .width = 200, .height = 150 }, decoder.videoSizeAt(1.5).?);
    try testing.expectEqual(media.VideoSize{ .width = 400, .height = 300 }, decoder.videoSizeAt(-1).?);
}

test "audio only: no frame size" {
    const file = try demuxer_mod.readFixture(testing.allocator, "test-a-128k-44100Hz-1ch.webm");
    defer testing.allocator.free(file);
    var decoder = try openDecoder();
    defer decoder.deinit();
    try testing.expect(decoder.push(file, true) == .current_data);
    try testing.expectEqual(@as(?media.VideoSize, null), decoder.videoSizeAt(0));
}
