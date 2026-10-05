//! What an object element's - or an embed element's - fetched resource is:
//! HTML 4.8.7 "(re)determine what the object element represents", step 8
//! ("determine the resource type") and step 9's choice between a child
//! navigable, an image and the fallback content.
//!
//! Spec: https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-object-element
//!
//! Engine-free: the element's machinery (src/html/embedded_content.zig)
//! fetches, then asks here with the response's Content-Type, the element's
//! type attribute and the body's first bytes.
//!
//! Step 8.2 (a user agent "configured to strictly obey Content-Type
//! headers") is not taken, and step 8.4 (a plugin's URL patterns) finds
//! nothing: Crane has no plugins.

const std = @import("std");
const mimesniff = @import("mimesniff");
const document_type = @import("document_type.zig");

/// Step 9's cases.
pub const Handler = enum {
    /// "If the resource type is an XML MIME type, or if the resource type
    /// does not start with "image/"": the element's child navigable,
    /// navigated to the response's URL.
    navigable,
    /// "If the resource type starts with "image/", and support for images
    /// has not been disabled": the element represents the image.
    image,
    /// "Otherwise": the type is not supported - or unknown - and the element
    /// shows its fallback content.
    fallback,
};

/// What step 8 reads of the resource and the element.
pub const Input = struct {
    /// The response's `Content-Type` value - its Content-Type metadata -
    /// or null when it has none.
    content_type: ?[]const u8 = null,
    /// The element's type attribute's value, or null when it is absent.
    type_attribute: ?[]const u8 = null,
    /// The first bytes of the response's body (mimesniff reads 1445).
    body: []const u8 = "",
};

/// Step 8: the resource type, as a MIME type essence owned by `allocator`,
/// or null when it is unknown.
pub fn resourceType(allocator: std.mem.Allocator, input: Input) !?[]u8 {
    const header = input.body[0..@min(input.body.len, 1445)];
    // A type attribute names its type by essence; one that is empty names
    // none.
    const attribute: ?[]u8 = if (input.type_attribute) |value| blk: {
        const e = try document_type.essence(allocator, value);
        if (e.len == 0) {
            allocator.free(e);
            break :blk null;
        }
        break :blk e;
    } else null;
    defer if (attribute) |a| allocator.free(a);

    // "If the resource has associated Content-Type metadata" - a value that
    // names a type.
    const metadata: ?[]u8 = if (input.content_type) |value| blk: {
        const e = try document_type.essence(allocator, value);
        if (e.len == 0 or std.mem.indexOfScalar(u8, e, '/') == null) {
            allocator.free(e);
            break :blk null;
        }
        break :blk e;
    } else null;

    if (metadata) |content_type| {
        // 1. "Let binary be false."
        var binary = false;
        // 2. "If the type specified in the resource's Content-Type metadata
        // is "text/plain", and the result of applying the rules for
        // distinguishing if a resource is text or binary to the resource is
        // that the resource is not text/plain, then set binary to true."
        if (std.mem.eql(u8, content_type, "text/plain") and !isText(header)) binary = true;
        // 3. "If the type specified in the resource's Content-Type metadata
        // is "application/octet-stream", then set binary to true."
        if (std.mem.eql(u8, content_type, "application/octet-stream")) binary = true;
        // 4. "If binary is false, then let the resource type be the type
        // specified in the resource's Content-Type metadata, and jump to the
        // step below labeled handler."
        if (!binary) return content_type;
        allocator.free(content_type);
        // 5. "If there is a type attribute present on the object element, and
        // its value is not application/octet-stream": "If the attribute's
        // value is a type that starts with "image/" that is not also an XML
        // MIME type, then let the resource type be the type specified in that
        // type attribute. Jump to the step below labeled handler."
        if (attribute) |a| {
            if (!std.mem.eql(u8, a, "application/octet-stream")) {
                if (std.mem.startsWith(u8, a, "image/") and !document_type.isXml(a)) return try allocator.dupe(u8, a);
                return null;
            }
        }
        // Step 4, a plugin's URL patterns: none.
        return null;
    }

    // "Otherwise, if the resource does not have associated Content-Type
    // metadata": 1. "If there is a type attribute present on the object
    // element, then let the tentative type be the type specified in that type
    // attribute. Otherwise, let tentative type be the computed type of the
    // resource."
    const tentative: []u8 = if (attribute) |a| try allocator.dupe(u8, a) else try computedType(allocator, header);
    // 2. "If tentative type is not application/octet-stream, then let
    // resource type be tentative type and jump to the step below labeled
    // handler."
    if (!std.mem.eql(u8, tentative, "application/octet-stream")) return tentative;
    allocator.free(tentative);
    return null;
}

