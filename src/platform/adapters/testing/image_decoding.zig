//! The testing platform's image decoding (decisions 19, 19a and 19c): the
//! decoders are compiled into the platform, so the WPT runner's results
//! do not depend on the machine's image libraries. The MIME type Crane
//! determined picks the decoder (MIME Sniffing's image rules run above the
//! protocol); each decoder writes the protocol's DecodedImage.
//!
//! | MIME type | Decoder |
//! |---|---|
//! | image/png, image/apng | png.zig (W3C PNG Third Edition) |
//! | image/bmp | bmp.zig (Windows and OS/2 bitmaps, as Blink reads them; decision 19a) |
//! | image/gif | gif.zig (GIF87a and GIF89a, the first frame; decision 19c) |
//! | image/jpeg | pinned libjpeg-turbo, through kit/image_codecs |
//! | image/svg+xml | pinned Expat + NanoSVG, through kit/image_codecs |
//!
//! Anything else is `UnsupportedFormat`: the image is broken.

const std = @import("std");
const platform = @import("platform");
const png = @import("png.zig");
const bmp = @import("bmp.zig");
const gif = @import("gif.zig");
const image_codecs = @import("kit_image_codecs");

const Decoder = struct {
    essence: []const u8,
    decode: *const fn (std.mem.Allocator, []const u8, platform.ImageLimits) platform.ImageError!platform.DecodedImage,
};

// One table answers both selection and decoding, so they cannot drift.
const decoders = [_]Decoder{
    .{ .essence = "image/png", .decode = png.decode },
    .{ .essence = "image/apng", .decode = png.decode },
    .{ .essence = "image/bmp", .decode = bmp.decode },
    .{ .essence = "image/x-bmp", .decode = bmp.decode },
    .{ .essence = "image/x-ms-bmp", .decode = bmp.decode },
    .{ .essence = "image/gif", .decode = gif.decode },
    .{ .essence = "image/jpeg", .decode = image_codecs.jpeg },
    .{ .essence = "image/svg+xml", .decode = image_codecs.svg },
};

pub fn imageMimeTypeSupported(essence: platform.Str) bool {
    for (decoders) |decoder| {
        if (std.mem.eql(u8, essence.slice(), decoder.essence)) return true;
    }
    return false;
}

pub fn decodeImage(allocator: std.mem.Allocator, mime: platform.Str, bytes: platform.Bytes, limits: platform.ImageLimits) platform.ImageError!platform.DecodedImage {
    const essence = mimeEssence(mime.slice());
    for (decoders) |decoder| {
        if (std.ascii.eqlIgnoreCase(essence, decoder.essence)) return decoder.decode(allocator, bytes.slice(), limits);
    }
    return error.UnsupportedFormat;
}

/// The type and subtype of a MIME type string, parameters and surrounding
/// whitespace dropped (MIME Sniffing 4.1's essence, without the full parse:
/// Crane passes a serialized MIME type).
fn mimeEssence(mime: []const u8) []const u8 {
    const end = std.mem.indexOfScalar(u8, mime, ';') orelse mime.len;
    return std.mem.trim(u8, mime[0..end], " \t\r\n");
}
