//! CSP Parsing Algorithms
//!
//! W3C Content Security Policy Level 3
//! Spec: https://www.w3.org/TR/CSP3/
//!
//! This module implements:
//! - parseSerializedCSP: Parse a CSP header string into a Policy
//! - parseSourceExpression: Parse individual source expressions

const std = @import("std");
const types = @import("types.zig");

// ============================================================================
// Parse Serialized CSP
// ============================================================================

/// Parse a serialized CSP string into a Policy object.
/// Spec: CSP Level 3 § 2.2.1
///
/// Algorithm:
/// 1. If serialized is a byte sequence, isomorphic decode it
/// 2. Let policy be a new policy with empty directive set
/// 3. For each token from strictly splitting on ';':
///    a. Strip leading/trailing whitespace
///    b. If empty or non-ASCII, continue
///    c. Let directive name be first token before whitespace
///    d. Lowercase directive name
///    e. If directive name already in policy, continue (first wins)
///    f. Let directive value be remaining tokens split on whitespace
///    g. Append new directive to policy's directive set
/// 4. Return policy
pub fn parseSerializedCSP(
    allocator: std.mem.Allocator,
    serialized: []const u8,
    source: types.PolicySource,
    disposition: types.PolicyDisposition,
) !types.Policy {
    var policy = types.Policy.init(allocator, disposition, source);
    errdefer policy.deinit();

    // Split on semicolon
    var directive_tokens = std.mem.splitScalar(u8, serialized, ';');

    while (directive_tokens.next()) |token| {
        // Strip leading and trailing whitespace
        const trimmed = std.mem.trim(u8, token, &std.ascii.whitespace);

        if (trimmed.len == 0) continue;

        // Check if ASCII (non-ASCII tokens are skipped per spec)
        if (!isAscii(trimmed)) continue;

        // Extract directive name (first non-whitespace sequence)
        var name_end: usize = 0;
        while (name_end < trimmed.len and !std.ascii.isWhitespace(trimmed[name_end])) {
            name_end += 1;
        }

        if (name_end == 0) continue;

        // Lowercase directive name
        const directive_name_buf = try allocator.alloc(u8, name_end);
        defer allocator.free(directive_name_buf);
        _ = std.ascii.lowerString(directive_name_buf, trimmed[0..name_end]);

        // Skip if duplicate (first directive wins)
        // Per spec § 2.2.1 step 3.e
        if (policy.directive_set.containsDirective(directive_name_buf)) {
            // Note: Per spec, should notify developer about duplicate
            continue;
        }

        // Create directive with lowercased name
        var directive = try types.Directive.create(allocator, directive_name_buf);
        errdefer directive.deinit();

        // Parse directive value (split remaining on whitespace)
        if (name_end < trimmed.len) {
            const value_part = std.mem.trim(u8, trimmed[name_end..], &std.ascii.whitespace);

            var value_tokens = std.mem.tokenizeAny(u8, value_part, &std.ascii.whitespace);
            while (value_tokens.next()) |value_token| {
                const expr = try parseSourceExpression(allocator, value_token);
                try directive.value.append(expr);
            }
        }

        // Append directive to policy
        try policy.directive_set.append(directive);
    }

    return policy;
}

// ============================================================================
// Parse Source Expression
// ============================================================================

