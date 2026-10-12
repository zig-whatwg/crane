//! BMP through the platform protocol (decision 19a): the testing platform
//! decodes image/bmp in Zig, as Blink's BMPImageReader reads it (the rules
//! are listed in src/platform/adapters/testing/bmp.zig).
//!
//! fixtures/image-py-{28,29}.bmp are WPT's own output: tests/wpt/common/
//! security-features/subresource/image.py's encode_string_as_bmp_image,
//! run on a request's headers - the images every security-features img-tag
//! test reads back through a canvas (28 x 28 has no row padding, 29 x 29
//! three bytes a row). The other bitmaps are built here, a few pixels each,
//! with their expected pixels worked out by hand from the format.
//!
//! The decoder was also checked, outside these tests, against Jason
//! Summers' BMP Suite (Chromium's copy, web_tests/images/bmp-suite): every
//! "good" file matches PIL 12.0 exactly except where PIL itself is wrong or
//! does not decode (RLE4 nibble order; 5- and 6-bit components, which PIL
//! widens by bit replication and Blink by rounding: round(v * 255 / 31)) and
//! the RLE "cut" and "trns" files match their plain siblings with exactly
//! the skipped pixels transparent.

const std = @import("std");
const platform = @import("platform");

const testing = std.testing;

const limits: platform.ImageLimits = .{ .max_dimension = 1 << 15, .max_pixels = 1 << 24 };

fn decode(bytes: []const u8) platform.ImageError!platform.DecodedImage {
    return platform.decodeImage(testing.allocator, platform.Str.from("image/bmp"), platform.Bytes.from(bytes), limits);
}

fn free(image: platform.DecodedImage) void {
    testing.allocator.free(image.pixels.slice());
}

fn expectPixels(bytes: []const u8, width: u32, height: u32, expected: []const [4]u8) !void {
    const image = try decode(bytes);
    defer free(image);
    try testing.expectEqual(width, image.width);
    try testing.expectEqual(height, image.height);
    try testing.expectEqualSlices(u8, std.mem.sliceAsBytes(expected), image.pixels.slice());
}

// ---------------------------------------------------------------------------
// image.py's bitmaps, read back as common.sub.js's decodeImageData does
// ---------------------------------------------------------------------------

const image_py = [_]struct { []const u8, u32, []const u8 }{
    .{ @embedFile("fixtures/image-py-28.bmp"), 28, "{\"headers\": {\"host\": \"web-platform.test:8000\", \"referer\": \"http://web-platform.test:8000/referrer-policy/gen/req.attr/same-origin/img-tag.http.html\", \"user-agent\": \"Crane\", \"accept\": \"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\"}}" },
    .{ @embedFile("fixtures/image-py-29.bmp"), 29, "{\"headers\": {\"host\": \"web-platform.test:8000\", \"referer\": \"http://web-platform.test:8000/referrer-policy/gen/req.attr/same-origin/img-tag.http.html\", \"user-agent\": \"Crane\", \"accept\": \"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\"}}" },
};

/// common.sub.js decodeImageData: 8 bits from 3 pixels' R, G and B (the
/// ninth unused), a channel >= 128 a one, most significant bit first, up to
/// a zero byte.
fn readBack(allocator: std.mem.Allocator, rgba: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var i: usize = 0;
    while (i + 12 <= rgba.len) : (i += 12) {
        var byte: u8 = 0;
        var bit: usize = 0;
        for (0..3) |j| for (0..3) |c| {
            if (bit == 8) break;
            byte = (byte << 1) | @intFromBool(rgba[i + j * 4 + c] >= 128);
            bit += 1;
        };
        if (byte == 0) break;
        try out.append(allocator, byte);
    }
    return out.toOwnedSlice(allocator);
}

test "bmp: image.py's bitmaps read back as the request headers they encode" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    for (image_py) |case| {
        const image = try decode(case[0]);
        defer free(image);
        try testing.expectEqual(case[1], image.width);
        try testing.expectEqual(case[1], image.height);
        const text = try readBack(testing.allocator, image.pixels.slice());
        defer testing.allocator.free(text);
        try testing.expectEqualStrings(case[2], text);
    }
}

test "bmp: every truncation of image.py's bitmap is corrupt, and flipped bytes never crash" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const original = image_py[1][0];
    for (0..original.len) |len| {
        try testing.expectError(error.Corrupt, decode(original[0..len]));
    }
    const bytes = try testing.allocator.dupe(u8, original);
    defer testing.allocator.free(bytes);
    // The headers and the first rows: past them a flip only changes a pixel.
    for (0..200) |i| {
        for ([_]u8{ 0x01, 0x80, 0xff }) |mask| {
            bytes[i] = original[i] ^ mask;
            defer bytes[i] = original[i];
            if (decode(bytes)) |image| free(image) else |_| {}
        }
    }
}

