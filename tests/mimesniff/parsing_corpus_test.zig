//! MIME Sniffing parser/serializer regression coverage from upstream WPT.
const std = @import("std");
const mimesniff = @import("mimesniff");

fn roundTrip(allocator: std.mem.Allocator, input: []const u8, expected: ?[]const u8) !void {
    const wide = try std.unicode.utf8ToUtf16LeAlloc(allocator, input);
    defer allocator.free(wide);
    var record = (try mimesniff.parseMimeTypeFromString(allocator, allocator, wide)) orelse {
        try std.testing.expect(expected == null);
        return;
    };
    defer record.deinit();
    const result = try mimesniff.serializeMimeType(allocator, record);
    defer allocator.free(result);
    const utf8 = try std.unicode.utf16LeToUtf8Alloc(allocator, result);
    defer allocator.free(utf8);
    try std.testing.expectEqualStrings(expected orelse return error.UnexpectedMimeType, utf8);
}

fn corpus(path: []const u8) !void {
    const allocator = std.testing.allocator;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, allocator, .limited(2 << 20));
    defer allocator.free(bytes);
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, bytes, .{});
    defer parsed.deinit();
    for (parsed.value.array.items) |entry| {
        if (entry == .string) continue;
        const input = entry.object.get("input").?.string;
        const output = entry.object.get("output").?;
        try roundTrip(allocator, input, if (output == .null) null else output.string);
    }
}

test "MIME parser and serializer: WPT mime-types.json" {
    try corpus("tests/wpt/mimesniff/mime-types/resources/mime-types.json");
}

test "MIME parser and serializer: WPT generated-mime-types.json" {
    try corpus("tests/wpt/mimesniff/mime-types/resources/generated-mime-types.json");
}
