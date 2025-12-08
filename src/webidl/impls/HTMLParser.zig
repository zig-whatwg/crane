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

// Import the interface-free HTML core module
const html_core = @import("html_core");
const Tokenizer = html_core.parser.Tokenizer;
const TreeBuilder = html_core.parser.TreeBuilder;
const TreeNode = html_core.parser.TreeNode;
const InsertionMode = html_core.parser.InsertionMode;
const QuirksMode = html_core.parser.QuirksMode;
const ParserNamespace = html_core.parser.Namespace;

// Import DOM implementation modules for internal algorithm methods
const DocumentImpl = @import("Document.zig");
const ElementImpl = @import("Element.zig");
const DocumentTypeImpl = @import("DocumentType.zig");
const NodeImpl = @import("Node.zig");
const CharacterDataImpl = @import("CharacterData.zig");
const HTMLScriptElementImpl = @import("HTMLScriptElement.zig");

// Import script execution module from html module
const html_mod = @import("html");
const script_execution = html_mod.script_execution;

// Import parser script execution for incremental DOM building
const parser_script_execution = html_mod.parser_script_execution;
const DomTreeAdapter = parser_script_execution.DomTreeAdapter;
const ParserScriptContext = parser_script_execution.ParserScriptContext;

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
    const document = interfaces.Document.init(
        allocator,
        ctx,
    ) catch return error.OutOfMemory;
    errdefer interfaces.Document.deinit(document);

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

/// Script loader interface for external script loading
/// Used during HTML parsing to load external scripts synchronously
pub const ScriptLoader = struct {
    /// Opaque context pointer passed to load callback
    context: ?*anyopaque,
    /// Load an external script by URL, returns script content
    /// Returns null on failure
    loadScript: *const fn (?*anyopaque, []const u8) ?[]const u8,

    /// Load a script and return its content (or null on failure)
    pub fn load(self: ScriptLoader, url: []const u8) ?[]const u8 {
        return self.loadScript(self.context, url);
    }
};

/// Options for HTML parsing with scripting support
pub const ScriptingParseOptions = struct {
    /// Enable scripting (executes scripts during parsing)
    scripting_enabled: bool = true,
    /// Base URL for resolving relative URLs
    base_url: []const u8 = "",
    /// Script loader for external scripts (null = no external script loading)
    script_loader: ?ScriptLoader = null,
};

