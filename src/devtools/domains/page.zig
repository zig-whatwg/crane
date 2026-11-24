//! The Page domain on page sessions: frames, navigation, lifecycle events,
//! scripts on new documents, isolated worlds, document content (lane cdph,
//! P4; design 1.2, 1.4 and 3.3).
//!
//! Every command reaches the page through the path a browser has (design
//! 3.1): Page.navigate is HTML navigate with user involvement "browser UI"
//! (Browser.navigateNavigable), reload the browser's reload, close HTML
//! close prompting to unload, setDocumentContent the document's
//! open/write/close steps (Blink Document::SetContent). Events come from
//! the Browser's navigation observer (lane life1's html.navigation.observer)
//! at the spec step, as Blink's InspectorPageAgent probes do
//! (third_party/blink/renderer/core/inspector/inspector_page_agent.cc;
//! reproduced, not copied). Chrome's orders, which the runners depend on,
//! are the measured ones (tmp/plans/cdp1-evidence/seq-vue-e2e-one.txt,
//! seq-svelte.txt):
//! - Page.navigate answers when the navigation is ready to commit, before
//!   frameNavigated (Chrome answers from NavigationRequest's ready-to-commit);
//! - at a cross-document commit: lifecycle "init", executionContextsCleared,
//!   frameNavigated, then executionContextCreated (contexts.zig);
//! - DOMContentLoaded: domContentEventFired, then lifecycle
//!   "DOMContentLoaded"; load: loadEventFired, then lifecycle "load"; then
//!   frameStoppedLoading;
//! - setLifecycleEventsEnabled replays commit, DOMContentLoaded, load,
//!   networkAlmostIdle and networkIdle for each frame's current document
//!   (InspectorPageAgent::setLifecycleEventsEnabled).

const std = @import("std");
const Allocator = std.mem.Allocator;
const engine = @import("engine");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const PageSession = @import("../page_session.zig").PageSession;
const BrowserSide = @import("../browser_side.zig").BrowserSide;
const protocol = @import("../protocol/root.zig");
const Reply = @import("../dispatch.zig").Reply;
const host_bridge = @import("../host_bridge.zig");
const frames = @import("../frames.zig");
const contexts = @import("../contexts.zig");
const idleness = @import("../idleness.zig");
const fetch_observer = @import("../fetch_observer.zig");
const P = protocol.Page;

const log = std.log.scoped(.devtools);

/// Per-session state of the domain.
pub const State = struct {
    enabled: bool = false,
    /// Page.setLifecycleEventsEnabled.
    lifecycle_events: bool = false,
    /// Page.addScriptToEvaluateOnNewDocument's scripts, in the order added.
    scripts: std.ArrayListUnmanaged(Script) = .empty,
    next_script: u64 = 1,
    /// Page.navigate calls waiting for their navigation to be ready to
    /// commit (or to end).
    pending: std.ArrayListUnmanaged(Pending) = .empty,
    /// While this session's Page.navigate runs: same-document navigations
    /// it makes wait here, so its answer goes first (Chrome answers a
    /// fragment navigation before navigatedWithinDocument).
    navigating: bool = false,
    deferred: std.ArrayListUnmanaged(Deferred) = .empty,
};

/// A navigatedWithinDocument held until Page.navigate has answered.
const Deferred = struct {
    navigable: u64,
    /// OWNED.
    url: []u8,
    kind: @import("html").navigation.observer.SameDocumentKind,
};

/// Every frame's network idleness detector for its current document, for
/// the Browser (BrowserSide.idle): Blink keeps one per frame
/// (LocalFrame::GetIdlenessDetector) that starts at the document's
/// DOMContentLoaded whether or not DevTools listens
/// (third_party/blink/renderer/core/loader/idleness_detector.cc, BSD;
/// idleness.zig), so a session that comes later replays what it reached.
/// On the Browser's thread.
pub const IdleFrames = struct {
    entries: std.ArrayListUnmanaged(Idle) = .empty,

    /// The side's end: every armed check cancelled.
    pub fn deinit(self: *IdleFrames, side: *BrowserSide) void {
        for (self.entries.items) |*entry| disarm(side, entry);
        self.entries.deinit(side.allocator);
        self.* = .{};
    }
};

/// One frame's detector, for its current document, and the timer that
/// stands for Blink's next-task check.
const Idle = struct {
    navigable: u64,
    /// The document it started for (by identity and slab generation).
    document: *anyopaque,
    generation: u64,
    detector: idleness.Detector,
    /// The armed check's timer and its ticket (OWNED by the timer while
    /// armed), or 0.
    timer: runtime.TimerId = 0,
    ticket: ?*IdleTicket = null,
};

/// What an idleness timer carries: which Browser's which frame.
const IdleTicket = struct {
    allocator: Allocator,
    side: *BrowserSide,
    navigable: u64,
};

const Script = struct {
    identifier: u64,
    /// OWNED (the session's allocator).
    source: []u8,
    /// OWNED; null: the main world.
    world_name: ?[]u8,
};

const Pending = struct {
    navigation_id: u64,
    navigable: u64,
    reply: Reply(P.navigate),
};

fn state(session: *PageSession) *State {
    return &session.states.Page;
}

/// The session hears each new document of the Browser as it starts
/// (host_events' document_start), to run its new-document scripts there,
/// and each simple dialog as it opens and closes.
pub fn sessionStarted(session: *PageSession) void {
    const browser = session.browser orelse return;
    browser.addListener(documentStartListener(session)) catch {};
}

fn documentStartListener(session: *PageSession) @import("browser").host_events.Listener {
    return .{ .context = session, .on_event = onHostEvent };
}

fn onHostEvent(context: *anyopaque, event: *const @import("browser").host_events.Event) void {
    const session: *PageSession = @ptrCast(@alignCast(context));
    switch (event.*) {
        .document_start => |start| documentStarted(session, start),
        .dialog_opening => |opening| dialogOpening(session, opening),
        .dialog_closed => |closed| dialogClosed(session, closed),
        .window_open => |opened| windowOpened(session, opened),
        .frame_touched => |touched| frameTouched(session, touched.navigable),
        else => {},
    }
}

