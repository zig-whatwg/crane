//! Refcount step 7, the switch: counts decide when a tree is freed
//! (tmp/plans/refcount-design.md 1.4 and section 7 step 7; the lane's design
//! delta, tmp/plans/refcount9-design.md B1).
//!
//! A tree is alive while any node in it is held (decision D1). Where the
//! counts lower a tree's total to zero - a wrapper's, a holder's, a creator's
//! or a remover's reference ending, a removal leaving two roots, a host's end,
//! a document's last foreign hold - refcount.zig calls `settle` with the
//! tree's root. When the root is garbage (parentless, unhosted, no hold
//! anywhere in its tree; a Document also no held detached node of it,
//! decision D6) it is flagged `garbage` and queued on its agent's deferred
//! teardown queue (runtime.gc.DeferredTeardown, the AgentHost's). Nothing is
//! freed there, and nothing runs script (decision D8: "deref to zero frees
//! later").
//!
//! The queue's slices - between tasks, at a realm's end (`drainOwner`, its
//! items are its realm's), at a full collection and at the agent's end -
//! run `runGarbageTree`: the re-check (design 1.4 step 2: the same instance,
//! its teardown not begun, still flagged, still garbage), then the tree's
//! nodes a budget at a time, leaves first (dom.tree_teardown), and the root
//! last through its own type's teardown and its storage at once
//! (runtime.gc.onObjectFreed, as the collector's queue freed a collected
//! root - an Attr, a Document and an element alike): no wrapper reaches a
//! garbage tree (a wrapper holds a reference). A Document goes in one go - its own teardown
//! frees its tree - as the collector's queue freed one.
//!
//! A tree held again before its slice - a reference reaching its root, or the
//! root linked under a parent or a host - is a RESURRECTION: the flag is
//! cleared where it happens (`resurrect`), the slice finds it unflagged and
//! drops the item. In a correct DOM nothing reaches a garbage tree (it is
//! unreachable from script and from every counted holder; weak links read it
//! as gone), so a resurrection is a raw holder the counts did not see - the
//! zombie audit's class (refcount step 6). It is counted, and logged when a
//! runner asked for the counts' diagnostics (CRANE_REFCOUNT_CHECK).
//!
//! WebKit frees a node whose last `Ref` ends at once (Node::removedLastRef,
//! Source/WebCore/dom/Node.cpp; a container's children through
//! removeDetachedChildrenInContainer, ContainerNodeAlgorithms.cpp, unlinking
//! each before its deref). Crane frees the same trees one slice later, in the
//! same order.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const NodeBase = @import("node_base.zig").NodeBase;
const instance_bridge = @import("instance_bridge.zig");
const tree_teardown = @import("tree_teardown.zig");
const DeferredTeardown = runtime.gc.DeferredTeardown;

const log = std.log.scoped(.refcount);

/// The switch's books, kept on the agent's queue.
pub const Books = DeferredTeardown.Books;

/// The switch's books of `node`'s agent (tests, diagnostics); null for a
/// node of a realm whose agent has no queue.
pub fn booksOf(node: *NodeBase) ?*Books {
    const instance = instanceOf(node) orelse return null;
    const queue = queueOf(instance) orelse return null;
    return &queue.books;
}

fn instanceOf(node: *NodeBase) ?*runtime.Instance {
    const raw = node.owner_instance orelse return null;
    return @ptrCast(@alignCast(raw));
}

/// The deferred teardown queue of `instance`'s realm's agent (a ShadowRealm's:
/// its principal realm's) - the one the agent was created with
/// (engine.deferredTeardownOf). Null for a realm with no agent, or an agent
/// made without a queue (an engine-less test's, or one the adapter did not
/// make): its trees the counts never free; its realm's end does. Never the
/// agent's `host` pointer cast to the html AgentHost: a host pointer an agent
/// was given is only its creator's type, and tests make agents with their
/// own.
pub fn queueOf(instance: *runtime.Instance) ?*DeferredTeardown {
    var current: ?runtime.Context = instance.ctx;
    while (current) |realm| : (current = realm.principal_realm) {
        const agent = realm.agent orelse continue;
        return engine.deferredTeardownOf(agent);
    }
    return null;
}

/// Whether `root` is the root of a garbage tree: parentless, unhosted, no
/// hold anywhere in it - and, a Document, no held detached node of it
/// (`foreign_holds`, null when unknown: not garbage).
pub fn isGarbageRoot(root: *const NodeBase, foreign_holds: ?u32) bool {
    if (root.parent_node != null or root.rc_flags.hosted or root.subtree_holds != 0) return false;
    if (root.node_type == NodeBase.DOCUMENT_NODE) {
        const foreign = foreign_holds orelse return false;
        if (foreign != 0) return false;
    }
    return true;
}

