//! Reference counting for DOM nodes: the types (lane rc12, step 2 of
//! tmp/plans/refcount-design.md; decisions in tmp/plans/refcount-decisions.md).
//!
//! NOTHING IN PRODUCTION USES THIS YET. Steps 3 to 6 run the counts in shadow
//! mode (kept and checked, deciding nothing); step 7 lets them decide.
//!
//! What a node count is, from WebKit (Source/WebCore/dom/Node.h, NodeInlines.h):
//! `NodeBase.rc` holds the count of `Ref`s in units of `NodeBase.rc_one` with
//! bit 0 as the parent bit; a node is born with one reference. Counts are
//! non-atomic: nodes belong to one agent and one thread (design section 4).
//!
//! What differs from WebKit is decision D1: the TREE is the unit. A node in a
//! tree has no count of its own to keep itself alive; a tree is alive while any
//! node in it is held, and a held node is one whose count is not zero.
//! `NodeBase.subtree_holds` counts the held nodes of a node's host-including
//! subtree, itself included, so the root's total says whether any node holds the
//! tree. When it reaches zero the whole tree is garbage and the root goes to the
//! agent's deferred teardown queue (`Ledger.on_garbage`), never freed inline
//! (D8).
//!
//! Four types carry ownership (as `engine.Owned` does at the engine seam,
//! docs/engine-protocol.md section 2):
//!   * `Ref(T)`: one counted reference. It ends with exactly one `release` (or
//!     `take`). `?Ref(T)` is WebKit's RefPtr.
//!   * `GCReachableRef(T)`: a `Ref` that also keeps the node's wrapper
//!     reachable by script, for holders that hand the node to script later
//!     while no wrapper of their own reaches it (WebKit GCReachableRef.h). The
//!     engine reads `Ledger.gcReachable`.
//!   * `WeakRef(T)`: a raw pointer plus the slab generation; `get` is null once
//!     the node was freed or its tree is garbage. Generation checks remain in
//!     Crane only as the implementation of weak references.
//!   * `Ledger`: the agent's books. It is the agent's, not a global: one per
//!     agent, owned by whoever owns the agent.
//!
//! Zig has no destructors and copies `Ref` values, so a value-side flag cannot
//! catch two releases. In Debug builds every `Ref` carries an id the ledger
//! issued, and a second release of the same id is a violation; outstanding ids
//! at `Ledger.finish` are leaks. Violations are fatal in unit tests and
//! logged and counted elsewhere (decision D9: "logged and counted like crashes"
//! in WPT sweeps, so a sweep's report can show them).

const std = @import("std");
const builtin = @import("builtin");
const runtime = @import("runtime");
const NodeBase = @import("node_base.zig").NodeBase;

const log = std.log.scoped(.refcount);

/// The Debug bookkeeping (ids, entries, stacks) exists only in Debug builds.
/// Everything else - underflow, ref on a garbage node, the thread check in
/// Debug - works in every mode.
pub const tracking = builtin.mode == .Debug;

/// What a violation does.
pub const Mode = enum {
    /// Panic at the violation: unit tests.
    fatal,
    /// Log it, count it in `Ledger.violations`, and make the operation a
    /// no-op: WPT sweeps, where a violation is reported like a crash.
    log,
};

pub const Kind = enum { ref, gc_reachable_ref };

/// A trees whose total reached zero: the root, flagged `garbage`. The sink
/// queues it for teardown between tasks (defertd's `DeferredTeardown`); it
/// must not free anything, and must not run script.
pub const GarbageSink = struct {
    context: ?*anyopaque = null,
    push: *const fn (context: ?*anyopaque, root: *NodeBase) void,
};

/// The parent of a parentless node that is a shadow root or a template's
/// contents: its host. Null for any other root. The chain of a node's
/// host-including ancestors is parent, else host (design section 1.4).
pub const HostOf = *const fn (root: *NodeBase) ?*NodeBase;

