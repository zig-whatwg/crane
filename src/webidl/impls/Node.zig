//! Implementation for Node interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-node
//! WHATWG DOM Standard §4.4
//!
//! Node is the primary datatype for the entire DOM. It represents a single node
//! in the document tree. Node extends EventTarget, so all nodes can receive events.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const infra = @import("infra");
const Node = interfaces.Node;

pub const State = Node.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    HierarchyRequestError,
    NotFoundError,
    OutOfMemory,
};

/// DOM §4.4 Node types
/// https://dom.spec.whatwg.org/#node
pub const NodeType = struct {
    pub const ELEMENT_NODE: u16 = 1;
    pub const ATTRIBUTE_NODE: u16 = 2;
    pub const TEXT_NODE: u16 = 3;
    pub const CDATA_SECTION_NODE: u16 = 4;
    pub const ENTITY_REFERENCE_NODE: u16 = 5; // legacy
    pub const ENTITY_NODE: u16 = 6; // legacy
    pub const PROCESSING_INSTRUCTION_NODE: u16 = 7;
    pub const COMMENT_NODE: u16 = 8;
    pub const DOCUMENT_NODE: u16 = 9;
    pub const DOCUMENT_TYPE_NODE: u16 = 10;
    pub const DOCUMENT_FRAGMENT_NODE: u16 = 11;
    pub const NOTATION_NODE: u16 = 12; // legacy
};

/// Document position flags for compareDocumentPosition
/// https://dom.spec.whatwg.org/#dom-node-comparedocumentposition
pub const DocumentPosition = struct {
    pub const DISCONNECTED: u16 = 0x01;
    pub const PRECEDING: u16 = 0x02;
    pub const FOLLOWING: u16 = 0x04;
    pub const CONTAINS: u16 = 0x08;
    pub const CONTAINED_BY: u16 = 0x10;
    pub const IMPLEMENTATION_SPECIFIC: u16 = 0x20;
};

/// Internal state for Node implementation
/// Node uses a tree structure with parent, first child, last child, and sibling pointers
/// This is the standard representation used in all major browser engines.
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The type of this node (ELEMENT_NODE, TEXT_NODE, etc.)
    /// This determines behavior of many getters (nodeName, nodeValue, textContent)
    node_type: u16 = NodeType.ELEMENT_NODE,

    /// The local name for Element nodes, target for PI nodes, etc.
    /// Used by nodeName getter
    local_name: ?runtime.DOMString = null,

    /// The namespace URI for Element nodes
    namespace_uri: ?runtime.DOMString = null,

    /// The namespace prefix for Element nodes
    prefix: ?runtime.DOMString = null,

    /// The node value (for Text, Comment, CDATA, PI, Attr nodes)
    /// For Element and Document nodes, this is always null
    node_value: ?runtime.DOMString = null,

    /// Tree pointers - standard browser engine representation
    parent: ?*runtime.Instance = null,
    first_child: ?*runtime.Instance = null,
    last_child: ?*runtime.Instance = null,
    previous_sibling: ?*runtime.Instance = null,
    next_sibling: ?*runtime.Instance = null,

    /// The owner document for this node
    /// Document nodes return null from ownerDocument getter
    owner_document: ?*runtime.Instance = null,

    /// Cached childNodes NodeList (lazily created)
    /// This is a live NodeList that reflects changes to the tree
    child_nodes_list: ?*runtime.Instance = null,

    /// For tracking if node is in a document tree (for isConnected)
    /// A node is connected when its root is a document
    is_connected: bool = false,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InternalState) void {
        if (self.local_name) |*name| {
            name.deinit(self.allocator);
        }
        if (self.namespace_uri) |*uri| {
            uri.deinit(self.allocator);
        }
        if (self.prefix) |*p| {
            p.deinit(self.allocator);
        }
        if (self.node_value) |*val| {
            val.deinit(self.allocator);
        }
        // Note: child_nodes_list is managed separately via deinit
    }
};

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Get or create the EventTarget internal state (for event handling)
/// Note: In the runtime system, EventTarget state access depends on how
/// inheritance is flattened. For now, return null as this needs proper
/// integration with the codegen's inheritance model.
fn getEventTargetInternal(instance: *runtime.Instance) ?*@import("EventTarget.zig").InternalState {
    _ = instance;
    // TODO: Access EventTarget's internal state via proper inheritance mechanism
    return null;
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize internal state
    const state = instance.getState(StateType);
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;

    // Note: EventTarget's internal state initialization is handled by the
    // codegen's inheritance mechanism. Each interface in the chain initializes
    // its own _internal state.

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    // EventTarget cleanup happens via inheritance chain
    runtime.Instance.deinit(instance);
}

