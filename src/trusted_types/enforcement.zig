//! Trusted Types Enforcement Algorithms
//!
//! W3C Trusted Types Spec: https://w3c.github.io/trusted-types/dist/spec/ § 3.4-3.5, § 4.3.3-4.3.4
//!
//! This module implements the core enforcement algorithms that integrate
//! Trusted Types with CSP:
//!
//! - Get Trusted Type compliant string (§3.4)
//! - Process value with default policy (§3.5)
//! - Should sink type mismatch violation be blocked? (§4.3.4)
//!
//! These algorithms are called when a value is passed to an injection sink
//! (like innerHTML, eval, script.src) to enforce Trusted Types.
//!
//! ## Usage
//!
//! ```zig
//! const enforcement = @import("trusted_types").enforcement;
//!
//! // When setting innerHTML:
//! const result = try enforcement.getTrustedTypeCompliantString(
//!     allocator,
//!     TrustedHTML,
//!     &global,
//!     input_value,
//!     "Element innerHTML",
//!     "script",
//! );
//! // result is the validated string to use
//! ```
//!
//! ## CSP Integration
//!
//! This module is designed to be independent of the CSP module to avoid circular
//! dependencies (CSP needs to import Trusted Types for directives, and enforcement
//! needs to check CSP). Instead, the GlobalObject type accepts CSP state via
//! callback functions that can be provided by the CSP module at runtime.

const std = @import("std");
const types = @import("types.zig");
const policy_mod = @import("policy.zig");
const policy_factory_mod = @import("policy_factory.zig");

pub const TrustedHTML = types.TrustedHTML;
pub const TrustedScript = types.TrustedScript;
pub const TrustedScriptURL = types.TrustedScriptURL;
pub const TrustedType = types.TrustedType;
pub const TrustedTypePolicy = policy_mod.TrustedTypePolicy;
pub const TrustedTypePolicyFactory = policy_factory_mod.TrustedTypePolicyFactory;

// ============================================================================
// Error Types
// ============================================================================

/// Errors that can occur during enforcement
pub const EnforcementError = error{
    /// TypeError - value is not a Trusted Type and enforcement is enabled
    TypeError,
    /// Default policy callback threw an error
    CallbackError,
    /// Memory allocation failed
    OutOfMemory,
};

/// Result of sink type mismatch check
pub const SinkMismatchResult = enum {
    /// The sink type mismatch is allowed (report-only or no CSP)
    Allowed,
    /// The sink type mismatch should be blocked
    Blocked,
};

/// CSP disposition (enforce vs report-only)
pub const CspDisposition = enum {
    enforce,
    report,
};

// ============================================================================
// Expected Type Enum
// ============================================================================

/// The expected Trusted Type for a sink
pub const ExpectedType = enum {
    TrustedHTML,
    TrustedScript,
    TrustedScriptURL,

    /// Get the type name string for error messages
    pub fn typeName(self: ExpectedType) []const u8 {
        return switch (self) {
            .TrustedHTML => "TrustedHTML",
            .TrustedScript => "TrustedScript",
            .TrustedScriptURL => "TrustedScriptURL",
        };
    }

    /// Get the function name for policy create methods
    pub fn createFunctionName(self: ExpectedType) []const u8 {
        return switch (self) {
            .TrustedHTML => "createHTML",
            .TrustedScript => "createScript",
            .TrustedScriptURL => "createScriptURL",
        };
    }
};

// ============================================================================
// Input Value Type
// ============================================================================

/// Input to enforcement algorithms - either a string or a Trusted Type
pub const InputValue = union(enum) {
    string: []const u8,
    trusted_html: TrustedHTML,
    trusted_script: TrustedScript,
    trusted_script_url: TrustedScriptURL,

    /// Check if this input is an instance of the expected type
    pub fn isInstanceOf(self: InputValue, expected: ExpectedType) bool {
        return switch (expected) {
            .TrustedHTML => self == .trusted_html,
            .TrustedScript => self == .trusted_script,
            .TrustedScriptURL => self == .trusted_script_url,
        };
    }

    /// Get the string value (for Trusted Types, this is the data value)
    pub fn toStringValue(self: InputValue) []const u8 {
        return switch (self) {
            .string => |s| s,
            .trusted_html => |h| h.toString(),
            .trusted_script => |s| s.toString(),
            .trusted_script_url => |u| u.toString(),
        };
    }
};

