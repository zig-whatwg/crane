//! CSP Source Expression Matching
//!
//! W3C Content Security Policy Level 3
//! Spec: https://www.w3.org/TR/CSP3/ § 6.7
//!
//! This module implements source list and source expression matching algorithms.

const std = @import("std");
const types = @import("types.zig");

// ============================================================================
// URL Matching
// ============================================================================

/// Check if a URL matches a source list.
/// Spec: CSP Level 3 § 6.7.2.1
///
/// Arguments:
/// - url_scheme, url_host, url_port, url_path: URL components
/// - source_list: The source list to match against
/// - self_origin: Origin for 'self' matching (may be null)
/// - redirect_count: Number of redirects (affects path matching)
pub fn doesUrlMatchSourceList(
    url_scheme: []const u8,
    url_host: []const u8,
    url_port: ?u16,
    url_path: []const u8,
    source_list: *const types.SourceList,
    self_origin: ?*const types.Origin,
    redirect_count: u32,
) bool {
    // If source list is empty, nothing matches
    if (source_list.isEmpty()) {
        return false;
    }

    // Check for 'none' - nothing matches 'none'
    if (source_list.isNone()) {
        return false;
    }

    // Check each expression
    for (source_list.expressions.items) |*expr| {
        if (doesUrlMatchExpression(
            url_scheme,
            url_host,
            url_port,
            url_path,
            expr,
            self_origin,
            redirect_count,
        )) {
            return true;
        }
    }

    return false;
}

/// Check if a URL matches a single source expression.
/// Spec: CSP Level 3 § 6.7.2.8
pub fn doesUrlMatchExpression(
    url_scheme: []const u8,
    url_host: []const u8,
    url_port: ?u16,
    url_path: []const u8,
    expr: *const types.SourceExpression,
    self_origin: ?*const types.Origin,
    redirect_count: u32,
) bool {
    switch (expr.type) {
        .keyword_none => return false,

        .keyword_self => {
            if (self_origin) |origin| {
                return doesUrlMatchOrigin(url_scheme, url_host, url_port, origin);
            }
            return false;
        },

        .scheme => {
            if (expr.scheme_part) |scheme| {
                return doesSchemeMatch(url_scheme, scheme);
            }
            return false;
        },

        .host => {
            return doesUrlMatchHost(
                url_scheme,
                url_host,
                url_port,
                url_path,
                expr,
                self_origin,
                redirect_count,
            );
        },

        .wildcard => {
            // Wildcard (*) matches any URL
            return true;
        },

        // Keywords that don't match URLs - they're checked separately
        .keyword_unsafe_inline,
        .keyword_unsafe_eval,
        .keyword_unsafe_hashes,
        .keyword_strict_dynamic,
        .keyword_wasm_unsafe_eval,
        .keyword_report_sample,
        .keyword_trusted_types_eval,
        .keyword_allow_duplicates,
        => return false,

        // Nonce and hash are checked separately for inline content
        .nonce, .hash => return false,

        // Policy names are for trusted-types directive, not URL matching
        .policy_name => return false,
    }
}

/// Check if URL's scheme matches scheme source.
/// Spec: CSP Level 3 § 6.7.2.3
fn doesSchemeMatch(url_scheme: []const u8, scheme_expr: []const u8) bool {
    // Remove trailing : from scheme expression if present
    const expr_scheme = if (scheme_expr.len > 0 and scheme_expr[scheme_expr.len - 1] == ':')
        scheme_expr[0 .. scheme_expr.len - 1]
    else
        scheme_expr;

    // Case-insensitive comparison
    if (std.ascii.eqlIgnoreCase(url_scheme, expr_scheme)) {
        return true;
    }

    // http: also matches https: (scheme upgrade)
    if (std.ascii.eqlIgnoreCase(expr_scheme, "http") and
        std.ascii.eqlIgnoreCase(url_scheme, "https"))
    {
        return true;
    }

    // ws: also matches wss: (scheme upgrade)
    if (std.ascii.eqlIgnoreCase(expr_scheme, "ws") and
        std.ascii.eqlIgnoreCase(url_scheme, "wss"))
    {
        return true;
    }

    return false;
}

/// Check if URL matches 'self' (same origin).
fn doesUrlMatchOrigin(
    url_scheme: []const u8,
    url_host: []const u8,
    url_port: ?u16,
    origin: *const types.Origin,
) bool {
    // Compare scheme (case-insensitive)
    if (!std.ascii.eqlIgnoreCase(url_scheme, origin.scheme)) {
        return false;
    }

    // Compare host (case-insensitive)
    if (!std.ascii.eqlIgnoreCase(url_host, origin.host)) {
        return false;
    }

    // Port comparison (consider default ports)
    const url_effective_port = url_port orelse getDefaultPort(url_scheme);
    const origin_effective_port = origin.port orelse getDefaultPort(origin.scheme);

    return url_effective_port == origin_effective_port;
}

