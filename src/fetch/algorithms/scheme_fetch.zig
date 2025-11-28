//! Scheme Fetch - WHATWG Fetch Specification
//!
//! This module implements the scheme fetch algorithm that dispatches
//! based on URL scheme.
//!
//! Spec: https://fetch.spec.whatwg.org/#scheme-fetch
//!
//! Supported schemes:
//! - about: Returns about:blank response or network error
//! - blob: Resolves blob URL and returns blob data (stubbed)
//! - data: Processes data URLs
//! - file: Implementation-defined (returns network error)
//! - http/https: Delegates to HTTP fetch (stubbed)

const std = @import("std");
const Allocator = std.mem.Allocator;
const data_url = @import("data_url.zig");
const DataUrlResult = data_url.DataUrlResult;
const internal_response = @import("../internal/response.zig");
const InternalResponse = internal_response.InternalResponse;
const ResponseType = internal_response.ResponseType;
const Body = @import("../internal/body.zig").Body;

/// Result of scheme fetch operation.
pub const SchemeFetchResult = union(enum) {
    /// Successful response
    response: *InternalResponse,
    /// Network error with optional reason
    network_error: ?[]const u8,
};

/// Error types for scheme fetch.
pub const SchemeFetchError = error{
    OutOfMemory,
};

/// Execute scheme fetch based on URL scheme.
///
/// Algorithm per Fetch spec §4.2:
/// 1. If fetchParams is canceled, return appropriate network error
/// 2. Let request be fetchParams's request
/// 3. Switch on request's current URL's scheme:
///    - about: about:blank returns 200 with empty HTML
///    - blob: resolve blob URL
///    - data: process data URL
///    - file: implementation-defined
///    - http/https: HTTP fetch
///    - otherwise: network error
pub fn schemeFetch(
    allocator: Allocator,
    scheme: []const u8,
    url: []const u8,
) SchemeFetchError!SchemeFetchResult {
    if (std.ascii.eqlIgnoreCase(scheme, "about")) {
        return aboutFetch(allocator, url);
    } else if (std.ascii.eqlIgnoreCase(scheme, "blob")) {
        return blobFetch(allocator, url);
    } else if (std.ascii.eqlIgnoreCase(scheme, "data")) {
        return dataFetch(allocator, url);
    } else if (std.ascii.eqlIgnoreCase(scheme, "file")) {
        // Implementation-defined - return network error for now
        return .{ .network_error = "file: URLs not supported" };
    } else if (std.ascii.eqlIgnoreCase(scheme, "http") or
        std.ascii.eqlIgnoreCase(scheme, "https"))
    {
        // HTTP fetch would be handled separately by the caller
        // This function handles non-HTTP schemes only
        return .{ .network_error = "HTTP fetch should be called directly" };
    } else {
        return .{ .network_error = "Unknown scheme" };
    }
}

/// Handle about: URLs.
///
/// Per spec: Only about:blank is supported.
/// Returns a response with status 200 and content-type text/html;charset=utf-8.
fn aboutFetch(allocator: Allocator, url: []const u8) SchemeFetchError!SchemeFetchResult {
    // Parse out the path from about:blank or about:blank?... or about:blank#...
    const after_scheme = if (std.mem.startsWith(u8, url, "about:"))
        url[6..]
    else
        url;

    // Get path (before ? or #)
    var path_end = after_scheme.len;
    if (std.mem.indexOf(u8, after_scheme, "?")) |pos| {
        path_end = pos;
    }
    if (std.mem.indexOf(u8, after_scheme, "#")) |pos| {
        if (pos < path_end) path_end = pos;
    }
    const path = after_scheme[0..path_end];

    if (std.mem.eql(u8, path, "blank")) {
        // Return about:blank response
        const response = InternalResponse.init(allocator) catch {
            return SchemeFetchError.OutOfMemory;
        };
        errdefer response.deinit();

        response.status = 200;
        response.header_list.append("Content-Type", "text/html;charset=utf-8") catch {
            return SchemeFetchError.OutOfMemory;
        };
        // Body is empty for about:blank

        return .{ .response = response };
    }

    return .{ .network_error = "Only about:blank is supported" };
}

/// Handle blob: URLs.
///
/// Per spec: Resolve blob URL from blob URL store.
/// Currently stubbed - returns network error.
fn blobFetch(allocator: Allocator, url: []const u8) SchemeFetchError!SchemeFetchResult {
    _ = allocator;
    _ = url;
    // TODO: Implement blob URL resolution from blob URL store
    // Would need to:
    // 1. Parse the blob URL to extract the UUID
    // 2. Look up the UUID in the blob URL store
    // 3. Return the blob data as a response
    return .{ .network_error = "blob: URL resolution not yet implemented" };
}

/// Handle data: URLs.
///
/// Per spec: Process data URL and return response with decoded body.
fn dataFetch(allocator: Allocator, url: []const u8) SchemeFetchError!SchemeFetchResult {
    var data_result = data_url.processDataUrl(allocator, url) catch |err| {
        const msg = switch (err) {
            data_url.DataUrlError.NotDataUrl => "Not a data URL",
            data_url.DataUrlError.MissingComma => "Invalid data URL: missing comma",
            data_url.DataUrlError.Base64DecodeFailed => "Invalid data URL: base64 decode failed",
            data_url.DataUrlError.OutOfMemory => return SchemeFetchError.OutOfMemory,
        };
        return .{ .network_error = msg };
    };

    if (data_result == null) {
        return .{ .network_error = "Data URL processing returned null" };
    }

    defer data_result.?.deinit();

    // Create response
    const response = InternalResponse.init(allocator) catch {
        return SchemeFetchError.OutOfMemory;
    };
    errdefer response.deinit();

    response.status = 200;
    response.header_list.append("Content-Type", data_result.?.mime_type) catch {
        return SchemeFetchError.OutOfMemory;
    };

    // Set body using Body abstraction
    response.body = Body.fromBytes(allocator, data_result.?.body) catch {
        return SchemeFetchError.OutOfMemory;
    };

    return .{ .response = response };
}

