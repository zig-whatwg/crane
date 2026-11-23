//! runtime.gc.DeferredTeardown: the agent's queue of native objects whose last
//! owner went away (a collected wrapper today; a reference count reaching zero
//! later), freed a bounded slice at a time from the agent's event loop, fully at
//! the ends of their realm and agent, and inline past a memory bound.
//!
//! The queue never interprets an item: its steps do. These tests stand a
//! counter in for a tree - `nodes` left to free - so each property is pinned
//! without an engine: slicing by budget, FIFO with resumption, the owner's
//! drain, drop and close, the memory bound and its re-entrancy guard.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const DeferredTeardown = runtime.gc.DeferredTeardown;
const SlabAllocator = runtime.SlabAllocator;
const Instance = runtime.Instance;

const delegates = .{};
const vtable = runtime.VTable{ .name = "DeferredTeardownTest", .deinit = null, .methods_ptr = &delegates };

/// A tree of `nodes` nodes the steps free `budget` at a time, recording the
/// order items finished in.
const FakeTree = struct {
    nodes: usize,
    freed: usize = 0,
    finished: bool = false,
    /// What a step does before freeing: another item queued (a collection
    /// during teardown), or another owner's end.
    during: ?*const fn (*FakeTree) void = null,
    queue: ?*DeferredTeardown = null,
    log: ?*std.ArrayListUnmanaged(usize) = null,
    id: usize = 0,
};

var trees: [8]FakeTree = undefined;

fn treeOf(item: *DeferredTeardown.Item) *FakeTree {
    return @ptrCast(@alignCast(item.data.?));
}

fn runFake(item: *DeferredTeardown.Item, budget: usize) DeferredTeardown.Progress {
    const tree = treeOf(item);
    if (tree.during) |during| during(tree);
    const n = @min(budget, tree.nodes - tree.freed);
    tree.freed += n;
    if (tree.freed < tree.nodes) return .{ .freed = n, .done = false };
    tree.finished = true;
    if (tree.log) |log| log.append(testing.allocator, tree.id) catch {};
    return .{ .freed = n, .done = true };
}

const fake_steps: DeferredTeardown.Steps = .{ .run = runFake };

/// The slab the tests' instances come from (each test makes and ends it).
var test_slab: SlabAllocator = undefined;

fn setupSlab() void {
    test_slab = SlabAllocator.init(testing.allocator);
}

fn push(queue: *DeferredTeardown, tree: *FakeTree, owner: ?*const anyopaque) !*Instance {
    const inst = try test_slab.alloc(&vtable);
    try testing.expect(queue.push(.{
        .instance = inst,
        .generation = SlabAllocator.generationOf(inst),
        .owner = owner,
        .steps = &fake_steps,
        .data = tree,
        .weight = tree.nodes,
    }));
    return inst;
}

test "a slice frees at most its budget, and the item resumes in the next one" {
    setupSlab();
    defer test_slab.deinit();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();

    trees[0] = .{ .nodes = 10_000 };
    _ = try push(&queue, &trees[0], null);
    try testing.expectEqual(@as(usize, 10_000), queue.pendingNodes());

    var slices: usize = 0;
    while (!queue.isEmpty()) : (slices += 1) {
        const freed = queue.runSlice(1000);
        try testing.expect(freed <= 1000);
        try testing.expect(slices < 100);
    }
    // A 10,000-node tree over several slices, never in one.
    try testing.expectEqual(@as(usize, 10), slices);
    try testing.expect(trees[0].finished);
    try testing.expectEqual(@as(usize, 0), queue.pendingNodes());
}

test "items are freed in the order they were queued, a slice running into the next item" {
    setupSlab();
    defer test_slab.deinit();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var log: std.ArrayListUnmanaged(usize) = .empty;
    defer log.deinit(testing.allocator);

    for (0..3) |i| {
        trees[i] = .{ .nodes = 300, .id = i, .log = &log };
        _ = try push(&queue, &trees[i], null);
    }
    // 500: the first item and part of the second.
    try testing.expectEqual(@as(usize, 500), queue.runSlice(500));
    try testing.expectEqualSlices(usize, &.{0}, log.items);
    try testing.expectEqual(@as(usize, 200), trees[1].freed);
    while (!queue.isEmpty()) _ = queue.runSlice(500);
    try testing.expectEqualSlices(usize, &.{ 0, 1, 2 }, log.items);
}

