//! dom.dying_trees: which trees die with the node wrappers a full collection
//! found dead, decided while that collection is still in its pause (lane
//! dm1's design, tmp/plans/dom-memory-figure-design.md 3.2 B and 3.3; lane
//! dm2, batch B).
//!
//! WHY. An engine sets the threshold of its next collection when a
//! collection ends, from what it believes is alive. A Browser tells its
//! window agent's engine what its DOM holds (runtime.gc.ExternalMemory), and
//! a tree's bytes leave that figure where the counts decide the tree dead
//! (dom.refcount_teardown.settle). For a tree only wrappers held, that is
//! when the dead wrappers' references are released - at the agent's next
//! safe point, AFTER the collection that found them dead computed its
//! threshold with the tree still in the figure. So the threshold ratchets:
//! V8 set 105.7 MB after the parser page's first collection, with 47 MB
//! alive (design 2.1). Both browsers give their collector survivors only:
//! Blink's nodes are on V8's C++ heap, whose MARKED bytes V8 reads when it
//! recomputes its limits (Chromium 157.0.8103.50 core/dom/node.h:165; V8
//! 15.7.112.43 src/heap/cppgc-js/cpp-heap.cc:1016), and a full collection of
//! JavaScriptCore zeroes its extra-memory sum and adds only what each
//! visited wrapper keeps (WebKit 621b33b3b71 Source/JavaScriptCore/heap/
//! Heap.cpp:1811-1817, :2254-2270).
//!
//! WHAT. runtime.lifetime's `dyingWith` hook (installed by dom.refcount at
//! process start; called by an adapter whose engine can be told inside its
//! collection, engine.capabilities.external_memory_at_collection): the
//! collector hands the wrappers it found dead in this collection's marking,
//! their references still held. `predict` decides which trees die with them,
//! sums what those trees hold of the figure - the walk and the sum their
//! queueing makes, tree_teardown.measureUpTo - and the bytes leave the
//! figure there (ExternalMemory.predictDead). Each tree's queueing then takes
//! its bytes from that pool instead of from the figure, and what no queueing
//! took once every reference is released goes back
//! (ExternalMemory.settlePredictions).
//!
//! THE RULE IS THE MARKS' (design 3.3). A replay of the releases on the
//! counts finds almost nothing: script read `div.childNodes`, that NodeList
//! holds a counted reference on the div, the NodeList died in the same
//! collection, and its reference is released by its finalizer - the counts
//! cannot see that the two die together (0 MB of 55.6 MB found). What the
//! collection proved is stronger. The walk (dom.wrapper_tracing) keeps EVERY
//! wrapper of a tree as soon as one wrapper of it, one pending-activity keep
//! or one kept holder of one of its nodes is reached. So:
//!
//!   A node wrapper found dead proves that nothing the collector kept
//!   reaches its tree. Every reference left on that tree belongs to a
//!   holder that is dead too, or is a native reference.
//!
//! A dead wrapper's tree therefore dies unless a native reference holds it.
//! The ones a root shows are checked: a remover's hold and a creator's
//! reference on a detached root; for a Document, any reference beyond its
//! own dead wrapper and its own pending work (a Window's), and its held
//! detached trees (refcount decision D6: a Document's tree waits for them),
//! which must be dying in this same collection. A native reference those
//! flags do not show - a counted hold of pending work on a node of the tree
//! (an image's pending load deep in a dropped tree) - is not seen: the tree
//! is then predicted dead and is not. The error lasts
//! until the releases at the agent's next safe point, where the bytes go
//! back, and it makes the engine's number too LOW meanwhile - the engine
//! collects sooner, never later. Debug builds count each such tree
//! (runtime.gc.DeferredTeardown.Books.mispredicted): the integrator's ruling
//! 2 on the design is that the WPT sweep's count decides whether the rule
//! must be made exact.
//!
//! INSIDE THE COLLECTOR'S PAUSE, like the walk: read-only on the DOM, no
//! allocation (the documents that wait for a tally sit in a table on the
//! stack; a Debug build's list of predicted roots is the queue's own
//! memory), no engine operation but engine.traceVisitOnce, and no recursion.
//! The trees read are consistent for the walk's reason (dom.wrapper_tracing's
//! header: a collection starts only at an allocation, and no tree mutation
//! allocates between its link writes and its count updates).
//!
//! COST: nothing for a kept wrapper; a dead wrapper whose node is alone
//! 13-16 ns; a node of a dying tree 2-29 ns by how cold its memory is (the
//! design's 3.5, measured on its prototype). It is the walk the tree's
//! queueing makes a moment later anyway; a tree is walked twice, here and
//! there, until a row asks for the sum to ride on the release.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const NodeBase = @import("node_base.zig").NodeBase;
const refcount = @import("refcount.zig");
const refcount_teardown = @import("refcount_teardown.zig");
const tree_teardown = @import("tree_teardown.zig");
const wrapper_tracing = @import("wrapper_tracing.zig");
const instance_bridge = @import("instance_bridge.zig");

