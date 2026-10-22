//! A worker cannot replay a streamed upload to answer an authentication challenge.
const std = @import("std");
const fetch = @import("fetch");
const http = fetch.algorithms.http_fetch;
const internal = fetch.internal;

const Case = struct {
    source: enum { stream, bytes, absent } = .stream,
    challenge: ?[]const u8 = "Basic realm=\"fa3\"",
    credentials: internal.request.CredentialsMode = .same_origin,
    tainting: internal.request.ResponseTainting = .basic,
    status: u16 = 401,
    network_error: bool,
};

fn checkCase(case: Case) !void {
    try checkCaseAlloc(std.testing.allocator, case);
}

fn checkCaseAlloc(result_allocator: std.mem.Allocator, case: Case) !void {
    const allocator = std.testing.allocator;
    const request = try internal.InternalRequest.init(allocator, "https://a.test/upload");
    defer request.deinit();
    try request.setOrigin("https://a.test");
    try request.setMethod("POST");
    request.traversable_for_user_prompts = .no_traversable;
    request.credentials_mode = case.credentials;
    request.response_tainting = case.tainting;
    request.body = switch (case.source) {
        .stream => .{ .body = try internal.Body.fromSource(allocator, .none, 0) },
        .bytes => .{ .body = try internal.Body.fromBytes(allocator, "replayable") },
        .absent => null,
    };
    const controller = try internal.FetchController.init(allocator);
    defer controller.deinit();
    var timing = internal.FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try internal.FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    const response = try internal.InternalResponse.init(allocator);
    response.status = case.status;
    if (case.challenge) |challenge| response.header_list.append("WWW-Authenticate", challenge) catch |err| {
        response.deinit();
        return err;
    };
    const result = (try http.httpNetworkOrCacheFetchFinish(result_allocator, params, .{}, response)).response;
    defer result.deinit();
    try std.testing.expectEqual(case.network_error, result.response_type == .@"error");
    if (!case.network_error) try std.testing.expectEqual(case.status, result.status);
}

test "fa3: a worker's streamed upload rejects an actionable 401 challenge" {
    try checkCase(.{ .network_error = true });
    try checkCase(.{ .credentials = .include, .tainting = .cors, .network_error = true });
}

test "fa3: a worker's ordinary 401 response needs no replay" {
    try checkCase(.{ .source = .bytes, .network_error = false });
    try checkCase(.{ .source = .absent, .network_error = false });
    try checkCase(.{ .challenge = null, .network_error = false });
    try checkCase(.{ .challenge = "Unknown realm=\"fa3\"", .network_error = false });
    try checkCase(.{ .credentials = .omit, .network_error = false });
    try checkCase(.{ .tainting = .cors, .network_error = false });
    try checkCase(.{ .status = 200, .network_error = false });
    try checkCase(.{ .status = 421, .network_error = false });
}

test "fa3: challenge parsing and network-error allocation clean up on failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, checkCaseAlloc, .{Case{ .network_error = true }});
}
