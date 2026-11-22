//! The page side's execution contexts: when the realms of a tab's documents
//! - main world and isolated worlds, frames included - are made known to the
//! engine's inspector, and with what (lane cdph, P4; the inspector bridge
//! itself is lane cdpw's, through the engine protocol's inspector operations,
//! capability inspector_protocol - user ruling D3, 2026-11-21).
//!
//! Chrome's order at a cross-document commit, which the runners depend on
//! (tmp/plans/cdp1-evidence/seq-vue-e2e-one.txt; design 1.2):
//! `Runtime.executionContextsCleared`, `Page.lifecycleEvent` init,
//! `Page.frameNavigated`, then `Runtime.executionContextCreated` for the
//! main world and for each world. Blink: MainThreadDebugger::
//! DidClearContextsForFrame (resetContextGroup) as the old document goes,
//! InspectorPageAgent's frameNavigated in DidCommitLoad, and
//! LocalWindowProxy::Initialize -> MainThreadDebugger::ContextCreated as the
//! new document's main world context is made. A Crane realm is made BEFORE
//! its document commits (HTML "create and initialize a Document object"
//! step 7), so registering realms as they are made would put
//! executionContextCreated before executionContextsCleared - and Playwright
//! drops a context its frame's clear arrives after. So the host registers at
//! commit: the first session on the tab resets the group before the Page
//! events (`beforeCommit`), the last registers the new realms after them
//! (`afterCommit`).
//!
//! The inspector's groups are tabs (Blink: one per local root frame): a
//! session sees its tab's realms. auxData is Chrome's:
//! {"isDefault":..,"type":"default"|"isolated","frameId":".."}.
//!
//! Until the engine has the inspector operations (lane cdpw), everything
//! here compiles to nothing.

const std = @import("std");
const Allocator = std.mem.Allocator;
const engine = @import("engine");
const runtime = @import("runtime");
const browser_mod = @import("browser");
const frames = @import("frames.zig");
const PageSession = @import("page_session.zig").PageSession;

/// Whether the engine protocol has the inspector operations yet, and the
/// engine supports them.
pub const have_inspector = @hasDecl(engine, "inspectorContextCreated") and @hasDecl(engine, "inspectorResetGroup") and
    @hasDecl(engine, "inspectorContextId") and inspectorSupported();

fn inspectorSupported() bool {
    return if (@hasField(engine.Capabilities, "inspector_protocol")) @field(engine.capabilities, "inspector_protocol") != .unsupported else false;
}

/// The inspector group of tab `tab`.
pub fn groupOf(tab: u64) u64 {
    return tab;
}

/// A world realm's name, when the engine has worlds; "" for the main world.
fn worldNameOf(realm: runtime.Context) ?[]const u8 {
    if (comptime !@hasDecl(engine, "worldInfoOf")) return null;
    const info = engine.worldInfoOf(realm) orelse return null;
    return info.name;
}

/// Register `realm` - `bc`'s main world, or one of its world realms - with
/// the inspector, unless it is already. Its execution context id, or null.
pub fn register(session: *const PageSession, realm: runtime.Context, bc: *frames.BrowsingContext) ?i64 {
    if (comptime have_inspector) return registerLive(session, realm, bc);
    return null;
}

/// `register` with the engine's inspector operations (lane cdpw's bridge):
/// analysed only when the engine protocol has them.
fn registerLive(session: *const PageSession, realm: runtime.Context, bc: *frames.BrowsingContext) ?i64 {
    return registerWithToken(session.side.?.token, realm, bc);
}

/// `registerLive` for a Browser whose devtools token is `token` (ids.zig:
/// the first half of its frame ids).
fn registerWithToken(token: u64, realm: runtime.Context, bc: *frames.BrowsingContext) ?i64 {
    if (engine.inspectorContextId(realm)) |id| return id;
    var buffer: [512]u8 = undefined;
    var arena_state = std.heap.FixedBufferAllocator.init(&buffer);
    const arena = arena_state.allocator();
    const world_name = worldNameOf(realm);
    const is_default = world_name == null;
    const frame_id = @import("ids.zig").frameId(token, bc.id);
    const aux = std.fmt.allocPrint(arena, "{{\"isDefault\":{},\"type\":\"{s}\",\"frameId\":\"{s}\"}}", .{
        is_default, if (is_default) "default" else "isolated", frame_id.slice(),
    }) catch return null;
    var origin_buffer: [256]u8 = undefined;
    const origin = originOf(bc, &origin_buffer);
    return engine.inspectorContextCreated(&.{
        .realm = realm,
        .group = groupOf(bc.getTop().id),
        .name = world_name orelse "",
        .origin = origin,
        .aux_data = aux,
        .is_default = is_default,
    }) catch null;
}

fn originOf(bc: *frames.BrowsingContext, buffer: []u8) []const u8 {
    const window = frames.windowOf(bc) orelse return "";
    const text = @import("interfaces").Window.get_origin(window) catch return "";
    defer window.ctx.allocator.free(text);
    // Chrome gives an opaque origin as "://".
    if (std.mem.eql(u8, text, "null")) return "://";
    const n = @min(text.len, buffer.len);
    @memcpy(buffer[0..n], text[0..n]);
    return buffer[0..n];
}

/// Every live realm of `bc` and its frames - main worlds and world realms -
/// made known to the inspector (Runtime.enable replays what is known, so it
/// asks this first).
pub fn registerTree(session: *const PageSession, bc: *frames.BrowsingContext) void {
    if (comptime have_inspector) return registerTreeLive(session, bc);
    return;
}