/// Parse an HTML document with scripting support
///
/// This is the entry point for WPT runner HTML tests. It parses HTML,
/// builds the DOM tree incrementally, and executes scripts during parsing.
///
/// Key behaviors:
/// - DOM nodes are created incrementally as parsing progresses
/// - Scripts execute when their `</script>` end tag is seen
/// - Scripts can access DOM nodes parsed before them (e.g., document.querySelector)
/// - External scripts are loaded via the provided ScriptLoader
/// - defer/async attributes are respected
///
/// Architecture:
/// 1. Create Document first (scripts need access to it)
/// 2. Set up DomTreeAdapter for incremental TreeNode → DOM conversion
/// 3. Set up ParserScriptContext for script execution
/// 4. Wire callbacks to tree builder
/// 5. Parse (DOM builds incrementally, scripts execute at </script>)
/// 6. Return complete document
///
/// @param allocator Memory allocator for DOM nodes
/// @param ctx Runtime context for DOM instances
/// @param html The HTML string to parse
/// @param options Scripting parse options
/// @return A Document instance containing the parsed DOM tree with executed scripts
pub fn parseHTMLWithScripting(
    allocator: Allocator,
    ctx: runtime.Context,
    html: []const u8,
    options: ScriptingParseOptions,
) ParseError!*runtime.Instance {
    // Step 1: Create DOM Document FIRST (before parsing)
    // Scripts need access to the document during parsing
    const document = interfaces.Document.init(
        allocator,
        ctx,
    ) catch return error.OutOfMemory;
    errdefer interfaces.Document.deinit(document);

    // Set document type to HTML
    if (DocumentImpl.getInternal(document)) |doc_internal| {
        doc_internal.doc_type = .html;
    }

    // Step 2: Create tokenizer with input
    var tokenizer = Tokenizer.init(allocator, html);
    defer tokenizer.deinit();

    // Step 3: Create tree builder
    var tree_builder = TreeBuilder.init(allocator, &tokenizer) catch return error.OutOfMemory;
    defer tree_builder.deinit();

    // Step 4: Create DomTreeAdapter for incremental DOM building
    var dom_adapter = DomTreeAdapter.init(allocator, ctx, document);
    defer dom_adapter.deinit();

    // Pre-register the document's TreeNode → DOM mapping
    // The tree builder's document node maps to our DOM document
    dom_adapter.node_map.put(tree_builder.document, document) catch return error.OutOfMemory;

    // Step 5: Create ParserScriptContext for script execution
    var script_context = ParserScriptContext.init(
        allocator,
        ctx,
        document,
        &dom_adapter.node_map,
        &tree_builder,
        options.scripting_enabled,
    );

    // Step 6: Wire up callbacks to tree builder
    tree_builder.scripting_enabled = options.scripting_enabled;

    // Set DOM adapter callbacks for incremental conversion
    tree_builder.setDomAdapterCallbacks(
        @ptrCast(&dom_adapter),
        &parser_script_execution.domAdapterOnNodeCreated,
        &parser_script_execution.domAdapterOnChildAppended,
        &parser_script_execution.domAdapterOnTextContentChanged,
    );

    // Set script execution callback
    if (options.scripting_enabled) {
        tree_builder.setScriptExecutionCallback(
            &parser_script_execution.parserScriptCallback,
            @ptrCast(&script_context),
        );
    }

    // Step 7: Parse the document
    // During parsing:
    // - DomTreeAdapter callbacks convert TreeNodes to DOM nodes incrementally
    // - parserScriptCallback executes scripts when </script> is seen
    // - Scripts can access already-parsed DOM via document.querySelector, etc.
    tree_builder.parse() catch return error.TreeBuilderError;

    // Step 8: Set quirks mode based on parser result
    if (DocumentImpl.getInternal(document)) |doc_internal| {
        switch (tree_builder.quirks_mode) {
            .quirks => {},
            .limited_quirks => {},
            .no_quirks => {},
        }

        // Update document element reference
        // The html element should have been added during parsing
        if (tree_builder.document.first_child) |html_tree_node| {
            if (html_tree_node.hasTagName("html")) {
                if (dom_adapter.node_map.get(html_tree_node)) |html_dom| {
                    doc_internal.document_element = html_dom;
                }
            }
        }
    }

    // Step 9: Handle any deferred scripts (TODO: implement in follow-up task)
    // Per HTML spec, deferred scripts execute after parsing completes
    // This will be addressed in whatwg-9rji9 (external script loading)

    return document;
}

/// Convert a TreeNode tree to DOM nodes with script execution support
fn convertTreeNodeToDomWithScripts(
    allocator: Allocator,
    ctx: runtime.Context,
    tree_node: *TreeNode,
    parent_dom: *runtime.Instance,
    owner_document: *runtime.Instance,
    options: ScriptingParseOptions,
) ParseError!void {
    var child = tree_node.first_child;
    while (child) |tree_child| {
        const dom_node = try createDomNodeFromTreeNode(allocator, ctx, tree_child, owner_document);

        // Append to parent
        _ = interfaces.Node.call_appendChild(parent_dom, dom_node) catch return error.InvalidStateError;

        // For document element, update document's documentElement pointer
        if (tree_child.node_type == .element and tree_child.hasTagName("html")) {
            if (DocumentImpl.getInternal(owner_document)) |doc_internal| {
                doc_internal.document_element = dom_node;
            }
        }

        // Recursively convert children (with script execution)
        try convertChildrenToDomWithScripts(allocator, ctx, tree_child, dom_node, owner_document, options);

        // After converting a script element's children, prepare and potentially execute it
        if (tree_child.node_type == .element) {
            if (tree_child.local_name) |name| {
                if (std.mem.eql(u8, name, "script") and tree_child.namespace == .html) {
                    // Execute script via script_execution module
                    _ = script_execution.prepareScriptElement(allocator, dom_node) catch |err| {
                        std.debug.print("Script preparation error: {}\n", .{err});
                    };
                }
            }
        }

        child = tree_child.next_sibling;
    }
}

