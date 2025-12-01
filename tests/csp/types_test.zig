//! CSP Types Unit Tests
//!
//! Tests for CSP core data structures: Policy, Directive, DirectiveSet,
//! SourceExpression, SourceList, CSPList, and Violation.

const std = @import("std");
const testing = std.testing;
const csp = @import("csp");
const types = csp.types;

// ============================================================================
// Policy Tests
// ============================================================================

test "Policy - init and deinit" {
    const allocator = testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    try testing.expectEqual(types.PolicyDisposition.enforce, policy.disposition);
    try testing.expectEqual(types.PolicySource.header, policy.source);
    try testing.expect(policy.directive_set.isEmpty());
    try testing.expect(policy.self_origin == null);
}

test "Policy - report disposition" {
    const allocator = testing.allocator;

    var policy = types.Policy.init(allocator, .report, .meta);
    defer policy.deinit();

    try testing.expectEqual(types.PolicyDisposition.report, policy.disposition);
    try testing.expectEqual(types.PolicySource.meta, policy.source);
}

test "Policy - containsDirective" {
    const allocator = testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    const directive = try types.Directive.create(allocator, "script-src");
    try policy.directive_set.append(directive);

    try testing.expect(policy.containsDirective("script-src"));
    try testing.expect(!policy.containsDirective("style-src"));
    try testing.expect(!policy.containsDirective("default-src"));
}

test "Policy - getDirective" {
    const allocator = testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var directive = try types.Directive.create(allocator, "script-src");
    try directive.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(directive);

    const retrieved = policy.getDirective("script-src");
    try testing.expect(retrieved != null);
    try testing.expectEqualStrings("script-src", retrieved.?.name);
    try testing.expect(retrieved.?.value.contains(.keyword_self));

    try testing.expect(policy.getDirective("style-src") == null);
}

// ============================================================================
// Directive Tests
// ============================================================================

test "Directive - create and deinit" {
    const allocator = testing.allocator;

    var directive = try types.Directive.create(allocator, "default-src");
    defer directive.deinit();

    try testing.expectEqualStrings("default-src", directive.name);
    try testing.expect(directive.value.isEmpty());
}

test "Directive - with source expressions" {
    const allocator = testing.allocator;

    var directive = try types.Directive.create(allocator, "script-src");
    defer directive.deinit();

    try directive.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try directive.value.append(types.SourceExpression.createBorrowed(.scheme, "https:"));

    try testing.expectEqual(@as(usize, 2), directive.value.expressions.items.len);
    try testing.expect(directive.value.contains(.keyword_self));
    try testing.expect(directive.value.contains(.scheme));
}

// ============================================================================
// DirectiveSet Tests
// ============================================================================

test "DirectiveSet - init and isEmpty" {
    const allocator = testing.allocator;

    var set = types.DirectiveSet.init(allocator);
    defer set.deinit();

    try testing.expect(set.isEmpty());
    try testing.expectEqual(@as(usize, 0), set.count());
}

test "DirectiveSet - append first wins" {
    const allocator = testing.allocator;

    var set = types.DirectiveSet.init(allocator);
    defer set.deinit();

    // First directive with 'self'
    var d1 = try types.Directive.create(allocator, "script-src");
    try d1.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try set.append(d1);

    // Second directive with same name but different value - should be ignored
    var d2 = try types.Directive.create(allocator, "script-src");
    try d2.value.append(types.SourceExpression.createBorrowed(.scheme, "https:"));
    try set.append(d2);
    d2.deinit(); // Must clean up rejected directive

    try testing.expectEqual(@as(usize, 1), set.count());

    const retrieved = set.get("script-src").?;
    try testing.expect(retrieved.value.contains(.keyword_self));
    try testing.expect(!retrieved.value.contains(.scheme));
}

test "DirectiveSet - multiple different directives" {
    const allocator = testing.allocator;

    var set = types.DirectiveSet.init(allocator);
    defer set.deinit();

    const d1 = try types.Directive.create(allocator, "script-src");
    const d2 = try types.Directive.create(allocator, "style-src");
    const d3 = try types.Directive.create(allocator, "default-src");

    try set.append(d1);
    try set.append(d2);
    try set.append(d3);

    try testing.expectEqual(@as(usize, 3), set.count());
    try testing.expect(set.containsDirective("script-src"));
    try testing.expect(set.containsDirective("style-src"));
    try testing.expect(set.containsDirective("default-src"));
}

// ============================================================================
// SourceExpression Tests
// ============================================================================

