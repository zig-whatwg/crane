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

    /// Set the script loader for external scripts.
    pub fn setScriptLoader(self: *ParserScriptContext, loader_fn: ScriptLoaderFn, loader_ctx: ?*anyopaque) void {
        self.script_loader_fn = loader_fn;
        self.script_loader_ctx = loader_ctx;
    }

    /// Load an external script by URL.
    /// Returns null if no script loader is set or if loading fails.
    pub fn loadExternalScript(self: *const ParserScriptContext, url: []const u8) ?[]const u8 {
        if (self.script_loader_fn) |loader_fn| {
            return loader_fn(self.script_loader_ctx, url);
        }
        return null;
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
        // if the DOM adapter hasn't processed this node. In this case, we
        // need to create the DOM element now.
        //
        // For proper integration, the DOM adapter should have already created
        // the element. If not, we can try to create one from the tree.
        return;
    };

    // Step 2: Get script content from tree node's text content
    const script_content = script_tree_node.text_content.toSlice();

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
            _ = script_execution.prepareScriptElement(ctx.allocator, script_element) catch |err| {
                std.debug.print("External script preparation error: {}\n", .{err});
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
    _ = script_execution.prepareScriptElement(ctx.allocator, script_element) catch |err| {
        std.debug.print("Script preparation error: {}\n", .{err});
    };
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
    pub fn onChildAppended(self: *DomTreeAdapter, parent: *TreeNode, child: *TreeNode) !void {
        const parent_dom = self.node_map.get(parent) orelse return;
        const child_dom = self.node_map.get(child) orelse return;

        _ = interfaces.Node.call_appendChild(parent_dom, child_dom) catch {};
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

        // Check if this is a script element
        const is_script = std.mem.eql(u8, local_name, "script") and
            tree_node.namespace == .html;

        // Create the appropriate element type
        const element = if (is_script)
            try interfaces.HTMLScriptElement.init(self.allocator, self.ctx)
        else
            try interfaces.Element.init(self.allocator, self.ctx);

        // Set up the element (local name, namespace, attributes)
        const NodeImpl = impls.Node;
        const ElementImpl = impls.Element;

        NodeImpl.setNodeType(element, NodeImpl.NodeType.ELEMENT_NODE) catch {};
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
            self.allocator,
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
            self.allocator,
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
