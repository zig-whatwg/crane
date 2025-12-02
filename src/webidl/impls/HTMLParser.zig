//! HTML Parser DOM Integration
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html
//! HTML Standard §13 "Parsing HTML documents"
//!
//! This module provides the bridge between the full HTML tokenizer/tree builder
//! and the DOM layer, converting parsed TreeNodes into proper DOM nodes.
//!
//! The parsing uses:
//! - Full 80-state tokenizer (HTML Standard §13.2.5)
//! - Full 24-mode tree builder (HTML Standard §13.2.6)
//! - Proper DOM node creation for all node types
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

// Import the full HTML parser
const html_parser = @import("html_parser");
const Tokenizer = html_parser.Tokenizer;
const TreeBuilder = html_parser.TreeBuilder;
const TreeNode = html_parser.TreeNode;
const InsertionMode = html_parser.InsertionMode;
const QuirksMode = html_parser.QuirksMode;
const ParserNamespace = html_parser.Namespace;

// Import DOM implementation modules
const DocumentImpl = @import("Document.zig");
const ElementImpl = @import("Element.zig");
const TextImpl = @import("Text.zig");
const CommentImpl = @import("Comment.zig");
const DocumentTypeImpl = @import("DocumentType.zig");
const DocumentFragmentImpl = @import("DocumentFragment.zig");
const NodeImpl = @import("Node.zig");
const CharacterDataImpl = @import("CharacterData.zig");
const HTMLScriptElementImpl = @import("HTMLScriptElement.zig");

