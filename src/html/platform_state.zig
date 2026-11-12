//! A Browser's platform state (docs/platform-protocol.md section 3): the
//! `*platform.BrowserPlatform` its realms' per-Browser platform operations
//! take, held as a supplement of the Browser's scope and read through a
//! realm's (recipes 0.5).
//!
//! Minimal: Browser.init creates it and Browser.deinit destroys it; its
//! EventSink posts nothing yet. Recipes
//! step 7 grows it - the requester, the event loop's port, platform events
//! turned into tasks.

const std = @import("std");
const runtime = @import("runtime");
const platform = @import("platform");
const dom = @import("dom");

/// The scope's supplement: its Browser's BrowserPlatform, once made.
pub const PlatformState = struct {
    allocator: std.mem.Allocator,
    browser: ?*platform.BrowserPlatform = null,
    /// The Browser's request ids (contract: `RequestId` is "unique per
    /// Browser"): the last one handed out. Atomic - a worker's realm of the
    /// same Browser asks on its own thread.
    last_request_id: std.atomic.Value(platform.RequestId) = .init(0),

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

/// Who asks, for a per-Browser platform request made in `realm` (contract
/// section 4): what `platform.Requester` borrows, owned here. `deinit` frees
/// it once the operation has returned (the platform copies what it keeps).
pub const RequesterParts = struct {
    allocator: std.mem.Allocator,
    request_id: platform.RequestId,
    origin: []const u8,
    top_level_origin: []const u8,
    secure_context: bool,
    transient_activation: bool,

    /// The Requester, BORROWING these parts. Tab and frame are 0: reserved
    /// until recipes step 7 supplies the document-to-TabId mapping (as
    /// environmentValue below passes tab 0).
    pub fn requester(self: *const RequesterParts) platform.Requester {
        return .{
            .request_id = self.request_id,
            .tab = 0,
            .frame = 0,
            .origin = platform.Str.from(self.origin),
            .top_level_origin = platform.Str.from(self.top_level_origin),
            .secure_context = self.secure_context,
            .transient_activation = self.transient_activation,
        };
    }

    pub fn deinit(self: *RequesterParts) void {
        self.allocator.free(self.origin);
        self.allocator.free(self.top_level_origin);
    }
};

/// The requester of a request `realm` makes now: a new request id of its
/// Browser, the serialized origins of its relevant settings object and of
/// its top-level traversable's active document, whether it is a secure
/// context, and `transient_activation` - which the caller decides, since
/// what counts as one is each API's (a user's key press is one; HTML
/// 6.4.1 for script). Null when the realm has no Browser platform state or
/// no settings object.
pub fn requester(realm: runtime.Context, transient_activation: bool) error{OutOfMemory}!?RequesterParts {
    const scope = realm.browserScope() orelse return null;
    const state = scope.existing(PlatformState) orelse return null;
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    const settings = dom.global_settings.of(global) orelse return null;
    // The settings hooks allocate with the global's allocator.
    const allocator = global.ctx.allocator;
    const origin = settings.origin(global) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else null;
    errdefer allocator.free(origin);
    const top_level_origin: []const u8 = blk: {
        const top_of = settings.top_level_origin orelse break :blk try allocator.dupe(u8, origin);
        break :blk (try top_of(global)) orelse try allocator.dupe(u8, origin);
    };
    return .{
        .allocator = allocator,
        .request_id = state.last_request_id.fetchAdd(1, .monotonic) + 1,
        .origin = origin,
        .top_level_origin = top_level_origin,
        .secure_context = settings.is_secure_context(global),
        .transient_activation = transient_activation,
    };
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
