//! Trusted Types - Factory Tests
//!
//! Tests for TrustedTypePolicyFactory - policy creation, management,
//! type checking, default policy, and sink type introspection.
//!
//! ## NOTE ON anyopaque IN THESE TESTS
//!
//! Some tests use `?*anyopaque` for callback context parameters. This is INTENTIONAL:
//!
//! 1. **Legacy pattern** (line ~83, ~298) - Shows the original API for backward compatibility
//! 2. **Typed pattern** (line ~326+) - Shows the preferred `makeUntypedCallback` approach
//!
//! Both patterns are tested to demonstrate the migration path from legacy to type-safe.

const std = @import("std");
const testing = std.testing;
const trusted_types = @import("trusted_types");

// ============================================================================
// Factory Initialization Tests
// ============================================================================

test "TrustedTypePolicyFactory - init and deinit" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    // Check empty instances
    try testing.expectEqualStrings("", factory.getEmptyHTML().toString());
    try testing.expectEqualStrings("", factory.getEmptyScript().toString());

    // Check default policy is null
    try testing.expectEqual(@as(?*trusted_types.TrustedTypePolicy, null), factory.getDefaultPolicy());
}

// ============================================================================
// Policy Creation Tests
// ============================================================================

test "TrustedTypePolicyFactory - createPolicy basic" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    const test_policy = try factory.createPolicy("test-policy", .{});

    try testing.expectEqualStrings("test-policy", test_policy.name);

    // Create HTML with the policy
    var html = try test_policy.createHTML("<div>test</div>", null);
    defer html.deinit();
    try testing.expectEqualStrings("<div>test</div>", html.toString());
}

test "TrustedTypePolicyFactory - createPolicy multiple policies" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    const policy1 = try factory.createPolicy("policy-1", .{});
    const policy2 = try factory.createPolicy("policy-2", .{});
    const policy3 = try factory.createPolicy("policy-3", .{});

    try testing.expectEqualStrings("policy-1", policy1.name);
    try testing.expectEqualStrings("policy-2", policy2.name);
    try testing.expectEqualStrings("policy-3", policy3.name);
}

test "TrustedTypePolicyFactory - createPolicy rejects duplicates" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    _ = try factory.createPolicy("unique", .{});

    // Second creation with same name should fail
    const result = factory.createPolicy("unique", .{});
    try testing.expectError(trusted_types.FactoryError.TypeError, result);
}

test "TrustedTypePolicyFactory - createPolicy with callbacks" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    const sanitize_callback = struct {
        fn callback(input: []const u8, _: ?*anyopaque) ?[]const u8 {
            // Reject <script> tags
            if (std.mem.indexOf(u8, input, "<script") != null) {
                return null;
            }
            return input;
        }
    }.callback;

    const policy = try factory.createPolicy("sanitizer", .{
        .createHTML = sanitize_callback,
    });

    // Safe content should pass
    var html = try policy.createHTML("<p>safe</p>", null);
    defer html.deinit();
    try testing.expectEqualStrings("<p>safe</p>", html.toString());

    // Dangerous content should be rejected
    const result = policy.createHTML("<script>evil()</script>", null);
    try testing.expectError(trusted_types.PolicyError.TypeError, result);
}

// ============================================================================
// Default Policy Tests
// ============================================================================

test "TrustedTypePolicyFactory - default policy creation" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    // Initially no default policy
    try testing.expectEqual(@as(?*trusted_types.TrustedTypePolicy, null), factory.getDefaultPolicy());

    // Create default policy
    const default_policy = try factory.createPolicy("default", .{});

    // Now default policy should be set
    try testing.expectEqual(default_policy, factory.getDefaultPolicy().?);
    try testing.expectEqualStrings("default", factory.getDefaultPolicy().?.name);
}

