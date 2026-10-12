//! GIF through the platform protocol (decision 19c): the testing platform
//! decodes image/gif in Zig - GIF87a and GIF89a, the first frame only,
//! composited onto a transparent canvas of the logical screen's size (the
//! rules, and which browser each follows, are listed in
//! src/platform/adapters/testing/gif.zig).
//!
//! WPT's own GIFs are the main cases: every .gif file in the tree, read from
//! tests/wpt at run time as the PngSuite cases are, with the expected pixels
//! a SHA-256 of RGBA8 from PIL 12.0 (Image.open, frame 0, convert("RGBA"),
//! and every pixel whose alpha is 0 made transparent black: browsers keep no
//! colour under a transparent pixel, and PIL keeps the palette's). The GIF
//! data URIs WPT's tests use, and the GIF cookies/resources/imgIfMatch.py
//! serves, are here byte for byte with their pixels worked out by hand. The
//! rest are built here: a GIF container writer and an LZW encoder whose
//! output for one fixed input is pinned to a reference encoder's (see the
//! deferred-clear test).

const std = @import("std");
const platform = @import("platform");

const testing = std.testing;

/// Generous limits: nothing here comes near them, except where a test says.
const limits: platform.ImageLimits = .{ .max_dimension = 1 << 15, .max_pixels = 1 << 24 };

fn decode(bytes: []const u8) platform.ImageError!platform.DecodedImage {
    return platform.decodeImage(testing.allocator, platform.Str.from("image/gif"), platform.Bytes.from(bytes), limits);
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

fn hexDigest(pixels: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(pixels, &digest, .{});
    var hex: [64]u8 = undefined;
    _ = std.fmt.bufPrint(&hex, "{x}", .{&digest}) catch unreachable;
    return hex;
}

const clear: [4]u8 = .{ 0, 0, 0, 0 };
const black: [4]u8 = .{ 0, 0, 0, 255 };
const white: [4]u8 = .{ 255, 255, 255, 255 };
const red: [4]u8 = .{ 255, 0, 0, 255 };
const green: [4]u8 = .{ 0, 255, 0, 255 };
const blue: [4]u8 = .{ 0, 0, 255, 255 };

// ---------------------------------------------------------------------------
// WPT's GIF files
// ---------------------------------------------------------------------------

/// Every GIF in WPT's tree: path under tests/wpt, width, height, SHA-256 of
/// the expected RGBA8 (the file comment says where the values come from).
/// css/css-images/image-multipart-crash.gif is not a GIF (a multipart body)
/// and is below with the corrupt ones.
const wpt_gifs = [_]struct { []const u8, u32, u32, []const u8 }{
    .{ "conformance-checkers/html-aria/_functional/tree/css/img/expander.gif", 18, 9, "a535bbc56ad773d6c9a426557af20f4ebdbb0dc399ce713e7946086faa382439" },
    .{ "css/css-backgrounds/support/bg_flower.gif", 106, 160, "b51ebfffb3c538b13e4da8e6e5373f9ca46fbbf8b20f96249ec6af099d75de93" },
    .{ "css/css-images/support/1x1-green.gif", 1, 1, "e93bd575c4eab800d580b157d271ebdfbb0b164842cbdb0db19ce816801e0db1" },
    // Interlaced.
    .{ "css/css-lists/resources/white.gif", 10, 10, "3cf1d41abcc848ebd26aacda1f86a659990fe2401c3b21c6ce8302ed100ef2ab" },
    .{ "css/css-shapes/shape-outside/shape-image/support/animated.gif", 100, 100, "7d2b32308a5daf5ad2b3011b411703bc48f1f277e3c51b34dfa3e91dbe1299fa" },
    .{ "css/css-shapes/shape-outside/shape-image/support/right-half-rectangle.gif", 100, 100, "d151b45bcbc9bf5da224a4029fe83d6882aa9d31d108e77795b4c1e98d45e4f9" },
    // GIF87a.
    .{ "css/css-transitions/support/one.gif", 50, 50, "b295ff11a42c2b2f8c7f50ce82e4bad0babc209cf0b0eb8bc8380892a72ddcdf" },
    .{ "css/css-transitions/support/two.gif", 50, 50, "6dab83b4c1127e99c2457b73eeccb7aa12c43c0bd91d4b7f84b85b2a9ceeeab4" },
    // GIF87a; the same pixels as PngSuite's basn0g08.png.
    .{ "css/css-ui/support/cursors/basn0g08.gif", 32, 32, "982faa277e83f73ca15b491e67eb41fa25526418ed23e057a9986c4f620eb158" },
    .{ "css/css-ui/support/cursors/tp1n3p08.gif", 32, 32, "25810383a177936e082ebda0c2967474198ad62f367e70ebc08e06e6bacbe31f" },
    // Application and comment extensions before the first frame.
    .{ "css/CSS2/backgrounds/support/animated.gif", 47, 46, "faba8cf45e32e4ecb5e0ab976d5726087ca98f7090fc2602ae17e9474e077b4e" },
    .{ "css/CSS2/ui/support/animated.gif", 47, 46, "faba8cf45e32e4ecb5e0ab976d5726087ca98f7090fc2602ae17e9474e077b4e" },
    .{ "css/CSS2/ui/support/cat.gif", 98, 99, "6946ab9530667fe1d94bf53a952ae7debf7b8d80e8191a9eb0b5d980740b869f" },
    .{ "dom/nodes/Document-contentType/resources/t.gif", 100, 100, "3d7f11ac1ff3795e7fe7201576018719d1d501c532c9131848bb41fa87d38897" },
    .{ "gif/reset-no-gce.gif", 2, 2, "fb3a6a641bbce9b762a240d320a72e963ebbfd6d38cf17e86f37f165574bdbe0" },
    .{ "html/canvas/element/manual/draw-element-image/resources/rgb100.gif", 100, 100, "869ed904c16375f570ddac4b544936b94dca27dda7f31eaaab814c09606a2e34" },
    .{ "html/canvas/element/manual/wide-gamut-canvas/resources/pattern-srgb.gif", 20, 20, "50be0c3c3a2e22358d499096476efae9401cf58883e76c04fdca3b160ee9ea63" },
    .{ "html/canvas/offscreen/manual/draw-element-image/resources/rgb100.gif", 100, 100, "869ed904c16375f570ddac4b544936b94dca27dda7f31eaaab814c09606a2e34" },
    .{ "html/editing/dnd/resources/1x1-transparent.gif", 1, 1, "df3f619804a92fdb4057192dc43dd748ea778adc52bc498ce80524c014b81119" },
    .{ "html/semantics/embedded-content/the-img-element/resources/animated.gif", 100, 100, "869ed904c16375f570ddac4b544936b94dca27dda7f31eaaab814c09606a2e34" },
    .{ "images/anim-gr.gif", 100, 50, "42f918becde1d7a197cb96baebd4e9f7217e4492414f277e39198c4a7d17721d" },
    .{ "images/anim-rgb.gif", 100, 50, "d9ff8ebeb617ae638af9958d864976fec2c845877399febd5d4866b1ff72d818" },
    // No global table: the frame's local one, 256 entries.
    .{ "images/fail.gif", 320, 240, "0b348ff5767ee5352361b9c24c6d95a3913ed90b475b098501dad39af3921f2a" },
    .{ "images/red-green-animated.gif", 50, 50, "558f17e4b2f182d31e6926d7374c0b40c577680aef212bc261d20530ec87c1f1" },
    .{ "mathml/crashtests/mozilla/347355-1.gif", 16, 16, "5a50aca7974615aa57fbe7726a8e86ddfba1da307c05f9cb11bfafa2549c3372" },
    .{ "webcodecs/animated-zero-delay.gif", 2, 2, "fb3a6a641bbce9b762a240d320a72e963ebbfd6d38cf17e86f37f165574bdbe0" },
    .{ "webcodecs/four-colors-flip.gif", 320, 240, "be518a26482c965768998280a4a8e4e9458ee9ca8bd88c85208ab0b19acb0814" },
    .{ "webcodecs/four-colors.gif", 320, 240, "be518a26482c965768998280a4a8e4e9458ee9ca8bd88c85208ab0b19acb0814" },
    .{ "webvtt/rendering/cues-with-video/processing-model/media/background.gif", 745, 32, "d01a6bfa360c567e9f6fddbb486f838775bc65132766054a93e2f306e2aa1642" },
    // 165 KB of 8-bit LZW data: the code table fills and is cleared many times.
    .{ "xhr/resources/image.gif", 505, 323, "bca58692705b4b72467f54903fdfb95e28bfabbefeb4c42c15ea20449893ae81" },
};

fn readWpt(comptime path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(testing.io, "tests/wpt/" ++ path, testing.allocator, .limited(1 << 20));
}

test "gif: every GIF in WPT decodes to the reference pixels" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    inline for (wpt_gifs) |case| {
        const bytes = try readWpt(case[0]);
        defer testing.allocator.free(bytes);
        const image = decode(bytes) catch |err| {
            std.debug.print("{s}: {s}\n", .{ case[0], @errorName(err) });
            return err;
        };
        defer free(image);
        testing.expectEqual(case[1], image.width) catch |err| {
            std.debug.print("{s}: width\n", .{case[0]});
            return err;
        };
        try testing.expectEqual(case[2], image.height);
        try testing.expectEqual(@as(usize, case[1]) * case[2] * 4, image.pixels.len);
        const digest = hexDigest(image.pixels.slice());
        testing.expectEqualStrings(case[3], &digest) catch |err| {
            std.debug.print("{s}: pixels differ from the reference\n", .{case[0]});
            return err;
        };
    }
}

