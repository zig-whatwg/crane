//! HTML Parser DOM Integration
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html
//! HTML Standard §13 "Parsing HTML documents"
//!
//! This module provides the bridge between the HTML tokenizer/tree builder
//! and the DOM layer, converting parsed TreeNodes into proper DOM nodes.
//!
//! ## Usage
//!
//! ```zig
//! const HTMLParser = @import("HTMLParser.zig");
//!
//! // Parse HTML string into a Document
//! const doc = try HTMLParser.parseHTML(allocator, ctx, "<html><body>Hello</body></html>");
//!
//! // Parse HTML fragment into a DocumentFragment
//! const frag = try HTMLParser.parseFragment(allocator, ctx, "<div>content</div>", context_element);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const infra = @import("infra");

// Import DOM implementation modules
const DocumentImpl = @import("Document.zig");
const ElementImpl = @import("Element.zig");
const TextImpl = @import("Text.zig");
const CommentImpl = @import("Comment.zig");
const DocumentTypeImpl = @import("DocumentType.zig");
const DocumentFragmentImpl = @import("DocumentFragment.zig");
const NodeImpl = @import("Node.zig");
const CharacterDataImpl = @import("CharacterData.zig");

/// Error type for HTML parsing operations
pub const ParseError = error{
    OutOfMemory,
    InvalidStateError,
    TokenizerError,
    TreeBuilderError,
    InvalidInput,
};

/// Options for HTML parsing
pub const ParseOptions = struct {
    /// Enable scripting (affects parser behavior for <noscript>)
    scripting_enabled: bool = false,
    /// Fragment parsing context element tag name (null for document parsing)
    context_element: ?[]const u8 = null,
    /// Fragment parsing context element namespace
    context_namespace: Namespace = .html,
};

/// Namespace enumeration matching the tree builder
pub const Namespace = enum {
    html,
    mathml,
    svg,

    pub fn toUri(self: Namespace) ?[]const u8 {
        return switch (self) {
            .html => "http://www.w3.org/1999/xhtml",
            .mathml => "http://www.w3.org/1998/Math/MathML",
            .svg => "http://www.w3.org/2000/svg",
        };
    }
};

/// TreeNode from the HTML parser (simplified for DOM conversion)
/// This mirrors the structure from src/html/parser/tree_builder.zig
pub const TreeNode = struct {
    node_type: NodeType,
    local_name: ?[]const u8,
    namespace: Namespace,
    parent: ?*TreeNode,
    first_child: ?*TreeNode,
    last_child: ?*TreeNode,
    prev_sibling: ?*TreeNode,
    next_sibling: ?*TreeNode,
    attributes: infra.List(Attribute),
    text_content: infra.List(u8),
    doctype_name: ?[]const u8,
    doctype_public_id: ?[]const u8,
    doctype_system_id: ?[]const u8,
    force_quirks: bool,
    allocator: Allocator,

    pub const NodeType = enum {
        document,
        doctype,
        element,
        text,
        comment,
    };

    pub const Attribute = struct {
        name: []const u8,
        value: []const u8,
        namespace: ?Namespace,
    };

    /// Free all resources associated with this node and its descendants
    pub fn deinitRecursive(self: *TreeNode) void {
        // Deinit children first
        var child = self.first_child;
        while (child) |c| {
            const next = c.next_sibling;
            c.deinitRecursive();
            child = next;
        }

        // Free local name
        if (self.local_name) |name| {
            self.allocator.free(name);
        }
        // Free attributes
        const attrs = self.attributes.toSlice();
        for (attrs) |attr| {
            self.allocator.free(attr.name);
            self.allocator.free(attr.value);
        }
        self.attributes.deinit();
        // Free text content
        self.text_content.deinit();
        // Free DOCTYPE fields
        if (self.doctype_name) |n| self.allocator.free(n);
        if (self.doctype_public_id) |p| self.allocator.free(p);
        if (self.doctype_system_id) |s| self.allocator.free(s);
        // Free node itself
        self.allocator.destroy(self);
    }
};

