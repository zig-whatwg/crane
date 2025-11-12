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
            // TODO: Initialize EventTarget parent fields (will be added by codegen)
        };
    }

    pub fn deinit(self: *Node) void {
        // NOTE: EventTarget parent cleanup will be handled by codegen
        self.child_nodes.deinit();
        self.registered_observers.deinit();
        // TODO: Call parent EventTarget deinit (will be added by codegen)
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
        // TODO: Implement full algorithm from spec
        // For now, return disconnected
        _ = self;
        _ = other;
        return DOCUMENT_POSITION_DISCONNECTED;
    }

    /// isEqualNode(otherNode)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-isequalnode
    pub fn call_isEqualNode(self: *const Node, other_node: ?*const Node) bool {
        if (other_node == null) return false;
        // TODO: Implement deep equality check per spec
        const other = other_node.?;
        if (self.node_type != other.node_type) return false;
        if (!std.mem.eql(u8, self.node_name, other.node_name)) return false;
        // TODO: Check children, attributes, etc.
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
