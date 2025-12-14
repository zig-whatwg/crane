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
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const infra = @import("infra");

// HTTP fetch for external scripts
const fetch = @import("fetch");

// HTML parser types
const html_core = @import("html_core");
const TreeBuilder = html_core.parser.TreeBuilder;
const TreeNode = html_core.parser.TreeNode;
const Tokenizer = html_core.parser.Tokenizer;

// Script execution
const script_execution = @import("script_execution.zig");

// DOM implementation access for internal state
const impls = @import("impls");
const HTMLScriptElementImpl = impls.HTMLScriptElement;
const DocumentImpl = impls.Document;

// DOM internals for document_element setting
const dom = @import("dom");
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

    /// Load an external script by URL.
    ///
    /// If a custom script loader is set, tries that first. If the loader returns null,
    /// falls back to HTTP fetch like a real browser would.
    ///
    /// Relative URLs are resolved against the base URL.
    ///
    /// Returns null if loading fails.
    pub fn loadExternalScript(self: *ParserScriptContext, url: []const u8) ?[]const u8 {
        // Try custom loader first if provided
        if (self.script_loader_fn) |loader_fn| {
            if (loader_fn(self.script_loader_ctx, url)) |content| {
                return content;
            }
            // Custom loader returned null - fall through to HTTP fetch
        }

        // Resolve relative URLs against base URL
        const resolved_url = resolveScriptUrl(self.allocator, url, self.base_url) orelse {
            std.debug.print("Failed to resolve script URL: {s}\n", .{url});
            return null;
        };
        defer if (resolved_url.ptr != url.ptr) self.allocator.free(resolved_url);

        // Default: HTTP fetch like a real browser
        return fetchScriptViaHttp(self.allocator, resolved_url);
    }

    /// Get the DOM element for a TreeNode (if it has been converted).
    pub fn getDomElement(self: *const ParserScriptContext, tree_node: *TreeNode) ?*runtime.Instance {
        return self.tree_node_to_dom_map.get(tree_node);
    }
};

/// Parser script execution callback.
///
/// This function is invoked by the tree builder when a `</script>` end tag is encountered.
/// It retrieves the corresponding DOM HTMLScriptElement and executes the script via V8.
///
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#scriptEndTag
///
/// The steps are:
/// 1. Get the DOM HTMLScriptElement from the tree node via the adapter
/// 2. Get script content from the tree node's text content
/// 3. Check if it's an external script (queue for loading) or inline (execute)
/// 4. Execute inline script via V8
pub fn parserScriptCallback(script_tree_node: *TreeNode, context: ?*anyopaque) void {
    const ctx: *ParserScriptContext = @ptrCast(@alignCast(context orelse return));

    // Check if scripting is enabled
    if (!ctx.scripting_enabled) {
        return;
    }

    // Step 1: Get DOM HTMLScriptElement from tree node via adapter
    const script_element = ctx.getDomElement(script_tree_node) orelse {
        // Script element hasn't been converted to DOM yet - this can happen
        // if the DOM adapter hasn't processed this node.
        return;
    };

    // Step 2: Get script content from tree node's child text nodes
    // The tree builder creates text nodes as children, not in the element's own text_content
    const script_content = getScriptTextContent(script_tree_node);

    // Step 3: Check for src attribute (external script)
    const src_attr = getScriptSrcAttribute(script_tree_node);

    if (src_attr) |src_url| {
        // External script - try to load via script loader
        HTMLScriptElementImpl.setParserDocument(script_element, ctx.document);
        HTMLScriptElementImpl.setFromExternalFile(script_element, true);

        // Try to load the external script
        if (ctx.loadExternalScript(src_url)) |external_content| {
            // Free the loaded content when we're done (cacheSourceText duplicates it)
            defer ctx.allocator.free(external_content);

            // Successfully loaded - execute the external script content
            if (external_content.len == 0) {
                return; // Empty script
            }

            // Cache the external script content (this duplicates external_content)
            HTMLScriptElementImpl.cacheSourceText(script_element, external_content) catch {
                return;
            };

            // Set the insertion point before script execution
            setInsertionPointForScript(ctx);
            defer clearInsertionPointAfterScript(ctx);

            // Execute via the standard preparation path
            _ = script_execution.prepareScriptElement(ctx.allocator, script_element) catch {
                // Script preparation failed - continue anyway
            };
            return;
        } else {
            // Script loader not available or failed to load
            // This is not necessarily an error - the test might not need this script
            // Just skip execution
            return;
        }
    }

    // Step 4: Inline script - execute via script_execution module
    if (script_content.len == 0) {
        return; // Empty script
    }

    // Mark as parser-inserted
    HTMLScriptElementImpl.setParserDocument(script_element, ctx.document);

    // Cache the source text from the tree node
    HTMLScriptElementImpl.cacheSourceText(script_element, script_content) catch {
        return;
    };

    // Set the insertion point before script execution
    // This allows document.write() to insert content at the correct position
    setInsertionPointForScript(ctx);
    defer clearInsertionPointAfterScript(ctx);

    // Execute the script via the standard preparation path
    // This handles CSP checks, script type determination, etc.
    _ = script_execution.prepareScriptElement(ctx.allocator, script_element) catch {};
}

