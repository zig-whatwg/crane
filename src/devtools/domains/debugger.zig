//! The Debugger domain on page sessions: the engine's inspector (user ruling D3;
//! design 3.4), every method through `dispatchRaw` - V8's own Debugger agent
//! answers (htmx's runner: precise coverage and script sources; Vue's
//! browser-mode tests: HeapProfiler.collectGarbage), as Chrome hands it to
//! V8 (Blink's DevToolsSession and V8InspectorSession::canDispatchMethod).

const PageSession = @import("../page_session.zig").PageSession;

/// Per-session state of the domain: none of Crane's (the inspector session
/// keeps the domain's).
pub const State = struct {};

pub fn dispatchRaw(session: *PageSession, method: []const u8, raw: []const u8) bool {
    return @import("runtime.zig").passToInspector(session, method, raw);
}
