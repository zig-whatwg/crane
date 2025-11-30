//! Trusted Types CSP Directives
//!
//! W3C Trusted Types Spec: https://w3c.github.io/trusted-types/dist/spec/ § 4
//!
//! This module implements:
//! - trusted-types directive: Controls which policy names can be created
//! - Policy name matching and 'allow-duplicates' handling

const std = @import("std");
const types = @import("../types.zig");

// ============================================================================
// Constants
// ============================================================================

/// Trusted Types directive value keywords
pub const TT_KEYWORD_NONE = "'none'";
pub const TT_KEYWORD_ALLOW_DUPLICATES = "'allow-duplicates'";
pub const TT_WILDCARD = "*";

// ============================================================================
// Policy Creation Blocking
// ============================================================================

/// Result of policy creation blocking check
pub const BlockingResult = enum {
    Allowed,
    Blocked,
};

/// Check if a Trusted Type policy creation should be blocked by CSP.
/// Spec: Trusted Types spec § 4.3.1
///
/// Algorithm (Should Trusted Type policy creation be blocked by CSP?):
/// 1. Let dominated be null
/// 2. For each policy in global's CSP list:
///    a. If policy disposition is not input disposition, continue
///    b. If policy does not contain 'trusted-types' directive, continue
///    c. Let dominated' be result of 'Does TT directive value allow name?'
///    d. If dominated' is false, set dominated to false
///    e. If dominated is null, set dominated to dominated'
/// 3. If dominated is false, return 'Blocked'
/// 4. Return 'Allowed'
///
/// Arguments:
/// - csp_list: The document's CSP list
/// - policy_name: Name of the policy being created
/// - disposition: Which disposition to check (enforce or report)
pub fn shouldTrustedTypePolicyCreationBeBlocked(
    csp_list: *const types.CSPList,
    policy_name: []const u8,
    disposition: types.PolicyDisposition,
) BlockingResult {
    var dominated: ?bool = null;

    for (csp_list.policies.items) |*policy| {
        // Step 2a: Check disposition
        if (policy.disposition != disposition) continue;

        // Step 2b: Check for trusted-types directive
        const tt_directive = policy.getDirective("trusted-types") orelse continue;

        // Step 2c: Check if directive allows this policy name
        const allows = doesTrustedTypesDirectiveAllowName(
            &tt_directive.value,
            policy_name,
        );

        // Step 2d-2e: Update dominated flag
        if (!allows) {
            dominated = false;
        } else if (dominated == null) {
            dominated = allows;
        }
    }

    // Step 3-4: Return result
    if (dominated == false) {
        return .Blocked;
    }

    return .Allowed;
}

/// Check if a trusted-types directive value allows a policy name.
/// Spec: Trusted Types spec § 4.3.1.1
///
/// Arguments:
/// - source_list: The directive's source list (value)
/// - policy_name: Name of the policy to check
pub fn doesTrustedTypesDirectiveAllowName(
    source_list: *const types.SourceList,
    policy_name: []const u8,
) bool {
    // Empty directive value means nothing is allowed
    if (source_list.isEmpty()) {
        return false;
    }

    for (source_list.expressions.items) |expr| {
        // 'none' keyword - nothing allowed
        if (expr.type == .keyword_none) {
            return false;
        }

        // Wildcard (*) - everything allowed
        if (expr.type == .wildcard) {
            return true;
        }
        if (std.mem.eql(u8, expr.raw_value, TT_WILDCARD)) {
            return true;
        }

        // Skip 'allow-duplicates' keyword (it's a modifier, not a policy name)
        if (expr.type == .keyword_allow_duplicates) {
            continue;
        }
        if (std.ascii.eqlIgnoreCase(expr.raw_value, TT_KEYWORD_ALLOW_DUPLICATES)) {
            continue;
        }

        // Check if policy name matches this expression
        // Policy names are case-sensitive per spec
        if (std.mem.eql(u8, expr.raw_value, policy_name)) {
            return true;
        }
    }

    return false;
}

// ============================================================================
// Duplicate Policy Names
// ============================================================================

/// Check if duplicate policy names are allowed by any policy in the CSP list.
/// Spec: Trusted Types spec § 4.3.1
///
/// If any policy's trusted-types directive contains 'allow-duplicates',
/// duplicate policy names are allowed.
pub fn areDuplicatePolicyNamesAllowed(
    csp_list: *const types.CSPList,
) bool {
    for (csp_list.policies.items) |*policy| {
        const tt_directive = policy.getDirective("trusted-types") orelse continue;

        for (tt_directive.value.expressions.items) |expr| {
            if (expr.type == .keyword_allow_duplicates) {
                return true;
            }
            if (std.ascii.eqlIgnoreCase(expr.raw_value, TT_KEYWORD_ALLOW_DUPLICATES)) {
                return true;
            }
        }
    }

    return false;
}

// ============================================================================
// Trusted Types Policy Check
// ============================================================================

/// Check if Trusted Types policies are controlled by CSP.
/// Returns true if any policy in the CSP list has a trusted-types directive.
pub fn hasTrustedTypesDirective(csp_list: *const types.CSPList) bool {
    for (csp_list.policies.items) |*policy| {
        if (policy.containsDirective("trusted-types")) {
            return true;
        }
    }
    return false;
}

