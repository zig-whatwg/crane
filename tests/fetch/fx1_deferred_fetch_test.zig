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

test "deferred quota has separate document and request-origin limits" {
    var quota = deferred.Quota.init(512 * 1024);
    quota.reserveContainer(64 * 1024);
    quota.accountRequest(32 * 1024, true, .pending);
    quota.accountRequest(64 * 1024, false, .pending);
    try std.testing.expectEqual(@as(u64, 32 * 1024), quota.available());
    quota.accountRequest(32 * 1024, true, .pending);
    try std.testing.expectEqual(@as(u64, 0), quota.available());
}

test "sent and aborted deferred requests no longer consume quota" {
    var quota = deferred.Quota.init(8 * 1024);
    quota.accountRequest(8 * 1024, true, .sent);
    quota.accountRequest(8 * 1024, true, .aborted);
    try std.testing.expectEqual(@as(u64, 8 * 1024), quota.available());
    quota.accountRequest(1, false, .pending);
    try std.testing.expectEqual(@as(u64, 8 * 1024 - 1), quota.available());
}

test "deferred quota saturates instead of underflowing" {
    var reserved = deferred.Quota.init(8 * 1024);
    reserved.reserveContainer(64 * 1024);
    try std.testing.expectEqual(@as(u64, 0), reserved.available());
    var used = deferred.Quota.init(8 * 1024);
    used.accountRequest(std.math.maxInt(u64), true, .pending);
    try std.testing.expectEqual(@as(u64, 0), used.available());
}

test "deferred-fetch allocation follows top-level policy and container reservations" {
    const Case = struct { top: bool, full: bool, minimal: bool, reserved: u64, want: u64 };
    const cases = [_]Case{
        .{ .top = true, .full = true, .minimal = true, .reserved = 0, .want = 512 * 1024 },
        .{ .top = true, .full = true, .minimal = false, .reserved = 0, .want = 640 * 1024 },
        .{ .top = true, .full = false, .minimal = true, .reserved = 0, .want = 0 },
        .{ .top = true, .full = false, .minimal = false, .reserved = 0, .want = 0 },
        .{ .top = false, .full = true, .minimal = true, .reserved = 64 * 1024, .want = 64 * 1024 },
        .{ .top = false, .full = true, .minimal = true, .reserved = 8 * 1024, .want = 8 * 1024 },
        .{ .top = false, .full = false, .minimal = true, .reserved = 8 * 1024, .want = 8 * 1024 },
        .{ .top = false, .full = false, .minimal = true, .reserved = 64 * 1024, .want = 0 },
        .{ .top = false, .full = true, .minimal = false, .reserved = 8 * 1024, .want = 0 },
        .{ .top = false, .full = true, .minimal = true, .reserved = 0, .want = 0 },
    };
    for (cases) |case| try std.testing.expectEqual(case.want, deferred.allocatedQuota(.{
        .is_top_level = case.top,
        .deferred_fetch_allowed = case.full,
        .minimal_allowed = case.minimal,
        .reserved = case.reserved,
    }));
}

test "a deferred record activates once and transfers its request" {
    const request = try Request.init(std.testing.allocator, "https://example.test/");
    var record = deferred.Record.init(request, 21, 0);
    defer record.deinit();
    try std.testing.expectEqual(deferred.InvokeState.pending, record.invoke_state);
    const sent = record.takeForActivation() orelse return error.TestUnexpectedResult;
    defer sent.deinit();
    try std.testing.expectEqual(request, sent);
    try std.testing.expectEqual(deferred.InvokeState.sent, record.invoke_state);
    try std.testing.expectEqual(@as(?f64, 0), record.activate_after_ms);
    try std.testing.expect(record.takeForActivation() == null);
}

test "aborting a deferred record prevents sending and frees its unsent request" {
    const request = try Request.init(std.testing.allocator, "https://example.test/");
    var record = deferred.Record.init(request, 21, null);
    defer record.deinit();
    record.abort();
    record.abort();
    try std.testing.expectEqual(deferred.InvokeState.aborted, record.invoke_state);
    try std.testing.expect(record.takeForActivation() == null);
}

test "deferred request preparation snapshots policy and disables service worker interception" {
    try prepareCase(std.testing.allocator);
}

test "deferred request preparation unwinds every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, prepareCase, .{});
}

fn prepareCase(allocator: std.mem.Allocator) !void {
    var policy = fetch.internal.PolicyContainer.init(allocator);
    defer policy.deinit();
    policy.referrer_policy = .origin;
    const request = try Request.init(allocator, "https://destination.test/");
    defer request.deinit();
    try deferred.prepare(request, .{
        .origin = "https://client.test",
        .referrer_source = "https://client.test/page",
        .policy_container = &policy,
    });
    policy.referrer_policy = .no_referrer;
    try std.testing.expectEqualStrings("https://client.test", request.origin.origin);
    try std.testing.expectEqualStrings("https://client.test/page", request.referrer.url);
    try std.testing.expectEqual(fetch.internal.request.ReferrerPolicy.origin, request.policyContainerReferrerPolicy());
    try std.testing.expectEqual(fetch.internal.request.ServiceWorkersMode.none, request.service_workers_mode);
    try std.testing.expect(request.keepalive);
}
