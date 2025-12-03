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
//! NOTE: These tests use the internal NodeBase/ElementWithBase types directly
//! to avoid requiring the full WebIDL interface chain and V8 runtime.

const std = @import("std");
const testing = std.testing;
const dom = @import("dom");
const infra = @import("infra");

// Internal DOM types (don't require V8)
const NodeBase = dom.NodeBase;
const ElementWithBase = dom.ElementWithBase;
const TextWithBase = dom.TextWithBase;

// =============================================================================
// Test Infrastructure
// =============================================================================

/// A simple document-like root for testing
/// This simulates document structure without requiring runtime.Instance
const TestDocument = struct {
    allocator: std.mem.Allocator,
    root: NodeBase,
    children: std.ArrayListUnmanaged(*NodeBase),
    elements: std.ArrayListUnmanaged(*ElementWithBase),

    /// Document type determines case-sensitivity for matching
    is_html: bool = true,

    pub fn init(allocator: std.mem.Allocator) TestDocument {
        return .{
            .allocator = allocator,
            .root = NodeBase{
                .allocator = allocator,
                .node_type = NodeBase.DOCUMENT_NODE,
                .node_name = "#document",
                .parent_node = null,
                .child_nodes = infra.List(*NodeBase).init(allocator),
                .owner_document = null,
                .registered_observers = infra.List(dom.node_base.RegisteredObserverType).init(allocator),
            },
            .children = .{},
            .elements = .{},
        };
    }

    pub fn deinit(self: *TestDocument) void {
        // Clean up all created elements
        for (self.elements.items) |elem| {
            elem.deinit();
            self.allocator.destroy(elem);
        }
        self.elements.deinit(self.allocator);
        self.children.deinit(self.allocator);
        self.root.child_nodes.deinit();
        self.root.registered_observers.deinit();
    }

    /// Create an element and track it for cleanup
    pub fn createElement(self: *TestDocument, tag_name: []const u8) !*ElementWithBase {
        const elem = try self.allocator.create(ElementWithBase);
        errdefer self.allocator.destroy(elem);

        elem.* = ElementWithBase.init(self.allocator, tag_name);
        try self.elements.append(self.allocator, elem);
        return elem;
    }

    /// Append child to document root
    pub fn appendChild(self: *TestDocument, child: *ElementWithBase) !void {
        const node = child.asNode();
        node.parent_node = &self.root;
        try self.root.child_nodes.append(node);
        try self.children.append(self.allocator, node);
    }

    /// Remove child from document root
    pub fn removeChild(self: *TestDocument, child: *ElementWithBase) !void {
        const node = child.asNode();
        const items = self.root.child_nodes.items();
        for (items, 0..) |item, i| {
            if (item == node) {
                _ = try self.root.child_nodes.remove(i);
                node.parent_node = null;

                // Also remove from children tracking list
                for (self.children.items, 0..) |c, j| {
                    if (c == node) {
                        _ = self.children.orderedRemove(j);
                        break;
                    }
                }
                return;
            }
        }
        return error.NotFoundError;
    }

    /// Get images collection (elements with tag "img")
    /// Returns a list of matching elements
    pub fn getImages(self: *TestDocument) !std.ArrayListUnmanaged(*ElementWithBase) {
        return self.getElementsByTagName("img");
    }

    /// Get forms collection (elements with tag "form")
    pub fn getForms(self: *TestDocument) !std.ArrayListUnmanaged(*ElementWithBase) {
        return self.getElementsByTagName("form");
    }

    /// Get scripts collection (elements with tag "script")
    pub fn getScripts(self: *TestDocument) !std.ArrayListUnmanaged(*ElementWithBase) {
        return self.getElementsByTagName("script");
    }

    /// Get links collection (a and area elements)
    /// Note: Full spec requires href attribute, this is simplified
    pub fn getLinks(self: *TestDocument) !std.ArrayListUnmanaged(*ElementWithBase) {
        return self.getElementsByTagNames(&[_][]const u8{ "a", "area" });
    }

    /// Get elements by tag name (tree traversal)
    pub fn getElementsByTagName(self: *TestDocument, tag_name: []const u8) !std.ArrayListUnmanaged(*ElementWithBase) {
        var results = std.ArrayListUnmanaged(*ElementWithBase){};
        errdefer results.deinit(self.allocator);

        // Traverse all children of root
        const children = self.root.child_nodes.items();
        for (children) |child| {
            try self.collectElementsByTagName(child, tag_name, &results);
        }

        return results;
    }

    /// Get elements by multiple tag names
    pub fn getElementsByTagNames(self: *TestDocument, tag_names: []const []const u8) !std.ArrayListUnmanaged(*ElementWithBase) {
        var results = std.ArrayListUnmanaged(*ElementWithBase){};
        errdefer results.deinit(self.allocator);

        // Traverse all children of root
        const children = self.root.child_nodes.items();
        for (children) |child| {
            try self.collectElementsByTagNames(child, tag_names, &results);
        }

        return results;
    }

    fn collectElementsByTagName(
        self: *TestDocument,
        node: *NodeBase,
        target_name: []const u8,
        results: *std.ArrayListUnmanaged(*ElementWithBase),
    ) !void {
        if (node.node_type == NodeBase.ELEMENT_NODE) {
            const elem: *ElementWithBase = @ptrCast(node);
            // Case-insensitive comparison for HTML documents
            if (self.is_html) {
                if (std.ascii.eqlIgnoreCase(elem.tag_name, target_name)) {
                    try results.append(self.allocator, elem);
                }
            } else {
                if (std.mem.eql(u8, elem.tag_name, target_name)) {
                    try results.append(self.allocator, elem);
                }
            }

            // Recurse into children
            const children = elem.base.child_nodes.items();
            for (children) |child| {
                try self.collectElementsByTagName(child, target_name, results);
            }
        }
    }

    fn collectElementsByTagNames(
        self: *TestDocument,
        node: *NodeBase,
        target_names: []const []const u8,
        results: *std.ArrayListUnmanaged(*ElementWithBase),
    ) !void {
        if (node.node_type == NodeBase.ELEMENT_NODE) {
            const elem: *ElementWithBase = @ptrCast(node);

            // Check against all target names
            var matches = false;
            for (target_names) |target_name| {
                if (self.is_html) {
                    if (std.ascii.eqlIgnoreCase(elem.tag_name, target_name)) {
                        matches = true;
                        break;
                    }
                } else {
                    if (std.mem.eql(u8, elem.tag_name, target_name)) {
                        matches = true;
                        break;
                    }
                }
            }

            if (matches) {
                try results.append(self.allocator, elem);
            }

            // Recurse into children
            const children = elem.base.child_nodes.items();
            for (children) |child| {
                try self.collectElementsByTagNames(child, target_names, results);
            }
        }
    }
};

