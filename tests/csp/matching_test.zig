//! CSP Matching Unit Tests
//!
//! Tests for CSP source expression matching algorithms.

const std = @import("std");
const testing = std.testing;
const csp = @import("csp");
const types = csp.types;
const matching = csp.matching;

// ============================================================================
// 'none' Matching Tests
// ============================================================================

test "'none' matches nothing" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();
    try list.append(types.SourceExpression.createBorrowed(.keyword_none, "'none'"));

    // 'none' should not match any URL
    try testing.expect(!matching.doesUrlMatchSourceList(
        "https",
        "example.com",
        443,
        "/script.js",
        &list,
        null,
        0,
    ));
}

// ============================================================================
// 'self' Matching Tests
// ============================================================================

test "'self' matches same origin" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();
    try list.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));

    const origin = types.Origin.createBorrowed("https", "example.com", 443);

    // Same origin should match
    try testing.expect(matching.doesUrlMatchSourceList(
        "https",
        "example.com",
        443,
        "/script.js",
        &list,
        &origin,
        0,
    ));

    // Same origin with default port (null)
    try testing.expect(matching.doesUrlMatchSourceList(
        "https",
        "example.com",
        null,
        "/script.js",
        &list,
        &origin,
        0,
    ));
}

test "'self' does not match different origin" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();
    try list.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));

    const origin = types.Origin.createBorrowed("https", "example.com", 443);

    // Different scheme
    try testing.expect(!matching.doesUrlMatchSourceList(
        "http",
        "example.com",
        80,
        "/script.js",
        &list,
        &origin,
        0,
    ));

    // Different host
    try testing.expect(!matching.doesUrlMatchSourceList(
        "https",
        "other.com",
        443,
        "/script.js",
        &list,
        &origin,
        0,
    ));

    // Different port
    try testing.expect(!matching.doesUrlMatchSourceList(
        "https",
        "example.com",
        8080,
        "/script.js",
        &list,
        &origin,
        0,
    ));
}

test "'self' without origin returns false" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();
    try list.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));

    // No origin provided - should not match
    try testing.expect(!matching.doesUrlMatchSourceList(
        "https",
        "example.com",
        443,
        "/script.js",
        &list,
        null,
        0,
    ));
}

// ============================================================================
// Scheme Matching Tests
// ============================================================================

test "scheme exact matching" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();

    var expr = types.SourceExpression.createBorrowed(.scheme, "https:");
    expr.scheme_part = "https:";
    try list.append(expr);

    try testing.expect(matching.doesUrlMatchSourceList(
        "https",
        "example.com",
        443,
        "/script.js",
        &list,
        null,
        0,
    ));

    try testing.expect(!matching.doesUrlMatchSourceList(
        "http",
        "example.com",
        80,
        "/script.js",
        &list,
        null,
        0,
    ));
}

test "scheme upgrade - http: matches https:" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();

    var expr = types.SourceExpression.createBorrowed(.scheme, "http:");
    expr.scheme_part = "http:";
    try list.append(expr);

    // http: allows https: (upgrade)
    try testing.expect(matching.doesUrlMatchSourceList(
        "https",
        "example.com",
        443,
        "/script.js",
        &list,
        null,
        0,
    ));

    // http: also allows http:
    try testing.expect(matching.doesUrlMatchSourceList(
        "http",
        "example.com",
        80,
        "/script.js",
        &list,
        null,
        0,
    ));
}

test "scheme upgrade - ws: matches wss:" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();

    var expr = types.SourceExpression.createBorrowed(.scheme, "ws:");
    expr.scheme_part = "ws:";
    try list.append(expr);

    // ws: allows wss:
    try testing.expect(matching.doesUrlMatchSourceList(
        "wss",
        "example.com",
        443,
        "/socket",
        &list,
        null,
        0,
    ));
}

test "scheme no downgrade - https: does not match http:" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();

    var expr = types.SourceExpression.createBorrowed(.scheme, "https:");
    expr.scheme_part = "https:";
    try list.append(expr);

    // https: does NOT allow http:
    try testing.expect(!matching.doesUrlMatchSourceList(
        "http",
        "example.com",
        80,
        "/script.js",
        &list,
        null,
        0,
    ));
}

// ============================================================================
// Host Matching Tests
// ============================================================================

test "host exact matching" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();

    var expr = types.SourceExpression.createBorrowed(.host, "example.com");
    expr.host_part = "example.com";
    try list.append(expr);

    try testing.expect(matching.doesUrlMatchSourceList(
        "https",
        "example.com",
        443,
        "/script.js",
        &list,
        null,
        0,
    ));

    // Different host
    try testing.expect(!matching.doesUrlMatchSourceList(
        "https",
        "other.com",
        443,
        "/script.js",
        &list,
        null,
        0,
    ));

    // Subdomain doesn't match (not wildcard)
    try testing.expect(!matching.doesUrlMatchSourceList(
        "https",
        "sub.example.com",
        443,
        "/script.js",
        &list,
        null,
        0,
    ));
}

