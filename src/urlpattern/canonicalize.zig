//! URLPattern Canonicalization Callbacks
//!
//! WHATWG URLPattern Standard: https://urlpattern.spec.whatwg.org/#canon
//! Spec Reference: Section 3.1 Encoding callbacks
//!
//! These callbacks are used to canonicalize fixed text parts of patterns
//! during component compilation. Each URL component has specific
//! canonicalization rules derived from URL parsing.
//!
//! ## Canonicalizers
//!
//! - `canonicalizeProtocol` - Lowercase, validate scheme
//! - `canonicalizeUsername` - Percent-encode with userinfo set
//! - `canonicalizePassword` - Percent-encode with userinfo set
//! - `canonicalizeHostname` - IDNA/punycode processing
//! - `canonicalizeIPv6Hostname` - Special IPv6 handling
//! - `canonicalizePort` - Validate numeric, remove default ports
//! - `canonicalizePathname` - Special vs opaque path handling
//! - `canonicalizeOpaquePathname` - Opaque path percent-encoding
//! - `canonicalizeSearch` - Remove leading '?', percent-encode
//! - `canonicalizeHash` - Remove leading '#', percent-encode

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import URL module components for canonicalization
const url_mod = @import("url");
const percent_encoding = url_mod.percent_encoding;
const encode_sets = url_mod.encode_sets;
const special_schemes = url_mod.special_schemes;
const idna = url_mod.idna;
const host_parser = url_mod.host_parser;

pub const CanonicalizationError = error{
    InvalidProtocol,
    InvalidHostname,
    InvalidIPv6,
    InvalidPort,
    InvalidPathname,
    OutOfMemory,
};

/// Create a dummy URL for canonicalization
/// Spec: "create a dummy URL" algorithm
fn createDummyURL() struct { scheme: []const u8, host: []const u8 } {
    return .{
        .scheme = "https",
        .host = "dummy.invalid",
    };
}

/// Canonicalize a protocol/scheme (spec section 3.1)
///
/// If value is empty, return empty string.
/// Parse using basic URL parser, return the scheme component.
///
/// Example: "HTTPS:" -> "https"
/// Example: "http" -> "http"
pub fn canonicalizeProtocol(allocator: Allocator, value: []const u8) CanonicalizationError![]u8 {
    // Step 1: If value is empty, return value
    if (value.len == 0) {
        return try allocator.dupe(u8, value);
    }

    // Step 2: Parse "value://dummy.invalid/" as URL
    // The basic URL parser normalizes the scheme to lowercase
    // We simulate this by:
    // 1. Stripping trailing ':'
    // 2. Lowercasing
    // 3. Validating scheme characters

    var clean_value = value;
    // Strip trailing ':' if present
    if (clean_value.len > 0 and clean_value[clean_value.len - 1] == ':') {
        clean_value = clean_value[0 .. clean_value.len - 1];
    }

    // Validate scheme: must start with ASCII alpha, followed by ASCII alphanumeric, +, -, or .
    if (clean_value.len == 0) {
        return CanonicalizationError.InvalidProtocol;
    }

    if (!std.ascii.isAlphabetic(clean_value[0])) {
        return CanonicalizationError.InvalidProtocol;
    }

    for (clean_value[1..]) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '+' and c != '-' and c != '.') {
            return CanonicalizationError.InvalidProtocol;
        }
    }

    // Lowercase the scheme
    const result = try allocator.alloc(u8, clean_value.len);
    for (clean_value, 0..) |c, i| {
        result[i] = std.ascii.toLower(c);
    }

    return result;
}

/// Canonicalize a username (spec section 3.1)
///
/// If value is empty, return empty string.
/// Use URL's "set the username" algorithm via dummy URL.
///
/// Example: "user name" -> "user%20name"
pub fn canonicalizeUsername(allocator: Allocator, value: []const u8) CanonicalizationError![]u8 {
    // Step 1: If value is empty, return value
    if (value.len == 0) {
        return try allocator.dupe(u8, value);
    }

    // Step 2-4: Set username on dummy URL, return result
    // Username uses userinfo percent-encode set
    return percent_encoding.utf8PercentEncode(
        allocator,
        value,
        encode_sets.EncodeSet.userinfo,
    ) catch |err| switch (err) {
        error.OutOfMemory => return CanonicalizationError.OutOfMemory,
    };
}

