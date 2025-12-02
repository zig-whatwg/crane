//! CSP base-uri Directive
//!
//! W3C Content Security Policy Level 3
//! Spec: https://www.w3.org/TR/CSP3/#directive-base-uri
//!
//! The base-uri directive restricts the URLs that can be used
//! in a document's <base> element.

const std = @import("std");
const types = @import("../types.zig");
const matching = @import("../matching.zig");

// ============================================================================
// Base URI Checking
// ============================================================================

/// Check if a base URI is allowed by base-uri directive.
/// Spec: CSP Level 3 § 7.7.1
///
/// Arguments:
/// - policy: The CSP policy to check
/// - base_scheme: Scheme of the proposed base URI
/// - base_host: Host of the proposed base URI
/// - base_port: Port of the proposed base URI (null for default)
/// - base_path: Path of the proposed base URI
///
/// Returns: true if the base URI is allowed, false if blocked
pub fn isBaseUriAllowed(
    policy: *const types.Policy,
    base_scheme: []const u8,
    base_host: []const u8,
    base_port: ?u16,
    base_path: []const u8,
) bool {
    // Get base-uri directive
    const directive = policy.getDirective("base-uri") orelse {
        // No base-uri directive - any base is allowed
        return true;
    };

    // Check against source list
    return matching.doesUrlMatchSourceList(
        base_scheme,
        base_host,
        base_port,
        base_path,
        &directive.value,
        if (policy.self_origin) |*o| o else null,
        0,
    );
}

/// Check if base-uri blocks all base elements (has 'none').
pub fn blocksAllBaseUris(policy: *const types.Policy) bool {
    const directive = policy.getDirective("base-uri") orelse return false;
    return directive.value.isNone();
}

/// Check if base-uri allows only same origin ('self').
pub fn allowsOnlySameOriginBase(policy: *const types.Policy) bool {
    const directive = policy.getDirective("base-uri") orelse return false;

    // Must have exactly one expression and it must be 'self'
    if (directive.value.expressions.items.len != 1) return false;
    return directive.value.expressions.items[0].type == .keyword_self;
}

// ============================================================================
// CSP List Checking
// ============================================================================

/// Check if a base URI is allowed by all policies in the CSP list.
/// All policies must allow the base URI for it to be allowed.
pub fn isBaseUriAllowedByList(
    csp_list: *const types.CSPList,
    base_scheme: []const u8,
    base_host: []const u8,
    base_port: ?u16,
    base_path: []const u8,
) bool {
    for (csp_list.policies.items) |*policy| {
        if (!isBaseUriAllowed(policy, base_scheme, base_host, base_port, base_path)) {
            return false;
        }
    }
    return true;
}

// ============================================================================
// Tests
// ============================================================================

test "isBaseUriAllowed - no directive allows all" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    // No base-uri directive - should allow everything
    try std.testing.expect(isBaseUriAllowed(&policy, "https", "example.com", 443, "/"));
    try std.testing.expect(isBaseUriAllowed(&policy, "https", "evil.com", 443, "/"));
}

test "isBaseUriAllowed - none blocks all" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var directive = try types.Directive.create(allocator, "base-uri");
    try directive.value.append(types.SourceExpression.createBorrowed(.keyword_none, "'none'"));
    try policy.directive_set.append(directive);

    // 'none' should block all base URIs
    try std.testing.expect(!isBaseUriAllowed(&policy, "https", "example.com", 443, "/"));
}

test "isBaseUriAllowed - self allows same origin" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    // Set self origin
    policy.self_origin = types.Origin.createBorrowed("https", "example.com", 443);

    var directive = try types.Directive.create(allocator, "base-uri");
    try directive.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(directive);

    // Same origin should be allowed
    try std.testing.expect(isBaseUriAllowed(&policy, "https", "example.com", 443, "/"));

    // Different origin should be blocked
    try std.testing.expect(!isBaseUriAllowed(&policy, "https", "evil.com", 443, "/"));
}

test "blocksAllBaseUris" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    // No directive
    try std.testing.expect(!blocksAllBaseUris(&policy));

    // Add 'none'
    var directive = try types.Directive.create(allocator, "base-uri");
    try directive.value.append(types.SourceExpression.createBorrowed(.keyword_none, "'none'"));
    try policy.directive_set.append(directive);

    try std.testing.expect(blocksAllBaseUris(&policy));
}
