//! What the remote end uses of the host API (CDP part 1 phase P0c, lane
//! cdph: src/browser/BrowserHost.zig and the Browser's tab operations), in
//! one place.
//!
//! TODO(cdph P0c): until the host API lands on this branch, each name here
//! falls back to a stub that fails with `error.HostApiMissing`; the real one
//! is used as soon as `browser` declares it (`@hasDecl`), with the exact
//! signatures lane cdph gave (main, 2026-11-21 6:04 PM ET):
//! - thread-safe `browser.BrowserHost`: start(allocator, config) !*BrowserHost,
//!   stop(self), post(self, ctx, run, drop) bool, call(self, ctx, run)
//!   error{BrowserGone, WrongThread}!void, isBrowserThread(self) bool;
//! - on the Browser thread, `browser.Browser`: TabId = u64,
//!   createTab(self, CreateTabOptions{url, background, hold_first_navigation})
//!   !TabId, closeTab(self, tab, CloseTabOptions{prompt_unload}) !void,
//!   releaseTab(self, tab), activateTab(self, tab) !void, listTabs(self,
//!   allocator) ![]TabInfo, freeTabs(allocator, tabs), tabRealm(self, tab),
//!   addListener/removeListener(self, host_events.Listener);
//! - `browser.host_events`: Listener{context, on_event}, Event = union
//!   {tab_created, tab_destroyed, frame_created, frame_destroyed,
//!   navigation: *const Milestone (lane life1's navigation observer)}.
//! When it lands, this file shrinks to aliases.

const std = @import("std");
const browser = @import("browser");

pub const Browser = browser.Browser;
pub const BrowserConfig = browser.BrowserConfig;

/// Whether the host API is on this branch yet.
pub const have_host_api = @hasDecl(browser, "BrowserHost");
pub const have_host_events = @hasDecl(browser, "host_events");

pub const Error = error{HostApiMissing};

/// A Browser on its own thread with a thread-safe command queue.
pub const BrowserHost = if (have_host_api) browser.BrowserHost else StubHost;

/// A top-level traversable: its top-level BrowsingContext's id.
pub const TabId = u64;

pub const RunFn = *const fn (?*anyopaque, *Browser) void;
pub const DropFn = *const fn (?*anyopaque) void;

/// The stand-in until lane cdph's BrowserHost lands: it starts nothing.
const StubHost = struct {
    pub fn start(allocator: std.mem.Allocator, config: BrowserConfig) (Error || std.mem.Allocator.Error)!*StubHost {
        _ = .{ allocator, config };
        return error.HostApiMissing;
    }
    pub fn stop(self: *StubHost) void {
        _ = self;
    }
    pub fn post(self: *StubHost, ctx: ?*anyopaque, run: RunFn, drop: DropFn) bool {
        _ = .{ self, run };
        drop(ctx);
        return false;
    }
    pub fn isBrowserThread(self: *StubHost) bool {
        _ = self;
        return false;
    }
};

pub const CreateTabOptions = struct {
    url: ?[]const u8 = null,
    background: bool = false,
    /// waitForDebuggerOnStart: the tab's first navigation waits for
    /// `releaseTab` (life1's hold_first_navigation).
    hold_first_navigation: bool = false,
};

/// Browser thread. A host-opened tab in a new browsing context group.
pub fn createTab(b: *Browser, options: CreateTabOptions) !TabId {
    if (comptime @hasDecl(Browser, "createTab")) {
        return b.createTab(.{ .url = options.url, .background = options.background, .hold_first_navigation = options.hold_first_navigation });
    }
    return error.HostApiMissing;
}

/// Browser thread. Close `tab`; with `prompt_unload` false nobody is asked
/// (Target.closeTarget), true runs "prompt to unload" (Page.close).
pub fn closeTab(b: *Browser, tab: TabId, prompt_unload: bool) !void {
    if (comptime @hasDecl(Browser, "closeTab")) return b.closeTab(tab, .{ .prompt_unload = prompt_unload });
    // Today's traversable view (Browser.zig "The host's view of its
    // top-level traversables") closes without a prompt.
    return b.closeTraversable(tab);
}

