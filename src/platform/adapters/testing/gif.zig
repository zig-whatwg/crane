//! The testing platform's GIF decoder (decision 19c): GIF87a and GIF89a to
//! RGBA8, in Zig. specs/w3c/gif89a.txt is the format; what a browser does
//! where it is silent or where files break it is the browsers' choice
//! (golden rule 2). Read 2026-10-12, their design and not their code:
//! Firefox's image/decoders/nsGIFDecoder2.cpp, Safari's
//! Source/WebCore/platform/image-decoders/gif/GIFImageReader.cpp and
//! GIFImageDecoder.cpp, and Chrome's Wuffs std/gif/decode_gif.wuffs and
//! std/lzw/decode_lzw.wuffs as Skia's src/codec/SkWuffsCodec.cpp drives it.
//! Firefox and Safari both descend from Netscape's decoder and agree with
//! each other where Chrome differs, so most rules below are theirs.
//!
//! - The default image of an animated GIF is its first frame (animation is
//!   a later batch), drawn onto a transparent canvas of the logical screen's
//!   size. Nothing after the first frame's data is read.
//! - The logical screen (18): when the first frame is wider or taller than
//!   the screen, or the file is GIF87a, the screen becomes the first frame's
//!   size and the frame moves to (0, 0) (Firefox, Safari: "Work around broken
//!   GIF files where the logical screen size has weird width or height. We
//!   assume that GIF87a files don't contain animations"; Chrome instead
//!   grows the screen to cover the frame). A frame with no width or height
//!   takes the screen's (Firefox, Safari); with neither, there is no image.
//!   The rest of a frame outside the screen is clipped.
//! - The background colour index is ignored: what the frame does not cover
//!   is transparent (all three; Firefox: "implementing that feature would
//!   not be web compatible").
//! - Colour tables (19, 21): the local table if the frame has one, else the
//!   global one. An index with no entry - past the table, or with no table at
//!   all - is opaque black. The browsers split three ways here (Chrome:
//!   opaque black, Wuffs pads its palette with it; Firefox: the index wraps
//!   within the table's power-of-two size, and entries past the table, or no
//!   table, are opaque white; Safari: the pixel is left transparent). The
//!   GIF spec is silent, so the integrator settled it (2026-10-12) by
//!   analogy with PNG 13.1's rule for an out-of-range palette index, which
//!   png.zig follows - also Chrome's. This is the testing decoder only: a
//!   host's decoder may differ.
//! - The Graphic Control Extension (23) before the frame sets its
//!   transparent index: those pixels are transparent black. The last one
//!   before the frame applies; a block size under 4 still reads 4 bytes
//!   (Firefox, Safari), and a block size of 0 ends the extension (16, a
//!   block terminator; Firefox). Comment, Plain Text, Application and
//!   unknown extensions are skipped, whatever the version. A NETSCAPE2.0 or
//!   ANIMEXTS1.0 application block's sub-blocks are read as Firefox and
//!   Safari read them (at least 3 bytes each; kind 1, looping, and 2,
//!   buffering, are allowed, any other kind is corrupt).
//! - Before the first frame, anything but an extension or an image
//!   descriptor - the trailer, or junk - means there is no image (corrupt).
//! - LZW (Appendix F) with Firefox's and Safari's arithmetic: a minimum code
//!   size up to 11 (the clear code must fit 12 bits; Chrome rejects more than
//!   8), codes widen when the next free code reaches the width's limit, up to
//!   12 bits; a full table is kept until a clear code (the deferred clear of
//!   the cover sheet); a code past the next free one is decoded as the next
//!   free one is (the previous string plus its first index); a literal is
//!   the low 8 bits of its code. A string that refers to itself, or one
//!   longer than the table, is corrupt.
//! - Interlaced frames (Appendix E): four passes, rows 0, 4, 2 and 1 modulo
//!   8, 8, 4 and 2.
//! - The frame's data ends at its end code, at its block terminator, or when
//!   every pixel is decoded; pixels the data did not reach stay transparent
//!   (Firefox, Safari: "some broken GIF files do not have enough LZW blocks
//!   to fully decode all rows but we treat it as frame complete"; WPT's own
//!   26-byte 1x1 GIF has no LZW data at all). Data past the last pixel is
//!   ignored. A missing trailer after the first frame is no matter.
//! - The dimensions are known at the first image descriptor (the screen as
//!   adjusted below): Gecko's nsGIFDecoder2 posts the size there (BeginGIF),
//!   and Chrome's Wuffs decoder has the image's configuration from it;
//!   ImageIO, probed on macOS 27, has no size until the whole first frame
//!   has arrived - the minority. Before it, a file that ends or breaks has no
//!   image (corrupt). After it, nothing is fatal: a file that ENDS before the
//!   frame's data does (no end code, no terminator, pixels missing) is a
//!   truncated partial image, and data that breaks - a minimum code size
//!   over 11, an LZW string the table cannot hold - a corrupt one (the
//!   protocol's ImageDecodeStatus), with the pixels decoded before that
//!   point and the rest transparent (Gecko's FinishInternal: "If the GIF got
//!   cut off, handle it anyway").
//! - Limits: the logical screen, as adjusted above, is checked against them
//!   before the canvas is allocated.

