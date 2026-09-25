//! Fetch Algorithm - WHATWG Fetch Specification
//!
//! This module implements the top-level fetch algorithm that ties
//! everything together.
//!
//! Spec: https://fetch.spec.whatwg.org/#fetching
//!
//! The fetch algorithm:
//! 1. Create fetch params with request and timing info
//! 2. If request's URL is a local scheme, handle locally
//! 3. Otherwise dispatch to main fetch
//! 4. Handle response callbacks

const std = @import("std");
const Allocator = std.mem.Allocator;
const internal_response = @import("../internal/response.zig");
const internal_request = @import("../internal/request.zig");
const InternalRequest = internal_request.InternalRequest;
const InternalResponse = internal_response.InternalResponse;
const network = @import("../network/root.zig");
const NetworkResponse = network.NetworkResponse;
const NetworkError = network.NetworkError;
const LibcurlBackend = network.LibcurlBackend;
const fetch_job = @import("fetch_job.zig");
const FetchJob = fetch_job.FetchJob;

pub const FetchError = fetch_job.FetchError;
pub const FetchResult = fetch_job.FetchResult;
pub const ProcessResponseCallback = fetch_job.ProcessResponseCallback;
pub const FetchOptions = fetch_job.FetchOptions;

/// Execute the top-level fetch algorithm, waiting for the network.
///
/// Every request HTTP-network fetch sends is performed there and then, so
/// this returns with the response - and nothing else on the thread runs until
/// it does. That is what navigation and synchronous XHR need; `fetch()`, the
/// method, runs the same algorithm on the event loop instead (see
/// `async_fetch.zig`). `request` is borrowed.
pub fn fetch(
    allocator: Allocator,
    request: *InternalRequest,
    options: FetchOptions,
) FetchError!FetchResult {
    const job = try FetchJob.create(allocator, request, false, options);
    defer job.destroy();

    var step = try job.start();
    while (true) switch (step) {
        .done => return job.takeResult(),
        .network => |needed| step = try job.resumeNetwork(sendBlocking(allocator, needed)),
    };
}

/// Perform HTTP-network fetch's request now, blocking until it is answered.
fn sendBlocking(allocator: Allocator, needed: FetchJob.NetworkStep) NetworkError!NetworkResponse {
    const backend_impl = LibcurlBackend.initWithOptions(allocator, .{ .enable_cookies = needed.cookies }) catch {
        // A backend that cannot be made is a network error, not a lack of
        // memory the caller could act on.
        return NetworkError.Unknown;
    };
    defer backend_impl.deinit();
    return backend_impl.getBackend().send(allocator, needed.request);
}

/// Simplified fetch that just returns the response.
pub fn fetchSimple(
    allocator: Allocator,
    url: []const u8,
) FetchError!*InternalResponse {
    // Create a simple GET request
    const request = InternalRequest.init(allocator, url) catch {
        return FetchError.OutOfMemory;
    };
    defer request.deinit();

    var result = try fetch(allocator, request, .{});
    // Caller takes ownership of response
    const response = result.response;
    result.timing_info.deinit();
    return response;
}

/// Fetch with abort support.
pub fn fetchWithAbort(
    allocator: Allocator,
    request: *InternalRequest,
    abort_signal: ?*anyopaque,
    options: FetchOptions,
) FetchError!FetchResult {
    _ = abort_signal; // TODO: Implement abort signal integration
    return fetch(allocator, request, options);
}

// =============================================================================
// Tests
// =============================================================================

test "fetch - about:blank" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "about:blank");
    defer request.deinit();

    var result = try fetch(allocator, request, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(u16, 200), result.response.status);
    try std.testing.expect(result.timing_info.start_time > 0);
    try std.testing.expect(result.timing_info.end_time >= result.timing_info.start_time);
}

test "fetch - data URL" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "data:text/plain,Hello");
    defer request.deinit();

    var result = try fetch(allocator, request, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(u16, 200), result.response.status);
}

test "fetch - unsupported scheme" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "ftp://example.com");
    defer request.deinit();

    var result = try fetch(allocator, request, .{});
    defer result.deinit();

    // Should return network error
    try std.testing.expectEqual(internal_response.ResponseType.@"error", result.response.response_type);
}

test "fetchSimple - about:blank" {
    const allocator = std.testing.allocator;

    const response = try fetchSimple(allocator, "about:blank");
    defer response.deinit();

    try std.testing.expectEqual(@as(u16, 200), response.status);
}

test "extractScheme" {
    const extractScheme = fetch_job.extractScheme;
    try std.testing.expectEqualStrings("https", extractScheme("https://example.com"));
    try std.testing.expectEqualStrings("http", extractScheme("http://example.com"));
    try std.testing.expectEqualStrings("data", extractScheme("data:text/plain,Hello"));
    try std.testing.expectEqualStrings("about", extractScheme("about:blank"));
    try std.testing.expectEqualStrings("", extractScheme("no-colon"));
}
