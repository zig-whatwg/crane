//! Node interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-node

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");

const Allocator = std.mem.Allocator;
const EventTarget = @import("event_target").EventTarget;

/// Node WebIDL interface
pub const Node = webidl.interface(struct {
    allocator: Allocator,
    event_target: EventTarget,
    node_type: u16,
    node_name: []const u8,
    parent_node: ?*Node,
    child_nodes: infra.List(*Node),
    owner_document: ?*Document,

    const Document = @import("document").Document;

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
        return .{
            .allocator = allocator,
            .event_target = try EventTarget.init(allocator),
            .node_type = node_type,
            .node_name = node_name,
            .parent_node = null,
            .child_nodes = infra.List(*Node).init(allocator),
            .owner_document = null,
        };
    }

    pub fn deinit(self: *Node) void {
        self.event_target.deinit();
        self.child_nodes.deinit();
    }

    /// insertBefore(node, child)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-insertbefore
    pub fn call_insertBefore(self: *Node, node: *Node, child: ?*Node) !*Node {
        // TODO: Use mutation.preInsert algorithm from src/dom/mutation.zig
        // For now, basic implementation
        _ = child;
        try self.child_nodes.append(node);
        node.parent_node = self;
        return node;
    }

    /// appendChild(node)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-appendchild
    pub fn call_appendChild(self: *Node, node: *Node) !*Node {
        // TODO: Use mutation.append algorithm from src/dom/mutation.zig
        try self.child_nodes.append(node);
        node.parent_node = self;
        return node;
    }

    /// replaceChild(node, child)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-replacechild
    pub fn call_replaceChild(self: *Node, node: *Node, child: *Node) !*Node {
        // TODO: Use mutation.replace algorithm from src/dom/mutation.zig
        // For now, basic implementation
        for (self.child_nodes.items, 0..) |existing, i| {
            if (existing == child) {
                self.child_nodes.items[i] = node;
                child.parent_node = null;
                node.parent_node = self;
                return child;
            }
        }
        return error.NotFoundError;
    }

    /// removeChild(child)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-removechild
    pub fn call_removeChild(self: *Node, child: *Node) !*Node {
        // TODO: Use mutation.preRemove algorithm from src/dom/mutation.zig
        for (self.child_nodes.items, 0..) |node, i| {
            if (node == child) {
                _ = self.child_nodes.orderedRemove(i);
                child.parent_node = null;
                return child;
            }
        }
        return error.NotFoundError;
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
        _ = deep;
        // Clone the node
        return try Node.init(self.allocator, self.node_type, self.node_name);
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
}, .{
    .exposed = &.{.Window},
});

/// GetRootNodeOptions dictionary
/// Spec: https://dom.spec.whatwg.org/#dictdef-getrootnodeoptions
pub const GetRootNodeOptions = struct {
    composed: bool = false,
};
