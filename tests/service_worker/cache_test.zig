//! Service Worker Cache API Tests
//!
//! Tests for Cache and CacheStorage interfaces.

const std = @import("std");
const testing = std.testing;

const sw = @import("service_worker");
const Cache = sw.Cache;
const CacheStorage = sw.CacheStorage;
const HeaderEntry = sw.HeaderEntry;
const ResponseType = sw.ResponseType;

// =============================================================================
// Cache Tests
// =============================================================================

test "Cache - init and deinit" {
    const allocator = testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    try testing.expectEqualStrings("v1", cache.name);
    try testing.expect(cache.isEmpty());
    try testing.expectEqual(@as(usize, 0), cache.count());
}

test "Cache - put and match" {
    const allocator = testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    // Put an entry
    const put_result = try cache.put(
        "https://example.com/api",
        "GET",
        &[_]HeaderEntry{},
        200,
        "OK",
        &[_]HeaderEntry{.{ .name = "Content-Type", .value = "application/json" }},
        "{\"data\": 42}",
        .basic,
    );
    try testing.expect(put_result.isFulfilled());

    // Match should find it
    const match_result = try cache.match(
        "https://example.com/api",
        "GET",
        &[_]HeaderEntry{},
        .{},
    );
    try testing.expect(match_result.isFulfilled());
    try testing.expect(match_result.value.? != null);

    const response = match_result.value.?.?;
    try testing.expectEqual(@as(u16, 200), response.status);
    try testing.expectEqualStrings("{\"data\": 42}", response.body.?);
}

test "Cache - match with query options" {
    const allocator = testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    // Put with query string
    _ = try cache.put(
        "https://example.com/api?version=1",
        "GET",
        &[_]HeaderEntry{},
        200,
        "OK",
        &[_]HeaderEntry{},
        "response-v1",
        .basic,
    );

    // Exact match should work
    const match1 = try cache.match(
        "https://example.com/api?version=1",
        "GET",
        &[_]HeaderEntry{},
        .{},
    );
    try testing.expect(match1.value.? != null);

    // Different query should not match by default
    const match2 = try cache.match(
        "https://example.com/api?version=2",
        "GET",
        &[_]HeaderEntry{},
        .{},
    );
    try testing.expect(match2.value.? == null);

    // With ignoreSearch, different query should match
    const match3 = try cache.match(
        "https://example.com/api?version=2",
        "GET",
        &[_]HeaderEntry{},
        .{ .ignore_search = true },
    );
    try testing.expect(match3.value.? != null);
}

test "Cache - match with method options" {
    const allocator = testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    _ = try cache.put(
        "https://example.com/api",
        "POST",
        &[_]HeaderEntry{},
        200,
        "OK",
        &[_]HeaderEntry{},
        "post-response",
        .basic,
    );

    // GET should not match POST by default
    const match1 = try cache.match(
        "https://example.com/api",
        "GET",
        &[_]HeaderEntry{},
        .{},
    );
    try testing.expect(match1.value.? == null);

    // With ignoreMethod, GET should match POST
    const match2 = try cache.match(
        "https://example.com/api",
        "GET",
        &[_]HeaderEntry{},
        .{ .ignore_method = true },
    );
    try testing.expect(match2.value.? != null);
}

test "Cache - delete" {
    const allocator = testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    _ = try cache.put(
        "https://example.com/api",
        "GET",
        &[_]HeaderEntry{},
        200,
        "OK",
        &[_]HeaderEntry{},
        "data",
        .basic,
    );
    try testing.expectEqual(@as(usize, 1), cache.count());

    // Delete it
    const delete_result = try cache.delete(
        "https://example.com/api",
        "GET",
        &[_]HeaderEntry{},
        .{},
    );
    try testing.expect(delete_result.value.?);
    try testing.expect(cache.isEmpty());

    // Delete non-existent returns false
    const delete_again = try cache.delete(
        "https://example.com/api",
        "GET",
        &[_]HeaderEntry{},
        .{},
    );
    try testing.expect(!delete_again.value.?);
}