test "an owner's end drains its items fully and leaves the others queued" {
    setupSlab();
    defer test_slab.deinit();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var realm_a: u8 = 0;
    var realm_b: u8 = 0;

    trees[0] = .{ .nodes = 5000 };
    trees[1] = .{ .nodes = 5000 };
    trees[2] = .{ .nodes = 5000 };
    _ = try push(&queue, &trees[0], &realm_a);
    _ = try push(&queue, &trees[1], &realm_b);
    _ = try push(&queue, &trees[2], &realm_a);

    queue.drainOwner(&realm_a);
    try testing.expect(trees[0].finished and trees[2].finished);
    try testing.expectEqual(@as(usize, 0), trees[1].freed);
    try testing.expectEqual(@as(usize, 1), queue.len());
    try testing.expectEqual(@as(usize, 5000), queue.pendingNodes());

    queue.drainAll();
    try testing.expect(trees[1].finished);
    try testing.expect(queue.isEmpty());
}

test "an item in the middle of its teardown is finished by its owner's end" {
    setupSlab();
    defer test_slab.deinit();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var realm: u8 = 0;

    trees[0] = .{ .nodes = 5000 };
    _ = try push(&queue, &trees[0], &realm);
    _ = queue.runSlice(1000);
    try testing.expectEqual(@as(usize, 1000), trees[0].freed);
    queue.drainOwner(&realm);
    try testing.expect(trees[0].finished);
    try testing.expect(queue.isEmpty());
}

test "drop forgets an owner's items without running them" {
    setupSlab();
    defer test_slab.deinit();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var realm: u8 = 0;

    trees[0] = .{ .nodes = 10 };
    _ = try push(&queue, &trees[0], &realm);
    queue.dropOwner(&realm);
    try testing.expect(queue.isEmpty());
    try testing.expectEqual(@as(usize, 0), trees[0].freed);
    try testing.expectEqual(@as(usize, 0), queue.pendingNodes());
}

test "a closed queue refuses items: the caller tears them down inline" {
    setupSlab();
    defer test_slab.deinit();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();

    queue.close();
    const inst = try test_slab.alloc(&vtable);
    trees[0] = .{ .nodes = 1 };
    try testing.expect(!queue.push(.{
        .instance = inst,
        .generation = SlabAllocator.generationOf(inst),
        .owner = null,
        .steps = &fake_steps,
        .data = &trees[0],
        .weight = 1,
    }));
    try testing.expect(queue.isEmpty());
}

test "under the high-water mark relieve frees nothing; over it, what was added and a slice more" {
    setupSlab();
    defer test_slab.deinit();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();

    const big = DeferredTeardown.high_water / 4;
    for (0..4) |i| {
        trees[i] = .{ .nodes = big };
        _ = try push(&queue, &trees[i], null);
        queue.relieve(big);
    }
    // At the mark, not over it: everything still queued.
    try testing.expectEqual(DeferredTeardown.high_water, queue.pendingNodes());
    try testing.expectEqual(@as(usize, 0), trees[0].freed);

    trees[4] = .{ .nodes = big };
    _ = try push(&queue, &trees[4], null);
    queue.relieve(big);
    // Over the mark: the item's weight plus one slice came off, so churn past
    // the mark shrinks the queue instead of growing it.
    try testing.expectEqual(DeferredTeardown.high_water - DeferredTeardown.slice_budget, queue.pendingNodes());
    queue.drainAll();
}

fn pushAnotherAndRelieve(tree: *FakeTree) void {
    const queue = tree.queue.?;
    tree.during = null;
    trees[7] = .{ .nodes = DeferredTeardown.high_water };
    const inst = test_slab.alloc(&vtable) catch return;
    _ = queue.push(.{
        .instance = inst,
        .generation = SlabAllocator.generationOf(inst),
        .owner = null,
        .steps = &fake_steps,
        .data = &trees[7],
        .weight = trees[7].nodes,
    });
    // Over the mark, but a slice is running: the bound waits for it.
    queue.relieve(trees[7].nodes);
}

test "a collection during a slice queues its items but runs no nested slice" {
    setupSlab();
    defer test_slab.deinit();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();

    trees[0] = .{ .nodes = 10, .during = pushAnotherAndRelieve, .queue = &queue };
    _ = try push(&queue, &trees[0], null);
    _ = queue.runSlice(DeferredTeardown.slice_budget);
    try testing.expect(trees[0].finished);
    // Queued during the slice, and untouched by it except as the next item.
    try testing.expectEqual(@as(usize, 1), queue.len());
    try testing.expect(trees[7].freed <= DeferredTeardown.slice_budget);
    queue.drainAll();
    try testing.expect(trees[7].finished);
}

var other_realm: u8 = 0;

fn endOtherRealm(tree: *FakeTree) void {
    tree.during = null;
    tree.queue.?.drainOwner(&other_realm);
}

