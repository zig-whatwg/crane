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
const interfaces = @import("interfaces");
const instance_bridge = @import("instance_bridge.zig");
const process_start = @import("process_start.zig");
const shadow_hosts = @import("shadow_hosts.zig");
const template_contents = @import("template_contents.zig");

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
/// template's contents, else null. A ledger's `host_of` (hand-linked trees in
/// tests) answers first; in the DOM a parentless node with a live host is
/// flagged `hosted`, and only those pay the host lookup.
fn up(ledger: ?*const Ledger, node: *NodeBase) ?*NodeBase {
    if (node.parent_node) |parent| return parent;
    if (ledger) |books| if (books.options.host_of) |host_of| return host_of(node);
    if (!node.rc_flags.hosted) return null;
    return hostOf(node);
}

/// The live host of a `hosted` node, through the hook modules that own the
/// two links (dom.template_contents answers for shadow roots too).
fn hostOf(node: *NodeBase) ?*NodeBase {
    const raw = node.owner_instance orelse return null;
    const instance: *runtime.Instance = @ptrCast(@alignCast(raw));
    const host = template_contents.host(instance) orelse return null;
    return instance_bridge.getNodeBase(host);
}

/// The root of `node`'s host-including tree.
pub fn root(ledger: ?*const Ledger, node: *NodeBase) *NodeBase {
    var current = node;
    while (up(ledger, current)) |next| current = next;
    return current;
}

/// Adds `delta` to `subtree_holds` of `start` and of each of its host-including
/// ancestors, and returns the root reached. The walk is O(depth). A total that
/// would leave 0..u32 max is a violation (and the walk stops: the counts are
/// already wrong).
fn walkAdd(ledger: ?*Ledger, start: *NodeBase, delta: i64) *NodeBase {
    var current = start;
    while (true) {
        const next_total = @as(i64, current.subtree_holds) + delta;
        if (next_total < 0 or next_total > std.math.maxInt(u32)) {
            violate(ledger, "subtree_holds of node {*} would become {d}", .{ current, next_total });
            return current;
        }
        current.subtree_holds = @intCast(next_total);
        current = up(ledger, current) orelse return current;
    }
}

/// A violation: the ledger's (fatal or logged), or - for the tree links, which
/// run in production with no ledger yet - an error log, which fails a unit
/// test and is counted in a WPT run's output.
fn violate(ledger: ?*Ledger, comptime fmt: []const u8, args: anytype) void {
    if (ledger) |books| return books.violation(fmt, args);
    log.err("refcount: " ++ fmt, args);
}

