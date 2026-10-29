//! A platform must advertise exactly the image formats its decoder accepts.
const std = @import("std");
const platform = @import("platform");

test "image MIME support rejects an unlisted type" {
    if (platform.capabilities.image_decoding == .unsupported) return error.SkipZigTest;
    try std.testing.expect(!platform.imageMimeTypeSupported(.from("image/x-unknown")));
    try std.testing.expect(!platform.imageMimeTypeSupported(.from("text/plain")));
}

test "every advertised testing image MIME type has a working decoder" {
    if (platform.capabilities.image_decoding == .unsupported) return error.SkipZigTest;
    const Case = struct { essence: []const u8, path: []const u8 };
    const cases = [_]Case{
        .{ .essence = "image/png", .path = "tests/wpt/images/green.png" },
        .{ .essence = "image/apng", .path = "tests/wpt/images/apng.png" },
        .{ .essence = "image/bmp", .path = "tests/platform/fixtures/image-py-28.bmp" },
        .{ .essence = "image/x-bmp", .path = "tests/platform/fixtures/image-py-28.bmp" },
        .{ .essence = "image/x-ms-bmp", .path = "tests/platform/fixtures/image-py-28.bmp" },
        .{ .essence = "image/gif", .path = "tests/wpt/images/anim-gr.gif" },
        .{ .essence = "image/jpeg", .path = "tests/wpt/html/semantics/embedded-content/the-img-element/3.jpg" },
    };
    for (cases) |case| {
        try std.testing.expect(platform.imageMimeTypeSupported(.from(case.essence)));
        const bytes = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, case.path, std.testing.allocator, .limited(1 << 22));
        defer std.testing.allocator.free(bytes);
        try decode(case.essence, bytes);
    }
    try std.testing.expect(platform.imageMimeTypeSupported(.from("image/svg+xml")));
    try decode("image/svg+xml", "<svg xmlns='http://www.w3.org/2000/svg' width='2' height='2'><rect width='2' height='2'/></svg>");
}

fn decode(essence: []const u8, bytes: []const u8) !void {
    const image = try platform.decodeImage(std.testing.allocator, .from(essence), .from(bytes), .{ .max_dimension = 4096, .max_pixels = 4096 * 4096 });
    defer std.testing.allocator.free(image.pixels.slice());
    try std.testing.expect(image.width > 0 and image.height > 0);
    try std.testing.expect(!image.empty);
}
