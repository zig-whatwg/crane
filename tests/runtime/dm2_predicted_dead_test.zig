//! Lane dm2 (batch B of tmp/plans/dom-memory-figure-design.md, section 3.2
//! B): the host side of a prediction - runtime.gc.ExternalMemory's
//! `predicted` pool, with runtime.gc.DeferredTeardown.
//!
//! An engine computes the threshold of its next collection when a collection
//! ends. The trees that collection made dead are still in the figure then:
//! their wrappers' references are released at the agent's next safe point,
//! and only there do the counts queue each tree and take its bytes out
//! (batch A, tests/runtime/dm2_dying_figure_test.zig). So the owner of the
//! counts is asked inside the collection which trees die with the wrappers
//! found dead (dom.dying_trees), and their bytes leave the figure THERE,
//! into a pool (`predictDead`). Each tree's queueing takes its bytes from
//! the pool, so no tree is taken out of the figure twice; what no queueing
//! took once every reference is released was predicted dead and lived, and
//! goes back (`settlePredictions`).
//!
//! These tests stand a counter in for a tree, with no engine and no DOM.
//! tests/html/dm2_dying_trees_test.zig pins the rule that decides which
//! trees die, and the whole path through a collection, on real trees.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const DeferredTeardown = runtime.gc.DeferredTeardown;
const ExternalMemory = runtime.gc.ExternalMemory;
const SlabAllocator = runtime.SlabAllocator;
const Instance = runtime.Instance;

const delegates = .{};
const vtable = runtime.VTable{ .name = "Dm2PredictedDeadTest", .deinit = null, .methods_ptr = &delegates };

/// A tree of `nodes` nodes of `node_bytes` each, counted in `memory` when
/// made; its steps free a budget of them at a time.
const FakeTree = struct {
    memory: *ExternalMemory,
    nodes: usize,
    node_bytes: usize,
    freed: usize = 0,

    fn make(memory: *ExternalMemory, nodes: usize, node_bytes: usize) FakeTree {
        memory.add(nodes * node_bytes);
        return .{ .memory = memory, .nodes = nodes, .node_bytes = node_bytes };
    }

    fn bytes(self: *const FakeTree) usize {
        return self.nodes * self.node_bytes;
    }
};

fn runFake(item: *DeferredTeardown.Item, budget: usize) DeferredTeardown.Progress {
    const tree: *FakeTree = @ptrCast(@alignCast(item.data.?));
    const n = @min(budget, tree.nodes - tree.freed);
    for (0..n) |_| tree.memory.sub(tree.node_bytes);
    tree.freed += n;
    return .{ .freed = n, .done = tree.freed == tree.nodes };
}

const fake_steps: DeferredTeardown.Steps = .{ .run = runFake };

const Fixture = struct {
    slab: SlabAllocator,
    queue: DeferredTeardown,
    memory: ExternalMemory = .{},

    fn init() Fixture {
        return .{ .slab = SlabAllocator.init(testing.allocator), .queue = DeferredTeardown.init(testing.allocator) };
    }

    fn deinit(self: *Fixture) void {
        self.queue.deinit();
        self.slab.deinit();
    }

    /// The counts queue `tree` (its wrapper's reference was released): its
    /// queueing sums `tree.bytes()`.
    fn queueTree(self: *Fixture, tree: *FakeTree) !void {
        const instance = try self.slab.alloc(&vtable);
        try testing.expect(self.queue.push(.{
            .instance = instance,
            .generation = SlabAllocator.generationOf(instance),
            .owner = null,
            .steps = &fake_steps,
            .data = tree,
            .weight = tree.nodes,
            .dying = .{ .memory = &self.memory, .bytes = tree.bytes() },
        }));
    }
};

test "what a collection predicts dead leaves the figure in its pause, and stays counted until it is freed" {
    var f = Fixture.init();
    defer f.deinit();
    f.memory.claim(&f.queue);
    defer f.memory.release();
    // 1,000 nodes stay alive; two trees die with the wrappers a collection
    // found dead.
    f.memory.add(1000 * 224);
    const a = FakeTree.make(&f.memory, 3000, 224);
    const b = FakeTree.make(&f.memory, 500, 192);
    const counted = f.memory.live;
    // The engine was told all of it at the last safe point.
    f.memory.markReported(f.memory.live);

    try testing.expectEqual(a.bytes() + b.bytes(), f.memory.predictDead(a.bytes() + b.bytes(), 2));
    // Out of the figure before any release ran - what the engine sets its
    // next threshold from - and still counted: nothing was freed.
    try testing.expectEqual(@as(usize, 1000 * 224), f.memory.live);
    try testing.expectEqual(a.bytes() + b.bytes(), f.memory.dying);
    try testing.expectEqual(a.bytes() + b.bytes(), f.memory.predicted);
    try testing.expectEqual(counted, f.memory.held());
    try testing.expectEqual(@as(u64, 2), f.queue.books.predicted);
    try testing.expectEqual(@as(u64, a.bytes() + b.bytes()), f.queue.books.predicted_bytes);
    // The adapter that asked tells its engine in the same pause: predicting
    // owes no report at a safe point.
    try testing.expect(!f.queue.owed.report);
}

