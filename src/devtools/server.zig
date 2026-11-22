//! The remote end's server: the devtools thread, its listener and pipe, its
//! connections, and the routing of every message (tmp/plans/cdp-part1-design.md
//! 2.1-2.3).
//!
//! Chromium's DevToolsHttpHandler (content/browser/devtools/
//! devtools_http_handler.cc, BSD-3) runs the HTTP server and its WebSocket
//! connections on a thread of its own and hands each message to the UI
//! thread, where DevToolsSession routes it; DevToolsPipeHandler
//! (devtools_pipe_handler.cc) reads and writes the pipe on two threads of
//! its own. Crane's shape is the same:
//! - the ACCEPTOR thread waits for TCP connections (devtoolsAccept with a
//!   timeout, so it sees the server stopping);
//! - each connection has a READER thread (HTTP request head, then WebSocket
//!   frames - or the pipe's NUL-delimited messages) and a WRITER thread (its
//!   outbound FIFO, framed for its transport). Both are pumps: they decide
//!   nothing;
//! - the DEVTOOLS thread owns everything else - the HTTP endpoints and their
//!   checks, the target registry, every session, the browser target's
//!   domains (browser_target.zig) - and posts a page session's messages to
//!   its Browser's thread (browser_side.zig).
//! The devtools thread never touches a DOM or an engine.

const std = @import("std");
const Allocator = std.mem.Allocator;
const platform = @import("platform");
const runtime = @import("runtime");
const ids = @import("ids.zig");
const http = @import("http.zig");
const ws = @import("websocket_server.zig");
const json_rpc = @import("json_rpc.zig");
const dispatch = @import("dispatch.zig");
const outbound = @import("outbound.zig");
const targets = @import("targets.zig");
const host_bridge = @import("host_bridge.zig");
const browser_side = @import("browser_side.zig");
const browser_target = @import("browser_target.zig");
const protocol = @import("protocol/root.zig");
const PageSession = @import("page_session.zig").PageSession;
const fetch_interception = @import("fetch_interception.zig");
const BrowserSide = browser_side.BrowserSide;

/// The Fetch commands the devtools thread answers (dispatch.zig's handler
/// set: domains/fetch.zig DevtoolsThread).
pub const FetchDevtoolsHandlers = struct {
    pub const Fetch = @import("domains/fetch.zig").DevtoolsThread;
};

const log = std.log.scoped(.devtools);

fn futexIo() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}

/// What the embedder starts a server with. Slices are BORROWED for the
/// server's life.
pub const Options = struct {
    /// --remote-debugging-port: 0 for any free port; null for none.
    port: ?u16 = null,
    /// --remote-debugging-pipe: the inherited descriptors (Chrome's 3 and 4).
    pipe: ?Pipe = null,
    /// --remote-allow-origins: origins whose WebSocket upgrades are served
    /// ("*" for any).
    allowed_origins: []const []const u8 = &.{},
    /// --user-data-dir: where DevToolsActivePort is written (null: nowhere).
    user_data_dir: ?[]const u8 = null,
    /// Browser.getVersion's product (decision D4: "Crane/0.1").
    product: []const u8 = "Crane/0.1",
    /// Browser.getVersion's and /json/version's user agent: Crane's own.
    user_agent: []const u8 = "",
    /// Browser.getVersion's jsVersion and /json/version's V8-Version; empty:
    /// the engine's own (engine.engineVersion - V8's v8::V8::GetVersion, as
    /// Chrome reports V8_VERSION_STRING), or "" from an engine that names
    /// none.
    js_version: []const u8 = "",
    /// Browser.getVersion's revision.
    revision: []const u8 = "",
    /// The default browser context: the embedder's Browser (BORROWED; the
    /// embedder stops it after the server).
    default_host: *host_bridge.BrowserHost,
    /// What Target.createBrowserContext's Browsers are made with.
    context_config: host_bridge.BrowserConfig = .{},
    /// Browser.close, or the pipe's end: the embedder ends (the console
    /// exits, WebDriver ends its session). Called on the devtools thread.
    on_close: ?Callback = null,

    pub const Pipe = struct {
        read_fd: i32 = 3,
        write_fd: i32 = 4,
    };
};

pub const Callback = struct {
    context: ?*anyopaque,
    run: *const fn (?*anyopaque) void,
};

/// How long the acceptor waits for a connection before it looks at whether
/// the server is stopping.
const accept_poll_ms: u32 = 200;