/// Told when a node's GC-reachable count goes between zero and not zero, so the
/// engine can keep or release the node's wrapper (the counted
/// `keepPlatformObjectAlive` of design section 2.3).
pub const GcReachableObserver = struct {
    context: ?*anyopaque = null,
    changed: *const fn (context: ?*anyopaque, node: *NodeBase, reachable: bool) void,
};

pub const Options = struct {
    /// Defaults to `.fatal` in a test binary and `.log` otherwise.
    mode: Mode = if (builtin.is_test) .fatal else .log,
    /// Capture the acquisition stack of every `Ref` so a leak report can print
    /// it (WebKit `trackForDebugging`; the design's `-Drefcount-trace`, as a
    /// runtime option: the host that makes the agent decides). Debug builds only.
    trace: bool = false,
    on_garbage: ?GarbageSink = null,
    host_of: ?HostOf = null,
    gc_reachable_observer: ?GcReachableObserver = null,
    /// Where `.log` mode's messages go; null logs them as errors through
    /// `std.log` (scope `.refcount`). A unit test that provokes a violation
    /// passes a quiet reporter: an error log fails a test.
    report: ?*const fn (message: []const u8) void = null,
};

const trace_depth = 12;

const Entry = struct {
    node: *NodeBase,
    kind: Kind,
    addresses: [trace_depth]usize = [_]usize{0} ** trace_depth,
    address_count: usize = 0,
};

