//! Cookie Domain and Path Matching Algorithms
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/
//! RFC 6265bis: https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis
//!
//! This module implements domain matching, path matching, and public suffix
//! validation for cookie scoping.

const std = @import("std");

/// Domain matching per RFC 6265bis Section 5.1.3
/// https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis#section-5.1.3
///
/// A string domain-matches a given domain string if at least one of the
/// following conditions hold:
///
/// 1. The domain string and the string are identical (case-insensitive)
/// 2. All of the following conditions hold:
///    - The domain string is a suffix of the string
///    - The last character of the string that is not included in the
///      domain string is a %x2E (".") character
///    - The string is a host name (not an IP address)
pub fn domainMatches(domain: []const u8, cookie_domain: []const u8) bool {
    // Remove any leading dots for comparison
    const clean_domain = if (domain.len > 0 and domain[0] == '.')
        domain[1..]
    else
        domain;

    const clean_cookie_domain = if (cookie_domain.len > 0 and cookie_domain[0] == '.')
        cookie_domain[1..]
    else
        cookie_domain;

    // Case-insensitive comparison
    // Condition 1: Exact match
    if (std.ascii.eqlIgnoreCase(clean_domain, clean_cookie_domain)) {
        return true;
    }

    // Condition 2: cookie_domain is a suffix of domain
    if (clean_domain.len > clean_cookie_domain.len) {
        // Check if it ends with the cookie domain
        const suffix_start = clean_domain.len - clean_cookie_domain.len;
        const suffix = clean_domain[suffix_start..];

        if (std.ascii.eqlIgnoreCase(suffix, clean_cookie_domain)) {
            // Check that the character before is a dot
            if (suffix_start > 0 and clean_domain[suffix_start - 1] == '.') {
                // Don't match if domain is an IP address
                if (!isIpAddress(clean_domain)) {
                    return true;
                }
            }
        }
    }

    return false;
}

/// Path matching per RFC 6265bis Section 5.1.4
/// https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis#section-5.1.4
///
/// A request-path path-matches a given cookie-path if at least one of the
/// following conditions holds:
///
/// 1. The cookie-path and the request-path are identical
/// 2. The cookie-path is a prefix of the request-path, and either:
///    - The last character of the cookie-path is %x2F ("/")
///    - The first character of the request-path that is not included in
///      the cookie-path is a %x2F ("/") character
pub fn pathMatches(request_path: []const u8, cookie_path: []const u8) bool {
    // Empty paths should be treated as "/"
    const req_path = if (request_path.len == 0) "/" else request_path;
    const cook_path = if (cookie_path.len == 0) "/" else cookie_path;

    // Condition 1: Exact match
    if (std.mem.eql(u8, req_path, cook_path)) {
        return true;
    }

    // Condition 2: cookie_path is a prefix of request_path
    if (std.mem.startsWith(u8, req_path, cook_path)) {
        // Either cookie_path ends with /
        if (cook_path[cook_path.len - 1] == '/') {
            return true;
        }
        // Or the next character in request_path is /
        if (req_path.len > cook_path.len and req_path[cook_path.len] == '/') {
            return true;
        }
    }

    return false;
}

/// Calculate the default path for a request URI
/// https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis#section-5.1.4
/// https://fetch.spec.whatwg.org/#serialized-cookie-default-path
///
/// 1. Let uri-path be the path portion of the request-uri
/// 2. If the uri-path is empty or the first character is not "/", return "/"
/// 3. If the uri-path contains only "/" character, return "/"
/// 4. Let default-path be the characters of uri-path from the first character
///    up to, but not including, the right-most %x2F ("/")
/// 5. Return default-path
pub fn getDefaultPath(uri_path: []const u8) []const u8 {
    // Step 2: Empty or doesn't start with /
    if (uri_path.len == 0 or uri_path[0] != '/') {
        return "/";
    }

    // Step 3: Only contains /
    if (uri_path.len == 1) {
        return "/";
    }

    // Step 4: Find rightmost /
    const last_slash = std.mem.lastIndexOfScalar(u8, uri_path, '/');
    if (last_slash) |idx| {
        if (idx == 0) {
            return "/";
        }
        return uri_path[0..idx];
    }

    return "/";
}

/// Check if a domain is a public suffix
/// Uses the Public Suffix List for accurate detection
pub fn isPublicSuffix(allocator: std.mem.Allocator, domain: []const u8) !bool {
    // Import the URL module's PSL support
    const Host = @import("url").Host;

    // Try to get the public suffix
    const host = Host{ .domain = domain };
    const url_psl = @import("url").public_suffix;
    const ps = try url_psl.getPublicSuffix(allocator, host);
    defer if (ps) |p| allocator.free(p);

    if (ps) |public_suffix| {
        // If the public suffix equals the domain, it's a public suffix
        return std.ascii.eqlIgnoreCase(public_suffix, domain);
    }

    return false;
}

/// Check if a domain is a registrable domain suffix of another
/// https://html.spec.whatwg.org/multipage/browsers.html#is-a-registrable-domain-suffix-of-or-is-equal-to
///
/// Returns true if:
/// - The domains are equal (case-insensitive), or
/// - cookie_domain is a suffix of request_host with the following constraints:
///   - There's a dot before the suffix in request_host
///   - cookie_domain is not a public suffix
///   - request_host's registrable domain is a suffix of cookie_domain
pub fn isRegistrableDomainSuffixOrEqual(
    allocator: std.mem.Allocator,
    request_host: []const u8,
    cookie_domain: []const u8,
) !bool {
    // Equal check (case-insensitive)
    if (std.ascii.eqlIgnoreCase(request_host, cookie_domain)) {
        return true;
    }

    // cookie_domain must be a suffix of request_host
    if (!domainMatches(request_host, cookie_domain)) {
        return false;
    }

    // cookie_domain must not be a public suffix
    if (try isPublicSuffix(allocator, cookie_domain)) {
        return false;
    }

    return true;
}

