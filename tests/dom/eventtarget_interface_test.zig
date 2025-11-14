//! Tests migrated from webidl/src/dom/EventTarget.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");

const source = @import("../../webidl/src/dom/EventTarget.zig");

test "EventTarget - event_listener_list starts as null (lazy allocation)" {
    const allocator = std.testing.allocator;

    const target = try allocator.create(EventTarget);
    defer allocator.destroy(target);
    target.* = try EventTarget.init(allocator);
    defer target.deinit();

    // Should start as null (not allocated)
    try std.testing.expect(target.event_listener_list == null);
}
test "EventTarget - addEventListener allocates list on first use" {
    const allocator = std.testing.allocator;

    const target = try allocator.create(EventTarget);
    defer allocator.destroy(target);
    target.* = try EventTarget.init(allocator);
    defer target.deinit();

    // Starts null
    try std.testing.expect(target.event_listener_list == null);

    // Add first listener
    try target.call_addEventListener("click", .{ .js_value = 42 }, .{});

    // Should now be allocated
    try std.testing.expect(target.event_listener_list != null);
    try std.testing.expectEqual(@as(usize, 1), target.event_listener_list.?.len);
}
test "EventTarget - removeEventListener on never-used target is safe" {
    const allocator = std.testing.allocator;

    const target = try allocator.create(EventTarget);
    defer allocator.destroy(target);
    target.* = try EventTarget.init(allocator);
    defer target.deinit();

    // Remove from target that never had listeners added
    target.call_removeEventListener("click", null, .{});

    // Should still be null (no allocation needed)
    try std.testing.expect(target.event_listener_list == null);
}
test "EventTarget - memory savings from lazy allocation" {
    const allocator = std.testing.allocator;

    // Create 100 targets, only 10 get listeners
    var targets: [100]*EventTarget = undefined;

    // Initialize all targets
    for (&targets) |*t| {
        t.* = try allocator.create(EventTarget);
        t.*.* = try EventTarget.init(allocator);
    }
    defer {
        for (targets) |t| {
            t.deinit();
            allocator.destroy(t);
        }
    }

    // Only 10% get listeners
    for (targets[0..10]) |t| {
        try t.call_addEventListener("click", .{ .js_value = 1 }, .{});
    }

    // Count how many have allocated lists
    var allocated_count: usize = 0;
    for (targets) |t| {
        if (t.event_listener_list != null) {
            allocated_count += 1;
        }
    }

    // Only 10 should have allocated lists
    try std.testing.expectEqual(@as(usize, 10), allocated_count);

    // 90 targets saved memory by not allocating
    try std.testing.expectEqual(@as(usize, 90), 100 - allocated_count);
}
test "EventTarget - getEventListenerList returns empty for unused target" {
    const allocator = std.testing.allocator;

    const target = try allocator.create(EventTarget);
    defer allocator.destroy(target);
    target.* = try EventTarget.init(allocator);
    defer target.deinit();

    // Should return empty slice, not crash
    const listeners = target.getEventListenerList();
    try std.testing.expectEqual(@as(usize, 0), listeners.len);
}
test "EventTarget - deinit handles both null and allocated list" {
    const allocator = std.testing.allocator;

    // Target with no listeners (null list)
    {
        const target = try allocator.create(EventTarget);
        defer allocator.destroy(target);
        target.* = try EventTarget.init(allocator);
        target.deinit(); // Should not crash
    }

    // Target with listeners (allocated list)
    {
        const target = try allocator.create(EventTarget);
        defer allocator.destroy(target);
        target.* = try EventTarget.init(allocator);
        try target.call_addEventListener("click", .{ .js_value = 1 }, .{});
        target.deinit(); // Should clean up list
    }

    // No leaks should be detected by testing allocator
}