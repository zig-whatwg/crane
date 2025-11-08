//! WHATWG MIME Type Sniffing Algorithms
//!
//! Spec: https://mimesniff.spec.whatwg.org/#determining-the-computed-mime-type
//!
//! This module implements the core MIME type sniffing algorithms that determine
//! the computed MIME type of a resource based on byte patterns and metadata.

const std = @import("std");
const mime_type = @import("mime_type.zig");
const MimeType = mime_type.MimeType;
const resource_mod = @import("resource.zig");
const Resource = resource_mod.Resource;
const predicates = @import("predicates.zig");
const pattern_matching = @import("pattern_matching.zig");
const constants = @import("constants.zig");
const mime_constants = @import("mime_constants.zig");

/// Sniff MIME type in a browsing context (WHATWG MIME Sniffing §8.1)
///
/// This is the entry point for sniffing in a browsing context (the main
/// context for web pages). It simply delegates to the main MIME type
/// sniffing algorithm.
///
/// Parameters:
///   - allocator: Memory allocator
///   - res: Resource with supplied MIME type and flags
///   - resource_header: First bytes of the resource (up to 1445 bytes)
///
/// Returns: Computed MIME type (may be null if undefined)
///
/// Spec: https://mimesniff.spec.whatwg.org/#sniffing-in-a-browsing-context
pub fn sniffInBrowsingContext(
    allocator: std.mem.Allocator,
    res: *const Resource,
    resource_header: []const u8,
) !?MimeType {
    // Use the MIME type sniffing algorithm
    return try sniffMimeType(allocator, res, resource_header);
}

/// Sniff the MIME type of a resource (WHATWG MIME Sniffing §7)
///
/// This is the main entry point for MIME type sniffing. It determines the
/// computed MIME type of a resource based on the supplied MIME type,
/// resource header, and various flags.
///
/// Parameters:
///   - allocator: Memory allocator
///   - res: Resource with supplied MIME type and flags
///   - resource_header: First bytes of the resource (up to 1445 bytes)
///
/// Returns: Computed MIME type (may be null if undefined)
///
/// Spec: https://mimesniff.spec.whatwg.org/#mime-type-sniffing-algorithm
pub fn sniffMimeType(
    allocator: std.mem.Allocator,
    res: *const Resource,
    resource_header: []const u8,
) !?MimeType {
    // 1. If the supplied MIME type is an XML MIME type or HTML MIME type,
    //    the computed MIME type is the supplied MIME type. Abort these steps.
    if (res.supplied_mime_type) |supplied| {
        if (predicates.isXmlMimeType(&supplied) or predicates.isHtmlMimeType(&supplied)) {
            // Return a copy of the supplied MIME type
            return try copyMimeType(allocator, supplied);
        }
    }

    // 2. If the supplied MIME type is undefined or its essence is
    //    "unknown/unknown", "application/unknown", or "*/*",
    //    execute the rules for identifying an unknown MIME type
    if (res.supplied_mime_type == null) {
        const sniff_scriptable = !res.no_sniff;
        return try identifyUnknownMimeType(allocator, resource_header, sniff_scriptable);
    }

    if (res.supplied_mime_type) |supplied| {
        if (essenceEquals(&supplied, "unknown", "unknown") or
            essenceEquals(&supplied, "application", "unknown") or
            essenceEquals(&supplied, "*", "*"))
        {
            const sniff_scriptable = !res.no_sniff;
            return try identifyUnknownMimeType(allocator, resource_header, sniff_scriptable);
        }
    }

    // 3. If the no-sniff flag is set, the computed MIME type is the supplied MIME type.
    //    Abort these steps.
    if (res.no_sniff) {
        if (res.supplied_mime_type) |supplied| {
            return try copyMimeType(allocator, supplied);
        }
        return null;
    }

    // 4. If the check-for-apache-bug flag is set, execute the rules for
    //    distinguishing if a resource is text or binary and abort these steps.
    if (res.check_for_apache_bug) {
        return try distinguishTextOrBinary(allocator, resource_header);
    }

    // 5. If the supplied MIME type is an image MIME type supported by the user agent
    if (res.supplied_mime_type) |supplied| {
        if (predicates.isImageMimeType(&supplied)) {
            // Let matched-type be the result of executing the image type pattern matching algorithm
            if (pattern_matching.matchImageTypePattern(resource_header)) |matched| {
                return matched;
            }
            // If matched-type is undefined, fall through
        }
    }

    // 6. If the supplied MIME type is an audio or video MIME type supported by the user agent
    if (res.supplied_mime_type) |supplied| {
        if (predicates.isAudioOrVideoMimeType(&supplied)) {
            // Let matched-type be the result of executing the audio or video type pattern matching algorithm
            if (pattern_matching.matchAudioOrVideoTypePattern(resource_header)) |matched| {
                return matched;
            }
            // If matched-type is undefined, fall through
        }
    }

    // 7. The computed MIME type is the supplied MIME type
    if (res.supplied_mime_type) |supplied| {
        return try copyMimeType(allocator, supplied);
    }

    return null;
}

