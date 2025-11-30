//! Trusted Types - Policy Tests
//!
//! Tests for TrustedTypePolicy callback invocation, error handling, and name management.

const std = @import("std");
const testing = std.testing;
const trusted_types = @import("trusted_types");

// ============================================================================
// Policy Creation Tests
// ============================================================================

test "TrustedTypePolicy - create with name" {
    const allocator = testing.allocator;

    var policy = try trusted_types.TrustedTypePolicy.create(allocator, "my-policy", .{});
    defer policy.deinit();

    try testing.expectEqualStrings("my-policy", policy.name);
}

test "TrustedTypePolicy - create with empty name" {
    const allocator = testing.allocator;

    var policy = try trusted_types.TrustedTypePolicy.create(allocator, "", .{});
    defer policy.deinit();

    try testing.expectEqualStrings("", policy.name);
}

test "TrustedTypePolicy - borrowed name" {
    const allocator = testing.allocator;

    const static_name = "static-policy";
    var policy = trusted_types.TrustedTypePolicy.createWithBorrowedName(allocator, static_name, .{});
    defer policy.deinit(); // Should not free the static name

    try testing.expectEqualStrings("static-policy", policy.name);
}

// ============================================================================
// Identity Transformation (No Callback) Tests
// ============================================================================

test "TrustedTypePolicy - createHTML without callback passes through" {
    const allocator = testing.allocator;

    var policy = try trusted_types.TrustedTypePolicy.create(allocator, "passthrough", .{});
    defer policy.deinit();

    var html = try policy.createHTML("<div>test</div>", null);
    defer html.deinit();

    try testing.expectEqualStrings("<div>test</div>", html.toString());
}

test "TrustedTypePolicy - createScript without callback passes through" {
    const allocator = testing.allocator;

    var policy = try trusted_types.TrustedTypePolicy.create(allocator, "passthrough", .{});
    defer policy.deinit();

    var script = try policy.createScript("console.log('hello')", null);
    defer script.deinit();

    try testing.expectEqualStrings("console.log('hello')", script.toString());
}

test "TrustedTypePolicy - createScriptURL without callback passes through" {
    const allocator = testing.allocator;

    var policy = try trusted_types.TrustedTypePolicy.create(allocator, "passthrough", .{});
    defer policy.deinit();

    var url = try policy.createScriptURL("https://example.com/script.js", null);
    defer url.deinit();

    try testing.expectEqualStrings("https://example.com/script.js", url.toString());
}

// ============================================================================
// Callback Tests
// ============================================================================

test "TrustedTypePolicy - createHTML with callback" {
    const allocator = testing.allocator;

    // Callback that transforms input
    const transform_callback = struct {
        fn callback(_: []const u8, _: ?*anyopaque) ?[]const u8 {
            return "<TRANSFORMED>";
        }
    }.callback;

    var policy = try trusted_types.TrustedTypePolicy.create(allocator, "transformer", .{
        .createHTML = transform_callback,
    });
    defer policy.deinit();

    var html = try policy.createHTML("<div>original</div>", null);
    defer html.deinit();

    try testing.expectEqualStrings("<TRANSFORMED>", html.toString());
}

test "TrustedTypePolicy - createScript with callback" {
    const allocator = testing.allocator;

    const transform_callback = struct {
        fn callback(input: []const u8, _: ?*anyopaque) ?[]const u8 {
            // Simple passthrough for valid input
            return input;
        }
    }.callback;

    var policy = try trusted_types.TrustedTypePolicy.create(allocator, "validator", .{
        .createScript = transform_callback,
    });
    defer policy.deinit();

    var script = try policy.createScript("safe_function()", null);
    defer script.deinit();

    try testing.expectEqualStrings("safe_function()", script.toString());
}

test "TrustedTypePolicy - createScriptURL with callback" {
    const allocator = testing.allocator;

    const validate_url_callback = struct {
        fn callback(input: []const u8, _: ?*anyopaque) ?[]const u8 {
            // Only allow HTTPS URLs
            if (std.mem.startsWith(u8, input, "https://")) {
                return input;
            }
            return null;
        }
    }.callback;

    var policy = try trusted_types.TrustedTypePolicy.create(allocator, "url-validator", .{
        .createScriptURL = validate_url_callback,
    });
    defer policy.deinit();

    // HTTPS URL should pass
    var url = try policy.createScriptURL("https://example.com/script.js", null);
    defer url.deinit();
    try testing.expectEqualStrings("https://example.com/script.js", url.toString());

    // HTTP URL should be rejected
    const result = policy.createScriptURL("http://example.com/script.js", null);
    try testing.expectError(trusted_types.PolicyError.TypeError, result);
}