pub const Ledger = struct {
    gpa: std.mem.Allocator,
    options: Options,
    /// The thread of the agent that owns this ledger and every node counted in it.
    thread: std.Thread.Id,
    /// Violations seen (in `.log` mode; in `.fatal` mode the first one panics).
    violations: u64 = 0,
    /// A garbage tree that a re-check found held again (design 1.4 step 2).
    resurrections: u64 = 0,
    finished: bool = false,
    /// Debug: ids issued, and the references outstanding.
    next_id: if (tracking) u64 else void = if (tracking) 1 else {},
    entries: if (tracking) std.AutoHashMapUnmanaged(u64, Entry) else void = if (tracking) .empty else {},
    /// The counted set of GC-reachable nodes (WebKit's `GCReachableRefMap` is a
    /// `HashCountedSet`).
    gc_reachable: std.AutoHashMapUnmanaged(*NodeBase, u32) = .empty,

    pub fn init(gpa: std.mem.Allocator, options: Options) Ledger {
        return .{ .gpa = gpa, .options = options, .thread = std.Thread.getCurrentId() };
    }

    /// Ends the books: returns the number of references still outstanding
    /// (leaks, each logged with its acquisition stack when tracing; Debug builds
    /// only, 0 elsewhere) and frees the ledger. A leak is a violation: fatal in
    /// `.fatal` mode.
    pub fn finish(self: *Ledger) usize {
        if (self.finished) return 0;
        self.finished = true;
        var leaks: usize = 0;
        if (tracking) {
            var it = self.entries.iterator();
            while (it.next()) |item| {
                leaks += 1;
                self.logEntry("leaked reference", item.value_ptr.*);
            }
            self.entries.deinit(self.gpa);
        }
        self.gc_reachable.deinit(self.gpa);
        if (leaks > 0) self.violation("{d} counted reference(s) outstanding at the end of the agent", .{leaks});
        return leaks;
    }

    /// Counted references not yet released (Debug builds; 0 elsewhere).
    pub fn outstanding(self: *const Ledger) usize {
        if (!tracking) return 0;
        return self.entries.count();
    }

    /// Whether any `GCReachableRef` holds `node`: the engine keeps such a
    /// node's wrapper reachable (WebKit `GCReachableRefMap::contains`).
    pub fn gcReachable(self: *const Ledger, node: *NodeBase) bool {
        return self.gc_reachable.contains(node);
    }

    fn violation(self: *Ledger, comptime fmt: []const u8, args: anytype) void {
        self.violations += 1;
        switch (self.options.mode) {
            .fatal => std.debug.panic("refcount: " ++ fmt, args),
            .log => self.say("refcount: " ++ fmt, args),
        }
    }

    /// One line to `options.report`, or to the error log.
    fn say(self: *Ledger, comptime fmt: []const u8, args: anytype) void {
        if (self.options.report) |report| {
            var buffer: [512]u8 = undefined;
            const message = std.fmt.bufPrint(&buffer, fmt, args) catch buffer[0..];
            report(message);
        } else {
            log.err(fmt, args);
        }
    }

    fn logEntry(self: *Ledger, what: []const u8, entry: Entry) void {
        self.say("{s}: node {*} ({s})", .{ what, entry.node, @tagName(entry.kind) });
        if (entry.address_count > 0) {
            self.say("  acquired at (resolve with atos):", .{});
            for (entry.addresses[0..entry.address_count]) |address| self.say("    0x{x}", .{address});
        }
    }

    fn checkThread(self: *Ledger) void {
        if (!tracking) return;
        if (std.Thread.getCurrentId() != self.thread) {
            self.violation("a reference was taken or released on a thread other than its agent's", .{});
        }
    }

    // ---- Debug ids ------------------------------------------------------

    fn issue(self: *Ledger, node: *NodeBase, kind: Kind, first_address: usize) if (tracking) u64 else void {
        if (!tracking) return;
        const id = self.next_id;
        self.next_id += 1;
        var entry: Entry = .{ .node = node, .kind = kind };
        if (self.options.trace) {
            var buffer: [trace_depth]usize = undefined;
            const trace = std.debug.captureCurrentStackTrace(.{ .first_address = first_address }, &buffer);
            const n = @min(trace.return_addresses.len, trace_depth);
            @memcpy(entry.addresses[0..n], trace.return_addresses[0..n]);
            entry.address_count = n;
        }
        self.entries.put(self.gpa, id, entry) catch @panic("refcount ledger: out of memory");
        return id;
    }

    /// Ends `id`'s entry. False when it was not outstanding: a second release
    /// of one reference (already reported).
    fn retire(self: *Ledger, id: if (tracking) u64 else void, node: *NodeBase) bool {
        if (!tracking) return true;
        if (id == 0) {
            self.violation("released a Ref that was moved out or never acquired (node {*})", .{node});
            return false;
        }
        const removed = self.entries.fetchRemove(id) orelse {
            self.violation("a Ref was released twice (id {d}, node {*})", .{ id, node });
            return false;
        };
        if (removed.value.node != node) {
            self.violation("a Ref's id {d} belongs to node {*}, released on node {*}", .{ id, removed.value.node, node });
            return false;
        }
        return true;
    }
};

// ============================================================================
// The count word
// ============================================================================

/// The number of references held on `node` (WebKit `Node::refCount`), not
/// counting the parent bit.
pub fn count(node: *const NodeBase) u32 {
    return node.rc / NodeBase.rc_one;
}

/// Whether `node` has a parent, as the parent bit says. Step 3 keeps the bit in
/// step with `parent_node`; until then it is false.
pub fn hasParentBit(node: *const NodeBase) bool {
    return node.rc & NodeBase.rc_parent_bit != 0;
}

/// Sets the parent bit (WebKit `Node::setParentNode`): the one write of it.
pub fn setParentBit(node: *NodeBase, has_parent: bool) void {
    node.rc = (node.rc & ~NodeBase.rc_parent_bit) | @intFromBool(has_parent);
}

/// Whether `node` is held: its count is not zero.
pub fn isHeld(node: *const NodeBase) bool {
    return count(node) != 0;
}

/// The host-including parent: the parent, else the host of a shadow root or a
/// template's contents, else null.
fn up(ledger: *const Ledger, node: *NodeBase) ?*NodeBase {
    if (node.parent_node) |parent| return parent;
    if (ledger.options.host_of) |host_of| return host_of(node);
    return null;
}

