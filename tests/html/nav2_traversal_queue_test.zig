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
    action: enum { none, complete_self, end_traversable, wait_for, wait_and_end_one } = .none,
    traversable: ?*BrowsingContext = null,
    /// `.wait_for`: the navigables whose populations the run waits for.
    /// `.wait_and_end_one`: the same, and the first one's population ends
    /// inside the run.
    waits: []const u64 = &.{},

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
            .wait_for, .wait_and_end_one => {
                const top = self.traversable.?;
                for (self.waits) |navigable| {
                    if (!TraversalQueue.waitFor(&self.harness.navigables, top.id, item.token, navigable)) return .done;
                }
                if (self.action == .wait_and_end_one) {
                    TraversalQueue.populationEnded(&self.harness.navigables, top.id, item.token, self.waits[0]);
                }
            },
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

test "a traversal waiting on populations completes when the last one ends, by its own token only" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    defer top.deinit();
    const queue = try top.traversalQueue(Harness.schedule);

    const waiting = try Step.make(&harness, 'A', .pending, null);
    waiting.action = .wait_for;
    waiting.traversable = top;
    waiting.waits = &.{ 7, 8 };
    try testing.expect(queue.append(&waiting.item));
    const token = waiting.item.token;
    try testing.expect(queue.append(&(try Step.make(&harness, 'B', .done, null)).item));
    _ = harness.runTasks();
    try testing.expectEqualStrings("A", harness.log.items);

    // Another token's end, or another traversable's, changes nothing.
    TraversalQueue.populationEnded(&harness.navigables, top.id, token + 1, 7);
    TraversalQueue.populationEnded(&harness.navigables, top.id + 1000, token, 7);
    // A navigable it does not wait for, nothing either.
    TraversalQueue.populationEnded(&harness.navigables, top.id, token, 9);
    try testing.expectEqual(@as(usize, 0), harness.runTasks());
    try testing.expect(TraversalQueue.isRunning(&harness.navigables, top.id, token));

    // One of two: still waiting.
    TraversalQueue.populationEnded(&harness.navigables, top.id, token, 7);
    try testing.expect(TraversalQueue.isRunning(&harness.navigables, top.id, token));
    // The last: the queue moves on.
    TraversalQueue.populationEnded(&harness.navigables, top.id, token, 8);
    try testing.expect(!TraversalQueue.isRunning(&harness.navigables, top.id, token));
    _ = harness.runTasks();
    try testing.expectEqualStrings("AB", harness.log.items);
    try testing.expectEqual(@as(usize, 2), harness.destroyed);
}

test "a destroyed navigable ends the running traversal's wait for it, and the queue continues" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    defer top.deinit();
    const queue = try top.traversalQueue(Harness.schedule);

    const waiting = try Step.make(&harness, 'A', .pending, null);
    waiting.action = .wait_for;
    waiting.traversable = top;
    waiting.waits = &.{7};
    try testing.expect(queue.append(&waiting.item));
    try testing.expect(queue.append(&(try Step.make(&harness, 'B', .done, null)).item));
    _ = harness.runTasks();
    try testing.expectEqualStrings("A", harness.log.items);
    TraversalQueue.navigableGone(&harness.navigables, top.id, 7);
    _ = harness.runTasks();
    try testing.expectEqualStrings("AB", harness.log.items);
    try testing.expectEqual(@as(usize, 2), harness.destroyed);
}

test "a population that ends inside its traversal's run leaves the traversal waiting for the others" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    defer top.deinit();
    const queue = try top.traversalQueue(Harness.schedule);

    // Its only population ends in the run: finished when the run returns.
    const quick = try Step.make(&harness, 'A', .pending, null);
    quick.action = .wait_and_end_one;
    quick.traversable = top;
    quick.waits = &.{7};
    try testing.expect(queue.append(&quick.item));
    // One of two ends in the run: still waiting on the other.
    const slow = try Step.make(&harness, 'B', .pending, null);
    slow.action = .wait_and_end_one;
    slow.traversable = top;
    slow.waits = &.{ 7, 8 };
    try testing.expect(queue.append(&slow.item));
    try testing.expect(queue.append(&(try Step.make(&harness, 'C', .done, null)).item));
    _ = harness.runTasks();
    try testing.expectEqualStrings("AB", harness.log.items);
    try testing.expectEqual(@as(usize, 1), harness.destroyed);
    TraversalQueue.populationEnded(&harness.navigables, top.id, slow.item.token, 8);
    _ = harness.runTasks();
    try testing.expectEqualStrings("ABC", harness.log.items);
    try testing.expectEqual(@as(usize, 3), harness.destroyed);
}