// ---------------------------------------------------------------------------
// Bitmaps built here
// ---------------------------------------------------------------------------

const Bitmap = struct {
    header_size: u32 = 40,
    width: i32,
    height: i32,
    bit_count: u16,
    compression: u32 = 0,
    colors_used: u32 = 0,
    /// R, G, B, A masks: in a V2+ header, or after a 40-byte one for
    /// BI_BITFIELDS (`extra_masks` of them).
    masks: [4]u32 = .{ 0, 0, 0, 0 },
    extra_masks: u8 = 0,
    /// Colour table entries, R G B; written B G R (and a zero byte, except
    /// with the 12-byte header).
    palette: []const [3]u8 = &.{},
    /// The pixel data as the file stores it.
    data: []const u8,
    /// Overrides the file header's pixel data offset.
    data_offset: ?u32 = null,

    fn build(self: Bitmap) ![]u8 {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(testing.allocator);
        const a = testing.allocator;
        const entry_len: u32 = if (self.header_size == 12) 3 else 4;
        const offset = self.data_offset orelse 14 + self.header_size + 4 * @as(u32, self.extra_masks) + entry_len * @as(u32, @intCast(self.palette.len));
        try out.appendSlice(a, "BM");
        try appendU32(&out, 0); // file size: no browser reads it
        try appendU32(&out, 0);
        try appendU32(&out, offset);
        try appendU32(&out, self.header_size);
        if (self.header_size == 12) {
            try appendU16(&out, @intCast(self.width));
            try appendU16(&out, @intCast(self.height));
            try appendU16(&out, 1);
            try appendU16(&out, self.bit_count);
        } else {
            try appendU32(&out, @bitCast(self.width));
            try appendU32(&out, @bitCast(self.height));
            try appendU16(&out, 1);
            try appendU16(&out, self.bit_count);
            try appendU32(&out, self.compression);
            try appendU32(&out, 0); // image size
            try appendU32(&out, 2835); // 72 dpi
            try appendU32(&out, 2835);
            try appendU32(&out, self.colors_used);
            try appendU32(&out, 0);
            var written: u32 = 40;
            for (self.masks) |mask| {
                if (written >= self.header_size) break;
                try appendU32(&out, mask);
                written += 4;
            }
            // V4/V5's colour space fields: zero (LCS_CALIBRATED_RGB with no
            // endpoints), which the decoder ignores.
            while (written < self.header_size) : (written += 1) try out.append(a, 0);
        }
        for (0..self.extra_masks) |i| try appendU32(&out, self.masks[i]);
        for (self.palette) |rgb| {
            try out.appendSlice(a, &.{ rgb[2], rgb[1], rgb[0] });
            if (entry_len == 4) try out.append(a, 0);
        }
        while (out.items.len < offset) try out.append(a, 0);
        try out.appendSlice(a, self.data);
        return out.toOwnedSlice(a);
    }

    fn appendU16(out: *std.ArrayList(u8), value: u16) !void {
        var b: [2]u8 = undefined;
        std.mem.writeInt(u16, &b, value, .little);
        try out.appendSlice(testing.allocator, &b);
    }

    fn appendU32(out: *std.ArrayList(u8), value: u32) !void {
        var b: [4]u8 = undefined;
        std.mem.writeInt(u32, &b, value, .little);
        try out.appendSlice(testing.allocator, &b);
    }
};

fn expectBitmap(bitmap: Bitmap, width: u32, height: u32, expected: []const [4]u8) !void {
    const bytes = try bitmap.build();
    defer testing.allocator.free(bytes);
    try expectPixels(bytes, width, height, expected);
}

fn expectBitmapError(bitmap: Bitmap, expected: platform.ImageError) !void {
    const bytes = try bitmap.build();
    defer testing.allocator.free(bytes);
    try testing.expectError(expected, decode(bytes));
}

const red: [4]u8 = .{ 255, 0, 0, 255 };
const green: [4]u8 = .{ 0, 255, 0, 255 };
const blue: [4]u8 = .{ 0, 0, 255, 255 };
const white: [4]u8 = .{ 255, 255, 255, 255 };
const black: [4]u8 = .{ 0, 0, 0, 255 };
const clear: [4]u8 = .{ 0, 0, 0, 0 };

