//! Mock WorkerNavigator for Service Workers
//!
//! TODO(html-spec): Replace this mock with real HTML WorkerNavigator
//! when the HTML specification workers section is implemented.
//! See: https://html.spec.whatwg.org/multipage/workers.html#workernavigator
//!
//! WorkerNavigator provides browser/environment information in worker contexts.
//! This mock implements the basic navigator properties.
//!
//! WebIDL:
//! ```idl
//! [Exposed=Worker]
//! interface WorkerNavigator {};
//! WorkerNavigator includes NavigatorID;
//! WorkerNavigator includes NavigatorLanguage;
//! WorkerNavigator includes NavigatorOnLine;
//! WorkerNavigator includes NavigatorConcurrentHardware;
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Mock WorkerNavigator interface.
///
/// Provides browser/environment information for workers.
/// Includes mixins: NavigatorID, NavigatorLanguage, NavigatorOnLine, NavigatorConcurrentHardware.
pub const WorkerNavigator = struct {
    allocator: Allocator,

    // === NavigatorID mixin ===

    /// Always "Mozilla" per spec.
    app_code_name: []const u8 = "Mozilla",

    /// Always "Netscape" per spec.
    app_name: []const u8 = "Netscape",

    /// Browser version string.
    app_version: []const u8,

    /// Platform identifier.
    platform: []const u8,

    /// Always "Gecko" per spec.
    product: []const u8 = "Gecko",

    /// User agent string.
    user_agent: []const u8,

    // === NavigatorLanguage mixin ===

    /// Primary language.
    language: []const u8,

    /// All accepted languages.
    languages: []const []const u8,

    // === NavigatorOnLine mixin ===

    /// Whether the browser is online.
    on_line: bool = true,

    // === NavigatorConcurrentHardware mixin ===

    /// Number of logical processors.
    hardware_concurrency: u64 = 1,

    // === ServiceWorker specific ===

    /// Reference to ServiceWorkerContainer (set by ServiceWorkerGlobalScope).
    /// TODO(service-worker-spec): This will be the real ServiceWorkerContainer.
    service_worker: ?*anyopaque = null,

    const Self = @This();

    /// Create a WorkerNavigator with default values.
    pub fn init(allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const app_version = try allocator.dupe(u8, "5.0");
        errdefer allocator.free(app_version);

        const platform = try allocator.dupe(u8, "Zig");
        errdefer allocator.free(platform);

        const user_agent = try allocator.dupe(u8, "Mozilla/5.0 (compatible; ZigWHATWG/1.0)");
        errdefer allocator.free(user_agent);

        const language = try allocator.dupe(u8, "en-US");
        errdefer allocator.free(language);

        // Create languages array
        const languages = try allocator.alloc([]const u8, 1);
        errdefer allocator.free(languages);
        languages[0] = try allocator.dupe(u8, "en-US");

        self.* = .{
            .allocator = allocator,
            .app_version = app_version,
            .platform = platform,
            .user_agent = user_agent,
            .language = language,
            .languages = languages,
        };

        return self;
    }

    /// Create with custom configuration.
    pub fn initWithConfig(allocator: Allocator, config: Config) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const app_version = try allocator.dupe(u8, config.app_version);
        errdefer allocator.free(app_version);

        const platform = try allocator.dupe(u8, config.platform);
        errdefer allocator.free(platform);

        const user_agent = try allocator.dupe(u8, config.user_agent);
        errdefer allocator.free(user_agent);

        const language = try allocator.dupe(u8, config.language);
        errdefer allocator.free(language);

        // Copy languages array
        const languages = try allocator.alloc([]const u8, config.languages.len);
        errdefer allocator.free(languages);

        var copied: usize = 0;
        errdefer {
            for (languages[0..copied]) |lang| {
                allocator.free(lang);
            }
        }

        for (config.languages, 0..) |lang, i| {
            languages[i] = try allocator.dupe(u8, lang);
            copied += 1;
        }

        self.* = .{
            .allocator = allocator,
            .app_version = app_version,
            .platform = platform,
            .user_agent = user_agent,
            .language = language,
            .languages = languages,
            .on_line = config.on_line,
            .hardware_concurrency = config.hardware_concurrency,
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.app_version);
        self.allocator.free(self.platform);
        self.allocator.free(self.user_agent);
        self.allocator.free(self.language);
        for (self.languages) |lang| {
            self.allocator.free(lang);
        }
        self.allocator.free(self.languages);
        self.allocator.destroy(self);
    }

    // === Getters (matching WebIDL attributes) ===

    /// NavigatorID.appCodeName - always "Mozilla".
    pub fn getAppCodeName(self: *const Self) []const u8 {
        return self.app_code_name;
    }

    /// NavigatorID.appName - always "Netscape".
    pub fn getAppName(self: *const Self) []const u8 {
        return self.app_name;
    }

    /// NavigatorID.appVersion.
    pub fn getAppVersion(self: *const Self) []const u8 {
        return self.app_version;
    }

    /// NavigatorID.platform.
    pub fn getPlatform(self: *const Self) []const u8 {
        return self.platform;
    }

    /// NavigatorID.product - always "Gecko".
    pub fn getProduct(self: *const Self) []const u8 {
        return self.product;
    }

    /// NavigatorID.userAgent.
    pub fn getUserAgent(self: *const Self) []const u8 {
        return self.user_agent;
    }

    /// NavigatorLanguage.language.
    pub fn getLanguage(self: *const Self) []const u8 {
        return self.language;
    }

    /// NavigatorLanguage.languages.
    pub fn getLanguages(self: *const Self) []const []const u8 {
        return self.languages;
    }

    /// NavigatorOnLine.onLine.
    pub fn getOnLine(self: *const Self) bool {
        return self.on_line;
    }

    /// NavigatorConcurrentHardware.hardwareConcurrency.
    pub fn getHardwareConcurrency(self: *const Self) u64 {
        return self.hardware_concurrency;
    }

    // === Setters for testing ===

    /// Set online status (for testing offline scenarios).
    pub fn setOnLine(self: *Self, on_line: bool) void {
        self.on_line = on_line;
    }

    /// Configuration for creating WorkerNavigator.
    pub const Config = struct {
        app_version: []const u8 = "5.0",
        platform: []const u8 = "Zig",
        user_agent: []const u8 = "Mozilla/5.0 (compatible; ZigWHATWG/1.0)",
        language: []const u8 = "en-US",
        languages: []const []const u8 = &[_][]const u8{"en-US"},
        on_line: bool = true,
        hardware_concurrency: u64 = 1,
    };
};

