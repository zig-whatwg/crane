//! Media decoding on Crane's default platforms (lane wptcfg, D4; the user,
//! 2026-11-09: "our default platform for running wpt should get its own
//! implementation of these things ... The platform itself that is compiled
//! in will decide if these features are built within the platform or
//! dynamically link out to existing capabilities on the platform"). darwin,
//! linux and testing each compose the built-in WAV decoder
//! (src/platform/kit/media_decoding/) behind `media_decoding`; there is no
//! WebM, Ogg or MP4 decoder yet, so those answer "" and decode nothing.
//!
//! The directory's executable binds `testing`; build.zig binds this file to
//! darwin and linux too, beside protocol_conformance_test.zig - one set of
//! tests for the three platforms, which share the decoder.

const std = @import("std");
const platform = @import("platform");

const testing = std.testing;

fn ignoreEvent(context: ?*anyopaque, event: *const platform.PlatformEvent) callconv(.c) void {
    _ = .{ context, event };
}

const no_events: platform.EventSink = .{ .context = null, .post = ignoreEvent };

/// A canonical 44-byte header - PCM, mono, 8,000 Hz, 8-bit - and `samples`
/// bytes of silence.
fn wav(comptime samples: u32) [44 + samples]u8 {
    return comptime blk: {
        var header: [44]u8 = undefined;
        @memcpy(header[0..4], "RIFF");
        std.mem.writeInt(u32, header[4..8], 36 + samples, .little);
        @memcpy(header[8..16], "WAVEfmt ");
        std.mem.writeInt(u32, header[16..20], 16, .little);
        std.mem.writeInt(u16, header[20..22], 1, .little); // WAVE_FORMAT_PCM
        std.mem.writeInt(u16, header[22..24], 1, .little); // channels
        std.mem.writeInt(u32, header[24..28], 8000, .little); // sample rate
        std.mem.writeInt(u32, header[28..32], 8000, .little); // byte rate
        std.mem.writeInt(u16, header[32..34], 1, .little); // block align
        std.mem.writeInt(u16, header[34..36], 8, .little); // bits per sample
        @memcpy(header[36..40], "data");
        std.mem.writeInt(u32, header[40..44], samples, .little);
        break :blk header ++ @as([samples]u8, @splat(0x80));
    };
}

test "media_decoding is native on the default platforms: the built-in decoder" {
    try testing.expectEqual(platform.Support.native, platform.capabilities.media_decoding);
}

test "canPlayType: WAV is maybe, PCM probably; WebM, Ogg and MP4 are \"\"" {
    // Every default platform decodes media: a binding without it fails here,
    // never skips.
    if (comptime platform.capabilities.media_decoding == .unsupported) return error.MediaDecodingUnsupported;
    const browser = try platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    for ([_][]const u8{ "audio/wav", "audio/wave", "audio/x-wav", "AUDIO/WAV" }) |mime| {
        try testing.expectEqual(platform.MediaSupport.maybe, platform.mediaCanPlayType(browser, .from(mime)));
    }
    for ([_][]const u8{ "audio/wav; codecs=\"1\"", "audio/x-wav;codecs=1" }) |mime| {
        try testing.expectEqual(platform.MediaSupport.probably, platform.mediaCanPlayType(browser, .from(mime)));
    }
    for ([_][]const u8{ "", "video/webm", "audio/webm", "video/webm; codecs=\"vp9, opus\"", "audio/webm; codecs=vorbis", "audio/ogg", "video/mp4", "audio/mpeg", "audio/wav; codecs=\"3\"", "application/octet-stream" }) |mime| {
        try testing.expectEqual(platform.MediaSupport.unsupported, platform.mediaCanPlayType(browser, .from(mime)));
    }
}

test "a WAV decodes in pieces: need_more through its header, metadata, then current data" {
    // Every default platform decodes media: a binding without it fails here,
    // never skips.
    if (comptime platform.capabilities.media_decoding == .unsupported) return error.MediaDecodingUnsupported;
    const browser = try platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    const file = wav(4000);
    // The Content-Type does not decide: the bytes do, as the media element
    // sniffs a resource.
    for ([_][]const u8{ "audio/wav", "", "application/octet-stream" }) |mime| {
        const decoder = try platform.openMediaDecoder(browser, .from(mime));
        defer platform.closeMediaDecoder(decoder);
        var metadata: platform.MediaMetadata = .{};
        try testing.expectEqual(platform.MediaResult.need_more, platform.pushMediaData(decoder, .from(file[0..43]), false, &metadata));
        try testing.expectEqual(platform.MediaResult.metadata, platform.pushMediaData(decoder, .from(file[43..44]), false, &metadata));
        try testing.expectEqual(@as(f64, 0.5), metadata.duration);
        metadata = .{};
        try testing.expectEqual(platform.MediaResult.current_data, platform.pushMediaData(decoder, .from(file[44..]), true, &metadata));
        try testing.expectEqual(@as(f64, 0.5), metadata.duration);
        try testing.expectEqual(@as(u32, 0), metadata.width);
        try testing.expectEqual(@as(u32, 0), metadata.height);
        // Audio only: no frame size at any position.
        var size: platform.VideoSize = .{ .width = 1, .height = 1 };
        try testing.expect(!platform.mediaVideoSize(decoder, 0, &size));
        try testing.expect(!platform.mediaVideoSize(decoder, 0.25, &size));
    }
}

test "WebM, Ogg and MP3 bytes are unsupported, and stay so" {
    // Every default platform decodes media: a binding without it fails here,
    // never skips.
    if (comptime platform.capabilities.media_decoding == .unsupported) return error.MediaDecodingUnsupported;
    const browser = try platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    for ([_][]const u8{ "\x1a\x45\xdf\xa3\x84\x42\x82\x84webm", "OggS\x00\x02 an ogg file", "ID3\x04\x00\x00\x00\x00\x00\x00 an mp3" }) |bytes| {
        const decoder = try platform.openMediaDecoder(browser, .from("video/webm"));
        defer platform.closeMediaDecoder(decoder);
        var metadata: platform.MediaMetadata = .{};
        try testing.expectEqual(platform.MediaResult.unsupported, platform.pushMediaData(decoder, .from(bytes), false, &metadata));
        const after = wav(8);
        try testing.expectEqual(platform.MediaResult.unsupported, platform.pushMediaData(decoder, .from(&after), true, &metadata));
    }
}

test "a truncated WAV header is a decode error at the end of the stream" {
    // Every default platform decodes media: a binding without it fails here,
    // never skips.
    if (comptime platform.capabilities.media_decoding == .unsupported) return error.MediaDecodingUnsupported;
    const browser = try platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    const decoder = try platform.openMediaDecoder(browser, .from("audio/wav"));
    defer platform.closeMediaDecoder(decoder);
    var metadata: platform.MediaMetadata = .{};
    const file = wav(8);
    try testing.expectEqual(platform.MediaResult.need_more, platform.pushMediaData(decoder, .from(file[0..30]), false, &metadata));
    try testing.expectEqual(platform.MediaResult.decode_error, platform.pushMediaData(decoder, .from(""), true, &metadata));
}
