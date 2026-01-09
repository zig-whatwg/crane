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
const InternalResponse = internal_response.InternalResponse;
const internal_request = @import("../internal/request.zig");
const InternalRequest = internal_request.InternalRequest;
const fetch_params_mod = @import("../internal/fetch_params.zig");
const FetchParams = fetch_params_mod.FetchParams;
const fetch_controller_mod = @import("../internal/fetch_controller.zig");
const FetchController = fetch_controller_mod.FetchController;
const fetch_timing = @import("../internal/fetch_timing.zig");
const FetchTimingInfo = fetch_timing.FetchTimingInfo;
const main_fetch = @import("main_fetch.zig");
const scheme_fetch = @import("scheme_fetch.zig");
const http_fetch = @import("http_fetch.zig");
const certificate_trust = @import("../network/certificate_trust.zig");

/// Error types for fetch.
pub const FetchError = error{
    OutOfMemory,
    NetworkError,
    AbortError,
};

/// Fetch result containing the response and timing info.
pub const FetchResult = struct {
    response: *InternalResponse,
    timing_info: FetchTimingInfo,

    pub fn deinit(self: *FetchResult) void {
        self.response.deinit();
        self.timing_info.deinit();
    }
};

/// Callback type for process response.
pub const ProcessResponseCallback = *const fn (response: *InternalResponse) void;

/// Options for the fetch operation.
pub const FetchOptions = struct {
    /// Process response callback
    process_response: ?ProcessResponseCallback = null,
    /// Use CORS mode
    use_cors: bool = false,
    /// Cross-origin isolated capability
    cross_origin_isolated_capability: bool = false,
    /// Certificate trust store for HTTPS (e.g., for WPT self-signed certs)
    trust_store: ?*const certificate_trust.CertificateTrustStore = null,
};

/// Execute the top-level fetch algorithm.
///
/// Per Fetch spec §4:
/// 1. Let request be the request argument
/// 2. If request's client is non-null and is not a secure context...
/// 3. Let taskDestination be null
/// 4. Let crossOriginIsolatedCapability be false
/// 5. If useParallelQueue is true, set taskDestination to parallel queue
/// 6. Let timingInfo be a new fetch timing info
/// 7. Let fetchParams be a new fetch params
/// 8. Set fetchParams's items
/// 9. If request's body is a byte sequence, convert to Body
/// 10. If request's window is "client", set to current global object
/// 11. If request's origin is "client", set to current origin
/// 12. If all requests are local, set local-URLs-only
/// 13. If response is null, main fetch
/// 14. Return response
pub fn fetch(
    allocator: Allocator,
    request: *InternalRequest,
    options: FetchOptions,
) FetchError!FetchResult {
    // Step 6: Let timingInfo be a new fetch timing info
    var timing_info = FetchTimingInfo.init(allocator);
    errdefer timing_info.deinit();

    // Record start time
    const now = getCurrentTimeMs();
    timing_info.start_time = now;

    // Step 7-8: Create fetch controller and params
    const controller = FetchController.init(allocator) catch {
        return FetchError.OutOfMemory;
    };
    errdefer controller.deinit();

    const params = FetchParams.init(allocator, request, controller, &timing_info) catch {
        return FetchError.OutOfMemory;
    };
    errdefer params.deinit();

    // Set options
    params.cross_origin_isolated_capability = options.cross_origin_isolated_capability;
    if (options.process_response) |callback| {
        params.process_response = callback;
    }
    // Pass certificate trust store for HTTPS validation
    params.trust_store = options.trust_store;

    // Step 13: Dispatch based on URL scheme
    const url_str = request.currentUrl();
    const url_scheme = extractScheme(url_str);

    var response: *InternalResponse = undefined;

    if (scheme_fetch.isLocalScheme(url_scheme)) {
        // Handle local schemes (about, blob, data) directly
        const result = scheme_fetch.schemeFetch(allocator, url_scheme, url_str) catch {
            return FetchError.OutOfMemory;
        };

        response = switch (result) {
            .response => |r| r,
            .network_error => blk: {
                break :blk internal_response.networkError(allocator) catch {
                    return FetchError.OutOfMemory;
                };
            },
        };
    } else if (scheme_fetch.isHttpScheme(url_scheme)) {
        // HTTP(S) requests go through main fetch -> HTTP fetch
        response = main_fetch.mainFetch(allocator, params, false) catch |err| switch (err) {
            main_fetch.MainFetchError.OutOfMemory => return FetchError.OutOfMemory,
            main_fetch.MainFetchError.NetworkError => internal_response.networkError(allocator) catch {
                return FetchError.OutOfMemory;
            },
        };
    } else {
        // Unsupported scheme
        response = internal_response.networkError(allocator) catch {
            return FetchError.OutOfMemory;
        };
    }

    // Record end time
    timing_info.end_time = getCurrentTimeMs();

    // Call process response callback if set
    if (options.process_response) |callback| {
        callback(response);
    }

    // Clean up params (we keep timing_info for result)
    params.deinit();
    controller.deinit();

    return FetchResult{
        .response = response,
        .timing_info = timing_info,
    };
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

/// Extract scheme from URL string.
fn extractScheme(url_str: []const u8) []const u8 {
    const colon_pos = std.mem.indexOf(u8, url_str, ":");
    if (colon_pos) |pos| {
        return url_str[0..pos];
    }
    return "";
}

/// Get current time in milliseconds.
fn getCurrentTimeMs() f64 {
    return @as(f64, @floatFromInt(std.time.timestamp())) * 1000.0;
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
    try std.testing.expectEqualStrings("https", extractScheme("https://example.com"));
    try std.testing.expectEqualStrings("http", extractScheme("http://example.com"));
    try std.testing.expectEqualStrings("data", extractScheme("data:text/plain,Hello"));
    try std.testing.expectEqualStrings("about", extractScheme("about:blank"));
    try std.testing.expectEqualStrings("", extractScheme("no-colon"));
}
