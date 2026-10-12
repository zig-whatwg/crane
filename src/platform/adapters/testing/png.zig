//! The testing platform's PNG decoder (decision 19): PNG datastreams to
//! RGBA8, in Zig - its zlib data through inflate.zig, which stops exactly
//! where truncated data does - so the WPT runner's results do not depend on
//! the machine's image libraries. W3C PNG (Third Edition),
//! specs/w3c/png-3.md, as a decoder that extracts the image:
//!
//! - every colour type and bit depth of Table 11.1, Adam7 interlacing (8.2),
//!   the five filter types (9.2-9.4), tRNS (11.3.1.1);
//! - the static image only: of an APNG, the default image (the IDAT data);
//!   acTL, fcTL and fdAT are ancillary and skipped;
//! - no colour management: gAMA, cHRM, sRGB, iCCP, cICP, mDCV, cLLI and sBIT
//!   are skipped, and samples are delivered as stored (decision 19);
//! - 16-bit samples rescaled to 8 by 13.12's "most accurate" equation,
//!   floor(v * 255 / 65535 + 0.5), after tRNS is compared exactly (13.12);
//!   sub-8-bit greys by the same equation (v * 255 / (2^depth - 1));
//! - errors as 13.1 says, up to the image's dimensions: a signature or CRC
//!   mismatch on a critical chunk, an unknown critical chunk, a bad IHDR, a
//!   missing PLTE for an indexed image, a datastream that ends before its
//!   image data begins, are fatal (`Corrupt`); an ancillary chunk with a bad
//!   CRC, misplaced or of the wrong length is discarded; an out-of-range
//!   palette index is opaque black (13.1, now required); a missing IEND is
//!   tolerated once the image data is complete;
//! - the dimensions are known once the first IDAT chunk begins - its length
//!   and type read - as the browsers know them (libpng calls its info
//!   callback there, which is where Gecko's nsPNGDecoder posts the size; the
//!   png crate's read_info, under Chrome's SkPngRustCodec, stops there; and
//!   ImageIO, probed on macOS 27, has no size for smiley.png cut before it
//!   and one cut 8 bytes into it). From there nothing is fatal: data that
//!   ends early or goes bad leaves a partial image (the protocol's
//!   ImageDecodeStatus) - the whole scanlines decoded before that point, the
//!   rest transparent black - as libpng, which hands a row over only when it
//!   is whole, and the png crate decode it. An IDAT chunk's data is decoded
//!   as it arrives, before its CRC (streaming, as both do): a chunk cut short
//!   is decoded as far as it goes, and an IDAT whose CRC does not match is
//!   decoded and then ends the datastream, corrupt. A bad filter type, a
//!   zlib stream that is invalid or holds too few scanlines, and an invalid
//!   chunk after the image data are corrupt; a datastream that ends before
//!   the image data does is truncated.

const std = @import("std");
const platform = @import("platform");
const inflate = @import("inflate.zig");

const ImageError = platform.ImageError;

/// PNG 5.2.
const signature = "\x89PNG\r\n\x1a\n";

/// PNG 6.1, Table 11.1.
const ColorType = enum(u8) {
    greyscale = 0,
    truecolor = 2,
    indexed = 3,
    greyscale_alpha = 4,
    truecolor_alpha = 6,

    fn channels(self: ColorType) u8 {
        return switch (self) {
            .greyscale, .indexed => 1,
            .greyscale_alpha => 2,
            .truecolor => 3,
            .truecolor_alpha => 4,
        };
    }

    /// The bit depths Table 11.1 allows for the colour type.
    fn allows(self: ColorType, depth: u8) bool {
        return switch (self) {
            .greyscale => depth == 1 or depth == 2 or depth == 4 or depth == 8 or depth == 16,
            .indexed => depth == 1 or depth == 2 or depth == 4 or depth == 8,
            .truecolor, .greyscale_alpha, .truecolor_alpha => depth == 8 or depth == 16,
        };
    }
};

