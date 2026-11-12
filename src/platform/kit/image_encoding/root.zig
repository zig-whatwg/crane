//! kit/image_encoding: the built-in image encoders, which every built-in
//! platform - darwin, linux and testing - answers the `image_encoding`
//! capability with, as kit/image_decoding answers `image_decoding` (D1, the
//! user 2026-11-09: "The platform itself that is compiled in will decide if
//! these features are built within the platform or dynamically link out to
//! existing capabilities on the platform"). Crane runs HTML's "a
//! serialization of the bitmap as a file" (4.12.5.5) above the protocol -
//! the type, its fallback to PNG, the alpha conversion - and the platform
//! turns pixels into one file of the type Crane chose.
//!
//! | MIME type | Encoder |
//! |---|---|
//! | image/png | png.zig (W3C PNG Third Edition), which HTML requires every user agent to support |
//!
//! Anything else is `UnsupportedFormat`. HTML lets a user agent support
//! more ("User agents may support other types"); image/jpeg, which all
//! three browsers encode, is queued (the integrator, 2026-11-12).

const std = @import("std");
const platform = @import("platform");
const png = @import("png.zig");

const Encoder = struct {
    essence: []const u8,
    encode: *const fn (std.mem.Allocator, u32, u32, []const u8) png.Error![]u8,
};

// One table answers both the query and the encode, so they cannot drift.
const encoders = [_]Encoder{
    .{ .essence = "image/png", .encode = png.encode },
};

pub fn imageEncodingMimeTypeSupported(essence: platform.Str) bool {
    for (encoders) |encoder| {
        if (std.mem.eql(u8, essence.slice(), encoder.essence)) return true;
    }
    return false;
}

/// `quality` is for a format with a quality level; PNG has none.
pub fn encodeImage(allocator: std.mem.Allocator, mime: platform.Str, source: platform.EncodeSource, quality: f64) platform.ImageEncodeError!platform.Bytes {
    _ = quality;
    for (encoders) |encoder| {
        if (!std.mem.eql(u8, mime.slice(), encoder.essence)) continue;
        const bytes = encoder.encode(allocator, source.width, source.height, source.pixels.slice()) catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            error.TooLarge => error.TooLarge,
            error.UnsupportedFormat => error.UnsupportedFormat,
        };
        return platform.Bytes.from(bytes);
    }
    return error.UnsupportedFormat;
}

test {
    _ = png;
}
