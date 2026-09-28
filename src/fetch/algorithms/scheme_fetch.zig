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
const InternalRequest = @import("../internal/request.zig").InternalRequest;
const parsing = @import("../internal/parsing.zig");

const log = std.log.scoped(.scheme_fetch);

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

        // "a new response whose status message is `OK`, header list is
        // « (`Content-Type`, `text/html;charset=utf-8`) »".
        response.status = 200;
        response.setStatusMessage("OK") catch return SchemeFetchError.OutOfMemory;
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
    // Scheme fetch "blob" needs the request (its method, `Range` header and
    // origin): `schemeFetchRequest` is the one that does it.
    return .{ .network_error = "blob: needs the request - schemeFetchRequest" };
}

/// `n` serialized as a decimal, in `buf` - 20 bytes hold any u64.
fn decimal(buf: *[20]u8, n: u64) []const u8 {
    return std.fmt.bufPrint(buf, "{d}", .{n}) catch unreachable;
}

/// A blob URL's blob, as scheme fetch "blob" reads it: its bytes and its
/// type. Owned.
pub const ResolvedBlob = struct {
    bytes: []u8,
    content_type: []u8,

    pub fn deinit(self: ResolvedBlob, allocator: Allocator) void {
        allocator.free(self.bytes);
        allocator.free(self.content_type);
    }
};

/// Resolves a blob URL, for a request whose origin is `origin`, to its
/// blob - null when "obtaining a blob object" fails: no entry, a revoked
/// one, or another origin's. The File API's blob URL store is the file
/// module's, which fetch does not import, so the code that owns the store
/// installs this (src/webidl/impls/fetch_body.zig).
pub const BlobResolver = *const fn (allocator: Allocator, url: []const u8, origin: []const u8) error{OutOfMemory}!?ResolvedBlob;

/// The one blob URL store is process-wide (file.getGlobalBlobURLStore), so
/// its resolver is too.
var blob_resolver: ?BlobResolver = null;

/// Install the resolver scheme fetch "blob" asks. Idempotent.
pub fn installBlobResolver(resolver: BlobResolver) void {
    blob_resolver = resolver;
}

/// Scheme fetch for `request`: "blob" with the request it needs, and every
/// other scheme through `schemeFetch`.
pub fn schemeFetchRequest(allocator: Allocator, request: *const InternalRequest) SchemeFetchError!SchemeFetchResult {
    const url = request.currentUrl();
    const scheme = url[0 .. std.mem.indexOfScalar(u8, url, ':') orelse 0];
    if (std.ascii.eqlIgnoreCase(scheme, "blob")) {
        return blobFetchRequest(allocator, request) catch |err| switch (err) {
            error.OutOfMemory => SchemeFetchError.OutOfMemory,
        };
    }
    return schemeFetch(allocator, scheme, url);
}