test "Cache - matchAll" {
    const allocator = testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    _ = try cache.put("https://example.com/a", "GET", &[_]HeaderEntry{}, 200, "OK", &[_]HeaderEntry{}, "a", .basic);
    _ = try cache.put("https://example.com/b", "GET", &[_]HeaderEntry{}, 200, "OK", &[_]HeaderEntry{}, "b", .basic);
    _ = try cache.put("https://example.com/c", "POST", &[_]HeaderEntry{}, 201, "Created", &[_]HeaderEntry{}, "c", .basic);

    // Match all with no filter
    const all = try cache.matchAll(null, null, &[_]HeaderEntry{}, .{});
    defer allocator.free(all.value.?);
    try testing.expectEqual(@as(usize, 3), all.value.?.len);
}

test "Cache - keys" {
    const allocator = testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    _ = try cache.put("https://example.com/a", "GET", &[_]HeaderEntry{}, 200, "OK", &[_]HeaderEntry{}, null, .basic);
    _ = try cache.put("https://example.com/b", "GET", &[_]HeaderEntry{}, 200, "OK", &[_]HeaderEntry{}, null, .basic);

    const keys = try cache.keys(null, null, &[_]HeaderEntry{}, .{});
    defer allocator.free(keys.value.?);
    try testing.expectEqual(@as(usize, 2), keys.value.?.len);
}

test "Cache - put replaces existing" {
    const allocator = testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    _ = try cache.put("https://example.com/api", "GET", &[_]HeaderEntry{}, 200, "OK", &[_]HeaderEntry{}, "v1", .basic);
    _ = try cache.put("https://example.com/api", "GET", &[_]HeaderEntry{}, 200, "OK", &[_]HeaderEntry{}, "v2", .basic);

    // Should only have one entry
    try testing.expectEqual(@as(usize, 1), cache.count());

    // Should have the new value
    const match = try cache.match("https://example.com/api", "GET", &[_]HeaderEntry{}, .{});
    try testing.expectEqualStrings("v2", match.value.?.?.body.?);
}

// =============================================================================
// CacheStorage Tests
// =============================================================================

test "CacheStorage - init and deinit" {
    const allocator = testing.allocator;

    const storage = try CacheStorage.init(allocator);
    defer storage.deinit();

    try testing.expect(storage.isEmpty());
    try testing.expectEqual(@as(u32, 0), storage.count());
}

test "CacheStorage - open creates cache" {
    const allocator = testing.allocator;

    const storage = try CacheStorage.init(allocator);
    defer storage.deinit();

    const open_result = try storage.open("v1");
    try testing.expect(open_result.isFulfilled());

    const cache = open_result.value.?;
    try testing.expectEqualStrings("v1", cache.name);
    try testing.expectEqual(@as(u32, 1), storage.count());
}

test "CacheStorage - open returns existing cache" {
    const allocator = testing.allocator;

    const storage = try CacheStorage.init(allocator);
    defer storage.deinit();

    const cache1 = (try storage.open("v1")).value.?;
    const cache2 = (try storage.open("v1")).value.?;

    try testing.expectEqual(cache1, cache2);
    try testing.expectEqual(@as(u32, 1), storage.count());
}

test "CacheStorage - has" {
    const allocator = testing.allocator;

    const storage = try CacheStorage.init(allocator);
    defer storage.deinit();

    try testing.expect(!storage.has("v1").value.?);

    _ = try storage.open("v1");
    try testing.expect(storage.has("v1").value.?);
    try testing.expect(!storage.has("v2").value.?);
}

test "CacheStorage - delete" {
    const allocator = testing.allocator;

    const storage = try CacheStorage.init(allocator);
    defer storage.deinit();

    _ = try storage.open("v1");
    try testing.expect(storage.delete("v1").value.?);
    try testing.expect(!storage.has("v1").value.?);

    // Delete non-existent returns false
    try testing.expect(!storage.delete("v1").value.?);
}

