//! Navigation Fetch Integration - HTML Standard §7.4
//!
//! This module provides the fetch integration for navigation, connecting
//! the navigation algorithms to the Fetch module for actual network requests.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html
//!
//! ## Key Functions
//!
//! - `fetchNavigationResource`: Performs the actual fetch for navigation
//! - `processNavigationResponse`: Handles the response from navigation fetch
//! - `isHtmlResponse`: Checks if response is HTML based on Content-Type

const std = @import("std");
const Allocator = std.mem.Allocator;

// The fetch module is conditionally available - when not available,
// navigation will work in offline mode without actual fetching.
// This allows html_core to be used without fetch dependency.

/// Fetch result for navigation
pub const NavigationFetchResult = struct {
    allocator: Allocator,

    /// HTTP status code (200, 404, etc.)
    status: u16,

    /// Final URL after redirects
    final_url: []const u8,

    /// Content-Type header value
    content_type: ?[]const u8,

    /// Response body (HTML content for documents)
    body: ?[]const u8,

    /// Whether the fetch was successful (2xx status)
    ok: bool,

    /// Whether this is a network error (couldn't reach server)
    is_network_error: bool,

    /// Whether cross-origin
    is_cross_origin: bool,

    /// Response headers (optional, for COOP/COEP)
    headers: ?HeaderMap,

    pub const HeaderMap = std.StringHashMap([]const u8);

    pub fn init(allocator: Allocator) NavigationFetchResult {
        return .{
            .allocator = allocator,
            .status = 0,
            .final_url = "",
            .content_type = null,
            .body = null,
            .ok = false,
            .is_network_error = true,
            .is_cross_origin = false,
            .headers = null,
        };
    }

    pub fn deinit(self: *NavigationFetchResult) void {
        if (self.final_url.len > 0 and !isStaticString(self.final_url)) {
            self.allocator.free(self.final_url);
        }
        if (self.content_type) |ct| {
            if (!isStaticString(ct)) {
                self.allocator.free(ct);
            }
        }
        if (self.body) |b| {
            self.allocator.free(b);
        }
        if (self.headers) |*h| {
            var it = h.iterator();
            while (it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            h.deinit();
        }
    }

    fn isStaticString(s: []const u8) bool {
        // Check if the string pointer is in the static string section
        // This is a heuristic - we consider strings shorter than 256 bytes
        // and with high addresses as potentially static
        _ = s;
        return false; // For safety, always assume owned
    }
};

/// Navigation fetch options
pub const NavigationFetchOptions = struct {
    /// Request method (GET, POST, etc.)
    method: []const u8 = "GET",

    /// Request body for POST
    body: ?[]const u8 = null,

    /// Request origin for CORS
    origin: ?[]const u8 = null,

    /// Referrer URL
    referrer: ?[]const u8 = null,

    /// Whether credentials should be included
    include_credentials: bool = true,

    /// Request destination type
    destination: Destination = .document,

    /// Request mode for CORS
    mode: Mode = .navigate,

    /// Redirect behavior
    redirect: Redirect = .follow,

    pub const Destination = enum {
        document,
        iframe,
        frame,
        embed,
        object,
    };

    pub const Mode = enum {
        navigate,
        same_origin,
        cors,
        no_cors,
    };

    pub const Redirect = enum {
        follow,
        @"error",
        manual,
    };
};

/// Error types for navigation fetch
pub const NavigationFetchError = error{
    OutOfMemory,
    NetworkError,
    AbortError,
    SecurityError,
    InvalidUrl,
    FetchNotAvailable,
};

/// Fetch a navigation resource.
///
/// HTML Standard §7.4.3 step 13+:
/// "If navigationType is not reload, then: ... Fetch request."
///
/// This function performs the actual network fetch for a navigation request
/// using the Fetch module infrastructure.
///
/// Returns a NavigationFetchResult containing:
/// - status: HTTP status code
/// - final_url: URL after redirects
/// - content_type: Content-Type header
/// - body: Response body bytes
/// - ok: Whether status is 2xx
/// - is_network_error: Whether network error occurred
pub fn fetchNavigationResource(
    allocator: Allocator,
    url: []const u8,
    options: NavigationFetchOptions,
) NavigationFetchError!NavigationFetchResult {
    // For now, we'll use a stub implementation until the fetch module
    // is properly integrated. This allows the navigation infrastructure
    // to be built without blocking on fetch integration.
    //
    // TODO: Wire up actual fetch module when build.zig is updated to
    // include fetch import in html_core_mod

    _ = options;

    // Check for special URLs that don't need fetching
    if (std.mem.startsWith(u8, url, "about:")) {
        return handleAboutUrl(allocator, url);
    }

    if (std.mem.startsWith(u8, url, "data:")) {
        return handleDataUrl(allocator, url);
    }

    if (std.mem.startsWith(u8, url, "javascript:")) {
        return handleJavascriptUrl(allocator, url);
    }

    // For HTTP(S) URLs, we need the actual fetch module
    // Return a placeholder that indicates fetch is not yet wired
    var result = NavigationFetchResult.init(allocator);
    result.is_network_error = true;
    result.final_url = try allocator.dupe(u8, url);
    return result;
}

/// Handle about: URLs
fn handleAboutUrl(allocator: Allocator, url: []const u8) NavigationFetchError!NavigationFetchResult {
    var result = NavigationFetchResult.init(allocator);
    result.final_url = try allocator.dupe(u8, url);

    if (std.mem.eql(u8, url, "about:blank")) {
        result.status = 200;
        result.ok = true;
        result.is_network_error = false;
        result.content_type = try allocator.dupe(u8, "text/html;charset=utf-8");
        result.body = try allocator.dupe(u8, "");
    } else if (std.mem.eql(u8, url, "about:srcdoc")) {
        // about:srcdoc is handled by the iframe srcdoc attribute
        result.status = 200;
        result.ok = true;
        result.is_network_error = false;
        result.content_type = try allocator.dupe(u8, "text/html;charset=utf-8");
    } else {
        // Unknown about: URL
        result.status = 404;
        result.ok = false;
        result.is_network_error = false;
    }

    return result;
}

/// Handle data: URLs
fn handleDataUrl(allocator: Allocator, url: []const u8) NavigationFetchError!NavigationFetchResult {
    var result = NavigationFetchResult.init(allocator);
    result.final_url = try allocator.dupe(u8, url);

    // Parse data URL: data:[<mediatype>][;base64],<data>
    const data_prefix = "data:";
    if (url.len <= data_prefix.len) {
        result.status = 400;
        result.ok = false;
        result.is_network_error = false;
        return result;
    }

    const rest = url[data_prefix.len..];

    // Find comma separator
    const comma_pos = std.mem.indexOf(u8, rest, ",");
    if (comma_pos == null) {
        result.status = 400;
        result.ok = false;
        result.is_network_error = false;
        return result;
    }

    const metadata = rest[0..comma_pos.?];
    const data_part = rest[comma_pos.? + 1 ..];

    // Check for base64 encoding
    const is_base64 = std.mem.endsWith(u8, metadata, ";base64");
    const mediatype = if (is_base64)
        metadata[0 .. metadata.len - 7]
    else
        metadata;

    // Set content type (default to text/plain if empty)
    if (mediatype.len > 0) {
        result.content_type = try allocator.dupe(u8, mediatype);
    } else {
        result.content_type = try allocator.dupe(u8, "text/plain;charset=US-ASCII");
    }

    // Decode data
    if (is_base64) {
        // Base64 decode
        const decoded_size = std.base64.standard.Decoder.calcSizeForSlice(data_part) catch {
            result.status = 400;
            result.ok = false;
            result.is_network_error = false;
            return result;
        };
        const decoded = try allocator.alloc(u8, decoded_size);
        errdefer allocator.free(decoded);

        std.base64.standard.Decoder.decode(decoded, data_part) catch {
            allocator.free(decoded);
            result.status = 400;
            result.ok = false;
            result.is_network_error = false;
            return result;
        };
        result.body = decoded;
    } else {
        // Percent-decode
        result.body = try percentDecode(allocator, data_part);
    }

    result.status = 200;
    result.ok = true;
    result.is_network_error = false;

    return result;
}

/// Handle javascript: URLs
fn handleJavascriptUrl(allocator: Allocator, url: []const u8) NavigationFetchError!NavigationFetchResult {
    _ = allocator;
    _ = url;
    // javascript: URLs don't return a document through fetch
    // They are executed inline and may produce a new document
    return NavigationFetchError.SecurityError;
}

/// Percent-decode a string
fn percentDecode(allocator: Allocator, input: []const u8) ![]u8 {
    // Pre-calculate the maximum size needed
    var result = try allocator.alloc(u8, input.len);
    var write_idx: usize = 0;

    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            const hex = input[i + 1 .. i + 3];
            const byte = std.fmt.parseInt(u8, hex, 16) catch {
                // Invalid hex, keep as-is
                result[write_idx] = input[i];
                write_idx += 1;
                i += 1;
                continue;
            };
            result[write_idx] = byte;
            write_idx += 1;
            i += 3;
        } else if (input[i] == '+') {
            result[write_idx] = ' ';
            write_idx += 1;
            i += 1;
        } else {
            result[write_idx] = input[i];
            write_idx += 1;
            i += 1;
        }
    }

    // Resize to actual size
    if (write_idx < result.len) {
        return allocator.realloc(result, write_idx);
    }
    return result;
}