// Import script execution module - inline implementation since the html module
// is not directly accessible from impls
const ScriptExecution = struct {
    /// Prepare a script element for execution
    /// Currently a simplified version that handles inline classic scripts only
    pub fn prepareScriptElement(allocator: std.mem.Allocator, script_element: *runtime.Instance) !bool {
        // Check if already started
        if (HTMLScriptElementImpl.hasAlreadyStarted(script_element)) {
            return false;
        }

        // Get parser document
        const parser_document = HTMLScriptElementImpl.getParserDocument(script_element);

        // Clear parser document temporarily
        HTMLScriptElementImpl.setParserDocument(script_element, null);

        // Get source text from element's text content
        const source_text = getScriptSourceText(allocator, script_element) catch return false;
        defer if (source_text.len > 0) allocator.free(source_text);

        // If no src and no source text, return
        if (!hasAttribute(script_element, "src") and source_text.len == 0) {
            return false;
        }

        // Check if connected
        if (!isConnected(script_element)) {
            return false;
        }

        // Determine script type
        const script_type = determineScriptType(script_element);
        if (script_type == .null) {
            return false;
        }

        // Restore parser document if was parser-inserted
        if (parser_document) |pd| {
            HTMLScriptElementImpl.setParserDocument(script_element, pd);
            HTMLScriptElementImpl.clearForceAsync(script_element);
        }

        // Mark as already started
        HTMLScriptElementImpl.setAlreadyStarted(script_element, true);

        // Set preparation-time document
        const node_doc = getNodeDocument(script_element);
        HTMLScriptElementImpl.setPreparationTimeDocument(script_element, node_doc);

        // Check scripting enabled
        if (node_doc) |doc| {
            if (!DocumentImpl.isScriptingEnabled(doc)) {
                return false;
            }
        }

        // Set script type
        HTMLScriptElementImpl.setScriptType(script_element, script_type);

        // For inline classic scripts without external src, execute immediately
        if (!hasAttribute(script_element, "src")) {
            if (script_type == .classic) {
                // Cache source text
                HTMLScriptElementImpl.cacheSourceText(script_element, source_text) catch return false;

                // Set result
                const script = HTMLScriptElementImpl.ClassicScript.init(source_text, "");
                HTMLScriptElementImpl.setResult(script_element, .{ .script = script });

                // Execute (if parser-inserted and inline, execute immediately)
                if (parser_document != null) {
                    executeScriptElement(allocator, script_element) catch {};
                }
                return true;
            }
        }

        return true;
    }

    /// Execute a prepared script element
    fn executeScriptElement(allocator: std.mem.Allocator, script_element: *runtime.Instance) !void {
        _ = allocator;

        const node_doc = getNodeDocument(script_element) orelse return;
        const prep_doc = HTMLScriptElementImpl.getPreparationTimeDocument(script_element);

        if (prep_doc != node_doc) {
            return;
        }

        const script_type = HTMLScriptElementImpl.getScriptType(script_element);
        if (script_type != .classic) {
            return; // Only classic scripts supported for now
        }

        // Get old current script
        const old_script = DocumentImpl.getCurrentScript(node_doc);

        // Set current script
        DocumentImpl.setCurrentScript(node_doc, script_element);
        defer DocumentImpl.setCurrentScript(node_doc, old_script);

        // Run the script
        runClassicScript(script_element) catch |err| {
            std.debug.print("Script execution error: {}\n", .{err});
        };
    }

    /// Run a classic script using V8
    fn runClassicScript(script_element: *runtime.Instance) !void {
        const source = HTMLScriptElementImpl.getCachedSourceText(script_element) orelse return;

        // Get V8 FFI
        const v8 = @import("v8");
        const ffi = v8.ffi;

        const isolate = ffi.v8_Isolate_GetCurrent() orelse {
            std.debug.print("No V8 isolate for script execution\n", .{});
            return;
        };

        const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
            std.debug.print("No V8 context for script execution\n", .{});
            return;
        };

        const source_str = ffi.v8_String_NewFromUtf8(isolate, source.ptr, @intCast(source.len)) orelse {
            return;
        };
        defer ffi.v8_String_Dispose(source_str);

        const script = ffi.v8_Script_Compile(context, source_str) orelse {
            std.debug.print("Script compile failed\n", .{});
            return;
        };
        defer ffi.v8_Script_Dispose(script);

        _ = ffi.v8_Script_Run(context, script);
    }

    // Helper functions

    fn hasAttribute(element: *runtime.Instance, name: []const u8) bool {
        if (ElementImpl.getInternal(element)) |internal| {
            for (internal.attributes.items) |attr| {
                if (std.mem.eql(u8, attr.local_name, name)) {
                    return true;
                }
            }
        }
        return false;
    }

    fn getAttribute(element: *runtime.Instance, name: []const u8) ?[]const u8 {
        if (ElementImpl.getInternal(element)) |internal| {
            for (internal.attributes.items) |attr| {
                if (std.mem.eql(u8, attr.local_name, name)) {
                    return attr.value;
                }
            }
        }
        return null;
    }

    fn isConnected(element: *runtime.Instance) bool {
        return getNodeDocument(element) != null;
    }

    fn getNodeDocument(node: *runtime.Instance) ?*runtime.Instance {
        if (NodeImpl.getInternalState(node)) |internal| {
            return internal.owner_document;
        }
        return null;
    }

    fn getScriptSourceText(allocator: std.mem.Allocator, element: *runtime.Instance) ![]const u8 {
        var result: std.ArrayListUnmanaged(u8) = .{};
        errdefer result.deinit(allocator);

        try collectTextContent(element, &result, allocator);

        if (result.items.len == 0) {
            result.deinit(allocator);
            return "";
        }

        return try result.toOwnedSlice(allocator);
    }

    fn collectTextContent(node: *runtime.Instance, result: *std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator) !void {
        const node_type = NodeImpl.getNodeType(node) orelse return;

        if (node_type == NodeImpl.NodeType.TEXT_NODE) {
            // Text inherits from CharacterData, which stores the actual data
            if (CharacterDataImpl.getInternalState(node)) |char_internal| {
                try result.appendSlice(allocator, char_internal.data);
            }
        } else {
            var child = NodeImpl.getFirstChild(node);
            while (child) |c| {
                try collectTextContent(c, result, allocator);
                child = NodeImpl.getNextSibling(c);
            }
        }
    }

    fn determineScriptType(element: *runtime.Instance) HTMLScriptElementImpl.ScriptType {
        const type_attr = getAttribute(element, "type") orelse "";
        const lang_attr = getAttribute(element, "language") orelse "";

        var type_string: []const u8 = undefined;

        if (type_attr.len == 0) {
            if (lang_attr.len == 0) {
                type_string = "text/javascript";
            } else if (std.ascii.eqlIgnoreCase(lang_attr, "javascript")) {
                type_string = "text/javascript";
            } else {
                return .null;
            }
        } else {
            type_string = std.mem.trim(u8, type_attr, " \t\n\r\x0c");
        }

        if (isJavaScriptMimeType(type_string)) {
            return .classic;
        }

        if (std.ascii.eqlIgnoreCase(type_string, "module")) {
            return .module;
        }

        if (std.ascii.eqlIgnoreCase(type_string, "importmap")) {
            return .importmap;
        }

        return .null;
    }

    fn isJavaScriptMimeType(mime_type: []const u8) bool {
        var lower_buf: [64]u8 = undefined;
        const len = @min(mime_type.len, 64);
        for (0..len) |i| {
            lower_buf[i] = std.ascii.toLower(mime_type[i]);
        }
        const lower = lower_buf[0..len];

        const js_types = [_][]const u8{
            "application/ecmascript",
            "application/javascript",
            "text/ecmascript",
            "text/javascript",
        };

        for (js_types) |js_type| {
            if (std.mem.startsWith(u8, lower, js_type)) {
                if (lower.len == js_type.len or
                    (lower.len > js_type.len and lower[js_type.len] == ';'))
                {
                    return true;
                }
            }
        }

        return false;
    }
};