// =============================================================================
// Tests
// =============================================================================

test "WorkerNavigator.init creates navigator with defaults" {
    const allocator = std.testing.allocator;

    const nav = try WorkerNavigator.init(allocator);
    defer nav.deinit();

    try std.testing.expectEqualStrings("Mozilla", nav.getAppCodeName());
    try std.testing.expectEqualStrings("Netscape", nav.getAppName());
    try std.testing.expectEqualStrings("5.0", nav.getAppVersion());
    try std.testing.expectEqualStrings("Zig", nav.getPlatform());
    try std.testing.expectEqualStrings("Gecko", nav.getProduct());
    try std.testing.expectEqualStrings("en-US", nav.getLanguage());
    try std.testing.expect(nav.getOnLine());
    try std.testing.expectEqual(@as(u64, 1), nav.getHardwareConcurrency());
}

test "WorkerNavigator.initWithConfig" {
    const allocator = std.testing.allocator;

    const languages = [_][]const u8{ "en-US", "en", "fr" };
    const nav = try WorkerNavigator.initWithConfig(allocator, .{
        .platform = "Linux",
        .language = "fr-FR",
        .languages = &languages,
        .on_line = false,
        .hardware_concurrency = 8,
    });
    defer nav.deinit();

    try std.testing.expectEqualStrings("Linux", nav.getPlatform());
    try std.testing.expectEqualStrings("fr-FR", nav.getLanguage());
    try std.testing.expectEqual(@as(usize, 3), nav.getLanguages().len);
    try std.testing.expect(!nav.getOnLine());
    try std.testing.expectEqual(@as(u64, 8), nav.getHardwareConcurrency());
}

test "WorkerNavigator.setOnLine" {
    const allocator = std.testing.allocator;

    const nav = try WorkerNavigator.init(allocator);
    defer nav.deinit();

    try std.testing.expect(nav.getOnLine());

    nav.setOnLine(false);
    try std.testing.expect(!nav.getOnLine());

    nav.setOnLine(true);
    try std.testing.expect(nav.getOnLine());
}

test "WorkerNavigator user agent string" {
    const allocator = std.testing.allocator;

    const nav = try WorkerNavigator.init(allocator);
    defer nav.deinit();

    const ua = nav.getUserAgent();
    try std.testing.expect(std.mem.indexOf(u8, ua, "Mozilla") != null);
}
