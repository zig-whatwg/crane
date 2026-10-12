//! The testing platform's BMP decoder (decision 19a): Windows and OS/2
//! bitmaps to RGBA8, in Zig. There is no web specification for BMP; the
//! formats are Microsoft's (BITMAPCOREHEADER, BITMAPINFOHEADER,
//! BITMAPV4HEADER, BITMAPV5HEADER and the V2/V3 headers between them) and
//! OS/2's, and what a browser accepts is the browsers' choice. This follows
//! Blink's BMPImageReader
//! (third_party/blink/renderer/platform/image-decoders/bmp/bmp_image_reader.cc,
//! read 2026-10-12) - its design, not its code:
//!
//! - file types "BM", and "BA" (a bitmap array: its first bitmap);
//! - info headers of 12 bytes (OS/2 1.x), 40, 52, 56, 108 and 124 (Windows
//!   V3, V2, V3 with alpha, V4, V5), and OS/2 2.x's (16 to 64 bytes, a
//!   multiple of 4, or 42 or 46) - the extra fields ignored;
//! - 1, 2, 4 and 8 bits per pixel through a colour table (an index past its
//!   end is opaque black), 16, 24 and 32 through bit masks: BI_RGB's 5-5-5
//!   and 8-8-8 defaults, BI_BITFIELDS and BI_ALPHABITFIELDS masks, each
//!   contiguous and not overlapping, wider than 8 bits read from their top 8,
//!   narrower ones rescaled to 8 bits;
//! - BI_RLE8, BI_RLE4 and OS/2's RLE24: encoded and absolute runs, end of
//!   line, delta and end of bitmap; pixels a run skips stay transparent
//!   black; data after the image or a missing end of bitmap is corrupt;
//! - a PNG inside a BMP (BI_PNG) through png.zig; a JPEG inside (BI_JPEG) is
//!   `UnsupportedFormat`;
//! - top-down bitmaps (a negative height, Windows V3 and later);
//! - alpha only from an alpha mask a V3+ header or BI_ALPHABITFIELDS gives;
//!   a Windows V3 bitmap's fourth byte is never alpha (Blink: "we match other
//!   browsers and ignore alpha in Windows V3 BMPs except inside ICO files").
//!   An alpha channel that is all zero is opaque: pixels decode opaque until
//!   a non-zero alpha appears, and then every pixel decoded so far is reset
//!   to transparent black (Blink's seen_non_zero_alpha_pixel_);
//! - rejected as Blink rejects them: a width or height of 0, or of 65536 or
//!   more; planes or bit counts a header type does not allow; a header that
//!   overruns the pixel data offset; bit masks or a colour table the data
//!   does not hold;
//! - the dimensions are known once the headers, the bit masks and the colour
//!   table are read - where Chrome's BMP codec (Skia's SkBmpRustDecoder over
//!   the image crate, whose metadata read takes the palette) knows them, and
//!   ImageIO, probed on macOS 27, wants even a byte of pixel data; Gecko's
//!   nsBMPDecoder posts the size before the colour table. Pixel data that
//!   ends before the image does, or that is invalid (an RLE run past the
//!   image or its row), leaves a partial image (the protocol's
//!   ImageDecodeStatus): the pixels decoded before that point, the rest
//!   transparent black - a row of uncompressed data only when the data holds
//!   all of it;
//! - no colour management: the V4/V5 colour space fields and an embedded
//!   ICC profile are ignored (decision 19).

const std = @import("std");
const platform = @import("platform");
const png = @import("png.zig");

const ImageError = platform.ImageError;

const file_header_len = 14;

const Compression = enum(u32) {
    rgb = 0,
    rle8 = 1,
    rle4 = 2,
    bitfields = 3,
    jpeg = 4,
    png = 5,
    alphabitfields = 6,
    /// OS/2 2.x: compression 4 at 24 bits per pixel.
    rle24 = 0xffff_0001,
};