const std = @import("std");
const platform = @import("platform");

const ImageError = platform.ImageError;

/// Whether `bytes` begins with a GIF signature and version (17).
pub fn hasSignature(bytes: []const u8) bool {
    return bytes.len >= 6 and (std.mem.eql(u8, bytes[0..6], "GIF87a") or std.mem.eql(u8, bytes[0..6], "GIF89a"));
}

/// The bytes still to read.
const Reader = struct {
    bytes: []const u8,
    pos: usize = 0,

    fn take(self: *Reader, n: usize) ?[]const u8 {
        if (self.bytes.len - self.pos < n) return null;
        defer self.pos += n;
        return self.bytes[self.pos..][0..n];
    }

    fn byte(self: *Reader) ?u8 {
        const b = self.take(1) orelse return null;
        return b[0];
    }

    /// Skip data sub-blocks up to and including their block terminator
    /// (15, 16). Null if the data ends first.
    fn skipSubBlocks(self: *Reader) ?void {
        while (true) {
            const len = self.byte() orelse return null;
            if (len == 0) return;
            _ = self.take(len) orelse return null;
        }
    }
};

fn readU16(bytes: []const u8, at: usize) u16 {
    return std.mem.readInt(u16, bytes[at..][0..2], .little);
}

/// Decode `bytes`, a GIF - whole, or as much of one as the fetch delivered.
/// The pixels are OWNED by `allocator`.
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8, limits: platform.ImageLimits) ImageError!platform.DecodedImage {
    var r: Reader = .{ .bytes = bytes };

    // 17. Header.
    if (!hasSignature(bytes)) return error.Corrupt;
    const gif87a = bytes[4] == '7';
    r.pos = 6;

    // 18. Logical Screen Descriptor; 19. Global Color Table.
    const screen = r.take(7) orelse return error.Corrupt;
    var screen_width: u32 = readU16(screen, 0);
    var screen_height: u32 = readU16(screen, 2);
    var global: ?[]const u8 = null;
    if (screen[4] & 0x80 != 0) {
        global = r.take(3 * (@as(usize, 2) << @intCast(screen[4] & 0x07))) orelse return error.Corrupt;
    }

    // Blocks up to the first image. 23: the Graphic Control Extension's
    // scope is the next graphic rendering block; the last one wins.
    var transparent: ?u8 = null;
    while (true) {
        const introducer = r.byte() orelse return error.Corrupt;
        switch (introducer) {
            0x21 => {
                const label = r.byte() orelse return error.Corrupt;
                try readExtension(&r, label, &transparent);
            },
            0x2c => break,
            // The trailer, or anything else: no image comes first.
            else => return error.Corrupt,
        }
    }

    // 20. Image Descriptor.
    const descriptor = r.take(9) orelse return error.Corrupt;
    var x: u32 = readU16(descriptor, 0);
    var y: u32 = readU16(descriptor, 2);
    var width: u32 = readU16(descriptor, 4);
    var height: u32 = readU16(descriptor, 6);
    const flags = descriptor[8];
    // The screen follows the first frame when it is larger, or for GIF87a
    // (Firefox, Safari; see the file comment).
    if (gif87a or screen_width < width or screen_height < height) {
        screen_width = width;
        screen_height = height;
        x = 0;
        y = 0;
    }
    if (width == 0 or height == 0) {
        width = screen_width;
        height = screen_height;
        if (width == 0 or height == 0) return error.Corrupt;
    }
    if (screen_width > limits.max_dimension or screen_height > limits.max_dimension or
        @as(u64, screen_width) * screen_height > limits.max_pixels) return error.TooLarge;

    const pixel_len = @as(u64, screen_width) * screen_height * 4;
    if (pixel_len > std.math.maxInt(usize)) return error.TooLarge;
    const pixels = allocator.alloc(u8, @intCast(pixel_len)) catch return error.OutOfMemory;
    errdefer allocator.free(pixels);
    // A transparent canvas.
    @memset(pixels, 0);

    // From here the dimensions are known: what fails leaves a partial image.
    var any_pixel = false;
    const status: platform.ImageDecodeStatus = if (decodeFrame(allocator, &r, .{
        .pixels = pixels,
        .screen_width = screen_width,
        .screen_height = screen_height,
        .x = x,
        .y = y,
        .width = width,
        .height = height,
        .interlaced = flags & 0x40 != 0,
        .colors = &.{},
        .transparent = transparent,
        .rows_left = height,
    }, global, flags, &any_pixel)) |_| .complete else |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.Truncated => .truncated,
        error.Invalid => .corrupt,
    };
    return .{
        .width = screen_width,
        .height = screen_height,
        .pixels = platform.Bytes.from(pixels),
        .status = status,
        .empty = status != .complete and !any_pixel,
    };
}

