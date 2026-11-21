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

    pub fn getWindowForTarget(session: *Session, params: B.getWindowForTarget.Params) !B.getWindowForTarget.Result {
        const target = try targetOrOwn(session, params.targetId);
        return .{ .windowId = target.window_id, .bounds = bounds(target.window) };
    }

    pub fn getWindowBounds(session: *Session, params: B.getWindowBounds.Params) !B.getWindowBounds.Result {
        const target = windowTarget(session, params.windowId) orelse return session.fail("Browser window not found");
        return .{ .bounds = bounds(target.window) };
    }

    /// The tab's window rect: the platform's window_rect_changed for its
    /// tab (viewport.zig: a headless window's rect IS its viewport), as a
    /// window manager's resize reaches a page.
    pub fn setWindowBounds(session: *Session, params: B.setWindowBounds.Params) !B.setWindowBounds.Result {
        const target = windowTarget(session, params.windowId) orelse return session.fail("Browser window not found");
        const b = params.bounds;
        // browser_handler.cc SetWindowBounds: a state other than normal
        // takes no position or size.
        if (b.windowState) |state| if (state != .normal and (b.left != null or b.top != null or b.width != null or b.height != null)) {
            return session.failWithCode(.invalid_params, "The 'minimized', 'maximized' and 'fullscreen' states cannot be combined with 'left', 'top', 'width' or 'height'");
        };
        var w = &target.window;
        if (b.left) |v| w.left = v;
        if (b.top) |v| w.top = v;
        if (b.width) |v| w.width = v;
        if (b.height) |v| w.height = v;
        if (b.windowState) |v| w.state = v;
        if (target.partner) |p| p.window = w.*;
        WindowRectTask.post(target.context.side, target.tab, w.*);
        return .{};
    }

    fn windowTarget(session: *Session, window_id: i64) ?*targets.Target {
        for (serverOf(session).target_list.items) |t| if (t.window_id == window_id and t.type == .page) return t;
        return null;
    }

    fn bounds(w: targets.WindowBounds) B.Bounds {
        return .{ .left = w.left, .top = w.top, .width = w.width, .height = w.height, .windowState = w.state };
    }
};

/// Browser thread: a tab's window rect changed (Browser.setWindowBounds).
const WindowRectTask = struct {
    side: *browser_side.BrowserSide,
    tab: host_bridge.TabId,
    rect: targets.WindowBounds,

    fn post(side: *browser_side.BrowserSide, tab: host_bridge.TabId, rect: targets.WindowBounds) void {
        const task = side.allocator.create(WindowRectTask) catch return;
        task.* = .{ .side = side, .tab = tab, .rect = rect };
        _ = side.host.post(task, run, drop);
    }

    fn run(context: ?*anyopaque, b: *host_bridge.Browser) void {
        const task: *WindowRectTask = @ptrCast(@alignCast(context.?));
        defer task.side.allocator.destroy(task);
        const browser = @import("browser");
        browser.viewport.windowRectChanged(b.scope, task.tab, .{
            .x = @floatFromInt(task.rect.left),
            .y = @floatFromInt(task.rect.top),
            .width = @floatFromInt(task.rect.width),
            .height = @floatFromInt(task.rect.height),
        });
    }

    fn drop(context: ?*anyopaque) void {
        const task: *WindowRectTask = @ptrCast(@alignCast(context.?));
        task.side.allocator.destroy(task);
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
            .tab => if (session.target) |tab| if (tab.partner) |page| {
                if (session.auto_attach.filter.matches(.page) and !alreadyAttachedBy(server, session, page)) {
                    _ = try server.attach(session, page, params.waitForDebuggerOnStart and session.waiting);
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
        if (params.proxyServer) |proxy| {
            config.proxy = proxyConfig(proxy, params.proxyBypassList) orelse return session.failWithCode(.invalid_params, "Invalid proxy server");
        }
        const host = host_bridge.BrowserHost.start(server.allocator, config) catch |err| {
            log.warn("devtools: a browser context could not start: {t}", .{err});
            return session.fail("Failed to create browser context");
        };
        const context = server.addContext(host, true) catch |err| {
            host.stop();
            return err;
        };
        if (params.disposeOnDetach orelse false) context.dispose_with = session.connection_id;
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

    fn proxyConfig(proxy: []const u8, bypass: ?[]const u8) ?host_bridge.BrowserConfig.Proxy {
        _ = bypass;
        // TODO(cdpt): BrowserConfig.Proxy.manual from a proxyServer string
        // ("http=foo:80;https=bar:80" or "foo:80") once NetworkContext's
        // Manual takes a parsed list; until then only "direct://".
        if (std.mem.eql(u8, proxy, "direct://")) return .direct;
        return null;
    }
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
