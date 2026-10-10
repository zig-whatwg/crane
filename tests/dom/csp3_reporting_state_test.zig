const std = @import("std");
const reporting = @import("dom").reporting;

test "Reporting buffer retains the latest 100 records independently for each type" {
    const allocator = std.testing.allocator;
    var state: reporting.State = .{};
    defer state.deinit(allocator);
    for (0..105) |index| {
        const record = try reporting.Record.create(allocator, .{
            .type = "csp-violation",
            .url = "https://example.test/page",
            .destination = "group",
            .body_json = "{}",
            .timestamp_ms = @intCast(index),
            .user_agent = "Crane",
        });
        defer record.release();
        try state.bufferReport(allocator, record);
    }
    const other = try reporting.Record.create(allocator, .{
        .type = "test",
        .url = "https://example.test/page",
        .destination = "group",
        .body_json = "{\"message\":\"x\"}",
        .timestamp_ms = 50,
        .user_agent = "Crane",
    });
    defer other.release();
    try state.bufferReport(allocator, other);
    try std.testing.expectEqual(@as(usize, 101), state.buffer.items.len);
    try std.testing.expectEqual(@as(i64, 5), state.buffer.items[0].timestamp_ms);
    try std.testing.expectEqual(@as(i64, 104), state.buffer.items[99].timestamp_ms);
    try std.testing.expectEqualStrings("test", state.buffer.items[100].type);
    try std.testing.expectEqual(@as(usize, 0), state.pending.items.len);
}

test "Reporting records own every input, preserve nested JSON, and serialize a report batch" {
    const allocator = std.testing.allocator;
    var body = [_]u8{ '{', '"', 'x', '"', ':', '1', '}' };
    const record = try reporting.Record.create(allocator, .{
        .type = "test",
        .url = "https://example.test/page",
        .destination = "group",
        .body_json = &body,
        .timestamp_ms = 1234,
        .user_agent = "Crane \"test\"",
    });
    defer record.release();
    body[5] = '2';
    const bytes = try reporting.serializeReports(allocator, &.{record}, 1500);
    defer allocator.free(bytes);
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, bytes, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.value.array.items.len);
    const entry = parsed.value.array.items[0].object;
    try std.testing.expectEqual(@as(usize, 5), entry.count());
    try std.testing.expectEqual(@as(i64, 266), entry.get("age").?.integer);
    try std.testing.expectEqualStrings("test", entry.get("type").?.string);
    try std.testing.expectEqualStrings("Crane \"test\"", entry.get("user_agent").?.string);
    try std.testing.expectEqual(@as(i64, 1), entry.get("body").?.object.get("x").?.integer);
    try std.testing.expectEqual(@as(u64, 1), record.attempts);
}