test "a predicted tree's queueing takes its bytes from the pool: it leaves the figure once" {
    var f = Fixture.init();
    defer f.deinit();
    f.memory.claim(&f.queue);
    defer f.memory.release();
    f.memory.add(1000 * 224);
    var a = FakeTree.make(&f.memory, 3000, 224);
    var b = FakeTree.make(&f.memory, 500, 192);
    _ = f.memory.predictDead(a.bytes() + b.bytes(), 2);
    const figure = f.memory.live;

    // The safe point releases the wrappers' references; the counts queue
    // each tree. The figure does not move: these bytes left it in the pause.
    try f.queueTree(&a);
    try testing.expectEqual(figure, f.memory.live);
    try testing.expectEqual(b.bytes(), f.memory.predicted);
    try testing.expectEqual(a.bytes() + b.bytes(), f.memory.dying);
    try f.queueTree(&b);
    try testing.expectEqual(figure, f.memory.live);
    try testing.expectEqual(@as(usize, 0), f.memory.predicted);
    try testing.expectEqual(a.bytes() + b.bytes(), f.memory.dying);

    // Every reference is released: nothing is left to put back.
    try testing.expectEqual(@as(usize, 0), f.memory.settlePredictions());
    try testing.expectEqual(figure, f.memory.live);
    try testing.expectEqual(@as(u64, 0), f.queue.books.put_back_bytes);

    // The slices free them: off the counter, and the figure still does not
    // move.
    f.queue.drainAll();
    try testing.expectEqual(figure, f.memory.live);
    try testing.expectEqual(@as(usize, 0), f.memory.dying);
    try testing.expectEqual(@as(usize, 1000 * 224), f.memory.held());
}

test "a tree predicted dead that lived is back in the figure once every reference is released" {
    var f = Fixture.init();
    defer f.deinit();
    f.memory.claim(&f.queue);
    defer f.memory.release();
    f.memory.add(1000 * 224);
    var dies = FakeTree.make(&f.memory, 3000, 224);
    // A native reference below its root keeps this one (an image's pending
    // load): the marks could not show it.
    const lives = FakeTree.make(&f.memory, 2000, 224);
    const counted = f.memory.live;
    _ = f.memory.predictDead(dies.bytes() + lives.bytes(), 2);
    f.memory.markReported(f.memory.live);
    try testing.expectEqual(@as(usize, 1000 * 224), f.memory.live);

    // The releases: only one tree is queued.
    try f.queueTree(&dies);
    try testing.expectEqual(lives.bytes(), f.memory.predicted);

    // The drain emptied its list: what is left was predicted dead and lived.
    try testing.expectEqual(lives.bytes(), f.memory.settlePredictions());
    try testing.expectEqual(@as(usize, 0), f.memory.predicted);
    try testing.expectEqual(@as(usize, 1000 * 224) + lives.bytes(), f.memory.live);
    try testing.expectEqual(dies.bytes(), f.memory.dying);
    try testing.expectEqual(counted, f.memory.held());
    try testing.expectEqual(@as(u64, lives.bytes()), f.queue.books.put_back_bytes);
    // The engine was told it was gone: it hears of the growth at the next
    // report (448,000 bytes: past a step).
    try testing.expect(f.memory.due);
    try testing.expect(f.queue.owed.report);

    f.queue.drainAll();
    try testing.expectEqual(@as(usize, 1000 * 224) + lives.bytes(), f.memory.live);
    try testing.expectEqual(@as(usize, 0), f.memory.dying);
}

test "the pool is bytes: a tree nobody predicted takes from it, and the settle puts back exactly the rest" {
    var f = Fixture.init();
    defer f.deinit();
    f.memory.claim(&f.queue);
    defer f.memory.release();
    f.memory.add(100_000);
    // Predicted dead, and it lives.
    const predicted = FakeTree.make(&f.memory, 1000, 200);
    // Not predicted (script dropped it after the collection), and it dies
    // before the releases are done.
    var unpredicted = FakeTree.make(&f.memory, 300, 200);
    _ = f.memory.predictDead(predicted.bytes(), 1);
    try testing.expectEqual(@as(usize, 100_000 + 60_000), f.memory.live);

    try f.queueTree(&unpredicted);
    // It took its 60,000 from the pool: the figure reads 60,000 too many
    // and the pool 60,000 too few, until the settle.
    try testing.expectEqual(@as(usize, 100_000 + 60_000), f.memory.live);
    try testing.expectEqual(@as(usize, 140_000), f.memory.predicted);

    // The settle puts back what is left, and the figure is exact: 100,000
    // alive and the predicted tree's 200,000.
    try testing.expectEqual(@as(usize, 140_000), f.memory.settlePredictions());
    try testing.expectEqual(@as(usize, 300_000), f.memory.live);
    try testing.expectEqual(unpredicted.bytes(), f.memory.dying);
    f.queue.drainAll();
    try testing.expectEqual(@as(usize, 300_000), f.memory.live);
    try testing.expectEqual(@as(usize, 300_000), f.memory.held());
}