/// IHDR (11.2.1).
const Header = struct {
    width: u32,
    height: u32,
    depth: u8,
    color: ColorType,
    interlaced: bool,
};

/// A pass of the image: its origin and spacing in the reference image (8.2).
const Pass = struct { x0: u32, y0: u32, dx: u32, dy: u32 };

const adam7 = [7]Pass{
    .{ .x0 = 0, .y0 = 0, .dx = 8, .dy = 8 },
    .{ .x0 = 4, .y0 = 0, .dx = 8, .dy = 8 },
    .{ .x0 = 0, .y0 = 4, .dx = 4, .dy = 8 },
    .{ .x0 = 2, .y0 = 0, .dx = 4, .dy = 4 },
    .{ .x0 = 0, .y0 = 2, .dx = 2, .dy = 4 },
    .{ .x0 = 1, .y0 = 0, .dx = 2, .dy = 2 },
    .{ .x0 = 0, .y0 = 1, .dx = 1, .dy = 2 },
};
const no_interlace = [1]Pass{.{ .x0 = 0, .y0 = 0, .dx = 1, .dy = 1 }};

/// The pixels of `pass` across and down an image of `header`'s size.
fn passSize(header: Header, pass: Pass) struct { u32, u32 } {
    const w = if (header.width > pass.x0) (header.width - pass.x0 + pass.dx - 1) / pass.dx else 0;
    const h = if (header.height > pass.y0) (header.height - pass.y0 + pass.dy - 1) / pass.dy else 0;
    return .{ w, h };
}

/// The bytes of one scanline of `width` pixels, without its filter byte (7.2).
fn rowBytes(header: Header, width: u32) u64 {
    return (@as(u64, width) * header.color.channels() * header.depth + 7) / 8;
}

/// Whether `data` begins with the PNG signature: the MIME Sniffing signature
/// is Crane's to check; this is the decoder's own first check (13.1 item 1).
pub fn hasSignature(data: []const u8) bool {
    return data.len >= signature.len and std.mem.eql(u8, data[0..signature.len], signature);
}

