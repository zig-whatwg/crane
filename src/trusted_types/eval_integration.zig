//! Trusted Types JavaScript eval() Integration
//!
//! W3C Trusted Types Spec: https://w3c.github.io/trusted-types/dist/spec/ § 4.4
//! CSP Spec: https://www.w3.org/TR/CSP3/ § 4.4.1
//!
//! This module integrates Trusted Types with JavaScript dynamic code execution:
//! - eval()
//! - Function constructor
//! - setTimeout/setInterval with string arguments
//!
//! ## Key Algorithm: EnsureCSPDoesNotBlockStringCompilation
//!
//! From CSP spec § 4.4.1, this algorithm is called before dynamic code execution.
//! It integrates with Trusted Types via the 'trusted-types-eval' keyword.
//!
//! ## Usage
//!
//! ```zig
//! const eval_integration = @import("trusted_types").eval_integration;
//!
//! // Before eval("code"):
//! const result = try eval_integration.ensureCSPDoesNotBlockStringCompilation(
//!     allocator,
//!     &csp_list,
//!     &global,
//!     input_code,
//!     "eval",
//! );
//! // result.allowed indicates if compilation can proceed
//! // result.stringified_code is the validated code string
//! ```

const std = @import("std");
const enforcement = @import("enforcement.zig");
const types = @import("types.zig");

// ============================================================================
// Types
// ============================================================================

/// Result of compilation check
pub const CompilationCheckResult = struct {
    /// Whether string compilation is allowed
    allowed: bool,
    /// The stringified code to compile (if allowed)
    /// May be modified by default policy
    stringified_code: []const u8,
    /// If blocked, the reason
    block_reason: ?BlockReason = null,

    pub const BlockReason = enum {
        /// Blocked by CSP (no 'unsafe-eval' or 'trusted-types-eval')
        csp_blocked,
        /// Blocked by Trusted Types enforcement (no valid TrustedScript)
        trusted_types_blocked,
    };
};

/// Input value for eval - either a string or TrustedScript
pub const EvalInput = union(enum) {
    string: []const u8,
    trusted_script: types.TrustedScript,

    /// Check if this is already a TrustedScript
    pub fn isTrustedScript(self: EvalInput) bool {
        return self == .trusted_script;
    }

    /// Get the string value
    pub fn toStringValue(self: EvalInput) []const u8 {
        return switch (self) {
            .string => |s| s,
            .trusted_script => |ts| ts.toString(),
        };
    }
};

/// Sink names for dynamic code execution
pub const SINK_EVAL = "eval";
pub const SINK_FUNCTION = "Function";
pub const SINK_SET_TIMEOUT = "setTimeout";
pub const SINK_SET_INTERVAL = "setInterval";

// ============================================================================
// CSP Policy Info for eval
// ============================================================================

/// CSP policy information relevant to eval/Function compilation.
/// This is passed from the CSP module to avoid circular dependencies.
pub const EvalCspPolicyInfo = struct {
    /// Whether policy has 'unsafe-eval' in effective script-src
    allows_unsafe_eval: bool,
    /// Whether policy has 'trusted-types-eval' in effective script-src
    allows_trusted_types_eval: bool,
    /// Whether policy requires Trusted Types for 'script' sinks
    requires_trusted_types: bool,
    /// Policy disposition (enforce vs report)
    disposition: enforcement.CspDisposition,
};

// ============================================================================
// EnsureCSPDoesNotBlockStringCompilation
// ============================================================================