/// Check if a scheme is supported by scheme fetch.
pub fn isSupportedScheme(scheme: []const u8) bool {
    return std.ascii.eqlIgnoreCase(scheme, "about") or
        std.ascii.eqlIgnoreCase(scheme, "blob") or
        std.ascii.eqlIgnoreCase(scheme, "data") or
        std.ascii.eqlIgnoreCase(scheme, "file") or
        std.ascii.eqlIgnoreCase(scheme, "http") or
        std.ascii.eqlIgnoreCase(scheme, "https");
}

/// Check if a scheme is a local scheme.
/// Per spec: local scheme is "about", "blob", or "data".
pub fn isLocalScheme(scheme: []const u8) bool {
    return std.ascii.eqlIgnoreCase(scheme, "about") or
        std.ascii.eqlIgnoreCase(scheme, "blob") or
        std.ascii.eqlIgnoreCase(scheme, "data");
}

/// Check if a scheme is an HTTP(S) scheme.
pub fn isHttpScheme(scheme: []const u8) bool {
    return std.ascii.eqlIgnoreCase(scheme, "http") or
        std.ascii.eqlIgnoreCase(scheme, "https");
}

/// Check if a scheme is a fetch scheme.
/// Per spec: fetch scheme is "about", "blob", "data", "file", or HTTP(S) scheme.
pub fn isFetchScheme(scheme: []const u8) bool {
    return isLocalScheme(scheme) or
        std.ascii.eqlIgnoreCase(scheme, "file") or
        isHttpScheme(scheme);
}

// =============================================================================
// Tests
// =============================================================================

test "schemeFetch - about:blank" {
    const allocator = std.testing.allocator;

    const result = try schemeFetch(allocator, "about", "about:blank");

    switch (result) {
        .response => |response| {
            defer response.deinit();
            try std.testing.expectEqual(@as(u16, 200), response.status);
        },
        .network_error => |err| {
            std.debug.print("Unexpected error: {?s}\n", .{err});
            try std.testing.expect(false);
        },
    }
}

test "schemeFetch - about:invalid" {
    const allocator = std.testing.allocator;

    const result = try schemeFetch(allocator, "about", "about:invalid");

    switch (result) {
        .response => |response| {
            defer response.deinit();
            try std.testing.expect(false); // Should be network error
        },
        .network_error => |err| {
            try std.testing.expectEqualStrings("Only about:blank is supported", err.?);
        },
    }
}

test "schemeFetch - data URL" {
    const allocator = std.testing.allocator;

    const result = try schemeFetch(allocator, "data", "data:text/plain,Hello");

    switch (result) {
        .response => |response| {
            defer response.deinit();
            try std.testing.expectEqual(@as(u16, 200), response.status);
        },
        .network_error => |err| {
            std.debug.print("Unexpected error: {?s}\n", .{err});
            try std.testing.expect(false);
        },
    }
}

test "schemeFetch - file returns error" {
    const allocator = std.testing.allocator;

    const result = try schemeFetch(allocator, "file", "file:///etc/passwd");

    switch (result) {
        .response => |response| {
            defer response.deinit();
            try std.testing.expect(false); // Should be network error
        },
        .network_error => |err| {
            try std.testing.expectEqualStrings("file: URLs not supported", err.?);
        },
    }
}

test "schemeFetch - unknown scheme" {
    const allocator = std.testing.allocator;

    const result = try schemeFetch(allocator, "ftp", "ftp://example.com");

    switch (result) {
        .response => |response| {
            defer response.deinit();
            try std.testing.expect(false); // Should be network error
        },
        .network_error => |err| {
            try std.testing.expectEqualStrings("Unknown scheme", err.?);
        },
    }
}

test "isSupportedScheme" {
    try std.testing.expect(isSupportedScheme("http"));
    try std.testing.expect(isSupportedScheme("https"));
    try std.testing.expect(isSupportedScheme("data"));
    try std.testing.expect(isSupportedScheme("blob"));
    try std.testing.expect(isSupportedScheme("about"));
    try std.testing.expect(isSupportedScheme("file"));
    try std.testing.expect(!isSupportedScheme("ftp"));
    try std.testing.expect(!isSupportedScheme("mailto"));
}

test "isLocalScheme" {
    try std.testing.expect(isLocalScheme("about"));
    try std.testing.expect(isLocalScheme("blob"));
    try std.testing.expect(isLocalScheme("data"));
    try std.testing.expect(!isLocalScheme("file"));
    try std.testing.expect(!isLocalScheme("http"));
}

test "isHttpScheme" {
    try std.testing.expect(isHttpScheme("http"));
    try std.testing.expect(isHttpScheme("https"));
    try std.testing.expect(isHttpScheme("HTTP"));
    try std.testing.expect(isHttpScheme("HTTPS"));
    try std.testing.expect(!isHttpScheme("data"));
    try std.testing.expect(!isHttpScheme("file"));
}

test "isFetchScheme" {
    try std.testing.expect(isFetchScheme("http"));
    try std.testing.expect(isFetchScheme("https"));
    try std.testing.expect(isFetchScheme("data"));
    try std.testing.expect(isFetchScheme("blob"));
    try std.testing.expect(isFetchScheme("about"));
    try std.testing.expect(isFetchScheme("file"));
    try std.testing.expect(!isFetchScheme("ftp"));
    try std.testing.expect(!isFetchScheme("ws"));
}
