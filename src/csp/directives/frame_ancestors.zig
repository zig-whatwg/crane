//! CSP frame-ancestors Directive
//!
//! W3C Content Security Policy Level 3
//! Spec: https://www.w3.org/TR/CSP3/#directive-frame-ancestors
//!
//! The frame-ancestors directive restricts which parents may embed
//! this document in a frame, iframe, object, or embed element.
//! It replaces the X-Frame-Options header.

const std = @import("std");
const types = @import("../types.zig");
const matching = @import("../matching.zig");

// ============================================================================
// Frame Ancestors Checking
// ============================================================================

/// Check if embedding in an ancestor is allowed by frame-ancestors.
/// Spec: CSP Level 3 § 7.7.2
///
/// Arguments:
/// - policy: The CSP policy to check
/// - ancestor_scheme: Scheme of the ancestor document
/// - ancestor_host: Host of the ancestor document
/// - ancestor_port: Port of the ancestor document (null for default)
///
/// Returns: true if embedding is allowed, false if blocked
pub fn isAncestorAllowed(
    policy: *const types.Policy,
    ancestor_scheme: []const u8,
    ancestor_host: []const u8,
    ancestor_port: ?u16,
) bool {
    // Get frame-ancestors directive
    const directive = policy.getDirective("frame-ancestors") orelse {
        // No frame-ancestors directive - embedding is allowed
        return true;
    };

    // Check if 'none' - blocks all framing
    if (directive.value.isNone()) {
        return false;
    }

    // Check each source expression
    return matching.doesUrlMatchSourceList(
        ancestor_scheme,
        ancestor_host,
        ancestor_port,
        "/", // Path doesn't matter for frame-ancestors
        &directive.value,
        if (policy.self_origin) |*o| o else null,
        0,
    );
}

/// Check all ancestors in the frame hierarchy.
/// Spec: CSP Level 3 § 7.7.2
///
/// Arguments:
/// - policy: The CSP policy to check
/// - ancestors: List of ancestor origins (innermost to outermost)
///
/// Returns: true if all ancestors are allowed, false if any blocked
pub fn areAllAncestorsAllowed(
    policy: *const types.Policy,
    ancestors: []const types.Origin,
) bool {
    for (ancestors) |ancestor| {
        if (!isAncestorAllowed(policy, ancestor.scheme, ancestor.host, ancestor.port)) {
            return false;
        }
    }
    return true;
}

/// Check if frame-ancestors blocks all embedding (has 'none').
pub fn blocksAllFraming(policy: *const types.Policy) bool {
    const directive = policy.getDirective("frame-ancestors") orelse return false;
    return directive.value.isNone();
}

/// Check if frame-ancestors allows only same origin ('self').
pub fn allowsOnlySameOrigin(policy: *const types.Policy) bool {
    const directive = policy.getDirective("frame-ancestors") orelse return false;

    // Must have exactly one expression and it must be 'self'
    if (directive.value.expressions.items.len != 1) return false;
    return directive.value.expressions.items[0].type == .keyword_self;
}

// ============================================================================
// X-Frame-Options Compatibility
// ============================================================================

/// X-Frame-Options equivalent values
pub const XFrameOptionsEquivalent = enum {
    /// No equivalent (frame-ancestors allows more flexibility)
    none,
    /// Equivalent to X-Frame-Options: DENY
    deny,
    /// Equivalent to X-Frame-Options: SAMEORIGIN
    sameorigin,
};

/// Get the X-Frame-Options equivalent for this frame-ancestors directive.
/// This is useful for backward compatibility reporting.
pub fn getXFrameOptionsEquivalent(policy: *const types.Policy) XFrameOptionsEquivalent {
    const directive = policy.getDirective("frame-ancestors") orelse return .none;

    // 'none' is equivalent to DENY
    if (directive.value.isNone()) {
        return .deny;
    }

    // Single 'self' is equivalent to SAMEORIGIN
    if (directive.value.expressions.items.len == 1 and
        directive.value.expressions.items[0].type == .keyword_self)
    {
        return .sameorigin;
    }

    // Anything else has no direct X-Frame-Options equivalent
    return .none;
}

// ============================================================================
// Tests
// ============================================================================

test "isAncestorAllowed - no directive allows all" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    // No frame-ancestors directive - should allow everything
    try std.testing.expect(isAncestorAllowed(&policy, "https", "example.com", 443));
    try std.testing.expect(isAncestorAllowed(&policy, "https", "evil.com", 443));
}

test "isAncestorAllowed - none blocks all" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var directive = try types.Directive.create(allocator, "frame-ancestors");
    try directive.value.append(types.SourceExpression.createBorrowed(.keyword_none, "'none'"));
    try policy.directive_set.append(directive);

    // 'none' should block all framing
    try std.testing.expect(!isAncestorAllowed(&policy, "https", "example.com", 443));
    try std.testing.expect(!isAncestorAllowed(&policy, "https", "evil.com", 443));
}

test "isAncestorAllowed - self allows same origin" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    // Set self origin
    policy.self_origin = types.Origin.createBorrowed("https", "example.com", 443);

    var directive = try types.Directive.create(allocator, "frame-ancestors");
    try directive.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(directive);

    // Same origin should be allowed
    try std.testing.expect(isAncestorAllowed(&policy, "https", "example.com", 443));

    // Different origin should be blocked
    try std.testing.expect(!isAncestorAllowed(&policy, "https", "evil.com", 443));
}

test "blocksAllFraming" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    // No directive
    try std.testing.expect(!blocksAllFraming(&policy));

    // Add 'none'
    var directive = try types.Directive.create(allocator, "frame-ancestors");
    try directive.value.append(types.SourceExpression.createBorrowed(.keyword_none, "'none'"));
    try policy.directive_set.append(directive);

    try std.testing.expect(blocksAllFraming(&policy));
}

test "getXFrameOptionsEquivalent" {
    const allocator = std.testing.allocator;

    // No directive
    {
        var policy = types.Policy.init(allocator, .enforce, .header);
        defer policy.deinit();
        try std.testing.expectEqual(XFrameOptionsEquivalent.none, getXFrameOptionsEquivalent(&policy));
    }

    // 'none' = DENY
    {
        var policy = types.Policy.init(allocator, .enforce, .header);
        defer policy.deinit();

        var directive = try types.Directive.create(allocator, "frame-ancestors");
        try directive.value.append(types.SourceExpression.createBorrowed(.keyword_none, "'none'"));
        try policy.directive_set.append(directive);

        try std.testing.expectEqual(XFrameOptionsEquivalent.deny, getXFrameOptionsEquivalent(&policy));
    }

    // 'self' = SAMEORIGIN
    {
        var policy = types.Policy.init(allocator, .enforce, .header);
        defer policy.deinit();

        var directive = try types.Directive.create(allocator, "frame-ancestors");
        try directive.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
        try policy.directive_set.append(directive);

        try std.testing.expectEqual(XFrameOptionsEquivalent.sameorigin, getXFrameOptionsEquivalent(&policy));
    }
}