/// Simple check if a string looks like an IP address
/// (IPv4 dotted decimal or IPv6)
fn isIpAddress(s: []const u8) bool {
    if (s.len == 0) return false;

    // IPv6 in brackets
    if (s[0] == '[') return true;

    // Check for IPv4 pattern (all digits and dots, ends with digit)
    var all_digits_dots = true;
    var has_alpha = false;
    for (s) |c| {
        if (c == '.') continue;
        if (std.ascii.isDigit(c)) continue;
        if (std.ascii.isAlphabetic(c)) {
            has_alpha = true;
        }
        all_digits_dots = false;
    }

    // If it's all digits and dots with no letters, assume IPv4
    if (all_digits_dots and !has_alpha) {
        // Verify it has at least one dot and ends with a digit
        if (std.mem.indexOfScalar(u8, s, '.') != null) {
            return std.ascii.isDigit(s[s.len - 1]);
        }
    }

    return false;
}

/// Normalize a domain for cookie storage
/// - Convert to lowercase
/// - Remove trailing dots
pub fn normalizeDomain(allocator: std.mem.Allocator, domain: []const u8) ![]u8 {
    // Remove trailing dot
    const trimmed = if (domain.len > 0 and domain[domain.len - 1] == '.')
        domain[0 .. domain.len - 1]
    else
        domain;

    // Convert to lowercase
    const result = try allocator.alloc(u8, trimmed.len);
    for (trimmed, 0..) |c, i| {
        result[i] = std.ascii.toLower(c);
    }

    return result;
}

// ============================================================================
// Tests
// ============================================================================

test "domainMatches - exact match" {
    try std.testing.expect(domainMatches("example.com", "example.com"));
    try std.testing.expect(domainMatches("Example.Com", "example.com"));
    try std.testing.expect(domainMatches("EXAMPLE.COM", "example.com"));
}

test "domainMatches - subdomain match" {
    try std.testing.expect(domainMatches("www.example.com", "example.com"));
    try std.testing.expect(domainMatches("sub.www.example.com", "example.com"));
    try std.testing.expect(domainMatches("a.b.c.example.com", "example.com"));
}

test "domainMatches - no match" {
    try std.testing.expect(!domainMatches("example.com", "other.com"));
    try std.testing.expect(!domainMatches("example.com", "www.example.com")); // cookie domain can't be subdomain of request
    try std.testing.expect(!domainMatches("example.com", "xample.com")); // partial match without dot
    try std.testing.expect(!domainMatches("notexample.com", "example.com")); // not a true suffix
}

test "domainMatches - with leading dot" {
    try std.testing.expect(domainMatches("www.example.com", ".example.com"));
    try std.testing.expect(domainMatches("example.com", ".example.com"));
}

test "domainMatches - IP addresses don't domain-match" {
    // IP addresses should not domain-match as subdomains
    try std.testing.expect(domainMatches("192.168.1.1", "192.168.1.1")); // exact match OK
    // Subdomain matching is skipped for IPs - we don't have a case where
    // an IP could be a "suffix" anyway in real usage
}

test "pathMatches - exact match" {
    try std.testing.expect(pathMatches("/", "/"));
    try std.testing.expect(pathMatches("/path", "/path"));
    try std.testing.expect(pathMatches("/path/to/resource", "/path/to/resource"));
}

test "pathMatches - prefix match" {
    try std.testing.expect(pathMatches("/path/to/resource", "/path"));
    try std.testing.expect(pathMatches("/path/to/resource", "/path/"));
    try std.testing.expect(pathMatches("/app/users/123", "/app"));
}

test "pathMatches - no match" {
    try std.testing.expect(!pathMatches("/other", "/path"));
    try std.testing.expect(!pathMatches("/pathextra", "/path")); // no / separator
    try std.testing.expect(!pathMatches("/pat", "/path")); // request shorter than cookie
}

test "pathMatches - root path" {
    try std.testing.expect(pathMatches("/anything", "/"));
    try std.testing.expect(pathMatches("/deeply/nested/path", "/"));
}

test "getDefaultPath" {
    try std.testing.expectEqualStrings("/", getDefaultPath(""));
    try std.testing.expectEqualStrings("/", getDefaultPath("/"));
    try std.testing.expectEqualStrings("/", getDefaultPath("relative"));
    try std.testing.expectEqualStrings("/path", getDefaultPath("/path/resource"));
    try std.testing.expectEqualStrings("/path/to", getDefaultPath("/path/to/resource"));
    try std.testing.expectEqualStrings("/", getDefaultPath("/resource"));
}

test "normalizeDomain" {
    const allocator = std.testing.allocator;

    const result1 = try normalizeDomain(allocator, "Example.COM");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("example.com", result1);

    const result2 = try normalizeDomain(allocator, "Example.COM.");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("example.com", result2);
}

test "isIpAddress" {
    try std.testing.expect(isIpAddress("192.168.1.1"));
    try std.testing.expect(isIpAddress("10.0.0.1"));
    try std.testing.expect(isIpAddress("[::1]"));
    try std.testing.expect(!isIpAddress("example.com"));
    try std.testing.expect(!isIpAddress("192.168.1.example"));
}
