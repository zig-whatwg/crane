//! The fetches of the agent a realm belongs to: its network scheduler and
//! every fetch in flight (fetch.algorithms.AgentFetches), kept on the agent's
//! host (html AgentHost.fetches) and pumped by the agent's event loop - the
//! window agent's, or a worker's on its own thread (docs/instances.md: an
//! agent owns its event loop's state).
//!
//! Every caller that starts a fetch on the event loop - fetch(), XHR,
//! EventSource, script, style sheet, image, frame and media loads, keepalive
//! dispatches - starts it here, on the agent of the realm it fetches for, so
//! that agent's loop is the one that hears it.

const runtime = @import("runtime");
const engine = @import("engine");
const fetch = @import("fetch");
const AgentHost = @import("html_core").agent_host.AgentHost;

pub const AgentFetches = fetch.algorithms.AgentFetches;

/// The fetches of `realm`'s agent - a ShadowRealm's, its principal realm's
/// agent's. Null for a realm with no agent (an engine-less test's), whose
/// fetch the caller fails as a network error.
pub fn of(realm: runtime.Context) ?*AgentFetches {
    var current: ?runtime.Context = realm;
    while (current) |r| : (current = r.principal_realm) {
        const agent = r.agent orelse continue;
        const host: *AgentHost = @ptrCast(@alignCast(engine.agentHost(agent) orelse return null));
        return &host.fetches;
    }
    return null;
}