pub const Server = struct {
    /// Thread-safe.
    allocator: Allocator,
    options: Options,
    /// The devtools thread's inbox.
    inbox: *runtime.TaskSink,
    /// The browser target's id: /devtools/browser/<id>.
    browser_id: ids.Token,
    port: u16 = 0,
    listener: ?platform.DevtoolsListener = null,
    acceptor: ?platform.Thread = null,
    devtools_thread: ?platform.Thread = null,
    stopping: std.atomic.Value(bool) = .init(false),
    /// 1 once Browser.close or the pipe's end asked the embedder to end:
    /// the futex word `waitUntilClosed` waits on.
    closed: std.atomic.Value(u32) = .init(0),
    /// Connection threads still running; `stop` waits for 0.
    live_threads: std.atomic.Value(u32) = .init(0),
    /// 1 once the devtools thread has finished its last task.
    devtools_done: std.atomic.Value(u32) = .init(0),
    token_high: u64,
    token_counter: std.atomic.Value(u64) = .init(1),

    // The devtools thread's own state.
    connections: std.ArrayList(*Connection) = .empty,
    contexts: std.ArrayList(*targets.Context) = .empty,
    target_list: std.ArrayList(*targets.Target) = .empty,
    sessions: std.ArrayList(*targets.Session) = .empty,
    next_connection_id: u32 = 1,
    next_window_id: i64 = 1,
    default_context: ?*targets.Context = null,

    /// Start the server: its listener and/or pipe, the devtools thread, and
    /// the default browser context's record on its Browser. OWNED by the
    /// caller until `stop`.
    pub fn start(allocator: Allocator, options: Options) !*Server {
        var random_bytes: [16]u8 = undefined;
        platform.fillRandom(&random_bytes);
        const self = try allocator.create(Server);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .options = options,
            .inbox = try runtime.TaskSink.create(allocator),
            .browser_id = ids.Token.of(std.mem.readInt(u64, random_bytes[0..8], .little), std.mem.readInt(u64, random_bytes[8..16], .little)),
            .token_high = std.mem.readInt(u64, random_bytes[0..8], .big),
        };
        errdefer self.inbox.release();
        // Browser.getVersion's user agent: the Browser's, Crane's default
        // when the embedder gave none.
        if (self.options.user_agent.len == 0) self.options.user_agent = @import("fetch").internal.user_agent.default_user_agent;
        // The JavaScript engine's version, as the engine reports it.
        if (self.options.js_version.len == 0) self.options.js_version = @import("engine").engineVersion() catch "";

        // The default context: the embedder's Browser.
        const default_context = try self.addContext(options.default_host, false);
        self.default_context = default_context;

        if (options.port) |port| {
            const listener = try platform.devtoolsListen(port);
            self.listener = listener;
            self.port = listener.port;
        }
        errdefer if (self.listener) |l| platform.devtoolsCloseListener(l);

        self.devtools_thread = try platform.spawnThread(.{ .name = .from("devtools") }, devtoolsMain, self);
        if (self.listener != null) {
            self.acceptor = platform.spawnThread(.{ .name = .from("devtools-accept") }, acceptorMain, self) catch |err| {
                self.stopThreads();
                return err;
            };
        }
        if (options.pipe) |pipe| {
            const fds = platform.devtoolsOpenInheritedPipe(pipe.read_fd, pipe.write_fd) catch |err| {
                self.stopThreads();
                return err;
            };
            self.openConnection(.{ .pipe = fds }) catch |err| {
                self.stopThreads();
                return err;
            };
        }
        if (options.user_data_dir) |dir| self.writeActivePort(dir);
        return self;
    }

    /// `ws://127.0.0.1:<port>/devtools/browser/<id>`, into `buffer`.
    pub fn browserUrl(self: *const Server, buffer: []u8) []const u8 {
        return std.fmt.bufPrint(buffer, "ws://127.0.0.1:{d}/devtools/browser/{s}", .{ self.port, self.browser_id.slice() }) catch "";
    }

    /// Block until Browser.close, the pipe's end, or `stop`.
    pub fn waitUntilClosed(self: *Server) void {
        while (self.closed.load(.acquire) == 0) {
            futexIo().futexWaitTimeout(u32, &self.closed.raw, 0, .none) catch {};
        }
    }

    /// Whether the server was asked to close (Browser.close, the pipe's end).
    pub fn isClosed(self: *const Server) bool {
        return self.closed.load(.acquire) != 0;
    }

    /// Stop: every connection closes, every session detaches, the Browsers
    /// Target.createBrowserContext made stop; the default Browser keeps
    /// running (it is the embedder's). Frees the server.
    pub fn stop(self: *Server) void {
        self.stopThreads();
        self.inbox.close();
        self.inbox.release();
        if (self.listener) |l| platform.devtoolsCloseListener(l);
        for (self.target_list.items) |t| self.freeTarget(t);
        self.target_list.deinit(self.allocator);
        for (self.sessions.items) |s| self.freeSession(s);
        self.sessions.deinit(self.allocator);
        for (self.contexts.items) |c| self.freeContext(c);
        self.contexts.deinit(self.allocator);
        self.connections.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    fn stopThreads(self: *Server) void {
        self.stopping.store(true, .release);
        if (self.devtools_thread) |thread| {
            // The devtools thread's last task closes every connection and
            // uninstalls from every Browser.
            if (!self.postTask(StopTask, .{})) self.devtools_done.store(1, .release);
            platform.joinThread(thread);
            self.devtools_thread = null;
        }
        if (self.acceptor) |thread| {
            platform.joinThread(thread);
            self.acceptor = null;
        }
        // No task runs any more: what is still queued is dropped now, before
        // the wait below - a connection the acceptor opened after StopTask
        // (its AddConnection, never run) is closed by its drop, so its
        // reader and writer end; every task's reference is let go. Later
        // posts are dropped as they come (TaskSink.post).
        self.inbox.close();
        // Readers and writers end once their connections are shut down.
        while (true) {
            const live = self.live_threads.load(.acquire);
            if (live == 0) break;
            futexIo().futexWaitTimeout(u32, &self.live_threads.raw, live, .{ .duration = .{ .raw = .fromMilliseconds(50), .clock = .awake } }) catch {};
        }
        self.closed.store(1, .release);
        futexIo().futexWake(u32, &self.closed.raw, std.math.maxInt(u32));
    }

    /// Ask the embedder to end (Browser.close, the pipe's EOF).
    pub fn requestClose(self: *Server) void {
        if (self.options.on_close) |cb| cb.run(cb.context);
        self.closed.store(1, .release);
        futexIo().futexWake(u32, &self.closed.raw, std.math.maxInt(u32));
    }

    pub fn freshToken(self: *Server) ids.Token {
        return ids.fresh(self.token_high, self.token_counter.fetchAdd(1, .monotonic));
    }

    /// Chrome's DevToolsActivePort file: the port, then the browser
    /// target's path (chrome/browser/devtools/remote_debugging_server.cc
    /// WriteDevToolsActivePortFile); chromedriver and Puppeteer read it.
    fn writeActivePort(self: *Server, dir: []const u8) void {
        var path_buffer: [4096]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buffer, "{s}/DevToolsActivePort", .{dir}) catch return;
        var text_buffer: [128]u8 = undefined;
        const text = std.fmt.bufPrint(&text_buffer, "{d}\n/devtools/browser/{s}", .{ self.port, self.browser_id.slice() }) catch return;
        platform.makeDirectoryPath(.from(dir)) catch {};
        platform.writeFileAtomic(.from(path), .from(text)) catch |err| log.warn("devtools: could not write {s}: {t}", .{ path, err });
    }

    // ------------------------------------------------------------------
    // The devtools thread's inbox
    // ------------------------------------------------------------------

    /// Post `value` (a struct with `fn run(*@This(), *Server) void` and an
    /// optional `fn drop(*@This(), Allocator) void`) to the devtools thread.
    /// Any thread. False when the server has stopped (the value is dropped).
    /// Run `value.run(server)` on the devtools thread. A task the inbox
    /// does not run - posted after it closed, still queued at its close, or
    /// refused for want of memory - is dropped instead: `value.drop`, which
    /// must be `pub` (Zig's @hasDecl does not see a private declaration: a
    /// private `drop` was never called, and every dropped task leaked what
    /// it held - a ClosedTask its Connection, with the Connection's Outbound,
    /// at every Server.stop that raced a reader's end; lane tpf).
    pub fn postTask(self: *Server, comptime T: type, value: T) bool {
        const Task = struct {
            server: *Server,
            value: T,

            fn run(data: ?*anyopaque) void {
                const task: *@This() = @ptrCast(@alignCast(data.?));
                const server = task.server;
                defer server.allocator.destroy(task);
                task.value.run(server);
            }

            fn drop(data: ?*anyopaque) void {
                const task: *@This() = @ptrCast(@alignCast(data.?));
                const server = task.server;
                if (comptime @hasDecl(T, "drop")) task.value.drop(server.allocator);
                server.allocator.destroy(task);
            }
        };
        const task = self.allocator.create(Task) catch {
            if (comptime @hasDecl(T, "drop")) {
                var v = value;
                v.drop(self.allocator);
            }
            return false;
        };
        task.* = .{ .server = self, .value = value };
        return self.inbox.post(.{ .run = Task.run, .drop = Task.drop, .data = task });
    }

    fn devtoolsMain(context: ?*anyopaque) callconv(.c) void {
        const self: *Server = @ptrCast(@alignCast(context.?));
        var tasks: std.ArrayList(runtime.CrossThreadTask) = .empty;
        defer tasks.deinit(self.allocator);
        while (self.devtools_done.load(.acquire) == 0) {
            self.inbox.waitForWork(null);
            tasks.clearRetainingCapacity();
            self.inbox.takeAll(&tasks, self.allocator) catch continue;
            for (tasks.items) |task| task.run(task.data);
        }
    }

    // ------------------------------------------------------------------
    // Browser contexts
    // ------------------------------------------------------------------

    /// Devtools thread (or `start`, before it runs): a context for `host`.
    pub fn addContext(self: *Server, host: *host_bridge.BrowserHost, owned: bool) !*targets.Context {
        const context = try self.allocator.create(targets.Context);
        errdefer self.allocator.destroy(context);
        const id = self.freshToken();
        const side = try BrowserSide.create(self.allocator, host, self.freshToken().low() ^ self.token_high, id.text, .{ .context = self, .post = postTargetEvent });
        errdefer side.destroy();
        context.* = .{ .id = id, .host = host, .side = side, .owned = owned };
        try self.contexts.append(self.allocator, context);
        browser_side.InstallTask.post(side) catch |err| log.warn("devtools: the Browser did not take the remote end's listener: {t}", .{err});
        return context;
    }

    pub fn findContext(self: *Server, id: ?[]const u8) ?*targets.Context {
        const wanted = id orelse return self.default_context;
        for (self.contexts.items) |c| if (!c.disposed and c.id.eql(wanted)) return c;
        return null;
    }

    fn contextOfSide(self: *Server, side: *BrowserSide) ?*targets.Context {
        for (self.contexts.items) |c| if (c.side == side) return c;
        return null;
    }

    /// Devtools thread: dispose a context (Target.disposeBrowserContext, a
    /// disposeOnDetach connection's end): its targets go - detachedFromTarget
    /// for their sessions, targetDestroyed for the discoverers - then its
    /// Browser stops.
    pub fn disposeContext(self: *Server, context: *targets.Context) void {
        if (context.disposed) return;
        context.disposed = true;
        // One target at a time, found afresh: a removal takes a tab's pair
        // (and their sessions) out of the lists at once, so no index into
        // them survives it (lane cdpr's G12: the backward walk read past the
        // list's end on Target.disposeBrowserContext).
        while (self.lastTargetOf(context)) |target| self.removeTarget(target, true);
        browser_side.uninstallAndWait(context.side);
        if (context.owned) context.host.stop();
    }

    fn freeContext(self: *Server, context: *targets.Context) void {
        if (!context.disposed) {
            context.disposed = true;
            browser_side.uninstallAndWait(context.side);
            if (context.owned) context.host.stop();
        }
        context.side.destroy();
        if (context.download_path) |p| self.allocator.free(p);
        self.allocator.destroy(context);
    }

    // ------------------------------------------------------------------
    // Targets
    // ------------------------------------------------------------------

    /// The newest target of `context`, or null.
    fn lastTargetOf(self: *Server, context: *targets.Context) ?*targets.Target {
        var i = self.target_list.items.len;
        while (i > 0) {
            i -= 1;
            if (self.target_list.items[i].context == context) return self.target_list.items[i];
        }
        return null;
    }

    /// The newest session that `matches(session, key)`, or null: what a
    /// removal loop asks again after each removal (`detach` takes a
    /// session's children with it, so no index survives one).
    fn lastSessionWhere(self: *Server, key: anytype, comptime matches: fn (*targets.Session, @TypeOf(key)) bool) ?*targets.Session {
        var i = self.sessions.items.len;
        while (i > 0) {
            i -= 1;
            if (matches(self.sessions.items[i], key)) return self.sessions.items[i];
        }
        return null;
    }

    fn sessionOnTarget(s: *targets.Session, target: *targets.Target) bool {
        return s.target == target;
    }

    fn sessionChildOf(s: *targets.Session, parent: *targets.Session) bool {
        return s.parent == parent;
    }

    fn sessionOfConnection(s: *targets.Session, connection_id: u32) bool {
        return s.connection_id == connection_id;
    }

    pub fn findTarget(self: *Server, id: []const u8) ?*targets.Target {
        for (self.target_list.items) |t| if (t.id.eql(id)) return t;
        return null;
    }

    pub fn pageTargetOf(self: *Server, context: *targets.Context, tab: host_bridge.TabId) ?*targets.Target {
        for (self.target_list.items) |t| if (t.context == context and t.tab == tab and t.type == .page) return t;
        return null;
    }

    /// A tab became known (host event tab_created): its tab and page
    /// targets, targetCreated for the discoverers, auto-attach.
    fn addTab(self: *Server, context: *targets.Context, tab: host_bridge.TabId, opener_tab: ?host_bridge.TabId, opened_by_page: bool) void {
        if (self.pageTargetOf(context, tab) != null) return;
        const page = self.allocator.create(targets.Target) catch return;
        const tab_target = self.allocator.create(targets.Target) catch {
            self.allocator.destroy(page);
            return;
        };
        const window_id = self.next_window_id;
        self.next_window_id += 1;
        const opener: ?ids.Token = if (opener_tab) |o| ids.frameId(context.side.token, o) else null;
        page.* = .{
            .id = ids.frameId(context.side.token, tab),
            .type = .page,
            .context = context,
            .tab = tab,
            .url = self.allocator.dupe(u8, "about:blank") catch return,
            .title = &.{},
            .opener = opener,
            .opened_by_page = opened_by_page,
            .partner = tab_target,
            .window_id = window_id,
            .held = self.wouldWait(context),
        };
        tab_target.* = .{
            .id = self.freshToken(),
            .type = .tab,
            .context = context,
            .tab = tab,
            // Chrome's new tab target has no URL until its page commits
            // (vue-e2e protocol log l.103: url ""); its page target's is
            // about:blank from the start.
            .url = self.allocator.alloc(u8, 0) catch return,
            .title = &.{},
            .opener = opener,
            .opened_by_page = opened_by_page,
            .partner = page,
            .window_id = window_id,
        };
        self.target_list.append(self.allocator, tab_target) catch return;
        self.target_list.append(self.allocator, page) catch return;

        // Target.targetCreated to the discoverers (Chrome: TargetHandler::
        // DevToolsAgentHostCreated), tab first.
        for (self.sessions.items) |s| {
            const filter = s.discover orelse continue;
            for ([_]*targets.Target{ tab_target, page }) |t| {
                if (filter.matches(t.type)) s.emit(protocol.Target.targetCreated, .{ .targetInfo = targets.targetInfo(t) });
            }
        }
        // Auto-attach: browser sessions to whichever of the two their filter
        // takes; tab sessions of... none yet (the tab is new).
        var i: usize = 0;
        while (i < self.sessions.items.len) : (i += 1) {
            const s = self.sessions.items[i];
            if (s.kind != .browser or !s.auto_attach.enabled) continue;
            if (s.target != null) continue;
            for ([_]*targets.Target{ tab_target, page }) |t| {
                if (!s.auto_attach.filter.matches(t.type)) continue;
                if (t.context != context and !self.contextVisibleTo(s, t.context)) continue;
                _ = self.attach(s, t, s.auto_attach.wait_for_debugger) catch continue;
            }
        }
    }

    fn contextVisibleTo(self: *Server, session: *targets.Session, context: *targets.Context) bool {
        _ = .{ self, session, context };
        // Chrome's browser session sees every context's targets.
        return true;
    }

    /// Whether a new tab of `context` will be reported waiting: some
    /// session auto-attaches with waitForDebuggerOnStart.
    pub fn wouldWait(self: *Server, context: *targets.Context) bool {
        _ = context;
        for (self.sessions.items) |s| {
            if (s.kind == .browser and s.auto_attach.enabled and s.auto_attach.wait_for_debugger) return true;
        }
        return false;
    }

    /// Tell every Browser whether the tabs its pages open start held: while
    /// any browser session auto-attaches with waitForDebuggerOnStart.
    pub fn updatePopupHolds(self: *Server) void {
        for (self.contexts.items) |c| {
            if (c.disposed) continue;
            const hold = self.wouldWait(c);
            if (c.side.wait_for_debugger.load(.acquire) != hold) browser_side.HoldPopupsTask.post(c.side, hold);
        }
    }

    /// Devtools thread: a tab's targets go - with `with_partner`, both of
    /// them, the PAGE target first: its sessions detach (the page child's
    /// detachedFromTarget goes to the tab session it was auto-attached on)
    /// and its targetDestroyed goes, then the tab target's sessions detach
    /// (detachedFromTarget on the browser session) and its targetDestroyed.
    /// Chrome's order (tmp/plans/cdp1-evidence/vue-e2e.protocol.log.gz, a
    /// tab closing: targetInfoChanged page attached:false, detachedFromTarget
    /// of the page session on the tab session, targetDestroyed page,
    /// targetInfoChanged tab attached:false, detachedFromTarget of the tab
    /// session on the browser session): the page's WebContents goes before
    /// its tab's agent host (content/browser/devtools/protocol/
    /// target_handler.cc DevToolsAgentHostDestroyed per host). Removing the
    /// tab first detached the page child with its parent, unannounced, and
    /// Puppeteer kept its CDPSession (lane cdpr's G7).
    pub fn removeTarget(self: *Server, target: *targets.Target, with_partner: bool) void {
        if (with_partner) if (target.partner) |partner| {
            const page = if (target.type == .page) target else partner;
            const tab = if (target.type == .page) partner else target;
            self.removeTarget(page, false);
            self.removeTarget(tab, false);
            return;
        };
        while (self.lastSessionWhere(target, sessionOnTarget)) |s| self.detach(s, true);
        for (self.sessions.items) |s| {
            const filter = s.discover orelse continue;
            if (filter.matches(target.type)) s.emit(protocol.Target.targetDestroyed, .{ .targetId = target.id.slice() });
        }
        for (self.target_list.items, 0..) |t, at| if (t == target) {
            _ = self.target_list.orderedRemove(at);
            break;
        };
        if (target.partner) |p| p.partner = null;
        self.freeTarget(target);
    }

    fn freeTarget(self: *Server, target: *targets.Target) void {
        self.allocator.free(target.url);
        self.allocator.free(target.title);
        target.waiting.deinit(self.allocator);
        self.allocator.destroy(target);
    }

    /// A target's URL or title changed: targetInfoChanged to the
    /// discoverers (TargetHandler::DevToolsAgentHostChanged).
    fn targetChanged(self: *Server, target: *targets.Target) void {
        for (self.sessions.items) |s| {
            const filter = s.discover orelse continue;
            if (filter.matches(target.type)) s.emit(protocol.Target.targetInfoChanged, .{ .targetInfo = targets.targetInfo(target) });
        }
    }

    // ------------------------------------------------------------------
    // Sessions
    // ------------------------------------------------------------------

    /// Attach a new session of `parent`'s connection to `target`, announced
    /// on `parent` (Target.attachedToTarget). `waiting`: reported
    /// waitingForDebugger (a new target under waitForDebuggerOnStart).
    pub fn attach(self: *Server, parent: *targets.Session, target: *targets.Target, waiting: bool) !*targets.Session {
        const id = self.freshToken();
        const connection = self.connectionById(parent.connection_id) orelse return error.ConnectionGone;
        const link = try outbound.SessionLink.create(self.allocator, connection.outbound, id.slice());
        errdefer link.release();
        const session = try self.allocator.create(targets.Session);
        errdefer self.allocator.destroy(session);
        // What holds is the tab's first navigation, kept on its page target:
        // a session on the tab target waits for its page's hold. Chrome
        // reports the TAB attached waitingForDebugger: true and its page
        // child false (vue-e2e protocol log: Puppeteer's tab session, then
        // its runIfWaitingForDebugger releases the tab - lane cdpr's G1).
        const hold = holdOf(target);
        const wait_now = waiting and hold.held;
        session.* = .{
            .id = id,
            .implicit = false,
            .kind = switch (target.type) {
                .page => .page,
                .tab => .tab,
                .browser => .browser,
            },
            .connection_id = parent.connection_id,
            .link = link,
            .target = target,
            .parent = parent,
            .waiting = wait_now,
            .server = self,
        };
        try self.sessions.append(self.allocator, session);
        self.noteAttached(target);
        if (wait_now) hold.waiting.append(self.allocator, id) catch {};
        // The event that creates the session goes before anything on it.
        parent.emit(protocol.Target.attachedToTarget, .{
            .sessionId = id.slice(),
            .targetInfo = targets.targetInfo(target),
            .waitingForDebugger = wait_now,
        });
        if (session.kind == .page) self.attachPage(session, target);
        return session;
    }

    /// Target.attachToBrowserTarget: another browser session on `parent`'s
    /// connection, announced on `parent`.
    pub fn attachBrowserSession(self: *Server, parent: *targets.Session) !*targets.Session {
        const connection = self.connectionById(parent.connection_id) orelse return error.ConnectionGone;
        const id = self.freshToken();
        const link = try outbound.SessionLink.create(self.allocator, connection.outbound, id.slice());
        errdefer link.release();
        const session = try self.allocator.create(targets.Session);
        errdefer self.allocator.destroy(session);
        session.* = .{ .id = id, .implicit = false, .kind = .browser, .connection_id = parent.connection_id, .link = link, .parent = parent, .server = self };
        try self.sessions.append(self.allocator, session);
        parent.emit(protocol.Target.attachedToTarget, .{
            .sessionId = id.slice(),
            .targetInfo = .{ .targetId = self.browser_id.slice(), .type = "browser", .title = "", .url = "", .attached = true, .canAccessOpener = false },
            .waitingForDebugger = false,
        });
        return session;
    }

    /// The connection's own session for /devtools/page/<id>.
    fn attachImplicitPage(self: *Server, connection: *Connection, target: *targets.Target) !void {
        const link = try outbound.SessionLink.create(self.allocator, connection.outbound, "");
        errdefer link.release();
        const session = try self.allocator.create(targets.Session);
        errdefer self.allocator.destroy(session);
        session.* = .{
            .id = self.freshToken(),
            .implicit = true,
            .kind = .page,
            .connection_id = connection.id,
            .link = link,
            .target = target,
            .server = self,
        };
        try self.sessions.append(self.allocator, session);
        self.noteAttached(target);
        connection.implicit_session = session;
        self.attachPage(session, target);
    }

    fn attachPage(self: *Server, session: *targets.Session, target: *targets.Target) void {
        const page = PageSession.allocate(self.allocator, session.link, target.tab, target.id) catch return;
        browser_side.AttachTask.post(target.context.side, page) catch {
            page.discard();
            return;
        };
        session.page = page;
    }

    /// Detach `session`: its Browser-thread half goes, detachedFromTarget
    /// goes to its parent (`notify`), and the sessions it auto-attached
    /// detach with it.
    pub fn detach(self: *Server, session: *targets.Session, notify: bool) void {
        // Its children first (each found afresh: a child's own children go
        // with it).
        while (self.lastSessionWhere(session, sessionChildOf)) |child| self.detach(child, false);
        // The target's last session going: targetInfoChanged (attached
        // false) to the discoverers, before the detachedFromTarget (Chrome's
        // order in the vue-e2e log, removeTarget).
        if (session.target) |t| {
            t.attached_sessions -|= 1;
            if (t.attached_sessions == 0) self.targetChanged(t);
        }
        if (notify) if (session.parent) |parent| {
            if (session.target) |t| parent.emit(protocol.Target.detachedFromTarget, .{ .sessionId = session.id.slice(), .targetId = t.id.slice() });
        };
        for (self.sessions.items, 0..) |s, at| if (s == session) {
            _ = self.sessions.orderedRemove(at);
            break;
        };
        if (session.target) |t| {
            if (session.waiting) self.doneWaiting(t, session.id);
        }
        self.freeSession(session);
    }

    /// A session attached to `target`: its first makes it `attached`, which
    /// the discoverers hear (targetInfoChanged) before the attachedToTarget
    /// (Chrome: TargetHandler::DevToolsAgentHostAttached; the vue-e2e log's
    /// targetInfoChanged attached:true, then attachedToTarget).
    fn noteAttached(self: *Server, target: *targets.Target) void {
        target.attached_sessions += 1;
        if (target.attached_sessions == 1) self.targetChanged(target);
    }

    /// The target whose `held` and `waiting` decide a session's wait on
    /// `target`: the tab's page target for a tab target (the hold is the
    /// tab's first navigation, kept on its page), else `target`. A tab whose
    /// page is gone holds nothing.
    fn holdOf(target: *targets.Target) *targets.Target {
        if (target.type == .tab) return target.partner orelse target;
        return target;
    }

    fn freeSession(self: *Server, session: *targets.Session) void {
        if (session.page) |page| {
            if (session.target) |t| {
                // A detach lets go of what the session holds (Chrome's
                // interceptor Detach); a blocking fetch's hold here, as its
                // Browser thread waits in it.
                fetch_interception.release(t.context.side, page, .blocking);
                browser_side.DetachTask.post(t.context.side, page);
            } else page.discard();
            session.page = null;
        }
        session.link.end();
        session.link.release();
        if (session.discover) |*f| f.deinit(self.allocator);
        session.auto_attach.filter.deinit(self.allocator);
        self.allocator.destroy(session);
    }

    pub fn findSession(self: *Server, connection_id: u32, id: []const u8) ?*targets.Session {
        for (self.sessions.items) |s| {
            if (s.connection_id == connection_id and !s.implicit and s.id.eql(id)) return s;
        }
        return null;
    }

    /// One of `target`'s waiting sessions has run: at zero, the tab's hold
    /// is released (life1's `release`, through the host's releaseTab).
    /// `target` may be the tab target: its waiting is its page's (`holdOf`),
    /// on runIfWaitingForDebugger and on detach alike.
    pub fn doneWaiting(self: *Server, target: *targets.Target, session_id: ids.Token) void {
        _ = self;
        const hold = holdOf(target);
        for (hold.waiting.items, 0..) |w, at| if (std.mem.eql(u8, &w.text, &session_id.text)) {
            _ = hold.waiting.swapRemove(at);
            break;
        };
        if (hold.waiting.items.len != 0 or !hold.held) return;
        hold.held = false;
        ReleaseTask.post(hold.context.side, hold.tab);
    }

    // ------------------------------------------------------------------
    // Connections
    // ------------------------------------------------------------------

    fn connectionById(self: *Server, id: u32) ?*Connection {
        for (self.connections.items) |c| if (c.id == id) return c;
        return null;
    }

    /// Any thread before the devtools thread starts, else the acceptor: a
    /// connection and its threads.
    fn openConnection(self: *Server, transport: Connection.Transport) !void {
        const connection = try Connection.create(self, transport);
        // The devtools thread lists it; until then it is the reader's.
        // A refused post drops the task, which shuts the connection and
        // releases the task's reference.
        if (!self.postTask(AddConnection, .{ .connection = connection.retain() })) {
            connection.release();
            return error.Stopping;
        }
        connection.startThreads() catch |err| {
            connection.shutdown();
            connection.release();
            return err;
        };
        connection.release();
    }

    fn acceptorMain(context: ?*anyopaque) callconv(.c) void {
        const self: *Server = @ptrCast(@alignCast(context.?));
        const listener = self.listener.?;
        while (!self.stopping.load(.acquire)) {
            const stream = platform.devtoolsAccept(listener, accept_poll_ms) catch |err| {
                log.warn("devtools: accept failed: {t}", .{err});
                platform.sleepThread(accept_poll_ms * std.time.ns_per_ms);
                continue;
            } orelse continue;
            self.openConnection(.{ .socket = stream }) catch |err| {
                log.warn("devtools: a connection could not start: {t}", .{err});
            };
        }
    }

    /// Devtools thread: a connection ended. Its sessions detach, and the
    /// contexts it made with disposeOnDetach are disposed.
    fn connectionClosed(self: *Server, connection: *Connection) void {
        while (self.lastSessionWhere(connection.id, sessionOfConnection)) |s| self.detach(s, false);
        for (self.contexts.items) |c| {
            if (c.dispose_with == connection.id) self.disposeContext(c);
        }
        connection.implicit_session = null;
        connection.outbound.close();
        connection.shutdown();
        self.updatePopupHolds();
        for (self.connections.items, 0..) |c, at| if (c == connection) {
            _ = self.connections.orderedRemove(at);
            connection.release();
            break;
        };
        // Chrome: the pipe's end ends the browser (DevToolsPipeHandler's
        // read thread reaching EOF shuts it down).
        if (connection.transport == .pipe) self.requestClose();
    }

    // ------------------------------------------------------------------
    // HTTP, on the devtools thread
    // ------------------------------------------------------------------

    fn handleHttp(self: *Server, connection: *Connection, request: *const OwnedRequest) void {
        // devtools_http_handler.cc: refuse a Host that is not an IP or
        // localhost (500), before anything else.
        if (!http.hostIsSafe(request.host)) return self.respond(connection, 500, http.text_type, http.host_refused_message);
        const path = request.path;
        if (request.upgrade) return self.handleUpgrade(connection, request);
        if (eqlPath(path, "/json/version")) {
            const body = self.versionJson() catch return self.respond(connection, 500, http.text_type, "");
            defer self.allocator.free(body);
            return self.respond(connection, 200, http.json_type, body);
        }
        if (eqlPath(path, "/json") or eqlPath(path, "/json/list")) {
            const body = self.listJson() catch return self.respond(connection, 500, http.text_type, "");
            defer self.allocator.free(body);
            return self.respond(connection, 200, http.json_type, body);
        }
        if (eqlPath(path, "/json/protocol")) {
            const body = protocolJson(self.allocator) catch return self.respond(connection, 500, http.text_type, "");
            defer self.allocator.free(body);
            return self.respond(connection, 200, http.json_type, body);
        }
        // /json/new, /json/activate, /json/close: CDP part 2.
        self.respond(connection, 404, http.text_type, "Unknown command");
    }

    fn handleUpgrade(self: *Server, connection: *Connection, request: *const OwnedRequest) void {
        if (request.origin) |origin| if (!http.originAllowed(origin, self.options.allowed_origins)) {
            const message = http.originRefusedMessage(self.allocator, origin) catch return self.respond(connection, 403, http.text_type, "");
            defer self.allocator.free(message);
            return self.respond(connection, 403, http.text_type, message);
        };
        // RFC 6455 4.2.1: version 13 and a valid key, or 400 (4.2.2: a
        // Sec-WebSocket-Version header with the supported versions).
        const key = request.ws_key orelse return self.respond(connection, 400, http.text_type, "");
        if (!ws.validKey(key) or !std.mem.eql(u8, request.ws_version orelse "", "13")) return self.respond(connection, 400, http.text_type, "");

        const browser_prefix = "/devtools/browser/";
        const page_prefix = "/devtools/page/";
        var page_target: ?*targets.Target = null;
        if (std.mem.startsWith(u8, request.path, browser_prefix)) {
            if (!self.browser_id.eql(request.path[browser_prefix.len..])) return self.respond(connection, 404, http.text_type, "");
        } else if (std.mem.startsWith(u8, request.path, page_prefix)) {
            page_target = self.findTarget(request.path[page_prefix.len..]) orelse return self.respond(connection, 404, http.text_type, "");
            if (page_target.?.type != .page) return self.respond(connection, 404, http.text_type, "");
        } else return self.respond(connection, 404, http.text_type, "");

        const accept = ws.handshakeResponse(self.allocator, key) catch return;
        connection.outbound.pushRaw(accept);
        connection.mode.store(.websocket, .release);
        if (page_target) |target| {
            self.attachImplicitPage(connection, target) catch {};
        } else {
            self.makeBrowserSession(connection) catch {};
        }
    }

    fn makeBrowserSession(self: *Server, connection: *Connection) !void {
        const link = try outbound.SessionLink.create(self.allocator, connection.outbound, "");
        errdefer link.release();
        const session = try self.allocator.create(targets.Session);
        errdefer self.allocator.destroy(session);
        session.* = .{ .id = self.freshToken(), .implicit = true, .kind = .browser, .connection_id = connection.id, .link = link, .server = self };
        try self.sessions.append(self.allocator, session);
        connection.implicit_session = session;
    }

    fn respond(self: *Server, connection: *Connection, status: u16, content_type: []const u8, body: []const u8) void {
        const bytes = http.response(self.allocator, status, content_type, body) catch return;
        connection.outbound.pushRaw(bytes);
        connection.outbound.finish();
    }

    /// /json/version (devtools_http_handler.cc kVersion fields).
    fn versionJson(self: *Server) ![]u8 {
        var url_buffer: [160]u8 = undefined;
        const Version = struct {
            Browser: []const u8,
            @"Protocol-Version": []const u8,
            @"User-Agent": []const u8,
            @"V8-Version": []const u8,
            webSocketDebuggerUrl: []const u8,
        };
        return std.json.Stringify.valueAlloc(self.allocator, Version{
            .Browser = self.options.product,
            .@"Protocol-Version" = protocol.protocol_version,
            .@"User-Agent" = self.options.user_agent,
            .@"V8-Version" = self.options.js_version,
            .webSocketDebuggerUrl = self.browserUrl(&url_buffer),
        }, .{ .whitespace = .indent_3 });
    }

    /// /json/list: the page targets (devtools_http_handler.cc
    /// SerializeDescriptor), without devtoolsFrontendUrl - Crane serves no
    /// DevTools front end.
    fn listJson(self: *Server) ![]u8 {
        const Entry = struct {
            description: []const u8 = "",
            id: []const u8,
            title: []const u8,
            type: []const u8,
            url: []const u8,
            webSocketDebuggerUrl: []const u8,
        };
        var entries: std.ArrayList(Entry) = .empty;
        defer entries.deinit(self.allocator);
        var urls: std.ArrayList([]u8) = .empty;
        defer {
            for (urls.items) |u| self.allocator.free(u);
            urls.deinit(self.allocator);
        }
        for (self.target_list.items) |t| {
            if (t.type != .page) continue;
            const ws_url = try std.fmt.allocPrint(self.allocator, "ws://127.0.0.1:{d}/devtools/page/{s}", .{ self.port, t.id.slice() });
            try urls.append(self.allocator, ws_url);
            try entries.append(self.allocator, .{
                .id = t.id.slice(),
                .title = if (t.title.len != 0) t.title else t.url,
                .type = "page",
                .url = t.url,
                .webSocketDebuggerUrl = ws_url,
            });
        }
        return std.json.Stringify.valueAlloc(self.allocator, entries.items, .{ .whitespace = .indent_3 });
    }

    // ------------------------------------------------------------------
    // Messages, on the devtools thread
    // ------------------------------------------------------------------

    fn handleMessage(self: *Server, connection: *Connection, raw: []const u8) void {
        var arena_state = std.heap.ArenaAllocator.init(self.allocator);
        defer arena_state.deinit();
        const arena = arena_state.allocator();
        const fallback_link = if (connection.implicit_session) |s| s.link else return;
        const parsed = json_rpc.parse(arena, raw) catch return;
        const command = switch (parsed) {
            .failure => |f| {
                const link = if (f.session_id.len != 0) (if (self.findSession(connection.id, f.session_id)) |s| s.link else fallback_link) else fallback_link;
                return dispatch.sendError(link, f.id, @backingInt(f.code), f.message, null);
            },
            .command => |c| c,
        };
        const session = if (command.session_id.len == 0)
            connection.implicit_session.?
        else
            self.findSession(connection.id, command.session_id) orelse {
                // DevToolsSession: "Session with given id not found."
                return dispatch.sendError(fallback_link, command.id, @backingInt(json_rpc.Code.session_not_found), "Session with given id not found.", null);
            };
        const dot = std.mem.indexOfScalar(u8, command.method, '.') orelse command.method.len;
        const domain = command.method[0..dot];
        const devtools_side = std.mem.eql(u8, domain, "Target") or std.mem.eql(u8, domain, "Browser") or session.kind != .page;
        if (devtools_side) {
            return dispatch.dispatch(browser_target.Handlers, session, arena, &command);
        }
        // Page.handleJavaScriptDialog: answered here, by completing the
        // dialog the Browser thread waits in - Chrome's browser process
        // answers it (content/browser/devtools/protocol/page_handler.cc
        // PageHandler::HandleJavaScriptDialog) while the renderer is blocked
        // on the dialog; the session's other messages wait for the dialog
        // to close (host_bridge.postSessionMessage queues them).
        if (std.mem.eql(u8, command.method, protocol.Page.handleJavaScriptDialog.method)) {
            return self.answerDialog(session, arena, &command);
        }
        // The Fetch commands that answer a held request: answered here, as
        // Chrome's browser-side FetchHandler answers them while the
        // renderer may be blocked in a synchronous fetch the request
        // belongs to (fetch_interception.zig).
        if (fetch_interception.isDevtoolsThreadCommand(command.method)) {
            return dispatch.dispatch(FetchDevtoolsHandlers, session, arena, &command);
        }
        // Fetch.disable: the session's blocking holds are let go here first
        // (the Browser thread may be waiting in one); the message then
        // disables the patterns on the Browser thread.
        if (std.mem.eql(u8, command.method, protocol.Fetch.disable.method)) {
            if (session.page) |page| if (session.target) |t| fetch_interception.release(t.context.side, page, .blocking);
        }
        // A page session's message: to its Browser's thread.
        const page = session.page orelse return dispatch.sendError(session.link, command.id, @backingInt(json_rpc.Code.server_error), "Target is closing", null);
        const target = session.target.?;
        browser_side.MessageTask.post(target.context.side, page, raw) catch {
            dispatch.sendError(session.link, command.id, @backingInt(json_rpc.Code.server_error), "Target closed", null);
        };
    }

    fn answerDialog(self: *Server, session: *targets.Session, arena: Allocator, command: *const json_rpc.Command) void {
        _ = self;
        const P = protocol.Page.handleJavaScriptDialog;
        const params = std.json.parseFromValueLeaky(P.Params, arena, command.params, .{ .ignore_unknown_fields = true }) catch |err| {
            return dispatch.sendError(session.link, command.id, @backingInt(json_rpc.Code.invalid_params), "Invalid parameters", @errorName(err));
        };
        const target = session.target orelse return dispatch.sendError(session.link, command.id, @backingInt(json_rpc.Code.server_error), "No dialog is showing", null);
        const text = params.promptText orelse "";
        // The host's answer for the tab's open dialog (the DialogAnswer the
        // paused Browser thread waits on); before the host API has it, the
        // answer the dialog_opening event carried.
        const answered = host_bridge.answerUserPrompt(target.context.host, target.tab, params.accept, text) orelse blk: {
            const dialog = target.dialog orelse break :blk false;
            break :blk dialog.answer(dialog.context, params.accept, text);
        };
        target.dialog = null;
        if (!answered) return dispatch.sendError(session.link, command.id, @backingInt(json_rpc.Code.server_error), "No dialog is showing", null);
        const reply: dispatch.Reply(P) = .{ .link = session.link.retain(), .id = command.id };
        reply.ok(.{});
    }

    // ------------------------------------------------------------------
    // Events from the Browsers (BrowserSide's sink): any thread
    // ------------------------------------------------------------------

    fn postTargetEvent(context: *anyopaque, side: *BrowserSide, event: browser_side.TargetEvent) void {
        const self: *Server = @ptrCast(@alignCast(context));
        _ = self.postTask(TargetEventTask, .{ .side = side, .event = event });
    }

    fn handleTargetEvent(self: *Server, side: *BrowserSide, event: browser_side.TargetEvent) void {
        const context = self.contextOfSide(side) orelse return;
        if (context.disposed) return;
        switch (event) {
            .tab_created => |e| self.addTab(context, e.tab, e.opener, e.opened_by_page),
            .tab_destroyed => |e| if (self.pageTargetOf(context, e.tab)) |t| self.removeTarget(t, true),
            // A commit: the new document's URL, its title not known yet (the
            // URL stands for it, Chrome's fallback); a same-document
            // navigation keeps the title.
            .navigated => |e| if (self.pageTargetOf(context, e.navigable)) |page| {
                for ([_]?*targets.Target{ page, page.partner }) |maybe| {
                    const t = maybe orelse continue;
                    const url = self.allocator.dupe(u8, e.url) catch continue;
                    self.allocator.free(t.url);
                    t.url = url;
                    t.committed = true;
                    if (e.cross_document and t.title.len > 0) {
                        self.allocator.free(t.title);
                        t.title = &.{};
                    }
                    self.targetChanged(t);
                }
            },
            // Only the page target carries the title (Chrome's tab target
            // reports "").
            .title_changed => |e| if (self.pageTargetOf(context, e.tab)) |page| {
                if (!std.mem.eql(u8, page.title, e.title)) {
                    if (self.allocator.dupe(u8, e.title)) |title| {
                        self.allocator.free(page.title);
                        page.title = title;
                        self.targetChanged(page);
                    } else |_| {}
                }
            },
            .dialog_opening => |e| if (self.pageTargetOf(context, e.tab)) |t| {
                t.dialog = e.answer;
            },
            .dialog_closed => |e| if (self.pageTargetOf(context, e.tab)) |t| {
                t.dialog = null;
            },
            .run_if_waiting => |e| if (self.pageTargetOf(context, e.tab)) |t| {
                for (self.sessions.items) |s| {
                    if (s.target == t and std.mem.eql(u8, s.id.slice(), std.mem.sliceTo(&e.session_id, 0)) and s.waiting) {
                        s.waiting = false;
                        self.doneWaiting(t, s.id);
                        break;
                    }
                }
            },
        }
    }
};

