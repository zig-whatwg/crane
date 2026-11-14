//! Lane dm2 (batch A of tmp/plans/dom-memory-figure-design.md): the host side
//! of the figure a Browser's window agent tells its engine about its DOM -
//! runtime.gc.ExternalMemory, with runtime.gc.DeferredTeardown.
//!
//! The engine sets its next collection threshold from what it is told is
//! alive. The figure was a counter that fell only when a node was freed, and
//! a dead tree is freed in slices after it was decided dead: V8 was told the
//! dead were alive, and its limit climbed 11.7 -> 206.9 MB over four
//! collections with about 30 MB alive (lane dm1). The rule: the engine is
//! told the counter (`held`) LESS the bytes of the trees decided dead
//! (`dying`). A tree's bytes enter `dying` where it is queued for its sliced
//! free and leave it as its slices free them - or go back into the figure
//! when the tree is held again.
//!
//! These tests stand a counter in for a tree - nodes of a fixed size the
//! steps free a budget at a time - so each property is pinned without an
//! engine and without a DOM. tests/html/dm2_dying_figure_test.zig pins the
//! same life on real trees.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const DeferredTeardown = runtime.gc.DeferredTeardown;
const ExternalMemory = runtime.gc.ExternalMemory;
const SlabAllocator = runtime.SlabAllocator;
const Instance = runtime.Instance;

const delegates = .{};
const vtable = runtime.VTable{ .name = "Dm2DyingFigureTest", .deinit = null, .methods_ptr = &delegates };

/// A tree of `nodes` nodes, each counted as `node_bytes` in `memory` when it
/// was made; its steps free `budget` of them at a time, as a garbage tree's
/// do (dom.refcount_teardown).
const FakeTree = struct {
    memory: *ExternalMemory,
    nodes: usize,
    node_bytes: usize,
    freed: usize = 0,
    /// The tree was held again while its item waited: its steps free nothing
    /// and drop the item (the re-check of dom.refcount_teardown.runGarbageTree).
    held_again: bool = false,
    /// What a step does before it frees: another owner's end, say.
    during: ?*const fn (*FakeTree) void = null,
    queue: ?*DeferredTeardown = null,
    other_owner: ?*const anyopaque = null,

    /// Make the tree: its nodes are counted.
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
    if (tree.held_again) return .{ .freed = 0, .done = true };
    if (tree.during) |during| {
        tree.during = null;
        during(tree);
    }
    const n = @min(budget, tree.nodes - tree.freed);
    // Node by node, as a tree's teardown frees them.
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

    /// Queue `tree` as a garbage tree whose queueing summed `summed` bytes.
    fn push(self: *Fixture, tree: *FakeTree, summed: usize, owner: ?*const anyopaque) !*Instance {
        const instance = try self.slab.alloc(&vtable);
        try testing.expect(self.queue.push(.{
            .instance = instance,
            .generation = SlabAllocator.generationOf(instance),
            .owner = owner,
            .steps = &fake_steps,
            .data = tree,
            .weight = tree.nodes,
            .dying = .{ .memory = &self.memory, .bytes = summed },
        }));
        return instance;
    }
};

test "a queued tree's bytes leave the figure at the push, and the counter keeps them until they are freed" {
    var f = Fixture.init();
    defer f.deinit();
    // 1,000 nodes that stay alive, and a tree of 3,000 that dies.
    f.memory.add(1000 * 224);
    var tree = FakeTree.make(&f.memory, 3000, 224);
    const counted = 4000 * 224;
    try testing.expectEqual(@as(usize, counted), f.memory.live);
    try testing.expectEqual(@as(usize, 0), f.memory.dying);

    _ = try f.push(&tree, tree.bytes(), null);
    // Decided dead: out of the figure, still counted.
    try testing.expectEqual(@as(usize, 1000 * 224), f.memory.live);
    try testing.expectEqual(@as(usize, 3000 * 224), f.memory.dying);
    try testing.expectEqual(@as(usize, counted), f.memory.held());

    f.queue.drainAll();
    try testing.expectEqual(@as(usize, 1000 * 224), f.memory.live);
    try testing.expectEqual(@as(usize, 0), f.memory.dying);
    try testing.expectEqual(@as(usize, 1000 * 224), f.memory.held());
}