// ============================================================================
// CSP Policy Info (for avoiding circular dependency)
// ============================================================================

/// Information about a CSP policy relevant to Trusted Types enforcement.
/// This abstracts the CSP module's Policy type to avoid circular imports.
pub const CspPolicyInfo = struct {
    /// Whether this policy has require-trusted-types-for directive
    has_require_trusted_types_for: bool,
    /// The sink groups required (e.g., "'script'")
    required_sink_groups: []const []const u8,
    /// The disposition of this policy
    disposition: CspDisposition,
};

// ============================================================================
// Global Object
// ============================================================================

/// Represents the global object's Trusted Types state.
/// In a browser, this would be Window or Worker.
/// Here we model the relevant parts for enforcement.
///
/// This type is designed to avoid circular dependencies with CSP by accepting
/// CSP state as parameters rather than importing CSP types directly.
pub const GlobalObject = struct {
    /// The trusted type policy factory for this global
    policy_factory: ?*TrustedTypePolicyFactory = null,

    allocator: std.mem.Allocator,

    /// CSP policy information for enforcement checks
    csp_policies: []const CspPolicyInfo,

    const Self = @This();

    /// Initialize a global object
    pub fn init(
        allocator: std.mem.Allocator,
        csp_policies: []const CspPolicyInfo,
    ) Self {
        return Self{
            .policy_factory = null,
            .allocator = allocator,
            .csp_policies = csp_policies,
        };
    }

    /// Initialize a global object with no CSP (for testing)
    pub fn initNoCsp(allocator: std.mem.Allocator) Self {
        return Self{
            .policy_factory = null,
            .allocator = allocator,
            .csp_policies = &[_]CspPolicyInfo{},
        };
    }

    /// Get the default policy if one exists
    pub fn getDefaultPolicy(self: *const Self) ?*TrustedTypePolicy {
        if (self.policy_factory) |factory| {
            return factory.getDefaultPolicy();
        }
        return null;
    }

    /// Check if Trusted Types are required for a sink group
    /// This implements "Does sink type require trusted types?" from spec
    pub fn doesSinkTypeRequireTrustedTypes(
        self: *const Self,
        sink_group: []const u8,
        include_report_only: bool,
    ) bool {
        for (self.csp_policies) |policy| {
            if (!policy.has_require_trusted_types_for) continue;

            // Check disposition
            if (!include_report_only and policy.disposition == .report) continue;

            // Check if sink group is required
            for (policy.required_sink_groups) |required_group| {
                if (std.ascii.eqlIgnoreCase(required_group, sink_group)) {
                    return true;
                }
            }
        }
        return false;
    }
};

// ============================================================================
// Get Trusted Type Compliant String (§3.4)
// ============================================================================