/// Ensure CSP does not block string compilation (eval, Function, etc.)
/// Spec: CSP § 4.4.1
///
/// This algorithm determines if a string can be compiled into executable code.
/// It integrates with Trusted Types via the 'trusted-types-eval' keyword.
///
/// Algorithm:
/// 1. If source is a TrustedScript, skip to step 4 (TT already validated)
/// 2. If not trusted:
///    a. Run getTrustedTypeCompliantString with TrustedScript, sink name 'eval' or 'Function'
///    b. If that throws, block and report violation
/// 3. Check CSP policies:
///    a. If 'trusted-types-eval' in script-src AND TT enforcement required → continue
///    b. If 'unsafe-eval' in script-src → continue
///    c. Otherwise → block and report violation
/// 4. Return the validated string for compilation
///
/// Arguments:
/// - allocator: Allocator for temporary allocations
/// - csp_policies: CSP policy information for this global
/// - global: The global object
/// - source: The source code to compile
/// - sink_name: "eval" or "Function" (for violation reports)
///
/// Returns: CompilationCheckResult indicating if compilation is allowed
pub fn ensureCSPDoesNotBlockStringCompilation(
    allocator: std.mem.Allocator,
    csp_policies: []const EvalCspPolicyInfo,
    global: *const enforcement.GlobalObject,
    source: EvalInput,
    sink_name: []const u8,
) !CompilationCheckResult {
    // Step 1: If source is already TrustedScript, skip TT validation
    var stringified_code = source.toStringValue();
    var tt_validation_passed = source.isTrustedScript();

    // Step 2: If not trusted, run getTrustedTypeCompliantString
    if (!tt_validation_passed) {
        // Check if Trusted Types enforcement is required
        const requires_tt = doesAnyPolicyRequireTrustedTypes(csp_policies);

        if (requires_tt) {
            // Convert to InputValue for enforcement
            const input_value: enforcement.InputValue = switch (source) {
                .string => |s| .{ .string = s },
                .trusted_script => |ts| .{ .trusted_script = ts },
            };

            // Try to get compliant string through default policy
            if (enforcement.getTrustedTypeCompliantString(
                allocator,
                .TrustedScript,
                global,
                input_value,
                sink_name,
                "'script'",
            )) |validated| {
                stringified_code = validated;
                tt_validation_passed = true;
            } else |_| {
                // TT enforcement failed - block if any enforcing policy
                if (hasEnforcingPolicyRequiringTT(csp_policies)) {
                    return CompilationCheckResult{
                        .allowed = false,
                        .stringified_code = stringified_code,
                        .block_reason = .trusted_types_blocked,
                    };
                }
                // Report-only: continue but log violation
                // (Actual violation reporting would happen here)
            }
        }
    }

    // Step 3: Check CSP policies for 'unsafe-eval' or 'trusted-types-eval'
    const csp_result = checkCSPAllowsEval(csp_policies, tt_validation_passed);

    if (!csp_result.allowed and csp_result.has_enforcing) {
        return CompilationCheckResult{
            .allowed = false,
            .stringified_code = stringified_code,
            .block_reason = .csp_blocked,
        };
    }

    // Step 4: Compilation is allowed
    return CompilationCheckResult{
        .allowed = true,
        .stringified_code = stringified_code,
        .block_reason = null,
    };
}

/// Validate eval() call and return the code to execute if allowed.
/// This is a convenience wrapper around ensureCSPDoesNotBlockStringCompilation.
pub fn validateEval(
    allocator: std.mem.Allocator,
    csp_policies: []const EvalCspPolicyInfo,
    global: *const enforcement.GlobalObject,
    source: EvalInput,
) !CompilationCheckResult {
    return ensureCSPDoesNotBlockStringCompilation(
        allocator,
        csp_policies,
        global,
        source,
        SINK_EVAL,
    );
}

/// Validate Function constructor call and return the code if allowed.
/// This is a convenience wrapper around ensureCSPDoesNotBlockStringCompilation.
pub fn validateFunctionConstructor(
    allocator: std.mem.Allocator,
    csp_policies: []const EvalCspPolicyInfo,
    global: *const enforcement.GlobalObject,
    source: EvalInput,
) !CompilationCheckResult {
    return ensureCSPDoesNotBlockStringCompilation(
        allocator,
        csp_policies,
        global,
        source,
        SINK_FUNCTION,
    );
}