// =============================================================================
// Getters
// =============================================================================

/// Getter for nodeType
/// https://dom.spec.whatwg.org/#dom-node-nodetype
/// Returns an integer corresponding to the type of the node
pub fn get_nodeType(instance: *runtime.Instance) !u16 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.node_type;
}

/// Getter for nodeName
/// https://dom.spec.whatwg.org/#dom-node-nodename
/// Returns a string appropriate for the type of node
pub fn get_nodeName(instance: *runtime.Instance) !runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    return switch (internal.node_type) {
        NodeType.ELEMENT_NODE => blk: {
            // For Element: its HTML-uppercased qualified name
            if (internal.local_name) |name| {
                // TODO: Properly uppercase for HTML elements
                break :blk name;
            }
            break :blk runtime.DOMString.initEmpty();
        },
        NodeType.ATTRIBUTE_NODE => blk: {
            // For Attr: its qualified name
            if (internal.local_name) |name| {
                break :blk name;
            }
            break :blk runtime.DOMString.initEmpty();
        },
        NodeType.TEXT_NODE => runtime.DOMString.initInterned("#text"),
        NodeType.CDATA_SECTION_NODE => runtime.DOMString.initInterned("#cdata-section"),
        NodeType.PROCESSING_INSTRUCTION_NODE => blk: {
            // For ProcessingInstruction: its target
            if (internal.local_name) |name| {
                break :blk name;
            }
            break :blk runtime.DOMString.initEmpty();
        },
        NodeType.COMMENT_NODE => runtime.DOMString.initInterned("#comment"),
        NodeType.DOCUMENT_NODE => runtime.DOMString.initInterned("#document"),
        NodeType.DOCUMENT_TYPE_NODE => blk: {
            // For DocumentType: its name
            if (internal.local_name) |name| {
                break :blk name;
            }
            break :blk runtime.DOMString.initEmpty();
        },
        NodeType.DOCUMENT_FRAGMENT_NODE => runtime.DOMString.initInterned("#document-fragment"),
        else => runtime.DOMString.initEmpty(),
    };
}

/// Getter for baseURI
/// https://dom.spec.whatwg.org/#dom-node-baseuri
/// Returns the node's document's document base URL, serialized
pub fn get_baseURI(instance: *runtime.Instance) !runtime.USVString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Get the owner document and its base URL
    if (internal.owner_document) |_| {
        // TODO: Get document.baseURI from owner document
        // For now, return empty string
        return runtime.USVString.initEmpty();
    }

    // If this is a Document node, get its own base URL
    if (internal.node_type == NodeType.DOCUMENT_NODE) {
        // TODO: Return document's base URL
        return runtime.USVString.initEmpty();
    }

    return runtime.USVString.initEmpty();
}

/// Getter for isConnected
/// https://dom.spec.whatwg.org/#dom-node-isconnected
/// Returns true if the node is connected (its root is a document)
pub fn get_isConnected(instance: *runtime.Instance) !bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.is_connected;
}

/// Getter for ownerDocument
/// https://dom.spec.whatwg.org/#dom-node-ownerdocument
/// Returns the document that the node belongs to, or null for Document nodes
pub fn get_ownerDocument(instance: *runtime.Instance) !*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Document nodes return null
    if (internal.node_type == NodeType.DOCUMENT_NODE) {
        return error.NotImplemented; // Return null via nullable mechanism
    }

    if (internal.owner_document) |doc| {
        return doc;
    }

    return error.NotImplemented; // Return null
}

/// Getter for parentNode
/// https://dom.spec.whatwg.org/#dom-node-parentnode
pub fn get_parentNode(instance: *runtime.Instance) !*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.parent) |parent| {
        return parent;
    }
    return error.NotImplemented; // Return null
}

/// Getter for parentElement
/// https://dom.spec.whatwg.org/#dom-node-parentelement
/// Returns parent if parent is an Element, otherwise null
pub fn get_parentElement(instance: *runtime.Instance) !*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    if (internal.parent) |parent| {
        const parent_internal = getInternal(parent) orelse return error.NotImplemented;
        if (parent_internal.node_type == NodeType.ELEMENT_NODE) {
            return parent;
        }
    }

    return error.NotImplemented; // Return null
}

