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
        self.deferred_teardown.deinit();
        self.indexeddb_cleanup.deinit();
        self.event_sources.deinit();
        self.media_elements.deinit();
        self.custom_elements.deinit();
        self.embedded_contents.deinit();
        self.hyperlink_pings.deinit();
    }
};