/// How a frame's data failed after the dimensions: it ended, or it broke.
const FrameError = error{ OutOfMemory, Truncated, Invalid };

/// The first frame's colour table and data (21, 22) onto `out`'s canvas;
/// `any_pixel` says whether any pixel was decoded.
fn decodeFrame(allocator: std.mem.Allocator, r: *Reader, frame: Output, global: ?[]const u8, flags: u8, any_pixel: *bool) FrameError!void {
    var out = frame;
    defer any_pixel.* = out.decoded;
    // 21. Local Color Table.
    var colors: ?[]const u8 = global;
    if (flags & 0x80 != 0) {
        colors = r.take(3 * (@as(usize, 2) << @intCast(flags & 0x07))) orelse return error.Truncated;
    }
    out.colors = colors orelse &.{};

    // 22. Table Based Image Data: the LZW minimum code size.
    const min_code_size = r.byte() orelse return error.Truncated;
    if (min_code_size > max_min_code_size) return error.Invalid;

    const lzw = allocator.create(Lzw) catch return error.OutOfMemory;
    defer allocator.destroy(lzw);
    lzw.init(@intCast(min_code_size));

    // The data sub-blocks, one continuous bit stream.
    const bytes = r.bytes;
    while (!out.done()) {
        const len = r.byte() orelse return error.Truncated;
        // The block terminator: the data ends, complete or not.
        if (len == 0) break;
        const available = @min(len, bytes.len - r.pos);
        const data = bytes[r.pos..][0..available];
        r.pos += available;
        switch (lzw.feed(data, &out) catch return error.Invalid) {
            .more => {},
            .end => break,
        }
        // The file ends inside the sub-block, pixels still to come.
        if (available < len and !out.done()) return error.Truncated;
    }
}

/// Firefox and Safari: the clear code, 2^size, must be below 4096.
const max_min_code_size = 11;