test "bmp: 24 bits, bottom-up rows padded to four bytes, and top-down" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // 3 x 2: each row 9 bytes of B G R, padded to 12. The bottom row first.
    const rows = [_]u8{
        255, 0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, // bottom: blue, green, red
        255, 255, 255, 0, 0, 0, 1, 2, 3, 0, 0, 0, // top: white, black, (3,2,1)
    };
    const top_then_bottom = [_][4]u8{ white, black, .{ 3, 2, 1, 255 }, blue, green, red };
    try expectBitmap(.{ .width = 3, .height = 2, .bit_count = 24, .data = &rows }, 3, 2, &top_then_bottom);
    // A negative height: the first row stored is the top.
    const bottom_then_top = [_][4]u8{ blue, green, red, white, black, .{ 3, 2, 1, 255 } };
    try expectBitmap(.{ .width = 3, .height = -2, .bit_count = 24, .data = &rows }, 3, 2, &bottom_then_top);
}

test "bmp: 1, 2, 4 and 8 bits through the colour table; an index past it is black" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const palette = [_][3]u8{ .{ 255, 0, 0 }, .{ 0, 255, 0 }, .{ 0, 0, 255 } };
    // 1 bit: 3 pixels 0b101 in the top bits; 2 colours used.
    try expectBitmap(.{ .width = 3, .height = 1, .bit_count = 1, .colors_used = 2, .palette = palette[0..2], .data = &.{ 0b1010_0000, 0, 0, 0 } }, 3, 1, &.{ green, red, green });
    // 2 bits: indexes 2, 1, 0, 3 - and 3 is past the 3-entry table.
    try expectBitmap(.{ .width = 4, .height = 1, .bit_count = 2, .colors_used = 3, .palette = &palette, .data = &.{ 0b10_01_00_11, 0, 0, 0 } }, 4, 1, &.{ blue, green, red, black });
    // 4 bits: indexes 1, 2, 15.
    try expectBitmap(.{ .width = 3, .height = 1, .bit_count = 4, .colors_used = 3, .palette = &palette, .data = &.{ 0x12, 0xf0, 0, 0 } }, 3, 1, &.{ green, blue, black });
    // 8 bits, and "0 colours used" meaning all 256 - of which 3 are given
    // before the pixel data begins: the table is cut at the data offset.
    try expectBitmap(.{ .width = 2, .height = 1, .bit_count = 8, .palette = &palette, .data = &.{ 2, 200, 0, 0 } }, 2, 1, &.{ blue, black });
}

test "bmp: the OS/2 1.x header has 16-bit sizes and three-byte colour entries" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const palette = [_][3]u8{ .{ 10, 20, 30 }, .{ 40, 50, 60 } };
    try expectBitmap(.{ .header_size = 12, .width = 2, .height = 1, .bit_count = 8, .palette = &palette, .data = &.{ 1, 0, 0, 0 } }, 2, 1, &.{ .{ 40, 50, 60, 255 }, .{ 10, 20, 30, 255 } });
}

test "bmp: 16 bits - BI_RGB's 5-5-5 and BI_BITFIELDS 5-6-5, rescaled by rounding" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // 0x7c00 red 31, 0x03e0 green 31, 0x0001 blue 1 -> round(255 / 31) = 8;
    // the top bit is unused.
    try expectBitmap(.{ .width = 3, .height = 1, .bit_count = 16, .data = &.{ 0x00, 0x7c, 0xe0, 0x03, 0x01, 0x80, 0, 0 } }, 3, 1, &.{ red, green, .{ 0, 0, 8, 255 } });
    // 5-6-5 masks after a 40-byte header: green 1 of 6 bits -> round(255 / 63) = 4.
    try expectBitmap(.{ .width = 2, .height = 1, .bit_count = 16, .compression = 3, .masks = .{ 0xf800, 0x07e0, 0x001f, 0 }, .extra_masks = 3, .data = &.{ 0x00, 0xf8, 0x20, 0x00 } }, 2, 1, &.{ red, .{ 0, 4, 0, 255 } });
}

