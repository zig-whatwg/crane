//! The domains the devtools thread serves: Browser and Target for every
//! session, Security for the browser target, and Runtime's one command a
//! tab target answers (tmp/plans/cdp-part1-design.md 3.2).
//!
//! Chromium's browser-side handlers are the model (content/browser/devtools/
//! protocol/target_handler.cc, browser_handler.cc, security_handler.cc;
//! BSD-3): commands are answered from the target registry and the host API,
//! never by reaching into a page. Each function follows dispatch.zig's
//! handler interface; error messages are Chrome's.

const std = @import("std");
const protocol = @import("protocol/root.zig");
const dispatch = @import("dispatch.zig");
const ids = @import("ids.zig");
const targets = @import("targets.zig");
const host_bridge = @import("host_bridge.zig");
const browser_side = @import("browser_side.zig");
const server_mod = @import("server.zig");
const Server = server_mod.Server;
const Session = targets.Session;
const Reply = dispatch.Reply;

const log = std.log.scoped(.devtools);

/// dispatch.zig's handler set for the devtools thread.
pub const Handlers = struct {
    pub const Browser = BrowserDomain;
    pub const Target = TargetDomain;
    pub const Security = SecurityDomain;
    pub const Runtime = RuntimeDomain;
};

fn serverOf(session: *Session) *Server {
    return @ptrCast(@alignCast(session.server));
}

/// The target `target_id` names, or the session's own.
fn targetOrOwn(session: *Session, target_id: ?[]const u8) !*targets.Target {
    const server = serverOf(session);
    if (target_id) |id| return server.findTarget(id) orelse session.fail("No target with given id found");
    return session.target orelse session.fail("No target with given id found");
}

// ============================================================================
// Browser
// ============================================================================

const B = protocol.Browser;

pub const BrowserDomain = struct {
    /// Decision D4 (the user, 2026-11-21): product "Crane/0.1", Crane's own
    /// user agent.
    pub fn getVersion(session: *Session, _: B.getVersion.Params) !B.getVersion.Result {
        const options = &serverOf(session).options;
        return .{
            .protocolVersion = protocol.protocol_version,
            .product = options.product,
            .revision = options.revision,
            .userAgent = options.user_agent,
            .jsVersion = options.js_version,
        };
    }

    /// Answered, then the embedder ends (browser_handler.cc Close: replies,
    /// then closes every window and exits).
    pub fn close(session: *Session, _: B.close.Params, reply: Reply(B.close)) !void {
        reply.ok(.{});
        serverOf(session).requestClose();
    }

    /// Per browser context: what HTML's download steps do with a response
    /// handed to external software. Recorded for the context; `eventsEnabled`
    /// (Browser.downloadWillBegin/downloadProgress) is part 2.
    pub fn setDownloadBehavior(session: *Session, params: B.setDownloadBehavior.Params) !B.setDownloadBehavior.Result {
        const server = serverOf(session);
        const context = server.findContext(params.browserContextId) orelse return session.fail("Failed to find browser context for id");
        if (params.behavior == .allow or params.behavior == .allowAndName) {
            if (params.downloadPath == null) return session.failWithCode(.invalid_params, "downloadPath not provided");
        }
        context.download_behavior = params.behavior;
        if (context.download_path) |p| server.allocator.free(p);
        context.download_path = if (params.downloadPath) |p| try server.allocator.dupe(u8, p) else null;
        return .{};
    }

    /// The target's window (BrowserHandler::GetWindowForTarget): its id, and
    /// its bounds as its tab keeps them (browser.viewport.windowBounds - the
    /// rect and state the platform, Browser.setWindowBounds or moveTo set),
    /// read on the tab's Browser thread.
    pub fn getWindowForTarget(session: *Session, params: B.getWindowForTarget.Params, reply: Reply(B.getWindowForTarget)) !void {
        const target = try targetOrOwn(session, params.targetId);
        try WindowTask.post(target, .{ .get_for_target = reply }, .{});
    }

    pub fn getWindowBounds(session: *Session, params: B.getWindowBounds.Params, reply: Reply(B.getWindowBounds)) !void {
        const target = windowTarget(session, params.windowId) orelse return session.fail("Browser window not found");
        try WindowTask.post(target, .{ .get_bounds = reply }, .{});
    }

    /// The tab's window rect and state, as Chrome's
    /// BrowserHandler::SetWindowBounds changes them (browser.viewport
    /// .setWindowBounds: restore, move/resize, minimize/maximize/
    /// fullscreen), on the tab's Browser thread; the viewport follows (a
    /// headless window's rect IS its viewport).
    pub fn setWindowBounds(session: *Session, params: B.setWindowBounds.Params, reply: Reply(B.setWindowBounds)) !void {
        const target = windowTarget(session, params.windowId) orelse return session.fail("Browser window not found");
        const b = params.bounds;
        // browser_handler.cc SetWindowBounds: a state other than normal
        // takes no position or size.
        if (b.windowState) |state| if (state != .normal and (b.left != null or b.top != null or b.width != null or b.height != null)) {
            return session.failWithCode(.invalid_params, "The 'minimized', 'maximized' and 'fullscreen' states cannot be combined with 'left', 'top', 'width' or 'height'");
        };
        try WindowTask.post(target, .{ .set = reply }, .{
            .x = narrow(b.left),
            .y = narrow(b.top),
            .width = narrow(b.width),
            .height = narrow(b.height),
            .state = if (b.windowState) |state| switch (state) {
                .normal => .normal,
                .minimized => .minimized,
                .maximized => .maximized,
                .fullscreen => .fullscreen,
            } else null,
        });
    }

    fn narrow(value: ?i64) ?i32 {
        const v = value orelse return null;
        return @intCast(std.math.clamp(v, std.math.minInt(i32), std.math.maxInt(i32)));
    }

    fn windowTarget(session: *Session, window_id: i64) ?*targets.Target {
        for (serverOf(session).target_list.items) |t| if (t.window_id == window_id and t.type == .page) return t;
        return null;
    }
};

