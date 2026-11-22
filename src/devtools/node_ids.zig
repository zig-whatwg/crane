//! DevTools node ids: CDP's backendNodeId, a stable id per node that is
//! never reused (Chrome's DOMNodeIds: one int per Node, kept in a weak map,
//! third_party/blink/renderer/core/dom/dom_node_ids.h) - lane cdph, P4,
//! design 3.6.
//!
//! The registry never keeps a node alive (src/AGENTS.md, "DOM lifetime": no
//! bare pointer held for script; this is no hold, only a name): it records
//! each node it named with its slab generation, and a lookup whose node's
//! slot has been reused or freed answers none - "No node with given id
//! found" - as Chrome's does for a collected node. One registry per Browser
//! (a supplement of its scope): ids are per Browser, as Chrome's are per
//! renderer process.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");

pub const NodeIds = struct {
    allocator: Allocator,
    by_node: std.AutoHashMapUnmanaged(usize, Entry) = .empty,
    by_id: std.AutoHashMapUnmanaged(i64, Entry) = .empty,
    /// Chrome's first id is 1; 0 is "no node".
    next_id: i64 = 1,

    const Entry = struct {
        id: i64,
        node: usize,
        generation: u64,
    };

    pub fn init(allocator: Allocator) NodeIds {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *NodeIds) void {
        self.by_node.deinit(self.allocator);
        self.by_id.deinit(self.allocator);
    }

    /// `node`'s id, given on first ask.
    pub fn idOf(self: *NodeIds, node: *runtime.Instance) Allocator.Error!i64 {
        const address = @intFromPtr(node);
        const generation = runtime.SlabAllocator.generationOf(node);
        if (self.by_node.get(address)) |entry| {
            if (entry.generation == generation) return entry.id;
            // The slot holds another node now: the old one's id goes.
            _ = self.by_id.remove(entry.id);
        }
        const entry: Entry = .{ .id = self.next_id, .node = address, .generation = generation };
        try self.by_id.ensureUnusedCapacity(self.allocator, 1);
        try self.by_node.put(self.allocator, address, entry);
        self.by_id.putAssumeCapacity(entry.id, entry);
        self.next_id += 1;
        return entry.id;
    }

    /// The node named `id`, while it lives; null otherwise.
    pub fn nodeOf(self: *NodeIds, id: i64) ?*runtime.Instance {
        const entry = self.by_id.get(id) orelse return null;
        const node: *runtime.Instance = @ptrFromInt(entry.node);
        if (runtime.SlabAllocator.generationOf(node) != entry.generation) {
            _ = self.by_id.remove(id);
            _ = self.by_node.remove(entry.node);
            return null;
        }
        return node;
    }
};
