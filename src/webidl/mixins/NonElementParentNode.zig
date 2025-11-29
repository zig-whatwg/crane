//! NonElementParentNode Mixin
//!
//! Spec: https://dom.spec.whatwg.org/#interface-nonelementparentnode
//!
//! This mixin delegates to the NonElementParentNode impl for all functionality.
//! The impl contains the actual logic for NonElementParentNode methods.
//!
//! The NonElementParentNode mixin defines:
//! - getElementById(elementId) - Returns the first element with matching ID

const std = @import("std");
const runtime = @import("runtime");

// Import the impl which contains all the actual logic
const NonElementParentNodeImpl = @import("impls").NonElementParentNode;

pub const MixinError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

// =============================================================================
// NonElementParentNode Methods (delegate to impl)
// =============================================================================

/// getElementById - Returns the first element with matching ID
/// Spec: https://dom.spec.whatwg.org/#dom-nonelementparentnode-getelementbyid
pub fn getElementById(
    root: *runtime.Instance,
    element_id: []const u8,
) ?*runtime.Instance {
    const dom_string = runtime.DOMString.initInterned(element_id);
    return NonElementParentNodeImpl.call_getElementById(root, dom_string) catch null;
}

// =============================================================================
// Tests
// =============================================================================

test "NonElementParentNode mixin - delegation to impl" {
    // Test that mixin correctly delegates to impl
    // Full tests are in the impl file
}