/// Check if URL matches a host source expression.
/// Spec: CSP Level 3 § 6.7.2.5-6.7.2.8
fn doesUrlMatchHost(
    url_scheme: []const u8,
    url_host: []const u8,
    url_port: ?u16,
    url_path: []const u8,
    expr: *const types.SourceExpression,
    self_origin: ?*const types.Origin,
    redirect_count: u32,
) bool {
    // If expression has scheme, it must match
    if (expr.scheme_part) |scheme| {
        if (!doesSchemeMatch(url_scheme, scheme)) {
            return false;
        }
    } else {
        // No scheme in expression - use default rules
        // http: and https: are acceptable, ws: and wss: are acceptable
        if (!std.ascii.eqlIgnoreCase(url_scheme, "http") and
            !std.ascii.eqlIgnoreCase(url_scheme, "https") and
            !std.ascii.eqlIgnoreCase(url_scheme, "ws") and
            !std.ascii.eqlIgnoreCase(url_scheme, "wss"))
        {
            // For other schemes, must match self-origin scheme
            if (self_origin) |origin| {
                if (!std.ascii.eqlIgnoreCase(url_scheme, origin.scheme)) {
                    return false;
                }
            } else {
                return false;
            }
        }
    }

    // Host matching
    if (expr.host_part) |host_expr| {
        // Wildcard host (*.example.com)
        if (host_expr.len > 2 and host_expr[0] == '*' and host_expr[1] == '.') {
            const suffix = host_expr[1..]; // .example.com

            if (!std.ascii.endsWithIgnoreCase(url_host, suffix)) {
                return false;
            }

            // Ensure it's a subdomain, not just suffix match
            // url_host must be longer than suffix (minus the dot)
            if (url_host.len <= suffix.len - 1) {
                return false;
            }
        } else {
            // Exact host match (case-insensitive)
            if (!std.ascii.eqlIgnoreCase(url_host, host_expr)) {
                return false;
            }
        }
    }

    // Port matching
    if (expr.port_part) |expr_port| {
        const url_effective_port = url_port orelse getDefaultPort(url_scheme);
        if (url_effective_port != expr_port) {
            return false;
        }
    }

    // Path matching
    // Per spec: if redirect_count > 0, path matching is relaxed
    if (expr.path_part) |path_expr| {
        if (redirect_count == 0) {
            // Exact path prefix matching
            if (!std.mem.startsWith(u8, url_path, path_expr)) {
                return false;
            }
        }
        // If redirect_count > 0, path matching is skipped
    }

    return true;
}

// ============================================================================
// Nonce and Hash Matching
// ============================================================================

/// Check if nonce matches any nonce in source list.
/// Spec: CSP Level 3 § 6.7.2.2
pub fn doesNonceMatch(
    nonce: []const u8,
    source_list: *const types.SourceList,
) bool {
    for (source_list.expressions.items) |expr| {
        if (expr.type == .nonce) {
            if (expr.nonce_value) |expr_nonce| {
                if (std.mem.eql(u8, nonce, expr_nonce)) {
                    return true;
                }
            }
        }
    }
    return false;
}

