//! Host-side state owned by one agent, freed after the agent is destroyed.
const std = @import("std");
const dom = @import("dom");

pub const AgentHost = struct {
    indexeddb_cleanup: dom.indexeddb.CleanupList,
    event_sources: @import("eventsource").Registry(*anyopaque, *anyopaque),

    pub fn init(allocator: std.mem.Allocator) AgentHost {
        return .{
            .indexeddb_cleanup = dom.indexeddb.CleanupList.init(allocator),
            .event_sources = @import("eventsource").Registry(*anyopaque, *anyopaque).init(allocator),
        };
    }
    pub fn deinit(self: *AgentHost) void {
        self.indexeddb_cleanup.deinit();
        self.event_sources.deinit();
    }
};