test "an item whose teardown ends another realm drains that realm's items, nested" {
    setupSlab();
    defer test_slab.deinit();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var realm: u8 = 0;

    trees[0] = .{ .nodes = 10, .during = endOtherRealm, .queue = &queue };
    trees[1] = .{ .nodes = 10 };
    _ = try push(&queue, &trees[0], &realm);
    _ = try push(&queue, &trees[1], &other_realm);
    _ = queue.runSlice(5);
    // The first item's step ended the other realm: its item went then, in
    // full, while the first item was in hand.
    try testing.expect(trees[1].finished);
    try testing.expect(!trees[0].finished);
    queue.drainOwner(&realm);
    try testing.expect(queue.isEmpty());
}

// ============================================================================
// The fresh rule for trees inside a callback (lane mem1, follow-up A)
// ============================================================================

/// `push` with the tree's lowest slab generation: the instance's own, as a
/// one-node tree's walk would find (dom.tree_teardown.Measure).
fn pushMade(queue: *DeferredTeardown, tree: *FakeTree) !*Instance {
    const inst = try test_slab.alloc(&vtable);
    try testing.expect(queue.push(.{
        .instance = inst,
        .generation = SlabAllocator.generationOf(inst),
        .owner = null,
        .steps = &fake_steps,
        .data = tree,
        .weight = tree.nodes,
        .min_generation = SlabAllocator.generationOf(inst),
    }));
    return inst;
}

/// A binding called from the innermost callback's script returns to it.
fn bindingReturn(queue: *DeferredTeardown) void {
    queue.enterAlgorithm();
    queue.leaveAlgorithmToScript();
}

test "inside a callback, past a bound, a binding's return frees a slice of the trees made inside it and none older" {
    setupSlab();
    defer test_slab.deinit();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();

    // Made and queued before the callback began.
    trees[0] = .{ .nodes = 60_000 };
    _ = try pushMade(&queue, &trees[0]);
    const outer = queue.enterCallback(.{ .slab = &test_slab, .generation = test_slab.generationNow() });
    // Made inside it: together they pass high_water.
    trees[1] = .{ .nodes = 60_000 };
    _ = try pushMade(&queue, &trees[1]);
    try testing.expect(queue.pendingNodes() > DeferredTeardown.high_water);

    bindingReturn(&queue);
    try testing.expectEqual(DeferredTeardown.slice_budget, trees[1].freed);
    try testing.expectEqual(@as(usize, 0), trees[0].freed);

    // The callback returns; at depth zero everything is the queue's again.
    queue.leaveCallback(outer);
    queue.drainAll();
    try testing.expect(trees[0].finished and trees[1].finished);
}

test "under the bounds a binding's return inside a callback frees nothing" {
    setupSlab();
    defer test_slab.deinit();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();

    const outer = queue.enterCallback(.{ .slab = &test_slab, .generation = test_slab.generationNow() });
    trees[0] = .{ .nodes = 1_000 };
    _ = try pushMade(&queue, &trees[0]);
    bindingReturn(&queue);
    try testing.expectEqual(@as(usize, 0), trees[0].freed);
    queue.leaveCallback(outer);
    queue.drainAll();
}

test "fresh is proven, never assumed: no generation, another slab's object, or no callback known is old" {
    setupSlab();
    defer test_slab.deinit();
    var other_slab = SlabAllocator.init(testing.allocator);
    defer other_slab.deinit();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();

    const entry = test_slab.generationNow();
    const made = try test_slab.alloc(&vtable);
    const elsewhere = try other_slab.alloc(&vtable);
    var item: DeferredTeardown.Item = .{
        .instance = made,
        .generation = SlabAllocator.generationOf(made),
        .owner = null,
        .steps = &fake_steps,
        .data = null,
        .weight = 1,
        .min_generation = SlabAllocator.generationOf(made),
    };
    // No callback on the stack.
    try testing.expect(!queue.isFresh(&item));
    // A callback whose entry nothing knows.
    var outer = queue.enterCallback(.{});
    try testing.expect(!queue.isFresh(&item));
    queue.leaveCallback(outer);

    outer = queue.enterCallback(.{ .slab = &test_slab, .generation = entry });
    try testing.expect(queue.isFresh(&item));
    // A tree no walk vouched for.
    item.min_generation = 0;
    try testing.expect(!queue.isFresh(&item));
    // A tree begun before the callback.
    item.min_generation = entry - 1;
    try testing.expect(!queue.isFresh(&item));
    // Another slab's object, whatever its generation says.
    item.instance = elsewhere;
    item.min_generation = SlabAllocator.generationOf(elsewhere) + entry;
    try testing.expect(!queue.isFresh(&item));
    queue.leaveCallback(outer);
    test_slab.free(made);
    other_slab.free(elsewhere);
}

