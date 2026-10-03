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

/// § 6.7.2.7 Does url match source list in origin with redirect count?
///
/// Arguments:
/// - url_scheme, url_host, url_port, url_path: the URL's parts. A host of
///   "" is a URL with no host (data:, blob:); a port equal to the scheme's
///   default port is the URL's null port, as the URL Standard records it.
/// - source_list: the source list to match against
/// - self_origin: the policy's self-origin, for 'self' and schemeless
///   expressions (null: none)
/// - redirect_count: the request's redirect count (path parts are ignored
///   after a redirect)
pub fn doesUrlMatchSourceList(
    url_scheme: []const u8,
    url_host: []const u8,
    url_port: ?u16,
    url_path: []const u8,
    source_list: *const types.SourceList,
    self_origin: ?*const types.Origin,
    redirect_count: u32,
) bool {
    // 2. "If source list is empty, return "Does Not Match"."
    if (source_list.isEmpty()) return false;
    // 3. A list holding only 'none' matches nothing.
    if (source_list.isNone()) return false;
    // 4. "For each expression of source list": any match is a match.
    for (source_list.expressions.items) |*expr| {
        if (doesUrlMatchExpression(url_scheme, url_host, url_port, url_path, expr, self_origin, redirect_count)) return true;
    }
    // 5. "Return "Does Not Match"."
    return false;
}

/// § 6.7.2.8 Does url match expression in origin with redirect count?
pub fn doesUrlMatchExpression(
    url_scheme: []const u8,
    url_host: []const u8,
    url_port: ?u16,
    url_path: []const u8,
    expr: *const types.SourceExpression,
    self_origin: ?*const types.Origin,
    redirect_count: u32,
) bool {
    // The URL's port as the URL Standard records it: null for the scheme's
    // default.
    const port: ?u16 = if (url_port) |p| (if (getDefaultPort(url_scheme) == p) null else p) else null;
    switch (expr.type) {
        // 1. "*" matches an HTTP(S) URL, or a URL of origin's scheme.
        .wildcard => {
            if (std.ascii.eqlIgnoreCase(url_scheme, "http") or std.ascii.eqlIgnoreCase(url_scheme, "https")) return true;
            const origin = self_origin orelse return false;
            return std.ascii.eqlIgnoreCase(url_scheme, origin.scheme);
        },
        // 2. scheme-source: its scheme-part must scheme-part match the URL's
        // scheme, and then it matches.
        .scheme => {
            const scheme = expr.scheme_part orelse return false;
            return schemePartMatches(trimColon(scheme), url_scheme);
        },
        // 2-3. host-source.
        .host => return doesUrlMatchHostSource(url_scheme, url_host, port, url_path, expr, self_origin, redirect_count),
        // 4. 'self'.
        .keyword_self => {
            const origin = self_origin orelse return false;
            // 4.1. "If url's scheme is "blob", return "Does Not Match"."
            if (std.ascii.eqlIgnoreCase(url_scheme, "blob")) return false;
            // 4.2.1. origin and url's origin are same origin.
            const origin_port: ?u16 = if (origin.port) |p| (if (getDefaultPort(origin.scheme) == p) null else p) else null;
            if (url_host.len > 0 and std.ascii.eqlIgnoreCase(url_scheme, origin.scheme) and
                std.ascii.eqlIgnoreCase(url_host, origin.host) and port == origin_port) return true;
            // 4.2.2. Same host, ports the same or both default, and the URL
            // is https/wss, or origin is http and the URL http/ws.
            if (url_host.len == 0 or !std.ascii.eqlIgnoreCase(url_host, origin.host)) return false;
            if (port != origin_port) return false;
            if (std.ascii.eqlIgnoreCase(url_scheme, "https") or std.ascii.eqlIgnoreCase(url_scheme, "wss")) return true;
            return std.ascii.eqlIgnoreCase(origin.scheme, "http") and
                (std.ascii.eqlIgnoreCase(url_scheme, "http") or std.ascii.eqlIgnoreCase(url_scheme, "ws"));
        },
        // 5. Everything else - the other keywords, nonces, hashes, policy
        // names - matches no URL.
        else => return false,
    }
}