test "gif: WPT's file that is named .gif but is not a GIF is corrupt" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const bytes = try readWpt("css/css-images/image-multipart-crash.gif");
    defer testing.allocator.free(bytes);
    try testing.expectError(error.Corrupt, decode(bytes));
}

// ---------------------------------------------------------------------------
// The GIFs WPT's tests write inline, and imgIfMatch.py's
// ---------------------------------------------------------------------------

fn base64(comptime text: []const u8) [std.base64.standard.Decoder.calcSizeForSlice(text) catch unreachable]u8 {
    var out: [std.base64.standard.Decoder.calcSizeForSlice(text) catch unreachable]u8 = undefined;
    std.base64.standard.Decoder.decode(&out, text) catch unreachable;
    return out;
}

test "gif: cookies/resources/imgIfMatch.py's 1x1 GIF is one transparent pixel" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // From the resource, byte for byte (mathiasbynens/small's
    // gif-transparent.gif): a two-colour global table, a Graphic Control
    // Extension making index 0 transparent, one pixel of index 0.
    const gif = "\x47\x49\x46\x38\x39\x61\x01\x00\x01\x00\x80\x00\x00\xFF\xFF\xFF\x00\x00\x00\x21\xF9\x04\x01\x00\x00\x00\x00\x2C\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02\x44\x01\x00\x3B";
    try expectPixels(gif, 1, 1, &.{clear});
}