const DeferredTeardown = runtime.gc.DeferredTeardown;
const ExternalMemory = runtime.gc.ExternalMemory;
const DeadWrapper = runtime.lifetime.DeadWrapper;

/// runtime.lifetime's `dyingWith` hook: the end of a full collection's
/// marking found the wrappers of `dead` dead. The trees that die with them
/// leave `memory`'s figure; returns the bytes that left.
pub fn dyingWith(memory: *ExternalMemory, dead: []const DeadWrapper, tracer: *engine.Tracer) usize {
    const Collection = struct {
        tracer: *engine.Tracer,
        queue: ?*DeferredTeardown,

        pub fn once(self: @This(), root: *const NodeBase) bool {
            return engine.traceVisitOnce(self.tracer, root);
        }

        pub fn took(self: @This(), root: *runtime.Instance) void {
            const queue = self.queue orelse return;
            queue.notePredicted(.{ .instance = root, .generation = runtime.SlabAllocator.generationOf(root), .lives = &rootLives });
        }
    };
    const found = predict(memory, dead, Collection{ .tracer = tracer, .queue = memory.queue });
    if (found.trees == 0) return 0;
    return memory.predictDead(found.bytes, found.trees);
}

/// What `predict` found.
pub const Prediction = struct {
    /// Trees that die with the dead wrappers.
    trees: usize = 0,
    /// Their nodes, each tree's up to the queue's bound (as its queueing
    /// counts them), and what those nodes hold of the figure.
    nodes: usize = 0,
    bytes: usize = 0,
};

