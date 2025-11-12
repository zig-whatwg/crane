//! HTMLSlotElement Mock (WHATWG HTML Standard)
//!
//! Spec: https://html.spec.whatwg.org/multipage/scripting.html#the-slot-element
//!
//! **TEMPORARY MOCK** - Located in webidl/src/html/ to separate HTML mocks from DOM.
//! This will be replaced when the full HTML specification is implemented.
//!
//! DOM §4.8.2.3: "A slot can only be created through HTML's slot element."
//! Slots are part of the shadow DOM specification and referenced by the
//! DOM Standard, but the actual <slot> element is defined in HTML.
//!
//! This mock provides minimal functionality needed for Shadow DOM slot algorithms:
//! - Slot name management
//! - Assigned nodes tracking
//! - Manual slot assignment support

const std = @import("std");
const webidl = @import("webidl");

/// HTMLSlotElement - Represents a <slot> element in shadow DOM
///
/// TODO: This is a mock implementation. Replace with full HTML spec implementation
/// when available. The full implementation will extend HTMLElement and include:
/// - Full HTML element attributes and methods
/// - Integration with HTML parsing
/// - Complete event handling
///
/// Current mock provides ONLY the minimal interface needed for shadow DOM:
/// - name attribute (slot name)
/// - assigned_nodes list (slottables assigned to this slot)
/// - manually_assigned_nodes list (for manual slot assignment mode)
pub const HTMLSlotElement = webidl.interface(struct {
    const Self = @This();

    /// Allocator for managing slot data
    allocator: std.mem.Allocator,

    /// Slot name (DOM §4.8.2.3)
    /// Default is empty string
    name: []const u8,

    /// Assigned nodes list (DOM §4.8.2.3)
    /// List of slottables assigned to this slot
    /// Initially empty, updated by assign slottables algorithm
    assigned_nodes: std.ArrayList(*anyopaque),

    /// Manually assigned nodes list (DOM §4.8.2.5)
    /// For manual slot assignment mode
    /// Initially empty
    manually_assigned_nodes: std.ArrayList(*anyopaque),

    /// Initialize a new HTMLSlotElement
    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .allocator = allocator,
            .name = "",
            .assigned_nodes = std.ArrayList(*anyopaque).init(allocator),
            .manually_assigned_nodes = std.ArrayList(*anyopaque).init(allocator),
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        if (self.name.len > 0) {
            self.allocator.free(self.name);
        }
        self.assigned_nodes.deinit();
        self.manually_assigned_nodes.deinit();
    }

    /// Set the slot name
    pub fn setName(self: *Self, name: []const u8) !void {
        if (self.name.len > 0) {
            self.allocator.free(self.name);
        }
        self.name = try self.allocator.dupe(u8, name);
    }

    /// Get the slot name
    pub fn getName(self: *const Self) []const u8 {
        return self.name;
    }

    /// Get assigned nodes list
    pub fn getAssignedNodes(self: *Self) *std.ArrayList(*anyopaque) {
        return &self.assigned_nodes;
    }

    /// Get manually assigned nodes list
    pub fn getManuallyAssignedNodes(self: *Self) *std.ArrayList(*anyopaque) {
        return &self.manually_assigned_nodes;
    }

    /// Check if this slot has any assigned nodes
    pub fn hasAssignedNodes(self: *const Self) bool {
        return self.assigned_nodes.items.len > 0;
    }
}, .{});

// ============================================================================
// Tests
// ============================================================================

test "HTMLSlotElement - initialization" {
    const allocator = std.testing.allocator;

    var slot = try HTMLSlotElement.init(allocator);
    defer slot.deinit();

    // Default name is empty string
    try std.testing.expectEqualStrings("", slot.getName());

    // Lists are initially empty
    try std.testing.expectEqual(@as(usize, 0), slot.assigned_nodes.items.len);
    try std.testing.expectEqual(@as(usize, 0), slot.manually_assigned_nodes.items.len);
    try std.testing.expect(!slot.hasAssignedNodes());
}

test "HTMLSlotElement - set and get name" {
    const allocator = std.testing.allocator;

    var slot = try HTMLSlotElement.init(allocator);
    defer slot.deinit();

    try slot.setName("header");
    try std.testing.expectEqualStrings("header", slot.getName());

    // Change name
    try slot.setName("footer");
    try std.testing.expectEqualStrings("footer", slot.getName());
}

test "HTMLSlotElement - assigned nodes" {
    const allocator = std.testing.allocator;

    var slot = try HTMLSlotElement.init(allocator);
    defer slot.deinit();

    // Add some mock nodes
    var dummy1: u32 = 1;
    var dummy2: u32 = 2;

    try slot.assigned_nodes.append(@ptrCast(&dummy1));
    try slot.assigned_nodes.append(@ptrCast(&dummy2));

    try std.testing.expect(slot.hasAssignedNodes());
    try std.testing.expectEqual(@as(usize, 2), slot.assigned_nodes.items.len);
}
