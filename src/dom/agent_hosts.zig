//! The host of the agent a realm belongs to (html AgentHost): the state an
//! agent owns beyond its engine - its event loop's nesting levels, its
//! mutation observers, its fetches (docs/instances.md, "The model": an agent
//! owns its event loop's state). Found from the realm, through the agent the
//! engine recorded on it and the host state the agent was made with
//! (engine.hostStateOf) - never its `host`, whose type is only its creator's
//! (lesson architecture-a-host-pointer-an-agent-was-given-is-only-its-
//! creators-type.md: a tests/v8 agent with a struct of its own as its host
//! was read as custom element reaction queues). This file is the only place
//! an AgentHost becomes the engine's `HostState` and back.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const AgentHost = @import("html_core").agent_host.AgentHost;

/// The options of an agent `host` is the host of: `options` with its `host`
/// and `host_state` both set to `host` - the one way html's creators (a
/// Browser, a worker host, a test that makes an agent html serves) fill
/// them, so the two never name different things. `host` is BORROWED by the
/// agent for its life, as both options say.
pub fn agentOptions(host: *AgentHost, options: engine.AgentOptions) engine.AgentOptions {
    std.debug.assert(options.host == null and options.host_state == null);
    var with_host = options;
    with_host.host = host;
    with_host.host_state = @ptrCast(host);
    return with_host;
}

/// The AgentHost of `agent` - the `host_state` it was made with
/// (`agentOptions`) - or null for an agent made without one: a test's own
/// agent, whatever its `host`. The agent registry's locked lookup: for a
/// caller with an agent and no realm (html.rejected_promises.releaseAgent);
/// one with a realm reads its cache (`ofOwnAgent`). No check reads `engine.agentHost` against it:
/// `agentOptions` sets both from one pointer, and nothing in src/ outside
/// the engine protocol calls agentHost (lint-engine's `agentHost()` key).
pub fn ofAgent(agent: *engine.Agent) ?*AgentHost {
    const state = engine.hostStateOf(agent) orelse return null;
    return @ptrCast(@alignCast(state));
}

/// The host of `realm`'s agent - a ShadowRealm's, its principal realm's
/// agent's. Null for a realm with no agent (an engine-less test's), or an
/// agent made with no host state (a bare test agent's, whatever its host).
pub fn of(realm: runtime.Context) ?*AgentHost {
    var current: ?runtime.Context = realm;
    while (current) |r| : (current = r.principal_realm) {
        if (r.agent == null) continue;
        return ofOwnAgent(r);
    }
    return null;
}

/// The host of `realm`'s own agent (`realm.agent`, no principal realm
/// followed): the host state the adapter cached on the realm when it made
/// it (runtime.ContextData.host_state) - one load, no lookup, as Blink's
/// ExecutionContext reaches its agent. The realm lives within its agent, so
/// the cached pointer outlives it. A realm with an agent and nothing cached
/// - one a host made by hand and gave an agent after (an engine-less test's
/// ContextData), or one of an agent made with no host state - asks the
/// registry (`ofAgent`), which answers what it would have cached. Null for a
/// realm with no agent, or an agent made with no host state.
pub fn ofOwnAgent(realm: runtime.Context) ?*AgentHost {
    if (realm.host_state) |state| return @ptrCast(@alignCast(state));
    return ofAgent(realm.agent orelse return null);
}
