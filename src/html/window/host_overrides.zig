//! A host's overrides of what the platform answers for one top-level
//! traversable - its tab: the media its documents' media queries see, the
//! touch points and the user agent its navigator reports. What an automation
//! client emulates: CDP's Emulation domain (Chrome's EmulationHandler and
//! Blink's InspectorEmulationAgent keep them per page,
//! content/browser/devtools/protocol/emulation_handler.cc,
//! third_party/blink/renderer/core/inspector/inspector_emulation_agent.cc),
//! and WebDriver BiDi's emulation module the same way. Generic: compiled in
//! with or without CDP (lane cdph, P4; the integrator's ruling 7:27 PM ET
//! 2026-11-21).
//!
//! Each group records which setter set it (an opaque token: a CDP session),
//! so a setter that goes clears only what it set - Chrome clears a detaching
//! session's own overrides and leaves another session's. The last setter of
//! a group wins. Strings are copied and owned here: freed when replaced,
//! cleared, or when the browsing context ends. On the Browser's window
//! thread.

const std = @import("std");
const Allocator = std.mem.Allocator;
const platform_mod = @import("platform");

pub const MediaType = enum { screen, print };
pub const ColorScheme = enum { light, dark };
pub const ReducedMotion = enum { no_preference, reduce };
pub const Contrast = enum { no_preference, more, less, custom };

/// The media a document's media queries are evaluated against (Media
/// Queries 5): each null field answers as the platform does.
pub const Media = struct {
    media_type: ?MediaType = null,
    color_scheme: ?ColorScheme = null,
    reduced_motion: ?ReducedMotion = null,
    contrast: ?Contrast = null,
    forced_colors: ?bool = null,
};

/// The screen an emulated device reports (CDP's
/// Emulation.setDeviceMetricsOverride; Blink's ScreenMetricsEmulator):
/// screen.width/height - availWidth/availHeight with them, as the emulator
/// sets the available rect to the screen rect - devicePixelRatio and the
/// current orientation type and angle. Null fields answer as the platform
/// does.
pub const Screen = struct {
    width: ?i32 = null,
    height: ?i32 = null,
    device_pixel_ratio: ?f64 = null,
    orientation: ?Orientation = null,

    pub const Orientation = struct {
        type: platform_mod.OrientationType,
        angle: u16,
    };
};

/// An opaque token naming who set an override; 0 is nobody.
pub const Owner = usize;