test "gif: the data: GIFs WPT's tests use" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // The common 1x1 transparent GIF (75 uses): white and black, index 0
    // transparent.
    try expectPixels(&base64("R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="), 1, 1, &.{clear});
    // Black and white, index 0 transparent; the LZW data is one byte, a
    // clear code and index 0, with no end code before the block terminator:
    // one transparent pixel.
    try expectPixels(&base64("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"), 1, 1, &.{clear});
    // "The smallest GIF" (26 bytes): no colour table, and the image data is
    // only its block terminator - no LZW data at all. Browsers show it as a
    // transparent pixel.
    try expectPixels(&base64("R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs="), 1, 1, &.{clear});
    // No colour table; a Graphic Control Extension makes index 1
    // transparent, and the pixel is index 1.
    try expectPixels(&base64("R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=="), 1, 1, &.{clear});
    // An opaque grey pixel (no Graphic Control Extension). WPT writes it
    // without base64 padding (forgiving-base64 accepts that); padded here.
    try expectPixels(&base64("R0lGODlhAQABAJAAAMjIyAAAACwAAAAAAQABAAACAgQBADs="), 1, 1, &.{.{ 200, 200, 200, 255 }});
    // A Graphic Control Extension without the transparency flag: opaque.
    try expectPixels(&base64("R0lGODlhAQABAIAAAMLCwgAAACH5BAAAAAAALAAAAAABAAEAAAICRAEAOw=="), 1, 1, &.{.{ 194, 194, 194, 255 }});
    // Index 1 of white, white; index 1 transparent.
    try expectPixels(&base64("R0lGODlhAQABAIAAAP///////yH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=="), 1, 1, &.{clear});
    // A white pixel, no extension.
    try expectPixels(&base64("R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="), 1, 1, &.{white});
    // 4x4 of white and a light grey.
    const grey: [4]u8 = .{ 218, 218, 218, 255 };
    try expectPixels(&base64("R0lGODlhBAAEAIAAANra2v///yH5BAAAAAAALAAAAAAEAAQAAAIFTGB4xlcAOw=="), 4, 4, &.{
        white, white, grey,  white,
        white, grey,  white, white,
        grey,  white, white, white,
        white, white, white, grey,
    });
    // 12x12 that ends after its first frame's block terminator: no trailer
    // (and, in WPT, no base64 padding; padded here). Browsers display it; the
    // frame is whole.
    const no_trailer = base64("R0lGODlhDAAMAKIFAF5LAP/zxAAAANyuAP/gaP///wAAAAAAACH5BAEAAAUALAAAAAAMAAwAAAMlWLPcGjDKFYi9lxKBOaGcF35DhWHamZUW0K4mAbiwWtuf0uxFAgA=");
    const image = try decode(&no_trailer);
    defer free(image);
    try testing.expectEqual(@as(u32, 12), image.width);
    try testing.expectEqual(@as(u32, 12), image.height);
    // PIL 12.0's pixels, transparent ones made transparent black.
    try testing.expectEqualStrings("c0be9c6a6ea5131506ab392dfa6b9bbaf970ea1fc89b628ae343d3d23f23f7f6", &hexDigest(image.pixels.slice()));
}

// ---------------------------------------------------------------------------
// A GIF writer and an LZW encoder for the built cases
// ---------------------------------------------------------------------------

/// What the encoder does when its code table is full (4096 codes).
const WhenFull = enum {
    /// Emit a clear code and start again: what most encoders do.
    clear,
    /// Keep going with the full table at 12 bits, no clear (the "deferred
    /// clear code" of the GIF89a cover sheet, which decoders must handle).
    defer_clear,
};

const EncodeOptions = struct {
    clear_first: bool = true,
    when_full: WhenFull = .clear,
    end: bool = true,
};

/// LSB-first bit packing (GIF89a Appendix F, "Build 8-bit bytes").
const BitWriter = struct {
    out: std.ArrayList(u8) = .empty,
    acc: u32 = 0,
    bits: u5 = 0,

    fn write(self: *BitWriter, code: u16, width: u5) !void {
        self.acc |= @as(u32, code) << self.bits;
        self.bits += width;
        while (self.bits >= 8) {
            try self.out.append(testing.allocator, @truncate(self.acc));
            self.acc >>= 8;
            self.bits -= 8;
        }
    }

    fn finish(self: *BitWriter) ![]u8 {
        if (self.bits > 0) try self.out.append(testing.allocator, @truncate(self.acc));
        return self.out.toOwnedSlice(testing.allocator);
    }
};

/// Explicit codes at explicit widths, for streams no encoder writes.
fn codes(list: []const struct { u16, u5 }) ![]u8 {
    var writer: BitWriter = .{};
    errdefer writer.out.deinit(testing.allocator);
    for (list) |entry| try writer.write(entry[0], entry[1]);
    return writer.finish();
}

/// GIF LZW (Appendix F) of `indices` at minimum code size `min`; OWNED. The
/// code width is giflib's rule: after writing a code, one more bit once the
/// next code to assign has reached the current width's limit, never more
/// than 12 - which is where the decoder widens, since it defines each entry
/// one code later than the encoder does.
fn lzwEncode(min: u4, indices: []const u8, options: EncodeOptions) ![]u8 {
    var encoder: Encoder = .{ .clear_code = @as(u16, 1) << min };
    encoder.next = encoder.clear_code + 2;
    encoder.width = @as(u5, min) + 1;
    var table: std.AutoHashMap(u32, u16) = .init(testing.allocator);
    defer table.deinit();
    errdefer encoder.writer.out.deinit(testing.allocator);

    if (options.clear_first) try encoder.put(encoder.clear_code);
    var prefix: ?u16 = null;
    for (indices) |c| {
        const w = prefix orelse {
            prefix = c;
            continue;
        };
        const key = (@as(u32, w) << 8) | c;
        if (table.get(key)) |code| {
            prefix = code;
            continue;
        }
        try encoder.put(w);
        if (encoder.next < 4096) {
            try table.put(key, encoder.next);
            encoder.next += 1;
        } else if (options.when_full == .clear) {
            try encoder.put(encoder.clear_code);
            table.clearRetainingCapacity();
            encoder.next = encoder.clear_code + 2;
            encoder.width = @as(u5, min) + 1;
        }
        prefix = c;
    }
    if (prefix) |w| try encoder.put(w);
    if (options.end) try encoder.put(encoder.clear_code + 1);
    return encoder.writer.finish();
}

