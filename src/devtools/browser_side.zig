//! The remote end's record of one Browser (one browser context), on that
//! Browser's thread.
//!
//! It holds the Browser's attached page sessions, listens to the host's
//! events (tabs made and closed, frames, lane life1's navigation milestones)
//! and passes them on: milestones to every page session's handlers
//! (`onNavigation`), tab events to the devtools thread, whose target registry
//! turns them into Target.targetCreated / targetDestroyed / targetInfoChanged
//! and auto-attaches (Chrome: TargetHandler observes its
//! DevToolsAgentHosts the same way, content/browser/devtools/protocol/
//! target_handler.cc).
//!
//! Made by the devtools thread when it adopts a Browser; `install` and
//! `uninstall` run on the Browser thread (a posted task, then a blocking
//! call before the Browser stops), so no session outlives it.

const std = @import("std");
const Allocator = std.mem.Allocator;
const host_bridge = @import("host_bridge.zig");
const page_domains = @import("domains/page_domains.zig");
const PageSession = @import("page_session.zig").PageSession;

const log = std.log.scoped(.devtools);

/// What the devtools thread hears about a Browser's tabs.
pub const TargetEvent = union(enum) {
    tab_created: struct { tab: host_bridge.TabId, opener: ?host_bridge.TabId, opened_by_page: bool },
    tab_destroyed: struct { tab: host_bridge.TabId },
    /// A navigable's URL changed (a commit, or a same-document navigation):
    /// the devtools thread updates the target whose tab it is
    /// (Target.targetInfoChanged). `url` is OWNED by the event (allocated
    /// with the side's allocator).
    navigated: struct { navigable: u64, url: []u8 },
    /// A page session's Runtime.runIfWaitingForDebugger: one of the tab's
    /// waiting sessions is done waiting (the hold is released when all are).
    run_if_waiting: struct { tab: host_bridge.TabId, session_id: [32]u8 },
};

/// The devtools thread's door: `post` may be called from any thread and
/// takes ownership of the event's slices.
pub const TargetSink = struct {
    context: *anyopaque,
    post: *const fn (context: *anyopaque, side: *BrowserSide, event: TargetEvent) void,
};

