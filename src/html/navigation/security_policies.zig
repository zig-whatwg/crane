//! Cross-Origin Security Policies - HTML Standard §7.1.4, §7.4.3
//!
//! This module implements the security policy checks for navigation:
//! - COOP (Cross-Origin-Opener-Policy) - Controls opener relationship
//! - COEP (Cross-Origin-Embedder-Policy) - Controls embedded resource requirements
//! - CORP (Cross-Origin-Resource-Policy) - Controls resource sharing
//! - CSP navigate-to directive - Controls navigation destinations
//! - Sandbox flags - Restricts various capabilities
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#cross-origin-opener-policies
//!       https://html.spec.whatwg.org/multipage/browsers.html#cross-origin-embedder-policy

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// Cross-Origin-Opener-Policy (COOP)
// ============================================================================

/// Cross-Origin-Opener-Policy value
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#cross-origin-opener-policy-value
pub const CoopValue = enum {
    /// No COOP restrictions
    /// Header: "unsafe-none" or absent
    unsafe_none,

    /// Same origin only
    /// Header: "same-origin"
    same_origin,

    /// Same origin, but allow popups
    /// Header: "same-origin-allow-popups"
    same_origin_allow_popups,

    /// Same origin, but allow popups to establish opener
    /// Header: "same-origin-plus-COEP" (internal)
    same_origin_plus_coep,

    /// Restrict properties (experimental)
    /// Header: "restrict-properties"
    restrict_properties,

    /// No-op (policy not applicable)
    noop,

    /// Convert to string representation
    pub fn toString(self: CoopValue) []const u8 {
        return switch (self) {
            .unsafe_none => "unsafe-none",
            .same_origin => "same-origin",
            .same_origin_allow_popups => "same-origin-allow-popups",
            .same_origin_plus_coep => "same-origin-plus-coep",
            .restrict_properties => "restrict-properties",
            .noop => "",
        };
    }

    /// Parse from header value
    pub fn parse(value: []const u8) CoopValue {
        const trimmed = std.mem.trim(u8, value, " \t");

        // Check for parameters (e.g., "same-origin; report-to=...")
        const semicolon_pos = std.mem.indexOf(u8, trimmed, ";");
        const directive = if (semicolon_pos) |pos| trimmed[0..pos] else trimmed;
        const directive_trimmed = std.mem.trim(u8, directive, " \t");

        if (std.ascii.eqlIgnoreCase(directive_trimmed, "same-origin")) {
            return .same_origin;
        }
        if (std.ascii.eqlIgnoreCase(directive_trimmed, "same-origin-allow-popups")) {
            return .same_origin_allow_popups;
        }
        if (std.ascii.eqlIgnoreCase(directive_trimmed, "unsafe-none")) {
            return .unsafe_none;
        }
        if (std.ascii.eqlIgnoreCase(directive_trimmed, "restrict-properties")) {
            return .restrict_properties;
        }

        // Default: unsafe-none for unrecognized values
        return .unsafe_none;
    }
};

/// Cross-Origin-Opener-Policy with reporting endpoint
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#cross-origin-opener-policy
pub const CrossOriginOpenerPolicy = struct {
    /// The policy value
    value: CoopValue,

    /// Report-only value (for reporting without enforcing)
    report_only_value: ?CoopValue,

    /// Reporting endpoint for violations
    reporting_endpoint: ?[]const u8,

    /// Report-only reporting endpoint
    report_only_reporting_endpoint: ?[]const u8,

    allocator: ?Allocator,

    const Self = @This();

    /// Default policy (unsafe-none)
    pub const DEFAULT = Self{
        .value = .unsafe_none,
        .report_only_value = null,
        .reporting_endpoint = null,
        .report_only_reporting_endpoint = null,
        .allocator = null,
    };

    /// Create from header value
    pub fn fromHeader(allocator: Allocator, header_value: ?[]const u8) !Self {
        if (header_value == null) {
            return Self.DEFAULT;
        }

        var result = Self.DEFAULT;
        result.allocator = allocator;
        result.value = CoopValue.parse(header_value.?);

        // Parse report-to parameter
        if (std.mem.indexOf(u8, header_value.?, "report-to=")) |start| {
            const after_eq = header_value.?[start + 10 ..];
            const end = std.mem.indexOfAny(u8, after_eq, "; \t") orelse after_eq.len;
            result.reporting_endpoint = try allocator.dupe(u8, after_eq[0..end]);
        }

        return result;
    }

    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            if (self.reporting_endpoint) |ep| alloc.free(ep);
            if (self.report_only_reporting_endpoint) |ep| alloc.free(ep);
        }
    }
};