/// Get Trusted Type compliant string algorithm.
/// Spec: https://w3c.github.io/trusted-types/dist/spec/#get-trusted-type-compliant-string-algorithm
///
/// This algorithm will return a string that can be used with an injection sink,
/// optionally unwrapping it from a matching Trusted Type. It will ensure that
/// the Trusted Type enforcement rules were respected.
///
/// Algorithm:
/// 1. If input is an instance of expectedType, return stringified input
/// 2. Let requireTrustedTypes be result of "Does sink type require trusted types?"
/// 3. If requireTrustedTypes is false, return stringified input
/// 4. Let convertedInput be result of "Process value with a default policy"
/// 5. If algorithm threw, rethrow
/// 6. If convertedInput is null:
///    a. Let disposition be result of "should sink type mismatch be blocked?"
///    b. If disposition is "Allowed", return stringified input
///    c. Throw TypeError
/// 7. Assert: convertedInput is instance of expectedType
/// 8. Return stringified convertedInput
///
/// Arguments:
/// - allocator: Allocator for any temporary allocations
/// - expected_type: The expected Trusted Type for this sink
/// - global: The global object (Window/Worker)
/// - input: The input value (string or Trusted Type)
/// - sink: The sink name (e.g., "Element innerHTML")
/// - sink_group: The sink group (e.g., "script")
///
/// Returns: The validated string value to use, or error
pub fn getTrustedTypeCompliantString(
    allocator: std.mem.Allocator,
    expected_type: ExpectedType,
    global: *const GlobalObject,
    input: InputValue,
    sink: []const u8,
    sink_group: []const u8,
) EnforcementError![]const u8 {
    // Step 1: If input is an instance of expectedType, return stringified input
    if (input.isInstanceOf(expected_type)) {
        return input.toStringValue();
    }

    // Step 2: Check if Trusted Types are required for this sink
    // Does sink type require trusted types? (include report-only for step 2)
    const require_trusted_types = global.doesSinkTypeRequireTrustedTypes(
        sink_group,
        true, // includeReportOnlyPolicies
    );

    // Step 3: If not required, return stringified input
    if (!require_trusted_types) {
        return input.toStringValue();
    }

    // Step 4: Process value with default policy
    const converted_input = processValueWithDefaultPolicy(
        allocator,
        expected_type,
        global,
        input,
        sink,
    ) catch |err| {
        // Step 5: If algorithm threw, rethrow
        return err;
    };

    // Step 6: If convertedInput is null
    if (converted_input == null) {
        // Step 6a: Check if should be blocked
        const disposition = shouldSinkTypeMismatchViolationBeBlockedByCSP(
            global,
            sink,
            sink_group,
            input.toStringValue(),
        );

        // Step 6b: If Allowed, return stringified input (report-only mode)
        if (disposition == .Allowed) {
            return input.toStringValue();
        }

        // Step 6c: Throw TypeError
        return EnforcementError.TypeError;
    }

    // Step 7-8: Return stringified convertedInput
    return converted_input.?.toStringValue();
}

// ============================================================================
// Process Value with Default Policy (§3.5)
// ============================================================================

/// Process value with a default policy algorithm.
/// Spec: https://w3c.github.io/trusted-types/dist/spec/#process-value-with-a-default-policy-algorithm
///
/// This algorithm routes a value to be assigned to an injection sink through
/// a default policy, should one exist.
///
/// Algorithm:
/// 1. Let defaultPolicy be global's trusted type policy factory's default policy
/// 2. Let policyValue be result of "get trusted type policy value" with:
///    - defaultPolicy as policy
///    - stringified input as value
///    - expectedType's type name as trustedTypeName
///    - « trustedTypeName, sink » as arguments
///    - false as throwIfMissing
/// 3. If algorithm threw, rethrow
/// 4. If policyValue is null/undefined, return null
/// 5. Let dataString be stringified policyValue
/// 6. Return new instance of expectedType with data = dataString
///
/// Returns: The converted Trusted Type, or null if no default policy or callback
pub fn processValueWithDefaultPolicy(
    allocator: std.mem.Allocator,
    expected_type: ExpectedType,
    global: *const GlobalObject,
    input: InputValue,
    sink: []const u8,
) EnforcementError!?InputValue {
    // Step 1: Get default policy
    const default_policy = global.getDefaultPolicy() orelse {
        // No default policy - return null
        return null;
    };

    // Step 2: Get trusted type policy value
    // We call the appropriate create* function on the default policy
    const input_string = input.toStringValue();

    // The sink is passed as context to the callback
    // In a real implementation, we'd pass both trustedTypeName and sink
    // For now, we use a simple context
    _ = sink;

    const policy_value: ?[]const u8 = switch (expected_type) {
        .TrustedHTML => blk: {
            if (default_policy.options.createHTML) |callback| {
                break :blk callback(input_string, null);
            }
            break :blk null;
        },
        .TrustedScript => blk: {
            if (default_policy.options.createScript) |callback| {
                break :blk callback(input_string, null);
            }
            break :blk null;
        },
        .TrustedScriptURL => blk: {
            if (default_policy.options.createScriptURL) |callback| {
                break :blk callback(input_string, null);
            }
            break :blk null;
        },
    };

    // Step 4: If policyValue is null, return null
    if (policy_value == null) {
        return null;
    }

    // Step 5-6: Create and return new Trusted Type instance
    const data_string = policy_value.?;

    return switch (expected_type) {
        .TrustedHTML => InputValue{
            .trusted_html = TrustedHTML.create(allocator, data_string) catch {
                return EnforcementError.OutOfMemory;
            },
        },
        .TrustedScript => InputValue{
            .trusted_script = TrustedScript.create(allocator, data_string) catch {
                return EnforcementError.OutOfMemory;
            },
        },
        .TrustedScriptURL => InputValue{
            .trusted_script_url = TrustedScriptURL.create(allocator, data_string) catch {
                return EnforcementError.OutOfMemory;
            },
        },
    };
}