test "host wildcard matching - *.example.com" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();

    var expr = types.SourceExpression.createBorrowed(.host, "*.example.com");
    expr.host_part = "*.example.com";
    try list.append(expr);

    // Subdomain matches
    try testing.expect(matching.doesUrlMatchSourceList(
        "https",
        "sub.example.com",
        443,
        "/script.js",
        &list,
        null,
        0,
    ));

    // Deep subdomain matches
    try testing.expect(matching.doesUrlMatchSourceList(
        "https",
        "deep.sub.example.com",
        443,
        "/script.js",
        &list,
        null,
        0,
    ));

    // Base domain doesn't match wildcard
    try testing.expect(!matching.doesUrlMatchSourceList(
        "https",
        "example.com",
        443,
        "/script.js",
        &list,
        null,
        0,
    ));
}

test "host with scheme" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();

    var expr = types.SourceExpression.createBorrowed(.host, "https://example.com");
    expr.scheme_part = "https";
    expr.host_part = "example.com";
    try list.append(expr);

    // Matching scheme and host
    try testing.expect(matching.doesUrlMatchSourceList(
        "https",
        "example.com",
        443,
        "/script.js",
        &list,
        null,
        0,
    ));

    // Wrong scheme
    try testing.expect(!matching.doesUrlMatchSourceList(
        "http",
        "example.com",
        80,
        "/script.js",
        &list,
        null,
        0,
    ));
}

test "host with port" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();

    var expr = types.SourceExpression.createBorrowed(.host, "example.com:8080");
    expr.host_part = "example.com";
    expr.port_part = 8080;
    try list.append(expr);

    // Matching port
    try testing.expect(matching.doesUrlMatchSourceList(
        "https",
        "example.com",
        8080,
        "/script.js",
        &list,
        null,
        0,
    ));

    // Wrong port
    try testing.expect(!matching.doesUrlMatchSourceList(
        "https",
        "example.com",
        443,
        "/script.js",
        &list,
        null,
        0,
    ));
}

test "host with path" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();

    var expr = types.SourceExpression.createBorrowed(.host, "example.com/scripts/");
    expr.host_part = "example.com";
    expr.path_part = "/scripts/";
    try list.append(expr);

    // Matching path
    try testing.expect(matching.doesUrlMatchSourceList(
        "https",
        "example.com",
        443,
        "/scripts/app.js",
        &list,
        null,
        0,
    ));

    // Wrong path
    try testing.expect(!matching.doesUrlMatchSourceList(
        "https",
        "example.com",
        443,
        "/other/app.js",
        &list,
        null,
        0,
    ));
}

// ============================================================================
// Nonce Matching Tests
// ============================================================================

test "nonce matching" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();

    var expr = try types.SourceExpression.create(allocator, .nonce, "'nonce-abc123'");
    expr.nonce_value = try allocator.dupe(u8, "abc123");
    try list.append(expr);

    try testing.expect(matching.doesNonceMatch("abc123", &list));
    try testing.expect(!matching.doesNonceMatch("xyz789", &list));
    try testing.expect(!matching.doesNonceMatch("", &list));
}

test "nonce multiple in list" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();

    var expr1 = try types.SourceExpression.create(allocator, .nonce, "'nonce-first'");
    expr1.nonce_value = try allocator.dupe(u8, "first");
    try list.append(expr1);

    var expr2 = try types.SourceExpression.create(allocator, .nonce, "'nonce-second'");
    expr2.nonce_value = try allocator.dupe(u8, "second");
    try list.append(expr2);

    try testing.expect(matching.doesNonceMatch("first", &list));
    try testing.expect(matching.doesNonceMatch("second", &list));
    try testing.expect(!matching.doesNonceMatch("third", &list));
}

// ============================================================================
// Hash Matching Tests
// ============================================================================

test "hash matching" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();

    var expr = try types.SourceExpression.create(allocator, .hash, "'sha256-abcdef'");
    expr.hash_algorithm = try allocator.dupe(u8, "sha256");
    expr.hash_value = try allocator.dupe(u8, "abcdef");
    try list.append(expr);

    try testing.expect(matching.doesHashMatch("sha256", "abcdef", &list));
    try testing.expect(!matching.doesHashMatch("sha256", "xyz", &list));
    try testing.expect(!matching.doesHashMatch("sha384", "abcdef", &list));
}

test "hash algorithm case insensitive" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();

    var expr = try types.SourceExpression.create(allocator, .hash, "'sha256-abcdef'");
    expr.hash_algorithm = try allocator.dupe(u8, "sha256");
    expr.hash_value = try allocator.dupe(u8, "abcdef");
    try list.append(expr);

    try testing.expect(matching.doesHashMatch("SHA256", "abcdef", &list));
    try testing.expect(matching.doesHashMatch("Sha256", "abcdef", &list));
}