/// Getter for childNodes
/// https://dom.spec.whatwg.org/#dom-node-childnodes
/// Returns a live NodeList of child nodes
pub fn get_childNodes(instance: *runtime.Instance) !*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return cached NodeList if it exists
    if (internal.child_nodes_list) |list| {
        return list;
    }

    // TODO: Create a live NodeList for this node's children
    // This requires NodeList implementation with live collection support
    return error.NotImplemented;
}

/// Getter for firstChild
/// https://dom.spec.whatwg.org/#dom-node-firstchild
pub fn get_firstChild(instance: *runtime.Instance) !*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.first_child) |child| {
        return child;
    }
    return error.NotImplemented; // Return null
}

/// Getter for lastChild
/// https://dom.spec.whatwg.org/#dom-node-lastchild
pub fn get_lastChild(instance: *runtime.Instance) !*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.last_child) |child| {
        return child;
    }
    return error.NotImplemented; // Return null
}

/// Getter for previousSibling
/// https://dom.spec.whatwg.org/#dom-node-previoussibling
pub fn get_previousSibling(instance: *runtime.Instance) !*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.previous_sibling) |sibling| {
        return sibling;
    }
    return error.NotImplemented; // Return null
}

/// Getter for nextSibling
/// https://dom.spec.whatwg.org/#dom-node-nextsibling
pub fn get_nextSibling(instance: *runtime.Instance) !*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.next_sibling) |sibling| {
        return sibling;
    }
    return error.NotImplemented; // Return null
}

/// Getter for nodeValue
/// https://dom.spec.whatwg.org/#dom-node-nodevalue
/// Returns/sets the value of the node depending on node type
pub fn get_nodeValue(instance: *runtime.Instance) !runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    return switch (internal.node_type) {
        NodeType.ATTRIBUTE_NODE,
        NodeType.TEXT_NODE,
        NodeType.CDATA_SECTION_NODE,
        NodeType.PROCESSING_INSTRUCTION_NODE,
        NodeType.COMMENT_NODE,
        => blk: {
            if (internal.node_value) |val| {
                break :blk val;
            }
            break :blk runtime.DOMString.initEmpty();
        },
        // For Element, Document, DocumentType, DocumentFragment: null
        else => runtime.DOMString.initEmpty(),
    };
}

/// Getter for textContent
/// https://dom.spec.whatwg.org/#dom-node-textcontent
/// Returns the text content of the node and its descendants
pub fn get_textContent(instance: *runtime.Instance) !runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    return switch (internal.node_type) {
        NodeType.DOCUMENT_NODE, NodeType.DOCUMENT_TYPE_NODE => {
            // Returns null
            return runtime.DOMString.initEmpty();
        },
        NodeType.ATTRIBUTE_NODE,
        NodeType.TEXT_NODE,
        NodeType.CDATA_SECTION_NODE,
        NodeType.PROCESSING_INSTRUCTION_NODE,
        NodeType.COMMENT_NODE,
        => blk: {
            // Returns the node's data
            if (internal.node_value) |val| {
                break :blk val;
            }
            break :blk runtime.DOMString.initEmpty();
        },
        NodeType.ELEMENT_NODE, NodeType.DOCUMENT_FRAGMENT_NODE => {
            // Returns concatenation of descendant text content
            // TODO: Implement tree traversal to collect text
            return error.NotImplemented;
        },
        else => runtime.DOMString.initEmpty(),
    };
}

// =============================================================================
// Setters
// =============================================================================

/// Setter for nodeValue
/// https://dom.spec.whatwg.org/#dom-node-nodevalue
pub fn set_nodeValue(instance: *runtime.Instance, value: runtime.DOMString) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    switch (internal.node_type) {
        NodeType.ATTRIBUTE_NODE,
        NodeType.TEXT_NODE,
        NodeType.CDATA_SECTION_NODE,
        NodeType.PROCESSING_INSTRUCTION_NODE,
        NodeType.COMMENT_NODE,
        => {
            // Free old value if it exists
            if (internal.node_value) |*old| {
                old.deinit(internal.allocator);
            }
            // Clone and store new value
            internal.node_value = try value.clone(internal.allocator);
        },
        // For Element, Document, etc: do nothing
        else => {},
    }
}