const script_execution = ScriptExecution;

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

/// Namespace enumeration matching the parser's namespace
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

    pub fn fromParserNamespace(ns: ParserNamespace) Namespace {
        return switch (ns) {
            .html => .html,
            .mathml => .mathml,
            .svg => .svg,
        };
    }
};

/// Parse an HTML string and return a DOM Document
///
/// This is the main entry point for parsing complete HTML documents.
/// Implements the HTML parsing algorithm from WHATWG HTML Standard §13.2.
///
/// Uses the full tokenizer (80 states) and tree builder (24 insertion modes)
/// to construct a TreeNode tree, then converts it to DOM nodes.
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
    // Step 1: Create tokenizer with input
    // The tokenizer handles input stream internally
    var tokenizer = Tokenizer.init(allocator, html);
    defer tokenizer.deinit();

    // Step 2: Create tree builder
    var tree_builder = TreeBuilder.init(allocator, &tokenizer) catch return error.OutOfMemory;
    defer tree_builder.deinit();

    // Configure tree builder
    tree_builder.scripting_enabled = options.scripting_enabled;

    // Step 4: Parse the document using full algorithm
    tree_builder.parse() catch return error.TreeBuilderError;

    // Step 5: Create DOM Document from parsed tree
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

        // Set quirks mode based on parser result
        switch (tree_builder.quirks_mode) {
            .quirks => {
                // Set quirks mode (full)
            },
            .limited_quirks => {
                // Set limited quirks mode
            },
            .no_quirks => {
                // Standards mode (default)
            },
        }
    }

    // Step 6: Convert TreeNode tree to DOM nodes
    try convertTreeNodeToDom(allocator, ctx, tree_builder.document, document, document);

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
    // Determine context element tag name for fragment parsing
    var context_tag: ?[]const u8 = null;
    if (context_element) |elem| {
        if (ElementImpl.getInternal(elem)) |elem_internal| {
            context_tag = elem_internal.local_name.asSlice();
        }
    }

    // Step 1: Create tokenizer with input
    var tokenizer = Tokenizer.init(allocator, html);
    defer tokenizer.deinit();

    // Step 2: Create tree builder for fragment parsing
    var tree_builder = TreeBuilder.init(allocator, &tokenizer) catch return error.OutOfMemory;
    defer tree_builder.deinit();

    // Step 4: Set up fragment parsing context
    // HTML Standard §13.4 "Parsing HTML fragments"
    if (context_tag) |tag| {
        // Set initial insertion mode based on context element
        tree_builder.insertion_mode = getFragmentInsertionMode(tag);

        // For certain elements, set tokenizer state
        if (std.mem.eql(u8, tag, "title") or std.mem.eql(u8, tag, "textarea")) {
            tokenizer.state = .rcdata;
        } else if (std.mem.eql(u8, tag, "style") or
            std.mem.eql(u8, tag, "xmp") or
            std.mem.eql(u8, tag, "iframe") or
            std.mem.eql(u8, tag, "noembed") or
            std.mem.eql(u8, tag, "noframes"))
        {
            tokenizer.state = .rawtext;
        } else if (std.mem.eql(u8, tag, "script")) {
            tokenizer.state = .script_data;
        } else if (std.mem.eql(u8, tag, "noscript")) {
            // Depends on scripting flag
            if (tree_builder.scripting_enabled) {
                tokenizer.state = .rawtext;
            }
        } else if (std.mem.eql(u8, tag, "plaintext")) {
            tokenizer.state = .plaintext;
        }
    }

    // Step 5: Parse the fragment using full algorithm
    tree_builder.parse() catch return error.TreeBuilderError;

    // Step 6: Create DocumentFragment
    const fragment = DocumentFragmentImpl.init(
        allocator,
        interfaces.DocumentFragment.State,
        &interfaces.DocumentFragment.vtable,
        ctx,
    ) catch return error.OutOfMemory;
    errdefer DocumentFragmentImpl.deinit(fragment);

    // Get owner document for node creation
    var owner_doc: ?*runtime.Instance = null;
    if (context_element) |elem| {
        owner_doc = NodeImpl.get_ownerDocument(elem) catch null;
    }

    // Step 7: Convert parsed children to DOM nodes
    // For fragments, we only want the children of the parsed document's body/html
    const parsed_root = tree_builder.document;

    // Find the relevant content (typically under html > body or just the children)
    var content_root = parsed_root;

    // If there's an html element, look for body
    if (parsed_root.first_child) |first| {
        if (first.hasTagName("html")) {
            // Look for body element
            var child = first.first_child;
            while (child) |c| {
                if (c.hasTagName("body")) {
                    content_root = c;
                    break;
                }
                child = c.next_sibling;
            }
        }
    }

    // Convert children of content_root to fragment
    var tree_child = content_root.first_child;
    while (tree_child) |tc| {
        const dom_node = try createDomNodeFromTreeNode(allocator, ctx, tc, owner_doc);
        _ = NodeImpl.appendChild(fragment, dom_node) catch return error.InvalidStateError;

        // Recursively convert children
        try convertChildrenToDom(allocator, ctx, tc, dom_node, owner_doc);

        tree_child = tc.next_sibling;
    }

    return fragment;
}

