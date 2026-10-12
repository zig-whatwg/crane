//! Partial images through the platform protocol: once a decoder knows an
//! image's dimensions, data that ends early (a truncated file) or goes bad
//! (corrupt image data) is not an error but a partial DecodedImage - the
//! pixels decoded before that point, the rest transparent black, and a
//! status saying how the decode ended. Before the dimensions, it stays
//! `Corrupt`: HTML's "the image dimensions cannot be obtained".
//!
//! This is what the browsers do (lane imgpart, 2026-10-12): Blink fires load
//! once the size is available and draws a kFramePartial frame
//! (ImageResourceContent::UpdateImage, ImageDecoderWrapper::Decode); Gecko
//! fires load once the metadata decode has a size and finishes a frame the
//! data left mid-way (RasterImage::OnImageDataComplete,
//! Decoder::CompleteDecode); Safari's ImageIO, probed on macOS 27, returns an
//! image for every truncated and corrupt variant below once it has a size.
//! Where each format's dimensions become known is where the browsers place
//! it: PNG at its first IDAT chunk (libpng's info callback, the png crate's
//! read_info, ImageIO alike), GIF at its first image descriptor (Gecko's
//! BeginGIF), BMP after its headers, bit masks and colour table.
//!
//! The cases are WPT's own images, read from tests/wpt at run time and cut
//! at every length (or every few, for the larger ones), and images built
//! here with damage in a known place.

const std = @import("std");
const platform = @import("platform");

const testing = std.testing;

const limits: platform.ImageLimits = .{ .max_dimension = 1 << 15, .max_pixels = 1 << 24 };

fn readWpt(comptime path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(testing.io, "tests/wpt/" ++ path, testing.allocator, .limited(1 << 22));
}

fn decode(mime: []const u8, bytes: []const u8) platform.ImageError!platform.DecodedImage {
    return platform.decodeImage(testing.allocator, platform.Str.from(mime), platform.Bytes.from(bytes), limits);
}

fn free(image: platform.DecodedImage) void {
    testing.allocator.free(image.pixels.slice());
}

const clear = [4]u8{ 0, 0, 0, 0 };

/// The pixels of `part` that are decoded - not transparent black where the
/// whole image is not. Every other pixel must be the whole image's, or
/// transparent black (not reached).
fn decodedPixels(whole: platform.DecodedImage, part: platform.DecodedImage) !usize {
    try testing.expectEqual(whole.width, part.width);
    try testing.expectEqual(whole.height, part.height);
    const a = whole.pixels.slice();
    const b = part.pixels.slice();
    try testing.expectEqual(a.len, b.len);
    var decoded: usize = 0;
    var i: usize = 0;
    while (i < b.len) : (i += 4) {
        const pixel = b[i..][0..4];
        if (std.mem.eql(u8, pixel, a[i..][0..4])) {
            if (!std.mem.eql(u8, pixel, &clear)) decoded += 1;
            continue;
        }
        if (!std.mem.eql(u8, pixel, &clear)) {
            std.debug.print("pixel {d}: {any}, whole {any}\n", .{ i / 4, pixel, a[i..][0..4] });
            return error.TestUnexpectedResult;
        }
    }
    return decoded;
}

