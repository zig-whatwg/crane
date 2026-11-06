//! A response handed on at its headers - its body still arriving, as a
//! navigation's is - has its body info's content encoding from the start:
//! HTTP-network fetch sets "response's body info's content encoding" from the
//! response's `Content-Encoding` header (the filtered coding,
//! `filteredContentCoding`) when it makes the response, before any of its body
//! has come. Navigation Timing's contentEncoding reads it from the navigation
//! timing entry made before the document's parser runs
//! (navigation-timing/content-encoding.https.html?pipe=gzip; lane loadpath1:
//! the page load streams since it became a navigation).
const std = @import("std");
const fetch = @import("fetch");
const body_pipe = fetch.internal.body_pipe;

test "a streamed response has its body info's content encoding at its headers" {
    const allocator = std.testing.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, "http://example.test/page.html");
    defer request.deinit();
    const controller = try fetch.internal.FetchController.init(allocator);
    defer controller.deinit();
    var timing = fetch.internal.FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try fetch.internal.FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    for ([_]struct { value: ?[]const u8, expected: []const u8 }{
        .{ .value = "gzip", .expected = "gzip" },
        .{ .value = "br", .expected = "br" },
        .{ .value = "gzip, br", .expected = "multiple" },
        .{ .value = null, .expected = "" },
    }) |case| {
        var with = [_]fetch.network.NetworkResponse.Header{.{ .name = "Content-Encoding", .value = case.value orelse "" }};
        const answer = fetch.network.NetworkResponse{
            .allocator = allocator,
            .status = 200,
            .http_version = .http_1_1,
            .headers = if (case.value != null) &with else &.{},
            // A body still arriving: none yet (the pipe carries it).
            .body = null,
            .final_url = null,
            .total_time_ms = 0,
            .time_to_first_byte_ms = 0,
            .redirect_count = 0,
            .remote_ip = null,
            .remote_port = null,
        };
        // The body's pipe: nothing has arrived yet. Its ownership passes to
        // the response.
        const source = try body_pipe.PipeSource.create(allocator);
        const pipe = try source.branch();
        const response = try fetch.algorithms.http_fetch.httpNetworkFetchFinish(allocator, params, &answer, 10, pipe);
        defer response.deinit();
        try std.testing.expectEqualStrings(case.expected, response.body_info.content_encoding);
    }
}