/// A simple dialog opens in the session's tab: with Page enabled the
/// session hears Page.javascriptDialogOpening and claims the dialog - Chrome
/// then waits for Page.handleJavaScriptDialog (which lane cdpt's devtools
/// thread answers through the dialog's DialogAnswer while this thread is
/// paused; Chrome's PageHandler in the browser process). headless has no
/// browser-side handler (hasBrowserHandler false).
fn dialogOpening(session: *PageSession, opening: *const @import("browser").host_events.DialogOpening) void {
    if (!state(session).enabled or opening.tab != session.tab) return;
    const frame_id = session.frameId(opening.navigable);
    session.emit(P.javascriptDialogOpening, .{
        .url = opening.url,
        .frameId = frame_id.slice(),
        .message = opening.message,
        .type = switch (opening.kind) {
            .alert => .alert,
            .confirm => .confirm,
            .prompt => .prompt,
            .beforeunload => .beforeunload,
        },
        .hasBrowserHandler = false,
        .defaultPrompt = if (opening.kind == .prompt) opening.default_prompt else null,
    });
    opening.claim.* = true;
}

/// The dialog closed, whoever answered: Page.javascriptDialogClosed.
fn dialogClosed(session: *PageSession, closed: *const @import("browser").host_events.DialogClosed) void {
    if (!state(session).enabled or closed.tab != session.tab) return;
    const frame_id = session.frameId(closed.navigable);
    session.emit(P.javascriptDialogClosed, .{
        .frameId = frame_id.slice(),
        .result = closed.accepted,
        .userInput = closed.user_input,
    });
}

/// Script reached a frame of the tab still on its initial about:blank: its
/// main world context is announced now (Blink makes it then:
/// LocalWindowProxy::Initialize -> DidCreateMainWorldContext), by the last
/// session on the tab, as a commit's are (contexts.zig).
fn frameTouched(session: *PageSession, navigable: u64) void {
    if (!frames.inTab(session, navigable) or !contexts.isEdgeSession(session, .last)) return;
    const bc = frames.navigable(session, navigable) orelse return;
    contexts.registerNavigable(session, bc);
}

/// A page of the session's tab asks for a new window, before it is made:
/// Page.windowOpen (Blink's InspectorPageAgent::WindowOpen, from
/// probe::WindowOpen in CreateNewWindow), so it precedes the new tab's
/// Target events. Playwright reads its features for the popup's size.
fn windowOpened(session: *PageSession, opened: *const @import("browser").host_events.WindowOpen) void {
    if (!state(session).enabled or opened.tab != session.tab) return;
    session.emit(P.windowOpen, .{
        .url = opened.url,
        .windowName = opened.name,
        .windowFeatures = opened.features,
        .userGesture = opened.user_gesture,
    });
}

/// A new document of the session's tab is ready for host scripts, before any
/// of its own (Blink's InspectorPageAgent::DidCreateMainWorldContext): the
/// session's new-document scripts run in it, each in its world.
fn documentStarted(session: *PageSession, start: *const @import("browser").host_events.DocumentStart) void {
    if (state(session).scripts.items.len == 0) return;
    if (!frames.inTab(session, start.navigable_id)) return;
    const bc = frames.navigable(session, start.navigable_id) orelse return;
    const realm: runtime.Context = @ptrCast(@alignCast(start.realm));
    runNewDocumentScriptsIn(session, bc, realm);
}

pub fn sessionEnded(session: *PageSession) void {
    if (session.browser) |browser| browser.removeListener(documentStartListener(session));
    const s = state(session);
    for (s.scripts.items) |script| freeScript(session.allocator, script);
    s.scripts.deinit(session.allocator);
    for (s.pending.items) |pending| pending.reply.drop();
    s.pending.deinit(session.allocator);
    for (s.deferred.items) |d| session.allocator.free(d.url);
    s.deferred.deinit(session.allocator);
    s.* = .{};
}

fn freeScript(allocator: Allocator, script: Script) void {
    allocator.free(script.source);
    if (script.world_name) |name| allocator.free(name);
}

// ============================================================================
// Commands
// ============================================================================

pub fn enable(session: *PageSession, params: P.enable.Params) !P.enable.Result {
    _ = params;
    state(session).enabled = true;
    return .{};
}

pub fn disable(session: *PageSession, params: P.disable.Params) !P.disable.Result {
    _ = params;
    const s = state(session);
    s.enabled = false;
    s.lifecycle_events = false;
    return .{};
}

/// The tab's frames (InspectorPageAgent::getFrameTree).
pub fn getFrameTree(session: *PageSession, params: P.getFrameTree.Params, reply: Reply(P.getFrameTree)) !void {
    _ = params;
    const top = frames.navigable(session, session.tab) orelse return session.fail("No frame for given id found");
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    const tree = try frames.tree(session, arena_state.allocator(), top);
    reply.ok(.{ .frameTree = tree });
}

/// Lifecycle events on or off; turned on, each frame's current document's
/// lifecycle so far is replayed (Blink's setLifecycleEventsEnabled: commit,
/// DOMContentLoaded, load, networkAlmostIdle, networkIdle - each that has
/// happened).
pub fn setLifecycleEventsEnabled(session: *PageSession, params: P.setLifecycleEventsEnabled.Params) !P.setLifecycleEventsEnabled.Result {
    state(session).lifecycle_events = params.enabled;
    if (!params.enabled) return .{};
    const top = frames.navigable(session, session.tab) orelse return .{};
    replayLifecycle(session, top);
    return .{};
}