/// Setter for textContent
/// https://dom.spec.whatwg.org/#dom-node-textcontent
pub fn set_textContent(instance: *runtime.Instance, value: runtime.DOMString) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    switch (internal.node_type) {
        NodeType.DOCUMENT_NODE, NodeType.DOCUMENT_TYPE_NODE => {
            // Do nothing
        },
        NodeType.ATTRIBUTE_NODE,
        NodeType.TEXT_NODE,
        NodeType.CDATA_SECTION_NODE,
        NodeType.PROCESSING_INSTRUCTION_NODE,
        NodeType.COMMENT_NODE,
        => {
            // Replace data with value
            if (internal.node_value) |*old| {
                old.deinit(internal.allocator);
            }
            internal.node_value = try value.clone(internal.allocator);
        },
        NodeType.ELEMENT_NODE, NodeType.DOCUMENT_FRAGMENT_NODE => {
            // Remove all children, then append a Text node with value
            // TODO: Implement removeAllChildren and createTextNode
            return error.NotImplemented;
        },
        else => {},
    }
}

// =============================================================================
// Operations
// =============================================================================

/// Operation: hasChildNodes
/// https://dom.spec.whatwg.org/#dom-node-haschildnodes
pub fn call_hasChildNodes(instance: *runtime.Instance) !bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.first_child != null;
}

/// Operation: getRootNode
/// https://dom.spec.whatwg.org/#dom-node-getrootnode
pub fn call_getRootNode(instance: *runtime.Instance, options: dictionaries.GetRootNodeOptions) !*runtime.Instance {
    var current = instance;
    var current_internal = getInternal(current) orelse return error.InvalidStateError;

    // If composed is true and this is in a shadow tree, get the composed root
    // TODO: Handle shadow DOM composed root when ShadowRoot is implemented
    _ = options.composed;

    // Walk up the tree to find the root
    while (current_internal.parent) |parent| {
        current = parent;
        current_internal = getInternal(current) orelse return current;
    }

    return current;
}

/// Operation: contains
/// https://dom.spec.whatwg.org/#dom-node-contains
/// Returns true if other is an inclusive descendant of this node
pub fn call_contains(instance: *runtime.Instance, other: *runtime.Instance) !bool {
    // A node contains itself
    if (instance == other) return true;

    // Walk up from other to see if we find instance
    var current: ?*runtime.Instance = other;
    while (current) |curr| {
        if (curr == instance) return true;
        const curr_internal = getInternal(curr) orelse break;
        current = curr_internal.parent;
    }

    return false;
}

/// Operation: compareDocumentPosition
/// https://dom.spec.whatwg.org/#dom-node-comparedocumentposition
pub fn call_compareDocumentPosition(instance: *runtime.Instance, other: *runtime.Instance) !u16 {
    // Same node
    if (instance == other) return 0;

    const self_internal = getInternal(instance) orelse return DocumentPosition.DISCONNECTED;
    const other_internal = getInternal(other) orelse return DocumentPosition.DISCONNECTED;

    // Check if disconnected (different trees)
    var self_root = instance;
    var self_root_internal = self_internal;
    while (self_root_internal.parent) |parent| {
        self_root = parent;
        self_root_internal = getInternal(self_root) orelse break;
    }

    var other_root = other;
    var other_root_internal = other_internal;
    while (other_root_internal.parent) |parent| {
        other_root = parent;
        other_root_internal = getInternal(other_root) orelse break;
    }

    if (self_root != other_root) {
        // Disconnected - use pointer comparison for consistent ordering
        const self_ptr = @intFromPtr(instance);
        const other_ptr = @intFromPtr(other);
        if (self_ptr < other_ptr) {
            return DocumentPosition.DISCONNECTED | DocumentPosition.FOLLOWING | DocumentPosition.IMPLEMENTATION_SPECIFIC;
        } else {
            return DocumentPosition.DISCONNECTED | DocumentPosition.PRECEDING | DocumentPosition.IMPLEMENTATION_SPECIFIC;
        }
    }

    // Check contains relationships
    if (try call_contains(instance, other)) {
        return DocumentPosition.CONTAINED_BY | DocumentPosition.FOLLOWING;
    }
    if (try call_contains(other, instance)) {
        return DocumentPosition.CONTAINS | DocumentPosition.PRECEDING;
    }

    // Find common ancestor and determine order
    // TODO: Full tree order comparison
    return DocumentPosition.FOLLOWING;
}