test "each slice takes what it frees off the counter and the dying bytes, and the figure does not move" {
    var f = Fixture.init();
    defer f.deinit();
    f.memory.add(500 * 192);
    var tree = FakeTree.make(&f.memory, 2000, 224);
    _ = try f.push(&tree, tree.bytes(), null);
    const figure = f.memory.live;
    try testing.expectEqual(@as(usize, 500 * 192), figure);

    var freed: usize = 0;
    var slices: usize = 0;
    while (!f.queue.isEmpty()) : (slices += 1) {
        freed += f.queue.runSlice(DeferredTeardown.slice_budget);
        try testing.expectEqual(figure, f.memory.live);
        try testing.expectEqual((2000 - freed) * 224, f.memory.dying);
        try testing.expectEqual(figure + (2000 - freed) * 224, f.memory.held());
        // Between slices nothing is being paid down.
        try testing.expectEqual(@as(usize, 0), f.memory.paying);
        try testing.expect(slices < 10);
    }
    try testing.expectEqual(@as(usize, 4), slices);
    try testing.expectEqual(@as(usize, 2000), freed);
    try testing.expectEqual(@as(usize, 0), f.memory.dying);
}

test "what a tree's frees take beyond the bytes its queueing summed comes off the figure" {
    var f = Fixture.init();
    defer f.deinit();
    f.memory.add(100_000);
    // Each node holds 240 bytes; the queueing's walk saw 224 of them (an
    // element's rare block is counted by its type, not by the walk).
    var tree = FakeTree.make(&f.memory, 1000, 240);
    _ = try f.push(&tree, 1000 * 224, null);
    try testing.expectEqual(@as(usize, 100_000 + 1000 * 16), f.memory.live);
    try testing.expectEqual(@as(usize, 1000 * 224), f.memory.dying);

    var last = f.memory.live;
    while (!f.queue.isEmpty()) {
        _ = f.queue.runSlice(300);
        // The sum is a floor: the figure only falls while the tree is freed.
        try testing.expect(f.memory.live <= last);
        last = f.memory.live;
    }
    try testing.expectEqual(@as(usize, 100_000), f.memory.live);
    try testing.expectEqual(@as(usize, 0), f.memory.dying);
}

test "a sum above what a tree's frees take goes back into the figure when its item ends" {
    var f = Fixture.init();
    defer f.deinit();
    f.memory.add(100_000);
    // The walk summed 224 bytes a node; each frees 200.
    var tree = FakeTree.make(&f.memory, 1000, 200);
    _ = try f.push(&tree, 1000 * 224, null);
    try testing.expectEqual(@as(usize, 300_000 - 224_000), f.memory.live);
    f.queue.drainAll();
    // Freed: 200,000 off the counter, and nothing is dying any more.
    try testing.expectEqual(@as(usize, 100_000), f.memory.live);
    try testing.expectEqual(@as(usize, 0), f.memory.dying);
    try testing.expectEqual(@as(usize, 100_000), f.memory.held());
}

test "a sum larger than everything counted moves only what is counted" {
    var f = Fixture.init();
    defer f.deinit();
    var tree = FakeTree.make(&f.memory, 10, 100);
    _ = try f.push(&tree, 5000, null);
    try testing.expectEqual(@as(usize, 0), f.memory.live);
    try testing.expectEqual(@as(usize, 1000), f.memory.dying);
    f.queue.drainAll();
    try testing.expectEqual(@as(usize, 0), f.memory.live);
    try testing.expectEqual(@as(usize, 0), f.memory.dying);
}

test "a tree held again before its teardown leaves the queue, and its bytes are back in the figure at once" {
    var f = Fixture.init();
    defer f.deinit();
    f.memory.add(50_000);
    var tree = FakeTree.make(&f.memory, 1500, 224);
    const instance = try f.push(&tree, tree.bytes(), null);
    try testing.expectEqual(@as(usize, 50_000), f.memory.live);
    try testing.expectEqual(@as(usize, 1500), f.queue.pendingNodes());

    try testing.expect(f.queue.withdraw(instance, SlabAllocator.generationOf(instance), &fake_steps));
    try testing.expectEqual(@as(usize, 50_000 + 1500 * 224), f.memory.live);
    try testing.expectEqual(@as(usize, 0), f.memory.dying);
    try testing.expect(f.queue.isEmpty());
    try testing.expectEqual(@as(usize, 0), f.queue.pendingNodes());
    // Nothing waits under that name any more.
    try testing.expect(!f.queue.withdraw(instance, SlabAllocator.generationOf(instance), &fake_steps));
    // The tree is alive: its nodes are freed by whoever holds it (here, the
    // end of the test).
    f.memory.sub(tree.bytes());
    try testing.expectEqual(@as(usize, 50_000), f.memory.live);
}