test "bmp: a Windows V3 bitmap's fourth byte is not alpha; a V4 alpha mask is" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // 32 bits, B G R x; x = 0x40 and 0x00 ignored: opaque.
    const data = [_]u8{ 0, 0, 255, 0x40, 255, 0, 0, 0x00 };
    try expectBitmap(.{ .width = 2, .height = 1, .bit_count = 32, .data = &data }, 2, 1, &.{ red, blue });
    // A V4 header's alpha mask 0xff000000 is respected, even with BI_RGB.
    const v4 = Bitmap{ .header_size = 108, .width = 2, .height = 1, .bit_count = 32, .masks = .{ 0xff0000, 0xff00, 0xff, 0xff000000 }, .data = &.{ 0, 0, 255, 0x80, 255, 0, 0, 0xff } };
    try expectBitmap(v4, 2, 1, &.{ .{ 255, 0, 0, 0x80 }, blue });
}

test "bmp: an all-zero alpha channel is opaque, and a later non-zero alpha resets what came before" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // V5, alpha all zero: opaque.
    try expectBitmap(.{ .header_size = 124, .width = 2, .height = 1, .bit_count = 32, .masks = .{ 0xff0000, 0xff00, 0xff, 0xff000000 }, .data = &.{ 0, 0, 255, 0, 255, 0, 0, 0 } }, 2, 1, &.{ red, blue });
    // A zero alpha, then 0x80: the alpha channel is real, and the pixel
    // decoded before it becomes transparent black (Blink).
    try expectBitmap(.{ .header_size = 124, .width = 2, .height = 1, .bit_count = 32, .masks = .{ 0xff0000, 0xff00, 0xff, 0xff000000 }, .data = &.{ 0, 0, 255, 0, 255, 0, 0, 0x80 } }, 2, 1, &.{ clear, .{ 0, 0, 255, 0x80 } });
}

test "bmp: RLE8 - runs, absolute runs, delta, end of line, end of bitmap; skipped pixels are transparent" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const palette = [_][3]u8{ .{ 0, 0, 0 }, .{ 255, 0, 0 }, .{ 0, 255, 0 } };
    // 4 x 3, bottom-up.
    const data = [_]u8{
        3, 1, 0, 0, // bottom row: 3 x index 1, end of line (the 4th stays clear)
        0, 2, 1, 0, // delta: 1 right, 0 down
        0, 3, 2, 1, 2, 0, // absolute: 3 pixels 2, 1, 2, padded to 16 bits
        0, 0, // end of line
        6, 2, // top row: a run of 6 green, cut at the row's end
        0, 1, // end of bitmap
    };
    try expectBitmap(.{ .width = 4, .height = 3, .bit_count = 8, .compression = 1, .colors_used = 3, .palette = &palette, .data = &data }, 4, 3, &.{
        green, green, green, green,
        clear, green, red,   green,
        red,   red,   red,   clear,
    });
}

test "bmp: RLE4 alternates a run's two indexes" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const palette = [_][3]u8{ .{ 0, 0, 0 }, .{ 255, 0, 0 }, .{ 0, 255, 0 } };
    // 5 pixels of 1, 2, 1, 2, 1; then 3 absolute pixels 2, 0, 1 (two bytes, padded to 16 bits).
    try expectBitmap(.{ .width = 8, .height = 1, .bit_count = 4, .compression = 2, .colors_used = 3, .palette = &palette, .data = &.{ 5, 0x12, 0, 3, 0x20, 0x10, 0, 1 } }, 8, 1, &.{ red, green, red, green, red, green, black, red });
}

test "bmp: an RLE stream without its end, or with data past the image, is corrupt" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const palette = [_][3]u8{ .{ 0, 0, 0 }, .{ 255, 0, 0 } };
    // No end of bitmap.
    try expectBitmapError(.{ .width = 2, .height = 1, .bit_count = 8, .compression = 1, .colors_used = 2, .palette = &palette, .data = &.{ 2, 1, 0, 0 } }, error.Corrupt);
    // A run after the last row.
    try expectBitmapError(.{ .width = 2, .height = 1, .bit_count = 8, .compression = 1, .colors_used = 2, .palette = &palette, .data = &.{ 2, 1, 0, 0, 2, 1, 0, 1 } }, error.Corrupt);
    // An absolute run wider than the row.
    try expectBitmapError(.{ .width = 2, .height = 1, .bit_count = 8, .compression = 1, .colors_used = 2, .palette = &palette, .data = &.{ 0, 3, 1, 1, 1, 0, 0, 1 } }, error.Corrupt);
}

