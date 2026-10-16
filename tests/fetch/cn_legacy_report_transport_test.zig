//! CSP report-uri uses no-cors and refuses redirects, including across origins.
const std = @import("std");
const fetch = @import("fetch");
const a = std.testing.allocator;

fn exercise(destination: fetch.internal.Destination, origin: []const u8, expect_network: bool, redirect_response: bool) !void {
    const request = try fetch.internal.InternalRequest.init(a, "https://reports.test/report");
    defer request.deinit();
    try request.setOrigin(origin);
    try request.setMethod("POST");
    request.mode = .no_cors;
    request.redirect_mode = .@"error";
    request.destination = destination;
    request.credentials_mode = .same_origin;
    request.keepalive = true;
    const controller = try fetch.internal.FetchController.init(a);
    defer controller.deinit();
    var timing = fetch.internal.FetchTimingInfo.init(a);
    defer timing.deinit();
    const params = try fetch.internal.FetchParams.init(a, request, controller, &timing);
    defer params.deinit();

    const start = try fetch.algorithms.main_fetch.mainFetchStart(a, params, false);
    switch (start) {
        .http_fetch => try std.testing.expect(expect_network),
        .response => |response| {
            defer response.deinit();
            try std.testing.expect(!expect_network);
            try std.testing.expectEqual(fetch.internal.ResponseType.@"error", response.response_type);
            return;
        },
        else => return error.UnexpectedPreflight,
    }
    try std.testing.expectEqual(fetch.internal.ResponseTainting.@"opaque", request.response_tainting);
    if (redirect_response) {
        const response = try fetch.internal.InternalResponse.init(a);
        response.status = 302;
        const finish = try fetch.algorithms.http_fetch.httpFetchFinish(a, params, .{}, response);
        switch (finish) {
            .response => |blocked| {
                defer blocked.deinit();
                try std.testing.expectEqual(fetch.internal.ResponseType.@"error", blocked.response_type);
            },
            else => return error.FollowedReportRedirect,
        }
    }
}

test "legacy reports reach cross-origin endpoints without a CORS preflight" {
    try exercise(.report, "https://sender.test", true, false);
    try exercise(.report, "null", true, false);
}

test "ordinary no-cors requests still reject redirect error across origins" {
    try exercise(.empty, "https://sender.test", false, false);
    try exercise(.image, "https://sender.test", false, false);
}

test "a cross-origin legacy report still refuses an actual HTTP redirect" {
    try exercise(.report, "https://sender.test", true, true);
}
