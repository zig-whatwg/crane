//! Worker Navigator
//!
//! Spec: HTML Standard § 10.1.3 The WorkerNavigator interface
//! https://html.spec.whatwg.org/#workernavigator
//!
//! The WorkerNavigator interface provides navigator-like information
//! within worker contexts, with a subset of the Window's Navigator API.

const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");

/// Navigator ID (NavigatorID mixin).
///
/// Spec: HTML Standard § 8.8.1.1 NavigatorID
/// https://html.spec.whatwg.org/#navigatorid
pub const NavigatorId = struct {
    /// Application code name (always "Mozilla" for compatibility).
    app_code_name: []const u8 = "Mozilla",

    /// Application name (always "Netscape" for compatibility).
    app_name: []const u8 = "Netscape",

    /// Application version.
    app_version: []const u8 = "5.0",

    /// Platform identifier.
    platform: []const u8,

    /// Product name (always "Gecko" for compatibility).
    product: []const u8 = "Gecko",

    /// Product sub (empty for non-Gecko).
    product_sub: []const u8 = "",

    /// User agent string.
    user_agent: []const u8,

    /// Vendor name.
    vendor: []const u8 = "",

    /// Vendor sub (always empty).
    vendor_sub: []const u8 = "",
};

/// Navigator Language (NavigatorLanguage mixin).
///
/// Spec: HTML Standard § 8.8.1.2 NavigatorLanguage
/// https://html.spec.whatwg.org/#navigatorlanguage
pub const NavigatorLanguage = struct {
    /// Preferred language (BCP 47 tag).
    language: []const u8 = "en-US",

    /// All preferred languages.
    languages: []const []const u8 = &[_][]const u8{"en-US"},
};

/// Navigator Online (NavigatorOnLine mixin).
///
/// Spec: HTML Standard § 8.8.1.3 NavigatorOnLine
/// https://html.spec.whatwg.org/#navigatoronline
pub const NavigatorOnLine = struct {
    /// Whether the browser is online.
    on_line: bool = true,
};

/// Navigator Concurrent Hardware (NavigatorConcurrentHardware mixin).
///
/// Spec: HTML Standard § 8.8.1.4 NavigatorConcurrentHardware
/// https://html.spec.whatwg.org/#navigatorconcurrenthardware
pub const NavigatorConcurrentHardware = struct {
    /// Number of logical processors.
    hardware_concurrency: usize,

    pub fn init() NavigatorConcurrentHardware {
        return .{
            .hardware_concurrency = getHardwareConcurrency(),
        };
    }
};

