//! CSP sandbox Directive
//!
//! W3C Content Security Policy Level 3
//! Spec: https://www.w3.org/TR/CSP3/#directive-sandbox
//!
//! The sandbox directive specifies an HTML sandbox policy that the
//! user agent applies to the protected resource.

const std = @import("std");
const types = @import("../types.zig");

// ============================================================================
// Sandbox Flags
// ============================================================================

/// Sandbox flags - matches HTML Standard sandbox flags
/// Spec: HTML Standard § 7.6.1.1
pub const SandboxFlags = packed struct {
    /// Forms can be submitted
    allow_forms: bool = false,
    /// Modals can be created (alert, confirm, prompt, print)
    allow_modals: bool = false,
    /// Screen orientation can be locked
    allow_orientation_lock: bool = false,
    /// Pointer lock can be used
    allow_pointer_lock: bool = false,
    /// Popups can be created
    allow_popups: bool = false,
    /// Popups can escape the sandbox
    allow_popups_to_escape_sandbox: bool = false,
    /// Presentation API can be used
    allow_presentation: bool = false,
    /// Same-origin policy is not enforced
    allow_same_origin: bool = false,
    /// Scripts can run
    allow_scripts: bool = false,
    /// Top-level navigation is allowed
    allow_top_navigation: bool = false,
    /// Top-level navigation via user activation
    allow_top_navigation_by_user_activation: bool = false,
    /// Top-level navigation to custom protocols
    allow_top_navigation_to_custom_protocols: bool = false,
    /// Downloads are allowed
    allow_downloads: bool = false,

    /// Create flags with all restrictions (most restrictive sandbox)
    pub fn allRestricted() SandboxFlags {
        return .{};
    }

    /// Create flags with all permissions (no sandbox)
    pub fn allAllowed() SandboxFlags {
        return .{
            .allow_forms = true,
            .allow_modals = true,
            .allow_orientation_lock = true,
            .allow_pointer_lock = true,
            .allow_popups = true,
            .allow_popups_to_escape_sandbox = true,
            .allow_presentation = true,
            .allow_same_origin = true,
            .allow_scripts = true,
            .allow_top_navigation = true,
            .allow_top_navigation_by_user_activation = true,
            .allow_top_navigation_to_custom_protocols = true,
            .allow_downloads = true,
        };
    }

    /// Check if any restriction is active
    pub fn hasAnyRestriction(self: SandboxFlags) bool {
        const all_allowed = SandboxFlags.allAllowed();
        return @as(u16, @bitCast(self)) != @as(u16, @bitCast(all_allowed));
    }

    /// Merge two sandbox flags (intersection - both must allow)
    pub fn merge(self: SandboxFlags, other: SandboxFlags) SandboxFlags {
        return .{
            .allow_forms = self.allow_forms and other.allow_forms,
            .allow_modals = self.allow_modals and other.allow_modals,
            .allow_orientation_lock = self.allow_orientation_lock and other.allow_orientation_lock,
            .allow_pointer_lock = self.allow_pointer_lock and other.allow_pointer_lock,
            .allow_popups = self.allow_popups and other.allow_popups,
            .allow_popups_to_escape_sandbox = self.allow_popups_to_escape_sandbox and other.allow_popups_to_escape_sandbox,
            .allow_presentation = self.allow_presentation and other.allow_presentation,
            .allow_same_origin = self.allow_same_origin and other.allow_same_origin,
            .allow_scripts = self.allow_scripts and other.allow_scripts,
            .allow_top_navigation = self.allow_top_navigation and other.allow_top_navigation,
            .allow_top_navigation_by_user_activation = self.allow_top_navigation_by_user_activation and other.allow_top_navigation_by_user_activation,
            .allow_top_navigation_to_custom_protocols = self.allow_top_navigation_to_custom_protocols and other.allow_top_navigation_to_custom_protocols,
            .allow_downloads = self.allow_downloads and other.allow_downloads,
        };
    }
};

// ============================================================================
// Sandbox Parsing
// ============================================================================