fn eqlPath(path: []const u8, wanted: []const u8) bool {
    return std.mem.eql(u8, std.mem.trimEnd(u8, path, "/"), wanted);
}

/// /json/protocol: both pinned files' domains in one object, as Chrome
/// serves its compiled-in copy. OWNED by the caller.
pub fn protocolJson(allocator: Allocator) ![]u8 {
    const browser_text = @embedFile("browser_protocol.json");
    const js_text = @embedFile("js_protocol.json");
    // browser_protocol.json is {"version": ..., "domains": [ ... ]}: splice
    // js_protocol.json's domains in before its last "]".
    const browser_end = std.mem.lastIndexOfScalar(u8, browser_text, ']') orelse return error.InvalidProtocol;
    const js_start = (std.mem.indexOf(u8, js_text, "\"domains\"") orelse return error.InvalidProtocol);
    const js_open = std.mem.indexOfScalarPos(u8, js_text, js_start, '[') orelse return error.InvalidProtocol;
    const js_close = std.mem.lastIndexOfScalar(u8, js_text, ']') orelse return error.InvalidProtocol;
    return std.mem.concat(allocator, u8, &.{
        browser_text[0..browser_end],
        ",",
        js_text[js_open + 1 .. js_close],
        browser_text[browser_end..],
    });
}