/// The parts of the info header this decoder uses.
const Info = struct {
    size: u32,
    width: u32,
    height: u32,
    top_down: bool,
    bit_count: u16,
    compression: Compression,
    colors_used: u32,
    os2_1x: bool,
    os2_2x: bool,
    /// R, G, B, A masks read from the header (V2+), if it has them.
    masks: [4]u32 = .{ 0, 0, 0, 0 },

    fn hasAlphaMaskInHeader(self: Info) bool {
        return (self.size == 56 and !self.os2_2x) or self.size == 108 or self.size == 124;
    }

    fn hasRgbMasksInHeader(self: Info) bool {
        return (self.size == 52 and !self.os2_2x) or self.hasAlphaMaskInHeader();
    }
};

fn readU16(bytes: []const u8, at: usize) u16 {
    return std.mem.readInt(u16, bytes[at..][0..2], .little);
}

fn readU32(bytes: []const u8, at: usize) u32 {
    return std.mem.readInt(u32, bytes[at..][0..4], .little);
}

/// Whether `bytes` begins with a BMP file type this decoder reads.
pub fn hasSignature(bytes: []const u8) bool {
    return bytes.len >= 2 and (std.mem.eql(u8, bytes[0..2], "BM") or std.mem.eql(u8, bytes[0..2], "BA"));
}

/// Decode `bytes`, a whole BMP file. The pixels are OWNED by `allocator`.
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8, limits: platform.ImageLimits) ImageError!platform.DecodedImage {
    // The file header: "BM", or "BA" - a bitmap array, whose first entry's
    // own file header follows.
    var start: usize = 0;
    if (bytes.len < file_header_len) return error.Corrupt;
    if (std.mem.eql(u8, bytes[0..2], "BA")) {
        start = file_header_len;
        if (bytes.len < start + file_header_len) return error.Corrupt;
    }
    if (!std.mem.eql(u8, bytes[start..][0..2], "BM")) return error.Corrupt;
    // The pixel data's offset from the file's start; 0 = right after the
    // colour table or masks.
    const data_offset: usize = readU32(bytes, start + 10);
    const header_offset = start + file_header_len;

    var info = try readInfoHeader(bytes, header_offset, data_offset);
    try validate(&info);
    if (info.width > limits.max_dimension or info.height > limits.max_dimension or
        @as(u64, info.width) * info.height > limits.max_pixels) return error.TooLarge;

    const header_end = header_offset + info.size;
    switch (info.compression) {
        .png => {
            if (data_offset == 0 or data_offset > bytes.len) return error.Corrupt;
            const image = png.decode(allocator, bytes[data_offset..], limits) catch |err| return switch (err) {
                error.OutOfMemory, error.TooLarge => err,
                else => error.Corrupt,
            };
            // The embedded image is the bitmap: its size is the header's.
            if (image.width != info.width or image.height != info.height) {
                allocator.free(image.pixels.slice());
                return error.Corrupt;
            }
            return image;
        },
        .jpeg => return error.UnsupportedFormat,
        else => {},
    }

    var cursor: usize = header_end;
    var masks: Masks = undefined;
    var palette: []const u8 = &.{};
    const palette_entry_len: usize = if (info.os2_1x) 3 else 4;
    if (info.bit_count >= 16) {
        masks = try readMasks(bytes, &info, &cursor, data_offset);
    } else {
        // The colour table, cut short where the pixel data begins (some
        // BMPs do not have a whole one).
        var colors: usize = info.colors_used;
        if (data_offset != 0 and data_offset < header_end + colors * palette_entry_len) {
            colors = (data_offset - header_end) / palette_entry_len;
        }
        const table_len = colors * palette_entry_len;
        if (bytes.len < cursor or bytes.len - cursor < table_len) return error.Corrupt;
        palette = bytes[cursor..][0..table_len];
        cursor += table_len;
    }
    if (data_offset != 0) cursor = data_offset;

    const pixel_len = @as(usize, info.width) * info.height * 4;
    const pixels = allocator.alloc(u8, pixel_len) catch return error.OutOfMemory;
    errdefer allocator.free(pixels);
    // Pixels nothing writes (an RLE skip, or data that ends) are
    // transparent black.
    @memset(pixels, 0);

    var writer: PixelWriter = .{
        .pixels = pixels,
        .info = &info,
        .palette = palette,
        .palette_entry_len = palette_entry_len,
        .masks = if (info.bit_count >= 16) masks else undefined,
        .y = if (info.top_down) 0 else @intCast(info.height - 1),
    };
    // From here the dimensions are known: the pixel data's failures leave a
    // partial image.
    const result: PixelError!void = if (cursor > bytes.len)
        error.Truncated
    else switch (info.compression) {
        .rle8, .rle4, .rle24 => writer.decodeRle(bytes, cursor),
        else => writer.decodeRows(bytes, cursor),
    };
    const status: platform.ImageDecodeStatus = if (result) |_| .complete else |err| switch (err) {
        error.Truncated => .truncated,
        error.Invalid => .corrupt,
    };
    return .{
        .width = info.width,
        .height = info.height,
        .pixels = platform.Bytes.from(pixels),
        .status = status,
        .empty = status != .complete and !writer.wrote,
    };
}

