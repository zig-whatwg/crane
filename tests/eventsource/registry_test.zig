const std = @import("std");
const Sources = @import("eventsource").Registry(*u8, *u8);

test "sources belong to their own agent and removal is idempotent" {
    var sources = Sources.init(std.testing.allocator);
    defer sources.deinit();
    var other = Sources.init(std.testing.allocator);
    defer other.deinit();
    var one: u8 = 1;
    var two: u8 = 2;
    var realm: u8 = 3;
    try sources.add(&one, &realm);
    try sources.add(&two, &realm);
    try sources.add(&one, &realm);
    try std.testing.expectEqual(@as(usize, 2), sources.entries.len);
    try std.testing.expectEqual(@as(usize, 0), other.entries.len);
    sources.remove(&one);
    sources.remove(&one);
    try std.testing.expectEqual(@as(usize, 1), sources.entries.len);
    try std.testing.expectEqual(&two, sources.entries.get(0).?.instance);
    sources.remove(&two);
    try std.testing.expectEqual(@as(usize, 0), sources.entries.len);
}

test "realm filtering can remove entries while walking backwards" {
    var sources = Sources.init(std.testing.allocator);
    defer sources.deinit();
    var instances = [_]u8{ 1, 2, 3, 4 };
    var realms = [_]u8{ 5, 6 };
    for (&instances, 0..) |*instance, i| try sources.add(instance, &realms[i % 2]);
    var index = sources.entries.len;
    while (index > 0) {
        index -= 1;
        if (index >= sources.entries.len) continue;
        const entry = sources.entries.get(index).?;
        if (entry.realm == &realms[0]) sources.remove(entry.instance);
    }
    try std.testing.expectEqual(@as(usize, 2), sources.entries.len);
    for (sources.entries.toSlice()) |entry| try std.testing.expectEqual(&realms[1], entry.realm);
}