const Encoder = struct {
    clear_code: u16,
    next: u16 = 0,
    width: u5 = 0,
    writer: BitWriter = .{},

    fn put(self: *Encoder, code: u16) !void {
        try self.writer.write(code, self.width);
        if (self.next >= (@as(u32, 1) << self.width) and self.width < 12) self.width += 1;
    }
};

const Frame = struct {
    x: u16 = 0,
    y: u16 = 0,
    width: u16,
    height: u16,
    local: ?[]const [3]u8 = null,
    interlaced: bool = false,
    min_code_size: u8 = 2,
    /// The LZW data, cut into sub-blocks by the writer.
    data: []const u8,
    /// Sub-block size the writer cuts at (at most 255).
    block: u8 = 255,
    terminator: bool = true,
};

const Gif = struct {
    version: []const u8 = "GIF89a",
    width: u16,
    height: u16,
    global: ?[]const [3]u8 = null,
    background: u8 = 0,
    /// Raw blocks between the screen descriptor and the frame (extensions).
    before: []const u8 = "",
    /// A Graphic Control Extension with this transparent index, just before
    /// the frame.
    transparent: ?u8 = null,
    frame: Frame,
    /// Raw bytes after the frame (later frames, the trailer).
    after: []const u8 = "\x3b",
};

fn tableField(table: []const [3]u8) u8 {
    // 2^(field + 1) entries.
    std.debug.assert(std.math.isPowerOfTwo(table.len) and table.len >= 2 and table.len <= 256);
    return @intCast(std.math.log2_int(usize, table.len) - 1);
}

fn le16(out: *std.ArrayList(u8), v: u16) !void {
    var b: [2]u8 = undefined;
    std.mem.writeInt(u16, &b, v, .little);
    try out.appendSlice(testing.allocator, &b);
}

/// The GIF `gif` describes; OWNED.
fn build(gif: Gif) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(testing.allocator);
    const a = testing.allocator;
    try out.appendSlice(a, gif.version);
    try le16(&out, gif.width);
    try le16(&out, gif.height);
    try out.append(a, if (gif.global) |t| 0x80 | 0x70 | tableField(t) else 0x70);
    try out.append(a, gif.background);
    try out.append(a, 0);
    if (gif.global) |t| for (t) |entry| try out.appendSlice(a, &entry);
    try out.appendSlice(a, gif.before);
    if (gif.transparent) |index| try out.appendSlice(a, &.{ 0x21, 0xf9, 4, 1, 0, 0, index, 0 });
    const f = gif.frame;
    try out.append(a, 0x2c);
    try le16(&out, f.x);
    try le16(&out, f.y);
    try le16(&out, f.width);
    try le16(&out, f.height);
    var flags: u8 = if (f.interlaced) 0x40 else 0;
    if (f.local) |t| flags |= 0x80 | tableField(t);
    try out.append(a, flags);
    if (f.local) |t| for (t) |entry| try out.appendSlice(a, &entry);
    try out.append(a, f.min_code_size);
    var rest = f.data;
    while (rest.len > 0) {
        const n = @min(rest.len, f.block);
        try out.append(a, @intCast(n));
        try out.appendSlice(a, rest[0..n]);
        rest = rest[n..];
    }
    if (f.terminator) try out.append(a, 0);
    try out.appendSlice(a, gif.after);
    return out.toOwnedSlice(a);
}

const rgbw = [_][3]u8{ .{ 255, 0, 0 }, .{ 0, 255, 0 }, .{ 0, 0, 255 }, .{ 255, 255, 255 } };

/// A GIF of `indices` (min code size 2, the four-colour table above) with
/// the frame and screen as given; OWNED.
fn simple(gif: Gif, indices: []const u8) ![]u8 {
    const data = try lzwEncode(2, indices, .{});
    defer testing.allocator.free(data);
    var g = gif;
    g.frame.data = data;
    if (g.global == null and g.frame.local == null) g.global = &rgbw;
    return build(g);
}

/// Deterministic noise: the C library's LCG, its bits 16 and up.
fn noise(out: []u8, mask: u8, seed: u32) void {
    var x = seed;
    for (out) |*v| {
        x = (x *% 1103515245 +% 12345) & 0x7fff_ffff;
        v.* = @as(u8, @truncate(x >> 16)) & mask;
    }
}

// ---------------------------------------------------------------------------
// The logical screen and the first frame
// ---------------------------------------------------------------------------

test "gif: a frame smaller than the screen is placed at its offset on a transparent canvas" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const bytes = try simple(.{ .width = 3, .height = 3, .frame = .{ .x = 1, .y = 1, .width = 2, .height = 2, .data = "" } }, &.{ 0, 1, 2, 3 });
    defer testing.allocator.free(bytes);
    try expectPixels(bytes, 3, 3, &.{
        clear, clear, clear,
        clear, red,   green,
        clear, blue,  white,
    });
}

test "gif: the background colour is not drawn" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // Background colour index 1 (green): every browser leaves what the frame
    // does not cover transparent.
    const bytes = try simple(.{ .width = 2, .height = 1, .background = 1, .frame = .{ .width = 1, .height = 1, .data = "" } }, &.{0});
    defer testing.allocator.free(bytes);
    try expectPixels(bytes, 2, 1, &.{ red, clear });
}

test "gif: a frame that runs past the screen is clipped to it" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // Screen 3x3, frame 2x2 at (2, 2): only its top-left pixel is on screen.
    const bytes = try simple(.{ .width = 3, .height = 3, .frame = .{ .x = 2, .y = 2, .width = 2, .height = 2, .data = "" } }, &.{ 0, 1, 2, 3 });
    defer testing.allocator.free(bytes);
    try expectPixels(bytes, 3, 3, &.{
        clear, clear, clear,
        clear, clear, clear,
        clear, clear, red,
    });
}

