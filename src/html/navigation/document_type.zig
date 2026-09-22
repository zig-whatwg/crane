//! Navigation Document Type Selection - HTML Standard §7.4.6
//!
//! Implements the branch table at the head of "load a document", which decides
//! what kind of `Document` a navigation response becomes:
//!
//! > Let type be the computed type of navigationParams's response. [...] if the
//! > type is one of the following types:
//! >
//! > - an HTML MIME type -> loading an HTML document
//! > - an XML MIME type that is not an explicitly supported XML MIME type
//! >   -> loading an XML document
//! > - a JavaScript MIME type / a JSON MIME type that is not an explicitly
//! >   supported JSON MIME type / "text/css" / "text/plain" / "text/vtt"
//! >   -> loading a text document
//! > - "multipart/x-mixed-replace" -> loading a multipart/x-mixed-replace document
//! > - a supported image, video, or audio type -> loading a media document
//! > - "application/pdf" / "text/pdf" -> inline content with no DOM, if the
//! >   user agent's PDF viewer supported is true
//! >
//! > Otherwise, proceed onward.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#loading-a-document
//!
//! ## Why the MIME predicates are restated here
//!
//! `src/mimesniff/predicates.zig` already defines "HTML MIME type", "XML MIME
//! type", "JavaScript MIME type" and "JSON MIME type" over a parsed
//! `MimeType`. That module is not in `html_core`'s import set, so the same
//! definitions are restated below over an essence string. They are kept
//! deliberately literal against mimesniff so a reader can diff them.
//!
//! TODO: collapse these onto `mimesniff.predicates` once `html_core` can import
//! the `mimesniff` module.

const std = @import("std");

/// The kind of Document a response's computed MIME type calls for.
pub const DocumentClass = enum {
    /// "loading an HTML document" - parse the body with the HTML parser.
    html,
    /// "loading an XML document" - parse the body with an XML parser.
    xml,
    /// "loading a text document" - the body becomes the text of a single
    /// `pre` element; no markup in it is significant.
    text,
    /// "loading a media document" - the body is not parsed at all; the
    /// document hosts an `img`, `video` or `audio` element pointing at the
    /// resource's address.
    media,
    /// "loading a multipart/x-mixed-replace document".
    multipart,
    /// None of the above: the spec's "otherwise, proceed onward", which ends in
    /// handing the resource off to external software (a download). No Document
    /// is produced and the navigation does not commit.
    external,
};

/// The element a media document hosts, per the table in "loading a media
/// document": Image -> `img`, Video -> `video`, Audio -> `audio`. The
/// appropriate attribute is `src` in all three rows.
pub const MediaHostElement = enum {
    img,
    video,
    audio,

    pub fn tagName(self: MediaHostElement) []const u8 {
        return switch (self) {
            .img => "img",
            .video => "video",
            .audio => "audio",
        };
    }
};

/// The "essence" of a MIME type: its type, U+002F (/), and its subtype, with
/// parameters stripped and the whole lowercased.
///
/// mimesniff defines essence over a parsed MIME type record. A full parse is
/// not needed to select a document class, so this takes the shortcut the
/// definition permits: everything before the first U+003B (;), trimmed of HTTP
/// whitespace, ASCII-lowercased.
///
/// Caller owns the returned slice.
///
/// Spec: https://mimesniff.spec.whatwg.org/#mime-type-essence
pub fn essence(allocator: std.mem.Allocator, content_type: []const u8) ![]u8 {
    const before_params = if (std.mem.indexOfScalar(u8, content_type, ';')) |i|
        content_type[0..i]
    else
        content_type;

    const trimmed = std.mem.trim(u8, before_params, " \t\n\r");

    const out = try allocator.alloc(u8, trimmed.len);
    for (trimmed, 0..) |c, i| out[i] = std.ascii.toLower(c);
    return out;
}

/// An HTML MIME type is any MIME type whose essence is "text/html".
///
/// Spec: https://mimesniff.spec.whatwg.org/#html-mime-type
pub fn isHtml(mime_essence: []const u8) bool {
    return std.mem.eql(u8, mime_essence, "text/html");
}