/// Parse a source expression token into a SourceExpression.
/// Spec: CSP Level 3 § 6.7
pub fn parseSourceExpression(
    allocator: std.mem.Allocator,
    token: []const u8,
) !types.SourceExpression {
    // Check for keywords (case-insensitive, enclosed in single quotes)
    if (token.len >= 2 and token[0] == '\'' and token[token.len - 1] == '\'') {
        const inner = token[1 .. token.len - 1];

        // Check known keywords (case-insensitive)
        if (std.ascii.eqlIgnoreCase(inner, "none")) {
            return types.SourceExpression.create(allocator, .keyword_none, token);
        }
        if (std.ascii.eqlIgnoreCase(inner, "self")) {
            return types.SourceExpression.create(allocator, .keyword_self, token);
        }
        if (std.ascii.eqlIgnoreCase(inner, "unsafe-inline")) {
            return types.SourceExpression.create(allocator, .keyword_unsafe_inline, token);
        }
        if (std.ascii.eqlIgnoreCase(inner, "unsafe-eval")) {
            return types.SourceExpression.create(allocator, .keyword_unsafe_eval, token);
        }
        if (std.ascii.eqlIgnoreCase(inner, "unsafe-hashes")) {
            return types.SourceExpression.create(allocator, .keyword_unsafe_hashes, token);
        }
        if (std.ascii.eqlIgnoreCase(inner, "strict-dynamic")) {
            return types.SourceExpression.create(allocator, .keyword_strict_dynamic, token);
        }
        if (std.ascii.eqlIgnoreCase(inner, "wasm-unsafe-eval")) {
            return types.SourceExpression.create(allocator, .keyword_wasm_unsafe_eval, token);
        }
        if (std.ascii.eqlIgnoreCase(inner, "report-sample")) {
            return types.SourceExpression.create(allocator, .keyword_report_sample, token);
        }
        if (std.ascii.eqlIgnoreCase(inner, "trusted-types-eval")) {
            return types.SourceExpression.create(allocator, .keyword_trusted_types_eval, token);
        }
        if (std.ascii.eqlIgnoreCase(inner, "allow-duplicates")) {
            return types.SourceExpression.create(allocator, .keyword_allow_duplicates, token);
        }

        // Check for nonce ('nonce-xxx')
        if (inner.len > 6 and std.ascii.startsWithIgnoreCase(inner, "nonce-")) {
            var expr = try types.SourceExpression.create(allocator, .nonce, token);
            expr.nonce_value = try allocator.dupe(u8, inner[6..]);
            return expr;
        }

        // Check for hash ('sha256-xxx', 'sha384-xxx', 'sha512-xxx')
        if (inner.len > 7) {
            if (std.ascii.startsWithIgnoreCase(inner, "sha256-")) {
                var expr = try types.SourceExpression.create(allocator, .hash, token);
                expr.hash_algorithm = try allocator.dupe(u8, "sha256");
                expr.hash_value = try allocator.dupe(u8, inner[7..]);
                return expr;
            }
            if (std.ascii.startsWithIgnoreCase(inner, "sha384-")) {
                var expr = try types.SourceExpression.create(allocator, .hash, token);
                expr.hash_algorithm = try allocator.dupe(u8, "sha384");
                expr.hash_value = try allocator.dupe(u8, inner[7..]);
                return expr;
            }
            if (std.ascii.startsWithIgnoreCase(inner, "sha512-")) {
                var expr = try types.SourceExpression.create(allocator, .hash, token);
                expr.hash_algorithm = try allocator.dupe(u8, "sha512");
                expr.hash_value = try allocator.dupe(u8, inner[7..]);
                return expr;
            }
        }

        // Unknown quoted value - treat as policy name (for trusted-types directive)
        return types.SourceExpression.create(allocator, .policy_name, token);
    }

    // Check for wildcard (*)
    if (std.mem.eql(u8, token, "*")) {
        return types.SourceExpression.create(allocator, .wildcard, token);
    }

    // Check for scheme source (ends with : but no /)
    // Examples: https:, data:, blob:
    if (std.mem.indexOf(u8, token, ":") != null) {
        const colon_pos = std.mem.indexOf(u8, token, ":").?;

        // If there's a :// it's a host, not a scheme
        if (colon_pos + 2 < token.len and
            token[colon_pos + 1] == '/' and
            token[colon_pos + 2] == '/')
        {
            // Host source with scheme (https://example.com)
            return try parseHostSource(allocator, token);
        }

        // If it's just scheme: (no path), it's a scheme source
        if (colon_pos == token.len - 1 or
            (colon_pos + 1 < token.len and token[colon_pos + 1] != '/'))
        {
            var expr = try types.SourceExpression.create(allocator, .scheme, token);
            expr.scheme_part = try allocator.dupe(u8, token[0 .. colon_pos + 1]);
            return expr;
        }
    }

    // Default: treat as host source
    return try parseHostSource(allocator, token);
}

