const std = @import("std");
const fetch = @import("fetch");

fn recordTiming(url: []const u8, reused: bool, post_redirect_start: f64) !fetch.internal.FetchTimingInfo {
    const allocator = std.testing.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, url);
    defer request.deinit();
    const controller = try fetch.internal.FetchController.init(allocator);
    defer controller.deinit();
    var timing = fetch.internal.FetchTimingInfo.init(allocator);
    errdefer timing.deinit();
    timing.start_time = 10.125;
    timing.post_redirect_start_time = post_redirect_start;
    const params = try fetch.internal.FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();
    const answer = fetch.network.NetworkResponse{
        .allocator = allocator,
        .status = 200,
        .http_version = .http_1_1,
        .headers = &.{},
        .body = null,
        .final_url = null,
        .total_time_ms = 20,
        .time_to_first_byte_ms = 10,
        .redirect_count = 0,
        .remote_ip = null,
        .remote_port = null,
        .dns_lookup_time_ms = 2,
        .connect_time_ms = 5,
        .app_connect_time_ms = 8,
        .pretransfer_time_ms = 9,
        .connection_reused = reused,
    };
    // A deliberately later network start makes the reuse bug deterministic,
    // rather than depending on which side of a 100-us boundary a clock reads.
    const response = try fetch.algorithms.http_fetch.httpNetworkFetchFinish(allocator, params, &answer, 100.375, null);
    defer response.deinit();
    return timing;
}

test "reused connections copy this fetch's post-redirect start exactly" {
    for ([_]f64{ 10.125, 90.225 }) |fetch_start| {
        var timing = try recordTiming("https://example.test/resource", true, fetch_start);
        defer timing.deinit();
        const connection = timing.final_connection_timing_info.?;
        try std.testing.expectEqual(fetch_start, connection.domain_lookup_start_time);
        try std.testing.expectEqual(fetch_start, connection.domain_lookup_end_time);
        try std.testing.expectEqual(fetch_start, connection.connection_start_time);
        try std.testing.expectEqual(fetch_start, connection.connection_end_time);
        try std.testing.expectEqual(fetch_start, connection.secure_connection_start_time);
        try std.testing.expectEqualStrings("http/1.1", connection.alpn_negotiated_protocol);
        try std.testing.expectEqual(@as(f64, 109.375), timing.final_network_request_start_time);
        try std.testing.expectEqual(@as(f64, 110.375), timing.final_network_response_start_time);
    }
}

test "reused cleartext connections have no TLS start" {
    var timing = try recordTiming("http://example.test/resource", true, 90.225);
    defer timing.deinit();
    const connection = timing.final_connection_timing_info.?;
    try std.testing.expectEqual(@as(f64, 0), connection.secure_connection_start_time);
    try std.testing.expectEqual(timing.post_redirect_start_time, connection.connection_end_time);
}

test "fresh connections keep their measured DNS TCP and TLS intervals" {
    var timing = try recordTiming("https://example.test/resource", false, 90.225);
    defer timing.deinit();
    const connection = timing.final_connection_timing_info.?;
    try std.testing.expectEqual(@as(f64, 100.375), connection.domain_lookup_start_time);
    try std.testing.expectEqual(@as(f64, 102.375), connection.domain_lookup_end_time);
    try std.testing.expectEqual(@as(f64, 102.375), connection.connection_start_time);
    try std.testing.expectEqual(@as(f64, 105.375), connection.secure_connection_start_time);
    try std.testing.expectEqual(@as(f64, 108.375), connection.connection_end_time);
}