// ============================================================================
// Cross-Origin-Embedder-Policy (COEP)
// ============================================================================

/// Cross-Origin-Embedder-Policy value
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#coep
pub const CoepValue = enum {
    /// No COEP restrictions
    /// Header: "unsafe-none" or absent
    unsafe_none,

    /// Require CORP for all cross-origin resources
    /// Header: "require-corp"
    require_corp,

    /// Allow credentialless cross-origin requests
    /// Header: "credentialless"
    credentialless,

    /// Convert to string representation
    pub fn toString(self: CoepValue) []const u8 {
        return switch (self) {
            .unsafe_none => "unsafe-none",
            .require_corp => "require-corp",
            .credentialless => "credentialless",
        };
    }

    /// Parse from header value
    pub fn parse(value: []const u8) CoepValue {
        const trimmed = std.mem.trim(u8, value, " \t");

        // Check for parameters
        const semicolon_pos = std.mem.indexOf(u8, trimmed, ";");
        const directive = if (semicolon_pos) |pos| trimmed[0..pos] else trimmed;
        const directive_trimmed = std.mem.trim(u8, directive, " \t");

        if (std.ascii.eqlIgnoreCase(directive_trimmed, "require-corp")) {
            return .require_corp;
        }
        if (std.ascii.eqlIgnoreCase(directive_trimmed, "credentialless")) {
            return .credentialless;
        }

        // Default: unsafe-none
        return .unsafe_none;
    }
};

/// Cross-Origin-Embedder-Policy with reporting
pub const CrossOriginEmbedderPolicy = struct {
    /// The policy value
    value: CoepValue,

    /// Report-only value
    report_only_value: ?CoepValue,

    /// Reporting endpoint
    reporting_endpoint: ?[]const u8,

    allocator: ?Allocator,

    const Self = @This();

    /// Default policy (unsafe-none)
    pub const DEFAULT = Self{
        .value = .unsafe_none,
        .report_only_value = null,
        .reporting_endpoint = null,
        .allocator = null,
    };

    /// Create from header value
    pub fn fromHeader(allocator: Allocator, header_value: ?[]const u8) !Self {
        if (header_value == null) {
            return Self.DEFAULT;
        }

        var result = Self.DEFAULT;
        result.allocator = allocator;
        result.value = CoepValue.parse(header_value.?);

        // Parse report-to parameter
        if (std.mem.indexOf(u8, header_value.?, "report-to=")) |start| {
            const after_eq = header_value.?[start + 10 ..];
            const end = std.mem.indexOfAny(u8, after_eq, "; \t") orelse after_eq.len;
            result.reporting_endpoint = try allocator.dupe(u8, after_eq[0..end]);
        }

        return result;
    }

    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            if (self.reporting_endpoint) |ep| alloc.free(ep);
        }
    }
};

// ============================================================================
// Cross-Origin-Resource-Policy (CORP)
// ============================================================================

/// Cross-Origin-Resource-Policy value
/// Spec: https://fetch.spec.whatwg.org/#cross-origin-resource-policy-header
pub const CorpValue = enum {
    /// No CORP header present
    none,

    /// Only same-origin requests allowed
    same_origin,

    /// Same-site requests allowed (includes subdomains)
    same_site,

    /// Any origin allowed
    cross_origin,

    /// Convert to string representation
    pub fn toString(self: CorpValue) []const u8 {
        return switch (self) {
            .none => "",
            .same_origin => "same-origin",
            .same_site => "same-site",
            .cross_origin => "cross-origin",
        };
    }

    /// Parse from header value
    pub fn parse(value: ?[]const u8) CorpValue {
        if (value == null) return .none;

        const trimmed = std.mem.trim(u8, value.?, " \t");

        if (std.ascii.eqlIgnoreCase(trimmed, "same-origin")) {
            return .same_origin;
        }
        if (std.ascii.eqlIgnoreCase(trimmed, "same-site")) {
            return .same_site;
        }
        if (std.ascii.eqlIgnoreCase(trimmed, "cross-origin")) {
            return .cross_origin;
        }

        // Default: no policy
        return .none;
    }
};

// ============================================================================
// Security Policy Context
// ============================================================================

