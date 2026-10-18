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

// TAO step 6 for a navigation whose chain went through another origin and
// came back (SO -> XO -> SO): the request is redirect-tainted, and the hop
// without `Timing-Allow-Origin` fails - Chromium's CorsURLLoader::
// PassesTimingAllowOriginCheck fails a navigate-mode request that is
// `tainted_` whatever its current URL; Chrome, Firefox and Safari all mask
// resource-timing/SO-XO-SO-redirect-chain-tao.https.html's partial-TAO case.
// A same-origin chain still passes (step 7, basic tainting).
test "TAO step 6: a redirect-tainted navigation fails without TAO" {
    const allocator = std.testing.allocator;
    for ([_]struct { urls: []const []const u8, failed: bool }{
        .{ .urls = &.{ "https://a.test/1", "https://b.test/2", "https://a.test/3" }, .failed = true },
        .{ .urls = &.{ "https://a.test/1", "https://a.test/2" }, .failed = false },
        .{ .urls = &.{"https://a.test/1"}, .failed = false },
    }) |case| {
        const request = try fetch.internal.InternalRequest.init(allocator, case.urls[0]);
        defer request.deinit();
        try request.setOrigin("https://a.test");
        for (case.urls[1..]) |url| try request.addUrl(url);
        request.mode = .navigate;
        request.destination = .iframe;
        request.response_tainting = .basic;
        const controller = try fetch.internal.FetchController.init(allocator);
        defer controller.deinit();
        var timing = fetch.internal.FetchTimingInfo.init(allocator);
        defer timing.deinit();
        const params = try fetch.internal.FetchParams.init(allocator, request, controller, &timing);
        defer params.deinit();
        const response = try fetch.internal.InternalResponse.init(allocator);
        response.status = 200;
        const next = try fetch.algorithms.http_fetch.httpFetchFinish(allocator, params, .{}, response);
        defer next.response.deinit();
        try std.testing.expectEqual(case.failed, request.timing_allow_failed);
    }
}
