//! The event loop's "termination nesting level" (HTML §7.5.9 "unload" steps
//! 7 and 14, and the steps to fire beforeunload, steps 3 and 5): raised while
//! beforeunload, pagehide, visibilitychange or unload handlers run. The window
//! open steps refuse to open anything while it is nonzero (step 1).
//!
//! An event loop is an agent's, so the level is the agent's: on its host
//! (AgentHost.termination_nesting_level), which a caller finds from the realm
//! it runs in (dom.agent_hosts.of). It was one per thread: with two agents on
//! a thread, one's unload handlers kept the other's window.open from opening
//! anything. Document raises it around the handlers unloading runs; Window
//! reads it. A null host (an agent made without one) has no level: entering
//! and leaving do nothing, and it is never active.
//!
//! Spec: https://html.spec.whatwg.org/multipage/document-lifecycle.html#termination-nesting-level

const AgentHost = @import("../agent_host.zig").AgentHost;

/// "Increase the event loop's termination nesting level by 1."
pub fn enter(host: ?*AgentHost) void {
    const agent_host = host orelse return;
    agent_host.termination_nesting_level += 1;
}

/// "Decrease the event loop's termination nesting level by 1."
pub fn leave(host: ?*AgentHost) void {
    const agent_host = host orelse return;
    if (agent_host.termination_nesting_level > 0) agent_host.termination_nesting_level -= 1;
}

/// Whether the level is nonzero: unload-time handlers are running.
pub fn active(host: ?*AgentHost) bool {
    const agent_host = host orelse return false;
    return agent_host.termination_nesting_level > 0;
}