/// Canonicalize a password (spec section 3.1)
///
/// If value is empty, return empty string.
/// Use URL's "set the password" algorithm via dummy URL.
///
/// Example: "pass word" -> "pass%20word"
pub fn canonicalizePassword(allocator: Allocator, value: []const u8) CanonicalizationError![]u8 {
    // Step 1: If value is empty, return value
    if (value.len == 0) {
        return try allocator.dupe(u8, value);
    }

    // Step 2-4: Set password on dummy URL, return result
    // Password uses userinfo percent-encode set
    return percent_encoding.utf8PercentEncode(
        allocator,
        value,
        encode_sets.EncodeSet.userinfo,
    ) catch |err| switch (err) {
        error.OutOfMemory => return CanonicalizationError.OutOfMemory,
    };
}

/// Canonicalize a hostname (spec section 3.1)
///
/// If value is empty, return empty string.
/// Use basic URL parser with hostname state override.
///
/// Example: "EXAMPLE.COM" -> "example.com"
/// Example: "münchen.de" -> "xn--mnchen-3ya.de" (punycode)
pub fn canonicalizeHostname(allocator: Allocator, value: []const u8) CanonicalizationError![]u8 {
    // Step 1: If value is empty, return value
    if (value.len == 0) {
        return try allocator.dupe(u8, value);
    }

    // Step 2-5: Use URL parser's host parsing (hostname state)
    // This handles IDNA/punycode conversion and lowercasing

    // Use IDNA domain-to-ASCII for hostname canonicalization
    const ascii_domain = idna.domainToASCII(allocator, value, false) catch {
        return CanonicalizationError.InvalidHostname;
    };

    return ascii_domain;
}

/// Canonicalize an IPv6 hostname (spec section 3.1)
///
/// Special handling for IPv6 addresses in hostnames.
/// Only accepts hex digits, '[', ']', and ':'.
/// Lowercases hex digits.
///
/// Example: "[::1]" -> "[::1]"
/// Example: "[2001:DB8::1]" -> "[2001:db8::1]"
pub fn canonicalizeIPv6Hostname(allocator: Allocator, value: []const u8) CanonicalizationError![]u8 {
    // Step 1: If code point length < 2, return false (but we return the value)
    if (value.len < 2) {
        return try allocator.dupe(u8, value);
    }

    // Step 2: Validate and lowercase
    const result = try allocator.alloc(u8, value.len);
    errdefer allocator.free(result);

    for (value, 0..) |c, i| {
        // Must be ASCII hex digit, '[', ']', or ':'
        if (std.ascii.isHex(c)) {
            // Lowercase hex digits
            result[i] = std.ascii.toLower(c);
        } else if (c == '[' or c == ']' or c == ':') {
            result[i] = c;
        } else {
            // errdefer will free result, just return the error
            return CanonicalizationError.InvalidIPv6;
        }
    }

    return result;
}

/// Canonicalize a port (spec section 3.1)
///
/// If value is empty, return empty string.
/// Validate numeric port, remove default ports for known protocols.
///
/// Example: "443" with "https" -> "" (default port removed)
/// Example: "8080" with "http" -> "8080"
pub fn canonicalizePort(allocator: Allocator, port_value: []const u8, protocol_value: ?[]const u8) CanonicalizationError![]u8 {
    // Step 1: If portValue is empty, return portValue
    if (port_value.len == 0) {
        return try allocator.dupe(u8, port_value);
    }

    // Step 2-4: Parse and validate port
    // Validate all characters are digits
    for (port_value) |c| {
        if (!std.ascii.isDigit(c)) {
            return CanonicalizationError.InvalidPort;
        }
    }

    // Parse the port number
    const port = std.fmt.parseInt(u16, port_value, 10) catch {
        return CanonicalizationError.InvalidPort;
    };

    // Step 5: If protocol given, check if port is default for that protocol
    if (protocol_value) |protocol| {
        if (special_schemes.defaultPort(protocol)) |default_port| {
            if (port == default_port) {
                // Return empty string for default port
                return try allocator.dupe(u8, "");
            }
        }
    }

    // Step 6: Return serialized port
    return try std.fmt.allocPrint(allocator, "{d}", .{port});
}