// ============================================================================
// Tasks on the devtools thread
// ============================================================================

const StopTask = struct {
    fn run(_: *StopTask, server: *Server) void {
        // Every connection closes; every session detaches; every Browser the
        // server made stops; the default Browser loses its listener.
        while (server.connections.items.len > 0) {
            closeConnectionForStop(server, server.connections.items[server.connections.items.len - 1]);
        }
        for (server.contexts.items) |c| {
            if (!c.disposed) {
                c.disposed = true;
                browser_side.uninstallAndWait(c.side);
                if (c.owned) c.host.stop();
            }
        }
        server.devtools_done.store(1, .release);
    }
};

const AddConnection = struct {
    connection: *Connection,

    fn run(self: *AddConnection, server: *Server) void {
        // After StopTask (a connection accepted while the server stopped,
        // its task behind StopTask in the same batch): no StopTask will
        // close it, so it is closed now, as a dropped task's.
        if (server.devtools_done.load(.acquire) != 0) return self.drop(server.allocator);
        server.connections.append(server.allocator, self.connection) catch {
            self.drop(server.allocator);
            return;
        };
        if (self.connection.transport == .pipe) {
            self.connection.mode.store(.pipe, .release);
            server.makeBrowserSession(self.connection) catch {};
        }
    }

    pub fn drop(self: *AddConnection, allocator: Allocator) void {
        _ = allocator;
        // Its writer waits on the outbound, its reader on the transport:
        // both end.
        self.connection.outbound.close();
        self.connection.shutdown();
        self.connection.release();
    }
};