/// Browser thread: a Browser.* window command for a tab - its bounds read,
/// or changed - answered from there.
const WindowTask = struct {
    side: *browser_side.BrowserSide,
    tab: host_bridge.TabId,
    window_id: i64,
    change: viewport.WindowChange,
    reply: Answer,

    const viewport = @import("browser").viewport;

    const Answer = union(enum) {
        get_for_target: Reply(B.getWindowForTarget),
        get_bounds: Reply(B.getWindowBounds),
        set: Reply(B.setWindowBounds),
    };

    fn post(target: *targets.Target, reply: Answer, change: viewport.WindowChange) !void {
        const side = target.context.side;
        const task = try side.allocator.create(WindowTask);
        errdefer side.allocator.destroy(task);
        task.* = .{ .side = side, .tab = target.tab, .window_id = target.window_id, .change = change, .reply = reply };
        if (!side.host.post(task, run, drop)) return error.BrowserGone;
    }

    fn run(context: ?*anyopaque, b: *host_bridge.Browser) void {
        const task: *WindowTask = @ptrCast(@alignCast(context.?));
        defer task.side.allocator.destroy(task);
        switch (task.reply) {
            .get_for_target => |reply| {
                const window = viewport.windowBounds(b.scope, task.tab) orelse return reply.fail(.server_error, "Browser window not found");
                reply.ok(.{ .windowId = task.window_id, .bounds = boundsOf(window) });
            },
            .get_bounds => |reply| {
                const window = viewport.windowBounds(b.scope, task.tab) orelse return reply.fail(.server_error, "Browser window not found");
                reply.ok(.{ .bounds = boundsOf(window) });
            },
            .set => |reply| {
                viewport.setWindowBounds(b.scope, task.tab, task.change) catch |err| return switch (err) {
                    error.NoSuchTab => reply.fail(.server_error, "Browser window not found"),
                    error.NotNormal => reply.fail(.server_error, "To resize minimized/maximized/fullscreen window, restore it to normal state first."),
                };
                reply.ok(.{});
            },
        }
    }

    fn drop(context: ?*anyopaque) void {
        const task: *WindowTask = @ptrCast(@alignCast(context.?));
        switch (task.reply) {
            inline else => |reply| reply.fail(.server_error, "Browser window not found"),
        }
        task.side.allocator.destroy(task);
    }

    fn boundsOf(window: viewport.WindowBounds) B.Bounds {
        return .{
            .left = window.rect.x,
            .top = window.rect.y,
            .width = window.rect.width,
            .height = window.rect.height,
            .windowState = switch (window.state) {
                .normal => .normal,
                .minimized => .minimized,
                .maximized => .maximized,
                .fullscreen => .fullscreen,
            },
        };
    }
};