/// Identify an unknown MIME type (WHATWG MIME Sniffing §7.1)
///
/// Determines the computed MIME type of a resource with an unknown MIME type
/// by checking byte patterns for various content types.
///
/// Parameters:
///   - allocator: Memory allocator
///   - resource_header: First bytes of the resource
///   - sniff_scriptable: Whether to sniff for scriptable MIME types (HTML, XML, PDF)
///
/// Returns: Computed MIME type
///
/// Spec: https://mimesniff.spec.whatwg.org/#rules-for-identifying-an-unknown-mime-type
pub fn identifyUnknownMimeType(
    allocator: std.mem.Allocator,
    resource_header: []const u8,
    sniff_scriptable: bool,
) !?MimeType {
    // 1. If the sniff-scriptable flag is set, check for scriptable types
    if (sniff_scriptable) {
        // Check HTML patterns (case-insensitive with tag-terminating byte)
        // Spec: https://mimesniff.spec.whatwg.org/#rules-for-identifying-an-unknown-mime-type
        const html_patterns = [_]struct { pattern: []const u8, mask: []const u8 }{
            .{ .pattern = "\x3C\x21\x44\x4F\x43\x54\x59\x50\x45\x20\x48\x54\x4D\x4C\x20", .mask = "\xFF\xFF\xDF\xDF\xDF\xDF\xDF\xDF\xDF\xFF\xDF\xDF\xDF\xDF\xFF" }, // "<!DOCTYPE HTML "
            .{ .pattern = "\x3C\x48\x54\x4D\x4C\x20", .mask = "\xFF\xDF\xDF\xDF\xDF\xFF" }, // "<HTML "
            .{ .pattern = "\x3C\x48\x45\x41\x44\x20", .mask = "\xFF\xDF\xDF\xDF\xDF\xFF" }, // "<HEAD "
            .{ .pattern = "\x3C\x53\x43\x52\x49\x50\x54\x20", .mask = "\xFF\xDF\xDF\xDF\xDF\xDF\xDF\xFF" }, // "<SCRIPT "
            .{ .pattern = "\x3C\x49\x46\x52\x41\x4D\x45\x20", .mask = "\xFF\xDF\xDF\xDF\xDF\xDF\xDF\xFF" }, // "<IFRAME "
            .{ .pattern = "\x3C\x48\x31\x20", .mask = "\xFF\xDF\xFF\xFF" }, // "<H1 "
            .{ .pattern = "\x3C\x44\x49\x56\x20", .mask = "\xFF\xDF\xDF\xDF\xFF" }, // "<DIV "
            .{ .pattern = "\x3C\x46\x4F\x4E\x54\x20", .mask = "\xFF\xDF\xDF\xDF\xDF\xFF" }, // "<FONT "
            .{ .pattern = "\x3C\x54\x41\x42\x4C\x45\x20", .mask = "\xFF\xDF\xDF\xDF\xDF\xDF\xFF" }, // "<TABLE "
            .{ .pattern = "\x3C\x41\x20", .mask = "\xFF\xDF\xFF" }, // "<A "
            .{ .pattern = "\x3C\x53\x54\x59\x4C\x45\x20", .mask = "\xFF\xDF\xDF\xDF\xDF\xDF\xFF" }, // "<STYLE "
            .{ .pattern = "\x3C\x54\x49\x54\x4C\x45\x20", .mask = "\xFF\xDF\xDF\xDF\xDF\xDF\xFF" }, // "<TITLE "
            .{ .pattern = "\x3C\x42\x20", .mask = "\xFF\xDF\xFF" }, // "<B "
            .{ .pattern = "\x3C\x42\x4F\x44\x59\x20", .mask = "\xFF\xDF\xDF\xDF\xDF\xFF" }, // "<BODY "
            .{ .pattern = "\x3C\x42\x52\x20", .mask = "\xFF\xDF\xDF\xFF" }, // "<BR "
            .{ .pattern = "\x3C\x50\x20", .mask = "\xFF\xDF\xFF" }, // "<P "
            .{ .pattern = "\x3C\x21\x2D\x2D\x20", .mask = "\xFF\xFF\xFF\xFF\xFF" }, // "<!--"
        };

        const whitespace = "\x09\x0A\x0C\x0D\x20"; // Whitespace bytes to ignore

        for (html_patterns) |p| {
            if (pattern_matching.patternMatching(resource_header, p.pattern, p.mask, whitespace)) {
                return try mime_type.parseMimeType(allocator, "text/html");
            }
        }

        // Check for <?xml
        const xml_pattern = "\x3C\x3F\x78\x6D\x6C"; // "<?xml"
        const xml_mask = "\xFF\xFF\xFF\xFF\xFF";
        if (pattern_matching.patternMatching(resource_header, xml_pattern, xml_mask, whitespace)) {
            return try mime_type.parseMimeType(allocator, "text/xml");
        }

        // Check for %PDF-
        const pdf_pattern = "\x25\x50\x44\x46\x2D"; // "%PDF-"
        const pdf_mask = "\xFF\xFF\xFF\xFF\xFF";
        const no_ignored = "";
        if (pattern_matching.patternMatching(resource_header, pdf_pattern, pdf_mask, no_ignored)) {
            return try mime_type.parseMimeType(allocator, "application/pdf");
        }
    }

    // 2. Check for PostScript signature
    const ps_pattern = "\x25\x21\x50\x53\x2D\x41\x64\x6F\x62\x65\x2D"; // "%!PS-Adobe-"
    const ps_mask = "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF";
    const no_ignored = "";
    if (pattern_matching.patternMatching(resource_header, ps_pattern, ps_mask, no_ignored)) {
        return try mime_type.parseMimeType(allocator, "application/postscript");
    }

    // Check for UTF-16BE BOM
    const utf16be_pattern = "\xFE\xFF";
    const utf16be_mask = "\xFF\xFF";
    if (pattern_matching.patternMatching(resource_header, utf16be_pattern, utf16be_mask, no_ignored)) {
        return mime_constants.TEXT_PLAIN;
    }

    // Check for UTF-16LE BOM
    const utf16le_pattern = "\xFF\xFE";
    const utf16le_mask = "\xFF\xFF";
    if (pattern_matching.patternMatching(resource_header, utf16le_pattern, utf16le_mask, no_ignored)) {
        return mime_constants.TEXT_PLAIN;
    }

    // Check for UTF-8 BOM
    const utf8_pattern = "\xEF\xBB\xBF";
    const utf8_mask = "\xFF\xFF\xFF";
    if (pattern_matching.patternMatching(resource_header, utf8_pattern, utf8_mask, no_ignored)) {
        return mime_constants.TEXT_PLAIN;
    }

    // 3. Check for image types
    if (pattern_matching.matchImageTypePattern(resource_header)) |matched| {
        return matched;
    }

    // 4. Check for audio/video types
    if (pattern_matching.matchAudioOrVideoTypePattern(resource_header)) |matched| {
        return matched;
    }

    // 5. Check for archive types
    if (pattern_matching.matchArchiveTypePattern(resource_header)) |matched| {
        return matched;
    }

    // 6. If resource header contains no binary data bytes, return "text/plain"
    if (!containsBinaryDataBytes(resource_header)) {
        return mime_constants.TEXT_PLAIN;
    }

    // 7. Return "application/octet-stream"
    return mime_constants.APPLICATION_OCTET_STREAM;
}