/// Operation: isSameNode
/// https://dom.spec.whatwg.org/#dom-node-issamenode
/// Returns true if other is the same node (reference equality)
pub fn call_isSameNode(instance: *runtime.Instance, otherNode: *runtime.Instance) !bool {
    return instance == otherNode;
}

/// Operation: isEqualNode
/// https://dom.spec.whatwg.org/#dom-node-isequalnode
/// Returns true if nodes are equal (same type, attributes, children)
pub fn call_isEqualNode(instance: *runtime.Instance, otherNode: *runtime.Instance) !bool {
    const self_internal = getInternal(instance) orelse return false;
    const other_internal = getInternal(otherNode) orelse return false;

    // Must be same node type
    if (self_internal.node_type != other_internal.node_type) return false;

    // Check type-specific equality
    switch (self_internal.node_type) {
        NodeType.DOCUMENT_TYPE_NODE => {
            // Check name, publicId, systemId
            // TODO: Compare DocumentType specific fields
        },
        NodeType.ELEMENT_NODE => {
            // Check namespace, prefix, localName, attributes count, attributes
            const self_ns = self_internal.namespace_uri;
            const other_ns = other_internal.namespace_uri;
            if (self_ns == null and other_ns != null) return false;
            if (self_ns != null and other_ns == null) return false;
            if (self_ns != null and other_ns != null) {
                if (!std.mem.eql(u8, self_ns.?.asSlice(), other_ns.?.asSlice())) return false;
            }

            const self_name = self_internal.local_name;
            const other_name = other_internal.local_name;
            if (self_name == null and other_name != null) return false;
            if (self_name != null and other_name == null) return false;
            if (self_name != null and other_name != null) {
                if (!std.mem.eql(u8, self_name.?.asSlice(), other_name.?.asSlice())) return false;
            }
            // TODO: Compare attributes
        },
        NodeType.ATTRIBUTE_NODE => {
            // Check namespace, localName, value
            // TODO: Compare Attr specific fields
        },
        NodeType.PROCESSING_INSTRUCTION_NODE => {
            // Check target, data
            const self_name = self_internal.local_name;
            const other_name = other_internal.local_name;
            if (self_name == null and other_name != null) return false;
            if (self_name != null and other_name == null) return false;
            if (self_name != null and other_name != null) {
                if (!std.mem.eql(u8, self_name.?.asSlice(), other_name.?.asSlice())) return false;
            }

            const self_val = self_internal.node_value;
            const other_val = other_internal.node_value;
            if (self_val == null and other_val != null) return false;
            if (self_val != null and other_val == null) return false;
            if (self_val != null and other_val != null) {
                if (!std.mem.eql(u8, self_val.?.asSlice(), other_val.?.asSlice())) return false;
            }
        },
        NodeType.TEXT_NODE, NodeType.COMMENT_NODE => {
            // Check data
            const self_val = self_internal.node_value;
            const other_val = other_internal.node_value;
            if (self_val == null and other_val != null) return false;
            if (self_val != null and other_val == null) return false;
            if (self_val != null and other_val != null) {
                if (!std.mem.eql(u8, self_val.?.asSlice(), other_val.?.asSlice())) return false;
            }
        },
        else => {},
    }

    // Compare children recursively
    var self_child = self_internal.first_child;
    var other_child = other_internal.first_child;

    while (self_child != null and other_child != null) {
        if (!try call_isEqualNode(self_child.?, other_child.?)) return false;

        const self_child_internal = getInternal(self_child.?) orelse break;
        const other_child_internal = getInternal(other_child.?) orelse break;
        self_child = self_child_internal.next_sibling;
        other_child = other_child_internal.next_sibling;
    }

    // Both should be null (same number of children)
    return self_child == null and other_child == null;
}

/// Operation: cloneNode
/// https://dom.spec.whatwg.org/#dom-node-clonenode
pub fn call_cloneNode(instance: *runtime.Instance, subtree: bool) !*runtime.Instance {
    _ = instance;
    _ = subtree;
    // TODO: Implement node cloning
    // This requires creating a new node with same type, attributes, etc.
    // If subtree is true, also clone all descendants
    return error.NotImplemented;
}