// ============================================================================
// Target
// ============================================================================

const T = protocol.Target;

pub const TargetDomain = struct {
    /// TargetHandler::SetDiscoverTargets: on, every existing target matching
    /// the filter is announced at once (tab targets first), then every
    /// creation, change and destruction.
    pub fn setDiscoverTargets(session: *Session, params: T.setDiscoverTargets.Params) !T.setDiscoverTargets.Result {
        const server = serverOf(session);
        if (session.discover) |*f| f.deinit(server.allocator);
        session.discover = null;
        if (!params.discover) return .{};
        session.discover = try targets.Filter.fromParams(server.allocator, params.filter);
        for (server.target_list.items) |t| {
            if (session.discover.?.matches(t.type)) session.emit(T.targetCreated, .{ .targetInfo = targets.targetInfo(t) });
        }
        return .{};
    }

    /// TargetHandler::SetAutoAttach. On a browser session: the targets its
    /// filter takes are attached - the existing ones now, not waiting, and
    /// every new one as it comes, waiting when waitForDebuggerOnStart. On a
    /// tab session: its page child. On a page session: nothing to attach -
    /// a tab's frames run in its agent and workers are not targets yet
    /// (decision D10) - but the settings are kept.
    pub fn setAutoAttach(session: *Session, params: T.setAutoAttach.Params) !T.setAutoAttach.Result {
        const server = serverOf(session);
        session.auto_attach.filter.deinit(server.allocator);
        session.auto_attach = .{
            .enabled = params.autoAttach,
            .wait_for_debugger = params.waitForDebuggerOnStart,
            .filter = try targets.Filter.fromParams(server.allocator, params.filter),
        };
        // Popups start held while some browser session waits for new
        // targets (every context's Browser hears it).
        server.updatePopupHolds();
        if (!params.autoAttach) return .{};
        switch (session.kind) {
            .browser => {
                // Existing targets (Chrome reports them not waiting: they
                // have already started).
                var i: usize = 0;
                while (i < server.target_list.items.len) : (i += 1) {
                    const t = server.target_list.items[i];
                    if (!session.auto_attach.filter.matches(t.type)) continue;
                    if (alreadyAttachedBy(server, session, t)) continue;
                    _ = server.attach(session, t, false) catch continue;
                }
            },
            // The page child is reported NOT waiting: the wait is the tab
            // session's, whose runIfWaitingForDebugger releases the tab
            // (Chrome, vue-e2e protocol log: the tab attachedToTarget
            // waitingForDebugger true, its page child false - lane cdpr's G1).
            .tab => if (session.target) |tab| if (tab.partner) |page| {
                if (session.auto_attach.filter.matches(.page) and !alreadyAttachedBy(server, session, page)) {
                    _ = try server.attach(session, page, false);
                }
            },
            .page => {},
        }
        return .{};
    }

    fn alreadyAttachedBy(server: *Server, parent: *Session, target: *targets.Target) bool {
        for (server.sessions.items) |s| if (s.parent == parent and s.target == target) return true;
        return false;
    }

    pub fn getTargetInfo(session: *Session, params: T.getTargetInfo.Params) !T.getTargetInfo.Result {
        const server = serverOf(session);
        if (params.targetId == null and session.target == null) {
            // The browser target (TargetHandler::GetTargetInfo with no id
            // on the browser session).
            return .{ .targetInfo = .{
                .targetId = server.browser_id.slice(),
                .type = "browser",
                .title = "",
                .url = "",
                .attached = true,
                .canAccessOpener = false,
            } };
        }
        const target = try targetOrOwn(session, params.targetId);
        return .{ .targetInfo = targets.targetInfo(target) };
    }

    pub fn getTargets(session: *Session, params: T.getTargets.Params) !T.getTargets.Result {
        const server = serverOf(session);
        const arena = session.arena.?;
        var filter = try targets.Filter.fromParams(arena, params.filter);
        var infos: std.ArrayList(T.TargetInfo) = .empty;
        for (server.target_list.items) |t| {
            if (filter.matches(t.type)) try infos.append(arena, targets.targetInfo(t));
        }
        _ = &filter;
        return .{ .targetInfos = infos.items };
    }

    /// TargetHandler::CreateTarget: a host-opened tab in its own browsing
    /// context group (HTML "create a new top-level traversable"), held when
    /// a session will report it waiting, then navigated to `url`. Answered
    /// once the tab exists - after its targetCreated and attachedToTarget,
    /// as in Chrome.
    pub fn createTarget(session: *Session, params: T.createTarget.Params, reply: Reply(T.createTarget)) !void {
        const server = serverOf(session);
        const context = server.findContext(params.browserContextId) orelse return session.fail("Failed to find browser context with id");
        const url = if (params.url.len == 0) "about:blank" else params.url;
        try CreateTabTask.post(server, context, url, params.background orelse false, server.wouldWait(context), reply);
    }

    /// Closed without prompting to unload (Chrome: WebContents::ClosePage
    /// ignores beforeunload for DevTools); answered at once, the
    /// targetDestroyed follows.
    pub fn closeTarget(session: *Session, params: T.closeTarget.Params) !T.closeTarget.Result {
        const server = serverOf(session);
        const target = server.findTarget(params.targetId) orelse return session.failWithCode(.invalid_params, "No target with given id found");
        CloseTabTask.post(target.context.side, target.tab);
        return .{ .success = true };
    }

    pub fn activateTarget(session: *Session, params: T.activateTarget.Params) !T.activateTarget.Result {
        const server = serverOf(session);
        const target = server.findTarget(params.targetId) orelse return session.failWithCode(.invalid_params, "No target with given id found");
        ActivateTabTask.post(target.context.side, target.tab);
        return .{};
    }

    /// TargetHandler::AttachToTarget, flat (`flatten` false is the
    /// deprecated sendMessageToTarget mode: refused).
    pub fn attachToTarget(session: *Session, params: T.attachToTarget.Params) !T.attachToTarget.Result {
        const server = serverOf(session);
        if (!(params.flatten orelse false)) return session.fail("Only flatten mode is supported");
        const target = server.findTarget(params.targetId) orelse return session.failWithCode(.invalid_params, "No target with given id found");
        const attached = try server.attach(session, target, false);
        return .{ .sessionId = attached.id.slice() };
    }

    /// A second browser session on this connection (Vitest's `cdp()`).
    pub fn attachToBrowserTarget(session: *Session, _: T.attachToBrowserTarget.Params) !T.attachToBrowserTarget.Result {
        const server = serverOf(session);
        const attached = try server.attachBrowserSession(session);
        return .{ .sessionId = attached.id.slice() };
    }

    pub fn detachFromTarget(session: *Session, params: T.detachFromTarget.Params) !T.detachFromTarget.Result {
        const server = serverOf(session);
        const victim = blk: {
            if (params.sessionId) |id| break :blk server.findSession(session.connection_id, id);
            if (params.targetId) |id| {
                for (server.sessions.items) |s| {
                    if (s.connection_id == session.connection_id and !s.implicit and s.target != null and s.target.?.id.eql(id)) break :blk s;
                }
            }
            break :blk null;
        } orelse return session.fail("No session with given id");
        server.detach(victim, true);
        return .{};
    }

    /// TargetHandler::CreateBrowserContext: a new Browser on its own thread
    /// ("two instances share nothing", docs/instances.md), with the proxy
    /// asked for.
    pub fn createBrowserContext(session: *Session, params: T.createBrowserContext.Params) !T.createBrowserContext.Result {
        const server = serverOf(session);
        var config = server.options.context_config;
        // An off-the-record context: it never opens the user data directory
        // (Chrome: TargetHandler::CreateBrowserContext makes its contexts
        // with DevToolsBrowserContextManager::CreateBrowserContext - an
        // off-the-record Profile of the original, chrome/browser/devtools/
        // devtools_browser_context_manager.cc). The console started with
        // --user-data-dir hands a config whose profile directory the default
        // Browser holds: a second Browser on it failed with ProfileInUse
        // (lane cdpr's G18), and would have shared its state.
        config.profile_dir = null;
        // The context's proxy (TargetHandler::CreateBrowserContext: a
        // net::ProxyConfig whose proxy_rules() parse proxyServer and whose
        // bypass rules parse proxyBypassList - ProxyRules::ParseFromString,
        // ProxyBypassRules::ParseFromString, which skip what they cannot
        // read). The Browser's network context keeps its own copy.
        var rules: ?ProxyRules = null;
        defer if (rules) |*r| r.deinit();
        if (params.proxyServer) |proxy| {
            rules = try ProxyRules.parse(server.allocator, proxy, params.proxyBypassList orelse "");
            config.proxy = .{ .rules = &rules.? };
        }
        const host = host_bridge.BrowserHost.start(server.allocator, config) catch |err| {
            log.warn("devtools: a browser context could not start: {t}", .{err});
            return session.fail("Failed to create browser context");
        };
        // A new context has no tab until the client makes one (Chrome:
        // TargetHandler::CreateBrowserContext makes an off-the-record profile
        // with no window - Playwright's newContext, then its createTarget):
        // the Browser's own first page closes before the context is known,
        // so no target of it is ever reported (lane tpg: cdpt_targets'
        // Playwright launch read that page's attachedToTarget for the one it
        // created). A Browser lives on with its first page closed (its agent
        // keeps its isolate entered: protocol_agents createAgent).
        const CloseFirstPage = struct {
            fn run(_: ?*anyopaque, b: *host_bridge.Browser) void {
                const first = b.hostTraversableId() orelse return;
                b.closeTab(first, .{}) catch |err| log.warn("devtools: a new context's first page did not close: {t}", .{err});
            }
        };
        host.call(null, CloseFirstPage.run) catch {};
        const context = server.addContext(host, true) catch |err| {
            host.stop();
            return err;
        };
        if (params.disposeOnDetach orelse false) context.dispose_with = session.connection_id;
        server.updatePopupHolds();
        return .{ .browserContextId = context.id.slice() };
    }

    pub fn disposeBrowserContext(session: *Session, params: T.disposeBrowserContext.Params) !T.disposeBrowserContext.Result {
        const server = serverOf(session);
        const context = server.findContext(params.browserContextId) orelse return session.fail("Failed to find context with id");
        if (!context.owned) return session.fail("Default context cannot be disposed");
        server.disposeContext(context);
        return .{};
    }

    pub fn getBrowserContexts(session: *Session, _: T.getBrowserContexts.Params) !T.getBrowserContexts.Result {
        const server = serverOf(session);
        var list: std.ArrayList([]const u8) = .empty;
        for (server.contexts.items) |c| if (c.owned and !c.disposed) try list.append(session.arena.?, c.id.slice());
        return .{ .browserContextIds = list.items, .defaultBrowserContextId = server.default_context.?.id.slice() };
    }

    /// Kept for TargetHandler compatibility: remote locations are for
    /// remote targets, which Crane has none of.
    pub fn setRemoteLocations(_: *Session, _: T.setRemoteLocations.Params) !T.setRemoteLocations.Result {
        return .{};
    }

    const ProxyRules = @import("fetch").network.NetworkContext.ProxyRules;
};