test "SourceExpression - create with allocation" {
    const allocator = testing.allocator;

    var expr = try types.SourceExpression.create(allocator, .keyword_self, "'self'");
    defer expr.deinit();

    try testing.expectEqual(types.SourceExpressionType.keyword_self, expr.type);
    try testing.expectEqualStrings("'self'", expr.raw_value);
    try testing.expect(expr.allocator != null);
}

test "SourceExpression - createBorrowed" {
    const expr = types.SourceExpression.createBorrowed(.scheme, "https:");

    try testing.expectEqual(types.SourceExpressionType.scheme, expr.type);
    try testing.expectEqualStrings("https:", expr.raw_value);
    try testing.expect(expr.allocator == null);
}

test "SourceExpression - with nonce" {
    const allocator = testing.allocator;

    var expr = try types.SourceExpression.create(allocator, .nonce, "'nonce-abc123'");
    expr.nonce_value = try allocator.dupe(u8, "abc123");
    defer expr.deinit();

    try testing.expectEqual(types.SourceExpressionType.nonce, expr.type);
    try testing.expectEqualStrings("abc123", expr.nonce_value.?);
}

test "SourceExpression - with hash" {
    const allocator = testing.allocator;

    var expr = try types.SourceExpression.create(allocator, .hash, "'sha256-abcdef'");
    expr.hash_algorithm = try allocator.dupe(u8, "sha256");
    expr.hash_value = try allocator.dupe(u8, "abcdef");
    defer expr.deinit();

    try testing.expectEqual(types.SourceExpressionType.hash, expr.type);
    try testing.expectEqualStrings("sha256", expr.hash_algorithm.?);
    try testing.expectEqualStrings("abcdef", expr.hash_value.?);
}

// ============================================================================
// SourceList Tests
// ============================================================================

test "SourceList - init and isEmpty" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();

    try testing.expect(list.isEmpty());
}

test "SourceList - append and contains" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();

    try list.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try list.append(types.SourceExpression.createBorrowed(.scheme, "https:"));

    try testing.expect(!list.isEmpty());
    try testing.expect(list.contains(.keyword_self));
    try testing.expect(list.contains(.scheme));
    try testing.expect(!list.contains(.keyword_none));
    try testing.expect(!list.contains(.nonce));
}

test "SourceList - isNone with 'none'" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();

    try list.append(types.SourceExpression.createBorrowed(.keyword_none, "'none'"));

    try testing.expect(list.isNone());
}

test "SourceList - isNone with multiple items" {
    const allocator = testing.allocator;

    var list = types.SourceList.init(allocator);
    defer list.deinit();

    try list.append(types.SourceExpression.createBorrowed(.keyword_none, "'none'"));
    try list.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));

    // Not isNone because multiple items
    try testing.expect(!list.isNone());
}

// ============================================================================
// CSPList Tests
// ============================================================================

test "CSPList - init and isEmpty" {
    const allocator = testing.allocator;

    var list = types.CSPList.init(allocator);
    defer list.deinit();

    try testing.expect(list.isEmpty());
    try testing.expect(!list.contains_header_policy);
}

test "CSPList - append policies" {
    const allocator = testing.allocator;

    var list = types.CSPList.init(allocator);
    defer list.deinit();

    const p1 = types.Policy.init(allocator, .enforce, .header);
    const p2 = types.Policy.init(allocator, .report, .meta);

    try list.append(p1);
    try list.append(p2);

    try testing.expect(!list.isEmpty());
    try testing.expectEqual(@as(usize, 2), list.policies.items.len);
    try testing.expect(list.contains_header_policy);
}

test "CSPList - hasEnforcingPolicy" {
    const allocator = testing.allocator;

    // Empty list
    {
        var list = types.CSPList.init(allocator);
        defer list.deinit();
        try testing.expect(!list.hasEnforcingPolicy());
    }

    // Only report-only
    {
        var list = types.CSPList.init(allocator);
        defer list.deinit();
        try list.append(types.Policy.init(allocator, .report, .header));
        try testing.expect(!list.hasEnforcingPolicy());
    }

    // Has enforcing
    {
        var list = types.CSPList.init(allocator);
        defer list.deinit();
        try list.append(types.Policy.init(allocator, .enforce, .header));
        try testing.expect(list.hasEnforcingPolicy());
    }
}

test "CSPList - hasReportOnlyPolicy" {
    const allocator = testing.allocator;

    // Empty list
    {
        var list = types.CSPList.init(allocator);
        defer list.deinit();
        try testing.expect(!list.hasReportOnlyPolicy());
    }

    // Has report-only
    {
        var list = types.CSPList.init(allocator);
        defer list.deinit();
        try list.append(types.Policy.init(allocator, .report, .header));
        try testing.expect(list.hasReportOnlyPolicy());
    }
}

