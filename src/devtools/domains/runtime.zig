//! The Runtime domain on page sessions: the engine's inspector (user ruling
//! D3, 2026-11-21: V8's inspector for the JavaScript domains, "scoped
//! through our js engine protocol" - capability inspector_protocol; the
//! bridge is lane cdpw's). Chrome's architecture: Blink's DevToolsSession
//! hands every method V8InspectorSession::canDispatchMethod accepts to V8
//! (third_party/blink/renderer/core/inspector/devtools_session.cc) - here
//! `dispatchRaw` passes Runtime's to the session's inspector session, which
//! answers in CDP through `session.sendRaw`. Crane acts itself where it must
//! (lane cdph, P4; design 3.4):
//! - Runtime.runIfWaitingForDebugger releases the tab's start hold
//!   (`session.runIfWaitingForDebugger`, cdpt's throttle; Chrome:
//!   V8InspectorClient::runIfWaitingForDebugger reaches the same);
//! - Runtime.enable first makes every live realm of the tab known
//!   (contexts.registerTree), so V8's replay of executionContextCreated has
//!   them all;
//! - at each cross-document commit, the last session on the tab registers
//!   the new document's realms after every session's Page events
//!   (contexts.zig); each session's new-document scripts then run at the
//!   document-start hook (page.zig).

const std = @import("std");
const engine = @import("engine");
const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");
const frames = @import("../frames.zig");
const contexts = @import("../contexts.zig");
const R = protocol.Runtime;

const log = std.log.scoped(.devtools);

/// Whether the engine protocol has inspector sessions (lane cdpw's bridge).
pub const have_sessions = contexts.have_inspector and @hasDecl(engine, "inspectorConnect") and
    @hasDecl(engine, "inspectorDispatch") and @hasDecl(engine, "inspectorDisconnect");

const SessionHandle = if (have_sessions) ?*engine.InspectorSession else ?*anyopaque;

/// Per-session state of the domain.
pub const State = struct {
    /// The session's own inspector session (Blink: a V8InspectorSession per
    /// DevToolsSession), connected while the page session is attached.
    inspector: SessionHandle = null,
};

pub fn sessionStarted(session: *PageSession) void {
    if (comptime have_sessions) return sessionStartedLive(session);
    return;
}

/// `sessionStarted` with the engine's inspector operations (lane cdpw's bridge):
/// analysed only when the engine protocol has them.
fn sessionStartedLive(session: *PageSession) void {
    // World realms made on demand are registered as they are made.
    contexts.watchWorlds(session);
    const browser = session.browser orelse return;
    const agent = browser.agent orelse return;
    session.states.Runtime.inspector = engine.inspectorConnect(agent, contexts.groupOf(session.tab), .{ .context = session, .send = sendToClient }) catch |err| blk: {
        log.warn("devtools: no inspector session for a page session: {}", .{err});
        break :blk null;
    };
}

pub fn sessionEnded(session: *PageSession) void {
    if (comptime have_sessions) return sessionEndedLive(session);
    return;
}

/// `sessionEnded` with the engine's inspector operations (lane cdpw's bridge):
/// analysed only when the engine protocol has them.
fn sessionEndedLive(session: *PageSession) void {
    if (session.states.Runtime.inspector) |inspector| engine.inspectorDisconnect(inspector);
    session.states.Runtime.inspector = null;
}

/// What the inspector sends this session's client: a CDP response or event,
/// with the session's id added.
fn sendToClient(context: ?*anyopaque, message: []const u8) void {
    const session: *PageSession = @ptrCast(@alignCast(context orelse return));
    session.sendRaw(message);
}

/// Release the tab's start hold (Target.setAutoAttach
/// {waitForDebuggerOnStart}): its first navigation goes on.
pub fn runIfWaitingForDebugger(session: *PageSession, params: R.runIfWaitingForDebugger.Params) !R.runIfWaitingForDebugger.Result {
    _ = params;
    session.runIfWaitingForDebugger();
    return .{};
}

/// Every other Runtime method: the inspector's.
pub fn dispatchRaw(session: *PageSession, method: []const u8, raw: []const u8) bool {
    if (std.mem.eql(u8, method, "Runtime.enable")) {
        if (frames.navigable(session, session.tab)) |top| contexts.registerTree(session, top);
    }
    return passToInspector(session, method, raw);
}

/// Hand `raw` (a CDP request) to the session's inspector session, for a
/// method the engine's inspector implements. False when it has none: the
/// dispatcher answers "'<method>' wasn't found".
pub fn passToInspector(session: *PageSession, method: []const u8, raw: []const u8) bool {
    if (comptime have_sessions) return passToInspectorLive(session, method, raw);
    return false;
}

/// `passToInspector` with the engine's inspector operations (lane cdpw's bridge):
/// analysed only when the engine protocol has them.
fn passToInspectorLive(session: *PageSession, method: []const u8, raw: []const u8) bool {
    const inspector = session.states.Runtime.inspector orelse return false;
    if (@hasDecl(engine, "inspectorCanDispatch") and !engine.inspectorCanDispatch(method)) return false;
    engine.inspectorDispatch(inspector, raw);
    return true;
}

pub fn onNavigation(session: *PageSession, milestone: *const frames.Milestone) void {
    switch (milestone.event) {
        .committed => {
            if (!frames.inTab(session, milestone.navigable_id)) return;
            // After every session's Page events for this commit: the last
            // session on the tab registers its realms, then each session's
            // scripts run in them.
            if (!contexts.isEdgeSession(session, .last)) return;
            const bc = frames.navigable(session, milestone.navigable_id) orelse return;
            // A child's initial about:blank: no executionContextCreated, as
            // Chrome (its context is made when script first touches it;
            // lane cdpr's vue-e2e-browser log l.392-405).
            if (milestone.navigation_id == 0 and milestone.navigable_id != session.tab) return;
            contexts.afterCommit(session, bc);
            // The sessions' new-document scripts run next, at the
            // document-start hook (page.zig), in the contexts made known here.
        },
        else => {},
    }
}