// ============================================================================
// Security (the browser target's: every context)
// ============================================================================

const S = protocol.Security;

pub const SecurityDomain = struct {
    /// security_handler.cc SetIgnoreCertificateErrors on the browser
    /// target: every Browser's network context (NetworkContext
    /// accept_insecure_certs) from now on.
    pub fn setIgnoreCertificateErrors(session: *Session, params: S.setIgnoreCertificateErrors.Params) !S.setIgnoreCertificateErrors.Result {
        const server = serverOf(session);
        for (server.contexts.items) |c| {
            if (!c.disposed) @import("domains/security.zig").InsecureCertsTask.post(c.side, params.ignore);
        }
        return .{};
    }

    pub fn enable(_: *Session, _: S.enable.Params) !S.enable.Result {
        return .{};
    }

    pub fn disable(_: *Session, _: S.disable.Params) !S.disable.Result {
        return .{};
    }
};

// ============================================================================
// Runtime on a tab target
// ============================================================================

pub const RuntimeDomain = struct {
    /// A tab session was told its target waits for the debugger: this
    /// session is done waiting (the hold goes when every waiting session
    /// has run).
    pub fn runIfWaitingForDebugger(session: *Session, _: protocol.Runtime.runIfWaitingForDebugger.Params) !protocol.Runtime.runIfWaitingForDebugger.Result {
        const server = serverOf(session);
        if (session.waiting) {
            session.waiting = false;
            if (session.target) |t| {
                // A tab target's waiting is its page's.
                const page = if (t.type == .tab) (t.partner orelse t) else t;
                server.doneWaiting(page, session.id);
            }
        }
        return .{};
    }
};

