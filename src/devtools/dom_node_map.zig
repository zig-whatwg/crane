//! A DOM agent's node ids: CDP's nodeId, bound per session as nodes are
//! pushed to its client (DOM.getDocument, DOM.setChildNodes, the mutation
//! events), the containers whose children the client has
//! (children_requested), and the child count the client was last sent for
//! each container whose children it has not (cached_child_count). Blink's
//! InspectorDOMAgent keeps the same per agent: document_node_to_id_map_,
//! id_to_node_, children_requested_, cached_child_count_, last_node_id_
//! (third_party/blink/renderer/core/inspector/inspector_dom_agent.cc at
//! Chrome 157.0.8103.78: Bind, Unbind, BoundNodeId, NodeForId,
//! DiscardFrontendBindings; Apple/Google BSD - reproduced, not copied).
//!
//! The map never keeps a node alive (src/AGENTS.md, "DOM lifetime": no bare
//! pointer held for script; this is no hold, only a name): each binding
//! records its node's slab generation, and a lookup whose node's slot has
//! been freed or reused answers none, as Blink's map forgets a node. A bound
//! node is in a bound tree, and its removal unbinds it (the agent's
//! WillRemoveDOMNode), so the net catches only what Blink keeps alive in its
//! strong id_to_node_ and no event reaches: the nodes of a frame's replaced
//! document.
//!
//! Bindings go one at a time (`forget`: a removal, Blink's Unbind) or all at
//! once (`clear`: a new document, getDocument, the domain disabled); the
//! maps' removals leave tombstones, which their guards rehash away
//! (infra.tombstones, as NodeIds).

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const TombstoneGuard = @import("infra").tombstones.TombstoneGuard;

pub const NodeMap = struct {
    allocator: Allocator,
    by_node: std.AutoHashMapUnmanaged(usize, Entry) = .empty,
    by_id: std.AutoHashMapUnmanaged(i64, Entry) = .empty,
    /// The bound containers whose children the client was sent.
    children_requested: std.AutoHashMapUnmanaged(i64, void) = .empty,
    /// The child count the client was sent for each bound container
    /// (Blink's cached_child_count_): the base of childNodeCountUpdated.
    child_counts: std.AutoHashMapUnmanaged(i64, i64) = .empty,
    by_node_guard: TombstoneGuard = .{},
    by_id_guard: TombstoneGuard = .{},
    requested_guard: TombstoneGuard = .{},
    counts_guard: TombstoneGuard = .{},
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
        self.child_counts.deinit(self.allocator);
    }

    /// Bind: `node`'s id, made on first push.
    pub fn bind(self: *NodeMap, node: *runtime.Instance) Allocator.Error!i64 {
        const id = self.boundId(node);
        if (id != 0) return id;
        const entry: Entry = .{ .id = self.next_id, .node = @intFromPtr(node), .generation = runtime.SlabAllocator.generationOf(node) };
        self.by_id_guard.beforeInsert(&self.by_id);
        try self.by_id.ensureUnusedCapacity(self.allocator, 1);
        self.by_node_guard.beforeInsert(&self.by_node);
        // A slot reused by another node replaces the old binding's key; the
        // old binding's id stays until a clear, naming a node that is gone
        // (its generation check fails).
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
        self.requested_guard.beforeInsert(&self.children_requested);
        try self.children_requested.put(self.allocator, id, {});
    }

    /// The child count the client was last sent for `id` (0 if none).
    pub fn childCount(self: *const NodeMap, id: i64) i64 {
        return self.child_counts.get(id) orelse 0;
    }

    pub fn setChildCount(self: *NodeMap, id: i64, count: i64) Allocator.Error!void {
        self.counts_guard.beforeInsert(&self.child_counts);
        try self.child_counts.put(self.allocator, id, count);
    }

    /// Blink's Unbind, the map's half: `node`'s binding, its children
    /// requested mark and its cached count go. Returns its id (0 when the
    /// client did not have it) and whether its children had been requested
    /// - the caller then forgets each inner child too, as Blink's Unbind
    /// recurses.
    pub fn forget(self: *NodeMap, node: *runtime.Instance) struct { id: i64, children_requested: bool } {
        const id = self.boundId(node);
        if (id == 0) return .{ .id = 0, .children_requested = false };
        if (self.by_id.remove(id)) self.by_id_guard.noteRemoval(&self.by_id);
        if (self.by_node.remove(@intFromPtr(node))) self.by_node_guard.noteRemoval(&self.by_node);
        const requested = self.children_requested.remove(id);
        if (requested) self.requested_guard.noteRemoval(&self.children_requested);
        if (self.child_counts.remove(id)) self.counts_guard.noteRemoval(&self.child_counts);
        return .{ .id = id, .children_requested = requested };
    }

    /// DiscardFrontendBindings: the client forgets every node.
    pub fn clear(self: *NodeMap) void {
        self.by_node.clearRetainingCapacity();
        self.by_id.clearRetainingCapacity();
        self.children_requested.clearRetainingCapacity();
        self.child_counts.clearRetainingCapacity();
        self.by_node_guard.reset();
        self.by_id_guard.reset();
        self.requested_guard.reset();
        self.counts_guard.reset();
    }
};