/// Parse a host source expression.
/// Examples: example.com, *.example.com, https://example.com:443/path
fn parseHostSource(allocator: std.mem.Allocator, token: []const u8) !types.SourceExpression {
    var expr = try types.SourceExpression.create(allocator, .host, token);
    errdefer expr.deinit();

    var remaining = token;

    // Check for scheme
    if (std.mem.indexOf(u8, remaining, "://")) |scheme_end| {
        expr.scheme_part = try allocator.dupe(u8, remaining[0..scheme_end]);
        remaining = remaining[scheme_end + 3 ..];
    }

    // Check for port (look for : after host)
    // Also need to handle path
    var host_end = remaining.len;
    var port_start: ?usize = null;
    var path_start: ?usize = null;

    for (remaining, 0..) |c, i| {
        if (c == ':' and port_start == null and path_start == null) {
            host_end = i;
            port_start = i + 1;
        } else if (c == '/') {
            if (port_start == null) {
                host_end = i;
            }
            path_start = i;
            break;
        }
    }

    // Extract host
    if (host_end > 0) {
        expr.host_part = try allocator.dupe(u8, remaining[0..host_end]);
    }

    // Extract port
    if (port_start) |ps| {
        const port_end = path_start orelse remaining.len;
        if (port_end > ps) {
            const port_str = remaining[ps..port_end];
            if (std.mem.eql(u8, port_str, "*")) {
                // Wildcard port - matches any port
                expr.port_part = null; // null means any port
            } else {
                expr.port_part = std.fmt.parseInt(u16, port_str, 10) catch null;
            }
        }
    }

    // Extract path
    if (path_start) |ps| {
        expr.path_part = try allocator.dupe(u8, remaining[ps..]);
    }

    return expr;
}

/// Check if string contains only ASCII characters.
fn isAscii(str: []const u8) bool {
    for (str) |c| {
        if (c > 127) return false;
    }
    return true;
}

// ============================================================================
// Tests
// ============================================================================

