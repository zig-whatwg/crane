//! The testing platform's image decoding (decisions 19 and 19a): the
//! decoders are Zig, compiled into the platform, so the WPT runner's results
//! do not depend on the machine's image libraries. The MIME type Crane
//! determined picks the decoder (MIME Sniffing's image rules run above the
//! protocol); each decoder writes the protocol's DecodedImage.
//!
//! | MIME type | Decoder |
//! |---|---|
//! | image/png, image/apng | png.zig (W3C PNG Third Edition) |
//!
//! Anything else is `UnsupportedFormat`: the image is broken.

const std = @import("std");
const platform = @import("platform");
const png = @import("png.zig");

pub fn decodeImage(allocator: std.mem.Allocator, mime: platform.Str, bytes: platform.Bytes, limits: platform.ImageLimits) platform.ImageError!platform.DecodedImage {
    const essence = mimeEssence(mime.slice());
    if (std.ascii.eqlIgnoreCase(essence, "image/png") or std.ascii.eqlIgnoreCase(essence, "image/apng")) {
        return png.decode(allocator, bytes.slice(), limits);
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