/// Operation: normalize
/// https://dom.spec.whatwg.org/#dom-node-normalize
/// Removes empty text nodes and merges adjacent text nodes
pub fn call_normalize(instance: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    var child = internal.first_child;
    while (child) |current_child| {
        const child_internal = getInternal(current_child) orelse {
            child = null;
            continue;
        };

        // Recursively normalize
        try call_normalize(current_child);

        // Handle text nodes
        if (child_internal.node_type == NodeType.TEXT_NODE) {
            // Remove empty text nodes
            const data = child_internal.node_value orelse runtime.DOMString.initEmpty();
            if (data.len() == 0) {
                // TODO: Remove this node
                child = child_internal.next_sibling;
                continue;
            }

            // Merge with adjacent text nodes
            while (child_internal.next_sibling) |next| {
                const next_internal = getInternal(next) orelse break;
                if (next_internal.node_type != NodeType.TEXT_NODE) break;

                // Append next's data to current and remove next
                // TODO: Implement data concatenation and node removal
                break;
            }
        }

        child = child_internal.next_sibling;
    }
}

// =============================================================================
// Tree Mutation Operations
// =============================================================================

/// Internal helper: Pre-insert validation
/// https://dom.spec.whatwg.org/#concept-node-pre-insert
fn preInsertValidation(parent: *runtime.Instance, node: *runtime.Instance, child: ?*runtime.Instance) !void {
    const parent_internal = getInternal(parent) orelse return error.InvalidStateError;
    const node_internal = getInternal(node) orelse return error.InvalidStateError;

    // 1. If parent is not a Document, DocumentFragment, or Element node, throw HierarchyRequestError
    switch (parent_internal.node_type) {
        NodeType.DOCUMENT_NODE, NodeType.DOCUMENT_FRAGMENT_NODE, NodeType.ELEMENT_NODE => {},
        else => return error.HierarchyRequestError,
    }

    // 2. If node is a host-including inclusive ancestor of parent, throw HierarchyRequestError
    var ancestor: ?*runtime.Instance = parent;
    while (ancestor) |anc| {
        if (anc == node) return error.HierarchyRequestError;
        const anc_internal = getInternal(anc) orelse break;
        ancestor = anc_internal.parent;
    }

    // 3. If child is non-null and its parent is not parent, throw NotFoundError
    if (child) |c| {
        const child_internal = getInternal(c) orelse return error.InvalidStateError;
        if (child_internal.parent != parent) return error.NotFoundError;
    }

    // 4. If node is not a DocumentFragment, DocumentType, Element, or CharacterData node, throw HierarchyRequestError
    switch (node_internal.node_type) {
        NodeType.DOCUMENT_FRAGMENT_NODE,
        NodeType.DOCUMENT_TYPE_NODE,
        NodeType.ELEMENT_NODE,
        NodeType.TEXT_NODE,
        NodeType.CDATA_SECTION_NODE,
        NodeType.PROCESSING_INSTRUCTION_NODE,
        NodeType.COMMENT_NODE,
        => {},
        else => return error.HierarchyRequestError,
    }

    // Additional Document-specific checks omitted for brevity
}

/// Internal helper: Insert a node
/// https://dom.spec.whatwg.org/#concept-node-insert
fn insertNode(node: *runtime.Instance, parent: *runtime.Instance, child: ?*runtime.Instance) !void {
    const node_internal = getInternal(node) orelse return error.InvalidStateError;
    const parent_internal = getInternal(parent) orelse return error.InvalidStateError;

    // Remove from old parent if needed
    if (node_internal.parent) |old_parent| {
        try removeNodeFromParent(node, old_parent);
    }

    // Set new parent
    node_internal.parent = parent;
    node_internal.owner_document = parent_internal.owner_document;

    // Update isConnected based on parent's connected status
    node_internal.is_connected = parent_internal.is_connected;

    if (child) |before_child| {
        // Insert before child
        const child_internal = getInternal(before_child) orelse return error.InvalidStateError;

        node_internal.next_sibling = before_child;
        node_internal.previous_sibling = child_internal.previous_sibling;

        if (child_internal.previous_sibling) |prev| {
            const prev_internal = getInternal(prev) orelse return error.InvalidStateError;
            prev_internal.next_sibling = node;
        } else {
            parent_internal.first_child = node;
        }

        child_internal.previous_sibling = node;
    } else {
        // Append at end
        node_internal.previous_sibling = parent_internal.last_child;
        node_internal.next_sibling = null;

        if (parent_internal.last_child) |last| {
            const last_internal = getInternal(last) orelse return error.InvalidStateError;
            last_internal.next_sibling = node;
        } else {
            parent_internal.first_child = node;
        }

        parent_internal.last_child = node;
    }

    // Update isConnected for descendants
    try updateConnectedStatus(node, node_internal.is_connected);
}