const HttpTask = struct {
    connection: *Connection,
    request: OwnedRequest,

    fn run(self: *HttpTask, server: *Server) void {
        defer self.drop(server.allocator);
        server.handleHttp(self.connection, &self.request);
    }

    pub fn drop(self: *HttpTask, allocator: Allocator) void {
        self.request.deinit(allocator);
        self.connection.release();
    }
};

const MessageTask = struct {
    connection: *Connection,
    text: []u8,

    fn run(self: *MessageTask, server: *Server) void {
        defer self.drop(server.allocator);
        server.handleMessage(self.connection, self.text);
    }

    pub fn drop(self: *MessageTask, allocator: Allocator) void {
        allocator.free(self.text);
        self.connection.release();
    }
};

const ClosedTask = struct {
    connection: *Connection,

    fn run(self: *ClosedTask, server: *Server) void {
        defer self.connection.release();
        for (server.connections.items) |c| if (c == self.connection) {
            server.connectionClosed(self.connection);
            return;
        };
    }

    pub fn drop(self: *ClosedTask, allocator: Allocator) void {
        _ = allocator;
        self.connection.release();
    }
};

const TargetEventTask = struct {
    side: *BrowserSide,
    event: browser_side.TargetEvent,

    fn run(self: *TargetEventTask, server: *Server) void {
        defer self.drop(server.allocator);
        server.handleTargetEvent(self.side, self.event);
    }

    pub fn drop(self: *TargetEventTask, allocator: Allocator) void {
        switch (self.event) {
            .navigated => |e| allocator.free(e.url),
            .title_changed => |e| allocator.free(e.title),
            else => {},
        }
    }
};