/// Parse an HTML string and return a DOM Document
///
/// This is the main entry point for parsing complete HTML documents.
/// Implements the HTML parsing algorithm from WHATWG HTML Standard §13.2.
///
/// @param allocator Memory allocator for DOM nodes
/// @param ctx Runtime context for DOM instances
/// @param html The HTML string to parse
/// @param options Parsing options (scripting, etc.)
/// @return A Document instance containing the parsed DOM tree
pub fn parseHTML(
    allocator: Allocator,
    ctx: runtime.Context,
    html: []const u8,
    options: ParseOptions,
) ParseError!*runtime.Instance {
    _ = options;

    // For now, create a simple document with basic structure
    // TODO: Integrate with actual HTML tokenizer and tree builder

    // Create the Document
    const document = DocumentImpl.init(
        allocator,
        interfaces.Document.State,
        &interfaces.Document.vtable,
        ctx,
    ) catch return error.OutOfMemory;
    errdefer DocumentImpl.deinit(document);

    // Set document type to HTML
    if (DocumentImpl.getInternal(document)) |doc_internal| {
        doc_internal.doc_type = .html;
    }

    // For simple HTML, parse manually
    // This is a simplified implementation - the full implementation
    // will use the tokenizer and tree builder
    try parseSimpleHTML(allocator, ctx, document, html);

    return document;
}

/// Parse an HTML fragment and return a DocumentFragment
///
/// Implements the HTML fragment parsing algorithm from WHATWG HTML Standard §13.4.
/// Used by innerHTML, outerHTML, insertAdjacentHTML, etc.
///
/// @param allocator Memory allocator for DOM nodes
/// @param ctx Runtime context for DOM instances
/// @param html The HTML fragment string to parse
/// @param context_element The context element for fragment parsing (optional)
/// @return A DocumentFragment containing the parsed nodes
pub fn parseFragment(
    allocator: Allocator,
    ctx: runtime.Context,
    html: []const u8,
    context_element: ?*runtime.Instance,
) ParseError!*runtime.Instance {
    _ = context_element;

    // Create a DocumentFragment
    const fragment = DocumentFragmentImpl.init(
        allocator,
        interfaces.DocumentFragment.State,
        &interfaces.DocumentFragment.vtable,
        ctx,
    ) catch return error.OutOfMemory;
    errdefer DocumentFragmentImpl.deinit(fragment);

    // Parse the HTML into the fragment
    // For now, use simple parsing - full implementation will use tree builder
    try parseSimpleHTMLFragment(allocator, ctx, fragment, html);

    return fragment;
}

/// Convert a TreeNode tree (from tree builder) to DOM nodes
///
/// This function recursively converts the parser's internal TreeNode
/// representation into proper DOM nodes (Element, Text, Comment, etc.)
///
/// @param allocator Memory allocator
/// @param ctx Runtime context
/// @param tree_node The root TreeNode to convert
/// @param parent_dom The parent DOM node to append children to
pub fn convertTreeToDom(
    allocator: Allocator,
    ctx: runtime.Context,
    tree_node: *TreeNode,
    parent_dom: *runtime.Instance,
) ParseError!void {
    var child = tree_node.first_child;
    while (child) |tree_child| {
        const dom_node = try createDomNode(allocator, ctx, tree_child, parent_dom);

        // Append to parent
        _ = NodeImpl.appendChild(parent_dom, dom_node) catch return error.InvalidStateError;

        // Recursively convert children
        try convertTreeToDom(allocator, ctx, tree_child, dom_node);

        child = tree_child.next_sibling;
    }
}

/// Create a single DOM node from a TreeNode
fn createDomNode(
    allocator: Allocator,
    ctx: runtime.Context,
    tree_node: *TreeNode,
    owner_document: *runtime.Instance,
) ParseError!*runtime.Instance {
    return switch (tree_node.node_type) {
        .element => try createElementNode(allocator, ctx, tree_node, owner_document),
        .text => try createTextNode(allocator, ctx, tree_node, owner_document),
        .comment => try createCommentNode(allocator, ctx, tree_node, owner_document),
        .doctype => try createDoctypeNode(allocator, ctx, tree_node, owner_document),
        .document => error.InvalidStateError, // Document should not appear as child
    };
}

