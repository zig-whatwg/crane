//! NonDocumentTypeChildNode Mixin
//!
//! Spec: https://dom.spec.whatwg.org/#interface-nondocumenttypechildnode
//!
//! This mixin delegates to the NonDocumentTypeChildNode impl for all functionality.
//! The impl contains the actual logic for NonDocumentTypeChildNode methods.
//!
//! The NonDocumentTypeChildNode mixin defines:
//! - previousElementSibling - Returns the previous sibling that is an element
//! - nextElementSibling - Returns the next sibling that is an element

const std = @import("std");
const runtime = @import("runtime");

// Import the impl which contains all the actual logic
const NonDocumentTypeChildNodeImpl = @import("impls").NonDocumentTypeChildNode;

pub const MixinError = error{
    NotImplemented,
    InvalidStateError,
};

// =============================================================================
// NonDocumentTypeChildNode Attributes (delegate to impl)
// =============================================================================

/// previousElementSibling - Returns the previous sibling that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-previouselementsibling
pub fn previousElementSibling(node: *runtime.Instance) ?*runtime.Instance {
    return NonDocumentTypeChildNodeImpl.get_previousElementSibling(node) catch null;
}

/// nextElementSibling - Returns the next sibling that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-nextelementsibling
pub fn nextElementSibling(node: *runtime.Instance) ?*runtime.Instance {
    return NonDocumentTypeChildNodeImpl.get_nextElementSibling(node) catch null;
}

// =============================================================================
// Tests
// =============================================================================

test "NonDocumentTypeChildNode mixin - delegation to impl" {
    // Test that mixin correctly delegates to impl
    // Full tests are in the impl file
}