/// Internal helper: Remove node from parent
fn removeNodeFromParent(node: *runtime.Instance, parent: *runtime.Instance) !void {
    const node_internal = getInternal(node) orelse return error.InvalidStateError;
    const parent_internal = getInternal(parent) orelse return error.InvalidStateError;

    // Update sibling links
    if (node_internal.previous_sibling) |prev| {
        const prev_internal = getInternal(prev) orelse return error.InvalidStateError;
        prev_internal.next_sibling = node_internal.next_sibling;
    } else {
        parent_internal.first_child = node_internal.next_sibling;
    }

    if (node_internal.next_sibling) |next| {
        const next_internal = getInternal(next) orelse return error.InvalidStateError;
        next_internal.previous_sibling = node_internal.previous_sibling;
    } else {
        parent_internal.last_child = node_internal.previous_sibling;
    }

    // Clear node's parent and sibling pointers
    node_internal.parent = null;
    node_internal.previous_sibling = null;
    node_internal.next_sibling = null;

    // Update isConnected for this node and descendants
    try updateConnectedStatus(node, false);
}

/// Internal helper: Update isConnected status for node and all descendants
fn updateConnectedStatus(node: *runtime.Instance, connected: bool) !void {
    const internal = getInternal(node) orelse return error.InvalidStateError;
    internal.is_connected = connected;

    // Recursively update children
    var child = internal.first_child;
    while (child) |c| {
        try updateConnectedStatus(c, connected);
        const child_internal = getInternal(c) orelse break;
        child = child_internal.next_sibling;
    }
}

/// Operation: appendChild
/// https://dom.spec.whatwg.org/#dom-node-appendchild
pub fn call_appendChild(instance: *runtime.Instance, node: *runtime.Instance) !*runtime.Instance {
    try preInsertValidation(instance, node, null);
    try insertNode(node, instance, null);
    return node;
}

/// Operation: insertBefore
/// https://dom.spec.whatwg.org/#dom-node-insertbefore
pub fn call_insertBefore(instance: *runtime.Instance, node: *runtime.Instance, child: *runtime.Instance) !*runtime.Instance {
    try preInsertValidation(instance, node, child);
    try insertNode(node, instance, child);
    return node;
}

/// Operation: removeChild
/// https://dom.spec.whatwg.org/#dom-node-removechild
pub fn call_removeChild(instance: *runtime.Instance, child: *runtime.Instance) !*runtime.Instance {
    const child_internal = getInternal(child) orelse return error.InvalidStateError;

    // Child must be a child of this node
    if (child_internal.parent != instance) {
        return error.NotFoundError;
    }

    try removeNodeFromParent(child, instance);
    return child;
}

/// Operation: replaceChild
/// https://dom.spec.whatwg.org/#dom-node-replacechild
pub fn call_replaceChild(instance: *runtime.Instance, node: *runtime.Instance, child: *runtime.Instance) !*runtime.Instance {
    try preInsertValidation(instance, node, child);

    const child_internal = getInternal(child) orelse return error.InvalidStateError;

    // Child must be a child of this node
    if (child_internal.parent != instance) {
        return error.NotFoundError;
    }

    // Get reference to next sibling before removal
    const next_ref = child_internal.next_sibling;

    // Remove the old child
    try removeNodeFromParent(child, instance);

    // Insert the new node at the old position
    try insertNode(node, instance, next_ref);

    return child;
}

// =============================================================================
// Namespace Operations
// =============================================================================

