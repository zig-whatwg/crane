//! The Network domain on page sessions (tmp/plans/cdp-part1-design.md 3.9):
//! the session's switches. The events come from the Browser's fetch observer
//! (src/devtools/fetch_observer.zig), which reports a request to every
//! session of its tab with Network enabled - Blink's InspectorNetworkAgent,
//! enabled per session (third_party/blink/renderer/core/inspector/
//! inspector_network_agent.cc).

const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");

const N = protocol.Network;

/// Per-session state of the domain.
pub const State = struct {
    enabled: bool = false,
    /// Network.setCacheDisabled: the tab's requests go past the HTTP cache.
    cache_disabled: bool = false,
};

pub fn enable(session: *PageSession, _: N.enable.Params) !N.enable.Result {
    session.states.Network.enabled = true;
    return .{};
}

pub fn disable(session: *PageSession, _: N.disable.Params) !N.disable.Result {
    session.states.Network = .{};
    return .{};
}

pub fn setCacheDisabled(session: *PageSession, params: N.setCacheDisabled.Params) !N.setCacheDisabled.Result {
    session.states.Network.cache_disabled = params.cacheDisabled;
    return .{};
}

/// TODO(cdpt): the bodies of finished requests, kept per tab in a bounded
/// buffer while Network is enabled (Chrome's NetworkResourcesData). Until
/// then every id answers as one whose body was not kept, with Chrome's
/// message (inspector_network_agent.cc GetResponseBody).
pub fn getResponseBody(session: *PageSession, _: N.getResponseBody.Params) !N.getResponseBody.Result {
    return session.fail("No resource with given identifier found");
}
