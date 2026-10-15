//! Host-side state owned by one agent, freed after the agent is destroyed.
const std = @import("std");
const dom = @import("dom");

pub const AgentHost = struct {
    indexeddb_cleanup: dom.indexeddb.CleanupList,
    event_sources: @import("eventsource").Registry(*anyopaque, *anyopaque),
    media_elements: @import("media/root.zig").Registry(*anyopaque, *anyopaque),
    custom_elements: dom.custom_elements.AgentState,
    embedded_contents: @import("eventsource").Registry(*anyopaque, *anyopaque),
    hyperlink_pings: @import("eventsource").Registry(*anyopaque, *anyopaque),
    /// The agent's queue of native objects whose last owner went away - the
    /// nodes whose wrappers the collector took (engine.AgentOptions.
    /// deferred_teardown) - freed a slice at a time by the agent's event
    /// loop, and fully at the ends of their realms and of the agent.
    deferred_teardown: dom.tree_teardown.DeferredTeardown,
    /// The rejected-promise bookkeeping of every global of the agent's
    /// realms (html.rejected_promises; each entry its `*Tracked`, OWNED by
    /// it): the agent's handles, read and released only on the agent's
    /// thread, and released before the agent ends
    /// (`rejected_promises.releaseAgent`) - so empty here at `deinit`.
    rejections: std.ArrayListUnmanaged(*anyopaque) = .empty,
    /// The agent cluster a dedicated worker's agent is in - its owner's
    /// (HTML "obtain a worker/worklet agent" step 3) - as the worker host
    /// records it when it obtains the agent (html.agent_clusters.ofRealm on
    /// the owner's thread); 0 when none is known. Read by
    /// html.agent_clusters.agentClusterOf.
    agent_cluster: u64 = 0,
    /// The agent's fetches on its event loop - its network scheduler and
    /// every fetch in flight (fetch.algorithms.AgentFetches): pumped by the
    /// agent's loop, on its thread only; reached from a realm through its
    /// agent (dom.agent_fetches). Its realms' ends swept what they left.
    fetches: @import("fetch").algorithms.AgentFetches,
    /// The script-queue drains nested on the agent's stack
    /// (html.script_execution: the "as soon as possible" queues and the
    /// scripts that run when parsing finishes). Read and written only on the
    /// agent's thread, inside a drain.
    script_drain: ScriptDrain = .{},

    pub fn init(allocator: std.mem.Allocator) AgentHost {
        return .{
            .fetches = @import("fetch").algorithms.AgentFetches.init(allocator),
            .indexeddb_cleanup = dom.indexeddb.CleanupList.init(allocator),
            .event_sources = @import("eventsource").Registry(*anyopaque, *anyopaque).init(allocator),
            .media_elements = @import("media/root.zig").Registry(*anyopaque, *anyopaque).init(allocator),
            .custom_elements = dom.custom_elements.AgentState.init(allocator),
            .embedded_contents = @import("eventsource").Registry(*anyopaque, *anyopaque).init(allocator),
            .hyperlink_pings = @import("eventsource").Registry(*anyopaque, *anyopaque).init(allocator),
            .deferred_teardown = dom.tree_teardown.DeferredTeardown.init(allocator),
        };
    }
    /// After the agent's end, which emptied and closed the queue.
    pub fn deinit(self: *AgentHost) void {
        // Released while the agent lived: its promises were its handles.
        std.debug.assert(self.rejections.items.len == 0);
        self.deferred_teardown.deinit();
        self.indexeddb_cleanup.deinit();
        self.event_sources.deinit();
        self.media_elements.deinit();
        self.custom_elements.deinit();
        self.embedded_contents.deinit();
        self.hyperlink_pings.deinit();
        // After the agent's end: the scheduler's multi handle closes, which
        // touches no engine.
        self.fetches.deinit();
    }
};

/// One agent's nested script-queue drains (html.script_execution
/// `DrainScope`). A drain runs scripts on its agent's thread, and a script it
/// runs can insert another script and ask for a drain of its own - which
/// nests on the same agent's stack, whatever document it is for. So the
/// state is the agent's: V8 keeps "is running microtasks" and the microtasks
/// scope depth on each MicrotaskQueue (src/execution/microtask-queue.h,
/// `is_running_microtasks_`, `microtasks_depth_`), the queue Blink's
/// per-agent EventLoop owns (platform/scheduler/public/event_loop.h). It was
/// one pair of process-wide variables, and two Browsers' drains on two
/// threads interleaved on them (docs/instances.md).
pub const ScriptDrain = struct {
    /// The document the innermost drain walks - an identity, compared and
    /// never read through: a script the drain runs can end it.
    document: ?*const anyopaque = null,
    /// How many drains are nested on the agent's stack.
    depth: usize = 0,
};