// ============================================================================
// Keyword Checking Tests
// ============================================================================

test "allowsUnsafeInline" {
    const allocator = testing.allocator;

    // Without 'unsafe-inline'
    {
        var list = types.SourceList.init(allocator);
        defer list.deinit();
        try list.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));

        try testing.expect(!matching.allowsUnsafeInline(&list));
    }

    // With 'unsafe-inline'
    {
        var list = types.SourceList.init(allocator);
        defer list.deinit();
        try list.append(types.SourceExpression.createBorrowed(.keyword_unsafe_inline, "'unsafe-inline'"));

        try testing.expect(matching.allowsUnsafeInline(&list));
    }
}

test "allowsUnsafeEval" {
    const allocator = testing.allocator;

    // Without 'unsafe-eval'
    {
        var list = types.SourceList.init(allocator);
        defer list.deinit();
        try list.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));

        try testing.expect(!matching.allowsUnsafeEval(&list));
    }

    // With 'unsafe-eval'
    {
        var list = types.SourceList.init(allocator);
        defer list.deinit();
        try list.append(types.SourceExpression.createBorrowed(.keyword_unsafe_eval, "'unsafe-eval'"));

        try testing.expect(matching.allowsUnsafeEval(&list));
    }
}

test "hasStrictDynamic" {
    const allocator = testing.allocator;

    // Without 'strict-dynamic'
    {
        var list = types.SourceList.init(allocator);
        defer list.deinit();
        try list.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));

        try testing.expect(!matching.hasStrictDynamic(&list));
    }

    // With 'strict-dynamic'
    {
        var list = types.SourceList.init(allocator);
        defer list.deinit();
        try list.append(types.SourceExpression.createBorrowed(.keyword_strict_dynamic, "'strict-dynamic'"));

        try testing.expect(matching.hasStrictDynamic(&list));
    }
}

test "hasTrustedTypesEval" {
    const allocator = testing.allocator;

    // Without 'trusted-types-eval'
    {
        var list = types.SourceList.init(allocator);
        defer list.deinit();
        try list.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));

        try testing.expect(!matching.hasTrustedTypesEval(&list));
    }

    // With 'trusted-types-eval'
    {
        var list = types.SourceList.init(allocator);
        defer list.deinit();
        try list.append(types.SourceExpression.createBorrowed(.keyword_trusted_types_eval, "'trusted-types-eval'"));

        try testing.expect(matching.hasTrustedTypesEval(&list));
    }
}

// ============================================================================
// Default Port Tests
// ============================================================================

test "getDefaultPort" {
    try testing.expectEqual(@as(?u16, 80), matching.getDefaultPort("http"));
    try testing.expectEqual(@as(?u16, 443), matching.getDefaultPort("https"));
    try testing.expectEqual(@as(?u16, 80), matching.getDefaultPort("ws"));
    try testing.expectEqual(@as(?u16, 443), matching.getDefaultPort("wss"));
    try testing.expectEqual(@as(?u16, 21), matching.getDefaultPort("ftp"));
    try testing.expectEqual(@as(?u16, null), matching.getDefaultPort("custom"));
    try testing.expectEqual(@as(?u16, null), matching.getDefaultPort("blob"));
    try testing.expectEqual(@as(?u16, null), matching.getDefaultPort("data"));
}

// ============================================================================
// Empty Source List Tests
// ============================================================================

test "empty source list matches nothing" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();
    // Empty list

    try testing.expect(!matching.doesUrlMatchSourceList(
        "https",
        "example.com",
        443,
        "/script.js",
        &list,
        null,
        0,
    ));
}

// ============================================================================
// Wildcard Tests
// ============================================================================

test "wildcard * matches any URL" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();
    try list.append(types.SourceExpression.createBorrowed(.wildcard, "*"));

    // Should match any URL
    try testing.expect(matching.doesUrlMatchSourceList(
        "https",
        "example.com",
        443,
        "/script.js",
        &list,
        null,
        0,
    ));

    try testing.expect(matching.doesUrlMatchSourceList(
        "http",
        "other.com",
        8080,
        "/",
        &list,
        null,
        0,
    ));
}

// ============================================================================
// Unknown Keywords Don't Match URLs
// ============================================================================

test "keywords don't match URLs" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();
    try list.append(types.SourceExpression.createBorrowed(.keyword_unsafe_inline, "'unsafe-inline'"));
    try list.append(types.SourceExpression.createBorrowed(.keyword_unsafe_eval, "'unsafe-eval'"));

    // These keywords are for inline/eval checking, not URL matching
    try testing.expect(!matching.doesUrlMatchSourceList(
        "https",
        "example.com",
        443,
        "/script.js",
        &list,
        null,
        0,
    ));
}
