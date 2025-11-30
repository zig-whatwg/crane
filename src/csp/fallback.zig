//! CSP Directive Fallback Chains
//!
//! W3C Content Security Policy Level 3
//! Spec: https://www.w3.org/TR/CSP3/ § 6.8.3
//!
//! This module implements directive fallback resolution.
//! When a specific directive is not present, CSP falls back to more general directives.

const std = @import("std");
const types = @import("types.zig");

// ============================================================================
// Fallback Chain Definition
// ============================================================================

/// Directive fallback chains as defined in CSP Level 3 § 6.8.3
/// Each entry is: [effective_directive, fallback1, fallback2, ...]
/// The chain is tried in order until a directive is found.
pub const FallbackChain = struct {
    effective: []const u8,
    chain: []const []const u8,
};

/// All fallback chains for fetch directives
pub const fallback_chains = [_]FallbackChain{
    // script-src-elem → script-src → default-src
    .{ .effective = "script-src-elem", .chain = &.{ "script-src-elem", "script-src", "default-src" } },

    // script-src-attr → script-src → default-src
    .{ .effective = "script-src-attr", .chain = &.{ "script-src-attr", "script-src", "default-src" } },

    // style-src-elem → style-src → default-src
    .{ .effective = "style-src-elem", .chain = &.{ "style-src-elem", "style-src", "default-src" } },

    // style-src-attr → style-src → default-src
    .{ .effective = "style-src-attr", .chain = &.{ "style-src-attr", "style-src", "default-src" } },

    // worker-src → child-src → script-src → default-src
    .{ .effective = "worker-src", .chain = &.{ "worker-src", "child-src", "script-src", "default-src" } },

    // connect-src → default-src
    .{ .effective = "connect-src", .chain = &.{ "connect-src", "default-src" } },

    // frame-src → child-src → default-src
    .{ .effective = "frame-src", .chain = &.{ "frame-src", "child-src", "default-src" } },

    // img-src → default-src
    .{ .effective = "img-src", .chain = &.{ "img-src", "default-src" } },

    // font-src → default-src
    .{ .effective = "font-src", .chain = &.{ "font-src", "default-src" } },

    // media-src → default-src
    .{ .effective = "media-src", .chain = &.{ "media-src", "default-src" } },

    // object-src → default-src
    .{ .effective = "object-src", .chain = &.{ "object-src", "default-src" } },

    // manifest-src → default-src
    .{ .effective = "manifest-src", .chain = &.{ "manifest-src", "default-src" } },

    // prefetch-src → default-src
    .{ .effective = "prefetch-src", .chain = &.{ "prefetch-src", "default-src" } },

    // child-src → default-src (used by worker-src and frame-src fallback)
    .{ .effective = "child-src", .chain = &.{ "child-src", "default-src" } },

    // script-src → default-src (base directive)
    .{ .effective = "script-src", .chain = &.{ "script-src", "default-src" } },

    // style-src → default-src (base directive)
    .{ .effective = "style-src", .chain = &.{ "style-src", "default-src" } },
};

// ============================================================================
// Fallback Resolution
// ============================================================================

/// Get the effective directive value using fallback chain.
/// Spec: CSP Level 3 § 6.8.3
///
/// Arguments:
/// - policy: The policy to search in
/// - effective_directive: The directive we're looking for (e.g., "script-src-elem")
///
/// Returns: The directive value from the first matching directive in the fallback chain,
///          or null if no directive in the chain is present.
pub fn getEffectiveDirective(
    policy: *const types.Policy,
    effective_directive: []const u8,
) ?*const types.Directive {
    // Find the fallback chain for this directive
    const chain = getFallbackChain(effective_directive);

    // Try each directive in the chain
    for (chain) |directive_name| {
        if (policy.getDirective(directive_name)) |directive| {
            return directive;
        }
    }

    return null;
}

/// Get the fallback chain for a directive.
/// Returns the full chain including the directive itself.
pub fn getFallbackChain(effective_directive: []const u8) []const []const u8 {
    for (fallback_chains) |fc| {
        if (std.mem.eql(u8, fc.effective, effective_directive)) {
            return fc.chain;
        }
    }

    // For unknown directives, return just the directive itself
    // (no fallback - it either exists or doesn't)
    return &.{effective_directive};
}

/// Get the name of the directive that actually matched in the fallback chain.
/// This is needed for violation reporting (violated-directive vs effective-directive).
pub fn getMatchingDirectiveName(
    policy: *const types.Policy,
    effective_directive: []const u8,
) ?[]const u8 {
    const chain = getFallbackChain(effective_directive);

    for (chain) |directive_name| {
        if (policy.containsDirective(directive_name)) {
            return directive_name;
        }
    }

    return null;
}