/// The counts lowered the total of the tree rooted at `root`: when that left
/// it garbage, flag it and queue its teardown. `foreign_holds` is the root's
/// document's foreign holds when `root` is a Document. Frees nothing.
pub fn settle(root: *NodeBase, foreign_holds: ?u32) void {
    if (root.rc_flags.garbage) return;
    if (!isGarbageRoot(root, foreign_holds)) return;
    const instance = instanceOf(root) orelse return;
    // A node being torn down already is that teardown's (a realm's, a
    // tree's): a release inside it is not a garbage moment.
    if (runtime.instance_lifecycle.isCleanupStarted(instance)) return;
    const queue = queueOf(instance) orelse return;
    root.rc_flags.garbage = true;
    if (!queue.push(.{
        .instance = instance,
        .generation = runtime.SlabAllocator.generationOf(instance),
        .owner = queueOwner(instance.ctx),
        .steps = &garbage_tree_steps,
        // The memory bound counts nodes: a walk capped at `weight_cap`, so
        // a removal stays O(1) and a large tree weighs at least that much.
        .weight = tree_teardown.countUpTo(root, weight_cap),
    })) {
        // The agent is ending (its queue closed): the old model frees it.
        root.rc_flags.garbage = false;
        return;
    }
    queue.books.queued += 1;
}

/// The most nodes a garbage tree's weight counts at its push (the queue's
/// memory bound; design 1.4 item 6 left the weight to an estimate).
pub const weight_cap: usize = 64;

/// The owner a realm's garbage is queued under: its ContextData, whose end
/// drains it (`drainRealm`).
pub fn queueOwner(realm: runtime.Context) *const anyopaque {
    return @ptrCast(realm);
}

/// `realm` ends: the garbage its trees left goes now, while everything of the
/// realm lives - before its coordinated teardown, the conditions the
/// collector's queue had. The realm's adapter calls this beside its own
/// drain.
pub fn drainRealm(queue: *DeferredTeardown, realm: runtime.Context) void {
    queue.drainOwner(queueOwner(realm));
}

/// `root`, flagged garbage, is held again (a reference reached it, or it was
/// linked): the flag goes now, so weak links read its tree as alive again,
/// and its slice drops the item.
pub fn resurrect(root: *NodeBase) void {
    if (!root.rc_flags.garbage) return;
    root.rc_flags.garbage = false;
    const instance = instanceOf(root) orelse return;
    if (queueOf(instance)) |queue| queue.books.resurrections += 1;
    if (@import("refcount.zig").diagnosticsOn())
        log.warn("a garbage tree was held again before its teardown (root node type {d}): a holder the counts do not see", .{root.node_type});
}

const garbage_tree_steps: DeferredTeardown.Steps = .{ .run = runGarbageTree };

/// The refcount steps (design 1.4 steps 2-3): re-check, then free a budget
/// of the tree, leaves first, the root last.
fn runGarbageTree(item: *DeferredTeardown.Item, budget: usize) DeferredTeardown.Progress {
    const nothing: DeferredTeardown.Progress = .{ .freed = 0, .done = true };
    const instance = item.instance;
    // Freed since, by the old model's nets (a realm's teardown), or its slot
    // reissued.
    if (runtime.SlabAllocator.generationOf(instance) != item.generation) return nothing;
    if (runtime.instance_lifecycle.isCleanupStarted(instance)) return nothing;
    const root = instance_bridge.getNodeBaseUnaudited(instance) orelse return nothing;
    // Resurrected (the flag went where it was held again).
    if (!root.rc_flags.garbage) return nothing;
    const refcount = @import("refcount.zig");
    const foreign = if (root.node_type == NodeBase.DOCUMENT_NODE) refcount.documentForeignHolds(root) else null;
    if (!isGarbageRoot(root, foreign)) {
        resurrect(root);
        return nothing;
    }
    // A tree of a realm that ended (a frame's retired realm) goes too, as the
    // collector's queue freed one (lane pageretention1): no wrapper of any
    // realm holds a count on a garbage tree, so it is unwrapped, and
    // Node.deinitNodeByType's retired-realm rule returns its storage.
    const books: ?*Books = if (queueOf(instance)) |queue| &queue.books else null;
    // A Document, or inside a realm's coordinated teardown (a realm ended
    // within another's runs its drain there): the root's own teardown, in
    // one go - it frees the whole tree.
    if (root.node_type == NodeBase.DOCUMENT_NODE or runtime.cleanup_coordinator.isContextTearingDown()) {
        root.rc_flags.garbage = false;
        runtime.gc.onObjectFreed(instance);
        if (books) |b| b.freed_trees += 1;
        return .{ .freed = 1, .done = true };
    }
    const freed = tree_teardown.freeDescendants(root, &item.position, budget);
    if (books) |b| b.freed_nodes += freed;
    // Children left, or the budget spent on them: the root next slice.
    if (root.first_child != null or freed >= budget) return .{ .freed = freed, .done = false };
    root.rc_flags.garbage = false;
    runtime.gc.onObjectFreed(instance);
    if (books) |b| {
        b.freed_trees += 1;
        b.freed_nodes += 1;
    }
    return .{ .freed = freed + 1, .done = true };
}

