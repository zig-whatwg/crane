//! DOM Tree Adapter for Incremental TreeNode to DOM Conversion
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#tree-construction
//! HTML Standard §13.2.6 "Tree construction"
//!
//! This module provides an adapter that converts TreeNodes to DOM nodes incrementally
//! during parsing. This is essential for script execution during parsing, where scripts
//! need access to DOM nodes that were parsed before them (e.g., `document.querySelector()`).
//!
//! ## Problem
//!
//! When a `</script>` tag is encountered:
//! 1. Tree builder has TreeNode tree up to that point
//! 2. Script needs access to DOM nodes (e.g., `document.querySelector()`)
//! 3. But DOM nodes don't exist yet - conversion happens after parsing
//!
//! ## Solution
//!
//! This adapter maintains a bidirectional mapping between TreeNodes and DOM nodes,
//! converting nodes incrementally as they are created during parsing.
//!
//! ## Usage
//!
//! ```zig
//! // Create adapter during parser initialization
//! var adapter = DomTreeAdapter.init(allocator, ctx, document);
//! defer adapter.deinit();
//!
//! // Connect to tree builder
//! tree_builder.setDomAdapter(&adapter);
//!
//! // During parsing, adapter callbacks are invoked automatically
//! // Scripts can now access DOM nodes via document.querySelector() etc.
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");

// Import runtime for DOM types
const runtime = @import("runtime");

// Import tree builder types from html_core (the parser module)
const html_core = @import("html_core");
const TreeNode = html_core.parser.TreeNode;
const Namespace = html_core.parser.Namespace;
const TreeBuilder = html_core.parser.TreeBuilder;

// Import interface types for DOM operations (Golden Rule #12)
const interfaces = @import("interfaces");
const Document = interfaces.Document;
const Element = interfaces.Element;
const Text = interfaces.Text;
const Comment = interfaces.Comment;
const DocumentType = interfaces.DocumentType;
const DocumentFragment = interfaces.DocumentFragment;
const Node = interfaces.Node;
const HTMLScriptElement = interfaces.HTMLScriptElement;
const HTMLIFrameElement = interfaces.HTMLIFrameElement;

// Import DOM internals for state access (Golden Rule #12 compliant)
const dom = @import("dom");
const document_internals = dom.document_internals;

// Import impls only for internal state access (Golden Rule #12 exception - to be migrated)
const impls = @import("impls");
const NodeImpl = impls.Node;
const ElementImpl = impls.Element;
const DocumentTypeImpl = impls.DocumentType;
const HTMLScriptElementImpl = impls.HTMLScriptElement;
const HTMLIFrameElementImpl = impls.HTMLIFrameElement;

// WebIDL types
const webidl = @import("webidl");

/// Error type for DOM tree adapter operations
pub const DomTreeAdapterError = error{
    OutOfMemory,
    InvalidNode,
    InvalidState,
    NodeNotFound,
    ParentNotFound,
    DomOperationFailed,
};

