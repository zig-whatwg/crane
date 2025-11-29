//! Slottable Mixin
//!
//! Spec: https://dom.spec.whatwg.org/#interface-slottable
//!
//! This mixin delegates to the Slottable impl for all functionality.
//! The impl contains the actual logic for Slottable methods.
//!
//! The Slottable mixin defines:
//! - assignedSlot - Returns the assigned slot, if any

const std = @import("std");
const runtime = @import("runtime");

// Import the impl which contains all the actual logic
const SlottableImpl = @import("impls").Slottable;

pub const MixinError = error{
    NotImplemented,
    InvalidStateError,
};

// =============================================================================
// Slottable Attributes (delegate to impl)
// =============================================================================

/// assignedSlot - Returns the slot the node is assigned to
/// Spec: https://dom.spec.whatwg.org/#dom-slottable-assignedslot
pub fn assignedSlot(node: *runtime.Instance) ?*runtime.Instance {
    return SlottableImpl.get_assignedSlot(node) catch null;
}

/// find_slot - Internal algorithm to find slot for a slottable
/// Spec: https://dom.spec.whatwg.org/#find-a-slot
pub fn findSlot(slottable: *runtime.Instance, open_flag: bool) ?*runtime.Instance {
    return SlottableImpl.findSlot(slottable, open_flag);
}

/// find_slottables - Internal algorithm to find slottables for a slot
/// Spec: https://dom.spec.whatwg.org/#find-slotables
pub fn findSlottables(allocator: std.mem.Allocator, slot: *runtime.Instance) !std.ArrayList(*runtime.Instance) {
    return SlottableImpl.findSlottables(allocator, slot);
}

// =============================================================================
// Tests
// =============================================================================

test "Slottable mixin - delegation to impl" {
    // Test that mixin correctly delegates to impl
    // Full tests are in the impl file
}
