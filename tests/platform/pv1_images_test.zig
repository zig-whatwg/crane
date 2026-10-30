const std = @import("std");
const platform = @import("platform");

/// `s` repeated `n` times: what `s ** n` was (Zig 0.17 removes `**`; roadmap zig-017).
fn repeat(comptime s: []const u8, comptime n: usize) *const [s.len * n:0]u8 {
    return comptime blk: {
        @setEvalBranchQuota(10 * n + 1000);
        var out: [s.len * n:0]u8 = undefined;
        for (0..n) |i| @memcpy(out[i * s.len ..][0..s.len], s);
        const final = out;
        break :blk &final;
    };
}
const testing = std.testing;
const limits: platform.ImageLimits = .{ .max_dimension = 4096, .max_pixels = 4096 * 4096 };
const jpeg_path = "tests/wpt/html/semantics/embedded-content/the-img-element/3.jpg";
const rectangle = "<svg xmlns='http://www.w3.org/2000/svg' width='2' height='2'><rect width='2' height='2' fill='#ff0000'/></svg>";

fn decode(allocator: std.mem.Allocator, mime: []const u8, bytes: []const u8) !platform.DecodedImage {
    return platform.decodeImage(allocator, .from(mime), .from(bytes), limits);
}

test "vendored JPEG decodes real WPT pixels and enforces limits before allocation" {
    if (platform.capabilities.image_decoding == .unsupported) return error.SkipZigTest;
    const data = try std.Io.Dir.cwd().readFileAlloc(testing.io, jpeg_path, testing.allocator, .limited(1 << 20));
    defer testing.allocator.free(data);
    const image = try decode(testing.allocator, "image/jpeg", data);
    defer testing.allocator.free(image.pixels.slice());
    try testing.expectEqual(@as(u32, 650), image.width);
    try testing.expectEqual(@as(u32, 470), image.height);
    try testing.expectEqual(platform.ImageDecodeStatus.complete, image.status);
    try testing.expect(!image.empty);
    for (0..@as(usize, image.width) * image.height) |i| try testing.expectEqual(@as(u8, 255), image.pixels.slice()[i * 4 + 3]);
    var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
    try testing.expectError(error.TooLarge, platform.decodeImage(failing.allocator(), .from("image/jpeg"), .from(data), .{ .max_dimension = 649, .max_pixels = 4096 * 4096 }));
    try testing.expectError(error.OutOfMemory, decode(failing.allocator(), "image/jpeg", data));
}

test "JPEG incomplete entropy retains complete rows and marks the rest transparent" {
    if (platform.capabilities.image_decoding == .unsupported) return error.SkipZigTest;
    const data = try std.Io.Dir.cwd().readFileAlloc(testing.io, jpeg_path, testing.allocator, .limited(1 << 20));
    defer testing.allocator.free(data);
    try testing.expectError(error.Corrupt, decode(testing.allocator, "image/jpeg", data[0..8]));
    for ([_]usize{ data.len / 2, data.len - 2 }) |end| {
        const image = try decode(testing.allocator, "image/jpeg", data[0..end]);
        defer testing.allocator.free(image.pixels.slice());
        try testing.expect(image.status != .complete);
        try testing.expectEqual(@as(u32, 650), image.width);
        for (0..@as(usize, image.width) * image.height) |i| {
            const pixel = image.pixels.slice()[i * 4 ..][0..4];
            if (pixel[3] != 0) try testing.expectEqual(@as(u8, 255), pixel[3]) else try testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0 }, pixel);
        }
    }
}

test "SVG rasterizes straight RGBA pixels from XML" {
    if (platform.capabilities.image_decoding == .unsupported) return error.SkipZigTest;
    const image = try decode(testing.allocator, " IMAGE/SVG+XML; charset=utf-8 ", rectangle);
    defer testing.allocator.free(image.pixels.slice());
    try testing.expectEqual(@as(u32, 2), image.width);
    try testing.expectEqual(@as(u32, 2), image.height);
    try testing.expectEqual(platform.ImageDecodeStatus.complete, image.status);
    try testing.expectEqualSlices(u8, repeat(&.{ 255, 0, 0, 255 }, 4), image.pixels.slice());
}