/// The rule (this file's header), over the wrappers a collection found dead.
/// `collection` is that collection's memory of the trees it has seen:
/// `collection.once(root)` is true the first time a root is offered in this
/// collection - false for a tree the walk kept, or one this call already
/// took (engine.traceVisitOnce's set) - and `collection.took(root)` hears of
/// each tree predicted dead. Only trees counted in `memory` are taken.
/// Read-only; changes nothing in the DOM or in `memory`.
pub fn predict(memory: *const ExternalMemory, dead: []const DeadWrapper, collection: anytype) Prediction {
    var found: Prediction = .{};
    var waiting: WaitingDocuments = .{};
    for (dead) |wrapper| {
        // Freed, or its teardown begun, since the collector found the
        // wrapper dead (a forced realm end): nothing of it may be read.
        if (runtime.SlabAllocator.generationOf(wrapper.instance) != wrapper.generation) continue;
        if (runtime.instance_lifecycle.isCleanupStarted(wrapper.instance)) continue;
        const node: *NodeBase = @ptrCast(@alignCast(wrapper.target));
        // The host-including root: the unit the counts and the walk keep. A
        // connected node's is its node document (its shadow-including root
        // is a document, and a shadow root's host-including parent is its
        // host): read, not climbed to, as the walk reads it
        // (wrapper_tracing.connectedDocument). While a Document lives the
        // walk keeps every wrapper of its tree, so a connected node's
        // wrapper is dead only when its whole document is: a dying document
        // with thousands of wrapped nodes costs the pause a read a wrapper,
        // not a climb.
        const root = wrapper_tracing.connectedDocument(node) orelse refcount.root(null, node);
        if (root.node_type == NodeBase.DOCUMENT_NODE) {
            // A Document script still holds (the page's own, nearly always).
            if (root.rc_flags.garbage or !root.wrapper.isEmpty()) continue;
            const own = root == node;
            const foreign = refcount.documentForeignHolds(root) orelse continue;
            if (foreign != 0) {
                // It waits for its held detached trees: decided below, once
                // every dying one of them is tallied.
                waiting.reached(root, own);
                continue;
            }
            if (!documentMayDie(root, own)) continue;
            // Once per tree. A Document that is its tree's only held node
            // has no other wrapper to be offered through.
            if (!(own and root.subtree_holds == 1) and !collection.once(root)) continue;
            _ = take(&found, memory, root, collection);
            continue;
        }
        if (!detachedRootMayDie(root)) continue;
        // Once per tree; a root that is its tree's only held node needs no
        // set (the common dropped element: one hash insert saved a wrapper).
        if (!(root == node and root.subtree_holds == 1) and !collection.once(root)) continue;
        if (!take(&found, memory, root, collection)) continue;
        // Its holds are among its node document's foreign holds, which that
        // Document's own death waits for.
        if (root.rc_flags.foreign) waiting.dying(root);
    }
    for (waiting.slice()) |entry| {
        const document = entry.document;
        if (!documentMayDie(document, entry.own)) continue;
        // Every held detached tree of it must be dying here.
        const foreign = refcount.documentForeignHolds(document) orelse continue;
        if (foreign != entry.tally) continue;
        // A tree the walk kept (a kept wrapper, keep or holder reaches a
        // node of it) is alive whatever its detached trees do. A Document
        // with no held node below it is not in the walk's set, and needs no
        // answer from it: nothing kept holds a node of its tree.
        if (!wrapper_tracing.isLone(document) and !collection.once(document)) continue;
        _ = take(&found, memory, document, collection);
    }
    return found;
}

/// Whether `root`, the detached root of a dead wrapper's tree, dies with the
/// collection's dead: not decided dead already (its bytes left the figure
/// then), not reached by a wrapper the collector kept, and not held by a
/// native reference a root shows - a remover's hold (refcount.zig
/// `removal_held`: a node a DOM algorithm removed and still works on), its
/// creator's reference (a node made and not yet handed on), a host link
/// that outlived its host (`hosted`, which the counts never call garbage).
fn detachedRootMayDie(root: *const NodeBase) bool {
    const flags = root.rc_flags;
    if (flags.garbage or flags.hosted or flags.removal_held or flags.creator) return false;
    return root.wrapper.isEmpty();
}

/// Whether `document`, the root of a dead wrapper's tree or the node
/// document of dying detached trees, dies with the collection's dead, its
/// detached trees aside: not decided dead already, no wrapper the collector
/// kept, and no reference on it beyond its own dead wrapper (`own`: that
/// wrapper is among the dead, its reference still counted) and its own
/// pending work (refcount_teardown.ownWorkReferences) - a Window holds its
/// document counted, and so does every native holder. A Document is judged
/// by its count, not by the marks: a dead holder's reference on it cannot be
/// told from a Window's, so a Document a dead NodeList still names waits for
/// its queueing (the figure is then too high for one collection, the old
/// direction).
fn documentMayDie(document: *const NodeBase, own: bool) bool {
    if (document.rc_flags.garbage or !document.wrapper.isEmpty()) return false;
    const instance = instanceOf(document) orelse return false;
    const references = refcount.count(document);
    const explained = @as(u32, @intFromBool(own)) + refcount_teardown.ownWorkReferences(instance);
    return references <= explained;
}

