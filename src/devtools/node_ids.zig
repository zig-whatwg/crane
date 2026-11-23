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
const TombstoneGuard = @import("infra").tombstones.TombstoneGuard;

pub const NodeIds = struct {
    allocator: Allocator,
    by_node: std.AutoHashMapUnmanaged(usize, Entry) = .empty,
    by_id: std.AutoHashMapUnmanaged(i64, Entry) = .empty,
    /// Both maps lose entries as nodes go (infra.tombstones).
    by_node_guard: TombstoneGuard = .{},
    by_id_guard: TombstoneGuard = .{},
    /// Chrome's first id is 1; 0 is "no node".
    next_id: i64 = 1,

    const Entry = struct {
        id: i64,
        /// The node's address - or, for a pseudo-element, its originating
        /// element's address with the pseudo-element's kind (1-7) in the
        /// low bits an Instance's alignment leaves clear.
        node: usize,
        generation: u64,
    };

    /// The key of `element`'s pseudo-element of kind `kind` (1-7).
    pub fn pseudoKey(element: *runtime.Instance, kind: u3) usize {
        std.debug.assert(kind != 0 and @intFromPtr(element) & 7 == 0);
        return @intFromPtr(element) | kind;
    }

    pub fn init(allocator: Allocator) NodeIds {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *NodeIds) void {
        self.by_node.deinit(self.allocator);
        self.by_id.deinit(self.allocator);
    }

    /// `node`'s id, given on first ask.
    pub fn idOf(self: *NodeIds, node: *runtime.Instance) Allocator.Error!i64 {
        return self.idOfKey(@intFromPtr(node), runtime.SlabAllocator.generationOf(node));
    }

    /// The backendNodeId of `element`'s pseudo-element of kind `kind`
    /// (Blink's PseudoElement is a Node with its own DOMNodeId), given on
    /// first ask; it lives as long as its originating element.
    pub fn idOfPseudo(self: *NodeIds, element: *runtime.Instance, kind: u3) Allocator.Error!i64 {
        return self.idOfKey(pseudoKey(element, kind), runtime.SlabAllocator.generationOf(element));
    }

    /// `element`'s pseudo-element of kind `kind` was destroyed (Blink frees
    /// a removed element's PseudoElements): its id goes, and one made again
    /// is a new node with a new id, as in Chrome.
    pub fn forgetPseudo(self: *NodeIds, element: *runtime.Instance, kind: u3) void {
        const removed = self.by_node.fetchRemove(pseudoKey(element, kind)) orelse return;
        self.by_node_guard.noteRemoval(&self.by_node);
        if (self.by_id.remove(removed.value.id)) self.by_id_guard.noteRemoval(&self.by_id);
    }

    fn idOfKey(self: *NodeIds, address: usize, generation: u64) Allocator.Error!i64 {
        if (self.by_node.get(address)) |entry| {
            if (entry.generation == generation) return entry.id;
            // The slot holds another node now: the old one's id goes.
            if (self.by_id.remove(entry.id)) self.by_id_guard.noteRemoval(&self.by_id);
        }
        const entry: Entry = .{ .id = self.next_id, .node = address, .generation = generation };
        self.by_id_guard.beforeInsert(&self.by_id);
        try self.by_id.ensureUnusedCapacity(self.allocator, 1);
        self.by_node_guard.beforeInsert(&self.by_node);
        try self.by_node.put(self.allocator, address, entry);
        self.by_id.putAssumeCapacity(entry.id, entry);
        self.next_id += 1;
        return entry.id;
    }

    /// The node named `id`, while it lives; null otherwise - and for a
    /// pseudo-element's id, which names no node here.
    pub fn nodeOf(self: *NodeIds, id: i64) ?*runtime.Instance {
        const entry = self.by_id.get(id) orelse return null;
        if (entry.node & 7 != 0) return null;
        const node: *runtime.Instance = @ptrFromInt(entry.node);
        if (runtime.SlabAllocator.generationOf(node) != entry.generation) {
            if (self.by_id.remove(id)) self.by_id_guard.noteRemoval(&self.by_id);
            if (self.by_node.remove(entry.node)) self.by_node_guard.noteRemoval(&self.by_node);
            return null;
        }
        return node;
    }
};