/// The info header at `at`: its size decides its type.
fn readInfoHeader(bytes: []const u8, at: usize, data_offset: usize) ImageError!Info {
    if (bytes.len < at + 4) return error.Corrupt;
    const size = readU32(bytes, at);
    // The header must not overflow or overrun the pixel data.
    if (size > bytes.len - at) return error.Corrupt;
    if (data_offset != 0 and data_offset < at + size) return error.Corrupt;

    var info: Info = .{
        .size = size,
        .width = 0,
        .height = 0,
        .top_down = false,
        .bit_count = 0,
        .compression = .rgb,
        .colors_used = 0,
        .os2_1x = false,
        .os2_2x = false,
    };
    if (size == 12) {
        // OS/2 1.x and Windows 2.x: 16-bit width and height.
        info.os2_1x = true;
        info.width = readU16(bytes, at + 4);
        info.height = readU16(bytes, at + 6);
        // The plane count is not checked: no browser does.
        info.bit_count = readU16(bytes, at + 10);
        return info;
    }
    if (size == 40 or size == 52 or size == 56 or size == 108 or size == 124) {
        // Windows V3 and later.
    } else if (size >= 16 and size <= 64 and (size % 4 == 0 or size == 42 or size == 46)) {
        info.os2_2x = true;
    } else {
        return error.Corrupt;
    }

    const width: i32 = @bitCast(readU32(bytes, at + 4));
    const height: i32 = @bitCast(readU32(bytes, at + 8));
    if (width <= 0 or height == 0 or height == std.math.minInt(i32)) return error.Corrupt;
    info.width = @intCast(width);
    info.top_down = height < 0;
    info.height = @intCast(@abs(height));
    info.bit_count = readU16(bytes, at + 14);
    if (size >= 20) {
        const compression = readU32(bytes, at + 16);
        if (compression == 4 and info.bit_count == 24) {
            // OS/2 2.x's RLE24 shares Windows' BI_JPEG value.
            info.compression = .rle24;
            info.os2_2x = true;
        } else if (compression == 3 and info.bit_count == 1) {
            // OS/2 2.x's 1D Huffman, which Blink and Gecko do not decode.
            return error.Corrupt;
        } else {
            info.compression = std.enums.fromInt(Compression, compression) orelse return error.Corrupt;
        }
    }
    if (size >= 36) info.colors_used = readU32(bytes, at + 32);
    if (info.hasRgbMasksInHeader()) {
        info.masks[0] = readU32(bytes, at + 40);
        info.masks[1] = readU32(bytes, at + 44);
        info.masks[2] = readU32(bytes, at + 48);
    }
    if (info.hasAlphaMaskInHeader()) info.masks[3] = readU32(bytes, at + 52);
    return info;
}

