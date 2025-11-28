//! Global fetch() Function - WHATWG Fetch Specification
//!
//! This module implements the global fetch() function that is exposed
//! on Window and Worker global scopes.
//!
//! Spec: https://fetch.spec.whatwg.org/#fetch-method
//!
//! The fetch() method starts the process of fetching a resource.

const std = @import("std");
const Allocator = std.mem.Allocator;
const request_mod = @import("request.zig");
const Request = request_mod.Request;
const RequestInit = request_mod.RequestInit;
const RequestInput = request_mod.RequestInput;
const response_mod = @import("response.zig");
const Response = response_mod.Response;
const fetch_algorithm = @import("../algorithms/fetch.zig");
const internal_request = @import("../internal/request.zig");
const InternalRequest = internal_request.InternalRequest;

/// Error types from fetch() global function.
pub const FetchError = error{
    OutOfMemory,
    NetworkError,
    AbortError,
    TypeError,
};

/// Result of a fetch operation.
/// In a real implementation, this would be a Promise<Response>.
/// For now, we return a synchronous result.
pub const FetchResult = union(enum) {
    /// Successful response
    response: *Response,
    /// Error during fetch
    err: FetchError,

    pub fn deinit(self: *FetchResult) void {
        switch (self.*) {
            .response => |r| r.deinit(),
            .err => {},
        }
    }
};

/// The global fetch() function.
///
/// Spec: fetch(input, init)
/// 1. Let p be a new promise
/// 2. Let requestObject be the result of invoking the Request constructor
/// 3. If this throws, reject p with the exception and return p
/// 4. Let request be requestObject's request
/// 5. If requestObject's signal's aborted flag is set, reject with AbortError
/// 6. Let globalObject be this's relevant global object
/// 7. If globalObject is a ServiceWorkerGlobalScope, set request's service-workers mode to "none"
/// 8. Let responseObject be null
/// 9. Let relevantRealm be this's relevant realm
/// 10. Let locallyAborted be false
/// 11. Let controller be null
/// 12-17. Set up fetch with request, processResponseEndOfBody callback, etc.
/// 18. Return p
pub fn globalFetch(
    allocator: Allocator,
    input: FetchInput,
    init: RequestInit,
) FetchResult {
    // Step 2: Create Request object
    const request_input: RequestInput = switch (input) {
        .url => |url_str| .{ .url = url_str },
        .request => |req| .{ .request = req },
    };

    const request_obj = Request.init(allocator, request_input, init) catch |err| {
        return .{ .err = switch (err) {
            error.OutOfMemory => FetchError.OutOfMemory,
            else => FetchError.TypeError,
        } };
    };
    defer request_obj.deinit();

    // Step 5: Check abort signal (simplified - we don't have real AbortSignal yet)
    if (request_obj.signal != null) {
        // TODO: Check if signal is aborted
    }

    // Step 12-17: Execute fetch
    var result = fetch_algorithm.fetch(allocator, request_obj.internal, .{}) catch |err| {
        return .{ .err = switch (err) {
            fetch_algorithm.FetchError.OutOfMemory => FetchError.OutOfMemory,
            fetch_algorithm.FetchError.NetworkError => FetchError.NetworkError,
            fetch_algorithm.FetchError.AbortError => FetchError.AbortError,
        } };
    };
    defer result.timing_info.deinit();

    // Create Response WebIDL object from internal response
    const response = Response.fromInternal(allocator, result.response) catch |err| {
        result.response.deinit();
        return .{ .err = switch (err) {
            error.OutOfMemory => FetchError.OutOfMemory,
            else => FetchError.TypeError,
        } };
    };

    // Note: We transfer ownership of internal response to the Response object,
    // so we don't deinit result.response

    return .{ .response = response };
}

/// Input type for fetch() - either URL string or Request object.
pub const FetchInput = union(enum) {
    url: []const u8,
    request: *Request,
};

/// Simplified fetch that takes just a URL string.
pub fn fetchUrl(allocator: Allocator, url: []const u8) FetchResult {
    return globalFetch(allocator, .{ .url = url }, .{});
}

/// Fetch with method override.
pub fn fetchWithMethod(allocator: Allocator, url: []const u8, method: []const u8) FetchResult {
    return globalFetch(allocator, .{ .url = url }, .{ .method = method });
}

/// Fetch with body.
pub fn fetchWithBody(allocator: Allocator, url: []const u8, method: []const u8, body: []const u8) FetchResult {
    return globalFetch(allocator, .{ .url = url }, .{
        .method = method,
        .body = body,
    });
}

// =============================================================================
// Tests
// =============================================================================

test "globalFetch - about:blank" {
    const allocator = std.testing.allocator;

    var result = globalFetch(allocator, .{ .url = "about:blank" }, .{});
    defer result.deinit();

    switch (result) {
        .response => |response| {
            try std.testing.expectEqual(@as(u16, 200), response.status());
        },
        .err => |err| {
            std.debug.print("Unexpected error: {}\n", .{err});
            try std.testing.expect(false);
        },
    }
}

test "globalFetch - data URL" {
    const allocator = std.testing.allocator;

    var result = globalFetch(allocator, .{ .url = "data:text/plain,Hello" }, .{});
    defer result.deinit();

    switch (result) {
        .response => |response| {
            try std.testing.expectEqual(@as(u16, 200), response.status());
        },
        .err => |err| {
            std.debug.print("Unexpected error: {}\n", .{err});
            try std.testing.expect(false);
        },
    }
}

test "fetchUrl convenience" {
    const allocator = std.testing.allocator;

    var result = fetchUrl(allocator, "about:blank");
    defer result.deinit();

    switch (result) {
        .response => |response| {
            try std.testing.expectEqual(@as(u16, 200), response.status());
        },
        .err => {
            try std.testing.expect(false);
        },
    }
}

test "fetchWithMethod - POST" {
    const allocator = std.testing.allocator;

    // This would normally make a POST request, but since about:blank
    // is handled locally, we just verify no errors
    var result = fetchWithMethod(allocator, "about:blank", "POST");
    defer result.deinit();

    switch (result) {
        .response => |response| {
            try std.testing.expectEqual(@as(u16, 200), response.status());
        },
        .err => {
            try std.testing.expect(false);
        },
    }
}
