//! NonDocumentTypeChildNode Mixin Implementation
//!
//! Spec: https://dom.spec.whatwg.org/#interface-nondocumenttypechildnode
//!
//! This mixin provides sibling element accessors for Element and CharacterData.
//!
//! The NonDocumentTypeChildNode mixin defines:
//! - previousElementSibling - Returns the previous sibling that is an element
//! - nextElementSibling - Returns the next sibling that is an element

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

// Import impl modules for accessing internal state
const impls = @import("impls");
const NodeImpl = impls.Node;

pub const MixinError = error{
    NotImplemented,
    InvalidStateError,
};

// =============================================================================
// NonDocumentTypeChildNode Attributes
// =============================================================================

/// previousElementSibling - Returns the previous sibling that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-previouselementsibling
///
/// Returns the first preceding sibling that is an element, or null if none exists.
pub fn previousElementSibling(node: *runtime.Instance) ?*runtime.Instance {
    var sibling = NodeImpl.getPreviousSibling(node);
    while (sibling) |s| {
        const node_type = NodeImpl.getNodeType(s) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            return s;
        }
        sibling = NodeImpl.getPreviousSibling(s);
    }
    return null;
}

/// nextElementSibling - Returns the next sibling that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-nextelementsibling
///
/// Returns the first following sibling that is an element, or null if none exists.
pub fn nextElementSibling(node: *runtime.Instance) ?*runtime.Instance {
    var sibling = NodeImpl.getNextSibling(node);
    while (sibling) |s| {
        const node_type = NodeImpl.getNodeType(s) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            return s;
        }
        sibling = NodeImpl.getNextSibling(s);
    }
    return null;
}

// =============================================================================
// Tests
// =============================================================================

test "NonDocumentTypeChildNode mixin - previousElementSibling" {
    // Test would require setting up runtime instances
    // Placeholder for now
}

test "NonDocumentTypeChildNode mixin - nextElementSibling" {
    // Test would require setting up runtime instances
    // Placeholder for now
}
