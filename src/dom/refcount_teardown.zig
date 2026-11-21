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
//! cleared where it happens (`resurrect`) and its item leaves the queue
//! there (the one a slice has in hand: that slice finds it unflagged and
//! drops it). In a correct DOM nothing reaches a garbage tree (it is
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
    return node.registeredInstance();
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
    // The memory bound counts nodes, so the tree weighs its nodes - up to
    // the bound itself, past which one tree alone has the next safe point
    // free it. The walk is the one its slices then make to free them: one
    // more pass, read-only, over a tree freed anyway. A capped weight let
    // the bound admit trees instead of nodes (lane perf1: weighed at most
    // 64, 1,562 innerHTML-replaced lists of 900 nodes waited - 1.39M nodes,
    // 4 GB; the document-unreferenced item below weighs its tree the same
    // way).
    //
    // The same walk sums what the tree holds of its Browser's DOM memory:
    // THE TREE IS DECIDED DEAD HERE, so those bytes leave the figure the
    // engine is told at this push and not when its slices free them (lane
    // dm1's design, tmp/plans/dom-memory-figure-design.md 3.2 A: the moment
    // a tree's count reaches zero outside a full collection). The engine
    // sets its next threshold from what it is told is alive; a tree that
    // only waits for its slices is not. Both browsers tell their collector
    // survivors only (runtime.gc.ExternalMemory.dying has the sources).
    const measure = tree_teardown.measureUpTo(root, DeferredTeardown.high_water);
    if (!queue.push(.{
        .instance = instance,
        .generation = runtime.SlabAllocator.generationOf(instance),
        .owner = queueOwner(instance.ctx),
        .steps = &garbage_tree_steps,
        .weight = measure.nodes,
        .dying = .{ .memory = &runtime.BrowserScope.ofInstance(instance).dom_memory, .bytes = measure.bytes },
    })) {
        // The agent is ending (its queue closed): the old model frees it.
        root.rc_flags.garbage = false;
        return;
    }
    queue.books.queued += 1;
    queue.books.queued_bytes += measure.bytes;
}

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
/// and its item leaves the queue - with it the tree's bytes go back into the
/// figure the engine is told (they are alive again), and a tree that is
/// queued a second time later is counted once. The item a slice has in hand
/// is not in the queue: that slice finds the tree unflagged and drops it.
pub fn resurrect(root: *NodeBase) void {
    if (!root.rc_flags.garbage) return;
    root.rc_flags.garbage = false;
    const instance = instanceOf(root) orelse return;
    if (queueOf(instance)) |queue| {
        queue.books.resurrections += 1;
        _ = queue.withdraw(instance, runtime.SlabAllocator.generationOf(instance), &garbage_tree_steps);
    }
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
    if (root.firstChild() != null or freed >= budget) return .{ .freed = freed, .done = false };
    root.rc_flags.garbage = false;
    runtime.gc.onObjectFreed(instance);
    if (books) |b| {
        b.freed_trees += 1;
        b.freed_nodes += 1;
    }
    return .{ .freed = freed + 1, .done = true };
}

/// The references on `document` that are its own pending work: one per
/// lifecycle task still queued for it (Document.zig's LifecycleTask holds
/// its document counted from its queueing to its run or drop, and stands in
/// its Browser's dom.document_state.PendingLifecycleTasks meanwhile).
/// Read-only: dom.dying_trees asks inside a collection's pause.
pub fn ownWorkReferences(instance: *runtime.Instance) u32 {
    const pending = @import("document_state.zig").PendingLifecycleTasks.of(instance) orelse return 0;
    return pending.countFor(instance);
}