/// Check if a response is HTML based on Content-Type
pub fn isHtmlResponse(content_type: ?[]const u8) bool {
    const ct = content_type orelse return false;

    // Check for text/html or application/xhtml+xml
    if (std.mem.startsWith(u8, ct, "text/html")) return true;
    if (std.mem.startsWith(u8, ct, "application/xhtml+xml")) return true;

    return false;
}

/// Check if a response is XML based on Content-Type
pub fn isXmlResponse(content_type: ?[]const u8) bool {
    const ct = content_type orelse return false;

    if (std.mem.startsWith(u8, ct, "text/xml")) return true;
    if (std.mem.startsWith(u8, ct, "application/xml")) return true;
    if (std.mem.endsWith(u8, ct, "+xml")) return true;

    return false;
}

/// Check if navigation should proceed based on response status
pub fn shouldNavigationProceed(status: u16) bool {
    // Navigation proceeds for 2xx responses and some redirects
    // 204 No Content and 205 Reset Content don't create new documents
    return status >= 200 and status < 300 and status != 204 and status != 205;
}

/// Determine if a navigation is cross-origin
pub fn isCrossOrigin(source_origin: ?[]const u8, target_url: []const u8) bool {
    const src = source_origin orelse return true; // No origin = cross-origin

    // Extract origin from target URL (scheme + host + port)
    const target_origin = extractOrigin(target_url) orelse return true;

    return !std.mem.eql(u8, src, target_origin);
}