// ============================================================================
// Should Sink Type Mismatch Violation Be Blocked? (§4.3.4)
// ============================================================================

/// Should sink type mismatch violation be blocked by CSP?
/// Spec: https://w3c.github.io/trusted-types/dist/spec/#should-block-sink-type-mismatch
///
/// This algorithm returns "Blocked" if the injection sink requires a Trusted Type,
/// and "Allowed" otherwise.
///
/// Algorithm:
/// 1. Let result be "Allowed"
/// 2. Let sample be source (with special handling for Function sink)
/// 3. For each policy in global's CSP list:
///    a. If policy doesn't have require-trusted-types-for directive, continue
///    b. Let directive be the require-trusted-types-for directive
///    c. If directive doesn't contain sinkGroup, continue
///    d. Create violation object and report it
///    e. If policy disposition is "enforce", set result to "Blocked"
/// 4. Return result
///
/// Note: This implementation does not create actual violation reports.
/// A full implementation would integrate with CSP violation reporting.
pub fn shouldSinkTypeMismatchViolationBeBlockedByCSP(
    global: *const GlobalObject,
    sink: []const u8,
    sink_group: []const u8,
    source: []const u8,
) SinkMismatchResult {
    var result = SinkMismatchResult.Allowed;

    // Step 2: Sample preparation (special handling for Function sink)
    // Note: In a full implementation, this sample would be used for violation reporting.
    // The sample is prepared per spec but not currently used since we don't report violations.
    _ = source;
    _ = sink;

    // Step 3: Check each policy
    for (global.csp_policies) |policy| {
        // Step 3a: Check for require-trusted-types-for directive
        if (!policy.has_require_trusted_types_for) continue;

        // Step 3c: Check if directive contains sink group
        var contains_sink_group = false;
        for (policy.required_sink_groups) |required_group| {
            if (std.ascii.eqlIgnoreCase(required_group, sink_group)) {
                contains_sink_group = true;
                break;
            }
        }

        if (!contains_sink_group) continue;

        // Step 3d: Create and report violation
        // Note: In a full implementation, we would:
        // 1. Create a violation object with:
        //    - resource: "trusted-types-sink"
        //    - sample: sink + "|" + sample (truncated to 40 chars)
        // 2. Report the violation
        // For now, we skip violation reporting (sample is prepared above)

        // Step 3e: Check disposition
        if (policy.disposition == .enforce) {
            result = .Blocked;
        }
    }

    // Step 4: Return result
    return result;
}

// ============================================================================
// Convenience Functions
// ============================================================================

