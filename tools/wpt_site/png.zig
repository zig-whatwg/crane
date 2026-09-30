//! PNG, as much of it as the social card needs, over std's deflate.
//!
//! * `encodeRgb` writes an 8-bit truecolour, non-interlaced PNG. Each
//!   scanline takes the filter (None, Sub, Up, Average, Paeth) whose output
//!   has the smallest sum of absolute values - the heuristic the PNG
//!   specification suggests (PNG 3rd ed., 12.8 "Filter selection") - and the
//!   filtered image is deflated by `std.compress.flate.Compress` in a zlib
//!   container. Same pixels, same bytes: there is no timestamp or text chunk.
//! * `decode` reads the 8-bit, non-interlaced PNGs headless Chrome writes
//!   (greyscale, grey+alpha, RGB, RGBA) into RGB, compositing any alpha over
//!   white. It exists for the card's committed glyph atlas and base image.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const flate = std.compress.flate;

pub const signature = "\x89PNG\r\n\x1a\n";

/// An RGB image, 3 bytes per pixel, rows top to bottom.
pub const Image = struct {
    width: u32,
    height: u32,
    rgb: []u8,

    pub fn deinit(img: *Image, gpa: Allocator) void {
        gpa.free(img.rgb);
        img.* = undefined;
    }

    pub fn at(img: Image, x: u32, y: u32) *[3]u8 {
        const i = (@as(usize, y) * img.width + x) * 3;
        return img.rgb[i..][0..3];
    }
};

fn writeChunk(w: *Io.Writer, kind: *const [4]u8, data: []const u8) Io.Writer.Error!void {
    try w.writeInt(u32, @intCast(data.len), .big);
    try w.writeAll(kind);
    try w.writeAll(data);
    var crc = std.hash.Crc32.init();
    crc.update(kind);
    crc.update(data);
    try w.writeInt(u32, crc.final(), .big);
}

