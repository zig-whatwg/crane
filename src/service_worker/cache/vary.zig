//! Vary Header Matching
//!
//! Implements Vary header matching per HTTP and Cache API spec.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#request-matches-cached-item-algorithm

const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const StoredRequest = types.StoredRequest;
const StoredResponse = types.StoredResponse;
const HeaderEntry = types.HeaderEntry;
const CacheQueryOptions = types.CacheQueryOptions;

/// Parse the Vary header value into a list of header names.
///
/// The Vary header can contain:
/// - "*" - matches nothing (every request is unique)
/// - Comma-separated list of header names
pub fn parseVaryHeader(allocator: Allocator, vary_value: []const u8) ![][]const u8 {
    var result = std.ArrayList([]const u8).init(allocator);
    errdefer {
        for (result.items) |item| {
            allocator.free(item);
        }
        result.deinit();
    }

    // Split by comma
    var iter = std.mem.splitSequence(u8, vary_value, ",");
    while (iter.next()) |part| {
        // Trim whitespace
        const trimmed = std.mem.trim(u8, part, " \t");
        if (trimmed.len > 0) {
            const name = try allocator.dupe(u8, trimmed);
            try result.append(name);
        }
    }

    return result.toOwnedSlice();
}

/// Free a parsed Vary header list.
pub fn freeVaryList(allocator: Allocator, list: [][]const u8) void {
    for (list) |item| {
        allocator.free(item);
    }
    allocator.free(list);
}

/// Check if the Vary header value is "*".
pub fn isVaryStar(vary_value: []const u8) bool {
    const trimmed = std.mem.trim(u8, vary_value, " \t");
    return std.mem.eql(u8, trimmed, "*");
}

/// Check if a request matches a cached item considering the Vary header.
///
/// Per spec:
/// 1. If ignoreVary is true, return true
/// 2. Get Vary header from cached response
/// 3. If Vary is "*", return false
/// 4. For each header name in Vary:
///    - If the header values don't match between new request and cached request, return false
/// 5. Return true
pub fn varyMatches(
    new_request: *const StoredRequest,
    cached_request: *const StoredRequest,
    cached_response: *const StoredResponse,
    options: CacheQueryOptions,
) bool {
    // Step 1: If ignoreVary is true, always match
    if (options.ignore_vary) {
        return true;
    }

    // Step 2: Get Vary header from cached response
    const vary_value = cached_response.getHeader("Vary") orelse {
        // No Vary header - match
        return true;
    };

    // Step 3: If Vary is "*", never match
    if (isVaryStar(vary_value)) {
        return false;
    }

    // Step 4: Compare each header listed in Vary
    // We need to parse the Vary header - for simplicity, we'll do inline parsing
    var iter = std.mem.splitSequence(u8, vary_value, ",");
    while (iter.next()) |part| {
        const header_name = std.mem.trim(u8, part, " \t");
        if (header_name.len == 0) continue;

        const new_value = new_request.getHeader(header_name);
        const cached_value = cached_request.getHeader(header_name);

        // Both must be the same (both null, or both equal strings)
        if (new_value == null and cached_value == null) {
            continue;
        }
        if (new_value == null or cached_value == null) {
            return false;
        }
        if (!std.mem.eql(u8, new_value.?, cached_value.?)) {
            return false;
        }
    }

    // Step 5: All Vary headers match
    return true;
}

/// Check if a URL matches another URL with query options.
pub fn urlMatches(url1: []const u8, url2: []const u8, options: CacheQueryOptions) bool {
    if (options.ignore_search) {
        // Compare only the part before '?'
        const base1 = getUrlBase(url1);
        const base2 = getUrlBase(url2);
        return std.mem.eql(u8, base1, base2);
    }
    return std.mem.eql(u8, url1, url2);
}

/// Get the base URL (without query string).
fn getUrlBase(url: []const u8) []const u8 {
    if (std.mem.indexOf(u8, url, "?")) |idx| {
        return url[0..idx];
    }
    return url;
}

/// Check if a method matches with query options.
pub fn methodMatches(method1: []const u8, method2: []const u8, options: CacheQueryOptions) bool {
    if (options.ignore_method) {
        return true;
    }
    return std.ascii.eqlIgnoreCase(method1, method2);
}

/// Full request match check.
pub fn requestMatches(
    new_request: *const StoredRequest,
    cached_request: *const StoredRequest,
    cached_response: *const StoredResponse,
    options: CacheQueryOptions,
) bool {
    // Check URL
    if (!urlMatches(new_request.url, cached_request.url, options)) {
        return false;
    }

    // Check method
    if (!methodMatches(new_request.method, cached_request.method, options)) {
        return false;
    }

    // Check Vary header
    if (!varyMatches(new_request, cached_request, cached_response, options)) {
        return false;
    }

    return true;
}

// =============================================================================
// Tests
// =============================================================================

test "parseVaryHeader single value" {
    const allocator = std.testing.allocator;

    const list = try parseVaryHeader(allocator, "Accept-Encoding");
    defer freeVaryList(allocator, list);

    try std.testing.expectEqual(@as(usize, 1), list.len);
    try std.testing.expectEqualStrings("Accept-Encoding", list[0]);
}

test "parseVaryHeader multiple values" {
    const allocator = std.testing.allocator;

    const list = try parseVaryHeader(allocator, "Accept-Encoding, Accept-Language, Cookie");
    defer freeVaryList(allocator, list);

    try std.testing.expectEqual(@as(usize, 3), list.len);
    try std.testing.expectEqualStrings("Accept-Encoding", list[0]);
    try std.testing.expectEqualStrings("Accept-Language", list[1]);
    try std.testing.expectEqualStrings("Cookie", list[2]);
}

