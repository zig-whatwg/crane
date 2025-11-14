//! Tests migrated from src/mimesniff/mime_type.zig
//! Per WHATWG specifications

const std = @import("std");
const infra = @import("infra");
const mimesniff = @import("mimesniff");

test "parseMimeType - simple type" {
    const allocator = std.testing.allocator;

    var mime = (try mimesniff.parseMimeType(allocator, "text/html")) orelse return error.ParseFailed;
    defer mime.deinit();

    // Type should be "text"
    const expected_type = try infra.bytes.isomorphicDecode(allocator, "text");
    defer allocator.free(expected_type);
    try std.testing.expect(std.mem.eql(u16, mime.type, expected_type));

    // Subtype should be "html"
    const expected_subtype = try infra.bytes.isomorphicDecode(allocator, "html");
    defer allocator.free(expected_subtype);
    try std.testing.expect(std.mem.eql(u16, mime.subtype, expected_subtype));

    // No parameters
    try std.testing.expectEqual(@as(usize, 0), mime.parameters.size());
}
test "parseMimeType - with parameter" {
    const allocator = std.testing.allocator;

    var mime = (try mimesniff.parseMimeType(allocator, "text/html; charset=utf-8")) orelse return error.ParseFailed;
    defer mime.deinit();

    // Check parameter count
    try std.testing.expectEqual(@as(usize, 1), mime.parameters.size());

    // Find parameter by iterating (workaround for OrderedMap.get not working with slices)
    const entries = mime.parameters.entries.items();
    var found_charset = false;
    for (entries) |entry| {
        const key_bytes = try infra.bytes.isomorphicEncode(allocator, entry.key);
        defer allocator.free(key_bytes);

        if (std.mem.eql(u8, key_bytes, "charset")) {
            found_charset = true;

            const value_bytes = try infra.bytes.isomorphicEncode(allocator, entry.value);
            defer allocator.free(value_bytes);

            try std.testing.expect(std.mem.eql(u8, value_bytes, "utf-8"));
        }
    }

    try std.testing.expect(found_charset);
}
test "parseMimeType - invalid: no slash" {
    const allocator = std.testing.allocator;
    const result = try mimesniff.parseMimeType(allocator, "texthtml");
    try std.testing.expect(result == null);
}
test "parseMimeType - invalid: empty type" {
    const allocator = std.testing.allocator;
    const result = try mimesniff.parseMimeType(allocator, "/html");
    try std.testing.expect(result == null);
}
test "parseMimeType - invalid: empty subtype" {
    const allocator = std.testing.allocator;
    const result = try mimesniff.parseMimeType(allocator, "text/");
    try std.testing.expect(result == null);
}
test "serializeMimeType - simple type" {
    const allocator = std.testing.allocator;

    var mime = (try mimesniff.parseMimeType(allocator, "text/html")) orelse return error.ParseFailed;
    defer mime.deinit();

    const serialized = try mimesniff.serializeMimeType(allocator, mime);
    defer allocator.free(serialized);

    const expected = try infra.bytes.isomorphicDecode(allocator, "text/html");
    defer allocator.free(expected);

    try std.testing.expect(std.mem.eql(u16, serialized, expected));
}
test "serializeMimeType - with parameter" {
    const allocator = std.testing.allocator;

    var mime = (try mimesniff.parseMimeType(allocator, "text/html; charset=utf-8")) orelse return error.ParseFailed;
    defer mime.deinit();

    const serialized = try mimesniff.serializeMimeType(allocator, mime);
    defer allocator.free(serialized);

    const expected = try infra.bytes.isomorphicDecode(allocator, "text/html;charset=utf-8");
    defer allocator.free(expected);

    try std.testing.expect(std.mem.eql(u16, serialized, expected));
}
test "minimizeSupportedMimeType - JavaScript" {
    const allocator = std.testing.allocator;

    var mime = (try mimesniff.parseMimeType(allocator, "text/javascript")) orelse return error.ParseFailed;
    defer mime.deinit();

    const minimized = try mimesniff.minimizeSupportedMimeType(allocator, &mime);
    defer allocator.free(minimized);

    try std.testing.expectEqualStrings("text/javascript", minimized);
}
test "minimizeSupportedMimeType - JavaScript variant" {
    const allocator = std.testing.allocator;

    var mime = (try mimesniff.parseMimeType(allocator, "application/x-javascript")) orelse return error.ParseFailed;
    defer mime.deinit();

    const minimized = try mimesniff.minimizeSupportedMimeType(allocator, &mime);
    defer allocator.free(minimized);

    try std.testing.expectEqualStrings("text/javascript", minimized);
}
test "minimizeSupportedMimeType - JSON" {
    const allocator = std.testing.allocator;

    var mime = (try mimesniff.parseMimeType(allocator, "application/json")) orelse return error.ParseFailed;
    defer mime.deinit();

    const minimized = try mimesniff.minimizeSupportedMimeType(allocator, &mime);
    defer allocator.free(minimized);

    try std.testing.expectEqualStrings("application/json", minimized);
}
test "minimizeSupportedMimeType - JSON with +json" {
    const allocator = std.testing.allocator;

    var mime = (try mimesniff.parseMimeType(allocator, "application/manifest+json")) orelse return error.ParseFailed;
    defer mime.deinit();

    const minimized = try mimesniff.minimizeSupportedMimeType(allocator, &mime);
    defer allocator.free(minimized);

    try std.testing.expectEqualStrings("application/json", minimized);
}
test "minimizeSupportedMimeType - SVG" {
    const allocator = std.testing.allocator;

    var mime = (try mimesniff.parseMimeType(allocator, "image/svg+xml")) orelse return error.ParseFailed;
    defer mime.deinit();

    const minimized = try mimesniff.minimizeSupportedMimeType(allocator, &mime);
    defer allocator.free(minimized);

    try std.testing.expectEqualStrings("image/svg+xml", minimized);
}
test "minimizeSupportedMimeType - XML" {
    const allocator = std.testing.allocator;

    var mime = (try mimesniff.parseMimeType(allocator, "application/xml")) orelse return error.ParseFailed;
    defer mime.deinit();

    const minimized = try mimesniff.minimizeSupportedMimeType(allocator, &mime);
    defer allocator.free(minimized);

    try std.testing.expectEqualStrings("application/xml", minimized);
}
test "minimizeSupportedMimeType - XML with +xml" {
    const allocator = std.testing.allocator;

    var mime = (try mimesniff.parseMimeType(allocator, "application/rss+xml")) orelse return error.ParseFailed;
    defer mime.deinit();

    const minimized = try mimesniff.minimizeSupportedMimeType(allocator, &mime);
    defer allocator.free(minimized);

    try std.testing.expectEqualStrings("application/xml", minimized);
}
test "minimizeSupportedMimeType - other types return essence" {
    const allocator = std.testing.allocator;

    var mime = (try mimesniff.parseMimeType(allocator, "image/png")) orelse return error.ParseFailed;
    defer mime.deinit();

    const minimized = try mimesniff.minimizeSupportedMimeType(allocator, &mime);
    defer allocator.free(minimized);

    try std.testing.expectEqualStrings("image/png", minimized);
}
test "isValidMimeTypeString - valid simple" {
    try std.testing.expect(mimesniff.isValidMimeTypeString("text/html"));
}
test "isValidMimeTypeString - valid with parameters" {
    try std.testing.expect(mimesniff.isValidMimeTypeString("text/html; charset=utf-8"));
}
test "isValidMimeTypeString - valid complex" {
    try std.testing.expect(mimesniff.isValidMimeTypeString("application/json; charset=utf-8; boundary=something"));
}
test "isValidMimeTypeString - invalid no slash" {
    try std.testing.expect(!mimesniff.isValidMimeTypeString("texthtml"));
}
test "isValidMimeTypeString - invalid empty type" {
    try std.testing.expect(!mimesniff.isValidMimeTypeString("/html"));
}
test "isValidMimeTypeString - invalid empty subtype" {
    try std.testing.expect(!mimesniff.isValidMimeTypeString("text/"));
}
test "isValidMimeTypeWithNoParameters - valid" {
    try std.testing.expect(mimesniff.isValidMimeTypeWithNoParameters("text/html"));
    try std.testing.expect(mimesniff.isValidMimeTypeWithNoParameters("application/json"));
}
test "isValidMimeTypeWithNoParameters - invalid with parameters" {
    try std.testing.expect(!mimesniff.isValidMimeTypeWithNoParameters("text/html; charset=utf-8"));
}
test "isValidMimeTypeWithNoParameters - invalid no slash" {
    try std.testing.expect(!mimesniff.isValidMimeTypeWithNoParameters("texthtml"));
}
test "parseMimeType - custom type with + in subtype and multiple parameters" {
    const allocator = std.testing.allocator;

    // Test: text/swiftui+vml;target=ios;charset=UTF-8
    const input = "text/swiftui+vml;target=ios;charset=UTF-8";

    var mime = (try mimesniff.parseMimeType(allocator, input)) orelse return error.ParseFailed;
    defer mime.deinit();

    // Check type
    const type_utf8 = try infra.bytes.isomorphicEncode(allocator, mime.type);
    defer allocator.free(type_utf8);
    try std.testing.expectEqualStrings("text", type_utf8);

    // Check subtype (should include the +)
    const subtype_utf8 = try infra.bytes.isomorphicEncode(allocator, mime.subtype);
    defer allocator.free(subtype_utf8);
    try std.testing.expectEqualStrings("swiftui+vml", subtype_utf8);

    // Check parameter count
    try std.testing.expectEqual(@as(usize, 2), mime.parameters.size());

    // Check parameters
    const entries = mime.parameters.entries.items();

    // First parameter: target=ios
    const key1_utf8 = try infra.bytes.isomorphicEncode(allocator, entries[0].key);
    defer allocator.free(key1_utf8);
    const value1_utf8 = try infra.bytes.isomorphicEncode(allocator, entries[0].value);
    defer allocator.free(value1_utf8);
    try std.testing.expectEqualStrings("target", key1_utf8);
    try std.testing.expectEqualStrings("ios", value1_utf8);

    // Second parameter: charset=UTF-8 (should be lowercased to utf-8)
    const key2_utf8 = try infra.bytes.isomorphicEncode(allocator, entries[1].key);
    defer allocator.free(key2_utf8);
    const value2_utf8 = try infra.bytes.isomorphicEncode(allocator, entries[1].value);
    defer allocator.free(value2_utf8);
    try std.testing.expectEqualStrings("charset", key2_utf8);
    try std.testing.expectEqualStrings("UTF-8", value2_utf8); // Note: value is NOT lowercased

    // Serialize back
    const serialized = try mimesniff.serializeMimeTypeToBytes(allocator, mime);
    defer allocator.free(serialized);

    // Should be: text/swiftui+vml;target=ios;charset=UTF-8
    // Note: Parameter names are lowercased, but values preserve case
    try std.testing.expectEqualStrings("text/swiftui+vml;target=ios;charset=UTF-8", serialized);
}
