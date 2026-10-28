//! DOM § 4.3 a node's registered observer list, as the hook between a node
//! and the MutationObservers registered on it.
//!
//! "Nodes have a strong reference to registered observers in their registered
//! observer list. Registered observers in a node's registered observer list
//! have a weak reference to the node." Crane has no tracing collector to
//! express either, so the MutationObserver impl keeps itself alive while any
//! node lists it (it holds its own wrapper), and a node that goes away tells
//! each observer registered on it here, so the observer can forget the node
//! and let itself go once it observes nothing. The Node impl may not call into
//! the MutationObserver impl; the MutationObserver impl installs the
//! implementation in its installHooks, before any registration can exist.
//!
//! It is also where the mutation observer algorithms meet an observer's own
//! state (src/dom/mutation_observer_algorithms.zig): its record queue, whose
//! TYPE lives here and whose state the observer keeps, and the invocation of
//! its callback.
//!
//! lint-impls: hook for MutationObserver
const process_start = @import("process_start.zig");

const std = @import("std");
const infra = @import("infra");
const runtime = @import("runtime");
const handles = @import("handles.zig");
const RegisteredObserver = @import("registered_observer.zig").RegisteredObserver;
const NodeBase = @import("node_base.zig").NodeBase;
const node_holds = @import("node_holds.zig");

/// What the MutationObserver impl supplies.
pub const Implementation = struct {
    /// `node` is going away while `observer` - taken at slab generation
    /// `generation` - is registered on it.
    node_released: *const fn (observer: *runtime.Instance, generation: u64, node: *runtime.Instance) void,
    /// A transient registered observer of `observer` (generation
    /// `generation`) has been appended to `node`'s list: "remove" step 15.
    /// The observer remembers the node, to take it off again.
    transient_added: *const fn (observer: *runtime.Instance, generation: u64, node: *runtime.Instance) void,
    /// "Notify mutation observers" step 6.3 for `observer`: remove all its
    /// transient registered observers from the nodes that list them.
    remove_transients: *const fn (observer: *runtime.Instance) void,
    /// `observer`'s record queue, in its state.
    record_queue: *const fn (observer: *runtime.Instance) *RecordQueue,
    /// "Notify mutation observers" step 6.4: invoke `observer`'s callback
    /// with « `records`, `observer` », and "report" what it throws. The
    /// records are taken: wrapped, they are the wrapper cache's.
    invoke_callback: *const fn (observer: *runtime.Instance, records: []const *runtime.Instance) anyerror!void,
};

