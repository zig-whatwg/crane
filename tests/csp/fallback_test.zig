//! CSP Fallback Chain Unit Tests
//!
//! Tests for CSP directive fallback resolution.

const std = @import("std");
const testing = std.testing;
const csp = @import("csp");
const types = csp.types;
const fallback = csp.fallback;

// ============================================================================
// script-src-elem Fallback Tests
// ============================================================================

test "script-src-elem fallback chain" {
    const chain = fallback.getFallbackChain("script-src-elem");

    try testing.expectEqual(@as(usize, 3), chain.len);
    try testing.expectEqualStrings("script-src-elem", chain[0]);
    try testing.expectEqualStrings("script-src", chain[1]);
    try testing.expectEqualStrings("default-src", chain[2]);
}

test "script-src-elem falls back to script-src" {
    const allocator = testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    // Only have script-src
    var script_src = try types.Directive.create(allocator, "script-src");
    try script_src.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(script_src);

    const effective = fallback.getEffectiveDirective(&policy, "script-src-elem");
    try testing.expect(effective != null);
    try testing.expectEqualStrings("script-src", effective.?.name);
}

test "script-src-elem falls back to default-src" {
    const allocator = testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    // Only have default-src
    var default_src = try types.Directive.create(allocator, "default-src");
    try default_src.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(default_src);

    const effective = fallback.getEffectiveDirective(&policy, "script-src-elem");
    try testing.expect(effective != null);
    try testing.expectEqualStrings("default-src", effective.?.name);
}

test "script-src-elem uses most specific directive" {
    const allocator = testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    // Have both default-src and script-src
    var default_src = try types.Directive.create(allocator, "default-src");
    try default_src.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(default_src);

    var script_src = try types.Directive.create(allocator, "script-src");
    try script_src.value.append(types.SourceExpression.createBorrowed(.scheme, "https:"));
    try policy.directive_set.append(script_src);

    // Should use script-src (more specific)
    const effective = fallback.getEffectiveDirective(&policy, "script-src-elem");
    try testing.expect(effective != null);
    try testing.expectEqualStrings("script-src", effective.?.name);
    try testing.expect(effective.?.value.contains(.scheme));
}

// ============================================================================
// script-src-attr Fallback Tests
// ============================================================================

test "script-src-attr fallback chain" {
    const chain = fallback.getFallbackChain("script-src-attr");

    try testing.expectEqual(@as(usize, 3), chain.len);
    try testing.expectEqualStrings("script-src-attr", chain[0]);
    try testing.expectEqualStrings("script-src", chain[1]);
    try testing.expectEqualStrings("default-src", chain[2]);
}

// ============================================================================
// worker-src Fallback Tests
// ============================================================================

test "worker-src fallback chain" {
    const chain = fallback.getFallbackChain("worker-src");

    try testing.expectEqual(@as(usize, 4), chain.len);
    try testing.expectEqualStrings("worker-src", chain[0]);
    try testing.expectEqualStrings("child-src", chain[1]);
    try testing.expectEqualStrings("script-src", chain[2]);
    try testing.expectEqualStrings("default-src", chain[3]);
}

test "worker-src falls back to child-src" {
    const allocator = testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var child_src = try types.Directive.create(allocator, "child-src");
    try child_src.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(child_src);

    const effective = fallback.getEffectiveDirective(&policy, "worker-src");
    try testing.expect(effective != null);
    try testing.expectEqualStrings("child-src", effective.?.name);
}

test "worker-src falls back to script-src" {
    const allocator = testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var script_src = try types.Directive.create(allocator, "script-src");
    try script_src.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(script_src);

    const effective = fallback.getEffectiveDirective(&policy, "worker-src");
    try testing.expect(effective != null);
    try testing.expectEqualStrings("script-src", effective.?.name);
}

// ============================================================================
// frame-src Fallback Tests
// ============================================================================

