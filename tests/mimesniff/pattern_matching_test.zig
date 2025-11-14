//! Tests migrated from src/mimesniff/pattern_matching.zig
//! Per WHATWG specifications

const std = @import("std");

const mimesniff = @import("mimesniff");
const source = @import("../../src/mimesniff/pattern_matching.zig");

test "matchImageTypePattern - PNG" {
    const png_signature = [_]u8{ 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };
    const result = matchImageTypePattern(&png_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "image", "png");
}
test "matchImageTypePattern - JPEG" {
    const jpeg_signature = [_]u8{ 0xFF, 0xD8, 0xFF, 0xE0 };
    const result = matchImageTypePattern(&jpeg_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "image", "jpeg");
}
test "matchImageTypePattern - GIF87a" {
    const gif_signature = "GIF87a";
    const result = matchImageTypePattern(gif_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "image", "gif");
}
test "matchImageTypePattern - GIF89a" {
    const gif_signature = "GIF89a";
    const result = matchImageTypePattern(gif_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "image", "gif");
}
test "matchImageTypePattern - WebP" {
    const webp_signature = "RIFF\x00\x00\x00\x00WEBPVP";
    const result = matchImageTypePattern(webp_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "image", "webp");
}
test "matchImageTypePattern - no match" {
    const random_data = "Not an image!";
    const result = matchImageTypePattern(random_data);
    try std.testing.expect(result == null);
}
test "matchFontTypePattern - WOFF" {
    const woff_signature = "wOFF";
    const result = matchFontTypePattern(woff_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "font", "woff");
}
test "matchFontTypePattern - WOFF2" {
    const woff2_signature = "wOF2";
    const result = matchFontTypePattern(woff2_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "font", "woff2");
}
test "matchArchiveTypePattern - GZIP" {
    const gzip_signature = [_]u8{ 0x1F, 0x8B, 0x08 };
    const result = matchArchiveTypePattern(&gzip_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "application", "x-gzip");
}
test "matchArchiveTypePattern - ZIP" {
    const zip_signature = "PK\x03\x04";
    const result = matchArchiveTypePattern(zip_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "application", "zip");
}
test "patternMatchingSIMD - long pattern" {
    const input = "0123456789ABCDEF_Hello_World_Test";
    const pattern = "0123456789ABCDEF";
    const mask = &[_]u8{0xFF} ** 16;
    const ignored = &[_]u8{};

    try std.testing.expect(patternMatchingSIMD(input, pattern, mask, ignored));
}
test "matchesMp4Signature - valid ftyp box" {
    const mp4_signature = [_]u8{
        0x00, 0x00, 0x00, 0x18, // box size = 24 bytes
        'f', 't', 'y', 'p', // box type = ftyp
        'm', 'p', '4', '2', // brand = mp42
        0x00, 0x00, 0x00, 0x00, // version
        'm', 'p', '4', '1', // compatible brand
        'm', 'p', '4', '2', // compatible brand
    };
    try std.testing.expect(matchesMp4Signature(&mp4_signature));
}
test "matchesMp4Signature - iso5 brand with mp4 in compatible brands" {
    const mp4_signature = [_]u8{
        0x00, 0x00, 0x00, 0x14, // box size = 20 bytes
        'f', 't', 'y', 'p', // box type = ftyp
        'i', 's', 'o', '5', // brand = iso5
        0x00, 0x00, 0x00, 0x00, // version
        'm', 'p', '4', '2', // compatible brand starting with "mp4"
    };
    try std.testing.expect(matchesMp4Signature(&mp4_signature));
}
test "matchesMp4Signature - invalid box type" {
    const not_ftyp = [_]u8{
        0x00, 0x00, 0x00, 0x18,
        'w',  'r',  'o',  'n', // wrong box type
        'm',  'p',  '4',  '2',
        0x00, 0x00, 0x00, 0x00,
    };
    try std.testing.expect(!matchesMp4Signature(&not_ftyp));
}
test "matchesWebmSignature - valid EBML with DocType webm" {
    const webm_signature = [_]u8{
        0x1A, 0x45, 0xDF, 0xA3, // EBML header (bytes 0-3)
        0x42, 0x82, // DocType element ID (bytes 4-5)
        0x84, // vint length = 4 (byte 6, high bit set, so size=1)
        'w', 'e', 'b', 'm', // DocType = "webm" (bytes 7-10)
        0x00, // extra byte to satisfy "length greater than end" requirement
    };
    try std.testing.expect(matchesWebmSignature(&webm_signature));
}
test "matchesWebmSignature - matroska does not match" {
    // WebM signature only matches "webm" DocType, not "matroska"
    const matroska_signature = [_]u8{
        0x1A, 0x45, 0xDF, 0xA3, // EBML header
        0x42, 0x82, // DocType element ID
        0x88, // vint length = 8
        'm',  'a', 't', 'r', 'o', 's', 'k', 'a', // DocType = "matroska"
        0x00,
    };
    try std.testing.expect(!matchesWebmSignature(&matroska_signature));
}
test "matchesWebmSignature - invalid DocType" {
    const invalid_signature = [_]u8{
        0x1A, 0x45, 0xDF, 0xA3,
        0x42, 0x82, 0x84,
        'f',  'a', 'k', 'e', // wrong DocType
        0x00,
    };
    try std.testing.expect(!matchesWebmSignature(&invalid_signature));
}
test "matchesMp3Signature - valid MP3 with ID3" {
    // Note: This test is for MP3 WITHOUT ID3, so ID3 signatures should fail
    // The function name is misleading - it only matches raw MP3 frames
    const mp3_with_id3 = [_]u8{
        'I',  'D',  '3', // ID3 tag - this will cause matchMp3Header to fail
        0x03, 0x00, 0x00,
        0x00, 0x00, 0x00,
        0x10,
    };
    try std.testing.expect(!matchesMp3Signature(&mp3_with_id3));
}
test "matchesMp3Signature - valid MP3 without ID3" {
    const allocator = std.testing.allocator;

    // Create valid MP3 frame data
    // Header: 0xFF 0xFB
    //   Byte 1: 0xFB = 0b11111011
    //   - Sync (11 bits): 0xFFE (all 1s)
    //   - Version: (0xFB & 0x18) >> 3 = 0x18 >> 3 = 3
    //   - Layer: (0xFB & 0x06) >> 1 = 0x02 >> 1 = 1 (Layer III)
    //   - CRC: 1 (no CRC)
    // Byte 2: 0x90
    //   - Bitrate index: (0x90 & 0xF0) >> 4 = 9
    //   - Sample rate index: (0x90 & 0x0C) >> 2 = 0
    //   - Padding: 0
    // Byte 3: 0x00
    //   - Mode, etc.
    //
    // Frame size calculation (per spec algorithm):
    //   version = 3, version & 0x01 = 1, so use MP2_5_RATES
    //   bitrate = MP2_5_RATES[9] = 80000
    //   samplerate = SAMPLE_RATES[0] = 44100
    //   scale = (version == 1) ? 72 : 144 = 144
    //   frame_size = 80000 * 144 / 44100 = 261 bytes

    var mp3_data = infra.List(u8).init(allocator);
    try mp3_data.ensureCapacity(530);
    defer mp3_data.deinit();

    // First MP3 frame: 261 bytes
    try mp3_data.appendSlice(&[_]u8{ 0xFF, 0xFB, 0x90, 0x00 });
    try mp3_data.appendSlice(&([_]u8{0x00} ** 257)); // 4 + 257 = 261

    // Second MP3 frame: 261 bytes
    try mp3_data.appendSlice(&[_]u8{ 0xFF, 0xFB, 0x90, 0x00 });
    try mp3_data.appendSlice(&([_]u8{0x00} ** 257)); // 4 + 257 = 261

    try std.testing.expect(matchesMp3Signature(mp3_data.items()));
}
test "matchesMp3Signature - invalid MP3 header (bad bitrate)" {
    const invalid_mp3 = [_]u8{
        0xFF, 0xFB,
        0xF0, 0x00, // bitrate = 15 (invalid)
    };
    try std.testing.expect(!matchesMp3Signature(&invalid_mp3));
}
test "matchesMp3Signature - invalid MP3 header (bad sample rate)" {
    const invalid_mp3 = [_]u8{
        0xFF, 0xFB,
        0x9C, 0x00, // sample rate = 3 (invalid)
    };
    try std.testing.expect(!matchesMp3Signature(&invalid_mp3));
}
test "matchesMp3Signature - invalid MP3 header (layer 0)" {
    const invalid_mp3 = [_]u8{
        0xFF, 0xF9, // layer = 0 (invalid)
        0x90, 0x00,
    };
    try std.testing.expect(!matchesMp3Signature(&invalid_mp3));
}
test "matchesMp3Signature - too short" {
    const short_mp3 = [_]u8{ 0xFF, 0xFB };
    try std.testing.expect(!matchesMp3Signature(&short_mp3));
}