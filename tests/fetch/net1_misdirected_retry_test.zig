//! Fetch, HTTP-network-or-cache fetch step 17: a 421 (Misdirected Request) on
//! a connection that was not new is retried once, on a new connection, when
//! the request can be sent again - its body null, or a body with a source.
//! fetch/api/basic/request-upload-421.any.js ("Request was sent 2 times. 2
//! connections were created."; Chrome and Firefox pass it, wpt.fyi runs
//! 4786307730243584 / 4877168468033536) was sent once.
const std = @import("std");
const fetch = @import("fetch");
const http = fetch.algorithms.http_fetch;
const internal = fetch.internal;

const Body = enum { absent, bytes, stream };

const Case = struct {
    body: Body = .absent,
    status: u16 = 421,
    is_new_connection_fetch: bool = false,
    canceled: bool = false,
};

const Outcome = enum { retried, kept, network_error };

fn finish(case: Case) !Outcome {
    const allocator = std.testing.allocator;
    const request = try internal.InternalRequest.init(allocator, "https://a.test/upload");
    defer request.deinit();
    try request.setOrigin("https://a.test");
    try request.setMethod("POST");
    request.body = switch (case.body) {
        .absent => null,
        .bytes => .{ .body = try internal.Body.fromBytes(allocator, "foobar") },
        .stream => .{ .body = try internal.Body.fromSource(allocator, .none, 0) },
    };
    const controller = try internal.FetchController.init(allocator);
    defer controller.deinit();
    var timing = internal.FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try internal.FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();
    if (case.canceled) try controller.abort(null);

    const response = try internal.InternalResponse.init(allocator);
    response.status = case.status;
    const finished = try http.httpNetworkOrCacheFetchFinish(allocator, params, .{ .is_new_connection_fetch = case.is_new_connection_fetch }, response);
    switch (finished) {
        .new_connection_retry => {
            // A body sent again is the same bytes.
            if (request.body) |b| try std.testing.expectEqualStrings("foobar", b.body.getBytes());
            return .retried;
        },
        .authentication_retry => |realm| {
            allocator.free(realm);
            return error.UnexpectedAuthenticationRetry;
        },
        .response => |r| {
            defer r.deinit();
            if (r.response_type == .@"error") return .network_error;
            try std.testing.expectEqual(case.status, r.status);
            return .kept;
        },
    }
}

test "net1 421: a misdirected request with no body, or a body with a source, is retried once on a new connection" {
    try std.testing.expectEqual(Outcome.retried, try finish(.{}));
    try std.testing.expectEqual(Outcome.retried, try finish(.{ .body = .bytes }));
}

test "net1 421: not again on the new connection, nor for a body made from a stream, nor for another status" {
    try std.testing.expectEqual(Outcome.kept, try finish(.{ .is_new_connection_fetch = true }));
    try std.testing.expectEqual(Outcome.kept, try finish(.{ .body = .stream }));
    try std.testing.expectEqual(Outcome.kept, try finish(.{ .status = 200 }));
    try std.testing.expectEqual(Outcome.kept, try finish(.{ .status = 400 }));
}

test "net1 421: a canceled fetch answers the appropriate network error instead of a retry" {
    try std.testing.expectEqual(Outcome.network_error, try finish(.{ .canceled = true }));
}

test "net1 421: the retry asks HTTP-network fetch for a new connection; the first request does not" {
    const allocator = std.testing.allocator;
    const request = try internal.InternalRequest.init(allocator, "http://a.test/upload");
    defer request.deinit();
    const controller = try internal.FetchController.init(allocator);
    defer controller.deinit();
    var timing = internal.FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try internal.FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    const first = try http.httpNetworkOrCacheFetchStart(allocator, params, .{});
    defer http.freeNetworkRequest(allocator, first.network.request);
    try std.testing.expect(!first.network.request.force_new_connection);

    const again = try http.httpNetworkOrCacheFetchStart(allocator, params, .{ .is_new_connection_fetch = true });
    defer http.freeNetworkRequest(allocator, again.network.request);
    try std.testing.expect(again.network.request.force_new_connection);
}
