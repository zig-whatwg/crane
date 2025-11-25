//! Slottable mixin per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#mixin-slottable

const std = @import("std");
const webidl = @import("webidl");

/// DOM §4.3.7 - Slottable mixin
///
/// Element and Text nodes are slottables. They can be assigned to slots
/// in shadow trees.
///
/// A slottable has:
/// - An associated name (a string, empty string by default)
/// - An associated assigned slot (null or a slot)
/// - An associated manual slot assignment (null or a slot)
pub const Slottable = webidl.mixin(struct {
    /// Slottable name (from "slot" attribute for elements, empty for text)
    /// DOM §4.3.7: A slottable has an associated name (a string). Unless stated otherwise it is the empty string.
    slottable_name: []const u8 = "",

    /// Currently assigned slot (null if not assigned)
    /// DOM §4.3.7: A slottable has an associated assigned slot (null or a slot).
    /// Initially null.
    assigned_slot: ?*anyopaque = null,

    /// Manual slot assignment (for manual slot assignment mode)
    /// DOM §4.3.7: A slottable has an associated manual slot assignment (null or a slot).
    /// Initially null. This is a weak reference per spec.
    manual_slot_assignment: ?*anyopaque = null,

    // ========================================================================
    // Attributes
    // ========================================================================

    /// DOM §4.3.7 - Slottable.assignedSlot
    ///
    /// Returns the slot element this slottable is assigned to, if any.
    /// Returns null if not assigned or if the shadow root is closed.
    ///
    /// Spec: https://dom.spec.whatwg.org/#dom-slottable-assignedslot
    ///
    /// The assignedSlot getter steps are to return the result of
    /// find a slot given this and with the open flag set.
    pub fn get_assignedSlot(self: *const @This()) ?*anyopaque {
        // Import dom module for algorithm access
        const dom = @import("dom");

        // Find a slot for this slottable with open flag = true
        // This means we only return slots in open shadow roots
        //
        // The "open" flag causes the algorithm to return null if the
        // shadow root's mode is "closed", providing encapsulation.
        const slot = dom.shadow_dom_algorithms.findSlot(@ptrCast(@constCast(self)), true);

        return slot;
    }

    // ========================================================================
    // Internal Methods
    // ========================================================================

    /// Get the slottable name
    pub fn getSlottableName(self: *const @This()) []const u8 {
        return self.slottable_name;
    }

    /// Set the slottable name
    /// For elements, this should be called when the "slot" attribute changes
    pub fn setSlottableName(self: *@This(), name: []const u8) void {
        self.slottable_name = name;
    }

    /// Check if this slottable is assigned to a slot
    pub fn isAssigned(self: *const @This()) bool {
        return self.assigned_slot != null;
    }

    /// Get the assigned slot (internal use, doesn't check open/closed mode)
    pub fn getAssignedSlotInternal(self: *const @This()) ?*anyopaque {
        return self.assigned_slot;
    }

    /// Set the assigned slot
    /// Called by the assign slottables algorithm
    pub fn setAssignedSlot(self: *@This(), slot: ?*anyopaque) void {
        self.assigned_slot = slot;
    }

    /// Get the manual slot assignment
    pub fn getManualSlotAssignment(self: *const @This()) ?*anyopaque {
        return self.manual_slot_assignment;
    }

    /// Set the manual slot assignment
    /// Called by HTMLSlotElement.assign() for manual slot assignment mode
    pub fn setManualSlotAssignment(self: *@This(), slot: ?*anyopaque) void {
        self.manual_slot_assignment = slot;
    }
});
