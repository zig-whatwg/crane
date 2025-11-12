//! Document interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-document

const std = @import("std");
const webidl = @import("webidl");
const dom = @import("dom");
const Node = @import("node").Node;
const ParentNode = @import("parent_node").ParentNode;
const NonElementParentNode = @import("non_element_parent_node").NonElementParentNode;
const DocumentOrShadowRoot = @import("document_or_shadow_root").DocumentOrShadowRoot;
const NodeList = @import("node_list").NodeList;
const HTMLCollection = @import("html_collection").HTMLCollection;
const dom_types = @import("dom_types");
const ProcessingInstruction = @import("processing_instruction").ProcessingInstruction;
const CDATASection = @import("cdata_section").CDATASection;
const DocumentType = @import("document_type").DocumentType;
const DOMImplementation = @import("dom_implementation").DOMImplementation;
const Allocator = std.mem.Allocator;
const Element = @import("element").Element;
const Text = @import("text").Text;
const Comment = @import("comment").Comment;
const DocumentFragment = @import("document_fragment").DocumentFragment;
const Attr = @import("attr").Attr;

/// DOM Spec: interface Document : Node
pub const Document = webidl.interface(struct {
    pub const extends = Node;
    pub const includes = .{ ParentNode, NonElementParentNode, DocumentOrShadowRoot };

    allocator: Allocator,
    /// Cached DOMImplementation instance ([SameObject])
    _implementation: ?DOMImplementation,
    /// String interning pool for tag names, attribute names, etc.
    /// Provides memory savings (20-30%) and O(1) string comparison via pointer equality
    _string_pool: std.StringHashMap(void),
    /// Document base URL (fallback: empty string for about:blank)
    base_uri: []const u8,
    /// Document content type (e.g., "text/html", "application/xml")
    content_type: []const u8,
    /// Document type: html or xml
    document_type: enum { html, xml },
    /// Document origin (opaque for now)
    origin: ?*anyopaque,

    pub fn init(allocator: Allocator) !Document {
        // NOTE: Parent Node fields will be flattened by codegen
        return .{
            .allocator = allocator,
            ._implementation = null,
            ._string_pool = std.StringHashMap(void).init(allocator),
            .content_type = "application/xml",
            .document_type = .xml,
            .origin = null,
            .base_uri = "about:blank",
        };
    }

    pub fn deinit(self: *Document) void {
        // Free all interned strings from pool
        var it = self._string_pool.keyIterator();
        while (it.next()) |key_ptr| {
            self.allocator.free(key_ptr.*);
        }
        self._string_pool.deinit();

        // Clean up cached implementation if it exists
        if (self._implementation) |*impl| {
            impl.deinit();
        }
        // NOTE: Parent Node cleanup is handled by codegen
    }

    /// Intern a string in the document's string pool
    /// Returns a pointer to the interned string which can be compared via pointer equality
    /// If the string is already interned, returns the existing copy
    /// Caller does NOT own the returned slice - it's managed by the Document
    pub fn internString(self: *Document, str: []const u8) ![]const u8 {
        // Check if string is already interned
        if (self._string_pool.getKey(str)) |existing| {
            return existing;
        }

        // Not interned yet - allocate and store
        const owned = try self.allocator.dupe(u8, str);
        errdefer self.allocator.free(owned);

        try self._string_pool.put(owned, {});
        return owned;
    }

    /// implementation getter
    /// DOM §4.6 - Returns document's DOMImplementation object
    /// [SameObject] - Always returns the same instance
    pub fn get_implementation(self: *Document) !DOMImplementation {
        if (self._implementation) |impl| {
            return impl;
        }
        // Create and cache the implementation
        const impl = try DOMImplementation.init(self.allocator, self);
        self._implementation = impl;
        return impl;
    }

    /// createElement(localName)
    /// Spec: https://dom.spec.whatwg.org/#dom-document-createelement
    pub fn call_createElement(self: *Document, local_name: []const u8) !*Element {
        // Intern the tag name for memory savings and fast comparison
        const interned_name = try self.internString(local_name);

        const element = try self.allocator.create(Element);
        element.* = try Element.init(self.allocator, interned_name);
        return element;
    }

    /// createTextNode(data)
    /// Spec: https://dom.spec.whatwg.org/#dom-document-createtextnode
    pub fn call_createTextNode(self: *Document, data: []const u8) !*Text {
        const text = try self.allocator.create(Text);
        text.* = try Text.init(self.allocator);

        // Set data field (Text extends CharacterData which has data field)
        const cd: *@import("character_data").CharacterData = @ptrCast(text);
        cd.data = try self.allocator.dupe(u8, data);

        return text;
    }

    /// createComment(data)
    /// DOM §4.6.1 - The createComment(data) method steps are to return
    /// a new Comment node whose data is data and node document is this.
    pub fn call_createComment(self: *Document, data: []const u8) !*Comment {
        const comment = try self.allocator.create(Comment);
        comment.* = try Comment.init(self.allocator);

        // Set data field (Comment extends CharacterData which has data field)
        const cd: *@import("character_data").CharacterData = @ptrCast(comment);
        cd.data = try self.allocator.dupe(u8, data);

        return comment;
    }

    /// createProcessingInstruction(target, data)
    /// DOM §4.6.1 - Creates a ProcessingInstruction node
    /// Returns a new ProcessingInstruction node whose target is target, data is data,
    /// and node document is this.
    pub fn call_createProcessingInstruction(
        self: *Document,
        target: []const u8,
        data: []const u8,
    ) !*ProcessingInstruction {
        const pi = try self.allocator.create(ProcessingInstruction);
        pi.* = try ProcessingInstruction.init(self.allocator, target, data);
        return pi;
    }

    /// createCDATASection(data)
    /// DOM §4.6.1 - Creates a CDATASection node
    /// Returns a new CDATASection node whose data is data and node document is this.
    pub fn call_createCDATASection(self: *Document, data: []const u8) !*CDATASection {
        const cdata = try self.allocator.create(CDATASection);
        cdata.* = try CDATASection.init(self.allocator, data);
        return cdata;
    }

    /// createDocumentType(qualifiedName, publicId, systemId)
    /// DOM §4.6.1 - Creates a DocumentType node
    /// Returns a new DocumentType node whose name is qualifiedName, public ID is publicId,
    /// system ID is systemId, and node document is this.
    pub fn call_createDocumentType(
        self: *Document,
        qualified_name: []const u8,
        public_id: []const u8,
        system_id: []const u8,
    ) !*DocumentType {
        const doctype = try self.allocator.create(DocumentType);
        doctype.* = try DocumentType.init(self.allocator, qualified_name, public_id, system_id);
        return doctype;
    }

    /// createDocumentFragment()
    /// DOM §4.6.1 - The createDocumentFragment() method steps are to return
    /// a new DocumentFragment node whose node document is this.
    pub fn call_createDocumentFragment(self: *Document) !*DocumentFragment {
        const fragment = try self.allocator.create(DocumentFragment);
        fragment.* = try DocumentFragment.init(self.allocator);
        return fragment;
    }

    /// createElementNS(namespace, qualifiedName)
    /// DOM §4.6.1 - Creates an element in the given namespace
    ///
    /// Spec: Internal createElementNS steps:
    /// 1. Validate and extract namespace and qualifiedName
    /// 2. Flatten element creation options (for custom elements)
    /// 3. Create an element with namespace, prefix, localName
    ///
    /// Simplified implementation:
    /// - Sets namespace_uri field on element
    /// - Parses qualified name for prefix:localName
    /// - Skips custom element handling
    pub fn call_createElementNS(
        self: *Document,
        namespace: ?[]const u8,
        qualified_name: []const u8,
    ) !*Element {
        // Parse qualified name for prefix and local name
        var prefix: ?[]const u8 = null;
        var local_name: []const u8 = qualified_name;

        if (std.mem.indexOfScalar(u8, qualified_name, ':')) |colon_pos| {
            prefix = qualified_name[0..colon_pos];
            local_name = qualified_name[colon_pos + 1 ..];
        }

        // Create element with qualified name
        const element = try self.allocator.create(Element);
        element.* = try Element.init(self.allocator, qualified_name);

        // Set namespace, prefix, and local name
        if (namespace) |ns| {
            element.namespace_uri = try self.allocator.dupe(u8, ns);
        }
        if (prefix) |p| {
            element.prefix = try self.allocator.dupe(u8, p);
        }
        element.local_name = try self.allocator.dupe(u8, local_name);

        return element;
    }

    /// createAttribute(localName)
    /// DOM §4.6.1 - Creates an Attr node with the given local name
    pub fn call_createAttribute(self: *Document, local_name: []const u8) !*Attr {
        _ = self;
        _ = local_name;
        return error.NotImplemented;
    }

    /// createAttributeNS(namespace, qualifiedName)
    /// DOM §4.6.1 - Creates an Attr node in the given namespace
    pub fn call_createAttributeNS(
        self: *Document,
        namespace: ?[]const u8,
        qualified_name: []const u8,
    ) !*Attr {
        _ = self;
        _ = namespace;
        _ = qualified_name;
        return error.NotImplemented;
    }

    /// importNode(node, deep)
    /// DOM §4.6.1 - Returns a copy of node imported into this document.
    /// If deep is true, the copy also includes the node's descendants.
    /// TODO: Implement full node cloning algorithm
    pub fn call_importNode(self: *Document, node: *Node, deep: bool) !*Node {
        _ = self;
        _ = node;
        _ = deep;
        return error.NotImplemented;
    }

    /// adoptNode(node)
    /// DOM §4.6.1 - Moves node from another document to this document.
    ///
    /// Spec steps:
    /// 1. If node is a document, throw "NotSupportedError".
    /// 2. If node is a shadow root, throw "HierarchyRequestError".
    /// 3. If node is a DocumentFragment whose host is non-null, return.
    /// 4. Adopt node into this.
    /// 5. Return node.
    pub fn call_adoptNode(self: *Document, node: *Node) !*Node {
        const mutation = @import("dom").mutation;

        // Step 1: If node is a document, throw "NotSupportedError"
        if (node.node_type == Node.DOCUMENT_NODE) {
            return error.NotSupportedError;
        }

        // Step 2: If node is a shadow root, throw "HierarchyRequestError"
        // TODO: Check for shadow root when shadow DOM is implemented
        // For now, we don't have shadow roots, so skip this check

        // Step 3: If node is a DocumentFragment whose host is non-null, return
        if (node.node_type == Node.DOCUMENT_FRAGMENT_NODE) {
            // TODO: Check DocumentFragment.host when shadow DOM is implemented
            // For now, DocumentFragment doesn't have host field, so skip
        }

        // Step 4: Adopt node into this
        try mutation.adopt(node, self);

        // Step 5: Return node
        return node;
    }
}, .{
    .exposed = &.{.Window},
});