test "parseVaryHeader with whitespace" {
    const allocator = std.testing.allocator;

    const list = try parseVaryHeader(allocator, "  Accept , Content-Type  ");
    defer freeVaryList(allocator, list);

    try std.testing.expectEqual(@as(usize, 2), list.len);
    try std.testing.expectEqualStrings("Accept", list[0]);
    try std.testing.expectEqualStrings("Content-Type", list[1]);
}

test "isVaryStar" {
    try std.testing.expect(isVaryStar("*"));
    try std.testing.expect(isVaryStar(" * "));
    try std.testing.expect(!isVaryStar("Accept"));
    try std.testing.expect(!isVaryStar("*, Accept"));
}

test "urlMatches exact" {
    const opts = CacheQueryOptions{};
    try std.testing.expect(urlMatches("https://example.com/path", "https://example.com/path", opts));
    try std.testing.expect(!urlMatches("https://example.com/path", "https://example.com/other", opts));
}

test "urlMatches ignore search" {
    const opts = CacheQueryOptions{ .ignore_search = true };
    try std.testing.expect(urlMatches("https://example.com/path?a=1", "https://example.com/path?b=2", opts));
    try std.testing.expect(urlMatches("https://example.com/path?a=1", "https://example.com/path", opts));
    try std.testing.expect(!urlMatches("https://example.com/path1?a=1", "https://example.com/path2?a=1", opts));
}

test "methodMatches" {
    const opts_strict = CacheQueryOptions{};
    try std.testing.expect(methodMatches("GET", "GET", opts_strict));
    try std.testing.expect(methodMatches("get", "GET", opts_strict)); // Case insensitive
    try std.testing.expect(!methodMatches("GET", "POST", opts_strict));

    const opts_ignore = CacheQueryOptions{ .ignore_method = true };
    try std.testing.expect(methodMatches("GET", "POST", opts_ignore));
}

test "varyMatches no Vary header" {
    const allocator = std.testing.allocator;

    const req1 = try StoredRequest.init(allocator, "https://example.com", "GET", &[_]types.HeaderEntry{});
    defer req1.deinit();

    const req2 = try StoredRequest.init(allocator, "https://example.com", "GET", &[_]types.HeaderEntry{});
    defer req2.deinit();

    const resp = try types.StoredResponse.init(allocator, 200, "OK", &[_]types.HeaderEntry{}, null, .basic);
    defer resp.deinit();

    try std.testing.expect(varyMatches(req1, req2, resp, .{}));
}

test "varyMatches with Vary star" {
    const allocator = std.testing.allocator;

    const req1 = try StoredRequest.init(allocator, "https://example.com", "GET", &[_]types.HeaderEntry{});
    defer req1.deinit();

    const req2 = try StoredRequest.init(allocator, "https://example.com", "GET", &[_]types.HeaderEntry{});
    defer req2.deinit();

    const headers = [_]types.HeaderEntry{.{ .name = "Vary", .value = "*" }};
    const resp = try types.StoredResponse.init(allocator, 200, "OK", &headers, null, .basic);
    defer resp.deinit();

    try std.testing.expect(!varyMatches(req1, req2, resp, .{}));
}

test "varyMatches headers match" {
    const allocator = std.testing.allocator;

    const req1_headers = [_]types.HeaderEntry{.{ .name = "Accept-Encoding", .value = "gzip" }};
    const req1 = try StoredRequest.init(allocator, "https://example.com", "GET", &req1_headers);
    defer req1.deinit();

    const req2_headers = [_]types.HeaderEntry{.{ .name = "Accept-Encoding", .value = "gzip" }};
    const req2 = try StoredRequest.init(allocator, "https://example.com", "GET", &req2_headers);
    defer req2.deinit();

    const resp_headers = [_]types.HeaderEntry{.{ .name = "Vary", .value = "Accept-Encoding" }};
    const resp = try types.StoredResponse.init(allocator, 200, "OK", &resp_headers, null, .basic);
    defer resp.deinit();

    try std.testing.expect(varyMatches(req1, req2, resp, .{}));
}

test "varyMatches headers differ" {
    const allocator = std.testing.allocator;

    const req1_headers = [_]types.HeaderEntry{.{ .name = "Accept-Encoding", .value = "gzip" }};
    const req1 = try StoredRequest.init(allocator, "https://example.com", "GET", &req1_headers);
    defer req1.deinit();

    const req2_headers = [_]types.HeaderEntry{.{ .name = "Accept-Encoding", .value = "br" }};
    const req2 = try StoredRequest.init(allocator, "https://example.com", "GET", &req2_headers);
    defer req2.deinit();

    const resp_headers = [_]types.HeaderEntry{.{ .name = "Vary", .value = "Accept-Encoding" }};
    const resp = try types.StoredResponse.init(allocator, 200, "OK", &resp_headers, null, .basic);
    defer resp.deinit();

    try std.testing.expect(!varyMatches(req1, req2, resp, .{}));
}

test "varyMatches ignoreVary" {
    const allocator = std.testing.allocator;

    const req1 = try StoredRequest.init(allocator, "https://example.com", "GET", &[_]types.HeaderEntry{});
    defer req1.deinit();

    const req2 = try StoredRequest.init(allocator, "https://example.com", "GET", &[_]types.HeaderEntry{});
    defer req2.deinit();

    const resp_headers = [_]types.HeaderEntry{.{ .name = "Vary", .value = "*" }};
    const resp = try types.StoredResponse.init(allocator, 200, "OK", &resp_headers, null, .basic);
    defer resp.deinit();

    // With ignoreVary, even Vary: * should match
    try std.testing.expect(varyMatches(req1, req2, resp, .{ .ignore_vary = true }));
}