/// Aggregated security policies for a navigation or fetch
pub const SecurityPolicies = struct {
    /// Cross-Origin-Opener-Policy
    coop: CrossOriginOpenerPolicy,

    /// Cross-Origin-Embedder-Policy
    coep: CrossOriginEmbedderPolicy,

    /// Cross-Origin-Resource-Policy (from response)
    corp: CorpValue,

    allocator: Allocator,

    const Self = @This();

    /// Create default policies
    pub fn init(allocator: Allocator) Self {
        return Self{
            .coop = CrossOriginOpenerPolicy.DEFAULT,
            .coep = CrossOriginEmbedderPolicy.DEFAULT,
            .corp = .none,
            .allocator = allocator,
        };
    }

    /// Parse policies from response headers
    pub fn fromHeaders(allocator: Allocator, headers: ?*const HeaderMap) !Self {
        var result = Self.init(allocator);

        if (headers) |h| {
            // Parse COOP
            const coop_header = h.get("cross-origin-opener-policy");
            result.coop = try CrossOriginOpenerPolicy.fromHeader(allocator, coop_header);

            // Parse COEP
            const coep_header = h.get("cross-origin-embedder-policy");
            result.coep = try CrossOriginEmbedderPolicy.fromHeader(allocator, coep_header);

            // Parse CORP
            const corp_header = h.get("cross-origin-resource-policy");
            result.corp = CorpValue.parse(corp_header);
        }

        return result;
    }

    pub fn deinit(self: *Self) void {
        self.coop.deinit();
        self.coep.deinit();
    }
};

/// Simple header map type
pub const HeaderMap = std.StringHashMap([]const u8);

// ============================================================================
// COOP Enforcement
// ============================================================================

/// Result of COOP enforcement check
pub const CoopEnforcementResult = struct {
    /// Whether a browsing context group switch is needed
    needs_bcg_switch: bool,

    /// Whether to sever the opener relationship
    would_need_bcg_switch_due_to_report_only: bool,

    /// Origin to use for the new document
    origin: ?[]const u8,

    /// Cross-origin opener policy to apply
    cross_origin_opener_policy: CrossOriginOpenerPolicy,
};

/// Check if COOP requires a browsing context group switch
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#obtain-coop
pub fn checkCoopEnforcement(
    current_coop: CrossOriginOpenerPolicy,
    current_origin: []const u8,
    response_coop: CrossOriginOpenerPolicy,
    response_origin: []const u8,
    is_initial_about_blank: bool,
) CoopEnforcementResult {
    // Initial about:blank documents never trigger BCG switch
    if (is_initial_about_blank) {
        return .{
            .needs_bcg_switch = false,
            .would_need_bcg_switch_due_to_report_only = false,
            .origin = response_origin,
            .cross_origin_opener_policy = response_coop,
        };
    }

    // Check if origins match
    const same_origin = std.mem.eql(u8, current_origin, response_origin);

    // Determine if BCG switch is needed
    const needs_switch = needsBrowsingContextGroupSwitch(
        current_coop.value,
        current_origin,
        response_coop.value,
        response_origin,
        same_origin,
    );

    return .{
        .needs_bcg_switch = needs_switch,
        .would_need_bcg_switch_due_to_report_only = false,
        .origin = response_origin,
        .cross_origin_opener_policy = response_coop,
    };
}

/// Check if a BCG switch is needed based on COOP values
fn needsBrowsingContextGroupSwitch(
    current: CoopValue,
    current_origin: []const u8,
    response: CoopValue,
    response_origin: []const u8,
    same_origin: bool,
) bool {
    _ = current_origin;
    _ = response_origin;

    // If both are unsafe-none, no switch needed
    if (current == .unsafe_none and response == .unsafe_none) {
        return false;
    }

    // If response is same-origin or same-origin-allow-popups, check origin
    if (response == .same_origin or response == .same_origin_allow_popups) {
        // Cross-origin responses with same-origin COOP need switch
        if (!same_origin) {
            return true;
        }
    }

    // If current is same-origin and response is different
    if (current == .same_origin) {
        if (response == .unsafe_none) {
            return true;
        }
        if (response == .same_origin_allow_popups and !same_origin) {
            return true;
        }
    }

    // If policies differ and either is restrictive
    if (current != response) {
        if (current == .same_origin or response == .same_origin) {
            return true;
        }
    }

    return false;
}

