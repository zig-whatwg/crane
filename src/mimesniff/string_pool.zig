//! String Interning Pool for Common MIME Type Components
//!
//! This module provides compile-time string constants for the most common
//! MIME type component strings. By interning these strings, we can avoid
//! allocations for ~80% of real-world MIME types.
//!
//! All strings are UTF-16 (infra.String) and immutable (comptime constants).
//! No runtime state, no initialization required, thread-safe.

const std = @import("std");
const infra = @import("infra");

/// Common MIME type strings (UTF-16, comptime constants)
///
/// These cover the most frequently used MIME type components based on
/// web usage statistics:
/// - text/* (HTML, CSS, JavaScript, plain text)
/// - image/* (PNG, JPEG, GIF, WebP, SVG)
/// - application/* (JSON, XML, PDF, ZIP)
/// - audio/video/* (MP3, MP4, WebM)
/// - font/* (WOFF, WOFF2, TTF, OTF)

// ============================================================================
// Type Strings (6 most common)
// ============================================================================

pub const TYPE_TEXT: infra.String = &[_]u16{ 't', 'e', 'x', 't' };
pub const TYPE_IMAGE: infra.String = &[_]u16{ 'i', 'm', 'a', 'g', 'e' };
pub const TYPE_APPLICATION: infra.String = &[_]u16{ 'a', 'p', 'p', 'l', 'i', 'c', 'a', 't', 'i', 'o', 'n' };
pub const TYPE_AUDIO: infra.String = &[_]u16{ 'a', 'u', 'd', 'i', 'o' };
pub const TYPE_VIDEO: infra.String = &[_]u16{ 'v', 'i', 'd', 'e', 'o' };
pub const TYPE_FONT: infra.String = &[_]u16{ 'f', 'o', 'n', 't' };

// ============================================================================
// Subtype Strings (20 most common)
// ============================================================================

// Text subtypes
pub const SUBTYPE_HTML: infra.String = &[_]u16{ 'h', 't', 'm', 'l' };
pub const SUBTYPE_PLAIN: infra.String = &[_]u16{ 'p', 'l', 'a', 'i', 'n' };
pub const SUBTYPE_CSS: infra.String = &[_]u16{ 'c', 's', 's' };
pub const SUBTYPE_JAVASCRIPT: infra.String = &[_]u16{ 'j', 'a', 'v', 'a', 's', 'c', 'r', 'i', 'p', 't' };
pub const SUBTYPE_XML: infra.String = &[_]u16{ 'x', 'm', 'l' };

// Image subtypes
pub const SUBTYPE_PNG: infra.String = &[_]u16{ 'p', 'n', 'g' };
pub const SUBTYPE_JPEG: infra.String = &[_]u16{ 'j', 'p', 'e', 'g' };
pub const SUBTYPE_GIF: infra.String = &[_]u16{ 'g', 'i', 'f' };
pub const SUBTYPE_WEBP: infra.String = &[_]u16{ 'w', 'e', 'b', 'p' };
pub const SUBTYPE_SVG_XML: infra.String = &[_]u16{ 's', 'v', 'g', '+', 'x', 'm', 'l' };

// Application subtypes
pub const SUBTYPE_JSON: infra.String = &[_]u16{ 'j', 's', 'o', 'n' };
pub const SUBTYPE_PDF: infra.String = &[_]u16{ 'p', 'd', 'f' };
pub const SUBTYPE_ZIP: infra.String = &[_]u16{ 'z', 'i', 'p' };
pub const SUBTYPE_OCTET_STREAM: infra.String = &[_]u16{ 'o', 'c', 't', 'e', 't', '-', 's', 't', 'r', 'e', 'a', 'm' };

// Audio/Video subtypes
pub const SUBTYPE_MPEG: infra.String = &[_]u16{ 'm', 'p', 'e', 'g' };
pub const SUBTYPE_MP4: infra.String = &[_]u16{ 'm', 'p', '4' };
pub const SUBTYPE_WEBM: infra.String = &[_]u16{ 'w', 'e', 'b', 'm' };

