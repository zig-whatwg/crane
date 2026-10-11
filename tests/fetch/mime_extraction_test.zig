//! Fetch's Content-Type list splitting must preserve the MIME quoted strings.
const std = @import("std");
const fetch = @import("fetch");

fn expectMime(allocator: std.mem.Allocator, values: []const []const u8, essence: []const u8, parameters: []const [2][]const u8) !void {
    var headers = fetch.internal.HeaderList.init(allocator);
    defer headers.deinit();
    for (values) |value| try headers.append("Content-Type", value);
    var mime = (try fetch.internal.mime.extractMimeType(allocator, &headers)) orelse return error.MimeMissing;
    defer mime.deinit();
    const actual_essence = try fetch.internal.mime.essenceBytes(allocator, mime);
    defer allocator.free(actual_essence);
    try std.testing.expectEqualStrings(essence, actual_essence);
    const entries = mime.parameters.entries.items();
    try std.testing.expectEqual(parameters.len, entries.len);
    for (parameters, entries) |expected, actual| {
        const key = try std.unicode.utf16LeToUtf8Alloc(allocator, actual.key);
        defer allocator.free(key);
        const value = try std.unicode.utf16LeToUtf8Alloc(allocator, actual.value);
        defer allocator.free(value);
        try std.testing.expectEqualStrings(expected[0], key);
        try std.testing.expectEqualStrings(expected[1], value);
    }
}

test "extract MIME: quoted commas and semicolons belong to parameter values" {
    try expectMime(std.testing.allocator, &.{"x/x;a=\"a,b;c\";z=x"}, "x/x", &.{ .{ "a", "a,b;c" }, .{ "z", "x" } });
    try expectMime(std.testing.allocator, &.{"x/x;a=\"a\\\"b\\\\c\";z=x"}, "x/x", &.{ .{ "a", "a\"b\\c" }, .{ "z", "x" } });
    try expectMime(std.testing.allocator, &.{"x/x;a=\"abc\\"}, "x/x", &.{.{ "a", "abc\\" }});
}

test "extract MIME: first charset carries only while essence stays the same" {
    try expectMime(std.testing.allocator, &.{"text/html;charset=gbk, text/html;charset=utf-8, text/html;x=y"}, "text/html", &.{ .{ "x", "y" }, .{ "charset", "gbk" } });
    try expectMime(std.testing.allocator, &.{ "text/html;charset=gbk", "x/x", "text/html;x=y" }, "text/html", &.{.{ "x", "y" }});
}

fn allocationTrial(allocator: std.mem.Allocator) !void {
    try expectMime(allocator, &.{"text/html;charset=gbk, text/html;x=y"}, "text/html", &.{ .{ "x", "y" }, .{ "charset", "gbk" } });
}

test "extract MIME releases allocations on every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationTrial, .{});
}

test "get decode split preserves quoted X-Content-Type-Options" {
    var headers = fetch.internal.HeaderList.init(std.testing.allocator);
    defer headers.deinit();
    try headers.append("X-Content-Type-Options", "\"nosniff\"");
    const values = (try headers.getDecodeSplit(std.testing.allocator, "X-Content-Type-Options")).?;
    defer {
        for (values) |value| std.testing.allocator.free(value);
        std.testing.allocator.free(values);
    }
    try std.testing.expectEqual(@as(usize, 1), values.len);
    try std.testing.expectEqualStrings("\"nosniff\"", values[0]);
}