/// Decode `bytes`, a PNG datastream - whole, or as much of one as the fetch
/// delivered. The pixels are OWNED by `allocator`.
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8, limits: platform.ImageLimits) ImageError!platform.DecodedImage {
    if (!hasSignature(bytes)) return error.Corrupt;

    var header: ?Header = null;
    var palette: ?[]const u8 = null;
    var transparency: ?[]const u8 = null;
    var image_data: std.ArrayList(u8) = .empty;
    defer image_data.deinit(allocator);
    // IDAT chunks are consecutive (5.6); the run ends at the next chunk.
    var idat_state: enum { before, in_run, after } = .before;
    // How the chunk stream ended once the image data had begun (before
    // that, an error is fatal): at IEND or the data's end between chunks
    // (null), with the data ending inside a chunk, or at an invalid chunk.
    var ended: ?platform.ImageDecodeStatus = null;
    var saw_iend = false;

    var pos: usize = signature.len;
    chunks: while (bytes.len - pos >= 8) {
        // 5.3: length, type, data, CRC.
        const length = std.mem.readInt(u32, bytes[pos..][0..4], .big);
        const kind = bytes[pos + 4 ..][0..4];
        const valid_kind = for (kind) |c| {
            if (!std.ascii.isAlphabetic(c)) break false;
        } else true;
        if (length > std.math.maxInt(i32) or !valid_kind) {
            if (idat_state == .before) return error.Corrupt;
            ended = .corrupt;
            break;
        }
        const is_idat = std.mem.eql(u8, kind, "IDAT");
        // 5.4: bit 5 of the first byte clear means critical.
        const critical = kind[0] & 0x20 == 0;
        if (bytes.len - pos - 8 < @as(usize, length) + 4) {
            // A chunk cut short ends the datastream (an unexpected end,
            // 13.1). Before the image data, what came before decides; an
            // IDAT's data is decoded as far as it goes, as a streaming
            // decoder decodes it before its CRC arrives.
            if (is_idat and idat_state != .after) {
                const h = header orelse return error.Corrupt;
                if (h.color == .indexed and palette == null) return error.Corrupt;
                const available = bytes[pos + 8 ..][0..@min(length, bytes.len - pos - 8)];
                image_data.appendSlice(allocator, available) catch return error.OutOfMemory;
                idat_state = .in_run;
            }
            if (idat_state != .before) ended = .truncated;
            break;
        }
        const data = bytes[pos + 8 ..][0..length];
        const stored_crc = std.mem.readInt(u32, bytes[pos + 8 + length ..][0..4], .big);
        pos += 12 + @as(usize, length);

        var crc: std.hash.Crc32 = .init();
        crc.update(kind);
        crc.update(data);
        if (crc.final() != stored_crc) {
            // 13.1 item 3: a CRC mismatch is a corrupted datastream - fatal
            // for the chunks the image needs; an ancillary chunk is dropped.
            if (!critical) continue;
            if (idat_state == .before and !is_idat) return error.Corrupt;
            // Once the image data has begun: an IDAT's data has been decoded
            // by the time its CRC is checked; the datastream ends there.
            if (is_idat and idat_state != .after) {
                const h = header orelse return error.Corrupt;
                if (h.color == .indexed and palette == null) return error.Corrupt;
                image_data.appendSlice(allocator, data) catch return error.OutOfMemory;
                idat_state = .in_run;
            }
            ended = .corrupt;
            break;
        }

        if (idat_state == .in_run and !is_idat) idat_state = .after;
        if (header == null and !std.mem.eql(u8, kind, "IHDR")) return error.Corrupt;

        if (std.mem.eql(u8, kind, "IHDR")) {
            if (header != null) {
                if (idat_state == .before) return error.Corrupt;
                ended = .corrupt;
                break;
            }
            header = try parseHeader(data);
            try checkLimits(header.?, limits);
        } else if (std.mem.eql(u8, kind, "PLTE")) {
            // 11.2.2: one PLTE, before the image data.
            if (idat_state != .before) {
                ended = .corrupt;
                break;
            }
            if (palette != null) return error.Corrupt;
            const entries = data.len / 3;
            const valid = data.len % 3 == 0 and entries >= 1 and entries <= 256;
            switch (header.?.color) {
                // Required, and needed: a bad one is fatal.
                .indexed => {
                    if (!valid) return error.Corrupt;
                    palette = data;
                },
                // A suggested palette for a truecolour image: not needed.
                .truecolor, .truecolor_alpha => {},
                // 11.2.2: PLTE "shall not appear" for greyscale; nothing
                // here needs it, so it is ignored (13.1's "invalid PLTE in a
                // truecolour image" leniency).
                .greyscale, .greyscale_alpha => {},
            }
        } else if (is_idat) {
            if (header.?.color == .indexed and palette == null) return error.Corrupt;
            switch (idat_state) {
                .before, .in_run => {
                    idat_state = .in_run;
                    image_data.appendSlice(allocator, data) catch return error.OutOfMemory;
                },
                // IDAT chunks not consecutive: the image data ended at the
                // first run; a later IDAT is extra data, ignored.
                .after => {},
            }
        } else if (std.mem.eql(u8, kind, "IEND")) {
            saw_iend = true;
            break :chunks;
        } else if (std.mem.eql(u8, kind, "tRNS")) {
            // 11.3.1.1: before the image data, after PLTE, of the length its
            // colour type says; anything else is discarded.
            if (idat_state != .before or transparency != null) continue;
            switch (header.?.color) {
                .greyscale => if (data.len == 2) {
                    transparency = data;
                },
                .truecolor => if (data.len == 6) {
                    transparency = data;
                },
                .indexed => if (palette) |p| {
                    // No more entries than the palette has.
                    transparency = data[0..@min(data.len, p.len / 3)];
                },
                .greyscale_alpha, .truecolor_alpha => {},
            }
        } else if (critical) {
            // 13.1: an unknown critical chunk is fatal - before the image
            // data; after it, the datastream ends there.
            if (idat_state == .before) return error.Corrupt;
            ended = .corrupt;
            break;
        }
        // Any other ancillary chunk - colour space, text, time, animation,
        // and every unknown one - is skipped.
    } else {
        // Fewer bytes than a chunk's length and type: the datastream ended
        // inside a chunk, unless it ended between two.
        if (bytes.len != pos and idat_state != .before) ended = .truncated;
    }

    const h = header orelse return error.Corrupt;
    // No image data begun: the dimensions were never known (libpng's info
    // callback comes with the first IDAT).
    if (idat_state == .before) return error.Corrupt;
    // How the datastream ended: whole, at its IEND; truncated, before it; or
    // at an invalid chunk.
    const datastream: platform.ImageDecodeStatus = ended orelse if (saw_iend) .complete else .truncated;
    return decodeImageData(allocator, h, image_data.items, palette, transparency, datastream);
}