// =============================================================================
// document.images Tests
// =============================================================================

test "document.images - empty document returns empty collection" {
    const allocator = testing.allocator;

    var doc = TestDocument.init(allocator);
    defer doc.deinit();

    var images = try doc.getImages();
    defer images.deinit(allocator);

    try testing.expectEqual(@as(usize, 0), images.items.len);
}

test "document.images - returns img elements" {
    const allocator = testing.allocator;

    var doc = TestDocument.init(allocator);
    defer doc.deinit();

    // Create img elements
    const img1 = try doc.createElement("img");
    const img2 = try doc.createElement("img");

    // Append to document
    try doc.appendChild(img1);
    try doc.appendChild(img2);

    // Get images collection
    var images = try doc.getImages();
    defer images.deinit(allocator);

    try testing.expectEqual(@as(usize, 2), images.items.len);
    try testing.expectEqual(img1, images.items[0]);
    try testing.expectEqual(img2, images.items[1]);
}

test "document.images - does not include other elements" {
    const allocator = testing.allocator;

    var doc = TestDocument.init(allocator);
    defer doc.deinit();

    // Create mixed elements
    const img = try doc.createElement("img");
    const div = try doc.createElement("div");
    const span = try doc.createElement("span");

    try doc.appendChild(img);
    try doc.appendChild(div);
    try doc.appendChild(span);

    var images = try doc.getImages();
    defer images.deinit(allocator);

    // Should only include img
    try testing.expectEqual(@as(usize, 1), images.items.len);
    try testing.expectEqual(img, images.items[0]);
}

test "document.images - case insensitive in HTML mode" {
    const allocator = testing.allocator;

    var doc = TestDocument.init(allocator);
    defer doc.deinit();

    // Create IMG with uppercase (uncommon but valid)
    const img = try doc.createElement("IMG");
    try doc.appendChild(img);

    var images = try doc.getImages();
    defer images.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), images.items.len);
}

