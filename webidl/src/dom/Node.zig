//! Node interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-node

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");

const Allocator = std.mem.Allocator;
const EventTarget = @import("event_target").EventTarget;

/// Node WebIDL interface
/// DOM Spec: interface Node : EventTarget
pub const Node = webidl.interface(struct {
    pub const extends = EventTarget;

    allocator: Allocator,
    node_type: u16,
    node_name: []const u8,
    parent_node: ?*Node,
    child_nodes: infra.List(*Node),
    owner_document: ?*Document,

    /// DOM §7.1 - Registered observer list
    /// List of registered mutation observers watching this node
    registered_observers: infra.List(@import("registered_observer").RegisteredObserver),

    const Document = @import("document").Document;
    const RegisteredObserver = @import("registered_observer").RegisteredObserver;
    const TransientRegisteredObserver = @import("registered_observer").TransientRegisteredObserver;

    pub const ELEMENT_NODE: u16 = 1;
    pub const ATTRIBUTE_NODE: u16 = 2;
    pub const TEXT_NODE: u16 = 3;
    pub const CDATA_SECTION_NODE: u16 = 4;
    pub const ENTITY_REFERENCE_NODE: u16 = 5;
    pub const ENTITY_NODE: u16 = 6;
    pub const PROCESSING_INSTRUCTION_NODE: u16 = 7;
    pub const COMMENT_NODE: u16 = 8;
    pub const DOCUMENT_NODE: u16 = 9;
    pub const DOCUMENT_TYPE_NODE: u16 = 10;
    pub const DOCUMENT_FRAGMENT_NODE: u16 = 11;
    pub const NOTATION_NODE: u16 = 12;

    pub const DOCUMENT_POSITION_DISCONNECTED: u16 = 0x01;
    pub const DOCUMENT_POSITION_PRECEDING: u16 = 0x02;
    pub const DOCUMENT_POSITION_FOLLOWING: u16 = 0x04;
    pub const DOCUMENT_POSITION_CONTAINS: u16 = 0x08;
    pub const DOCUMENT_POSITION_CONTAINED_BY: u16 = 0x10;
    pub const DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC: u16 = 0x20;

    pub fn init(allocator: Allocator, node_type: u16, node_name: []const u8) !Node {
        // NOTE: Parent EventTarget fields will be flattened by codegen
        // Don't manually initialize parent fields here
        return .{
            .allocator = allocator,
            .node_type = node_type,
            .node_name = node_name,
            .parent_node = null,
            .child_nodes = infra.List(*Node).init(allocator),
            .owner_document = null,
            .registered_observers = infra.List(@import("registered_observer").RegisteredObserver).init(allocator),
            // NOTE: Parent EventTarget initialization is handled by codegen
        };
    }

    pub fn deinit(self: *Node) void {
        // NOTE: EventTarget parent cleanup is handled by codegen
        self.child_nodes.deinit();
        self.registered_observers.deinit();
    }

    /// insertBefore(node, child)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-insertbefore
    pub fn call_insertBefore(self: *Node, node: *Node, child: ?*Node) !*Node {
        // Call mutation.preInsert algorithm from src/dom/mutation.zig
        const mutation = @import("dom").mutation;
        return mutation.preInsert(node, self, child) catch |err| switch (err) {
            error.HierarchyRequestError => error.HierarchyRequestError,
            error.NotFoundError => error.NotFoundError,
            error.NotSupportedError => error.NotSupportedError,
        };
    }

    /// appendChild(node)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-appendchild
    pub fn call_appendChild(self: *Node, node: *Node) !*Node {
        // Call mutation.append algorithm from src/dom/mutation.zig
        const mutation = @import("dom").mutation;
        return mutation.append(node, self) catch |err| switch (err) {
            error.HierarchyRequestError => error.HierarchyRequestError,
            error.NotFoundError => error.NotFoundError,
            error.NotSupportedError => error.NotSupportedError,
        };
    }

    /// replaceChild(node, child)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-replacechild
    pub fn call_replaceChild(self: *Node, node: *Node, child: *Node) !*Node {
        // Call mutation.replace algorithm from src/dom/mutation.zig
        const mutation = @import("dom").mutation;
        return mutation.replace(child, node, self) catch |err| switch (err) {
            error.HierarchyRequestError => error.HierarchyRequestError,
            error.NotFoundError => error.NotFoundError,
            error.NotSupportedError => error.NotSupportedError,
        };
    }

    /// removeChild(child)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-removechild
    pub fn call_removeChild(self: *Node, child: *Node) !*Node {
        // Call mutation.preRemove algorithm from src/dom/mutation.zig
        const mutation = @import("dom").mutation;
        return mutation.preRemove(child, self) catch |err| switch (err) {
            error.HierarchyRequestError => error.HierarchyRequestError,
            error.NotFoundError => error.NotFoundError,
            error.NotSupportedError => error.NotSupportedError,
        };
    }

    /// getRootNode(options)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-getrootnode
    pub fn call_getRootNode(self: *Node, options: ?GetRootNodeOptions) *Node {
        // TODO: Support shadow-including root when options.composed is true
        _ = options;
        // For now, return regular root (from tree.zig)
        var current = self;
        while (current.parent_node) |parent| {
            current = parent;
        }
        return current;
    }

    /// contains(other)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-contains
    pub fn call_contains(self: *const Node, other: ?*const Node) bool {
        if (other == null) return false;
        // Check if other is an inclusive descendant of this
        // TODO: Use tree.isInclusiveDescendant from src/dom/tree.zig
        const other_node = other.?;
        if (self == other_node) return true;

        var current = other_node.parent_node;
        while (current) |parent| {
            if (parent == self) return true;
            current = parent.parent_node;
        }
        return false;
    }

    /// compareDocumentPosition(other)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-comparedocumentposition
    pub fn call_compareDocumentPosition(self: *const Node, other: *const Node) u16 {
        const tree = @import("dom").tree;

        // Step 1: If this is other, then return zero
        if (self == other) {
            return 0;
        }

        // Step 2: Let node1 be other and node2 be this
        const node1 = other;
        const node2 = self;

        // Step 3: Let attr1 and attr2 be null
        // Step 4-5: Handle attributes (not implemented yet - attributes don't participate in tree)
        // For now, we skip attribute handling as Attr nodes are handled separately

        // Step 6: If node1 or node2 is null, or node1's root is not node2's root
        // Check if nodes are in the same tree by comparing roots
        const root1 = tree.root(@constCast(node1));
        const root2 = tree.root(@constCast(node2));

        if (root1 != root2) {
            // Return disconnected + implementation specific + preceding/following
            // Use pointer comparison for consistent ordering
            const ptr1 = @intFromPtr(node1);
            const ptr2 = @intFromPtr(node2);
            const ordering = if (ptr1 < ptr2) Node.DOCUMENT_POSITION_PRECEDING else Node.DOCUMENT_POSITION_FOLLOWING;
            return Node.DOCUMENT_POSITION_DISCONNECTED | Node.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC | ordering;
        }

        // Step 7: If node1 is an ancestor of node2
        if (tree.isAncestor(node1, node2)) {
            return Node.DOCUMENT_POSITION_CONTAINS | Node.DOCUMENT_POSITION_PRECEDING;
        }

        // Step 8: If node1 is a descendant of node2
        if (tree.isDescendant(node1, node2)) {
            return Node.DOCUMENT_POSITION_CONTAINED_BY | Node.DOCUMENT_POSITION_FOLLOWING;
        }

        // Step 9: If node1 is preceding node2
        if (tree.isPreceding(node1, node2)) {
            return Node.DOCUMENT_POSITION_PRECEDING;
        }

        // Step 10: Return DOCUMENT_POSITION_FOLLOWING
        return Node.DOCUMENT_POSITION_FOLLOWING;
    }

    /// isEqualNode(otherNode)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-isequalnode
    pub fn call_isEqualNode(self: *const Node, other_node: ?*const Node) bool {
        // Step 1: Return true if otherNode is non-null and this equals otherNode
        if (other_node == null) return false;
        return Node.nodeEquals(self, other_node.?);
    }

    /// Node A equals node B - DOM Spec algorithm
    /// A node A equals a node B if all of the following conditions are true:
    /// - A and B implement the same interfaces
    /// - Node-specific properties are equal
    /// - If A is an element, each attribute in its list equals an attribute in B's list
    /// - A and B have the same number of children
    /// - Each child of A equals the child of B at the identical index
    pub fn nodeEquals(a: *const Node, b: *const Node) bool {
        // Step 1: A and B implement the same interfaces (check node_type)
        if (a.node_type != b.node_type) return false;

        // Step 2: Check node-type-specific properties
        switch (a.node_type) {
            DOCUMENT_TYPE_NODE => {
                // DocumentType: check name, public ID, and system ID
                // TODO: Cast to DocumentType when implemented
                // For now, just check node_name
                if (!std.mem.eql(u8, a.node_name, b.node_name)) return false;
            },
            ELEMENT_NODE => {
                // Element: check namespace, namespace prefix, local name, and attribute list size
                const elem_a: *const Element = @ptrCast(@alignCast(a));
                const elem_b: *const Element = @ptrCast(@alignCast(b));

                // Check namespace
                if (elem_a.namespace_uri == null and elem_b.namespace_uri != null) return false;
                if (elem_a.namespace_uri != null and elem_b.namespace_uri == null) return false;
                if (elem_a.namespace_uri != null and elem_b.namespace_uri != null) {
                    if (!std.mem.eql(u8, elem_a.namespace_uri.?, elem_b.namespace_uri.?)) return false;
                }

                // Check local name (tag_name)
                if (!std.mem.eql(u8, elem_a.tag_name, elem_b.tag_name)) return false;

                // Check attribute list size
                if (elem_a.attributes.len != elem_b.attributes.len) return false;

                // Step 3: Each attribute in A's list has an equal attribute in B's list
                for (elem_a.attributes.items) |attr_a| {
                    var found = false;
                    for (elem_b.attributes.items) |attr_b| {
                        if (Node.attributeEquals(&attr_a, &attr_b)) {
                            found = true;
                            break;
                        }
                    }
                    if (!found) return false;
                }
            },
            ATTRIBUTE_NODE => {
                // Attr: check namespace, local name, and value
                // Note: Attr nodes don't participate in tree, but we check for completeness
                const Attr = @import("attr").Attr;
                const attr_a: *const Attr = @ptrCast(@alignCast(a));
                const attr_b: *const Attr = @ptrCast(@alignCast(b));
                return Node.attributeEquals(attr_a, attr_b);
            },
            PROCESSING_INSTRUCTION_NODE => {
                // ProcessingInstruction: check target and data
                const PI = @import("processing_instruction").ProcessingInstruction;
                const pi_a: *const PI = @ptrCast(@alignCast(a));
                const pi_b: *const PI = @ptrCast(@alignCast(b));

                if (!std.mem.eql(u8, pi_a.target, pi_b.target)) return false;
                if (!std.mem.eql(u8, pi_a.data, pi_b.data)) return false;
            },
            TEXT_NODE, COMMENT_NODE, CDATA_SECTION_NODE => {
                // Text, Comment, CDATASection: check data
                const CharacterData = @import("character_data").CharacterData;
                const cd_a: *const CharacterData = @ptrCast(@alignCast(a));
                const cd_b: *const CharacterData = @ptrCast(@alignCast(b));

                if (!std.mem.eql(u8, cd_a.data, cd_b.data)) return false;
            },
            else => {
                // For other node types, basic node_name check is sufficient
                if (!std.mem.eql(u8, a.node_name, b.node_name)) return false;
            },
        }

        // Step 4: A and B have the same number of children
        if (a.child_nodes.len != b.child_nodes.len) return false;

        // Step 5: Each child of A equals the child of B at the identical index
        for (a.child_nodes.items, 0..) |child_a, i| {
            const child_b = b.child_nodes.items[i];
            if (!Node.nodeEquals(child_a, child_b)) return false;
        }

        return true;
    }

    /// Attribute equality check
    /// An attribute A equals an attribute B if:
    /// - namespace is equal
    /// - local name is equal
    /// - value is equal
    pub fn attributeEquals(a: *const @import("attr").Attr, b: *const @import("attr").Attr) bool {
        // Check namespace
        if (a.namespace_uri == null and b.namespace_uri != null) return false;
        if (a.namespace_uri != null and b.namespace_uri == null) return false;
        if (a.namespace_uri != null and b.namespace_uri != null) {
            if (!std.mem.eql(u8, a.namespace_uri.?, b.namespace_uri.?)) return false;
        }

        // Check local name
        if (!std.mem.eql(u8, a.local_name, b.local_name)) return false;

        // Check value
        if (!std.mem.eql(u8, a.value, b.value)) return false;

        return true;
    }

    /// isSameNode(otherNode)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-issamenode
    pub fn call_isSameNode(self: *const Node, other_node: ?*const Node) bool {
        // Legacy alias of === (pointer equality)
        if (other_node == null) return false;
        return self == other_node.?;
    }

    /// hasChildNodes()
    /// Spec: https://dom.spec.whatwg.org/#dom-node-haschildnodes
    pub fn call_hasChildNodes(self: *const Node) bool {
        return self.child_nodes.len > 0;
    }

    /// cloneNode(deep)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-clonenode
    pub fn call_cloneNode(self: *Node, deep: bool) !*Node {
        // TODO: Implement full clone algorithm from DOM §4.2.4
        // Steps:
        // 1. Let document be node's node document
        // 2. Let copy be result of cloning a single node (node, document, null)
        // 3. Run cloning steps for node (pass node, copy, deep)
        // 4. If deep is true, clone all descendants recursively
        // 5. If node is shadow host and clonable, clone shadow root too
        // 6. Return copy

        // For now, shallow clone only
        const copy = try Node.init(self.allocator, self.node_type, self.node_name);

        // If deep, should recursively clone children
        if (deep) {
            // TODO: Clone all children recursively
            // for (self.child_nodes.items) |child| {
            //     const child_copy = try child.call_cloneNode(true);
            //     try copy.child_nodes.append(child_copy);
            //     child_copy.parent_node = &copy;
            // }
        }

        return copy;
    }

    /// normalize()
    /// Spec: https://dom.spec.whatwg.org/#dom-node-normalize
    pub fn call_normalize(self: *Node) void {
        _ = self;
        // Normalize adjacent text nodes
    }

    /// Getters
    pub fn get_nodeType(self: *const Node) u16 {
        return self.node_type;
    }

    pub fn get_nodeName(self: *const Node) []const u8 {
        return self.node_name;
    }

    pub fn get_parentNode(self: *const Node) ?*Node {
        return self.parent_node;
    }

    pub fn get_parentElement(self: *const Node) ?*Element {
        // Returns parent if it's an Element, null otherwise
        const parent = self.parent_node orelse return null;
        if (parent.node_type == ELEMENT_NODE) {
            // TODO: Proper type casting when Element type is integrated
            return @ptrCast(parent);
        }
        return null;
    }

    const Element = @import("element").Element;

    pub fn get_childNodes(self: *const Node) *const infra.List(*Node) {
        // Returns a NodeList rooted at this matching only children
        // TODO: Return actual NodeList interface when implemented
        return &self.child_nodes;
    }

    pub fn get_firstChild(self: *const Node) ?*Node {
        if (self.child_nodes.len > 0) {
            return self.child_nodes.get(0);
        }
        return null;
    }

    pub fn get_lastChild(self: *const Node) ?*Node {
        if (self.child_nodes.len > 0) {
            return self.child_nodes.get(self.child_nodes.len - 1);
        }
        return null;
    }

    pub fn get_ownerDocument(self: *const Node) ?*Document {
        return self.owner_document;
    }

    pub fn get_previousSibling(self: *const Node) ?*Node {
        const parent = self.parent_node orelse return null;
        for (parent.child_nodes.items, 0..) |child, i| {
            if (child == self) {
                if (i == 0) return null;
                return parent.child_nodes.items[i - 1];
            }
        }
        return null;
    }

    pub fn get_nextSibling(self: *const Node) ?*Node {
        const parent = self.parent_node orelse return null;
        for (parent.child_nodes.items, 0..) |child, i| {
            if (child == self) {
                if (i + 1 >= parent.child_nodes.items.len) return null;
                return parent.child_nodes.items[i + 1];
            }
        }
        return null;
    }

    pub fn get_isConnected(self: *const Node) bool {
        // A node is connected if its root is a document
        // TODO: Use tree.root from src/dom/tree.zig
        var current = self;
        while (current.parent_node) |parent| {
            current = parent;
        }
        // Check if root is a document (node_type == DOCUMENT_NODE)
        return current.node_type == DOCUMENT_NODE;
    }

    pub fn get_baseURI(self: *const Node) []const u8 {
        // Returns node document's document base URL, serialized
        // TODO: Implement once Document has base URL support
        _ = self;
        return "";
    }

    pub fn get_nodeValue(self: *const Node) ?[]const u8 {
        // Spec: https://dom.spec.whatwg.org/#dom-node-nodevalue
        // Returns value for Attr and CharacterData, null otherwise
        // TODO: Implement for Attr and CharacterData nodes
        _ = self;
        return null;
    }

    pub fn set_nodeValue(self: *Node, value: ?[]const u8) void {
        // Spec: https://dom.spec.whatwg.org/#dom-node-nodevalue
        // If null, treat as empty string
        // Set value for Attr, replace data for CharacterData
        // TODO: Implement for Attr and CharacterData nodes
        _ = self;
        _ = value;
    }

    pub fn get_textContent(self: *const Node) ?[]const u8 {
        // Spec: https://dom.spec.whatwg.org/#dom-node-textcontent
        // Returns text content based on node type
        // TODO: Implement full algorithm:
        // - DocumentFragment, Element: concatenated text of descendants
        // - Attr, CharacterData: return their data
        // - Document, DocumentType: null
        _ = self;
        return null;
    }

    pub fn set_textContent(self: *Node, value: ?[]const u8) !void {
        // Spec: https://dom.spec.whatwg.org/#dom-node-textcontent
        // If null, treat as empty string
        // For DocumentFragment/Element: string replace all
        // TODO: Implement full algorithm using mutation.replaceAll
        _ = self;
        _ = value;
    }

    /// lookupPrefix(namespace)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-lookupprefix
    pub fn call_lookupPrefix(self: *const Node, namespace_param: ?[]const u8) ?[]const u8 {
        // TODO: Implement full algorithm from spec
        _ = self;
        _ = namespace_param;
        return null;
    }

    /// lookupNamespaceURI(prefix)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-lookupnamespaceuri
    pub fn call_lookupNamespaceURI(self: *const Node, prefix: ?[]const u8) ?[]const u8 {
        // TODO: Implement full algorithm from spec
        _ = self;
        _ = prefix;
        return null;
    }

    /// isDefaultNamespace(namespace)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-isdefaultnamespace
    pub fn call_isDefaultNamespace(self: *const Node, namespace_param: ?[]const u8) bool {
        // TODO: Implement full algorithm from spec
        _ = self;
        _ = namespace_param;
        return false;
    }

    // ========================================================================
    // Mutation Observer Support (DOM §7.1)
    // ========================================================================

    /// Get the list of registered observers for this node
    pub fn getRegisteredObservers(self: *Node) *std.ArrayList(RegisteredObserver) {
        return &self.registered_observers;
    }

    /// Add a registered observer to this node's list
    pub fn addRegisteredObserver(self: *Node, registered: RegisteredObserver) !void {
        try self.registered_observers.append(registered);
    }

    /// Remove all registered observers for a specific MutationObserver
    pub fn removeRegisteredObserver(self: *Node, observer: *const @import("mutation_observer").MutationObserver) void {
        var i: usize = 0;
        while (i < self.registered_observers.items.len) {
            if (self.registered_observers.items[i].observer == observer) {
                _ = self.registered_observers.orderedRemove(i);
                // Don't increment i, we just shifted everything down
            } else {
                i += 1;
            }
        }
    }

    /// Remove all transient registered observers whose source matches the given registered observer
    pub fn removeTransientObservers(self: *Node, source: *const RegisteredObserver) !void {
        // TODO: Implement transient registered observers
        // For now, this is a no-op since we haven't implemented transient observers yet
        _ = self;
        _ = source;
    }
}, .{
    .exposed = &.{.Window},
});

/// GetRootNodeOptions dictionary
/// Spec: https://dom.spec.whatwg.org/#dictdef-getrootnodeoptions
pub const GetRootNodeOptions = struct {
    composed: bool = false,
};
