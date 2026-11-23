//! A DOM agent's node ids: CDP's nodeId, bound per session as nodes are
//! pushed to its client (DOM.getDocument, DOM.setChildNodes, the mutation
//! events), the containers whose children the client has
//! (children_requested), and the child count the client was last sent for
//! each container whose children it has not (child_counts). Blink's
//! InspectorDOMAgent keeps the same per agent: document_node_to_id_map_,
//! dangling_node_to_id_maps_, id_to_node_, id_to_nodes_map_,
//! children_requested_, cached_child_count_, last_node_id_
//! (third_party/blink/renderer/core/inspector/inspector_dom_agent.cc at
//! Chrome 157.0.8103.78: Bind, Unbind, BoundNodeId, NodeForId,
//! PushNodePathToFrontend, DiscardFrontendBindings; Apple/Google BSD -
//! reproduced, not copied).
//!
//! Two kinds of bindings. The DOCUMENT's (`document`): the nodes of the
//! inspected document the client has - what BoundNodeId answers and every
//! mutation event reads. It never keeps a node alive (src/AGENTS.md, "DOM
//! lifetime": this is no hold, only a name): each binding records its
//! node's slab generation, a bound node is in a bound tree, and its removal
//! unbinds it (the agent's WillRemoveDOMNode), so the generation check is a
//! net for what no event reaches (a frame's replaced document). And a
//! DETACHED tree's (`dangling`): a node pushed while outside the document
//! (DOM.requestNode of a detached node) is pushed with its subtree's root
//! into a map of its own, which HOLDS that root (dom.node_holds.RefHold, a
//! counted reference - Blink's dangling maps keep their nodes as Member<>)
//! until the bindings are discarded, so the ids the client was given keep
//! naming the nodes; no event is sent for a change inside such a tree
//! (BoundNodeId reads the document's map only).
//!
//! Bindings go one at a time (`forget`: a removal, Blink's Unbind) or all at
//! once (`clear`: a new document, getDocument, the domain disabled); the
//! maps' removals leave tombstones, which their guards rehash away
//! (infra.tombstones, as NodeIds).

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const TombstoneGuard = @import("infra").tombstones.TombstoneGuard;
const RefHold = @import("dom").node_holds.RefHold;
const NodeIds = @import("node_ids.zig").NodeIds;

/// One map from nodes to their ids: the document's, or a detached tree's
/// (Blink's NodeToIdMap).
pub const Bindings = struct {
    by_node: std.AutoHashMapUnmanaged(usize, Entry) = .empty,
    guard: TombstoneGuard = .{},
    /// A detached tree's root, held while its map is (never the document's).
    root: RefHold = .{},

    const Entry = struct {
        id: i64,
        generation: u64,
    };

    /// `node`'s id in this map, or 0.
    pub fn idOf(self: *const Bindings, node: *runtime.Instance) i64 {
        const entry = self.by_node.get(@intFromPtr(node)) orelse return 0;
        if (entry.generation != runtime.SlabAllocator.generationOf(node)) return 0;
        return entry.id;
    }

    /// Whether `node` is in this map (Blink's nodes_map->Contains).
    pub fn contains(self: *const Bindings, node: *runtime.Instance) bool {
        return self.idOf(node) != 0;
    }

    fn deinit(self: *Bindings, allocator: Allocator) void {
        self.root.release();
        self.by_node.deinit(allocator);
    }
};