/// Cut `bytes` at every length up to just past `dimensions_at`, then every
/// `step`th (and the last few): before `dimensions_at` each cut is
/// `Corrupt`; from it, a partial image of the whole one's size whose decoded
/// pixels never shrink as the data grows - complete when every pixel
/// decoded (a cut after the last pixel's data: a missing CRC, checksum or
/// trailer), truncated otherwise - and from `complete_from` on, complete.
fn expectEveryCut(mime: []const u8, bytes: []const u8, dimensions_at: usize, complete_from: usize, step: usize) !void {
    const whole = try decode(mime, bytes);
    defer free(whole);
    try testing.expectEqual(platform.ImageDecodeStatus.complete, whole.status);
    try testing.expect(!whole.empty);
    var previous: usize = 0;
    var len: usize = 0;
    while (len <= bytes.len) : (len += if (len < dimensions_at + 3 or len + 8 >= bytes.len) 1 else step) {
        const cut = bytes[0..len];
        if (len < dimensions_at) {
            testing.expectError(error.Corrupt, decode(mime, cut)) catch |err| {
                std.debug.print("{s}: a cut at {d} of {d} has no dimensions yet\n", .{ mime, len, bytes.len });
                return err;
            };
            continue;
        }
        const part = decode(mime, cut) catch |err| {
            std.debug.print("{s}: a cut at {d} of {d} (dimensions at {d}): {s}\n", .{ mime, len, bytes.len, dimensions_at, @errorName(err) });
            return err;
        };
        defer free(part);
        const decoded = try decodedPixels(whole, part);
        testing.expect(decoded >= previous) catch |err| {
            std.debug.print("{s}: a cut at {d} decoded {d} pixels, a shorter one {d}\n", .{ mime, len, decoded, previous });
            return err;
        };
        previous = decoded;
        const every_pixel = std.mem.eql(u8, whole.pixels.slice(), part.pixels.slice());
        switch (part.status) {
            .complete => testing.expect(every_pixel) catch |err| {
                std.debug.print("{s}: a cut at {d} of {d} is complete without every pixel\n", .{ mime, len, bytes.len });
                return err;
            },
            .truncated => testing.expect(len < complete_from) catch |err| {
                std.debug.print("{s}: a cut at {d} of {d} should be complete\n", .{ mime, len, bytes.len });
                return err;
            },
            .corrupt => {
                std.debug.print("{s}: a cut at {d} of {d} is corrupt, not truncated\n", .{ mime, len, bytes.len });
                return error.TestUnexpectedResult;
            },
        }
        if (!every_pixel) try testing.expectEqual(platform.ImageDecodeStatus.truncated, part.status);
        // Empty: nothing decoded.
        if (part.empty) try testing.expectEqual(@as(usize, 0), decoded);
    }
}

/// The offset just past the 8-byte header (length and type) of the first
/// chunk of `kind`.
fn chunkStart(bytes: []const u8, kind: []const u8) usize {
    var pos: usize = 8;
    while (pos + 8 <= bytes.len) {
        const len = std.mem.readInt(u32, bytes[pos..][0..4], .big);
        if (std.mem.eql(u8, bytes[pos + 4 ..][0..4], kind)) return pos + 8;
        pos += 12 + len;
    }
    unreachable;
}

// ---------------------------------------------------------------------------
// PNG
// ---------------------------------------------------------------------------

test "partial: a PNG has dimensions from its first IDAT chunk's header, and keeps the rows its data reached" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // smiley.png: 300 x 150 truecolour, one IDAT of 1,705 bytes at 123, IEND
    // at 1,840. ImageIO: no size at 123 bytes, a size at 131 (the IDAT's
    // length and type).
    const smiley = try readWpt("images/smiley.png");
    defer testing.allocator.free(smiley);
    try testing.expectEqual(@as(usize, 131), chunkStart(smiley, "IDAT"));
    // Complete once the image data is: its CRC and the IEND may be missing.
    try expectEveryCut("image/png", smiley, 131, 123 + 8 + 1705, 7);
    // lcp-133x106.png: indexed, a PLTE before its IDAT.
    const indexed = try readWpt("images/lcp-133x106.png");
    defer testing.allocator.free(indexed);
    const idat = chunkStart(indexed, "IDAT");
    try expectEveryCut("image/png", indexed, idat, idat + std.mem.readInt(u32, indexed[idat - 8 ..][0..4], .big), 5);
}

test "partial: an interlaced PNG keeps the passes its data reached" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    inline for (.{ "basi0g08.png", "basi6a16.png", "basi3p02.png" }) |name| {
        const bytes = try readWpt("css/css-ui/support/PTS/" ++ name);
        defer testing.allocator.free(bytes);
        const idat = chunkStart(bytes, "IDAT");
        var end = idat;
        // The last IDAT's data end: these files' image data is one run.
        var pos: usize = idat - 8;
        while (std.mem.eql(u8, bytes[pos + 4 ..][0..4], "IDAT")) {
            end = pos + 8 + std.mem.readInt(u32, bytes[pos..][0..4], .big);
            pos = end + 4;
        }
        try expectEveryCut("image/png", bytes, idat, end, 1);
    }
}

