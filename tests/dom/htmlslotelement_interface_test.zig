//! Tests migrated from webidl/src/html/dom.HTMLSlotElement.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");


test "dom.HTMLSlotElement - initialization" {
    const allocator = std.testing.allocator;

    var slot = try dom.HTMLSlotElement.init(allocator);
    defer slot.deinit();

    // Default name is empty string
    try std.testing.expectEqualStrings("", slot.getName());

    // Lists are initially empty
    try std.testing.expectEqual(@as(usize, 0), slot.assigned_nodes.items.len);
    try std.testing.expectEqual(@as(usize, 0), slot.manually_assigned_nodes.items.len);
    try std.testing.expect(!slot.hasAssignedNodes());
}
test "dom.HTMLSlotElement - set and get name" {
    const allocator = std.testing.allocator;

    var slot = try dom.HTMLSlotElement.init(allocator);
    defer slot.deinit();

    try slot.setName("header");
    try std.testing.expectEqualStrings("header", slot.getName());

    // Change name
    try slot.setName("footer");
    try std.testing.expectEqualStrings("footer", slot.getName());
}
test "dom.HTMLSlotElement - assigned nodes" {
    const allocator = std.testing.allocator;

    var slot = try dom.HTMLSlotElement.init(allocator);
    defer slot.deinit();

    // Add some mock nodes
    var dummy1: u32 = 1;
    var dummy2: u32 = 2;

    try slot.assigned_nodes.append(@ptrCast(&dummy1));
    try slot.assigned_nodes.append(@ptrCast(&dummy2));

    try std.testing.expect(slot.hasAssignedNodes());
    try std.testing.expectEqual(@as(usize, 2), slot.assigned_nodes.items.len);
}