test "frame-src fallback chain" {
    const chain = fallback.getFallbackChain("frame-src");

    try testing.expectEqual(@as(usize, 3), chain.len);
    try testing.expectEqualStrings("frame-src", chain[0]);
    try testing.expectEqualStrings("child-src", chain[1]);
    try testing.expectEqualStrings("default-src", chain[2]);
}

// ============================================================================
// style-src Fallback Tests
// ============================================================================

test "style-src-elem fallback chain" {
    const chain = fallback.getFallbackChain("style-src-elem");

    try testing.expectEqual(@as(usize, 3), chain.len);
    try testing.expectEqualStrings("style-src-elem", chain[0]);
    try testing.expectEqualStrings("style-src", chain[1]);
    try testing.expectEqualStrings("default-src", chain[2]);
}

test "style-src-attr fallback chain" {
    const chain = fallback.getFallbackChain("style-src-attr");

    try testing.expectEqual(@as(usize, 3), chain.len);
    try testing.expectEqualStrings("style-src-attr", chain[0]);
    try testing.expectEqualStrings("style-src", chain[1]);
    try testing.expectEqualStrings("default-src", chain[2]);
}

// ============================================================================
// Other Fetch Directives Fallback Tests
// ============================================================================

test "connect-src fallback chain" {
    const chain = fallback.getFallbackChain("connect-src");

    try testing.expectEqual(@as(usize, 2), chain.len);
    try testing.expectEqualStrings("connect-src", chain[0]);
    try testing.expectEqualStrings("default-src", chain[1]);
}

test "img-src fallback chain" {
    const chain = fallback.getFallbackChain("img-src");

    try testing.expectEqual(@as(usize, 2), chain.len);
    try testing.expectEqualStrings("img-src", chain[0]);
    try testing.expectEqualStrings("default-src", chain[1]);
}

test "font-src fallback chain" {
    const chain = fallback.getFallbackChain("font-src");

    try testing.expectEqual(@as(usize, 2), chain.len);
    try testing.expectEqualStrings("font-src", chain[0]);
    try testing.expectEqualStrings("default-src", chain[1]);
}

test "media-src fallback chain" {
    const chain = fallback.getFallbackChain("media-src");

    try testing.expectEqual(@as(usize, 2), chain.len);
    try testing.expectEqualStrings("media-src", chain[0]);
    try testing.expectEqualStrings("default-src", chain[1]);
}

test "object-src fallback chain" {
    const chain = fallback.getFallbackChain("object-src");

    try testing.expectEqual(@as(usize, 2), chain.len);
    try testing.expectEqualStrings("object-src", chain[0]);
    try testing.expectEqualStrings("default-src", chain[1]);
}

test "manifest-src fallback chain" {
    const chain = fallback.getFallbackChain("manifest-src");

    try testing.expectEqual(@as(usize, 2), chain.len);
    try testing.expectEqualStrings("manifest-src", chain[0]);
    try testing.expectEqualStrings("default-src", chain[1]);
}

// ============================================================================
// Unknown Directive Tests
// ============================================================================

test "unknown directive returns empty fallback" {
    const chain = fallback.getFallbackChain("unknown-directive");

    try testing.expectEqual(@as(usize, 1), chain.len);
    try testing.expectEqualStrings("unknown-directive", chain[0]);
}

// ============================================================================
// Effective Directive Resolution Tests
// ============================================================================

test "getEffectiveDirective - no matching directive" {
    const allocator = testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();
    // Empty policy

    const effective = fallback.getEffectiveDirective(&policy, "script-src");
    try testing.expect(effective == null);
}

test "getEffectiveDirective - exact match takes precedence" {
    const allocator = testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var default_src = try types.Directive.create(allocator, "default-src");
    try default_src.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(default_src);

    var script_src = try types.Directive.create(allocator, "script-src");
    try script_src.value.append(types.SourceExpression.createBorrowed(.scheme, "https:"));
    try policy.directive_set.append(script_src);

    var script_src_elem = try types.Directive.create(allocator, "script-src-elem");
    try script_src_elem.value.append(types.SourceExpression.createBorrowed(.keyword_none, "'none'"));
    try policy.directive_set.append(script_src_elem);

    // Should use script-src-elem (most specific)
    const effective = fallback.getEffectiveDirective(&policy, "script-src-elem");
    try testing.expect(effective != null);
    try testing.expectEqualStrings("script-src-elem", effective.?.name);
    try testing.expect(effective.?.value.contains(.keyword_none));
}