fn replayLifecycle(session: *PageSession, bc: *frames.BrowsingContext) void {
    if (frames.documentOf(bc)) |document| {
        const ready = interfaces.Document.get_readyState(document) catch ._loading_;
        emitLifecycle(session, bc, "commit");
        if (ready != ._loading_) emitLifecycle(session, bc, "DOMContentLoaded");
        if (ready == ._complete_) emitLifecycle(session, bc, "load");
        // The idleness reached so far: Blink's replay reads the frame's
        // IdlenessDetector - GetNetworkAlmostIdleTime / GetNetworkIdleTime,
        // the quiet periods' start times, set as each quiet begins (before
        // its event fires). A document past its DOMContentLoaded with no
        // detector (the remote end came after it) starts one now
        // (IdlenessDetector::StartIfNeeded).
        if (ready != ._loading_) if (session.side) |side| {
            const entry = idleOf(side, bc.id, document) orelse startIdleness(side, bc.id, document);
            if (entry) |e| {
                if (e.detector.quiet_2_start) |at| emitLifecycleAt(session, bc, "networkAlmostIdle", at);
                if (e.detector.quiet_0_start) |at| emitLifecycleAt(session, bc, "networkIdle", at);
            }
        };
    }
    for (bc.children.items) |child| {
        if (child.is_closed or child.active_window == null) continue;
        replayLifecycle(session, child);
    }
}

fn emitLifecycle(session: *PageSession, bc: *frames.BrowsingContext, name: []const u8) void {
    emitLifecycleTimed(session, bc, name, frames.monotonicSeconds());
}

/// A lifecycle event stamped with the monotonic moment `at_ns`.
fn emitLifecycleAt(session: *PageSession, bc: *frames.BrowsingContext, name: []const u8, at_ns: i64) void {
    emitLifecycleTimed(session, bc, name, @as(f64, @floatFromInt(at_ns)) / std.time.ns_per_s);
}

fn emitLifecycleTimed(session: *PageSession, bc: *frames.BrowsingContext, name: []const u8, timestamp: f64) void {
    const frame_id = session.frameId(bc.id);
    const loader = if (frames.of(session.browser.?)) |f| f.loaderOf(bc) else 0;
    const loader_id = frames.loaderToken(session, loader);
    session.emit(P.lifecycleEvent, .{
        .frameId = frame_id.slice(),
        .loaderId = loader_id.slice(),
        .name = name,
        .timestamp = timestamp,
    });
}

// ============================================================================
// Network idleness (idleness.zig, Blink's IdlenessDetector)
// ============================================================================

fn monotonicNs() i64 {
    return @intCast(@import("platform").monotonicNow().ns);
}

fn idleOf(side: *BrowserSide, navigable: u64, document: *runtime.Instance) ?*Idle {
    for (side.idle.entries.items) |*entry| {
        if (entry.navigable != navigable) continue;
        if (entry.document != @as(*anyopaque, @ptrCast(document)) or entry.generation != runtime.SlabAllocator.generationOf(document)) return null;
        return entry;
    }
    return null;
}

/// IdlenessDetector::DomContentLoadedEventFired -> Start: the frame's
/// document has fired DOMContentLoaded; what is in flight now is counted
/// from here (fetch_observer.inFlight: ResourceFetcher::ActiveRequestCount).
fn startIdleness(side: *BrowserSide, navigable: u64, document: *runtime.Instance) ?*Idle {
    stopIdleness(side, navigable);
    const count = fetch_observer.inFlight(side, navigable);
    side.idle.entries.append(side.allocator, .{
        .navigable = navigable,
        .document = document,
        .generation = runtime.SlabAllocator.generationOf(document),
        .detector = idleness.Detector.start(count, monotonicNs()),
    }) catch return null;
    const entry = &side.idle.entries.items[side.idle.entries.items.len - 1];
    schedule(side, entry);
    return entry;
}

/// The frame's detector goes: a new document (IdlenessDetector::
/// WillCommitLoad clears its periods and start times), the frame's end.
fn stopIdleness(side: *BrowserSide, navigable: u64) void {
    for (side.idle.entries.items, 0..) |*entry, i| {
        if (entry.navigable != navigable) continue;
        disarm(side, entry);
        _ = side.idle.entries.swapRemove(i);
        return;
    }
}

/// A milestone of the Browser's navigables, whether or not a session
/// listens (BrowserSide.fanOutNavigation, before the sessions' handlers):
/// each frame's detector starts at its document's DOMContentLoaded and goes
/// with the document (a commit) or the frame.
pub fn onBrowserMilestone(side: *BrowserSide, milestone: *const frames.Milestone) void {
    // A served tab with no session keeps its contexts known, as Chrome's
    // inspector does (contexts.zig onServedCommit).
    contexts.onServedCommit(side, milestone);
    const navigable = milestone.navigable_id;
    noteNavigationInFlight(side, milestone);
    switch (milestone.event) {
        .committed, .navigable_destroyed => stopIdleness(side, navigable),
        .dom_content_loaded => |loaded| {
            const document: *runtime.Instance = @ptrCast(@alignCast(loaded.document.document));
            if (runtime.SlabAllocator.generationOf(document) != loaded.document.generation) return;
            _ = startIdleness(side, navigable, document);
        },
        else => {},
    }
}

/// The Browser's record of the tabs' cross-document navigations in flight
/// (BrowserSide.navigations), whose sessions hold the commands the page
/// answers (held_commands.zig): from a navigation's request start until it
/// commits or ends, or its tab goes. Chrome keeps it on the page's agent
/// host, for its frame only (RenderFrameDevToolsAgentHost::
/// DidStartNavigation returns for another frame tree node's navigation):
/// a frame's navigation holds nothing. When a tab's last one ends, its
/// sessions' held commands go, from a session message of their own
/// (PageSession.scheduleRelease) - after the commit, in the new document.
fn noteNavigationInFlight(side: *BrowserSide, milestone: *const frames.Milestone) void {
    const navigable = milestone.navigable_id;
    const ended = switch (milestone.event) {
        .request_started => {
            if (!isTab(side, navigable)) return;
            side.navigations.begin(side.allocator, navigable, milestone.navigation_id) catch {
                log.warn("out of memory: the commands of tab {d} are not held for its navigation", .{navigable});
            };
            return;
        },
        .committed => milestone.navigation_id != 0 and side.navigations.end(navigable, milestone.navigation_id),
        .aborted => side.navigations.end(navigable, milestone.navigation_id),
        .navigable_destroyed => {
            side.navigations.forget(navigable);
            return;
        },
        else => return,
    };
    if (!ended) return;
    for (side.sessions.items) |session| {
        if (session.tab == navigable) session.scheduleRelease();
    }
}