test "gif: a first frame larger than the screen makes the screen its size, at the origin" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // Firefox and Safari: the screen becomes the frame's size and the frame
    // moves to (0, 0) when it is wider or taller than the screen.
    const bytes = try simple(.{ .width = 2, .height = 2, .frame = .{ .x = 1, .y = 0, .width = 3, .height = 1, .data = "" } }, &.{ 0, 1, 2 });
    defer testing.allocator.free(bytes);
    try expectPixels(bytes, 3, 1, &.{ red, green, blue });
}

test "gif: a GIF87a's screen is its first frame's size" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // Firefox and Safari: "We assume that GIF87a files don't contain
    // animations": the screen is the first frame, whatever the descriptor.
    const bytes = try simple(.{ .version = "GIF87a", .width = 4, .height = 4, .frame = .{ .x = 1, .y = 1, .width = 2, .height = 1, .data = "" } }, &.{ 3, 0 });
    defer testing.allocator.free(bytes);
    try expectPixels(bytes, 2, 1, &.{ white, red });
}

test "gif: a zero-sized frame takes the screen's size" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const bytes = try simple(.{ .width = 2, .height = 1, .frame = .{ .width = 0, .height = 0, .data = "" } }, &.{ 1, 2 });
    defer testing.allocator.free(bytes);
    try expectPixels(bytes, 2, 1, &.{ green, blue });
    // Screen and frame both empty: there is no image.
    const empty = try simple(.{ .width = 0, .height = 0, .frame = .{ .width = 0, .height = 0, .data = "" } }, &.{0});
    defer testing.allocator.free(empty);
    try testing.expectError(error.Corrupt, decode(empty));
    // A zero-sized screen with a real frame: the frame's size.
    const no_screen = try simple(.{ .width = 0, .height = 0, .frame = .{ .width = 1, .height = 1, .data = "" } }, &.{2});
    defer testing.allocator.free(no_screen);
    try expectPixels(no_screen, 1, 1, &.{blue});
}

test "gif: a local colour table replaces the global one for its frame" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const local = [_][3]u8{ .{ 1, 2, 3 }, .{ 4, 5, 6 } };
    const bytes = try simple(.{ .width = 2, .height = 1, .global = &rgbw, .frame = .{ .width = 2, .height = 1, .local = &local, .data = "" } }, &.{ 1, 0 });
    defer testing.allocator.free(bytes);
    try expectPixels(bytes, 2, 1, &.{ .{ 4, 5, 6, 255 }, .{ 1, 2, 3, 255 } });
}

test "gif: an index past the colour table is opaque black, as is any index with no table" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // Two entries; indices 2 and 3 have none. (A three-way split between the
    // browsers, settled by PNG 13.1's rule: see gif.zig.)
    const two = [_][3]u8{ .{ 10, 20, 30 }, .{ 40, 50, 60 } };
    const bytes = try simple(.{ .width = 4, .height = 1, .global = &two, .frame = .{ .width = 4, .height = 1, .data = "" } }, &.{ 0, 1, 2, 3 });
    defer testing.allocator.free(bytes);
    try expectPixels(bytes, 4, 1, &.{ .{ 10, 20, 30, 255 }, .{ 40, 50, 60, 255 }, black, black });
    // No global and no local table.
    const data = try lzwEncode(2, &.{ 0, 3 }, .{});
    defer testing.allocator.free(data);
    const none = try build(.{ .width = 2, .height = 1, .frame = .{ .width = 2, .height = 1, .data = data } });
    defer testing.allocator.free(none);
    try expectPixels(none, 2, 1, &.{ black, black });
}

test "gif: the Graphic Control Extension's transparent index is transparent black" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const bytes = try simple(.{ .width = 4, .height = 1, .transparent = 2, .frame = .{ .width = 4, .height = 1, .data = "" } }, &.{ 0, 2, 3, 2 });
    defer testing.allocator.free(bytes);
    try expectPixels(bytes, 4, 1, &.{ red, clear, white, clear });
    // In a GIF87a too: decoders read the extension whatever the version.
    const old = try simple(.{ .version = "GIF87a", .width = 2, .height = 1, .transparent = 0, .frame = .{ .width = 2, .height = 1, .data = "" } }, &.{ 0, 1 });
    defer testing.allocator.free(old);
    try expectPixels(old, 2, 1, &.{ clear, green });
    // A transparent index past the table still makes its pixels transparent.
    {
        const data = try lzwEncode(4, &.{ 9, 1 }, .{});
        defer testing.allocator.free(data);
        const g = try build(.{ .width = 2, .height = 1, .global = &rgbw, .transparent = 9, .frame = .{ .width = 2, .height = 1, .min_code_size = 4, .data = data } });
        defer testing.allocator.free(g);
        try expectPixels(g, 2, 1, &.{ clear, green });
    }
}

test "gif: the last Graphic Control Extension before the frame applies; its flag decides" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // Two extensions: index 0 transparent, then index 1 transparent.
    const bytes = try simple(.{
        .width = 2,
        .height = 1,
        .before = "\x21\xf9\x04\x01\x00\x00\x00\x00" ++ "\x21\xf9\x04\x01\x00\x00\x01\x00",
        .frame = .{ .width = 2, .height = 1, .data = "" },
    }, &.{ 0, 1 });
    defer testing.allocator.free(bytes);
    try expectPixels(bytes, 2, 1, &.{ red, clear });
    // The flag clear: the index field is ignored.
    const unflagged = try simple(.{ .width = 2, .height = 1, .before = "\x21\xf9\x04\x00\x00\x00\x00\x00", .frame = .{ .width = 2, .height = 1, .data = "" } }, &.{ 0, 1 });
    defer testing.allocator.free(unflagged);
    try expectPixels(unflagged, 2, 1, &.{ red, green });
}