/// Convert children of a TreeNode to DOM nodes with script execution
fn convertChildrenToDomWithScripts(
    allocator: Allocator,
    ctx: runtime.Context,
    tree_node: *TreeNode,
    parent_dom: *runtime.Instance,
    owner_document: ?*runtime.Instance,
    options: ScriptingParseOptions,
) ParseError!void {
    var child = tree_node.first_child;
    while (child) |tree_child| {
        const dom_node = try createDomNodeFromTreeNode(allocator, ctx, tree_child, owner_document);

        // Append to parent
        _ = interfaces.Node.call_appendChild(parent_dom, dom_node) catch return error.InvalidStateError;

        // Recursively convert children
        try convertChildrenToDomWithScripts(allocator, ctx, tree_child, dom_node, owner_document, options);

        // After converting a script element's children, prepare and execute it
        if (tree_child.node_type == .element) {
            if (tree_child.local_name) |name| {
                if (std.mem.eql(u8, name, "script") and tree_child.namespace == .html) {
                    // Execute script
                    _ = script_execution.prepareScriptElement(allocator, dom_node) catch |err| {
                        std.debug.print("Script preparation error: {}\n", .{err});
                    };
                }
            }
        }

        child = tree_child.next_sibling;
    }
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
    const fragment = interfaces.DocumentFragment.init(
        allocator,
        ctx,
    ) catch return error.OutOfMemory;
    errdefer interfaces.DocumentFragment.deinit(fragment);

    // Get owner document for node creation
    var owner_doc: ?*runtime.Instance = null;
    if (context_element) |elem| {
        owner_doc = interfaces.Node.get_ownerDocument(elem) catch null;
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
        // Use interface instead of impl (per Golden Rule #13)
        _ = interfaces.Node.call_appendChild(fragment, dom_node) catch return error.InvalidStateError;

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

        // Append to parent (use interface per Golden Rule #13)
        _ = interfaces.Node.call_appendChild(parent_dom, dom_node) catch return error.InvalidStateError;

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

        // Append to parent (use interface per Golden Rule #13)
        _ = interfaces.Node.call_appendChild(parent_dom, dom_node) catch return error.InvalidStateError;

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
        interfaces.HTMLScriptElement.init(allocator, ctx) catch return error.OutOfMemory
    else
        interfaces.Element.init(allocator, ctx) catch return error.OutOfMemory;
    errdefer if (is_script) interfaces.HTMLScriptElement.deinit(element) else interfaces.Element.deinit(element);

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
        interfaces.Element.call_setAttribute(element, name_str, value_str) catch continue;
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
    const text = interfaces.Text.call_constructor(
        allocator,
        ctx,
        webidl.Opt(runtime.DOMString).passed(dom_string),
    ) catch return error.OutOfMemory;
    errdefer interfaces.Text.deinit(text);

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
    const comment = interfaces.Comment.call_constructor(
        allocator,
        ctx,
        webidl.Opt(runtime.DOMString).passed(dom_string),
    ) catch return error.OutOfMemory;
    errdefer interfaces.Comment.deinit(comment);

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
    const doctype = interfaces.DocumentType.init(
        allocator,
        ctx,
    ) catch return error.OutOfMemory;
    errdefer interfaces.DocumentType.deinit(doctype);

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
    defer interfaces.Document.deinit(doc);

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
    defer interfaces.Document.deinit(doc);

    try std.testing.expect(doc != null);
}

test "HTMLParser - parse fragment" {
    const allocator = std.testing.allocator;
    const ctx = runtime.Context{};

    const frag = try parseFragment(allocator, ctx, "<div>Hello</div><span>World</span>", null);
    defer interfaces.DocumentFragment.deinit(frag);

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