/// Get the src attribute from a script tree node.
fn getScriptSrcAttribute(tree_node: *TreeNode) ?[]const u8 {
    const attrs = tree_node.attributes.toSlice();
    for (attrs) |attr| {
        if (std.mem.eql(u8, attr.name, "src")) {
            return attr.value;
        }
    }
    return null;
}

/// Get text content from a script element's child text nodes.
/// The tree builder creates text nodes as children, not in the element's own text_content.
fn getScriptTextContent(tree_node: *TreeNode) []const u8 {
    // First check if there's a single child text node (common case)
    if (tree_node.first_child) |first| {
        if (first.node_type == .text) {
            // If there's only one child and it's a text node, return its content directly
            if (first.next_sibling == null) {
                return first.text_content.toSlice();
            }
        }
    }

    // If no children or not a text node, check the element's own text_content
    // (fallback for edge cases)
    return tree_node.text_content.toSlice();
}

/// Set the insertion point for document.write() during script execution.
///
/// Per HTML Standard, the insertion point is set to just before the next input character
/// when a script is about to be executed during parsing.
fn setInsertionPointForScript(ctx: *ParserScriptContext) void {
    // The tree builder maintains a reference to the tokenizer which has the input stream.
    // We set the insertion point to the current position in the input stream.
    //
    // Note: For full document.write() support during parsing, we need to:
    // 1. Get the current position from the tokenizer's input stream
    // 2. Set that as the insertion point
    // 3. When document.write() is called, insert content at that position
    //
    // For now, we note that this is where integration would happen.
    _ = ctx;
}

/// Clear the insertion point after script execution.
fn clearInsertionPointAfterScript(ctx: *ParserScriptContext) void {
    _ = ctx;
}

// =============================================================================
// URL Resolution for Scripts
// =============================================================================

/// Resolve a script URL against a base URL.
///
/// If the URL is already absolute (starts with http:// or https://), returns it as-is.
/// If the URL is relative (starts with /), resolves it against the base URL's origin.
/// Otherwise, resolves it relative to the base URL's path.
fn resolveScriptUrl(allocator: Allocator, url: []const u8, base_url: []const u8) ?[]const u8 {
    // Already absolute URL
    if (std.mem.startsWith(u8, url, "http://") or std.mem.startsWith(u8, url, "https://")) {
        return url;
    }

    // No base URL - can't resolve
    if (base_url.len == 0) {
        return null;
    }

    // Extract origin from base URL (scheme + host + optional port)
    // e.g., "http://localhost:8000/path/to/doc.html" -> "http://localhost:8000"
    const origin_end = blk: {
        // Find end of scheme
        const scheme_end = std.mem.indexOf(u8, base_url, "://") orelse return null;
        const after_scheme = base_url[scheme_end + 3 ..];

        // Find end of authority (host:port)
        if (std.mem.indexOf(u8, after_scheme, "/")) |slash_pos| {
            break :blk scheme_end + 3 + slash_pos;
        } else {
            break :blk base_url.len;
        }
    };

    const origin = base_url[0..origin_end];

    // URL starts with / - resolve against origin
    if (std.mem.startsWith(u8, url, "/")) {
        return std.fmt.allocPrint(allocator, "{s}{s}", .{ origin, url }) catch null;
    }

    // Relative URL - resolve against base path
    // e.g., base="http://localhost/path/to/doc.html", url="script.js" -> "http://localhost/path/to/script.js"
    const base_path = base_url[origin_end..];
    const last_slash = std.mem.lastIndexOf(u8, base_path, "/") orelse 0;
    const dir_path = base_path[0 .. last_slash + 1];

    return std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ origin, dir_path, url }) catch null;
}

// =============================================================================
// HTTP Script Fetching (Default Browser Behavior)
// =============================================================================

