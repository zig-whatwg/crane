//! Parser Script Execution Callback
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#script-processing-model
//! HTML Standard §13.2.6.4.7 "The rules for parsing tokens in HTML content"
//!
//! This module provides the bridge between the HTML tree builder's script execution
//! callback and actual V8 script execution during parsing.
//!
//! When the tree builder encounters a `</script>` end tag, it invokes the registered
//! callback with the script TreeNode. This module converts that TreeNode to a DOM
//! HTMLScriptElement (via the DomAdapter mapping) and executes it via V8.
//!
//! ## Architecture
//!
//! ```
//! TreeBuilder --[callback]--> ParserScriptContext --[via DomAdapter]--> DOM HTMLScriptElement
//!                                                  |
//!                                                  v
//!                                            V8 Script Execution
//! ```

const std = @import("std");

const log = std.log.scoped(.parser_script_execution);
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const infra = @import("infra");

// HTML parser types
const html_core = @import("html_core");
const TreeBuilder = html_core.parser.TreeBuilder;
const TreeNode = html_core.parser.TreeNode;
const Tokenizer = html_core.parser.Tokenizer;
const Namespace = html_core.parser.Namespace;

// Script execution
const script_execution = @import("script_execution.zig");

// DOM internals for document_element setting
const dom = @import("dom");
const node_document = @import("dom").node_document;
const document_internals = dom.document_internals;

/// Script loader function type for external scripts.
/// Takes a context pointer and URL, returns script content or null on failure.
pub const ScriptLoaderFn = *const fn (?*anyopaque, []const u8) ?[]const u8;

/// Context for parser script execution callback.
///
/// This struct holds all state needed to execute scripts during parsing.
/// It is passed as the context pointer to the tree builder's script execution callback.
pub const ParserScriptContext = struct {
    /// Memory allocator for script-related allocations.
    allocator: Allocator,

    /// Runtime context for DOM instances.
    ctx: runtime.Context,

    /// The document being parsed.
    document: *runtime.Instance,

    /// Mapping from TreeNode pointers to DOM Element instances.
    /// This is populated by the DomTreeAdapter during incremental DOM conversion.
    tree_node_to_dom_map: *std.AutoHashMap(*TreeNode, *runtime.Instance),

    /// Reference to the tree builder for insertion point management.
    tree_builder: *TreeBuilder,

    /// Whether scripting is enabled for this document.
    scripting_enabled: bool,

    /// Base URL for resolving relative script URLs.
    base_url: []const u8 = "",

    /// Optional script loader for external scripts.
    script_loader_fn: ?ScriptLoaderFn = null,
    script_loader_ctx: ?*anyopaque = null,

    /// Create a new parser script context.
    pub fn init(
        allocator: Allocator,
        ctx: runtime.Context,
        document: *runtime.Instance,
        tree_node_to_dom_map: *std.AutoHashMap(*TreeNode, *runtime.Instance),
        tree_builder: *TreeBuilder,
        scripting_enabled: bool,
    ) ParserScriptContext {
        return .{
            .allocator = allocator,
            .ctx = ctx,
            .document = document,
            .tree_node_to_dom_map = tree_node_to_dom_map,
            .tree_builder = tree_builder,
            .scripting_enabled = scripting_enabled,
        };
    }

    /// Set the base URL for resolving relative script URLs.
    pub fn setBaseUrl(self: *ParserScriptContext, base_url: []const u8) void {
        self.base_url = base_url;
    }

    /// Set the script loader for external scripts.
    pub fn setScriptLoader(self: *ParserScriptContext, loader_fn: ScriptLoaderFn, loader_ctx: ?*anyopaque) void {
        self.script_loader_fn = loader_fn;
        self.script_loader_ctx = loader_ctx;
    }

    /// Get the DOM element for a TreeNode (if it has been converted).
    pub fn getDomElement(self: *const ParserScriptContext, tree_node: *TreeNode) ?*runtime.Instance {
        return self.tree_node_to_dom_map.get(tree_node);
    }
};

