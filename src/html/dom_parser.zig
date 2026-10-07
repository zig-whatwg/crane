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
//! const HTMLParser = @import("html").dom_parser;
//!
//! // Parse HTML string into a Document
//! const doc = try HTMLParser.parseHTML(allocator, ctx, "<html><body>Hello</body></html>");
//!
//! // Parse HTML fragment into a DocumentFragment
//! const frag = try HTMLParser.parseFragment(allocator, ctx, "<div>content</div>", context_element);
//! ```

const std = @import("std");
const log = std.log.scoped(.html_parser);
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const infra = @import("infra");

// Import the interface-free HTML core module
const html_core = @import("html_core");
const Tokenizer = html_core.parser.Tokenizer;
const TreeBuilder = html_core.parser.TreeBuilder;
const TreeNode = html_core.parser.TreeNode;
const QuirksMode = html_core.parser.QuirksMode;
const ParserNamespace = html_core.parser.Namespace;

// Import DOM internals for document state access (Golden Rule #12 compliant)
const dom = @import("dom");
const document_internals = dom.document_internals;

// Import script execution module from html module
const html_mod = @import("full.zig");
const node_document = @import("dom").node_document;
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
    errdefer dom.node_creation.destroyUninserted(document);

    // Set document type to HTML
    document_internals.setDocumentType(document, .html) catch {};
    // A document parsed without a browsing context has disabled scripting;
    // serialization (notably noscript) consults this document state too.
    document_internals.setScriptingEnabled(document, options.scripting_enabled);

    // The document's mode, as the "initial" insertion mode set it. Nothing
    // runs script during this parse, so it can follow the parse.
    document_internals.setMode(document, parser_script_execution.documentMode(tree_builder.quirks_mode)) catch {};

    // Step 6: Convert TreeNode tree to DOM nodes
    try convertTreeNodeToDom(allocator, ctx, tree_builder.document, document, document);

    return document;
}

/// Type-safe script loader for external script loading.
///
/// This generic provides compile-time type safety for script loader implementations.
/// Use `makeTypedLoader` to create a typed wrapper function that can be used with
/// the legacy ScriptLoader interface while maintaining type safety in implementation.
///
/// ## Example Usage
///
/// ```zig
/// const BrowserContext = struct {
///     allocator: std.mem.Allocator,
///     // ...
/// };
///
/// // Type-safe loader implementation - no anyopaque casts needed!
/// fn loadScript(ctx: *BrowserContext, url: []const u8) ?[]const u8 {
///     if (std.mem.endsWith(u8, url, "special.js")) {
///         return ctx.allocator.dupe(u8, "// special") catch null;
///     }
///     return null;
/// }
///
/// // Create legacy-compatible wrapper
/// const typedLoader = TypedScriptLoader(BrowserContext).makeTypedLoader(loadScript);
///
/// // Use with ScriptLoader interface
/// const loader = ScriptLoader{
///     .context = &my_context,
///     .loadScript = typedLoader,
/// };
/// ```
pub fn TypedScriptLoader(comptime Context: type) type {
    return struct {
        /// Create a legacy-compatible wrapper function from a typed callback.
        ///
        /// The returned function pointer can be used with ScriptLoader.loadScript
        /// while the actual implementation receives a properly typed context.
        pub fn makeTypedLoader(
            comptime typedFn: *const fn (*Context, []const u8) ?[]const u8,
        ) *const fn (?*anyopaque, []const u8) ?[]const u8 {
            return struct {
                fn wrapper(ctx: ?*anyopaque, url: []const u8) ?[]const u8 {
                    const typed: *Context = @ptrCast(@alignCast(ctx orelse return null));
                    return typedFn(typed, url);
                }
            }.wrapper;
        }
    };
}

/// Script loader interface for external script loading
/// Used during HTML parsing to load external scripts synchronously
///
/// For type-safe loading, prefer TypedScriptLoader(Context) which provides
/// compile-time type checking. This legacy interface is kept for compatibility
/// and for cases where the context type cannot be known at compile time.
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
    /// Existing document to populate (null = create new document)
    /// When provided, the parser populates this document instead of creating a new one.
    /// This is critical for WPT runner: the document must be registered in V8 BEFORE
    /// parsing so that scripts executing during parsing can access DOM elements via
    /// document.getElementById(), document.querySelector(), etc.
    existing_document: ?*runtime.Instance = null,
    /// The input is the page's byte stream, decoded with the encoding HTML's
    /// encoding sniffing algorithm determines (see
    /// html.scripted_parser.ByteStream); null when it is characters.
    byte_stream: ?html_mod.scripted_parser.ByteStream = null,
};