/// `root`'s tree is predicted dead: summed as its queueing will sum it
/// (dom.refcount_teardown.settle), so the pool it leaves the figure into
/// gives its queueing exactly its bytes. False for a tree that is not
/// counted in `memory` (another Browser's), or whose root's teardown began.
fn take(found: *Prediction, memory: *const ExternalMemory, root: *NodeBase, collection: anytype) bool {
    const instance = instanceOf(root) orelse return false;
    if (runtime.instance_lifecycle.isCleanupStarted(instance)) return false;
    if (&runtime.BrowserScope.ofInstance(instance).dom_memory != memory) return false;
    const measure = tree_teardown.measureUpTo(root, DeferredTeardown.high_water);
    found.trees += 1;
    found.nodes += measure.nodes;
    found.bytes += measure.bytes;
    collection.took(instance);
    return true;
}

fn instanceOf(node: *const NodeBase) ?*runtime.Instance {
    const raw = node.ownerInstance() orelse return null;
    return @ptrCast(@alignCast(raw));
}

/// A Debug build's question about a root it kept as predicted dead, once
/// the dead wrappers' references are released (DeferredTeardown.
/// PredictedRoot.lives; the root is still the same object and not being
/// torn down): alive when the counts have not decided it dead.
fn rootLives(root: *runtime.Instance) bool {
    const node = instance_bridge.getNodeBaseUnaudited(root) orelse return false;
    return !node.rc_flags.garbage;
}

/// The Documents whose death waits for a tally of their dying detached
/// trees: a Document with held detached trees (foreign holds) dies only when
/// all of them die with it. A table on the stack - the pass allocates
/// nothing - of the few such Documents one collection meets: nearly every
/// dying detached tree's node document is the page's own, which is alive,
/// has a wrapper and is not tallied at all. A Document the table has no room
/// for is not predicted: its queueing takes its bytes out, as before.
const WaitingDocuments = struct {
    entries: [capacity]Entry = undefined,
    len: usize = 0,
    /// The entry asked for last: a document's trees come one after another.
    last: usize = 0,
    /// The key (NodeBase.documentKey) of the node document `dying` found
    /// last that plainly lives or is decided dead already - the page's own
    /// document, for nearly every detached tree a page drops: the next tree
    /// of it is answered by one compare, with no question to the document
    /// (30,000 lone dead wrappers in one collection cost the pause that
    /// question each; gc_bench `wrapper-churn-nogc`). 0: none.
    settled_key: usize = 0,

    const capacity = 32;

    const Entry = struct {
        document: *NodeBase,
        /// Held nodes of its dying detached trees (their roots' totals).
        tally: u64 = 0,
        /// Its own wrapper is among the dead.
        own: bool = false,
    };

    fn slice(self: *const WaitingDocuments) []const Entry {
        return self.entries[0..self.len];
    }

    fn entryOf(self: *WaitingDocuments, document: *NodeBase) ?*Entry {
        if (self.last < self.len and self.entries[self.last].document == document) return &self.entries[self.last];
        for (self.entries[0..self.len], 0..) |*entry, index| {
            if (entry.document != document) continue;
            self.last = index;
            return entry;
        }
        if (self.len == capacity) return null;
        self.entries[self.len] = .{ .document = document };
        self.last = self.len;
        self.len += 1;
        return &self.entries[self.last];
    }

    /// A dead wrapper's tree is `document`'s (`own`: the wrapper is the
    /// Document's own).
    fn reached(self: *WaitingDocuments, document: *NodeBase, own: bool) void {
        const entry = self.entryOf(document) orelse return;
        if (own) entry.own = true;
    }

    /// `root`, a detached tree predicted dead, counts in its node
    /// document's foreign holds: tallied for that Document - unless it
    /// plainly lives (a wrapper the collector kept) or is decided dead
    /// already.
    fn dying(self: *WaitingDocuments, root: *NodeBase) void {
        const key = root.documentKey();
        if (key != 0 and key == self.settled_key) return;
        const document = refcount.liveNodeDocument(root) orelse return;
        if (!document.wrapper.isEmpty() or document.rc_flags.garbage) {
            // Neither changes inside one collection's pause.
            self.settled_key = key;
            return;
        }
        const entry = self.entryOf(document) orelse return;
        entry.tally += root.subtree_holds;
    }
};