test "TrustedTypePolicyFactory - only 'default' name sets default policy" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    // Create non-default policies
    _ = try factory.createPolicy("not-default", .{});
    _ = try factory.createPolicy("also-not-default", .{});

    // Default should still be null
    try testing.expectEqual(@as(?*trusted_types.TrustedTypePolicy, null), factory.getDefaultPolicy());

    // Now create the actual default
    const default = try factory.createPolicy("default", .{});
    try testing.expectEqual(default, factory.getDefaultPolicy().?);
}

// ============================================================================
// Empty Instances Tests
// ============================================================================

test "TrustedTypePolicyFactory - emptyHTML" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    const empty_html = factory.getEmptyHTML();
    try testing.expectEqualStrings("", empty_html.toString());
    try testing.expectEqualStrings("", empty_html.toJSON());
}

test "TrustedTypePolicyFactory - emptyScript" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    const empty_script = factory.getEmptyScript();
    try testing.expectEqualStrings("", empty_script.toString());
    try testing.expectEqualStrings("", empty_script.toJSON());
}

// ============================================================================
// getPropertyType Tests
// ============================================================================

test "TrustedTypePolicyFactory - getPropertyType innerHTML" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    // innerHTML requires TrustedHTML on any element
    try testing.expectEqualStrings("TrustedHTML", factory.getPropertyType("div", "innerHTML", null).?);
    try testing.expectEqualStrings("TrustedHTML", factory.getPropertyType("span", "innerHTML", null).?);
    try testing.expectEqualStrings("TrustedHTML", factory.getPropertyType("p", "innerHTML", null).?);
}

test "TrustedTypePolicyFactory - getPropertyType outerHTML" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    try testing.expectEqualStrings("TrustedHTML", factory.getPropertyType("div", "outerHTML", null).?);
}

test "TrustedTypePolicyFactory - getPropertyType script.src" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    try testing.expectEqualStrings("TrustedScriptURL", factory.getPropertyType("script", "src", null).?);
}

test "TrustedTypePolicyFactory - getPropertyType script text properties" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    try testing.expectEqualStrings("TrustedScript", factory.getPropertyType("script", "text", null).?);
    try testing.expectEqualStrings("TrustedScript", factory.getPropertyType("script", "textContent", null).?);
    try testing.expectEqualStrings("TrustedScript", factory.getPropertyType("script", "innerText", null).?);
}

test "TrustedTypePolicyFactory - getPropertyType iframe.srcdoc" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    try testing.expectEqualStrings("TrustedHTML", factory.getPropertyType("iframe", "srcdoc", null).?);
}

test "TrustedTypePolicyFactory - getPropertyType returns null for non-sink" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    // Regular properties don't require Trusted Types
    try testing.expectEqual(@as(?[]const u8, null), factory.getPropertyType("div", "id", null));
    try testing.expectEqual(@as(?[]const u8, null), factory.getPropertyType("div", "className", null));
    try testing.expectEqual(@as(?[]const u8, null), factory.getPropertyType("input", "value", null));
    try testing.expectEqual(@as(?[]const u8, null), factory.getPropertyType("a", "href", null));
}

// ============================================================================
// getAttributeType Tests
// ============================================================================

test "TrustedTypePolicyFactory - getAttributeType event handlers" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    // All event handler attributes require TrustedScript
    try testing.expectEqualStrings("TrustedScript", factory.getAttributeType("button", "onclick", null, null).?);
    try testing.expectEqualStrings("TrustedScript", factory.getAttributeType("div", "onmouseover", null, null).?);
    try testing.expectEqualStrings("TrustedScript", factory.getAttributeType("form", "onsubmit", null, null).?);
    try testing.expectEqualStrings("TrustedScript", factory.getAttributeType("body", "onload", null, null).?);
    try testing.expectEqualStrings("TrustedScript", factory.getAttributeType("img", "onerror", null, null).?);
}

test "TrustedTypePolicyFactory - getAttributeType script.src" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    try testing.expectEqualStrings("TrustedScriptURL", factory.getAttributeType("script", "src", null, null).?);
}

test "TrustedTypePolicyFactory - getAttributeType iframe.srcdoc" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    try testing.expectEqualStrings("TrustedHTML", factory.getAttributeType("iframe", "srcdoc", null, null).?);
}