/// Step 3 of § 6.7.2.8, for a host-source `expr`.
fn doesUrlMatchHostSource(
    url_scheme: []const u8,
    url_host: []const u8,
    port: ?u16,
    url_path: []const u8,
    expr: *const types.SourceExpression,
    self_origin: ?*const types.Origin,
    redirect_count: u32,
) bool {
    // 2.1. A scheme-part must scheme-part match the URL's scheme.
    if (expr.scheme_part) |scheme| {
        if (!schemePartMatches(trimColon(scheme), url_scheme)) return false;
    }
    // 3.1. "If url's host is null, return "Does Not Match"."
    if (url_host.len == 0) return false;
    // 3.2. With no scheme-part, origin's scheme must scheme-part match the
    // URL's scheme.
    if (expr.scheme_part == null) {
        if (self_origin) |origin| {
            if (!schemePartMatches(origin.scheme, url_scheme)) return false;
        } else {
            // Deviation, stated: a policy whose self-origin is not known
            // (none was recorded as it was delivered) lets a schemeless
            // host-source match the HTTP(S) and WS(S) schemes, as this
            // matcher always did.
            const web = std.ascii.eqlIgnoreCase(url_scheme, "http") or std.ascii.eqlIgnoreCase(url_scheme, "https") or
                std.ascii.eqlIgnoreCase(url_scheme, "ws") or std.ascii.eqlIgnoreCase(url_scheme, "wss");
            if (!web) return false;
        }
    }
    // 3.3. The host-part must host-part match the URL's host.
    const host_part = expr.host_part orelse return false;
    if (!hostPartMatches(host_part, url_host)) return false;
    // 3.4-3.5. The port-part (null when absent) must port-part match.
    if (!portPartMatches(expr, port, url_scheme)) return false;
    // 3.6. A non-empty path-part, with redirect count 0, must path-part
    // match the URL's path.
    if (expr.path_part) |path_part| {
        if (path_part.len > 0 and redirect_count == 0 and !pathPartMatches(path_part, url_path)) return false;
    }
    // 3.7. "Return "Matches"."
    return true;
}

fn trimColon(scheme: []const u8) []const u8 {
    return if (scheme.len > 0 and scheme[scheme.len - 1] == ':') scheme[0 .. scheme.len - 1] else scheme;
}

/// § 6.7.2.9 scheme-part matching: `a` (an expression's) matches `b` (a
/// URL's) when they are equal, or `b` is the secure upgrade of `a`.
pub fn schemePartMatches(a: []const u8, b: []const u8) bool {
    if (std.ascii.eqlIgnoreCase(a, b)) return true;
    if (std.ascii.eqlIgnoreCase(a, "http") and std.ascii.eqlIgnoreCase(b, "https")) return true;
    if (std.ascii.eqlIgnoreCase(a, "ws") and (std.ascii.eqlIgnoreCase(b, "wss") or std.ascii.eqlIgnoreCase(b, "http") or std.ascii.eqlIgnoreCase(b, "https"))) return true;
    if (std.ascii.eqlIgnoreCase(a, "wss") and std.ascii.eqlIgnoreCase(b, "https")) return true;
    return false;
}

/// § 6.7.2.10 host-part matching.
fn hostPartMatches(pattern: []const u8, host: []const u8) bool {
    // 1. "If host is not a domain, return "Does Not Match"": an IP address
    // (IPv6 in brackets, or all digits and dots) is not one.
    if (host.len > 0 and host[0] == '[') return false;
    if (std.mem.indexOfNone(u8, host, "0123456789.") == null) return false;
    // 2. "*" matches any domain.
    if (std.mem.eql(u8, pattern, "*")) return true;
    // 3. "*.example.com": the host ends with ".example.com".
    if (pattern.len >= 2 and pattern[0] == '*' and pattern[1] == '.') {
        return std.ascii.endsWithIgnoreCase(host, pattern[1..]);
    }
    // 4-5. Otherwise an ASCII case-insensitive match.
    return std.ascii.eqlIgnoreCase(pattern, host);
}