test "a traversable that ends while its traversal waits frees the wait, and a later end finds nothing" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    const top_id = top.id;
    const queue = try top.traversalQueue(Harness.schedule);
    const waiting = try Step.make(&harness, 'A', .pending, null);
    waiting.action = .wait_for;
    waiting.traversable = top;
    waiting.waits = &.{ 7, 8 };
    try testing.expect(queue.append(&waiting.item));
    const token = waiting.item.token;
    _ = harness.runTasks();
    top.deinit();
    try testing.expectEqual(@as(usize, 1), harness.destroyed);
    TraversalQueue.populationEnded(&harness.navigables, top_id, token, 7);
    TraversalQueue.navigableGone(&harness.navigables, top_id, 8);
    try testing.expectEqual(@as(usize, 1), harness.destroyed);
}

/// The contexts `serviceContext` may pick (a test's stand-in for "has an
/// active window with an event loop").
const WithLoop = struct {
    contexts: []const *BrowsingContext,

    fn has(self: WithLoop, bc: *BrowsingContext) bool {
        return std.mem.indexOfScalar(*BrowsingContext, self.contexts, bc) != null;
    }
};

test "the service task goes to the traversable's loop, else one in its own tree, else another traversable's on the Browser, else none" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    defer top.deinit();
    const child = try BrowsingContext.initChild(testing.allocator, top);
    defer child.deinit();
    const grandchild = try BrowsingContext.initChild(testing.allocator, child);
    defer grandchild.deinit();
    const other_tab = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    defer other_tab.deinit();
    const pick = struct {
        fn of(navigables: *Navigables, traversable: *BrowsingContext, contexts: []const *BrowsingContext) ?*BrowsingContext {
            return TraversalQueue.serviceContext(navigables, traversable, WithLoop{ .contexts = contexts }, WithLoop.has);
        }
    }.of;

    // The traversable's own window first.
    try testing.expectEqual(top, pick(&harness.navigables, top, &.{ child, other_tab, top }).?);
    // With none of its own (a realm mid-swap), a window in its tree, parents
    // first - before another Tab's, which also has one.
    try testing.expectEqual(child, pick(&harness.navigables, top, &.{ grandchild, other_tab, child }).?);
    try testing.expectEqual(grandchild, pick(&harness.navigables, top, &.{ other_tab, grandchild }).?);
    // Only when its whole tree has none, another traversable's on the list.
    try testing.expectEqual(other_tab, pick(&harness.navigables, top, &.{other_tab}).?);
    // None at all: no task, and nothing runs inline.
    try testing.expect(pick(&harness.navigables, top, &.{}) == null);
}

// Lane nav2 C2: an item whose steps go on after their waits end - "apply
// the history step" waits for every change job (step 14), then queues the
// non-changing navigables' tasks and waits for them (steps 18-19), then sets
// the step (20). Its `proceed` steps run from a service task of their own
// once the last wait ends - never inside the call that ended it.