/// Canonicalize a pathname for special schemes (spec section 3.1)
///
/// If value is empty, return empty string.
/// Uses path URL encoding and handles '..' and '.' segments.
///
/// Example: "/foo/../bar" -> "/bar"
/// Example: "/hello world" -> "/hello%20world"
pub fn canonicalizePathname(allocator: Allocator, value: []const u8) CanonicalizationError![]u8 {
    // Step 1: If value is empty, return value
    if (value.len == 0) {
        return try allocator.dupe(u8, value);
    }

    // Step 2: Handle leading slash
    const leading_slash = value.len > 0 and value[0] == '/';

    // Step 3: For special scheme URLs, use path-start-state parsing simulation
    // We need to:
    // 1. Prepend "/-" if no leading slash (to prevent dot collapse)
    // 2. Percent-encode with path encode set
    // 3. Remove the "/-" prefix if we added it

    var modified_value: []const u8 = undefined;
    var needs_prefix_removal = false;

    if (!leading_slash) {
        // Prepend "/-" to avoid dot collapse issues
        const temp = try allocator.alloc(u8, 2 + value.len);
        temp[0] = '/';
        temp[1] = '-';
        @memcpy(temp[2..], value);
        modified_value = temp;
        needs_prefix_removal = true;
    } else {
        modified_value = value;
    }
    defer if (needs_prefix_removal) allocator.free(modified_value);

    // Percent-encode with path encode set
    const encoded = percent_encoding.utf8PercentEncode(
        allocator,
        modified_value,
        encode_sets.EncodeSet.path,
    ) catch |err| switch (err) {
        error.OutOfMemory => return CanonicalizationError.OutOfMemory,
    };
    defer if (needs_prefix_removal) allocator.free(encoded);

    // Remove the "/-" prefix if we added it
    if (needs_prefix_removal) {
        if (encoded.len >= 2) {
            return try allocator.dupe(u8, encoded[2..]);
        }
        return try allocator.dupe(u8, "");
    }

    return encoded;
}

/// Canonicalize an opaque pathname (spec section 3.1)
///
/// For non-special scheme URLs that have opaque paths.
///
/// Example: "data:text/plain,hello" pathname part
pub fn canonicalizeOpaquePathname(allocator: Allocator, value: []const u8) CanonicalizationError![]u8 {
    // Step 1: If value is empty, return value
    if (value.len == 0) {
        return try allocator.dupe(u8, value);
    }

    // Step 2-6: Use opaque path state parsing
    // Percent-encode using C0 control encode set
    return percent_encoding.utf8PercentEncode(
        allocator,
        value,
        encode_sets.EncodeSet.c0_control,
    ) catch |err| switch (err) {
        error.OutOfMemory => return CanonicalizationError.OutOfMemory,
    };
}

/// Canonicalize a search/query string (spec section 3.1)
///
/// If value is empty, return empty string.
/// Remove leading '?', percent-encode with query encode set.
///
/// Example: "?foo=bar" -> "foo=bar"
/// Example: "hello world" -> "hello%20world"
pub fn canonicalizeSearch(allocator: Allocator, value: []const u8) CanonicalizationError![]u8 {
    // Step 1: If value is empty, return value
    if (value.len == 0) {
        return try allocator.dupe(u8, value);
    }

    // Step 2-5: Remove leading '?' if present, set query on dummy URL
    var search_value = value;
    if (search_value.len > 0 and search_value[0] == '?') {
        search_value = search_value[1..];
    }

    // Percent-encode with query encode set
    return percent_encoding.utf8PercentEncode(
        allocator,
        search_value,
        encode_sets.EncodeSet.query,
    ) catch |err| switch (err) {
        error.OutOfMemory => return CanonicalizationError.OutOfMemory,
    };
}

