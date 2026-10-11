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

    pub fn init(allocator: std.mem.Allocator) AgentHost {
        return .{
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
    }
};
