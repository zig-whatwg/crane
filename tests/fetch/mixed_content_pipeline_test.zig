//! Fetch main fetch steps 5–7 and 20, including the recursive redirect call.
const std = @import("std");
const fetch = @import("fetch");
const main = fetch.algorithms.main_fetch;
const Request = fetch.internal.InternalRequest;

fn startsBlocked(request: *Request, recursive: bool) !bool {
    const allocator = std.testing.allocator;
    const controller = try fetch.internal.FetchController.init(allocator);
    defer controller.deinit();
    var timing = fetch.internal.FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try fetch.internal.FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();
    return switch (try main.mainFetchStart(allocator, params, recursive)) {
        .response => |response| blk: {
            defer response.deinit();
            break :blk response.response_type == .@"error";
        },
        else => false,
    };
}

test "main fetch blocks before network dispatch and rechecks a redirect's URL" {
    const request = try Request.init(std.testing.allocator, "https://example.test/start");
    defer request.deinit();
    request.mode = .no_cors;
    try fetch.internal.populateRequestFromClient(request, .{ .prohibits_mixed_security_contexts = true });
    try std.testing.expect(!try startsBlocked(request, false));
    try request.url_list.append(request.allocator, try request.allocator.dupe(u8, "http://example.test/redirected"));
    try std.testing.expect(try startsBlocked(request, true));
}

test "main fetch upgrades mixed images before applying request blocking" {
    const request = try Request.init(std.testing.allocator, "http://example.test:8443/image.png");
    defer request.deinit();
    request.mode = .no_cors;
    request.destination = .image;
    request.prohibits_mixed_security_contexts = true;
    try std.testing.expect(!try startsBlocked(request, false));
    try std.testing.expectEqualStrings("https://example.test:8443/image.png", request.currentUrl());
}

test "main fetch applies CSP upgrade-insecure-requests before mixed content blocking" {
    const allocator = std.testing.allocator;
    const request = try Request.init(allocator, "http://example.test:8443/script.js");
    defer request.deinit();
    request.destination = .script;
    request.mode = .cors;
    request.prohibits_mixed_security_contexts = true;
    request.setPolicyContainer(try fetch.internal.PolicyContainer.fromResponseHeaders(allocator, .{
        .url = "https://example.test/",
        .csp = "upgrade-insecure-requests",
    }));
    try std.testing.expect(!try startsBlocked(request, false));
    try std.testing.expectEqualStrings("https://example.test:8443/script.js", request.currentUrl());
}

test "main fetch response check uses the internal response URL before opaque filtering" {
    const allocator = std.testing.allocator;
    const request = try Request.init(allocator, "https://example.test/request");
    defer request.deinit();
    request.prohibits_mixed_security_contexts = true;
    request.response_tainting = .@"opaque";
    const controller = try fetch.internal.FetchController.init(allocator);
    defer controller.deinit();
    var timing = fetch.internal.FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try fetch.internal.FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();
    const response = try fetch.internal.InternalResponse.init(allocator);
    try response.url_list.append(allocator, try allocator.dupe(u8, "http://example.test/response"));
    response.status = 200;
    try response.setStatusMessage("OK");
    try response.header_list.append("Content-Type", "text/plain");
    response.body = try fetch.internal.Body.fromBytes(allocator, "secret response");
    const result = main.mainFetchFinish(params, false, response);
    defer result.deinit();
    try std.testing.expectEqual(fetch.internal.ResponseType.@"error", result.response_type);
    try std.testing.expectEqual(@as(u16, 0), result.status);
    try std.testing.expectEqual(@as(usize, 0), result.url_list.items.len);
    try std.testing.expectEqualStrings("", result.status_message);
    try std.testing.expectEqual(@as(usize, 0), result.header_list.entries.items.len);
    try std.testing.expect(result.body == null);
}

test "main fetch response check fails closed when authentication allocation fails" {
    const allocator = std.testing.allocator;
    const request = try Request.init(allocator, "https://example.test/request");
    defer request.deinit();
    request.prohibits_mixed_security_contexts = true;
    const controller = try fetch.internal.FetchController.init(allocator);
    defer controller.deinit();
    var timing = fetch.internal.FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try fetch.internal.FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();
    const response = try fetch.internal.InternalResponse.init(allocator);
    // Empty response URL list uses Fetch's step 16 fallback to the request.
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    request.allocator = failing.allocator();
    defer request.allocator = allocator;
    const result = main.mainFetchFinish(params, false, response);
    defer result.deinit();
    try std.testing.expectEqual(fetch.internal.ResponseType.@"error", result.response_type);
    try std.testing.expectEqual(@as(u16, 0), result.status);
}