// ============================================================================
// Tasks on the Browser thread
// ============================================================================

const CreateTabTask = struct {
    server: *Server,
    side: *browser_side.BrowserSide,
    url: []u8,
    background: bool,
    hold: bool,
    reply: Reply(T.createTarget),

    fn post(server: *Server, context: *targets.Context, url: []const u8, background: bool, hold: bool, reply: Reply(T.createTarget)) !void {
        const side = context.side;
        const task = try side.allocator.create(CreateTabTask);
        errdefer side.allocator.destroy(task);
        task.* = .{ .server = server, .side = side, .url = try side.allocator.dupe(u8, url), .background = background, .hold = hold, .reply = reply };
        if (!side.host.post(task, run, drop)) return error.BrowserGone;
    }

    fn run(context: ?*anyopaque, b: *host_bridge.Browser) void {
        const task: *CreateTabTask = @ptrCast(@alignCast(context.?));
        const result = host_bridge.createTab(b, .{ .url = task.url, .background = task.background, .hold_first_navigation = task.hold });
        // The tab's host event (tab_created) reached the devtools thread's
        // inbox inside createTab: the answer goes after it.
        _ = task.server.postTask(CreatedTab, .{ .side = task.side, .reply = task.reply, .tab = result catch null, .held = task.hold });
        task.side.allocator.free(task.url);
        task.side.allocator.destroy(task);
    }

    fn drop(context: ?*anyopaque) void {
        const task: *CreateTabTask = @ptrCast(@alignCast(context.?));
        task.reply.fail(.server_error, "Failed to open a new tab");
        task.side.allocator.free(task.url);
        task.side.allocator.destroy(task);
    }
};

