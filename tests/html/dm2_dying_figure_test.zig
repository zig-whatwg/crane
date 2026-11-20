//! Lane dm2 (batch A of tmp/plans/dom-memory-figure-design.md, the host
//! side): the figure a Browser tells its window agent's engine about its DOM
//! is what is counted LESS the trees decided dead
//! (runtime.BrowserScope.dom_memory: `live` = `held()` - `dying`).
//!
//! V8 sets its next limit from what it is told is alive. The figure was a
//! counter that fell only at a node's free, and a dead tree is freed in
//! slices after it was decided dead, so V8 was told the dead were alive: on
//! a script that drops 400,000 divs in one task the counter held 6.0, 14.9
//! and 27.2 MB at its three full collections, of which 5.6, 14.3 and 26.8 MB
//! were trees already queued, and V8 set its limits to 20.7, 33.5 and 44 MB
//! (lane dm1, server1, main 929bcfca883). Both browsers give their collector
//! survivors only (Blink: V8 reads its C++ heap's marked bytes; WebKit: a
//! full collection zeroes the extra-memory sum and each visited wrapper adds
//! what it keeps - runtime.gc.ExternalMemory.dying has the sources).
//!
//! A tree's bytes leave the figure where the counts queue it
//! (dom.refcount_teardown.settle: the walk that weighs it also sums them),
//! come off the counter as its slices free them, and go back into the figure
//! when the tree is held again. The engine-less half - the queue and the
//! figure with a counter standing in for a tree - is
//! tests/runtime/dm2_dying_figure_test.zig.
const h = @import("refcount_holders_helpers.zig");
const std = h.std;
const testing = h.testing;
const dom = h.dom;
const runtime = h.runtime;
const engine = h.engine;
const interfaces = @import("interfaces");
const clock = @import("clock");

const DeferredTeardown = runtime.gc.DeferredTeardown;
const ExternalMemory = runtime.gc.ExternalMemory;

fn instanceOf(node: *dom.NodeBase) !*runtime.Instance {
    return @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return error.NotANode));
}

fn memoryOf(page: h.Page) *ExternalMemory {
    return &page.browser.scope.dom_memory;
}

fn queueOf(page: h.Page) *DeferredTeardown {
    return &page.browser.agent_host.deferred_teardown;
}

/// One event loop turn: the deferred teardown's slices run between tasks.
fn turn(page: h.Page) !void {
    _ = try page.browser.runEventLoopBlocking(20);
}

/// Turns of the event loop - at least one - until the deferred teardown's
/// queue is empty: every queued tree freed. A turn is 20 ms of real time,
/// and its slices are a share of it (event_loop.zig runDeferredTeardown), so
/// HOW MANY turns that takes is the host's load: two fixed turns freed the
/// 2,101-node tree's five slices in 0.8-1.7 s at rest and left some unrun
/// once beside a gate on chat2 (21.7 s, 2026-11-19). The wait is on the
/// queue; the deadline only stops a test whose queue never empties.
fn turnUntilFreed(page: h.Page) !void {
    const queue = queueOf(page);
    const deadline = clock.monotonicMillis() + 60 * std.time.ms_per_s;
    try turn(page);
    while (!queue.isEmpty()) {
        if (clock.monotonicMillis() >= deadline) return error.TestConditionNeverCame;
        try turn(page);
    }
}