/// Token to flag mapping
const TokenFlagMap = struct {
    token: []const u8,
    setter: *const fn (*SandboxFlags) void,
};

fn setAllowForms(flags: *SandboxFlags) void {
    flags.allow_forms = true;
}
fn setAllowModals(flags: *SandboxFlags) void {
    flags.allow_modals = true;
}
fn setAllowOrientationLock(flags: *SandboxFlags) void {
    flags.allow_orientation_lock = true;
}
fn setAllowPointerLock(flags: *SandboxFlags) void {
    flags.allow_pointer_lock = true;
}
fn setAllowPopups(flags: *SandboxFlags) void {
    flags.allow_popups = true;
}
fn setAllowPopupsToEscapeSandbox(flags: *SandboxFlags) void {
    flags.allow_popups_to_escape_sandbox = true;
}
fn setAllowPresentation(flags: *SandboxFlags) void {
    flags.allow_presentation = true;
}
fn setAllowSameOrigin(flags: *SandboxFlags) void {
    flags.allow_same_origin = true;
}
fn setAllowScripts(flags: *SandboxFlags) void {
    flags.allow_scripts = true;
}
fn setAllowTopNavigation(flags: *SandboxFlags) void {
    flags.allow_top_navigation = true;
}
fn setAllowTopNavigationByUserActivation(flags: *SandboxFlags) void {
    flags.allow_top_navigation_by_user_activation = true;
}
fn setAllowTopNavigationToCustomProtocols(flags: *SandboxFlags) void {
    flags.allow_top_navigation_to_custom_protocols = true;
}
fn setAllowDownloads(flags: *SandboxFlags) void {
    flags.allow_downloads = true;
}

const token_flag_map = [_]TokenFlagMap{
    .{ .token = "allow-forms", .setter = setAllowForms },
    .{ .token = "allow-modals", .setter = setAllowModals },
    .{ .token = "allow-orientation-lock", .setter = setAllowOrientationLock },
    .{ .token = "allow-pointer-lock", .setter = setAllowPointerLock },
    .{ .token = "allow-popups", .setter = setAllowPopups },
    .{ .token = "allow-popups-to-escape-sandbox", .setter = setAllowPopupsToEscapeSandbox },
    .{ .token = "allow-presentation", .setter = setAllowPresentation },
    .{ .token = "allow-same-origin", .setter = setAllowSameOrigin },
    .{ .token = "allow-scripts", .setter = setAllowScripts },
    .{ .token = "allow-top-navigation", .setter = setAllowTopNavigation },
    .{ .token = "allow-top-navigation-by-user-activation", .setter = setAllowTopNavigationByUserActivation },
    .{ .token = "allow-top-navigation-to-custom-protocols", .setter = setAllowTopNavigationToCustomProtocols },
    .{ .token = "allow-downloads", .setter = setAllowDownloads },
};

/// Parse sandbox directive value into flags.
/// Spec: CSP Level 3 § 7.7.4
///
/// If the directive value is empty, all restrictions apply.
/// Each token relaxes a specific restriction.
pub fn parseSandboxDirective(directive: *const types.Directive) SandboxFlags {
    // Start with all restrictions
    var flags = SandboxFlags.allRestricted();

    // Parse each token
    for (directive.value.expressions.items) |expr| {
        // Sandbox tokens are stored as raw values
        const token = expr.raw_value;

        for (token_flag_map) |mapping| {
            if (std.ascii.eqlIgnoreCase(token, mapping.token)) {
                mapping.setter(&flags);
                break;
            }
        }
    }

    return flags;
}

// ============================================================================
// Sandbox Checking
// ============================================================================

/// Get sandbox flags from a policy.
/// Returns null if no sandbox directive is present.
pub fn getSandboxFlags(policy: *const types.Policy) ?SandboxFlags {
    const directive = policy.getDirective("sandbox") orelse return null;
    return parseSandboxDirective(directive);
}