/// § 6.7.2.11 port-part matching, given the URL's port (null for its
/// scheme's default) and scheme.
fn portPartMatches(expr: *const types.SourceExpression, port: ?u16, scheme: []const u8) bool {
    // 2. "If input is equal to "*", return "Matches"."
    if (expr.port_wildcard) return true;
    // 3-4. normalizedInput equal to url's port.
    const input = expr.port_part;
    if (input == port) return true;
    // 5. "If url's port is null": normalizedInput equal to the default port.
    if (port == null) {
        if (getDefaultPort(scheme)) |default_port| {
            if (input != null and input.? == default_port) return true;
        }
    }
    // 6. "Return "Does Not Match"."
    return false;
}

/// § 6.7.2.12 path-part matching.
fn pathPartMatches(path_a: []const u8, path_b: []const u8) bool {
    // 1. An empty path A matches.
    if (path_a.len == 0) return true;
    // 2. "/" matches an empty path B.
    if (std.mem.eql(u8, path_a, "/") and path_b.len == 0) return true;
    // 3. Exact match unless path A ends with "/".
    const exact_match = path_a[path_a.len - 1] != '/';
    // 4. Strictly split both on "/".
    const count_a = std.mem.count(u8, path_a, "/") + 1;
    const count_b = std.mem.count(u8, path_b, "/") + 1;
    // 5. Path list A longer than path list B: no match.
    if (count_a > count_b) return false;
    // 6. An exact match needs as many pieces.
    if (exact_match and count_a != count_b) return false;
    // 7. Otherwise the final, empty, piece of A is dropped.
    const pieces_a = if (exact_match) count_a else count_a - 1;
    // 8. Each piece of A, percent-decoded, equals B's.
    var it_a = std.mem.splitScalar(u8, path_a, '/');
    var it_b = std.mem.splitScalar(u8, path_b, '/');
    var i: usize = 0;
    while (i < pieces_a) : (i += 1) {
        const a = it_a.next() orelse return false;
        const b = it_b.next() orelse return false;
        if (!percentDecodedEql(a, b)) return false;
    }
    // 9. "Return "Matches"."
    return true;
}

/// Whether `a` and `b` percent-decode to the same bytes.
fn percentDecodedEql(a: []const u8, b: []const u8) bool {
    var ia: usize = 0;
    var ib: usize = 0;
    while (true) {
        const ca = nextDecoded(a, &ia);
        const cb = nextDecoded(b, &ib);
        if (ca == null and cb == null) return true;
        if (ca == null or cb == null or ca.? != cb.?) return false;
    }
}

