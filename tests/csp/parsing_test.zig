//! CSP Parsing Unit Tests
//!
//! Tests for CSP header parsing algorithms.

const std = @import("std");
const testing = std.testing;
const csp = @import("csp");
const types = csp.types;
const parsing = csp.parsing;

// ============================================================================
// parseSerializedCSP Tests
// ============================================================================

test "parse empty CSP" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(allocator, "", .header, .enforce);
    defer policy.deinit();

    try testing.expect(policy.directive_set.isEmpty());
    try testing.expectEqual(types.PolicyDisposition.enforce, policy.disposition);
    try testing.expectEqual(types.PolicySource.header, policy.source);
}

test "parse single directive" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src 'self'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    try testing.expect(policy.containsDirective("script-src"));
    try testing.expectEqual(@as(usize, 1), policy.directive_set.count());

    const directive = policy.getDirective("script-src").?;
    try testing.expectEqual(@as(usize, 1), directive.value.expressions.items.len);
    try testing.expect(directive.value.contains(.keyword_self));
}

test "parse multiple directives" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "default-src 'self'; script-src https:; style-src 'unsafe-inline'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    try testing.expectEqual(@as(usize, 3), policy.directive_set.count());
    try testing.expect(policy.containsDirective("default-src"));
    try testing.expect(policy.containsDirective("script-src"));
    try testing.expect(policy.containsDirective("style-src"));

    const default_src = policy.getDirective("default-src").?;
    try testing.expect(default_src.value.contains(.keyword_self));

    const script_src = policy.getDirective("script-src").?;
    try testing.expect(script_src.value.contains(.scheme));

    const style_src = policy.getDirective("style-src").?;
    try testing.expect(style_src.value.contains(.keyword_unsafe_inline));
}

test "parse with semicolon separators and whitespace" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "  script-src   'self'  ;   style-src   'none'  ",
        .header,
        .enforce,
    );
    defer policy.deinit();

    try testing.expect(policy.containsDirective("script-src"));
    try testing.expect(policy.containsDirective("style-src"));
}

test "directive names are case-insensitive" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "SCRIPT-SRC 'self'; Script-Src https:",
        .header,
        .enforce,
    );
    defer policy.deinit();

    // Should lowercase directive name
    try testing.expect(policy.containsDirective("script-src"));
    try testing.expect(!policy.containsDirective("SCRIPT-SRC"));

    // Only one directive (first wins, case-insensitive)
    try testing.expectEqual(@as(usize, 1), policy.directive_set.count());
}

test "duplicate directive handling - first wins" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src 'self'; script-src https://evil.com",
        .header,
        .enforce,
    );
    defer policy.deinit();

    try testing.expectEqual(@as(usize, 1), policy.directive_set.count());

    const directive = policy.getDirective("script-src").?;
    // Should have 'self' from first directive, not https: from second
    try testing.expect(directive.value.contains(.keyword_self));
    try testing.expect(!directive.value.contains(.scheme));
}

// ============================================================================
// Keyword Parsing Tests
// ============================================================================

test "parse keyword 'none'" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src 'none'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("script-src").?;
    try testing.expect(directive.value.contains(.keyword_none));
    try testing.expect(directive.value.isNone());
}

test "parse keyword 'self'" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src 'self'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("script-src").?;
    try testing.expect(directive.value.contains(.keyword_self));
}

test "parse keyword 'unsafe-eval'" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src 'unsafe-eval'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("script-src").?;
    try testing.expect(directive.value.contains(.keyword_unsafe_eval));
}

test "parse keyword 'unsafe-inline'" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src 'unsafe-inline'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("script-src").?;
    try testing.expect(directive.value.contains(.keyword_unsafe_inline));
}

test "parse keyword 'strict-dynamic'" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src 'strict-dynamic'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("script-src").?;
    try testing.expect(directive.value.contains(.keyword_strict_dynamic));
}

