//! The Performance domain on page sessions (lane cdph, P4; design 1.4 "A"
//! and 3.11): enabled per session, as Puppeteer asks; getMetrics (Blink's
//! InspectorPerformanceAgent counters) is part 2 and answers "wasn't
//! found" until then.

const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");
const Perf = protocol.Performance;

/// Per-session state of the domain.
pub const State = struct {
    enabled: bool = false,
};

pub fn enable(session: *PageSession, params: Perf.enable.Params) !Perf.enable.Result {
    _ = params;
    session.states.Performance.enabled = true;
    return .{};
}

pub fn disable(session: *PageSession, params: Perf.disable.Params) !Perf.disable.Result {
    _ = params;
    session.states.Performance.enabled = false;
    return .{};
}
