//! A DOM agent's node ids: CDP's nodeId, bound per session as nodes are
//! pushed to its client (DOM.getDocument, DOM.setChildNodes), and the
//! containers whose children the client has (children_requested). Blink's
//! InspectorDOMAgent keeps the same per agent: document_node_to_id_map_,
//! id_to_node_, children_requested_, last_node_id_ (third_party/blink/
//! renderer/core/inspector/inspector_dom_agent.cc: Bind, BoundNodeId,
//! NodeForId, DiscardFrontendBindings; Apple/Google BSD - reproduced, not
//! copied).
//!
//! The map never keeps a node alive (src/AGENTS.md, "DOM lifetime": no bare
//! pointer held for script; this is no hold, only a name): each binding
//! records its node's slab generation, and a lookup whose node's slot has
//! been freed or reused answers none, as Blink's weak map forgets a collected
//! node. Bindings go only all at once (`clear`: a new document, getDocument,
//! the domain disabled), so the maps never remove one entry at a time.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");

pub const NodeMap = struct {
    allocator: Allocator,
    by_node: std.AutoHashMapUnmanaged(usize, Entry) = .empty,
    by_id: std.AutoHashMapUnmanaged(i64, Entry) = .empty,
    /// The bound containers whose children the client was sent.
    children_requested: std.AutoHashMapUnmanaged(i64, void) = .empty,
    /// Blink's last_node_id_ starts at 1; 0 is "no node". Ids keep rising
    /// across `clear`, as Blink's do.
    next_id: i64 = 1,

    const Entry = struct {
        id: i64,
        node: usize,
        generation: u64,
    };

    pub fn init(allocator: Allocator) NodeMap {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *NodeMap) void {
        self.by_node.deinit(self.allocator);
        self.by_id.deinit(self.allocator);
        self.children_requested.deinit(self.allocator);
    }

    /// Bind: `node`'s id, made on first push.
    pub fn bind(self: *NodeMap, node: *runtime.Instance) Allocator.Error!i64 {
        const id = self.boundId(node);
        if (id != 0) return id;
        const entry: Entry = .{ .id = self.next_id, .node = @intFromPtr(node), .generation = runtime.SlabAllocator.generationOf(node) };
        try self.by_id.ensureUnusedCapacity(self.allocator, 1);
        // A slot reused by another node replaces the old binding's key.
        try self.by_node.put(self.allocator, entry.node, entry);
        self.by_id.putAssumeCapacity(entry.id, entry);
        self.next_id += 1;
        return entry.id;
    }

    /// BoundNodeId: `node`'s id if the client has it, else 0.
    pub fn boundId(self: *const NodeMap, node: *runtime.Instance) i64 {
        const entry = self.by_node.get(@intFromPtr(node)) orelse return 0;
        if (entry.generation != runtime.SlabAllocator.generationOf(node)) return 0;
        return entry.id;
    }

    /// NodeForId: the node bound to `id`, while it lives.
    pub fn nodeOf(self: *const NodeMap, id: i64) ?*runtime.Instance {
        if (id == 0) return null;
        const entry = self.by_id.get(id) orelse return null;
        const node: *runtime.Instance = @ptrFromInt(entry.node);
        if (runtime.SlabAllocator.generationOf(node) != entry.generation) return null;
        return node;
    }

    pub fn childrenRequested(self: *const NodeMap, id: i64) bool {
        return self.children_requested.contains(id);
    }

    pub fn markChildrenRequested(self: *NodeMap, id: i64) Allocator.Error!void {
        try self.children_requested.put(self.allocator, id, {});
    }

    /// DiscardFrontendBindings: the client forgets every node.
    pub fn clear(self: *NodeMap) void {
        self.by_node.clearRetainingCapacity();
        self.by_id.clearRetainingCapacity();
        self.children_requested.clearRetainingCapacity();
    }
};
