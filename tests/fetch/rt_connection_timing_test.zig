const std = @import("std");
const fetch = @import("fetch");

/// The network's measurements of one transfer, ms after it started.
const Measures = struct {
    dns: f64 = 2,
    connect: f64 = 5,
    app_connect: f64 = 8,
    pretransfer: f64 = 9,
    first_byte: f64 = 10,
};

fn recordTiming(url: []const u8, reused: bool, post_redirect_start: f64) !fetch.internal.FetchTimingInfo {
    return recordMeasuredTiming(url, reused, post_redirect_start, .{});
}

fn recordMeasuredTiming(url: []const u8, reused: bool, post_redirect_start: f64, measures: Measures) !fetch.internal.FetchTimingInfo {
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
        .time_to_first_byte_ms = measures.first_byte,
        .redirect_count = 0,
        .remote_ip = null,
        .remote_port = null,
        .dns_lookup_time_ms = measures.dns,
        .connect_time_ms = measures.connect,
        .app_connect_time_ms = measures.app_connect,
        .pretransfer_time_ms = measures.pretransfer,
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

test "a fresh connection's sub-millisecond phases keep their fractions" {
    // A loopback connection: DNS 17 us, TCP connected at 0.2 ms, TLS done at
    // 0.9 ms, the request sent at 0.92 ms and its first byte at 1.5 ms. Each
    // phase starts and ends where it happened, not on a whole millisecond:
    // floored, the TLS start fell on the transfer's start and in fetchStart's
    // coarsening tick - secure-connection-start-non-zero.https.html read 0
    // in 28 of 30 runs after a file whose connections had closed (lane
    // flaky6). Chrome, Firefox and Safari all expose these phases below a
    // millisecond (Blink LoadTimingInfo::ConnectTiming, Gecko's
    // nsITimedChannel TimeStamps, WebKit NetworkLoadMetrics, each a precise
    // time coarsened only when exposed).
    var timing = try recordMeasuredTiming("https://example.test/resource", false, 90.225, .{
        .dns = 0.017,
        .connect = 0.2,
        .app_connect = 0.9,
        .pretransfer = 0.92,
        .first_byte = 1.5,
    });
    defer timing.deinit();
    const connection = timing.final_connection_timing_info.?;
    try std.testing.expectEqual(@as(f64, 100.375), connection.domain_lookup_start_time);
    try std.testing.expectApproxEqAbs(@as(f64, 100.392), connection.domain_lookup_end_time, 1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, 100.392), connection.connection_start_time, 1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, 100.575), connection.secure_connection_start_time, 1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, 101.275), connection.connection_end_time, 1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, 101.295), timing.final_network_request_start_time, 1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, 101.875), timing.final_network_response_start_time, 1e-9);
}