/// Validate setTimeout/setInterval with string argument.
/// This is a convenience wrapper around ensureCSPDoesNotBlockStringCompilation.
pub fn validateTimerStringCallback(
    allocator: std.mem.Allocator,
    csp_policies: []const EvalCspPolicyInfo,
    global: *const enforcement.GlobalObject,
    source: EvalInput,
    timer_name: []const u8,
) !CompilationCheckResult {
    return ensureCSPDoesNotBlockStringCompilation(
        allocator,
        csp_policies,
        global,
        source,
        timer_name,
    );
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Check if any CSP policy requires Trusted Types
fn doesAnyPolicyRequireTrustedTypes(csp_policies: []const EvalCspPolicyInfo) bool {
    for (csp_policies) |policy| {
        if (policy.requires_trusted_types) return true;
    }
    return false;
}

/// Check if any enforcing policy requires Trusted Types
fn hasEnforcingPolicyRequiringTT(csp_policies: []const EvalCspPolicyInfo) bool {
    for (csp_policies) |policy| {
        if (policy.disposition == .enforce and policy.requires_trusted_types) {
            return true;
        }
    }
    return false;
}

/// Result of CSP eval check
const CspEvalCheckResult = struct {
    allowed: bool,
    has_enforcing: bool,
};

/// Check if CSP policies allow eval
fn checkCSPAllowsEval(
    csp_policies: []const EvalCspPolicyInfo,
    tt_validation_passed: bool,
) CspEvalCheckResult {
    if (csp_policies.len == 0) {
        // No CSP policies - eval is allowed
        return .{ .allowed = true, .has_enforcing = false };
    }

    var all_allowed = true;
    var has_enforcing = false;

    for (csp_policies) |policy| {
        var this_policy_allows = false;

        // Check if policy allows via 'unsafe-eval'
        if (policy.allows_unsafe_eval) {
            this_policy_allows = true;
        }

        // Check if policy allows via 'trusted-types-eval' (if TT validation passed)
        if (policy.allows_trusted_types_eval and tt_validation_passed and policy.requires_trusted_types) {
            this_policy_allows = true;
        }

        if (!this_policy_allows) {
            // This policy blocks eval
            if (policy.disposition == .enforce) {
                all_allowed = false;
                has_enforcing = true;
            }
            // Report-only policies don't block but should report
        }
    }

    return .{
        .allowed = all_allowed,
        .has_enforcing = has_enforcing,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "ensureCSPDoesNotBlockStringCompilation - no CSP allows eval" {
    const allocator = std.testing.allocator;

    const global = enforcement.GlobalObject.initNoCsp(allocator);
    const csp_policies = [_]EvalCspPolicyInfo{};

    const result = try ensureCSPDoesNotBlockStringCompilation(
        allocator,
        &csp_policies,
        &global,
        .{ .string = "console.log('hello')" },
        SINK_EVAL,
    );

    try std.testing.expect(result.allowed);
    try std.testing.expectEqualStrings("console.log('hello')", result.stringified_code);
}

test "ensureCSPDoesNotBlockStringCompilation - unsafe-eval allows" {
    const allocator = std.testing.allocator;

    const global = enforcement.GlobalObject.initNoCsp(allocator);
    const csp_policies = [_]EvalCspPolicyInfo{
        .{
            .allows_unsafe_eval = true,
            .allows_trusted_types_eval = false,
            .requires_trusted_types = false,
            .disposition = .enforce,
        },
    };

    const result = try ensureCSPDoesNotBlockStringCompilation(
        allocator,
        &csp_policies,
        &global,
        .{ .string = "console.log('hello')" },
        SINK_EVAL,
    );

    try std.testing.expect(result.allowed);
}

test "ensureCSPDoesNotBlockStringCompilation - no unsafe-eval blocks" {
    const allocator = std.testing.allocator;

    const global = enforcement.GlobalObject.initNoCsp(allocator);
    const csp_policies = [_]EvalCspPolicyInfo{
        .{
            .allows_unsafe_eval = false,
            .allows_trusted_types_eval = false,
            .requires_trusted_types = false,
            .disposition = .enforce,
        },
    };

    const result = try ensureCSPDoesNotBlockStringCompilation(
        allocator,
        &csp_policies,
        &global,
        .{ .string = "console.log('hello')" },
        SINK_EVAL,
    );

    try std.testing.expect(!result.allowed);
    try std.testing.expect(result.block_reason == .csp_blocked);
}

test "ensureCSPDoesNotBlockStringCompilation - TrustedScript bypasses check" {
    const allocator = std.testing.allocator;

    const global = enforcement.GlobalObject.initNoCsp(allocator);

    // Policy that would block strings
    const csp_policies = [_]EvalCspPolicyInfo{
        .{
            .allows_unsafe_eval = false,
            .allows_trusted_types_eval = true,
            .requires_trusted_types = true,
            .disposition = .enforce,
        },
    };

    // Create a TrustedScript (unmanaged for testing - no allocation needed)
    const ts = types.TrustedScript.createUnmanaged("console.log('trusted')");

    const result = try ensureCSPDoesNotBlockStringCompilation(
        allocator,
        &csp_policies,
        &global,
        .{ .trusted_script = ts },
        SINK_EVAL,
    );

    try std.testing.expect(result.allowed);
    try std.testing.expectEqualStrings("console.log('trusted')", result.stringified_code);
}

test "ensureCSPDoesNotBlockStringCompilation - trusted-types-eval allows with TT" {
    const allocator = std.testing.allocator;

    const global = enforcement.GlobalObject.initNoCsp(allocator);

    // Policy with trusted-types-eval that requires TT
    const csp_policies = [_]EvalCspPolicyInfo{
        .{
            .allows_unsafe_eval = false,
            .allows_trusted_types_eval = true,
            .requires_trusted_types = true,
            .disposition = .enforce,
        },
    };

    // TrustedScript bypasses and trusted-types-eval allows
    const ts = types.TrustedScript.createUnmanaged("safe()");

    const result = try ensureCSPDoesNotBlockStringCompilation(
        allocator,
        &csp_policies,
        &global,
        .{ .trusted_script = ts },
        SINK_EVAL,
    );

    try std.testing.expect(result.allowed);
}

test "validateEval - convenience function" {
    const allocator = std.testing.allocator;

    const global = enforcement.GlobalObject.initNoCsp(allocator);
    const csp_policies = [_]EvalCspPolicyInfo{};

    const result = try validateEval(
        allocator,
        &csp_policies,
        &global,
        .{ .string = "1 + 1" },
    );

    try std.testing.expect(result.allowed);
}

test "validateFunctionConstructor - convenience function" {
    const allocator = std.testing.allocator;

    const global = enforcement.GlobalObject.initNoCsp(allocator);
    const csp_policies = [_]EvalCspPolicyInfo{
        .{
            .allows_unsafe_eval = true,
            .allows_trusted_types_eval = false,
            .requires_trusted_types = false,
            .disposition = .enforce,
        },
    };

    const result = try validateFunctionConstructor(
        allocator,
        &csp_policies,
        &global,
        .{ .string = "return a + b" },
    );

    try std.testing.expect(result.allowed);
}

test "validateTimerStringCallback - convenience function" {
    const allocator = std.testing.allocator;

    const global = enforcement.GlobalObject.initNoCsp(allocator);
    const csp_policies = [_]EvalCspPolicyInfo{};

    const result = try validateTimerStringCallback(
        allocator,
        &csp_policies,
        &global,
        .{ .string = "callback()" },
        SINK_SET_TIMEOUT,
    );

    try std.testing.expect(result.allowed);
}

test "report-only policy does not block" {
    const allocator = std.testing.allocator;

    const global = enforcement.GlobalObject.initNoCsp(allocator);

    // Report-only policy without unsafe-eval
    const csp_policies = [_]EvalCspPolicyInfo{
        .{
            .allows_unsafe_eval = false,
            .allows_trusted_types_eval = false,
            .requires_trusted_types = false,
            .disposition = .report,
        },
    };

    const result = try ensureCSPDoesNotBlockStringCompilation(
        allocator,
        &csp_policies,
        &global,
        .{ .string = "console.log('hello')" },
        SINK_EVAL,
    );

    // Report-only should not block
    try std.testing.expect(result.allowed);
}