/// The tree builder's script callback: what the parser does at a script's
/// end tag, between the steps that raise and lower its script nesting level.
///
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#scriptEndTag
/// "An end tag whose tag name is "script"": ... "prepare the script element".
/// ... "At this stage, if the pending parsing-blocking script is not null,
/// then: if the script nesting level is not zero, set the parser pause flag to
/// true, and abort the processing of any nested invocations of the tokenizer;
/// otherwise run the pending parsing-blocking script" - see
/// `runPendingParsingBlockingScripts`.
/// And, for an SVG script (the "in foreign content" end tag): "process the SVG
/// script element".
pub fn parserScriptCallback(script_tree_node: *TreeNode, context: ?*anyopaque) void {
    const ctx: *ParserScriptContext = @ptrCast(@alignCast(context orelse return));
    if (!ctx.scripting_enabled) return;

    const script_element = ctx.getDomElement(script_tree_node) orelse return;

    // Trusted Types 4.1.2.6: "Set script's script text value to its child
    // text content" - before preparing it, for an HTML script and (as the
    // spec asks of implementations) an SVG one.
    dom.script_elements.setScriptTextToChildTextContent(ctx.allocator, script_element) catch {};

    if (isSvgScript(script_tree_node)) {
        script_execution.processSvgScriptElement(ctx.allocator, script_element);
        return;
    }

    // The embedder's loader, when it has one, is what "prepare the script
    // element" fetches a parser-inserted classic script's src with (the WPT
    // runner has one, to keep testharness.js from loading twice) - at its
    // fetch step, so only a script it would fetch anyway is loaded. What the
    // loader returns is used as-is, EMPTY included (an empty script still
    // runs and fires load); null is a network error, which executing the
    // element turns into the error event.
    const loader: ?script_execution.ParserScriptLoader = if (ctx.script_loader_fn != null) .{
        .context = ctx,
        .load = &loadForPrepare,
        .allocator = ctx.allocator,
    } else null;
    _ = script_execution.prepareScriptElementWithLoader(ctx.allocator, script_element, loader) catch {};

    runPendingParsingBlockingScripts(ctx);
}

/// `ParserScriptLoader.load` for a ParserScriptContext: its embedder's
/// loader. Null - the loader has no answer - leaves the fetch to "fetch a
/// classic script", which builds the request the spec's way.
fn loadForPrepare(context: ?*anyopaque, src: []const u8) ?[]const u8 {
    const ctx: *ParserScriptContext = @ptrCast(@alignCast(context orelse return null));
    const loader_fn = ctx.script_loader_fn orelse return null;
    return loader_fn(ctx.script_loader_ctx, src);
}

/// The script end-tag steps' pending parsing-blocking script handling.
///
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#scriptEndTag
/// "If the script nesting level is not zero: Set the parser pause flag to
///  true, and abort the processing of any nested invocations of the tokenizer,
///  yielding control back to the caller." - a script document.write()
///  inserted waits for the script that wrote it to finish. "Otherwise: While
///  the pending parsing-blocking script is not null: ... Let the insertion
///  point be just before the next input character. Increment the parser's
///  script nesting level by one. ... Execute the script element the script.
///  Decrement the parser's script nesting level by one. If the parser's script
///  nesting level is zero (which it always should be at this point), then set
///  the parser pause flag to false. Let the insertion point be undefined
///  again."
///
/// This runs inside the end-tag steps, before they lower the nesting level
/// they raised - so the spec's "not zero" is more than one here, and the level
/// the loop sets (one) is the one already in effect. The insertion point is
/// set again for each script: the pending script may be one a nested write
/// inserted, whose end tag the tokenizer has passed, and the characters
/// written after it wait just after the tokenizer - where the script's own
/// document.write() must insert (document-write/script_013). The end-tag
/// steps restore the old insertion point after this returns.
fn runPendingParsingBlockingScripts(ctx: *ParserScriptContext) void {
    if (script_execution.pendingParsingBlockingScript(ctx.document) == null) return;
    if (ctx.tree_builder.script_nesting_level > 1) {
        ctx.tree_builder.parser_pause_flag = true;
        return;
    }
    while (true) {
        if (ctx.tree_builder.input_stream_manager) |stream| stream.setInsertionPointAtNextInputCharacter();
        if (!script_execution.executePendingParserBlockingScript(ctx.allocator, ctx.document)) break;
        ctx.tree_builder.parser_pause_flag = false;
    }
}