/// Worker Navigator implementation.
///
/// Spec: HTML Standard § 10.1.3
/// "The WorkerNavigator object must not outlive its WorkerGlobalScope."
///
/// WorkerNavigator includes:
/// - NavigatorID (appCodeName, appName, appVersion, platform, product, userAgent, etc.)
/// - NavigatorLanguage (language, languages)
/// - NavigatorOnLine (onLine)
/// - NavigatorConcurrentHardware (hardwareConcurrency)
pub const WorkerNavigator = struct {
    /// NavigatorID mixin data.
    id: NavigatorId,

    /// NavigatorLanguage mixin data.
    language: NavigatorLanguage,

    /// NavigatorOnLine mixin data.
    online: NavigatorOnLine,

    /// NavigatorConcurrentHardware mixin data.
    concurrent_hardware: NavigatorConcurrentHardware,

    /// Allocator
    allocator: Allocator,

    /// User agent string (owned).
    user_agent_owned: []const u8,

    /// Platform string (owned).
    platform_owned: []const u8,

    /// Create a WorkerNavigator.
    pub fn init(allocator: Allocator) !*WorkerNavigator {
        const navigator = try allocator.create(WorkerNavigator);
        errdefer allocator.destroy(navigator);

        // Build platform string
        const platform_str = try getPlatformString(allocator);
        errdefer allocator.free(platform_str);

        // Build user agent string
        const user_agent_str = try getUserAgentString(allocator);
        errdefer allocator.free(user_agent_str);

        navigator.* = .{
            .id = .{
                .platform = platform_str,
                .user_agent = user_agent_str,
            },
            .language = .{},
            .online = .{},
            .concurrent_hardware = NavigatorConcurrentHardware.init(),
            .allocator = allocator,
            .user_agent_owned = user_agent_str,
            .platform_owned = platform_str,
        };

        return navigator;
    }

    /// Clean up resources.
    pub fn deinit(self: *WorkerNavigator) void {
        self.allocator.free(self.user_agent_owned);
        self.allocator.free(self.platform_owned);
        self.allocator.destroy(self);
    }

    // ============================================
    // NavigatorID (§8.8.1.1)
    // ============================================

    /// Get the application code name.
    ///
    /// Spec: "Must return the string "Mozilla"."
    pub fn getAppCodeName(self: *const WorkerNavigator) []const u8 {
        return self.id.app_code_name;
    }

    /// Get the application name.
    ///
    /// Spec: "Must return the string "Netscape"."
    pub fn getAppName(self: *const WorkerNavigator) []const u8 {
        return self.id.app_name;
    }

    /// Get the application version.
    ///
    /// Spec: "Must return the appropriate string..."
    pub fn getAppVersion(self: *const WorkerNavigator) []const u8 {
        return self.id.app_version;
    }

    /// Get the platform.
    ///
    /// Spec: "Must return a string representing the platform on which
    /// the browser is executing."
    pub fn getPlatform(self: *const WorkerNavigator) []const u8 {
        return self.id.platform;
    }

    /// Get the product.
    ///
    /// Spec: "Must return the string "Gecko"."
    pub fn getProduct(self: *const WorkerNavigator) []const u8 {
        return self.id.product;
    }

    /// Get the product sub.
    pub fn getProductSub(self: *const WorkerNavigator) []const u8 {
        return self.id.product_sub;
    }

    /// Get the user agent string.
    ///
    /// Spec: "Must return the default `User-Agent` value."
    pub fn getUserAgent(self: *const WorkerNavigator) []const u8 {
        return self.id.user_agent;
    }

    /// Get the vendor.
    pub fn getVendor(self: *const WorkerNavigator) []const u8 {
        return self.id.vendor;
    }

    /// Get the vendor sub.
    pub fn getVendorSub(self: *const WorkerNavigator) []const u8 {
        return self.id.vendor_sub;
    }

    // ============================================
    // NavigatorLanguage (§8.8.1.2)
    // ============================================

    /// Get the preferred language.
    ///
    /// Spec: "Must return a valid BCP 47 language tag representing
    /// the user's preferred language."
    pub fn getLanguage(self: *const WorkerNavigator) []const u8 {
        return self.language.language;
    }

    /// Get all preferred languages.
    ///
    /// Spec: "Must return a frozen array of valid BCP 47 language tags."
    pub fn getLanguages(self: *const WorkerNavigator) []const []const u8 {
        return self.language.languages;
    }

    // ============================================
    // NavigatorOnLine (§8.8.1.3)
    // ============================================

    /// Check if online.
    ///
    /// Spec: "Must return false if the user agent is definitely offline
    /// (disconnected from the network). Must return true if the user
    /// agent might be online."
    pub fn isOnLine(self: *const WorkerNavigator) bool {
        return self.online.on_line;
    }

    /// Set online status.
    pub fn setOnLine(self: *WorkerNavigator, online: bool) void {
        self.online.on_line = online;
    }

    // ============================================
    // NavigatorConcurrentHardware (§8.8.1.4)
    // ============================================

    /// Get hardware concurrency.
    ///
    /// Spec: "Must return a number greater than or equal to 1,
    /// representing the approximate number of logical processors
    /// available to run JavaScript."
    pub fn getHardwareConcurrency(self: *const WorkerNavigator) usize {
        return self.concurrent_hardware.hardware_concurrency;
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

/// Get the hardware concurrency (number of logical processors).
fn getHardwareConcurrency() usize {
    // Try to get actual CPU count
    // Default to 1 if unable to determine
    return std.Thread.getCpuCount() catch 1;
}

test "WorkerNavigator - init and deinit" {
    const allocator = std.testing.allocator;

    const navigator = try WorkerNavigator.init(allocator);
    defer navigator.deinit();

    // Check NavigatorID
    try std.testing.expectEqualStrings("Mozilla", navigator.getAppCodeName());
    try std.testing.expectEqualStrings("Netscape", navigator.getAppName());
    try std.testing.expectEqualStrings("Gecko", navigator.getProduct());

    // Check NavigatorLanguage
    try std.testing.expectEqualStrings("en-US", navigator.getLanguage());

    // Check NavigatorOnLine
    try std.testing.expect(navigator.isOnLine());

    // Check NavigatorConcurrentHardware
    try std.testing.expect(navigator.getHardwareConcurrency() >= 1);
}

test "WorkerNavigator - platform" {
    const allocator = std.testing.allocator;

    const navigator = try WorkerNavigator.init(allocator);
    defer navigator.deinit();

    const platform = navigator.getPlatform();
    try std.testing.expect(platform.len > 0);
}

test "WorkerNavigator - user agent" {
    const allocator = std.testing.allocator;

    const navigator = try WorkerNavigator.init(allocator);
    defer navigator.deinit();

    const user_agent = navigator.getUserAgent();
    try std.testing.expect(std.mem.indexOf(u8, user_agent, "Mozilla") != null);
}

test "WorkerNavigator - online status" {
    const allocator = std.testing.allocator;

    const navigator = try WorkerNavigator.init(allocator);
    defer navigator.deinit();

    try std.testing.expect(navigator.isOnLine());

    navigator.setOnLine(false);
    try std.testing.expect(!navigator.isOnLine());

    navigator.setOnLine(true);
    try std.testing.expect(navigator.isOnLine());
}

test "WorkerNavigator - hardware concurrency" {
    const allocator = std.testing.allocator;

    const navigator = try WorkerNavigator.init(allocator);
    defer navigator.deinit();

    // Should be at least 1
    const concurrency = navigator.getHardwareConcurrency();
    try std.testing.expect(concurrency >= 1);
}
