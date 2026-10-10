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

fn setupSlab() void {
    SlabAllocator.init(testing.allocator);
}

fn push(queue: *DeferredTeardown, tree: *FakeTree, owner: ?*const anyopaque) !*Instance {
    const inst = try SlabAllocator.get().alloc(&vtable);
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
    defer SlabAllocator.deinit();
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
    defer SlabAllocator.deinit();
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
    defer SlabAllocator.deinit();
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
    defer SlabAllocator.deinit();
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
    defer SlabAllocator.deinit();
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
    defer SlabAllocator.deinit();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();

    queue.close();
    const inst = try SlabAllocator.get().alloc(&vtable);
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
    defer SlabAllocator.deinit();
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
    const inst = SlabAllocator.get().alloc(&vtable) catch return;
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
    defer SlabAllocator.deinit();
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
    defer SlabAllocator.deinit();
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