pub const NodeMap = struct {
    allocator: Allocator,
    /// The inspected document's nodes the client has
    /// (document_node_to_id_map_).
    document: Bindings = .{},
    /// The detached trees pushed to the client (dangling_node_to_id_maps_),
    /// each OWNED.
    dangling: std.ArrayListUnmanaged(*Bindings) = .empty,
    /// Every id the client has, of either kind (id_to_node_ and
    /// id_to_nodes_map_).
    by_id: std.AutoHashMapUnmanaged(i64, IdEntry) = .empty,
    /// The bound containers whose children the client was sent.
    children_requested: std.AutoHashMapUnmanaged(i64, void) = .empty,
    /// The child count the client was sent for each container of the
    /// document's map (Blink's cached_child_count_): the base of
    /// childNodeCountUpdated.
    child_counts: std.AutoHashMapUnmanaged(i64, i64) = .empty,
    by_id_guard: TombstoneGuard = .{},
    requested_guard: TombstoneGuard = .{},
    counts_guard: TombstoneGuard = .{},
    /// Blink's last_node_id_ starts at 1; 0 is "no node". Ids keep rising
    /// across `clear`, as Blink's do.
    next_id: i64 = 1,

    const IdEntry = struct {
        node: usize,
        generation: u64,
        bindings: *Bindings,
    };

    pub fn init(allocator: Allocator) NodeMap {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *NodeMap) void {
        self.clear();
        self.document.deinit(self.allocator);
        self.dangling.deinit(self.allocator);
        self.by_id.deinit(self.allocator);
        self.children_requested.deinit(self.allocator);
        self.child_counts.deinit(self.allocator);
    }

    /// Bind(node, nodes_map): `node`'s id in `bindings`, made on first push.
    pub fn bindIn(self: *NodeMap, bindings: *Bindings, node: *runtime.Instance) Allocator.Error!i64 {
        const id = bindings.idOf(node);
        if (id != 0) return id;
        const generation = runtime.SlabAllocator.generationOf(node);
        self.by_id_guard.beforeInsert(&self.by_id);
        try self.by_id.ensureUnusedCapacity(self.allocator, 1);
        bindings.guard.beforeInsert(&bindings.by_node);
        // A slot reused by another node replaces the old binding's key; the
        // old binding's id stays until a clear, naming a node that is gone
        // (its generation check fails).
        try bindings.by_node.put(self.allocator, @intFromPtr(node), .{ .id = self.next_id, .generation = generation });
        self.by_id.putAssumeCapacity(self.next_id, .{ .node = @intFromPtr(node), .generation = generation, .bindings = bindings });
        self.next_id += 1;
        return self.next_id - 1;
    }

    /// Bind in the document's map.
    pub fn bind(self: *NodeMap, node: *runtime.Instance) Allocator.Error!i64 {
        return self.bindIn(&self.document, node);
    }

    /// BoundNodeId: `node`'s id in the document's map, else 0.
    pub fn boundId(self: *const NodeMap, node: *runtime.Instance) i64 {
        return self.document.idOf(node);
    }

    /// The id of `element`'s pseudo-element of kind `kind` (1-7) in the
    /// document's map, else 0. A pseudo-element is no Instance here: it is
    /// keyed by its originating element's address with its kind in the low
    /// bits (NodeIds.pseudoKey), and lives as long as that element.
    pub fn pseudoId(self: *const NodeMap, element: *runtime.Instance, kind: u3) i64 {
        const entry = self.document.by_node.get(NodeIds.pseudoKey(element, kind)) orelse return 0;
        if (entry.generation != runtime.SlabAllocator.generationOf(element)) return 0;
        return entry.id;
    }

    /// Bind `element`'s pseudo-element of kind `kind` in the document's map.
    pub fn bindPseudo(self: *NodeMap, element: *runtime.Instance, kind: u3) Allocator.Error!i64 {
        const id = self.pseudoId(element, kind);
        if (id != 0) return id;
        const key = NodeIds.pseudoKey(element, kind);
        const generation = runtime.SlabAllocator.generationOf(element);
        self.by_id_guard.beforeInsert(&self.by_id);
        try self.by_id.ensureUnusedCapacity(self.allocator, 1);
        self.document.guard.beforeInsert(&self.document.by_node);
        try self.document.by_node.put(self.allocator, key, .{ .id = self.next_id, .generation = generation });
        self.by_id.putAssumeCapacity(self.next_id, .{ .node = key, .generation = generation, .bindings = &self.document });
        self.next_id += 1;
        return self.next_id - 1;
    }

    /// Unbind `element`'s pseudo-element of kind `kind`; its id, or 0.
    pub fn forgetPseudo(self: *NodeMap, element: *runtime.Instance, kind: u3) i64 {
        const id = self.pseudoId(element, kind);
        if (id == 0) return 0;
        if (self.by_id.remove(id)) self.by_id_guard.noteRemoval(&self.by_id);
        if (self.document.by_node.remove(NodeIds.pseudoKey(element, kind))) self.document.guard.noteRemoval(&self.document.by_node);
        return id;
    }

    /// NodeForId: the node bound to `id` in any map, while it lives (none
    /// for a pseudo-element's id).
    pub fn nodeOf(self: *const NodeMap, id: i64) ?*runtime.Instance {
        if (id == 0) return null;
        const entry = self.by_id.get(id) orelse return null;
        if (entry.node & 7 != 0) return null;
        const node: *runtime.Instance = @ptrFromInt(entry.node);
        if (runtime.SlabAllocator.generationOf(node) != entry.generation) return null;
        return node;
    }

    /// id_to_nodes_map_.at(id): the map `id` is bound in.
    pub fn bindingsOf(self: *const NodeMap, id: i64) ?*Bindings {
        const entry = self.by_id.get(id) orelse return null;
        return entry.bindings;
    }

    /// A map of its own for the detached tree under `root`, which it holds
    /// until the bindings are discarded (PushNodePathToFrontend's
    /// dangling_node_to_id_maps_.push_back).
    pub fn newDangling(self: *NodeMap, root: *runtime.Instance) Allocator.Error!*Bindings {
        try self.dangling.ensureUnusedCapacity(self.allocator, 1);
        const bindings = try self.allocator.create(Bindings);
        bindings.* = .{};
        bindings.root.set(root);
        self.dangling.appendAssumeCapacity(bindings);
        return bindings;
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

    /// Blink's Unbind, the map's half: `node`'s binding in the document's
    /// map, its children requested mark and its cached count go. Returns its
    /// id (0 when the client did not have it) and whether its children had
    /// been requested - the caller then forgets each inner child too, as
    /// Blink's Unbind recurses.
    pub fn forget(self: *NodeMap, node: *runtime.Instance) struct { id: i64, children_requested: bool } {
        const id = self.boundId(node);
        if (id == 0) return .{ .id = 0, .children_requested = false };
        if (self.by_id.remove(id)) self.by_id_guard.noteRemoval(&self.by_id);
        if (self.document.by_node.remove(@intFromPtr(node))) self.document.guard.noteRemoval(&self.document.by_node);
        const requested = self.children_requested.remove(id);
        if (requested) self.requested_guard.noteRemoval(&self.children_requested);
        if (self.child_counts.remove(id)) self.counts_guard.noteRemoval(&self.child_counts);
        return .{ .id = id, .children_requested = requested };
    }

    /// DiscardFrontendBindings: the client forgets every node; the detached
    /// trees' roots are let go (ReleaseDanglingNodes).
    pub fn clear(self: *NodeMap) void {
        self.document.by_node.clearRetainingCapacity();
        self.document.guard.reset();
        for (self.dangling.items) |bindings| {
            bindings.deinit(self.allocator);
            self.allocator.destroy(bindings);
        }
        self.dangling.clearRetainingCapacity();
        self.by_id.clearRetainingCapacity();
        self.children_requested.clearRetainingCapacity();
        self.child_counts.clearRetainingCapacity();
        self.by_id_guard.reset();
        self.requested_guard.reset();
        self.counts_guard.reset();
    }
};
