const std = @import("std");
const server_timing = @import("fetch").internal.fetch_timing.server_timing;

test "Server-Timing keeps duplicate metrics and first case-insensitive parameters" {
    const allocator = std.testing.allocator;
    const metrics = try server_timing.parse(allocator, &.{
        "db;DuR=12.5;DeSc=\"cache, \\\"hit\\\"\";dur=99;desc=ignored, db;dur=bad;dur=7",
        "empty;desc;desc=ignored;dur;dur=8",
    });
    defer server_timing.deinit(allocator, metrics);
    try std.testing.expectEqual(@as(usize, 3), metrics.len);
    try std.testing.expectEqualStrings("db", metrics[0].name);
    try std.testing.expectEqual(@as(f64, 12.5), metrics[0].duration);
    try std.testing.expectEqualStrings("cache, \"hit\"", metrics[0].description);
    try std.testing.expectEqualStrings("db", metrics[1].name);
    try std.testing.expectEqual(@as(f64, 0), metrics[1].duration);
    try std.testing.expectEqualStrings("", metrics[2].description);
    try std.testing.expectEqual(@as(f64, 0), metrics[2].duration);
}

test "Server-Timing ignores malformed suffixes and decodes quoted header bytes" {
    const allocator = std.testing.allocator;
    const metrics = try server_timing.parse(allocator, &.{
        "metric== junk;desc=d1 d2;dur=2.5",
        "latin;desc=\"caf\xe9\\\"\"",
        "unterminated;desc=\"missing",
        "=not-a-metric",
        "tabs;\tdesc=\ttrimmed\t;dur=\t42",
    });
    defer server_timing.deinit(allocator, metrics);
    try std.testing.expectEqual(@as(usize, 4), metrics.len);
    try std.testing.expectEqualStrings("metric", metrics[0].name);
    try std.testing.expectEqualStrings("d1", metrics[0].description);
    try std.testing.expectEqual(@as(f64, 2.5), metrics[0].duration);
    try std.testing.expectEqualStrings("café\"", metrics[1].description);
    try std.testing.expectEqualStrings("", metrics[2].description);
    try std.testing.expectEqualStrings("trimmed", metrics[3].description);
    try std.testing.expectEqual(@as(f64, 42), metrics[3].duration);
}

test "Server-Timing parsing and copies unwind every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, parseAndClone, .{});
}

fn parseAndClone(allocator: std.mem.Allocator) !void {
    const metrics = try server_timing.parse(allocator, &.{"a;dur=1;desc=\"one\\two\", b;desc=\"caf\xe9\""});
    defer server_timing.deinit(allocator, metrics);
    const copy = try server_timing.clone(allocator, metrics);
    defer server_timing.deinit(allocator, copy);
    try std.testing.expectEqual(@as(usize, 2), copy.len);
    try std.testing.expectEqualStrings(metrics[1].description, copy[1].description);
    try std.testing.expect(metrics[0].name.ptr != copy[0].name.ptr);
}

test "absent Server-Timing does not allocate" {
    var storage: [0]u8 = .{};
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    const metrics = try server_timing.parse(fixed.allocator(), &.{});
    defer server_timing.deinit(fixed.allocator(), metrics);
    try std.testing.expectEqual(@as(usize, 0), metrics.len);
}
