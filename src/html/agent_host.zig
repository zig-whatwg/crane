//! Host-side state owned by one agent, freed after the agent is destroyed.
const std = @import("std");
const dom = @import("dom");

pub const AgentHost = struct {
    indexeddb_cleanup: dom.indexeddb.CleanupList,
    event_sources: @import("eventsource").Registry(*anyopaque, *anyopaque),
    media_elements: @import("media/root.zig").Registry(*anyopaque, *anyopaque),
    embedded_contents: @import("eventsource").Registry(*anyopaque, *anyopaque),
    hyperlink_pings: @import("eventsource").Registry(*anyopaque, *anyopaque),

    pub fn init(allocator: std.mem.Allocator) AgentHost {
        return .{
            .indexeddb_cleanup = dom.indexeddb.CleanupList.init(allocator),
            .event_sources = @import("eventsource").Registry(*anyopaque, *anyopaque).init(allocator),
            .media_elements = @import("media/root.zig").Registry(*anyopaque, *anyopaque).init(allocator),
            .embedded_contents = @import("eventsource").Registry(*anyopaque, *anyopaque).init(allocator),
            .hyperlink_pings = @import("eventsource").Registry(*anyopaque, *anyopaque).init(allocator),
        };
    }
    pub fn deinit(self: *AgentHost) void {
        self.indexeddb_cleanup.deinit();
        self.event_sources.deinit();
        self.media_elements.deinit();
        self.embedded_contents.deinit();
        self.hyperlink_pings.deinit();
    }
};
