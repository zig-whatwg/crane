//! NodeBase - Base type for WebIDL interface inheritance (Node hierarchy)
//!
//! This provides a flat memory layout for the Node inheritance hierarchy,
//! enabling safe downcasting between Node types (Node, Element, CharacterData, etc.)
//!
//! Design Pattern: Flat Memory Layout with Type Header
//! - All concrete node types (Element, CharacterData, etc.) have NodeBase as FIRST field
//! - This allows safe @ptrCast between NodeBase* and concrete types
//! - Runtime type checking via node_type ensures type safety
//!
//! Spec: https://dom.spec.whatwg.org/#interface-node

const std = @import("std");
const infra = @import("infra");
const Allocator = std.mem.Allocator;
const interfaces = @import("interfaces");

// Forward declarations at file scope
const DocumentType = interfaces.Document;
pub const RegisteredObserverType = @import("registered_observer.zig").RegisteredObserver;

/// Base structure containing all fields from the Node interface
/// This is used as the first field in all concrete node types (Element, CharacterData, etc.)
pub const NodeBase = struct {
    // ========================================================================
    // Core Node Fields (from webidl/src/dom/Node.zig)
    // ========================================================================

    allocator: Allocator,

    /// The runtime.Instance that owns this NodeBase, or null for a NodeBase built
    /// outside the WebIDL layer.
    ///
    /// Stored here rather than in a side table. This replaced the global
    /// `nodebase_to_instance: AutoHashMap(*NodeBase, *anyopaque)` in
    /// src/dom/instance_bridge.zig: a process-wide mutable map on page_allocator,
    /// explicitly documented as "NOT thread-safe", consulted 37 times across the DOM
    /// hot path. The owning instance is a property OF the node, so it belongs on the
    /// node - which also makes it die with the node instead of needing an unregister
    /// call to avoid leaking an entry.
    ///
    /// Typed `?*anyopaque` to keep src/dom free of a hard dependency on the concrete
    /// runtime.Instance type, matching the bridge API it replaces.
    owner_instance: ?*anyopaque = null,

    node_type: u16,
    node_name: []const u8,
    /// Tracks whether node_name was dynamically allocated (vs a string literal).
    /// Used to determine if node_name should be freed during cleanup.
    node_name_allocated: bool = false,

    // Tree structure - BOTH patterns for O(1) access in all directions
    // Parent pointer
    parent_node: ?*NodeBase = null,

    // Sibling pointers - O(1) sibling navigation (Phase 1 addition)
    first_child: ?*NodeBase = null,
    last_child: ?*NodeBase = null,
    previous_sibling: ?*NodeBase = null,
    next_sibling: ?*NodeBase = null,

    // Child list - O(1) index access and iteration
    child_nodes: infra.List(*NodeBase),

    // Document ownership
    owner_document: ?*DocumentType = null,

    /// DOM §7.1 - Registered observer list
    /// List of registered mutation observers watching this node
    registered_observers: infra.List(RegisteredObserverType),

    /// Connection status - true when root is a document
    /// Used by isConnected getter
    is_connected: bool = false,

    /// Whether this element is a shadow host: set by "attach a shadow root"
    /// (Element's attachShadow, the one step every shadow root attaches
    /// through), never cleared - a shadow root is never detached. A guard
    /// for the insert and remove steps' slot steps, so a tree with no shadow
    /// root pays a field test for them (Blink's HasShadowRoot bit); the
    /// shadow root itself is the Element state's, which stays the source of
    /// truth (dom.shadow_hosts.rootForHost).
    is_shadow_host: bool = false,

    /// The holds on this node (src/dom/node_holds.zig): the head of a chain
    /// of every holder's hold on it - a MutationRecord's, a static
    /// NodeList's - or null when nothing holds it. The removing steps test it
    /// for each node a removal visits, so a removal of a subtree nothing in
    /// which is held pays one field test per node; when something is, the
    /// chain names exactly the holders that must rescue the subtree's root.
    holds: ?*@import("node_holds.zig").Hold = null,

    /// The reference count word, WebKit's encoding (Source/WebCore/dom/Node.h
    /// `m_refCountAndParentBit`): bit 0 is the parent bit (this node has a
    /// parent), the rest is the count of references held through `Ref`, in
    /// units of `rc_one`. A node is born with one reference, its creator's.
    /// Maintained only through src/dom/refcount.zig; nothing reads it for
    /// lifetime yet (tmp/plans/refcount-design.md, steps 2 to 6: shadow mode).
    /// Non-atomic: nodes belong to one agent's thread.
    rc: u32 = rc_one,

    /// The number of held nodes - nodes whose count is not zero - in this
    /// node's host-including subtree, itself included: decision D1 (a held node
    /// keeps its whole tree) as arithmetic. A tree is garbage when its root's
    /// total is 0. A node is born held (`rc_one`), so it starts at 1.
    subtree_holds: u32 = 1,

    /// The reference counting state that is not a number (see RcFlags).
    rc_flags: RcFlags = .{},

    /// V8 wrapper for cross-context identity
    /// When set, this wrapper is returned for ALL contexts to ensure `===` identity works.
    /// Solves the problem where MutationObserver addedNodes[0] !== original element
    /// because different contexts were creating different wrappers for the same instance.
    bound_v8_wrapper: ?*anyopaque = null,

    // ========================================================================
    // Reference counting (tmp/plans/refcount-design.md section 1)
    // ========================================================================

    /// One reference in `rc`'s units (WebKit `s_refCountIncrement`).
    pub const rc_one: u32 = 2;
    /// `rc`'s parent bit (WebKit `s_refCountMask` is its complement).
    pub const rc_parent_bit: u32 = 1;

    /// The booleans the count machinery keeps beside the numbers.
    pub const RcFlags = packed struct(u8) {
        /// The node is the root of a tree whose total reached zero and which
        /// is queued for teardown: a `Ref` taken on it is a bug, and a
        /// `WeakRef` reads it as gone.
        garbage: bool = false,
        /// The node is being torn down (WebKit
        /// `applyRefDuringDestructionCheck`): a `Ref` taken on it is a bug.
        destroying: bool = false,
        /// A parentless shadow root or template contents whose host is
        /// alive: its holds count in its host's chain (design 1.4, the
        /// host-including chain). Set and cleared only by refcount.zig.
        hosted: bool = false,
        /// A parentless, unhosted node that is not a Document and has a
        /// node document: the root of a detached tree, whose
        /// `subtree_holds` count in its document's `foreign_holds`
        /// (decision D6). Set and cleared only by refcount.zig.
        foreign: bool = false,
        /// The reference the node was born with (`rc_one`) is still its
        /// creator's, offered to whoever takes the node on first
        /// (refcount7; refcount design 1.2, "the creator of a node until it
        /// hands the node on"): its first wrapper adopts it - WebKit's
        /// binding moves the `Ref` a create function returned into the new
        /// wrapper (bindings/js/JSDOMWrapperCache.h `createWrapper`,
        /// "domObject is moved into the wrapper") - or, inserted first, the
        /// tree takes the node over and the creator's reference ends, as a
        /// WebKit creator's `Ref` ends at its scope after the append (the
        /// parent bit keeps the node). Clear from birth on a Document, whose
        /// creator keeps it (a navigable's, until step 5i) unless it hands
        /// the document to script (`refcount.offerCreatorReference`), and
        /// once a creator that hands its reference on itself has claimed it
        /// (the HTML parser, decision D-A). Set and cleared only by
        /// refcount.zig.
        creator: bool = true,
        _unused: u3 = 0,
    };

    /// The one write of `parent_node` (WebKit `Node::setParentNode`): the
    /// pointer and the parent bit of `rc` together. The holds a link moves
    /// are refcount.zig's (`linkChild`, `unlinkChild`, `moveChild`); this is
    /// only the write, which `zig build lint-refcount` allows nowhere else.
    pub fn setParent(self: *NodeBase, parent: ?*NodeBase) void {
        self.parent_node = parent;
        self.rc = (self.rc & ~rc_parent_bit) | @intFromBool(parent != null);
    }

    // ========================================================================
    // Node Type Constants (DOM Spec §5.1)
    // ========================================================================

    pub const ELEMENT_NODE: u16 = 1;
    pub const ATTRIBUTE_NODE: u16 = 2;
    pub const TEXT_NODE: u16 = 3;
    pub const CDATA_SECTION_NODE: u16 = 4;
    pub const ENTITY_REFERENCE_NODE: u16 = 5; // Historical
    pub const ENTITY_NODE: u16 = 6; // Historical
    pub const PROCESSING_INSTRUCTION_NODE: u16 = 7;
    pub const COMMENT_NODE: u16 = 8;
    pub const DOCUMENT_NODE: u16 = 9;
    pub const DOCUMENT_TYPE_NODE: u16 = 10;
    pub const DOCUMENT_FRAGMENT_NODE: u16 = 11;
    pub const NOTATION_NODE: u16 = 12; // Historical

    // ========================================================================
    // Document Position Constants (DOM Spec §5.8)
    // ========================================================================

    pub const DOCUMENT_POSITION_DISCONNECTED: u16 = 0x01;
    pub const DOCUMENT_POSITION_PRECEDING: u16 = 0x02;
    pub const DOCUMENT_POSITION_FOLLOWING: u16 = 0x04;
    pub const DOCUMENT_POSITION_CONTAINS: u16 = 0x08;
    pub const DOCUMENT_POSITION_CONTAINED_BY: u16 = 0x10;
    pub const DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC: u16 = 0x20;

    // ========================================================================
    // Safe Downcasting Utilities
    // ========================================================================

    /// Safely cast NodeBase to Element (using ElementWithBase temporarily)
    pub fn asElement(node: *NodeBase) ?*Element {
        if (node.node_type != ELEMENT_NODE) return null;
        // Safe: Element has NodeBase as first field, so addresses are identical
        return @ptrCast(node);
    }

    /// Safely cast const NodeBase to const Element
    pub fn asElementConst(node: *const NodeBase) ?*const Element {
        if (node.node_type != ELEMENT_NODE) return null;
        return @ptrCast(node);
    }

    /// Safely cast NodeBase to CharacterData
    /// Returns null if node is not a CharacterData-based node
    pub fn asCharacterData(node: *NodeBase) ?*CharacterData {
        const is_text_like = node.node_type == TEXT_NODE or
            node.node_type == CDATA_SECTION_NODE or
            node.node_type == COMMENT_NODE;
        if (!is_text_like) return null;
        return @ptrCast(node);
    }

    /// Safely cast const NodeBase to const CharacterData
    pub fn asCharacterDataConst(node: *const NodeBase) ?*const CharacterData {
        const is_text_like = node.node_type == TEXT_NODE or
            node.node_type == CDATA_SECTION_NODE or
            node.node_type == COMMENT_NODE;
        if (!is_text_like) return null;
        return @ptrCast(node);
    }

    /// Safely cast NodeBase to Text
    pub fn asText(node: *NodeBase) ?*Text {
        if (node.node_type != TEXT_NODE) return null;
        return @ptrCast(node);
    }

    /// Safely cast NodeBase to Comment
    pub fn asComment(node: *NodeBase) ?*Comment {
        if (node.node_type != COMMENT_NODE) return null;
        return @ptrCast(node);
    }

    /// Safely cast NodeBase to Attr (using AttrWithBase temporarily)
    pub fn asAttr(node: *NodeBase) ?*AttrWithBase {
        if (node.node_type != ATTRIBUTE_NODE) return null;
        return @ptrCast(node);
    }

    /// Safely cast const NodeBase to const Attr
    pub fn asAttrConst(node: *const NodeBase) ?*const AttrWithBase {
        if (node.node_type != ATTRIBUTE_NODE) return null;
        return @ptrCast(node);
    }

    /// Safely cast NodeBase to Document
    pub fn asDocument(node: *NodeBase) ?*DocumentType {
        if (node.node_type != DOCUMENT_NODE) return null;
        return @ptrCast(node);
    }

    // ========================================================================
    // Common Node Operations
    // ========================================================================

    /// Get the root node (walk up to parent until we reach the root)
    /// DOM Spec: https://dom.spec.whatwg.org/#concept-tree-root
    pub fn getRoot(self: *NodeBase) *NodeBase {
        var current = self;
        while (current.parent_node) |parent| {
            current = parent;
        }
        return current;
    }

    /// Check if this node contains another node
    /// DOM Spec: https://dom.spec.whatwg.org/#dom-node-contains
    pub fn contains(self: *const NodeBase, other: ?*const NodeBase) bool {
        if (other == null) return false;
        const other_node = other.?;
        if (self == other_node) return true;

        var current = other_node.parent_node;
        while (current) |parent| {
            if (parent == self) return true;
            current = parent.parent_node;
        }
        return false;
    }

    /// Check if node is connected (root is a document)
    /// DOM Spec: https://dom.spec.whatwg.org/#connected
    pub fn isConnected(self: *const NodeBase) bool {
        var current = self;
        while (current.parent_node) |parent| {
            current = parent;
        }
        return current.node_type == DOCUMENT_NODE;
    }

    /// Get the node document for this node
    /// DOM Spec: https://dom.spec.whatwg.org/#concept-node-document
    ///
    /// Per spec §4.2.5:
    /// - Every node has an associated node document (set upon creation)
    /// - For Document nodes, the node document is itself
    /// - Can ONLY be changed by the adopt algorithm
    /// - NEVER null at any time after creation
    ///
    /// Note: Returns null only during node construction before document assignment.
    /// After proper initialization, this should never return null.
    pub fn getNodeDocument(self: *NodeBase) ?*DocumentType {
        // For Document nodes, the node document is itself
        if (self.node_type == DOCUMENT_NODE) {
            return @ptrCast(self);
        }
        return self.owner_document;
    }

    /// Get the node document for this node (const version)
    pub fn getNodeDocumentConst(self: *const NodeBase) ?*const DocumentType {
        if (self.node_type == DOCUMENT_NODE) {
            return @ptrCast(self);
        }
        return self.owner_document;
    }
};

// Forward declarations for concrete types we cast to
// Using the WithBase variants until codegen is updated for XPath/selectors
const Element = @import("element_with_base.zig").ElementWithBase;
const Text = @import("text_with_base.zig").TextWithBase;
const Comment = @import("text_with_base.zig").CommentWithBase;
const AttrWithBase = @import("attr_with_base.zig").AttrWithBase;

// CharacterData from generated WebIDL interfaces
// Has NodeBase as first field, enabling safe downcasting
pub const CharacterData = interfaces.CharacterData;

// ============================================================================
// Tests
// ============================================================================
// NodeBase is tested via the concrete node types (Element, CharacterData, etc.)
// See tests/dom/ for comprehensive node hierarchy tests
