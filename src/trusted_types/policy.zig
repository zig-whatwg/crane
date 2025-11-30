//! TrustedTypePolicy Implementation
//!
//! W3C Trusted Types Spec: https://w3c.github.io/trusted-types/dist/spec/
//!
//! This module implements TrustedTypePolicy which creates Trusted Types
//! using user-defined callback functions for validation/transformation.
//!
//! WebIDL:
//! ```webidl
//! [Exposed=(Window,Worker)]
//! interface TrustedTypePolicy {
//!   readonly attribute DOMString name;
//!   TrustedHTML createHTML(DOMString input, any... arguments);
//!   TrustedScript createScript(DOMString input, any... arguments);
//!   TrustedScriptURL createScriptURL(DOMString input, any... arguments);
//! };
//!
//! dictionary TrustedTypePolicyOptions {
//!    CreateHTMLCallback createHTML;
//!    CreateScriptCallback createScript;
//!    CreateScriptURLCallback createScriptURL;
//! };
//! ```

const std = @import("std");
const types = @import("types.zig");

pub const TrustedHTML = types.TrustedHTML;
pub const TrustedScript = types.TrustedScript;
pub const TrustedScriptURL = types.TrustedScriptURL;

/// Error type for policy operations
pub const PolicyError = error{
    /// Callback returned null, indicating the input should not be trusted
    TypeError,
    /// Allocation failed
    OutOfMemory,
    /// Callback threw an exception (for future JS integration)
    CallbackException,
};

/// Callback function type for creating TrustedHTML.
/// Per spec: `callback CreateHTMLCallback = DOMString? (DOMString input, any... arguments);`
///
/// In Zig, we model variadic arguments as an optional slice of opaque data.
/// The actual argument handling will be done at the JS binding layer.
///
/// Returns: The transformed string, or null to indicate the input should be rejected.
pub const CreateHTMLCallback = *const fn (
    input: []const u8,
    /// Opaque user data passed through from the caller
    context: ?*anyopaque,
) ?[]const u8;

/// Callback function type for creating TrustedScript.
/// Per spec: `callback CreateScriptCallback = DOMString? (DOMString input, any... arguments);`
pub const CreateScriptCallback = *const fn (
    input: []const u8,
    context: ?*anyopaque,
) ?[]const u8;

/// Callback function type for creating TrustedScriptURL.
/// Per spec: `callback CreateScriptURLCallback = USVString? (DOMString input, any... arguments);`
pub const CreateScriptURLCallback = *const fn (
    input: []const u8,
    context: ?*anyopaque,
) ?[]const u8;

/// TrustedTypePolicyOptions - Configuration for policy behavior.
///
/// Per spec dictionary:
/// ```webidl
/// dictionary TrustedTypePolicyOptions {
///    CreateHTMLCallback createHTML;
///    CreateScriptCallback createScript;
///    CreateScriptURLCallback createScriptURL;
/// };
/// ```
///
/// All callbacks are optional. When not provided, the corresponding create*
/// method will pass the input through unchanged (identity transformation).
pub const TrustedTypePolicyOptions = struct {
    /// Callback for creating TrustedHTML values
    createHTML: ?CreateHTMLCallback = null,
    /// Callback for creating TrustedScript values
    createScript: ?CreateScriptCallback = null,
    /// Callback for creating TrustedScriptURL values
    createScriptURL: ?CreateScriptURLCallback = null,
};