// ============================================================================
// getMatchingDirectiveName Tests
// ============================================================================

test "getMatchingDirectiveName" {
    const allocator = testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    const default_src = try types.Directive.create(allocator, "default-src");
    try policy.directive_set.append(default_src);

    // Looking for script-src-elem, but only default-src exists
    const name = fallback.getMatchingDirectiveName(&policy, "script-src-elem");
    try testing.expect(name != null);
    try testing.expectEqualStrings("default-src", name.?);
}

test "getMatchingDirectiveName - no match" {
    const allocator = testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();
    // Empty policy

    const name = fallback.getMatchingDirectiveName(&policy, "script-src");
    try testing.expect(name == null);
}

// ============================================================================
// hasFallback Tests
// ============================================================================

test "hasFallback" {
    // Directives with fallbacks
    try testing.expect(fallback.hasFallback("script-src-elem"));
    try testing.expect(fallback.hasFallback("worker-src"));
    try testing.expect(fallback.hasFallback("connect-src"));

    // Unknown directives have no fallback
    try testing.expect(!fallback.hasFallback("base-uri"));
    try testing.expect(!fallback.hasFallback("form-action"));
    try testing.expect(!fallback.hasFallback("unknown-directive"));
}

// ============================================================================
// Convenience Function Tests
// ============================================================================

test "getEffectiveScriptSrc" {
    const allocator = testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var default_src = try types.Directive.create(allocator, "default-src");
    try default_src.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(default_src);

    const effective = fallback.getEffectiveScriptSrc(&policy);
    try testing.expect(effective != null);
    try testing.expectEqualStrings("default-src", effective.?.name);
}

test "getEffectiveScriptSrcElem" {
    const allocator = testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var script_src = try types.Directive.create(allocator, "script-src");
    try script_src.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(script_src);

    const effective = fallback.getEffectiveScriptSrcElem(&policy);
    try testing.expect(effective != null);
    try testing.expectEqualStrings("script-src", effective.?.name);
}

test "getEffectiveStyleSrc" {
    const allocator = testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var style_src = try types.Directive.create(allocator, "style-src");
    try style_src.value.append(types.SourceExpression.createBorrowed(.keyword_unsafe_inline, "'unsafe-inline'"));
    try policy.directive_set.append(style_src);

    const effective = fallback.getEffectiveStyleSrc(&policy);
    try testing.expect(effective != null);
    try testing.expectEqualStrings("style-src", effective.?.name);
}

test "getEffectiveConnectSrc" {
    const allocator = testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var connect_src = try types.Directive.create(allocator, "connect-src");
    try connect_src.value.append(types.SourceExpression.createBorrowed(.scheme, "https:"));
    try policy.directive_set.append(connect_src);

    const effective = fallback.getEffectiveConnectSrc(&policy);
    try testing.expect(effective != null);
    try testing.expectEqualStrings("connect-src", effective.?.name);
}

test "getEffectiveFrameSrc" {
    const allocator = testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var child_src = try types.Directive.create(allocator, "child-src");
    try child_src.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(child_src);

    const effective = fallback.getEffectiveFrameSrc(&policy);
    try testing.expect(effective != null);
    try testing.expectEqualStrings("child-src", effective.?.name);
}

test "getEffectiveWorkerSrc" {
    const allocator = testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var default_src = try types.Directive.create(allocator, "default-src");
    try default_src.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(default_src);

    const effective = fallback.getEffectiveWorkerSrc(&policy);
    try testing.expect(effective != null);
    try testing.expectEqualStrings("default-src", effective.?.name);
}