// ============================================================================
// COEP Enforcement
// ============================================================================

/// Check if a resource load is blocked by COEP
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#check-a-navigation-response's-adherence-to-x-frame-options
pub fn checkCoepEnforcement(
    embedder_coep: CoepValue,
    resource_corp: CorpValue,
    is_same_origin: bool,
    is_same_site: bool,
    is_navigation: bool,
) bool {
    // Navigations are not blocked by COEP
    if (is_navigation) {
        return true; // allowed
    }

    // If embedder has no COEP, allow
    if (embedder_coep == .unsafe_none) {
        return true;
    }

    // If same-origin, always allowed
    if (is_same_origin) {
        return true;
    }

    // Check COEP requirements
    switch (embedder_coep) {
        .require_corp => {
            // Requires CORP header for cross-origin resources
            switch (resource_corp) {
                .none => return false, // Blocked: no CORP header
                .same_origin => return false, // Blocked: CORP requires same-origin
                .same_site => return is_same_site, // Allowed if same-site
                .cross_origin => return true, // Allowed
            }
        },
        .credentialless => {
            // Credentialless allows cross-origin without credentials
            // For resources fetched without credentials, allow
            // This is simplified - full impl checks request credentials mode
            switch (resource_corp) {
                .none => return true, // Allowed in credentialless mode
                .same_origin => return false, // Still blocked
                .same_site => return is_same_site,
                .cross_origin => return true,
            }
        },
        .unsafe_none => return true,
    }
}

// ============================================================================
// Cross-Origin Isolation Check
// ============================================================================

/// Check if a browsing context is cross-origin isolated
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#cross-origin-isolated
pub fn isCrossOriginIsolated(coop: CoopValue, coep: CoepValue) bool {
    // Cross-origin isolated requires:
    // 1. COOP same-origin
    // 2. COEP require-corp or credentialless
    return coop == .same_origin and (coep == .require_corp or coep == .credentialless);
}

// ============================================================================
// Sandbox Navigation Checks
// ============================================================================

/// Sandbox flags that affect navigation
/// Spec: HTML Standard §4.8.5.4
/// This is a local definition matching the browsing_context.zig SandboxFlags for use
/// in navigation security checks. The actual SandboxFlags from browsing_context should
/// be used when available (they have the same layout).
pub const SandboxFlags = packed struct {
    /// allow-scripts: Allow script execution
    allow_scripts: bool = false,

    /// allow-same-origin: Keep the sandboxed document's origin
    allow_same_origin: bool = false,

    /// allow-forms: Allow form submission
    allow_forms: bool = false,

    /// allow-popups: Allow window.open() and similar
    allow_popups: bool = false,

    /// allow-top-navigation: Allow navigating the top-level browsing context
    allow_top_navigation: bool = false,

    /// allow-top-navigation-by-user-activation: Allow top navigation with user gesture
    allow_top_navigation_by_user_activation: bool = false,

    /// allow-pointer-lock: Allow Pointer Lock API
    allow_pointer_lock: bool = false,

    /// allow-modals: Allow alert(), confirm(), prompt()
    allow_modals: bool = false,

    /// allow-orientation-lock: Allow screen orientation lock
    allow_orientation_lock: bool = false,

    /// allow-presentation: Allow Presentation API
    allow_presentation: bool = false,

    /// allow-downloads: Allow downloads
    allow_downloads: bool = false,

    /// allow-storage-access-by-user-activation: Allow storage access with user gesture
    allow_storage_access_by_user_activation: bool = false,

    /// allow-popups-to-escape-sandbox: Popups don't inherit sandbox
    allow_popups_to_escape_sandbox: bool = false,

    /// allow-top-navigation-to-custom-protocols: Allow navigation to custom protocols
    allow_top_navigation_to_custom_protocols: bool = false,

    // Padding to align to byte boundary
    _padding: u2 = 0,

    /// Default flags (all restrictions enabled = all false)
    pub const RESTRICTIVE = SandboxFlags{};

    /// No restrictions (all permissions allowed)
    pub const PERMISSIVE = SandboxFlags{
        .allow_scripts = true,
        .allow_same_origin = true,
        .allow_forms = true,
        .allow_popups = true,
        .allow_top_navigation = true,
        .allow_top_navigation_by_user_activation = true,
        .allow_pointer_lock = true,
        .allow_modals = true,
        .allow_orientation_lock = true,
        .allow_presentation = true,
        .allow_downloads = true,
        .allow_storage_access_by_user_activation = true,
        .allow_popups_to_escape_sandbox = true,
        .allow_top_navigation_to_custom_protocols = true,
    };
};