/// A MutationObserver's record queue (DOM 4.3.1: "a record queue, which is a
/// queue of zero or more MutationRecord objects"). The observer keeps it by
/// value in its state and frees the records still in it when it goes;
/// "queue a mutation record" enqueues to it (step 4.2) and "notify mutation
/// observers" empties it (steps 6.1-6.2).
///
/// Beside the records, the observer's PENDING TARGETS (refcount step 5c,
/// lane refcount5): every node a queued record names as its target, once,
/// held until the records leave the queue - WebKit's
/// MutationObserver::m_pendingTargets, a HashSet<GCReachableRef<Node>> that
/// enqueueMutationRecord adds to and deliver, takeRecords and disconnect
/// empty (Source/WebCore/dom/MutationObserver.cpp). The record holds its
/// target too (5b); the pending target keeps the target's WRAPPER until
/// delivery, so its expandos survive a collection while the record waits.
pub const RecordQueue = struct {
    allocator: std.mem.Allocator,
    /// The records, unwrapped and OWNED until delivered or taken.
    records: std.ArrayListUnmanaged(*runtime.Instance) = .empty,
    /// The targets the queued records name.
    pending_targets: ReachableNodeSet = .{},

    /// Enqueue `record`, whose target is `target` (`target_base` its tree
    /// node), and hold the target as pending. On failure nothing changed and
    /// the caller still owns the record.
    pub fn enqueue(self: *RecordQueue, record: *runtime.Instance, target: *runtime.Instance, target_base: *NodeBase) error{OutOfMemory}!void {
        try self.records.ensureUnusedCapacity(self.allocator, 1);
        try self.pending_targets.add(self.allocator, target, target_base);
        self.records.appendAssumeCapacity(record);
    }

    /// What `take` hands over: the records (OWNED, as in the queue) and the
    /// pending targets, which the taker lets go once the records are the
    /// script's - after the callback returns, or after takeRecords()'s
    /// sequence is made.
    pub const Taken = struct {
        allocator: std.mem.Allocator,
        records: std.ArrayListUnmanaged(*runtime.Instance) = .empty,
        pending_targets: ReachableNodeSet = .{},

        /// Let the pending targets go and free the list (not the records:
        /// they are delivered).
        pub fn deinit(self: *Taken) void {
            self.pending_targets.deinit(self.allocator);
            self.records.deinit(self.allocator);
        }
    };

    /// Empty the queue into a `Taken` ("let records be a clone of mo's
    /// record queue; empty mo's record queue" - a move, which allocates
    /// nothing).
    pub fn take(self: *RecordQueue) Taken {
        const taken: Taken = .{ .allocator = self.allocator, .records = self.records, .pending_targets = self.pending_targets };
        self.records = .empty;
        self.pending_targets = .{};
        return taken;
    }

    /// Free the records still queued, empty the queue, and let the pending
    /// targets go.
    pub fn freeRecords(self: *RecordQueue) void {
        for (self.records.items) |record| runtime.Instance.deinit(record);
        self.records.clearRetainingCapacity();
        self.pending_targets.releaseAll(self.allocator);
    }

    pub fn deinit(self: *RecordQueue) void {
        self.freeRecords();
        self.records.deinit(self.allocator);
        self.pending_targets.deinit(self.allocator);
    }
};

