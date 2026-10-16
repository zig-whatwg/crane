const std = @import("std");
const fetch = @import("fetch");

test "resource timing reports no content coding for identity, as browsers do" {
    const allocator = std.testing.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, "http://example.test/resource");
    defer request.deinit();
    const controller = try fetch.internal.FetchController.init(allocator);
    defer controller.deinit();
    var timing = fetch.internal.FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try fetch.internal.FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();
    for ([_]struct { value: []const u8, expected: []const u8 }{
        .{ .value = "identity", .expected = "@unknown" },
        .{ .value = "gZip", .expected = "gzip" },
        .{ .value = "gzip, deflate", .expected = "multiple" },
        .{ .value = "unregistered", .expected = "@unknown" },
        .{ .value = "", .expected = "" },
    }) |case| {
        var headers = [_]fetch.network.NetworkResponse.Header{.{ .name = "Content-Encoding", .value = case.value }};
        const answer = fetch.network.NetworkResponse{
            .allocator = allocator,
            .status = 200,
            .http_version = .http_1_1,
            .headers = &headers,
            .body = "decoded",
            .final_url = null,
            .total_time_ms = 0,
            .time_to_first_byte_ms = 0,
            .redirect_count = 0,
            .remote_ip = null,
            .remote_port = null,
        };
        const response = try fetch.algorithms.http_fetch.httpNetworkFetchFinish(allocator, params, &answer, 10, null);
        defer response.deinit();
        try std.testing.expectEqualStrings(case.expected, response.body_info.content_encoding);
    }
}
