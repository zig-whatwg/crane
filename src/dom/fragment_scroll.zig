//! HTML 7.4.6.4 "Scrolling to a fragment": the indicated part of a document
//! and the target element it sets.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#scroll-to-the-fragment-identifier
//!
//! Crane lays nothing out, so the scrolling itself is the host's; what the
//! page can observe is the document's target element (`:target`), which this
//! sets. The steps after it - the ancestor revealing algorithm, scrolling the
//! target into view, the focusing steps and the sequential focus navigation
//! starting point - are TODO(fragment): the focusing steps change
//! document.activeElement and are not run yet.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const target_element = @import("target_element.zig");

/// "The indicated part of the document": an element, the top of the
/// document, or null.
pub const IndicatedPart = union(enum) {
    none,
    top_of_the_document,
    element: *runtime.Instance,
};

/// "Scroll to the fragment" given `document`: set its target element from its
/// indicated part.
pub fn scrollToTheFragment(document: *runtime.Instance) void {
    switch (indicatedPart(document)) {
        // Step 1: "If document's indicated part is null, then set document's
        // target element to null."
        .none => target_element.set(document, null),
        // Step 2: the top of the document - "Set document's target element
        // to null", and scroll to the beginning of the document (the host's).
        .top_of_the_document => target_element.set(document, null),
        // Step 3: "Let target be document's indicated part. Set document's
        // target element to target."
        .element => |target| target_element.set(document, target),
    }
}

/// "For an HTML document document, its indicated part is the result of
/// selecting the indicated part given document and document's URL."
pub fn indicatedPart(document: *runtime.Instance) IndicatedPart {
    const allocator = document.ctx.allocator;
    const url = interfaces.Document.get_URL(document) catch return .none;
    defer allocator.free(url);
    // "Select the indicated part" step 1 compares document's URL with url,
    // fragments excluded: the same URL here.
    // Step 2: "Let fragment be url's fragment." A URL without one has a null
    // fragment and so indicates nothing.
    const fragment = fragmentOf(url) orelse return .none;
    return selectTheIndicatedPart(document, fragment);
}

/// "Select the indicated part" steps 3-11, given the URL's (non-null)
/// fragment.
fn selectTheIndicatedPart(document: *runtime.Instance, fragment: []const u8) IndicatedPart {
    // Step 3: "If fragment is the empty string, then return the special value
    // top of the document."
    if (fragment.len == 0) return .top_of_the_document;

    // Steps 4-5: a potential indicated element for fragment itself.
    if (findPotentialIndicatedElement(document, fragment)) |element| return .{ .element = element };

    // Steps 6-7: "Let fragmentBytes be the result of percent-decoding
    // fragment. Let decodedFragment be the result of running UTF-8 decode
    // without BOM on fragmentBytes."
    const allocator = document.ctx.allocator;
    const bytes = percentDecode(allocator, fragment) catch return .none;
    defer allocator.free(bytes);
    const decoded = utf8DecodeWithoutBom(allocator, bytes) catch return .none;
    defer allocator.free(decoded);

    // Steps 8-9: and for decodedFragment.
    if (findPotentialIndicatedElement(document, decoded)) |element| return .{ .element = element };

    // Step 10: "If decodedFragment is an ASCII case-insensitive match for the
    // string top, then return the top of the document."
    if (std.ascii.eqlIgnoreCase(decoded, "top")) return .top_of_the_document;

    // Step 11: "Return null."
    return .none;
}

/// "Find a potential indicated element" given `document` and `fragment`.
fn findPotentialIndicatedElement(document: *runtime.Instance, fragment: []const u8) ?*runtime.Instance {
    // Step 1: "If there is an element in the document tree whose root is
    // document and that has an ID equal to fragment, then return the first
    // such element in tree order" - getElementById on the document.
    if (interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(fragment)) catch null) |element| {
        return element;
    }

    // Step 2: "If there is an a element in the document tree whose root is
    // document that has a name attribute whose value is equal to fragment,
    // then return the first such element in tree order."
    var node: ?*runtime.Instance = interfaces.Node.get_firstChild(document) catch null;
    while (node) |n| {
        if (isAnchorNamed(n, fragment)) return n;
        node = following(n, document);
    }

    // Step 3: "Return null."
    return null;
}