/// Adapter that converts TreeNodes to DOM nodes incrementally during parsing.
///
/// This maintains a bidirectional mapping between TreeNodes (used by the tree builder)
/// and DOM Instances (used by the DOM API). As the tree builder creates and modifies
/// nodes, this adapter keeps the DOM in sync.
pub const DomTreeAdapter = struct {
    /// Memory allocator
    allocator: Allocator,

    /// Runtime context for DOM operations
    ctx: runtime.Context,

    /// The Document instance being built
    document: *runtime.Instance,

    /// Map from TreeNode pointer to DOM Instance
    /// This allows O(1) lookup of the DOM node for a given TreeNode
    node_map: std.AutoHashMap(*TreeNode, *runtime.Instance),

    /// Reverse map from DOM Instance to TreeNode pointer
    /// This allows O(1) lookup of the TreeNode for a given DOM node
    reverse_map: std.AutoHashMap(*runtime.Instance, *TreeNode),

    /// Whether to automatically execute scripts when script elements are created
    /// Set to false during fragment parsing
    execute_scripts: bool,

    /// Initialize a new DOM tree adapter.
    ///
    /// @param allocator Memory allocator for internal data structures
    /// @param ctx Runtime context for DOM operations
    /// @param document The Document instance being built
    pub fn init(allocator: Allocator, ctx: runtime.Context, document: *runtime.Instance) DomTreeAdapter {
        return .{
            .allocator = allocator,
            .ctx = ctx,
            .document = document,
            .node_map = std.AutoHashMap(*TreeNode, *runtime.Instance).init(allocator),
            .reverse_map = std.AutoHashMap(*runtime.Instance, *TreeNode).init(allocator),
            .execute_scripts = true,
        };
    }

    /// Free all resources.
    pub fn deinit(self: *DomTreeAdapter) void {
        self.node_map.deinit();
        self.reverse_map.deinit();
    }

    /// Connect this adapter to a tree builder.
    /// This registers the adapter's callbacks with the tree builder so that
    /// DOM nodes are created incrementally as parsing progresses.
    pub fn connectToTreeBuilder(self: *DomTreeAdapter, tree_builder: *TreeBuilder) void {
        tree_builder.setDomAdapterCallbacks(
            self,
            onNodeCreatedCallback,
            onChildAppendedCallback,
            onTextContentChangedCallback,
        );
    }

    // Static callback wrappers that the tree builder calls
    fn onNodeCreatedCallback(tree_node: *TreeNode, context: ?*anyopaque) void {
        const self: *DomTreeAdapter = @ptrCast(@alignCast(context));
        _ = self.onNodeCreated(tree_node) catch |err| {
            std.log.warn("DOM adapter onNodeCreated failed: {}", .{err});
        };
    }

    fn onChildAppendedCallback(parent: *TreeNode, child: *TreeNode, context: ?*anyopaque) void {
        const self: *DomTreeAdapter = @ptrCast(@alignCast(context));
        self.onChildAppended(parent, child) catch |err| {
            std.log.warn("DOM adapter onChildAppended failed: {}", .{err});
        };
    }

    fn onTextContentChangedCallback(tree_node: *TreeNode, context: ?*anyopaque) void {
        const self: *DomTreeAdapter = @ptrCast(@alignCast(context));
        self.onTextContentChanged(tree_node) catch |err| {
            std.log.warn("DOM adapter onTextContentChanged failed: {}", .{err});
        };
    }

    /// Called when tree builder creates a new element node.
    ///
    /// This creates the corresponding DOM Element and adds it to the mapping.
    /// The element is NOT yet attached to a parent - that happens in onChildAppended.
    ///
    /// @param tree_node The TreeNode that was just created
    /// @return The DOM Instance for the node, or error if creation failed
    pub fn onNodeCreated(self: *DomTreeAdapter, tree_node: *TreeNode) DomTreeAdapterError!*runtime.Instance {
        // Check if already mapped (shouldn't happen, but be safe)
        if (self.node_map.get(tree_node)) |existing| {
            return existing;
        }

        // Create the appropriate DOM node based on type
        const dom_node = switch (tree_node.node_type) {
            .element => try self.createElementNode(tree_node),
            .text => try self.createTextNode(tree_node),
            .comment => try self.createCommentNode(tree_node),
            .doctype => try self.createDoctypeNode(tree_node),
            .document => {
                // Document node is already created, just map it
                try self.node_map.put(tree_node, self.document);
                try self.reverse_map.put(self.document, tree_node);
                return self.document;
            },
        };

        // Add to maps
        try self.node_map.put(tree_node, dom_node);
        try self.reverse_map.put(dom_node, tree_node);

        return dom_node;
    }

    /// Called when tree builder appends a child to a parent.
    ///
    /// This establishes the parent-child relationship in the DOM.
    /// When appending an <html> element to the document, also sets document.documentElement.
    ///
    /// @param parent The parent TreeNode
    /// @param child The child TreeNode being appended
    pub fn onChildAppended(self: *DomTreeAdapter, parent: *TreeNode, child: *TreeNode) DomTreeAdapterError!void {
        // Get or create DOM nodes for both
        const parent_dom = try self.ensureDomNode(parent);
        const child_dom = try self.ensureDomNode(child);

        // Append child to parent using DOM interface (Golden Rule #12)
        _ = Node.call_appendChild(parent_dom, child_dom) catch {
            return DomTreeAdapterError.DomOperationFailed;
        };

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

    /// Called when tree builder removes a node from its parent.
    ///
    /// @param node The TreeNode being removed
    pub fn onNodeRemoved(self: *DomTreeAdapter, node: *TreeNode) DomTreeAdapterError!void {
        const dom_node = self.node_map.get(node) orelse return;

        // Get parent and remove from DOM
        const parent_dom = Node.get_parentNode(dom_node) catch return;
        if (parent_dom) |p| {
            _ = Node.call_removeChild(p, dom_node) catch {
                return DomTreeAdapterError.DomOperationFailed;
            };
        }
    }

    /// Called when tree builder inserts a node before another node.
    ///
    /// @param parent The parent TreeNode
    /// @param node The TreeNode being inserted
    /// @param reference The TreeNode before which to insert (null means append)
    pub fn onNodeInserted(
        self: *DomTreeAdapter,
        parent: *TreeNode,
        node: *TreeNode,
        reference: ?*TreeNode,
    ) DomTreeAdapterError!void {
        const parent_dom = try self.ensureDomNode(parent);
        const node_dom = try self.ensureDomNode(node);

        const ref_dom = if (reference) |ref|
            self.node_map.get(ref)
        else
            null;

        // Insert using DOM interface
        _ = Node.call_insertBefore(parent_dom, node_dom, ref_dom) catch {
            return DomTreeAdapterError.DomOperationFailed;
        };
    }

    /// Called when tree builder modifies text content of a text node.
    ///
    /// @param tree_node The text TreeNode whose content changed
    pub fn onTextContentChanged(self: *DomTreeAdapter, tree_node: *TreeNode) DomTreeAdapterError!void {
        const dom_node = self.node_map.get(tree_node) orelse return;

        // Update text content
        const text_content = tree_node.text_content.toSlice();
        const dom_string = runtime.DOMString.initInterned(text_content);

        // Use CharacterData.set_data for text/comment nodes
        if (tree_node.node_type == .text or tree_node.node_type == .comment) {
            interfaces.CharacterData.set_data(dom_node, dom_string) catch {
                return DomTreeAdapterError.DomOperationFailed;
            };
        }
    }

    /// Called when tree builder adds an attribute to an element.
    ///
    /// @param tree_node The element TreeNode
    /// @param name Attribute name
    /// @param value Attribute value
    pub fn onAttributeAdded(
        self: *DomTreeAdapter,
        tree_node: *TreeNode,
        name: []const u8,
        value: []const u8,
    ) DomTreeAdapterError!void {
        const dom_node = self.node_map.get(tree_node) orelse return;

        const name_str = runtime.DOMString.initInterned(name);
        const value_str = runtime.DOMString.initInterned(value);

        Element.call_setAttribute(dom_node, name_str, value_str) catch {
            return DomTreeAdapterError.DomOperationFailed;
        };
    }

    /// Get the DOM node for a TreeNode.
    ///
    /// @param tree_node The TreeNode to look up
    /// @return The corresponding DOM Instance, or null if not mapped
    pub fn getDomNode(self: *DomTreeAdapter, tree_node: *TreeNode) ?*runtime.Instance {
        return self.node_map.get(tree_node);
    }

    /// Get the TreeNode for a DOM node.
    ///
    /// @param dom_node The DOM Instance to look up
    /// @return The corresponding TreeNode, or null if not mapped
    pub fn getTreeNode(self: *DomTreeAdapter, dom_node: *runtime.Instance) ?*TreeNode {
        return self.reverse_map.get(dom_node);
    }

    /// Check if a TreeNode has been mapped to a DOM node.
    pub fn hasMapping(self: *DomTreeAdapter, tree_node: *TreeNode) bool {
        return self.node_map.contains(tree_node);
    }

    /// Get the number of nodes currently mapped.
    pub fn getMappingCount(self: *DomTreeAdapter) usize {
        return self.node_map.count();
    }

    // ==========================================================================
    // Private Helper Functions
    // ==========================================================================

    /// Ensure a DOM node exists for the given TreeNode, creating if necessary.
    fn ensureDomNode(self: *DomTreeAdapter, tree_node: *TreeNode) DomTreeAdapterError!*runtime.Instance {
        if (self.node_map.get(tree_node)) |existing| {
            return existing;
        }
        return try self.onNodeCreated(tree_node);
    }

    /// Create an Element DOM node from a TreeNode.
    fn createElementNode(self: *DomTreeAdapter, tree_node: *TreeNode) DomTreeAdapterError!*runtime.Instance {
        const local_name = tree_node.local_name orelse return DomTreeAdapterError.InvalidNode;

        // Check if this is a script or iframe element
        const is_script = std.mem.eql(u8, local_name, "script") and
            tree_node.namespace == .html;
        const is_iframe = std.mem.eql(u8, local_name, "iframe") and
            tree_node.namespace == .html;

        // Create the appropriate element type
        const element = if (is_script)
            HTMLScriptElement.init(self.allocator, self.ctx) catch return DomTreeAdapterError.OutOfMemory
        else if (is_iframe)
            HTMLIFrameElement.init(self.allocator, self.ctx) catch return DomTreeAdapterError.OutOfMemory
        else
            Element.init(self.allocator, self.ctx) catch return DomTreeAdapterError.OutOfMemory;

        // Set node type
        NodeImpl.setNodeType(element, NodeImpl.NodeType.ELEMENT_NODE) catch {
            return DomTreeAdapterError.DomOperationFailed;
        };

        // Set local name
        ElementImpl.setLocalName(element, local_name) catch {
            return DomTreeAdapterError.DomOperationFailed;
        };

        // Set namespace
        const ns = namespaceToUri(tree_node.namespace);
        if (ns) |ns_uri| {
            ElementImpl.setNamespaceURI(element, ns_uri) catch {
                return DomTreeAdapterError.DomOperationFailed;
            };
        }

        // Set owner document
        NodeImpl.setOwnerDocument(element, self.document) catch {
            return DomTreeAdapterError.DomOperationFailed;
        };

        // For script elements, mark as parser-inserted
        if (is_script) {
            HTMLScriptElementImpl.setParserDocument(element, self.document);
            HTMLScriptElementImpl.clearForceAsync(element);
        }

        // Add existing attributes
        const attrs = tree_node.attributes.toSlice();
        for (attrs) |attr| {
            const name_str = runtime.DOMString.initInterned(attr.name);
            const value_str = runtime.DOMString.initInterned(attr.value);
            Element.call_setAttribute(element, name_str, value_str) catch continue;
        }

        return element;
    }

    /// Create a Text DOM node from a TreeNode.
    fn createTextNode(self: *DomTreeAdapter, tree_node: *TreeNode) DomTreeAdapterError!*runtime.Instance {
        const text_data = tree_node.text_content.toSlice();
        const dom_string = runtime.DOMString.initInterned(text_data);

        const text = Text.call_constructor(
            self.ctx,
            webidl.Opt(runtime.DOMString).passed(dom_string),
        ) catch return DomTreeAdapterError.OutOfMemory;

        // Set owner document
        NodeImpl.setOwnerDocument(text, self.document) catch {
            return DomTreeAdapterError.DomOperationFailed;
        };

        return text;
    }

    /// Create a Comment DOM node from a TreeNode.
    fn createCommentNode(self: *DomTreeAdapter, tree_node: *TreeNode) DomTreeAdapterError!*runtime.Instance {
        const comment_data = tree_node.text_content.toSlice();
        const dom_string = runtime.DOMString.initInterned(comment_data);

        const comment = Comment.call_constructor(
            self.ctx,
            webidl.Opt(runtime.DOMString).passed(dom_string),
        ) catch return DomTreeAdapterError.OutOfMemory;

        // Set node type
        NodeImpl.setNodeType(comment, NodeImpl.NodeType.COMMENT_NODE) catch {
            return DomTreeAdapterError.DomOperationFailed;
        };

        // Set owner document
        NodeImpl.setOwnerDocument(comment, self.document) catch {
            return DomTreeAdapterError.DomOperationFailed;
        };

        return comment;
    }

    /// Create a DocumentType DOM node from a TreeNode.
    fn createDoctypeNode(self: *DomTreeAdapter, tree_node: *TreeNode) DomTreeAdapterError!*runtime.Instance {
        const doctype = DocumentType.init(
            self.allocator,
            self.ctx,
        ) catch return DomTreeAdapterError.OutOfMemory;

        // Set node type
        NodeImpl.setNodeType(doctype, NodeImpl.NodeType.DOCUMENT_TYPE_NODE) catch {
            return DomTreeAdapterError.DomOperationFailed;
        };

        // Set DocumentType-specific fields
        if (DocumentTypeImpl.getInternal(doctype)) |dt_internal| {
            if (tree_node.doctype_name) |name| {
                dt_internal.name = self.allocator.dupe(u8, name) catch return DomTreeAdapterError.OutOfMemory;
            }
            if (tree_node.doctype_public_id) |pub_id| {
                dt_internal.public_id = self.allocator.dupe(u8, pub_id) catch return DomTreeAdapterError.OutOfMemory;
            }
            if (tree_node.doctype_system_id) |sys_id| {
                dt_internal.system_id = self.allocator.dupe(u8, sys_id) catch return DomTreeAdapterError.OutOfMemory;
            }
        }

        // Set owner document
        NodeImpl.setOwnerDocument(doctype, self.document) catch {
            return DomTreeAdapterError.DomOperationFailed;
        };

        // Also set doctype reference on document
        if (document_internals.getInternal(self.document)) |doc_internal| {
            doc_internal.doctype = doctype;
        }

        return doctype;
    }

    /// Convert parser namespace to URI string.
    fn namespaceToUri(ns: Namespace) ?[]const u8 {
        return switch (ns) {
            .html => "http://www.w3.org/1999/xhtml",
            .mathml => "http://www.w3.org/1998/Math/MathML",
            .svg => "http://www.w3.org/2000/svg",
        };
    }
};

// =============================================================================
// Tests
// =============================================================================

// NOTE: Full integration tests for DomTreeAdapter require V8 runtime initialization
// and are run as part of the WPT runner tests, not as unit tests.
// The tests below only test helper functions that don't require runtime.

test "DomTreeAdapter - namespaceToUri" {
    try std.testing.expectEqualStrings(
        "http://www.w3.org/1999/xhtml",
        DomTreeAdapter.namespaceToUri(.html).?,
    );
    try std.testing.expectEqualStrings(
        "http://www.w3.org/2000/svg",
        DomTreeAdapter.namespaceToUri(.svg).?,
    );
    try std.testing.expectEqualStrings(
        "http://www.w3.org/1998/Math/MathML",
        DomTreeAdapter.namespaceToUri(.mathml).?,
    );
}