/// Whether `navigable` is a top-level traversable: a tab.
fn isTab(side: *BrowserSide, navigable: u64) bool {
    const b = side.browser orelse return false;
    const navigables = @import("dom").browser_state.existingNavigablesIn(b.scope) orelse return false;
    const bc = navigables.byId(navigable) orelse return false;
    return bc.parent == null;
}

/// fetch_observer: `navigable`'s count of fetches in flight is `in_flight`
/// (OnWillSendRequest when it rose, OnDidLoadResource when it fell),
/// whether or not a session listens.
pub fn onBrowserNetworkActivity(side: *BrowserSide, navigable: u64, in_flight: u32) void {
    for (side.idle.entries.items) |*entry| {
        if (entry.navigable != navigable) continue;
        entry.detector.moved(in_flight, monotonicNs());
        schedule(side, entry);
        return;
    }
}

/// Arm the check for the detector's next due moment, or none.
fn schedule(side: *BrowserSide, entry: *Idle) void {
    disarm(side, entry);
    const next = entry.detector.nextCheck() orelse return;
    const browser = side.browser orelse return;
    const loop = browser.event_loop orelse return;
    const timers = loop.timerInterface() orelse return;
    const ticket = side.allocator.create(IdleTicket) catch return;
    ticket.* = .{ .allocator = side.allocator, .side = side, .navigable = entry.navigable };
    const wait_ns = @max(next - monotonicNs(), 0);
    const wait_ms: u64 = @intCast(@divFloor(wait_ns + std.time.ns_per_ms - 1, std.time.ns_per_ms));
    const id = timers.setTimeoutOwned(wait_ms, idleCheck, ticket, dropTicket);
    if (id == 0) {
        side.allocator.destroy(ticket);
        return;
    }
    entry.timer = id;
    entry.ticket = ticket;
}

/// Cancel the detector's armed check. The Browser's thread is the timer's:
/// a check cannot be running while this runs.
fn disarm(side: *BrowserSide, entry: *Idle) void {
    if (entry.timer == 0) return;
    const ticket = entry.ticket;
    const cancelled = blk: {
        const browser = side.browser orelse break :blk false;
        const loop = browser.event_loop orelse break :blk false;
        const timers = loop.timerInterface() orelse break :blk false;
        break :blk timers.clearTimeout(entry.timer);
    };
    if (cancelled) if (ticket) |t| t.allocator.destroy(t);
    entry.timer = 0;
    entry.ticket = null;
}

fn dropTicket(data: ?*anyopaque) void {
    const ticket: *IdleTicket = @ptrCast(@alignCast(data orelse return));
    ticket.allocator.destroy(ticket);
}

/// The check (Blink's WillProcessTask): what is due fires, stamped with its
/// quiet period's start, to every session on the frame's tab with lifecycle
/// events on (LocalFrame::NetworkBecameAlmostIdle -> the page agents).
fn idleCheck(data: ?*anyopaque) void {
    const ticket: *IdleTicket = @ptrCast(@alignCast(data orelse return));
    const side = ticket.side;
    const navigable = ticket.navigable;
    ticket.allocator.destroy(ticket);
    for (side.idle.entries.items) |*entry| {
        if (entry.navigable != navigable) continue;
        entry.timer = 0;
        entry.ticket = null;
        const due = entry.detector.check(monotonicNs());
        if (due.almost_idle != null or due.idle != null) {
            // A session's emit cannot detach it: walk the list as it is.
            for (side.sessions.items) |session| {
                if (!state(session).lifecycle_events or !frames.inTab(session, navigable)) continue;
                const bc = frames.navigable(session, navigable) orelse continue;
                if (due.almost_idle) |at| emitLifecycleAt(session, bc, "networkAlmostIdle", at);
                if (due.idle) |at| emitLifecycleAt(session, bc, "networkIdle", at);
            }
        }
        schedule(side, entry);
        return;
    }
}

/// A script to run in every new document of the tab, in its main world or
/// in the world `worldName` (made for each document that needs it), before
/// any of the document's own scripts (Blink's InspectorPageAgent::
/// DidCreateMainWorldContext); `runImmediately` also runs it now in each
/// frame's current document.
pub fn addScriptToEvaluateOnNewDocument(session: *PageSession, params: P.addScriptToEvaluateOnNewDocument.Params, reply: Reply(P.addScriptToEvaluateOnNewDocument)) !void {
    const s = state(session);
    const source = try session.allocator.dupe(u8, params.source);
    errdefer session.allocator.free(source);
    const world_name: ?[]u8 = if (params.worldName) |name| (if (name.len > 0) try session.allocator.dupe(u8, name) else null) else null;
    errdefer if (world_name) |name| session.allocator.free(name);
    const identifier = s.next_script;
    try s.scripts.append(session.allocator, .{ .identifier = identifier, .source = source, .world_name = world_name });
    s.next_script += 1;
    var buffer: [24]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "{d}", .{identifier}) catch unreachable;
    reply.ok(.{ .identifier = text });
    if (params.runImmediately orelse false) {
        if (frames.navigable(session, session.tab)) |top| runScriptInTree(session, top, s.scripts.items[s.scripts.items.len - 1]);
    }
}