// =============================================================================
// Attributes from the parser
// =============================================================================

/// "Create an element for the token" step: "Append each attribute in the
/// given token to element" - DOM "append an attribute", with the namespace
/// and prefix "adjust foreign attributes" gave it, and no validation: an
/// attribute name the tokenizer produced is one the element holds, whether or
/// not setAttribute() would accept it (`<div a"b>`), and an `xlink:href` on
/// SVG is the attribute `href` in the XLink namespace, which setAttribute()
/// could not make.
///
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#create-an-element-for-the-token
pub fn appendParsedAttribute(element: *runtime.Instance, attr: html_core.parser.TreeNode.Attribute) void {
    dom.element_attributes.append(element, .{
        .namespace = if (attr.namespace) |ns| ns.uri() else null,
        .prefix = attr.prefix,
        .local_name = attr.name,
        .value = attr.value,
    }) catch |err| log.debug("parser attribute {s} not appended: {}", .{ attr.name, err });
}

/// The SVG script end-tag step's "process the SVG script element", or the
/// HTML script callback: which one `tree_node` is.
pub fn isSvgScript(tree_node: *const TreeNode) bool {
    return tree_node.namespace == .svg and tree_node.hasTagName("script");
}

// =============================================================================
// Static Callback Wrappers for Tree Builder Integration
// =============================================================================

/// Static callback wrapper for onNodeCreated.
/// This is passed to tree_builder.setDomAdapterCallbacks().
pub fn domAdapterOnNodeCreated(tree_node: *TreeNode, context: ?*anyopaque) void {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    adapter.onNodeCreated(tree_node) catch {};
}

/// Static callback wrapper for onChildAppended.
/// This is passed to tree_builder.setDomAdapterCallbacks().
pub fn domAdapterOnChildAppended(parent: *TreeNode, child: *TreeNode, context: ?*anyopaque) void {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    adapter.onChildAppended(parent, child) catch {};
}

/// Static callback wrapper for onTextContentChanged.
/// This is passed to tree_builder.setDomAdapterCallbacks().
pub fn domAdapterOnTextContentChanged(tree_node: *TreeNode, context: ?*anyopaque) void {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    adapter.onTextContentChanged(tree_node) catch {};
}

/// Static callback wrapper for an attribute added to an element the adapter
/// already made. Passed to tree_builder.setDomAdapterAttributeCallback().
pub fn domAdapterOnAttributeAdded(tree_node: *TreeNode, attr: *const TreeNode.Attribute, context: ?*anyopaque) void {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    const element = adapter.node_map.get(tree_node) orelse return;
    appendParsedAttribute(element, attr.*);
}

/// Static callback wrapper for the document mode the parser set: the Document
/// takes it. Passed to tree_builder.setDomAdapterModeCallback().
pub fn domAdapterOnModeSet(mode: html_core.parser.QuirksMode, context: ?*anyopaque) void {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    document_internals.setMode(adapter.document, documentMode(mode)) catch {};
}

/// Static callback wrapper for an element the "text" insertion mode popped:
/// a style element's style block updates now ("The element is popped off
/// the stack of open elements of an HTML parser"). Passed to
/// tree_builder.setDomAdapterPoppedCallback().
pub fn domAdapterOnElementPopped(tree_node: *TreeNode, context: ?*anyopaque) void {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    if (!tree_node.hasTagName("style")) return;
    const element = adapter.node_map.get(tree_node) orelse return;
    dom.style_sheet_owners.poppedByParser(element);
}