test "CacheStorage - keys" {
    const allocator = testing.allocator;

    const storage = try CacheStorage.init(allocator);
    defer storage.deinit();

    _ = try storage.open("v1");
    _ = try storage.open("v2");
    _ = try storage.open("v3");

    const keys = try storage.keys();
    defer allocator.free(keys.value.?);
    try testing.expectEqual(@as(usize, 3), keys.value.?.len);
}

test "CacheStorage - match searches all caches" {
    const allocator = testing.allocator;

    const storage = try CacheStorage.init(allocator);
    defer storage.deinit();

    const cache1 = (try storage.open("v1")).value.?;
    _ = try cache1.put("https://example.com/api", "GET", &[_]HeaderEntry{}, 200, "OK", &[_]HeaderEntry{}, "from-v1", .basic);

    const match = try storage.match("https://example.com/api", "GET", &[_]HeaderEntry{}, .{});
    try testing.expect(match.value.? != null);
    try testing.expectEqualStrings("from-v1", match.value.?.?.body.?);
}

test "CacheStorage - match with cache_name" {
    const allocator = testing.allocator;

    const storage = try CacheStorage.init(allocator);
    defer storage.deinit();

    const cache1 = (try storage.open("v1")).value.?;
    const cache2 = (try storage.open("v2")).value.?;

    _ = try cache1.put("https://example.com/api", "GET", &[_]HeaderEntry{}, 200, "OK", &[_]HeaderEntry{}, "from-v1", .basic);
    _ = try cache2.put("https://example.com/api", "GET", &[_]HeaderEntry{}, 200, "OK", &[_]HeaderEntry{}, "from-v2", .basic);

    // Match in specific cache
    const match = try storage.match("https://example.com/api", "GET", &[_]HeaderEntry{}, .{ .cache_name = "v2" });
    try testing.expectEqualStrings("from-v2", match.value.?.?.body.?);
}

// =============================================================================
// Memory Safety Tests
// =============================================================================

test "Cache - no memory leaks with many operations" {
    const allocator = testing.allocator;

    const cache = try Cache.init(allocator, "test");
    defer cache.deinit();

    // Many puts
    for (0..100) |i| {
        var url_buf: [64]u8 = undefined;
        const url = std.fmt.bufPrint(&url_buf, "https://example.com/{d}", .{i}) catch unreachable;

        _ = try cache.put(url, "GET", &[_]HeaderEntry{}, 200, "OK", &[_]HeaderEntry{}, "data", .basic);
    }

    // Many matches
    for (0..100) |i| {
        var url_buf: [64]u8 = undefined;
        const url = std.fmt.bufPrint(&url_buf, "https://example.com/{d}", .{i}) catch unreachable;

        _ = try cache.match(url, "GET", &[_]HeaderEntry{}, .{});
    }

    // Many deletes
    for (0..100) |i| {
        var url_buf: [64]u8 = undefined;
        const url = std.fmt.bufPrint(&url_buf, "https://example.com/{d}", .{i}) catch unreachable;

        _ = try cache.delete(url, "GET", &[_]HeaderEntry{}, .{});
    }

    try testing.expect(cache.isEmpty());
}

test "CacheStorage - no memory leaks with cache creation/deletion" {
    const allocator = testing.allocator;

    const storage = try CacheStorage.init(allocator);
    defer storage.deinit();

    // Create and delete many caches
    for (0..50) |i| {
        var name_buf: [32]u8 = undefined;
        const name = std.fmt.bufPrint(&name_buf, "cache-{d}", .{i}) catch unreachable;

        _ = try storage.open(name);
    }

    for (0..50) |i| {
        var name_buf: [32]u8 = undefined;
        const name = std.fmt.bufPrint(&name_buf, "cache-{d}", .{i}) catch unreachable;

        _ = storage.delete(name);
    }

    try testing.expect(storage.isEmpty());
}