pub fn removeScriptToEvaluateOnNewDocument(session: *PageSession, params: P.removeScriptToEvaluateOnNewDocument.Params) !P.removeScriptToEvaluateOnNewDocument.Result {
    const s = state(session);
    const identifier = std.fmt.parseInt(u64, params.identifier, 10) catch return session.fail("Script not found");
    for (s.scripts.items, 0..) |script, i| {
        if (script.identifier != identifier) continue;
        freeScript(session.allocator, s.scripts.orderedRemove(i));
        return .{};
    }
    return session.fail("Script not found");
}

/// The frame's world named `worldName` - made the first time the name is
/// asked for in the frame, kept across its navigations (Blink's
/// InspectorPageAgent::EnsureDOMWrapperWorld; browser.isolated_worlds) -
/// realized for the frame's current document, and its execution context id.
pub fn createIsolatedWorld(session: *PageSession, params: P.createIsolatedWorld.Params) !P.createIsolatedWorld.Result {
    const bc = frames.frameNamed(session, params.frameId) orelse return session.fail("No frame for given id found");
    const main = frames.mainRealmOf(bc) orelse return session.fail("No frame for given id found");
    // A session targeting a frame on its initial about:blank: its main world
    // is announced first, if it was not (a lazy context, as Blink's).
    if (bc.inspector_pending) {
        bc.inspector_pending = false;
        _ = contexts.register(session, main, bc);
    }
    const realm = worldRealm(main, bc.id, params.worldName orelse "", params.grantUniveralAccess orelse false) catch
        return session.fail("Could not create isolated world");
    const id = contexts.register(session, realm, bc) orelse return session.fail("Could not create isolated world");
    return .{ .executionContextId = id };
}

/// The world realm of `main`'s Window named `name` (browser.isolated_worlds).
fn worldRealm(main: runtime.Context, navigable: u64, name: []const u8, universal_access: bool) !runtime.Context {
    const browser_mod = @import("browser");
    if (comptime !@hasDecl(browser_mod, "isolated_worlds")) return error.NotSupported;
    return browser_mod.isolated_worlds.createIsolatedWorld(main, navigable, name, universal_access);
}

/// HTML navigate the frame (the tab's main frame by default) as the
/// browser's UI does, answered when the navigation is ready to commit: its
/// loaderId, or errorText for a navigation that fails, isDownload for one
/// handed to a download; at once, with no loaderId, for a navigation that
/// stays in the document (Chrome's same-document navigation).
pub fn navigate(session: *PageSession, params: P.navigate.Params, reply: Reply(P.navigate)) !void {
    const browser = session.browser orelse return session.fail("No frame for given id found");
    const bc = frames.frameNamed(session, params.frameId) orelse return session.fail("No frame with given id found");
    const navigable = bc.id;
    const s = state(session);
    // A same-document navigation's events wait until the answer has gone.
    s.navigating = true;
    defer {
        s.navigating = false;
        flushDeferred(session);
    }
    const navigation_id = browser.navigateNavigable(navigable, params.url, .{
        .referrer = params.referrer,
        .referrer_policy = referrerPolicyOf(params.referrerPolicy),
    }) catch |err| switch (err) {
        error.InvalidUrl => return session.fail("Cannot navigate to invalid URL"),
        error.NoSuchTab => return session.fail("No frame with given id found"),
        else => return err,
    };
    const frame_id = session.frameId(navigable);
    if (navigation_id == 0) {
        reply.ok(.{ .frameId = frame_id.slice() });
        return;
    }
    try s.pending.append(session.allocator, .{ .navigation_id = navigation_id, .navigable = navigable, .reply = reply });
}

/// The navigatedWithinDocument events a Page.navigate held, after its answer.
fn flushDeferred(session: *PageSession) void {
    const s = state(session);
    for (s.deferred.items) |d| {
        defer session.allocator.free(d.url);
        if (s.enabled) emitWithinDocument(session, d.navigable, d.url, d.kind);
    }
    s.deferred.clearRetainingCapacity();
}

fn emitWithinDocument(session: *PageSession, navigable: u64, url: []const u8, kind: @import("html").navigation.observer.SameDocumentKind) void {
    const frame_id = session.frameId(navigable);
    session.emit(P.navigatedWithinDocument, .{
        .frameId = frame_id.slice(),
        .url = url,
        .navigationType = switch (kind) {
            .fragment => .fragment,
            .push, .replace, .traverse => .historyApi,
            .intercept => .other,
        },
    });
}

/// CDP's ReferrerPolicy as Fetch's.
fn referrerPolicyOf(policy: ?P.ReferrerPolicy) @import("fetch").internal.ReferrerPolicy {
    const given = policy orelse return .empty;
    return switch (given) {
        .noReferrer => .no_referrer,
        .noReferrerWhenDowngrade => .no_referrer_when_downgrade,
        .origin => .origin,
        .originWhenCrossOrigin => .origin_when_cross_origin,
        .sameOrigin => .same_origin,
        .strictOrigin => .strict_origin,
        .strictOriginWhenCrossOrigin => .strict_origin_when_cross_origin,
        .unsafeUrl => .unsafe_url,
    };
}

/// HTML "reload" of the tab as the browser's reload button does.
pub fn reload(session: *PageSession, params: P.reload.Params) !P.reload.Result {
    _ = params;
    const browser = session.browser orelse return session.fail("Not attached to an active page");
    browser.reloadTraversable(session.tab) catch return session.fail("Not attached to an active page");
    return .{};
}

/// Chrome's PageHandler::GetNavigationHistory
/// (content/browser/devtools/protocol/page_handler.cc): the tab's
/// NavigationController entries - here, each step of the traversable's
/// joint session history with the browser's record of it
/// (Browser.navigationHistory; joint_history.NavigationEntryRecord) - and
/// the current one's index.
pub fn getNavigationHistory(session: *PageSession, params: P.getNavigationHistory.Params) !P.getNavigationHistory.Result {
    _ = params;
    const browser = session.browser orelse return session.fail("Not attached to an active page");
    const arena = session.arena.?;
    const history = browser.navigationHistory(session.tab, arena) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return session.fail("Not attached to an active page"),
    };
    const entries = try arena.alloc(P.NavigationEntry, history.entries.len);
    for (history.entries, entries) |e, *out| out.* = .{
        .id = @intCast(e.id),
        .url = e.url,
        .userTypedURL = e.user_typed_url,
        .title = e.title,
        .transitionType = switch (e.transition) {
            .link => .link,
            .typed => .typed,
            .auto_toplevel => .auto_toplevel,
            .form_submit => .form_submit,
            .reload => .reload,
        },
    };
    return .{ .currentIndex = @intCast(history.current), .entries = entries };
}