/// The root of `node`'s host-including tree.
pub fn root(ledger: *const Ledger, node: *NodeBase) *NodeBase {
    var current = node;
    while (up(ledger, current)) |next| current = next;
    return current;
}

/// Adds `delta` to `subtree_holds` of `start` and of each of its host-including
/// ancestors, and returns the root reached. The walk is O(depth). A total that
/// would leave 0..u32 max is a violation (and the walk stops: the counts are
/// already wrong).
fn walkAdd(ledger: *Ledger, start: *NodeBase, delta: i64) *NodeBase {
    var current = start;
    while (true) {
        const next_total = @as(i64, current.subtree_holds) + delta;
        if (next_total < 0 or next_total > std.math.maxInt(u32)) {
            ledger.violation("subtree_holds of node {*} would become {d}", .{ current, next_total });
            return current;
        }
        current.subtree_holds = @intCast(next_total);
        current = up(ledger, current) orelse return current;
    }
}

/// A tree whose root's total is zero is garbage: flag the root and hand it to
/// the sink, once (a flagged root is queued already).
fn settleRoot(ledger: *Ledger, tree_root: *NodeBase) void {
    if (tree_root.subtree_holds != 0) return;
    if (tree_root.parent_node != null) return;
    if (tree_root.rc_flags.garbage) return;
    tree_root.rc_flags.garbage = true;
    if (ledger.options.on_garbage) |sink| sink.push(sink.context, tree_root);
}

// ============================================================================
// ref, deref, moves
// ============================================================================

fn refusedOn(ledger: *Ledger, node: *NodeBase, what: []const u8) bool {
    if (node.rc_flags.garbage) {
        ledger.violation("{s} on node {*}, the root of a garbage tree", .{ what, node });
        return true;
    }
    if (node.rc_flags.destroying) {
        ledger.violation("{s} on node {*} during its teardown", .{ what, node });
        return true;
    }
    return false;
}

/// Takes one reference on `node` (WebKit `Node::ref`). A count going from zero
/// to one makes the node a hold: `subtree_holds` rises along its
/// host-including ancestors. The caller wraps the result in a `Ref`.
pub fn ref(ledger: *Ledger, node: *NodeBase) void {
    ledger.checkThread();
    if (refusedOn(ledger, node, "ref")) return;
    if (node.rc > std.math.maxInt(u32) - NodeBase.rc_one) {
        ledger.violation("the reference count of node {*} overflowed", .{node});
        return;
    }
    const was_held = isHeld(node);
    node.rc += NodeBase.rc_one;
    if (!was_held) _ = walkAdd(ledger, node, 1);
}

/// Drops one reference (WebKit `Node::deref`). Underflow is a violation. The
/// count reaching zero ends a hold: `subtree_holds` falls along the
/// host-including ancestors, and a root whose total reaches zero is garbage and
/// goes to the sink. Nothing is freed here.
pub fn deref(ledger: *Ledger, node: *NodeBase) void {
    ledger.checkThread();
    if (!isHeld(node)) {
        ledger.violation("deref of node {*} whose count is zero", .{node});
        return;
    }
    node.rc -= NodeBase.rc_one;
    if (isHeld(node)) return;
    settleRoot(ledger, walkAdd(ledger, node, -1));
}

/// A subtree moved: its `subtree_holds` leaves `from`'s chain and joins `to`'s
/// (insertion: `from` null; removal: `to` null; a move: both). The caller has
/// already linked or unlinked the subtree's root (and set the parent bit).
///
/// A subtree that holds nothing - the parse and innerHTML case - changes no
/// chain's total, and costs nothing; removed (`to` null) it is a tree nothing
/// holds, so it is garbage at once (design 5.2, "Remove a subtree": this frees
/// innerHTML garbage). A chain whose root's total falls to zero is garbage.
pub fn moveHolds(ledger: *Ledger, subtree_root: *NodeBase, from: ?*NodeBase, to: ?*NodeBase) void {
    ledger.checkThread();
    const holds = subtree_root.subtree_holds;
    if (holds == 0) {
        if (to == null) settleRoot(ledger, subtree_root);
        return;
    }
    const delta: i64 = holds;
    if (from) |old| settleRoot(ledger, walkAdd(ledger, old, -delta));
    if (to) |new| _ = walkAdd(ledger, new, delta);
}