test "a tree queued twice is counted once" {
    var f = Fixture.init();
    defer f.deinit();
    f.memory.add(50_000);
    var tree = FakeTree.make(&f.memory, 1500, 224);
    const all = 50_000 + 1500 * 224;

    // Queued, held again, queued again: one item, one share of dying.
    const first = try f.push(&tree, tree.bytes(), null);
    try testing.expect(f.queue.withdraw(first, SlabAllocator.generationOf(first), &fake_steps));
    _ = try f.push(&tree, tree.bytes(), null);
    try testing.expectEqual(@as(usize, 1), f.queue.len());
    try testing.expectEqual(@as(usize, 1500), f.queue.pendingNodes());
    try testing.expectEqual(@as(usize, 1500 * 224), f.memory.dying);
    try testing.expectEqual(@as(usize, 50_000), f.memory.live);
    try testing.expectEqual(@as(usize, all), f.memory.held());

    f.queue.drainAll();
    try testing.expectEqual(@as(usize, 50_000), f.memory.live);
    try testing.expectEqual(@as(usize, 0), f.memory.dying);
}

test "a tree held again after some of its slices: what was freed is gone, the rest is back in the figure" {
    var f = Fixture.init();
    defer f.deinit();
    f.memory.add(10_000);
    var tree = FakeTree.make(&f.memory, 2000, 224);
    const instance = try f.push(&tree, tree.bytes(), null);
    try testing.expectEqual(@as(usize, 512), f.queue.runSlice(512));
    try testing.expectEqual(@as(usize, 10_000), f.memory.live);
    try testing.expectEqual(@as(usize, (2000 - 512) * 224), f.memory.dying);

    try testing.expect(f.queue.withdraw(instance, SlabAllocator.generationOf(instance), &fake_steps));
    try testing.expectEqual(@as(usize, 10_000 + (2000 - 512) * 224), f.memory.live);
    try testing.expectEqual(@as(usize, 0), f.memory.dying);
    try testing.expectEqual(@as(usize, 0), f.queue.pendingNodes());

    // Dead again: the rest is queued, with the rest's bytes.
    tree.nodes -= tree.freed;
    tree.freed = 0;
    _ = try f.push(&tree, tree.bytes(), null);
    try testing.expectEqual(@as(usize, 10_000), f.memory.live);
    f.queue.drainAll();
    try testing.expectEqual(@as(usize, 10_000), f.memory.live);
    try testing.expectEqual(@as(usize, 0), f.memory.dying);
}

test "an item its own steps drop - held again while a slice had it in hand - gives its bytes back" {
    var f = Fixture.init();
    defer f.deinit();
    var tree = FakeTree.make(&f.memory, 800, 224);
    _ = try f.push(&tree, tree.bytes(), null);
    try testing.expectEqual(@as(usize, 0), f.memory.live);
    tree.held_again = true;
    _ = f.queue.runSlice(DeferredTeardown.slice_budget);
    try testing.expect(f.queue.isEmpty());
    try testing.expectEqual(@as(usize, 800 * 224), f.memory.live);
    try testing.expectEqual(@as(usize, 0), f.memory.dying);
    f.memory.sub(tree.bytes());
}

test "an owner forgotten with its pools gives its items' bytes back: their frees are not the queue's" {
    var f = Fixture.init();
    defer f.deinit();
    // Two owners: two addresses.
    const realms: [2]u8 = .{ 0, 0 };
    const realm_a = &realms[0];
    const realm_b = &realms[1];
    var a = FakeTree.make(&f.memory, 400, 224);
    var b = FakeTree.make(&f.memory, 600, 192);
    _ = try f.push(&a, a.bytes(), realm_a);
    _ = try f.push(&b, b.bytes(), realm_b);
    try testing.expectEqual(@as(usize, 0), f.memory.live);

    f.queue.dropOwner(realm_a);
    try testing.expectEqual(@as(usize, 400 * 224), f.memory.live);
    try testing.expectEqual(@as(usize, 600 * 192), f.memory.dying);
    // The pools go: plain frees, outside any teardown.
    f.memory.sub(a.bytes());
    try testing.expectEqual(@as(usize, 0), f.memory.live);

    f.queue.drainOwner(realm_b);
    try testing.expectEqual(@as(usize, 0), f.memory.held());
}

/// The outer tree's first step ends another realm, whose drain runs that
/// realm's items inside this teardown.
fn endOtherRealm(tree: *FakeTree) void {
    tree.queue.?.drainOwner(tree.other_owner.?);
}

