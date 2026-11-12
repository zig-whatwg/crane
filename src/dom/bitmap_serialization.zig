//! HTML 4.12.5.5 "a serialization of the bitmap as a file", and the data:
//! URL HTMLCanvasElement.toDataURL step 5 makes of one: shared by every
//! bitmap that serializes - a canvas element's (toDataURL, toBlob), and
//! OffscreenCanvas.convertToBlob's when it exists. No IDL member serializes
//! a bitmap on its own, so this is a helper, reached by its callers' impls;
//! the encoder is the platform's (the `image_encoding` capability).
//!
//! Crane's side of the algorithm, the platform's encoding beneath it:
//! - the type: "convert the provided type to ASCII lowercase before
//!   establishing if they support that type"; one the platform does not
//!   encode - one with parameters included ("If the type has any
//!   parameters, then it must be treated as not supported") - is PNG ("If
//!   the user agent does not support the requested type, then it must create
//!   the file using the PNG format"). The lowercased type is compared whole,
//!   unparsed and untrimmed, as Blink (ImageEncoderUtils::ToEncodingMimeType)
//!   and WebKit (MIMETypeRegistry::isSupportedImageMIMETypeForEncoding)
//!   compare it;
//! - the pixels: a 2D context's bitmap is premultiplied (4.12.5.7), a file
//!   holds straight alpha - unpremultiplied here, as every browser's encoder
//!   input is; a canvas with no context is transparent black of its size;
//! - an error - the encoder's, or a platform that encodes nothing - is a
//!   null serialization.
//!
//! Spec: https://html.spec.whatwg.org/multipage/canvas.html#a-serialisation-of-the-bitmap-as-a-file

const std = @import("std");
const platform = @import("platform");
const image_sources = @import("image_sources.zig");

/// A bitmap to serialize: `width` x `height`, both non-zero.
pub const Bitmap = struct {
    width: u32,
    height: u32,
    /// Premultiplied RGBA8, rows top down (a 2D context's output bitmap),
    /// BORROWED; null for a transparent black bitmap that nothing stores (a
    /// canvas with no rendering context).
    pixels: ?[]const u8,
};

/// A serialization: one file and the MIME type it is in.
pub const File = struct {
    /// The file's type, lowercase: the requested one the platform encodes,
    /// else "image/png".
    mime_buffer: [max_type_len]u8 = undefined,
    mime_len: usize = 0,
    /// OWNED by the allocator `serialize` was given.
    bytes: []const u8,

    pub fn mime(self: *const File) []const u8 {
        return self.mime_buffer[0..self.mime_len];
    }

    pub fn deinit(self: File, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
    }
};

/// The longest type the platform is asked about; a longer one is no type
/// any encoder takes, so it is PNG.
const max_type_len = 64;

const png = "image/png";

/// HTML 4.12.5.5 for `bitmap`, with `requested_type` when the caller
/// supplied one and `quality` when it is "a Number in the range 0.0 to 1.0
/// inclusive" (else null: the platform's default). Null: "an error occurs
/// during the creation of the image file".
pub fn serialize(allocator: std.mem.Allocator, bitmap: Bitmap, requested_type: ?[]const u8, quality: ?f64) ?File {
    // A platform without the capability encodes nothing: compiled out.
    if (comptime platform.capabilities.image_encoding == .unsupported) {
        return null;
    } else {
        return encode(allocator, bitmap, requested_type, quality);
    }
}

fn encode(allocator: std.mem.Allocator, bitmap: Bitmap, requested_type: ?[]const u8, quality: ?f64) ?File {
    var file: File = .{ .bytes = "" };
    var scratch: [max_type_len]u8 = undefined;
    const mime = chooseType(&scratch, requested_type);
    @memcpy(file.mime_buffer[0..mime.len], mime);
    file.mime_len = mime.len;

    // The file's pixel data is the bitmap's, one image pixel per coordinate
    // space unit, straight alpha.
    const len = std.math.mul(usize, std.math.mul(usize, bitmap.width, bitmap.height) catch return null, 4) catch return null;
    const straight = allocator.alloc(u8, len) catch return null;
    defer allocator.free(straight);
    if (bitmap.pixels) |pixels| {
        if (pixels.len != len) return null;
        unpremultiplyInto(straight, pixels);
    } else @memset(straight, 0);

    const encoded = platform.encodeImage(allocator, platform.Str.from(mime), .{
        .width = bitmap.width,
        .height = bitmap.height,
        .pixels = platform.Bytes.from(straight),
    }, quality orelse -1) catch return null;
    file.bytes = encoded.slice();
    return file;
}