/// A detached tree of 2,101 nodes that only a native hold keeps: a section
/// with 700 `<p><b>x</b></p>` in it, parsed and never wrapped, removed from
/// its parent while `held` - its first p - is held. Everything else the
/// removal left (the parser's fragment) is freed: the queue is empty and
/// nothing is dying. Ending the hold (dom.refcount.holderDeref) queues
/// exactly this tree.
const HeldTree = struct {
    host: *dom.NodeBase,
    root: *dom.NodeBase,
    held: *dom.NodeBase,
    root_instance: *runtime.Instance,
    root_generation: u64,

    const nodes: usize = 1 + 700 * 3;

    fn make(page: h.Page, per_p: []const u8) !HeldTree {
        try page.run("globalThis.host = document.createElement('div'); host.innerHTML = '<section>' + '<p><b>x</b></p>'.repeat(700) + '</section>';");
        if (per_p.len != 0) {
            // What `per_p` makes of each p (its wrapper, a rare block) while
            // script holds the tree; the wrappers go with the collections.
            try page.run(per_p);
            try page.collect();
            try turn(page);
        }
        const host = try page.node("host");
        const root = host.firstChild() orelse return error.NoChild;
        const held = root.firstChild() orelse return error.NoChild;
        dom.refcount.holderRef(held);
        errdefer dom.refcount.holderDeref(held);
        try page.run("host.innerHTML = '';");
        try page.collect();
        try turnUntilFreed(page);
        try testing.expect(!root.rc_flags.garbage);
        try testing.expect(root.parent_node == null);
        try testing.expect(queueOf(page).isEmpty());
        try testing.expectEqual(@as(usize, 0), memoryOf(page).dying);
        const root_instance = try instanceOf(root);
        return .{
            .host = host,
            .root = root,
            .held = held,
            .root_instance = root_instance,
            .root_generation = runtime.SlabAllocator.generationOf(root_instance),
        };
    }

    fn freed(self: HeldTree) bool {
        return runtime.SlabAllocator.generationOf(self.root_instance) != self.root_generation;
    }
};

fn aTreesBytesThroughItsLife() !void {
    const page = try h.Page.open();
    defer page.close();
    const tree = try HeldTree.make(page, "");
    const memory = memoryOf(page);
    const queue = queueOf(page);
    const books = dom.refcount_teardown.booksOf(tree.host) orelse return error.NoAgent;

    // Alive: all of it is in the figure.
    const alive = memory.live;
    const measure = dom.tree_teardown.measureUpTo(tree.root, DeferredTeardown.high_water);
    try testing.expectEqual(HeldTree.nodes, measure.nodes);
    // At least a slab slot and a NodeBase a node.
    try testing.expect(measure.bytes >= HeldTree.nodes * (runtime.SlabAllocator.slot_bytes + @sizeOf(dom.NodeBase)));
    const queued_bytes_before = books.queued_bytes;

    // QUEUED: its last hold ends, the counts queue it, and its bytes leave
    // the figure there. Nothing is freed: the counter still holds them.
    dom.refcount.holderDeref(tree.held);
    try testing.expect(tree.root.rc_flags.garbage);
    try testing.expect(!tree.freed());
    try testing.expectEqual(HeldTree.nodes, queue.pendingNodes());
    try testing.expectEqual(measure.bytes, memory.dying);
    try testing.expectEqual(alive - measure.bytes, memory.live);
    try testing.expectEqual(alive, memory.held());
    try testing.expectEqual(queued_bytes_before + measure.bytes, books.queued_bytes);

    // EACH SLICE: what it frees comes off the counter and the dying bytes;
    // the figure does not move - these nodes left it when they were queued.
    var slices: usize = 0;
    var last_dying = memory.dying;
    while (!queue.isEmpty()) : (slices += 1) {
        const freed_nodes = queue.runSlice(DeferredTeardown.slice_budget);
        try testing.expect(freed_nodes != 0 and freed_nodes <= DeferredTeardown.slice_budget);
        try testing.expectEqual(alive - measure.bytes, memory.live);
        try testing.expect(memory.dying < last_dying);
        try testing.expectEqual(alive - measure.bytes + memory.dying, memory.held());
        last_dying = memory.dying;
        try testing.expect(slices < 16);
    }
    // 2,101 nodes at 512 a slice: never in one.
    try testing.expect(slices >= 5);

    // FREED: nothing is dying, and the counter is the figure again. The sum
    // was exact for this tree: plain parsed nodes hold nothing a walk of
    // their NodeBases cannot see.
    try testing.expect(tree.freed());
    try testing.expectEqual(@as(usize, 0), memory.dying);
    try testing.expectEqual(alive - measure.bytes, memory.live);
    try testing.expectEqual(memory.live, memory.held());
}

test "a tree's bytes leave the figure where it is queued, come off the counter slice by slice, and are gone when it is freed" {
    try h.onFreshThread(aTreesBytesThroughItsLife);
}

