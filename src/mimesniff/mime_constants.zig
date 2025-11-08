//! Comptime MIME Type Constants
//!
//! This module provides compile-time MIME type constants for common types.
//! These constants are borrowed (not owned), so they can be returned without
//! allocation, significantly improving performance in pattern matching.

const mime_type = @import("mime_type.zig");
const infra = @import("infra");

/// Empty OrderedMap for comptime constants (no parameters)
const EmptyMap = infra.OrderedMap(infra.String, infra.String);
const empty_params = EmptyMap.init(undefined);

// Image MIME types
pub const IMAGE_PNG = mime_type.MimeType{
    .type = &.{ 'i', 'm', 'a', 'g', 'e' },
    .subtype = &.{ 'p', 'n', 'g' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

pub const IMAGE_JPEG = mime_type.MimeType{
    .type = &.{ 'i', 'm', 'a', 'g', 'e' },
    .subtype = &.{ 'j', 'p', 'e', 'g' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

pub const IMAGE_GIF = mime_type.MimeType{
    .type = &.{ 'i', 'm', 'a', 'g', 'e' },
    .subtype = &.{ 'g', 'i', 'f' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

pub const IMAGE_WEBP = mime_type.MimeType{
    .type = &.{ 'i', 'm', 'a', 'g', 'e' },
    .subtype = &.{ 'w', 'e', 'b', 'p' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

pub const IMAGE_BMP = mime_type.MimeType{
    .type = &.{ 'i', 'm', 'a', 'g', 'e' },
    .subtype = &.{ 'b', 'm', 'p' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

pub const IMAGE_ICON = mime_type.MimeType{
    .type = &.{ 'i', 'm', 'a', 'g', 'e' },
    .subtype = &.{ 'x', '-', 'i', 'c', 'o', 'n' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

// Audio MIME types
pub const AUDIO_AIFF = mime_type.MimeType{
    .type = &.{ 'a', 'u', 'd', 'i', 'o' },
    .subtype = &.{ 'a', 'i', 'f', 'f' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

pub const AUDIO_MPEG = mime_type.MimeType{
    .type = &.{ 'a', 'u', 'd', 'i', 'o' },
    .subtype = &.{ 'm', 'p', 'e', 'g' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

pub const AUDIO_WAVE = mime_type.MimeType{
    .type = &.{ 'a', 'u', 'd', 'i', 'o' },
    .subtype = &.{ 'w', 'a', 'v', 'e' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

pub const AUDIO_MIDI = mime_type.MimeType{
    .type = &.{ 'a', 'u', 'd', 'i', 'o' },
    .subtype = &.{ 'm', 'i', 'd', 'i' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

// Video MIME types
pub const VIDEO_MP4 = mime_type.MimeType{
    .type = &.{ 'v', 'i', 'd', 'e', 'o' },
    .subtype = &.{ 'm', 'p', '4' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

pub const VIDEO_WEBM = mime_type.MimeType{
    .type = &.{ 'v', 'i', 'd', 'e', 'o' },
    .subtype = &.{ 'w', 'e', 'b', 'm' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

pub const VIDEO_AVI = mime_type.MimeType{
    .type = &.{ 'v', 'i', 'd', 'e', 'o' },
    .subtype = &.{ 'a', 'v', 'i' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

pub const APPLICATION_OGG = mime_type.MimeType{
    .type = &.{ 'a', 'p', 'p', 'l', 'i', 'c', 'a', 't', 'i', 'o', 'n' },
    .subtype = &.{ 'o', 'g', 'g' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

// Font MIME types
pub const FONT_WOFF = mime_type.MimeType{
    .type = &.{ 'f', 'o', 'n', 't' },
    .subtype = &.{ 'w', 'o', 'f', 'f' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

pub const FONT_WOFF2 = mime_type.MimeType{
    .type = &.{ 'f', 'o', 'n', 't' },
    .subtype = &.{ 'w', 'o', 'f', 'f', '2' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

pub const FONT_TTF = mime_type.MimeType{
    .type = &.{ 'f', 'o', 'n', 't' },
    .subtype = &.{ 't', 't', 'f' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

pub const FONT_OTF = mime_type.MimeType{
    .type = &.{ 'f', 'o', 'n', 't' },
    .subtype = &.{ 'o', 't', 'f' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

pub const FONT_COLLECTION = mime_type.MimeType{
    .type = &.{ 'f', 'o', 'n', 't' },
    .subtype = &.{ 'c', 'o', 'l', 'l', 'e', 'c', 't', 'i', 'o', 'n' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

pub const APPLICATION_VND_MS_FONTOBJECT = mime_type.MimeType{
    .type = &.{ 'a', 'p', 'p', 'l', 'i', 'c', 'a', 't', 'i', 'o', 'n' },
    .subtype = &.{ 'v', 'n', 'd', '.', 'm', 's', '-', 'f', 'o', 'n', 't', 'o', 'b', 'j', 'e', 'c', 't' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

// Archive MIME types
pub const APPLICATION_GZIP = mime_type.MimeType{
    .type = &.{ 'a', 'p', 'p', 'l', 'i', 'c', 'a', 't', 'i', 'o', 'n' },
    .subtype = &.{ 'x', '-', 'g', 'z', 'i', 'p' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

pub const APPLICATION_ZIP = mime_type.MimeType{
    .type = &.{ 'a', 'p', 'p', 'l', 'i', 'c', 'a', 't', 'i', 'o', 'n' },
    .subtype = &.{ 'z', 'i', 'p' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

pub const APPLICATION_X_RAR_COMPRESSED = mime_type.MimeType{
    .type = &.{ 'a', 'p', 'p', 'l', 'i', 'c', 'a', 't', 'i', 'o', 'n' },
    .subtype = &.{ 'x', '-', 'r', 'a', 'r', '-', 'c', 'o', 'm', 'p', 'r', 'e', 's', 's', 'e', 'd' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

// Common fallback types
pub const TEXT_PLAIN = mime_type.MimeType{
    .type = &.{ 't', 'e', 'x', 't' },
    .subtype = &.{ 'p', 'l', 'a', 'i', 'n' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};

pub const APPLICATION_OCTET_STREAM = mime_type.MimeType{
    .type = &.{ 'a', 'p', 'p', 'l', 'i', 'c', 'a', 't', 'i', 'o', 'n' },
    .subtype = &.{ 'o', 'c', 't', 'e', 't', '-', 's', 't', 'r', 'e', 'a', 'm' },
    .parameters = empty_params,
    .owned = false,
    .allocator = undefined,
};