/// `registerTree` with the engine's inspector operations (lane cdpw's bridge):
/// analysed only when the engine protocol has them.
fn registerTreeLive(session: *const PageSession, bc: *frames.BrowsingContext) void {
    registerNavigable(session, bc);
    for (bc.children.items) |child| {
        if (child.is_closed or child.active_window == null) continue;
        registerTree(session, child);
    }
}

/// `bc`'s main world realm, then its world realms, made known.
pub fn registerNavigable(session: *const PageSession, bc: *frames.BrowsingContext) void {
    if (comptime have_inspector) return registerNavigableLive(session, bc);
    return;
}

/// `registerNavigable` with the engine's inspector operations (lane cdpw's bridge):
/// analysed only when the engine protocol has them.
fn registerNavigableLive(session: *const PageSession, bc: *frames.BrowsingContext) void {
    const main = frames.mainRealmOf(bc) orelse return;
    _ = register(session, main, bc);
    if (comptime @hasDecl(engine, "worldRealmsOf")) {
        var worlds: [16]runtime.Context = undefined;
        const count = @min(engine.worldRealmsOf(main, &worlds), worlds.len);
        for (worlds[0..count]) |world| _ = register(session, world, bc);
    }
}

/// A cross-document commit in navigable `navigable` of the session's tab,
/// before its Page events: a top-level one clears the tab's contexts
/// (`Runtime.executionContextsCleared` to every session of the tab); a
/// frame's forgets the frame's old realms (executionContextDestroyed for
/// each) - Blink's DidClearContextsForFrame. Asked by the FIRST session on
/// the tab only.
pub fn beforeCommit(session: *const PageSession, navigable: u64, old_realms: []const runtime.Context) void {
    if (comptime have_inspector) return beforeCommitLive(session, navigable, old_realms);
    return;
}

/// `beforeCommit` with the engine's inspector operations (lane cdpw's bridge):
/// analysed only when the engine protocol has them.
fn beforeCommitLive(session: *const PageSession, navigable: u64, old_realms: []const runtime.Context) void {
    const browser = session.browser orelse return;
    const agent = browser.agent orelse return;
    if (navigable == session.tab) {
        engine.inspectorResetGroup(agent, groupOf(session.tab));
        return;
    }
    if (comptime @hasDecl(engine, "inspectorContextDestroyed")) {
        for (old_realms) |realm| engine.inspectorContextDestroyed(realm);
    }
}

/// The same commit after every session's Page events: the new document's
/// realms made known (`Runtime.executionContextCreated`). Asked by the LAST
/// session on the tab only.
pub fn afterCommit(session: *const PageSession, bc: *frames.BrowsingContext) void {
    registerNavigable(session, bc);
}

/// Whether `session` is the first (`first`) or the last attached session on
/// its tab, in the order milestones reach them (BrowserSide's fan-out
/// order).
pub fn isEdgeSession(session: *const PageSession, comptime which: enum { first, last }) bool {
    const side = session.side orelse return true;
    var seen_first = false;
    var last: ?*const PageSession = null;
    for (side.sessions.items) |s| {
        if (s.tab != session.tab) continue;
        if (!seen_first) {
            seen_first = true;
            if (which == .first) return s == session;
        }
        last = s;
    }
    return last == session;
}

// ============================================================================
// World realms made on demand (the engine's world observer)
// ============================================================================

/// What the page side keeps per Browser to register world realms as they
/// are made: a world realm can be made without anything of CDP asking -
/// script of a world reaching another frame's Window makes that frame's
/// realm of the world - and Chrome announces it then
/// (Runtime.executionContextCreated, from MainThreadDebugger::ContextCreated
/// as Blink's WindowProxyManager makes an isolated world's context). The
/// engine's world observer (engine.installWorldObserver) tells it; explicit
/// registration at a commit or Runtime.enable stays, and a realm already
/// known is not registered twice. A supplement of the Browser's scope.
pub const WorldWatch = struct {
    /// The Browser's devtools token (ids.zig), set when the first page
    /// session attaches.
    token: u64 = 0,
    installed: bool = false,
    observer: engine.WorldObserver = .{ .created = worldCreated, .destroyed = worldDestroyed },

    pub fn init(allocator: std.mem.Allocator) WorldWatch {
        _ = allocator;
        return .{};
    }

    pub fn deinit(self: *WorldWatch) void {
        _ = self;
    }
};

/// The session's Browser has its world realms registered as they are made,
/// from now on (installed once, by the first page session that attaches).
pub fn watchWorlds(session: *const PageSession) void {
    if (comptime !have_inspector or !@hasDecl(engine, "installWorldObserver")) return;
    const browser = session.browser orelse return;
    const agent = browser.agent orelse return;
    const watch = browser.scope.of(WorldWatch) catch return;
    watch.token = session.side.?.token;
    if (watch.installed) return;
    engine.installWorldObserver(agent, &watch.observer, watch);
    watch.installed = true;
}

fn worldCreated(host: ?*anyopaque, world_realm: runtime.Context) void {
    if (comptime have_inspector) worldCreatedLive(host, world_realm);
}

fn worldCreatedLive(host: ?*anyopaque, world_realm: runtime.Context) void {
    const watch: *WorldWatch = @ptrCast(@alignCast(host orelse return));
    const main = engine.mainRealmOf(world_realm);
    const record = main.getRealm() orelse return;
    const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return));
    const bc = @import("dom").browser_state.browsingContextOf(window) orelse return;
    _ = registerWithToken(watch.token, world_realm, bc);
}

fn worldDestroyed(host: ?*anyopaque, world_realm: runtime.Context) void {
    _ = host;
    if (comptime have_inspector) {
        if (engine.inspectorContextId(world_realm) != null) engine.inspectorContextDestroyed(world_realm);
    }
}
