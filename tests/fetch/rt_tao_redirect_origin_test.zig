const std = @import("std");
const fetch = @import("fetch");

test "TAO compares the serialized redirect-tainted origin" {
    const allocator = std.testing.allocator;
    for ([_]struct { tao: []const u8, failed: bool }{
        .{ .tao = "http://a.test", .failed = true },
        .{ .tao = "null", .failed = false },
        .{ .tao = "*", .failed = false },
        .{ .tao = "http://other.test, null", .failed = false },
    }) |case| {
        const request = try fetch.internal.InternalRequest.init(allocator, "http://b.test/first");
        defer request.deinit();
        try request.setOrigin("http://a.test");
        try request.addUrl("http://a.test/final");
        request.mode = .no_cors;
        request.response_tainting = .@"opaque";
        const controller = try fetch.internal.FetchController.init(allocator);
        defer controller.deinit();
        var timing = fetch.internal.FetchTimingInfo.init(allocator);
        defer timing.deinit();
        const params = try fetch.internal.FetchParams.init(allocator, request, controller, &timing);
        defer params.deinit();
        const response = try fetch.internal.InternalResponse.init(allocator);
        response.status = 200;
        try response.header_list.append("Timing-Allow-Origin", case.tao);
        const next = try fetch.algorithms.http_fetch.httpFetchFinish(allocator, params, .{}, response);
        defer next.response.deinit();
        try std.testing.expectEqual(case.failed, request.timing_allow_failed);
    }
}
