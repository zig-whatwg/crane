//! HTML 9.2.2 step 15.2's retry classification survives Fetch's filtering.
const std = @import("std");
const fetch = @import("fetch");
const allocator = std.testing.allocator;

test "network errors default to unspecified, never implicitly retryable" {
    const initial = try fetch.internal.InternalResponse.init(allocator);
    defer initial.deinit();
    try std.testing.expectEqual(.unspecified, initial.network_error_cause);
    const response = try fetch.internal.response.networkError(allocator);
    defer response.deinit();
    try std.testing.expectEqual(.unspecified, response.network_error_cause);
}

test "transport failure reaches the fetch client result with its cause intact" {
    const request = try fetch.internal.InternalRequest.init(allocator, "http://example.test/events");
    request.mode = .cors;
    request.cache_mode = .no_store;
    try request.setOrigin("http://client.test");
    const job = try fetch.algorithms.FetchJob.create(allocator, request, true, .{});
    defer job.destroy();
    try std.testing.expect((try job.start()) == .network);
    try std.testing.expect((try job.resumeNetwork(error.ConnectionRefused)) == .done);
    // AsyncFetch hands this very takeResult() result to its Client.done.
    var result = job.takeResult();
    defer result.deinit();
    try std.testing.expectEqual(.@"error", result.response.response_type);
    try std.testing.expectEqual(.transport, result.response.network_error_cause);
    try std.testing.expect(!result.response.aborted);
}

test "a failed CORS preflight is not classified as a retryable event stream" {
    const request = try fetch.internal.InternalRequest.init(allocator, "http://example.test/events");
    request.mode = .cors;
    request.use_cors_preflight = true;
    try request.setOrigin("http://client.test");
    const job = try fetch.algorithms.FetchJob.create(allocator, request, true, .{});
    defer job.destroy();
    try std.testing.expect((try job.start()) == .network);
    try std.testing.expect(job.network_request_is_preflight);
    _ = try job.resumeNetwork(error.ConnectionRefused);
    var result = job.takeResult();
    defer result.deinit();
    try std.testing.expectEqual(.unspecified, result.response.network_error_cause);
}