/// Is `node` an HTML `a` element whose name attribute's value is `name`?
fn isAnchorNamed(node: *runtime.Instance, name: []const u8) bool {
    if ((interfaces.Node.get_nodeType(node) catch 0) != interfaces.Node.get_ELEMENT_NODE()) return false;
    const allocator = node.ctx.allocator;
    var local_name = interfaces.Element.get_localName(node) catch return false;
    defer local_name.deinit(allocator);
    if (!std.mem.eql(u8, local_name.asSlice(), "a")) return false;
    var namespace = (interfaces.Element.get_namespaceURI(node) catch return false) orelse return false;
    defer namespace.deinit(allocator);
    if (!std.mem.eql(u8, namespace.asSlice(), "http://www.w3.org/1999/xhtml")) return false;
    var value = (interfaces.Element.call_getAttribute(node, runtime.DOMString.initInterned("name")) catch return false) orelse return false;
    defer value.deinit(allocator);
    return std.mem.eql(u8, value.asSlice(), name);
}

/// The node after `node` in tree order below `root`, children first.
fn following(node: *runtime.Instance, root: *runtime.Instance) ?*runtime.Instance {
    if (interfaces.Node.get_firstChild(node) catch null) |child| return child;
    var current = node;
    while (current != root) {
        if (interfaces.Node.get_nextSibling(current) catch null) |next| return next;
        current = (interfaces.Node.get_parentNode(current) catch null) orelse return null;
    }
    return null;
}

/// A URL's fragment: what follows its first "#", or null when it has none.
/// The URL is serialized, so its fragment is already percent-encoded.
fn fragmentOf(url: []const u8) ?[]const u8 {
    const hash = std.mem.indexOfScalar(u8, url, '#') orelse return null;
    return url[hash + 1 ..];
}

/// URL "percent-decode" a string (as its UTF-8 bytes): each "%" followed by
/// two ASCII hex digits is the byte they spell; every other byte is itself.
/// OWNED.
fn percentDecode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var output = try std.ArrayList(u8).initCapacity(allocator, input.len);
    errdefer output.deinit(allocator);
    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        const byte = input[i];
        if (byte == '%' and i + 2 < input.len) {
            const high = std.fmt.charToDigit(input[i + 1], 16) catch {
                output.appendAssumeCapacity(byte);
                continue;
            };
            const low = std.fmt.charToDigit(input[i + 2], 16) catch {
                output.appendAssumeCapacity(byte);
                continue;
            };
            output.appendAssumeCapacity(high * 16 + low);
            i += 2;
            continue;
        }
        output.appendAssumeCapacity(byte);
    }
    return output.toOwnedSlice(allocator);
}

/// Encoding "UTF-8 decode without BOM": the bytes as UTF-8, invalid input
/// replaced by U+FFFD. OWNED. The Encoding Standard's decoder emits one
/// U+FFFD per maximal invalid subpart; this emits one per byte of it. The
/// two differ only for a truncated multi-byte sequence, and only an ID that
/// itself contains U+FFFD could tell them apart. (The dom module has no
/// encoding import to call the decoder itself.)
fn utf8DecodeWithoutBom(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var output = try std.ArrayList(u8).initCapacity(allocator, bytes.len);
    errdefer output.deinit(allocator);
    var i: usize = 0;
    while (i < bytes.len) {
        const length = std.unicode.utf8ByteSequenceLength(bytes[i]) catch {
            try output.appendSlice(allocator, "\u{FFFD}");
            i += 1;
            continue;
        };
        if (i + length <= bytes.len) {
            if (std.unicode.utf8Decode(bytes[i .. i + length])) |_| {
                try output.appendSlice(allocator, bytes[i .. i + length]);
                i += length;
                continue;
            } else |_| {}
        }
        try output.appendSlice(allocator, "\u{FFFD}");
        i += 1;
    }
    return output.toOwnedSlice(allocator);
}

test "a URL's fragment is what follows its first #, and none without one" {
    try std.testing.expectEqualStrings("target", fragmentOf("https://a.test/p.html#target").?);
    try std.testing.expectEqualStrings("", fragmentOf("https://a.test/#").?);
    try std.testing.expectEqualStrings("a#b", fragmentOf("https://a.test/#a#b").?);
    try std.testing.expect(fragmentOf("https://a.test/") == null);
}

test "percent-decode takes %XY pairs and leaves every other byte" {
    const allocator = std.testing.allocator;
    const decoded = try percentDecode(allocator, "caf%C3%A9%2x%");
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("caf\u{e9}%2x%", decoded);
}

test "UTF-8 decode without BOM replaces each invalid byte" {
    const allocator = std.testing.allocator;
    const decoded = try utf8DecodeWithoutBom(allocator, "a\xffb\xc3\xa9");
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("a\u{FFFD}b\u{e9}", decoded);
}
