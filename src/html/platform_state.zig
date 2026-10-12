//! A Browser's platform state (docs/platform-protocol.md section 3): the
//! `*platform.BrowserPlatform` its realms' per-Browser platform operations
//! take, held as a supplement of the Browser's scope and read through a
//! realm's (recipes 0.5).
//!
//! Minimal, for decision 19b's layout stopgap: Browser.init creates it and
//! Browser.deinit destroys it; its EventSink posts nothing yet. Recipes
//! step 7 grows it - the requester, the event loop's port, platform events
//! turned into tasks.

const std = @import("std");
const runtime = @import("runtime");
const platform = @import("platform");

/// The scope's supplement: its Browser's BrowserPlatform, once made.
pub const PlatformState = struct {
    allocator: std.mem.Allocator,
    browser: ?*platform.BrowserPlatform = null,

    pub fn init(allocator: std.mem.Allocator) PlatformState {
        return .{ .allocator = allocator };
    }

    /// With the scope, if Browser.deinit has not ended it first.
    pub fn deinit(self: *PlatformState) void {
        if (self.browser) |browser| platform.destroyBrowserPlatform(browser);
        self.browser = null;
    }
};

/// Platform events: none are turned into steps yet (recipes step 7).
fn ignoreEvent(context: ?*anyopaque, event: *const platform.PlatformEvent) callconv(.c) void {
    _ = .{ context, event };
}

const no_events: platform.EventSink = .{ .context = null, .post = ignoreEvent };

/// Make `scope`'s Browser's platform state - the platform's defaults for
/// every option (contract 3.1). Browser.init's.
pub fn create(scope: *runtime.BrowserScope) !void {
    const state = try scope.of(PlatformState);
    if (state.browser != null) return;
    state.browser = try platform.createBrowserPlatform(state.allocator, &.{}, no_events);
}

/// End `scope`'s Browser's platform state. Browser.deinit's.
pub fn destroy(scope: *runtime.BrowserScope) void {
    const state = scope.existing(PlatformState) orelse return;
    state.deinit();
}

/// The BrowserPlatform of `realm`'s Browser, if it has one (a realm of the
/// standalone runtime, or a test's, may not).
pub fn of(realm: runtime.Context) ?*platform.BrowserPlatform {
    const scope = realm.browserScope() orelse return null;
    const state = scope.existing(PlatformState) orelse return null;
    return state.browser;
}