/// IHDR's 13 bytes (11.2.1), checked.
fn parseHeader(data: []const u8) ImageError!Header {
    if (data.len != 13) return error.Corrupt;
    const width = std.mem.readInt(u32, data[0..4], .big);
    const height = std.mem.readInt(u32, data[4..8], .big);
    // 11.2.1: zero is invalid; the maximum is 2^31 - 1.
    if (width == 0 or height == 0 or width > std.math.maxInt(i32) or height > std.math.maxInt(i32)) return error.Corrupt;
    const depth = data[8];
    const color = std.enums.fromInt(ColorType, data[9]) orelse return error.Corrupt;
    if (!color.allows(depth)) return error.Corrupt;
    // Compression method 0, filter method 0, interlace method 0 or 1.
    if (data[10] != 0 or data[11] != 0 or data[12] > 1) return error.Corrupt;
    return .{ .width = width, .height = height, .depth = depth, .color = color, .interlaced = data[12] == 1 };
}

fn checkLimits(header: Header, limits: platform.ImageLimits) ImageError!void {
    if (header.width > limits.max_dimension or header.height > limits.max_dimension) return error.TooLarge;
    if (@as(u64, header.width) * header.height > limits.max_pixels) return error.TooLarge;
}

/// Inflate the image data, undo the filters pass by pass and write RGBA8.
/// The scanlines the data holds whole are decoded; the image is partial
/// when that is not all of them, and `datastream` - how the chunk stream
/// ended - says why: truncated when it ended before its IEND, corrupt when
/// an invalid chunk ended it or when, whole, it holds too little image data
/// (13.1's "short image data").
fn decodeImageData(
    allocator: std.mem.Allocator,
    header: Header,
    compressed: []const u8,
    palette: ?[]const u8,
    transparency: ?[]const u8,
    datastream: platform.ImageDecodeStatus,
) ImageError!platform.DecodedImage {
    const passes: []const Pass = if (header.interlaced) &adam7 else &no_interlace;
    // The size of the filtered image data (7.2, 8.2): each pass's scanlines,
    // each with its filter byte. Empty passes have no scanlines.
    var raw_len: u64 = 0;
    for (passes) |pass| {
        const w, const h = passSize(header, pass);
        if (w == 0 or h == 0) continue;
        raw_len += (rowBytes(header, w) + 1) * h;
    }
    const pixel_len = @as(u64, header.width) * header.height * 4;
    if (raw_len > std.math.maxInt(usize) or pixel_len > std.math.maxInt(usize)) return error.TooLarge;

    // zlib (10.1): as many bytes as the scanlines take, as far as the data
    // goes - exactly, so that a truncated image's last rows are the ones its
    // data holds whole.
    const buffer = allocator.alloc(u8, @intCast(raw_len)) catch return error.OutOfMemory;
    defer allocator.free(buffer);
    const raw = buffer[0..inflate.zlib(buffer, compressed).len];

    const pixels = allocator.alloc(u8, @intCast(pixel_len)) catch return error.OutOfMemory;
    errdefer allocator.free(pixels);
    // What the data does not reach is transparent black.
    @memset(pixels, 0);
    var converter: Converter = .{ .header = header, .palette = palette orelse &.{}, .transparency = transparency };

    var offset: usize = 0;
    var rows: u64 = 0;
    var bad_filter = false;
    passes: for (passes) |pass| {
        const w, const h = passSize(header, pass);
        if (w == 0 or h == 0) continue;
        const stride: usize = @intCast(rowBytes(header, w));
        // The filter's "corresponding byte of the pixel to the left" (9.2):
        // a whole pixel back, at least one byte.
        const bpp: usize = @max(1, (@as(usize, header.color.channels()) * header.depth) / 8);
        var previous: ?[]const u8 = null;
        for (0..h) |row| {
            // A scanline the data does not hold whole is not decoded.
            if (raw.len - offset < stride + 1) break :passes;
            const filter = raw[offset];
            const line = raw[offset + 1 ..][0..stride];
            offset += stride + 1;
            unfilter(filter, line, previous, bpp) catch {
                bad_filter = true;
                break :passes;
            };
            previous = line;
            converter.writeRow(pixels, line, pass, @intCast(row), w);
            rows += 1;
        }
    }
    const status: platform.ImageDecodeStatus = if (offset == raw_len and !bad_filter)
        // Every scanline: complete - unless an invalid chunk came after
        // them (the pixels are whole, the datastream is not without errors).
        (if (datastream == .corrupt) .corrupt else .complete)
    else if (bad_filter or datastream == .complete)
        .corrupt
    else
        datastream;
    return .{
        .width = header.width,
        .height = header.height,
        .pixels = platform.Bytes.from(pixels),
        .status = status,
        .empty = status != .complete and rows == 0,
    };
}