// Font subtypes
pub const SUBTYPE_WOFF: infra.String = &[_]u16{ 'w', 'o', 'f', 'f' };
pub const SUBTYPE_WOFF2: infra.String = &[_]u16{ 'w', 'o', 'f', 'f', '2' };
pub const SUBTYPE_TTF: infra.String = &[_]u16{ 't', 't', 'f' };

// ============================================================================
// String Comparison Helper
// ============================================================================

/// Compare two UTF-16 strings for equality
inline fn stringEquals(a: infra.String, b: infra.String) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (ca != cb) return false;
    }
    return true;
}

// ============================================================================
// Interning Functions
// ============================================================================

/// Try to intern a type string
///
/// Returns pointer to interned string if found in pool, null otherwise.
/// Caller must allocate if null is returned.
///
/// The returned pointer points to a comptime constant and never needs to be freed.
pub fn internType(str: infra.String) ?infra.String {
    if (stringEquals(str, TYPE_TEXT)) return TYPE_TEXT;
    if (stringEquals(str, TYPE_IMAGE)) return TYPE_IMAGE;
    if (stringEquals(str, TYPE_APPLICATION)) return TYPE_APPLICATION;
    if (stringEquals(str, TYPE_AUDIO)) return TYPE_AUDIO;
    if (stringEquals(str, TYPE_VIDEO)) return TYPE_VIDEO;
    if (stringEquals(str, TYPE_FONT)) return TYPE_FONT;
    return null;
}

/// Try to intern a subtype string
///
/// Returns pointer to interned string if found in pool, null otherwise.
/// Caller must allocate if null is returned.
///
/// The returned pointer points to a comptime constant and never needs to be freed.
pub fn internSubtype(str: infra.String) ?infra.String {
    // Text subtypes
    if (stringEquals(str, SUBTYPE_HTML)) return SUBTYPE_HTML;
    if (stringEquals(str, SUBTYPE_PLAIN)) return SUBTYPE_PLAIN;
    if (stringEquals(str, SUBTYPE_CSS)) return SUBTYPE_CSS;
    if (stringEquals(str, SUBTYPE_JAVASCRIPT)) return SUBTYPE_JAVASCRIPT;
    if (stringEquals(str, SUBTYPE_XML)) return SUBTYPE_XML;

    // Image subtypes
    if (stringEquals(str, SUBTYPE_PNG)) return SUBTYPE_PNG;
    if (stringEquals(str, SUBTYPE_JPEG)) return SUBTYPE_JPEG;
    if (stringEquals(str, SUBTYPE_GIF)) return SUBTYPE_GIF;
    if (stringEquals(str, SUBTYPE_WEBP)) return SUBTYPE_WEBP;
    if (stringEquals(str, SUBTYPE_SVG_XML)) return SUBTYPE_SVG_XML;

    // Application subtypes
    if (stringEquals(str, SUBTYPE_JSON)) return SUBTYPE_JSON;
    if (stringEquals(str, SUBTYPE_PDF)) return SUBTYPE_PDF;
    if (stringEquals(str, SUBTYPE_ZIP)) return SUBTYPE_ZIP;
    if (stringEquals(str, SUBTYPE_OCTET_STREAM)) return SUBTYPE_OCTET_STREAM;

    // Audio/Video subtypes
    if (stringEquals(str, SUBTYPE_MPEG)) return SUBTYPE_MPEG;
    if (stringEquals(str, SUBTYPE_MP4)) return SUBTYPE_MP4;
    if (stringEquals(str, SUBTYPE_WEBM)) return SUBTYPE_WEBM;

    // Font subtypes
    if (stringEquals(str, SUBTYPE_WOFF)) return SUBTYPE_WOFF;
    if (stringEquals(str, SUBTYPE_WOFF2)) return SUBTYPE_WOFF2;
    if (stringEquals(str, SUBTYPE_TTF)) return SUBTYPE_TTF;

    return null;
}

