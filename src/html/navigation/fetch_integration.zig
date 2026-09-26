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

// Fetch module for HTTP(S) requests - now available via html_core_mod.addImport("fetch")
const fetch = @import("fetch");

// Host platform IO, for file: URLs.
const host = @import("host");

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

    if (std.mem.startsWith(u8, url, "file:")) {
        return handleFileUrl(allocator, url);
    }

    // For HTTP(S) URLs, use the fetch module
    return fetchHttpResource(allocator, url, options);
}

/// Fetch an HTTP(S) resource using the fetch module, blocking until the
/// response is in.
///
/// HTML Standard §7.4.3:
/// Creates an internal request with appropriate destination and mode,
/// then executes the fetch algorithm.
fn fetchHttpResource(
    allocator: Allocator,
    url: []const u8,
    options: NavigationFetchOptions,
) NavigationFetchError!NavigationFetchResult {
    const internal_request = try navigationRequest(allocator, url, options);

    // Step 3: Execute fetch
    var fetch_result = fetch.algorithms.fetch(allocator, internal_request, .{}) catch |err| {
        internal_request.deinit();
        return switch (err) {
            fetch.FetchError.OutOfMemory => NavigationFetchError.OutOfMemory,
            fetch.FetchError.NetworkError => NavigationFetchError.NetworkError,
            fetch.FetchError.AbortError => NavigationFetchError.AbortError,
        };
    };
    defer fetch_result.timing_info.deinit();
    internal_request.deinit();

    const response = fetch_result.response;
    defer response.deinit();
    return resultFromResponse(allocator, url, response, options);
}

/// Steps 1-2 of a navigation fetch: the request for `url`, with the
/// destination, mode, credentials and redirect mode `options` asks for.
/// Owned by the caller - or by the fetch it is handed to.
pub fn navigationRequest(
    allocator: Allocator,
    url: []const u8,
    options: NavigationFetchOptions,
) NavigationFetchError!*fetch.internal.InternalRequest {
    // Step 1: Create an internal request
    // Per Fetch spec §5.1, create request with URL
    const internal_request = fetch.internal.InternalRequest.init(allocator, url) catch {
        return NavigationFetchError.OutOfMemory;
    };
    errdefer internal_request.deinit();

    // Step 2: Set request properties per HTML Standard §7.4.3
    // Set method
    if (!std.mem.eql(u8, options.method, "GET")) {
        allocator.free(internal_request.method);
        internal_request.method = allocator.dupe(u8, options.method) catch {
            return NavigationFetchError.OutOfMemory;
        };
    }

    // Set destination based on navigation options
    internal_request.destination = switch (options.destination) {
        .document => .document,
        .iframe => .iframe,
        .frame => .frame,
        .embed => .embed,
        .object => .object,
    };

    // Set mode to navigate for navigation requests
    internal_request.mode = switch (options.mode) {
        .navigate => .navigate,
        .same_origin => .same_origin,
        .cors => .cors,
        .no_cors => .no_cors,
    };

    // Set credentials mode
    internal_request.credentials_mode = if (options.include_credentials)
        .include
    else
        .same_origin;

    // Set redirect mode
    internal_request.redirect_mode = switch (options.redirect) {
        .follow => .follow,
        .@"error" => .@"error",
        .manual => .manual,
    };

    // Set referrer if provided
    if (options.referrer) |ref| {
        internal_request.referrer = .{ .url = ref };
    }

    // Set origin if provided
    if (options.origin) |org| {
        internal_request.origin = .{ .origin = org };
    }
    return internal_request;
}

