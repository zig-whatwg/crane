//! Permissions Policy Implementation
//!
//! W3C Permissions Policy Specification
//! https://www.w3.org/TR/permissions-policy/
//!
//! Permissions Policy (formerly Feature Policy) allows web developers to selectively
//! enable, disable, or modify the behavior of certain APIs and web features in the
//! browser. It provides a mechanism to explicitly declare what functionality can be
//! used in a document and its child frames.
//!
//! ## Features
//!
//! - **Policy-controlled features**: APIs like geolocation, camera, microphone
//! - **Allowlist-based control**: Features can be allowed/denied per origin
//! - **Inheritance**: Child frames inherit policies from parents
//! - **Headers and attributes**: Policies via HTTP headers or iframe allow attribute
//!
//! ## Usage
//!
//! ```zig
//! const policy = @import("html").permissions_policy;
//!
//! // Parse a Permissions-Policy header
//! var pp = try policy.PermissionsPolicy.fromHeader(allocator,
//!     "geolocation=(), camera=(self \"https://example.com\")"
//! );
//! defer pp.deinit();
//!
//! // Check if a feature is allowed for an origin
//! const allowed = pp.isFeatureAllowed(.geolocation, origin);
//! ```
//!
//! ## Specification References
//!
//! - Permissions Policy: https://www.w3.org/TR/permissions-policy/
//! - HTML Standard § 7.10.2: Permissions Policy
//! - Feature Policy (predecessor): https://w3c.github.io/webappsec-feature-policy/

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// Policy-Controlled Features
// ============================================================================

/// Policy-controlled features
/// Spec: https://www.w3.org/TR/permissions-policy/#features
pub const Feature = enum {
    // Sensors
    accelerometer,
    ambient_light_sensor,
    gyroscope,
    magnetometer,

    // Media
    autoplay,
    camera,
    display_capture,
    microphone,
    speaker_selection,

    // Power
    battery,

    // Device APIs
    bluetooth,
    hid,
    serial,
    usb,

    // Location
    geolocation,

    // Screen
    fullscreen,
    picture_in_picture,
    screen_wake_lock,

    // WebXR
    xr_spatial_tracking,

    // Payments
    payment,

    // Clipboard
    clipboard_read,
    clipboard_write,

    // Document/DOM
    document_domain,
    encrypted_media,
    execution_while_not_rendered,
    execution_while_out_of_viewport,
    focus_without_user_activation,
    gamepad,
    idle_detection,
    interest_cohort, // deprecated/removed
    local_fonts,
    midi,
    navigation_override,
    otp_credentials,
    publickey_credentials_get,
    screen_wake_lock_2, // Alternative name
    sync_xhr,
    unload,
    web_share,

    // Display
    browsing_topics, // Privacy Sandbox

    /// Get the string name of the feature (lowercase with hyphens)
    pub fn toString(self: Feature) []const u8 {
        return switch (self) {
            .accelerometer => "accelerometer",
            .ambient_light_sensor => "ambient-light-sensor",
            .gyroscope => "gyroscope",
            .magnetometer => "magnetometer",
            .autoplay => "autoplay",
            .camera => "camera",
            .display_capture => "display-capture",
            .microphone => "microphone",
            .speaker_selection => "speaker-selection",
            .battery => "battery",
            .bluetooth => "bluetooth",
            .hid => "hid",
            .serial => "serial",
            .usb => "usb",
            .geolocation => "geolocation",
            .fullscreen => "fullscreen",
            .picture_in_picture => "picture-in-picture",
            .screen_wake_lock, .screen_wake_lock_2 => "screen-wake-lock",
            .xr_spatial_tracking => "xr-spatial-tracking",
            .payment => "payment",
            .clipboard_read => "clipboard-read",
            .clipboard_write => "clipboard-write",
            .document_domain => "document-domain",
            .encrypted_media => "encrypted-media",
            .execution_while_not_rendered => "execution-while-not-rendered",
            .execution_while_out_of_viewport => "execution-while-out-of-viewport",
            .focus_without_user_activation => "focus-without-user-activation",
            .gamepad => "gamepad",
            .idle_detection => "idle-detection",
            .interest_cohort => "interest-cohort",
            .local_fonts => "local-fonts",
            .midi => "midi",
            .navigation_override => "navigation-override",
            .otp_credentials => "otp-credentials",
            .publickey_credentials_get => "publickey-credentials-get",
            .sync_xhr => "sync-xhr",
            .unload => "unload",
            .web_share => "web-share",
            .browsing_topics => "browsing-topics",
        };
    }

    /// Parse a feature name from a string
    pub fn fromString(name: []const u8) ?Feature {
        // Normalize by lowercasing
        inline for (std.meta.fields(Feature)) |field| {
            const feature: Feature = @enumFromInt(field.value);
            if (std.ascii.eqlIgnoreCase(name, feature.toString())) {
                return feature;
            }
        }
        return null;
    }

    /// Get the default allowlist for this feature
    /// Spec: https://www.w3.org/TR/permissions-policy/#default-allowlist
    pub fn defaultAllowlist(self: Feature) DefaultAllowlist {
        return switch (self) {
            // Features that default to self (most restrictive common default)
            .camera,
            .microphone,
            .geolocation,
            .display_capture,
            .battery,
            .bluetooth,
            .usb,
            .hid,
            .serial,
            .midi,
            .xr_spatial_tracking,
            .idle_detection,
            .otp_credentials,
            .publickey_credentials_get,
            .local_fonts,
            => .self_origin,

            // Features that default to * (most permissive)
            .autoplay,
            .fullscreen,
            .picture_in_picture,
            .document_domain,
            .encrypted_media,
            .gamepad,
            .sync_xhr,
            .web_share,
            => .all,

            // Features that default to self
            else => .self_origin,
        };
    }
};