fn nextDecoded(s: []const u8, i: *usize) ?u8 {
    if (i.* >= s.len) return null;
    const c = s[i.*];
    if (c == '%' and i.* + 2 < s.len) {
        const hi = std.fmt.charToDigit(s[i.* + 1], 16) catch {
            i.* += 1;
            return c;
        };
        const lo = std.fmt.charToDigit(s[i.* + 2], 16) catch {
            i.* += 1;
            return c;
        };
        i.* += 3;
        return @as(u8, hi) * 16 + lo;
    }
    i.* += 1;
    return c;
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

test "scheme-part matching: equal, or the secure upgrade of the expression's" {
    try std.testing.expect(schemePartMatches("https", "https"));
    try std.testing.expect(schemePartMatches("data", "DATA"));
    try std.testing.expect(schemePartMatches("http", "https"));
    try std.testing.expect(!schemePartMatches("https", "http"));
    try std.testing.expect(schemePartMatches("ws", "wss"));
    try std.testing.expect(schemePartMatches("ws", "https"));
    try std.testing.expect(schemePartMatches("wss", "https"));
    try std.testing.expect(!schemePartMatches("wss", "ws"));
}

fn listOf(expressions: []const types.SourceExpression) types.SourceList {
    var list = types.SourceList.init(std.testing.allocator);
    for (expressions) |e| list.append(e) catch unreachable;
    return list;
}

test "'self': same origin, or a secure upgrade on the same host and port; never blob:" {
    const origin = types.Origin.createBorrowed("http", "a.test", 8000);
    var list = listOf(&.{types.SourceExpression.createBorrowed(.keyword_self, "'self'")});
    defer list.deinit();
    try std.testing.expect(doesUrlMatchSourceList("http", "a.test", 8000, "/w.js", &list, &origin, 0));
    try std.testing.expect(doesUrlMatchSourceList("https", "a.test", 8000, "/w.js", &list, &origin, 0));
    try std.testing.expect(doesUrlMatchSourceList("ws", "a.test", 8000, "/", &list, &origin, 0));
    try std.testing.expect(!doesUrlMatchSourceList("https", "a.test", 8443, "/w.js", &list, &origin, 0));
    try std.testing.expect(!doesUrlMatchSourceList("http", "www1.a.test", 8000, "/w.js", &list, &origin, 0));
    try std.testing.expect(!doesUrlMatchSourceList("data", "", null, "text/javascript,", &list, &origin, 0));
    try std.testing.expect(!doesUrlMatchSourceList("blob", "", null, "http://a.test:8000/uuid", &list, &origin, 0));
}

test "'*' matches HTTP(S) URLs and URLs of the origin's scheme, not data:" {
    const origin = types.Origin.createBorrowed("http", "a.test", 8000);
    var list = listOf(&.{types.SourceExpression.createBorrowed(.wildcard, "*")});
    defer list.deinit();
    try std.testing.expect(doesUrlMatchSourceList("https", "b.test", 8443, "/", &list, &origin, 0));
    try std.testing.expect(!doesUrlMatchSourceList("data", "", null, "x", &list, &origin, 0));
    try std.testing.expect(!doesUrlMatchSourceList("blob", "", null, "x", &list, &origin, 0));
    try std.testing.expect(!doesUrlMatchSourceList("ws", "a.test", 8000, "/", &list, &origin, 0));
}

test "a host-source without a port matches only the scheme's default port; ':*' any" {
    const origin = types.Origin.createBorrowed("https", "a.test", null);
    var plain = types.SourceExpression.createBorrowed(.host, "b.test");
    plain.host_part = "b.test";
    var any_port = types.SourceExpression.createBorrowed(.host, "c.test:*");
    any_port.host_part = "c.test";
    any_port.port_wildcard = true;
    var list = listOf(&.{ plain, any_port });
    defer list.deinit();
    try std.testing.expect(doesUrlMatchSourceList("https", "b.test", 443, "/", &list, &origin, 0));
    try std.testing.expect(doesUrlMatchSourceList("https", "b.test", null, "/", &list, &origin, 0));
    try std.testing.expect(!doesUrlMatchSourceList("https", "b.test", 8443, "/", &list, &origin, 0));
    try std.testing.expect(doesUrlMatchSourceList("https", "c.test", 8443, "/", &list, &origin, 0));
}

test "path-part matching: a trailing slash is a prefix, otherwise exact, after percent-decoding" {
    try std.testing.expect(pathPartMatches("/scripts/", "/scripts/app.js"));
    try std.testing.expect(!pathPartMatches("/scripts/", "/other/app.js"));
    try std.testing.expect(pathPartMatches("/a.js", "/a.js"));
    try std.testing.expect(!pathPartMatches("/a.js", "/a.js/b"));
    try std.testing.expect(pathPartMatches("/a%2Ejs", "/a.js"));
    try std.testing.expect(pathPartMatches("/", ""));
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
