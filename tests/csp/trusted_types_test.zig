//! CSP Trusted Types Directive Unit Tests
//!
//! Tests for trusted-types and require-trusted-types-for directives.

const std = @import("std");
const testing = std.testing;
const csp = @import("csp");
const types = csp.types;
const directives = csp.directives;

// ============================================================================
// trusted-types Directive Tests
// ============================================================================

test "trusted-types with explicit names" {
    const allocator = testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    var policy = types.Policy.init(allocator, .enforce, .header);
    var tt_directive = try types.Directive.create(allocator, "trusted-types");
    try tt_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "foo"));
    try tt_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "bar"));
    try policy.directive_set.append(tt_directive);
    try csp_list.append(policy);

    // Allowed names
    try testing.expectEqual(
        directives.trusted_types.BlockingResult.Allowed,
        directives.shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "foo", .enforce),
    );
    try testing.expectEqual(
        directives.trusted_types.BlockingResult.Allowed,
        directives.shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "bar", .enforce),
    );

    // Not allowed
    try testing.expectEqual(
        directives.trusted_types.BlockingResult.Blocked,
        directives.shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "baz", .enforce),
    );
}

test "trusted-types with wildcard (*)" {
    const allocator = testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    var policy = types.Policy.init(allocator, .enforce, .header);
    var tt_directive = try types.Directive.create(allocator, "trusted-types");
    try tt_directive.value.append(types.SourceExpression.createBorrowed(.wildcard, "*"));
    try policy.directive_set.append(tt_directive);
    try csp_list.append(policy);

    // Any name should be allowed
    try testing.expectEqual(
        directives.trusted_types.BlockingResult.Allowed,
        directives.shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "any-policy-name", .enforce),
    );
    try testing.expectEqual(
        directives.trusted_types.BlockingResult.Allowed,
        directives.shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "another-policy", .enforce),
    );
}

test "trusted-types 'none'" {
    const allocator = testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    var policy = types.Policy.init(allocator, .enforce, .header);
    var tt_directive = try types.Directive.create(allocator, "trusted-types");
    try tt_directive.value.append(types.SourceExpression.createBorrowed(.keyword_none, "'none'"));
    try policy.directive_set.append(tt_directive);
    try csp_list.append(policy);

    // All names should be blocked
    try testing.expectEqual(
        directives.trusted_types.BlockingResult.Blocked,
        directives.shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "any-policy", .enforce),
    );
}

test "trusted-types 'allow-duplicates'" {
    const allocator = testing.allocator;

    // Without 'allow-duplicates'
    {
        var csp_list = types.CSPList.init(allocator);
        defer csp_list.deinit();

        var policy = types.Policy.init(allocator, .enforce, .header);
        var tt_directive = try types.Directive.create(allocator, "trusted-types");
        try tt_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "my-policy"));
        try policy.directive_set.append(tt_directive);
        try csp_list.append(policy);

        try testing.expect(!directives.areDuplicatePolicyNamesAllowed(&csp_list));
    }

    // With 'allow-duplicates'
    {
        var csp_list = types.CSPList.init(allocator);
        defer csp_list.deinit();

        var policy = types.Policy.init(allocator, .enforce, .header);
        var tt_directive = try types.Directive.create(allocator, "trusted-types");
        try tt_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "my-policy"));
        try tt_directive.value.append(types.SourceExpression.createBorrowed(.keyword_allow_duplicates, "'allow-duplicates'"));
        try policy.directive_set.append(tt_directive);
        try csp_list.append(policy);

        try testing.expect(directives.areDuplicatePolicyNamesAllowed(&csp_list));
    }
}

test "trusted-types policy names are case-sensitive" {
    const allocator = testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    var policy = types.Policy.init(allocator, .enforce, .header);
    var tt_directive = try types.Directive.create(allocator, "trusted-types");
    try tt_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "MyPolicy"));
    try policy.directive_set.append(tt_directive);
    try csp_list.append(policy);

    // Exact match
    try testing.expectEqual(
        directives.trusted_types.BlockingResult.Allowed,
        directives.shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "MyPolicy", .enforce),
    );

    // Different case - should be blocked
    try testing.expectEqual(
        directives.trusted_types.BlockingResult.Blocked,
        directives.shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "mypolicy", .enforce),
    );
    try testing.expectEqual(
        directives.trusted_types.BlockingResult.Blocked,
        directives.shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "MYPOLICY", .enforce),
    );
}

