//! A PNG encoder (W3C PNG Third Edition, https://www.w3.org/TR/png-3/): one
//! RGBA8 image, straight alpha, rows top down, to a PNG datastream of colour
//! type 6 (truecolour with alpha), bit depth 8, no interlace.
//!
//! Its chunks, in order: IHDR; sRGB, the bitmap's colour space (HTML 4.12.5.5:
//! "the serialized image must include a color profile indicating the color
//! space of the underlying bitmap" - a canvas's bitmap is sRGB, which PNG's
//! sRGB chunk names, rendering intent perceptual, libpng's PNG_sRGB_INTENT_
//! PERCEPTUAL default); pHYs, 96 dpi (HTML 4.12.5.5: "the resolution must be
//! given as 96dpi" - 3780 pixels per metre, unit metre); IDAT, the zlib
//! stream of the filtered scanlines (PNG 9, 10); IEND.
//!
//! Each scanline takes the filter type (PNG 9.2: None, Sub, Up, Average,
//! Paeth) whose filtered bytes have the smallest sum of absolute values,
//! read as signed - the heuristic PNG 12.8 recommends and libpng's adaptive
//! filtering applies to truecolour images. The stream is deflated at zlib's
//! default level (6) by std.compress.flate.

const std = @import("std");
const flate = std.compress.flate;

pub const Error = error{ OutOfMemory, TooLarge, UnsupportedFormat };

/// PNG 11.2.1: "The maximum for each [width and height] is 2^31 - 1".
pub const max_dimension: u32 = (1 << 31) - 1;

const signature = [8]u8{ 0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n' };

/// 96 dpi in pixels per metre: 96 / 0.0254 = 3779.53, rounded.
const pixels_per_metre_96dpi: u32 = 3780;

/// Encode `width` x `height` RGBA8 pixels (straight alpha, rows top down;
/// `pixels.len` must be width * height * 4) as a PNG datastream, OWNED by
/// `allocator`. A dimension of zero or above `max_dimension`, or a size whose
/// bytes cannot be counted, is TooLarge, found before anything is allocated;
/// `pixels` of another length is UnsupportedFormat.
pub fn encode(allocator: std.mem.Allocator, width: u32, height: u32, pixels: []const u8) Error![]u8 {
    if (width == 0 or height == 0 or width > max_dimension or height > max_dimension) return error.TooLarge;
    const stride = std.math.mul(usize, width, 4) catch return error.TooLarge;
    const total = std.math.mul(usize, stride, height) catch return error.TooLarge;
    // The filtered stream adds one filter byte per row.
    _ = std.math.add(usize, total, height) catch return error.TooLarge;
    if (pixels.len != total) return error.UnsupportedFormat;

    const idat = try deflateScanlines(allocator, stride, height, pixels);
    defer allocator.free(idat);

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, &signature);

    // IHDR (PNG 11.2.1).
    var ihdr: [13]u8 = undefined;
    std.mem.writeInt(u32, ihdr[0..4], width, .big);
    std.mem.writeInt(u32, ihdr[4..8], height, .big);
    ihdr[8] = 8; // bit depth
    ihdr[9] = 6; // colour type: truecolour with alpha
    ihdr[10] = 0; // compression method: deflate
    ihdr[11] = 0; // filter method: adaptive, five types
    ihdr[12] = 0; // interlace method: none
    try writeChunk(allocator, &out, "IHDR", &ihdr);

    // sRGB (PNG 11.3.2.5): rendering intent 0, perceptual.
    try writeChunk(allocator, &out, "sRGB", &.{0});

    // pHYs (PNG 11.3.4.3): 96 dpi, unit 1 (the metre).
    var phys: [9]u8 = undefined;
    std.mem.writeInt(u32, phys[0..4], pixels_per_metre_96dpi, .big);
    std.mem.writeInt(u32, phys[4..8], pixels_per_metre_96dpi, .big);
    phys[8] = 1;
    try writeChunk(allocator, &out, "pHYs", &phys);

    // IDAT (PNG 11.2.3): a chunk's length is at most 2^31 - 1, so a larger
    // stream is split over several, as PNG 10.1 allows.
    var rest: []const u8 = idat;
    const max_chunk: usize = 1 << 30;
    while (true) {
        const n = @min(rest.len, max_chunk);
        try writeChunk(allocator, &out, "IDAT", rest[0..n]);
        rest = rest[n..];
        if (rest.len == 0) break;
    }

    // IEND (PNG 11.2.4).
    try writeChunk(allocator, &out, "IEND", &.{});
    return out.toOwnedSlice(allocator);
}