/// Check if a string is interned (points to pool constant)
///
/// Used by MimeType.deinit() to determine if a string should be freed.
/// Interned strings must NOT be freed (they're comptime constants).
///
/// Implementation: Check if pointer matches any interned string pointer.
pub fn isInterned(str: infra.String) bool {
    const ptr = str.ptr;

    // Check type pointers
    if (ptr == TYPE_TEXT.ptr) return true;
    if (ptr == TYPE_IMAGE.ptr) return true;
    if (ptr == TYPE_APPLICATION.ptr) return true;
    if (ptr == TYPE_AUDIO.ptr) return true;
    if (ptr == TYPE_VIDEO.ptr) return true;
    if (ptr == TYPE_FONT.ptr) return true;

    // Check subtype pointers
    if (ptr == SUBTYPE_HTML.ptr) return true;
    if (ptr == SUBTYPE_PLAIN.ptr) return true;
    if (ptr == SUBTYPE_CSS.ptr) return true;
    if (ptr == SUBTYPE_JAVASCRIPT.ptr) return true;
    if (ptr == SUBTYPE_XML.ptr) return true;
    if (ptr == SUBTYPE_PNG.ptr) return true;
    if (ptr == SUBTYPE_JPEG.ptr) return true;
    if (ptr == SUBTYPE_GIF.ptr) return true;
    if (ptr == SUBTYPE_WEBP.ptr) return true;
    if (ptr == SUBTYPE_SVG_XML.ptr) return true;
    if (ptr == SUBTYPE_JSON.ptr) return true;
    if (ptr == SUBTYPE_PDF.ptr) return true;
    if (ptr == SUBTYPE_ZIP.ptr) return true;
    if (ptr == SUBTYPE_OCTET_STREAM.ptr) return true;
    if (ptr == SUBTYPE_MPEG.ptr) return true;
    if (ptr == SUBTYPE_MP4.ptr) return true;
    if (ptr == SUBTYPE_WEBM.ptr) return true;
    if (ptr == SUBTYPE_WOFF.ptr) return true;
    if (ptr == SUBTYPE_WOFF2.ptr) return true;
    if (ptr == SUBTYPE_TTF.ptr) return true;

    return false;
}

// ============================================================================
// Tests
// ============================================================================

test "internType - common types" {
    const type_text = &[_]u16{ 't', 'e', 'x', 't' };
    const interned = internType(type_text);
    try std.testing.expect(interned != null);
    try std.testing.expect(interned.?.ptr == TYPE_TEXT.ptr);
}

test "internType - uncommon type returns null" {
    const type_multipart = &[_]u16{ 'm', 'u', 'l', 't', 'i', 'p', 'a', 'r', 't' };
    const interned = internType(type_multipart);
    try std.testing.expect(interned == null);
}

test "internSubtype - common subtypes" {
    const subtype_html = &[_]u16{ 'h', 't', 'm', 'l' };
    const interned = internSubtype(subtype_html);
    try std.testing.expect(interned != null);
    try std.testing.expect(interned.?.ptr == SUBTYPE_HTML.ptr);
}

test "internSubtype - uncommon subtype returns null" {
    const subtype_markdown = &[_]u16{ 'm', 'a', 'r', 'k', 'd', 'o', 'w', 'n' };
    const interned = internSubtype(subtype_markdown);
    try std.testing.expect(interned == null);
}

test "isInterned - detects interned strings" {
    try std.testing.expect(isInterned(TYPE_TEXT));
    try std.testing.expect(isInterned(TYPE_IMAGE));
    try std.testing.expect(isInterned(SUBTYPE_HTML));
    try std.testing.expect(isInterned(SUBTYPE_JSON));
}

test "isInterned - rejects non-interned strings" {
    const allocator = std.testing.allocator;
    const custom = try allocator.alloc(u16, 4);
    defer allocator.free(custom);

    @memcpy(custom, &[_]u16{ 't', 'e', 'x', 't' });
    try std.testing.expect(!isInterned(custom));
}
