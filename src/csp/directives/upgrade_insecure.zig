//! CSP upgrade-insecure-requests Directive
//!
//! W3C Content Security Policy Level 3
//! Spec: https://www.w3.org/TR/upgrade-insecure-requests/
//!
//! The upgrade-insecure-requests directive instructs user agents to
//! upgrade HTTP to HTTPS and WS to WSS before fetching resources.

const std = @import("std");
const types = @import("../types.zig");

// ============================================================================
// Upgrade Detection
// ============================================================================

/// Check if upgrade-insecure-requests is active in any policy.
/// Spec: Upgrade Insecure Requests § 3.1
pub fn shouldUpgradeInsecureRequests(csp_list: *const types.CSPList) bool {
    for (csp_list.policies.items) |policy| {
        if (policy.containsDirective("upgrade-insecure-requests")) {
            return true;
        }
    }
    return false;
}

/// Check if a single policy has upgrade-insecure-requests.
pub fn hasUpgradeInsecureRequests(policy: *const types.Policy) bool {
    return policy.containsDirective("upgrade-insecure-requests");
}

// ============================================================================
// URL Upgrade
// ============================================================================

/// Scheme upgrades: http → https, ws → wss
pub const SchemeUpgrade = struct {
    from: []const u8,
    to: []const u8,
};

pub const scheme_upgrades = [_]SchemeUpgrade{
    .{ .from = "http", .to = "https" },
    .{ .from = "ws", .to = "wss" },
};

/// Check if a scheme can be upgraded.
pub fn canUpgradeScheme(scheme: []const u8) bool {
    for (scheme_upgrades) |upgrade| {
        if (std.ascii.eqlIgnoreCase(scheme, upgrade.from)) {
            return true;
        }
    }
    return false;
}

/// Get the upgraded scheme, or null if no upgrade available.
pub fn getUpgradedScheme(scheme: []const u8) ?[]const u8 {
    for (scheme_upgrades) |upgrade| {
        if (std.ascii.eqlIgnoreCase(scheme, upgrade.from)) {
            return upgrade.to;
        }
    }
    return null;
}

/// Default port changes when upgrading schemes
pub const PortUpgrade = struct {
    from_port: u16,
    to_port: u16,
};

pub const port_upgrades = [_]PortUpgrade{
    .{ .from_port = 80, .to_port = 443 }, // HTTP default → HTTPS default
};

/// Get the upgraded port, or the original if no change needed.
pub fn getUpgradedPort(port: ?u16, from_scheme: []const u8, to_scheme: []const u8) ?u16 {
    // If no port specified, use default ports
    if (port == null) {
        return null; // Let the new scheme use its default
    }

    const p = port.?;

    // Check if this is a default port that should be upgraded
    if (std.ascii.eqlIgnoreCase(from_scheme, "http") and
        std.ascii.eqlIgnoreCase(to_scheme, "https"))
    {
        if (p == 80) {
            return 443;
        }
    }

    if (std.ascii.eqlIgnoreCase(from_scheme, "ws") and
        std.ascii.eqlIgnoreCase(to_scheme, "wss"))
    {
        if (p == 80) {
            return 443;
        }
    }

    // Non-standard port - keep it
    return p;
}

/// Result of URL upgrade operation
pub const UpgradeResult = struct {
    /// New scheme (or original if not upgraded)
    scheme: []const u8,
    /// New port (or original if not upgraded)
    port: ?u16,
    /// Whether an upgrade occurred
    upgraded: bool,
};

/// Upgrade a URL's scheme and port if applicable.
/// Spec: Upgrade Insecure Requests § 4.1
///
/// This only computes the new values - actual URL mutation is caller's responsibility.
pub fn upgradeUrlComponents(scheme: []const u8, port: ?u16) UpgradeResult {
    if (getUpgradedScheme(scheme)) |new_scheme| {
        return .{
            .scheme = new_scheme,
            .port = getUpgradedPort(port, scheme, new_scheme),
            .upgraded = true,
        };
    }

    return .{
        .scheme = scheme,
        .port = port,
        .upgraded = false,
    };
}

// ============================================================================
// Request Context
// ============================================================================

