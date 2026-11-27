//! Lane net-nav1 (Item 2): Fetch HTTP-network-or-cache fetch step 15.3 / 16
//! prompt behavior with `traversable_for_user_prompts` and `use_url_credentials`.

const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");
const http_fetch = fetch.algorithms.http_fetch;
const InternalRequest = fetch.internal.InternalRequest;
const InternalResponse = fetch.internal.InternalResponse;
const FetchParams = fetch.internal.FetchParams;
const FetchController = fetch.internal.FetchController;
const FetchTimingInfo = fetch.internal.FetchTimingInfo;
const NetworkResponse = fetch.network.NetworkResponse;

test "Item 2: step 15.3 prompts when use_url_credentials is set but URL has no credentials" {
    const allocator = testing.allocator;
    var token: u8 = 0;

    const request = try InternalRequest.init(allocator, "http://example.test/protected");
    defer request.deinit();
    request.use_url_credentials = true;
    request.credentials_mode = .include;
    request.traversable_for_user_prompts = .{ .traversable = &token };

    const controller = try FetchController.init(allocator);
    defer controller.deinit();
    var timing = FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    const raw_headers = [_]NetworkResponse.Header{
        .{ .name = "WWW-Authenticate", .value = "Basic realm=\"area\"" },
    };
    const pre = try http_fetch.wouldPrompt(allocator, params, .{}, 401, &raw_headers);
    try testing.expect(pre != null);
    defer allocator.free(pre.?.realm);
    try testing.expectEqualStrings("area", pre.?.realm);

    const unauthorized = try InternalResponse.init(allocator);
    unauthorized.status = 401;
    try unauthorized.header_list.append("WWW-Authenticate", "Basic realm=\"area\"");

    const finished = try http_fetch.httpNetworkOrCacheFetchFinish(allocator, params, .{}, unauthorized);
    switch (finished) {
        .prompt => |p| {
            defer p.deinit(allocator);
            try testing.expectEqualStrings("area", p.realm);
        },
        .response => |r| {
            r.deinit();
            return error.ExpectedPrompt;
        },
        .authentication_retry => |realm| {
            allocator.free(realm);
            return error.ExpectedPrompt;
        },
        .new_connection_retry => return error.ExpectedPrompt,
    }
}

test "Item 2: step 15.3 retries with URL credentials when URL has embedded credentials, does not prompt first" {
    const allocator = testing.allocator;
    var token: u8 = 0;

    const request = try InternalRequest.init(allocator, "http://alice:secret@example.test/protected");
    defer request.deinit();
    request.use_url_credentials = true;
    request.credentials_mode = .include;
    request.traversable_for_user_prompts = .{ .traversable = &token };

    const controller = try FetchController.init(allocator);
    defer controller.deinit();
    var timing = FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    const raw_headers = [_]NetworkResponse.Header{
        .{ .name = "WWW-Authenticate", .value = "Basic realm=\"area\"" },
    };
    const pre = try http_fetch.wouldPrompt(allocator, params, .{}, 401, &raw_headers);
    try testing.expect(pre == null);

    const unauthorized = try InternalResponse.init(allocator);
    unauthorized.status = 401;
    try unauthorized.header_list.append("WWW-Authenticate", "Basic realm=\"area\"");

    const finished = try http_fetch.httpNetworkOrCacheFetchFinish(allocator, params, .{}, unauthorized);
    switch (finished) {
        .authentication_retry => |realm| {
            defer allocator.free(realm);
            try testing.expectEqualStrings("area", realm);
        },
        .prompt => |p| {
            p.deinit(allocator);
            return error.ExpectedAuthRetry;
        },
        .response => |r| {
            r.deinit();
            return error.ExpectedAuthRetry;
        },
        .new_connection_retry => return error.ExpectedAuthRetry,
    }
}

test "Item 2: step 16 407 prompts when traversable is set, returns network error when no_traversable" {
    const allocator = testing.allocator;
    var token: u8 = 0;

    const request = try InternalRequest.init(allocator, "http://example.test/page");
    defer request.deinit();
    request.traversable_for_user_prompts = .{ .traversable = &token };

    const controller = try FetchController.init(allocator);
    defer controller.deinit();
    var timing = FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    const resp407 = try InternalResponse.init(allocator);
    resp407.status = 407;
    try resp407.header_list.append("Proxy-Authenticate", "Basic realm=\"proxy\"");

    const finished = try http_fetch.httpNetworkOrCacheFetchFinish(allocator, params, .{}, resp407);
    switch (finished) {
        .prompt => |p| {
            defer p.deinit(allocator);
            try testing.expectEqualStrings("proxy", p.realm);
        },
        else => return error.ExpectedPrompt,
    }

    // With no_traversable, 407 is a network error.
    request.traversable_for_user_prompts = .no_traversable;
    const resp407_b = try InternalResponse.init(allocator);
    resp407_b.status = 407;
    try resp407_b.header_list.append("Proxy-Authenticate", "Basic realm=\"proxy\"");
    const finished_b = try http_fetch.httpNetworkOrCacheFetchFinish(allocator, params, .{}, resp407_b);
    switch (finished_b) {
        .response => |r| {
            defer r.deinit();
            try testing.expectEqual(fetch.internal.ResponseType.@"error", r.response_type);
        },
        else => return error.ExpectedNetworkError,
    }
}