pub const HostOverrides = struct {
    media: ?Media = null,
    media_owner: Owner = 0,
    /// navigator.maxTouchPoints (Pointer Events 3).
    max_touch_points: ?i32 = null,
    touch_owner: Owner = 0,
    /// The emulated device's screen (html.screen_info reads it).
    screen: ?Screen = null,
    screen_owner: Owner = 0,
    /// navigator.userAgent, navigator.platform and the navigator's languages
    /// (from an Accept-Language list). OWNED.
    user_agent: ?[]u8 = null,
    platform: ?[]u8 = null,
    accept_language: ?[]u8 = null,
    user_agent_owner: Owner = 0,

    /// Free what is owned (the browsing context's end).
    pub fn deinit(self: *HostOverrides, allocator: Allocator) void {
        self.freeUserAgent(allocator);
        self.* = .{};
    }

    pub fn setMedia(self: *HostOverrides, owner: Owner, media: ?Media) void {
        self.media = media;
        self.media_owner = if (media != null) owner else 0;
    }

    pub fn setMaxTouchPoints(self: *HostOverrides, owner: Owner, points: ?i32) void {
        self.max_touch_points = points;
        self.touch_owner = if (points != null) owner else 0;
    }

    pub fn setScreen(self: *HostOverrides, owner: Owner, screen: ?Screen) void {
        self.screen = screen;
        self.screen_owner = if (screen != null) owner else 0;
    }

    /// Replace the user agent override with copies of `user_agent`,
    /// `platform` and `accept_language`. Each null or empty one is not
    /// overridden - an empty user agent with an Accept-Language overrides
    /// the languages alone (Chrome's EmulationHandler::ApplyOverrides and
    /// Blink's InspectorEmulationAgent apply each field only when it is
    /// non-empty; Playwright sends `userAgent: ""` with every locale). All
    /// three empty clears it.
    pub fn setUserAgent(self: *HostOverrides, allocator: Allocator, owner: Owner, user_agent: ?[]const u8, platform: ?[]const u8, accept_language: ?[]const u8) Allocator.Error!void {
        const ua_copy: ?[]u8 = if (user_agent) |u| (if (u.len > 0) try allocator.dupe(u8, u) else null) else null;
        errdefer if (ua_copy) |u| allocator.free(u);
        const platform_copy: ?[]u8 = if (platform) |p| (if (p.len > 0) try allocator.dupe(u8, p) else null) else null;
        errdefer if (platform_copy) |p| allocator.free(p);
        const language_copy: ?[]u8 = if (accept_language) |l| (if (l.len > 0) try allocator.dupe(u8, l) else null) else null;
        self.freeUserAgent(allocator);
        if (ua_copy == null and platform_copy == null and language_copy == null) return;
        self.user_agent = ua_copy;
        self.platform = platform_copy;
        self.accept_language = language_copy;
        self.user_agent_owner = owner;
    }

    /// Clear every override `owner` set (a setter that goes: Chrome's
    /// detaching session); another setter's stay.
    pub fn clearOwnedBy(self: *HostOverrides, allocator: Allocator, owner: Owner) void {
        if (owner == 0) return;
        if (self.media_owner == owner) self.setMedia(0, null);
        if (self.touch_owner == owner) self.setMaxTouchPoints(0, null);
        if (self.screen_owner == owner) self.setScreen(0, null);
        if (self.user_agent_owner == owner) self.freeUserAgent(allocator);
    }

    fn freeUserAgent(self: *HostOverrides, allocator: Allocator) void {
        if (self.user_agent) |s| allocator.free(s);
        if (self.platform) |s| allocator.free(s);
        if (self.accept_language) |s| allocator.free(s);
        self.user_agent = null;
        self.platform = null;
        self.accept_language = null;
        self.user_agent_owner = 0;
    }

    /// The first language of the Accept-Language override ("de-DE,de;q=0.9"
    /// -> "de-DE"), or null.
    pub fn language(self: *const HostOverrides) ?[]const u8 {
        const list = self.accept_language orelse return null;
        var parts = std.mem.splitScalar(u8, list, ',');
        const first = std.mem.trim(u8, parts.first(), " ");
        const tag = if (std.mem.indexOfScalar(u8, first, ';')) |i| first[0..i] else first;
        return if (tag.len > 0) tag else null;
    }
};

/// A copy of a tab's user agent override, taken when a dedicated worker is
/// made, which the worker's navigator and requests use for its life: Chrome
/// copies its owner's user agent - the override applied
/// (FrameLoader::UserAgent through probe::ApplyUserAgentOverride) - into the
/// worker's creation params (DedicatedWorker::CreateGlobalScopeCreationParams
/// `user_agent`, third_party/blink/renderer/core/workers/
/// dedicated_worker.cc), and WorkerFetchContext::PrepareRequest sends that
/// copy. An override set later reaches only workers made later. Thread-safe
/// by construction: copied on the owner's thread before the worker's thread
/// starts, read only on the worker's. OWNED; null fields: none.
pub const UserAgentSnapshot = struct {
    user_agent: ?[]u8 = null,
    platform: ?[]u8 = null,
    accept_language: ?[]u8 = null,

    /// The override as `overrides` holds it now.
    pub fn of(allocator: Allocator, overrides: *const HostOverrides) Allocator.Error!UserAgentSnapshot {
        return copyOf(allocator, overrides.user_agent, overrides.platform, overrides.accept_language);
    }

    /// Another snapshot's copy (a nested dedicated worker takes its owner
    /// worker's).
    pub fn clone(self: *const UserAgentSnapshot, allocator: Allocator) Allocator.Error!UserAgentSnapshot {
        return copyOf(allocator, self.user_agent, self.platform, self.accept_language);
    }

    fn copyOf(allocator: Allocator, user_agent: ?[]const u8, platform: ?[]const u8, accept_language: ?[]const u8) Allocator.Error!UserAgentSnapshot {
        var copy: UserAgentSnapshot = .{};
        errdefer copy.deinit(allocator);
        if (user_agent) |text| copy.user_agent = try allocator.dupe(u8, text);
        if (platform) |text| copy.platform = try allocator.dupe(u8, text);
        if (accept_language) |text| copy.accept_language = try allocator.dupe(u8, text);
        return copy;
    }

    pub fn deinit(self: *UserAgentSnapshot, allocator: Allocator) void {
        if (self.user_agent) |text| allocator.free(text);
        if (self.platform) |text| allocator.free(text);
        if (self.accept_language) |text| allocator.free(text);
        self.* = .{};
    }
};

