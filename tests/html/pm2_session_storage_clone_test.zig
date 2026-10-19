const std = @import("std");
const web_storage = @import("html_core").web_storage;
const storage = web_storage.web_storage;

fn seed(store: *web_storage.UserAgentStorage, top: u64, origin: []const u8, value: []const u8) !void {
    var area = try web_storage.getSessionStorage(std.testing.allocator, store, top, origin);
    defer area.deinit();
    try area.setItem("key", value);
    try area.setItem("other", "second value");
}

test "new traversable storage copies every origin independently and excludes other tabs and local storage" {
    const allocator = std.testing.allocator;
    var store = web_storage.UserAgentStorage.init(allocator);
    defer store.deinit();
    try seed(&store, 1, "https://one.test", "first");
    try seed(&store, 1, "https://two.test", "second");
    try seed(&store, 10, "https://unrelated.test", "unrelated");
    var local = try web_storage.getLocalStorage(allocator, &store, "https://local.test");
    defer local.deinit();
    try local.setItem("local-only", "value");

    try storage.cloneSessionStorage(&store, 1, 2);
    for ([_][]const u8{ "https://one.test", "https://two.test" }, [_][]const u8{ "first", "second" }) |origin, expected| {
        var original = try web_storage.getSessionStorage(allocator, &store, 1, origin);
        defer original.deinit();
        var copied = try web_storage.getSessionStorage(allocator, &store, 2, origin);
        defer copied.deinit();
        try std.testing.expectEqualStrings(expected, copied.getItem("key").?);
        try std.testing.expectEqual(original.length(), copied.length());
        for (0..original.length()) |i| {
            const key = original.key(i).?;
            try std.testing.expectEqualStrings(original.getItem(key).?, copied.getItem(key).?);
        }
        try copied.setItem("key", "popup");
        try std.testing.expectEqualStrings(expected, original.getItem("key").?);
        original.removeItem("other");
        try std.testing.expectEqualStrings("second value", copied.getItem("other").?);
    }
    for ([_][]const u8{ "https://unrelated.test", "https://local.test" }) |origin| {
        var absent = try web_storage.getSessionStorage(allocator, &store, 2, origin);
        defer absent.deinit();
        try std.testing.expectEqual(@as(usize, 0), absent.length());
    }
}

fn cloneAllocationScenario(allocator: std.mem.Allocator) !void {
    // Seed with an infallible testing allocator: this test injects failures
    // into cloning, not the legacy backend's unrelated creation algorithms.
    var store = web_storage.UserAgentStorage.init(std.testing.allocator);
    defer store.deinit();
    try seed(&store, 1, "https://one.test", "first");
    try seed(&store, 1, "https://two.test", "second");
    const count = store.shed.count();
    var original = try web_storage.getSessionStorage(std.testing.allocator, &store, 1, "https://one.test");
    defer original.deinit();
    // Keep the pre-existing outer allocation with its original allocator.
    // This case injects every private-copy allocation; the separate growth
    // case below also injects the final publication reservation.
    try store.shed.shelves.ensureUnusedCapacity(2);
    // Both allocators share std.testing.allocator as their backing allocator.
    // The fail-checking wrapper lives until after this store is destroyed.
    store.allocator = allocator;
    store.shed.allocator = allocator;
    store.shed.shelves.allocator = allocator;
    defer {
        store.allocator = std.testing.allocator;
        store.shed.allocator = std.testing.allocator;
        store.shed.shelves.allocator = std.testing.allocator;
    }
    storage.cloneSessionStorage(&store, 1, 2) catch |err| {
        try std.testing.expectEqual(count, store.shed.count());
        try std.testing.expectEqualStrings("first", original.getItem("key").?);
        return err;
    };
    try std.testing.expectEqual(count + 2, store.shed.count());
}

test "session storage clone allocation failure publishes no partial shelves" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, cloneAllocationScenario, .{});
}

fn growingCloneAllocationScenario(fail_index: usize) !bool {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = fail_index });
    var store = web_storage.UserAgentStorage.init(std.testing.allocator);
    defer store.deinit();
    const origins = [_][]const u8{ "https://one.test", "https://two.test", "https://three.test", "https://four.test", "https://five.test" };
    for (origins) |origin| try seed(&store, 1, origin, "source");
    var original = try web_storage.getSessionStorage(std.testing.allocator, &store, 1, origins[0]);
    defer original.deinit();
    store.allocator = failing.allocator();
    store.shed.allocator = failing.allocator();
    store.shed.shelves.allocator = failing.allocator();
    storage.cloneSessionStorage(&store, 1, 2) catch |err| {
        try std.testing.expectEqual(error.OutOfMemory, err);
        try std.testing.expect(failing.has_induced_failure);
        try std.testing.expectEqual(@as(usize, 5), store.shed.count());
        try std.testing.expectEqualStrings("source", original.getItem("key").?);
        return true;
    };
    try std.testing.expectEqual(@as(usize, 10), store.shed.count());
    try std.testing.expectEqualStrings("source", original.getItem("key").?);
    return false;
}

test "session storage clone allocation failures also cover growing the destination shed" {
    // All allocations, including the old outer table, share the leak-checking
    // backing allocator. Its pre-existing table may be freed by a grow, so
    // injection counts cannot double as the leak count in this scenario.
    var fail_index: usize = 0;
    while (try growingCloneAllocationScenario(fail_index)) : (fail_index += 1) {}
    try std.testing.expect(fail_index > 0);
}

test "session storage clone preserves the independent key-value set after growth and deletion" {
    const allocator = std.testing.allocator;
    var store = web_storage.UserAgentStorage.init(allocator);
    defer store.deinit();
    var original = try web_storage.getSessionStorage(allocator, &store, 1, "https://order.test");
    defer original.deinit();
    var key_buffer: [32]u8 = undefined;
    for (0..100) |i| {
        const key = try std.fmt.bufPrint(&key_buffer, "item-{d}", .{i});
        try original.setItem(key, "value");
    }
    for (0..90) |i| {
        const key = try std.fmt.bufPrint(&key_buffer, "item-{d}", .{i});
        original.removeItem(key);
    }
    try storage.cloneSessionStorage(&store, 1, 2);
    var copy = try web_storage.getSessionStorage(allocator, &store, 2, "https://order.test");
    defer copy.deinit();
    try std.testing.expectEqual(original.length(), copy.length());
    // TODO(STORAGE): ordered map; key(i) order should match the source.
    // Q9 routes that representation defect to STORAGE. This clone owns
    // independent keys and values, without reaching into HashMap metadata.
    for (0..original.length()) |i| {
        const key = original.key(i).?;
        try std.testing.expectEqualStrings(original.getItem(key).?, copy.getItem(key).?);
    }
    try copy.setItem("item-99", "copy");
    try std.testing.expectEqualStrings("value", original.getItem("item-99").?);
    try original.setItem("item-98", "source");
    try std.testing.expectEqualStrings("value", copy.getItem("item-98").?);
    try std.testing.expectEqual(@as(usize, 10), original.length());
    try std.testing.expectEqual(@as(usize, 10), copy.length());
}