test "trusted-types no CSP means no restriction" {
    const allocator = testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();
    // No policies

    // All names should be allowed (no CSP means no restriction)
    try testing.expectEqual(
        directives.trusted_types.BlockingResult.Allowed,
        directives.shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "any-policy", .enforce),
    );
}

test "trusted-types respects disposition" {
    const allocator = testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    var policy = types.Policy.init(allocator, .report, .header); // report-only
    var tt_directive = try types.Directive.create(allocator, "trusted-types");
    try tt_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "my-policy"));
    try policy.directive_set.append(tt_directive);
    try csp_list.append(policy);

    // Checking enforce disposition - should not be blocked (policy is report-only)
    try testing.expectEqual(
        directives.trusted_types.BlockingResult.Allowed,
        directives.shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "other-policy", .enforce),
    );

    // Checking report disposition - should be blocked
    try testing.expectEqual(
        directives.trusted_types.BlockingResult.Blocked,
        directives.shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "other-policy", .report),
    );
}

// ============================================================================
// require-trusted-types-for Directive Tests
// ============================================================================

test "require-trusted-types-for 'script'" {
    const allocator = testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    var policy = types.Policy.init(allocator, .enforce, .header);
    var rttf_directive = try types.Directive.create(allocator, "require-trusted-types-for");
    try rttf_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "'script'"));
    try policy.directive_set.append(rttf_directive);
    try csp_list.append(policy);

    try testing.expect(directives.isScriptSinkEnforcementRequired(&csp_list));
    try testing.expect(directives.isTrustedTypesEnforcementActive(&csp_list));
}

test "require-trusted-types-for without 'script'" {
    const allocator = testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    var policy = types.Policy.init(allocator, .enforce, .header);
    var rttf_directive = try types.Directive.create(allocator, "require-trusted-types-for");
    try rttf_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "'other'"));
    try policy.directive_set.append(rttf_directive);
    try csp_list.append(policy);

    try testing.expect(!directives.isScriptSinkEnforcementRequired(&csp_list));
}

test "require-trusted-types-for no CSP" {
    const allocator = testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();
    // No policies

    try testing.expect(!directives.isScriptSinkEnforcementRequired(&csp_list));
    try testing.expect(!directives.isTrustedTypesEnforcementActive(&csp_list));
}

test "enforcement vs report-only" {
    const allocator = testing.allocator;

    // Report-only mode
    {
        var csp_list = types.CSPList.init(allocator);
        defer csp_list.deinit();

        var policy = types.Policy.init(allocator, .report, .header);
        var rttf_directive = try types.Directive.create(allocator, "require-trusted-types-for");
        try rttf_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "'script'"));
        try policy.directive_set.append(rttf_directive);
        try csp_list.append(policy);

        // Script sink enforcement NOT required (report-only)
        try testing.expect(!directives.isScriptSinkEnforcementRequired(&csp_list));

        // But enforcement is active (for reporting)
        try testing.expect(directives.isTrustedTypesEnforcementActive(&csp_list));

        // Report-only mode is active
        try testing.expect(directives.require_trusted_types.isTrustedTypesReportOnly(&csp_list));
    }

    // Enforce mode
    {
        var csp_list = types.CSPList.init(allocator);
        defer csp_list.deinit();

        var policy = types.Policy.init(allocator, .enforce, .header);
        var rttf_directive = try types.Directive.create(allocator, "require-trusted-types-for");
        try rttf_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "'script'"));
        try policy.directive_set.append(rttf_directive);
        try csp_list.append(policy);

        // Script sink enforcement IS required
        try testing.expect(directives.isScriptSinkEnforcementRequired(&csp_list));

        // Enforcement is active
        try testing.expect(directives.isTrustedTypesEnforcementActive(&csp_list));

        // Report-only mode is NOT active
        try testing.expect(!directives.require_trusted_types.isTrustedTypesReportOnly(&csp_list));
    }
}

// ============================================================================
// Helper Function Tests
// ============================================================================