fn aTreeQueuedTwiceIsCountedOnce() !void {
    const page = try h.Page.open();
    defer page.close();
    const tree = try HeldTree.make(page, "");
    const memory = memoryOf(page);
    const queue = queueOf(page);
    const books = dom.refcount_teardown.booksOf(tree.host) orelse return error.NoAgent;
    const alive = memory.live;
    const measure = dom.tree_teardown.measureUpTo(tree.root, DeferredTeardown.high_water);

    // Queued once.
    dom.refcount.holderDeref(tree.held);
    try testing.expectEqual(measure.bytes, memory.dying);
    try testing.expectEqual(@as(usize, 1), queue.len());

    // Held again before its slice (a holder the counts did not see: a
    // resurrection): its item leaves the queue and its bytes are back.
    const resurrections = books.resurrections;
    dom.refcount.holderRef(tree.held);
    try testing.expect(!tree.root.rc_flags.garbage);
    try testing.expectEqual(resurrections + 1, books.resurrections);
    try testing.expectEqual(@as(usize, 0), memory.dying);
    try testing.expectEqual(alive, memory.live);
    try testing.expect(queue.isEmpty());
    try testing.expectEqual(@as(usize, 0), queue.pendingNodes());

    // Queued a second time: one item, its bytes once.
    dom.refcount.holderDeref(tree.held);
    try testing.expect(tree.root.rc_flags.garbage);
    try testing.expectEqual(@as(usize, 1), queue.len());
    try testing.expectEqual(HeldTree.nodes, queue.pendingNodes());
    try testing.expectEqual(measure.bytes, memory.dying);
    try testing.expectEqual(alive - measure.bytes, memory.live);
    try testing.expectEqual(alive, memory.held());

    try turnUntilFreed(page);
    try testing.expect(tree.freed());
    try testing.expectEqual(@as(usize, 0), memory.dying);
    try testing.expectEqual(alive - measure.bytes, memory.live);
}

test "a tree queued twice is counted once" {
    try h.onFreshThread(aTreeQueuedTwiceIsCountedOnce);
}

fn aTreeRescuedBeforeItsFreeLeavesTheDyingBytes() !void {
    const page = try h.Page.open();
    defer page.close();
    const tree = try HeldTree.make(page, "");
    const memory = memoryOf(page);
    const queue = queueOf(page);
    const alive = memory.live;
    const measure = dom.tree_teardown.measureUpTo(tree.root, DeferredTeardown.high_water);

    dom.refcount.holderDeref(tree.held);
    try testing.expect(tree.root.rc_flags.garbage);
    try testing.expectEqual(alive - measure.bytes, memory.live);

    // A native insertion in the same task links it under a live parent: it
    // is alive again, at once - nothing of it is dying, all of it is in the
    // figure, and no item waits to free it.
    _ = try interfaces.Node.call_appendChild(try instanceOf(tree.host), tree.root_instance);
    try testing.expect(!tree.root.rc_flags.garbage);
    try testing.expect(tree.root.parent_node == tree.host);
    try testing.expectEqual(@as(usize, 0), memory.dying);
    try testing.expectEqual(alive, memory.live);
    try testing.expect(queue.isEmpty());

    try turn(page);
    try testing.expect(!tree.freed());
    try testing.expectEqual(alive, memory.live);
    try testing.expectEqual(alive, memory.held());
}

test "a tree rescued before its free leaves the dying bytes and is back in the figure" {
    try h.onFreshThread(aTreeRescuedBeforeItsFreeLeavesTheDyingBytes);
}

fn aTreeRescuedAfterSomeSlicesKeepsWhatIsLeft() !void {
    const page = try h.Page.open();
    defer page.close();
    const tree = try HeldTree.make(page, "");
    const memory = memoryOf(page);
    const queue = queueOf(page);
    const alive = memory.live;
    const measure = dom.tree_teardown.measureUpTo(tree.root, DeferredTeardown.high_water);

    dom.refcount.holderDeref(tree.held);
    // One slice frees 512 of its nodes, leaves first, from the end.
    try testing.expectEqual(DeferredTeardown.slice_budget, queue.runSlice(DeferredTeardown.slice_budget));
    try testing.expect(!queue.isEmpty());
    const left = dom.tree_teardown.measureUpTo(tree.root, DeferredTeardown.high_water);
    try testing.expectEqual(HeldTree.nodes - DeferredTeardown.slice_budget, left.nodes);
    try testing.expectEqual(left.bytes, memory.dying);
    try testing.expectEqual(alive - measure.bytes, memory.live);

    // Its root is held again: what is left of it is alive, and counted so.
    dom.refcount.holderRef(tree.root);
    try testing.expect(!tree.root.rc_flags.garbage);
    try testing.expect(queue.isEmpty());
    try testing.expectEqual(@as(usize, 0), memory.dying);
    try testing.expectEqual(alive - measure.bytes + left.bytes, memory.live);
    try testing.expectEqual(memory.live, memory.held());

    // Released: the rest is queued with the rest's bytes, and freed.
    dom.refcount.holderDeref(tree.root);
    try testing.expectEqual(left.bytes, memory.dying);
    try testing.expectEqual(left.nodes, queue.pendingNodes());
    try testing.expectEqual(alive - measure.bytes, memory.live);
    try turnUntilFreed(page);
    try testing.expect(tree.freed());
    try testing.expectEqual(@as(usize, 0), memory.dying);
    try testing.expectEqual(alive - measure.bytes, memory.live);
}