/// The DOM document mode for the parser's.
pub fn documentMode(mode: html_core.parser.QuirksMode) document_internals.Mode {
    return switch (mode) {
        .no_quirks => .no_quirks,
        .quirks => .quirks,
        .limited_quirks => .limited_quirks,
    };
}

// =============================================================================
// DomTreeAdapter Integration
// =============================================================================

/// DomTreeAdapter provides incremental TreeNode to DOM conversion during parsing.
///
/// This adapter is called by the tree builder as nodes are created and modified,
/// allowing scripts to access DOM elements that have already been parsed.
pub const DomTreeAdapter = struct {
    allocator: Allocator,
    ctx: runtime.Context,
    document: *runtime.Instance,

    /// Mapping from TreeNode pointers to DOM Element instances.
    node_map: std.AutoHashMap(*TreeNode, *runtime.Instance),

    /// The DOM nodes this adapter created and has not yet seen attached to the
    /// tree - the only ones it may free in `deinit`.
    ///
    /// A node is added on creation and dropped the moment `appendChild` succeeds,
    /// because from then on it is V8's: the wrapper cache holds it and a weak
    /// callback can return its Instance handle to the slab at any time. A pointer
    /// to an attached node is therefore not safe to dereference later, let alone
    /// deinit. An unattached node is unreachable from script, so nothing can have
    /// wrapped or collected it and its pointer stays valid until we free it here.
    unattached_nodes: std.AutoHashMap(*runtime.Instance, void),

    pub fn init(
        allocator: Allocator,
        ctx: runtime.Context,
        document: *runtime.Instance,
    ) DomTreeAdapter {
        return .{
            .allocator = allocator,
            .ctx = ctx,
            .document = document,
            .node_map = std.AutoHashMap(*TreeNode, *runtime.Instance).init(allocator),
            .unattached_nodes = std.AutoHashMap(*runtime.Instance, void).init(allocator),
        };
    }

    pub fn deinit(self: *DomTreeAdapter) void {
        // Free the DOM nodes this adapter created and never managed to attach.
        //
        // onNodeCreated creates a DOM node before the tree builder knows where it
        // goes; onChildAppended attaches it. If appendChild fails (errors here are
        // swallowed) or onChildAppended never runs for that node, nothing else will
        // ever free it - attached nodes are freed by Document.deinit's tree walk.
        //
        // This iterates `unattached_nodes`, NOT `node_map`. node_map keeps an entry
        // for every node the parser ever created, including the ones it attached,
        // and an attached node belongs to V8: `Node.deinit` on an orphaned ancestor
        // frees its whole subtree, a script can detach a node and drop it, and
        // either way a weak callback returns the Instance handle to the slab, where
        // the next allocation takes the address over. Deciding ownership from a
        // reread of `getParent(dom_node)` therefore dereferenced pointers V8 had
        // already recycled: on a large document the recycled slot belonged to a
        // node of some other context, and markInstanceCleanedUp panicked with
        // "incorrect alignment" reading its wrapper cache. `unattached_nodes` only
        // ever holds nodes that no wrapper and no script can reach, so every
        // pointer in it is still ours.
        var it = self.unattached_nodes.keyIterator();
        while (it.next()) |key| {
            const dom_node = key.*;

            // The document is created and freed by the caller, never by us.
            if (dom_node == self.document) continue;

            // Belt: a node that somehow acquired a parent without going through
            // onChildAppended is attached, whatever this map says.
            const parent = interfaces.Node.get_parentNode(dom_node) catch null;
            if (parent == null) dom.node_creation.destroyUninserted(dom_node);
        }

        self.unattached_nodes.deinit();
        self.node_map.deinit();
    }

    /// Called when a new node is created during parsing.
    /// Creates the corresponding DOM node and adds it to the map.
    pub fn onNodeCreated(self: *DomTreeAdapter, tree_node: *TreeNode) !void {
        const dom_node = try self.createDomNode(tree_node);

        // Record ownership BEFORE publishing the node, so a failing put below
        // still leaves the node on the list `deinit` frees. Note that node_map is
        // keyed by TreeNode and a second create for the same TreeNode overwrites
        // it - `unattached_nodes` is keyed by instance and keeps both.
        if (dom_node != self.document) {
            try self.unattached_nodes.put(dom_node, {});
        }
        try self.node_map.put(tree_node, dom_node);
    }

    /// Called when a child is appended to a parent during parsing.
    /// Updates the DOM tree structure.
    /// When appending <html> to document, also sets document.documentElement.
    pub fn onChildAppended(self: *DomTreeAdapter, parent: *TreeNode, child: *TreeNode) !void {
        const parent_dom = self.node_map.get(parent) orelse return;
        const child_dom = self.node_map.get(child) orelse return;

        // Hand the child over to V8 only if it really was attached: a failed
        // append leaves it orphaned and still ours to free.
        if (interfaces.Node.call_appendChild(parent_dom, child_dom)) |_| {
            _ = self.unattached_nodes.remove(child_dom);
        } else |_| {}

        // CRITICAL: If appending <html> to document, set documentElement
        // Per DOM spec, documentElement is the first Element child of the Document
        if (parent.node_type == .document and child.node_type == .element) {
            if (child.local_name) |name| {
                if (std.mem.eql(u8, name, "html") and child.namespace == .html) {
                    document_internals.setDocumentElement(self.document, child_dom);
                }
            }
        }
    }

    /// Called when a node's text content changes during parsing.
    pub fn onTextContentChanged(self: *DomTreeAdapter, tree_node: *TreeNode) !void {
        const dom_node = self.node_map.get(tree_node) orelse return;

        // Update the DOM node's text content
        const text_content = tree_node.text_content.toSlice();
        const dom_string = runtime.DOMString.initInterned(text_content);

        // For Text nodes, update via CharacterData interface
        interfaces.CharacterData.set_data(dom_node, dom_string) catch {};
    }

    /// Get the DOM element for a TreeNode.
    pub fn getDomNode(self: *const DomTreeAdapter, tree_node: *TreeNode) ?*runtime.Instance {
        return self.node_map.get(tree_node);
    }

    /// Create a DOM node from a TreeNode.
    fn createDomNode(self: *DomTreeAdapter, tree_node: *TreeNode) !*runtime.Instance {
        return switch (tree_node.node_type) {
            .element => try self.createElementNode(tree_node),
            .text => try self.createTextNode(tree_node),
            .comment => try self.createCommentNode(tree_node),
            .doctype => try self.createDoctypeNode(tree_node),
            .document => self.document, // Document already exists
        };
    }

    fn createElementNode(self: *DomTreeAdapter, tree_node: *TreeNode) !*runtime.Instance {
        const local_name = tree_node.local_name orelse return error.InvalidStateError;

        // Check if this is an HTML element (most common case)
        const is_html = tree_node.namespace == .html;

        // Create the appropriate element type using HTML element factory
        // This ensures HTMLIFrameElement is created for "iframe", HTMLDivElement for "div", etc.
        const element = if (is_html)
            try createHTMLElement(self.allocator, self.ctx, local_name)
        else
            try createForeignElement(self.allocator, self.ctx, tree_node.namespace, local_name);

        // Set up the element (local name, namespace, attributes). Its node
        // type is Element.init's, HTML or not. DOM "create an element" sets
        // the namespace and local name, which no IDL member does.
        const ns_uri: []const u8 = switch (tree_node.namespace) {
            .html => "http://www.w3.org/1999/xhtml",
            .mathml => "http://www.w3.org/1998/Math/MathML",
            .svg => "http://www.w3.org/2000/svg",
        };
        dom.node_creation.setElementNames(element, ns_uri, local_name) catch {};

        // Set owner document
        node_document.set(element, self.document) catch {};

        // A script element - HTML's, or an SVG script, whose insertion and
        // children-changed steps wait for its end tag too - is
        // parser-inserted.
        if (std.mem.eql(u8, local_name, "script")) dom.script_elements.markParserInserted(element, self.document);
        // A style element updates its style block when the parser pops it
        // (`domAdapterOnElementPopped`), not as it is inserted and filled.
        if (std.mem.eql(u8, local_name, "style")) dom.style_sheet_owners.createdByParser(element);

        for (tree_node.attributes.toSlice()) |attr| appendParsedAttribute(element, attr);

        return element;
    }

    fn createTextNode(self: *DomTreeAdapter, tree_node: *TreeNode) !*runtime.Instance {
        const text_data = tree_node.text_content.toSlice();
        const dom_string = runtime.DOMString.initInterned(text_data);
        const webidl = @import("webidl");

        const text = try interfaces.Text.call_constructor(
            self.ctx,
            webidl.Opt(runtime.DOMString).passed(dom_string),
        );

        node_document.set(text, self.document) catch {};

        return text;
    }

    fn createCommentNode(self: *DomTreeAdapter, tree_node: *TreeNode) !*runtime.Instance {
        const comment_data = tree_node.text_content.toSlice();
        const dom_string = runtime.DOMString.initInterned(comment_data);
        const webidl = @import("webidl");

        const comment = try interfaces.Comment.call_constructor(
            self.ctx,
            webidl.Opt(runtime.DOMString).passed(dom_string),
        );

        node_document.set(comment, self.document) catch {};

        return comment;
    }

    fn createDoctypeNode(self: *DomTreeAdapter, tree_node: *TreeNode) !*runtime.Instance {
        // Its node type is DocumentType.init's; its name, public ID and
        // system ID are the token's, which no IDL member sets.
        const doctype = try interfaces.DocumentType.init(self.allocator, self.ctx);
        dom.node_creation.setDoctypeIds(doctype, tree_node.doctype_name, tree_node.doctype_public_id, tree_node.doctype_system_id);

        node_document.set(doctype, self.document) catch {};

        return doctype;
    }
};