test "a tree made inside a nested callback is fresh in the callback around it, and not in a later one" {
    setupSlab();
    defer test_slab.deinit();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();

    const outer = queue.enterCallback(.{ .slab = &test_slab, .generation = test_slab.generationNow() });
    const inner = queue.enterCallback(.{ .slab = &test_slab, .generation = test_slab.generationNow() });
    const made = try test_slab.alloc(&vtable);
    var item: DeferredTeardown.Item = .{
        .instance = made,
        .generation = SlabAllocator.generationOf(made),
        .owner = null,
        .steps = &fake_steps,
        .data = null,
        .weight = 1,
        .min_generation = SlabAllocator.generationOf(made),
    };
    try testing.expect(queue.isFresh(&item));
    queue.leaveCallback(inner);
    // Back in the outer callback, which began earlier still.
    try testing.expect(queue.isFresh(&item));
    // A sibling callback that began after the tree was made: its caller may
    // hold it.
    const later = queue.enterCallback(.{ .slab = &test_slab, .generation = test_slab.generationNow() });
    try testing.expect(!queue.isFresh(&item));
    queue.leaveCallback(later);
    queue.leaveCallback(outer);
    test_slab.free(made);
}

test "a finalizer's stamp by generation: the innermost callback's for what it made, the outermost's for what an outer one made, none for the rest" {
    setupSlab();
    defer test_slab.deinit();
    var other_slab = SlabAllocator.init(testing.allocator);
    defer other_slab.deinit();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();

    const before = try test_slab.alloc(&vtable);
    const elsewhere = try other_slab.alloc(&vtable);
    const generation_before = SlabAllocator.generationOf(before);
    // No callback on the stack: depth zero finalizes everything.
    try testing.expectEqual(@as(u32, 0), queue.freshSerialOf(&test_slab, generation_before));

    const outer = queue.enterCallback(.{ .slab = &test_slab, .generation = test_slab.generationNow() });
    const in_outer = try test_slab.alloc(&vtable);
    const inner = queue.enterCallback(.{ .slab = &test_slab, .generation = test_slab.generationNow() });
    const in_inner = try test_slab.alloc(&vtable);
    const innermost = queue.callback.active;
    const outermost = queue.callback.outermost;
    try testing.expect(innermost > outermost);

    // Made inside the innermost callback: fresh for it.
    try testing.expectEqual(innermost, queue.freshSerialOf(&test_slab, SlabAllocator.generationOf(in_inner)));
    // Made inside the outer one before the inner began: waits for the outer.
    try testing.expectEqual(outermost, queue.freshSerialOf(&test_slab, SlabAllocator.generationOf(in_outer)));
    // Made before every callback on the stack.
    try testing.expectEqual(@as(u32, 0), queue.freshSerialOf(&test_slab, generation_before));
    // No generation known, or another slab's object whatever its number.
    try testing.expectEqual(@as(u32, 0), queue.freshSerialOf(&test_slab, SlabAllocator.dead_generation));
    try testing.expectEqual(@as(u32, 0), queue.freshSerialOf(&other_slab, SlabAllocator.generationOf(in_inner)));
    try testing.expectEqual(@as(u32, 0), queue.freshSerialOf(SlabAllocator.ownerOf(elsewhere), SlabAllocator.generationOf(elsewhere) + test_slab.generationNow()));

    // Back in the outer callback: what the inner one made is fresh there.
    queue.leaveCallback(inner);
    try testing.expectEqual(outermost, queue.callback.active);
    try testing.expectEqual(outermost, queue.freshSerialOf(&test_slab, SlabAllocator.generationOf(in_inner)));
    try testing.expectEqual(outermost, queue.freshSerialOf(&test_slab, SlabAllocator.generationOf(in_outer)));
    queue.leaveCallback(outer);
    // The stack is empty again: nothing is fresh.
    try testing.expectEqual(@as(u32, 0), queue.freshSerialOf(&test_slab, SlabAllocator.generationOf(in_inner)));

    // A callback whose entry nothing knows proves nothing fresh.
    const unknown = queue.enterCallback(.{});
    try testing.expectEqual(@as(u32, 0), queue.freshSerialOf(&test_slab, SlabAllocator.generationOf(in_inner)));
    queue.leaveCallback(unknown);

    // A stopped clock stamps nothing: its invocations share one value, and
    // an outermost serial would compare as the innermost's.
    queue.callback.serial = std.math.maxInt(u32);
    const stopped = queue.enterCallback(.{ .slab = &test_slab, .generation = SlabAllocator.generationOf(in_inner) });
    try testing.expectEqual(@as(u32, 0), queue.freshSerialOf(&test_slab, SlabAllocator.generationOf(in_inner)));
    queue.leaveCallback(stopped);

    for ([_]*Instance{ before, in_outer, in_inner }) |inst| test_slab.free(inst);
    other_slab.free(elsewhere);
}
