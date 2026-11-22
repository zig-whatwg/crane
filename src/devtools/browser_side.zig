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
const fetch_observer = @import("fetch_observer.zig");
const log_domain = @import("domains/log.zig");
const page_domain = @import("domains/page.zig");
const fetch_interception = @import("fetch_interception.zig");
const fetch = @import("fetch");

const log = std.log.scoped(.devtools);

/// What the devtools thread hears about a Browser's tabs.
pub const TargetEvent = union(enum) {
    tab_created: struct { tab: host_bridge.TabId, opener: ?host_bridge.TabId, opened_by_page: bool },
    tab_destroyed: struct { tab: host_bridge.TabId },
    /// A navigable's URL changed (a commit, or a same-document navigation):
    /// the devtools thread updates the target whose tab it is
    /// (Target.targetInfoChanged). `url` is OWNED by the event (allocated
    /// with the side's allocator).
    navigated: struct { navigable: u64, url: []u8, cross_document: bool = true },
    /// A tab's document title is known or changed (read at its document's
    /// DOMContentLoaded and load, and of a tab already open when the
    /// remote end came: Target.targetInfoChanged as Chrome's TitleWasSet).
    /// `title` is OWNED by the event.
    title_changed: struct { tab: host_bridge.TabId, title: []u8 },
    /// A page session's Runtime.runIfWaitingForDebugger: one of the tab's
    /// waiting sessions is done waiting (the hold is released when all are).
    run_if_waiting: struct { tab: host_bridge.TabId, session_id: [32]u8 },
    /// A simple dialog opened in the tab; the Browser thread waits in it.
    dialog_opening: struct { tab: host_bridge.TabId, answer: host_bridge.DialogAnswer },
    /// The tab's dialog closed (whoever answered it).
    dialog_closed: struct { tab: host_bridge.TabId },
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
    /// Browser thread only: the fetch observer's state (fetch_observer.zig).
    fetch_state: fetch_observer.State = .{},
    /// Browser thread only: each tab's kept Log entries (domains/log.zig).
    log_storage: log_domain.Storage = .{},
    /// Browser thread only: every frame's network idleness detector
    /// (domains/page.zig IdleFrames: Blink's per-frame IdlenessDetector).
    idle: page_domain.IdleFrames = .{},
    /// Any thread (locked): the requests a session holds
    /// (fetch_interception.zig) - the devtools thread answers them.
    interceptions: fetch_interception.Table = .{},

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
        // The Browser's fetch observer: Network events, Fetch interception.
        const network = try browser.scope.of(fetch.network.NetworkContext);
        network.observer = fetch_observer.observerFor(self);
        // The tabs that exist already (the console's first tab, a WebDriver
        // session's): the devtools thread hears of them as of new ones.
        const tabs = try host_bridge.listTabs(browser, self.allocator);
        defer host_bridge.freeTabs(self.allocator, tabs);
        for (tabs) |t| {
            self.sink.post(self.sink.context, self, .{ .tab_created = .{ .tab = t.id, .opener = t.opener, .opened_by_page = t.opened_by_page } });
            // It has committed its document already: its URL and title.
            self.postNavigated(t.id, t.url, true);
            if (t.title.len > 0) self.postTitle(t.id, t.title);
        }
        // And their realms are the inspector's from now on (contexts.onServed).
        @import("contexts.zig").onServed(self);
    }

    /// Browser thread: detach every session and stop listening.
    pub fn uninstall(self: *BrowserSide) void {
        while (self.sessions.items.len > 0) {
            self.sessions.items[self.sessions.items.len - 1].detach();
        }
        if (self.listening) {
            if (self.browser) |b| {
                host_bridge.removeListener(b, self.listener());
                if (b.scope.of(fetch.network.NetworkContext)) |network| {
                    network.observer = null;
                } else |_| {}
            }
            self.listening = false;
        }
        self.fetch_state.deinit(self.allocator);
        self.fetch_state = .{};
        // Every session detached (its holds let go); none is left.
        fetch_interception.release(self, null, .any);
        self.interceptions.deinit(self.allocator);
        self.log_storage.deinit(self.allocator);
        // The detectors' armed checks are cancelled on this, the timers'
        // thread, while the Browser's loop still runs.
        self.idle.deinit(self);
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
            .tab_destroyed => |destroyed| {
                log_domain.tabGone(self, destroyed.tab);
                self.sink.post(self.sink.context, self, .{ .tab_destroyed = .{ .tab = destroyed.tab } });
            },
            .navigation => |milestone| self.fanOutNavigation(milestone),
            // Lane cdph's dialog events (named, so this compiles before they
            // exist): the devtools thread keeps the open dialog's answer.
            inline else => |payload, tag| {
                if (comptime std.mem.eql(u8, @tagName(tag), "dialog_opening")) {
                    self.sink.post(self.sink.context, self, .{ .dialog_opening = .{ .tab = payload.tab, .answer = payload.answer } });
                } else if (comptime std.mem.eql(u8, @tagName(tag), "dialog_closed")) {
                    self.sink.post(self.sink.context, self, .{ .dialog_closed = .{ .tab = payload.tab } });
                }
            },
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
        fetch_observer.onMilestone(self, milestone);
        log_domain.onMilestone(self, milestone);
        page_domain.onBrowserMilestone(self, milestone);
        switch (milestone.event) {
            .committed => |c| self.postNavigated(milestone.navigable_id, c.url, true),
            .same_document => |c| self.postNavigated(milestone.navigable_id, c.url, false),
            // A top-level document's title, once its parser has had the
            // <title> (Chrome reports each title the page sets: WebContents
            // TitleWasSet -> targetInfoChanged).
            .dom_content_loaded => |d| self.postTitleOf(milestone.navigable_id, d.document),
            .load => |d| self.postTitleOf(milestone.navigable_id, d.document),
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

    fn postNavigated(self: *BrowserSide, navigable: u64, url: []const u8, cross_document: bool) void {
        const owned = self.allocator.dupe(u8, url) catch return;
        self.sink.post(self.sink.context, self, .{ .navigated = .{ .navigable = navigable, .url = owned, .cross_document = cross_document } });
    }

    fn postTitle(self: *BrowserSide, tab: host_bridge.TabId, title: []const u8) void {
        const owned = self.allocator.dupe(u8, title) catch return;
        self.sink.post(self.sink.context, self, .{ .title_changed = .{ .tab = tab, .title = owned } });
    }

    /// The title of `ref`, a tab's active document (a frame's is no
    /// target's), for the devtools thread, which reports it when it moved.
    fn postTitleOf(self: *BrowserSide, navigable: u64, ref: host_bridge.MilestoneDocument) void {
        const b = self.browser orelse return;
        const navigables = @import("dom").browser_state.existingNavigablesIn(b.scope) orelse return;
        const bc = navigables.byId(navigable) orelse return;
        if (bc.parent != null) return;
        const document: *@import("runtime").Instance = @ptrCast(@alignCast(ref.document));
        if (@import("runtime").SlabAllocator.generationOf(document) != ref.generation) return;
        if (bc.getActiveDocument() != ref.document) return;
        var title = @import("interfaces").Document.get_title(document) catch return;
        defer title.deinit(document.ctx.allocator);
        self.postTitle(navigable, title.asSlice());
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

/// Install `side` on its Browser and wait until it has: the remote end's
/// start (Server.start), from a thread that is not the Browser's. `install`
/// posts a tab_created for every tab that exists already, so those reach
/// the devtools thread's inbox before any connection is accepted - a
/// client's first Target.setAutoAttach finds the console's first tab as an
/// existing target, attached not waiting and before its reply, as Chrome's
/// browser process knows its tabs when the client connects (lane cdpr's
/// Playwright replay: posted and not waited for, the tab could arrive after
/// setAutoAttach and be attached as a new, held target). A session message
/// (host_bridge.postSessionMessage), so a Browser already sitting in a
/// simple dialog's or a pause's nested loop runs it.
pub fn installAndWait(side: *BrowserSide) void {
    const Wait = struct {
        side: *BrowserSide,
        /// 1 once the install ran, or the Browser went without it.
        done: std.atomic.Value(u32) = .init(0),

        fn run(context: ?*anyopaque, browser: *host_bridge.Browser) void {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            self.side.install(browser) catch |err| log.warn("devtools: listening to the Browser's events failed: {t}", .{err});
            self.signal();
        }

        fn drop(context: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            self.signal();
        }

        fn signal(self: *@This()) void {
            self.done.store(1, .release);
            futexIo().futexWake(u32, &self.done.raw, 1);
        }
    };
    var wait: Wait = .{ .side = side };
    // False: the Browser has gone, and `drop` ran already.
    if (!host_bridge.postSessionMessage(side.host, &wait, Wait.run, Wait.drop)) {
        log.warn("devtools: the Browser did not take the remote end's listener: it has gone", .{});
        return;
    }
    while (wait.done.load(.acquire) == 0) {
        futexIo().futexWaitTimeout(u32, &wait.done.raw, 0, .{ .duration = .{ .raw = .fromMilliseconds(20), .clock = .awake } }) catch {};
    }
}

/// Attach an allocated session.
///
/// A session's attach (AttachTask), its messages (MessageTask) and its
/// detach (DetachTask) all go as session messages (host_bridge.
/// postSessionMessage), so they run in the order they were posted - and
/// inside a debugger pause, whose nested loop runs session messages and no
/// other task. Posted as ordinary tasks, an attach or a detach waited out the
/// pause while the session's messages and the server's uninstall ran inside
/// it: a message found its session not attached yet and went unanswered, and
/// a detach ran after the uninstall had freed its session (CDP part 1 gap 6).
/// Blink orders them the same way: "devtools relies on a disconnect handler
/// for detaching and is sensitive to reordering of detach and attach", so a
/// session's attach goes to the task runner its messages use, through the
/// InspectorTaskRunner that interrupts a paused or busy V8
/// (third_party/blink/renderer/core/inspector/devtools_agent.cc,
/// IOAgent::AttachDevToolsSession, DevToolsAgent::AttachDevToolsSessionImpl).
pub const AttachTask = struct {
    session: *PageSession,
    side: *BrowserSide,

    pub fn post(side: *BrowserSide, session: *PageSession) !void {
        const task = try side.allocator.create(AttachTask);
        task.* = .{ .session = session, .side = side };
        if (!host_bridge.postSessionMessage(side.host, task, run, drop)) return error.BrowserGone;
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
        // Into the Browser thread's nested loop while it is paused (the
        // debugger, a dialog), else in order with every other command.
        if (!host_bridge.postSessionMessage(side.host, task, run, drop)) return error.BrowserGone;
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

/// Detach and free a session: a session message, after the session's own
/// (AttachTask says why).
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
        _ = host_bridge.postSessionMessage(side.host, task, run, drop);
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
/// Browser stops, or the server does) - without ever blocking on the page
/// (CDP part 1 gap 6):
/// - it goes as a page session's message does (host_bridge.
///   postSessionMessage): in order with the sessions' messages, and inside
///   the nested loop of a debugger pause, where detaching the sessions ends
///   the V8 inspector session, which resumes the paused agent (V8's
///   V8DebuggerAgentImpl::disable continues a paused program; Blink runs a
///   session's detach as an interrupting task of the paused loop the same
///   way);
/// - while it waits, a simple dialog the Browser thread sits in is
///   dismissed - Chrome's PageHandler::Disable answers a pending dialog
///   false when no dialog manager takes it (headless; content/browser/
///   devtools/protocol/page_handler.cc) - and a request a blocking fetch
///   waits on a holder for is let go (the interceptor's Detach:
///   fetch_interception.release), each again if another opens before the
///   uninstall runs.
pub fn uninstallAndWait(side: *BrowserSide) void {
    const Wait = struct {
        side: *BrowserSide,
        /// 1 once the uninstall ran, or the Browser went without it.
        done: std.atomic.Value(u32) = .init(0),

        fn run(context: ?*anyopaque, browser: *host_bridge.Browser) void {
            _ = browser;
            const self: *@This() = @ptrCast(@alignCast(context.?));
            self.side.uninstall();
            self.signal();
        }

        fn drop(context: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            self.signal();
        }

        fn signal(self: *@This()) void {
            self.done.store(1, .release);
            futexIo().futexWake(u32, &self.done.raw, 1);
        }
    };
    var wait: Wait = .{ .side = side };
    // False: the Browser has gone, and `drop` ran already.
    if (!host_bridge.postSessionMessage(side.host, &wait, Wait.run, Wait.drop)) return;
    while (wait.done.load(.acquire) == 0) {
        host_bridge.dismissUserPrompt(side.host, side.allocator);
        fetch_interception.release(side, null, .blocking);
        futexIo().futexWaitTimeout(u32, &wait.done.raw, 0, .{ .duration = .{ .raw = .fromMilliseconds(20), .clock = .awake } }) catch {};
    }
}

fn futexIo() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}