test "partial: a PNG cut right at its first IDAT chunk is a partial image with nothing decoded" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const smiley = try readWpt("images/smiley.png");
    defer testing.allocator.free(smiley);
    const image = try decode("image/png", smiley[0..131]);
    defer free(image);
    try testing.expectEqual(@as(u32, 300), image.width);
    try testing.expectEqual(@as(u32, 150), image.height);
    try testing.expectEqual(platform.ImageDecodeStatus.truncated, image.status);
    try testing.expect(image.empty);
    for (0..image.pixels.len) |i| try testing.expectEqual(@as(u8, 0), image.pixels.slice()[i]);
}

test "partial: an IDAT chunk whose CRC does not match keeps what its data decoded, corrupt" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // libpng and the png crate check a chunk's CRC at its end, after its
    // data has been decoded, and stop there; ImageIO ignores CRCs.
    const smiley = try readWpt("images/smiley.png");
    defer testing.allocator.free(smiley);
    const whole = try decode("image/png", smiley);
    defer free(whole);
    const bad_crc = try testing.allocator.dupe(u8, smiley);
    defer testing.allocator.free(bad_crc);
    bad_crc[123 + 8 + 1705] ^= 0x5a;
    const image = try decode("image/png", bad_crc);
    defer free(image);
    try testing.expectEqual(platform.ImageDecodeStatus.corrupt, image.status);
    try testing.expect(!image.empty);
    try testing.expectEqualSlices(u8, whole.pixels.slice(), image.pixels.slice());
    // PngSuite's xcsn0g01.png: an IDAT CRC mismatch.
    const xcsn = try readWpt("css/css-ui/support/PTS/xcsn0g01.png");
    defer testing.allocator.free(xcsn);
    const suite = try decode("image/png", xcsn);
    defer free(suite);
    try testing.expectEqual(platform.ImageDecodeStatus.corrupt, suite.status);
    try testing.expectEqual(@as(u32, 32), suite.width);
}

test "partial: WPT's undecodable.png - an empty IDAT - is a partial image with nothing decoded, corrupt" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // "a valid signature and IHDR followed by a zero-length IDAT. It has an
    // intrinsic size, so the image becomes available, but ... nothing that
    // can be decoded" (html/canvas/element/manual/imagebitmap/
    // createImageBitmap-invalid-args.html; all three browsers fire load).
    const bytes = try readWpt("images/undecodable.png");
    defer testing.allocator.free(bytes);
    const image = try decode("image/png", bytes);
    defer free(image);
    try testing.expectEqual(@as(u32, 100), image.width);
    try testing.expectEqual(@as(u32, 50), image.height);
    try testing.expectEqual(platform.ImageDecodeStatus.corrupt, image.status);
    try testing.expect(image.empty);
}

/// A PNG of `width` x `height` truecolour pixels whose image data is
/// `scanlines` (filter bytes included) in stored deflate blocks of at most
/// `block` bytes: damage can be put exactly where a test wants it. OWNED.
fn storedPng(width: u32, height: u32, scanlines: []const u8, block: usize) ![]u8 {
    const a = testing.allocator;
    var zlib: std.ArrayList(u8) = .empty;
    defer zlib.deinit(a);
    try zlib.appendSlice(a, &.{ 0x78, 0x01 });
    var at: usize = 0;
    while (true) {
        const n = @min(block, scanlines.len - at);
        const final = at + n == scanlines.len;
        try zlib.append(a, @intFromBool(final));
        var lens: [4]u8 = undefined;
        std.mem.writeInt(u16, lens[0..2], @intCast(n), .little);
        std.mem.writeInt(u16, lens[2..4], ~@as(u16, @intCast(n)), .little);
        try zlib.appendSlice(a, &lens);
        try zlib.appendSlice(a, scanlines[at..][0..n]);
        at += n;
        if (final) break;
    }
    var adler: [4]u8 = undefined;
    std.mem.writeInt(u32, &adler, std.hash.Adler32.hash(scanlines), .big);
    try zlib.appendSlice(a, &adler);

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    try out.appendSlice(a, "\x89PNG\r\n\x1a\n");
    var ihdr: [13]u8 = undefined;
    std.mem.writeInt(u32, ihdr[0..4], width, .big);
    std.mem.writeInt(u32, ihdr[4..8], height, .big);
    ihdr[8..13].* = .{ 8, 2, 0, 0, 0 };
    try appendChunk(&out, "IHDR", &ihdr);
    try appendChunk(&out, "IDAT", zlib.items);
    try appendChunk(&out, "IEND", "");
    return out.toOwnedSlice(a);
}

