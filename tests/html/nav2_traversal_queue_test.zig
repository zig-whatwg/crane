//! A traversable's session history traversal queue
//! (src/html/navigation/traversal_queue.zig; HTML 7.4.1.3): appended steps
//! never run inside their caller, run one per task in order, a waiting item
//! holds the queue until its waiter completes it by ID and token, synchronous
//! navigation steps can be taken out ahead ("apply the history step" 14.1),
//! and a traversable that ends destroys every item exactly once - a waiter
//! that completes afterwards finds nothing, and an item whose run ended the
//! traversable is destroyed once the run returns. std.testing.allocator
//! checks the "exactly once": a missed destroy leaks, a second one is a
//! double free.
//!
//! The event loop is the harness: `schedule` records the service tasks the
//! queue asks for, and `runTasks` runs them in order, one per turn.

const std = @import("std");
const testing = std.testing;
const html_core = @import("html_core");
const BrowsingContext = html_core.window.BrowsingContext;
const Navigables = html_core.window.Navigables;
const traversal_queue = html_core.navigation.traversal_queue;
const TraversalQueue = traversal_queue.TraversalQueue;
const Item = traversal_queue.Item;
const Outcome = traversal_queue.Outcome;

const Harness = struct {
    navigables: Navigables,
    /// Service tasks queued and not yet run: the traversable IDs.
    scheduled: std.ArrayListUnmanaged(u64) = .empty,
    /// No loop to queue on: `schedule` refuses.
    refuse: bool = false,
    /// What ran, in order.
    log: std.ArrayListUnmanaged(u8) = .empty,
    destroyed: usize = 0,

    fn init() Harness {
        return .{ .navigables = Navigables.init(testing.allocator) };
    }

    fn deinit(self: *Harness) void {
        self.scheduled.deinit(testing.allocator);
        self.log.deinit(testing.allocator);
        self.navigables.deinit();
    }

    fn schedule(navigables: *Navigables, traversable_id: u64) bool {
        const self: *Harness = @fieldParentPtr("navigables", navigables);
        if (self.refuse) return false;
        self.scheduled.append(testing.allocator, traversable_id) catch return false;
        return true;
    }

    /// Run the queued service tasks, one per turn, until none is left.
    fn runTasks(self: *Harness) usize {
        var turns: usize = 0;
        while (self.scheduled.items.len > 0) : (turns += 1) {
            const id = self.scheduled.orderedRemove(0);
            TraversalQueue.service(&self.navigables, id);
        }
        return turns;
    }
};

const Step = struct {
    item: Item,
    harness: *Harness,
    name: u8,
    outcome: Outcome = .done,
    /// Run-time behaviour beyond logging.
    action: enum { none, complete_self, end_traversable } = .none,
    traversable: ?*BrowsingContext = null,

    fn make(harness: *Harness, name: u8, outcome: Outcome, target: ?u64) !*Step {
        const step = try testing.allocator.create(Step);
        step.* = .{
            .item = .{ .target = target, .run = run, .destroy = destroy },
            .harness = harness,
            .name = name,
            .outcome = outcome,
        };
        return step;
    }

    fn run(item: *Item) Outcome {
        const self: *Step = @fieldParentPtr("item", item);
        self.harness.log.append(testing.allocator, self.name) catch {};
        switch (self.action) {
            .none => {},
            .complete_self => {
                const top = self.traversable.?;
                TraversalQueue.completeById(&self.harness.navigables, top.id, item.token);
            },
            .end_traversable => self.traversable.?.deinit(),
        }
        return self.outcome;
    }

    fn destroy(item: *Item) void {
        const self: *Step = @fieldParentPtr("item", item);
        self.harness.destroyed += 1;
        testing.allocator.destroy(self);
    }
};

test "appended steps never run in their caller, and run one per task in order" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    defer top.deinit();
    const queue = try top.traversalQueue(Harness.schedule);

    for ("ABC") |name| try testing.expect(queue.append(&(try Step.make(&harness, name, .done, null)).item));
    // Nothing ran in the caller; one service task was asked for.
    try testing.expectEqual(@as(usize, 0), harness.log.items.len);
    try testing.expectEqual(@as(usize, 1), harness.scheduled.items.len);

    try testing.expectEqual(@as(usize, 3), harness.runTasks());
    try testing.expectEqualStrings("ABC", harness.log.items);
    try testing.expectEqual(@as(usize, 3), harness.destroyed);
}

