//! The Log domain on page sessions (lane cdph, P4; design 3.11): accepted
//! per session, as every runner enables it. Log.entryAdded carries the
//! browser's own messages about the page - network errors, CSP and
//! permissions-policy violations, interventions (Blink's InspectorLogAgent)
//! - from their report points; the page's console output is Runtime's
//! (consoleAPICalled), not Log's.

const std = @import("std");
const PageSession = @import("../page_session.zig").PageSession;
const BrowserSide = @import("../browser_side.zig").BrowserSide;
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

// ============================================================================
// Entries (Blink's InspectorLogAgent::ConsoleMessageAdded)
// ============================================================================

/// Runtime.Timestamp: milliseconds since the epoch.
fn wallMs() f64 {
    return @as(f64, @floatFromInt(@import("platform").wallNow().ns_since_epoch)) / std.time.ns_per_ms;
}

/// Log.entryAdded to every session on `tab` with the domain enabled.
fn emitToTab(side: *BrowserSide, tab: u64, entry: L.LogEntry) void {
    for (side.sessions.items) |s| {
        if (s.tab != tab or !s.states.Log.enabled) continue;
        s.emit(L.entryAdded, .{ .entry = entry });
    }
}

/// A fetch of the tab's failed (the fetch observer's loadingFailed, not for
/// a cancellation): Blink's FrameConsole::DidFailLoading - "Failed to load
/// resource" and the error's description, source network, level error, the
/// failing URL and the request's id.
pub fn loadingFailed(side: *BrowserSide, tab: u64, url: []const u8, request_id: []const u8, error_text: []const u8) void {
    var buffer: [256]u8 = undefined;
    const text = if (error_text.len > 0)
        std.fmt.bufPrint(&buffer, "Failed to load resource: {s}", .{error_text}) catch "Failed to load resource"
    else
        "Failed to load resource";
    emitToTab(side, tab, .{
        .source = .network,
        .level = .@"error",
        .text = text,
        .timestamp = wallMs(),
        .url = if (url.len > 0) url else null,
        .networkRequestId = if (request_id.len > 0) request_id else null,
    });
}

/// A response of 400 or more for a fetch of the tab: Blink's
/// ResourceLoadObserverForFrame::DidReceiveResponse - "Failed to load
/// resource: the server responded with a status of <status> (<text>)".
pub fn errorResponse(side: *BrowserSide, tab: u64, url: []const u8, request_id: []const u8, status: u16, status_text: []const u8) void {
    var buffer: [256]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "Failed to load resource: the server responded with a status of {d} ({s})", .{ status, status_text }) catch "Failed to load resource";
    emitToTab(side, tab, .{
        .source = .network,
        .level = .@"error",
        .text = text,
        .timestamp = wallMs(),
        .url = if (url.len > 0) url else null,
        .networkRequestId = if (request_id.len > 0) request_id else null,
    });
}