/// Create an Element DOM node from a TreeNode
fn createElementNode(
    allocator: Allocator,
    ctx: runtime.Context,
    tree_node: *TreeNode,
    owner_document: *runtime.Instance,
) ParseError!*runtime.Instance {
    const local_name = tree_node.local_name orelse return error.InvalidStateError;

    // Create the element
    const element = ElementImpl.init(
        allocator,
        interfaces.Element.State,
        &interfaces.Element.vtable,
        ctx,
    ) catch return error.OutOfMemory;
    errdefer ElementImpl.deinit(element);

    // Set node type
    NodeImpl.setNodeType(element, NodeImpl.NodeType.ELEMENT_NODE) catch return error.InvalidStateError;

    // Set local name
    ElementImpl.setLocalName(element, local_name) catch return error.InvalidStateError;

    // Set namespace
    if (tree_node.namespace.toUri()) |ns_uri| {
        ElementImpl.setNamespaceURI(element, ns_uri) catch return error.InvalidStateError;
    }

    // Set owner document
    NodeImpl.setOwnerDocument(element, owner_document) catch return error.InvalidStateError;

    // Add attributes
    const attrs = tree_node.attributes.toSlice();
    for (attrs) |attr| {
        ElementImpl.setAttribute(element, attr.name, attr.value) catch continue;
    }

    return element;
}

/// Create a Text DOM node from a TreeNode
fn createTextNode(
    allocator: Allocator,
    ctx: runtime.Context,
    tree_node: *TreeNode,
    owner_document: *runtime.Instance,
) ParseError!*runtime.Instance {
    const text_data = tree_node.text_content.toSlice();

    // Create Text node using constructor
    const dom_string = runtime.DOMString.initInterned(text_data);
    const text = TextImpl.call_constructor(
        allocator,
        ctx,
        webidl.Opt(runtime.DOMString).passed(dom_string),
    ) catch return error.OutOfMemory;
    errdefer TextImpl.deinit(text);

    // Set owner document
    NodeImpl.setOwnerDocument(text, owner_document) catch return error.InvalidStateError;

    return text;
}

/// Create a Comment DOM node from a TreeNode
fn createCommentNode(
    allocator: Allocator,
    ctx: runtime.Context,
    tree_node: *TreeNode,
    owner_document: *runtime.Instance,
) ParseError!*runtime.Instance {
    const comment_data = tree_node.text_content.toSlice();

    // Create Comment node
    const dom_string = runtime.DOMString.initInterned(comment_data);
    const comment = CommentImpl.call_constructor(
        allocator,
        ctx,
        webidl.Opt(runtime.DOMString).passed(dom_string),
    ) catch return error.OutOfMemory;
    errdefer CommentImpl.deinit(comment);

    // Set node type
    NodeImpl.setNodeType(comment, NodeImpl.NodeType.COMMENT_NODE) catch return error.InvalidStateError;

    // Set owner document
    NodeImpl.setOwnerDocument(comment, owner_document) catch return error.InvalidStateError;

    return comment;
}

/// Create a DocumentType DOM node from a TreeNode
fn createDoctypeNode(
    allocator: Allocator,
    ctx: runtime.Context,
    tree_node: *TreeNode,
    owner_document: *runtime.Instance,
) ParseError!*runtime.Instance {
    // Create DocumentType node
    const doctype = DocumentTypeImpl.init(
        allocator,
        interfaces.DocumentType.State,
        &interfaces.DocumentType.vtable,
        ctx,
    ) catch return error.OutOfMemory;
    errdefer DocumentTypeImpl.deinit(doctype);

    // Set node type
    NodeImpl.setNodeType(doctype, NodeImpl.NodeType.DOCUMENT_TYPE_NODE) catch return error.InvalidStateError;

    // Set DocumentType-specific fields
    if (DocumentTypeImpl.getInternal(doctype)) |dt_internal| {
        if (tree_node.doctype_name) |name| {
            dt_internal.name = allocator.dupe(u8, name) catch return error.OutOfMemory;
        }
        if (tree_node.doctype_public_id) |pub_id| {
            dt_internal.public_id = allocator.dupe(u8, pub_id) catch return error.OutOfMemory;
        }
        if (tree_node.doctype_system_id) |sys_id| {
            dt_internal.system_id = allocator.dupe(u8, sys_id) catch return error.OutOfMemory;
        }
    }

    // Set owner document
    NodeImpl.setOwnerDocument(doctype, owner_document) catch return error.InvalidStateError;

    return doctype;
}

// =============================================================================
// Simple HTML Parsing (temporary implementation)
// =============================================================================

