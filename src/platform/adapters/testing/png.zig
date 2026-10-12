//! The testing platform's PNG decoder (decision 19): PNG datastreams to
//! RGBA8, in Zig over std.compress.flate, so the WPT runner's results do not
//! depend on the machine's image libraries. W3C PNG (Third Edition),
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
//! - errors as 13.1 says: a signature or CRC mismatch on a critical chunk,
//!   an unknown critical chunk, a bad IHDR, a missing PLTE for an indexed
//!   image, missing or short image data, are fatal (`Corrupt`); an ancillary
//!   chunk with a bad CRC, misplaced or of the wrong length is discarded; an
//!   out-of-range palette index is opaque black (13.1, now required); a
//!   missing IEND is tolerated once the image data is complete.

const std = @import("std");
const platform = @import("platform");

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

/// Decode `bytes`, a whole PNG datastream. The pixels are OWNED by
/// `allocator`.
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8, limits: platform.ImageLimits) ImageError!platform.DecodedImage {
    if (!hasSignature(bytes)) return error.Corrupt;

    var header: ?Header = null;
    var palette: ?[]const u8 = null;
    var transparency: ?[]const u8 = null;
    var image_data: std.ArrayList(u8) = .empty;
    defer image_data.deinit(allocator);
    // IDAT chunks are consecutive (5.6); the run ends at the next chunk.
    var idat_state: enum { before, in_run, after } = .before;

    var pos: usize = signature.len;
    chunks: while (bytes.len - pos >= 12) {
        // 5.3: length, type, data, CRC. A chunk cut short ends the datastream
        // (an unexpected end, 13.1): what came before decides.
        const length = std.mem.readInt(u32, bytes[pos..][0..4], .big);
        if (length > std.math.maxInt(i32)) return error.Corrupt;
        if (bytes.len - pos - 12 < length) break;
        const kind = bytes[pos + 4 ..][0..4];
        const data = bytes[pos + 8 ..][0..length];
        const stored_crc = std.mem.readInt(u32, bytes[pos + 8 + length ..][0..4], .big);
        pos += 12 + @as(usize, length);

        for (kind) |c| if (!std.ascii.isAlphabetic(c)) return error.Corrupt;
        // 5.4: bit 5 of the first byte clear means critical.
        const critical = kind[0] & 0x20 == 0;
        var crc: std.hash.Crc32 = .init();
        crc.update(kind);
        crc.update(data);
        if (crc.final() != stored_crc) {
            // 13.1 item 3: a CRC mismatch is a corrupted datastream - fatal
            // for the chunks the image needs; an ancillary chunk is dropped.
            if (critical) return error.Corrupt;
            continue;
        }

        if (idat_state == .in_run and !std.mem.eql(u8, kind, "IDAT")) idat_state = .after;
        if (header == null and !std.mem.eql(u8, kind, "IHDR")) return error.Corrupt;

        if (std.mem.eql(u8, kind, "IHDR")) {
            if (header != null) return error.Corrupt;
            header = try parseHeader(data);
            try checkLimits(header.?, limits);
        } else if (std.mem.eql(u8, kind, "PLTE")) {
            // 11.2.2: one PLTE, before the image data.
            if (palette != null or idat_state != .before) return error.Corrupt;
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
        } else if (std.mem.eql(u8, kind, "IDAT")) {
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
            // 13.1: an unknown critical chunk is fatal.
            return error.Corrupt;
        }
        // Any other ancillary chunk - colour space, text, time, animation,
        // and every unknown one - is skipped.
    }

    const h = header orelse return error.Corrupt;
    if (idat_state == .before) return error.Corrupt;
    return decodeImageData(allocator, h, image_data.items, palette, transparency);
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
fn decodeImageData(
    allocator: std.mem.Allocator,
    header: Header,
    compressed: []const u8,
    palette: ?[]const u8,
    transparency: ?[]const u8,
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

    const inflated = try inflate(allocator, compressed, @intCast(raw_len));
    defer allocator.free(inflated);
    const raw = inflated[0..@intCast(raw_len)];

    const pixels = allocator.alloc(u8, @intCast(pixel_len)) catch return error.OutOfMemory;
    errdefer allocator.free(pixels);
    var converter: Converter = .{ .header = header, .palette = palette orelse &.{}, .transparency = transparency };

    var offset: usize = 0;
    for (passes) |pass| {
        const w, const h = passSize(header, pass);
        if (w == 0 or h == 0) continue;
        const stride: usize = @intCast(rowBytes(header, w));
        // The filter's "corresponding byte of the pixel to the left" (9.2):
        // a whole pixel back, at least one byte.
        const bpp: usize = @max(1, (@as(usize, header.color.channels()) * header.depth) / 8);
        var previous: ?[]const u8 = null;
        for (0..h) |row| {
            const filter = raw[offset];
            const line = raw[offset + 1 ..][0..stride];
            offset += stride + 1;
            try unfilter(filter, line, previous, bpp);
            previous = line;
            converter.writeRow(pixels, line, pass, @intCast(row), w);
        }
    }
    return .{ .width = header.width, .height = header.height, .pixels = platform.Bytes.from(pixels) };
}

/// zlib (10.1): at least `len` bytes of inflated data, OWNED (longer than
/// `len`: the tail is scratch). Data that ends before `len` is corrupt; data
/// after it is not read.
///
/// std.compress.flate in Zig 0.16 cannot be handed input that simply stops:
/// its short-input check in `tossBitsShort` adds `consumed_bits` where it
/// should subtract them, and tosses past the end of the reader's buffer (an
/// assertion) - see docs/lessons/debugging-a-pull-inflater-needs-short-input-
/// and-block-transition-tests.md, where src/compression met it. So the input
/// is followed by zero padding, every step is checked to have consumed only
/// real input, and the inflater writes straight into one fixed buffer (its
/// direct mode: no read-ahead, the buffer is the history) in steps whose
/// overshoot - a stored block after compressed output in one step may write
/// up to the step's limit again - the buffer's slack absorbs.
fn inflate(allocator: std.mem.Allocator, compressed: []const u8, len: usize) ImageError![]u8 {
    const padding = 8;
    const padded = allocator.alloc(u8, compressed.len + padding) catch return error.OutOfMemory;
    defer allocator.free(padded);
    @memcpy(padded[0..compressed.len], compressed);
    @memset(padded[compressed.len..], 0);

    const step = std.compress.flate.history_len;
    const out = allocator.alloc(u8, len + 2 * step) catch return error.OutOfMemory;
    errdefer allocator.free(out);
    var writer: std.Io.Writer = .fixed(out);
    var input: std.Io.Reader = .fixed(padded);
    var decompress: std.compress.flate.Decompress = .init(&input, .zlib, &.{});
    const real_bits = @as(u64, compressed.len) * 8;
    while (writer.end < len) {
        const before = writer.end;
        const consumed_before = @as(u64, input.seek) * 8 + decompress.consumed_bits;
        // The vtable, not Reader.stream: the overshoot above trips its
        // "no more than the limit" assertion.
        _ = decompress.reader.vtable.stream(&decompress.reader, &writer, .limited(@min(len - writer.end, step))) catch return error.Corrupt;
        const consumed = @as(u64, input.seek) * 8 + decompress.consumed_bits;
        // Output that needed the padding: the real data ended first.
        if (consumed > real_bits) return error.Corrupt;
        if (writer.end == before and consumed == consumed_before) return error.Corrupt;
    }
    return out;
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