/// Determine initial insertion mode for fragment parsing based on context element
/// HTML Standard §13.4 step 4
fn getFragmentInsertionMode(context_tag: []const u8) InsertionMode {
    if (std.mem.eql(u8, context_tag, "title") or
        std.mem.eql(u8, context_tag, "textarea"))
    {
        return .text;
    } else if (std.mem.eql(u8, context_tag, "style") or
        std.mem.eql(u8, context_tag, "xmp") or
        std.mem.eql(u8, context_tag, "iframe") or
        std.mem.eql(u8, context_tag, "noembed") or
        std.mem.eql(u8, context_tag, "noframes"))
    {
        return .text;
    } else if (std.mem.eql(u8, context_tag, "script")) {
        return .text;
    } else if (std.mem.eql(u8, context_tag, "table")) {
        return .in_table;
    } else if (std.mem.eql(u8, context_tag, "caption")) {
        return .in_caption;
    } else if (std.mem.eql(u8, context_tag, "colgroup")) {
        return .in_column_group;
    } else if (std.mem.eql(u8, context_tag, "tbody") or
        std.mem.eql(u8, context_tag, "thead") or
        std.mem.eql(u8, context_tag, "tfoot"))
    {
        return .in_table_body;
    } else if (std.mem.eql(u8, context_tag, "tr")) {
        return .in_row;
    } else if (std.mem.eql(u8, context_tag, "td") or
        std.mem.eql(u8, context_tag, "th"))
    {
        return .in_cell;
    } else if (std.mem.eql(u8, context_tag, "select")) {
        return .in_select;
    } else if (std.mem.eql(u8, context_tag, "template")) {
        return .in_template;
    } else if (std.mem.eql(u8, context_tag, "html")) {
        return .before_head;
    } else if (std.mem.eql(u8, context_tag, "head")) {
        return .in_head;
    } else if (std.mem.eql(u8, context_tag, "body") or
        std.mem.eql(u8, context_tag, "frameset"))
    {
        return .in_body;
    }

    // Default: in_body
    return .in_body;
}

