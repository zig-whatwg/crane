const std = @import("std");
const web_storage = @import("html_core").web_storage;
const storage = web_storage.web_storage;

/// A traversable's storage shed (each tab's: runtime.TabScope's
/// session_storage slot).
const Shed = web_storage.TraversableStorageShed;

/// `origin`'s first-party storage key: its own site as the top-level site.
fn keyOf(origin: []const u8) web_storage.StorageKey {
    return web_storage.StorageKey.initBorrowed(origin, origin, false);
}

/// The number of shelves in a traversable's session storage shed.
fn shelvesOf(shed: *const Shed) usize {
    return shed.shelves.count();
}

fn seed(shed: *Shed, origin: []const u8, value: []const u8) !void {
    var area = try web_storage.getSessionStorage(std.testing.allocator, shed, keyOf(origin));
    defer area.deinit();
    try area.setItem("key", value);
    try area.setItem("other", "second value");
}

test "new traversable storage copies every origin independently and excludes other tabs and local storage" {
    const allocator = std.testing.allocator;
    var opener = web_storage.initTraversableStorageShed(allocator);
    defer opener.deinit();
    var popup = web_storage.initTraversableStorageShed(allocator);
    defer popup.deinit();
    var unrelated = web_storage.initTraversableStorageShed(allocator);
    defer unrelated.deinit();
    var user_agent_storage = web_storage.UserAgentStorage.init(allocator);
    defer user_agent_storage.deinit();
    try seed(&opener, "https://one.test", "first");
    try seed(&opener, "https://two.test", "second");
    try seed(&unrelated, "https://unrelated.test", "unrelated");
    var local = try web_storage.getLocalStorage(allocator, &user_agent_storage, keyOf("https://local.test"));
    defer local.deinit();
    try local.setItem("local-only", "value");

    try storage.cloneSessionStorage(&opener, &popup);
    for ([_][]const u8{ "https://one.test", "https://two.test" }, [_][]const u8{ "first", "second" }) |origin, expected| {
        var original = try web_storage.getSessionStorage(allocator, &opener, keyOf(origin));
        defer original.deinit();
        var copied = try web_storage.getSessionStorage(allocator, &popup, keyOf(origin));
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
        var absent = try web_storage.getSessionStorage(allocator, &popup, keyOf(origin));
        defer absent.deinit();
        try std.testing.expectEqual(@as(usize, 0), absent.length());
    }
}

fn cloneAllocationScenario(allocator: std.mem.Allocator) !void {
    // Seed with an infallible testing allocator: this test injects failures
    // into cloning, not the legacy backend's unrelated creation algorithms.
    var opener = web_storage.initTraversableStorageShed(std.testing.allocator);
    defer opener.deinit();
    try seed(&opener, "https://one.test", "first");
    try seed(&opener, "https://two.test", "second");
    var original = try web_storage.getSessionStorage(std.testing.allocator, &opener, keyOf("https://one.test"));
    defer original.deinit();
    // Every allocation of the copy is the new traversable's shed's, which
    // is injected. Both allocators share std.testing.allocator as their
    // backing allocator.
    var popup = web_storage.initTraversableStorageShed(allocator);
    defer popup.deinit();
    storage.cloneSessionStorage(&opener, &popup) catch |err| {
        try std.testing.expectEqual(@as(usize, 0), shelvesOf(&popup));
        try std.testing.expectEqual(@as(usize, 2), shelvesOf(&opener));
        try std.testing.expectEqualStrings("first", original.getItem("key").?);
        return err;
    };
    try std.testing.expectEqual(@as(usize, 2), shelvesOf(&popup));
}

test "session storage clone allocation failure publishes no partial shelves" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, cloneAllocationScenario, .{});
}

test "session storage clone preserves the independent key-value set after growth and deletion" {
    const allocator = std.testing.allocator;
    var opener = web_storage.initTraversableStorageShed(allocator);
    defer opener.deinit();
    var popup = web_storage.initTraversableStorageShed(allocator);
    defer popup.deinit();
    var original = try web_storage.getSessionStorage(allocator, &opener, keyOf("https://order.test"));
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
    try storage.cloneSessionStorage(&opener, &popup);
    var copy = try web_storage.getSessionStorage(allocator, &popup, keyOf("https://order.test"));
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