/// Step 9: the case `resource_type` (step 8's result) falls in.
pub fn handlerFor(resource_type: ?[]const u8) Handler {
    const t = resource_type orelse return .fallback;
    if (document_type.isXml(t)) return .navigable;
    if (!std.mem.startsWith(u8, t, "image/")) return .navigable;
    return .image;
}

/// mimesniff's "rules for distinguishing if a resource is text or binary":
/// whether `header` is text/plain.
fn isText(header: []const u8) bool {
    const result = mimesniff.sniffing.distinguishTextOrBinary(std.heap.page_allocator, header) catch return true;
    const mt = result orelse return true;
    return asciiEql(mt.subtype, "plain");
}

/// The computed type of a resource with no Content-Type metadata: mimesniff
/// "identify an unknown MIME type" with the sniff-scriptable flag set (the
/// MIME type sniffing algorithm for an undefined supplied type), as an
/// essence owned by `allocator`.
fn computedType(allocator: std.mem.Allocator, header: []const u8) ![]u8 {
    var sniffed = (try mimesniff.sniffing.identifyUnknownMimeType(allocator, header, true)) orelse
        return allocator.dupe(u8, "application/octet-stream");
    defer sniffed.deinit();
    const out = try allocator.alloc(u8, sniffed.type.len + 1 + sniffed.subtype.len);
    for (sniffed.type, 0..) |c, i| out[i] = std.ascii.toLower(@truncate(c));
    out[sniffed.type.len] = '/';
    for (sniffed.subtype, 0..) |c, i| out[sniffed.type.len + 1 + i] = std.ascii.toLower(@truncate(c));
    return out;
}

fn asciiEql(utf16: []const u16, ascii: []const u8) bool {
    if (utf16.len != ascii.len) return false;
    for (utf16, ascii) |a, b| {
        if (a != b) return false;
    }
    return true;
}

const testing = std.testing;

fn expectType(expected: ?[]const u8, input: Input) !void {
    const got = try resourceType(testing.allocator, input);
    defer if (got) |g| testing.allocator.free(g);
    if (expected) |e| {
        try testing.expect(got != null);
        try testing.expectEqualStrings(e, got.?);
    } else {
        try testing.expectEqual(@as(?[]u8, null), got);
    }
}

test "Content-Type metadata names the type, unless it says binary" {
    try expectType("text/html", .{ .content_type = "text/html; charset=utf-8", .body = "<p>x" });
    try expectType("image/png", .{ .content_type = "IMAGE/PNG", .type_attribute = "text/html" });
    try expectType("text/plain", .{ .content_type = "text/plain", .body = "plain words" });
    // text/plain whose bytes are binary, octet-stream: the type attribute
    // decides, and only for an image type.
    try expectType(null, .{ .content_type = "text/plain", .body = "\x00\x01\x02binary" });
    try expectType("image/png", .{ .content_type = "application/octet-stream", .type_attribute = "image/png" });
    try expectType(null, .{ .content_type = "application/octet-stream", .type_attribute = "text/html" });
    try expectType(null, .{ .content_type = "application/octet-stream", .type_attribute = "image/svg+xml" });
    try expectType(null, .{ .content_type = "application/octet-stream" });
}

test "without Content-Type metadata, the type attribute, else the computed type" {
    try expectType("text/html", .{ .type_attribute = "text/html", .body = "\x89PNG\r\n\x1a\n" });
    try expectType("image/png", .{ .body = "\x89PNG\r\n\x1a\n0000" });
    try expectType("text/html", .{ .body = "<!DOCTYPE html><p>x" });
    try expectType("text/plain", .{ .body = "just text" });
    try expectType(null, .{ .type_attribute = "application/octet-stream" });
    // An empty type attribute names no type.
    try expectType("text/plain", .{ .type_attribute = "", .body = "just text" });
}

test "the handler: XML or not an image is a navigable, an image an image, unknown the fallback" {
    try testing.expectEqual(Handler.navigable, handlerFor("text/html"));
    try testing.expectEqual(Handler.navigable, handlerFor("text/plain"));
    try testing.expectEqual(Handler.navigable, handlerFor("image/svg+xml"));
    try testing.expectEqual(Handler.navigable, handlerFor("application/x-shockwave-flash"));
    try testing.expectEqual(Handler.image, handlerFor("image/png"));
    try testing.expectEqual(Handler.fallback, handlerFor(null));
}