fn appendChunk(out: *std.ArrayList(u8), kind: *const [4]u8, data: []const u8) !void {
    var len: [4]u8 = undefined;
    std.mem.writeInt(u32, &len, @intCast(data.len), .big);
    try out.appendSlice(testing.allocator, &len);
    try out.appendSlice(testing.allocator, kind);
    try out.appendSlice(testing.allocator, data);
    var crc: std.hash.Crc32 = .init();
    crc.update(kind);
    crc.update(data);
    var tail: [4]u8 = undefined;
    std.mem.writeInt(u32, &tail, crc.final(), .big);
    try out.appendSlice(testing.allocator, &tail);
}

/// 4 x 6 truecolour rows, filter type 0, row `y` all (40 * y, 255, 0).
fn rows() [6 * 13]u8 {
    var out: [6 * 13]u8 = undefined;
    for (0..6) |y| {
        out[y * 13] = 0;
        for (0..4) |x| out[y * 13 + 1 + x * 3 ..][0..3].* = .{ @intCast(40 * y), 255, 0 };
    }
    return out;
}

/// Rows 0 to `decoded` - 1 are decoded, the rest transparent black.
fn expectRows(image: platform.DecodedImage, decoded: usize) !void {
    try testing.expectEqual(@as(u32, 4), image.width);
    try testing.expectEqual(@as(u32, 6), image.height);
    for (0..6) |y| for (0..4) |x| {
        const pixel = image.pixels.slice()[(y * 4 + x) * 4 ..][0..4];
        const expected: [4]u8 = if (y < decoded) .{ @intCast(40 * y), 255, 0, 255 } else clear;
        testing.expectEqualSlices(u8, &expected, pixel) catch |err| {
            std.debug.print("row {d} pixel {d}\n", .{ y, x });
            return err;
        };
    };
    try testing.expectEqual(decoded == 0, image.empty);
}

test "partial: invalid PNG image data after the dimensions keeps the rows before it, corrupt" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    var data = rows();
    {
        // The built image itself is whole.
        const bytes = try storedPng(4, 6, &data, 1000);
        defer testing.allocator.free(bytes);
        const image = try decode("image/png", bytes);
        defer free(image);
        try testing.expectEqual(platform.ImageDecodeStatus.complete, image.status);
        try expectRows(image, 6);
    }
    {
        // Row 3's filter type is 5 (9.2: only 0 to 4).
        data[3 * 13] = 5;
        defer data[3 * 13] = 0;
        const bytes = try storedPng(4, 6, &data, 1000);
        defer testing.allocator.free(bytes);
        const image = try decode("image/png", bytes);
        defer free(image);
        try testing.expectEqual(platform.ImageDecodeStatus.corrupt, image.status);
        try expectRows(image, 3);
    }
    {
        // The second stored block's LEN and NLEN disagree: a broken zlib
        // stream after the first 2 rows (26 bytes).
        const bytes = try storedPng(4, 6, &data, 26);
        defer testing.allocator.free(bytes);
        const broken = try testing.allocator.dupe(u8, bytes);
        defer testing.allocator.free(broken);
        // The IDAT's data starts at 8 + 25 + 8; the zlib header is 2 bytes,
        // the first block 5 + 26.
        const second = 8 + 25 + 8 + 2 + 5 + 26;
        broken[second + 3] ^= 0xff;
        try fixCrc(broken, "IDAT");
        const image = try decode("image/png", broken);
        defer free(image);
        try testing.expectEqual(platform.ImageDecodeStatus.corrupt, image.status);
        try expectRows(image, 2);
    }
    {
        // Short image data: the zlib stream ends properly, after 4 rows.
        const bytes = try storedPng(4, 6, data[0 .. 4 * 13], 1000);
        defer testing.allocator.free(bytes);
        const image = try decode("image/png", bytes);
        defer free(image);
        try testing.expectEqual(platform.ImageDecodeStatus.corrupt, image.status);
        try expectRows(image, 4);
    }
    {
        // A row's data begun but not ended is not drawn (libpng hands a
        // row over whole): the stream ends 5 bytes into row 2.
        const bytes = try storedPng(4, 6, data[0 .. 2 * 13 + 5], 1000);
        defer testing.allocator.free(bytes);
        const image = try decode("image/png", bytes);
        defer free(image);
        try testing.expectEqual(platform.ImageDecodeStatus.corrupt, image.status);
        try expectRows(image, 2);
    }
}