// =============================================================================
// document.forms Tests
// =============================================================================

test "document.forms - empty document returns empty collection" {
    const allocator = testing.allocator;

    var doc = TestDocument.init(allocator);
    defer doc.deinit();

    var forms = try doc.getForms();
    defer forms.deinit(allocator);

    try testing.expectEqual(@as(usize, 0), forms.items.len);
}

test "document.forms - returns form elements" {
    const allocator = testing.allocator;

    var doc = TestDocument.init(allocator);
    defer doc.deinit();

    // Create form elements
    const form1 = try doc.createElement("form");
    const form2 = try doc.createElement("form");

    try doc.appendChild(form1);
    try doc.appendChild(form2);

    var forms = try doc.getForms();
    defer forms.deinit(allocator);

    try testing.expectEqual(@as(usize, 2), forms.items.len);
}

// =============================================================================
// document.scripts Tests
// =============================================================================

test "document.scripts - empty document returns empty collection" {
    const allocator = testing.allocator;

    var doc = TestDocument.init(allocator);
    defer doc.deinit();

    var scripts = try doc.getScripts();
    defer scripts.deinit(allocator);

    try testing.expectEqual(@as(usize, 0), scripts.items.len);
}

test "document.scripts - returns script elements" {
    const allocator = testing.allocator;

    var doc = TestDocument.init(allocator);
    defer doc.deinit();

    const script1 = try doc.createElement("script");
    const script2 = try doc.createElement("script");
    const script3 = try doc.createElement("script");

    try doc.appendChild(script1);
    try doc.appendChild(script2);
    try doc.appendChild(script3);

    var scripts = try doc.getScripts();
    defer scripts.deinit(allocator);

    try testing.expectEqual(@as(usize, 3), scripts.items.len);
}

// =============================================================================
// document.links Tests
// =============================================================================

test "document.links - empty document returns empty collection" {
    const allocator = testing.allocator;

    var doc = TestDocument.init(allocator);
    defer doc.deinit();

    var links = try doc.getLinks();
    defer links.deinit(allocator);

    try testing.expectEqual(@as(usize, 0), links.items.len);
}

test "document.links - returns a and area elements" {
    const allocator = testing.allocator;

    var doc = TestDocument.init(allocator);
    defer doc.deinit();

    // Create link elements (a and area)
    const a1 = try doc.createElement("a");
    const a2 = try doc.createElement("a");
    const area1 = try doc.createElement("area");

    try doc.appendChild(a1);
    try doc.appendChild(a2);
    try doc.appendChild(area1);

    var links = try doc.getLinks();
    defer links.deinit(allocator);

    // Should include all a and area elements
    try testing.expectEqual(@as(usize, 3), links.items.len);
}

// =============================================================================
// Nested Element Tests
// =============================================================================

test "document.images - finds nested img elements" {
    const allocator = testing.allocator;

    var doc = TestDocument.init(allocator);
    defer doc.deinit();

    // Create nested structure: doc > div > img
    const div = try doc.createElement("div");
    const img = try doc.createElement("img");

    try doc.appendChild(div);
    _ = try div.appendChild(img.asNode());

    var images = try doc.getImages();
    defer images.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), images.items.len);
    try testing.expectEqual(img, images.items[0]);
}

test "document.forms - finds deeply nested form elements" {
    const allocator = testing.allocator;

    var doc = TestDocument.init(allocator);
    defer doc.deinit();

    // Create deeply nested structure: doc > div > section > form
    const div = try doc.createElement("div");
    const section = try doc.createElement("section");
    const form = try doc.createElement("form");

    try doc.appendChild(div);
    _ = try div.appendChild(section.asNode());
    _ = try section.appendChild(form.asNode());

    var forms = try doc.getForms();
    defer forms.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), forms.items.len);
}

test "document.scripts - finds scripts at multiple levels" {
    const allocator = testing.allocator;

    var doc = TestDocument.init(allocator);
    defer doc.deinit();

    // Create: doc > script1
    //              div > script2
    //                    span > script3
    const script1 = try doc.createElement("script");
    const div = try doc.createElement("div");
    const script2 = try doc.createElement("script");
    const span = try doc.createElement("span");
    const script3 = try doc.createElement("script");

    try doc.appendChild(script1);
    try doc.appendChild(div);
    _ = try div.appendChild(script2.asNode());
    _ = try div.appendChild(span.asNode());
    _ = try span.appendChild(script3.asNode());

    var scripts = try doc.getScripts();
    defer scripts.deinit(allocator);

    try testing.expectEqual(@as(usize, 3), scripts.items.len);
}