test "a teardown that drains another owner's items pays each tree's own bytes" {
    var f = Fixture.init();
    defer f.deinit();
    // Two owners: two addresses.
    const realms: [2]u8 = .{ 0, 0 };
    const realm_a = &realms[0];
    const realm_b = &realms[1];
    f.memory.add(7000);
    var outer = FakeTree.make(&f.memory, 1000, 224);
    // The inner tree's frees take 40 bytes a node more than was summed: paid
    // from the outer tree's share, they would leave the figure too high
    // until the outer tree is gone.
    var inner = FakeTree.make(&f.memory, 300, 232);
    outer.during = endOtherRealm;
    outer.queue = &f.queue;
    outer.other_owner = realm_b;
    _ = try f.push(&outer, outer.bytes(), realm_a);
    _ = try f.push(&inner, 300 * 192, realm_b);
    try testing.expectEqual(@as(usize, 7000 + 300 * 40), f.memory.live);

    // One slice of the outer tree: the inner one goes whole inside it.
    try testing.expectEqual(@as(usize, 512), f.queue.runSlice(512));
    try testing.expectEqual(@as(usize, 300), inner.freed);
    try testing.expectEqual(@as(usize, 7000), f.memory.live);
    try testing.expectEqual(@as(usize, (1000 - 512) * 224), f.memory.dying);
    f.queue.drainAll();
    try testing.expectEqual(@as(usize, 7000), f.memory.live);
    try testing.expectEqual(@as(usize, 0), f.memory.dying);
}

test "an allocation during a teardown is alive, and a free pays the tree's share before the figure" {
    var memory: ExternalMemory = .{};
    // A tree of 1,000 bytes is decided dead; 200 bytes more stay alive.
    memory.add(1200);
    const share = memory.decideDead(1000);
    try testing.expectEqual(@as(usize, 1000), share);
    try testing.expectEqual(@as(usize, 200), memory.live);

    const outer = memory.beginTeardown(share);
    try testing.expectEqual(@as(usize, 0), outer);
    memory.add(500);
    try testing.expectEqual(@as(usize, 700), memory.live);
    memory.sub(900);
    try testing.expectEqual(@as(usize, 700), memory.live);
    try testing.expectEqual(@as(usize, 100), memory.dying);
    // 100 bytes of the share are left: the other 200 come off the figure.
    memory.sub(300);
    try testing.expectEqual(@as(usize, 500), memory.live);
    try testing.expectEqual(@as(usize, 0), memory.dying);
    try testing.expectEqual(@as(usize, 0), memory.endTeardown(outer));
    // Outside a teardown a free comes off the figure.
    memory.sub(500);
    try testing.expectEqual(@as(usize, 0), memory.held());
}

test "queueing a tree owes the adapter a report once the figure fell a report step, and freeing it owes none" {
    var f = Fixture.init();
    defer f.deinit();
    f.memory.claim(&f.queue);
    defer f.memory.release();
    var tree = FakeTree.make(&f.memory, 3000, 224);
    // The adapter told its engine: 672,000 bytes.
    f.memory.markReported(f.memory.live);
    try testing.expect(!f.memory.due);
    try testing.expect(!f.queue.owed.report);

    // 672,000 bytes leave the figure: more than a step (128 KB).
    _ = try f.push(&tree, tree.bytes(), null);
    try testing.expect(f.memory.due);
    try testing.expect(f.queue.owed.report);
    // The adapter's safe point tells its engine the figure: 0.
    try testing.expectEqual(@as(usize, 0), f.memory.live);
    f.memory.markReported(f.memory.live);

    // The slices free the tree: the figure does not move, nothing is owed.
    f.queue.drainAll();
    try testing.expect(!f.memory.due);
    try testing.expect(!f.queue.owed.report);
    try testing.expectEqual(@as(usize, 0), f.memory.live);
}

test "a tree held again owes a report once the figure rose a report step" {
    var f = Fixture.init();
    defer f.deinit();
    f.memory.claim(&f.queue);
    defer f.memory.release();
    var tree = FakeTree.make(&f.memory, 3000, 224);
    const instance = try f.push(&tree, tree.bytes(), null);
    f.memory.markReported(f.memory.live);
    try testing.expect(f.queue.withdraw(instance, SlabAllocator.generationOf(instance), &fake_steps));
    try testing.expect(f.memory.due);
    try testing.expectEqual(@as(usize, 3000 * 224), f.memory.live);
    f.memory.sub(tree.bytes());
}