test "a tree rescued after some of its slices keeps what is left of it in the figure, and the rest dies once" {
    try h.onFreshThread(aTreeRescuedAfterSomeSlicesKeepsWhatIsLeft);
}

fn theSumIsAFloorForATreeWithRareBlocks() !void {
    const page = try h.Page.open();
    defer page.close();
    // Each p's classList makes its element a rare block, which the
    // element's type counts and frees - a walk of NodeBases does not see it.
    const tree = try HeldTree.make(page, "for (const p of host.querySelectorAll('p')) void p.classList;");
    const memory = memoryOf(page);
    const queue = queueOf(page);
    const alive = memory.live;
    const measure = dom.tree_teardown.measureUpTo(tree.root, DeferredTeardown.high_water);

    dom.refcount.holderDeref(tree.held);
    try testing.expectEqual(measure.bytes, memory.dying);
    try testing.expectEqual(alive - measure.bytes, memory.live);

    // The frees take more than the sum: the figure only ever falls while
    // the tree is freed, and nothing is given back at the end.
    var last = memory.live;
    while (!queue.isEmpty()) {
        _ = queue.runSlice(DeferredTeardown.slice_budget);
        try testing.expect(memory.live <= last);
        last = memory.live;
    }
    try testing.expect(tree.freed());
    try testing.expectEqual(@as(usize, 0), memory.dying);
    const unsummed = (alive - measure.bytes) - memory.live;
    // 700 rare blocks of one field: 16 bytes each at least, and a small
    // share of the tree.
    try testing.expect(unsummed >= 700 * 16);
    try testing.expect(unsummed * 10 < measure.bytes);
}

test "the bytes summed at the queueing are a floor: what an element's type counts beside its node comes off the figure at its free" {
    try h.onFreshThread(theSumIsAFloorForATreeWithRareBlocks);
}

fn theEngineIsToldAtTheNextSafePoint() !void {
    if (engine.capabilities.external_memory == .unsupported or engine.capabilities.heap_statistics == .unsupported) return error.SkipZigTest;
    const page = try h.Page.open();
    defer page.close();
    const tree = try HeldTree.make(page, "");
    const memory = memoryOf(page);
    const queue = queueOf(page);
    const agent = page.browser.getAgent() orelse return error.NoAgent;
    const measure = dom.tree_teardown.measureUpTo(tree.root, DeferredTeardown.high_water);
    // Well over a report step, so the queueing owes a report.
    try testing.expect(measure.bytes > 2 * ExternalMemory.report_step);

    // A binding exit: the engine is told the figure as it is now.
    try page.run("void document.body;");
    const told_alive = engine.heapStatistics(agent).external;

    dom.refcount.holderDeref(tree.held);
    try testing.expect(memory.due);
    // The next safe point - a binding's return to script - tells the
    // engine, while the tree still waits for its slices.
    try page.run("void document.body;");
    try testing.expect(!tree.freed());
    try testing.expectEqual(HeldTree.nodes, queue.pendingNodes());
    const told_queued = engine.heapStatistics(agent).external;
    const fell = told_alive -| told_queued;
    if (fell + 2 * ExternalMemory.report_step < measure.bytes)
        std.debug.print("a tree of {d} B was queued: the engine's external count fell {d} B ({d} -> {d})\n", .{ measure.bytes, fell, told_alive, told_queued });
    try testing.expect(fell + 2 * ExternalMemory.report_step >= measure.bytes);

    // Its slices free it: the engine is told nothing more.
    try turnUntilFreed(page);
    try testing.expect(tree.freed());
    try page.run("void document.body;");
    const told_freed = engine.heapStatistics(agent).external;
    const moved = if (told_freed > told_queued) told_freed - told_queued else told_queued - told_freed;
    try testing.expect(moved <= 2 * ExternalMemory.report_step);
}