test "a worker's user agent snapshot is a copy: the tab's override changing later leaves it" {
    const allocator = std.testing.allocator;
    var overrides: HostOverrides = .{};
    defer overrides.deinit(allocator);
    try overrides.setUserAgent(allocator, 1, "UA-one", "", "fr-FR");
    var snapshot = try UserAgentSnapshot.of(allocator, &overrides);
    defer snapshot.deinit(allocator);
    var nested = try snapshot.clone(allocator);
    defer nested.deinit(allocator);
    try overrides.setUserAgent(allocator, 1, "UA-two", null, null);
    try std.testing.expectEqualStrings("UA-one", snapshot.user_agent.?);
    try std.testing.expectEqualStrings("fr-FR", nested.accept_language.?);
    try std.testing.expect(nested.platform == null);
    var none = try UserAgentSnapshot.of(allocator, &HostOverrides{});
    defer none.deinit(allocator);
    try std.testing.expect(none.user_agent == null);
}

test "an empty user agent overrides the languages alone (Playwright's locale call)" {
    const allocator = std.testing.allocator;
    var overrides: HostOverrides = .{};
    defer overrides.deinit(allocator);
    try overrides.setUserAgent(allocator, 1, "", null, "fr-FR,fr");
    try std.testing.expect(overrides.user_agent == null);
    try std.testing.expectEqualStrings("fr-FR", overrides.language().?);
    try std.testing.expectEqual(@as(Owner, 1), overrides.user_agent_owner);
    try overrides.setUserAgent(allocator, 1, "", "", "");
    try std.testing.expect(overrides.accept_language == null);
    try std.testing.expectEqual(@as(Owner, 0), overrides.user_agent_owner);
}

test "a setter that goes clears only what it set; strings are owned" {
    const allocator = std.testing.allocator;
    var overrides: HostOverrides = .{};
    defer overrides.deinit(allocator);
    try overrides.setUserAgent(allocator, 1, "UA-one", "Plat", "de-DE,de;q=0.9");
    overrides.setMedia(2, .{ .color_scheme = .dark });
    overrides.setMaxTouchPoints(1, 5);
    overrides.setScreen(1, .{ .width = 390, .height = 844, .device_pixel_ratio = 3 });
    try std.testing.expectEqualStrings("de-DE", overrides.language().?);
    overrides.clearOwnedBy(allocator, 1);
    try std.testing.expect(overrides.user_agent == null);
    try std.testing.expect(overrides.max_touch_points == null);
    try std.testing.expect(overrides.screen == null);
    try std.testing.expectEqual(ColorScheme.dark, overrides.media.?.color_scheme.?);
    // The last setter wins: setter 3 replaces 2's media; 2 going leaves 3's.
    overrides.setMedia(3, .{ .media_type = .print });
    overrides.clearOwnedBy(allocator, 2);
    try std.testing.expectEqual(MediaType.print, overrides.media.?.media_type.?);
}
