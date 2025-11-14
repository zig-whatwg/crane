//! Tests migrated from src/mimesniff/pattern_matching.zig
//! Per WHATWG specifications

const std = @import("std");

const mimesniff = @import("mimesniff");

const infra = @import("infra");

fn expectEssence(mime_type: MimeType, expected_type: []const u8, expected_subtype: []const u8) !void {
    try std.testing.expectEqualStrings(expected_type, mime_type.type_str);
    try std.testing.expectEqualStrings(expected_subtype, mime_type.subtype);
}


test "matchImageTypePattern - PNG" {
    const png_signature = [_]u8{ 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };
    const result = mimesniff.matchImageTypePattern(&png_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "image", "png");
}
test "matchImageTypePattern - JPEG" {
    const jpeg_signature = [_]u8{ 0xFF, 0xD8, 0xFF, 0xE0 };
    const result = mimesniff.matchImageTypePattern(&jpeg_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "image", "jpeg");
}
test "matchImageTypePattern - GIF87a" {
    const gif_signature = "GIF87a";
    const result = mimesniff.matchImageTypePattern(gif_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "image", "gif");
}
test "matchImageTypePattern - GIF89a" {
    const gif_signature = "GIF89a";
    const result = mimesniff.matchImageTypePattern(gif_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "image", "gif");
}
test "matchImageTypePattern - WebP" {
    const webp_signature = "RIFF\x00\x00\x00\x00WEBPVP";
    const result = mimesniff.matchImageTypePattern(webp_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "image", "webp");
}
test "matchImageTypePattern - no match" {
    const random_data = "Not an image!";
    const result = mimesniff.matchImageTypePattern(random_data);
    try std.testing.expect(result == null);
}
test "matchFontTypePattern - WOFF" {
    const woff_signature = "wOFF";
    const result = mimesniff.matchFontTypePattern(woff_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "font", "woff");
}
test "matchFontTypePattern - WOFF2" {
    const woff2_signature = "wOF2";
    const result = mimesniff.matchFontTypePattern(woff2_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "font", "woff2");
}
test "matchArchiveTypePattern - GZIP" {
    const gzip_signature = [_]u8{ 0x1F, 0x8B, 0x08 };
    const result = mimesniff.matchArchiveTypePattern(&gzip_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "application", "x-gzip");
}
test "matchArchiveTypePattern - ZIP" {
    const zip_signature = "PK\x03\x04";
    const result = mimesniff.matchArchiveTypePattern(zip_signature);
    try std.testing.expect(result != null);
    try expectEssence(result.?, "application", "zip");
}
test "patternMatchingSIMD - long pattern" {
    const input = "0123456789ABCDEF_Hello_World_Test";
    const pattern = "0123456789ABCDEF";
    const mask = &[_]u8{0xFF} ** 16;
    const ignored = &[_]u8{};

    try std.testing.expect(mimesniff.patternMatchingSIMD(input, pattern, mask, ignored));
}