/// Blink's IsInfoHeaderValid, then its fix-ups of the colour count and the
/// RLE bit counts.
fn validate(info: *Info) ImageError!void {
    if (info.width == 0 or info.height == 0) return error.Corrupt;
    // Top-down bitmaps are Windows V3+ only.
    if (info.top_down and (info.os2_1x or info.os2_2x)) return error.Corrupt;
    switch (info.bit_count) {
        1, 4, 8, 24 => {},
        // Windows V3+ only: 0 (an embedded JPEG or PNG), 2, 16, 32.
        0, 2, 16, 32 => if (info.os2_1x or info.os2_2x) return error.Corrupt,
        else => return error.Corrupt,
    }
    switch (info.compression) {
        .rgb => if (info.bit_count == 0) return error.Corrupt,
        // A too-low bit count with RLE is corrected below.
        .rle8 => if (info.bit_count == 0 or info.bit_count > 8) return error.Corrupt,
        .rle4 => if (info.bit_count == 0 or info.bit_count > 4) return error.Corrupt,
        .bitfields, .alphabitfields => if (info.os2_1x or info.os2_2x or (info.bit_count != 16 and info.bit_count != 32)) return error.Corrupt,
        .jpeg, .png => if (info.os2_1x or info.os2_2x or info.bit_count != 0) return error.Corrupt,
        .rle24 => if (!info.os2_2x or info.bit_count != 24) return error.Corrupt,
    }
    // Larger bitmaps are not decoded (Blink: "Bitmaps larger than 2^16
    // pixels in either dimension").
    if (info.width >= 1 << 16 or info.height >= 1 << 16) return error.Corrupt;

    if (info.bit_count < 16) {
        // 0 colours used, or too many, means all of them.
        const max_colors = @as(u32, 1) << @intCast(info.bit_count);
        if (info.colors_used == 0 or info.colors_used > max_colors) info.colors_used = max_colors;
    }
    switch (info.compression) {
        .rle8 => info.bit_count = 8,
        .rle4 => info.bit_count = 4,
        else => {},
    }
}

/// Where a component sits in a pixel, and how it becomes 8 bits.
const Mask = struct {
    mask: u32 = 0,
    shift: u5 = 0,
    /// Bits below 8: the component is rescaled from this many bits.
    bits: u4 = 0,

    fn component(self: Mask, pixel: u32) u8 {
        const value = (pixel & self.mask) >> self.shift;
        if (self.bits == 0) return @truncate(value);
        // floor(v * 255 / (2^bits - 1) + 0.5).
        const max: u32 = (@as(u32, 1) << self.bits) - 1;
        return @intCast((value * 255 + max / 2) / max);
    }
};

const Masks = [4]Mask;

/// The R, G, B, A masks of a 16-, 24- or 32-bit bitmap (Blink's
/// ProcessBitmasks), reading BI_BITFIELDS masks that follow a 40-byte header.
fn readMasks(bytes: []const u8, info: *Info, cursor: *usize, data_offset: usize) ImageError!Masks {
    var raw = info.masks;
    if (info.compression != .bitfields and info.compression != .alphabitfields) {
        // BI_RGB: 16 bits are x1r5g5b5, 24 and 32 are (x8)r8g8b8; a V4+
        // header's RGB masks are ignored.
        const bits: u5 = if (info.bit_count == 16) 5 else 8;
        for (0..3) |i| {
            const high: u5 = @intCast(@as(u32, bits) * (3 - i));
            const low: u5 = @intCast(@as(u32, bits) * (2 - i));
            raw[i] = ((@as(u32, 1) << high) - 1) ^ ((@as(u32, 1) << low) - 1);
        }
    } else if (!info.hasRgbMasksInHeader()) {
        const with_alpha = info.compression == .alphabitfields;
        const len: usize = if (with_alpha) 16 else 12;
        const end = cursor.* + len;
        if (data_offset != 0 and data_offset < end) return error.Corrupt;
        if (bytes.len < end) return error.Corrupt;
        raw[0] = readU32(bytes, cursor.*);
        raw[1] = readU32(bytes, cursor.* + 4);
        raw[2] = readU32(bytes, cursor.* + 8);
        if (with_alpha) raw[3] = readU32(bytes, cursor.* + 12);
        cursor.* = end;
    }
    // Alpha only from a header's alpha mask or BI_ALPHABITFIELDS.
    if (!info.hasAlphaMaskInHeader() and info.compression != .alphabitfields) raw[3] = 0;

    // Bits a pixel does not have (a 24-bit image's "alpha") are dropped.
    if (info.bit_count < 32) {
        for (&raw) |*mask| mask.* &= (@as(u32, 1) << @intCast(info.bit_count)) - 1;
    }
    var masks: Masks = .{ .{}, .{}, .{}, .{} };
    for (raw, 0..) |mask, i| {
        if (mask == 0) continue;
        for (raw[0..i]) |other| if (mask & other != 0) return error.Corrupt;
        const shift: u5 = @intCast(@ctz(mask));
        const width: u6 = @intCast(@popCount(mask));
        // Contiguous: all the set bits in one run.
        if ((mask >> shift) != (@as(u64, 1) << width) - 1) return error.Corrupt;
        // With 8 or more bits, the top 8 are the component; fewer are
        // rescaled.
        masks[i] = if (width >= 8)
            .{ .mask = mask, .shift = @intCast(shift + (width - 8)) }
        else
            .{ .mask = mask, .shift = shift, .bits = @intCast(width) };
    }
    return masks;
}