/// Release a held tab on its Browser's thread.
const ReleaseTask = struct {
    side: *BrowserSide,
    tab: host_bridge.TabId,

    fn post(side: *BrowserSide, tab: host_bridge.TabId) void {
        const task = side.allocator.create(ReleaseTask) catch return;
        task.* = .{ .side = side, .tab = tab };
        _ = side.host.post(task, run, drop);
    }

    fn run(context: ?*anyopaque, b: *host_bridge.Browser) void {
        const task: *ReleaseTask = @ptrCast(@alignCast(context.?));
        defer task.side.allocator.destroy(task);
        host_bridge.releaseTab(b, task.tab);
    }

    fn drop(context: ?*anyopaque) void {
        const task: *ReleaseTask = @ptrCast(@alignCast(context.?));
        task.side.allocator.destroy(task);
    }
};

/// A connection's end for the server's own stop: as `connectionClosed`,
/// without the pipe's close request, and with what is queued still written.
fn closeConnectionForStop(server: *Server, connection: *Connection) void {
    while (server.lastSessionWhere(connection.id, Server.sessionOfConnection)) |s| server.detach(s, false);
    connection.implicit_session = null;
    // The writer writes what is queued (a Browser.close reply) and then
    // shuts the connection, which ends the reader.
    connection.outbound.finish();
    for (server.connections.items, 0..) |c, at| if (c == connection) {
        _ = server.connections.orderedRemove(at);
        connection.release();
        break;
    };
}