/// Distinguish if a resource is text or binary (WHATWG MIME Sniffing §7.2)
///
/// Determines whether a binary resource has been mislabeled as plain text.
/// This is used when the check-for-apache-bug flag is set.
///
/// Parameters:
///   - allocator: Memory allocator
///   - resource_header: First bytes of the resource
///
/// Returns: "text/plain" or "application/octet-stream"
///
/// Spec: https://mimesniff.spec.whatwg.org/#rules-for-distinguishing-if-a-resource-is-text-or-binary
pub fn distinguishTextOrBinary(
    allocator: std.mem.Allocator,
    resource_header: []const u8,
) !?MimeType {
    _ = allocator; // No longer needed - we return constants
    const length = resource_header.len;

    // 1. If length >= 2 and first 2 bytes are UTF-16BE or UTF-16LE BOM
    if (length >= 2) {
        if ((resource_header[0] == 0xFE and resource_header[1] == 0xFF) or
            (resource_header[0] == 0xFF and resource_header[1] == 0xFE))
        {
            return mime_constants.TEXT_PLAIN;
        }
    }

    // 2. If length >= 3 and first 3 bytes are UTF-8 BOM
    if (length >= 3) {
        if (resource_header[0] == 0xEF and
            resource_header[1] == 0xBB and
            resource_header[2] == 0xBF)
        {
            return mime_constants.TEXT_PLAIN;
        }
    }

    // 3. If resource header contains no binary data bytes, return "text/plain"
    if (!containsBinaryDataBytes(resource_header)) {
        return mime_constants.TEXT_PLAIN;
    }

    // 4. Return "application/octet-stream"
    return mime_constants.APPLICATION_OCTET_STREAM;
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Check if byte sequence contains binary data bytes
///
/// A binary data byte is a byte in the range 0x00 to 0x08 (NUL to BS),
/// the byte 0x0B (VT), a byte in the range 0x0E to 0x1A (SO to SUB),
/// or a byte in the range 0x1C to 0x1F (FS to US).
fn containsBinaryDataBytes(data: []const u8) bool {
    for (data) |byte| {
        if (constants.isBinaryDataByte(byte)) {
            return true;
        }
    }
    return false;
}

/// Check if UTF-16 string equals ASCII string (no allocation)
inline fn stringEqualsAscii(utf16_str: []const u16, ascii_str: []const u8) bool {
    if (utf16_str.len != ascii_str.len)
        return false;

    for (utf16_str, 0..) |c, i| {
        if (c != ascii_str[i])
            return false;
    }

    return true;
}

/// Check if MIME type essence equals given type and subtype (no allocation)
inline fn essenceEquals(mt: *const MimeType, type_str: []const u8, subtype_str: []const u8) bool {
    return stringEqualsAscii(mt.type, type_str) and stringEqualsAscii(mt.subtype, subtype_str);
}

/// Get the essence of a MIME type (as UTF-8 bytes)
fn getEssence(allocator: std.mem.Allocator, mt: *const MimeType) ![]const u8 {
    const infra = @import("infra");

    const type_utf8 = try infra.bytes.isomorphicEncode(allocator, mt.type);
    defer allocator.free(type_utf8);

    const subtype_utf8 = try infra.bytes.isomorphicEncode(allocator, mt.subtype);
    defer allocator.free(subtype_utf8);

    const essence = try allocator.alloc(u8, type_utf8.len + 1 + subtype_utf8.len);
    @memcpy(essence[0..type_utf8.len], type_utf8);
    essence[type_utf8.len] = '/';
    @memcpy(essence[type_utf8.len + 1 ..], subtype_utf8);

    return essence;
}

/// Create a deep copy of a MIME type
fn copyMimeType(allocator: std.mem.Allocator, mt: MimeType) !MimeType {
    const infra = @import("infra");

    // Copy type
    const type_copy = try allocator.alloc(u16, mt.type.len);
    @memcpy(type_copy, mt.type);

    // Copy subtype
    const subtype_copy = try allocator.alloc(u16, mt.subtype.len);
    @memcpy(subtype_copy, mt.subtype);

    // Copy parameters
    var params_copy = infra.OrderedMap(infra.String, infra.String).init(allocator);
    const entries = mt.parameters.entries.items();
    for (entries) |entry| {
        const key_copy = try allocator.alloc(u16, entry.key.len);
        @memcpy(key_copy, entry.key);

        const value_copy = try allocator.alloc(u16, entry.value.len);
        @memcpy(value_copy, entry.value);

        try params_copy.set(key_copy, value_copy);
    }

    return MimeType{
        .type = type_copy,
        .subtype = subtype_copy,
        .parameters = params_copy,
        .owned = true,
        .allocator = allocator,
    };
}

// ============================================================================
// Context-Specific Sniffing (WHATWG MIME Sniffing §8)
// ============================================================================

/// Sniff MIME type in an image context (WHATWG MIME Sniffing §8.2)
///
/// To determine the computed MIME type of a resource with an image MIME type.
///
/// Parameters:
///   - allocator: Memory allocator
///   - supplied_mime_type: The supplied MIME type
///   - resource_header: First bytes of the resource
///
/// Returns: Computed MIME type
///
/// Spec: https://mimesniff.spec.whatwg.org/#sniffing-in-an-image-context
pub fn sniffInImageContext(
    allocator: std.mem.Allocator,
    supplied_mime_type: ?MimeType,
    resource_header: []const u8,
) !?MimeType {
    // 1. If the supplied MIME type is an XML MIME type, the computed MIME type
    //    is the supplied MIME type. Abort these steps.
    if (supplied_mime_type) |supplied| {
        if (predicates.isXmlMimeType(&supplied)) {
            return try copyMimeType(allocator, supplied);
        }
    }

    // 2. Let image-type-matched be the result of executing the image type
    //    pattern matching algorithm with the resource header
    // 3. If image-type-matched is not undefined, the computed MIME type is
    //    image-type-matched. Abort these steps.
    if (pattern_matching.matchImageTypePattern(resource_header)) |matched| {
        return matched;
    }

    // 4. The computed MIME type is the supplied MIME type
    if (supplied_mime_type) |supplied| {
        return try copyMimeType(allocator, supplied);
    }

    return null;
}

/// Sniff MIME type in an audio or video context (WHATWG MIME Sniffing §8.3)
///
/// To determine the computed MIME type of a resource with an audio or video MIME type.
///
/// Parameters:
///   - allocator: Memory allocator
///   - supplied_mime_type: The supplied MIME type
///   - resource_header: First bytes of the resource
///
/// Returns: Computed MIME type
///
/// Spec: https://mimesniff.spec.whatwg.org/#sniffing-in-an-audio-or-video-context
pub fn sniffInAudioOrVideoContext(
    allocator: std.mem.Allocator,
    supplied_mime_type: ?MimeType,
    resource_header: []const u8,
) !?MimeType {
    // 1. If the supplied MIME type is an XML MIME type, the computed MIME type
    //    is the supplied MIME type. Abort these steps.
    if (supplied_mime_type) |supplied| {
        if (predicates.isXmlMimeType(&supplied)) {
            return try copyMimeType(allocator, supplied);
        }
    }

    // 2. Let audio-or-video-type-matched be the result of executing the
    //    audio or video type pattern matching algorithm
    // 3. If audio-or-video-type-matched is not undefined, the computed MIME type
    //    is audio-or-video-type-matched. Abort these steps.
    if (pattern_matching.matchAudioOrVideoTypePattern(resource_header)) |matched| {
        return matched;
    }

    // 4. The computed MIME type is the supplied MIME type
    if (supplied_mime_type) |supplied| {
        return try copyMimeType(allocator, supplied);
    }

    return null;
}

/// Sniff MIME type in a font context (WHATWG MIME Sniffing §8.7)
///
/// To determine the computed MIME type of a resource with a font MIME type.
///
/// Parameters:
///   - allocator: Memory allocator
///   - supplied_mime_type: The supplied MIME type
///   - resource_header: First bytes of the resource
///
/// Returns: Computed MIME type
///
/// Spec: https://mimesniff.spec.whatwg.org/#sniffing-in-a-font-context
pub fn sniffInFontContext(
    allocator: std.mem.Allocator,
    supplied_mime_type: ?MimeType,
    resource_header: []const u8,
) !?MimeType {
    // 1. If the supplied MIME type is an XML MIME type, the computed MIME type
    //    is the supplied MIME type. Abort these steps.
    if (supplied_mime_type) |supplied| {
        if (predicates.isXmlMimeType(&supplied)) {
            return try copyMimeType(allocator, supplied);
        }
    }

    // 2. Let font-type-matched be the result of executing the font type
    //    pattern matching algorithm
    // 3. If font-type-matched is not undefined, the computed MIME type is
    //    font-type-matched. Abort these steps.
    if (pattern_matching.matchFontTypePattern(resource_header)) |matched| {
        return matched;
    }

    // 4. The computed MIME type is the supplied MIME type
    if (supplied_mime_type) |supplied| {
        return try copyMimeType(allocator, supplied);
    }

    return null;
}

/// Sniff MIME type in a plugin context (WHATWG MIME Sniffing §8.4)
///
/// To determine the computed MIME type of a resource fetched in a plugin context.
///
/// Parameters:
///   - allocator: Memory allocator
///   - supplied_mime_type: The supplied MIME type (may be undefined)
///
/// Returns: Computed MIME type
///
/// Spec: https://mimesniff.spec.whatwg.org/#sniffing-in-a-plugin-context
pub fn sniffInPluginContext(
    allocator: std.mem.Allocator,
    supplied_mime_type: ?MimeType,
) !?MimeType {
    // 1. If the supplied MIME type is undefined, the computed MIME type is
    //    "application/octet-stream".
    if (supplied_mime_type == null) {
        return mime_constants.APPLICATION_OCTET_STREAM;
    }

    // 2. The computed MIME type is the supplied MIME type
    if (supplied_mime_type) |supplied| {
        return try copyMimeType(allocator, supplied);
    }

    return null;
}

/// Sniff MIME type in a style context (WHATWG MIME Sniffing §8.5)
///
/// To determine the computed MIME type of a resource fetched in a style context.
/// Note: The spec leaves this undefined for now.
///
/// Parameters:
///   - allocator: Memory allocator
///   - supplied_mime_type: The supplied MIME type
///
/// Returns: Computed MIME type (the supplied MIME type)
///
/// Spec: https://mimesniff.spec.whatwg.org/#sniffing-in-a-style-context
pub fn sniffInStyleContext(
    allocator: std.mem.Allocator,
    supplied_mime_type: ?MimeType,
) !?MimeType {
    // The computed MIME type is the supplied MIME type
    if (supplied_mime_type) |supplied| {
        return try copyMimeType(allocator, supplied);
    }

    return null;
}

/// Sniff MIME type in a script context (WHATWG MIME Sniffing §8.6)
///
/// To determine the computed MIME type of a resource fetched in a script context.
/// Note: The spec leaves this undefined for now.
///
/// Parameters:
///   - allocator: Memory allocator
///   - supplied_mime_type: The supplied MIME type
///
/// Returns: Computed MIME type (the supplied MIME type)
///
/// Spec: https://mimesniff.spec.whatwg.org/#sniffing-in-a-script-context
pub fn sniffInScriptContext(
    allocator: std.mem.Allocator,
    supplied_mime_type: ?MimeType,
) !?MimeType {
    // The computed MIME type is the supplied MIME type
    if (supplied_mime_type) |supplied| {
        return try copyMimeType(allocator, supplied);
    }

    return null;
}

/// Sniff MIME type in a text track context (WHATWG MIME Sniffing §8.8)
///
/// The computed MIME type is always "text/vtt".
///
/// Parameters:
///   - allocator: Memory allocator
///
/// Returns: "text/vtt"
///
/// Spec: https://mimesniff.spec.whatwg.org/#sniffing-in-a-text-track-context
pub fn sniffInTextTrackContext(allocator: std.mem.Allocator) !?MimeType {
    return try mime_type.parseMimeType(allocator, "text/vtt");
}

/// Sniff MIME type in a cache manifest context (WHATWG MIME Sniffing §8.9)
///
/// The computed MIME type is always "text/cache-manifest".
///
/// Parameters:
///   - allocator: Memory allocator
///
/// Returns: "text/cache-manifest"
///
/// Spec: https://mimesniff.spec.whatwg.org/#sniffing-in-a-cache-manifest-context
pub fn sniffInCacheManifestContext(allocator: std.mem.Allocator) !?MimeType {
    return try mime_type.parseMimeType(allocator, "text/cache-manifest");
}

// ============================================================================
// Tests
// ============================================================================

test "sniffMimeType - XML MIME type returns supplied" {
    const allocator = std.testing.allocator;

    var res = Resource.init(allocator);
    defer res.deinit();

    res.supplied_mime_type = (try mime_type.parseMimeType(allocator, "application/xml")).?;

    const resource_header = "<xml>";
    const computed = try sniffMimeType(allocator, &res, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("application/xml", essence);
    } else {
        try std.testing.expect(false); // Should not be null
    }
}

test "sniffMimeType - HTML MIME type returns supplied" {
    const allocator = std.testing.allocator;

    var res = Resource.init(allocator);
    defer res.deinit();

    res.supplied_mime_type = (try mime_type.parseMimeType(allocator, "text/html")).?;

    const resource_header = "<html>";
    const computed = try sniffMimeType(allocator, &res, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "sniffMimeType - no-sniff flag returns supplied" {
    const allocator = std.testing.allocator;

    var res = Resource.init(allocator);
    defer res.deinit();

    res.supplied_mime_type = (try mime_type.parseMimeType(allocator, "text/plain")).?;
    res.no_sniff = true;

    // Resource header is PNG, but no-sniff should prevent sniffing
    const resource_header = "\x89PNG\x0D\x0A\x1A\x0A";
    const computed = try sniffMimeType(allocator, &res, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/plain", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "identifyUnknownMimeType - HTML detection" {
    const allocator = std.testing.allocator;

    const resource_header = "<!DOCTYPE HTML >"; // Space before > is tag-terminating
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "identifyUnknownMimeType - PNG detection" {
    const allocator = std.testing.allocator;

    const resource_header = "\x89PNG\x0D\x0A\x1A\x0A";
    const computed = try identifyUnknownMimeType(allocator, resource_header, false);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("image/png", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "identifyUnknownMimeType - text/plain for no binary data" {
    const allocator = std.testing.allocator;

    const resource_header = "Hello, World!";
    const computed = try identifyUnknownMimeType(allocator, resource_header, false);

    if (computed) |mt| {
        const essence = try getEssence(allocator, &mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/plain", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "identifyUnknownMimeType - application/octet-stream for binary data" {
    const allocator = std.testing.allocator;

    const resource_header = "\x00\x01\x02\x03\x04";
    const computed = try identifyUnknownMimeType(allocator, resource_header, false);

    if (computed) |mt| {
        const essence = try getEssence(allocator, &mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("application/octet-stream", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "distinguishTextOrBinary - UTF-16BE BOM" {
    const allocator = std.testing.allocator;

    const resource_header = "\xFE\xFF\x00\x48"; // UTF-16BE BOM + "H"
    const computed = try distinguishTextOrBinary(allocator, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/plain", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "distinguishTextOrBinary - UTF-8 BOM" {
    const allocator = std.testing.allocator;

    const resource_header = "\xEF\xBB\xBFHello";
    const computed = try distinguishTextOrBinary(allocator, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/plain", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "distinguishTextOrBinary - no binary data" {
    const allocator = std.testing.allocator;

    const resource_header = "Plain text content";
    const computed = try distinguishTextOrBinary(allocator, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/plain", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "distinguishTextOrBinary - with binary data" {
    const allocator = std.testing.allocator;

    const resource_header = "\x00\x01\x02Binary";
    const computed = try distinguishTextOrBinary(allocator, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("application/octet-stream", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "containsBinaryDataBytes - true for binary data" {
    try std.testing.expect(containsBinaryDataBytes("\x00\x01\x02"));
    try std.testing.expect(containsBinaryDataBytes("\x0B")); // VT
    try std.testing.expect(containsBinaryDataBytes("Hello\x00World"));
}

test "containsBinaryDataBytes - false for text data" {
    try std.testing.expect(!containsBinaryDataBytes("Hello, World!"));
    try std.testing.expect(!containsBinaryDataBytes("Text\x0A")); // LF is not binary data byte
    try std.testing.expect(!containsBinaryDataBytes(""));
}

// Context-specific sniffing tests

test "sniffInImageContext - XML MIME type returns supplied" {
    const allocator = std.testing.allocator;

    const supplied = (try mime_type.parseMimeType(allocator, "image/svg+xml")).?;
    defer {
        var mt = supplied;
        mt.deinit();
    }

    const resource_header = "\x89PNG\x0D\x0A\x1A\x0A"; // PNG signature
    const computed = try sniffInImageContext(allocator, supplied, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        // Should return supplied (SVG+XML), not sniffed (PNG)
        try std.testing.expectEqualStrings("image/svg+xml", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "sniffInImageContext - pattern matching" {
    const allocator = std.testing.allocator;

    const supplied = (try mime_type.parseMimeType(allocator, "image/unknown")).?;
    defer {
        var mt = supplied;
        mt.deinit();
    }

    const resource_header = "\x89PNG\x0D\x0A\x1A\x0A"; // PNG signature
    const computed = try sniffInImageContext(allocator, supplied, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("image/png", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "sniffInAudioOrVideoContext - pattern matching" {
    const allocator = std.testing.allocator;

    const supplied = (try mime_type.parseMimeType(allocator, "audio/unknown")).?;
    defer {
        var mt = supplied;
        mt.deinit();
    }

    const resource_header = "ID3"; // MP3 with ID3
    const computed = try sniffInAudioOrVideoContext(allocator, supplied, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("audio/mpeg", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "sniffInFontContext - pattern matching" {
    const allocator = std.testing.allocator;

    const supplied = (try mime_type.parseMimeType(allocator, "font/unknown")).?;
    defer {
        var mt = supplied;
        mt.deinit();
    }

    const resource_header = "wOFF"; // WOFF signature
    const computed = try sniffInFontContext(allocator, supplied, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("font/woff", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "sniffInPluginContext - undefined returns octet-stream" {
    const allocator = std.testing.allocator;

    const computed = try sniffInPluginContext(allocator, null);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("application/octet-stream", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "sniffInPluginContext - supplied returns supplied" {
    const allocator = std.testing.allocator;

    const supplied = (try mime_type.parseMimeType(allocator, "application/x-custom")).?;
    defer {
        var mt = supplied;
        mt.deinit();
    }

    const computed = try sniffInPluginContext(allocator, supplied);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("application/x-custom", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "sniffInStyleContext - returns supplied" {
    const allocator = std.testing.allocator;

    const supplied = (try mime_type.parseMimeType(allocator, "text/css")).?;
    defer {
        var mt = supplied;
        mt.deinit();
    }

    const computed = try sniffInStyleContext(allocator, supplied);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/css", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "sniffInScriptContext - returns supplied" {
    const allocator = std.testing.allocator;

    const supplied = (try mime_type.parseMimeType(allocator, "text/javascript")).?;
    defer {
        var mt = supplied;
        mt.deinit();
    }

    const computed = try sniffInScriptContext(allocator, supplied);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/javascript", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "sniffInTextTrackContext - returns text/vtt" {
    const allocator = std.testing.allocator;

    const computed = try sniffInTextTrackContext(allocator);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/vtt", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "sniffInCacheManifestContext - returns text/cache-manifest" {
    const allocator = std.testing.allocator;

    const computed = try sniffInCacheManifestContext(allocator);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/cache-manifest", essence);
    } else {
        try std.testing.expect(false);
    }
}

// Tests for new HTML patterns

test "identifyUnknownMimeType - HTML <H1> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<h1 >Header";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "identifyUnknownMimeType - HTML <DIV> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<div >Content";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "identifyUnknownMimeType - HTML <FONT> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<font >Text";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "identifyUnknownMimeType - HTML <TABLE> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<table >";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "identifyUnknownMimeType - HTML <A> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<a >Link";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "identifyUnknownMimeType - HTML <STYLE> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<style >";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "identifyUnknownMimeType - HTML <TITLE> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<title >";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "identifyUnknownMimeType - HTML <B> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<b >Bold";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "identifyUnknownMimeType - HTML <BODY> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<body >";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "identifyUnknownMimeType - HTML <BR> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<br >";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "identifyUnknownMimeType - HTML <P> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<p >Paragraph";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "identifyUnknownMimeType - HTML comment" {
    const allocator = std.testing.allocator;

    const resource_header = "<!-- Comment";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "identifyUnknownMimeType - HTML with leading whitespace" {
    const allocator = std.testing.allocator;

    const resource_header = "  \t\n<html >";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}

test "sniffInBrowsingContext - delegates to sniffMimeType" {
    const allocator = std.testing.allocator;

    var res = Resource.init(allocator);
    defer res.deinit();

    res.supplied_mime_type = (try mime_type.parseMimeType(allocator, "text/html")).?;

    const resource_header = "<html>";
    const computed = try sniffInBrowsingContext(allocator, &res, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}