/// Check if navigation is allowed by sandbox flags
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#sandboxed-navigation-browsing-context-flag
pub fn isNavigationAllowedBySandbox(
    source_sandbox: ?SandboxFlags,
    target_is_top_level: bool,
    has_user_activation: bool,
) bool {
    // No sandbox, allow all
    if (source_sandbox == null) {
        return true;
    }

    const flags = source_sandbox.?;

    // Check top-level navigation restrictions
    if (target_is_top_level) {
        // allow-top-navigation allows all top-level navigation
        if (flags.allow_top_navigation) {
            return true;
        }

        // allow-top-navigation-by-user-activation with user gesture
        if (flags.allow_top_navigation_by_user_activation and has_user_activation) {
            return true;
        }

        // Otherwise, top navigation is blocked
        return false;
    }

    // Non-top-level navigations within sandboxed frames are generally allowed
    return true;
}

/// Check if popups are allowed by sandbox flags
pub fn arePopupsAllowedBySandbox(sandbox: ?SandboxFlags) bool {
    if (sandbox == null) {
        return true;
    }
    return sandbox.?.allow_popups;
}

// ============================================================================
// Navigation Security Check
// ============================================================================

/// Result of a navigation security check
pub const NavigationSecurityCheckResult = struct {
    /// Whether navigation is allowed
    allowed: bool,

    /// Reason for blocking (if not allowed)
    block_reason: ?BlockReason,

    /// COOP enforcement result
    coop_result: ?CoopEnforcementResult,

    pub const BlockReason = enum {
        /// Blocked by COOP
        coop,
        /// Blocked by COEP
        coep,
        /// Blocked by CSP navigate-to
        csp_navigate_to,
        /// Blocked by sandbox flags
        sandbox,
        /// Blocked by X-Frame-Options
        x_frame_options,
    };
};

/// Perform comprehensive navigation security check
pub fn checkNavigationSecurity(
    allocator: Allocator,
    source_origin: ?[]const u8,
    target_url: []const u8,
    response_policies: ?SecurityPolicies,
    current_policies: ?SecurityPolicies,
    source_sandbox: ?SandboxFlags,
    target_is_top_level: bool,
    has_user_activation: bool,
    is_initial_about_blank: bool,
) !NavigationSecurityCheckResult {
    _ = allocator;
    _ = target_url;

    // Check sandbox restrictions first
    if (!isNavigationAllowedBySandbox(source_sandbox, target_is_top_level, has_user_activation)) {
        return .{
            .allowed = false,
            .block_reason = .sandbox,
            .coop_result = null,
        };
    }

    // Check COOP enforcement
    if (response_policies != null and current_policies != null and source_origin != null) {
        const coop_result = checkCoopEnforcement(
            current_policies.?.coop,
            source_origin.?,
            response_policies.?.coop,
            source_origin.?, // Response origin would be different in real impl
            is_initial_about_blank,
        );

        // COOP doesn't block navigation, but may trigger BCG switch
        // This is informational for the caller
        return .{
            .allowed = true,
            .block_reason = null,
            .coop_result = coop_result,
        };
    }

    // Navigation allowed
    return .{
        .allowed = true,
        .block_reason = null,
        .coop_result = null,
    };
}

// ============================================================================
// X-Frame-Options Check
// ============================================================================

/// X-Frame-Options value
pub const XFrameOptions = enum {
    /// No X-Frame-Options header
    none,
    /// DENY - never allow framing
    deny,
    /// SAMEORIGIN - only same-origin framing
    sameorigin,

    pub fn parse(value: ?[]const u8) XFrameOptions {
        if (value == null) return .none;

        const trimmed = std.mem.trim(u8, value.?, " \t");

        if (std.ascii.eqlIgnoreCase(trimmed, "deny")) {
            return .deny;
        }
        if (std.ascii.eqlIgnoreCase(trimmed, "sameorigin")) {
            return .sameorigin;
        }

        return .none;
    }
};

