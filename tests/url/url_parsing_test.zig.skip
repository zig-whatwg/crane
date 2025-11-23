//! URL Parsing Test Suite
//!
//! Comprehensive tests for URL parsing following WHATWG URL Standard.
//! Tests the basic URL parser (spec lines 1030-1530) covering:
//! - Basic URL parsing for all schemes
//! - Relative URL resolution
//! - Edge cases and error handling
//! - Component extraction
//! - Validation error collection

const std = @import("std");
const url_mod = @import("url");
const URL = @import("url0").URL;
const helpers = url_mod.test_helpers;

// ============================================================================
// Basic HTTP/HTTPS Parsing
// ============================================================================

test "parse - basic HTTP URL" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/", null);
    defer url.deinit();

    const href = try url.get_href();
    defer allocator.free(href);

    try helpers.expectEqualStrings(allocator, "http://example.com/", href);
}

test "parse - HTTPS URL with all components" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "https://user:pass@example.com:8080/path?query=value#frag", null);
    defer url.deinit();

    const protocol = try url.get_protocol();
    defer allocator.free(protocol);
    try helpers.expectEqualStrings(allocator, "https:", protocol);

    const username = try url.get_username();
    defer allocator.free(username);
    try helpers.expectEqualStrings(allocator, "user", username);

    const password = try url.get_password();
    defer allocator.free(password);
    try helpers.expectEqualStrings(allocator, "pass", password);

    const hostname = try url.get_hostname();
    defer allocator.free(hostname);
    try helpers.expectEqualStrings(allocator, "example.com", hostname);

    const port = try url.get_port();
    defer allocator.free(port);
    try helpers.expectEqualStrings(allocator, "8080", port);

    const pathname = try url.get_pathname();
    defer allocator.free(pathname);
    try helpers.expectEqualStrings(allocator, "/path", pathname);

    const search = try url.get_search();
    defer allocator.free(search);
    try helpers.expectEqualStrings(allocator, "?query=value", search);

    const hash = try url.get_hash();
    defer allocator.free(hash);
    try helpers.expectEqualStrings(allocator, "#frag", hash);
}

test "parse - URL without port uses default" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/", null);
    defer url.deinit();

    const port = try url.get_port();
    defer allocator.free(port);

    // Default port (80) should be omitted
    try std.testing.expectEqualStrings("", port);
}

test "parse - URL with explicit default port omits it" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com:80/", null);
    defer url.deinit();

    const port = try url.get_port();
    defer allocator.free(port);

    try std.testing.expectEqualStrings("", port);
}

test "parse - URL with non-default port" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com:8080/", null);
    defer url.deinit();

    const port = try url.get_port();
    defer allocator.free(port);

    try std.testing.expectEqualStrings("8080", port);
}

// ============================================================================
// File URLs
// ============================================================================

test "parse - file URL with host" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "file://host/path", null);
    defer url.deinit();

    const protocol = try url.get_protocol();
    defer allocator.free(protocol);
    try std.testing.expectEqualStrings("file:", protocol);

    const hostname = try url.get_hostname();
    defer allocator.free(hostname);
    try std.testing.expectEqualStrings("host", hostname);
}

test "parse - file URL without host (localhost implied)" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "file:///path/to/file", null);
    defer url.deinit();

    const href = try url.get_href();
    defer allocator.free(href);

    try std.testing.expect(std.mem.startsWith(u8, href, "file:///"));
}

// ============================================================================
// Special Schemes
// ============================================================================

test "parse - FTP URL" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "ftp://ftp.example.com/file.txt", null);
    defer url.deinit();

    const protocol = try url.get_protocol();
    defer allocator.free(protocol);
    try std.testing.expectEqualStrings("ftp:", protocol);
}

test "parse - WebSocket URL" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "ws://example.com/socket", null);
    defer url.deinit();

    const protocol = try url.get_protocol();
    defer allocator.free(protocol);
    try std.testing.expectEqualStrings("ws:", protocol);
}

test "parse - WebSocket Secure URL" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "wss://example.com/socket", null);
    defer url.deinit();

    const protocol = try url.get_protocol();
    defer allocator.free(protocol);
    try std.testing.expectEqualStrings("wss:", protocol);
}

// ============================================================================
// Non-Special Schemes (Opaque Paths)
// ============================================================================