test "gif: comment, plain text, application and unknown extensions are skipped" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const extensions =
        // Comment: two sub-blocks.
        "\x21\xfe\x03abc\x02de\x00" ++
        // Plain text: a 12-byte header and one text sub-block.
        "\x21\x01\x0c\x00\x00\x00\x00\x08\x00\x08\x00\x08\x08\x01\x00\x02hi\x00" ++
        // NETSCAPE2.0 looping, and an ANIMEXTS1.0 buffering sub-block.
        "\x21\xff\x0bNETSCAPE2.0\x03\x01\x00\x00\x00" ++
        "\x21\xff\x0bANIMEXTS1.0\x05\x02\x10\x00\x00\x00\x00" ++
        // Another application's, with data.
        "\x21\xff\x0bXMP DataXMP\x04abcd\x00" ++
        // An unknown label.
        "\x21\x42\x02xy\x00" ++
        // An extension whose first sub-block is empty.
        "\x21\xfe\x00";
    const bytes = try simple(.{ .width = 2, .height = 1, .before = extensions, .frame = .{ .width = 2, .height = 1, .data = "" } }, &.{ 3, 2 });
    defer testing.allocator.free(bytes);
    try expectPixels(bytes, 2, 1, &.{ white, blue });
}

test "gif: a NETSCAPE2.0 sub-block of an undefined kind is corrupt" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // Firefox and Safari refuse sub-block ids 0 and 3-7 ("yet to be
    // defined netscape extension codes").
    const bytes = try simple(.{ .width = 1, .height = 1, .before = "\x21\xff\x0bNETSCAPE2.0\x03\x03\x00\x00\x00", .frame = .{ .width = 1, .height = 1, .data = "" } }, &.{0});
    defer testing.allocator.free(bytes);
    try testing.expectError(error.Corrupt, decode(bytes));
}

test "gif: what comes after the first frame is not read" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // A second frame (animation is a later batch), then junk where a block
    // should begin: the first frame is the image.
    const second = "\x21\xf9\x04\x00\x0a\x00\x00\x00\x2c\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02\x4c\x01\x00";
    const bytes = try simple(.{ .width = 1, .height = 1, .frame = .{ .width = 1, .height = 1, .data = "" }, .after = second ++ "\x99junk" }, &.{2});
    defer testing.allocator.free(bytes);
    try expectPixels(bytes, 1, 1, &.{blue});
}

test "gif: no image before the trailer, junk before the first image, or a wrong signature is corrupt" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    try testing.expectError(error.Corrupt, decode("GIF89a\x01\x00\x01\x00\x00\x00\x00\x3b"));
    try testing.expectError(error.Corrupt, decode("GIF89a\x01\x00\x01\x00\x00\x00\x00\x99"));
    try testing.expectError(error.Corrupt, decode("GIF89a\x01\x00\x01\x00\x00\x00\x00"));
    const bytes = try simple(.{ .width = 1, .height = 1, .frame = .{ .width = 1, .height = 1, .data = "" } }, &.{0});
    defer testing.allocator.free(bytes);
    for ([_][]const u8{ "GIF88a", "gif89a", "GIF89b", "PNG89a" }) |signature| {
        const copy = try testing.allocator.dupe(u8, bytes);
        defer testing.allocator.free(copy);
        @memcpy(copy[0..6], signature);
        try testing.expectError(error.Corrupt, decode(copy));
    }
}

test "gif: a screen larger than the limits is refused before its pixels" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // 65535 x 65535: allocating it would fail the testing allocator long
    // before the limits matter, so a TooLarge here is the check working.
    const bytes = try simple(.{ .width = 65535, .height = 65535, .frame = .{ .width = 1, .height = 1, .data = "" } }, &.{0});
    defer testing.allocator.free(bytes);
    try testing.expectError(error.TooLarge, decode(bytes));
    const small = try simple(.{ .width = 4, .height = 2, .frame = .{ .width = 1, .height = 1, .data = "" } }, &.{0});
    defer testing.allocator.free(small);
    const gif = platform.Str.from("image/gif");
    try testing.expectError(error.TooLarge, platform.decodeImage(testing.allocator, gif, platform.Bytes.from(small), .{ .max_dimension = 3, .max_pixels = 1 << 24 }));
    try testing.expectError(error.TooLarge, platform.decodeImage(testing.allocator, gif, platform.Bytes.from(small), .{ .max_dimension = 1 << 15, .max_pixels = 7 }));
    const image = try platform.decodeImage(testing.allocator, gif, platform.Bytes.from(small), .{ .max_dimension = 4, .max_pixels = 8 });
    free(image);
}

// ---------------------------------------------------------------------------
// Interlacing (Appendix E)
// ---------------------------------------------------------------------------

test "gif: interlaced rows are placed by Appendix E's four passes" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // Every height from 1 to 20: the stream gives row k of the stream index
    // k mod 4, and row r of the image must show the stream row Appendix E
    // puts there.
    for (1..21) |h| {
        // Rows in stream order: pass 1 (every 8th from 0), pass 2 (every 8th
        // from 4), pass 3 (every 4th from 2), pass 4 (every 2nd from 1).
        var order: [20]usize = undefined;
        var n: usize = 0;
        for ([_][2]usize{ .{ 0, 8 }, .{ 4, 8 }, .{ 2, 4 }, .{ 1, 2 } }) |pass| {
            var row = pass[0];
            while (row < h) : (row += pass[1]) {
                order[n] = row;
                n += 1;
            }
        }
        try testing.expectEqual(h, n);
        var indices: [20]u8 = undefined;
        for (0..h) |k| indices[k] = @intCast(k % 4);
        const bytes = try simple(.{ .width = 1, .height = @intCast(h), .frame = .{ .width = 1, .height = @intCast(h), .interlaced = true, .data = "" } }, indices[0..h]);
        defer testing.allocator.free(bytes);
        var expected: [20][4]u8 = undefined;
        const colors = [_][4]u8{ red, green, blue, white };
        for (0..h) |k| expected[order[k]] = colors[k % 4];
        try expectPixels(bytes, 1, @intCast(h), expected[0..h]);
    }
}

