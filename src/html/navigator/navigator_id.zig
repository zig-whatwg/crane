//! NavigatorID Mixin
//!
//! HTML Standard § 8.8.1.1 - NavigatorID
//! https://html.spec.whatwg.org/#navigatorid
//!
//! This mixin provides legacy browser identification properties.
//! Many values are fixed for web compatibility reasons.

const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");

/// NavigatorID mixin implementation
/// Spec: HTML Standard § 8.8.1.1
pub const NavigatorId = struct {
    allocator: Allocator,

    /// User agent string (owned)
    user_agent_owned: []const u8,

    /// Platform string (owned)
    platform_owned: []const u8,

    const Self = @This();

    /// Initialize NavigatorID with platform-detected values
    pub fn init(allocator: Allocator) !Self {
        const platform_str = try getPlatformString(allocator);
        errdefer allocator.free(platform_str);

        const user_agent_str = try getUserAgentString(allocator);
        errdefer allocator.free(user_agent_str);

        return .{
            .allocator = allocator,
            .user_agent_owned = user_agent_str,
            .platform_owned = platform_str,
        };
    }

    /// Initialize with custom user agent and platform
    pub fn initWithUserAgent(
        allocator: Allocator,
        user_agent: []const u8,
        platform: []const u8,
    ) !Self {
        const platform_str = try allocator.dupe(u8, platform);
        errdefer allocator.free(platform_str);

        const user_agent_str = try allocator.dupe(u8, user_agent);

        return .{
            .allocator = allocator,
            .user_agent_owned = user_agent_str,
            .platform_owned = platform_str,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.user_agent_owned);
        self.allocator.free(self.platform_owned);
    }

    // ========================================================================
    // NavigatorID Properties
    // ========================================================================

    /// Get the application code name.
    /// Spec: "Must return the string 'Mozilla'."
    pub fn getAppCodeName(_: *const Self) []const u8 {
        return "Mozilla";
    }

    /// Get the application name.
    /// Spec: "Must return the string 'Netscape'."
    pub fn getAppName(_: *const Self) []const u8 {
        return "Netscape";
    }

    /// Get the application version.
    /// Spec: "Must return the appropriate string..."
    pub fn getAppVersion(_: *const Self) []const u8 {
        return "5.0";
    }

    /// Get the platform.
    /// Spec: "Must return a string representing the platform on which
    /// the browser is executing."
    pub fn getPlatform(self: *const Self) []const u8 {
        return self.platform_owned;
    }

    /// Get the product.
    /// Spec: "Must return the string 'Gecko'."
    pub fn getProduct(_: *const Self) []const u8 {
        return "Gecko";
    }

    /// Get the product sub.
    /// Only exposed in Window context.
    pub fn getProductSub(_: *const Self) []const u8 {
        return "20030107";
    }

    /// Get the user agent string.
    /// Spec: "Must return the default `User-Agent` value."
    pub fn getUserAgent(self: *const Self) []const u8 {
        return self.user_agent_owned;
    }

    /// Get the vendor.
    /// Only exposed in Window context.
    pub fn getVendor(_: *const Self) []const u8 {
        return "";
    }

    /// Get the vendor sub.
    /// Only exposed in Window context. Always empty.
    pub fn getVendorSub(_: *const Self) []const u8 {
        return "";
    }

    /// Get the OS/CPU string.
    /// Only exposed in Window context. Part of partial interface mixin.
    pub fn getOscpu(_: *const Self) []const u8 {
        return switch (builtin.os.tag) {
            .macos => "Intel Mac OS X",
            .windows => "Windows NT",
            .linux => "Linux x86_64",
            else => "Unknown",
        };
    }

    /// taintEnabled() - legacy method, always returns false.
    /// Only exposed in Window context.
    pub fn taintEnabled(_: *const Self) bool {
        return false;
    }
};

/// Get the platform string based on the OS.
fn getPlatformString(allocator: Allocator) ![]const u8 {
    const platform_str = switch (builtin.os.tag) {
        .macos => "MacIntel",
        .windows => "Win32",
        .linux => "Linux x86_64",
        .freebsd => "FreeBSD",
        .ios => "iPhone",
        else => "Unknown",
    };
    return try allocator.dupe(u8, platform_str);
}

/// Get the user agent string.
fn getUserAgentString(allocator: Allocator) ![]const u8 {
    // A reasonable default user agent string
    // In production, this would be configurable
    const user_agent = "Mozilla/5.0 (compatible; WHATWG-Zig/1.0)";
    return try allocator.dupe(u8, user_agent);
}

// ============================================================================
// Tests
// ============================================================================

test "NavigatorId - init and deinit" {
    const allocator = std.testing.allocator;

    var id = try NavigatorId.init(allocator);
    defer id.deinit();

    // Fixed values per spec
    try std.testing.expectEqualStrings("Mozilla", id.getAppCodeName());
    try std.testing.expectEqualStrings("Netscape", id.getAppName());
    try std.testing.expectEqualStrings("5.0", id.getAppVersion());
    try std.testing.expectEqualStrings("Gecko", id.getProduct());
    try std.testing.expectEqualStrings("20030107", id.getProductSub());
    try std.testing.expectEqualStrings("", id.getVendor());
    try std.testing.expectEqualStrings("", id.getVendorSub());
    try std.testing.expect(!id.taintEnabled());
}

test "NavigatorId - platform detection" {
    const allocator = std.testing.allocator;

    var id = try NavigatorId.init(allocator);
    defer id.deinit();

    const platform = id.getPlatform();
    try std.testing.expect(platform.len > 0);
}

test "NavigatorId - user agent" {
    const allocator = std.testing.allocator;

    var id = try NavigatorId.init(allocator);
    defer id.deinit();

    const user_agent = id.getUserAgent();
    try std.testing.expect(std.mem.indexOf(u8, user_agent, "Mozilla") != null);
}

test "NavigatorId - custom user agent" {
    const allocator = std.testing.allocator;

    var id = try NavigatorId.initWithUserAgent(
        allocator,
        "Custom/1.0",
        "CustomPlatform",
    );
    defer id.deinit();

    try std.testing.expectEqualStrings("Custom/1.0", id.getUserAgent());
    try std.testing.expectEqualStrings("CustomPlatform", id.getPlatform());
}
