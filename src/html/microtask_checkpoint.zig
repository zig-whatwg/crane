//! HTML 8.1.7 "perform a microtask checkpoint", host steps 4 and 5.
const std = @import("std");
const engine = @import("engine");
const AgentHost = @import("html_core").agent_host.AgentHost;
const rejected_promises = @import("rejected_promises.zig");

pub fn afterMicrotaskCheckpoint(host: ?*anyopaque, agent: *engine.Agent) void {
    std.debug.assert(host != null);
    const state: *AgentHost = @ptrCast(@alignCast(host.?));
    // Step 4: notify about rejected promises before deactivating transactions.
    rejected_promises.afterMicrotaskCheckpoint(host, agent);
    // Step 5: cleanup Indexed Database transactions, even for an empty queue.
    state.indexeddb_cleanup.cleanup();
    // Step 6 (ClearKeptObjects) follows in the engine's checkpoint.
}