test "parse - mailto URL" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "mailto:user@example.com", null);
    defer url.deinit();

    const protocol = try url.get_protocol();
    defer allocator.free(protocol);
    try std.testing.expectEqualStrings("mailto:", protocol);

    const pathname = try url.get_pathname();
    defer allocator.free(pathname);
    try std.testing.expectEqualStrings("user@example.com", pathname);
}

test "parse - data URL" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "data:text/plain;base64,SGVsbG8=", null);
    defer url.deinit();

    const protocol = try url.get_protocol();
    defer allocator.free(protocol);
    try std.testing.expectEqualStrings("data:", protocol);
}

test "parse - javascript URL" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "javascript:alert('test')", null);
    defer url.deinit();

    const protocol = try url.get_protocol();
    defer allocator.free(protocol);
    try std.testing.expectEqualStrings("javascript:", protocol);
}

// ============================================================================
// Relative URL Resolution
// ============================================================================

test "parse - relative path with base" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "other", "http://example.com/path");
    defer url.deinit();

    const href = try url.get_href();
    defer allocator.free(href);

    try std.testing.expectEqualStrings("http://example.com/other", href);
}

test "parse - relative path with ../ with base" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "../other", "http://example.com/path/file");
    defer url.deinit();

    const href = try url.get_href();
    defer allocator.free(href);

    try std.testing.expectEqualStrings("http://example.com/other", href);
}

test "parse - absolute path with base" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "/absolute", "http://example.com/path");
    defer url.deinit();

    const href = try url.get_href();
    defer allocator.free(href);

    try std.testing.expectEqualStrings("http://example.com/absolute", href);
}

test "parse - scheme-relative URL with base" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "//other.com/path", "http://example.com/");
    defer url.deinit();

    const href = try url.get_href();
    defer allocator.free(href);

    try std.testing.expectEqualStrings("http://other.com/path", href);
}

test "parse - query-only relative URL" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "?newquery", "http://example.com/path");
    defer url.deinit();

    const href = try url.get_href();
    defer allocator.free(href);

    try std.testing.expectEqualStrings("http://example.com/path?newquery", href);
}

test "parse - fragment-only relative URL" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "#frag", "http://example.com/path?query");
    defer url.deinit();

    const href = try url.get_href();
    defer allocator.free(href);

    try std.testing.expectEqualStrings("http://example.com/path?query#frag", href);
}

// ============================================================================
// Path Resolution
// ============================================================================

test "parse - multiple ../ segments" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "../../other", "http://example.com/a/b/c");
    defer url.deinit();

    const href = try url.get_href();
    defer allocator.free(href);

    try std.testing.expectEqualStrings("http://example.com/a/other", href);
}

test "parse - ./ segments are removed" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "./file", "http://example.com/path/");
    defer url.deinit();

    const href = try url.get_href();
    defer allocator.free(href);

    try std.testing.expectEqualStrings("http://example.com/path/file", href);
}

test "parse - trailing slash preserved" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/path/", null);
    defer url.deinit();

    const pathname = try url.get_pathname();
    defer allocator.free(pathname);

    try std.testing.expectEqualStrings("/path/", pathname);
}

// ============================================================================
// Username and Password
// ============================================================================

test "parse - URL with username only" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://user@example.com/", null);
    defer url.deinit();

    const username = url.get_username();
    try std.testing.expectEqualStrings("user", username);

    const password = url.get_password();
    try std.testing.expectEqualStrings("", password);
}

test "parse - URL with percent-encoded username" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://user%40host@example.com/", null);
    defer url.deinit();

    const username = url.get_username();
    try std.testing.expect(std.mem.indexOf(u8, username, "%40") != null);
}

// ============================================================================
// Query and Fragment
// ============================================================================

test "parse - URL with empty query" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/?", null);
    defer url.deinit();

    const search = try url.get_search();
    defer allocator.free(search);

    try std.testing.expectEqualStrings("?", search);
}

test "parse - URL with empty fragment" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/#", null);
    defer url.deinit();

    const hash = try url.get_hash();
    defer allocator.free(hash);

    try std.testing.expectEqualStrings("#", hash);
}

test "parse - URL without query or fragment" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/path", null);
    defer url.deinit();

    const search = try url.get_search();
    defer allocator.free(search);
    try std.testing.expectEqualStrings("", search);

    const hash = try url.get_hash();
    defer allocator.free(hash);
    try std.testing.expectEqualStrings("", hash);
}

// ============================================================================
// Edge Cases
// ============================================================================