/// Scheme fetch, "blob".
///
/// Spec: https://fetch.spec.whatwg.org/#scheme-fetch
fn blobFetchRequest(allocator: Allocator, request: *const InternalRequest) error{OutOfMemory}!SchemeFetchResult {
    // 2. If request's method is not `GET` or blobURLEntry is null, then
    //    return a network error.
    if (!std.mem.eql(u8, request.method, "GET")) return .{ .network_error = "blob: fetch is GET only" };
    const resolver = blob_resolver orelse return .{ .network_error = "no blob URL store" };
    // 1, 3-8. The blob URL entry, and the blob obtained from it for the
    //         request's environment - its origin.
    const origin: []const u8 = switch (request.origin) {
        .client => "",
        .origin => |o| o,
    };
    const blob = (try resolver(allocator, request.currentUrl(), origin)) orelse return .{ .network_error = "no blob for this URL" };
    defer blob.deinit(allocator);

    // 9. Let response be a new response.
    const response = try InternalResponse.init(allocator);
    errdefer response.deinit();
    // 10-12. fullLength, serializedFullLength and type.
    const full_length: u64 = blob.bytes.len;

    // 13. If request's header list does not contain `Range`:
    const range_header = (try request.header_list.get(allocator, "Range")) orelse {
        // 1-3. Its status message is `OK` and its body the blob's bytes.
        response.status = 200;
        try response.setStatusMessage("OK");
        response.body = try Body.fromBytes(allocator, blob.bytes);
        // 4. Header list « (`Content-Length`, serializedFullLength),
        //    (`Content-Type`, type) ».
        var length_buf: [20]u8 = undefined;
        try response.header_list.append("Content-Length", decimal(&length_buf, full_length));
        try response.header_list.append("Content-Type", blob.content_type);
        return .{ .response = response };
    };
    defer allocator.free(range_header);

    // 14. Otherwise:
    // 1. Set response's range-requested flag.
    response.range_requested = true;
    // 2-4. Parse the single range header value, allowing whitespace;
    //      failure is a network error.
    const range = parsing.parseSingleRangeHeaderValue(range_header, true) orelse {
        response.deinit();
        return .{ .network_error = "bad Range" };
    };
    // 5-7. rangeStart and rangeEnd, inclusive.
    const full: i64 = @intCast(full_length);
    var range_start: i64 = undefined;
    var range_end: i64 = undefined;
    if (range.start) |start| {
        // 7.1. If rangeStart >= fullLength, then return a network error.
        if (start >= full_length) {
            response.deinit();
            return .{ .network_error = "Range starts past the blob" };
        }
        range_start = @intCast(start);
        // 7.2. If rangeEnd is null or >= fullLength, it is fullLength - 1.
        range_end = if (range.end) |end| (if (end >= full_length) full - 1 else @as(i64, @intCast(end))) else full - 1;
    } else {
        // 6. A suffix: the last rangeEnd bytes.
        const suffix: i64 = @intCast(range.end.?);
        range_start = full - suffix;
        range_end = range_start + suffix - 1;
    }
    // 8. slicedBlob: "slice blob" given blob, rangeStart, rangeEnd + 1 -
    //    whose relative start and end clamp to [0, size].
    const slice_start: usize = @intCast(std.math.clamp(range_start, 0, full));
    const slice_end: usize = @intCast(std.math.clamp(range_end + 1, 0, full));
    const sliced = blob.bytes[slice_start..@max(slice_start, slice_end)];
    // 9-10. Its body is slicedBlob's bytes.
    response.body = try Body.fromBytes(allocator, sliced);
    // 12. contentRange: "build a content range". A suffix longer than the
    //     blob would make rangeStart negative; the bytes sent start at 0,
    //     and so does the range this reports.
    const content_range = try parsing.buildContentRange(allocator, @intCast(@max(range_start, 0)), @intCast(@max(range_end, 0)), full_length);
    defer allocator.free(content_range);
    // 13-14. 206, `Partial Content`.
    response.status = 206;
    try response.setStatusMessage("Partial Content");
    // 15. « (`Content-Length`, serializedSlicedLength), (`Content-Type`,
    //     type), (`Content-Range`, contentRange) ».
    var length_buf: [20]u8 = undefined;
    try response.header_list.append("Content-Length", decimal(&length_buf, sliced.len));
    try response.header_list.append("Content-Type", blob.content_type);
    try response.header_list.append("Content-Range", content_range);
    return .{ .response = response };
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

    // "Return a new response whose status message is `OK`, header list is
    // « (`Content-Type`, mimeType) », and body is dataURLStruct's body."
    response.status = 200;
    response.setStatusMessage("OK") catch return SchemeFetchError.OutOfMemory;
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
            log.err("Unexpected error: {?s}", .{err});
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
            log.err("Unexpected error: {?s}", .{err});
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

test "scheme fetch: a data: URL's response says OK" {
    const allocator = std.testing.allocator;
    const result = try schemeFetch(allocator, "data", "data:,hi");
    const response = result.response;
    defer response.deinit();
    try std.testing.expectEqual(@as(u16, 200), response.status);
    try std.testing.expectEqualStrings("OK", response.status_message);
}

fn testResolver(allocator: Allocator, url: []const u8, origin: []const u8) error{OutOfMemory}!?ResolvedBlob {
    if (!std.mem.eql(u8, url, "blob:http://a.test/1") or !std.mem.eql(u8, origin, "http://a.test")) return null;
    return .{ .bytes = try allocator.dupe(u8, "0123456789"), .content_type = try allocator.dupe(u8, "text/plain") };
}

test "scheme fetch blob: the whole blob, or a range of it" {
    const allocator = std.testing.allocator;
    installBlobResolver(&testResolver);
    defer blob_resolver = null;

    const request = try InternalRequest.init(allocator, "blob:http://a.test/1");
    defer request.deinit();
    try request.setOrigin("http://a.test");

    {
        const response = (try schemeFetchRequest(allocator, request)).response;
        defer response.deinit();
        try std.testing.expectEqual(@as(u16, 200), response.status);
        try std.testing.expectEqualStrings("OK", response.status_message);
        try std.testing.expectEqualStrings("0123456789", response.body.?.getBytes());
        const length = (try response.header_list.get(allocator, "Content-Length")).?;
        defer allocator.free(length);
        try std.testing.expectEqualStrings("10", length);
    }

    const Case = struct { range: []const u8, body: []const u8, content_range: []const u8 };
    const cases = [_]Case{
        .{ .range = "bytes=2-4", .body = "234", .content_range = "bytes 2-4/10" },
        .{ .range = "bytes = 7 - ", .body = "789", .content_range = "bytes 7-9/10" },
        .{ .range = "bytes=-3", .body = "789", .content_range = "bytes 7-9/10" },
        .{ .range = "bytes=5-100", .body = "56789", .content_range = "bytes 5-9/10" },
    };
    for (cases) |case| {
        try request.header_list.set("Range", case.range);
        const response = (try schemeFetchRequest(allocator, request)).response;
        defer response.deinit();
        try std.testing.expectEqual(@as(u16, 206), response.status);
        try std.testing.expectEqualStrings("Partial Content", response.status_message);
        try std.testing.expectEqualStrings(case.body, response.body.?.getBytes());
        const content_range = (try response.header_list.get(allocator, "Content-Range")).?;
        defer allocator.free(content_range);
        try std.testing.expectEqualStrings(case.content_range, content_range);
    }

    // Past the end, a bad Range, another origin or another method: network errors.
    try request.header_list.set("Range", "bytes=10-");
    try std.testing.expect((try schemeFetchRequest(allocator, request)) == .network_error);
    try request.header_list.set("Range", "bits=1-2");
    try std.testing.expect((try schemeFetchRequest(allocator, request)) == .network_error);
    request.header_list.delete("Range");
    try request.setOrigin("http://b.test");
    try std.testing.expect((try schemeFetchRequest(allocator, request)) == .network_error);
    try request.setOrigin("http://a.test");
    try request.setMethod("POST");
    try std.testing.expect((try schemeFetchRequest(allocator, request)) == .network_error);
}