/// Step 4 of a navigation fetch: what the navigation needs of `response`,
/// the fetch of `url`, copied out - the response itself stays the caller's.
pub fn resultFromResponse(
    allocator: Allocator,
    url: []const u8,
    response: *fetch.internal.InternalResponse,
    options: NavigationFetchOptions,
) NavigationFetchError!NavigationFetchResult {
    var result = NavigationFetchResult.init(allocator);
    errdefer result.deinit();

    // Set status
    result.status = response.status;
    result.ok = response.status >= 200 and response.status < 300;

    // Check if this is a network error response
    result.is_network_error = response.response_type == .@"error";

    // Get final URL from response URL list
    if (response.url()) |final_url| {
        result.final_url = allocator.dupe(u8, final_url) catch {
            return NavigationFetchError.OutOfMemory;
        };
    } else {
        result.final_url = allocator.dupe(u8, url) catch {
            return NavigationFetchError.OutOfMemory;
        };
    }

    // Get Content-Type header
    // getFirstValue, not get: `get` takes an allocator and returns an owned
    // string, and this dupes into `result` immediately afterwards anyway.
    if (response.header_list.getFirstValue("content-type")) |ct| {
        result.content_type = allocator.dupe(u8, ct) catch {
            return NavigationFetchError.OutOfMemory;
        };
    }

    // Get body bytes
    if (response.body) |body| {
        // getBytes returns a slice, not an optional - an empty body is a
        // zero-length slice, which is a legitimate result and must still be
        // duped so `result.body` is non-null for a 204 or an empty 200.
        const bytes = body.getBytes();
        result.body = allocator.dupe(u8, bytes) catch {
            return NavigationFetchError.OutOfMemory;
        };
    }

    // Determine cross-origin status
    result.is_cross_origin = isCrossOrigin(options.origin, url);

    // Copy relevant headers for COOP/COEP
    result.headers = NavigationFetchResult.HeaderMap.init(allocator);
    const security_headers = [_][]const u8{
        "cross-origin-opener-policy",
        "cross-origin-embedder-policy",
        "cross-origin-resource-policy",
        "content-security-policy",
        "x-frame-options",
    };
    for (security_headers) |header_name| {
        if (response.header_list.getFirstValue(header_name)) |value| {
            const owned_name = allocator.dupe(u8, header_name) catch {
                return NavigationFetchError.OutOfMemory;
            };
            errdefer allocator.free(owned_name);
            const owned_value = allocator.dupe(u8, value) catch {
                allocator.free(owned_name);
                return NavigationFetchError.OutOfMemory;
            };
            result.headers.?.put(owned_name, owned_value) catch {
                allocator.free(owned_name);
                allocator.free(owned_value);
                return NavigationFetchError.OutOfMemory;
            };
        }
    }

    return result;
}

