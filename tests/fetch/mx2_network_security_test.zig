//! Network-only browser headers and Mixed Content's network-error result.
const std = @import("std");
const fetch = @import("fetch");
const http = fetch.algorithms.http_fetch;
const main = fetch.algorithms.main_fetch;

test "network headers add Connection once without exposing it to script or replacing an explicit value" {
    const allocator = std.testing.allocator;
    for ([_]bool{ false, true }) |explicit| {
        const request = try fetch.internal.InternalRequest.init(allocator, "http://example.test/resource");
        defer request.deinit();
        if (explicit) try request.header_list.append("cOnNeCtIoN", "close");
        const controller = try fetch.internal.FetchController.init(allocator);
        defer controller.deinit();
        var timing = fetch.internal.FetchTimingInfo.init(allocator);
        defer timing.deinit();
        const params = try fetch.internal.FetchParams.init(allocator, request, controller, &timing);
        defer params.deinit();

        // A redirect/retry builds its own outgoing headers from this same
        // request. The user agent's addition must not accumulate there.
        for (0..2) |_| {
            const started = try http.httpNetworkOrCacheFetchStart(allocator, params, .{});
            const network = started.network.request;
            defer http.freeNetworkRequest(allocator, network);
            var count: usize = 0;
            for (network.headers) |header| {
                if (std.ascii.eqlIgnoreCase(header.name, "connection")) {
                    count += 1;
                    try std.testing.expectEqualStrings(if (explicit) "close" else "keep-alive", header.value);
                }
            }
            try std.testing.expectEqual(@as(usize, 1), count);
            try std.testing.expectEqual(explicit, request.header_list.contains("Connection"));
        }
    }
}

test "mixed response rejection clears body timing and cache metadata as a network error" {
    const allocator = std.testing.allocator;
    for ([_]fetch.internal.ResponseTainting{ .basic, .@"opaque" }) |tainting| {
        const request = try fetch.internal.InternalRequest.init(allocator, "https://example.test/request");
        defer request.deinit();
        request.prohibits_mixed_security_contexts = true;
        request.response_tainting = tainting;
        const controller = try fetch.internal.FetchController.init(allocator);
        defer controller.deinit();
        var timing = fetch.internal.FetchTimingInfo.init(allocator);
        defer timing.deinit();
        const params = try fetch.internal.FetchParams.init(allocator, request, controller, &timing);
        defer params.deinit();
        const response = try fetch.internal.InternalResponse.init(allocator);
        var response_owned = true;
        defer if (response_owned) response.deinit();
        try response.addUrl("http://example.test/response");
        try response.header_list.append("Content-Type", "text/plain");
        response.body = try fetch.internal.Body.fromBytes(allocator, "private content");
        response.timing_allow_passed = true;
        response.cache_state = .local;
        response.body_info = .{ .encoded_size = 7, .decoded_size = 15, .content_type = "text/plain", .content_encoding = "gzip" };

        const result = main.mainFetchFinish(params, false, response);
        response_owned = false;
        defer result.deinit();
        try std.testing.expectEqual(.@"error", result.response_type);
        try std.testing.expectEqualDeep(@as(fetch.internal.ResponseBodyInfo, .{}), result.body_info);
        try std.testing.expectEqual(.empty, result.cache_state);
        try std.testing.expect(!result.timing_allow_passed);
        try std.testing.expectEqual(@as(u16, 0), result.status);
        try std.testing.expectEqual(@as(usize, 0), result.url_list.items.len);
        try std.testing.expectEqual(@as(usize, 0), result.header_list.entries.items.len);
        try std.testing.expect(result.body == null);
    }
}
