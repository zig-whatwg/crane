//! URLSearchParams Unified Constructor Tests
//!
//! Tests for the unified constructor that accepts union type (string | sequence | record)
//! Spec: WebIDL line 30, spec lines 2067-2071

const std = @import("std");
const url = @import("url");
const URLSearchParams = @import("url_search_params").URLSearchParams;
const RecordEntry = url.internal.url_search_params_impl.RecordEntry;

test "URLSearchParams - init with empty" {
    const allocator = std.testing.allocator;

    var params = try URLSearchParams.init(allocator);
    defer params.deinit();

    try std.testing.expectEqual(@as(u32, 0), params.size());
}

test "URLSearchParams - init with string" {
    const allocator = std.testing.allocator;

    var params = try URLSearchParams.initWithString(allocator, "a=1&b=2&c=3");
    defer params.deinit();

    try std.testing.expectEqual(@as(u32, 3), params.size());
    try std.testing.expectEqualStrings("1", params.get("a").?);
    try std.testing.expectEqualStrings("2", params.get("b").?);
    try std.testing.expectEqualStrings("3", params.get("c").?);
}

test "URLSearchParams - init with string starting with ?" {
    const allocator = std.testing.allocator;

    // Spec line 2069: leading ? should be removed
    var params = try URLSearchParams.initWithString(allocator, "?key=value");
    defer params.deinit();

    try std.testing.expectEqual(@as(u32, 1), params.size());
    try std.testing.expectEqualStrings("value", params.get("key").?);
}

test "URLSearchParams - init with sequence" {
    const allocator = std.testing.allocator;

    const seq = [_][2][]const u8{
        .{ "name1", "value1" },
        .{ "name2", "value2" },
        .{ "name3", "value3" },
    };

    var params = try URLSearchParams.initWithSequence(allocator, &seq);
    defer params.deinit();

    try std.testing.expectEqual(@as(u32, 3), params.size());
    try std.testing.expectEqualStrings("value1", params.get("name1").?);
    try std.testing.expectEqualStrings("value2", params.get("name2").?);
    try std.testing.expectEqualStrings("value3", params.get("name3").?);
}

test "URLSearchParams - init with record" {
    const allocator = std.testing.allocator;

    const record = [_]RecordEntry{
        .{ .name = "key1", .value = "val1" },
        .{ .name = "key2", .value = "val2" },
        .{ .name = "key3", .value = "val3" },
    };

    var params = try URLSearchParams.initWithRecord(allocator, &record);
    defer params.deinit();

    try std.testing.expectEqual(@as(u32, 3), params.size());
    try std.testing.expectEqualStrings("val1", params.get("key1").?);
    try std.testing.expectEqualStrings("val2", params.get("key2").?);
    try std.testing.expectEqualStrings("val3", params.get("key3").?);
}

test "URLSearchParams - convenience wrappers still work" {
    const allocator = std.testing.allocator;

    // initWithString
    {
        var params = try URLSearchParams.initWithString(allocator, "a=1");
        defer params.deinit();
        try std.testing.expectEqual(@as(u32, 1), params.size());
    }

    // initWithSequence
    {
        const seq = [_][2][]const u8{.{ "a", "1" }};
        var params = try URLSearchParams.initWithSequence(allocator, &seq);
        defer params.deinit();
        try std.testing.expectEqual(@as(u32, 1), params.size());
    }

    // initWithRecord
    {
        const record = [_]RecordEntry{
            .{ .name = "a", .value = "1" },
        };
        var params = try URLSearchParams.initWithRecord(allocator, &record);
        defer params.deinit();
        try std.testing.expectEqual(@as(u32, 1), params.size());
    }
}

test "URLSearchParams - empty string vs empty init" {
    const allocator = std.testing.allocator;

    // Empty string
    var params1 = try URLSearchParams.initWithString(allocator, "");
    defer params1.deinit();

    // Empty init
    var params2 = try URLSearchParams.init(allocator);
    defer params2.deinit();

    try std.testing.expectEqual(@as(u32, 0), params1.size());
    try std.testing.expectEqual(@as(u32, 0), params2.size());
}

test "URLSearchParams - complex query string" {
    const allocator = std.testing.allocator;

    var params = try URLSearchParams.initWithString(allocator, "a=1&b=2&a=3&c=hello%20world");
    defer params.deinit();

    try std.testing.expectEqual(@as(u32, 4), params.size());

    // First 'a' value
    try std.testing.expectEqualStrings("1", params.get("a").?);

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