/// `document`'s own count reached zero: nothing outside its tree holds the
/// Document itself - its wrapper is gone, no holder names it, a Window would
/// (refcount step 5i). WebKit's Document::removedLastRef
/// (Source/WebCore/dom/Document.cpp) detaches its parser then
/// ("detachParser()", before removeDetachedChildren), and so does this, one
/// slice later (never inline: the deref can be a wrapper's second pass or a
/// step of a DOM algorithm). Without it a suspended parser's counted
/// structures (refcount step 5a) and the document that owns the parser are a
/// cycle no count ever ends. A node of the document held elsewhere still
/// keeps its tree (decision D6: those holds are foreign; the document's own
/// parser is not); with none, the tree is garbage once the parser lets go,
/// by the ordinary rules. The detach is the Document's own
/// (dom.document_lifecycle.discardParser): its scheduled scripts discarded
/// without running, its input aborted, its reference to the parser released.
pub fn documentUnreferenced(document: *NodeBase) void {
    const instance = instanceOf(document) orelse return;
    if (runtime.instance_lifecycle.isCleanupStarted(instance)) return;
    // Only a document with a parser has one to detach.
    const internal = @import("document_internals.zig").getInternal(instance) orelse return;
    if (internal.active_parser == null) return;
    const queue = queueOf(instance) orelse return;
    _ = queue.push(.{
        .instance = instance,
        .generation = runtime.SlabAllocator.generationOf(instance),
        .owner = queueOwner(instance.ctx),
        .steps = &document_unreferenced_steps,
        .weight = 0,
    });
}

const document_unreferenced_steps: DeferredTeardown.Steps = .{ .run = runDocumentUnreferenced };

fn runDocumentUnreferenced(item: *DeferredTeardown.Item, budget: usize) DeferredTeardown.Progress {
    _ = budget;
    const done: DeferredTeardown.Progress = .{ .freed = 0, .done = true };
    const instance = item.instance;
    if (runtime.SlabAllocator.generationOf(instance) != item.generation) return done;
    if (runtime.instance_lifecycle.isCleanupStarted(instance)) return done;
    const document = instance_bridge.getNodeBaseUnaudited(instance) orelse return done;
    // Referenced again since (wrapped again, held, given a Window).
    if (@import("refcount.zig").isHeld(document)) return done;
    const interfaces = @import("interfaces");
    if ((interfaces.Document.get_defaultView(instance) catch null) != null) return done;
    @import("document_lifecycle.zig").discardParser(instance, null);
    return done;
}

/// A Browser's agent ended (Browser.deinit, after its last realm's end and
/// the queue's last drain): every node the counts could free is freed, so a
/// node still alive is one something held at the agent's end - a leak the
/// Browser's final sweep (dom.teardown_sweeps) hides. Debug only: an ERROR in
/// a unit test (decision D9: fatal there) unless the test said why it leaves
/// nodes (`allowLiveNodesAtAgentEnd`: it exercises the final sweep, or an
/// out-of-memory path) - the safe default, so a new test that leaks nodes
/// fails; a warning in a run that asked for the counts' diagnostics
/// (CRANE_REFCOUNT_CHECK), where a sweep's report counts it. Returns the
/// count.
pub fn agentEnded(scope: *runtime.BrowserScope, queue: *const DeferredTeardown) usize {
    if (@import("builtin").mode != .Debug) return 0;
    const live = instance_bridge.entryCount(scope);
    if (live == 0) return 0;
    if (@import("builtin").is_test) {
        if (queue.live_nodes_at_end_allowed == null) {
            log.err("{d} node(s) alive at the agent's end: held past every realm's end, freed only by the final sweep", .{live});
            instance_bridge.visitNodes(scope, 12, {}, describeLiveNode);
        }
    } else if (@import("refcount.zig").diagnosticsOn()) {
        log.warn("{d} node(s) alive at the agent's end: held past every realm's end, freed only by the final sweep", .{live});
    }
    return live;
}

/// One node alive at the agent's end, for the report: what holds it.
fn describeLiveNode(_: void, node: *NodeBase) void {
    const refcount = @import("refcount.zig");
    var depth: usize = 0;
    var up: *NodeBase = node;
    while (up.parent_node) |p| : (depth += 1) up = p;
    log.warn("  alive: type {d} count {d} subtree_holds {d} depth {d} root type {d} root holds {d} garbage {} creator {} removal_held {} hosted {} wrapped {}", .{
        node.node_type,
        refcount.count(node),
        node.subtree_holds,
        depth,
        up.node_type,
        up.subtree_holds,
        up.rc_flags.garbage,
        node.rc_flags.creator,
        node.rc_flags.removal_held,
        node.rc_flags.hosted,
        node.bound_v8_wrapper != null,
    });
}

/// A test that leaves nodes alive at its agent's end on purpose - one that
/// exercises the final sweep, or an out-of-memory path that may leak a tree -
/// says why (`reason`, a static string), so `agentEnded` does not fail it.
pub fn allowLiveNodesAtAgentEnd(queue: *DeferredTeardown, reason: []const u8) void {
    queue.live_nodes_at_end_allowed = reason;
}