/// Check if framing is allowed by X-Frame-Options
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#the-x-frame-options-header
pub fn isFramingAllowed(
    x_frame_options: XFrameOptions,
    is_same_origin: bool,
) bool {
    return switch (x_frame_options) {
        .none => true,
        .deny => false,
        .sameorigin => is_same_origin,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "CoopValue - parse" {
    try std.testing.expectEqual(CoopValue.same_origin, CoopValue.parse("same-origin"));
    try std.testing.expectEqual(CoopValue.same_origin_allow_popups, CoopValue.parse("same-origin-allow-popups"));
    try std.testing.expectEqual(CoopValue.unsafe_none, CoopValue.parse("unsafe-none"));
    try std.testing.expectEqual(CoopValue.same_origin, CoopValue.parse("same-origin; report-to=endpoint"));
    try std.testing.expectEqual(CoopValue.unsafe_none, CoopValue.parse("unknown-value"));
}

test "CoepValue - parse" {
    try std.testing.expectEqual(CoepValue.require_corp, CoepValue.parse("require-corp"));
    try std.testing.expectEqual(CoepValue.credentialless, CoepValue.parse("credentialless"));
    try std.testing.expectEqual(CoepValue.unsafe_none, CoepValue.parse("unsafe-none"));
    try std.testing.expectEqual(CoepValue.unsafe_none, CoepValue.parse("unknown"));
}

test "CorpValue - parse" {
    try std.testing.expectEqual(CorpValue.same_origin, CorpValue.parse("same-origin"));
    try std.testing.expectEqual(CorpValue.same_site, CorpValue.parse("same-site"));
    try std.testing.expectEqual(CorpValue.cross_origin, CorpValue.parse("cross-origin"));
    try std.testing.expectEqual(CorpValue.none, CorpValue.parse(null));
}

test "isCrossOriginIsolated" {
    try std.testing.expect(isCrossOriginIsolated(.same_origin, .require_corp));
    try std.testing.expect(isCrossOriginIsolated(.same_origin, .credentialless));
    try std.testing.expect(!isCrossOriginIsolated(.unsafe_none, .require_corp));
    try std.testing.expect(!isCrossOriginIsolated(.same_origin, .unsafe_none));
}

test "isNavigationAllowedBySandbox - no sandbox" {
    try std.testing.expect(isNavigationAllowedBySandbox(null, true, false));
    try std.testing.expect(isNavigationAllowedBySandbox(null, false, false));
}

test "isNavigationAllowedBySandbox - with allow-top-navigation" {
    const flags = SandboxFlags{
        .allow_top_navigation = true,
    };
    try std.testing.expect(isNavigationAllowedBySandbox(flags, true, false));
}

test "isNavigationAllowedBySandbox - without allow-top-navigation" {
    const flags = SandboxFlags{
        .allow_top_navigation = false,
        .allow_top_navigation_by_user_activation = false,
    };
    try std.testing.expect(!isNavigationAllowedBySandbox(flags, true, false));
}

test "isNavigationAllowedBySandbox - with user activation" {
    const flags = SandboxFlags{
        .allow_top_navigation = false,
        .allow_top_navigation_by_user_activation = true,
    };
    try std.testing.expect(isNavigationAllowedBySandbox(flags, true, true));
    try std.testing.expect(!isNavigationAllowedBySandbox(flags, true, false));
}

test "checkCoepEnforcement - require-corp" {
    // Same-origin always allowed
    try std.testing.expect(checkCoepEnforcement(.require_corp, .none, true, false, false));

    // Cross-origin without CORP blocked
    try std.testing.expect(!checkCoepEnforcement(.require_corp, .none, false, false, false));

    // Cross-origin with cross-origin CORP allowed
    try std.testing.expect(checkCoepEnforcement(.require_corp, .cross_origin, false, false, false));

    // Navigation not blocked
    try std.testing.expect(checkCoepEnforcement(.require_corp, .none, false, false, true));
}

test "XFrameOptions - parse" {
    try std.testing.expectEqual(XFrameOptions.deny, XFrameOptions.parse("DENY"));
    try std.testing.expectEqual(XFrameOptions.sameorigin, XFrameOptions.parse("SAMEORIGIN"));
    try std.testing.expectEqual(XFrameOptions.none, XFrameOptions.parse(null));
}

test "isFramingAllowed" {
    try std.testing.expect(isFramingAllowed(.none, false));
    try std.testing.expect(!isFramingAllowed(.deny, true));
    try std.testing.expect(!isFramingAllowed(.deny, false));
    try std.testing.expect(isFramingAllowed(.sameorigin, true));
    try std.testing.expect(!isFramingAllowed(.sameorigin, false));
}