/// A reference on `document` ended. When what is left is only its own
/// pending work - nothing outside holds the Document: its wrapper is gone,
/// no holder names it, a Window would (refcount step 5i), and a held node of
/// it would keep its wrapper - it is unreachable. The trigger is "own count ==
/// its own pending lifecycle tasks": the same rule as "its last reference
/// went", measured honestly (each task's counted hold is a reference on the
/// Document node), and a held node or a listener closure still keeps the
/// count above it. WebKit's
/// Document::removedLastRef (Source/WebCore/dom/Document.cpp) then detaches
/// its parser ("detachParser()", before removeDetachedChildren) and stops its
/// pending work (commonTeardown); so does this, one slice later (never
/// inline: the deref can be a wrapper's second pass or a step of a DOM
/// algorithm). Without it a suspended parser's counted structures (refcount
/// step 5a), and a document's own lifecycle tasks (refcount8,
/// H-RC8-DOC-LIFECYCLE), keep a document nothing else reaches until they
/// end - a cycle, or, for a script that makes and drops documents, every
/// one of them until the script's task ends (the parser-write cost row).
/// A node of the document held elsewhere still keeps its tree (decision
/// D6: those holds are foreign). The detach is the Document's own
/// (dom.document_lifecycle.discardParser: its scheduled scripts discarded
/// without running, its input aborted, its parser reference released); its
/// lifecycle tasks go only when nothing listens to it
/// (dom.document_lifecycle.dropUnobservedLifecycleTasks).
pub fn documentDereffed(document: *NodeBase) void {
    const instance = instanceOf(document) orelse return;
    if (runtime.instance_lifecycle.isCleanupStarted(instance)) return;
    const internal = @import("document_internals.zig").getInternal(instance) orelse return;
    // Only a document with a parser to detach, lifecycle tasks to drop or -
    // destroyed - references of its own state to end, and nothing outside
    // its own pending work holding it.
    const own_work = ownWorkReferences(instance);
    if (internal.active_parser == null and own_work == 0 and !(internal.destroyed and holdsOwnReferences(internal))) return;
    if (@import("refcount.zig").count(document) > own_work) return;
    const queue = queueOf(instance) orelse return;
    _ = queue.push(.{
        .instance = instance,
        .generation = runtime.SlabAllocator.generationOf(instance),
        .owner = queueOwner(instance.ctx),
        .steps = &document_unreferenced_steps,
        // The tree its parser and tasks would let go: the memory bound counts
        // it, so a script that makes and drops documents gets its relief at
        // a binding exit once they pass high_water - not at its task's end
        // (the parser-write cost row: base freed them as their wrappers died).
        .weight = tree_teardown.countUpTo(document, DeferredTeardown.high_water),
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
    // Referenced again since from outside its own work (wrapped again,
    // held, given a Window).
    if (@import("refcount.zig").count(document) > ownWorkReferences(instance)) return done;
    const interfaces = @import("interfaces");
    if ((interfaces.Document.get_defaultView(instance) catch null) != null) return done;
    const document_lifecycle = @import("document_lifecycle.zig");
    document_lifecycle.discardParser(instance, null);
    // Its pending lifecycle tasks go too when nothing listens to it (the
    // integrator's ruling (c)): their holds were the last on it.
    document_lifecycle.dropUnobservedLifecycleTasks(instance);
    // A destroyed document's own state lets go of its nodes (refcount step
    // 7b): the references would keep its tree - and through its tree the
    // document - alive for ever, a cycle only the realm's forced free used
    // to break.
    document_lifecycle.releaseOwnReferences(instance);
    return done;
}

/// Whether `internal`, a document's state, keeps references on its own nodes:
/// its top layer (its popovers, modal dialogs and fullscreen elements, the
/// fullscreen events still pending, its pointer and hint targets, its open
/// dialogs), its autofocus candidates or its editor state (its editing undo
/// history's steps, dom.editor_states). Each is a counted hold on a node of
/// the document's tree, or of a subtree removed from it (a foreign hold,
/// decision D6) - so the document keeps itself alive through them.
fn holdsOwnReferences(internal: *const @import("document_state.zig").InternalState) bool {
    if (internal.editor_state) |editor_state| if (@import("editor_states.zig").holdsNodes(editor_state)) return true;
    const shared = internal.interaction_state orelse return false;
    return shared.top_layer != null or shared.autofocus != null;
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
    if (@import("builtin").mode != std.builtin.OptimizeMode.Debug) return 0;
    reportPredictions(queue);
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

/// The agent's books of the trees its collections predicted dead
/// (dom.dying_trees), one line a sweep's log is summed from: how often the
/// marks' rule called a tree dead that lived (the integrator's ruling 2 on
/// lane dm1's design: that count decides whether the rule must be made
/// exact). Logged when a tree was mispredicted - Debug builds count them, so
/// the bug-finding WPT run prints a line for each agent that had one - and,
/// for the totals of an agent that had none, when a run asked for the
/// counts' diagnostics (CRANE_REFCOUNT_CHECK). Never in a unit test, where a
/// test reads the books itself. Not a violation: the line never begins with
/// the counts' "refcount: ".
fn reportPredictions(queue: *const DeferredTeardown) void {
    if (@import("builtin").is_test) return;
    const books = &queue.books;
    if (books.mispredicted == 0 and !(books.predicted != 0 and @import("refcount.zig").diagnosticsOn())) return;
    log.warn("dying trees: {d} tree(s) predicted dead at a collection's end of marking ({d} B), {d} of them alive at their release; {d} B put back into the figure", .{ books.predicted, books.predicted_bytes, books.mispredicted, books.put_back_bytes });
}

/// Up to `limit` live nodes of `scope`'s Browser, each with what holds it,
/// as warnings (the agent-end report's lines): a test that finds nodes it
/// expected freed says which.
pub fn describeLiveNodes(scope: *runtime.BrowserScope, limit: usize) void {
    instance_bridge.visitNodes(scope, limit, {}, describeLiveNode);
}

/// One node alive at the agent's end, for the report: what holds it.
fn describeLiveNode(_: void, node: *NodeBase) void {
    const refcount = @import("refcount.zig");
    var depth: usize = 0;
    var up: *NodeBase = node;
    while (up.parent_node) |p| : (depth += 1) up = p;
    const instance = instanceOf(node);
    log.warn("  alive: {s} type {d} realm ended {} count {d} subtree_holds {d} depth {d} root type {d} root holds {d} garbage {} creator {} removal_held {} hosted {} wrapped {}", .{
        if (instance) |i| i.vtable.name else "?",
        node.node_type,
        if (instance) |i| !i.ctx.hasEngine() else false,
        refcount.count(node),
        node.subtree_holds,
        depth,
        up.node_type,
        up.subtree_holds,
        up.rc_flags.garbage,
        node.rc_flags.creator,
        node.rc_flags.removal_held,
        node.rc_flags.hosted,
        !node.wrapper.isEmpty(),
    });
}

/// A test that leaves nodes alive at its agent's end on purpose - one that
/// exercises the final sweep, or an out-of-memory path that may leak a tree -
/// says why (`reason`, a static string), so `agentEnded` does not fail it.
pub fn allowLiveNodesAtAgentEnd(queue: *DeferredTeardown, reason: []const u8) void {
    queue.live_nodes_at_end_allowed = reason;
}