test "parse keyword 'wasm-unsafe-eval'" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src 'wasm-unsafe-eval'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("script-src").?;
    try testing.expect(directive.value.contains(.keyword_wasm_unsafe_eval));
}

test "parse keyword 'trusted-types-eval'" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src 'trusted-types-eval'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("script-src").?;
    try testing.expect(directive.value.contains(.keyword_trusted_types_eval));
}

// ============================================================================
// Nonce Parsing Tests
// ============================================================================

test "parse nonce" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src 'nonce-abc123xyz'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("script-src").?;
    try testing.expect(directive.value.contains(.nonce));

    const expr = directive.value.expressions.items[0];
    try testing.expectEqual(types.SourceExpressionType.nonce, expr.type);
    try testing.expectEqualStrings("abc123xyz", expr.nonce_value.?);
}

test "parse nonce case-insensitive prefix" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src 'NONCE-ABC123'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("script-src").?;
    try testing.expect(directive.value.contains(.nonce));
}

// ============================================================================
// Hash Parsing Tests
// ============================================================================

test "parse sha256 hash" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src 'sha256-abcdef123456'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("script-src").?;
    try testing.expect(directive.value.contains(.hash));

    const expr = directive.value.expressions.items[0];
    try testing.expectEqualStrings("sha256", expr.hash_algorithm.?);
    try testing.expectEqualStrings("abcdef123456", expr.hash_value.?);
}

test "parse sha384 hash" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src 'sha384-xyz789'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("script-src").?;
    try testing.expect(directive.value.contains(.hash));

    const expr = directive.value.expressions.items[0];
    try testing.expectEqualStrings("sha384", expr.hash_algorithm.?);
}

test "parse sha512 hash" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src 'sha512-verylonghash'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("script-src").?;
    try testing.expect(directive.value.contains(.hash));

    const expr = directive.value.expressions.items[0];
    try testing.expectEqualStrings("sha512", expr.hash_algorithm.?);
}

// ============================================================================
// Scheme Source Parsing Tests
// ============================================================================

test "parse scheme source https:" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src https:",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("script-src").?;
    try testing.expect(directive.value.contains(.scheme));

    const expr = directive.value.expressions.items[0];
    try testing.expectEqualStrings("https:", expr.scheme_part.?);
}

test "parse scheme source data:" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "img-src data:",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("img-src").?;
    try testing.expect(directive.value.contains(.scheme));
}

test "parse scheme source blob:" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "worker-src blob:",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("worker-src").?;
    try testing.expect(directive.value.contains(.scheme));
}

// ============================================================================
// Host Source Parsing Tests
// ============================================================================

test "parse simple host" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src example.com",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("script-src").?;
    try testing.expect(directive.value.contains(.host));

    const expr = directive.value.expressions.items[0];
    try testing.expectEqualStrings("example.com", expr.host_part.?);
}

test "parse wildcard host" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src *.example.com",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("script-src").?;
    try testing.expect(directive.value.contains(.host));

    const expr = directive.value.expressions.items[0];
    try testing.expectEqualStrings("*.example.com", expr.host_part.?);
}

test "parse host with scheme" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src https://example.com",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("script-src").?;
    try testing.expect(directive.value.contains(.host));

    const expr = directive.value.expressions.items[0];
    try testing.expectEqualStrings("https", expr.scheme_part.?);
    try testing.expectEqualStrings("example.com", expr.host_part.?);
}

test "parse host with scheme and port" {
    const allocator = testing.allocator;

    // Note: Host with port but no scheme (e.g., "example.com:8080") is currently
    // parsed as a scheme source due to the colon. This is a known limitation.
    // Use explicit scheme for hosts with ports: "https://example.com:8080"
    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src https://example.com:8080",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("script-src").?;
    const expr = directive.value.expressions.items[0];

    try testing.expectEqualStrings("https", expr.scheme_part.?);
    try testing.expectEqualStrings("example.com", expr.host_part.?);
    try testing.expectEqual(@as(?u16, 8080), expr.port_part);
}