/// An item with three phases: wait for `first`, then for `second`, then
/// done. Logs 'r' for its run and 'p' for each proceed.
const Phased = struct {
    item: Item,
    harness: *Harness,
    top: *BrowsingContext,
    first: []const u64,
    second: []const u64,
    phase: u8 = 0,
    /// End this navigable's wait inside the run that records it.
    end_inside: ?u64 = null,

    fn make(harness: *Harness, top: *BrowsingContext, first: []const u64, second: []const u64) !*Phased {
        const self = try testing.allocator.create(Phased);
        self.* = .{
            .item = .{ .run = run, .destroy = destroy, .proceed = proceed },
            .harness = harness,
            .top = top,
            .first = first,
            .second = second,
        };
        return self;
    }

    fn waitAll(self: *Phased, ids: []const u64) Outcome {
        for (ids) |id| _ = TraversalQueue.waitFor(&self.harness.navigables, self.top.id, self.item.token, id);
        if (self.end_inside) |id| TraversalQueue.populationEnded(&self.harness.navigables, self.top.id, self.item.token, id);
        return if (ids.len == 0) .done else .pending;
    }

    fn run(item: *Item) Outcome {
        const self: *Phased = @fieldParentPtr("item", item);
        self.harness.log.append(testing.allocator, 'r') catch {};
        self.phase = 1;
        return self.waitAll(self.first);
    }

    fn proceed(item: *Item) Outcome {
        const self: *Phased = @fieldParentPtr("item", item);
        self.harness.log.append(testing.allocator, 'p') catch {};
        self.phase += 1;
        if (self.phase == 2) return self.waitAll(self.second);
        return .done;
    }

    fn destroy(item: *Item) void {
        const self: *Phased = @fieldParentPtr("item", item);
        self.harness.destroyed += 1;
        testing.allocator.destroy(self);
    }
};

test "an item's proceed steps run from a task of their own when its waits end, until they are done" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    defer top.deinit();
    const queue = try top.traversalQueue(Harness.schedule);

    const phased = try Phased.make(&harness, top, &.{ 7, 8 }, &.{9});
    try testing.expect(queue.append(&phased.item));
    const token = phased.item.token;
    try testing.expect(queue.append(&(try Step.make(&harness, 'B', .done, null)).item));
    _ = harness.runTasks();
    try testing.expectEqualStrings("r", harness.log.items);

    TraversalQueue.populationEnded(&harness.navigables, top.id, token, 7);
    try testing.expectEqual(@as(usize, 0), harness.scheduled.items.len);
    // The last wait of the first phase: nothing runs in this call; a service
    // task is asked for, and the item's proceed steps run there.
    TraversalQueue.populationEnded(&harness.navigables, top.id, token, 8);
    try testing.expectEqualStrings("r", harness.log.items);
    try testing.expectEqual(@as(usize, 1), harness.scheduled.items.len);
    _ = harness.runTasks();
    try testing.expectEqualStrings("rp", harness.log.items);
    try testing.expect(TraversalQueue.isRunning(&harness.navigables, top.id, token));

    // The second phase's wait, a navigable gone: proceed again, then done,
    // and the queue moves on.
    TraversalQueue.navigableGone(&harness.navigables, top.id, 9);
    _ = harness.runTasks();
    try testing.expectEqualStrings("rppB", harness.log.items);
    try testing.expectEqual(@as(usize, 2), harness.destroyed);
}

test "waits that end inside the run that records them lead to the proceed steps from the next task" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    defer top.deinit();
    const queue = try top.traversalQueue(Harness.schedule);

    const phased = try Phased.make(&harness, top, &.{7}, &.{});
    phased.end_inside = 7;
    try testing.expect(queue.append(&phased.item));
    try testing.expect(queue.append(&(try Step.make(&harness, 'B', .done, null)).item));
    // run (its only wait ends inside it), proceed (done), B: three tasks.
    try testing.expectEqual(@as(usize, 3), harness.runTasks());
    try testing.expectEqualStrings("rpB", harness.log.items);
    try testing.expectEqual(@as(usize, 2), harness.destroyed);
}

test "an item waiting between its phases is destroyed once when its traversable ends" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    const top_id = top.id;
    const queue = try top.traversalQueue(Harness.schedule);
    const phased = try Phased.make(&harness, top, &.{7}, &.{8});
    try testing.expect(queue.append(&phased.item));
    const token = phased.item.token;
    _ = harness.runTasks();
    TraversalQueue.populationEnded(&harness.navigables, top_id, token, 7);
    // Its proceed task is queued; the traversable ends before it runs.
    try testing.expectEqual(@as(usize, 1), harness.scheduled.items.len);
    top.deinit();
    try testing.expectEqual(@as(usize, 1), harness.destroyed);
    _ = harness.runTasks();
    try testing.expectEqualStrings("r", harness.log.items);
    try testing.expectEqual(@as(usize, 1), harness.destroyed);
}