// ============================================================================
// Error Handling Tests
// ============================================================================

test "TrustedTypePolicy - callback returning null throws TypeError" {
    const allocator = testing.allocator;

    const reject_all_callback = struct {
        fn callback(_: []const u8, _: ?*anyopaque) ?[]const u8 {
            return null;
        }
    }.callback;

    var policy = try trusted_types.TrustedTypePolicy.create(allocator, "reject-all", .{
        .createHTML = reject_all_callback,
        .createScript = reject_all_callback,
        .createScriptURL = reject_all_callback,
    });
    defer policy.deinit();

    // All create methods should return TypeError
    try testing.expectError(trusted_types.PolicyError.TypeError, policy.createHTML("anything", null));
    try testing.expectError(trusted_types.PolicyError.TypeError, policy.createScript("anything", null));
    try testing.expectError(trusted_types.PolicyError.TypeError, policy.createScriptURL("anything", null));
}

test "TrustedTypePolicy - sanitization callback rejects dangerous input" {
    const allocator = testing.allocator;

    const sanitize_callback = struct {
        fn callback(input: []const u8, _: ?*anyopaque) ?[]const u8 {
            // Reject input containing <script>
            if (std.mem.indexOf(u8, input, "<script") != null) {
                return null;
            }
            return input;
        }
    }.callback;

    var policy = try trusted_types.TrustedTypePolicy.create(allocator, "sanitizer", .{
        .createHTML = sanitize_callback,
    });
    defer policy.deinit();

    // Safe input should pass
    var safe_html = try policy.createHTML("<p>Safe content</p>", null);
    defer safe_html.deinit();
    try testing.expectEqualStrings("<p>Safe content</p>", safe_html.toString());

    // Dangerous input should be rejected
    const result = policy.createHTML("<script>evil()</script>", null);
    try testing.expectError(trusted_types.PolicyError.TypeError, result);
}

// ============================================================================
// Context Passing Tests
// ============================================================================

test "TrustedTypePolicy - callback receives context" {
    const allocator = testing.allocator;

    const Context = struct {
        prefix: []const u8,
    };

    const context_callback = struct {
        fn callback(_: []const u8, ctx: ?*anyopaque) ?[]const u8 {
            if (ctx) |c| {
                const context: *const Context = @ptrCast(@alignCast(c));
                return context.prefix;
            }
            return null;
        }
    }.callback;

    var policy = try trusted_types.TrustedTypePolicy.create(allocator, "context-aware", .{
        .createHTML = context_callback,
    });
    defer policy.deinit();

    var context = Context{ .prefix = "<safe>" };

    var html = try policy.createHTML("ignored", @ptrCast(&context));
    defer html.deinit();

    try testing.expectEqualStrings("<safe>", html.toString());
}

// ============================================================================
// Mixed Callback Configuration Tests
// ============================================================================

test "TrustedTypePolicy - partial callback configuration" {
    const allocator = testing.allocator;

    const html_callback = struct {
        fn callback(_: []const u8, _: ?*anyopaque) ?[]const u8 {
            return "<html-transformed>";
        }
    }.callback;

    // Only configure createHTML callback, others use identity
    var policy = try trusted_types.TrustedTypePolicy.create(allocator, "partial", .{
        .createHTML = html_callback,
        // createScript and createScriptURL are null - use identity
    });
    defer policy.deinit();

    // HTML uses callback
    var html = try policy.createHTML("input", null);
    defer html.deinit();
    try testing.expectEqualStrings("<html-transformed>", html.toString());

    // Script uses identity
    var script = try policy.createScript("console.log(1)", null);
    defer script.deinit();
    try testing.expectEqualStrings("console.log(1)", script.toString());

    // ScriptURL uses identity
    var url = try policy.createScriptURL("https://example.com", null);
    defer url.deinit();
    try testing.expectEqualStrings("https://example.com", url.toString());
}