test "bmp: headers and data a browser rejects are corrupt" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const row = [_]u8{ 0, 0, 255, 0 };
    // Zero width or height, too wide, an unknown bit count.
    try expectBitmapError(.{ .width = 0, .height = 1, .bit_count = 24, .data = &row }, error.Corrupt);
    try expectBitmapError(.{ .width = 1, .height = 0, .bit_count = 24, .data = &row }, error.Corrupt);
    try expectBitmapError(.{ .width = 1 << 16, .height = 1, .bit_count = 24, .data = &row }, error.Corrupt);
    try expectBitmapError(.{ .width = 1, .height = 1, .bit_count = 3, .data = &row }, error.Corrupt);
    // A header size that is no known header.
    try expectBitmapError(.{ .header_size = 41, .width = 1, .height = 1, .bit_count = 24, .data = &row }, error.Corrupt);
    // Pixel data said to begin inside the header.
    try expectBitmapError(.{ .width = 1, .height = 1, .bit_count = 24, .data = &row, .data_offset = 20 }, error.Corrupt);
    // Pixel data that ends early.
    try expectBitmapError(.{ .width = 2, .height = 1, .bit_count = 24, .data = &row }, error.Corrupt);
    // Overlapping, and non-contiguous, bit masks.
    try expectBitmapError(.{ .width = 1, .height = 1, .bit_count = 16, .compression = 3, .masks = .{ 0xf800, 0x0fe0, 0x001f, 0 }, .extra_masks = 3, .data = &row }, error.Corrupt);
    try expectBitmapError(.{ .width = 1, .height = 1, .bit_count = 16, .compression = 3, .masks = .{ 0xf400, 0x07e0, 0x001f, 0 }, .extra_masks = 3, .data = &row }, error.Corrupt);
    // A top-down OS/2 2.x bitmap.
    try expectBitmapError(.{ .header_size = 64, .width = 1, .height = -1, .bit_count = 24, .data = &row }, error.Corrupt);
    // Not a bitmap at all.
    try testing.expectError(error.Corrupt, decode("GIF89a and more bytes than a header"));
    try testing.expectError(error.Corrupt, decode(""));
}

test "bmp: an embedded JPEG is unsupported, and the limits refuse a large header first" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    try expectBitmapError(.{ .width = 1, .height = 1, .bit_count = 0, .compression = 4, .data = "\xff\xd8\xff" }, error.UnsupportedFormat);
    const bytes = try (Bitmap{ .width = 300, .height = 300, .bit_count = 24, .data = &.{} }).build();
    defer testing.allocator.free(bytes);
    try testing.expectError(error.TooLarge, platform.decodeImage(testing.allocator, platform.Str.from("image/bmp"), platform.Bytes.from(bytes), .{ .max_dimension = 299, .max_pixels = 1 << 24 }));
    try testing.expectError(error.TooLarge, platform.decodeImage(testing.allocator, platform.Str.from("image/bmp"), platform.Bytes.from(bytes), .{ .max_dimension = 300, .max_pixels = 300 * 300 - 1 }));
}

test "bmp: a PNG inside a BMP decodes as the PNG, at the header's size" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const png_bytes = try std.Io.Dir.cwd().readFileAlloc(testing.io, "tests/wpt/css/css-ui/support/PTS/basn6a08.png", testing.allocator, .limited(1 << 20));
    defer testing.allocator.free(png_bytes);
    const as_png = try platform.decodeImage(testing.allocator, platform.Str.from("image/png"), platform.Bytes.from(png_bytes), limits);
    defer free(as_png);
    const inside = try (Bitmap{ .width = 32, .height = 32, .bit_count = 0, .compression = 5, .data = png_bytes }).build();
    defer testing.allocator.free(inside);
    const image = try decode(inside);
    defer free(image);
    try testing.expectEqualSlices(u8, as_png.pixels.slice(), image.pixels.slice());
    const wrong_size = try (Bitmap{ .width = 16, .height = 32, .bit_count = 0, .compression = 5, .data = png_bytes }).build();
    defer testing.allocator.free(wrong_size);
    try testing.expectError(error.Corrupt, decode(wrong_size));
}

test "bmp: a bitmap array's first bitmap is the image" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const inner = try (Bitmap{ .width = 1, .height = 1, .bit_count = 24, .data = &.{ 0, 0, 255, 0 } }).build();
    defer testing.allocator.free(inner);
    // "BA", then 12 bytes of array header, then the bitmap, whose offsets
    // count from the array's start.
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(testing.allocator);
    try bytes.appendSlice(testing.allocator, "BA" ++ [_]u8{0} ** 12);
    try bytes.appendSlice(testing.allocator, inner);
    std.mem.writeInt(u32, bytes.items[14 + 10 ..][0..4], 14 + 14 + 40, .little);
    try expectPixels(bytes.items, 1, 1, &.{red});
}
