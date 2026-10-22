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

pub fn decodeImage(allocator: std.mem.Allocator, mime: platform.Str, bytes: platform.Bytes, limits: platform.ImageLimits) platform.ImageError!platform.DecodedImage {
    const essence = mimeEssence(mime.slice());
    if (std.ascii.eqlIgnoreCase(essence, "image/png") or std.ascii.eqlIgnoreCase(essence, "image/apng")) {
        return png.decode(allocator, bytes.slice(), limits);
    }
    // MIME Sniffing's image type pattern gives image/bmp; image/x-bmp and
    // image/x-ms-bmp are the names servers also send.
    if (std.ascii.eqlIgnoreCase(essence, "image/bmp") or std.ascii.eqlIgnoreCase(essence, "image/x-bmp") or std.ascii.eqlIgnoreCase(essence, "image/x-ms-bmp")) {
        return bmp.decode(allocator, bytes.slice(), limits);
    }
    // MIME Sniffing's image type pattern gives image/gif for both versions.
    if (std.ascii.eqlIgnoreCase(essence, "image/gif")) {
        return gif.decode(allocator, bytes.slice(), limits);
    }
    if (std.ascii.eqlIgnoreCase(essence, "image/jpeg")) {
        return image_codecs.jpeg(allocator, bytes.slice(), limits);
    }
    if (std.ascii.eqlIgnoreCase(essence, "image/svg+xml")) {
        return image_codecs.svg(allocator, bytes.slice(), limits);
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