test "parse host with path" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src https://cdn.example.com/scripts/",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("script-src").?;
    const expr = directive.value.expressions.items[0];

    try testing.expectEqualStrings("https", expr.scheme_part.?);
    try testing.expectEqualStrings("cdn.example.com", expr.host_part.?);
    try testing.expectEqualStrings("/scripts/", expr.path_part.?);
}

// ============================================================================
// Wildcard Parsing Tests
// ============================================================================

test "parse wildcard *" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "trusted-types *",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("trusted-types").?;
    try testing.expect(directive.value.contains(.wildcard));
}

// ============================================================================
// Trusted Types Directive Parsing Tests
// ============================================================================

test "parse trusted-types with policy names" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "trusted-types foo bar baz",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("trusted-types").?;
    try testing.expectEqual(@as(usize, 3), directive.value.expressions.items.len);
}

test "parse trusted-types with 'allow-duplicates'" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "trusted-types foo 'allow-duplicates'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    const directive = policy.getDirective("trusted-types").?;
    try testing.expect(directive.value.contains(.keyword_allow_duplicates));
}

test "parse require-trusted-types-for directive" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "require-trusted-types-for 'script'",
        .header,
        .enforce,
    );
    defer policy.deinit();

    try testing.expect(policy.containsDirective("require-trusted-types-for"));
}

// ============================================================================
// Complex CSP Parsing Tests
// ============================================================================

test "parse complex real-world CSP" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "default-src 'self'; script-src 'self' https://cdn.example.com 'nonce-abc123'; style-src 'self' 'unsafe-inline'; img-src *; connect-src https:; report-uri /csp-report",
        .header,
        .enforce,
    );
    defer policy.deinit();

    try testing.expect(policy.containsDirective("default-src"));
    try testing.expect(policy.containsDirective("script-src"));
    try testing.expect(policy.containsDirective("style-src"));
    try testing.expect(policy.containsDirective("img-src"));
    try testing.expect(policy.containsDirective("connect-src"));
    try testing.expect(policy.containsDirective("report-uri"));

    const script_src = policy.getDirective("script-src").?;
    try testing.expect(script_src.value.contains(.keyword_self));
    try testing.expect(script_src.value.contains(.host));
    try testing.expect(script_src.value.contains(.nonce));
}

test "parse CSP with empty directive value" {
    const allocator = testing.allocator;

    var policy = try parsing.parseSerializedCSP(
        allocator,
        "script-src",
        .header,
        .enforce,
    );
    defer policy.deinit();

    try testing.expect(policy.containsDirective("script-src"));

    const directive = policy.getDirective("script-src").?;
    try testing.expect(directive.value.isEmpty());
}

// ============================================================================
// parseSourceExpression Tests
// ============================================================================

test "parseSourceExpression - keyword" {
    const allocator = testing.allocator;

    var expr = try parsing.parseSourceExpression(allocator, "'self'");
    defer expr.deinit();

    try testing.expectEqual(types.SourceExpressionType.keyword_self, expr.type);
}

test "parseSourceExpression - scheme" {
    const allocator = testing.allocator;

    var expr = try parsing.parseSourceExpression(allocator, "https:");
    defer expr.deinit();

    try testing.expectEqual(types.SourceExpressionType.scheme, expr.type);
    try testing.expectEqualStrings("https:", expr.scheme_part.?);
}

test "parseSourceExpression - host" {
    const allocator = testing.allocator;

    var expr = try parsing.parseSourceExpression(allocator, "example.com");
    defer expr.deinit();

    try testing.expectEqual(types.SourceExpressionType.host, expr.type);
    try testing.expectEqualStrings("example.com", expr.host_part.?);
}

test "parseSourceExpression - wildcard" {
    const allocator = testing.allocator;

    var expr = try parsing.parseSourceExpression(allocator, "*");
    defer expr.deinit();

    try testing.expectEqual(types.SourceExpressionType.wildcard, expr.type);
}