test "a waiting item holds the queue until its waiter completes it by token" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    defer top.deinit();
    const queue = try top.traversalQueue(Harness.schedule);

    const waiting = try Step.make(&harness, 'A', .pending, null);
    try testing.expect(queue.append(&waiting.item));
    const token = waiting.item.token;
    try testing.expect(queue.append(&(try Step.make(&harness, 'B', .done, null)).item));

    _ = harness.runTasks();
    try testing.expectEqualStrings("A", harness.log.items);
    try testing.expect(TraversalQueue.isRunning(&harness.navigables, top.id, token));
    // Another token, or another traversable, completes nothing.
    TraversalQueue.completeById(&harness.navigables, top.id, token + 100);
    TraversalQueue.completeById(&harness.navigables, top.id + 1000, token);
    try testing.expectEqual(@as(usize, 0), harness.runTasks());
    try testing.expectEqual(@as(usize, 0), harness.destroyed);

    TraversalQueue.completeById(&harness.navigables, top.id, token);
    try testing.expectEqual(@as(usize, 1), harness.destroyed);
    _ = harness.runTasks();
    try testing.expectEqualStrings("AB", harness.log.items);
    try testing.expectEqual(@as(usize, 2), harness.destroyed);
    // Completing again is harmless.
    TraversalQueue.completeById(&harness.navigables, top.id, token);
    try testing.expectEqual(@as(usize, 2), harness.destroyed);
}

test "an item completed from inside its own run is finished when the run returns" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    defer top.deinit();
    const queue = try top.traversalQueue(Harness.schedule);

    const quick = try Step.make(&harness, 'A', .pending, null);
    quick.action = .complete_self;
    quick.traversable = top;
    try testing.expect(queue.append(&quick.item));
    try testing.expect(queue.append(&(try Step.make(&harness, 'B', .done, null)).item));
    _ = harness.runTasks();
    try testing.expectEqualStrings("AB", harness.log.items);
    try testing.expectEqual(@as(usize, 2), harness.destroyed);
}

test "synchronous navigation steps are taken out ahead of a waiting traversal, skipping excluded navigables" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    defer top.deinit();
    const queue = try top.traversalQueue(Harness.schedule);

    try testing.expect(queue.append(&(try Step.make(&harness, 'T', .pending, null)).item));
    _ = harness.runTasks();
    try testing.expect(queue.append(&(try Step.make(&harness, 'S', .done, null)).item));
    try testing.expect(queue.append(&(try Step.make(&harness, 'x', .done, 5)).item));
    try testing.expect(queue.append(&(try Step.make(&harness, 'y', .done, 7)).item));

    const first = queue.takeSyncNavigation(&.{5}) orelse return error.NoSyncNavigation;
    try testing.expectEqual(@as(?u64, 7), first.target);
    first.destroy(first);
    const second = queue.takeSyncNavigation(&.{}) orelse return error.NoSyncNavigation;
    try testing.expectEqual(@as(?u64, 5), second.target);
    second.destroy(second);
    try testing.expect(queue.takeSyncNavigation(&.{}) == null);
    // The plain steps stay queued behind the waiting traversal; the
    // traversable's end destroys both.
    try testing.expectEqual(@as(usize, 1), queue.items.items.len);
}

test "a traversable's end destroys every item once, and a later completion finds nothing" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    const id = top.id;
    const queue = try top.traversalQueue(Harness.schedule);

    const waiting = try Step.make(&harness, 'A', .pending, null);
    try testing.expect(queue.append(&waiting.item));
    const token = waiting.item.token;
    try testing.expect(queue.append(&(try Step.make(&harness, 'B', .done, null)).item));
    _ = harness.runTasks();

    top.deinit();
    try testing.expectEqual(@as(usize, 2), harness.destroyed);
    // The waiter completes after its traversable is gone, and a service task
    // queued before the end runs after it.
    TraversalQueue.completeById(&harness.navigables, id, token);
    TraversalQueue.service(&harness.navigables, id);
    try testing.expectEqual(@as(usize, 2), harness.destroyed);
    try testing.expectEqualStrings("A", harness.log.items);
}

test "an item whose run ends its traversable is destroyed once the run returns" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    const queue = try top.traversalQueue(Harness.schedule);

    const ending = try Step.make(&harness, 'A', .done, null);
    ending.action = .end_traversable;
    ending.traversable = top;
    try testing.expect(queue.append(&ending.item));
    try testing.expect(queue.append(&(try Step.make(&harness, 'B', .done, null)).item));
    _ = harness.runTasks();
    try testing.expectEqualStrings("A", harness.log.items);
    try testing.expectEqual(@as(usize, 2), harness.destroyed);
}

test "a service task that could not be queued is asked for again by the next append" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    defer top.deinit();
    const queue = try top.traversalQueue(Harness.schedule);

    harness.refuse = true;
    try testing.expect(queue.append(&(try Step.make(&harness, 'A', .done, null)).item));
    try testing.expectEqual(@as(usize, 0), harness.scheduled.items.len);
    harness.refuse = false;
    try testing.expect(queue.append(&(try Step.make(&harness, 'B', .done, null)).item));
    _ = harness.runTasks();
    try testing.expectEqualStrings("AB", harness.log.items);
    try testing.expectEqual(@as(usize, 2), harness.destroyed);
}

test "only the traversable keeps a queue: a child context reaches its top's" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    defer top.deinit();
    const child = try BrowsingContext.initChild(testing.allocator, top);
    defer child.deinit();
    const from_child = try child.traversalQueue(Harness.schedule);
    const from_top = try top.traversalQueue(Harness.schedule);
    try testing.expect(from_child == from_top);
    try testing.expect(child.traversal_queue == null);
    try testing.expectEqual(top.id, from_top.traversable_id);
}