/// A set of nodes a MutationObserver keeps for script, each held once by a
/// node_holds.ReachableHold (refcount design 2.4's GCReachableRef in shadow
/// mode): WebKit keeps its pending targets as a HashSet<GCReachableRef<Node>>.
///
/// The holds are links in their nodes' chains, so they never move
/// (docs/lessons/architecture-an-intrusive-hold-must-not-move.md): they sit
/// in fixed blocks, allocated as the set grows and freed when it is emptied
/// - a set never filled allocates nothing. Membership is a scan of the
/// entries, after a check of the last one added (the records of one target
/// in a row), and an index once there are more than `index_from`. The set is
/// emptied whole, never entry by entry, so the index has no tombstones.
pub const ReachableNodeSet = struct {
    first: ?*Block = null,
    last_block: ?*Block = null,
    /// Entries taken since the set was last emptied, in blocks of
    /// `block_len`, the last block holding `count % block_len` (or full).
    count: usize = 0,
    /// The entry added last.
    last: ?*Entry = null,
    index: std.AutoHashMapUnmanaged(*runtime.Instance, *Entry) = .empty,

    pub const Entry = node_holds.ReachableHold;
    const block_len = 8;
    const index_from = 16;
    const Block = struct {
        next: ?*Block = null,
        entries: [block_len]Entry = [_]Entry{.{}} ** block_len,
    };

    /// Hold `member` (`base` its tree node) unless the set holds it already.
    /// On failure nothing was added.
    pub fn add(self: *ReachableNodeSet, allocator: std.mem.Allocator, member: *runtime.Instance, base: *NodeBase) error{OutOfMemory}!void {
        if (self.last) |entry| if (entry.holds(member)) return;
        if (self.find(member)) |entry| {
            self.last = entry;
            return;
        }
        if (self.count >= index_from) try self.index.ensureUnusedCapacity(allocator, if (self.count == index_from) index_from + 1 else 1);
        const slot = try self.nextSlot(allocator);
        slot.take(member, base);
        self.count += 1;
        self.last = slot;
        if (self.count > index_from) {
            if (self.count == index_from + 1) {
                var entries = self.iterator();
                while (entries.next()) |entry| if (entry.get()) |node| self.index.putAssumeCapacity(node, entry);
            } else {
                self.index.putAssumeCapacity(member, slot);
            }
        }
    }

    /// Whether the set holds `member`.
    pub fn contains(self: *const ReachableNodeSet, member: *runtime.Instance) bool {
        return self.find(member) != null;
    }

    fn find(self: *const ReachableNodeSet, member: *runtime.Instance) ?*Entry {
        if (self.count > index_from) {
            const entry = self.index.get(member) orelse return null;
            return if (entry.holds(member)) entry else null;
        }
        var entries = self.iterator();
        while (entries.next()) |entry| if (entry.holds(member)) return entry;
        return null;
    }

    /// A free entry at the end, in a new block when the last is full.
    fn nextSlot(self: *ReachableNodeSet, allocator: std.mem.Allocator) error{OutOfMemory}!*Entry {
        const used = self.count % block_len;
        if (self.last_block == null or (used == 0 and self.count != 0)) {
            const block = try allocator.create(Block);
            block.* = .{};
            if (self.last_block) |tail| tail.next = block else self.first = block;
            self.last_block = block;
        }
        return &self.last_block.?.entries[used];
    }

    pub const Iterator = struct {
        block: ?*Block,
        left: usize,
        at: usize = 0,

        pub fn next(self: *Iterator) ?*Entry {
            if (self.left == 0) return null;
            const block = self.block orelse return null;
            const entry = &block.entries[self.at];
            self.left -= 1;
            self.at += 1;
            if (self.at == block_len) {
                self.block = block.next;
                self.at = 0;
            }
            return entry;
        }
    };

    /// The entries in the order they were taken (a node freed under its
    /// entry reads null through `Entry.get`).
    pub fn iterator(self: *const ReachableNodeSet) Iterator {
        return .{ .block = self.first, .left = self.count };
    }

    /// Let every node go and empty the set.
    pub fn releaseAll(self: *ReachableNodeSet, allocator: std.mem.Allocator) void {
        var entries = self.iterator();
        while (entries.next()) |entry| entry.release();
        var block = self.first;
        while (block) |current| {
            block = current.next;
            allocator.destroy(current);
        }
        self.first = null;
        self.last_block = null;
        self.count = 0;
        self.last = null;
        // Freed, not cleared: a large index's metadata memset would cost
        // every later emptying (agent.zig's releaseRecords, CE-S2).
        self.index.clearAndFree(allocator);
    }

    pub fn deinit(self: *ReachableNodeSet, allocator: std.mem.Allocator) void {
        self.releaseAll(allocator);
    }
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: ?Implementation = null;

/// Called by MutationObserver's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// `node` is going away: tell every observer registered on it, then free its
/// registered observer list.
pub fn releaseList(node: *runtime.Instance, list: *infra.List(RegisteredObserver)) void {
    if (implementation) |impl| {
        for (list.items()) |registered| {
            const observer_opaque = handles.mutationObserverToAnyopaque(registered.observer) orelse continue;
            const observer: *runtime.Instance = @ptrCast(@alignCast(observer_opaque));
            impl.node_released(observer, registered.observer_generation, node);
        }
    }
    list.deinit();
}

/// "remove" step 15: a transient registered observer of `observer` now sits
/// in `node`'s registered observer list.
pub fn transientAdded(observer: *runtime.Instance, generation: u64, node: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.transient_added(observer, generation, node);
}

/// "Notify mutation observers" step 6.3: remove all transient registered
/// observers whose observer is `observer`.
pub fn removeTransients(observer: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.remove_transients(observer);
}

/// `observer`'s record queue; null before MutationObserver has installed its
/// steps, when no observer can exist.
pub fn recordQueueOf(observer: *runtime.Instance) ?*RecordQueue {
    const impl = implementation orelse return null;
    return impl.record_queue(observer);
}

/// "Notify mutation observers" step 6.4 for `observer`: see
/// `Implementation.invoke_callback`.
pub fn invokeCallback(observer: *runtime.Instance, records: []const *runtime.Instance) !void {
    const impl = implementation orelse return error.NotSupported;
    return impl.invoke_callback(observer, records);
}