/// An XML MIME type is any MIME type whose subtype ends in "+xml", or whose
/// essence is "text/xml" or "application/xml".
///
/// Spec: https://mimesniff.spec.whatwg.org/#xml-mime-type
pub fn isXml(mime_essence: []const u8) bool {
    if (std.mem.eql(u8, mime_essence, "text/xml")) return true;
    if (std.mem.eql(u8, mime_essence, "application/xml")) return true;
    return std.mem.endsWith(u8, mime_essence, "+xml");
}

/// The JavaScript MIME type essence strings, verbatim from mimesniff.
///
/// Spec: https://mimesniff.spec.whatwg.org/#javascript-mime-type-essence-match
const javascript_essences = [_][]const u8{
    "application/ecmascript",
    "application/javascript",
    "application/x-ecmascript",
    "application/x-javascript",
    "text/ecmascript",
    "text/javascript",
    "text/javascript1.0",
    "text/javascript1.1",
    "text/javascript1.2",
    "text/javascript1.3",
    "text/javascript1.4",
    "text/javascript1.5",
    "text/jscript",
    "text/livescript",
    "text/x-ecmascript",
    "text/x-javascript",
};

/// A JavaScript MIME type is any MIME type whose essence is a JavaScript MIME
/// type essence match.
pub fn isJavaScript(mime_essence: []const u8) bool {
    for (javascript_essences) |candidate| {
        if (std.mem.eql(u8, mime_essence, candidate)) return true;
    }
    return false;
}

/// A JSON MIME type is any MIME type whose subtype ends in "+json", or whose
/// essence is "application/json" or "text/json".
///
/// Spec: https://mimesniff.spec.whatwg.org/#json-mime-type
pub fn isJson(mime_essence: []const u8) bool {
    if (std.mem.eql(u8, mime_essence, "application/json")) return true;
    if (std.mem.eql(u8, mime_essence, "text/json")) return true;
    return std.mem.endsWith(u8, mime_essence, "+json");
}

/// Does this essence have `prefix` as its *type* (the part before the slash)?
fn hasType(mime_essence: []const u8, comptime prefix: []const u8) bool {
    return std.mem.startsWith(u8, mime_essence, prefix ++ "/");
}

/// Select the document class for a computed MIME type.
///
/// `mime_essence` must already be an essence - lowercase, no parameters. Pass
/// the result of `essence()`.
///
/// ## On "a *supported* image, video, or audio type"
///
/// Crane decodes no media: layout and painting are the host's job
/// (`src/platform/layout_backend.zig`). What the engine has to supply for an
/// `image/png` navigation is a Document whose content type is "image/png" and
/// whose body hosts an `img` pointing at the resource - and it can do that for
/// every image, video and audio type equally. So "supported" is taken to be
/// mimesniff's type-prefix test rather than a decoder allowlist; narrowing it
/// to a hand-written list of formats would only turn types nobody thought of
/// into failed navigations.
pub fn classify(mime_essence: []const u8) DocumentClass {
    // The order below is the spec's order, and it matters: image/svg+xml is
    // both an XML MIME type and an image type, and must be an XML document.
    if (isHtml(mime_essence)) return .html;
    if (isXml(mime_essence)) return .xml;
    if (isJavaScript(mime_essence)) return .text;
    if (isJson(mime_essence)) return .text;
    if (std.mem.eql(u8, mime_essence, "text/css")) return .text;
    if (std.mem.eql(u8, mime_essence, "text/plain")) return .text;
    if (std.mem.eql(u8, mime_essence, "text/vtt")) return .text;
    if (std.mem.eql(u8, mime_essence, "multipart/x-mixed-replace")) return .multipart;
    if (hasType(mime_essence, "image")) return .media;
    if (hasType(mime_essence, "video")) return .media;
    if (hasType(mime_essence, "audio")) return .media;

    // "application/pdf" and "text/pdf" would be inline content with no DOM if
    // the user agent's PDF viewer supported were true. Crane has no PDF viewer,
    // so they fall through with everything else.
    return .external;
}

