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
/// every option (contract 3.1).
pub fn create(scope: *runtime.BrowserScope) !void {
    _ = try createWith(scope, &.{});
}

/// Make `scope`'s Browser's platform state with `options` (BrowserConfig's
/// platform options among them), and answer it: Browser.init's, before the
/// Browser's agent and event loop, which take its clock and its seed. A
/// scope that has one already keeps it.
pub fn createWith(scope: *runtime.BrowserScope, options: *const platform.BrowserOptions) !*platform.BrowserPlatform {
    const state = try scope.of(PlatformState);
    if (state.browser) |browser| return browser;
    const browser = try platform.createBrowserPlatform(state.allocator, options, no_events);
    state.browser = browser;
    return browser;
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

/// The clock `realm`'s HR-Time reads measure time with: its Browser's
/// (platform.browserClock) for a window realm, whose event loop - the
/// Browser's - runs on it. The platform's own clocks for every other realm,
/// a worker's among them: a worker's event loop runs on the process's clock
/// (the virtual clock's first batch, docs/platform-protocol.md section 9),
/// so its performance.now() must too. And for a realm with no Browser
/// platform state. A lookup in the scope: callers keep the answer, which is
/// fixed for the realm's life.
pub fn clockOf(realm: runtime.Context) platform.BrowserClock {
    if (!realm.isWindow()) return .real;
    return browserClockOf(realm);
}

/// The clock of `realm`'s Browser, whatever kind of realm it is: for a
/// Window being made, whose realm does not record its kind yet (the
/// context's realm info is synced when its realm record is set, after the
/// global exists) - the Window knows what it is. The platform's own clocks
/// without Browser platform state.
pub fn browserClockOf(realm: runtime.Context) platform.BrowserClock {
    const browser = of(realm) orelse return .real;
    return platform.browserClock(browser);
}

/// The platform owner installs the style provider once, at process start.
pub fn installHooks() void {
    @import("dom").style.environment_variables.install(.{
        .value = &environmentValue,
        .revision = &environmentRevision,
    });
}

fn environmentValue(document: *runtime.Instance, variable: @import("dom").style.environment_variables.Variable, x: u32, y: u32) ?f64 {
    const browser = of(document.ctx) orelse return null;
    comptime {
        const Variable = @import("dom").style.environment_variables.Variable;
        if (@typeInfo(Variable).@"enum".field_names.len != @typeInfo(platform.CssEnvironmentVariable).@"enum".field_names.len)
            @compileError("CSS and platform environment variable sets must match");
    }
    // Exhaustively resolve tags by name at compile time, never by ordinal.
    const platform_variable = switch (variable) {
        inline else => |tag| @field(platform.CssEnvironmentVariable, @tagName(tag)),
    };
    // Platform protocol §6.9: values are currently per Browser. Tab 0 is
    // reserved until recipes step 7 supplies document-to-TabId mapping.
    return platform.cssEnvironmentVariable(browser, 0, platform_variable, x, y);
}

fn environmentRevision(document: *runtime.Instance) u64 {
    const browser = of(document.ctx) orelse return 0;
    return platform.cssEnvironmentRevision(browser, 0);
}
