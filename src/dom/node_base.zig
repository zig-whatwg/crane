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

// Forward declarations at file scope
const DocumentType = @import("document").Document;
const RegisteredObserverType = @import("registered_observer").RegisteredObserver;

/// Base structure containing all fields from the Node interface
/// This is used as the first field in all concrete node types (Element, CharacterData, etc.)
pub const NodeBase = struct {
    // ========================================================================
    // Core Node Fields (from webidl/src/dom/Node.zig)
    // ========================================================================

    allocator: Allocator,
    node_type: u16,
    node_name: []const u8,
    parent_node: ?*NodeBase,
    child_nodes: infra.List(*NodeBase),
    owner_document: ?*DocumentType,

    /// DOM §7.1 - Registered observer list
    /// List of registered mutation observers watching this node
    registered_observers: std.ArrayList(RegisteredObserverType),

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
};

// Forward declarations for concrete types we cast to
// Using the WithBase variants until codegen is updated
const Element = @import("element_with_base.zig").ElementWithBase;
const Text = @import("text_with_base.zig").TextWithBase;
const Comment = @import("text_with_base.zig").CommentWithBase;
const AttrWithBase = @import("attr_with_base.zig").AttrWithBase;

// CharacterData is a base class for Text, Comment, etc.
// For now, we'll define a minimal stub until it's generated
// TODO: Replace with proper CharacterData once webidl codegen is updated
pub const CharacterData = struct {
    base: NodeBase,
    data: []u8,
    allocator: Allocator,

    pub fn asNode(self: *CharacterData) *NodeBase {
        return &self.base;
    }
};

// ============================================================================
// Tests
// ============================================================================
// TODO: Add proper tests once we have a complete test harness