/// The host element for a media document of this type.
pub fn mediaHostElement(mime_essence: []const u8) MediaHostElement {
    if (hasType(mime_essence, "video")) return .video;
    if (hasType(mime_essence, "audio")) return .audio;
    return .img;
}

// ============================================================================
// Tests
// ============================================================================

test "essence strips parameters, whitespace and case" {
    const allocator = std.testing.allocator;

    const cases = [_]struct { in: []const u8, want: []const u8 }{
        .{ .in = "text/html", .want = "text/html" },
        .{ .in = "text/html; charset=utf-8", .want = "text/html" },
        .{ .in = "TEXT/HTML;CHARSET=UTF-8", .want = "text/html" },
        .{ .in = "  text/css  ", .want = "text/css" },
        .{ .in = "text/plain;charset=US-ASCII", .want = "text/plain" },
        .{ .in = "", .want = "" },
    };

    for (cases) |c| {
        const got = try essence(allocator, c.in);
        defer allocator.free(got);
        try std.testing.expectEqualStrings(c.want, got);
    }
}

test "classify routes the HTML MIME type to an HTML document" {
    try std.testing.expectEqual(DocumentClass.html, classify("text/html"));
}

test "classify routes XML MIME types to an XML document" {
    try std.testing.expectEqual(DocumentClass.xml, classify("text/xml"));
    try std.testing.expectEqual(DocumentClass.xml, classify("application/xml"));
    try std.testing.expectEqual(DocumentClass.xml, classify("application/rss+xml"));
    // image/svg+xml is an image type too; XML wins because the spec tests it first.
    try std.testing.expectEqual(DocumentClass.xml, classify("image/svg+xml"));
}

test "classify routes script, JSON, css, plain and vtt to a text document" {
    try std.testing.expectEqual(DocumentClass.text, classify("text/javascript"));
    try std.testing.expectEqual(DocumentClass.text, classify("application/ecmascript"));
    try std.testing.expectEqual(DocumentClass.text, classify("text/javascript1.5"));
    try std.testing.expectEqual(DocumentClass.text, classify("application/json"));
    try std.testing.expectEqual(DocumentClass.text, classify("application/ld+json"));
    try std.testing.expectEqual(DocumentClass.text, classify("text/css"));
    try std.testing.expectEqual(DocumentClass.text, classify("text/plain"));
    try std.testing.expectEqual(DocumentClass.text, classify("text/vtt"));
}

test "classify routes image, video and audio to a media document" {
    try std.testing.expectEqual(DocumentClass.media, classify("image/png"));
    try std.testing.expectEqual(DocumentClass.media, classify("image/bmp"));
    try std.testing.expectEqual(DocumentClass.media, classify("image/gif"));
    try std.testing.expectEqual(DocumentClass.media, classify("image/jpeg"));
    try std.testing.expectEqual(DocumentClass.media, classify("video/mp4"));
    try std.testing.expectEqual(DocumentClass.media, classify("audio/mpeg"));
}

test "classify leaves everything else to external software" {
    try std.testing.expectEqual(DocumentClass.external, classify("application/octet-stream"));
    try std.testing.expectEqual(DocumentClass.external, classify("application/pdf"));
    try std.testing.expectEqual(DocumentClass.external, classify("application/zip"));
    // An empty or absent Content-Type is the caller's problem, not a document
    // class: callers substitute a computed type before classifying.
    try std.testing.expectEqual(DocumentClass.external, classify(""));
}

test "classify recognises multipart/x-mixed-replace" {
    try std.testing.expectEqual(DocumentClass.multipart, classify("multipart/x-mixed-replace"));
}

test "mediaHostElement follows the table in loading a media document" {
    try std.testing.expectEqual(MediaHostElement.img, mediaHostElement("image/png"));
    try std.testing.expectEqual(MediaHostElement.video, mediaHostElement("video/webm"));
    try std.testing.expectEqual(MediaHostElement.audio, mediaHostElement("audio/ogg"));
    try std.testing.expectEqualStrings("img", MediaHostElement.img.tagName());
    try std.testing.expectEqualStrings("video", MediaHostElement.video.tagName());
    try std.testing.expectEqualStrings("audio", MediaHostElement.audio.tagName());
}