/// Chrome's PageHandler::NavigateToHistoryEntry: the entry with that id,
/// gone to as NavigationController::GoToIndex goes - the browser's own
/// back/forward, HTML "traverse the history by a delta" by the difference
/// of the two indexes (Browser.traverseHistoryByDelta); InvalidParams "No
/// entry with passed id" when the tab has none.
pub fn navigateToHistoryEntry(session: *PageSession, params: P.navigateToHistoryEntry.Params) !P.navigateToHistoryEntry.Result {
    const browser = session.browser orelse return session.fail("Not attached to an active page");
    const arena = session.arena.?;
    const history = browser.navigationHistory(session.tab, arena) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return session.fail("Not attached to an active page"),
    };
    for (history.entries, 0..) |e, index| {
        if (@as(i64, @intCast(e.id)) != params.entryId) continue;
        const delta: i32 = @intCast(@as(i64, @intCast(index)) - @as(i64, @intCast(history.current)));
        // The current entry: Chrome's NavigateToExistingPendingEntry drops
        // a back/forward navigation to the last committed entry (and stops
        // loading - Crane has no browser-UI stop yet: TODO(mcp1) when one
        // lands); the answer is success.
        if (delta == 0) return .{};
        _ = browser.traverseHistoryByDelta(session.tab, delta) catch return session.fail("Not attached to an active page");
        return .{};
    }
    return session.failWithCode(.invalid_params, "No entry with passed id");
}

/// Chrome's PageHandler::ResetNavigationHistory: every entry but the
/// committed one goes (NavigationController::PruneAllButLastCommitted;
/// Browser.pruneNavigationHistory), or "History cannot be pruned" when it
/// cannot now.
pub fn resetNavigationHistory(session: *PageSession, params: P.resetNavigationHistory.Params) !P.resetNavigationHistory.Result {
    _ = params;
    const browser = session.browser orelse return session.fail("Not attached to an active page");
    const pruned = browser.pruneNavigationHistory(session.tab) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return session.fail("Not attached to an active page"),
    };
    if (!pruned) return session.fail("History cannot be pruned");
    return .{};
}

/// Close the tab, prompting to unload (Chrome: Page.close runs beforeunload,
/// where Target.closeTarget does not).
pub fn close(session: *PageSession, params: P.close.Params) !P.close.Result {
    _ = params;
    const browser = session.browser orelse return .{};
    host_bridge.closeTab(browser, session.tab, true) catch |err| switch (err) {
        error.CloseCanceled => {},
        else => return err,
    };
    return .{};
}

pub fn bringToFront(session: *PageSession, params: P.bringToFront.Params) !P.bringToFront.Result {
    _ = params;
    const browser = session.browser orelse return .{};
    host_bridge.activateTab(browser, session.tab) catch {};
    return .{};
}

/// Replace the frame's document's content: document.open(), write(html),
/// close() on it, in its realm (Blink's Document::SetContent, which the
/// DevTools agent calls for setDocumentContent).
pub fn setDocumentContent(session: *PageSession, params: P.setDocumentContent.Params) !P.setDocumentContent.Result {
    const bc = frames.frameNamed(session, params.frameId) orelse return session.fail("No frame for given id found");
    const document = frames.documentOf(bc) orelse return session.fail("No Document instance to set HTML for");
    var call: SetContent = .{ .document = document, .html = params.html };
    engine.runInRealm(document.ctx, SetContent.steps, &call) catch return session.fail("No Document instance to set HTML for");
    if (call.failed) return session.fail("No Document instance to set HTML for");
    return .{};
}

const SetContent = struct {
    document: *runtime.Instance,
    html: []const u8,
    failed: bool = false,

    fn steps(data: ?*anyopaque) void {
        const self: *SetContent = @ptrCast(@alignCast(data.?));
        const Document = interfaces.Document;
        // open()'s two optional arguments, not passed; write()'s one string.
        const OptString = @typeInfo(@TypeOf(Document.call_open)).@"fn".param_types[1].?;
        const WriteText = @typeInfo(@typeInfo(@TypeOf(Document.call_write)).@"fn".param_types[1].?).pointer.child;
        _ = Document.call_open(self.document, OptString.notPassed(), OptString.notPassed()) catch {
            self.failed = true;
            return;
        };
        const text = [_]WriteText{.{ .domstring = runtime.DOMString.initInterned(self.html) }};
        Document.call_write(self.document, &text) catch {
            self.failed = true;
        };
        Document.call_close(self.document) catch {
            self.failed = true;
        };
    }
};

/// Fonts are the renderer's: with none there is no font family to set
/// (acknowledged, design 1.4 "A"; Playwright sends it only for a UA naming
/// "Headless").
pub fn setFontFamilies(session: *PageSession, params: P.setFontFamilies.Params) !P.setFontFamilies.Result {
    _ = session;
    _ = params;
    return .{};
}

pub fn setFontSizes(session: *PageSession, params: P.setFontSizes.Params) !P.setFontSizes.Result {
    _ = session;
    _ = params;
    return .{};
}