/// A garbage root's re-check at slice time (design 1.4 step 2): whether it is
/// still garbage. A root that is no longer parentless or whose total is not zero
/// is a resurrection: the flag is cleared and the root dropped from the queue; a
/// bug in Debug unless `allowed` (a caller on the allowlist).
pub fn recheck(ledger: *Ledger, garbage_root: *NodeBase, allowed: bool) bool {
    if (garbage_root.parent_node == null and garbage_root.subtree_holds == 0) return true;
    garbage_root.rc_flags.garbage = false;
    ledger.resurrections += 1;
    if (tracking and !allowed) ledger.violation("garbage tree {*} was held again before its teardown", .{garbage_root});
    return false;
}

/// Marks `node` as being torn down: a `Ref` or `ref` on it is a violation from
/// here on (WebKit `applyRefDuringDestructionCheck`).
pub fn beginDestroy(node: *NodeBase) void {
    node.rc_flags.destroying = true;
}

// ============================================================================
// Ref, GCReachableRef, WeakRef
// ============================================================================

fn nodeBaseOf(comptime T: type, ptr: *T) *NodeBase {
    if (T == NodeBase) return ptr;
    return @ptrCast(ptr);
}

fn assertNodeLike(comptime T: type) void {
    if (T == NodeBase) return;
    const info = @typeInfo(T);
    if (info != .@"struct" or info.@"struct".fields.len == 0 or info.@"struct".fields[0].type != NodeBase) {
        @compileError("Ref(" ++ @typeName(T) ++ "): a counted type is NodeBase or a node struct with NodeBase as its first field");
    }
}

/// One counted reference to a node (WebKit `Ref<T>`/`RefPtr<T>`; `?Ref(T)` is
/// the RefPtr). It ends with exactly one `release` or `take`; Zig copies it, so
/// a copy that outlives a release is a bug the ledger finds in Debug.
pub fn Ref(comptime T: type) type {
    comptime assertNodeLike(T);
    return struct {
        const Self = @This();

        ptr: *T,
        id: if (tracking) u64 else void,

        /// Adopts the reference `ptr` was born with (WebKit `adoptRef`): the
        /// count is unchanged. Exactly one adoption per node birth.
        pub fn adopt(ledger: *Ledger, ptr: *T) Self {
            ledger.checkThread();
            return .{ .ptr = ptr, .id = ledger.issue(nodeBaseOf(T, ptr), .ref, @returnAddress()) };
        }

        /// Takes a new reference to `ptr`.
        pub fn retain(ledger: *Ledger, ptr: *T) Self {
            ref(ledger, nodeBaseOf(T, ptr));
            return .{ .ptr = ptr, .id = ledger.issue(nodeBaseOf(T, ptr), .ref, @returnAddress()) };
        }

        /// Another reference to the same node.
        pub fn clone(self: Self, ledger: *Ledger) Self {
            return retain(ledger, self.ptr);
        }

        pub fn get(self: Self) *T {
            return self.ptr;
        }

        /// Ends this reference. `self` must not be used afterwards.
        pub fn release(self: *Self, ledger: *Ledger) void {
            const node = nodeBaseOf(T, self.ptr);
            const live = ledger.retire(self.id, node);
            if (tracking) self.id = 0;
            if (live) deref(ledger, node);
        }

        /// Hands the reference to code that holds it without a `Ref`: the
        /// ledger forgets it, the count is unchanged, and the caller owns
        /// ending it with `deref`.
        pub fn take(self: *Self, ledger: *Ledger) *T {
            const node = nodeBaseOf(T, self.ptr);
            _ = ledger.retire(self.id, node);
            if (tracking) self.id = 0;
            return self.ptr;
        }
    };
}

