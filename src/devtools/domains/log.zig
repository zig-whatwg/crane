//! The Log domain on page sessions (lane cdph, P4; design 3.11): accepted
//! per session, as every runner enables it. Log.entryAdded carries the
//! browser's own messages about the page - network errors, CSP and
//! permissions-policy violations, interventions (Blink's InspectorLogAgent)
//! - from their report points; the page's console output is Runtime's
//! (consoleAPICalled), not Log's.

const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");
const L = protocol.Log;

/// Per-session state of the domain.
pub const State = struct {
    enabled: bool = false,
    /// Log.startViolationsReport's thresholds were asked for.
    violations: bool = false,
};

pub fn enable(session: *PageSession, params: L.enable.Params) !L.enable.Result {
    _ = params;
    session.states.Log.enabled = true;
    return .{};
}

pub fn disable(session: *PageSession, params: L.disable.Params) !L.disable.Result {
    _ = params;
    session.states.Log = .{};
    return .{};
}

/// Nothing is kept to clear: entries go out as they happen.
pub fn clear(session: *PageSession, params: L.clear.Params) !L.clear.Result {
    _ = session;
    _ = params;
    return .{};
}

pub fn startViolationsReport(session: *PageSession, params: L.startViolationsReport.Params) !L.startViolationsReport.Result {
    _ = params;
    session.states.Log.violations = true;
    return .{};
}

pub fn stopViolationsReport(session: *PageSession, params: L.stopViolationsReport.Params) !L.stopViolationsReport.Result {
    _ = params;
    session.states.Log.violations = false;
    return .{};
}