/// What the devtools thread needs of a request (OWNED copies).
const OwnedRequest = struct {
    path: []u8,
    host: ?[]u8,
    origin: ?[]u8,
    upgrade: bool,
    ws_key: ?[]u8,
    ws_version: ?[]u8,

    fn from(allocator: Allocator, request: *const http.Request) Allocator.Error!OwnedRequest {
        var owned: OwnedRequest = .{ .path = &.{}, .host = null, .origin = null, .upgrade = request.isWebSocketUpgrade(), .ws_key = null, .ws_version = null };
        errdefer owned.deinit(allocator);
        owned.path = try allocator.dupe(u8, request.path());
        if (request.header("host")) |v| owned.host = try allocator.dupe(u8, v);
        if (request.header("origin")) |v| owned.origin = try allocator.dupe(u8, v);
        if (request.header("sec-websocket-key")) |v| owned.ws_key = try allocator.dupe(u8, v);
        if (request.header("sec-websocket-version")) |v| owned.ws_version = try allocator.dupe(u8, v);
        return owned;
    }

    fn deinit(self: *OwnedRequest, allocator: Allocator) void {
        allocator.free(self.path);
        if (self.host) |v| allocator.free(v);
        if (self.origin) |v| allocator.free(v);
        if (self.ws_key) |v| allocator.free(v);
        if (self.ws_version) |v| allocator.free(v);
    }
};

// ============================================================================
// Connections: a reader and a writer thread each
// ============================================================================