test "parse - empty string with base" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "", "http://example.com/path");
    defer url.deinit();

    const href = try url.get_href();
    defer allocator.free(href);

    try std.testing.expectEqualStrings("http://example.com/path", href);
}

test "parse - whitespace is trimmed" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "  http://example.com/  ", null);
    defer url.deinit();

    const href = try url.get_href();
    defer allocator.free(href);

    try std.testing.expectEqualStrings("http://example.com/", href);
}

test "parse - tab and newline removed" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://exa\tmple.com/", null);
    defer url.deinit();

    const hostname = try url.get_hostname();
    defer allocator.free(hostname);

    try std.testing.expectEqualStrings("example.com", hostname);
}

// ============================================================================
// Error Cases
// ============================================================================

test "parse - invalid URL without base fails" {
    const allocator = std.testing.allocator;

    const result = helpers.initURL(allocator, "not-a-valid-url", null);
    try std.testing.expectError(error.TypeError, result);
}

test "parse - relative URL without base fails" {
    const allocator = std.testing.allocator;

    const result = helpers.initURL(allocator, "/path", null);
    try std.testing.expectError(error.TypeError, result);
}

test "parse - invalid base URL fails" {
    const allocator = std.testing.allocator;

    const result = helpers.initURL(allocator, "path", "not-valid");
    try std.testing.expectError(error.TypeError, result);
}

// ============================================================================
// Case Sensitivity
// ============================================================================

test "parse - scheme is case-insensitive" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "HTTP://example.com/", null);
    defer url.deinit();

    const protocol = try url.get_protocol();
    defer allocator.free(protocol);

    try std.testing.expectEqualStrings("http:", protocol);
}

test "parse - host is case-insensitive" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://EXAMPLE.COM/", null);
    defer url.deinit();

    const hostname = try url.get_hostname();
    defer allocator.free(hostname);

    try std.testing.expectEqualStrings("example.com", hostname);
}

test "parse - path is case-sensitive" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/PATH", null);
    defer url.deinit();

    const pathname = try url.get_pathname();
    defer allocator.free(pathname);

    try std.testing.expectEqualStrings("/PATH", pathname);
}

// ============================================================================
// Static Methods
// ============================================================================

test "URL.parse - returns null for invalid URL" {
    const allocator = std.testing.allocator;

    const result = URL.parse(allocator, "not-valid", null);
    try std.testing.expect(result == null);
}

test "URL.parse - returns URL for valid URL" {
    const allocator = std.testing.allocator;

    const result = URL.parse(allocator, "http://example.com/", null);
    try std.testing.expect(result != null);

    if (result) |url_val| {
        var url = url_val;
        defer url.deinit();
    }
}

test "URL.canParse - returns false for invalid URL" {
    const allocator = std.testing.allocator;

    const result = URL.canParse(allocator, "not-valid", null);
    try std.testing.expect(!result);
}

test "URL.canParse - returns true for valid URL" {
    const allocator = std.testing.allocator;

    const result = URL.canParse(allocator, "http://example.com/", null);
    try std.testing.expect(result);
}

// ============================================================================
// toJSON Method
// ============================================================================

test "toJSON - returns href" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/path", null);
    defer url.deinit();

    const json = try url.call_toJSON();
    defer allocator.free(json);

    try std.testing.expectEqualStrings("http://example.com/path", json);
}

// ============================================================================
// Complex Real-World URLs
// ============================================================================

test "parse - GitHub URL" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "https://github.com/zig-lang/zig/issues/12345", null);
    defer url.deinit();

    const hostname = try url.get_hostname();
    defer allocator.free(hostname);
    try std.testing.expectEqualStrings("github.com", hostname);

    const pathname = try url.get_pathname();
    defer allocator.free(pathname);
    try std.testing.expectEqualStrings("/zig-lang/zig/issues/12345", pathname);
}

test "parse - URL with many query parameters" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/?a=1&b=2&c=3", null);
    defer url.deinit();

    const search = try url.get_search();
    defer allocator.free(search);

    try std.testing.expectEqualStrings("?a=1&b=2&c=3", search);
}

test "parse - URL with encoded characters in query" {
    const allocator = std.testing.allocator;

    var url = try helpers.initURL(allocator, "http://example.com/?q=hello%20world", null);
    defer url.deinit();

    const search = try url.get_search();
    defer allocator.free(search);

    try std.testing.expect(std.mem.indexOf(u8, search, "hello%20world") != null);
}