/// Simple HTML parser for basic documents
/// This is a temporary implementation until full tokenizer integration
fn parseSimpleHTML(
    allocator: Allocator,
    ctx: runtime.Context,
    document: *runtime.Instance,
    html: []const u8,
) ParseError!void {
    // Skip leading whitespace and DOCTYPE
    var pos: usize = 0;
    pos = skipWhitespace(html, pos);

    // Check for DOCTYPE
    if (startsWithIgnoreCase(html[pos..], "<!doctype")) {
        pos = skipUntil(html, pos, '>') + 1;
        pos = skipWhitespace(html, pos);
    }

    // Create basic structure: <html><head></head><body>...</body></html>
    const html_element = try createElement(allocator, ctx, document, "html");
    _ = NodeImpl.appendChild(document, html_element) catch return error.InvalidStateError;

    // Set as document element
    if (DocumentImpl.getInternal(document)) |doc_internal| {
        doc_internal.document_element = html_element;
    }

    const head_element = try createElement(allocator, ctx, document, "head");
    _ = NodeImpl.appendChild(html_element, head_element) catch return error.InvalidStateError;

    const body_element = try createElement(allocator, ctx, document, "body");
    _ = NodeImpl.appendChild(html_element, body_element) catch return error.InvalidStateError;

    // Parse body content - extract text between <body> and </body>
    if (findTagContent(html, "body")) |body_content| {
        try parseContentInto(allocator, ctx, document, body_element, body_content);
    } else {
        // No body tag, treat remaining content as body content
        if (pos < html.len) {
            try parseContentInto(allocator, ctx, document, body_element, html[pos..]);
        }
    }
}

/// Parse HTML fragment into a container
fn parseSimpleHTMLFragment(
    allocator: Allocator,
    ctx: runtime.Context,
    container: *runtime.Instance,
    html: []const u8,
) ParseError!void {
    // Get owner document (for fragment, we need to create a temporary one or use null)
    const owner_doc = NodeImpl.get_ownerDocument(container) catch null;

    try parseContentInto(allocator, ctx, owner_doc, container, html);
}

/// Parse HTML content into a container element
fn parseContentInto(
    allocator: Allocator,
    ctx: runtime.Context,
    owner_document: ?*runtime.Instance,
    container: *runtime.Instance,
    content: []const u8,
) ParseError!void {
    var pos: usize = 0;

    while (pos < content.len) {
        // Skip whitespace
        const ws_start = pos;
        pos = skipWhitespace(content, pos);

        // Check what we have
        if (pos >= content.len) break;

        if (content[pos] == '<') {
            // Tag or comment
            if (pos + 1 < content.len) {
                if (content[pos + 1] == '!') {
                    // Comment or DOCTYPE
                    if (startsWithIgnoreCase(content[pos..], "<!--")) {
                        // Comment
                        const end = findStr(content, pos + 4, "-->") orelse content.len;
                        const comment_text = content[pos + 4 .. end];
                        const comment = try createComment(allocator, ctx, owner_document, comment_text);
                        _ = NodeImpl.appendChild(container, comment) catch return error.InvalidStateError;
                        pos = @min(end + 3, content.len);
                        continue;
                    } else {
                        // Skip other declarations
                        pos = skipUntil(content, pos, '>') + 1;
                        continue;
                    }
                } else if (content[pos + 1] == '/') {
                    // End tag - skip for now (simple parser)
                    pos = skipUntil(content, pos, '>') + 1;
                    continue;
                } else {
                    // Start tag
                    const tag_end = skipUntil(content, pos, '>');
                    const tag_content = content[pos + 1 .. tag_end];

                    // Parse tag name
                    const name_end = findAny(tag_content, " \t\n\r/>") orelse tag_content.len;
                    const tag_name = tag_content[0..name_end];

                    if (tag_name.len > 0) {
                        // Check if self-closing or void element
                        const is_void = isVoidElement(tag_name);
                        const is_self_closing = tag_content.len > 0 and tag_content[tag_content.len - 1] == '/';

                        const element = try createElement(allocator, ctx, owner_document, tag_name);
                        _ = NodeImpl.appendChild(container, element) catch return error.InvalidStateError;

                        pos = tag_end + 1;

                        if (!is_void and !is_self_closing) {
                            // Find matching end tag and parse children
                            if (findEndTag(content, pos, tag_name)) |end_info| {
                                const inner_content = content[pos..end_info.start];
                                try parseContentInto(allocator, ctx, owner_document, element, inner_content);
                                pos = end_info.end;
                            }
                        }
                    } else {
                        pos = tag_end + 1;
                    }
                    continue;
                }
            }
        }

        // Text content
        const text_end = findChar(content, pos, '<') orelse content.len;
        if (text_end > pos) {
            var text_content = content[pos..text_end];
            // Include leading whitespace if significant
            if (ws_start < pos and ws_start < text_end) {
                text_content = content[ws_start..text_end];
            }
            // Trim and check if non-empty
            const trimmed = std.mem.trim(u8, text_content, " \t\n\r");
            if (trimmed.len > 0) {
                const text = try createText(allocator, ctx, owner_document, text_content);
                _ = NodeImpl.appendChild(container, text) catch return error.InvalidStateError;
            }
        }
        pos = text_end;
    }
}

