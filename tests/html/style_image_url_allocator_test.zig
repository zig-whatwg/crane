//! The image-cache lookup may use call-local URL storage, never its queued task.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const fixture = @import("rf_fixture.zig");

test "document URL parsing returns storage from its explicit allocator" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    try dom.document_internals.setURL(page.document, "https://example.test/dir/page");
    for ([_]struct { encoding: []const u8, expected: []const u8 }{
        .{ .encoding = "UTF-8", .expected = "https://example.test/dir/%C3%A9?q=%C3%A9" },
        .{ .encoding = "windows-1252", .expected = "https://example.test/dir/%C3%A9?q=%E9" },
    }) |case| {
        try dom.document_internals.setEncoding(page.document, case.encoding);
        var counts = std.testing.FailingAllocator.init(std.testing.allocator, .{});
        const allocator = counts.allocator();
        {
            const url = (try dom.encoding_parse.encodingParseAndSerializeWithAllocator(allocator, page.element, "é?q=é")) orelse return error.InvalidURL;
            defer allocator.free(url);
            try std.testing.expectEqualStrings(case.expected, url);
            try std.testing.expect(counts.allocations > 0);
        }
        try std.testing.expectEqual(counts.allocated_bytes, counts.freed_bytes);
        // Existing callers still receive context-owned storage.
        const default_url = (try dom.encoding_parse.encodingParseAndSerialize(page.element, "é?q=é")) orelse return error.InvalidURL;
        defer std.testing.allocator.free(default_url);
        try std.testing.expectEqualStrings(case.expected, default_url);
    }
}

test "ordinary image URLs fit call-local parsing storage" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    try dom.document_internals.setURL(page.document, "http://web-platform.test:8000/crane/page.html");
    var fallback = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var memory = std.heap.stackFallback(4096, fallback.allocator());
    const allocator = memory.get();
    const url = (try dom.encoding_parse.encodingParseAndSerializeWithAllocator(allocator, page.element, "/images/green.png?ds1-image-cost=42")) orelse return error.InvalidURL;
    defer allocator.free(url);
    try std.testing.expectEqualStrings("http://web-platform.test:8000/images/green.png?ds1-image-cost=42", url);
    try std.testing.expect(memory.fixed_buffer_allocator.ownsPtr(@constCast(url.ptr)));
    try std.testing.expectEqual(@as(usize, 0), fallback.allocations);
}

test "long document-relative URLs use and release the fallback allocator" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    try dom.document_internals.setURL(page.document, "https://example.test/dir/page");
    const padding = @as([8192]u8, @splat('x'));
    const input = try std.fmt.allocPrint(std.testing.allocator, "image.png?pad={s}", .{&padding});
    defer std.testing.allocator.free(input);
    const expected = try std.fmt.allocPrint(std.testing.allocator, "https://example.test/dir/{s}", .{input});
    defer std.testing.allocator.free(expected);
    var fallback = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    {
        var memory = std.heap.stackFallback(4096, fallback.allocator());
        const allocator = memory.get();
        const url = (try dom.encoding_parse.encodingParseAndSerializeWithAllocator(allocator, page.element, input)) orelse return error.InvalidURL;
        defer allocator.free(url);
        try std.testing.expectEqualStrings(expected, url);
        try std.testing.expect(fallback.allocations > 0);
    }
    try std.testing.expectEqual(fallback.allocated_bytes, fallback.freed_bytes);
}

fn parseAtFailures(allocator: std.mem.Allocator, element: *runtime.Instance, input: []const u8, expected: ?[]const u8) !void {
    const result = try dom.encoding_parse.encodingParseAndSerializeWithAllocator(allocator, element, input);
    defer if (result) |url| allocator.free(url);
    if (expected) |value| {
        try std.testing.expectEqualStrings(value, result orelse return error.InvalidURL);
    } else {
        try std.testing.expect(result == null);
    }
}

fn fallbackAtFailures(allocator: std.mem.Allocator, element: *runtime.Instance, input: []const u8, expected: []const u8) !void {
    var memory = std.heap.stackFallback(4096, allocator);
    const temporary = memory.get();
    const url = (try dom.encoding_parse.encodingParseAndSerializeWithAllocator(temporary, element, input)) orelse return error.InvalidURL;
    defer temporary.free(url);
    // Only this durable allocation is allowed to survive the lookup's stack.
    const kept = try allocator.dupe(u8, url);
    defer allocator.free(kept);
    try std.testing.expectEqualStrings(expected, kept);
}

test "explicit URL allocation failure cleans up without taking context-owned strings" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    try dom.document_internals.setURL(page.document, "https://example.test/dir/page");
    try dom.document_internals.setEncoding(page.document, "windows-1252");
    try std.testing.checkAllAllocationFailures(std.testing.allocator, parseAtFailures, .{ page.element, "é?q=é", @as(?[]const u8, "https://example.test/dir/%C3%A9?q=%E9") });
    try std.testing.checkAllAllocationFailures(std.testing.allocator, parseAtFailures, .{ page.element, "http://[", @as(?[]const u8, null) });
    // The baseURI allocation uses ctx.allocator, independently of the failing
    // parser allocator; the original document remains usable after every error.
    const after = (try dom.encoding_parse.encodingParseAndSerialize(page.element, "next.png")) orelse return error.InvalidURL;
    defer std.testing.allocator.free(after);
    try std.testing.expectEqualStrings("https://example.test/dir/next.png", after);
}

test "fallback URL parsing and durable copying clean up every allocation failure" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    try dom.document_internals.setURL(page.document, "https://example.test/dir/page");
    const padding = @as([8192]u8, @splat('x'));
    const input = try std.fmt.allocPrint(std.testing.allocator, "image.png?pad={s}", .{&padding});
    defer std.testing.allocator.free(input);
    const expected = try std.fmt.allocPrint(std.testing.allocator, "https://example.test/dir/{s}", .{input});
    defer std.testing.allocator.free(expected);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, fallbackAtFailures, .{ page.element, input, expected });
    try std.testing.checkAllAllocationFailures(std.testing.allocator, fallbackAtFailures, .{ page.element, "image.png", "https://example.test/dir/image.png" });
}