/// Parse an HTML document with scripting support: the top-level page's parse.
///
/// The parse itself is html's `scripted_parser` - the one parser every
/// document with scripting uses, with the input stream document.write()
/// inserts into. This adds what is the top-level page's own: an existing
/// document (registered in V8 before parsing, so the page's scripts see it) is
/// emptied first, the embedder's script loader is used for external scripts,
/// and "the end" runs when the parser has stopped.
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
    // The document: the one navigation already registered in V8, so the
    // page's scripts see it - emptied of a previous run's tree - or a new one.
    if (options.existing_document) |existing| {
        document_internals.clearChildren(existing);
    }

    // The parse: html_mod.scripted_parser is the one parser every document
    // with scripting uses - this page's, a frame's, a script-created one's -
    // with its input stream for document.write().
    const document = html_mod.scripted_parser.parseHTMLWithScripting(allocator, ctx, html, .{
        .scripting_enabled = options.scripting_enabled,
        .document = options.existing_document,
        .script_loader = if (options.script_loader) |loader| .{
            .context = loader.context,
            .loadScript = loader.loadScript,
        } else null,
        .base_url = options.base_url,
        .byte_stream = options.byte_stream,
    }) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.InvalidStateError => error.InvalidStateError,
        error.TokenizerError => error.TokenizerError,
        error.TreeBuilderError => error.TreeBuilderError,
        error.InvalidInput => error.InvalidInput,
    };

    // HTML §13.2.7 "the end" step 3: the parser has stopped - readiness
    // "interactive", before the deferred scripts, which see it.
    @import("dom").document_lifecycle.parsingStopped(document);

    // Step 5: the scripts that execute when the document has finished parsing.
    if (options.scripting_enabled) {
        script_execution.executeScriptsWhenParsingFinished(allocator, document);
    }

    // Steps 6 and 9: DOMContentLoaded, then readiness "complete", load at the
    // window and pageshow - each queued as the task the spec makes it.
    @import("dom").document_lifecycle.finishLoading(document);

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
    // The context element's local name and namespace. Its HTML-specific
    // steps below - the tokenizer state, the insertion mode - are for an
    // element in the HTML namespace; a foreign context (innerHTML on an svg
    // element) is the parser's adjusted current node instead.
    var local_name: ?runtime.DOMString = null;
    defer if (local_name) |*name| name.deinit(ctx.allocator);
    var namespace: ?runtime.DOMString = null;
    defer if (namespace) |*name| name.deinit(ctx.allocator);
    var encoding_owned: ?runtime.DOMString = null;
    defer if (encoding_owned) |*value| value.deinit(ctx.allocator);
    var context_namespace: ParserNamespace = .html;
    if (context_element) |elem| {
        local_name = interfaces.Element.get_localName(elem) catch return error.InvalidStateError;
        namespace = interfaces.Element.get_namespaceURI(elem) catch return error.InvalidStateError;
        encoding_owned = interfaces.Element.call_getAttribute(elem, runtime.DOMString.initInterned("encoding")) catch return error.InvalidStateError;
        if (namespace) |ns| {
            if (std.mem.eql(u8, ns.asSlice(), "http://www.w3.org/2000/svg")) context_namespace = .svg;
            if (std.mem.eql(u8, ns.asSlice(), "http://www.w3.org/1998/Math/MathML")) context_namespace = .mathml;
        }
    }
    const context_tag: ?[]const u8 = if (local_name) |name| name.asSlice() else null;
    const context_encoding: ?[]const u8 = if (encoding_owned) |value| value.asSlice() else null;

    // Step 1: Create tokenizer with input
    var tokenizer = Tokenizer.init(allocator, html);
    defer tokenizer.deinit();

    // Step 2: Create tree builder for fragment parsing
    var tree_builder = TreeBuilder.init(allocator, &tokenizer) catch return error.OutOfMemory;
    defer tree_builder.deinit();

    // HTML Standard §13.4 "Parsing HTML fragments"
    // Step 7: Create a root html element and append to document
    const root = TreeNode.initElement(allocator, "html", .html) catch return error.OutOfMemory;
    tree_builder.document.appendChild(root);

    // Step 9: Set up stack of open elements with just the root element
    tree_builder.open_elements.append(root) catch return error.OutOfMemory;

    // "The adjusted current node is the context element if the parser was
    // created as part of the HTML fragment parsing algorithm and the stack of
    // open elements has only one element in it" - the tree builder asks it
    // for foreign content, so it gets the context's name, namespace and (for
    // annotation-xml) encoding.
    const context_node: ?*TreeNode = if (context_tag) |tag| blk: {
        const node = TreeNode.initElement(allocator, tag, context_namespace) catch return error.OutOfMemory;
        if (context_encoding) |encoding| node.addAttribute("encoding", encoding, null) catch {
            node.deinit();
            return error.OutOfMemory;
        };
        break :blk node;
    } else null;
    defer if (context_node) |node| node.deinit();
    tree_builder.fragment_context = context_node;

    // Steps 2-3: the fragment's document takes the mode of the context
    // element's node document - quirks, or limited-quirks - which the tree
    // builder reads for its mode-dependent rules.
    if (context_element) |elem| {
        if (interfaces.Node.get_ownerDocument(elem) catch null) |context_document| {
            // Fragment parsing steps 10–11: inherit disabled scripting.
            tree_builder.scripting_enabled = document_internals.isScriptingEnabled(context_document) and
                (interfaces.Document.get_defaultView(context_document) catch null) != null;
            if (document_internals.getMode(context_document)) |mode| tree_builder.quirks_mode = switch (mode) {
                .no_quirks => .no_quirks,
                .quirks => .quirks,
                .limited_quirks => .limited_quirks,
            };
        }
    }

    // Step 4: Set up fragment parsing context
    if (context_namespace != .html) {
        tree_builder.insertion_mode = .in_body;
    } else if (context_tag) |tag| {
        // HTML fragment parsing step 18.
        if (std.mem.eql(u8, tag, "template")) tree_builder.template_insertion_modes.append(.in_template) catch return error.OutOfMemory;

        // Step 6: For certain elements, set tokenizer state
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
    } else {
        // No context element - use in_body mode with root on stack
        tree_builder.insertion_mode = .in_body;
    }

    // Fragment steps 20–21. The context is the last node for reset purposes;
    // the ancestor form is only a pointer, not an entry on the open stack.
    if (context_node != null) tree_builder.resetInsertionModeAppropriately();
    var form_context: ?*TreeNode = null;
    defer if (form_context) |form| form.deinit();
    var ancestor = context_element;
    while (ancestor) |element| : (ancestor = interfaces.Node.get_parentElement(element) catch null) {
        if (element.stateAs(interfaces.HTMLFormElement.State) != null) {
            const form = TreeNode.initElement(allocator, "form", .html) catch return error.OutOfMemory;
            form_context = form;
            tree_builder.form_element = form;
            break;
        }
    }

    // Steps 22–23: Parse the fragment using the full algorithm.
    tree_builder.parse() catch return error.TreeBuilderError;

    // Step 6: Create DocumentFragment
    const fragment = interfaces.DocumentFragment.init(
        allocator,
        ctx,
    ) catch return error.OutOfMemory;
    errdefer dom.node_creation.destroyUninserted(fragment);

    // Get owner document for node creation
    var owner_doc: ?*runtime.Instance = null;
    if (context_element) |elem| {
        owner_doc = interfaces.Node.get_ownerDocument(elem) catch null;
    }

    if (owner_doc) |doc| node_document.set(fragment, doc) catch return error.InvalidStateError;

    // Step 16 (per HTML Standard §13.4): Return the children of root
    // The root element is the html element we created earlier
    const parsed_root = tree_builder.document;

    // Find the root html element - it should be the first child of document
    const root_element = parsed_root.first_child orelse return fragment;

    // Convert children of the root (html) element to fragment
    // Per spec, we return children of root, not the root itself
    var tree_child = root_element.first_child;
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
            document_internals.setDocumentElement(owner_document, dom_node);
        }

        // Recursively convert children
        try convertChildrenToDom(allocator, ctx, tree_child, dom_node, owner_document);

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
    const target = dom.template_contents.insertionTarget(parent_dom) catch return error.InvalidStateError;
    const document = (interfaces.Node.get_ownerDocument(target) catch null) orelse owner_document;
    var child = tree_node.first_child;
    while (child) |tree_child| {
        const dom_node = try createDomNodeFromTreeNode(allocator, ctx, tree_child, document);
        _ = interfaces.Node.call_appendChild(target, dom_node) catch {
            dom.node_creation.destroyUninserted(dom_node);
            return error.InvalidStateError;
        };
        try convertChildrenToDom(allocator, ctx, tree_child, dom_node, document);
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

    // Check if this is a script element: HTML's, or an SVG script.
    const is_script = std.mem.eql(u8, local_name, "script") and
        (tree_node.namespace == .html or tree_node.namespace == .svg);

    // Create the element with the interface its local name and namespace call
    // for - HTML "create an element for a token" looks the element interface
    // up exactly as `createElement` does. This path serves innerHTML,
    // outerHTML, insertAdjacentHTML and document.write, and it used to make
    // every non-script element a plain Element: `div.innerHTML = "<iframe>"`
    // produced an Element answering to `getElementsByTagName("iframe")`, and
    // the first caller that trusted the tag name and read HTMLIFrameElement
    // state out of it (the page load's iframe initialisation) faulted on
    // whatever bytes happened to sit where that state should be.
    // `parser_script_execution.createHTMLElement` is the factory the document
    // parser's adapter already uses, so both parsers now agree.
    const element = if (tree_node.namespace == .html)
        parser_script_execution.createHTMLElement(allocator, ctx, local_name) catch return error.OutOfMemory
    else
        parser_script_execution.createForeignElement(allocator, ctx, tree_node.namespace, local_name) catch return error.OutOfMemory;
    // Whatever interface it got, an element that never made it into the tree
    // is released through its own vtable.
    errdefer dom.node_creation.destroyUninserted(element);
    // Names are parser input: the creation hook does not apply script's
    // createElementNS validation a second time.
    const ns = Namespace.fromParserNamespace(tree_node.namespace);
    dom.node_creation.setElementNames(element, ns.toUri(), local_name) catch return error.InvalidStateError;

    // Set owner document
    if (owner_document) |doc| {
        node_document.set(element, doc) catch return error.InvalidStateError;

        // "in head", a start tag whose tag name is "script", step 4: the
        // element's parser document and force async - and "if the parser was
        // created as part of the HTML fragment parsing algorithm, then set the
        // script element's already started to true". This conversion serves
        // the fragment parser (innerHTML, outerHTML) and DOMParser, whose
        // document has scripting disabled - where "prepare the script
        // element" sets already started (step 15) before it returns at step
        // 18 - so every script made here is already started: none ever runs,
        // however it is later inserted, moved or cloned.
        if (is_script) dom.script_elements.markParserInserted(element, doc);
    }
    if (is_script) dom.script_elements.markAlreadyStarted(element);

    // "Append each attribute in the given token to element."
    for (tree_node.attributes.toSlice()) |attr| parser_script_execution.appendParsedAttribute(element, attr);

    return element;
}