/// The type the file is made in: `requested_type` lowercased, when the
/// platform encodes it, else PNG. Written into `buffer`.
fn chooseType(buffer: *[max_type_len]u8, requested_type: ?[]const u8) []const u8 {
    const requested = requested_type orelse return png;
    if (requested.len == 0 or requested.len > max_type_len) return png;
    const lowered = std.ascii.lowerString(buffer[0..requested.len], requested);
    if (platform.imageEncodingMimeTypeSupported(platform.Str.from(lowered))) return lowered;
    return png;
}

/// Premultiplied RGBA8 `from` to straight `into` (image_sources.unpremultiply:
/// alpha 0 is transparent black, as no colour survives it).
fn unpremultiplyInto(into: []u8, from: []const u8) void {
    var i: usize = 0;
    while (i < from.len) : (i += 4) {
        const alpha = from[i + 3];
        into[i] = image_sources.unpremultiply(from[i], alpha);
        into[i + 1] = image_sources.unpremultiply(from[i + 1], alpha);
        into[i + 2] = image_sources.unpremultiply(from[i + 2], alpha);
        into[i + 3] = alpha;
    }
}

/// toDataURL step 5: "a data: URL representing file" - its type, then its
/// bytes in base64 (RFC 2397), as every browser writes it:
/// "data:image/png;base64,...". OWNED by `allocator`.
pub fn dataUrl(allocator: std.mem.Allocator, file: *const File) error{OutOfMemory}![]u8 {
    const encoder = std.base64.standard.Encoder;
    const prefix_len = "data:".len + file.mime_len + ";base64,".len;
    const out = try allocator.alloc(u8, prefix_len + encoder.calcSize(file.bytes.len));
    const prefix = std.fmt.bufPrint(out[0..prefix_len], "data:{s};base64,", .{file.mime()}) catch unreachable;
    _ = encoder.encode(out[prefix.len..], file.bytes);
    return out;
}

test "a premultiplied bitmap serializes as straight-alpha PNG; alpha 0 is transparent black" {
    if (comptime platform.capabilities.image_encoding == .unsupported) return error.SkipZigTest;
    const allocator = std.testing.allocator;
    // Half-transparent red, then a colour alpha 0 cannot keep.
    const pixels = [_]u8{ 128, 0, 0, 128, 200, 100, 50, 0 };
    const file = serialize(allocator, .{ .width = 2, .height = 1, .pixels = &pixels }, null, null) orelse return error.TestUnexpectedResult;
    defer file.deinit(allocator);
    try std.testing.expectEqualStrings("image/png", file.mime());
    if (comptime platform.capabilities.image_decoding == .unsupported) return;
    const image = try platform.decodeImage(allocator, platform.Str.from("image/png"), platform.Bytes.from(file.bytes), .{ .max_dimension = 16, .max_pixels = 256 });
    defer allocator.free(image.pixels.slice());
    try std.testing.expectEqualSlices(u8, &.{ 255, 0, 0, 128, 0, 0, 0, 0 }, image.pixels.slice());
}

test "the type is lowercased, and any the platform does not encode is PNG" {
    if (comptime platform.capabilities.image_encoding == .unsupported) return error.SkipZigTest;
    const allocator = std.testing.allocator;
    const long: [100]u8 = @splat('x');
    for ([_]?[]const u8{ null, "IMAGE/PNG", "image/jpeg", "image/png;foo=bar", " image/png", "", &long }) |requested| {
        const file = serialize(allocator, .{ .width = 1, .height = 1, .pixels = null }, requested, 0.5) orelse return error.TestUnexpectedResult;
        defer file.deinit(allocator);
        try std.testing.expectEqualStrings("image/png", file.mime());
        const url = try dataUrl(allocator, &file);
        defer allocator.free(url);
        try std.testing.expect(std.mem.startsWith(u8, url, "data:image/png;base64,iVBORw0KGgo"));
    }
}