/// Extract origin from a URL string (scheme://host:port)
fn extractOrigin(url: []const u8) ?[]const u8 {
    // Find scheme separator
    const scheme_end = std.mem.indexOf(u8, url, "://") orelse return null;

    // Find path start (after host)
    const after_scheme = url[scheme_end + 3 ..];
    const path_start = std.mem.indexOf(u8, after_scheme, "/");

    if (path_start) |ps| {
        return url[0 .. scheme_end + 3 + ps];
    } else {
        return url;
    }
}

// =============================================================================
// Tests
// =============================================================================

test "handleAboutUrl - about:blank" {
    const allocator = std.testing.allocator;

    var result = try handleAboutUrl(allocator, "about:blank");
    defer result.deinit();

    try std.testing.expectEqual(@as(u16, 200), result.status);
    try std.testing.expect(result.ok);
    try std.testing.expect(!result.is_network_error);
    try std.testing.expectEqualStrings("text/html;charset=utf-8", result.content_type.?);
}

test "handleDataUrl - text data" {
    const allocator = std.testing.allocator;

    var result = try handleDataUrl(allocator, "data:text/plain,Hello%20World");
    defer result.deinit();

    try std.testing.expectEqual(@as(u16, 200), result.status);
    try std.testing.expect(result.ok);
    try std.testing.expectEqualStrings("text/plain", result.content_type.?);
    try std.testing.expectEqualStrings("Hello World", result.body.?);
}

test "handleDataUrl - base64 data" {
    const allocator = std.testing.allocator;

    // "Hello" in base64 is "SGVsbG8="
    var result = try handleDataUrl(allocator, "data:text/plain;base64,SGVsbG8=");
    defer result.deinit();

    try std.testing.expectEqual(@as(u16, 200), result.status);
    try std.testing.expect(result.ok);
    try std.testing.expectEqualStrings("Hello", result.body.?);
}

test "isHtmlResponse" {
    try std.testing.expect(isHtmlResponse("text/html"));
    try std.testing.expect(isHtmlResponse("text/html; charset=utf-8"));
    try std.testing.expect(isHtmlResponse("application/xhtml+xml"));
    try std.testing.expect(!isHtmlResponse("text/plain"));
    try std.testing.expect(!isHtmlResponse(null));
}

test "isCrossOrigin" {
    try std.testing.expect(!isCrossOrigin("https://example.com", "https://example.com/page"));
    try std.testing.expect(isCrossOrigin("https://example.com", "https://other.com/page"));
    try std.testing.expect(isCrossOrigin("http://example.com", "https://example.com/page"));
    try std.testing.expect(isCrossOrigin(null, "https://example.com"));
}

test "extractOrigin" {
    try std.testing.expectEqualStrings("https://example.com", extractOrigin("https://example.com/path").?);
    try std.testing.expectEqualStrings("https://example.com:8080", extractOrigin("https://example.com:8080/path").?);
    try std.testing.expectEqualStrings("http://localhost", extractOrigin("http://localhost/").?);
}
