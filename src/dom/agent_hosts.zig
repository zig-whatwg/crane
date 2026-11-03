//! The host of the agent a realm belongs to (html AgentHost): the state an
//! agent owns beyond its engine - its event loop's nesting levels, its
//! mutation observers, its fetches (docs/instances.md, "The model": an agent
//! owns its event loop's state). Found from the realm, through the agent the
//! engine recorded on it and the host the agent was made with.

const runtime = @import("runtime");
const engine = @import("engine");
const AgentHost = @import("html_core").agent_host.AgentHost;

/// The host of `realm`'s agent - a ShadowRealm's, its principal realm's
/// agent's. Null for a realm with no agent (an engine-less test's), or an
/// agent made with no host (a bare test agent's).
pub fn of(realm: runtime.Context) ?*AgentHost {
    var current: ?runtime.Context = realm;
    while (current) |r| : (current = r.principal_realm) {
        const agent = r.agent orelse continue;
        return @ptrCast(@alignCast(engine.agentHost(agent) orelse return null));
    }
    return null;
}
