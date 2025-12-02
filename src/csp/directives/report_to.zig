//! CSP report-to Directive
//!
//! W3C Content Security Policy Level 3
//! Spec: https://www.w3.org/TR/CSP3/#directive-report-to
//!
//! The report-to directive specifies the Reporting API endpoint group
//! that CSP violation reports should be sent to.
//!
//! Note: This replaces the deprecated report-uri directive.

const std = @import("std");
const types = @import("../types.zig");

// ============================================================================
// Report-To Directive
// ============================================================================

/// Get the Reporting API group name from report-to directive.
/// Spec: CSP Level 3 § 7.6
///
/// Returns: The group name, or null if no report-to directive
pub fn getReportingGroup(policy: *const types.Policy) ?[]const u8 {
    const directive = policy.getDirective("report-to") orelse return null;

    // report-to takes a single token (the group name)
    if (directive.value.expressions.items.len == 0) return null;

    return directive.value.expressions.items[0].raw_value;
}

/// Get all report-uri endpoints (deprecated but still supported).
/// Spec: CSP Level 3 § 7.6.2
pub fn getReportUris(policy: *const types.Policy) []const types.SourceExpression {
    const directive = policy.getDirective("report-uri") orelse return &.{};
    return directive.value.expressions.items;
}

/// Check if policy has any reporting configured.
pub fn hasReporting(policy: *const types.Policy) bool {
    return policy.containsDirective("report-to") or
        policy.containsDirective("report-uri");
}

// ============================================================================
// Report Configuration
// ============================================================================

/// Reporting configuration for a policy
pub const ReportConfig = struct {
    /// Reporting API group name (report-to)
    reporting_group: ?[]const u8,

    /// Legacy report-uri endpoints
    report_uris: []const []const u8,

    /// Allocator used for report_uris
    allocator: ?std.mem.Allocator,

    pub fn deinit(self: *ReportConfig) void {
        if (self.allocator) |alloc| {
            for (self.report_uris) |uri| {
                alloc.free(uri);
            }
            alloc.free(self.report_uris);
        }
    }
};

/// Extract reporting configuration from a policy.
pub fn getReportConfig(allocator: std.mem.Allocator, policy: *const types.Policy) !ReportConfig {
    const reporting_group = getReportingGroup(policy);

    // Collect report-uri endpoints
    const uri_exprs = getReportUris(policy);
    var uris = try allocator.alloc([]const u8, uri_exprs.len);
    errdefer allocator.free(uris);

    var i: usize = 0;
    for (uri_exprs) |expr| {
        uris[i] = try allocator.dupe(u8, expr.raw_value);
        i += 1;
    }

    return .{
        .reporting_group = reporting_group,
        .report_uris = uris,
        .allocator = allocator,
    };
}

// ============================================================================
// Reporting Priority
// ============================================================================

/// Determine which reporting mechanism to use.
/// Spec: CSP Level 3 § 5.3.1
///
/// Priority:
/// 1. report-to (Reporting API) - preferred
/// 2. report-uri (legacy) - fallback
pub const ReportingMechanism = enum {
    /// Use Reporting API (report-to)
    reporting_api,
    /// Use legacy report-uri
    legacy_uri,
    /// No reporting configured
    none,
};

pub fn getReportingMechanism(policy: *const types.Policy) ReportingMechanism {
    if (policy.containsDirective("report-to")) {
        return .reporting_api;
    }
    if (policy.containsDirective("report-uri")) {
        return .legacy_uri;
    }
    return .none;
}

// ============================================================================
// Meta Tag Restrictions
// ============================================================================

/// Check if report-to is valid in the policy's context.
/// report-to is NOT allowed in <meta> tag policies.
/// Spec: CSP Level 3 § 3.2.1
pub fn isReportToValidForSource(source: types.PolicySource) bool {
    return source == .header;
}

/// Check if report-uri is valid in the policy's context.
/// report-uri is also NOT allowed in <meta> tag policies.
pub fn isReportUriValidForSource(source: types.PolicySource) bool {
    return source == .header;
}

// ============================================================================
// Tests
// ============================================================================

test "getReportingGroup" {
    const allocator = std.testing.allocator;

    // No directive
    {
        var policy = types.Policy.init(allocator, .enforce, .header);
        defer policy.deinit();

        try std.testing.expect(getReportingGroup(&policy) == null);
    }

    // With report-to
    {
        var policy = types.Policy.init(allocator, .enforce, .header);
        defer policy.deinit();

        var directive = try types.Directive.create(allocator, "report-to");
        try directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "csp-endpoint"));
        try policy.directive_set.append(directive);

        const group = getReportingGroup(&policy);
        try std.testing.expect(group != null);
        try std.testing.expectEqualStrings("csp-endpoint", group.?);
    }
}

test "getReportingMechanism" {
    const allocator = std.testing.allocator;

    // No reporting
    {
        var policy = types.Policy.init(allocator, .enforce, .header);
        defer policy.deinit();

        try std.testing.expectEqual(ReportingMechanism.none, getReportingMechanism(&policy));
    }

    // report-to preferred
    {
        var policy = types.Policy.init(allocator, .enforce, .header);
        defer policy.deinit();

        var directive = try types.Directive.create(allocator, "report-to");
        try directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "group"));
        try policy.directive_set.append(directive);

        try std.testing.expectEqual(ReportingMechanism.reporting_api, getReportingMechanism(&policy));
    }

    // report-uri fallback
    {
        var policy = types.Policy.init(allocator, .enforce, .header);
        defer policy.deinit();

        var directive = try types.Directive.create(allocator, "report-uri");
        try directive.value.append(types.SourceExpression.createBorrowed(.host, "https://example.com/report"));
        try policy.directive_set.append(directive);

        try std.testing.expectEqual(ReportingMechanism.legacy_uri, getReportingMechanism(&policy));
    }
}

test "isReportToValidForSource" {
    try std.testing.expect(isReportToValidForSource(.header));
    try std.testing.expect(!isReportToValidForSource(.meta));
}
