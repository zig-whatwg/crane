//! Audio/video signature tests use the same byte vectors as upstream WPT.
const std = @import("std");
const mime = @import("mimesniff");

fn expectType(bytes: []const u8, expected: ?[]const u8) !void {
    var result = mime.pattern_matching.matchAudioOrVideoTypePattern(bytes) orelse {
        try std.testing.expect(expected == null);
        return;
    };
    defer result.deinit();
    const serialized = try mime.serializeMimeTypeToBytes(std.testing.allocator, result);
    defer std.testing.allocator.free(serialized);
    try std.testing.expectEqualStrings(expected orelse return error.UnexpectedMimeType, serialized);
}

test "audio/video MIME signatures recognize upstream WPT media vectors" {
    const cases = .{
        .{ "mp3-raw.mp3", "audio/mpeg" },
        .{ "mp3-with-id3.mp3", "audio/mpeg" },
        .{ "ogg.ogg", "application/ogg" },
        .{ "mp4.mp4", "video/mp4" },
        .{ "wav.wav", "audio/wave" },
        .{ "webm.webm", "video/webm" },
    };
    inline for (cases) |case| {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "tests/wpt/mimesniff/media/resources/" ++ case[0], std.testing.allocator, .limited(1 << 20));
        defer std.testing.allocator.free(bytes);
        try expectType(bytes, case[1]);
    }
}

fn twoFrames(version: u8, size: usize, padding: bool) !void {
    const allocator = std.testing.allocator;
    const bytes = try allocator.alloc(u8, size + 5);
    defer allocator.free(bytes);
    @memset(bytes, 0);
    const header = [4]u8{ 0xff, 0xe3 | (version << 3), 0x50 | @as(u8, if (padding) 2 else 0), 0 };
    @memcpy(bytes[0..4], &header);
    @memcpy(bytes[size..][0..4], &header);
    try expectType(bytes, "audio/mpeg");
    for (0..5) |remaining| try expectType(bytes[0 .. size + remaining], null);
}

test "MP3 signature uses MPEG1, MPEG2 and MPEG2.5 frame lengths" {
    try twoFrames(3, 208, false); // 64 kbit/s, 44.1 kHz, scale144.
    try twoFrames(3, 209, true);
    try twoFrames(1, 208, false); // Gecko accepts the reserved version as MPEG1.
    try twoFrames(2, 130, false); // 40 kbit/s, 22.05 kHz, scale72.
    try twoFrames(0, 261, false); // 40 kbit/s, 11.025 kHz, scale72.
}

test "MP3 signature rejects reserved fields and non-LayerIII headers" {
    var bytes = [_]u8{0} ** 1445;
    for ([_][4]u8{
        .{ 0xff, 0xfd, 0x50, 0 }, // LayerII
        .{ 0xff, 0xff, 0x50, 0 }, // LayerI
        .{ 0xff, 0xf9, 0x50, 0 }, // reserved layer
        .{ 0xff, 0xfb, 0xf0, 0 }, // reserved bitrate
        .{ 0xff, 0xfb, 0x5c, 0 }, // reserved sample rate
        .{ 0xfe, 0xfb, 0x50, 0 }, // broken sync
    }) |header| {
        @memset(&bytes, 0);
        @memcpy(bytes[0..4], &header);
        @memcpy(bytes[130..][0..4], &header);
        @memcpy(bytes[208..][0..4], &header);
        try expectType(&bytes, null);
    }
}

test "MP4 signature checks the declared box and skips the version field" {
    try expectType("\x00\x00\x00\x14ftypisom\x00\x00\x00\x00mp42", "video/mp4");
    try expectType("\x00\x00\x00\x14ftypisommp42xxxx", null);
    try expectType("\x00\x00\x00\x18ftypisom\x00\x00\x00\x00mp42", null);
    try expectType("\x00\x00\x00\x15ftypmp42\x00\x00\x00\x00xxxxx", null);
}

test "WebM signature rejects truncated EBML and DocType fields" {
    const bytes = "\x1a\x45\xdf\xa3\x9f\x42\x86\x81\x01\x42\xf7\x81\x01\x42\xf2\x81\x04\x42\xf3\x81\x08\x42\x82\x84webm\x42\x87\x81\x04";
    try expectType(bytes, "video/webm");
    for (0..29) |length| try expectType(bytes[0..length], null);
}
