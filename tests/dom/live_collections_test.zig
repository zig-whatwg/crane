//! Tests for HTMLDocument live collections (document.images, document.forms, etc.)
//!
//! Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-images
//!       https://html.spec.whatwg.org/multipage/dom.html#dom-document-forms
//!       https://html.spec.whatwg.org/multipage/dom.html#dom-document-links
//!       https://html.spec.whatwg.org/multipage/dom.html#dom-document-scripts
//!
//! These tests verify that:
//! 1. Live collections return the correct elements by tag name
//! 2. Collections are "live" (update when DOM changes)
//! 3. Collections work correctly with nested elements
//!
//! Lane wb1: the document, its elements and its collections are the real
//! ones (real_nodes.zig; Document.images / forms / scripts / links, each an
//! HTMLCollection). The tests used a mock Document NodeBase, ElementWithBase
//! values and a tree walk of their own that stood in for the collections, so
//! they held nothing of production's. Two assertions changed with that, both
//! toward the spec: `document.links` holds only a and area elements WITH an
//! href attribute (the mock took every a and area), and the live tests read
//! ONE collection object before and after a mutation (the mock built a new
//! list for each read, which could not show liveness).

const std = @import("std");
const testing = std.testing;
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const real_nodes = @import("real_nodes.zig");

const Instance = real_nodes.Instance;
const Collection = interfaces.HTMLCollection;

// =============================================================================
// Test Infrastructure
// =============================================================================

/// A document with its root element: a Document takes one element child, so
/// what the tests append "to the document" goes under the root.
const TestDocument = struct {
    nodes: real_nodes.Nodes,
    document: *Instance = undefined,
    root: *Instance = undefined,

    /// In place (the scope must not move).
    fn open(self: *TestDocument, kind: enum { html, xhtml }) !void {
        self.* = .{ .nodes = undefined };
        try self.nodes.open(testing.allocator);
        errdefer self.nodes.close();
        self.document = try self.nodes.document();
        if (kind == .xhtml) {
            try dom.document_internals.setContentType(self.document, "application/xhtml+xml");
            try dom.document_internals.setDocumentType(self.document, .xml);
        }
        self.root = try self.createElement("html");
        try self.nodes.append(self.document, self.root);
    }

    fn close(self: *TestDocument) void {
        self.nodes.close();
    }

    fn createElement(self: *TestDocument, tag_name: []const u8) !*Instance {
        return self.nodes.element(self.document, tag_name);
    }

    /// Append `child` under the document's root element.
    fn appendChild(self: *TestDocument, child: *Instance) !void {
        try self.nodes.append(self.root, child);
    }

    fn removeChild(self: *TestDocument, child: *Instance) !void {
        _ = try interfaces.Node.call_removeChild(self.root, child);
    }

    fn images(self: *TestDocument) !*Instance {
        return interfaces.Document.get_images(self.document);
    }

    fn forms(self: *TestDocument) !*Instance {
        return interfaces.Document.get_forms(self.document);
    }

    fn scripts(self: *TestDocument) !*Instance {
        return interfaces.Document.get_scripts(self.document);
    }

    fn links(self: *TestDocument) !*Instance {
        return interfaces.Document.get_links(self.document);
    }
};

fn expectLength(expected: u32, collection: *Instance) !void {
    try testing.expectEqual(expected, try Collection.get_length(collection));
}

fn expectItem(expected: ?*Instance, collection: *Instance, index: u32) !void {
    try testing.expectEqual(expected, try Collection.call_item(collection, index));
}

// =============================================================================
// document.images Tests
// =============================================================================

test "document.images - empty document returns empty collection" {
    var doc: TestDocument = undefined;
    try doc.open(.html);
    defer doc.close();

    try expectLength(0, try doc.images());
}

test "document.images - returns img elements" {
    var doc: TestDocument = undefined;
    try doc.open(.html);
    defer doc.close();

    // Create img elements
    const img1 = try doc.createElement("img");
    const img2 = try doc.createElement("img");

    // Append to document
    try doc.appendChild(img1);
    try doc.appendChild(img2);

    // Get images collection
    const images = try doc.images();
    try expectLength(2, images);
    try expectItem(img1, images, 0);
    try expectItem(img2, images, 1);
}

