//! The Inspector domain on page sessions (lane cdph, P4; design 1.4 "O"):
//! enabled per session, as Vitest's browser mode asks. Its events -
//! targetCrashed, detached - are not sent: a Crane tab runs in its Browser's
//! process and thread, so it does not crash on its own, and a session's
//! detach is Target's (Target.detachedFromTarget).

const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");
const I = protocol.Inspector;

/// Per-session state of the domain.
pub const State = struct {
    enabled: bool = false,
};

pub fn enable(session: *PageSession, params: I.enable.Params) !I.enable.Result {
    _ = params;
    session.states.Inspector.enabled = true;
    return .{};
}

pub fn disable(session: *PageSession, params: I.disable.Params) !I.disable.Result {
    _ = params;
    session.states.Inspector.enabled = false;
    return .{};
}