test "JPEG natural dimensions honor EXIF orientation" {
    if (platform.capabilities.image_decoding == .unsupported) return error.SkipZigTest;
    const data = try std.Io.Dir.cwd().readFileAlloc(testing.io, "tests/wpt/images/arrow-oriented-upright.jpg", testing.allocator, .limited(1 << 20));
    defer testing.allocator.free(data);
    const image = try decode(testing.allocator, "image/jpeg", data);
    defer testing.allocator.free(image.pixels.slice());
    try testing.expectEqual(@as(u32, 144), image.width);
    try testing.expectEqual(@as(u32, 240), image.height);
    try testing.expectEqual(platform.ImageDecodeStatus.complete, image.status);
}

test "SVG uses XML namespaces and rejects malformed documents" {
    if (platform.capabilities.image_decoding == .unsupported) return error.SkipZigTest;
    for ([_][]const u8{
        "<svg width='2' height='2'/>",
        "<svg xmlns='http://www.w3.org/2000/svg'><rect></svg>",
        "<html xmlns='http://www.w3.org/1999/xhtml'/>",
        "<svg xmlns='http://www.w3.org/2000/svg' width='2' height='2'/><extra/>",
    }) |invalid| try testing.expectError(error.Corrupt, decode(testing.allocator, "image/svg+xml", invalid));
    const image = try decode(testing.allocator, "image/svg+xml", "<s:svg xmlns:s='http://www.w3.org/2000/svg' width='2' height='2'><s:rect width='2' height='2' fill='&#35;ff0000'/></s:svg>");
    defer testing.allocator.free(image.pixels.slice());
    try testing.expectEqualSlices(u8, repeat(&.{ 255, 0, 0, 255 }, 4), image.pixels.slice());
}

test "SVG default sizing, viewBox ratio, zero size, and limits" {
    if (platform.capabilities.image_decoding == .unsupported) return error.SkipZigTest;
    const cases = .{
        .{ "", 300, 150 },
        .{ "viewBox='0 0 10 10'", 150, 150 },
        .{ "width='20' viewBox='0 0 10 5'", 20, 10 },
        .{ "width='0' height='10'", 0, 10 },
    };
    inline for (cases) |case| {
        const image = try decode(testing.allocator, "image/svg+xml", "<svg xmlns='http://www.w3.org/2000/svg' " ++ case[0] ++ "/>");
        defer testing.allocator.free(image.pixels.slice());
        try testing.expectEqual(@as(u32, case[1]), image.width);
        try testing.expectEqual(@as(u32, case[2]), image.height);
    }
    var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
    try testing.expectError(error.TooLarge, platform.decodeImage(failing.allocator(), .from("image/svg+xml"), .from(rectangle), .{ .max_dimension = 1, .max_pixels = 100 }));
    try testing.expectError(error.OutOfMemory, decode(failing.allocator(), "image/svg+xml", rectangle));
}

test "SVG resolves namespaced gradient references through XML" {
    if (platform.capabilities.image_decoding == .unsupported) return error.SkipZigTest;
    const image = try decode(testing.allocator, "image/svg+xml", "<svg xmlns='http://www.w3.org/2000/svg' xmlns:x='http://www.w3.org/1999/xlink' width='2' height='2'>" ++
        "<defs><linearGradient id='a'><stop offset='0' stop-color='red'/><stop offset='1' stop-color='red'/></linearGradient>" ++
        "<linearGradient id='b' x:href='#a'/></defs><rect width='2' height='2' fill='url(#b)'/></svg>");
    defer testing.allocator.free(image.pixels.slice());
    try testing.expectEqualSlices(u8, repeat(&.{ 255, 0, 0, 255 }, 4), image.pixels.slice());
}

test "SVG unrepresentable raster coordinates preserve dimensions without crashing" {
    if (platform.capabilities.image_decoding == .unsupported) return error.SkipZigTest;
    const image = try decode(testing.allocator, "image/svg+xml", "<svg xmlns='http://www.w3.org/2000/svg' width='2' height='2'><path d='M0 0 L1e30 1 L0 2Z'/></svg>");
    defer testing.allocator.free(image.pixels.slice());
    try testing.expectEqual(@as(u32, 2), image.width);
    try testing.expectEqual(@as(u32, 2), image.height);
    try testing.expectEqual(platform.ImageDecodeStatus.corrupt, image.status);
    try testing.expect(image.empty);
    try testing.expectEqualSlices(u8, &(@as([16]u8, @splat(0))), image.pixels.slice());
}