/// Default allowlist type
pub const DefaultAllowlist = enum {
    /// "*" - All origins allowed
    all,
    /// "self" - Only same-origin allowed
    self_origin,
    /// "()" - No origins allowed
    none,
};

// ============================================================================
// Allowlist
// ============================================================================

/// An allowlist specifies which origins may use a feature
/// Spec: https://www.w3.org/TR/permissions-policy/#allowlist
pub const Allowlist = struct {
    /// Special value: allow all origins
    allow_all: bool = false,

    /// Special value: allow self (same origin as document)
    allow_self: bool = false,

    /// Specific origins that are allowed
    origins: std.ArrayList([]const u8),

    /// Allocator for this allowlist
    allocator: Allocator,

    const Self = @This();

    /// Create an empty allowlist
    pub fn init(allocator: Allocator) Self {
        return .{
            .allow_all = false,
            .allow_self = false,
            .origins = std.ArrayList([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    /// Create an allowlist that allows all origins
    pub fn allowAll(allocator: Allocator) Self {
        return .{
            .allow_all = true,
            .allow_self = false,
            .origins = std.ArrayList([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    /// Create an allowlist that allows only self
    pub fn allowSelf(allocator: Allocator) Self {
        return .{
            .allow_all = false,
            .allow_self = true,
            .origins = std.ArrayList([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    /// Create an allowlist that allows nothing
    pub fn allowNone(allocator: Allocator) Self {
        return .{
            .allow_all = false,
            .allow_self = false,
            .origins = std.ArrayList([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    /// Add an origin to the allowlist
    pub fn addOrigin(self: *Self, origin: []const u8) !void {
        const origin_copy = try self.allocator.dupe(u8, origin);
        try self.origins.append(origin_copy);
    }

    /// Check if an origin is allowed
    pub fn isAllowed(self: *const Self, origin: []const u8, self_origin: []const u8) bool {
        // Allow all means all origins are allowed
        if (self.allow_all) {
            return true;
        }

        // Allow self means same-origin is allowed
        if (self.allow_self and std.mem.eql(u8, origin, self_origin)) {
            return true;
        }

        // Check specific origins
        for (self.origins.items) |allowed| {
            if (std.mem.eql(u8, origin, allowed)) {
                return true;
            }
        }

        return false;
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        for (self.origins.items) |origin| {
            self.allocator.free(origin);
        }
        self.origins.deinit();
    }
};

// ============================================================================
// Policy Directive
// ============================================================================

/// A policy directive is a feature-allowlist pair
/// Spec: https://www.w3.org/TR/permissions-policy/#policy-directive
pub const PolicyDirective = struct {
    feature: Feature,
    allowlist: Allowlist,

    const Self = @This();

    pub fn init(allocator: Allocator, feature: Feature) Self {
        return .{
            .feature = feature,
            .allowlist = Allowlist.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.allowlist.deinit();
    }
};

// ============================================================================
// Permissions Policy
// ============================================================================

/// Permissions Policy for a document
/// Spec: https://www.w3.org/TR/permissions-policy/#permissions-policy
pub const PermissionsPolicy = struct {
    /// Inherited policy from parent frame (null for top-level)
    inherited_policy: ?*const PermissionsPolicy,

    /// Declared policy (from header or iframe allow attribute)
    declared_policy: std.AutoHashMap(Feature, Allowlist),

    /// The origin of the document this policy applies to
    origin: []const u8,

    /// Whether this is for an iframe with sandbox without allow-same-origin
    /// (gives the document an opaque origin)
    is_sandboxed_without_same_origin: bool,

    /// Allocator
    allocator: Allocator,

    const Self = @This();

    /// Create a new permissions policy
    pub fn init(allocator: Allocator, origin: []const u8) !Self {
        return .{
            .inherited_policy = null,
            .declared_policy = std.AutoHashMap(Feature, Allowlist).init(allocator),
            .origin = try allocator.dupe(u8, origin),
            .is_sandboxed_without_same_origin = false,
            .allocator = allocator,
        };
    }

    /// Create from an HTTP Permissions-Policy header
    /// Spec: https://www.w3.org/TR/permissions-policy/#permissions-policy-http-header
    pub fn fromHeader(allocator: Allocator, header: []const u8, origin: []const u8) !Self {
        var policy = try Self.init(allocator, origin);
        errdefer policy.deinit();

        try policy.parseHeader(header);
        return policy;
    }

    /// Create from an iframe allow attribute
    /// Spec: https://www.w3.org/TR/permissions-policy/#iframe-allow-attribute
    pub fn fromAllowAttribute(
        allocator: Allocator,
        allow_value: []const u8,
        container_origin: []const u8,
        content_origin: []const u8,
    ) !Self {
        var policy = try Self.init(allocator, content_origin);
        errdefer policy.deinit();

        try policy.parseAllowAttribute(allow_value, container_origin);
        return policy;
    }

    /// Parse a Permissions-Policy header value
    fn parseHeader(self: *Self, header: []const u8) !void {
        // Format: feature1=(...), feature2=(...), ...
        var iter = std.mem.tokenizeAny(u8, header, ",");

        while (iter.next()) |directive_str| {
            const trimmed = std.mem.trim(u8, directive_str, " \t");

            // Split on '='
            const eq_pos = std.mem.indexOf(u8, trimmed, "=") orelse continue;
            const feature_name = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
            const allowlist_str = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t");

            // Parse feature
            const feature = Feature.fromString(feature_name) orelse continue;

            // Parse allowlist
            const allowlist = try self.parseAllowlist(allowlist_str);
            try self.declared_policy.put(feature, allowlist);
        }
    }

    /// Parse an iframe allow attribute value
    fn parseAllowAttribute(self: *Self, allow_value: []const u8, container_origin: []const u8) !void {
        // Format: feature1 'origin'; feature2; feature3 'origin1' 'origin2'
        var iter = std.mem.tokenizeAny(u8, allow_value, ";");

        while (iter.next()) |directive_str| {
            const trimmed = std.mem.trim(u8, directive_str, " \t");
            if (trimmed.len == 0) continue;

            // Split into feature name and origins
            var tokens = std.mem.tokenizeAny(u8, trimmed, " \t");
            const feature_name = tokens.next() orelse continue;

            const feature = Feature.fromString(feature_name) orelse continue;

            // Parse origins (or default to container + content origins)
            var allowlist = Allowlist.init(self.allocator);
            errdefer allowlist.deinit();

            var has_origins = false;
            while (tokens.next()) |token| {
                has_origins = true;
                const origin = std.mem.trim(u8, token, "'\"");
                if (std.mem.eql(u8, origin, "*")) {
                    allowlist.allow_all = true;
                } else if (std.mem.eql(u8, origin, "self")) {
                    // 'self' in allow attribute refers to the container's origin (parent document)
                    allowlist.allow_self = true;
                    try allowlist.addOrigin(container_origin);
                } else if (std.mem.eql(u8, origin, "src")) {
                    // 'src' means the iframe's src origin (content document)
                    try allowlist.addOrigin(self.origin);
                } else {
                    try allowlist.addOrigin(origin);
                }
            }

            // If no origins specified, allow src by default per spec
            if (!has_origins) {
                try allowlist.addOrigin(self.origin);
            }

            try self.declared_policy.put(feature, allowlist);
        }
    }

    /// Parse an allowlist string like "()" or "(*)" or "(self \"https://example.com\")"
    fn parseAllowlist(self: *Self, str: []const u8) !Allowlist {
        var allowlist = Allowlist.init(self.allocator);
        errdefer allowlist.deinit();

        // Remove parentheses
        var content = std.mem.trim(u8, str, " \t");
        if (std.mem.startsWith(u8, content, "(")) {
            content = content[1..];
        }
        if (std.mem.endsWith(u8, content, ")")) {
            content = content[0 .. content.len - 1];
        }
        content = std.mem.trim(u8, content, " \t");

        // Empty allowlist means no origins allowed
        if (content.len == 0) {
            return allowlist;
        }

        // Parse tokens
        var iter = std.mem.tokenizeAny(u8, content, " \t");
        while (iter.next()) |token| {
            const unquoted = std.mem.trim(u8, token, "\"'");

            if (std.mem.eql(u8, unquoted, "*")) {
                allowlist.allow_all = true;
            } else if (std.mem.eql(u8, unquoted, "self")) {
                allowlist.allow_self = true;
            } else {
                try allowlist.addOrigin(unquoted);
            }
        }

        return allowlist;
    }

    /// Check if a feature is allowed for an origin
    /// Spec: https://www.w3.org/TR/permissions-policy/#is-feature-enabled
    pub fn isFeatureAllowed(self: *const Self, feature: Feature, requesting_origin: []const u8) bool {
        // Sandboxed frames without allow-same-origin have opaque origins
        // which never match, so features are denied
        if (self.is_sandboxed_without_same_origin) {
            return false;
        }

        // Check inherited policy first
        if (self.inherited_policy) |parent| {
            if (!parent.isFeatureAllowed(feature, requesting_origin)) {
                return false;
            }
        }

        // Check declared policy
        if (self.declared_policy.get(feature)) |allowlist| {
            return allowlist.isAllowed(requesting_origin, self.origin);
        }

        // Use default allowlist for the feature
        return switch (feature.defaultAllowlist()) {
            .all => true,
            .self_origin => std.mem.eql(u8, requesting_origin, self.origin),
            .none => false,
        };
    }

    /// Check if a feature is allowed for self (document's own origin)
    pub fn isFeatureAllowedForSelf(self: *const Self, feature: Feature) bool {
        return self.isFeatureAllowed(feature, self.origin);
    }

    /// Set the inherited policy (from parent frame)
    pub fn setInheritedPolicy(self: *Self, parent: *const PermissionsPolicy) void {
        self.inherited_policy = parent;
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        var iter = self.declared_policy.iterator();
        while (iter.next()) |entry| {
            var allowlist = entry.value_ptr.*;
            allowlist.deinit();
        }
        self.declared_policy.deinit();
        self.allocator.free(self.origin);
    }
};

// ============================================================================
// Policy Enforcement
// ============================================================================

/// Error for policy violations
pub const PermissionsPolicyError = error{
    /// Feature is not allowed by the policy
    NotAllowedError,
};

/// Check if a feature is enabled and throw if not
pub fn requireFeature(policy: *const PermissionsPolicy, feature: Feature) PermissionsPolicyError!void {
    if (!policy.isFeatureAllowedForSelf(feature)) {
        return error.NotAllowedError;
    }
}

/// Report a policy violation (for console/DevTools)
pub const PolicyViolation = struct {
    feature: Feature,
    policy_origin: []const u8,
    requesting_origin: []const u8,
    message: []const u8,
};

/// Create a violation report for a blocked feature
pub fn createViolationReport(
    allocator: Allocator,
    feature: Feature,
    policy_origin: []const u8,
    requesting_origin: []const u8,
) !PolicyViolation {
    const message = try std.fmt.allocPrint(
        allocator,
        "Feature '{s}' is not allowed in this document. " ++
            "Origin '{s}' is not in the allowlist for origin '{s}'.",
        .{ feature.toString(), requesting_origin, policy_origin },
    );

    return .{
        .feature = feature,
        .policy_origin = policy_origin,
        .requesting_origin = requesting_origin,
        .message = message,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "Feature.fromString" {
    try std.testing.expectEqual(Feature.geolocation, Feature.fromString("geolocation").?);
    try std.testing.expectEqual(Feature.camera, Feature.fromString("camera").?);
    try std.testing.expectEqual(Feature.ambient_light_sensor, Feature.fromString("ambient-light-sensor").?);
    try std.testing.expect(Feature.fromString("nonexistent-feature") == null);
}

test "Allowlist - basic operations" {
    const allocator = std.testing.allocator;

    var allow_all = Allowlist.allowAll(allocator);
    defer allow_all.deinit();
    try std.testing.expect(allow_all.isAllowed("https://example.com", "https://self.com"));

    var allow_self = Allowlist.allowSelf(allocator);
    defer allow_self.deinit();
    try std.testing.expect(allow_self.isAllowed("https://self.com", "https://self.com"));
    try std.testing.expect(!allow_self.isAllowed("https://other.com", "https://self.com"));

    var allow_none = Allowlist.allowNone(allocator);
    defer allow_none.deinit();
    try std.testing.expect(!allow_none.isAllowed("https://example.com", "https://self.com"));
}

test "Allowlist - specific origins" {
    const allocator = std.testing.allocator;

    var allowlist = Allowlist.init(allocator);
    defer allowlist.deinit();

    try allowlist.addOrigin("https://allowed.com");
    try allowlist.addOrigin("https://also-allowed.com");

    try std.testing.expect(allowlist.isAllowed("https://allowed.com", "https://self.com"));
    try std.testing.expect(allowlist.isAllowed("https://also-allowed.com", "https://self.com"));
    try std.testing.expect(!allowlist.isAllowed("https://not-allowed.com", "https://self.com"));
}

test "PermissionsPolicy - default allowlists" {
    const allocator = std.testing.allocator;

    var policy = try PermissionsPolicy.init(allocator, "https://example.com");
    defer policy.deinit();

    // Geolocation defaults to self
    try std.testing.expect(policy.isFeatureAllowed(.geolocation, "https://example.com"));
    try std.testing.expect(!policy.isFeatureAllowed(.geolocation, "https://other.com"));

    // Fullscreen defaults to *
    try std.testing.expect(policy.isFeatureAllowed(.fullscreen, "https://example.com"));
    try std.testing.expect(policy.isFeatureAllowed(.fullscreen, "https://other.com"));
}

test "PermissionsPolicy - fromHeader" {
    const allocator = std.testing.allocator;

    var policy = try PermissionsPolicy.fromHeader(
        allocator,
        "geolocation=(), camera=(self)",
        "https://example.com",
    );
    defer policy.deinit();

    // Geolocation is disabled (empty allowlist)
    try std.testing.expect(!policy.isFeatureAllowed(.geolocation, "https://example.com"));

    // Camera is allowed for self only
    try std.testing.expect(policy.isFeatureAllowed(.camera, "https://example.com"));
    try std.testing.expect(!policy.isFeatureAllowed(.camera, "https://other.com"));
}

test "PermissionsPolicy - fromHeader with specific origins" {
    const allocator = std.testing.allocator;

    var policy = try PermissionsPolicy.fromHeader(
        allocator,
        "geolocation=(self \"https://trusted.com\")",
        "https://example.com",
    );
    defer policy.deinit();

    try std.testing.expect(policy.isFeatureAllowed(.geolocation, "https://example.com"));
    try std.testing.expect(policy.isFeatureAllowed(.geolocation, "https://trusted.com"));
    try std.testing.expect(!policy.isFeatureAllowed(.geolocation, "https://untrusted.com"));
}

test "PermissionsPolicy - inheritance" {
    const allocator = std.testing.allocator;

    // Parent policy allows geolocation only for self
    var parent = try PermissionsPolicy.fromHeader(
        allocator,
        "geolocation=(self)",
        "https://parent.com",
    );
    defer parent.deinit();

    // Child policy allows geolocation for all
    var child = try PermissionsPolicy.fromHeader(
        allocator,
        "geolocation=(*)",
        "https://child.com",
    );
    defer child.deinit();

    child.setInheritedPolicy(&parent);

    // Child can't grant more than parent allows
    // Parent only allows "self" (parent.com), so child.com is not allowed
    try std.testing.expect(!child.isFeatureAllowed(.geolocation, "https://child.com"));
    try std.testing.expect(child.isFeatureAllowed(.geolocation, "https://parent.com"));
}