/// The viewports, from the tab's viewport (life1's browser/viewport.zig -
/// the platform's window or an Emulation override). With no layout, the
/// content is the viewport.
pub fn getLayoutMetrics(session: *PageSession, params: P.getLayoutMetrics.Params) !P.getLayoutMetrics.Result {
    _ = params;
    const bc = frames.navigable(session, session.tab) orelse return session.fail("No frame for given id found");
    const size = bc.traversableViewport() orelse frames.ViewportSize{ .width = 0, .height = 0 };
    const width: i64 = @intCast(size.width);
    const height: i64 = @intCast(size.height);
    const w: f64 = @floatFromInt(size.width);
    const h: f64 = @floatFromInt(size.height);
    const layout: P.LayoutViewport = .{ .pageX = 0, .pageY = 0, .clientWidth = width, .clientHeight = height };
    const visual: P.VisualViewport = .{ .offsetX = 0, .offsetY = 0, .pageX = 0, .pageY = 0, .clientWidth = w, .clientHeight = h, .scale = 1, .zoom = 1 };
    const content: protocol.DOM.Rect = .{ .x = 0, .y = 0, .width = w, .height = h };
    return .{ .layoutViewport = layout, .visualViewport = visual, .contentSize = content, .cssLayoutViewport = layout, .cssVisualViewport = visual, .cssContentSize = content };
}

/// Pixels are a renderer's: with none there is no frame to capture (design
/// 1.4 "U": answered as Chrome answers when it has no compositor frame).
pub fn captureScreenshot(session: *PageSession, params: P.captureScreenshot.Params) !P.captureScreenshot.Result {
    _ = params;
    return session.fail("Unable to capture screenshot");
}

pub fn startScreencast(session: *PageSession, params: P.startScreencast.Params) !P.startScreencast.Result {
    _ = params;
    return session.fail("Screencast is not supported without a renderer");
}

/// Nothing to stop or acknowledge with no screencast running.
pub fn stopScreencast(session: *PageSession, params: P.stopScreencast.Params) !P.stopScreencast.Result {
    _ = session;
    _ = params;
    return .{};
}

pub fn screencastFrameAck(session: *PageSession, params: P.screencastFrameAck.Params) !P.screencastFrameAck.Result {
    _ = session;
    _ = params;
    return .{};
}

// ============================================================================
// The navigation observer's milestones
// ============================================================================

pub fn onNavigation(session: *PageSession, milestone: *const frames.Milestone) void {
    const navigable = milestone.navigable_id;
    const s = state(session);
    switch (milestone.event) {
        // Settled replies first: they need no frame to exist any more.
        .ready_to_commit => |ready| return answerPending(session, milestone.navigation_id, ready.outcome, ready.error_text),
        .aborted => return answerPending(session, milestone.navigation_id, .network_error, "net::ERR_ABORTED"),
        .navigable_destroyed => {
            if (frames.of(session.browser.?)) |f| f.forget(navigable);
            if (s.enabled and navigable != session.tab and frames.inTab(session, navigable)) {
                const frame_id = session.frameId(navigable);
                session.emit(P.frameDetached, .{ .frameId = frame_id.slice(), .reason = .remove });
            }
            return;
        },
        // A child navigable is made before its initial about:blank, so it
        // has no Window yet for frames.inTab to find: its parent says
        // whether it is in the session's tab.
        .navigable_created => |created| {
            const parent = created.parent_id orelse return;
            if (!s.enabled or !frames.inTab(session, parent)) return;
            const frame_id = session.frameId(navigable);
            const parent_id = session.frameId(parent);
            session.emit(P.frameAttached, .{ .frameId = frame_id.slice(), .parentFrameId = parent_id.slice() });
            return;
        },
        else => {},
    }
    if (!frames.inTab(session, navigable)) return;
    const frame_id = session.frameId(navigable);
    switch (milestone.event) {
        .navigable_created => unreachable,
        .started => |started| if (s.enabled) {
            const loader_id = frames.loaderToken(session, milestone.navigation_id);
            // A frame's first navigation away from its initial about:blank
            // is Chrome's kInitialFrameNavigation (an iframe's src as it is
            // inserted: HTMLFrameOwnerElement::LoadOrRedirectSubframe).
            const initial_frame = navigable != session.tab and if (frames.navigable(session, navigable)) |bc| (if (frames.documentOf(bc)) |document| @import("dom").document_lifecycle.isInitialAboutBlank(document) else true) else false;
            if (started.initiator == .document) session.emit(P.frameRequestedNavigation, .{
                .frameId = frame_id.slice(),
                .reason = if (initial_frame) .initialFrameNavigation else .scriptInitiated,
                .url = started.url,
                .disposition = .currentTab,
            });
            session.emit(P.frameStartedNavigating, .{
                .frameId = frame_id.slice(),
                .url = started.url,
                .loaderId = loader_id.slice(),
                .navigationType = .differentDocument,
            });
            session.emit(P.frameStartedLoading, .{ .frameId = frame_id.slice() });
        },
        .committed => |committed| {
            if (frames.of(session.browser.?)) |f| f.noteCommitted(navigable, committed.document.document, committed.document.generation, milestone.navigation_id);
            const bc = frames.navigable(session, navigable) orelse return;
            // Chrome's order (its Puppeteer log, lane cdpr): lifecycle
            // "init" for every session of the tab, then the tab's contexts
            // cleared (contexts.zig), then each session's frameNavigated -
            // the first session does the first two for all.
            if (contexts.isEdgeSession(session, .first)) {
                if (session.side) |side| for (side.sessions.items) |other| {
                    if (other.tab == session.tab and state(other).lifecycle_events) emitLifecycle(other, bc, "init");
                };
                contexts.beforeCommit(session, navigable, &.{});
            }
            // A child's initial about:blank (no navigation made it): Chrome
            // sends its lifecycle init and no frameNavigated (lane cdpr's
            // vue-e2e-browser log l.392-405).
            const initial_child = milestone.navigation_id == 0 and navigable != session.tab;
            // Its context waits for the first script to reach it
            // (BrowsingContext.touchedByScript) or a session to target it.
            if (initial_child) bc.inspector_pending = true;
            if (s.enabled and !initial_child) {
                var arena_state = std.heap.ArenaAllocator.init(session.allocator);
                defer arena_state.deinit();
                const frame = frames.describe(session, arena_state.allocator(), bc) catch return;
                session.emit(P.frameNavigated, .{ .frame = frame, .type = .Navigation });
            }
        },
        .same_document => |same| if (s.enabled) {
            if (s.navigating) {
                // This session's Page.navigate made it: after its answer.
                const url = session.allocator.dupe(u8, same.url) catch return;
                s.deferred.append(session.allocator, .{ .navigable = navigable, .url = url, .kind = same.kind }) catch session.allocator.free(url);
                return;
            }
            emitWithinDocument(session, navigable, same.url, same.kind);
        },
        .dom_content_loaded => {
            const bc = frames.navigable(session, navigable) orelse return;
            if (s.enabled and navigable == session.tab) session.emit(P.domContentEventFired, .{ .timestamp = frames.monotonicSeconds() });
            if (s.lifecycle_events) emitLifecycle(session, bc, "DOMContentLoaded");
            // (IdlenessDetector::DomContentLoadedEventFired: the frame's
            // detector started before the sessions heard it,
            // onBrowserMilestone.)
        },
        .load => {
            const bc = frames.navigable(session, navigable) orelse return;
            if (s.enabled and navigable == session.tab) session.emit(P.loadEventFired, .{ .timestamp = frames.monotonicSeconds() });
            if (s.lifecycle_events) emitLifecycle(session, bc, "load");
        },
        .stopped_loading => if (s.enabled) session.emit(P.frameStoppedLoading, .{ .frameId = frame_id.slice() }),
        // document.open(): InspectorPageAgent::DidOpenDocument -
        // documentOpened with the frame as it now is, then lifecycle init.
        .document_opened => {
            const bc = frames.navigable(session, navigable) orelse return;
            if (s.enabled) {
                var arena_state = std.heap.ArenaAllocator.init(session.allocator);
                defer arena_state.deinit();
                const frame = frames.describe(session, arena_state.allocator(), bc) catch return;
                session.emit(P.documentOpened, .{ .frame = frame });
            }
            if (s.lifecycle_events) emitLifecycle(session, bc, "init");
        },
        else => {},
    }
}