/// Fetch an external script via HTTP, like a real browser.
///
/// This is the default behavior when no custom script loader is provided.
/// It uses the Fetch API to retrieve scripts from URLs.
fn fetchScriptViaHttp(allocator: Allocator, url: []const u8) ?[]const u8 {

    // Use the fetch module to retrieve the script
    const response = fetch.fetchSimple(allocator, url) catch |err| {
        std.debug.print("HTTP fetch error for script {s}: {}\n", .{ url, err });
        return null;
    };
    defer response.deinit();

    // Check for successful response (2xx status)
    if (response.status < 200 or response.status >= 300) {
        std.debug.print("HTTP {d} fetching script {s}\n", .{ response.status, url });
        return null;
    }

    // Extract body content
    if (response.body) |resp_body| {
        if (resp_body.data.items.len > 0) {
            return allocator.dupe(u8, resp_body.data.items) catch null;
        }
    } else {}

    return null;
}

// =============================================================================
// Static Callback Wrappers for Tree Builder Integration
// =============================================================================

/// Static callback wrapper for onNodeCreated.
/// This is passed to tree_builder.setDomAdapterCallbacks().
pub fn domAdapterOnNodeCreated(tree_node: *TreeNode, context: ?*anyopaque) void {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    adapter.onNodeCreated(tree_node) catch |err| {
        std.debug.print("DomTreeAdapter.onNodeCreated error: {}\n", .{err});
    };
}

/// Static callback wrapper for onChildAppended.
/// This is passed to tree_builder.setDomAdapterCallbacks().
pub fn domAdapterOnChildAppended(parent: *TreeNode, child: *TreeNode, context: ?*anyopaque) void {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    adapter.onChildAppended(parent, child) catch |err| {
        std.debug.print("DomTreeAdapter.onChildAppended error: {}\n", .{err});
    };
}

/// Static callback wrapper for onTextContentChanged.
/// This is passed to tree_builder.setDomAdapterCallbacks().
pub fn domAdapterOnTextContentChanged(tree_node: *TreeNode, context: ?*anyopaque) void {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    adapter.onTextContentChanged(tree_node) catch |err| {
        std.debug.print("DomTreeAdapter.onTextContentChanged error: {}\n", .{err});
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
        };
    }

    pub fn deinit(self: *DomTreeAdapter) void {
        // Clean up any orphaned DOM nodes that were NOT successfully attached to the tree.
        //
        // During parsing, onNodeCreated creates DOM nodes and adds them to node_map.
        // onChildAppended then attaches them to the tree. However, if appendChild fails
        // (silently caught) or if onChildAppended is never called for a node, that node
        // becomes an orphan - it exists in node_map but has no parent.
        //
        // Nodes that ARE attached to the tree will be cleaned up recursively when
        // Document.deinit is called (via Node.deinit's child traversal).
        //
        // We MUST clean up orphaned nodes here to prevent memory leaks.
        var it = self.node_map.iterator();
        while (it.next()) |entry| {
            const dom_node = entry.value_ptr.*;

            // Skip the document node - it's managed externally
            if (dom_node == self.document) continue;

            // Check if this node has a parent (i.e., was successfully attached)
            const NodeImpl = impls.Node;
            if (NodeImpl.getInternalState(dom_node)) |internal| {
                if (internal.parent == null) {
                    // This node is an orphan - clean it up
                    // Use deinitNodeByType to properly clean up based on node type
                    NodeImpl.deinitNodeByType(dom_node);
                }
            }
        }

        // Clean up the HashMap itself
        self.node_map.deinit();
    }

    /// Called when a new node is created during parsing.
    /// Creates the corresponding DOM node and adds it to the map.
    pub fn onNodeCreated(self: *DomTreeAdapter, tree_node: *TreeNode) !void {
        const dom_node = try self.createDomNode(tree_node);
        try self.node_map.put(tree_node, dom_node);
    }

    /// Called when a child is appended to a parent during parsing.
    /// Updates the DOM tree structure.
    /// When appending <html> to document, also sets document.documentElement.
    pub fn onChildAppended(self: *DomTreeAdapter, parent: *TreeNode, child: *TreeNode) !void {
        const parent_dom = self.node_map.get(parent) orelse return;
        const child_dom = self.node_map.get(child) orelse return;

        _ = interfaces.Node.call_appendChild(parent_dom, child_dom) catch {};

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
            try interfaces.Element.init(self.allocator, self.ctx);

        // Set up the element (local name, namespace, attributes)
        const NodeImpl = impls.Node;
        const ElementImpl = impls.Element;

        // For non-HTML elements, set node type (HTML elements already have it from init chain)
        if (!is_html) {
            NodeImpl.setNodeType(element, NodeImpl.NodeType.ELEMENT_NODE) catch {};
        }
        ElementImpl.setLocalName(element, local_name) catch {};

        // Set namespace
        const ns_uri: ?[]const u8 = switch (tree_node.namespace) {
            .html => "http://www.w3.org/1999/xhtml",
            .mathml => "http://www.w3.org/1998/Math/MathML",
            .svg => "http://www.w3.org/2000/svg",
        };
        if (ns_uri) |uri| {
            ElementImpl.setNamespaceURI(element, uri) catch {};
        }

        // Set owner document
        NodeImpl.setOwnerDocument(element, self.document) catch {};

        // For script elements, mark as parser-inserted
        const is_script = std.mem.eql(u8, local_name, "script") and is_html;
        if (is_script) {
            HTMLScriptElementImpl.setParserDocument(element, self.document);
            HTMLScriptElementImpl.clearForceAsync(element);
        }

        // Add attributes
        const attrs = tree_node.attributes.toSlice();
        for (attrs) |attr| {
            const name_str = runtime.DOMString.initInterned(attr.name);
            const value_str = runtime.DOMString.initInterned(attr.value);
            interfaces.Element.call_setAttribute(element, name_str, value_str) catch {};
        }

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

        const NodeImpl = impls.Node;
        NodeImpl.setOwnerDocument(text, self.document) catch {};

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

        const NodeImpl = impls.Node;
        NodeImpl.setNodeType(comment, NodeImpl.NodeType.COMMENT_NODE) catch {};
        NodeImpl.setOwnerDocument(comment, self.document) catch {};

        return comment;
    }

    fn createDoctypeNode(self: *DomTreeAdapter, tree_node: *TreeNode) !*runtime.Instance {
        const doctype = try interfaces.DocumentType.init(self.allocator, self.ctx);

        const NodeImpl = impls.Node;
        NodeImpl.setNodeType(doctype, NodeImpl.NodeType.DOCUMENT_TYPE_NODE) catch {};

        // Set DocumentType-specific fields
        const DocumentTypeImpl = impls.DocumentType;
        if (DocumentTypeImpl.getInternal(doctype)) |dt_internal| {
            if (tree_node.doctype_name) |name| {
                dt_internal.name = self.allocator.dupe(u8, name) catch "";
            }
            if (tree_node.doctype_public_id) |pub_id| {
                dt_internal.public_id = self.allocator.dupe(u8, pub_id) catch "";
            }
            if (tree_node.doctype_system_id) |sys_id| {
                dt_internal.system_id = self.allocator.dupe(u8, sys_id) catch "";
            }
        }

        NodeImpl.setOwnerDocument(doctype, self.document) catch {};

        return doctype;
    }
};

