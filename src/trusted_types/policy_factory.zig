//! TrustedTypePolicyFactory Implementation
//!
//! W3C Trusted Types Spec: https://w3c.github.io/trusted-types/dist/spec/
//!
//! This module implements the TrustedTypePolicyFactory which is exposed
//! as `window.trustedTypes` or `self.trustedTypes` in JavaScript.
//!
//! The factory is responsible for:
//! - Creating TrustedTypePolicy instances
//! - Tracking policy names for uniqueness enforcement
//! - Providing type checking utilities (isHTML, isScript, isScriptURL)
//! - Providing sink type introspection (getPropertyType, getAttributeType)
//! - Managing the default policy
//!
//! WebIDL:
//! ```webidl
//! [Exposed=(Window,Worker)] interface TrustedTypePolicyFactory {
//!     TrustedTypePolicy createPolicy(
//!         DOMString policyName, optional TrustedTypePolicyOptions policyOptions = {});
//!     boolean isHTML(any value);
//!     boolean isScript(any value);
//!     boolean isScriptURL(any value);
//!     readonly attribute TrustedHTML emptyHTML;
//!     readonly attribute TrustedScript emptyScript;
//!     DOMString? getAttributeType(...);
//!     DOMString? getPropertyType(...);
//!     readonly attribute TrustedTypePolicy? defaultPolicy;
//! };
//! ```

const std = @import("std");
const types = @import("types.zig");
const policy_mod = @import("policy.zig");

pub const TrustedTypePolicy = policy_mod.TrustedTypePolicy;
pub const TrustedTypePolicyOptions = policy_mod.TrustedTypePolicyOptions;
pub const TrustedHTML = types.TrustedHTML;
pub const TrustedScript = types.TrustedScript;
pub const TrustedScriptURL = types.TrustedScriptURL;

/// Error types for factory operations
pub const FactoryError = error{
    /// Policy creation was blocked (by CSP or duplicate name)
    TypeError,
    /// Memory allocation failed
    OutOfMemory,
};