/// Answer the Page.navigate waiting for navigation `navigation_id`, if any.
fn answerPending(session: *PageSession, navigation_id: u64, outcome: @import("html").navigation.observer.ReadyOutcome, error_text: []const u8) void {
    if (navigation_id == 0) return;
    const s = state(session);
    var i: usize = 0;
    while (i < s.pending.items.len) {
        const pending = s.pending.items[i];
        if (pending.navigation_id != navigation_id) {
            i += 1;
            continue;
        }
        _ = s.pending.orderedRemove(i);
        const frame_id = session.frameId(pending.navigable);
        const loader_id = frames.loaderToken(session, navigation_id);
        switch (outcome) {
            // isDownload always present, as Chrome's PageHandler::Navigate
            // answers.
            .document => pending.reply.ok(.{ .frameId = frame_id.slice(), .loaderId = loader_id.slice(), .isDownload = false }),
            .network_error => pending.reply.ok(.{ .frameId = frame_id.slice(), .loaderId = loader_id.slice(), .errorText = if (error_text.len > 0) error_text else "net::ERR_FAILED", .isDownload = false }),
            // A 204/205: no document, the navigation ends without one.
            .no_document => pending.reply.ok(.{ .frameId = frame_id.slice(), .loaderId = loader_id.slice(), .errorText = "net::ERR_ABORTED", .isDownload = false }),
            .download => pending.reply.ok(.{ .frameId = frame_id.slice(), .loaderId = loader_id.slice(), .errorText = "net::ERR_ABORTED", .isDownload = true }),
        }
    }
}

// ============================================================================
// Scripts on new documents (html.navigation.document_start, after the
// commit's contexts were registered by the Runtime glue)
// ============================================================================

/// Run the session's new-document scripts in the document whose main world
/// realm is `main`, each in its world.
fn runNewDocumentScriptsIn(session: *PageSession, bc: *frames.BrowsingContext, main: runtime.Context) void {
    for (state(session).scripts.items) |script| runScript(session, bc, main, script);
}

fn runScriptInTree(session: *PageSession, bc: *frames.BrowsingContext, script: Script) void {
    if (frames.mainRealmOf(bc)) |main| runScript(session, bc, main, script);
    for (bc.children.items) |child| {
        if (child.is_closed or child.active_window == null) continue;
        runScriptInTree(session, child, script);
    }
}

fn runScript(session: *PageSession, bc: *frames.BrowsingContext, main: runtime.Context, script: Script) void {
    const realm = if (script.world_name) |name| blk: {
        // With universal access, as InspectorPageAgent::
        // EvaluateScriptOnNewDocument asks EnsureDOMWrapperWorld(frame,
        // world_name, /*grant_universal_access=*/true).
        const made = worldRealm(main, bc.id, name, true) catch |err| {
            log.debug("the world '{s}' of a new-document script was not made: {}", .{ name, err });
            return;
        };
        _ = contexts.register(session, made, bc);
        break :blk made;
    } else main;
    // An empty source only asks for the world (Playwright's utility world).
    if (script.source.len == 0) return;
    engine.runClassicScript(realm, .{ .utf8 = script.source }, "", null, .{ .report = reportToPage, .host = frames.windowOf(bc) }) catch {};
}

/// What a new-document script throws is the page's to report, as for any
/// of its scripts (HTML "report an exception"; Chrome reports it to the
/// console as uncaught).
fn reportToPage(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const window: *runtime.Instance = @ptrCast(@alignCast(host orelse return));
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
        // The realm whose script threw: a world's new-document script's
        // exception is that world's, and fires no error event at the page
        // (engine section 4.2a; lane cdpw's world-scoped error events).
        .realm = info.realm,
    };
    _ = @import("html").report_exception.reportErrorInfo(window, &extracted, .{});
}