pub const BrowserSide = struct {
    /// Thread-safe.
    allocator: Allocator,
    host: *host_bridge.BrowserHost,
    /// This Browser's half of every frame id (ids.zig).
    token: u64,
    /// The browser context id CDP names this Browser by.
    context_id: [32]u8,
    sink: TargetSink,
    /// Browser thread only: the attached page sessions.
    sessions: std.ArrayList(*PageSession) = .empty,
    browser: ?*host_bridge.Browser = null,
    listening: bool = false,
    /// Whether the client asked for new tabs to wait for the debugger
    /// (Target.setAutoAttach {waitForDebuggerOnStart}); the devtools thread
    /// writes it, the Browser thread reads it when a page opens a tab.
    wait_for_debugger: std.atomic.Value(bool) = .init(false),

    pub fn create(allocator: Allocator, host: *host_bridge.BrowserHost, token: u64, context_id: [32]u8, sink: TargetSink) Allocator.Error!*BrowserSide {
        const self = try allocator.create(BrowserSide);
        self.* = .{ .allocator = allocator, .host = host, .token = token, .context_id = context_id, .sink = sink };
        return self;
    }

    /// Free the record; `uninstall` has run (or `install` never did).
    pub fn destroy(self: *BrowserSide) void {
        std.debug.assert(self.sessions.items.len == 0);
        self.sessions.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Browser thread: start listening to `browser`'s host events.
    pub fn install(self: *BrowserSide, browser: *host_bridge.Browser) !void {
        self.browser = browser;
        try host_bridge.addListener(browser, self.listener());
        self.listening = true;
        // The tabs that exist already (the console's first tab, a WebDriver
        // session's): the devtools thread hears of them as of new ones.
        const tabs = try host_bridge.listTabs(browser, self.allocator);
        defer host_bridge.freeTabs(self.allocator, tabs);
        for (tabs) |t| self.sink.post(self.sink.context, self, .{ .tab_created = .{ .tab = t.id, .opener = t.opener, .opened_by_page = t.opened_by_page } });
    }

    /// Browser thread: detach every session and stop listening.
    pub fn uninstall(self: *BrowserSide) void {
        while (self.sessions.items.len > 0) {
            self.sessions.items[self.sessions.items.len - 1].detach();
        }
        if (self.listening) {
            if (self.browser) |b| host_bridge.removeListener(b, self.listener());
            self.listening = false;
        }
    }

    fn listener(self: *BrowserSide) host_bridge.Listener {
        return .{ .context = self, .on_event = onHostEvent };
    }

    fn onHostEvent(context: *anyopaque, event: *const host_bridge.HostEvent) void {
        const self: *BrowserSide = @ptrCast(@alignCast(context));
        switch (event.*) {
            .tab_created => |created| self.sink.post(self.sink.context, self, .{ .tab_created = .{
                .tab = created.tab,
                .opener = created.opener,
                .opened_by_page = openedByPage(created),
            } }),
            .tab_destroyed => |destroyed| self.sink.post(self.sink.context, self, .{ .tab_destroyed = .{ .tab = destroyed.tab } }),
            .navigation => |milestone| self.fanOutNavigation(milestone),
            else => {},
        }
    }

    fn openedByPage(created: anytype) bool {
        if (@hasField(@TypeOf(created), "made_by")) return created.made_by == .page;
        return created.opener != null;
    }

    /// Every attached page session's handlers hear the milestone, in order.
    /// A handler compares the milestone's navigable with its session's tab.
    /// A commit or a same-document navigation also tells the devtools thread
    /// the navigable's new URL (Target.targetInfoChanged).
    fn fanOutNavigation(self: *BrowserSide, milestone: *const host_bridge.Milestone) void {
        switch (milestone.event) {
            .committed => |c| self.postNavigated(milestone.navigable_id, c.url),
            .same_document => |c| self.postNavigated(milestone.navigable_id, c.url),
            else => {},
        }
        // A handler may detach its session (a tab's close); walk a copy.
        var copy: [64]*PageSession = undefined;
        const count = @min(self.sessions.items.len, copy.len);
        @memcpy(copy[0..count], self.sessions.items[0..count]);
        for (copy[0..count]) |session| {
            if (!self.stillAttached(session)) continue;
            inline for (@typeInfo(page_domains.Handlers).@"struct".decl_names) |name| {
                const H = @field(page_domains.Handlers, name);
                if (comptime @hasDecl(H, "onNavigation")) H.onNavigation(session, milestone);
            }
        }
    }

    fn postNavigated(self: *BrowserSide, navigable: u64, url: []const u8) void {
        const owned = self.allocator.dupe(u8, url) catch return;
        self.sink.post(self.sink.context, self, .{ .navigated = .{ .navigable = navigable, .url = owned } });
    }

    fn stillAttached(self: *BrowserSide, session: *PageSession) bool {
        for (self.sessions.items) |s| if (s == session) return true;
        return false;
    }

    /// The attached sessions on `tab`, into `out`; returns how many.
    pub fn sessionsOn(self: *BrowserSide, tab: host_bridge.TabId, out: []*PageSession) usize {
        var n: usize = 0;
        for (self.sessions.items) |s| {
            if (s.tab != tab) continue;
            if (n < out.len) out[n] = s;
            n += 1;
        }
        return @min(n, out.len);
    }
};

// ============================================================================
// Tasks the devtools thread posts to the Browser (host_bridge.BrowserHost.post)
// ============================================================================

/// Install `side` on its Browser.
pub const InstallTask = struct {
    side: *BrowserSide,

    pub fn post(side: *BrowserSide) !void {
        const task = try side.allocator.create(InstallTask);
        task.* = .{ .side = side };
        if (!side.host.post(task, run, drop)) return error.BrowserGone;
    }

    fn run(context: ?*anyopaque, browser: *host_bridge.Browser) void {
        const task: *InstallTask = @ptrCast(@alignCast(context.?));
        defer task.side.allocator.destroy(task);
        task.side.install(browser) catch |err| log.warn("devtools: listening to the Browser's events failed: {t}", .{err});
    }

    fn drop(context: ?*anyopaque) void {
        const task: *InstallTask = @ptrCast(@alignCast(context.?));
        task.side.allocator.destroy(task);
    }
};

/// Attach an allocated session.
pub const AttachTask = struct {
    session: *PageSession,
    side: *BrowserSide,

    pub fn post(side: *BrowserSide, session: *PageSession) !void {
        const task = try side.allocator.create(AttachTask);
        task.* = .{ .session = session, .side = side };
        if (!side.host.post(task, run, drop)) return error.BrowserGone;
    }

    fn run(context: ?*anyopaque, browser: *host_bridge.Browser) void {
        const task: *AttachTask = @ptrCast(@alignCast(context.?));
        defer task.side.allocator.destroy(task);
        task.session.attach(task.side, browser) catch {
            log.warn("devtools: out of memory attaching a session", .{});
        };
    }

    fn drop(context: ?*anyopaque) void {
        // The Browser went before the attach ran: the detach that follows
        // (posted later) frees the session through its own drop.
        const task: *AttachTask = @ptrCast(@alignCast(context.?));
        task.side.allocator.destroy(task);
    }
};

/// One client message for a session; `raw` is OWNED by the task.
pub const MessageTask = struct {
    session: *PageSession,
    raw: []u8,
    allocator: Allocator,

    pub fn post(side: *BrowserSide, session: *PageSession, raw: []const u8) !void {
        const task = try side.allocator.create(MessageTask);
        errdefer side.allocator.destroy(task);
        task.* = .{ .session = session, .raw = try side.allocator.dupe(u8, raw), .allocator = side.allocator };
        if (!side.host.post(task, run, drop)) return error.BrowserGone;
    }

    fn run(context: ?*anyopaque, browser: *host_bridge.Browser) void {
        _ = browser;
        const task: *MessageTask = @ptrCast(@alignCast(context.?));
        defer drop(context);
        if (task.session.attached) task.session.handleMessage(task.raw);
    }

    fn drop(context: ?*anyopaque) void {
        const task: *MessageTask = @ptrCast(@alignCast(context.?));
        task.allocator.free(task.raw);
        task.allocator.destroy(task);
    }
};

/// Detach and free a session.
pub const DetachTask = struct {
    session: *PageSession,
    allocator: Allocator,

    pub fn post(side: *BrowserSide, session: *PageSession) void {
        const task = side.allocator.create(DetachTask) catch {
            // No memory for the task: the session stays attached until its
            // Browser's uninstall detaches it.
            return;
        };
        task.* = .{ .session = session, .allocator = side.allocator };
        _ = side.host.post(task, run, drop);
    }

    fn run(context: ?*anyopaque, browser: *host_bridge.Browser) void {
        _ = browser;
        const task: *DetachTask = @ptrCast(@alignCast(context.?));
        defer task.allocator.destroy(task);
        task.session.detach();
    }

    fn drop(context: ?*anyopaque) void {
        const task: *DetachTask = @ptrCast(@alignCast(context.?));
        defer task.allocator.destroy(task);
        // The Browser is gone. Its uninstall detached the session if it had
        // attached; otherwise free it here.
        if (!task.session.attached) task.session.discard();
    }
};

/// Tell the Browser whether tabs its pages open start held
/// (host_bridge.holdTabsOpenedByPages).
pub const HoldPopupsTask = struct {
    side: *BrowserSide,
    hold: bool,

    pub fn post(side: *BrowserSide, hold: bool) void {
        side.wait_for_debugger.store(hold, .release);
        const task = side.allocator.create(HoldPopupsTask) catch return;
        task.* = .{ .side = side, .hold = hold };
        _ = side.host.post(task, run, drop);
    }

    fn run(context: ?*anyopaque, browser: *host_bridge.Browser) void {
        const task: *HoldPopupsTask = @ptrCast(@alignCast(context.?));
        defer task.side.allocator.destroy(task);
        host_bridge.holdTabsOpenedByPages(browser, task.hold);
    }

    fn drop(context: ?*anyopaque) void {
        const task: *HoldPopupsTask = @ptrCast(@alignCast(context.?));
        task.side.allocator.destroy(task);
    }
};

/// Run `uninstall` on the Browser thread and wait for it (before the
/// Browser stops).
pub fn uninstallAndWait(side: *BrowserSide) void {
    if (comptime @hasDecl(host_bridge.BrowserHost, "call")) {
        side.host.call(side, struct {
            fn run(context: ?*anyopaque, browser: *host_bridge.Browser) void {
                _ = browser;
                const s: *BrowserSide = @ptrCast(@alignCast(context.?));
                s.uninstall();
            }
        }.run) catch |err| log.warn("devtools: uninstalling from the Browser failed: {t}", .{err});
    }
}