test "gif: an interlaced frame at an offset" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // 2x5 frame at (1, 0) on a 3x5 screen: stream rows land on 0, 4, 2, 1, 3.
    const bytes = try simple(.{ .width = 3, .height = 5, .frame = .{ .x = 1, .width = 2, .height = 5, .interlaced = true, .data = "" } }, &.{ 0, 0, 1, 1, 2, 2, 3, 3, 0, 1 });
    defer testing.allocator.free(bytes);
    try expectPixels(bytes, 3, 5, &.{
        clear, red,   red,
        clear, white, white,
        clear, blue,  blue,
        clear, red,   green,
        clear, green, green,
    });
}

// ---------------------------------------------------------------------------
// LZW (Appendix F)
// ---------------------------------------------------------------------------

/// Decode `indices` encoded at `min` with `options` (and a palette of 256
/// entries whose entry i is (i, 255 - i, i ^ 0x55)) and check every pixel.
fn roundTrip(min: u4, width: u16, height: u16, indices: []const u8, options: EncodeOptions, block: u8) !void {
    var palette: [256][3]u8 = undefined;
    for (&palette, 0..) |*entry, i| entry.* = .{ @intCast(i), @intCast(255 - i), @as(u8, @intCast(i)) ^ 0x55 };
    const data = try lzwEncode(min, indices, options);
    defer testing.allocator.free(data);
    const bytes = try build(.{ .width = width, .height = height, .global = &palette, .frame = .{ .width = width, .height = height, .min_code_size = min, .data = data, .block = block } });
    defer testing.allocator.free(bytes);
    const image = try decode(bytes);
    defer free(image);
    try testing.expectEqual(@as(u32, width), image.width);
    try testing.expectEqual(@as(u32, height), image.height);
    for (indices, 0..) |index, i| {
        const px = image.pixels.slice()[i * 4 ..][0..4];
        try testing.expectEqualSlices(u8, &.{ palette[index][0], palette[index][1], palette[index][2], 255 }, px);
    }
}

test "gif: every minimum code size from 2 to 8, through every code width to 12" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const pixels = try testing.allocator.alloc(u8, 200 * 150);
    defer testing.allocator.free(pixels);
    for (2..9) |m| {
        const min: u4 = @intCast(m);
        const mask: u8 = @intCast((@as(u16, 1) << min) - 1);
        // Noise: the table fills (and is cleared) many times over.
        noise(pixels, mask, @intCast(m));
        try roundTrip(min, 200, 150, pixels, .{}, 255);
        // Runs: long strings, the KwKwK case (a code defined by the code
        // itself) on every run.
        for (pixels, 0..) |*p, i| p.* = @intCast((i / 37) & mask);
        try roundTrip(min, 200, 150, pixels, .{}, 255);
    }
}

test "gif: a stream that never clears, or never ends, or is cut into small blocks" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    const pixels = try testing.allocator.alloc(u8, 64 * 64);
    defer testing.allocator.free(pixels);
    noise(pixels, 0x0f, 7);
    // No clear code first: the decoder starts in the clear state.
    try roundTrip(4, 64, 64, pixels, .{ .clear_first = false }, 255);
    // No end code: the data sub-blocks end, every pixel decoded.
    try roundTrip(4, 64, 64, pixels, .{ .end = false }, 255);
    // One-byte sub-blocks: codes straddle every block boundary.
    try roundTrip(4, 64, 64, pixels, .{}, 1);
    try roundTrip(4, 64, 64, pixels, .{}, 7);
}

test "gif: a deferred clear code - a full table used at 12 bits, never cleared" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // GIF89a's cover sheet: "when the decoder's table is full, it must not
    // change the table until a clear code is received. The Code Size is
    // that of the maximum Code Size."
    const pixels = try testing.allocator.alloc(u8, 256 * 256);
    defer testing.allocator.free(pixels);
    noise(pixels, 0xff, 1);
    try roundTrip(8, 256, 256, pixels, .{ .when_full = .defer_clear }, 255);
    noise(pixels, 0x03, 2);
    try roundTrip(2, 256, 256, pixels, .{ .when_full = .defer_clear }, 255);
    // An encoder and a decoder written together could share one mistake,
    // which a round trip would hide: pin this encoder's output for one input
    // to the bytes of an independent one (scratch Python, written for this
    // check) whose streams, deferred clear or not, PIL 12.0 decodes back to
    // the input.
    noise(pixels[0 .. 128 * 128], 0x0f, 3);
    const deferred = try lzwEncode(4, pixels[0 .. 128 * 128], .{ .when_full = .defer_clear });
    defer testing.allocator.free(deferred);
    try testing.expectEqualStrings("ae2a10d17b42596507fea9a275fd13e713635244c011d213336c98ad3cebf14c", &hexDigest(deferred));
    const cleared = try lzwEncode(4, pixels[0 .. 128 * 128], .{});
    defer testing.allocator.free(cleared);
    try testing.expectEqualStrings("6a28529568c0e28efa276984bff90701e424e71f32b9db894d236cbb155b368b", &hexDigest(cleared));
}

test "gif: data that ends early - an end code or a block terminator - leaves the rest transparent" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // 2x2, but the stream holds three pixels and an end code.
    const early_end = try simple(.{ .width = 2, .height = 2, .frame = .{ .width = 2, .height = 2, .data = "" } }, &.{ 0, 1, 2 });
    defer testing.allocator.free(early_end);
    try expectPixels(early_end, 2, 2, &.{ red, green, blue, clear });
    // 3x2, four pixels and no end code: the block terminator ends the data.
    // (Codes that end on a byte boundary: padding bits after a last code
    // would be read as more codes.) After the third code the next free code
    // is 8, so the fourth is 4 bits wide.
    const data = try codes(&.{ .{ 4, 3 }, .{ 3, 3 }, .{ 2, 3 }, .{ 1, 3 }, .{ 0, 4 } });
    defer testing.allocator.free(data);
    try testing.expectEqual(@as(usize, 2), data.len);
    const short = try build(.{ .width = 3, .height = 2, .global = &rgbw, .frame = .{ .width = 3, .height = 2, .data = data } });
    defer testing.allocator.free(short);
    try expectPixels(short, 3, 2, &.{ white, blue, green, red, clear, clear });
}

