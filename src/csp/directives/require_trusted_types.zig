//! require-trusted-types-for CSP Directive
//!
//! W3C Trusted Types Spec: https://w3c.github.io/trusted-types/dist/spec/ § 4.3.2
//!
//! This module implements the require-trusted-types-for directive that enables
//! Trusted Types enforcement for DOM XSS sinks.

const std = @import("std");
const types = @import("../types.zig");

// ============================================================================
// Constants
// ============================================================================

/// Sink groups that can be protected by Trusted Types
/// Currently only 'script' is defined in the spec
pub const SINK_GROUP_SCRIPT = "'script'";

// ============================================================================
// Enforcement Checking
// ============================================================================

/// Check if a sink group requires Trusted Types.
/// Spec: Trusted Types spec § 4.3.3
///
/// Algorithm (Does sink type require trusted types?):
/// 1. For each policy in global's CSP list:
///    a. Let directive be result of getting 'require-trusted-types-for'
///    b. If directive is null, continue
///    c. If directive value does not contain sink group, continue
///    d. If policy disposition is 'enforce', return true
///    e. If includeReportOnly, return true
/// 2. Return false
///
/// Arguments:
/// - csp_list: The document's CSP list
/// - sink_group: The sink group to check (e.g., "'script'")
/// - include_report_only: Whether to consider report-only policies
pub fn doesSinkTypeRequireTrustedTypes(
    csp_list: *const types.CSPList,
    sink_group: []const u8,
    include_report_only: bool,
) bool {
    for (csp_list.policies.items) |*policy| {
        // Step 1a: Get require-trusted-types-for directive
        const directive = policy.getDirective("require-trusted-types-for") orelse continue;

        // Step 1c: Check if sink group is in directive value
        var contains_sink_group = false;
        for (directive.value.expressions.items) |expr| {
            if (std.ascii.eqlIgnoreCase(expr.raw_value, sink_group)) {
                contains_sink_group = true;
                break;
            }
        }

        if (!contains_sink_group) continue;

        // Step 1d: Check disposition
        if (policy.disposition == .enforce) {
            return true;
        }

        // Step 1e: Include report-only if requested
        if (include_report_only) {
            return true;
        }
    }

    // Step 2: No matching policy found
    return false;
}

/// Check if enforcement is required for the 'script' sink group.
/// Convenience function for the most common case.
///
/// This checks if DOM XSS sinks (innerHTML, eval, etc.) require Trusted Types.
pub fn isScriptSinkEnforcementRequired(csp_list: *const types.CSPList) bool {
    return doesSinkTypeRequireTrustedTypes(csp_list, SINK_GROUP_SCRIPT, false);
}

/// Check if any Trusted Types enforcement is active (including report-only).
/// Useful for determining if Trusted Types should be enforced at all.
pub fn isTrustedTypesEnforcementActive(csp_list: *const types.CSPList) bool {
    return doesSinkTypeRequireTrustedTypes(csp_list, SINK_GROUP_SCRIPT, true);
}

/// Check if Trusted Types should be reported (but not blocked).
/// Returns true only for report-only mode.
pub fn isTrustedTypesReportOnly(csp_list: *const types.CSPList) bool {
    // Report-only is active if enforcement is active but not required
    return isTrustedTypesEnforcementActive(csp_list) and
        !isScriptSinkEnforcementRequired(csp_list);
}

// ============================================================================
// Directive Presence
// ============================================================================

/// Check if any policy has require-trusted-types-for directive.
pub fn hasRequireTrustedTypesForDirective(csp_list: *const types.CSPList) bool {
    for (csp_list.policies.items) |*policy| {
        if (policy.containsDirective("require-trusted-types-for")) {
            return true;
        }
    }
    return false;
}

/// Get the list of required sink groups from CSP.
pub fn getRequiredSinkGroups(
    allocator: std.mem.Allocator,
    csp_list: *const types.CSPList,
) !std.ArrayList([]const u8) {
    var result = std.ArrayList([]const u8).init(allocator);
    errdefer result.deinit();

    for (csp_list.policies.items) |*policy| {
        const directive = policy.getDirective("require-trusted-types-for") orelse continue;

        for (directive.value.expressions.items) |expr| {
            // Avoid duplicates
            var found = false;
            for (result.items) |existing| {
                if (std.ascii.eqlIgnoreCase(existing, expr.raw_value)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                try result.append(expr.raw_value);
            }
        }
    }

    return result;
}

// ============================================================================
// Tests
// ============================================================================

test "doesSinkTypeRequireTrustedTypes - no CSP" {
    const allocator = std.testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    // No CSP policies - should not require
    try std.testing.expect(!doesSinkTypeRequireTrustedTypes(&csp_list, SINK_GROUP_SCRIPT, false));
}

test "doesSinkTypeRequireTrustedTypes - enforce mode" {
    const allocator = std.testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    var policy = types.Policy.init(allocator, .enforce, .header);
    var rttf_directive = try types.Directive.create(allocator, "require-trusted-types-for");
    try rttf_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "'script'"));
    try policy.directive_set.append(rttf_directive);
    try csp_list.append(policy);

    // Should require Trusted Types
    try std.testing.expect(doesSinkTypeRequireTrustedTypes(&csp_list, SINK_GROUP_SCRIPT, false));
    try std.testing.expect(isScriptSinkEnforcementRequired(&csp_list));
}

test "doesSinkTypeRequireTrustedTypes - report-only mode" {
    const allocator = std.testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    var policy = types.Policy.init(allocator, .report, .header);
    var rttf_directive = try types.Directive.create(allocator, "require-trusted-types-for");
    try rttf_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "'script'"));
    try policy.directive_set.append(rttf_directive);
    try csp_list.append(policy);

    // Should not require (enforce only)
    try std.testing.expect(!doesSinkTypeRequireTrustedTypes(&csp_list, SINK_GROUP_SCRIPT, false));
    try std.testing.expect(!isScriptSinkEnforcementRequired(&csp_list));

    // Should be active when including report-only
    try std.testing.expect(doesSinkTypeRequireTrustedTypes(&csp_list, SINK_GROUP_SCRIPT, true));
    try std.testing.expect(isTrustedTypesEnforcementActive(&csp_list));
}

test "doesSinkTypeRequireTrustedTypes - wrong sink group" {
    const allocator = std.testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    var policy = types.Policy.init(allocator, .enforce, .header);
    var rttf_directive = try types.Directive.create(allocator, "require-trusted-types-for");
    try rttf_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "'other'"));
    try policy.directive_set.append(rttf_directive);
    try csp_list.append(policy);

    // Should not require (wrong sink group)
    try std.testing.expect(!doesSinkTypeRequireTrustedTypes(&csp_list, SINK_GROUP_SCRIPT, false));
}

test "isTrustedTypesReportOnly" {
    const allocator = std.testing.allocator;

    // Report-only mode
    {
        var csp_list = types.CSPList.init(allocator);
        defer csp_list.deinit();

        var policy = types.Policy.init(allocator, .report, .header);
        var rttf_directive = try types.Directive.create(allocator, "require-trusted-types-for");
        try rttf_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "'script'"));
        try policy.directive_set.append(rttf_directive);
        try csp_list.append(policy);

        try std.testing.expect(isTrustedTypesReportOnly(&csp_list));
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

        try std.testing.expect(!isTrustedTypesReportOnly(&csp_list));
    }
}
