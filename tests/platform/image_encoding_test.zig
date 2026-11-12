//! Image encoding through the platform protocol (docs/platform-protocol.md,
//! `image_encoding`): `platform.encodeImage` turns straight-alpha RGBA8 into
//! one file - PNG, which HTML 4.12.5.5 requires, from kit/image_encoding on
//! every built-in platform. The files are read back with the bound
//! platform's own decoder (kit/image_decoding) and their chunks checked by
//! hand: signature, IHDR, sRGB, pHYs at 96 dpi, IDAT, IEND, each CRC.

const std = @import("std");
const platform = @import("platform");

const testing = std.testing;

const limits: platform.ImageLimits = .{ .max_dimension = 1 << 15, .max_pixels = 1 << 24 };

fn encode(allocator: std.mem.Allocator, width: u32, height: u32, pixels: []const u8) platform.ImageEncodeError![]const u8 {
    const file = try platform.encodeImage(allocator, platform.Str.from("image/png"), .{ .width = width, .height = height, .pixels = platform.Bytes.from(pixels) }, -1);
    return file.slice();
}

fn expectRoundTrip(width: u32, height: u32, pixels: []const u8) !void {
    const file = try encode(testing.allocator, width, height, pixels);
    defer testing.allocator.free(file);
    try expectChunks(file, width, height);
    const image = try platform.decodeImage(testing.allocator, platform.Str.from("image/png"), platform.Bytes.from(file), limits);
    defer testing.allocator.free(image.pixels.slice());
    try testing.expectEqual(width, image.width);
    try testing.expectEqual(height, image.height);
    try testing.expectEqual(platform.ImageDecodeStatus.complete, image.status);
    try testing.expectEqualSlices(u8, pixels, image.pixels.slice());
}

/// The datastream's chunks, in order, each with a correct CRC.
fn expectChunks(file: []const u8, width: u32, height: u32) !void {
    try testing.expect(std.mem.startsWith(u8, file, "\x89PNG\r\n\x1a\n"));
    var at: usize = 8;
    var kinds: [8][4]u8 = undefined;
    var count: usize = 0;
    while (at < file.len) {
        const length = std.mem.readInt(u32, file[at..][0..4], .big);
        const kind = file[at + 4 ..][0..4];
        const data = file[at + 8 ..][0..length];
        const crc = std.mem.readInt(u32, file[at + 8 + length ..][0..4], .big);
        var expected = std.hash.Crc32.init();
        expected.update(kind);
        expected.update(data);
        try testing.expectEqual(expected.final(), crc);
        if (std.mem.eql(u8, kind, "IHDR")) {
            try testing.expectEqual(width, std.mem.readInt(u32, data[0..4], .big));
            try testing.expectEqual(height, std.mem.readInt(u32, data[4..8], .big));
            try testing.expectEqualSlices(u8, &.{ 8, 6, 0, 0, 0 }, data[8..13]);
        }
        if (std.mem.eql(u8, kind, "pHYs")) {
            // HTML 4.12.5.5: 96 dpi, as pixels per metre.
            try testing.expectEqual(@as(u32, 3780), std.mem.readInt(u32, data[0..4], .big));
            try testing.expectEqual(@as(u32, 3780), std.mem.readInt(u32, data[4..8], .big));
            try testing.expectEqual(@as(u8, 1), data[8]);
        }
        if (count < kinds.len) kinds[count] = kind.*;
        count += 1;
        at += 12 + length;
    }
    try testing.expectEqual(file.len, at);
    try testing.expectEqual(@as(usize, 5), count);
    for ([_]*const [4]u8{ "IHDR", "sRGB", "pHYs", "IDAT", "IEND" }, 0..) |kind, i| {
        try testing.expectEqualSlices(u8, kind, &kinds[i]);
    }
}

test "image_encoding is native on the testing platform, PNG only" {
    try testing.expectEqual(platform.Support.native, platform.capabilities.image_encoding);
    try testing.expect(platform.imageEncodingMimeTypeSupported(platform.Str.from("image/png")));
    // Crane lowercases the type above the protocol: the query takes it as given.
    try testing.expect(!platform.imageEncodingMimeTypeSupported(platform.Str.from("IMAGE/PNG")));
    try testing.expect(!platform.imageEncodingMimeTypeSupported(platform.Str.from("image/jpeg")));
    try testing.expectError(error.UnsupportedFormat, platform.encodeImage(testing.allocator, platform.Str.from("image/webp"), .{ .width = 1, .height = 1, .pixels = platform.Bytes.from(&[_]u8{ 0, 0, 0, 0 }) }, 0.5));
}

