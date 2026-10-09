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

fn open(_: ?*anyopaque, _: std.mem.Allocator, _: []const u8) anyerror!media.Decoder {
    return error.NotImplemented;
}

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