// ============================================================================
// Tests for string interning
// ============================================================================

test "Document - internString basic deduplication" {
    const allocator = std.testing.allocator;

    const doc = try allocator.create(Document);
    defer allocator.destroy(doc);
    doc.* = try Document.init(allocator);
    defer doc.deinit();

    // Intern same string twice
    const str1 = try doc.internString("div");
    const str2 = try doc.internString("div");

    // Should return same pointer (deduplicated)
    try std.testing.expect(str1.ptr == str2.ptr);
    try std.testing.expectEqualStrings("div", str1);
}

test "Document - internString different strings" {
    const allocator = std.testing.allocator;

    const doc = try allocator.create(Document);
    defer allocator.destroy(doc);
    doc.* = try Document.init(allocator);
    defer doc.deinit();

    const div = try doc.internString("div");
    const span = try doc.internString("span");

    // Different strings should have different pointers
    try std.testing.expect(div.ptr != span.ptr);
    try std.testing.expectEqualStrings("div", div);
    try std.testing.expectEqualStrings("span", span);
}

test "Document - createElement uses interned tag names" {
    const allocator = std.testing.allocator;

    const doc = try allocator.create(Document);
    defer allocator.destroy(doc);
    doc.* = try Document.init(allocator);
    defer doc.deinit();

    // Create multiple elements with same tag
    const div1 = try doc.call_createElement("div");
    defer {
        div1.deinit();
        allocator.destroy(div1);
    }

    const div2 = try doc.call_createElement("div");
    defer {
        div2.deinit();
        allocator.destroy(div2);
    }

    // Both elements should share the same interned tag name
    try std.testing.expect(div1.tag_name.ptr == div2.tag_name.ptr);
    try std.testing.expectEqualStrings("div", div1.tag_name);
}

test "Document - string interning memory cleanup" {
    const allocator = std.testing.allocator;

    // Create and destroy document with interned strings
    {
        const doc = try allocator.create(Document);
        defer allocator.destroy(doc);
        doc.* = try Document.init(allocator);

        // Intern several strings
        _ = try doc.internString("div");
        _ = try doc.internString("span");
        _ = try doc.internString("p");

        // deinit should free all interned strings
        doc.deinit();
    }

    // std.testing.allocator will fail if there are memory leaks
}