/// Check if a value is a valid TrustedHTML instance.
/// This can be used by DOM APIs to check if enforcement should apply.
pub fn isValidTrustedHTML(value: InputValue) bool {
    return value == .trusted_html;
}

/// Check if a value is a valid TrustedScript instance.
pub fn isValidTrustedScript(value: InputValue) bool {
    return value == .trusted_script;
}

/// Check if a value is a valid TrustedScriptURL instance.
pub fn isValidTrustedScriptURL(value: InputValue) bool {
    return value == .trusted_script_url;
}

/// Get the required Trusted Type for a property sink.
/// Returns null if no Trusted Type is required.
pub fn getRequiredTypeForProperty(
    tag_name: []const u8,
    property: []const u8,
) ?ExpectedType {
    // innerHTML and outerHTML require TrustedHTML
    if (std.mem.eql(u8, property, "innerHTML") or
        std.mem.eql(u8, property, "outerHTML"))
    {
        return .TrustedHTML;
    }

    // iframe.srcdoc requires TrustedHTML
    if (std.mem.eql(u8, tag_name, "iframe") and std.mem.eql(u8, property, "srcdoc")) {
        return .TrustedHTML;
    }

    // script.src requires TrustedScriptURL
    if (std.mem.eql(u8, tag_name, "script") and std.mem.eql(u8, property, "src")) {
        return .TrustedScriptURL;
    }

    // script.text, textContent, innerText require TrustedScript
    if (std.mem.eql(u8, tag_name, "script")) {
        if (std.mem.eql(u8, property, "text") or
            std.mem.eql(u8, property, "textContent") or
            std.mem.eql(u8, property, "innerText"))
        {
            return .TrustedScript;
        }
    }

    return null;
}

/// Get the required Trusted Type for an attribute sink.
/// Returns null if no Trusted Type is required.
pub fn getRequiredTypeForAttribute(
    tag_name: []const u8,
    attribute: []const u8,
) ?ExpectedType {
    // Event handler attributes require TrustedScript
    if (std.mem.startsWith(u8, attribute, "on")) {
        return .TrustedScript;
    }

    // script[src] requires TrustedScriptURL
    if (std.mem.eql(u8, tag_name, "script") and std.mem.eql(u8, attribute, "src")) {
        return .TrustedScriptURL;
    }

    // iframe[srcdoc] requires TrustedHTML
    if (std.mem.eql(u8, tag_name, "iframe") and std.mem.eql(u8, attribute, "srcdoc")) {
        return .TrustedHTML;
    }

    return null;
}

// ============================================================================
// Helper to create CspPolicyInfo from CSP data
// ============================================================================