test "hasTrustedTypesDirective" {
    const allocator = testing.allocator;

    // Without trusted-types
    {
        var csp_list = types.CSPList.init(allocator);
        defer csp_list.deinit();

        var policy = types.Policy.init(allocator, .enforce, .header);
        var script_src = try types.Directive.create(allocator, "script-src");
        try script_src.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
        try policy.directive_set.append(script_src);
        try csp_list.append(policy);

        try testing.expect(!directives.trusted_types.hasTrustedTypesDirective(&csp_list));
    }

    // With trusted-types
    {
        var csp_list = types.CSPList.init(allocator);
        defer csp_list.deinit();

        var policy = types.Policy.init(allocator, .enforce, .header);
        var tt_directive = try types.Directive.create(allocator, "trusted-types");
        try tt_directive.value.append(types.SourceExpression.createBorrowed(.wildcard, "*"));
        try policy.directive_set.append(tt_directive);
        try csp_list.append(policy);

        try testing.expect(directives.trusted_types.hasTrustedTypesDirective(&csp_list));
    }
}

test "hasRequireTrustedTypesForDirective" {
    const allocator = testing.allocator;

    // Without require-trusted-types-for
    {
        var csp_list = types.CSPList.init(allocator);
        defer csp_list.deinit();

        var policy = types.Policy.init(allocator, .enforce, .header);
        var script_src = try types.Directive.create(allocator, "script-src");
        try script_src.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
        try policy.directive_set.append(script_src);
        try csp_list.append(policy);

        try testing.expect(!directives.require_trusted_types.hasRequireTrustedTypesForDirective(&csp_list));
    }

    // With require-trusted-types-for
    {
        var csp_list = types.CSPList.init(allocator);
        defer csp_list.deinit();

        var policy = types.Policy.init(allocator, .enforce, .header);
        var rttf_directive = try types.Directive.create(allocator, "require-trusted-types-for");
        try rttf_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "'script'"));
        try policy.directive_set.append(rttf_directive);
        try csp_list.append(policy);

        try testing.expect(directives.require_trusted_types.hasRequireTrustedTypesForDirective(&csp_list));
    }
}

// ============================================================================
// Combined Trusted Types Scenario Tests
// ============================================================================

test "complete Trusted Types CSP scenario" {
    const allocator = testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    // Realistic Trusted Types CSP policy
    var policy = types.Policy.init(allocator, .enforce, .header);

    // trusted-types: only allow 'default' and 'sanitizer' policies
    var tt_directive = try types.Directive.create(allocator, "trusted-types");
    try tt_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "default"));
    try tt_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "sanitizer"));
    try policy.directive_set.append(tt_directive);

    // require-trusted-types-for: enable enforcement for script sinks
    var rttf_directive = try types.Directive.create(allocator, "require-trusted-types-for");
    try rttf_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "'script'"));
    try policy.directive_set.append(rttf_directive);

    try csp_list.append(policy);

    // Enforcement is required
    try testing.expect(directives.isScriptSinkEnforcementRequired(&csp_list));

    // 'default' policy can be created
    try testing.expectEqual(
        directives.trusted_types.BlockingResult.Allowed,
        directives.shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "default", .enforce),
    );

    // 'sanitizer' policy can be created
    try testing.expectEqual(
        directives.trusted_types.BlockingResult.Allowed,
        directives.shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "sanitizer", .enforce),
    );

    // 'evil-policy' cannot be created
    try testing.expectEqual(
        directives.trusted_types.BlockingResult.Blocked,
        directives.shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "evil-policy", .enforce),
    );
}

test "multiple policies with trusted-types" {
    const allocator = testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    // First policy allows 'foo' and 'bar'
    var policy1 = types.Policy.init(allocator, .enforce, .header);
    var tt_directive1 = try types.Directive.create(allocator, "trusted-types");
    try tt_directive1.value.append(types.SourceExpression.createBorrowed(.policy_name, "foo"));
    try tt_directive1.value.append(types.SourceExpression.createBorrowed(.policy_name, "bar"));
    try policy1.directive_set.append(tt_directive1);
    try csp_list.append(policy1);

    // Second policy only allows 'foo'
    var policy2 = types.Policy.init(allocator, .enforce, .header);
    var tt_directive2 = try types.Directive.create(allocator, "trusted-types");
    try tt_directive2.value.append(types.SourceExpression.createBorrowed(.policy_name, "foo"));
    try policy2.directive_set.append(tt_directive2);
    try csp_list.append(policy2);

    // 'foo' is allowed by both policies
    try testing.expectEqual(
        directives.trusted_types.BlockingResult.Allowed,
        directives.shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "foo", .enforce),
    );

    // 'bar' is blocked by second policy (not in its list)
    try testing.expectEqual(
        directives.trusted_types.BlockingResult.Blocked,
        directives.shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "bar", .enforce),
    );
}