test "partial: a truncated PNG cut inside a stored block keeps the whole rows before the cut" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const data = rows();
    const bytes = try storedPng(4, 6, &data, 1000);
    defer testing.allocator.free(bytes);
    // The scanlines start 8 + 25 + 8 + 2 + 5 bytes in.
    const start = 8 + 25 + 8 + 2 + 5;
    for (0..6) |row| {
        const image = try decode("image/png", bytes[0 .. start + row * 13 + 12]);
        defer free(image);
        try testing.expectEqual(platform.ImageDecodeStatus.truncated, image.status);
        try expectRows(image, row);
    }
}

test "partial: a bad chunk after the image data leaves every pixel, corrupt" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const data = rows();
    const bytes = try storedPng(4, 6, &data, 1000);
    defer testing.allocator.free(bytes);
    // IEND's CRC broken: a critical chunk with a CRC mismatch.
    const bad_iend = try testing.allocator.dupe(u8, bytes);
    defer testing.allocator.free(bad_iend);
    bad_iend[bad_iend.len - 1] ^= 0xff;
    const image = try decode("image/png", bad_iend);
    defer free(image);
    try testing.expectEqual(platform.ImageDecodeStatus.corrupt, image.status);
    try expectRows(image, 6);
}

/// Recompute the CRC of the first chunk of `kind` in place.
fn fixCrc(bytes: []u8, kind: []const u8) !void {
    const start = chunkStart(bytes, kind);
    const len = std.mem.readInt(u32, bytes[start - 8 ..][0..4], .big);
    var crc: std.hash.Crc32 = .init();
    crc.update(bytes[start - 4 .. start + len]);
    std.mem.writeInt(u32, bytes[start + len ..][0..4], crc.final(), .big);
}

// ---------------------------------------------------------------------------
// BMP
// ---------------------------------------------------------------------------

test "partial: a BMP has dimensions after its headers, and keeps the rows its pixel data reached" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // t.bmp: 100 x 100, 24 bits, bottom-up, pixel data at 54 (300 bytes a
    // row, no padding). The bottom rows come first.
    const t = try readWpt("dom/nodes/Document-contentType/resources/t.bmp");
    defer testing.allocator.free(t);
    try expectEveryCut("image/bmp", t, 54, t.len, 97);
    // pattern-srgb.bmp: 20 x 20, 32 bits, BI_BITFIELDS in a V5 header,
    // pixel data at 138.
    const pattern = try readWpt("html/canvas/element/manual/wide-gamut-canvas/resources/pattern-srgb.bmp");
    defer testing.allocator.free(pattern);
    try expectEveryCut("image/bmp", pattern, 138, pattern.len, 3);
}

// ---------------------------------------------------------------------------
// GIF
// ---------------------------------------------------------------------------

test "partial: a GIF has dimensions from its first image descriptor, and keeps the pixels its data reached" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // anim-gr.gif: 100 x 50; its first image descriptor at 46 (10 bytes);
    // the first frame's LZW data from 56 to its block terminator at 135.
    // ImageIO needs the whole first frame before it has a size; Gecko posts
    // the size at the descriptor (BeginGIF), as Chrome's Wuffs knows it.
    const anim = try readWpt("images/anim-gr.gif");
    defer testing.allocator.free(anim);
    try expectEveryCut("image/gif", anim, 56, 136, 1);
    // fail.gif: 320 x 240, a 768-byte local colour table after its
    // descriptor at 21; LZW data from 799 to 24,478.
    const fail = try readWpt("images/fail.gif");
    defer testing.allocator.free(fail);
    try expectEveryCut("image/gif", fail, 31, 24479, 61);
}