/// A network error, as a navigation sees one: no response to show.
pub fn networkErrorResult(allocator: Allocator, url: []const u8) NavigationFetchError!NavigationFetchResult {
    var result = NavigationFetchResult.init(allocator);
    result.final_url = allocator.dupe(u8, url) catch return NavigationFetchError.OutOfMemory;
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

/// Maximum bytes read from a file: URL. A navigation response has to be held
/// whole in memory to be parsed, so the cap is what keeps a stray path from
/// exhausting the process.
const max_file_navigation_bytes: usize = 32 * 1024 * 1024;

/// Handle file: URLs.
///
/// file: is not a fetch scheme, so this does not go through the Fetch
/// algorithm: it reads the path and synthesises the response a navigation
/// needs. The MIME type comes from the file extension, which is the only
/// supplied type a local file has.
fn handleFileUrl(allocator: Allocator, url: []const u8) NavigationFetchError!NavigationFetchResult {
    var result = NavigationFetchResult.init(allocator);
    errdefer result.deinit();

    result.final_url = allocator.dupe(u8, url) catch return NavigationFetchError.OutOfMemory;
    result.is_network_error = false;
    result.is_cross_origin = false;

    // file://host/path is not supported; only file:///path and file:/path.
    const after_scheme = url["file:".len..];
    const raw_path = if (std.mem.startsWith(u8, after_scheme, "//")) blk: {
        const authority_and_path = after_scheme[2..];
        const slash = std.mem.indexOfScalar(u8, authority_and_path, '/') orelse {
            result.status = 400;
            return result;
        };
        const authority = authority_and_path[0..slash];
        if (authority.len != 0 and !std.mem.eql(u8, authority, "localhost")) {
            result.status = 400;
            return result;
        }
        break :blk authority_and_path[slash..];
    } else after_scheme;

    // Strip any query and fragment: neither is part of a file path.
    const path_end = std.mem.indexOfAny(u8, raw_path, "?#") orelse raw_path.len;
    const encoded_path = raw_path[0..path_end];

    const path = percentDecode(allocator, encoded_path) catch return NavigationFetchError.OutOfMemory;
    defer allocator.free(path);

    const io = host.io();
    const file = host.cwd().openFile(io, path, .{}) catch {
        result.status = 404;
        return result;
    };
    defer file.close(io);

    var file_reader = file.reader(io, &.{});
    const bytes = file_reader.interface.allocRemaining(allocator, .limited(max_file_navigation_bytes)) catch {
        result.status = 404;
        return result;
    };
    result.body = bytes;
    result.status = 200;
    result.ok = true;
    result.content_type = allocator.dupe(u8, contentTypeFromPath(path)) catch {
        return NavigationFetchError.OutOfMemory;
    };

    return result;
}

/// The supplied MIME type of a local file, from its extension.
///
/// mimesniff calls this "determining the supplied MIME type": for a local file
/// the extension is all there is. Unknown extensions get
/// "application/octet-stream", which routes to external software rather than
/// being guessed at.
pub fn contentTypeFromPath(path: []const u8) []const u8 {
    const table = [_]struct { ext: []const u8, mime: []const u8 }{
        .{ .ext = ".html", .mime = "text/html" },
        .{ .ext = ".htm", .mime = "text/html" },
        .{ .ext = ".xhtml", .mime = "application/xhtml+xml" },
        .{ .ext = ".xml", .mime = "text/xml" },
        .{ .ext = ".svg", .mime = "image/svg+xml" },
        .{ .ext = ".css", .mime = "text/css" },
        .{ .ext = ".js", .mime = "text/javascript" },
        .{ .ext = ".mjs", .mime = "text/javascript" },
        .{ .ext = ".json", .mime = "application/json" },
        .{ .ext = ".txt", .mime = "text/plain" },
        .{ .ext = ".vtt", .mime = "text/vtt" },
        .{ .ext = ".png", .mime = "image/png" },
        .{ .ext = ".gif", .mime = "image/gif" },
        .{ .ext = ".jpg", .mime = "image/jpeg" },
        .{ .ext = ".jpeg", .mime = "image/jpeg" },
        .{ .ext = ".bmp", .mime = "image/bmp" },
        .{ .ext = ".webp", .mime = "image/webp" },
        .{ .ext = ".ico", .mime = "image/vnd.microsoft.icon" },
        .{ .ext = ".mp4", .mime = "video/mp4" },
        .{ .ext = ".webm", .mime = "video/webm" },
        .{ .ext = ".ogg", .mime = "audio/ogg" },
        .{ .ext = ".mp3", .mime = "audio/mpeg" },
        .{ .ext = ".wav", .mime = "audio/wav" },
    };

    for (table) |row| {
        if (std.ascii.endsWithIgnoreCase(path, row.ext)) return row.mime;
    }
    return "application/octet-stream";
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
/// HTML "attempt to populate the history entry's document" step 12: "If
/// navigationParams is not null and navigationParams's response's status is
/// 204 or 205, then set navigationParams to null" - no document. Every other
/// response IS one: a 404 or a 500 is the server's error page, and browsers
/// show it and fire load for it. (A network error, status 0, is decided
/// before this is asked.)
pub fn shouldNavigationProceed(status: u16) bool {
    return status != 204 and status != 205;
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