/// Devtools thread: Target.createTarget's answer.
const CreatedTab = struct {
    side: *browser_side.BrowserSide,
    reply: Reply(T.createTarget),
    tab: ?host_bridge.TabId,
    held: bool,

    pub fn run(self: *CreatedTab, server: *Server) void {
        const tab = self.tab orelse return self.reply.fail(.server_error, "Failed to open a new tab");
        var id_buffer: [32]u8 = undefined;
        const id = ids.frameId(self.side.token, tab);
        @memcpy(&id_buffer, id.slice());
        _ = server;
        self.reply.ok(.{ .targetId = &id_buffer });
    }

    pub fn drop(self: *CreatedTab, _: std.mem.Allocator) void {
        self.reply.drop();
    }
};

const CloseTabTask = struct {
    side: *browser_side.BrowserSide,
    tab: host_bridge.TabId,

    fn post(side: *browser_side.BrowserSide, tab: host_bridge.TabId) void {
        const task = side.allocator.create(CloseTabTask) catch return;
        task.* = .{ .side = side, .tab = tab };
        _ = side.host.post(task, run, drop);
    }

    fn run(context: ?*anyopaque, b: *host_bridge.Browser) void {
        const task: *CloseTabTask = @ptrCast(@alignCast(context.?));
        defer task.side.allocator.destroy(task);
        host_bridge.closeTab(b, task.tab, false) catch |err| log.warn("devtools: closing tab {d}: {t}", .{ task.tab, err });
    }

    fn drop(context: ?*anyopaque) void {
        const task: *CloseTabTask = @ptrCast(@alignCast(context.?));
        task.side.allocator.destroy(task);
    }
};

const ActivateTabTask = struct {
    side: *browser_side.BrowserSide,
    tab: host_bridge.TabId,

    fn post(side: *browser_side.BrowserSide, tab: host_bridge.TabId) void {
        const task = side.allocator.create(ActivateTabTask) catch return;
        task.* = .{ .side = side, .tab = tab };
        _ = side.host.post(task, run, drop);
    }

    fn run(context: ?*anyopaque, b: *host_bridge.Browser) void {
        const task: *ActivateTabTask = @ptrCast(@alignCast(context.?));
        defer task.side.allocator.destroy(task);
        host_bridge.activateTab(b, task.tab) catch {};
    }

    fn drop(context: ?*anyopaque) void {
        const task: *ActivateTabTask = @ptrCast(@alignCast(context.?));
        task.side.allocator.destroy(task);
    }
};