test "a 1x1 image round-trips, transparent and opaque" {
    try expectRoundTrip(1, 1, &.{ 0, 0, 0, 0 });
    try expectRoundTrip(1, 1, &.{ 12, 34, 56, 255 });
    try expectRoundTrip(1, 1, &.{ 255, 255, 255, 1 });
}

test "odd widths and heights round-trip: every stride, every row filter" {
    var prng: std.Random.DefaultPrng = .init(0x5eed);
    const random = prng.random();
    for ([_][2]u32{ .{ 3, 1 }, .{ 1, 7 }, .{ 5, 3 }, .{ 7, 9 }, .{ 33, 17 }, .{ 300, 150 } }) |size| {
        const pixels = try testing.allocator.alloc(u8, @as(usize, size[0]) * size[1] * 4);
        defer testing.allocator.free(pixels);
        // Noise, a gradient and flat runs, so each filter type wins some row.
        for (pixels, 0..) |*byte, i| {
            const row = i / (@as(usize, size[0]) * 4);
            byte.* = switch (row % 3) {
                0 => random.int(u8),
                1 => @truncate(i),
                else => 0x80,
            };
        }
        try expectRoundTrip(size[0], size[1], pixels);
    }
}

test "a canvas's default bitmap - 300x150 transparent black - round-trips" {
    const pixels = try testing.allocator.alloc(u8, 300 * 150 * 4);
    defer testing.allocator.free(pixels);
    @memset(pixels, 0);
    try expectRoundTrip(300, 150, pixels);
    @memset(pixels, 0xff);
    try expectRoundTrip(300, 150, pixels);
}

test "a large image's file is smaller than its pixels: the stream is compressed" {
    const width = 512;
    const height = 256;
    const pixels = try testing.allocator.alloc(u8, width * height * 4);
    defer testing.allocator.free(pixels);
    for (0..height) |y| for (0..width) |x| {
        const p = pixels[(y * width + x) * 4 ..][0..4];
        p.* = .{ @truncate(x), @truncate(y), 0x40, 0xff };
    };
    const file = try encode(testing.allocator, width, height, pixels);
    defer testing.allocator.free(file);
    try testing.expect(file.len < pixels.len / 10);
    try expectRoundTrip(width, height, pixels);
}

test "dimensions PNG cannot hold are TooLarge, refused before anything is allocated" {
    // The failing allocator turns any allocation into OutOfMemory: TooLarge
    // shows the size was refused first.
    const none = testing.failing_allocator;
    try testing.expectError(error.TooLarge, encode(none, 1 << 31, 1, &.{}));
    try testing.expectError(error.TooLarge, encode(none, 1, 1 << 31, &.{}));
    // The largest dimensions PNG holds are not too large for the format:
    // pixels that cannot be theirs are refused, still before allocating.
    try testing.expectError(error.UnsupportedFormat, encode(none, (1 << 31) - 1, (1 << 31) - 1, &.{}));
    try testing.expectError(error.TooLarge, encode(none, 0, 1, &.{}));
    try testing.expectError(error.TooLarge, encode(none, 1, 0, &.{}));
    // Pixels of the wrong length are refused too, before any allocation.
    try testing.expectError(error.UnsupportedFormat, encode(none, 2, 2, &.{ 0, 0, 0, 0 }));
}

test "an allocation that fails mid-encode is OutOfMemory and leaks nothing" {
    const pixels: [64]u8 = @splat(0x7f);
    var fail_index: usize = 0;
    while (fail_index < 32) : (fail_index += 1) {
        var failing = std.testing.FailingAllocator.init(testing.allocator, .{ .fail_index = fail_index });
        const result = encode(failing.allocator(), 4, 4, &pixels);
        if (result) |file| {
            failing.allocator().free(file);
            break;
        } else |err| try testing.expectEqual(error.OutOfMemory, err);
    }
    try testing.expect(fail_index < 32);
}