/// Convert a TreeNode tree to DOM nodes recursively
fn convertTreeNodeToDom(
    allocator: Allocator,
    ctx: runtime.Context,
    tree_node: *TreeNode,
    parent_dom: *runtime.Instance,
    owner_document: *runtime.Instance,
) ParseError!void {
    var child = tree_node.first_child;
    while (child) |tree_child| {
        const dom_node = try createDomNodeFromTreeNode(allocator, ctx, tree_child, owner_document);

        // Append to parent
        _ = NodeImpl.appendChild(parent_dom, dom_node) catch return error.InvalidStateError;

        // For document element, update document's documentElement pointer
        if (tree_child.node_type == .element and tree_child.hasTagName("html")) {
            if (DocumentImpl.getInternal(owner_document)) |doc_internal| {
                doc_internal.document_element = dom_node;
            }
        }

        // Recursively convert children
        try convertChildrenToDom(allocator, ctx, tree_child, dom_node, owner_document);

        // After converting a script element's children, prepare and potentially execute it
        if (tree_child.node_type == .element) {
            if (tree_child.local_name) |name| {
                if (std.mem.eql(u8, name, "script") and tree_child.namespace == .html) {
                    _ = script_execution.prepareScriptElement(allocator, dom_node) catch |err| {
                        std.debug.print("Script preparation error: {}\n", .{err});
                    };
                }
            }
        }

        child = tree_child.next_sibling;
    }
}

/// Convert children of a TreeNode to DOM nodes
fn convertChildrenToDom(
    allocator: Allocator,
    ctx: runtime.Context,
    tree_node: *TreeNode,
    parent_dom: *runtime.Instance,
    owner_document: ?*runtime.Instance,
) ParseError!void {
    var child = tree_node.first_child;
    while (child) |tree_child| {
        const dom_node = try createDomNodeFromTreeNode(allocator, ctx, tree_child, owner_document);

        // Append to parent
        _ = NodeImpl.appendChild(parent_dom, dom_node) catch return error.InvalidStateError;

        // Recursively convert children
        try convertChildrenToDom(allocator, ctx, tree_child, dom_node, owner_document);

        // After converting a script element's children, prepare and potentially execute it
        // This happens after the script's text content has been added
        if (tree_child.node_type == .element) {
            if (tree_child.local_name) |name| {
                if (std.mem.eql(u8, name, "script") and tree_child.namespace == .html) {
                    // Prepare the script element per HTML Standard §4.12.1.1
                    // This will execute inline classic scripts immediately
                    _ = script_execution.prepareScriptElement(allocator, dom_node) catch |err| {
                        // Script preparation error - log but don't fail parsing
                        std.debug.print("Script preparation error: {}\n", .{err});
                    };
                }
            }
        }

        child = tree_child.next_sibling;
    }
}

/// Create a single DOM node from a TreeNode
fn createDomNodeFromTreeNode(
    allocator: Allocator,
    ctx: runtime.Context,
    tree_node: *TreeNode,
    owner_document: ?*runtime.Instance,
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
    owner_document: ?*runtime.Instance,
) ParseError!*runtime.Instance {
    const local_name = tree_node.local_name orelse return error.InvalidStateError;

    // Check if this is a script element
    const is_script = std.mem.eql(u8, local_name, "script") and
        tree_node.namespace == .html;

    // Create the appropriate element type
    const element = if (is_script)
        HTMLScriptElementImpl.init(
            allocator,
            interfaces.HTMLScriptElement.State,
            &interfaces.HTMLScriptElement.vtable,
            ctx,
        ) catch return error.OutOfMemory
    else
        ElementImpl.init(
            allocator,
            interfaces.Element.State,
            &interfaces.Element.vtable,
            ctx,
        ) catch return error.OutOfMemory;
    errdefer if (is_script) HTMLScriptElementImpl.deinit(element) else ElementImpl.deinit(element);

    // Set node type
    NodeImpl.setNodeType(element, NodeImpl.NodeType.ELEMENT_NODE) catch return error.InvalidStateError;

    // Set local name
    ElementImpl.setLocalName(element, local_name) catch return error.InvalidStateError;

    // Set namespace
    const ns = Namespace.fromParserNamespace(tree_node.namespace);
    if (ns.toUri()) |ns_uri| {
        ElementImpl.setNamespaceURI(element, ns_uri) catch return error.InvalidStateError;
    }

    // Set owner document
    if (owner_document) |doc| {
        NodeImpl.setOwnerDocument(element, doc) catch return error.InvalidStateError;

        // For script elements, set parser_document (marks as parser-inserted)
        if (is_script) {
            HTMLScriptElementImpl.setParserDocument(element, doc);
            HTMLScriptElementImpl.clearForceAsync(element);
        }
    }

    // Add attributes
    const attrs = tree_node.attributes.toSlice();
    for (attrs) |attr| {
        // Create DOMStrings for the attribute name and value
        // Use initInterned since the TreeNode owns the strings and they'll outlive this call
        const name_str = runtime.DOMString.initInterned(attr.name);
        const value_str = runtime.DOMString.initInterned(attr.value);
        ElementImpl.call_setAttribute(element, name_str, value_str) catch continue;
    }

    return element;
}