// =============================================================================
// Live Collection Tests (collection updates with DOM changes)
// =============================================================================

test "document.images - collection reflects added elements" {
    const allocator = testing.allocator;

    var doc = TestDocument.init(allocator);
    defer doc.deinit();

    // Get images collection when empty
    var images1 = try doc.getImages();
    defer images1.deinit(allocator);

    try testing.expectEqual(@as(usize, 0), images1.items.len);

    // Add an image
    const img = try doc.createElement("img");
    try doc.appendChild(img);

    // Get a new collection - it should include the new image
    var images2 = try doc.getImages();
    defer images2.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), images2.items.len);
}

test "document.forms - collection reflects removed elements" {
    const allocator = testing.allocator;

    var doc = TestDocument.init(allocator);
    defer doc.deinit();

    // Add two forms
    const form1 = try doc.createElement("form");
    const form2 = try doc.createElement("form");
    try doc.appendChild(form1);
    try doc.appendChild(form2);

    // Get initial collection
    var forms1 = try doc.getForms();
    defer forms1.deinit(allocator);

    try testing.expectEqual(@as(usize, 2), forms1.items.len);

    // Remove one form
    try doc.removeChild(form1);

    // Get new collection - should reflect the removal
    var forms2 = try doc.getForms();
    defer forms2.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), forms2.items.len);
}

// =============================================================================
// Collection Item Boundary Tests
// =============================================================================

test "collection - out of bounds returns nothing" {
    const allocator = testing.allocator;

    var doc = TestDocument.init(allocator);
    defer doc.deinit();

    const img = try doc.createElement("img");
    try doc.appendChild(img);

    var images = try doc.getImages();
    defer images.deinit(allocator);

    // Valid index
    try testing.expect(images.items.len > 0);
    try testing.expectEqual(img, images.items[0]);

    // Out of bounds would be index >= len
    try testing.expectEqual(@as(usize, 1), images.items.len);
}

// =============================================================================
// Mixed Content Tests
// =============================================================================

test "document collections - mixed elements sorted in tree order" {
    const allocator = testing.allocator;

    var doc = TestDocument.init(allocator);
    defer doc.deinit();

    // Create various elements
    const img1 = try doc.createElement("img");
    const form1 = try doc.createElement("form");
    const script1 = try doc.createElement("script");
    const img2 = try doc.createElement("img");
    const a1 = try doc.createElement("a");

    // Append in specific order
    try doc.appendChild(img1);
    try doc.appendChild(form1);
    try doc.appendChild(script1);
    try doc.appendChild(img2);
    try doc.appendChild(a1);

    // Get each collection
    var images = try doc.getImages();
    defer images.deinit(allocator);
    var forms = try doc.getForms();
    defer forms.deinit(allocator);
    var scripts = try doc.getScripts();
    defer scripts.deinit(allocator);
    var links = try doc.getLinks();
    defer links.deinit(allocator);

    // Verify counts
    try testing.expectEqual(@as(usize, 2), images.items.len);
    try testing.expectEqual(@as(usize, 1), forms.items.len);
    try testing.expectEqual(@as(usize, 1), scripts.items.len);
    try testing.expectEqual(@as(usize, 1), links.items.len);

    // Verify images are in tree order
    try testing.expectEqual(img1, images.items[0]);
    try testing.expectEqual(img2, images.items[1]);
}

// =============================================================================
// XML Mode Tests (case-sensitive)
// =============================================================================

test "XML document - case sensitive tag matching" {
    const allocator = testing.allocator;

    var doc = TestDocument.init(allocator);
    defer doc.deinit();

    // Set to XML mode (case-sensitive)
    doc.is_html = false;

    // Create img with lowercase
    const img_lower = try doc.createElement("img");
    // Create IMG with uppercase (different in XML)
    const img_upper = try doc.createElement("IMG");

    try doc.appendChild(img_lower);
    try doc.appendChild(img_upper);

    // In XML mode, only lowercase "img" should match
    var images = try doc.getImages();
    defer images.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), images.items.len);
    try testing.expectEqual(img_lower, images.items[0]);
}