pub const Connection = struct {
    server: *Server,
    /// Set by the devtools thread when it lists the connection.
    id: u32,
    transport: Transport,
    outbound: *outbound.Outbound,
    /// How the writer frames a message: set by the devtools thread when a
    /// WebSocket upgrade is accepted, or at once for the pipe.
    mode: std.atomic.Value(Mode) = .init(.http),
    refs: std.atomic.Value(u32) = .init(1),
    /// The devtools thread's: the connection's own session (no sessionId).
    implicit_session: ?*targets.Session = null,

    pub const Transport = union(enum) {
        socket: platform.DevtoolsStream,
        pipe: platform.DevtoolsPipe,
    };

    pub const Mode = enum(u8) { http, websocket, pipe };

    fn create(server: *Server, transport: Transport) !*Connection {
        const self = try server.allocator.create(Connection);
        errdefer server.allocator.destroy(self);
        self.* = .{
            .server = server,
            .id = @atomicRmw(u32, &server.next_connection_id, .Add, 1, .monotonic),
            .transport = transport,
            .outbound = try outbound.Outbound.create(server.allocator),
        };
        return self;
    }

    fn retain(self: *Connection) *Connection {
        _ = self.refs.fetchAdd(1, .monotonic);
        return self;
    }

    fn release(self: *Connection) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        switch (self.transport) {
            .socket => |s| platform.devtoolsClose(s),
            .pipe => |p| {
                platform.devtoolsClose(p.read);
                platform.devtoolsClose(p.write);
            },
        }
        self.outbound.release();
        self.server.allocator.destroy(self);
    }

    /// End both directions: the reader's read returns 0.
    fn shutdown(self: *Connection) void {
        switch (self.transport) {
            .socket => |s| platform.devtoolsShutdown(s),
            .pipe => |p| {
                platform.devtoolsShutdown(p.read);
                platform.devtoolsShutdown(p.write);
            },
        }
    }

    fn startThreads(self: *Connection) !void {
        _ = self.server.live_threads.fetchAdd(2, .acq_rel);
        const reader = platform.spawnThread(.{ .name = .from("devtools-read") }, readerMain, self.retain()) catch |err| {
            self.release();
            self.threadEnded();
            self.threadEnded();
            return err;
        };
        platform.detachThread(reader);
        const writer = platform.spawnThread(.{ .name = .from("devtools-write") }, writerMain, self.retain()) catch |err| {
            self.release();
            self.threadEnded();
            // The reader runs on; shutting down ends it.
            self.shutdown();
            return err;
        };
        platform.detachThread(writer);
    }

    fn threadEnded(self: *Connection) void {
        threadEndedOn(self.server);
    }

    /// A reader or writer of `server` is done with every connection it held
    /// (its last touch of either): Server.stop may go on.
    fn threadEndedOn(server: *Server) void {
        _ = server.live_threads.fetchSub(1, .acq_rel);
        futexIo().futexWake(u32, &server.live_threads.raw, 1);
    }

    fn readStream(self: *Connection) platform.DevtoolsStream {
        return switch (self.transport) {
            .socket => |s| s,
            .pipe => |p| p.read,
        };
    }

    fn writeStream(self: *Connection) platform.DevtoolsStream {
        return switch (self.transport) {
            .socket => |s| s,
            .pipe => |p| p.write,
        };
    }

    fn readerMain(context: ?*anyopaque) callconv(.c) void {
        const self: *Connection = @ptrCast(@alignCast(context.?));
        const server = self.server;
        defer {
            _ = server.postTask(ClosedTask, .{ .connection = self.retain() });
            // The thread's reference goes BEFORE the thread says it ended:
            // Server.stop returns - and frees the server, whose allocator
            // frees a connection - once no reader or writer is live, so a
            // release after that could be the last one, made on a freed
            // server or after the embedder's allocator checked for leaks
            // (lane tpf: the replay tests' DebugAllocator reported the
            // Connection, its Outbound and its queue leaked).
            self.release();
            threadEndedOn(server);
        }
        switch (self.transport) {
            .socket => self.readSocket(),
            .pipe => self.readPipe(),
        }
    }

    /// The HTTP request head; then WebSocket frames if it was an upgrade.
    fn readSocket(self: *Connection) void {
        const allocator = self.server.allocator;
        var head: std.ArrayList(u8) = .empty;
        defer head.deinit(allocator);
        var chunk: [16 * 1024]u8 = undefined;
        var arena_state = std.heap.ArenaAllocator.init(allocator);
        defer arena_state.deinit();
        const request: http.Request = while (true) {
            const n = platform.devtoolsRead(self.readStream(), &chunk) catch return;
            if (n == 0) return;
            head.appendSlice(allocator, chunk[0..n]) catch return;
            switch (http.parseRequest(arena_state.allocator(), head.items) catch return) {
                .incomplete => continue,
                .bad => {
                    const bytes = http.response(allocator, 400, http.text_type, "") catch return;
                    self.outbound.pushRaw(bytes);
                    self.outbound.finish();
                    return self.drain();
                },
                .request => |r| break r,
            }
        };
        const owned = OwnedRequest.from(allocator, &request) catch return;
        const upgrade = owned.upgrade;
        if (!self.server.postTask(HttpTask, .{ .connection = self.retain(), .request = owned })) return;
        if (!upgrade) return self.drain();

        // WebSocket frames, from the bytes after the head on.
        var decoder = ws.Decoder.init(allocator);
        defer decoder.deinit();
        decoder.feed(head.items[request.head_len..]) catch return;
        while (true) {
            while (decoder.next() catch return) |event| {
                switch (event) {
                    .text => |text| {
                        const owned_text = allocator.dupe(u8, text) catch return;
                        if (!self.server.postTask(MessageTask, .{ .connection = self.retain(), .text = owned_text })) return;
                    },
                    // A CDP message is text; Chrome's server takes nothing
                    // else (RFC 6455 7.4.1: 1003 for data it cannot accept).
                    .binary => return self.closeWith(.unsupported_data),
                    .ping => |payload| {
                        const pong = ws.encodeFrame(allocator, .pong, payload) catch return;
                        self.outbound.pushRaw(pong);
                    },
                    .pong => {},
                    // 5.5.1: answer a close with a close, then end.
                    .close => return self.closeWith(.normal),
                    .fail => |code| return self.closeWith(code),
                }
            }
            const n = platform.devtoolsRead(self.readStream(), &chunk) catch return;
            if (n == 0) return;
            decoder.feed(chunk[0..n]) catch return;
        }
    }

    fn closeWith(self: *Connection, code: ws.CloseCode) void {
        const frame = ws.encodeClose(self.server.allocator, code) catch return;
        self.outbound.pushRaw(frame);
        self.outbound.finish();
        self.drain();
    }

    /// Read until the peer or the writer ends the connection.
    fn drain(self: *Connection) void {
        var chunk: [4096]u8 = undefined;
        while (true) {
            const n = platform.devtoolsRead(self.readStream(), &chunk) catch return;
            if (n == 0) return;
        }
    }

    /// --remote-debugging-pipe: messages separated by NUL
    /// (devtools_pipe_handler.cc PipeReader::ReadLoop, kNullCharacter).
    fn readPipe(self: *Connection) void {
        const allocator = self.server.allocator;
        var pending: std.ArrayList(u8) = .empty;
        defer pending.deinit(allocator);
        var chunk: [64 * 1024]u8 = undefined;
        while (true) {
            const n = platform.devtoolsRead(self.readStream(), &chunk) catch return;
            if (n == 0) return;
            var rest = chunk[0..n];
            while (std.mem.indexOfScalar(u8, rest, 0)) |end| {
                pending.appendSlice(allocator, rest[0..end]) catch return;
                const message = pending.toOwnedSlice(allocator) catch return;
                if (!self.server.postTask(MessageTask, .{ .connection = self.retain(), .text = message })) return;
                rest = rest[end + 1 ..];
            }
            pending.appendSlice(allocator, rest) catch return;
            // Chrome's pipe reader caps a message at 256 MiB.
            if (pending.items.len > ws.max_message_bytes) return;
        }
    }

    fn writerMain(context: ?*anyopaque) callconv(.c) void {
        const self: *Connection = @ptrCast(@alignCast(context.?));
        const server = self.server;
        defer {
            // As the reader's: release, then say the thread ended.
            self.release();
            threadEndedOn(server);
        }
        const allocator = self.server.allocator;
        var items: std.ArrayList(outbound.Item) = .empty;
        defer items.deinit(allocator);
        while (true) {
            self.outbound.wait(null);
            items.clearRetainingCapacity();
            const state = self.outbound.takeAll(&items) catch continue;
            var failed = false;
            for (items.items) |item| {
                defer allocator.free(item.bytes);
                if (failed or state.closed) continue;
                self.write(item) catch {
                    failed = true;
                };
            }
            if (failed or state.closed or (state.finishing and items.items.len == 0)) break;
            if (state.finishing) continue;
        }
        // The writer is done: so is the connection.
        self.outbound.close();
        self.shutdown();
    }

    fn write(self: *Connection, item: outbound.Item) !void {
        const stream = self.writeStream();
        switch (item.kind) {
            .raw => try platform.devtoolsWrite(stream, .from(item.bytes)),
            .message => switch (self.mode.load(.acquire)) {
                .websocket => {
                    const frame = try ws.encodeFrame(self.server.allocator, .text, item.bytes);
                    defer self.server.allocator.free(frame);
                    try platform.devtoolsWrite(stream, .from(frame));
                },
                .pipe => {
                    try platform.devtoolsWrite(stream, .from(item.bytes));
                    try platform.devtoolsWrite(stream, .from("\x00"));
                },
                // A message before an upgrade completed: nothing to send it on.
                .http => {},
            },
        }
    }
};