/// Create an element in the HTML namespace: it implements the interface HTML's
/// "element interface" algorithm names for `local_name`, matched exactly.
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#htmlelement
pub fn createHTMLElement(
    allocator: Allocator,
    ctx: runtime.Context,
    local_name: []const u8,
) !*runtime.Instance {
    return switch (html_core.element_interface.forLocalName(local_name)) {
        inline else => |which| @field(interfaces, @tagName(which)).init(allocator, ctx),
    };
}

/// Create an element the parser met in foreign content - in the SVG or MathML
/// namespace - with the interface its local name and namespace call for.
///
/// Deviation, stated: of the SVG element interfaces only SVGScriptElement is
/// made (its `type`, and the script element state it keeps); every other
/// foreign element is a plain Element (TODO: the rest of SVG's interfaces,
/// SVGElement for the unknown ones, and MathMLElement).
pub fn createForeignElement(
    allocator: Allocator,
    ctx: runtime.Context,
    namespace: Namespace,
    local_name: []const u8,
) !*runtime.Instance {
    if (namespace == .svg and std.mem.eql(u8, local_name, "script")) {
        return interfaces.SVGScriptElement.init(allocator, ctx);
    }
    // An SVG a is an SVGAElement, whose activation behaviour follows its
    // hyperlink - as Document.createElementNS makes it. Other SVG elements
    // are still plain Elements (stated: their impls do not chain yet).
    if (namespace == .svg and std.mem.eql(u8, local_name, "a")) {
        return interfaces.SVGAElement.init(allocator, ctx);
    }
    return interfaces.Element.init(allocator, ctx);
}

// =============================================================================
// Tests
// =============================================================================

test "ParserScriptContext - init" {
    const allocator = std.testing.allocator;

    var node_map = std.AutoHashMap(*TreeNode, *runtime.Instance).init(allocator);
    defer node_map.deinit();

    // Create runtime context data for testing
    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    // Create minimal context (without actual document/tree_builder for unit test)
    const script_ctx = ParserScriptContext{
        .allocator = allocator,
        .ctx = ctx,
        .document = undefined,
        .tree_node_to_dom_map = &node_map,
        .tree_builder = undefined,
        .scripting_enabled = true,
    };

    try std.testing.expect(script_ctx.scripting_enabled);
}