/// Get the list of allowed policy names from CSP.
/// Returns null if no trusted-types directive is present (meaning all names allowed).
/// Returns empty list if 'none' is specified.
pub fn getAllowedPolicyNames(
    allocator: std.mem.Allocator,
    csp_list: *const types.CSPList,
) !?std.ArrayList([]const u8) {
    var has_tt_directive = false;
    var result = std.ArrayList([]const u8).init(allocator);
    errdefer result.deinit();

    for (csp_list.policies.items) |*policy| {
        const tt_directive = policy.getDirective("trusted-types") orelse continue;
        has_tt_directive = true;

        for (tt_directive.value.expressions.items) |expr| {
            // 'none' means no policies allowed
            if (expr.type == .keyword_none) {
                result.clearRetainingCapacity();
                return result;
            }

            // Wildcard means all policies allowed - return null to indicate this
            if (expr.type == .wildcard or std.mem.eql(u8, expr.raw_value, "*")) {
                result.deinit();
                return null;
            }

            // Skip keywords
            if (expr.type == .keyword_allow_duplicates) continue;
            if (std.ascii.eqlIgnoreCase(expr.raw_value, TT_KEYWORD_ALLOW_DUPLICATES)) continue;

            // Add policy name to list (avoid duplicates)
            var found = false;
            for (result.items) |existing| {
                if (std.mem.eql(u8, existing, expr.raw_value)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                try result.append(expr.raw_value);
            }
        }
    }

    if (!has_tt_directive) {
        result.deinit();
        return null; // No restriction
    }

    return result;
}

// ============================================================================
// Tests
// ============================================================================

test "shouldTrustedTypePolicyCreationBeBlocked - no CSP" {
    const allocator = std.testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    // No CSP policies - should allow
    const result = shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "my-policy", .enforce);
    try std.testing.expectEqual(BlockingResult.Allowed, result);
}

test "shouldTrustedTypePolicyCreationBeBlocked - allowed by name" {
    const allocator = std.testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    var policy = types.Policy.init(allocator, .enforce, .header);
    var tt_directive = try types.Directive.create(allocator, "trusted-types");
    try tt_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "my-policy"));
    try tt_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "other-policy"));
    try policy.directive_set.append(tt_directive);
    try csp_list.append(policy);

    // my-policy is allowed
    try std.testing.expectEqual(
        BlockingResult.Allowed,
        shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "my-policy", .enforce),
    );

    // unknown-policy is blocked
    try std.testing.expectEqual(
        BlockingResult.Blocked,
        shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "unknown-policy", .enforce),
    );
}

test "shouldTrustedTypePolicyCreationBeBlocked - wildcard allows all" {
    const allocator = std.testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    var policy = types.Policy.init(allocator, .enforce, .header);
    var tt_directive = try types.Directive.create(allocator, "trusted-types");
    try tt_directive.value.append(types.SourceExpression.createBorrowed(.wildcard, "*"));
    try policy.directive_set.append(tt_directive);
    try csp_list.append(policy);

    // Any policy name should be allowed
    try std.testing.expectEqual(
        BlockingResult.Allowed,
        shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "any-policy", .enforce),
    );
}

test "shouldTrustedTypePolicyCreationBeBlocked - none blocks all" {
    const allocator = std.testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    var policy = types.Policy.init(allocator, .enforce, .header);
    var tt_directive = try types.Directive.create(allocator, "trusted-types");
    try tt_directive.value.append(types.SourceExpression.createBorrowed(.keyword_none, "'none'"));
    try policy.directive_set.append(tt_directive);
    try csp_list.append(policy);

    // All policy names should be blocked
    try std.testing.expectEqual(
        BlockingResult.Blocked,
        shouldTrustedTypePolicyCreationBeBlocked(&csp_list, "any-policy", .enforce),
    );
}

test "areDuplicatePolicyNamesAllowed" {
    const allocator = std.testing.allocator;

    // Without 'allow-duplicates'
    {
        var csp_list = types.CSPList.init(allocator);
        defer csp_list.deinit();

        var policy = types.Policy.init(allocator, .enforce, .header);
        var tt_directive = try types.Directive.create(allocator, "trusted-types");
        try tt_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "my-policy"));
        try policy.directive_set.append(tt_directive);
        try csp_list.append(policy);

        try std.testing.expect(!areDuplicatePolicyNamesAllowed(&csp_list));
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

        try std.testing.expect(areDuplicatePolicyNamesAllowed(&csp_list));
    }
}

test "doesTrustedTypesDirectiveAllowName - case sensitive" {
    const allocator = std.testing.allocator;

    var source_list = types.SourceList.init(allocator);
    defer source_list.deinit();

    try source_list.append(types.SourceExpression.createBorrowed(.policy_name, "MyPolicy"));

    // Exact match works
    try std.testing.expect(doesTrustedTypesDirectiveAllowName(&source_list, "MyPolicy"));

    // Different case doesn't match (policy names are case-sensitive)
    try std.testing.expect(!doesTrustedTypesDirectiveAllowName(&source_list, "mypolicy"));
    try std.testing.expect(!doesTrustedTypesDirectiveAllowName(&source_list, "MYPOLICY"));
}
