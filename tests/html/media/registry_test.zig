//! The media registry belongs to one AgentHost; pointers here are borrowed.
//! Missing-module red and passing green observed on chat.local (media Q8).
const std = @import("std");
const testing = std.testing;
const Registry = @import("html_core").media.Registry(*u8, *u8);

test "media registry adds once and missing or repeated removal does nothing" {
    var registry = Registry.init(testing.allocator);
    defer registry.deinit();
    var other_agent = Registry.init(testing.allocator);
    defer other_agent.deinit();
    var instances = [_]u8{ 1, 2, 3 };
    var realm: u8 = 0;
    registry.remove(&instances[2]);
    try registry.add(&instances[0], &realm);
    try registry.add(&instances[1], &realm);
    try registry.add(&instances[0], &realm);
    try testing.expectEqual(@as(usize, 2), registry.entries.len);
    try testing.expectEqual(@as(usize, 0), other_agent.entries.len);
    registry.remove(&instances[2]);
    registry.remove(&instances[0]);
    registry.remove(&instances[0]);
    try testing.expectEqual(@as(usize, 1), registry.entries.len);
    try testing.expectEqual(&instances[1], registry.entries.get(0).?.instance);
    registry.remove(&instances[1]);
    try testing.expectEqual(@as(usize, 0), registry.entries.len);
}

test "realm cleanup can remove entries during a backwards traversal" {
    var registry = Registry.init(testing.allocator);
    defer registry.deinit();
    var instances = [_]u8{ 1, 2, 3, 4 };
    var realms = [_]u8{ 5, 6 };
    for (&instances, 0..) |*instance, i| try registry.add(instance, &realms[i % 2]);
    var index = registry.entries.len;
    while (index > 0) {
        index -= 1;
        if (index >= registry.entries.len) continue;
        const entry = registry.entries.get(index).?;
        if (entry.realm == &realms[0]) registry.remove(entry.instance);
    }
    try testing.expectEqual(@as(usize, 2), registry.entries.len);
    for (registry.entries.toSlice()) |entry| try testing.expectEqual(&realms[1], entry.realm);
}
