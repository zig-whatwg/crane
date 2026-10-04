//! Host-side state owned by one agent, freed after the agent is destroyed.
const std = @import("std");
const dom = @import("dom");

pub const AgentHost = struct {
    indexeddb_cleanup: dom.indexeddb.CleanupList,

    pub fn init(allocator: std.mem.Allocator) AgentHost {
        return .{ .indexeddb_cleanup = dom.indexeddb.CleanupList.init(allocator) };
    }
    pub fn deinit(self: *AgentHost) void {
        self.indexeddb_cleanup.deinit();
    }
};