test "TrustedTypePolicyFactory - getAttributeType returns null for non-sink" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    // Regular attributes don't require Trusted Types
    try testing.expectEqual(@as(?[]const u8, null), factory.getAttributeType("div", "id", null, null));
    try testing.expectEqual(@as(?[]const u8, null), factory.getAttributeType("div", "class", null, null));
    try testing.expectEqual(@as(?[]const u8, null), factory.getAttributeType("a", "href", null, null));
    try testing.expectEqual(@as(?[]const u8, null), factory.getAttributeType("img", "src", null, null));
}

// ============================================================================
// Integration Tests
// ============================================================================

test "TrustedTypePolicyFactory - full workflow" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    // Create a sanitizing policy (legacy pattern)
    const sanitize_callback = struct {
        fn callback(input: []const u8, _: ?*anyopaque) ?[]const u8 {
            if (std.mem.indexOf(u8, input, "javascript:") != null) {
                return null;
            }
            return input;
        }
    }.callback;

    const policy = try factory.createPolicy("xss-prevention", .{
        .createHTML = sanitize_callback,
        .createScriptURL = sanitize_callback,
    });

    // Create safe content
    var html = try policy.createHTML("<a href='https://example.com'>Link</a>", null);
    defer html.deinit();
    try testing.expectEqualStrings("<a href='https://example.com'>Link</a>", html.toString());

    // Reject XSS attempt
    const xss_result = policy.createHTML("<a href='javascript:alert(1)'>XSS</a>", null);
    try testing.expectError(trusted_types.PolicyError.TypeError, xss_result);

    // Check sink types
    try testing.expectEqualStrings("TrustedHTML", factory.getPropertyType("div", "innerHTML", null).?);
    try testing.expectEqualStrings("TrustedScript", factory.getAttributeType("button", "onclick", null, null).?);
}

test "TrustedTypePolicyFactory - typed callback workflow" {
    const allocator = testing.allocator;

    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    // XSS prevention context with configurable blocked patterns
    const XSSPreventionContext = struct {
        blocked_patterns: []const []const u8,
        block_count: usize = 0,

        pub fn isBlocked(self: *@This(), input: []const u8) bool {
            for (self.blocked_patterns) |pattern| {
                if (std.mem.indexOf(u8, input, pattern) != null) {
                    self.block_count += 1;
                    return true;
                }
            }
            return false;
        }
    };

    var ctx = XSSPreventionContext{
        .blocked_patterns = &[_][]const u8{ "javascript:", "data:", "vbscript:" },
    };

    // Use typed callback pattern with makeUntypedCallback
    const untyped = trusted_types.makeUntypedCallback(XSSPreventionContext, struct {
        fn callback(context: *XSSPreventionContext, input: []const u8) ?[]const u8 {
            if (context.isBlocked(input)) {
                return null;
            }
            return input;
        }
    }.callback);

    const policy = try factory.createPolicy("typed-xss-prevention", .{
        .createHTML = untyped.callback,
        .createHTMLContext = @ptrCast(&ctx),
        .createScriptURL = untyped.callback,
        .createScriptURLContext = @ptrCast(&ctx),
    });

    // Create safe content
    var html = try policy.createHTML("<a href='https://example.com'>Link</a>", null);
    defer html.deinit();
    try testing.expectEqualStrings("<a href='https://example.com'>Link</a>", html.toString());

    // Reject XSS attempts - all blocked patterns should be caught
    try testing.expectError(trusted_types.PolicyError.TypeError, policy.createHTML("<a href='javascript:alert(1)'>XSS</a>", null));
    try testing.expectError(trusted_types.PolicyError.TypeError, policy.createHTML("<img src='data:text/html,<script>alert(1)</script>'>", null));
    try testing.expectError(trusted_types.PolicyError.TypeError, policy.createScriptURL("vbscript:msgbox", null));

    // Verify block count
    try testing.expectEqual(@as(usize, 3), ctx.block_count);
}