test "parseSerializedCSP - single directive" {
    const allocator = std.testing.allocator;

    var policy = try parseSerializedCSP(
        allocator,
        "default-src 'self'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    try std.testing.expect(policy.containsDirective("default-src"));
    try std.testing.expectEqual(types.PolicyDisposition.enforce, policy.disposition);
    try std.testing.expectEqual(types.PolicySource.header, policy.source);

    const directive = policy.getDirective("default-src").?;
    try std.testing.expect(directive.value.contains(.keyword_self));
}

test "parseSerializedCSP - multiple directives" {
    const allocator = std.testing.allocator;

    var policy = try parseSerializedCSP(
        allocator,
        "default-src 'self'; script-src https:; style-src 'unsafe-inline'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    try std.testing.expect(policy.containsDirective("default-src"));
    try std.testing.expect(policy.containsDirective("script-src"));
    try std.testing.expect(policy.containsDirective("style-src"));

    const script_src = policy.getDirective("script-src").?;
    try std.testing.expect(script_src.value.contains(.scheme));

    const style_src = policy.getDirective("style-src").?;
    try std.testing.expect(style_src.value.contains(.keyword_unsafe_inline));
}

test "parseSerializedCSP - duplicate directive first wins" {
    const allocator = std.testing.allocator;

    var policy = try parseSerializedCSP(
        allocator,
        "script-src 'self'; script-src https:",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("script-src").?;
    try std.testing.expect(directive.value.contains(.keyword_self));
    try std.testing.expect(!directive.value.contains(.scheme));
}

test "parseSerializedCSP - case insensitive directive names" {
    const allocator = std.testing.allocator;

    var policy = try parseSerializedCSP(
        allocator,
        "Script-Src 'self'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    try std.testing.expect(policy.containsDirective("script-src"));
}

test "parseSerializedCSP - trusted-types directive" {
    const allocator = std.testing.allocator;

    var policy = try parseSerializedCSP(
        allocator,
        "trusted-types foo bar 'allow-duplicates'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    try std.testing.expect(policy.containsDirective("trusted-types"));

    const directive = policy.getDirective("trusted-types").?;
    try std.testing.expectEqual(@as(usize, 3), directive.value.expressions.items.len);
    try std.testing.expect(directive.value.contains(.keyword_allow_duplicates));
}

test "parseSerializedCSP - require-trusted-types-for directive" {
    const allocator = std.testing.allocator;

    var policy = try parseSerializedCSP(
        allocator,
        "require-trusted-types-for 'script'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    try std.testing.expect(policy.containsDirective("require-trusted-types-for"));
}

test "parseSourceExpression - keywords" {
    const allocator = std.testing.allocator;

    var none = try parseSourceExpression(allocator, "'none'");
    defer none.deinit();
    try std.testing.expectEqual(types.SourceExpressionType.keyword_none, none.type);

    var self_expr = try parseSourceExpression(allocator, "'self'");
    defer self_expr.deinit();
    try std.testing.expectEqual(types.SourceExpressionType.keyword_self, self_expr.type);

    var unsafe_inline = try parseSourceExpression(allocator, "'unsafe-inline'");
    defer unsafe_inline.deinit();
    try std.testing.expectEqual(types.SourceExpressionType.keyword_unsafe_inline, unsafe_inline.type);

    var unsafe_eval = try parseSourceExpression(allocator, "'unsafe-eval'");
    defer unsafe_eval.deinit();
    try std.testing.expectEqual(types.SourceExpressionType.keyword_unsafe_eval, unsafe_eval.type);
}

test "parseSourceExpression - nonce" {
    const allocator = std.testing.allocator;

    var expr = try parseSourceExpression(allocator, "'nonce-abc123xyz'");
    defer expr.deinit();

    try std.testing.expectEqual(types.SourceExpressionType.nonce, expr.type);
    try std.testing.expectEqualStrings("abc123xyz", expr.nonce_value.?);
}

test "parseSourceExpression - hash" {
    const allocator = std.testing.allocator;

    var sha256 = try parseSourceExpression(allocator, "'sha256-abcdef123456'");
    defer sha256.deinit();

    try std.testing.expectEqual(types.SourceExpressionType.hash, sha256.type);
    try std.testing.expectEqualStrings("sha256", sha256.hash_algorithm.?);
    try std.testing.expectEqualStrings("abcdef123456", sha256.hash_value.?);

    var sha384 = try parseSourceExpression(allocator, "'sha384-xyz789'");
    defer sha384.deinit();
    try std.testing.expectEqualStrings("sha384", sha384.hash_algorithm.?);
}

test "parseSourceExpression - scheme" {
    const allocator = std.testing.allocator;

    var https = try parseSourceExpression(allocator, "https:");
    defer https.deinit();

    try std.testing.expectEqual(types.SourceExpressionType.scheme, https.type);
    try std.testing.expectEqualStrings("https:", https.scheme_part.?);

    var data = try parseSourceExpression(allocator, "data:");
    defer data.deinit();
    try std.testing.expectEqual(types.SourceExpressionType.scheme, data.type);
}

test "parseSourceExpression - host" {
    const allocator = std.testing.allocator;

    var simple = try parseSourceExpression(allocator, "example.com");
    defer simple.deinit();

    try std.testing.expectEqual(types.SourceExpressionType.host, simple.type);
    try std.testing.expectEqualStrings("example.com", simple.host_part.?);

    var wildcard = try parseSourceExpression(allocator, "*.example.com");
    defer wildcard.deinit();
    try std.testing.expectEqualStrings("*.example.com", wildcard.host_part.?);

    var with_scheme = try parseSourceExpression(allocator, "https://example.com");
    defer with_scheme.deinit();
    try std.testing.expectEqualStrings("https", with_scheme.scheme_part.?);
    try std.testing.expectEqualStrings("example.com", with_scheme.host_part.?);
}

test "parseSourceExpression - wildcard" {
    const allocator = std.testing.allocator;

    var expr = try parseSourceExpression(allocator, "*");
    defer expr.deinit();

    try std.testing.expectEqual(types.SourceExpressionType.wildcard, expr.type);
}