test "the engine is told a queued tree's bytes are gone at the next safe point, before its slices free them" {
    try h.onFreshThread(theEngineIsToldAtTheNextSafePoint);
}

/// THE DESIGN'S HOST-SIDE RED (tmp/plans/dom-memory-figure-design.md 6,
/// batch A): a script makes and drops 400,000 divs in one task, and the
/// figure never holds a queued tree. The divs' wrappers die in young
/// collections; the agent's safe points release their references and the
/// counts queue each div; nothing frees them but the queue's own bound
/// (100,000 queued nodes), because no event loop turns. On main the figure
/// was the counter: with P divs queued it read P x 224 B more than was
/// alive (5.6, 14.3 and 26.8 MB at V8's three full collections of this
/// script).
///
/// The Browser allocates from the churn tests' allocator: the queue makes
/// and frees an item per dropped div (tests/AGENTS.md, "Tests come first").
fn theFigureHoldsNoQueuedTreeInOneTask() !void {
    var churn = @import("root").poisoning.ChurnAllocator.init("dm2_dying_figure_test: 400,000 dropped divs in one task");
    {
        const browser = try h.browser_mod.Browser.init(churn.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
        defer browser.deinit();
        try browser.navigate("about:blank", .window);
        const context = browser.current_context orelse return error.NoPage;
        try context.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
        const page: h.Page = .{ .browser = browser };
        // The initial about:blank's realm goes now, not in the middle of
        // what the test counts (refcount_holders_helpers.Page.open).
        for (0..3) |_| {
            try page.run("TestUtils.gc(); TestUtils.gc();");
            try turn(page);
        }
        const memory = memoryOf(page);
        const queue = queueOf(page);

        // What one detached div holds of the figure.
        try page.run("globalThis.one = document.createElement('div');");
        const per_div = dom.tree_teardown.measureUpTo(try page.node("one"), DeferredTeardown.high_water).bytes;
        try testing.expect(per_div >= runtime.SlabAllocator.slot_bytes + @sizeOf(dom.NodeBase));
        try page.collect();
        try turnUntilFreed(page);
        try testing.expect(queue.isEmpty());
        try testing.expectEqual(@as(usize, 0), memory.dying);

        const figure_before = memory.live;
        const nodes_before = dom.instance_bridge.entryCount(browser.scope);
        var most_queued: usize = 0;
        var most_over: usize = 0;
        for (0..8) |_| {
            // One chunk of the task: no event loop turn before or after it.
            try page.run("for (let i = 0; i < 50000; i++) document.createElement('div');");
            const queued = queue.pendingNodes();
            most_queued = @max(most_queued, queued);
            // Divs not freed yet, less those queued: the ones whose
            // wrappers no collection has taken yet. They are alive.
            const not_freed = dom.instance_bridge.entryCount(browser.scope) - nodes_before;
            const alive_bytes = (not_freed - queued) * per_div;
            const figure = memory.live -| figure_before;
            most_over = @max(most_over, figure -| alive_bytes);
            // Every queued div is dying, and none of them is in the figure.
            try testing.expectEqual(queued * per_div, memory.dying);
        }
        if (most_over > 4096) std.debug.print("400,000 dropped divs in one task: the figure read up to {d} B more than was alive, with up to {d} divs queued\n", .{ most_over, most_queued });
        try testing.expect(most_over <= 4096);
        // The script did queue divs between its chunks: the figure was
        // tested with trees waiting.
        if (most_queued < 10_000) std.debug.print("400,000 dropped divs in one task: at most {d} divs were queued at a chunk's end - the test saw no queued trees\n", .{most_queued});
        try testing.expect(most_queued >= 10_000);
    }
    try churn.deinit();
}

test "a script that drops 400,000 divs in one task: the figure never holds a queued tree" {
    try h.onFreshThread(theFigureHoldsNoQueuedTreeInOneTask);
}