fn paeth(a: u8, b: u8, c: u8) u8 {
    const p: i16 = @as(i16, a) + b - c;
    const pa = @abs(p - a);
    const pb = @abs(p - b);
    const pc = @abs(p - c);
    if (pa <= pb and pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
}

/// Filter one scanline with filter `f` into `out` (same length as `cur`).
fn filterRow(f: u8, cur: []const u8, prev: []const u8, bpp: usize, out: []u8) void {
    for (cur, 0..) |x, i| {
        const a: u8 = if (i >= bpp) cur[i - bpp] else 0;
        const b: u8 = prev[i];
        const c: u8 = if (i >= bpp) prev[i - bpp] else 0;
        out[i] = switch (f) {
            0 => x,
            1 => x -% a,
            2 => x -% b,
            3 => x -% @as(u8, @intCast((@as(u16, a) + b) / 2)),
            4 => x -% paeth(a, b, c),
            else => unreachable,
        };
    }
}

fn unfilterRow(f: u8, cur: []u8, prev: []const u8, bpp: usize) !void {
    for (cur, 0..) |*x, i| {
        const a: u8 = if (i >= bpp) cur[i - bpp] else 0;
        const b: u8 = prev[i];
        const c: u8 = if (i >= bpp) prev[i - bpp] else 0;
        x.* = switch (f) {
            0 => x.*,
            1 => x.* +% a,
            2 => x.* +% b,
            3 => x.* +% @as(u8, @intCast((@as(u16, a) + b) / 2)),
            4 => x.* +% paeth(a, b, c),
            else => return error.BadFilter,
        };
    }
}

/// Write `rgb` (width * height * 3 bytes) as a PNG to `w`.
pub fn encodeRgb(gpa: Allocator, w: *Io.Writer, width: u32, height: u32, rgb: []const u8) !void {
    const stride = @as(usize, width) * 3;
    std.debug.assert(rgb.len == stride * height);

    // Filtered scanlines: a filter byte, then the row.
    const raw = try gpa.alloc(u8, (stride + 1) * height);
    defer gpa.free(raw);
    const zero = try gpa.alloc(u8, stride);
    defer gpa.free(zero);
    @memset(zero, 0);
    const trial = try gpa.alloc(u8, stride);
    defer gpa.free(trial);
    for (0..height) |y| {
        const cur = rgb[y * stride ..][0..stride];
        const prev = if (y == 0) zero else rgb[(y - 1) * stride ..][0..stride];
        const dst = raw[y * (stride + 1) ..][0 .. stride + 1];
        var best: u8 = 0;
        var best_cost: u64 = std.math.maxInt(u64);
        for (0..5) |f| {
            filterRow(@intCast(f), cur, prev, 3, trial);
            var cost: u64 = 0;
            for (trial) |v| cost += @abs(@as(i8, @bitCast(v)));
            if (cost < best_cost) {
                best_cost = cost;
                best = @intCast(f);
            }
        }
        dst[0] = best;
        filterRow(best, cur, prev, 3, dst[1..]);
    }

    var zout: Io.Writer.Allocating = try .initCapacity(gpa, 64 * 1024);
    defer zout.deinit();
    const window = try gpa.alloc(u8, flate.max_window_len);
    defer gpa.free(window);
    var z = try flate.Compress.init(&zout.writer, window, .zlib, .best);
    try z.writer.writeAll(raw);
    try z.finish();

    var ihdr: [13]u8 = undefined;
    std.mem.writeInt(u32, ihdr[0..4], width, .big);
    std.mem.writeInt(u32, ihdr[4..8], height, .big);
    ihdr[8..13].* = .{ 8, 2, 0, 0, 0 }; // 8-bit, truecolour, deflate, adaptive filtering, no interlace

    try w.writeAll(signature);
    try writeChunk(w, "IHDR", &ihdr);
    try writeChunk(w, "IDAT", zout.written());
    try writeChunk(w, "IEND", "");
}

pub const DecodeError = error{ NotPng, BadChunk, BadCrc, Unsupported, BadFilter, Truncated } || Allocator.Error;

/// Decode an 8-bit, non-interlaced PNG into RGB. Alpha is composited over
/// white, which is what the card's black-on-white atlas was rendered on.
pub fn decode(gpa: Allocator, bytes: []const u8) (DecodeError || error{ReadFailed})!Image {
    if (!std.mem.startsWith(u8, bytes, signature)) return error.NotPng;
    var pos: usize = signature.len;
    var width: u32 = 0;
    var height: u32 = 0;
    var channels: usize = 0;
    var idat: std.ArrayList(u8) = .empty;
    defer idat.deinit(gpa);
    var seen_end = false;
    while (pos + 12 <= bytes.len) {
        const len = std.mem.readInt(u32, bytes[pos..][0..4], .big);
        if (pos + 12 + len > bytes.len) return error.BadChunk;
        const kind = bytes[pos + 4 ..][0..4];
        const data = bytes[pos + 8 ..][0..len];
        var crc = std.hash.Crc32.init();
        crc.update(kind);
        crc.update(data);
        if (crc.final() != std.mem.readInt(u32, bytes[pos + 8 + len ..][0..4], .big)) return error.BadCrc;
        pos += 12 + len;
        if (std.mem.eql(u8, kind, "IHDR")) {
            if (len != 13) return error.BadChunk;
            width = std.mem.readInt(u32, data[0..4], .big);
            height = std.mem.readInt(u32, data[4..8], .big);
            if (data[8] != 8 or data[10] != 0 or data[11] != 0 or data[12] != 0) return error.Unsupported;
            channels = switch (data[9]) {
                0 => 1,
                2 => 3,
                4 => 2,
                6 => 4,
                else => return error.Unsupported,
            };
        } else if (std.mem.eql(u8, kind, "IDAT")) {
            try idat.appendSlice(gpa, data);
        } else if (std.mem.eql(u8, kind, "IEND")) {
            seen_end = true;
            break;
        } else if (kind[0] & 0x20 == 0) {
            // A critical chunk we do not know (PLTE included: no palettes here).
            return error.Unsupported;
        }
    }
    if (!seen_end or channels == 0 or width == 0 or height == 0) return error.Truncated;

    var in: Io.Reader = .fixed(idat.items);
    var z: flate.Decompress = .init(&in, .zlib, &.{});
    const stride = @as(usize, width) * channels;
    const want = (stride + 1) * height;
    const raw = z.reader.allocRemaining(gpa, .limited(want + 1)) catch |e| switch (e) {
        error.StreamTooLong => return error.BadChunk,
        error.OutOfMemory => return error.OutOfMemory,
        error.ReadFailed => return error.ReadFailed,
    };
    defer gpa.free(raw);
    if (raw.len != want) return error.Truncated;

    const zero = try gpa.alloc(u8, stride);
    defer gpa.free(zero);
    @memset(zero, 0);
    var prev: []const u8 = zero;
    for (0..height) |y| {
        const row = raw[y * (stride + 1) ..][0 .. stride + 1];
        try unfilterRow(row[0], row[1..], prev, channels);
        prev = row[1..];
    }

    const rgb = try gpa.alloc(u8, @as(usize, width) * height * 3);
    for (0..height) |y| {
        const row = raw[y * (stride + 1) + 1 ..][0..stride];
        for (0..width) |x| {
            const p = row[x * channels ..][0..channels];
            const o = rgb[(y * width + x) * 3 ..][0..3];
            const c: [3]u8 = switch (channels) {
                1, 2 => .{ p[0], p[0], p[0] },
                else => .{ p[0], p[1], p[2] },
            };
            const a: u16 = switch (channels) {
                2 => p[1],
                4 => p[3],
                else => 255,
            };
            for (o, c) |*dst, v| dst.* = @intCast((@as(u16, v) * a + 255 * (255 - a) + 127) / 255);
        }
    }
    return .{ .width = width, .height = height, .rgb = rgb };
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn testImage(gpa: Allocator, w: u32, h: u32) ![]u8 {
    const px = try gpa.alloc(u8, @as(usize, w) * h * 3);
    for (0..h) |y| for (0..w) |x| {
        const o = px[(y * w + x) * 3 ..][0..3];
        // Flat areas, gradients and a hard edge, so every filter wins somewhere.
        o.* = .{ @truncate(x * 7), @truncate(y * 3 + x), if (x > w / 2) 255 else @truncate(y) };
    };
    return px;
}

test "png: an encoded image decodes to the same pixels" {
    const gpa = testing.allocator;
    const px = try testImage(gpa, 97, 41);
    defer gpa.free(px);
    var out: Io.Writer.Allocating = .init(gpa);
    defer out.deinit();
    try encodeRgb(gpa, &out.writer, 97, 41, px);
    const bytes = out.written();
    try testing.expect(std.mem.startsWith(u8, bytes, signature));
    try testing.expect(std.mem.endsWith(u8, bytes, "IEND\xae\x42\x60\x82"));

    var img = try decode(gpa, bytes);
    defer img.deinit(gpa);
    try testing.expectEqual(@as(u32, 97), img.width);
    try testing.expectEqual(@as(u32, 41), img.height);
    try testing.expectEqualSlices(u8, px, img.rgb);
}

test "png: encoding is deterministic and compresses flat images" {
    const gpa = testing.allocator;
    const px = try gpa.alloc(u8, 1200 * 630 * 3);
    defer gpa.free(px);
    @memset(px, 0xff);
    var a: Io.Writer.Allocating = .init(gpa);
    defer a.deinit();
    var b: Io.Writer.Allocating = .init(gpa);
    defer b.deinit();
    try encodeRgb(gpa, &a.writer, 1200, 630, px);
    try encodeRgb(gpa, &b.writer, 1200, 630, px);
    try testing.expectEqualSlices(u8, a.written(), b.written());
    try testing.expect(a.written().len < 8 * 1024);
}

test "png: every filter type round-trips" {
    const cur = [_]u8{ 10, 200, 3, 40, 250, 6, 70, 8, 90 };
    const prev = [_]u8{ 1, 2, 3, 250, 5, 6, 7, 180, 9 };
    for (0..5) |f| {
        var filtered: [cur.len]u8 = undefined;
        filterRow(@intCast(f), &cur, &prev, 3, &filtered);
        try unfilterRow(@intCast(f), &filtered, &prev, 3);
        try testing.expectEqualSlices(u8, &cur, &filtered);
    }
    var bad = cur;
    try testing.expectError(error.BadFilter, unfilterRow(5, &bad, &prev, 3));
}

test "png: a damaged file is refused, not guessed at" {
    const gpa = testing.allocator;
    const px = try testImage(gpa, 8, 8);
    defer gpa.free(px);
    var out: Io.Writer.Allocating = .init(gpa);
    defer out.deinit();
    try encodeRgb(gpa, &out.writer, 8, 8, px);
    const bytes = try gpa.dupe(u8, out.written());
    defer gpa.free(bytes);
    try testing.expectError(error.NotPng, decode(gpa, "GIF89a"));
    bytes[signature.len + 8 + 2] ^= 1; // inside IHDR: its CRC no longer matches
    try testing.expectError(error.BadCrc, decode(gpa, bytes));
}

test "png: grey+alpha is composited over white" {
    const gpa = testing.allocator;
    // A 2x1 grey+alpha image: black at full alpha, black at zero alpha.
    const raw = [_]u8{ 0, 0, 255, 0, 0 };
    var zout: Io.Writer.Allocating = try .initCapacity(gpa, 1024);
    defer zout.deinit();
    const window = try gpa.alloc(u8, flate.max_window_len);
    defer gpa.free(window);
    var z = try flate.Compress.init(&zout.writer, window, .zlib, .default);
    try z.writer.writeAll(&raw);
    try z.finish();
    var file: Io.Writer.Allocating = .init(gpa);
    defer file.deinit();
    var ihdr: [13]u8 = undefined;
    std.mem.writeInt(u32, ihdr[0..4], 2, .big);
    std.mem.writeInt(u32, ihdr[4..8], 1, .big);
    ihdr[8..13].* = .{ 8, 4, 0, 0, 0 };
    try file.writer.writeAll(signature);
    try writeChunk(&file.writer, "IHDR", &ihdr);
    try writeChunk(&file.writer, "tEXt", "Software\x00test"); // ancillary: skipped
    try writeChunk(&file.writer, "IDAT", zout.written());
    try writeChunk(&file.writer, "IEND", "");
    var img = try decode(gpa, file.written());
    defer img.deinit(gpa);
    try testing.expectEqualSlices(u8, &.{ 0, 0, 0, 255, 255, 255 }, img.rgb);
}