test "gif: data past the last pixel is ignored" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // Six pixels of data for a 2x2 frame, then more sub-blocks.
    const data = try lzwEncode(2, &.{ 0, 1, 2, 3, 3, 3 }, .{});
    defer testing.allocator.free(data);
    const bytes = try build(.{ .width = 2, .height = 2, .global = &rgbw, .frame = .{ .width = 2, .height = 2, .data = data, .block = 1 } });
    defer testing.allocator.free(bytes);
    try expectPixels(bytes, 2, 2, &.{ red, green, blue, white });
}

test "gif: minimum code sizes 9 to 11 decode, 12 and more are corrupt" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // Firefox and Safari read up to 11 (the clear code must fit 12 bits);
    // a literal is the low 8 bits of its code (their 8-bit string table).
    // Literals 0-3 at minimum code size 9: clear 512, end 513, 10-bit codes.
    const data = try codes(&.{ .{ 512, 10 }, .{ 3, 10 }, .{ 2, 10 }, .{ 256 + 1, 10 }, .{ 513, 10 } });
    defer testing.allocator.free(data);
    const nine = try build(.{ .width = 3, .height = 1, .global = &rgbw, .frame = .{ .width = 3, .height = 1, .min_code_size = 9, .data = data } });
    defer testing.allocator.free(nine);
    try expectPixels(nine, 3, 1, &.{ white, blue, green });
    for ([_]u8{ 12, 13, 255 }) |size| {
        const bad = try build(.{ .width = 1, .height = 1, .global = &rgbw, .frame = .{ .width = 1, .height = 1, .min_code_size = size, .data = "\x00\x00" } });
        defer testing.allocator.free(bad);
        try testing.expectError(error.Corrupt, decode(bad));
    }
}

test "gif: a code past the next free one repeats the previous string (Firefox, Safari)" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // Minimum code size 2: clear 4, end 5, first free code 6. After a 1, the
    // code 7 is one past the next free one: Firefox and Safari decode it as
    // they decode the next free code (the previous string plus its first
    // index), so "1 1" after the first 1; then the end code, early.
    const data = try codes(&.{ .{ 4, 3 }, .{ 1, 3 }, .{ 7, 3 }, .{ 5, 3 } });
    defer testing.allocator.free(data);
    const bytes = try build(.{ .width = 4, .height = 1, .global = &rgbw, .frame = .{ .width = 4, .height = 1, .data = data } });
    defer testing.allocator.free(bytes);
    try expectPixels(bytes, 4, 1, &.{ green, green, green, clear });
}

test "gif: a code table that refers to itself is corrupt" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    // After clear: 0; then 7 (past the next free code 6, taken as 6: entry
    // 6 = (0, 0), and the previous code becomes 7); then the literal 1 makes
    // entry 7 = (7, 1) - its own prefix. Decoding 7 then loops: corrupt, as
    // Firefox and Safari find it.
    const data = try codes(&.{ .{ 4, 3 }, .{ 0, 3 }, .{ 7, 3 }, .{ 1, 3 }, .{ 7, 4 }, .{ 5, 4 } });
    defer testing.allocator.free(data);
    const bytes = try build(.{ .width = 8, .height = 1, .global = &rgbw, .frame = .{ .width = 8, .height = 1, .data = data } });
    defer testing.allocator.free(bytes);
    try testing.expectError(error.Corrupt, decode(bytes));
}

// ---------------------------------------------------------------------------
// Truncation and damage
// ---------------------------------------------------------------------------

test "gif: every truncation fails cleanly, or decodes the whole first frame" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    inline for (.{ "css/css-lists/resources/white.gif", "images/anim-rgb.gif", "css/CSS2/backgrounds/support/animated.gif", "css/css-ui/support/cursors/tp1n3p08.gif" }) |path| {
        const bytes = try readWpt(path);
        defer testing.allocator.free(bytes);
        const whole = try decode(bytes);
        defer free(whole);
        for (0..bytes.len) |len| {
            const image = decode(bytes[0..len]) catch |err| {
                try testing.expectEqual(error.Corrupt, err);
                continue;
            };
            defer free(image);
            // A cut after the first frame's last pixel may succeed, and then
            // with every pixel.
            try testing.expectEqualSlices(u8, whole.pixels.slice(), image.pixels.slice());
        }
    }
}

test "gif: a flipped byte anywhere never crashes or leaks" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    inline for (.{ "css/css-lists/resources/white.gif", "css/CSS2/backgrounds/support/animated.gif", "html/editing/dnd/resources/1x1-transparent.gif" }) |path| {
        const original = try readWpt(path);
        defer testing.allocator.free(original);
        const bytes = try testing.allocator.dupe(u8, original);
        defer testing.allocator.free(bytes);
        for (0..bytes.len) |i| {
            for ([_]u8{ 0x01, 0x80, 0xff }) |mask| {
                bytes[i] = original[i] ^ mask;
                defer bytes[i] = original[i];
                if (decode(bytes)) |image| free(image) else |_| {}
            }
        }
    }
}

test "gif: noise after the signature never crashes or leaks" {
    if (platform.capabilities.image_decoding == .unsupported) return;
    var bytes: [600]u8 = undefined;
    for (0..300) |seed| {
        noise(&bytes, 0xff, @intCast(seed));
        @memcpy(bytes[0..6], "GIF89a");
        // Small limits, so a lucky parse does not allocate much.
        const small: platform.ImageLimits = .{ .max_dimension = 1024, .max_pixels = 1 << 16 };
        if (platform.decodeImage(testing.allocator, platform.Str.from("image/gif"), platform.Bytes.from(&bytes), small)) |image| free(image) else |_| {}
    }
}
