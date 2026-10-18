//! HTTP fetch step 3.5 for a service worker's response: whether the
//! client's timing allow check passes. Chromium's
//! ServiceWorkerSubresourceLoader: a synthetic or basic response passes; a
//! filtered (CORS or opaque) one passes only when the worker's own fetch of
//! it passed the TAO check AND its `Timing-Allow-Origin` names the client's
//! origin (or `*`). Chrome and Firefox pass cases 1-6 of
//! service-workers/.../resource-timing-cross-origin-server-timing.https.html.
const std = @import("std");
const fetch = @import("fetch");

test "a service worker's filtered response passes TAO only as its own fetch did, for the client's origin" {
    const allocator = std.testing.allocator;
    const Case = struct {
        type: fetch.internal.ResponseType,
        passed: bool,
        tao: ?[]const u8,
        failed: bool,
    };
    for ([_]Case{
        // 1-2. Cross-origin opaque or CORS without TAO: the worker's fetch failed it.
        .{ .type = .@"opaque", .passed = false, .tao = null, .failed = true },
        .{ .type = .cors, .passed = false, .tao = null, .failed = true },
        // 3-4. With `Timing-Allow-Origin: *`: passes.
        .{ .type = .cors, .passed = true, .tao = "*", .failed = false },
        .{ .type = .@"opaque", .passed = true, .tao = "*", .failed = false },
        // The worker's TAO named the worker's origin, not the client's.
        .{ .type = .cors, .passed = true, .tao = "https://other.test", .failed = true },
        .{ .type = .cors, .passed = true, .tao = "https://a.test", .failed = false },
        // 7 (a redirect whose first hop lacked TAO): the worker's fetch failed it.
        .{ .type = .cors, .passed = false, .tao = "*", .failed = true },
        // 5. Synthetic: passes.
        .{ .type = .default, .passed = false, .tao = null, .failed = false },
        // 6. Same-origin: passes.
        .{ .type = .basic, .passed = true, .tao = null, .failed = false },
    }) |case| {
        const request = try fetch.internal.InternalRequest.init(allocator, "https://a.test/sub");
        defer request.deinit();
        try request.setOrigin("https://a.test");
        request.mode = if (case.type == .@"opaque") .no_cors else .cors;
        const controller = try fetch.internal.FetchController.init(allocator);
        defer controller.deinit();
        var timing = fetch.internal.FetchTimingInfo.init(allocator);
        defer timing.deinit();
        const params = try fetch.internal.FetchParams.init(allocator, request, controller, &timing);
        defer params.deinit();
        const response = try fetch.internal.InternalResponse.init(allocator);
        response.status = 200;
        response.response_type = case.type;
        response.timing_allow_passed = case.passed;
        if (case.type != .default) try response.addUrl("https://b.test/sub");
        if (case.tao) |value| try response.header_list.append("Timing-Allow-Origin", value);
        const next = try fetch.algorithms.http_fetch.serviceWorkerResponse(allocator, params, response, 1.0);
        defer next.response.deinit();
        try std.testing.expect(next.response.response_type != .@"error");
        try std.testing.expectEqual(case.failed, request.timing_allow_failed);
    }
}