/// Check if hash matches any hash in source list.
/// Spec: CSP Level 3 § 6.7.2.4
pub fn doesHashMatch(
    hash_algorithm: []const u8,
    hash_value: []const u8,
    source_list: *const types.SourceList,
) bool {
    for (source_list.expressions.items) |expr| {
        if (expr.type == .hash) {
            if (expr.hash_algorithm) |algo| {
                if (expr.hash_value) |value| {
                    if (std.ascii.eqlIgnoreCase(algo, hash_algorithm) and
                        std.mem.eql(u8, value, hash_value))
                    {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

// ============================================================================
// Keyword Checking
// ============================================================================

/// Check if source list allows 'unsafe-inline'.
pub fn allowsUnsafeInline(source_list: *const types.SourceList) bool {
    return source_list.contains(.keyword_unsafe_inline);
}

/// Check if source list allows 'unsafe-eval'.
pub fn allowsUnsafeEval(source_list: *const types.SourceList) bool {
    return source_list.contains(.keyword_unsafe_eval);
}

/// Check if source list has 'strict-dynamic'.
pub fn hasStrictDynamic(source_list: *const types.SourceList) bool {
    return source_list.contains(.keyword_strict_dynamic);
}

/// Check if source list allows 'wasm-unsafe-eval'.
pub fn allowsWasmUnsafeEval(source_list: *const types.SourceList) bool {
    return source_list.contains(.keyword_wasm_unsafe_eval);
}

/// Check if source list has 'trusted-types-eval'.
/// This delegates eval() handling to Trusted Types.
pub fn hasTrustedTypesEval(source_list: *const types.SourceList) bool {
    return source_list.contains(.keyword_trusted_types_eval);
}

// ============================================================================
// Utility Functions
// ============================================================================

/// Get default port for scheme.
/// Spec: URL Standard § 4.2
pub fn getDefaultPort(scheme: []const u8) ?u16 {
    if (std.ascii.eqlIgnoreCase(scheme, "http") or
        std.ascii.eqlIgnoreCase(scheme, "ws"))
    {
        return 80;
    }
    if (std.ascii.eqlIgnoreCase(scheme, "https") or
        std.ascii.eqlIgnoreCase(scheme, "wss"))
    {
        return 443;
    }
    if (std.ascii.eqlIgnoreCase(scheme, "ftp")) {
        return 21;
    }
    return null;
}

// ============================================================================
// Tests
// ============================================================================

test "doesSchemeMatch - exact match" {
    try std.testing.expect(doesSchemeMatch("https", "https:"));
    try std.testing.expect(doesSchemeMatch("http", "http:"));
    try std.testing.expect(doesSchemeMatch("data", "data:"));
}

test "doesSchemeMatch - scheme upgrade" {
    // http: matches https:
    try std.testing.expect(doesSchemeMatch("https", "http:"));
    try std.testing.expect(!doesSchemeMatch("http", "https:"));

    // ws: matches wss:
    try std.testing.expect(doesSchemeMatch("wss", "ws:"));
    try std.testing.expect(!doesSchemeMatch("ws", "wss:"));
}

test "doesSchemeMatch - case insensitive" {
    try std.testing.expect(doesSchemeMatch("HTTPS", "https:"));
    try std.testing.expect(doesSchemeMatch("https", "HTTPS:"));
}

test "doesUrlMatchOrigin - same origin" {
    const origin = types.Origin.createBorrowed("https", "example.com", 443);

    try std.testing.expect(doesUrlMatchOrigin("https", "example.com", 443, &origin));
    try std.testing.expect(doesUrlMatchOrigin("https", "example.com", null, &origin)); // default port
}

test "doesUrlMatchOrigin - different origin" {
    const origin = types.Origin.createBorrowed("https", "example.com", 443);

    try std.testing.expect(!doesUrlMatchOrigin("http", "example.com", 80, &origin)); // wrong scheme
    try std.testing.expect(!doesUrlMatchOrigin("https", "other.com", 443, &origin)); // wrong host
    try std.testing.expect(!doesUrlMatchOrigin("https", "example.com", 8080, &origin)); // wrong port
}

test "doesNonceMatch" {
    const allocator = std.testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();

    var expr = try types.SourceExpression.create(allocator, .nonce, "'nonce-abc123'");
    expr.nonce_value = try allocator.dupe(u8, "abc123");
    try list.append(expr);

    try std.testing.expect(doesNonceMatch("abc123", &list));
    try std.testing.expect(!doesNonceMatch("xyz789", &list));
}

test "doesHashMatch" {
    const allocator = std.testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();

    var expr = try types.SourceExpression.create(allocator, .hash, "'sha256-abc'");
    expr.hash_algorithm = try allocator.dupe(u8, "sha256");
    expr.hash_value = try allocator.dupe(u8, "abcdef");
    try list.append(expr);

    try std.testing.expect(doesHashMatch("sha256", "abcdef", &list));
    try std.testing.expect(!doesHashMatch("sha256", "xyz", &list));
    try std.testing.expect(!doesHashMatch("sha384", "abcdef", &list));
}

test "getDefaultPort" {
    try std.testing.expectEqual(@as(?u16, 80), getDefaultPort("http"));
    try std.testing.expectEqual(@as(?u16, 443), getDefaultPort("https"));
    try std.testing.expectEqual(@as(?u16, 80), getDefaultPort("ws"));
    try std.testing.expectEqual(@as(?u16, 443), getDefaultPort("wss"));
    try std.testing.expectEqual(@as(?u16, 21), getDefaultPort("ftp"));
    try std.testing.expectEqual(@as(?u16, null), getDefaultPort("custom"));
}