/// Request destinations that should be upgraded
/// Spec: Upgrade Insecure Requests § 4.1
pub fn shouldUpgradeRequestDestination(destination: []const u8) bool {
    // All subresource requests should be upgraded
    // This includes: script, style, image, font, media, object, frame, etc.
    const upgradeable = [_][]const u8{
        "script",
        "style",
        "image",
        "font",
        "media",
        "object",
        "frame",
        "iframe",
        "worker",
        "sharedworker",
        "serviceworker",
        "manifest",
        "xslt",
        "fetch",
        "xmlhttprequest",
        "websocket",
        "eventsource",
        "track",
        "embed",
        "audio",
        "video",
    };

    for (upgradeable) |dest| {
        if (std.ascii.eqlIgnoreCase(destination, dest)) {
            return true;
        }
    }

    // Navigation requests are also upgraded
    if (std.ascii.eqlIgnoreCase(destination, "document") or
        std.ascii.eqlIgnoreCase(destination, "navigate"))
    {
        return true;
    }

    return false;
}

// ============================================================================
// Tests
// ============================================================================

test "shouldUpgradeInsecureRequests" {
    const allocator = std.testing.allocator;

    // Empty list - no upgrade
    {
        var csp_list = types.CSPList.init(allocator);
        defer csp_list.deinit();
        try std.testing.expect(!shouldUpgradeInsecureRequests(&csp_list));
    }

    // Policy with upgrade-insecure-requests
    {
        var csp_list = types.CSPList.init(allocator);
        defer csp_list.deinit();

        var policy = types.Policy.init(allocator, .enforce, .header);

        const directive = try types.Directive.create(allocator, "upgrade-insecure-requests");
        try policy.directive_set.append(directive);

        try csp_list.append(policy);

        try std.testing.expect(shouldUpgradeInsecureRequests(&csp_list));
    }
}

test "canUpgradeScheme" {
    try std.testing.expect(canUpgradeScheme("http"));
    try std.testing.expect(canUpgradeScheme("HTTP"));
    try std.testing.expect(canUpgradeScheme("ws"));
    try std.testing.expect(canUpgradeScheme("WS"));

    try std.testing.expect(!canUpgradeScheme("https"));
    try std.testing.expect(!canUpgradeScheme("wss"));
    try std.testing.expect(!canUpgradeScheme("ftp"));
}

test "getUpgradedScheme" {
    try std.testing.expectEqualStrings("https", getUpgradedScheme("http").?);
    try std.testing.expectEqualStrings("https", getUpgradedScheme("HTTP").?);
    try std.testing.expectEqualStrings("wss", getUpgradedScheme("ws").?);

    try std.testing.expect(getUpgradedScheme("https") == null);
    try std.testing.expect(getUpgradedScheme("ftp") == null);
}

test "upgradeUrlComponents" {
    // HTTP → HTTPS
    {
        const result = upgradeUrlComponents("http", 80);
        try std.testing.expectEqualStrings("https", result.scheme);
        try std.testing.expectEqual(@as(?u16, 443), result.port);
        try std.testing.expect(result.upgraded);
    }

    // HTTP with non-standard port
    {
        const result = upgradeUrlComponents("http", 8080);
        try std.testing.expectEqualStrings("https", result.scheme);
        try std.testing.expectEqual(@as(?u16, 8080), result.port);
        try std.testing.expect(result.upgraded);
    }

    // WS → WSS
    {
        const result = upgradeUrlComponents("ws", null);
        try std.testing.expectEqualStrings("wss", result.scheme);
        try std.testing.expect(result.upgraded);
    }

    // Already secure - no upgrade
    {
        const result = upgradeUrlComponents("https", 443);
        try std.testing.expectEqualStrings("https", result.scheme);
        try std.testing.expectEqual(@as(?u16, 443), result.port);
        try std.testing.expect(!result.upgraded);
    }
}

test "shouldUpgradeRequestDestination" {
    try std.testing.expect(shouldUpgradeRequestDestination("script"));
    try std.testing.expect(shouldUpgradeRequestDestination("image"));
    try std.testing.expect(shouldUpgradeRequestDestination("fetch"));
    try std.testing.expect(shouldUpgradeRequestDestination("document"));

    try std.testing.expect(!shouldUpgradeRequestDestination("unknown"));
}