test "document.images - does not include other elements" {
    var doc: TestDocument = undefined;
    try doc.open(.html);
    defer doc.close();

    // Create mixed elements
    const img = try doc.createElement("img");
    const div = try doc.createElement("div");
    const span = try doc.createElement("span");

    try doc.appendChild(img);
    try doc.appendChild(div);
    try doc.appendChild(span);

    // Should only include img
    const images = try doc.images();
    try expectLength(1, images);
    try expectItem(img, images, 0);
}

test "document.images - case insensitive in HTML mode" {
    var doc: TestDocument = undefined;
    try doc.open(.html);
    defer doc.close();

    // createElement("IMG") in an HTML document makes an img (DOM 4.5
    // createElement step 2 lowercases the name)
    const img = try doc.createElement("IMG");
    try doc.appendChild(img);

    const images = try doc.images();
    try expectLength(1, images);
    try expectItem(img, images, 0);
}

// =============================================================================
// document.forms Tests
// =============================================================================

test "document.forms - empty document returns empty collection" {
    var doc: TestDocument = undefined;
    try doc.open(.html);
    defer doc.close();

    try expectLength(0, try doc.forms());
}

test "document.forms - returns form elements" {
    var doc: TestDocument = undefined;
    try doc.open(.html);
    defer doc.close();

    // Create form elements
    const form1 = try doc.createElement("form");
    const form2 = try doc.createElement("form");

    try doc.appendChild(form1);
    try doc.appendChild(form2);

    const forms = try doc.forms();
    try expectLength(2, forms);
    try expectItem(form1, forms, 0);
    try expectItem(form2, forms, 1);
}

// =============================================================================
// document.scripts Tests
// =============================================================================

test "document.scripts - empty document returns empty collection" {
    var doc: TestDocument = undefined;
    try doc.open(.html);
    defer doc.close();

    try expectLength(0, try doc.scripts());
}

test "document.scripts - returns script elements" {
    var doc: TestDocument = undefined;
    try doc.open(.html);
    defer doc.close();

    const script1 = try doc.createElement("script");
    const script2 = try doc.createElement("script");
    const script3 = try doc.createElement("script");

    try doc.appendChild(script1);
    try doc.appendChild(script2);
    try doc.appendChild(script3);

    try expectLength(3, try doc.scripts());
}

// =============================================================================
// document.links Tests
// =============================================================================

test "document.links - empty document returns empty collection" {
    var doc: TestDocument = undefined;
    try doc.open(.html);
    defer doc.close();

    try expectLength(0, try doc.links());
}

test "document.links - returns a and area elements" {
    var doc: TestDocument = undefined;
    try doc.open(.html);
    defer doc.close();

    // Create link elements (a and area), each with an href attribute, and
    // one a without: HTML's document.links "matches only a elements with
    // href attributes and area elements with href attributes".
    const a1 = try doc.createElement("a");
    const a2 = try doc.createElement("a");
    const area1 = try doc.createElement("area");
    const no_href = try doc.createElement("a");
    for ([_]*Instance{ a1, a2, area1 }) |link| try doc.nodes.setAttribute(link, "href", "https://example.com/");

    try doc.appendChild(a1);
    try doc.appendChild(a2);
    try doc.appendChild(area1);
    try doc.appendChild(no_href);

    // Should include all a and area elements that have an href
    const links = try doc.links();
    try expectLength(3, links);
    try expectItem(a1, links, 0);
    try expectItem(a2, links, 1);
    try expectItem(area1, links, 2);
}

// =============================================================================
// Nested Element Tests
// =============================================================================

test "document.images - finds nested img elements" {
    var doc: TestDocument = undefined;
    try doc.open(.html);
    defer doc.close();

    // Create nested structure: root > div > img
    const div = try doc.createElement("div");
    const img = try doc.createElement("img");

    try doc.appendChild(div);
    try doc.nodes.append(div, img);

    const images = try doc.images();
    try expectLength(1, images);
    try expectItem(img, images, 0);
}

test "document.forms - finds deeply nested form elements" {
    var doc: TestDocument = undefined;
    try doc.open(.html);
    defer doc.close();

    // Create deeply nested structure: root > div > section > form
    const div = try doc.createElement("div");
    const section = try doc.createElement("section");
    const form = try doc.createElement("form");

    try doc.appendChild(div);
    try doc.nodes.append(div, section);
    try doc.nodes.append(section, form);

    const forms = try doc.forms();
    try expectLength(1, forms);
    try expectItem(form, forms, 0);
}