test "a predicted tree a forced teardown frees before its release is not put back" {
    var f = Fixture.init();
    defer f.deinit();
    f.memory.claim(&f.queue);
    defer f.memory.release();
    f.memory.add(10_000);
    const tree = FakeTree.make(&f.memory, 1000, 224);
    _ = f.memory.predictDead(tree.bytes(), 1);
    try testing.expectEqual(@as(usize, 10_000), f.memory.live);

    // Its realm ends before the safe point: its nodes are freed whatever
    // the counts say, outside any queued teardown. Their bytes left the
    // figure in the pause; what the figure cannot give comes off the pool.
    for (0..1000) |_| f.memory.sub(224);
    try testing.expectEqual(@as(usize, 0), f.memory.live);
    try testing.expectEqual(@as(usize, 10_000), f.memory.predicted);
    try testing.expectEqual(@as(usize, 10_000), f.memory.dying);

    // The settle puts back the rest: exactly what is alive.
    try testing.expectEqual(@as(usize, 10_000), f.memory.settlePredictions());
    try testing.expectEqual(@as(usize, 10_000), f.memory.live);
    try testing.expectEqual(@as(usize, 0), f.memory.dying);
    try testing.expectEqual(@as(usize, 10_000), f.memory.held());
}

test "a prediction above everything counted moves only what is counted" {
    var f = Fixture.init();
    defer f.deinit();
    f.memory.add(1000);
    try testing.expectEqual(@as(usize, 1000), f.memory.predictDead(5000, 1));
    try testing.expectEqual(@as(usize, 0), f.memory.live);
    try testing.expectEqual(@as(usize, 1000), f.memory.predicted);
    try testing.expectEqual(@as(usize, 1000), f.memory.settlePredictions());
    try testing.expectEqual(@as(usize, 1000), f.memory.live);
    try testing.expectEqual(@as(usize, 0), f.memory.dying);
    f.memory.sub(1000);
}

test "the agent's end puts back what a collection predicted dead and no queueing took" {
    var f = Fixture.init();
    defer f.deinit();
    f.memory.claim(&f.queue);
    f.memory.add(50_000);
    _ = f.memory.predictDead(20_000, 1);
    try testing.expectEqual(@as(usize, 30_000), f.memory.live);
    f.memory.release();
    try testing.expectEqual(@as(usize, 50_000), f.memory.live);
    try testing.expectEqual(@as(usize, 0), f.memory.predicted);
    try testing.expectEqual(@as(usize, 0), f.memory.dying);
    f.memory.sub(50_000);
}

fn rootLives(root: *Instance) bool {
    return root.vtable == &living_vtable;
}

const living_vtable = runtime.VTable{ .name = "Dm2PredictedDeadTest.living", .deinit = null, .methods_ptr = &delegates };

test "Debug: a root predicted dead that is alive when the releases are done is counted; one freed or decided dead is not" {
    if (!DeferredTeardown.prediction_checks) return error.SkipZigTest;
    var f = Fixture.init();
    defer f.deinit();
    f.memory.claim(&f.queue);
    defer f.memory.release();
    f.memory.add(3 * 224);
    // Three roots a collection predicted dead.
    const freed = try f.slab.alloc(&vtable);
    const decided = try f.slab.alloc(&vtable);
    const alive = try f.slab.alloc(&living_vtable);
    for ([_]*Instance{ freed, decided, alive }) |root| {
        f.queue.notePredicted(.{ .instance = root, .generation = SlabAllocator.generationOf(root), .lives = &rootLives });
    }
    _ = f.memory.predictDead(3 * 224, 3);

    // By the releases' end: one was queued and freed (its slot is free
    // again), one is decided dead and waits for its slice (`lives` answers
    // false), one is still alive.
    f.slab.free(freed);
    f.memory.sub(224);
    _ = f.memory.decideDead(224);
    try testing.expectEqual(@as(usize, 224), f.memory.settlePredictions());
    try testing.expectEqual(@as(u64, 1), f.queue.books.mispredicted);
    try testing.expectEqual(@as(u64, 224), f.queue.books.put_back_bytes);

    // Counted once: the next settle has no roots left to look at.
    try testing.expectEqual(@as(usize, 0), f.memory.settlePredictions());
    try testing.expectEqual(@as(u64, 1), f.queue.books.mispredicted);

    // (The test's own bookkeeping: the decided root's bytes back, and all
    // of it freed.)
    f.memory.rescue(224);
    f.memory.sub(2 * 224);
}
