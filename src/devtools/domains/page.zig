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
//! - at a cross-document commit: executionContextsCleared, lifecycle "init",
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
const protocol = @import("../protocol/root.zig");
const Reply = @import("../dispatch.zig").Reply;
const host_bridge = @import("../host_bridge.zig");
const frames = @import("../frames.zig");
const contexts = @import("../contexts.zig");
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
        if (ready == ._complete_) {
            emitLifecycle(session, bc, "load");
            // TODO(cdpt P5): networkAlmostIdle/networkIdle from the
            // document's fetch group's in-flight counts (Blink's
            // IdlenessDetector); a loaded document with none in flight is
            // idle, which is what the counts will say for a page at rest.
            emitLifecycle(session, bc, "networkAlmostIdle");
            emitLifecycle(session, bc, "networkIdle");
        }
    }
    for (bc.children.items) |child| {
        if (child.is_closed or child.active_window == null) continue;
        replayLifecycle(session, child);
    }
}

fn emitLifecycle(session: *PageSession, bc: *frames.BrowsingContext, name: []const u8) void {
    const frame_id = session.frameId(bc.id);
    const loader = if (frames.of(session.browser.?)) |f| f.loaderOf(bc) else 0;
    const loader_id = frames.loaderToken(session, loader);
    session.emit(P.lifecycleEvent, .{
        .frameId = frame_id.slice(),
        .loaderId = loader_id.slice(),
        .name = name,
        .timestamp = frames.monotonicSeconds(),
    });
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
    try state(session).pending.append(session.allocator, .{ .navigation_id = navigation_id, .navigable = navigable, .reply = reply });
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
        else => {},
    }
    if (!frames.inTab(session, navigable)) return;
    const frame_id = session.frameId(navigable);
    switch (milestone.event) {
        .navigable_created => |created| if (created.parent_id) |parent| {
            if (s.enabled) {
                const parent_id = session.frameId(parent);
                session.emit(P.frameAttached, .{ .frameId = frame_id.slice(), .parentFrameId = parent_id.slice() });
            }
        },
        .started => |started| if (s.enabled) {
            const loader_id = frames.loaderToken(session, milestone.navigation_id);
            if (started.initiator == .document) session.emit(P.frameRequestedNavigation, .{
                .frameId = frame_id.slice(),
                .reason = .scriptInitiated,
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
            // The tab's contexts cleared before any session's Page events
            // (contexts.zig: Chrome's order) - by the first session only.
            if (contexts.isEdgeSession(session, .first)) contexts.beforeCommit(session, navigable, &.{});
            const bc = frames.navigable(session, navigable) orelse return;
            if (s.lifecycle_events) emitLifecycle(session, bc, "init");
            if (s.enabled) {
                var arena_state = std.heap.ArenaAllocator.init(session.allocator);
                defer arena_state.deinit();
                const frame = frames.describe(session, arena_state.allocator(), bc) catch return;
                session.emit(P.frameNavigated, .{ .frame = frame, .type = .Navigation });
            }
        },
        .same_document => |same| if (s.enabled) {
            session.emit(P.navigatedWithinDocument, .{
                .frameId = frame_id.slice(),
                .url = same.url,
                .navigationType = switch (same.kind) {
                    .fragment => .fragment,
                    .push, .replace, .traverse => .historyApi,
                    .intercept => .other,
                },
            });
        },
        .dom_content_loaded => {
            const bc = frames.navigable(session, navigable) orelse return;
            if (s.enabled and navigable == session.tab) session.emit(P.domContentEventFired, .{ .timestamp = frames.monotonicSeconds() });
            if (s.lifecycle_events) emitLifecycle(session, bc, "DOMContentLoaded");
        },
        .load => {
            const bc = frames.navigable(session, navigable) orelse return;
            if (s.enabled and navigable == session.tab) session.emit(P.loadEventFired, .{ .timestamp = frames.monotonicSeconds() });
            if (s.lifecycle_events) emitLifecycle(session, bc, "load");
        },
        .stopped_loading => if (s.enabled) session.emit(P.frameStoppedLoading, .{ .frameId = frame_id.slice() }),
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
            .document => pending.reply.ok(.{ .frameId = frame_id.slice(), .loaderId = loader_id.slice() }),
            .network_error => pending.reply.ok(.{ .frameId = frame_id.slice(), .loaderId = loader_id.slice(), .errorText = if (error_text.len > 0) error_text else "net::ERR_FAILED" }),
            // A 204/205: no document, the navigation ends without one.
            .no_document => pending.reply.ok(.{ .frameId = frame_id.slice(), .loaderId = loader_id.slice(), .errorText = "net::ERR_ABORTED" }),
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
        const made = worldRealm(main, bc.id, name, false) catch |err| {
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