/// Create a Text DOM node from a TreeNode
fn createTextNode(
    _: Allocator,
    ctx: runtime.Context,
    tree_node: *TreeNode,
    owner_document: ?*runtime.Instance,
) ParseError!*runtime.Instance {
    const text_data = tree_node.text_content.toSlice();

    // Create Text node using constructor
    const dom_string = runtime.DOMString.initInterned(text_data);
    const text = interfaces.Text.call_constructor(
        ctx,
        webidl.Opt(runtime.DOMString).passed(dom_string),
    ) catch return error.OutOfMemory;
    errdefer dom.node_creation.destroyUninserted(text);

    // Set owner document
    if (owner_document) |doc| {
        node_document.set(text, doc) catch return error.InvalidStateError;
    }

    return text;
}

/// Create a Comment DOM node from a TreeNode
fn createCommentNode(
    _: Allocator,
    ctx: runtime.Context,
    tree_node: *TreeNode,
    owner_document: ?*runtime.Instance,
) ParseError!*runtime.Instance {
    const comment_data = tree_node.text_content.toSlice();

    // Create Comment node
    const dom_string = runtime.DOMString.initInterned(comment_data);
    const comment = interfaces.Comment.call_constructor(
        ctx,
        webidl.Opt(runtime.DOMString).passed(dom_string),
    ) catch return error.OutOfMemory;
    errdefer dom.node_creation.destroyUninserted(comment);

    // Set owner document
    if (owner_document) |doc| {
        node_document.set(comment, doc) catch return error.InvalidStateError;
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
    errdefer dom.node_creation.destroyUninserted(doctype);

    dom.node_creation.setDoctypeIds(doctype, tree_node.doctype_name, tree_node.doctype_public_id, tree_node.doctype_system_id);

    // Set owner document
    if (owner_document) |doc| {
        node_document.set(doctype, doc) catch return error.InvalidStateError;

        // Also set doctype reference on document
        document_internals.setDoctype(doc, doctype);
    }

    return doctype;
}

// =============================================================================
// DOMContentLoaded Event Firing
// =============================================================================

// =============================================================================
// Tests
// =============================================================================

test "HTMLParser - Namespace.fromParserNamespace" {
    try std.testing.expectEqual(Namespace.html, Namespace.fromParserNamespace(.html));
    try std.testing.expectEqual(Namespace.svg, Namespace.fromParserNamespace(.svg));
    try std.testing.expectEqual(Namespace.mathml, Namespace.fromParserNamespace(.mathml));
}