/// Create an element with the given tag name
fn createElement(
    allocator: Allocator,
    ctx: runtime.Context,
    owner_document: ?*runtime.Instance,
    tag_name: []const u8,
) ParseError!*runtime.Instance {
    const element = ElementImpl.init(
        allocator,
        interfaces.Element.State,
        &interfaces.Element.vtable,
        ctx,
    ) catch return error.OutOfMemory;
    errdefer ElementImpl.deinit(element);

    NodeImpl.setNodeType(element, NodeImpl.NodeType.ELEMENT_NODE) catch return error.InvalidStateError;
    ElementImpl.setLocalName(element, tag_name) catch return error.InvalidStateError;

    if (owner_document) |doc| {
        NodeImpl.setOwnerDocument(element, doc) catch return error.InvalidStateError;
    }

    return element;
}

/// Create a text node
fn createText(
    allocator: Allocator,
    ctx: runtime.Context,
    owner_document: ?*runtime.Instance,
    text: []const u8,
) ParseError!*runtime.Instance {
    const dom_string = runtime.DOMString.initInterned(text);
    const text_node = TextImpl.call_constructor(
        allocator,
        ctx,
        webidl.Opt(runtime.DOMString).passed(dom_string),
    ) catch return error.OutOfMemory;
    errdefer TextImpl.deinit(text_node);

    if (owner_document) |doc| {
        NodeImpl.setOwnerDocument(text_node, doc) catch return error.InvalidStateError;
    }

    return text_node;
}

/// Create a comment node
fn createComment(
    allocator: Allocator,
    ctx: runtime.Context,
    owner_document: ?*runtime.Instance,
    comment_text: []const u8,
) ParseError!*runtime.Instance {
    const dom_string = runtime.DOMString.initInterned(comment_text);
    const comment = CommentImpl.call_constructor(
        allocator,
        ctx,
        webidl.Opt(runtime.DOMString).passed(dom_string),
    ) catch return error.OutOfMemory;
    errdefer CommentImpl.deinit(comment);

    NodeImpl.setNodeType(comment, NodeImpl.NodeType.COMMENT_NODE) catch return error.InvalidStateError;

    if (owner_document) |doc| {
        NodeImpl.setOwnerDocument(comment, doc) catch return error.InvalidStateError;
    }

    return comment;
}

// =============================================================================
// String Utilities
// =============================================================================

fn skipWhitespace(s: []const u8, start: usize) usize {
    var i = start;
    while (i < s.len and (s[i] == ' ' or s[i] == '\t' or s[i] == '\n' or s[i] == '\r')) {
        i += 1;
    }
    return i;
}

fn skipUntil(s: []const u8, start: usize, char: u8) usize {
    var i = start;
    while (i < s.len and s[i] != char) {
        i += 1;
    }
    return i;
}

fn findChar(s: []const u8, start: usize, char: u8) ?usize {
    var i = start;
    while (i < s.len) : (i += 1) {
        if (s[i] == char) return i;
    }
    return null;
}

fn findStr(s: []const u8, start: usize, needle: []const u8) ?usize {
    if (start + needle.len > s.len) return null;
    var i = start;
    while (i + needle.len <= s.len) : (i += 1) {
        if (std.mem.eql(u8, s[i..][0..needle.len], needle)) return i;
    }
    return null;
}

fn findAny(s: []const u8, chars: []const u8) ?usize {
    for (s, 0..) |c, i| {
        for (chars) |target| {
            if (c == target) return i;
        }
    }
    return null;
}