/// A `Ref` that also keeps the node's wrapper reachable by script
/// (WebKit `GCReachableRef<T>`): for tasks, pending mutation targets and
/// custom element reaction queues, holders that will hand the node to script
/// while no wrapper of their own reaches it. The node joins the ledger's
/// counted GC-reachable set, which the engine reads.
pub fn GCReachableRef(comptime T: type) type {
    return struct {
        const Self = @This();

        ref: Ref(T),

        pub fn retain(ledger: *Ledger, ptr: *T) error{OutOfMemory}!Self {
            const node = nodeBaseOf(T, ptr);
            const slot = try ledger.gc_reachable.getOrPut(ledger.gpa, node);
            const first = !slot.found_existing;
            if (first) slot.value_ptr.* = 0;
            const held = Ref(T).retain(ledger, ptr);
            // The ledger's entry kind says what to report on a leak.
            if (tracking) if (ledger.entries.getPtr(held.id)) |entry| {
                entry.kind = .gc_reachable_ref;
            };
            slot.value_ptr.* += 1;
            if (first) if (ledger.options.gc_reachable_observer) |observer| observer.changed(observer.context, node, true);
            return .{ .ref = held };
        }

        pub fn get(self: Self) *T {
            return self.ref.ptr;
        }

        pub fn release(self: *Self, ledger: *Ledger) void {
            const node = nodeBaseOf(T, self.ref.ptr);
            if (ledger.gc_reachable.getPtr(node)) |held| {
                held.* -= 1;
                if (held.* == 0) {
                    _ = ledger.gc_reachable.remove(node);
                    if (ledger.options.gc_reachable_observer) |observer| observer.changed(observer.context, node, false);
                }
            } else {
                ledger.violation("a GCReachableRef released on node {*}, which is in no GC-reachable set", .{node});
            }
            self.ref.release(ledger);
        }
    };
}

/// A weak reference: a raw pointer plus the slab generation of the node's
/// Instance when it was taken. `get` is null once the node was freed (or its
/// slot reissued) and for a node in a garbage tree. A registry that must not
/// keep its node alive uses this where it cannot unregister at the node's
/// removal (design 1.3).
pub fn WeakRef(comptime T: type) type {
    comptime assertNodeLike(T);
    return struct {
        const Self = @This();

        ptr: *T,
        instance: *const runtime.Instance,
        generation: u64,

        /// Null for a NodeBase with no owning Instance (built outside the
        /// WebIDL layer): it has no generation to compare.
        pub fn of(ptr: *T) ?Self {
            const owner = nodeBaseOf(T, ptr).owner_instance orelse return null;
            const instance: *const runtime.Instance = @ptrCast(@alignCast(owner));
            return .{ .ptr = ptr, .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
        }

        /// The node, or null when it is gone. O(depth): the garbage flag is
        /// on the tree's root.
        pub fn get(self: Self, ledger: *const Ledger) ?*T {
            if (runtime.SlabAllocator.generationOf(self.instance) != self.generation) return null;
            if (root(ledger, nodeBaseOf(T, self.ptr)).rc_flags.garbage) return null;
            return self.ptr;
        }
    };
}

// ============================================================================
// Tests: the count word, holds, garbage. The types' own tests live in
// tests/dom/refcount_test.zig (they need real nodes and the slab).
// ============================================================================

test "the parent bit and the count are independent" {
    var node: NodeBase = undefined;
    node.rc = NodeBase.rc_one;
    try std.testing.expectEqual(@as(u32, 1), count(&node));
    try std.testing.expect(!hasParentBit(&node));
    setParentBit(&node, true);
    try std.testing.expectEqual(@as(u32, 1), count(&node));
    try std.testing.expect(hasParentBit(&node));
    setParentBit(&node, false);
    try std.testing.expectEqual(NodeBase.rc_one, node.rc);
}