// ============================================================================
// Origin Tests
// ============================================================================

test "Origin - createBorrowed" {
    const origin = types.Origin.createBorrowed("https", "example.com", 443);

    try testing.expectEqualStrings("https", origin.scheme);
    try testing.expectEqualStrings("example.com", origin.host);
    try testing.expectEqual(@as(?u16, 443), origin.port);
    try testing.expect(origin.allocator == null);
}

test "Origin - create with allocation" {
    const allocator = testing.allocator;

    var origin = try types.Origin.create(allocator, "https", "example.com", 8080);
    defer origin.deinit();

    try testing.expectEqualStrings("https", origin.scheme);
    try testing.expectEqualStrings("example.com", origin.host);
    try testing.expectEqual(@as(?u16, 8080), origin.port);
    try testing.expect(origin.allocator != null);
}

test "Origin - null port" {
    const origin = types.Origin.createBorrowed("file", "localhost", null);

    try testing.expectEqualStrings("file", origin.scheme);
    try testing.expectEqualStrings("localhost", origin.host);
    try testing.expect(origin.port == null);
}

// ============================================================================
// Violation Tests
// ============================================================================

test "Violation - ViolationResource variants" {
    const url_resource = types.ViolationResource{ .url = "https://evil.com/script.js" };
    const inline_resource = types.ViolationResource{ .inline_script = {} };
    const eval_resource = types.ViolationResource{ .eval_script = {} };
    const tt_policy = types.ViolationResource{ .trusted_types_policy = {} };
    const tt_sink = types.ViolationResource{ .trusted_types_sink = {} };

    // Just verify they can be created
    try testing.expect(url_resource == .url);
    try testing.expect(inline_resource == .inline_script);
    try testing.expect(eval_resource == .eval_script);
    try testing.expect(tt_policy == .trusted_types_policy);
    try testing.expect(tt_sink == .trusted_types_sink);
}

test "Violation - basic creation" {
    const violation = types.Violation{
        .document_uri = "https://example.com/page",
        .status_code = 200,
        .blocked_uri = .{ .inline_script = {} },
        .violated_directive = "script-src",
        .effective_directive = "script-src",
        .original_policy = "script-src 'self'",
        .disposition = .enforce,
        .allocator = null,
    };

    try testing.expectEqualStrings("https://example.com/page", violation.document_uri);
    try testing.expectEqual(@as(u16, 200), violation.status_code);
    try testing.expect(violation.blocked_uri == .inline_script);
    try testing.expectEqualStrings("script-src", violation.violated_directive);
    try testing.expectEqual(types.PolicyDisposition.enforce, violation.disposition);
}

// ============================================================================
// PolicyDisposition Tests
// ============================================================================

test "PolicyDisposition - enum values" {
    const enforce = types.PolicyDisposition.enforce;
    const report = types.PolicyDisposition.report;

    try testing.expect(enforce != report);
    try testing.expect(enforce == .enforce);
    try testing.expect(report == .report);
}

// ============================================================================
// SourceExpressionType Tests
// ============================================================================

test "SourceExpressionType - all keyword types" {
    // Verify all keyword types exist
    try testing.expect(types.SourceExpressionType.keyword_none == .keyword_none);
    try testing.expect(types.SourceExpressionType.keyword_self == .keyword_self);
    try testing.expect(types.SourceExpressionType.keyword_unsafe_inline == .keyword_unsafe_inline);
    try testing.expect(types.SourceExpressionType.keyword_unsafe_eval == .keyword_unsafe_eval);
    try testing.expect(types.SourceExpressionType.keyword_unsafe_hashes == .keyword_unsafe_hashes);
    try testing.expect(types.SourceExpressionType.keyword_strict_dynamic == .keyword_strict_dynamic);
    try testing.expect(types.SourceExpressionType.keyword_wasm_unsafe_eval == .keyword_wasm_unsafe_eval);
    try testing.expect(types.SourceExpressionType.keyword_report_sample == .keyword_report_sample);
    try testing.expect(types.SourceExpressionType.keyword_trusted_types_eval == .keyword_trusted_types_eval);
    try testing.expect(types.SourceExpressionType.keyword_allow_duplicates == .keyword_allow_duplicates);
}

test "SourceExpressionType - all value types" {
    try testing.expect(types.SourceExpressionType.scheme == .scheme);
    try testing.expect(types.SourceExpressionType.host == .host);
    try testing.expect(types.SourceExpressionType.nonce == .nonce);
    try testing.expect(types.SourceExpressionType.hash == .hash);
    try testing.expect(types.SourceExpressionType.wildcard == .wildcard);
    try testing.expect(types.SourceExpressionType.policy_name == .policy_name);
}
