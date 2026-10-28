//! Fetch 4.12: deferred request sizes and quota accounting.
const std = @import("std");
const fetch = @import("fetch");
const deferred = fetch.deferred_fetch;
const Request = fetch.internal.InternalRequest;

test "deferred request length includes URL, referrer, every header, and body" {
    try requestLengthCase(std.testing.allocator);
}

test "deferred request length setup is allocation-failure safe" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, requestLengthCase, .{});
}

fn requestLengthCase(allocator: std.mem.Allocator) !void {
    const request = try Request.init(allocator, "https://example.test/path?q=1#not-sent");
    defer request.deinit();
    try request.header_list.append("X-Value", "one");
    try request.header_list.append("X-Value", "two");
    // Complete the fallible allocation before publishing the union tag.
    const body = try fetch.internal.Body.fromBytes(allocator, "\xc3\xa9");
    request.body = .{ .body = body };
    const referrer = "https://example.test/source";
    const want = "https://example.test/path?q=1".len + referrer.len + 2 * "X-Value".len + "one".len + "two".len + 2;
    try std.testing.expectEqual(@as(u64, want), try deferred.totalRequestLength(request, referrer));
}

test "deferred request length counts encoded fragments in the path but excludes the fragment" {
    const request = try Request.init(std.testing.allocator, "https://example.test/%23?q=%23#ignored");
    defer request.deinit();
    try std.testing.expectEqual(@as(u64, "https://example.test/%23?q=%23".len), try deferred.totalRequestLength(request, ""));
}

test "deferred request length counts client, absent and URL referrer serializations before population" {
    const request = try Request.init(std.testing.allocator, "https://example.test/");
    defer request.deinit();
    // fetchLater step 12 precedes queue/populate. Chromium's serialization,
    // confirmed by liaison Q15, is about:client rather than the client's URL.
    try std.testing.expectEqual(@as(u64, request.getUrl().len + 12), try deferred.totalRequestLength(request, "about:client"));
    try std.testing.expectEqual(@as(u64, request.getUrl().len), try deferred.totalRequestLength(request, ""));
    const referrer = "https://referrer.test/path";
    try std.testing.expectEqual(@as(u64, request.getUrl().len + referrer.len), try deferred.totalRequestLength(request, referrer));
    try std.testing.expectEqual(fetch.internal.request.Referrer.client, request.referrer);
}

test "deferred fetching refuses a body whose length is unknown" {
    const request = try Request.init(std.testing.allocator, "https://example.test/");
    defer request.deinit();
    const body = try fetch.internal.Body.fromSource(std.testing.allocator, .none, null);
    request.body = .{ .body = body };
    try std.testing.expectError(error.UnknownBodyLength, deferred.totalRequestLength(request, ""));
}