/// Check if a directive should use fallback.
/// Some directives (like base-uri, form-action) don't have fallbacks.
pub fn hasFallback(directive_name: []const u8) bool {
    for (fallback_chains) |fc| {
        if (std.mem.eql(u8, fc.effective, directive_name)) {
            return fc.chain.len > 1;
        }
    }
    return false;
}

// ============================================================================
// Convenience Functions for Common Directives
// ============================================================================

/// Get the effective script-src directive (for inline scripts).
pub fn getEffectiveScriptSrc(policy: *const types.Policy) ?*const types.Directive {
    return getEffectiveDirective(policy, "script-src");
}

/// Get the effective script-src-elem directive (for <script> elements).
pub fn getEffectiveScriptSrcElem(policy: *const types.Policy) ?*const types.Directive {
    return getEffectiveDirective(policy, "script-src-elem");
}

/// Get the effective script-src-attr directive (for event handlers).
pub fn getEffectiveScriptSrcAttr(policy: *const types.Policy) ?*const types.Directive {
    return getEffectiveDirective(policy, "script-src-attr");
}

/// Get the effective style-src directive.
pub fn getEffectiveStyleSrc(policy: *const types.Policy) ?*const types.Directive {
    return getEffectiveDirective(policy, "style-src");
}

/// Get the effective img-src directive.
pub fn getEffectiveImgSrc(policy: *const types.Policy) ?*const types.Directive {
    return getEffectiveDirective(policy, "img-src");
}

/// Get the effective connect-src directive (for fetch, XHR, WebSocket).
pub fn getEffectiveConnectSrc(policy: *const types.Policy) ?*const types.Directive {
    return getEffectiveDirective(policy, "connect-src");
}

/// Get the effective frame-src directive (for iframes).
pub fn getEffectiveFrameSrc(policy: *const types.Policy) ?*const types.Directive {
    return getEffectiveDirective(policy, "frame-src");
}

/// Get the effective worker-src directive (for workers).
pub fn getEffectiveWorkerSrc(policy: *const types.Policy) ?*const types.Directive {
    return getEffectiveDirective(policy, "worker-src");
}

// ============================================================================
// Tests
// ============================================================================

test "getFallbackChain - script-src-elem" {
    const chain = getFallbackChain("script-src-elem");

    try std.testing.expectEqual(@as(usize, 3), chain.len);
    try std.testing.expectEqualStrings("script-src-elem", chain[0]);
    try std.testing.expectEqualStrings("script-src", chain[1]);
    try std.testing.expectEqualStrings("default-src", chain[2]);
}

test "getFallbackChain - worker-src" {
    const chain = getFallbackChain("worker-src");

    try std.testing.expectEqual(@as(usize, 4), chain.len);
    try std.testing.expectEqualStrings("worker-src", chain[0]);
    try std.testing.expectEqualStrings("child-src", chain[1]);
    try std.testing.expectEqualStrings("script-src", chain[2]);
    try std.testing.expectEqualStrings("default-src", chain[3]);
}

test "getFallbackChain - unknown directive" {
    const chain = getFallbackChain("unknown-directive");

    try std.testing.expectEqual(@as(usize, 1), chain.len);
    try std.testing.expectEqualStrings("unknown-directive", chain[0]);
}

test "getEffectiveDirective - uses fallback" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    // Add only default-src
    var default_src = try types.Directive.create(allocator, "default-src");
    try default_src.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(default_src);

    // script-src-elem should fall back to default-src
    const effective = getEffectiveDirective(&policy, "script-src-elem");
    try std.testing.expect(effective != null);
    try std.testing.expectEqualStrings("default-src", effective.?.name);
}

test "getEffectiveDirective - specific directive takes precedence" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    // Add both default-src and script-src
    var default_src = try types.Directive.create(allocator, "default-src");
    try default_src.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(default_src);

    var script_src = try types.Directive.create(allocator, "script-src");
    try script_src.value.append(types.SourceExpression.createBorrowed(.scheme, "https:"));
    try policy.directive_set.append(script_src);

    // script-src-elem should use script-src (not default-src)
    const effective = getEffectiveDirective(&policy, "script-src-elem");
    try std.testing.expect(effective != null);
    try std.testing.expectEqualStrings("script-src", effective.?.name);
    try std.testing.expect(effective.?.value.contains(.scheme));
}

test "getMatchingDirectiveName" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    const default_src = try types.Directive.create(allocator, "default-src");
    try policy.directive_set.append(default_src);

    const name = getMatchingDirectiveName(&policy, "script-src-elem");
    try std.testing.expect(name != null);
    try std.testing.expectEqualStrings("default-src", name.?);
}

test "hasFallback" {
    try std.testing.expect(hasFallback("script-src-elem")); // has 3-level fallback
    try std.testing.expect(hasFallback("worker-src")); // has 4-level fallback
    try std.testing.expect(!hasFallback("base-uri")); // no fallback defined
}