/// PNG 5.3: length, type, data, and the CRC-32 of type and data.
fn writeChunk(allocator: std.mem.Allocator, out: *std.ArrayList(u8), comptime kind: *const [4]u8, data: []const u8) error{OutOfMemory}!void {
    var length: [4]u8 = undefined;
    std.mem.writeInt(u32, &length, @intCast(data.len), .big);
    try out.appendSlice(allocator, &length);
    try out.appendSlice(allocator, kind);
    try out.appendSlice(allocator, data);
    var crc = std.hash.Crc32.init();
    crc.update(kind);
    crc.update(data);
    var sum: [4]u8 = undefined;
    std.mem.writeInt(u32, &sum, crc.final(), .big);
    try out.appendSlice(allocator, &sum);
}

/// The zlib stream (PNG 10.1: compression method 0) of every scanline,
/// each its filter type byte then its filtered bytes (PNG 9.2), OWNED.
fn deflateScanlines(allocator: std.mem.Allocator, stride: usize, height: u32, pixels: []const u8) Error![]u8 {
    var output: std.Io.Writer.Allocating = try .initCapacity(allocator, @max(64, (stride + 1) * @as(usize, height) / 4));
    defer output.deinit();
    const window = try allocator.alloc(u8, flate.max_window_len);
    defer allocator.free(window);
    // About 224 KiB of match tables: on the heap, not the caller's stack.
    const compress = try allocator.create(flate.Compress);
    defer allocator.destroy(compress);
    compress.* = flate.Compress.init(&output.writer, window, .zlib, .default) catch return error.OutOfMemory;

    // The chosen row and a trial row, each a filter type byte then the row.
    const best = try allocator.alloc(u8, stride + 1);
    defer allocator.free(best);
    const trial = try allocator.alloc(u8, stride + 1);
    defer allocator.free(trial);

    var y: usize = 0;
    while (y < height) : (y += 1) {
        const row = pixels[y * stride ..][0..stride];
        // PNG 9.2: the row above the first is all zero.
        const previous: ?[]const u8 = if (y == 0) null else pixels[(y - 1) * stride ..][0..stride];
        var best_cost: u64 = std.math.maxInt(u64);
        for ([_]u8{ 0, 1, 2, 3, 4 }) |filter_type| {
            const cost = filterRow(trial, filter_type, row, previous);
            if (cost < best_cost) {
                best_cost = cost;
                @memcpy(best, trial);
            }
        }
        compress.writer.writeAll(best) catch return error.OutOfMemory;
    }
    compress.finish() catch return error.OutOfMemory;
    return output.toOwnedSlice() catch return error.OutOfMemory;
}

/// Filter `row` with `filter_type` into `into` (its type byte first), and
/// return the sum of the filtered bytes' absolute values read as signed.
fn filterRow(into: []u8, filter_type: u8, row: []const u8, previous: ?[]const u8) u64 {
    const bpp = 4; // bytes per complete pixel (PNG 9.2's "bpp")
    into[0] = filter_type;
    var cost: u64 = 0;
    for (row, 0..) |x, i| {
        const a: u8 = if (i >= bpp) row[i - bpp] else 0;
        const b: u8 = if (previous) |p| p[i] else 0;
        const c: u8 = if (i >= bpp) (if (previous) |p| p[i - bpp] else 0) else 0;
        const predictor: u8 = switch (filter_type) {
            0 => 0,
            1 => a,
            2 => b,
            3 => @intCast((@as(u16, a) + b) / 2),
            4 => paeth(a, b, c),
            else => unreachable,
        };
        const filtered = x -% predictor;
        into[i + 1] = filtered;
        const signed: i8 = @bitCast(filtered);
        cost += @abs(signed);
    }
    return cost;
}

/// PNG 9.4: the Paeth predictor.
fn paeth(a: u8, b: u8, c: u8) u8 {
    const p: i16 = @as(i16, a) + b - c;
    const pa = @abs(p - a);
    const pb = @abs(p - b);
    const pc = @abs(p - c);
    if (pa <= pb and pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
}

test "paeth picks the nearest of left, up and upper-left, in that order on ties" {
    try std.testing.expectEqual(@as(u8, 10), paeth(10, 10, 10));
    try std.testing.expectEqual(@as(u8, 20), paeth(10, 20, 10));
    try std.testing.expectEqual(@as(u8, 10), paeth(10, 20, 20));
    // p = 200 + 100 - 5 = 295: |p - a| = 95 is the smallest.
    try std.testing.expectEqual(@as(u8, 200), paeth(200, 100, 5));
    // p = 0 + 0 - 255 = -255: |p - c| = 510, |p - a| = |p - b| = 255 -> a.
    try std.testing.expectEqual(@as(u8, 0), paeth(0, 0, 255));
}
