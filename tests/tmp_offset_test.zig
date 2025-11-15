const std = @import("std");
const dom = @import("dom");

test "check struct offsets" {
    std.debug.print("\nNode size={}, align={}\n", .{ @sizeOf(dom.Node), @alignOf(dom.Node) });
    std.debug.print("Node offsets:\n", .{});
    std.debug.print("  event_listener_list: {}\n", .{@offsetOf(dom.Node, "event_listener_list")});
    std.debug.print("  allocator: {}\n", .{@offsetOf(dom.Node, "allocator")});
    std.debug.print("  node_type: {}\n", .{@offsetOf(dom.Node, "node_type")});
    std.debug.print("  node_name: {}\n", .{@offsetOf(dom.Node, "node_name")});

    std.debug.print("\nElement size={}, align={}\n", .{ @sizeOf(dom.Element), @alignOf(dom.Element) });
    std.debug.print("Element offsets:\n", .{});
    std.debug.print("  event_listener_list: {}\n", .{@offsetOf(dom.Element, "event_listener_list")});
    std.debug.print("  allocator: {}\n", .{@offsetOf(dom.Element, "allocator")});
    std.debug.print("  node_type: {}\n", .{@offsetOf(dom.Element, "node_type")});
    std.debug.print("  node_name: {}\n", .{@offsetOf(dom.Element, "node_name")});

    // This test always passes, we just want to see the output
    try std.testing.expect(true);
}