/// TrustedTypePolicy - Creates Trusted Types with custom validation logic.
///
/// Spec: https://w3c.github.io/trusted-types/dist/spec/#trusted-type-policy
///
/// A policy encapsulates the rules for converting untrusted strings into
/// Trusted Types. Each policy has a name and a set of callback functions
/// that perform the actual transformation/validation.
///
/// ## Internal Slots (per spec)
/// - [[name]]: The policy's name
/// - [[options]]: The TrustedTypePolicyOptions
///
/// ## Example Usage
/// ```zig
/// // Define a sanitizing callback
/// fn sanitizeHTML(input: []const u8, ctx: ?*anyopaque) ?[]const u8 {
///     _ = ctx;
///     // Simple example: strip script tags (real impl would be more robust)
///     if (std.mem.indexOf(u8, input, "<script") != null) {
///         return null; // Reject input with script tags
///     }
///     return input;
/// }
///
/// // Create policy with the callback
/// var policy = try TrustedTypePolicy.create(allocator, "sanitizer", .{
///     .createHTML = sanitizeHTML,
/// });
/// defer policy.deinit();
///
/// // Use policy to create trusted values
/// var html = try policy.createHTML("<p>Safe content</p>", null);
/// defer html.deinit();
/// ```
pub const TrustedTypePolicy = struct {
    /// Policy name (readonly after creation).
    /// Per spec: "readonly attribute DOMString name"
    name: []const u8,

    /// Policy options containing the callback functions.
    /// Per spec internal slot [[options]]
    options: TrustedTypePolicyOptions,

    /// Allocator for creating trusted type values
    allocator: std.mem.Allocator,

    /// Whether this policy owns the name string (should free on deinit)
    owns_name: bool = true,

    const Self = @This();

    /// Create a new TrustedTypePolicy.
    ///
    /// This is an internal constructor - policies should be created through
    /// TrustedTypePolicyFactory.createPolicy() in normal usage.
    ///
    /// Arguments:
    /// - allocator: Allocator for the policy and created values
    /// - name: Policy name (will be copied)
    /// - options: Callback functions for creating trusted values
    pub fn create(
        allocator: std.mem.Allocator,
        name: []const u8,
        options: TrustedTypePolicyOptions,
    ) !Self {
        const name_copy = try allocator.dupe(u8, name);
        return Self{
            .name = name_copy,
            .options = options,
            .allocator = allocator,
            .owns_name = true,
        };
    }

    /// Create a policy without copying the name (caller manages name lifetime).
    pub fn createWithBorrowedName(
        allocator: std.mem.Allocator,
        name: []const u8,
        options: TrustedTypePolicyOptions,
    ) Self {
        return Self{
            .name = name,
            .options = options,
            .allocator = allocator,
            .owns_name = false,
        };
    }

    /// Create a TrustedHTML value.
    ///
    /// Spec: https://w3c.github.io/trusted-types/dist/spec/#dom-trustedtypepolicy-createhtml
    ///
    /// Algorithm:
    /// 1. Let callback be this's options's createHTML.
    /// 2. Let policyValue be the result of invoking callback with arguments.
    /// 3. If callback threw an exception, rethrow the exception.
    /// 4. If policyValue is null, throw a TypeError.
    /// 5. Return a new TrustedHTML object with [[Data]] set to policyValue.
    ///
    /// Arguments:
    /// - input: The string to transform into TrustedHTML
    /// - context: Optional opaque context passed to the callback
    ///
    /// Returns: A new TrustedHTML value, or an error
    pub fn createHTML(
        self: *const Self,
        input: []const u8,
        context: ?*anyopaque,
    ) PolicyError!TrustedHTML {
        // Step 1: Get callback
        const callback = self.options.createHTML;

        // Step 2: Invoke callback (or use identity if no callback)
        const policy_value: []const u8 = if (callback) |cb| blk: {
            // Invoke the callback
            const result = cb(input, context);

            // Step 4: If callback returned null, throw TypeError
            break :blk result orelse return PolicyError.TypeError;
        } else input; // No callback - use input unchanged (identity transformation)

        // Step 5: Create and return new TrustedHTML
        return TrustedHTML.create(self.allocator, policy_value) catch |err| switch (err) {
            error.OutOfMemory => return PolicyError.OutOfMemory,
        };
    }

    /// Create a TrustedScript value.
    ///
    /// Spec: https://w3c.github.io/trusted-types/dist/spec/#dom-trustedtypepolicy-createscript
    ///
    /// Same algorithm as createHTML but creates TrustedScript.
    pub fn createScript(
        self: *const Self,
        input: []const u8,
        context: ?*anyopaque,
    ) PolicyError!TrustedScript {
        const callback = self.options.createScript;

        const policy_value: []const u8 = if (callback) |cb| blk: {
            const result = cb(input, context);
            break :blk result orelse return PolicyError.TypeError;
        } else input;

        return TrustedScript.create(self.allocator, policy_value) catch |err| switch (err) {
            error.OutOfMemory => return PolicyError.OutOfMemory,
        };
    }

    /// Create a TrustedScriptURL value.
    ///
    /// Spec: https://w3c.github.io/trusted-types/dist/spec/#dom-trustedtypepolicy-createscripturl
    ///
    /// Same algorithm as createHTML but creates TrustedScriptURL.
    /// Note: Per spec, this returns USVString, so proper Unicode handling
    /// should be applied. For now we treat it as a regular string.
    pub fn createScriptURL(
        self: *const Self,
        input: []const u8,
        context: ?*anyopaque,
    ) PolicyError!TrustedScriptURL {
        const callback = self.options.createScriptURL;

        const policy_value: []const u8 = if (callback) |cb| blk: {
            const result = cb(input, context);
            break :blk result orelse return PolicyError.TypeError;
        } else input;

        return TrustedScriptURL.create(self.allocator, policy_value) catch |err| switch (err) {
            error.OutOfMemory => return PolicyError.OutOfMemory,
        };
    }

    /// Free resources owned by this policy.
    pub fn deinit(self: *Self) void {
        if (self.owns_name) {
            self.allocator.free(self.name);
        }
        self.name = "";
    }
};