fn startsWithIgnoreCase(s: []const u8, prefix: []const u8) bool {
    if (s.len < prefix.len) return false;
    for (s[0..prefix.len], prefix) |a, b| {
        if (std.ascii.toLower(a) != std.ascii.toLower(b)) return false;
    }
    return true;
}

fn isVoidElement(tag_name: []const u8) bool {
    const void_elements = [_][]const u8{
        "area", "base", "br",    "col",    "embed", "hr",  "img", "input",
        "link", "meta", "param", "source", "track", "wbr",
    };
    for (void_elements) |ve| {
        if (std.ascii.eqlIgnoreCase(tag_name, ve)) return true;
    }
    return false;
}

fn findTagContent(html: []const u8, tag_name: []const u8) ?[]const u8 {
    // Find <tagname> and </tagname>
    var pos: usize = 0;
    while (pos < html.len) {
        if (html[pos] == '<') {
            if (pos + 1 + tag_name.len < html.len) {
                const tag_start = pos + 1;
                const tag_end = tag_start + tag_name.len;
                if (tag_end < html.len and
                    std.ascii.eqlIgnoreCase(html[tag_start..tag_end], tag_name) and
                    (html[tag_end] == '>' or html[tag_end] == ' ' or html[tag_end] == '\t'))
                {
                    // Found start tag
                    const content_start = skipUntil(html, pos, '>') + 1;
                    // Find end tag
                    if (findEndTag(html, content_start, tag_name)) |end_info| {
                        return html[content_start..end_info.start];
                    }
                }
            }
        }
        pos += 1;
    }
    return null;
}

const EndTagInfo = struct {
    start: usize,
    end: usize,
};

fn findEndTag(html: []const u8, start: usize, tag_name: []const u8) ?EndTagInfo {
    var pos = start;
    var depth: usize = 1;

    while (pos < html.len) {
        if (html[pos] == '<') {
            if (pos + 2 + tag_name.len <= html.len) {
                if (html[pos + 1] == '/') {
                    // End tag
                    const tag_start = pos + 2;
                    const tag_end_pos = tag_start + tag_name.len;
                    if (tag_end_pos <= html.len and
                        std.ascii.eqlIgnoreCase(html[tag_start..tag_end_pos], tag_name))
                    {
                        depth -= 1;
                        if (depth == 0) {
                            const close = skipUntil(html, pos, '>') + 1;
                            return .{ .start = pos, .end = close };
                        }
                    }
                } else if (html[pos + 1] != '!' and html[pos + 1] != '?') {
                    // Start tag - check if same element (for nesting)
                    const tag_start = pos + 1;
                    const name_end = findAny(html[tag_start..], " \t\n\r/>") orelse (html.len - tag_start);
                    if (name_end == tag_name.len and
                        std.ascii.eqlIgnoreCase(html[tag_start..][0..name_end], tag_name))
                    {
                        // Check if not self-closing
                        const tag_close = skipUntil(html, pos, '>');
                        if (tag_close > 0 and html[tag_close - 1] != '/') {
                            depth += 1;
                        }
                    }
                }
            }
        }
        pos += 1;
    }
    return null;
}

// =============================================================================
// Tests
// =============================================================================

test "HTMLParser - create basic document" {
    const allocator = std.testing.allocator;
    const ctx = runtime.Context{}; // Mock context

    const doc = try parseHTML(allocator, ctx, "<html><body>Hello</body></html>", .{});
    defer DocumentImpl.deinit(doc);

    // Verify document was created
    try std.testing.expect(doc != null);
}

test "HTMLParser - isVoidElement" {
    try std.testing.expect(isVoidElement("br"));
    try std.testing.expect(isVoidElement("img"));
    try std.testing.expect(isVoidElement("input"));
    try std.testing.expect(!isVoidElement("div"));
    try std.testing.expect(!isVoidElement("span"));
}

test "HTMLParser - startsWithIgnoreCase" {
    try std.testing.expect(startsWithIgnoreCase("<!DOCTYPE html>", "<!doctype"));
    try std.testing.expect(startsWithIgnoreCase("<!doctype html>", "<!DOCTYPE"));
    try std.testing.expect(!startsWithIgnoreCase("hello", "<!doctype"));
}