/// Browser thread. Let a held tab's first navigation start
/// (Runtime.runIfWaitingForDebugger).
pub fn releaseTab(b: *Browser, tab: TabId) void {
    if (comptime @hasDecl(Browser, "releaseTab")) return b.releaseTab(tab);
}

/// Browser thread. Make `tab` the active one (Target.activateTarget).
pub fn activateTab(b: *Browser, tab: TabId) !void {
    if (comptime @hasDecl(Browser, "activateTab")) return b.activateTab(tab);
}

pub const TabInfo = struct {
    id: TabId,
    /// OWNED by the list.
    url: []u8,
    /// OWNED by the list.
    title: []u8,
    /// Whether a page opened it (window.open, a target=_blank link).
    opened_by_page: bool,
    opener: ?TabId,
};

/// Browser thread. Every open tab, in the host's order. Free with `freeTabs`.
pub fn listTabs(b: *Browser, allocator: std.mem.Allocator) ![]TabInfo {
    if (comptime @hasDecl(Browser, "listTabs")) {
        const tabs = try b.listTabs(allocator);
        defer Browser.freeTabs(allocator, tabs);
        const out = try allocator.alloc(TabInfo, tabs.len);
        var made: usize = 0;
        errdefer {
            for (out[0..made]) |t| {
                allocator.free(t.url);
                allocator.free(t.title);
            }
            allocator.free(out);
        }
        for (tabs, 0..) |t, i| {
            const url = try allocator.dupe(u8, t.url);
            errdefer allocator.free(url);
            out[i] = .{
                .id = t.id,
                .url = url,
                .title = try allocator.dupe(u8, t.title),
                .opened_by_page = t.made_by == .page,
                .opener = t.opener,
            };
            made += 1;
        }
        return out;
    }
    // Today's traversable view: ids and URLs, no titles.
    var ids: [64]u64 = undefined;
    const count = @min(b.traversableIds(&ids), ids.len);
    const out = try allocator.alloc(TabInfo, count);
    var made: usize = 0;
    errdefer {
        for (out[0..made]) |t| {
            allocator.free(t.url);
            allocator.free(t.title);
        }
        allocator.free(out);
    }
    for (ids[0..count], 0..) |id, i| {
        const url = try b.traversableUrl(allocator, id);
        errdefer allocator.free(url);
        out[i] = .{ .id = id, .url = url, .title = try allocator.alloc(u8, 0), .opened_by_page = false, .opener = null };
        made += 1;
    }
    return out;
}

pub fn freeTabs(allocator: std.mem.Allocator, tabs: []TabInfo) void {
    for (tabs) |t| {
        allocator.free(t.url);
        allocator.free(t.title);
    }
    allocator.free(tabs);
}

/// The host's events, as the remote end consumes them (Browser thread, in
/// order, no script inside).
pub const HostEvent = if (have_host_events) browser.host_events.Event else StubEvent;
pub const Listener = if (have_host_events) browser.host_events.Listener else StubListener;

/// Lane life1's navigation milestone (src/html/navigation/observer.zig),
/// as the host events carry it.
pub const Milestone = @import("html").navigation.observer.Milestone;
pub const MilestoneEvent = @import("html").navigation.observer.Event;

const StubEvent = union(enum) {
    tab_created: struct { tab: TabId, opener: ?TabId },
    tab_destroyed: struct { tab: TabId },
    navigation: *const Milestone,
};
const StubListener = struct {
    context: *anyopaque,
    on_event: *const fn (*anyopaque, *const StubEvent) void,
};

/// Browser thread. Start delivering host events to `listener`.
pub fn addListener(b: *Browser, listener: Listener) !void {
    if (comptime have_host_events) return b.addListener(listener);
}

pub fn removeListener(b: *Browser, listener: Listener) void {
    if (comptime have_host_events) return b.removeListener(listener);
}