// ============================================================================
// Tests
// ============================================================================

test "TrustedTypePolicy - create with identity transformation (no callbacks)" {
    const allocator = std.testing.allocator;

    var policy = try TrustedTypePolicy.create(allocator, "test-policy", .{});
    defer policy.deinit();

    try std.testing.expectEqualStrings("test-policy", policy.name);

    // Create HTML without callback - should pass through unchanged
    var html = try policy.createHTML("<div>test</div>", null);
    defer html.deinit();
    try std.testing.expectEqualStrings("<div>test</div>", html.toString());

    // Create Script without callback
    var script = try policy.createScript("console.log('test')", null);
    defer script.deinit();
    try std.testing.expectEqualStrings("console.log('test')", script.toString());

    // Create ScriptURL without callback
    var url = try policy.createScriptURL("https://example.com/script.js", null);
    defer url.deinit();
    try std.testing.expectEqualStrings("https://example.com/script.js", url.toString());
}

test "TrustedTypePolicy - with HTML callback" {
    const allocator = std.testing.allocator;

    // Callback that uppercases input
    const uppercase_callback = struct {
        fn callback(input: []const u8, _: ?*anyopaque) ?[]const u8 {
            _ = input;
            // In a real implementation, we'd transform the input
            // For testing, just return a static string
            return "<UPPERCASED>";
        }
    }.callback;

    var policy = try TrustedTypePolicy.create(allocator, "uppercase", .{
        .createHTML = uppercase_callback,
    });
    defer policy.deinit();

    var html = try policy.createHTML("<div>test</div>", null);
    defer html.deinit();
    try std.testing.expectEqualStrings("<UPPERCASED>", html.toString());
}

test "TrustedTypePolicy - callback returning null throws TypeError" {
    const allocator = std.testing.allocator;

    // Callback that always returns null (rejects all input)
    const reject_all_callback = struct {
        fn callback(_: []const u8, _: ?*anyopaque) ?[]const u8 {
            return null;
        }
    }.callback;

    var policy = try TrustedTypePolicy.create(allocator, "reject-all", .{
        .createHTML = reject_all_callback,
    });
    defer policy.deinit();

    // Should return TypeError
    const result = policy.createHTML("<script>evil()</script>", null);
    try std.testing.expectError(PolicyError.TypeError, result);
}

test "TrustedTypePolicy - callback with sanitization" {
    const allocator = std.testing.allocator;

    // Callback that rejects input containing <script>
    const sanitize_callback = struct {
        fn callback(input: []const u8, _: ?*anyopaque) ?[]const u8 {
            if (std.mem.indexOf(u8, input, "<script") != null) {
                return null; // Reject scripts
            }
            return input;
        }
    }.callback;

    var policy = try TrustedTypePolicy.create(allocator, "sanitizer", .{
        .createHTML = sanitize_callback,
    });
    defer policy.deinit();

    // Safe input should pass
    var safe_html = try policy.createHTML("<p>Safe content</p>", null);
    defer safe_html.deinit();
    try std.testing.expectEqualStrings("<p>Safe content</p>", safe_html.toString());

    // Dangerous input should be rejected
    const result = policy.createHTML("<script>evil()</script>", null);
    try std.testing.expectError(PolicyError.TypeError, result);
}

test "TrustedTypePolicy - borrowed name" {
    const allocator = std.testing.allocator;

    const static_name = "static-policy";
    var policy = TrustedTypePolicy.createWithBorrowedName(allocator, static_name, .{});
    defer policy.deinit(); // Should not free the static name

    try std.testing.expectEqualStrings("static-policy", policy.name);

    var html = try policy.createHTML("<div>test</div>", null);
    defer html.deinit();
    try std.testing.expectEqualStrings("<div>test</div>", html.toString());
}