/// One extension (12, 23-26), its label read.
fn readExtension(r: *Reader, label: u8, transparent: *?u8) ImageError!void {
    const size = r.byte() orelse return error.Corrupt;
    // 16: a block size of 0 is a block terminator; the extension ends.
    if (size == 0) return;
    switch (label) {
        // 23. Graphic Control Extension: packed fields, delay, transparent
        // index. Firefox and Safari read at least 4 bytes whatever the block
        // size says.
        0xf9 => {
            const data = r.take(@max(size, 4)) orelse return error.Corrupt;
            transparent.* = if (data[0] & 0x01 != 0) data[3] else null;
        },
        // 26. Application Extension: NETSCAPE2.0 and ANIMEXTS1.0 sub-blocks
        // are read as Firefox and Safari read them; any other application's
        // data is skipped.
        0xff => {
            const identifier = r.take(size) orelse return error.Corrupt;
            if (size == 11 and (std.mem.eql(u8, identifier, "NETSCAPE2.0") or std.mem.eql(u8, identifier, "ANIMEXTS1.0"))) {
                while (true) {
                    const len = r.byte() orelse return error.Corrupt;
                    if (len == 0) return;
                    const data = r.take(@max(len, 3)) orelse return error.Corrupt;
                    switch (data[0] & 0x07) {
                        // Looping, and buffering: allowed, and not needed
                        // for the first frame.
                        1, 2 => {},
                        // "0,3-7 are yet to be defined netscape extension
                        // codes" (Safari; Firefox the same).
                        else => return error.Corrupt,
                    }
                }
            }
        },
        // Comment (24), Plain Text (25; Plain Text is a graphic rendering
        // block, but every browser skips it) and unknown extensions.
        else => _ = r.take(size) orelse return error.Corrupt,
    }
    r.skipSubBlocks() orelse return error.Corrupt;
}

/// Where decoded indices go: the frame's rows, in stream order, onto the
/// screen.
const Output = struct {
    pixels: []u8,
    screen_width: u32,
    screen_height: u32,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    interlaced: bool,
    colors: []const u8,
    transparent: ?u8,
    /// The current row of the frame, its column, and the rows left.
    row: u32 = 0,
    column: u32 = 0,
    rows_left: u32,
    /// The interlace pass (Appendix E), 0 to 3.
    pass: u2 = 0,
    /// Whether any pixel has been decoded (a transparent one included).
    decoded: bool = false,

    const pass_start = [4]u32{ 0, 4, 2, 1 };
    const pass_step = [4]u32{ 8, 8, 4, 2 };

    fn done(self: *const Output) bool {
        return self.rows_left == 0;
    }

    /// The next pixel's index. Past the last pixel, ignored.
    fn put(self: *Output, index: u8) void {
        if (self.rows_left == 0) return;
        self.decoded = true;
        const sx = self.x + self.column;
        const sy = self.y + self.row;
        const is_transparent = if (self.transparent) |t| index == t else false;
        if (sx < self.screen_width and sy < self.screen_height and !is_transparent) {
            const out = self.pixels[(@as(usize, sy) * self.screen_width + sx) * 4 ..][0..4];
            const at = @as(usize, index) * 3;
            // No entry: opaque black (see the file comment).
            out.* = if (at + 3 <= self.colors.len) .{ self.colors[at], self.colors[at + 1], self.colors[at + 2], 255 } else .{ 0, 0, 0, 255 };
        }
        self.column += 1;
        if (self.column < self.width) return;
        self.column = 0;
        self.rows_left -= 1;
        if (self.rows_left == 0) return;
        if (!self.interlaced) {
            self.row += 1;
            return;
        }
        self.row += pass_step[self.pass];
        while (self.row >= self.height) {
            // rows_left > 0, so a later pass has a row in the frame.
            self.pass += 1;
            self.row = pass_start[self.pass];
        }
    }
};