/// Get combined sandbox flags from all policies in CSP list.
/// Flags are merged (intersection - all policies must allow).
pub fn getCombinedSandboxFlags(csp_list: *const types.CSPList) ?SandboxFlags {
    var result: ?SandboxFlags = null;

    for (csp_list.policies.items) |*policy| {
        if (getSandboxFlags(policy)) |flags| {
            if (result) |*current| {
                current.* = current.merge(flags);
            } else {
                result = flags;
            }
        }
    }

    return result;
}

/// Check if scripts are allowed to run.
pub fn areScriptsAllowed(csp_list: *const types.CSPList) bool {
    const flags = getCombinedSandboxFlags(csp_list) orelse return true;
    return flags.allow_scripts;
}

/// Check if forms can be submitted.
pub fn areFormsAllowed(csp_list: *const types.CSPList) bool {
    const flags = getCombinedSandboxFlags(csp_list) orelse return true;
    return flags.allow_forms;
}

/// Check if popups are allowed.
pub fn arePopupsAllowed(csp_list: *const types.CSPList) bool {
    const flags = getCombinedSandboxFlags(csp_list) orelse return true;
    return flags.allow_popups;
}

/// Check if top-level navigation is allowed.
pub fn isTopNavigationAllowed(csp_list: *const types.CSPList, has_user_activation: bool) bool {
    const flags = getCombinedSandboxFlags(csp_list) orelse return true;

    if (flags.allow_top_navigation) return true;
    if (has_user_activation and flags.allow_top_navigation_by_user_activation) return true;

    return false;
}

// ============================================================================
// Tests
// ============================================================================

test "SandboxFlags.allRestricted" {
    const flags = SandboxFlags.allRestricted();

    try std.testing.expect(!flags.allow_forms);
    try std.testing.expect(!flags.allow_scripts);
    try std.testing.expect(!flags.allow_popups);
    try std.testing.expect(!flags.allow_same_origin);
}

test "SandboxFlags.allAllowed" {
    const flags = SandboxFlags.allAllowed();

    try std.testing.expect(flags.allow_forms);
    try std.testing.expect(flags.allow_scripts);
    try std.testing.expect(flags.allow_popups);
    try std.testing.expect(flags.allow_same_origin);
}

test "SandboxFlags.merge" {
    var a = SandboxFlags.allRestricted();
    a.allow_scripts = true;
    a.allow_forms = true;

    var b = SandboxFlags.allRestricted();
    b.allow_scripts = true;
    b.allow_popups = true;

    const merged = a.merge(b);

    // Only scripts should be allowed (intersection)
    try std.testing.expect(merged.allow_scripts);
    try std.testing.expect(!merged.allow_forms);
    try std.testing.expect(!merged.allow_popups);
}

test "parseSandboxDirective - empty value" {
    const allocator = std.testing.allocator;

    var directive = try types.Directive.create(allocator, "sandbox");
    defer directive.deinit();

    const flags = parseSandboxDirective(&directive);

    // Empty sandbox = all restrictions
    try std.testing.expect(!flags.allow_forms);
    try std.testing.expect(!flags.allow_scripts);
    try std.testing.expect(!flags.allow_popups);
}

test "parseSandboxDirective - with tokens" {
    const allocator = std.testing.allocator;

    var directive = try types.Directive.create(allocator, "sandbox");
    defer directive.deinit();

    try directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "allow-scripts"));
    try directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "allow-forms"));

    const flags = parseSandboxDirective(&directive);

    try std.testing.expect(flags.allow_scripts);
    try std.testing.expect(flags.allow_forms);
    try std.testing.expect(!flags.allow_popups);
}

test "getSandboxFlags - no directive" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    const flags = getSandboxFlags(&policy);
    try std.testing.expect(flags == null);
}

test "getSandboxFlags - with directive" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var directive = try types.Directive.create(allocator, "sandbox");
    try directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "allow-scripts"));
    try policy.directive_set.append(directive);

    const flags = getSandboxFlags(&policy);
    try std.testing.expect(flags != null);
    try std.testing.expect(flags.?.allow_scripts);
    try std.testing.expect(!flags.?.allow_forms);
}