/// Undo filter type `filter` on `line` in place (9.2-9.4); `previous` is the
/// unfiltered scanline above in the same pass, null for its first.
fn unfilter(filter: u8, line: []u8, previous: ?[]const u8, bpp: usize) ImageError!void {
    switch (filter) {
        0 => {},
        // Sub: Recon(x) = Filt(x) + Recon(a).
        1 => for (bpp..line.len) |i| {
            line[i] +%= line[i - bpp];
        },
        // Up: Recon(x) = Filt(x) + Recon(b).
        2 => if (previous) |up| for (line, up) |*x, b| {
            x.* +%= b;
        },
        // Average: Recon(x) = Filt(x) + floor((Recon(a) + Recon(b)) / 2).
        3 => for (line, 0..) |*x, i| {
            const a: u16 = if (i >= bpp) line[i - bpp] else 0;
            const b: u16 = if (previous) |up| up[i] else 0;
            x.* +%= @intCast((a + b) / 2);
        },
        // Paeth: Recon(x) = Filt(x) + PaethPredictor(Recon(a), Recon(b), Recon(c)).
        4 => for (line, 0..) |*x, i| {
            const a: i16 = if (i >= bpp) line[i - bpp] else 0;
            const b: i16 = if (previous) |up| up[i] else 0;
            const c: i16 = if (i >= bpp) (if (previous) |up| up[i - bpp] else 0) else 0;
            x.* +%= paeth(a, b, c);
        },
        // 9.2: filter types 0 to 4 only.
        else => return error.Corrupt,
    }
}

/// 9.4's PaethPredictor.
fn paeth(a: i16, b: i16, c: i16) u8 {
    const p = a + b - c;
    const pa = @abs(p - a);
    const pb = @abs(p - b);
    const pc = @abs(p - c);
    const predicted = if (pa <= pb and pa <= pc) a else if (pb <= pc) b else c;
    return @intCast(predicted);
}