/// The LZW decoder (Appendix F) with the arithmetic Firefox and Safari share
/// (see the file comment): the code width grows when the next free code
/// leaves no bit of the current mask, and the mask grows by adding that
/// code - the spec's widening for every minimum code size from 2, and the
/// same answer as theirs for the sizes below that no encoder writes.
const Lzw = struct {
    clear_code: u16,
    min_code_size: u4,
    code_size: u5,
    code_mask: u16,
    /// The next free code.
    next: u16,
    /// The previous code, null after a clear code.
    previous: ?u16,
    first: u8,
    datum: u32,
    bits: u5,
    prefix: [table_len]u16,
    suffix: [table_len]u8,
    stack: [table_len + 1]u8,

    const table_len = 4096;

    const Result = enum { more, end };

    fn init(self: *Lzw, min_code_size: u4) void {
        self.clear_code = @as(u16, 1) << min_code_size;
        self.min_code_size = min_code_size;
        self.datum = 0;
        self.bits = 0;
        self.first = 0;
        // Every entry starts as a code with no prefix and suffix 0, and the
        // literals as themselves (their low 8 bits): a code that reaches an
        // entry a bad stream never defined decodes to something, never to
        // undefined memory (Safari: "Clearing the whole suffix table lets us
        // be more tolerant of bad data").
        @memset(&self.prefix, 0);
        @memset(&self.suffix, 0);
        for (0..self.clear_code) |i| self.suffix[i] = @truncate(i);
        self.reset();
    }

    /// The clear code's start-up state.
    fn reset(self: *Lzw) void {
        self.code_size = @as(u5, self.min_code_size) + 1;
        self.code_mask = @intCast((@as(u32, 1) << self.code_size) - 1);
        self.next = self.clear_code + 2;
        self.previous = null;
    }

    /// Decode `data`, the next piece of the stream, into `out`. `.end` at
    /// the end code; corrupt on a string the table cannot hold.
    fn feed(self: *Lzw, data: []const u8, out: *Output) ImageError!Result {
        for (data) |b| {
            self.datum |= @as(u32, b) << self.bits;
            self.bits += 8;
            while (self.bits >= self.code_size) {
                const code: u16 = @intCast(self.datum & self.code_mask);
                self.datum >>= self.code_size;
                self.bits -= self.code_size;
                if (code == self.clear_code) {
                    self.reset();
                    continue;
                }
                // The end code: "LZW processing terminates".
                if (code == self.clear_code + 1) return .end;
                try self.decodeCode(code, out);
                if (out.done()) return .end;
            }
        }
        return .more;
    }

    fn decodeCode(self: *Lzw, code: u16, out: *Output) ImageError!void {
        const previous = self.previous orelse {
            // The first code after a clear: a literal, output as it is.
            out.put(self.suffix[code]);
            self.first = @truncate(code);
            self.previous = code;
            return;
        };
        var depth: usize = 0;
        var c = code;
        // A code not yet in the table (the next free one, or past it): the
        // previous string plus its own first index.
        if (c >= self.next) {
            try self.push(&depth, self.first);
            c = previous;
        }
        while (c >= self.clear_code) {
            // A string that refers to itself would never end.
            if (c == self.prefix[c]) return error.Corrupt;
            try self.push(&depth, self.suffix[c]);
            c = self.prefix[c];
        }
        self.first = self.suffix[c];
        self.stack[depth] = self.first;
        depth += 1;
        // Define the next code: the previous string plus this one's first
        // index. A full table is kept as it is until a clear code.
        if (self.next < table_len) {
            self.prefix[self.next] = previous;
            self.suffix[self.next] = self.first;
            self.next += 1;
            if (self.next & self.code_mask == 0 and self.next < table_len) {
                self.code_size += 1;
                self.code_mask += self.next;
            }
        }
        self.previous = code;
        // The string was gathered last index first.
        while (depth > 0) {
            depth -= 1;
            out.put(self.stack[depth]);
        }
    }

    /// Firefox and Safari: a string as long as the table is corrupt.
    fn push(self: *Lzw, depth: *usize, index: u8) ImageError!void {
        self.stack[depth.*] = index;
        depth.* += 1;
        if (depth.* == table_len + 1) return error.Corrupt;
    }
};