/// How the pixel data failed: it ended before the image did, or it was
/// invalid.
const PixelError = error{ Truncated, Invalid };

const PixelWriter = struct {
    pixels: []u8,
    info: *const Info,
    palette: []const u8,
    palette_entry_len: usize,
    masks: Masks,
    x: u32 = 0,
    /// The row being written; past the image when it is `height` (top-down)
    /// or -1 (bottom-up).
    y: i64,
    seen_zero_alpha: bool = false,
    seen_non_zero_alpha: bool = false,
    /// Whether any pixel has been decoded.
    wrote: bool = false,

    fn pastEnd(self: *const PixelWriter, rows: u32) bool {
        return if (self.info.top_down) self.y + rows >= self.info.height else self.y - rows < 0;
    }

    fn nextRow(self: *PixelWriter, rows: u32) void {
        self.x = 0;
        if (self.info.top_down) self.y += rows else self.y -= rows;
    }

    fn set(self: *PixelWriter, rgba: [4]u8) void {
        const at = (@as(usize, @intCast(self.y)) * self.info.width + self.x) * 4;
        self.pixels[at..][0..4].* = rgba;
        self.x += 1;
        self.wrote = true;
    }

    fn setIndex(self: *PixelWriter, index: usize) void {
        const at = index * self.palette_entry_len;
        if (at + 3 > self.palette.len) {
            // An index past the colour table is black.
            self.set(.{ 0, 0, 0, 255 });
            return;
        }
        // Entries are blue, green, red (and a reserved byte).
        self.set(.{ self.palette[at + 2], self.palette[at + 1], self.palette[at], 255 });
    }

    fn setMasked(self: *PixelWriter, pixel: u32) void {
        var alpha: u8 = if (self.masks[3].mask != 0) self.masks[3].component(pixel) else 255;
        // An all-zero alpha channel is unused: opaque until a non-zero alpha
        // shows the channel is real, and then what was decoded is reset.
        if (!self.seen_non_zero_alpha and alpha == 0) {
            self.seen_zero_alpha = true;
            alpha = 255;
        } else if (!self.seen_non_zero_alpha) {
            self.seen_non_zero_alpha = true;
            if (self.seen_zero_alpha) @memset(self.pixels, 0);
        }
        self.set(.{ self.masks[0].component(pixel), self.masks[1].component(pixel), self.masks[2].component(pixel), alpha });
    }

    /// `count` pixels of the current row from uncompressed data at `at`;
    /// the number of bytes they take, unpadded.
    fn writePixels(self: *PixelWriter, bytes: []const u8, at: usize, count: u32) PixelError!usize {
        if (self.x + count > self.info.width) return error.Invalid;
        const bit_count = self.info.bit_count;
        const len: usize = if (bit_count < 16) (@as(usize, count) * bit_count + 7) / 8 else @as(usize, count) * (bit_count / 8);
        if (at > bytes.len or bytes.len - at < len) return error.Truncated;
        const data = bytes[at..][0..len];
        if (bit_count < 16) {
            // Packed most significant bits first.
            const per_byte = 8 / bit_count;
            for (0..count) |i| {
                const byte = data[i / per_byte];
                const shift: u3 = @intCast(8 - bit_count * (i % per_byte + 1));
                const mask: u16 = (@as(u16, 1) << @intCast(bit_count)) - 1;
                const index = (byte >> shift) & mask;
                self.setIndex(index);
            }
        } else {
            const step = bit_count / 8;
            for (0..count) |i| {
                const pixel: u32 = switch (step) {
                    2 => readU16(data, i * 2),
                    3 => @as(u32, data[i * 3]) | @as(u32, data[i * 3 + 1]) << 8 | @as(u32, data[i * 3 + 2]) << 16,
                    else => readU32(data, i * 4),
                };
                self.setMasked(pixel);
            }
        }
        return len;
    }

    /// Uncompressed rows, each padded to 4 bytes - the last row's padding
    /// not needed: every pixel is decoded without it.
    fn decodeRows(self: *PixelWriter, bytes: []const u8, start: usize) PixelError!void {
        var at = start;
        while (!self.pastEnd(0)) {
            const len = try self.writePixels(bytes, at, self.info.width);
            at += (len + 3) & ~@as(usize, 3);
            self.nextRow(1);
        }
    }

    /// RLE8, RLE4 and RLE24 (Blink's ProcessRLEData): a stream of entries
    /// until the end of bitmap.
    fn decodeRle(self: *PixelWriter, bytes: []const u8, start: usize) PixelError!void {
        var at = start;
        const width = self.info.width;
        while (true) {
            if (bytes.len - at < 2) return error.Truncated;
            const count = bytes[at];
            const code = bytes[at + 1];
            const past_end = self.pastEnd(0);
            // Only the end of bitmap may follow the image's last row.
            if ((count != 0 or code != 1) and past_end) return error.Invalid;
            if (count == 0) switch (code) {
                // End of line: the rest of the row is skipped.
                0 => {
                    self.nextRow(1);
                    at += 2;
                },
                // End of bitmap.
                1 => return,
                // Delta: skip dx pixels right and dy rows on.
                2 => {
                    if (bytes.len - at < 4) return error.Truncated;
                    const dx = bytes[at + 2];
                    const dy = bytes[at + 3];
                    if (self.x + dx > width or self.pastEnd(dy)) return error.Invalid;
                    const x = self.x + dx;
                    if (self.info.top_down) self.y += dy else self.y -= dy;
                    self.x = x;
                    at += 4;
                },
                // Absolute mode: `code` pixels as uncompressed data,
                // padded to 16 bits.
                else => {
                    at += 2;
                    const len = try self.writePixels(bytes, at, code);
                    const padded = (len + 1) & ~@as(usize, 1);
                    if (bytes.len - at < padded) return error.Truncated;
                    at += padded;
                },
            } else {
                // Encoded mode: `count` pixels of one colour (RLE4: two
                // alternating indexes); pixels past the row's end are
                // dropped.
                const end_x = @min(self.x + count, width);
                if (self.info.compression == .rle24) {
                    if (bytes.len - at < 4) return error.Truncated;
                    const rgba: [4]u8 = .{ bytes[at + 3], bytes[at + 2], code, 255 };
                    while (self.x < end_x) self.set(rgba);
                    at += 4;
                } else {
                    const indexes: [2]u8 = if (self.info.compression == .rle4) .{ code >> 4, code & 0xf } else .{ code, code };
                    var which: usize = 0;
                    while (self.x < end_x) : (which ^= 1) self.setIndex(indexes[which]);
                    at += 2;
                }
            }
        }
    }
};
