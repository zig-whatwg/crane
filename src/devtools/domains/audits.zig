//! The Audits domain on page sessions (lane cdph, P4; design 1.4 "A" and
//! 3.11): enabled per session, as Puppeteer asks. Crane reports no issues
//! yet - its CSP and cookie issues (Audits.issueAdded) are part 2 - so an
//! enabled session hears none, which is the truth of what it has to say.

const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");
const A = protocol.Audits;

/// Per-session state of the domain.
pub const State = struct {
    enabled: bool = false,
};

pub fn enable(session: *PageSession, params: A.enable.Params) !A.enable.Result {
    _ = params;
    session.states.Audits.enabled = true;
    return .{};
}

pub fn disable(session: *PageSession, params: A.disable.Params) !A.disable.Result {
    _ = params;
    session.states.Audits.enabled = false;
    return .{};
}