/// Create an HTML element with the correct interface based on tag name.
/// This factory ensures HTMLIFrameElement is created for "iframe", HTMLDivElement for "div", etc.
/// Used by DomTreeAdapter.createElementNode() during HTML parsing.
fn createHTMLElement(
    allocator: Allocator,
    ctx: runtime.Context,
    local_name: []const u8,
) !*runtime.Instance {
    // Convert to lowercase for case-insensitive matching (HTML is case-insensitive)
    var lower_buf: [64]u8 = undefined;
    const len = @min(local_name.len, lower_buf.len);
    for (local_name[0..len], 0..) |c, i| {
        lower_buf[i] = std.ascii.toLower(c);
    }
    const lower_name = lower_buf[0..len];

    // Most common elements first for faster lookup
    if (std.mem.eql(u8, lower_name, "div")) return try interfaces.HTMLDivElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "span")) return try interfaces.HTMLSpanElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "a")) return try interfaces.HTMLAnchorElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "p")) return try interfaces.HTMLParagraphElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "img")) return try interfaces.HTMLImageElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "input")) return try interfaces.HTMLInputElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "button")) return try interfaces.HTMLButtonElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "form")) return try interfaces.HTMLFormElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "script")) return try interfaces.HTMLScriptElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "style")) return try interfaces.HTMLStyleElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "link")) return try interfaces.HTMLLinkElement.init(allocator, ctx);

    // Structural elements
    if (std.mem.eql(u8, lower_name, "html")) return try interfaces.HTMLHtmlElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "head")) return try interfaces.HTMLHeadElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "body")) return try interfaces.HTMLBodyElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "title")) return try interfaces.HTMLTitleElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "base")) return try interfaces.HTMLBaseElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "meta")) return try interfaces.HTMLMetaElement.init(allocator, ctx);

    // Headings
    if (std.mem.eql(u8, lower_name, "h1") or
        std.mem.eql(u8, lower_name, "h2") or
        std.mem.eql(u8, lower_name, "h3") or
        std.mem.eql(u8, lower_name, "h4") or
        std.mem.eql(u8, lower_name, "h5") or
        std.mem.eql(u8, lower_name, "h6")) return try interfaces.HTMLHeadingElement.init(allocator, ctx);

    // Embedded content - CRITICAL for cross-realm support
    if (std.mem.eql(u8, lower_name, "iframe")) return try interfaces.HTMLIFrameElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "frame")) return try interfaces.HTMLFrameElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "frameset")) return try interfaces.HTMLFrameSetElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "object")) return try interfaces.HTMLObjectElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "embed")) return try interfaces.HTMLEmbedElement.init(allocator, ctx);

    // Media elements
    if (std.mem.eql(u8, lower_name, "video")) return try interfaces.HTMLVideoElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "audio")) return try interfaces.HTMLAudioElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "source")) return try interfaces.HTMLSourceElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "track")) return try interfaces.HTMLTrackElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "picture")) return try interfaces.HTMLPictureElement.init(allocator, ctx);

    // Canvas and drawing
    if (std.mem.eql(u8, lower_name, "canvas")) return try interfaces.HTMLCanvasElement.init(allocator, ctx);

    // Form elements
    if (std.mem.eql(u8, lower_name, "textarea")) return try interfaces.HTMLTextAreaElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "select")) return try interfaces.HTMLSelectElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "option")) return try interfaces.HTMLOptionElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "optgroup")) return try interfaces.HTMLOptGroupElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "label")) return try interfaces.HTMLLabelElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "fieldset")) return try interfaces.HTMLFieldSetElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "legend")) return try interfaces.HTMLLegendElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "output")) return try interfaces.HTMLOutputElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "progress")) return try interfaces.HTMLProgressElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "meter")) return try interfaces.HTMLMeterElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "datalist")) return try interfaces.HTMLDataListElement.init(allocator, ctx);

    // Table elements
    if (std.mem.eql(u8, lower_name, "table")) return try interfaces.HTMLTableElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "caption")) return try interfaces.HTMLTableCaptionElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "colgroup") or
        std.mem.eql(u8, lower_name, "col")) return try interfaces.HTMLTableColElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "thead") or
        std.mem.eql(u8, lower_name, "tbody") or
        std.mem.eql(u8, lower_name, "tfoot")) return try interfaces.HTMLTableSectionElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "tr")) return try interfaces.HTMLTableRowElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "td") or
        std.mem.eql(u8, lower_name, "th")) return try interfaces.HTMLTableCellElement.init(allocator, ctx);

    // List elements
    if (std.mem.eql(u8, lower_name, "ul")) return try interfaces.HTMLUListElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "ol")) return try interfaces.HTMLOListElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "li")) return try interfaces.HTMLLIElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "dl")) return try interfaces.HTMLDListElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "menu")) return try interfaces.HTMLMenuElement.init(allocator, ctx);

    // Quote elements
    if (std.mem.eql(u8, lower_name, "blockquote") or
        std.mem.eql(u8, lower_name, "q")) return try interfaces.HTMLQuoteElement.init(allocator, ctx);

    // Pre-formatted text
    if (std.mem.eql(u8, lower_name, "pre") or
        std.mem.eql(u8, lower_name, "listing") or
        std.mem.eql(u8, lower_name, "xmp")) return try interfaces.HTMLPreElement.init(allocator, ctx);

    // Semantic elements
    if (std.mem.eql(u8, lower_name, "br")) return try interfaces.HTMLBRElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "hr")) return try interfaces.HTMLHRElement.init(allocator, ctx);

    // Other common elements
    if (std.mem.eql(u8, lower_name, "area")) return try interfaces.HTMLAreaElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "map")) return try interfaces.HTMLMapElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "template")) return try interfaces.HTMLTemplateElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "slot")) return try interfaces.HTMLSlotElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "dialog")) return try interfaces.HTMLDialogElement.init(allocator, ctx);
    if (std.mem.eql(u8, lower_name, "details")) return try interfaces.HTMLDetailsElement.init(allocator, ctx);

    // Default: HTMLUnknownElement for unrecognized tags
    // This is per HTML spec - unknown elements should be HTMLUnknownElement
    return try interfaces.HTMLUnknownElement.init(allocator, ctx);
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