test "document.scripts - finds scripts at multiple levels" {
    var doc: TestDocument = undefined;
    try doc.open(.html);
    defer doc.close();

    // Create: root > script1
    //               div > script2
    //                     span > script3
    const script1 = try doc.createElement("script");
    const div = try doc.createElement("div");
    const script2 = try doc.createElement("script");
    const span = try doc.createElement("span");
    const script3 = try doc.createElement("script");

    try doc.appendChild(script1);
    try doc.appendChild(div);
    try doc.nodes.append(div, script2);
    try doc.nodes.append(div, span);
    try doc.nodes.append(span, script3);

    const scripts = try doc.scripts();
    try expectLength(3, scripts);
    // Tree order.
    try expectItem(script1, scripts, 0);
    try expectItem(script2, scripts, 1);
    try expectItem(script3, scripts, 2);
}

// =============================================================================
// Live Collection Tests (collection updates with DOM changes)
// =============================================================================

test "document.images - collection reflects added elements" {
    var doc: TestDocument = undefined;
    try doc.open(.html);
    defer doc.close();

    // Get images collection when empty
    const images = try doc.images();
    try expectLength(0, images);

    // Add an image
    const img = try doc.createElement("img");
    try doc.appendChild(img);

    // The SAME collection includes the new image, and a second read of the
    // attribute is that object ([SameObject])
    try expectLength(1, images);
    try expectItem(img, images, 0);
    try testing.expectEqual(images, try doc.images());
}

test "document.forms - collection reflects removed elements" {
    var doc: TestDocument = undefined;
    try doc.open(.html);
    defer doc.close();

    // Add two forms
    const form1 = try doc.createElement("form");
    const form2 = try doc.createElement("form");

    try doc.appendChild(form1);
    try doc.appendChild(form2);

    // Get initial collection
    const forms = try doc.forms();
    try expectLength(2, forms);

    // Remove one form
    try doc.removeChild(form1);

    // The same collection reflects the removal
    try expectLength(1, forms);
    try expectItem(form2, forms, 0);
}

// =============================================================================
// Collection Item Boundary Tests
// =============================================================================

test "collection - out of bounds returns nothing" {
    var doc: TestDocument = undefined;
    try doc.open(.html);
    defer doc.close();

    const img = try doc.createElement("img");
    try doc.appendChild(img);

    const images = try doc.images();

    // Valid index
    try expectLength(1, images);
    try expectItem(img, images, 0);

    // Out of bounds: item(index >= length) is null
    try expectItem(null, images, 1);
    try expectItem(null, images, 4_000_000_000);
}

// =============================================================================
// Mixed Content Tests
// =============================================================================

test "document collections - mixed elements sorted in tree order" {
    var doc: TestDocument = undefined;
    try doc.open(.html);
    defer doc.close();

    // Create various elements
    const img1 = try doc.createElement("img");
    const form1 = try doc.createElement("form");
    const script1 = try doc.createElement("script");
    const img2 = try doc.createElement("img");
    const a1 = try doc.createElement("a");
    try doc.nodes.setAttribute(a1, "href", "#");

    // Append in specific order
    try doc.appendChild(img1);
    try doc.appendChild(form1);
    try doc.appendChild(script1);
    try doc.appendChild(img2);
    try doc.appendChild(a1);

    // Get each collection
    const images = try doc.images();
    const forms = try doc.forms();
    const scripts = try doc.scripts();
    const links = try doc.links();

    // Verify counts
    try expectLength(2, images);
    try expectLength(1, forms);
    try expectLength(1, scripts);
    try expectLength(1, links);

    // Verify images are in tree order
    try expectItem(img1, images, 0);
    try expectItem(img2, images, 1);
}

// =============================================================================
// XML Mode Tests (case-sensitive)
// =============================================================================

test "XML document - case sensitive tag matching" {
    var doc: TestDocument = undefined;
    // An XHTML document: createElement makes HTML-namespace elements and
    // does not lowercase the name (DOM 4.5 createElement steps 2 and 4)
    try doc.open(.xhtml);
    defer doc.close();

    // Create img with lowercase
    const img_lower = try doc.createElement("img");
    // Create IMG with uppercase (a different element in XML)
    const img_upper = try doc.createElement("IMG");

    try doc.appendChild(img_lower);
    try doc.appendChild(img_upper);

    // In XML mode, only lowercase "img" is an img element
    const images = try doc.images();
    try expectLength(1, images);
    try expectItem(img_lower, images, 0);
}