/// Operation: lookupPrefix
/// https://dom.spec.whatwg.org/#dom-node-lookupprefix
pub fn call_lookupPrefix(instance: *runtime.Instance, namespace: runtime.DOMString) !runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    if (namespace.len() == 0) {
        return runtime.DOMString.initEmpty();
    }

    switch (internal.node_type) {
        NodeType.ELEMENT_NODE => {
            // Check this element's namespace
            if (internal.namespace_uri) |ns| {
                if (std.mem.eql(u8, ns.asSlice(), namespace.asSlice())) {
                    if (internal.prefix) |prefix| {
                        return prefix;
                    }
                }
            }
            // TODO: Check attributes and walk up tree
        },
        NodeType.DOCUMENT_NODE => {
            // Get document element and lookup on it
            if (internal.first_child) |doc_el| {
                return call_lookupPrefix(doc_el, namespace);
            }
        },
        NodeType.DOCUMENT_TYPE_NODE, NodeType.DOCUMENT_FRAGMENT_NODE => {
            return runtime.DOMString.initEmpty();
        },
        NodeType.ATTRIBUTE_NODE => {
            // Lookup on owner element
            // TODO: Get ownerElement
        },
        else => {
            // Lookup on parent element
            if (internal.parent) |parent| {
                const parent_internal = getInternal(parent) orelse return runtime.DOMString.initEmpty();
                if (parent_internal.node_type == NodeType.ELEMENT_NODE) {
                    return call_lookupPrefix(parent, namespace);
                }
            }
        },
    }

    return runtime.DOMString.initEmpty();
}

/// Operation: lookupNamespaceURI
/// https://dom.spec.whatwg.org/#dom-node-lookupnamespaceuri
pub fn call_lookupNamespaceURI(instance: *runtime.Instance, prefix: runtime.DOMString) !runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    switch (internal.node_type) {
        NodeType.ELEMENT_NODE => {
            // Check this element's namespace
            if (internal.namespace_uri) |ns| {
                const has_prefix = internal.prefix != null;
                const prefix_matches = if (internal.prefix) |p|
                    std.mem.eql(u8, p.asSlice(), prefix.asSlice())
                else
                    false;

                if (has_prefix and prefix_matches) {
                    return ns;
                }
                if (!has_prefix and prefix.len() == 0) {
                    return ns;
                }
            }
            // TODO: Check xmlns attributes and walk up tree
        },
        NodeType.DOCUMENT_NODE => {
            // Get document element and lookup on it
            if (internal.first_child) |doc_el| {
                return call_lookupNamespaceURI(doc_el, prefix);
            }
        },
        NodeType.DOCUMENT_TYPE_NODE, NodeType.DOCUMENT_FRAGMENT_NODE => {
            return runtime.DOMString.initEmpty();
        },
        NodeType.ATTRIBUTE_NODE => {
            // Lookup on owner element
            // TODO: Get ownerElement
        },
        else => {
            // Lookup on parent element
            if (internal.parent) |parent| {
                return call_lookupNamespaceURI(parent, prefix);
            }
        },
    }

    return runtime.DOMString.initEmpty();
}

/// Operation: isDefaultNamespace
/// https://dom.spec.whatwg.org/#dom-node-isdefaultnamespace
pub fn call_isDefaultNamespace(instance: *runtime.Instance, namespace: runtime.DOMString) !bool {
    const default_ns = try call_lookupNamespaceURI(instance, runtime.DOMString.initEmpty());

    if (namespace.len() == 0) {
        return default_ns.len() == 0;
    }

    return std.mem.eql(u8, default_ns.asSlice(), namespace.asSlice());
}

// =============================================================================
// Helper Functions for External Use
// =============================================================================

/// Set the node type (used by Element, Text, Comment, etc. during construction)
pub fn setNodeType(instance: *runtime.Instance, node_type: u16) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.node_type = node_type;

    // Also update EventTarget's node_type for duck typing
    if (getEventTargetInternal(instance)) |et_internal| {
        et_internal.node_type = node_type;
    }
}

/// Set the local name (used by Element, Attr, etc.)
pub fn setLocalName(instance: *runtime.Instance, name: runtime.DOMString) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.local_name) |*old| {
        old.deinit(internal.allocator);
    }
    internal.local_name = try name.clone(internal.allocator);
}

/// Set the namespace URI (used by Element, Attr)
pub fn setNamespaceURI(instance: *runtime.Instance, uri: ?runtime.DOMString) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.namespace_uri) |*old| {
        old.deinit(internal.allocator);
    }
    internal.namespace_uri = if (uri) |u| try u.clone(internal.allocator) else null;
}

/// Set the owner document
pub fn setOwnerDocument(instance: *runtime.Instance, doc: ?*runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.owner_document = doc;
}

/// Get the node type
pub fn getNodeType(instance: *runtime.Instance) ?u16 {
    const internal = getInternal(instance) orelse return null;
    return internal.node_type;
}
