//! URLSearchParams Unified Constructor Tests
//!
//! Tests for the unified constructor that accepts union type (string | sequence | record)
//! Spec: WebIDL line 30, spec lines 2067-2071

const std = @import("std");
const URLSearchParams = @import("url_search_params").URLSearchParams;
const URLSearchParamsInit = @import("url_search_params").URLSearchParamsInit;

test "URLSearchParams - init with empty" {
    const allocator = std.testing.allocator;

    var params = try URLSearchParams.init(allocator, .empty);
    defer params.deinit();

    try std.testing.expectEqual(@as(u32, 0), params.get_size());
}

test "URLSearchParams - init with string" {
    const allocator = std.testing.allocator;

    var params = try URLSearchParams.init(allocator, .{ .string = "a=1&b=2&c=3" });
    defer params.deinit();

    try std.testing.expectEqual(@as(u32, 3), params.get_size());
    try std.testing.expectEqualStrings("1", params.call_get("a").?);
    try std.testing.expectEqualStrings("2", params.call_get("b").?);
    try std.testing.expectEqualStrings("3", params.call_get("c").?);
}

test "URLSearchParams - init with string starting with ?" {
    const allocator = std.testing.allocator;

    // Spec line 2069: leading ? should be removed
    var params = try URLSearchParams.init(allocator, .{ .string = "?key=value" });
    defer params.deinit();

    try std.testing.expectEqual(@as(u32, 1), params.get_size());
    try std.testing.expectEqualStrings("value", params.call_get("key").?);
}

test "URLSearchParams - init with sequence" {
    const allocator = std.testing.allocator;

    const seq = [_][2][]const u8{
        .{ "name1", "value1" },
        .{ "name2", "value2" },
        .{ "name3", "value3" },
    };

    var params = try URLSearchParams.init(allocator, .{ .sequence = &seq });
    defer params.deinit();

    try std.testing.expectEqual(@as(u32, 3), params.get_size());
    try std.testing.expectEqualStrings("value1", params.call_get("name1").?);
    try std.testing.expectEqualStrings("value2", params.call_get("name2").?);
    try std.testing.expectEqualStrings("value3", params.call_get("name3").?);
}

test "URLSearchParams - init with record" {
    const allocator = std.testing.allocator;

    const record = [_]struct { name: []const u8, value: []const u8 }{
        .{ .name = "key1", .value = "val1" },
        .{ .name = "key2", .value = "val2" },
        .{ .name = "key3", .value = "val3" },
    };

    var params = try URLSearchParams.init(allocator, .{ .record = &record });
    defer params.deinit();

    try std.testing.expectEqual(@as(u32, 3), params.get_size());
    try std.testing.expectEqualStrings("val1", params.call_get("key1").?);
    try std.testing.expectEqualStrings("val2", params.call_get("key2").?);
    try std.testing.expectEqualStrings("val3", params.call_get("key3").?);
}

test "URLSearchParams - convenience wrappers still work" {
    const allocator = std.testing.allocator;

    // initFromString
    {
        var params = try URLSearchParams.initFromString(allocator, "a=1");
        defer params.deinit();
        try std.testing.expectEqual(@as(u32, 1), params.get_size());
    }

    // initFromSequence
    {
        const seq = [_][2][]const u8{.{ "a", "1" }};
        var params = try URLSearchParams.initFromSequence(allocator, &seq);
        defer params.deinit();
        try std.testing.expectEqual(@as(u32, 1), params.get_size());
    }

    // initFromRecord
    {
        const record = [_]struct { name: []const u8, value: []const u8 }{
            .{ .name = "a", .value = "1" },
        };
        var params = try URLSearchParams.initFromRecord(allocator, &record);
        defer params.deinit();
        try std.testing.expectEqual(@as(u32, 1), params.get_size());
    }
}

test "URLSearchParams - empty string vs empty init" {
    const allocator = std.testing.allocator;

    // Empty string
    var params1 = try URLSearchParams.init(allocator, .{ .string = "" });
    defer params1.deinit();

    // Empty init
    var params2 = try URLSearchParams.init(allocator, .empty);
    defer params2.deinit();

    try std.testing.expectEqual(@as(u32, 0), params1.get_size());
    try std.testing.expectEqual(@as(u32, 0), params2.get_size());
}

test "URLSearchParams - complex query string" {
    const allocator = std.testing.allocator;

    var params = try URLSearchParams.init(allocator, .{ .string = "a=1&b=2&a=3&c=hello%20world" });
    defer params.deinit();

    try std.testing.expectEqual(@as(u32, 4), params.get_size());

    // First 'a' value
    try std.testing.expectEqualStrings("1", params.call_get("a").?);

    // All 'a' values
    const all_a = try params.call_getAll("a");
    defer {
        for (all_a) |val| allocator.free(val);
        allocator.free(all_a);
    }
    try std.testing.expectEqual(@as(usize, 2), all_a.len);
    try std.testing.expectEqualStrings("1", all_a[0]);
    try std.testing.expectEqualStrings("3", all_a[1]);
}