/// Create a Text DOM node from a TreeNode
fn createTextNode(
    allocator: Allocator,
    ctx: runtime.Context,
    tree_node: *TreeNode,
    owner_document: ?*runtime.Instance,
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
    if (owner_document) |doc| {
        NodeImpl.setOwnerDocument(text, doc) catch return error.InvalidStateError;
    }

    return text;
}

/// Create a Comment DOM node from a TreeNode
fn createCommentNode(
    allocator: Allocator,
    ctx: runtime.Context,
    tree_node: *TreeNode,
    owner_document: ?*runtime.Instance,
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
    if (owner_document) |doc| {
        NodeImpl.setOwnerDocument(comment, doc) catch return error.InvalidStateError;
    }

    return comment;
}

/// Create a DocumentType DOM node from a TreeNode
fn createDoctypeNode(
    allocator: Allocator,
    ctx: runtime.Context,
    tree_node: *TreeNode,
    owner_document: ?*runtime.Instance,
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
    if (owner_document) |doc| {
        NodeImpl.setOwnerDocument(doctype, doc) catch return error.InvalidStateError;

        // Also set doctype reference on document
        if (DocumentImpl.getInternal(doc)) |doc_internal| {
            doc_internal.doctype = doctype;
        }
    }

    return doctype;
}

// =============================================================================
// Tests
// =============================================================================

test "HTMLParser - parse simple HTML document" {
    const allocator = std.testing.allocator;
    const ctx = runtime.Context{};

    const doc = try parseHTML(allocator, ctx, "<!DOCTYPE html><html><head></head><body>Hello</body></html>", .{});
    defer DocumentImpl.deinit(doc);

    // Verify document was created
    try std.testing.expect(doc != null);

    // Verify document element exists
    if (DocumentImpl.getInternal(doc)) |doc_internal| {
        try std.testing.expect(doc_internal.document_element != null);
        try std.testing.expect(doc_internal.doc_type == .html);
    }
}

test "HTMLParser - parse HTML with nested elements" {
    const allocator = std.testing.allocator;
    const ctx = runtime.Context{};

    const html =
        \\<!DOCTYPE html>
        \\<html>
        \\<head><title>Test</title></head>
        \\<body>
        \\  <div id="main">
        \\    <p>Paragraph 1</p>
        \\    <p>Paragraph 2</p>
        \\  </div>
        \\</body>
        \\</html>
    ;

    const doc = try parseHTML(allocator, ctx, html, .{});
    defer DocumentImpl.deinit(doc);

    try std.testing.expect(doc != null);
}

test "HTMLParser - parse fragment" {
    const allocator = std.testing.allocator;
    const ctx = runtime.Context{};

    const frag = try parseFragment(allocator, ctx, "<div>Hello</div><span>World</span>", null);
    defer DocumentFragmentImpl.deinit(frag);

    try std.testing.expect(frag != null);
}

test "HTMLParser - Namespace.fromParserNamespace" {
    try std.testing.expectEqual(Namespace.html, Namespace.fromParserNamespace(.html));
    try std.testing.expectEqual(Namespace.svg, Namespace.fromParserNamespace(.svg));
    try std.testing.expectEqual(Namespace.mathml, Namespace.fromParserNamespace(.mathml));
}

test "HTMLParser - getFragmentInsertionMode" {
    try std.testing.expectEqual(InsertionMode.in_table, getFragmentInsertionMode("table"));
    try std.testing.expectEqual(InsertionMode.in_row, getFragmentInsertionMode("tr"));
    try std.testing.expectEqual(InsertionMode.in_cell, getFragmentInsertionMode("td"));
    try std.testing.expectEqual(InsertionMode.in_body, getFragmentInsertionMode("div"));
    try std.testing.expectEqual(InsertionMode.in_body, getFragmentInsertionMode("body"));
    try std.testing.expectEqual(InsertionMode.in_head, getFragmentInsertionMode("head"));
    try std.testing.expectEqual(InsertionMode.in_select, getFragmentInsertionMode("select"));
}
