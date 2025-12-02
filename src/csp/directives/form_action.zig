//! CSP form-action Directive
//!
//! W3C Content Security Policy Level 3
//! Spec: https://www.w3.org/TR/CSP3/#directive-form-action
//!
//! The form-action directive restricts the URLs which can be used
//! as the target of a form submission from a given context.

const std = @import("std");
const types = @import("../types.zig");
const matching = @import("../matching.zig");

// ============================================================================
// Form Action Checking
// ============================================================================

/// Check if a form action URL is allowed by form-action directive.
/// Spec: CSP Level 3 § 7.7.3
///
/// Arguments:
/// - policy: The CSP policy to check
/// - action_scheme: Scheme of the form action URL
/// - action_host: Host of the form action URL
/// - action_port: Port of the form action URL (null for default)
/// - action_path: Path of the form action URL
///
/// Returns: true if the form action is allowed, false if blocked
pub fn isFormActionAllowed(
    policy: *const types.Policy,
    action_scheme: []const u8,
    action_host: []const u8,
    action_port: ?u16,
    action_path: []const u8,
) bool {
    // Get form-action directive
    const directive = policy.getDirective("form-action") orelse {
        // No form-action directive - any action is allowed
        return true;
    };

    // Check against source list
    return matching.doesUrlMatchSourceList(
        action_scheme,
        action_host,
        action_port,
        action_path,
        &directive.value,
        if (policy.self_origin) |*o| o else null,
        0,
    );
}

/// Check if form-action blocks all form submissions (has 'none').
pub fn blocksAllFormActions(policy: *const types.Policy) bool {
    const directive = policy.getDirective("form-action") orelse return false;
    return directive.value.isNone();
}

/// Check if form-action allows only same origin ('self').
pub fn allowsOnlySameOriginFormAction(policy: *const types.Policy) bool {
    const directive = policy.getDirective("form-action") orelse return false;

    // Must have exactly one expression and it must be 'self'
    if (directive.value.expressions.items.len != 1) return false;
    return directive.value.expressions.items[0].type == .keyword_self;
}

// ============================================================================
// CSP List Checking
// ============================================================================

/// Check if a form action is allowed by all policies in the CSP list.
/// All policies must allow the form action for it to be allowed.
pub fn isFormActionAllowedByList(
    csp_list: *const types.CSPList,
    action_scheme: []const u8,
    action_host: []const u8,
    action_port: ?u16,
    action_path: []const u8,
) bool {
    for (csp_list.policies.items) |*policy| {
        if (!isFormActionAllowed(policy, action_scheme, action_host, action_port, action_path)) {
            return false;
        }
    }
    return true;
}

// ============================================================================
// Special Form Actions
// ============================================================================

/// Check if javascript: form actions are allowed.
/// javascript: URLs in forms are blocked unless explicitly allowed.
pub fn allowsJavaScriptFormAction(policy: *const types.Policy) bool {
    const directive = policy.getDirective("form-action") orelse return true;

    // Check for javascript: scheme in source list
    for (directive.value.expressions.items) |expr| {
        if (expr.type == .scheme) {
            if (expr.scheme_part) |scheme| {
                if (std.ascii.eqlIgnoreCase(scheme, "javascript:") or
                    std.ascii.eqlIgnoreCase(scheme, "javascript"))
                {
                    return true;
                }
            }
        }
    }

    return false;
}

/// Check if data: form actions are allowed.
pub fn allowsDataFormAction(policy: *const types.Policy) bool {
    const directive = policy.getDirective("form-action") orelse return true;

    // Check for data: scheme in source list
    for (directive.value.expressions.items) |expr| {
        if (expr.type == .scheme) {
            if (expr.scheme_part) |scheme| {
                if (std.ascii.eqlIgnoreCase(scheme, "data:") or
                    std.ascii.eqlIgnoreCase(scheme, "data"))
                {
                    return true;
                }
            }
        }
    }

    return false;
}

// ============================================================================
// Tests
// ============================================================================

test "isFormActionAllowed - no directive allows all" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    // No form-action directive - should allow everything
    try std.testing.expect(isFormActionAllowed(&policy, "https", "example.com", 443, "/submit"));
    try std.testing.expect(isFormActionAllowed(&policy, "https", "evil.com", 443, "/collect"));
}

test "isFormActionAllowed - none blocks all" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var directive = try types.Directive.create(allocator, "form-action");
    try directive.value.append(types.SourceExpression.createBorrowed(.keyword_none, "'none'"));
    try policy.directive_set.append(directive);

    // 'none' should block all form submissions
    try std.testing.expect(!isFormActionAllowed(&policy, "https", "example.com", 443, "/submit"));
}

test "isFormActionAllowed - self allows same origin" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    // Set self origin
    policy.self_origin = types.Origin.createBorrowed("https", "example.com", 443);

    var directive = try types.Directive.create(allocator, "form-action");
    try directive.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(directive);

    // Same origin should be allowed
    try std.testing.expect(isFormActionAllowed(&policy, "https", "example.com", 443, "/submit"));

    // Different origin should be blocked
    try std.testing.expect(!isFormActionAllowed(&policy, "https", "evil.com", 443, "/collect"));
}

test "blocksAllFormActions" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    // No directive
    try std.testing.expect(!blocksAllFormActions(&policy));

    // Add 'none'
    var directive = try types.Directive.create(allocator, "form-action");
    try directive.value.append(types.SourceExpression.createBorrowed(.keyword_none, "'none'"));
    try policy.directive_set.append(directive);

    try std.testing.expect(blocksAllFormActions(&policy));
}