/// Create a CspPolicyInfo with require-trusted-types-for directive
pub fn createCspPolicyInfo(
    disposition: CspDisposition,
    required_sink_groups: []const []const u8,
) CspPolicyInfo {
    return CspPolicyInfo{
        .has_require_trusted_types_for = required_sink_groups.len > 0,
        .required_sink_groups = required_sink_groups,
        .disposition = disposition,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "getTrustedTypeCompliantString - already correct type" {
    const allocator = std.testing.allocator;

    // Create CSP policy requiring Trusted Types
    const sink_groups = [_][]const u8{"'script'"};
    const policies = [_]CspPolicyInfo{
        createCspPolicyInfo(.enforce, &sink_groups),
    };

    var global = GlobalObject.init(allocator, &policies);

    // Create a TrustedHTML value
    var trusted_html = try TrustedHTML.create(allocator, "<div>trusted</div>");
    defer trusted_html.deinit();

    const input = InputValue{ .trusted_html = trusted_html };

    // Should return the value directly since it's already the correct type
    const result = try getTrustedTypeCompliantString(
        allocator,
        .TrustedHTML,
        &global,
        input,
        "Element innerHTML",
        "'script'",
    );

    try std.testing.expectEqualStrings("<div>trusted</div>", result);
}

test "getTrustedTypeCompliantString - no enforcement" {
    const allocator = std.testing.allocator;

    // No CSP requiring Trusted Types
    var global = GlobalObject.initNoCsp(allocator);

    const input = InputValue{ .string = "<div>untrusted</div>" };

    // Should pass through when enforcement is not required
    const result = try getTrustedTypeCompliantString(
        allocator,
        .TrustedHTML,
        &global,
        input,
        "Element innerHTML",
        "'script'",
    );

    try std.testing.expectEqualStrings("<div>untrusted</div>", result);
}

test "getTrustedTypeCompliantString - enforcement blocks string" {
    const allocator = std.testing.allocator;

    // Add CSP policy requiring Trusted Types
    const sink_groups = [_][]const u8{"'script'"};
    const policies = [_]CspPolicyInfo{
        createCspPolicyInfo(.enforce, &sink_groups),
    };

    var global = GlobalObject.init(allocator, &policies);

    // No default policy
    const input = InputValue{ .string = "<div>untrusted</div>" };

    // Should throw TypeError when string is used with enforcement
    const result = getTrustedTypeCompliantString(
        allocator,
        .TrustedHTML,
        &global,
        input,
        "Element innerHTML",
        "'script'",
    );

    try std.testing.expectError(EnforcementError.TypeError, result);
}

test "shouldSinkTypeMismatchViolationBeBlockedByCSP - enforce" {
    const allocator = std.testing.allocator;

    // Add enforcing CSP policy
    const sink_groups = [_][]const u8{"'script'"};
    const policies = [_]CspPolicyInfo{
        createCspPolicyInfo(.enforce, &sink_groups),
    };

    const global = GlobalObject.init(allocator, &policies);

    const result = shouldSinkTypeMismatchViolationBeBlockedByCSP(
        &global,
        "Element innerHTML",
        "'script'",
        "<div>test</div>",
    );

    try std.testing.expectEqual(SinkMismatchResult.Blocked, result);
}

test "shouldSinkTypeMismatchViolationBeBlockedByCSP - report-only" {
    const allocator = std.testing.allocator;

    // Add report-only CSP policy
    const sink_groups = [_][]const u8{"'script'"};
    const policies = [_]CspPolicyInfo{
        createCspPolicyInfo(.report, &sink_groups),
    };

    const global = GlobalObject.init(allocator, &policies);

    const result = shouldSinkTypeMismatchViolationBeBlockedByCSP(
        &global,
        "Element innerHTML",
        "'script'",
        "<div>test</div>",
    );

    try std.testing.expectEqual(SinkMismatchResult.Allowed, result);
}

test "getRequiredTypeForProperty" {
    // innerHTML requires TrustedHTML
    try std.testing.expectEqual(ExpectedType.TrustedHTML, getRequiredTypeForProperty("div", "innerHTML").?);

    // script.src requires TrustedScriptURL
    try std.testing.expectEqual(ExpectedType.TrustedScriptURL, getRequiredTypeForProperty("script", "src").?);

    // script.text requires TrustedScript
    try std.testing.expectEqual(ExpectedType.TrustedScript, getRequiredTypeForProperty("script", "text").?);

    // Regular property requires nothing
    try std.testing.expectEqual(@as(?ExpectedType, null), getRequiredTypeForProperty("div", "id"));
}

test "getRequiredTypeForAttribute" {
    // onclick requires TrustedScript
    try std.testing.expectEqual(ExpectedType.TrustedScript, getRequiredTypeForAttribute("button", "onclick").?);

    // script[src] requires TrustedScriptURL
    try std.testing.expectEqual(ExpectedType.TrustedScriptURL, getRequiredTypeForAttribute("script", "src").?);

    // iframe[srcdoc] requires TrustedHTML
    try std.testing.expectEqual(ExpectedType.TrustedHTML, getRequiredTypeForAttribute("iframe", "srcdoc").?);

    // Regular attribute requires nothing
    try std.testing.expectEqual(@as(?ExpectedType, null), getRequiredTypeForAttribute("div", "id"));
}