/// TrustedTypePolicyFactory - Creates policies and provides type checking.
///
/// Exposed to JavaScript as `window.trustedTypes` / `self.trustedTypes`.
/// Spec: https://w3c.github.io/trusted-types/dist/spec/#trusted-type-policy-factory
///
/// ## Internal Slots (per spec)
/// - created policy names: Set of policy names created through this factory
/// - default policy: The policy named 'default', if any
///
/// ## Example Usage
/// ```zig
/// var factory = try TrustedTypePolicyFactory.init(allocator);
/// defer factory.deinit();
///
/// // Create a policy
/// var sanitizer = try factory.createPolicy("sanitizer", .{
///     .createHTML = mySanitizer,
/// });
///
/// // Use the policy
/// var html = try sanitizer.createHTML("<p>content</p>", null);
/// defer html.deinit();
///
/// // Check if value is trusted
/// const is_trusted = factory.isHTML(&html);
/// ```
pub const TrustedTypePolicyFactory = struct {
    /// The default policy (policy named 'default'), if any.
    /// Per spec: "readonly attribute TrustedTypePolicy? defaultPolicy"
    default_policy: ?*TrustedTypePolicy = null,

    /// Set of policy names that have been created through this factory.
    /// Per spec internal slot: "created policy names"
    created_policy_names: std.StringHashMap(void),

    /// List of created policies (for memory management)
    created_policies: std.ArrayListUnmanaged(*TrustedTypePolicy),

    /// Pre-created empty TrustedHTML instance.
    /// Per spec: "readonly attribute TrustedHTML emptyHTML"
    empty_html: TrustedHTML,

    /// Pre-created empty TrustedScript instance.
    /// Per spec: "readonly attribute TrustedScript emptyScript"
    empty_script: TrustedScript,

    allocator: std.mem.Allocator,

    const Self = @This();

    /// Initialize a new TrustedTypePolicyFactory.
    ///
    /// Creates the factory with pre-initialized empty instances.
    /// The factory should be a singleton per global scope (Window/Worker).
    pub fn init(allocator: std.mem.Allocator) !*Self {
        const factory = try allocator.create(Self);
        errdefer allocator.destroy(factory);

        factory.* = Self{
            .default_policy = null,
            .created_policy_names = std.StringHashMap(void).init(allocator),
            .created_policies = .{},
            .empty_html = TrustedHTML.createUnmanaged(""),
            .empty_script = TrustedScript.createUnmanaged(""),
            .allocator = allocator,
        };

        return factory;
    }

    /// Create a Trusted Type Policy.
    ///
    /// Spec: https://w3c.github.io/trusted-types/dist/spec/#dom-trustedtypepolicyfactory-createpolicy
    ///
    /// Algorithm (Create a Trusted Type Policy):
    /// 1. Let global be factory's relevant global object
    /// 2. If options is empty, set to new TrustedTypePolicyOptions
    /// 3. Let allowedByCSP be result of 'Should Trusted Type policy creation be blocked by CSP?'
    /// 4. If allowedByCSP is 'Blocked', throw TypeError
    /// 5. Let policy be new TrustedTypePolicy with name and options
    /// 6. Append policyName to factory's created policy names
    /// 7. If policyName is 'default', set factory's default policy to policy
    /// 8. Return policy
    ///
    /// Note: CSP checking is currently a placeholder.
    pub fn createPolicy(
        self: *Self,
        policy_name: []const u8,
        options: TrustedTypePolicyOptions,
    ) FactoryError!*TrustedTypePolicy {
        // TODO: Step 3 - CSP check
        // For now, skip CSP check (will be added when CSP module is ready)
        // The CSP module will implement "Should Trusted Type policy creation be blocked by CSP?"

        // Check for duplicate policy names
        // Note: Per spec, duplicates may be allowed with 'allow-duplicates' CSP keyword
        // For now, we reject duplicates by default
        if (self.created_policy_names.contains(policy_name)) {
            return FactoryError.TypeError;
        }

        // Step 5: Create the policy
        const new_policy = self.allocator.create(TrustedTypePolicy) catch {
            return FactoryError.OutOfMemory;
        };
        errdefer self.allocator.destroy(new_policy);

        const name_copy = self.allocator.dupe(u8, policy_name) catch {
            return FactoryError.OutOfMemory;
        };
        errdefer self.allocator.free(name_copy);

        new_policy.* = TrustedTypePolicy{
            .name = name_copy,
            .options = options,
            .allocator = self.allocator,
            .owns_name = true,
        };

        // Step 6: Track created policy name
        const name_for_tracking = self.allocator.dupe(u8, policy_name) catch {
            return FactoryError.OutOfMemory;
        };
        self.created_policy_names.put(name_for_tracking, {}) catch {
            self.allocator.free(name_for_tracking);
            return FactoryError.OutOfMemory;
        };

        // Track policy for cleanup
        self.created_policies.append(self.allocator, new_policy) catch {
            return FactoryError.OutOfMemory;
        };

        // Step 7: Set default policy if name is 'default'
        if (std.mem.eql(u8, policy_name, "default")) {
            self.default_policy = new_policy;
        }

        // Step 8: Return policy
        return new_policy;
    }

    /// Get the emptyHTML attribute.
    /// Per spec: "readonly attribute TrustedHTML emptyHTML"
    pub fn getEmptyHTML(self: *const Self) TrustedHTML {
        return self.empty_html;
    }

    /// Get the emptyScript attribute.
    /// Per spec: "readonly attribute TrustedScript emptyScript"
    pub fn getEmptyScript(self: *const Self) TrustedScript {
        return self.empty_script;
    }

    /// Get the defaultPolicy attribute.
    /// Per spec: "readonly attribute TrustedTypePolicy? defaultPolicy"
    pub fn getDefaultPolicy(self: *const Self) ?*TrustedTypePolicy {
        return self.default_policy;
    }

    /// Get the required Trusted Type for an element's property.
    ///
    /// Per spec: Returns "TrustedHTML", "TrustedScript", "TrustedScriptURL", or null.
    ///
    /// Arguments:
    /// - tag_name: Element tag name (e.g., "script", "div")
    /// - property: Property name (e.g., "innerHTML", "src")
    /// - element_ns: Element namespace (optional, defaults to HTML namespace)
    pub fn getPropertyType(
        self: *const Self,
        tag_name: []const u8,
        property: []const u8,
        element_ns: ?[]const u8,
    ) ?[]const u8 {
        _ = self;
        _ = element_ns;

        // Per W3C Trusted Types spec, these are the DOM properties that
        // require Trusted Types. The mapping is defined in the spec section
        // "DOM sinks that accept Trusted Types".
        //
        // This is a simplified implementation - full implementation would
        // use the sink_type_map module with comprehensive mappings.

        // Properties that require TrustedHTML
        if (std.mem.eql(u8, property, "innerHTML") or
            std.mem.eql(u8, property, "outerHTML"))
        {
            return "TrustedHTML";
        }

        // iframe.srcdoc requires TrustedHTML
        if (std.mem.eql(u8, tag_name, "iframe") and std.mem.eql(u8, property, "srcdoc")) {
            return "TrustedHTML";
        }

        // script.src requires TrustedScriptURL
        if (std.mem.eql(u8, tag_name, "script") and std.mem.eql(u8, property, "src")) {
            return "TrustedScriptURL";
        }

        // script.text, script.textContent, script.innerText require TrustedScript
        if (std.mem.eql(u8, tag_name, "script")) {
            if (std.mem.eql(u8, property, "text") or
                std.mem.eql(u8, property, "textContent") or
                std.mem.eql(u8, property, "innerText"))
            {
                return "TrustedScript";
            }
        }

        // No Trusted Type required
        return null;
    }

    /// Get the required Trusted Type for an element's attribute.
    ///
    /// Per spec: Returns "TrustedHTML", "TrustedScript", "TrustedScriptURL", or null.
    ///
    /// Arguments:
    /// - tag_name: Element tag name (e.g., "script", "a")
    /// - attribute: Attribute name (e.g., "src", "onclick")
    /// - element_ns: Element namespace (optional)
    /// - attr_ns: Attribute namespace (optional)
    pub fn getAttributeType(
        self: *const Self,
        tag_name: []const u8,
        attribute: []const u8,
        element_ns: ?[]const u8,
        attr_ns: ?[]const u8,
    ) ?[]const u8 {
        _ = self;
        _ = element_ns;
        _ = attr_ns;

        // Event handler attributes require TrustedScript
        if (std.mem.startsWith(u8, attribute, "on")) {
            return "TrustedScript";
        }

        // script[src] requires TrustedScriptURL
        if (std.mem.eql(u8, tag_name, "script") and std.mem.eql(u8, attribute, "src")) {
            return "TrustedScriptURL";
        }

        // iframe[srcdoc] requires TrustedHTML
        if (std.mem.eql(u8, tag_name, "iframe") and std.mem.eql(u8, attribute, "srcdoc")) {
            return "TrustedHTML";
        }

        // No Trusted Type required
        return null;
    }

    /// Clean up all resources owned by this factory.
    pub fn deinit(self: *Self) void {
        // Clean up created policies
        for (self.created_policies.items) |p| {
            p.deinit();
            self.allocator.destroy(p);
        }
        self.created_policies.deinit(self.allocator);

        // Clean up policy name tracking
        var iter = self.created_policy_names.keyIterator();
        while (iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.created_policy_names.deinit();

        // Note: empty_html and empty_script use unmanaged strings,
        // so no cleanup needed for their data

        // Clean up the factory itself
        self.allocator.destroy(self);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "TrustedTypePolicyFactory - init and deinit" {
    const allocator = std.testing.allocator;

    const factory = try TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    // Check empty instances
    try std.testing.expectEqualStrings("", factory.getEmptyHTML().toString());
    try std.testing.expectEqualStrings("", factory.getEmptyScript().toString());

    // Check default policy is null
    try std.testing.expectEqual(@as(?*TrustedTypePolicy, null), factory.getDefaultPolicy());
}

test "TrustedTypePolicyFactory - createPolicy basic" {
    const allocator = std.testing.allocator;

    const factory = try TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    const test_policy = try factory.createPolicy("test-policy", .{});

    try std.testing.expectEqualStrings("test-policy", test_policy.name);

    // Create HTML with the policy
    var html = try test_policy.createHTML("<div>test</div>", null);
    defer html.deinit();
    try std.testing.expectEqualStrings("<div>test</div>", html.toString());
}

test "TrustedTypePolicyFactory - createPolicy default policy" {
    const allocator = std.testing.allocator;

    const factory = try TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    // Initially no default policy
    try std.testing.expectEqual(@as(?*TrustedTypePolicy, null), factory.getDefaultPolicy());

    // Create default policy
    const default_policy = try factory.createPolicy("default", .{});

    // Now default policy should be set
    try std.testing.expectEqual(default_policy, factory.getDefaultPolicy().?);
}

test "TrustedTypePolicyFactory - createPolicy rejects duplicates" {
    const allocator = std.testing.allocator;

    const factory = try TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    _ = try factory.createPolicy("my-policy", .{});

    // Second creation with same name should fail
    const result = factory.createPolicy("my-policy", .{});
    try std.testing.expectError(FactoryError.TypeError, result);
}

test "TrustedTypePolicyFactory - getPropertyType" {
    const allocator = std.testing.allocator;

    const factory = try TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    // innerHTML requires TrustedHTML
    try std.testing.expectEqualStrings("TrustedHTML", factory.getPropertyType("div", "innerHTML", null).?);

    // script.src requires TrustedScriptURL
    try std.testing.expectEqualStrings("TrustedScriptURL", factory.getPropertyType("script", "src", null).?);

    // script.text requires TrustedScript
    try std.testing.expectEqualStrings("TrustedScript", factory.getPropertyType("script", "text", null).?);

    // Regular property requires nothing
    try std.testing.expectEqual(@as(?[]const u8, null), factory.getPropertyType("div", "id", null));
}

test "TrustedTypePolicyFactory - getAttributeType" {
    const allocator = std.testing.allocator;

    const factory = try TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    // onclick requires TrustedScript
    try std.testing.expectEqualStrings("TrustedScript", factory.getAttributeType("button", "onclick", null, null).?);

    // script[src] requires TrustedScriptURL
    try std.testing.expectEqualStrings("TrustedScriptURL", factory.getAttributeType("script", "src", null, null).?);

    // iframe[srcdoc] requires TrustedHTML
    try std.testing.expectEqualStrings("TrustedHTML", factory.getAttributeType("iframe", "srcdoc", null, null).?);

    // Regular attribute requires nothing
    try std.testing.expectEqual(@as(?[]const u8, null), factory.getAttributeType("div", "id", null, null));
}

test "TrustedTypePolicyFactory - multiple policies" {
    const allocator = std.testing.allocator;

    const factory = try TrustedTypePolicyFactory.init(allocator);
    defer factory.deinit();

    const policy1 = try factory.createPolicy("policy-1", .{});
    const policy2 = try factory.createPolicy("policy-2", .{});
    const policy3 = try factory.createPolicy("policy-3", .{});

    try std.testing.expectEqualStrings("policy-1", policy1.name);
    try std.testing.expectEqualStrings("policy-2", policy2.name);
    try std.testing.expectEqualStrings("policy-3", policy3.name);
}