/// Samples to RGBA8.
const Converter = struct {
    header: Header,
    palette: []const u8,
    transparency: ?[]const u8,

    /// Write pass row `row` (`width` pixels, unfiltered) into `pixels`.
    fn writeRow(self: *const Converter, pixels: []u8, line: []const u8, pass: Pass, row: u32, width: u32) void {
        const y = pass.y0 + row * pass.dy;
        const channels = self.header.color.channels();
        for (0..width) |column| {
            const x = pass.x0 + @as(u32, @intCast(column)) * pass.dx;
            const out = pixels[(@as(usize, y) * self.header.width + x) * 4 ..][0..4];
            const first = column * channels;
            switch (self.header.color) {
                .greyscale => {
                    const v = self.sample(line, first);
                    const grey = self.scale(v);
                    out.* = .{ grey, grey, grey, if (self.isTransparentGrey(v)) 0 else 255 };
                },
                .truecolor => {
                    const r = self.sample(line, first);
                    const g = self.sample(line, first + 1);
                    const b = self.sample(line, first + 2);
                    out.* = .{ self.scale(r), self.scale(g), self.scale(b), if (self.isTransparentColor(r, g, b)) 0 else 255 };
                },
                .indexed => {
                    const index: usize = self.sample(line, first);
                    if (index * 3 + 3 > self.palette.len) {
                        // 13.1: an out-of-range index is opaque black.
                        out.* = .{ 0, 0, 0, 255 };
                    } else {
                        const entry = self.palette[index * 3 ..][0..3];
                        const alpha: u8 = if (self.transparency) |t| (if (index < t.len) t[index] else 255) else 255;
                        out.* = .{ entry[0], entry[1], entry[2], alpha };
                    }
                },
                .greyscale_alpha => {
                    const grey = self.scale(self.sample(line, first));
                    out.* = .{ grey, grey, grey, self.scale(self.sample(line, first + 1)) };
                },
                .truecolor_alpha => out.* = .{
                    self.scale(self.sample(line, first)),
                    self.scale(self.sample(line, first + 1)),
                    self.scale(self.sample(line, first + 2)),
                    self.scale(self.sample(line, first + 3)),
                },
            }
        }
    }

    /// Sample `index` of the scanline, at the image's bit depth: packed most
    /// significant bits first below 8 (7.2), two bytes big-endian at 16 (7.1).
    fn sample(self: *const Converter, line: []const u8, index: usize) u16 {
        return switch (self.header.depth) {
            16 => std.mem.readInt(u16, line[index * 2 ..][0..2], .big),
            8 => line[index],
            else => |depth| blk: {
                const per_byte = 8 / depth;
                const byte = line[index / per_byte];
                const shift: u3 = @intCast(8 - depth * (index % per_byte + 1));
                const mask = (@as(u16, 1) << @intCast(depth)) - 1;
                break :blk (byte >> shift) & mask;
            },
        };
    }

    /// 13.12: output = floor(input * 255 / (2^depth - 1) + 0.5).
    fn scale(self: *const Converter, v: u16) u8 {
        const max: u32 = (@as(u32, 1) << @intCast(self.header.depth)) - 1;
        return @intCast((@as(u32, v) * 255 + max / 2) / max);
    }

    /// 11.3.1.1: a greyscale image's single transparent grey, compared at
    /// the image's own depth (13.12: exactly, before rescaling).
    fn isTransparentGrey(self: *const Converter, v: u16) bool {
        const t = self.transparency orelse return false;
        return std.mem.readInt(u16, t[0..2], .big) == v;
    }

    fn isTransparentColor(self: *const Converter, r: u16, g: u16, b: u16) bool {
        const t = self.transparency orelse return false;
        return std.mem.readInt(u16, t[0..2], .big) == r and
            std.mem.readInt(u16, t[2..4], .big) == g and
            std.mem.readInt(u16, t[4..6], .big) == b;
    }
};