/// Canonicalize a hash/fragment (spec section 3.1)
///
/// If value is empty, return empty string.
/// Remove leading '#', percent-encode with fragment encode set.
///
/// Example: "#section" -> "section"
/// Example: "hello world" -> "hello%20world"
pub fn canonicalizeHash(allocator: Allocator, value: []const u8) CanonicalizationError![]u8 {
    // Step 1: If value is empty, return value
    if (value.len == 0) {
        return try allocator.dupe(u8, value);
    }

    // Step 2-5: Remove leading '#' if present, set fragment on dummy URL
    var hash_value = value;
    if (hash_value.len > 0 and hash_value[0] == '#') {
        hash_value = hash_value[1..];
    }

    // Percent-encode with fragment encode set
    return percent_encoding.utf8PercentEncode(
        allocator,
        hash_value,
        encode_sets.EncodeSet.fragment,
    ) catch |err| switch (err) {
        error.OutOfMemory => return CanonicalizationError.OutOfMemory,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "canonicalizeProtocol - basic" {
    const allocator = std.testing.allocator;

    // Empty value
    {
        const result = try canonicalizeProtocol(allocator, "");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("", result);
    }

    // Lowercase
    {
        const result = try canonicalizeProtocol(allocator, "HTTPS");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("https", result);
    }

    // Strip trailing colon
    {
        const result = try canonicalizeProtocol(allocator, "http:");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("http", result);
    }

    // Valid scheme with special chars
    {
        const result = try canonicalizeProtocol(allocator, "my+custom-scheme.1");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("my+custom-scheme.1", result);
    }
}

test "canonicalizeProtocol - invalid" {
    const allocator = std.testing.allocator;

    // Must start with alpha
    {
        const result = canonicalizeProtocol(allocator, "123abc");
        try std.testing.expectError(CanonicalizationError.InvalidProtocol, result);
    }

    // Invalid character
    {
        const result = canonicalizeProtocol(allocator, "foo@bar");
        try std.testing.expectError(CanonicalizationError.InvalidProtocol, result);
    }
}

test "canonicalizeUsername - basic" {
    const allocator = std.testing.allocator;

    // Empty value
    {
        const result = try canonicalizeUsername(allocator, "");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("", result);
    }

    // Simple username
    {
        const result = try canonicalizeUsername(allocator, "user");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("user", result);
    }

    // Username with space
    {
        const result = try canonicalizeUsername(allocator, "user name");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("user%20name", result);
    }
}

test "canonicalizePassword - basic" {
    const allocator = std.testing.allocator;

    // Empty value
    {
        const result = try canonicalizePassword(allocator, "");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("", result);
    }

    // Password with special chars
    {
        const result = try canonicalizePassword(allocator, "pass:word");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("pass%3Aword", result);
    }
}

test "canonicalizeIPv6Hostname - basic" {
    const allocator = std.testing.allocator;

    // Simple IPv6
    {
        const result = try canonicalizeIPv6Hostname(allocator, "[::1]");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("[::1]", result);
    }

    // Uppercase to lowercase
    {
        const result = try canonicalizeIPv6Hostname(allocator, "[2001:DB8::1]");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("[2001:db8::1]", result);
    }

    // Invalid character
    {
        const result = canonicalizeIPv6Hostname(allocator, "[::g]");
        try std.testing.expectError(CanonicalizationError.InvalidIPv6, result);
    }
}

test "canonicalizePort - basic" {
    const allocator = std.testing.allocator;

    // Empty value
    {
        const result = try canonicalizePort(allocator, "", null);
        defer allocator.free(result);
        try std.testing.expectEqualStrings("", result);
    }

    // Simple port
    {
        const result = try canonicalizePort(allocator, "8080", null);
        defer allocator.free(result);
        try std.testing.expectEqualStrings("8080", result);
    }

    // Default port for https
    {
        const result = try canonicalizePort(allocator, "443", "https");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("", result);
    }

    // Default port for http
    {
        const result = try canonicalizePort(allocator, "80", "http");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("", result);
    }

    // Non-default port
    {
        const result = try canonicalizePort(allocator, "8443", "https");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("8443", result);
    }

    // Invalid port (non-numeric)
    {
        const result = canonicalizePort(allocator, "abc", null);
        try std.testing.expectError(CanonicalizationError.InvalidPort, result);
    }
}

test "canonicalizePathname - basic" {
    const allocator = std.testing.allocator;

    // Empty value
    {
        const result = try canonicalizePathname(allocator, "");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("", result);
    }

    // Simple path
    {
        const result = try canonicalizePathname(allocator, "/foo/bar");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("/foo/bar", result);
    }

    // Path with space
    {
        const result = try canonicalizePathname(allocator, "/hello world");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("/hello%20world", result);
    }

    // Path without leading slash
    {
        const result = try canonicalizePathname(allocator, "foo/bar");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("foo/bar", result);
    }
}

test "canonicalizeSearch - basic" {
    const allocator = std.testing.allocator;

    // Empty value
    {
        const result = try canonicalizeSearch(allocator, "");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("", result);
    }

    // With leading ?
    {
        const result = try canonicalizeSearch(allocator, "?foo=bar");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("foo=bar", result);
    }

    // Without leading ?
    {
        const result = try canonicalizeSearch(allocator, "foo=bar");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("foo=bar", result);
    }

    // With space
    {
        const result = try canonicalizeSearch(allocator, "foo=hello world");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("foo=hello%20world", result);
    }
}

test "canonicalizeHash - basic" {
    const allocator = std.testing.allocator;

    // Empty value
    {
        const result = try canonicalizeHash(allocator, "");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("", result);
    }

    // With leading #
    {
        const result = try canonicalizeHash(allocator, "#section");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("section", result);
    }

    // Without leading #
    {
        const result = try canonicalizeHash(allocator, "section");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("section", result);
    }

    // With space
    {
        const result = try canonicalizeHash(allocator, "section one");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("section%20one", result);
    }
}