/// A tree whose root's total is zero is garbage: flag the root and hand it to
/// the sink, once (a flagged root is queued already).
fn settleRoot(ledger: *Ledger, tree_root: *NodeBase) void {
    if (tree_root.subtree_holds != 0) return;
    if (tree_root.parent_node != null) return;
    if (tree_root.rc_flags.hosted) return;
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
    if (!was_held) adjustForeign(walkAdd(ledger, node, 1), 1);
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
    const tree_root = walkAdd(ledger, node, -1);
    adjustForeign(tree_root, -1);
    settleRoot(ledger, tree_root);
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
// The Document's two counts (decision D6, design 1.5)
// ============================================================================

/// What a Document counts beside its own node (design 1.5). They live in the
/// Document's state, not in NodeBase; the Document impl hands them out
/// through `installDocument`.
pub const DocumentCounts = struct {
    /// The nodes whose node document this is, the document itself excluded:
    /// up at a node's first node document and at adoption in, down at its
    /// free and at adoption out (WebKit `Document::m_referencingNodeCount`).
    /// The document's storage may go only at zero; step 7 makes its free wait
    /// for it (this step keeps it, and frees nothing differently).
    referencing_nodes: u32 = 0,
    /// The holds in this document's detached trees: the sum of the totals of
    /// every parentless, unhosted node of it other than itself (a node
    /// flagged `foreign`). A document's tree is garbage only when its own
    /// total and this are both zero: a held detached node keeps its
    /// document's tree (Blink; decision D6).
    foreign_holds: u32 = 0,
};

/// What the owners supply: the Document impl its counts, the Node impl the
/// counts of a node's live node document (it keeps the document's slab
/// generation beside the pointer, so a document freed under its node reads
/// as none, without the ownerDocument getter's warning).
pub const Hooks = struct {
    document_counts: ?*const fn (document: *runtime.Instance) ?*DocumentCounts = null,
    node_document_counts: ?*const fn (node: *runtime.Instance) ?*DocumentCounts = null,
};

// process-wide: the Document and Node impls' accessors for the counts - the same functions for every Browser, installed only at process start (process_start.zig)
var hooks: Hooks = .{};

/// Called by Document's and Node's installHooks, once each, at process
/// start; each installs only its own entry.
pub fn install(owned: Hooks) void {
    process_start.assertInstalling();
    inline for (@typeInfo(Hooks).@"struct".fields) |field| {
        if (@field(owned, field.name)) |accessor| @field(hooks, field.name) = accessor;
    }
}

/// `document`'s counts, or null for an instance that is not a live Document
/// (or before the Document impl installed its hook).
pub fn documentCounts(document: *runtime.Instance) ?*DocumentCounts {
    const accessor = hooks.document_counts orelse return null;
    return accessor(document);
}

/// The counts of the Document whose own node `document` is. The caller knows
/// it is alive: it is a root it just walked to, or a node in its tree.
fn countsOfDocumentNode(document: *NodeBase) ?*DocumentCounts {
    const raw = document.owner_instance orelse return null;
    return documentCounts(@ptrCast(@alignCast(raw)));
}

/// The counts of `node`'s node document, through the Node impl's accessor,
/// which answers none for a document freed under its node (the slab
/// generation it keeps; lane ownerdoc) rather than read freed memory.
fn countsOfNodeDocument(node: *NodeBase) ?*DocumentCounts {
    if (node.node_type == NodeBase.DOCUMENT_NODE) return countsOfDocumentNode(node);
    const raw = node.owner_instance orelse return null;
    const accessor = hooks.node_document_counts orelse return null;
    return accessor(@ptrCast(@alignCast(raw)));
}

fn addTo(field: *u32, delta: i64, what: []const u8) void {
    const next = @as(i64, field.*) + delta;
    if (next < 0 or next > std.math.maxInt(u32)) {
        violate(null, "a document's {s} would become {d}", .{ what, next });
        return;
    }
    field.* = @intCast(next);
}

/// `tree_root`'s total changed by `delta`: when it is a detached root, its
/// document's foreign holds change with it.
fn adjustForeign(tree_root: *NodeBase, delta: i64) void {
    if (delta == 0 or !tree_root.rc_flags.foreign) return;
    const document = countsOfNodeDocument(tree_root) orelse return;
    addTo(&document.foreign_holds, delta, "foreign_holds");
}

/// Whether `node` may be a detached root that counts in its document: not a
/// Document, and named by one.
fn countsAsForeign(node: *const NodeBase) bool {
    return node.node_type != NodeBase.DOCUMENT_NODE and node.owner_document != null;
}

// ============================================================================
// Tree links (design section 7, step 3): every parent and host link, with the
// holds it moves. SHADOW MODE: no ledger, no garbage sink - the counts are
// kept and checked, and decide nothing until step 7.
// ============================================================================

/// Insertion (DOM insert 7, append, the batch inserts): `node`, a root, is
/// linked under `parent`. Its holds leave its document's foreign holds and
/// join `parent`'s chain (and that chain's document's foreign holds, when it
/// ends at a detached root). The caller has linked the sibling and child
/// lists; this is the parent write.
pub fn linkChild(node: *NodeBase, parent: *NodeBase) void {
    if (node.parent_node != null) violate(null, "linkChild: node {*} already has a parent", .{node});
    if (node.rc_flags.hosted) violate(null, "linkChild: node {*} is a shadow root or template contents", .{node});
    const holds = node.subtree_holds;
    const was_foreign = node.rc_flags.foreign;
    node.rc_flags.foreign = false;
    node.setParent(parent);
    if (holds == 0) return;
    const delta: i64 = holds;
    const tree_root = walkAdd(null, parent, delta);
    // Within one document's detached trees, a move changes nothing there.
    if (was_foreign and tree_root.rc_flags.foreign and node.owner_document == tree_root.owner_document) return;
    if (was_foreign) {
        const document = if (isNodeDocumentOf(node, tree_root)) countsOfDocumentNode(tree_root) else countsOfNodeDocument(node);
        if (document) |counts| addTo(&counts.foreign_holds, -delta, "foreign_holds");
    }
    adjustForeign(tree_root, delta);
}

/// Removal (DOM remove 7): `node` leaves its parent and is the root of a
/// detached tree of its document from here on. Its holds leave the old
/// parent's chain and count in its document's foreign holds.
pub fn unlinkChild(node: *NodeBase) void {
    const parent = node.parent_node orelse {
        violate(null, "unlinkChild: node {*} has no parent", .{node});
        return;
    };
    const holds = node.subtree_holds;
    node.setParent(null);
    const foreign = countsAsForeign(node);
    node.rc_flags.foreign = foreign;
    if (holds == 0) return;
    const delta: i64 = holds;
    const tree_root = walkAdd(null, parent, -delta);
    if (foreign and tree_root.rc_flags.foreign and node.owner_document == tree_root.owner_document) return;
    adjustForeign(tree_root, -delta);
    if (!foreign) return;
    const document = if (isNodeDocumentOf(node, tree_root)) countsOfDocumentNode(tree_root) else countsOfNodeDocument(node);
    if (document) |counts| addTo(&counts.foreign_holds, delta, "foreign_holds");
}

/// Move (DOM move 19-20): `node`, still linked to its old parent, goes under
/// `new_parent` in the same tree (move requires one shadow-including root).
/// The new chain gains first, so no total passes through zero on the way.
pub fn moveChild(node: *NodeBase, new_parent: *NodeBase) void {
    const old_parent = node.parent_node orelse {
        violate(null, "moveChild: node {*} has no parent", .{node});
        return;
    };
    node.setParent(new_parent);
    const holds = node.subtree_holds;
    if (holds == 0 or old_parent == new_parent) return;
    const delta: i64 = holds;
    const new_root = walkAdd(null, new_parent, delta);
    const old_root = walkAdd(null, old_parent, -delta);
    if (new_root != old_root) {
        adjustForeign(new_root, delta);
        adjustForeign(old_root, -delta);
    }
}

/// A dying tree's teardown unlinks a child (dom.tree_teardown): the pointer
/// and the bit only. The tree's holds stay on its root, which takes them out
/// of its document's foreign holds when it is freed itself (`nodeFreed`).
pub fn unlinkForTeardown(node: *NodeBase) void {
    node.setParent(null);
}

/// A shadow root is attached to `host`, or a template's contents get their
/// template (`root` is parentless): its holds join the host's chain.
pub fn hostAttached(hosted_root: *NodeBase, host: *NodeBase) void {
    if (hosted_root.parent_node != null) violate(null, "hostAttached: node {*} has a parent", .{hosted_root});
    const holds = hosted_root.subtree_holds;
    const was_foreign = hosted_root.rc_flags.foreign;
    hosted_root.rc_flags.foreign = false;
    hosted_root.rc_flags.hosted = true;
    if (holds == 0) return;
    const delta: i64 = holds;
    if (was_foreign) if (countsOfNodeDocument(hosted_root)) |counts| addTo(&counts.foreign_holds, -delta, "foreign_holds");
    adjustForeign(walkAdd(null, host, delta), delta);
}

/// The host of a shadow root or of a template's contents is torn down, and
/// `hosted_root` lives on as a detached root of its document. The host's
/// dying tree keeps its total until its root is freed (`nodeFreed` takes it
/// out there, this root's holds included), so nothing walks the host's
/// chain; this root's holds count in its document from now on.
pub fn hostGone(hosted_root: *NodeBase) void {
    if (!hosted_root.rc_flags.hosted) return;
    hosted_root.rc_flags.hosted = false;
    const foreign = countsAsForeign(hosted_root);
    hosted_root.rc_flags.foreign = foreign;
    if (!foreign or hosted_root.subtree_holds == 0) return;
    if (countsOfNodeDocument(hosted_root)) |counts| addTo(&counts.foreign_holds, hosted_root.subtree_holds, "foreign_holds");
}

/// `node`'s node document changes from the one counted by `old` to the one
/// counted by `new` (a node's first document, and adopt): it moves its
/// reference, and - a detached root - its holds. Null counts are a document
/// already freed, or none.
pub fn nodeDocumentChanged(node: *NodeBase, old: ?*DocumentCounts, new: ?*DocumentCounts) void {
    if (node.node_type == NodeBase.DOCUMENT_NODE) return;
    if (old) |counts| addTo(&counts.referencing_nodes, -1, "referencing_nodes");
    if (new) |counts| addTo(&counts.referencing_nodes, 1, "referencing_nodes");
    if (node.parent_node != null or node.rc_flags.hosted) return;
    const holds: i64 = node.subtree_holds;
    if (node.rc_flags.foreign) if (old) |counts| addTo(&counts.foreign_holds, -holds, "foreign_holds");
    node.rc_flags.foreign = new != null;
    if (new) |counts| addTo(&counts.foreign_holds, holds, "foreign_holds");
}

/// `node` is freed, and `counts` are its node document's (null when that
/// document is gone): its reference ends, and a detached root's holds - its
/// whole tree's, which goes with it - leave the foreign holds.
pub fn nodeFreed(node: *NodeBase, counts: ?*DocumentCounts) void {
    if (node.node_type == NodeBase.DOCUMENT_NODE) return;
    const document = counts orelse return;
    addTo(&document.referencing_nodes, -1, "referencing_nodes");
    if (node.rc_flags.foreign) addTo(&document.foreign_holds, -@as(i64, node.subtree_holds), "foreign_holds");
    node.rc_flags.foreign = false;
}

/// Whether `tree_root` is `node`'s node document (a pointer compare: no read
/// through `owner_document`).
fn isNodeDocumentOf(node: *const NodeBase, tree_root: *const NodeBase) bool {
    return tree_root.node_type == NodeBase.DOCUMENT_NODE and @intFromPtr(node.owner_document) == @intFromPtr(tree_root);
}

// ============================================================================
// Shadow-mode checks: the counts' invariants, after every mutation
// ============================================================================

// process-wide: a diagnostic switch, set once by the WPT runner from CRANE_REFCOUNT_CHECK before any page runs; it changes no behaviour, only whether mutations check the counts
var tree_checks_requested: bool = false;

/// Turn the after-mutation checks on outside unit tests (the WPT runner's
/// `CRANE_REFCOUNT_CHECK=1`).
pub fn enableTreeChecks() void {
    tree_checks_requested = true;
}

/// Whether mutations check the counts: always in unit tests, and when a
/// runner asked for it.
pub inline fn treeChecksOn() bool {
    return builtin.is_test or tree_checks_requested;
}

pub const CheckError = error{ ParentBitMismatch, SubtreeHoldsMismatch, FlagMismatch };

/// A node's children are summed only up to this many: the after-mutation
/// check stays O(depth x fan-out) on a wide tree (verifyTree has no limit).
const check_fanout = 256;

/// After a mutation at `node`: check `node` and every host-including
/// ancestor (each against its children's totals). A violation is logged as
/// an error, which fails a unit test and is counted in a WPT run.
pub fn checkAround(node: *NodeBase) void {
    var current: ?*NodeBase = node;
    while (current) |at| : (current = up(null, at)) {
        checkNode(at, check_fanout) catch |err| {
            log.err("refcount: {s} at node {*} ({s}) after a mutation", .{ @errorName(err), at, at.node_name });
            return;
        };
    }
}

/// Check every node of `tree_root`'s host-including subtree (tests).
pub fn verifyTree(tree_root: *NodeBase) CheckError!void {
    try checkNode(tree_root, std.math.maxInt(usize));
    var child = tree_root.first_child;
    while (child) |at| : (child = at.next_sibling) try verifyTree(at);
    var hosted: [2]?*NodeBase = undefined;
    for (hostedRootsOf(tree_root, &hosted)) |maybe| if (maybe) |hosted_root| try verifyTree(hosted_root);
}

/// The shadow root and the template contents `node` hosts.
fn hostedRootsOf(node: *NodeBase, out: *[2]?*NodeBase) []?*NodeBase {
    out.* = .{ null, null };
    const raw = node.owner_instance orelse return out[0..0];
    const instance: *runtime.Instance = @ptrCast(@alignCast(raw));
    if (node.is_shadow_host) {
        if (shadow_hosts.rootForHost(instance)) |shadow| out[0] = instance_bridge.getNodeBase(shadow);
    }
    if (instance.stateAs(interfaces.HTMLTemplateElement.State) != null) {
        if (template_contents.contentOf(instance)) |content| out[1] = instance_bridge.getNodeBase(content);
    }
    return out[0..2];
}

fn checkNode(node: *NodeBase, fanout: usize) CheckError!void {
    if (hasParentBit(node) != (node.parent_node != null)) return error.ParentBitMismatch;
    if (node.rc_flags.hosted and node.parent_node != null) return error.FlagMismatch;
    if (node.rc_flags.foreign and (node.parent_node != null or node.rc_flags.hosted or !countsAsForeign(node))) return error.FlagMismatch;
    // A detached root of a document is counted there - for a node made
    // through the WebIDL layer, whose node document is set through
    // Node.setOwnerDocument (a NodeBase built outside it has no counts).
    if (node.owner_instance != null and node.parent_node == null and !node.rc_flags.hosted and countsAsForeign(node) and !node.rc_flags.foreign) return error.FlagMismatch;
    if (node.child_nodes.size() > fanout) return;
    var total: u64 = @intFromBool(isHeld(node));
    var child = node.first_child;
    while (child) |at| : (child = at.next_sibling) total += at.subtree_holds;
    var hosted: [2]?*NodeBase = undefined;
    for (hostedRootsOf(node, &hosted)) |maybe| if (maybe) |hosted_root| {
        if (!hosted_root.rc_flags.hosted) return error.FlagMismatch;
        total += hosted_root.subtree_holds;
    };
    if (total != node.subtree_holds) return error.SubtreeHoldsMismatch;
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
