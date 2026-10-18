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

test "HTTP fetch 3.5.3: the timing info takes the service worker response's timing info" {
    const allocator = std.testing.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, "https://a.test/page");
    defer request.deinit();
    try request.setOrigin("https://a.test");
    request.mode = .navigate;
    const controller = try fetch.internal.FetchController.init(allocator);
    defer controller.deinit();
    var timing = fetch.internal.FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try fetch.internal.FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();
    const response = try fetch.internal.InternalResponse.init(allocator);
    response.status = 200;
    response.service_worker_timing_info = .{ .start_time = 5.0, .fetch_event_dispatch_time = 9.5 };
    timing.post_redirect_start_time = 3.0;
    const next = try fetch.algorithms.http_fetch.serviceWorkerResponse(allocator, params, response, 4.0);
    defer next.response.deinit();
    try std.testing.expectEqual(@as(f64, 4.0), timing.final_service_worker_start_time);
    const sw = timing.service_worker_timing_info orelse return error.TestExpectedServiceWorkerTiming;
    try std.testing.expectEqual(@as(f64, 5.0), sw.start_time);
    try std.testing.expectEqual(@as(f64, 9.5), sw.fetch_event_dispatch_time);
    // No connection was made for the client: its connection times are its
    // fetch start (Chrome, Firefox and Safari: connectStart == fetchStart,
    // resource-timing-fetch-variants.https.html), no TLS time.
    const connection = timing.final_connection_timing_info orelse return error.TestExpectedConnectionTiming;
    try std.testing.expectEqual(@as(f64, 3.0), connection.domain_lookup_start_time);
    try std.testing.expectEqual(@as(f64, 3.0), connection.connection_end_time);
    try std.testing.expectEqual(@as(f64, 0), connection.secure_connection_start_time);
}

// Fetch response handover 4.2.4's body info, as Crane reads it: hidden for
// an opaque, opaque-redirect or error response; a CORS response keeps it
// (whatwg/fetch #1556) unless a service worker provided it and its timing
// allow check failed (Chrome and Firefox; the integrator's ruling B).
test "a service worker's CORS response without TAO hides its body sizes" {
    const allocator = std.testing.allocator;
    const Case = struct { type: fetch.internal.ResponseType, passed: bool, from_worker: bool, hidden: bool, client_cors: bool = false };
    for ([_]Case{
        .{ .type = .cors, .passed = false, .from_worker = true, .hidden = true },
        // The client's own request was a CORS request for that response
        // (resource-timing-bodySize.https.html's passthrough, cors): its
        // sizes stay, as #1556 has them.
        .{ .type = .cors, .passed = false, .from_worker = true, .hidden = false, .client_cors = true },
        .{ .type = .cors, .passed = true, .from_worker = true, .hidden = false },
        .{ .type = .cors, .passed = false, .from_worker = false, .hidden = false },
        .{ .type = .basic, .passed = false, .from_worker = true, .hidden = false },
        .{ .type = .@"opaque", .passed = true, .from_worker = false, .hidden = true },
        .{ .type = .opaqueredirect, .passed = true, .from_worker = false, .hidden = true },
    }) |case| {
        const response = try fetch.internal.InternalResponse.init(allocator);
        defer response.deinit();
        response.response_type = case.type;
        response.timing_allow_passed = case.passed;
        if (case.from_worker) response.service_worker_timing_info = .{ .start_time = 1, .fetch_event_dispatch_time = 2 };
        try std.testing.expectEqual(case.hidden, fetch.algorithms.fetch_job.bodyInfoHidden(response, if (case.client_cors) .cors else .basic));
    }
}
