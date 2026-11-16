//! TraversalQueue.catchUp (src/html/navigation/traversal_queue.zig; lane
//! nr1): a task that is about to read state the session history traversal
//! queue writes - a navigation's response task, which asks whether it is
//! still its navigable's ongoing navigation - first runs the queue's service
//! tasks that are already asked for. HTML runs the queue in parallel, so the
//! steps appended before that task ran have run by then; Crane runs them
//! from service tasks on the same loop, which the response's task can be
//! queued ahead of.
//!
//! What these tests pin: the items run in order, up to the first that waits;
//! nothing runs when no service task is asked for (the queue waits, or is
//! empty); an item appended by a caught-up item waits for a task of its own;
//! the service task that was already queued finds nothing left to do; a
//! traversable that ends inside a caught-up item is not touched again; a
//! catch-up asked for from inside one of the queue's own steps does nothing
//! (no re-entrancy).
//! std.testing.allocator checks that every item is destroyed exactly once.
//!
//! The event loop is the harness, as in nav2_traversal_queue_test.zig:
//! `schedule` records the service tasks the queue asks for.

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
    action: enum { none, append_next, end_traversable, catch_up_inside } = .none,
    traversable: ?*BrowsingContext = null,
    /// `.append_next`: the step this one's run appends to the queue.
    next: ?*Step = null,

    fn make(harness: *Harness, name: u8, outcome: Outcome) !*Step {
        const step = try testing.allocator.create(Step);
        step.* = .{
            .item = .{ .run = run, .destroy = destroy },
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
            .append_next => {
                const queue = self.traversable.?.traversal_queue.?;
                if (self.next) |next| _ = queue.append(&next.item);
                self.next = null;
            },
            .end_traversable => self.traversable.?.deinit(),
            .catch_up_inside => {
                const top = self.traversable.?;
                // The next item's append asks for a service task, so a
                // catch-up that re-entered the queue would find one to run.
                if (self.next) |next| _ = top.traversal_queue.?.append(&next.item);
                self.next = null;
                top.traversal_queue.?.service_queued = true;
                TraversalQueue.catchUp(&self.harness.navigables, top.id);
                top.traversal_queue.?.service_queued = false;
            },
        }
        return self.outcome;
    }

    fn destroy(item: *Item) void {
        const self: *Step = @fieldParentPtr("item", item);
        self.harness.destroyed += 1;
        // A step it never appended goes with it.
        if (self.next) |next| testing.allocator.destroy(next);
        testing.allocator.destroy(self);
    }
};

test "catchUp runs the queued items in order, up to the first that waits, and the service task already queued finds nothing" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    defer top.deinit();
    const queue = try top.traversalQueue(Harness.schedule);

    try testing.expect(queue.append(&(try Step.make(&harness, 'A', .done)).item));
    try testing.expect(queue.append(&(try Step.make(&harness, 'B', .done)).item));
    const waiting = try Step.make(&harness, 'C', .pending);
    try testing.expect(queue.append(&waiting.item));
    const token = waiting.item.token;
    try testing.expect(queue.append(&(try Step.make(&harness, 'D', .done)).item));
    // Appending ran nothing: one service task is asked for.
    try testing.expectEqualStrings("", harness.log.items);
    try testing.expectEqual(@as(usize, 1), harness.scheduled.items.len);

    TraversalQueue.catchUp(&harness.navigables, top.id);
    // A and B finished; C runs and waits; D stays queued behind it.
    try testing.expectEqualStrings("ABC", harness.log.items);
    try testing.expectEqual(@as(usize, 2), harness.destroyed);
    try testing.expect(TraversalQueue.isRunning(&harness.navigables, top.id, token));
    try testing.expectEqual(@as(usize, 1), queue.items.items.len);

    // The service tasks asked for meanwhile run, and do nothing: C waits.
    _ = harness.runTasks();
    try testing.expectEqualStrings("ABC", harness.log.items);
    try testing.expect(TraversalQueue.isRunning(&harness.navigables, top.id, token));

    TraversalQueue.completeById(&harness.navigables, top.id, token);
    _ = harness.runTasks();
    try testing.expectEqualStrings("ABCD", harness.log.items);
    try testing.expectEqual(@as(usize, 4), harness.destroyed);
}

test "catchUp runs nothing when no service task is asked for: the queue waits, or is empty" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    defer top.deinit();
    const queue = try top.traversalQueue(Harness.schedule);

    // Empty.
    TraversalQueue.catchUp(&harness.navigables, top.id);
    try testing.expectEqualStrings("", harness.log.items);
    // No such traversable.
    TraversalQueue.catchUp(&harness.navigables, top.id + 1000);

    const waiting = try Step.make(&harness, 'T', .pending);
    try testing.expect(queue.append(&waiting.item));
    const token = waiting.item.token;
    _ = harness.runTasks();
    try testing.expect(queue.append(&(try Step.make(&harness, 'B', .done)).item));
    // T waits and lets nothing jump it: B's append asked for no task.
    try testing.expectEqual(@as(usize, 0), harness.scheduled.items.len);

    TraversalQueue.catchUp(&harness.navigables, top.id);
    try testing.expectEqualStrings("T", harness.log.items);
    try testing.expect(TraversalQueue.isRunning(&harness.navigables, top.id, token));
    try testing.expectEqual(@as(usize, 1), queue.items.items.len);

    TraversalQueue.completeById(&harness.navigables, top.id, token);
    _ = harness.runTasks();
    try testing.expectEqualStrings("TB", harness.log.items);
    try testing.expectEqual(@as(usize, 2), harness.destroyed);
}

test "catchUp runs only what was queued when it began: an item a caught-up item appends waits for a task of its own" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    defer top.deinit();
    const queue = try top.traversalQueue(Harness.schedule);

    const first = try Step.make(&harness, 'A', .done);
    first.action = .append_next;
    first.traversable = top;
    first.next = try Step.make(&harness, 'X', .done);
    try testing.expect(queue.append(&first.item));
    try testing.expect(queue.append(&(try Step.make(&harness, 'B', .done)).item));

    TraversalQueue.catchUp(&harness.navigables, top.id);
    // A and B were queued; X came from A's run.
    try testing.expectEqualStrings("AB", harness.log.items);
    try testing.expectEqual(@as(usize, 1), queue.items.items.len);

    _ = harness.runTasks();
    try testing.expectEqualStrings("ABX", harness.log.items);
    try testing.expectEqual(@as(usize, 3), harness.destroyed);
}

test "catchUp stops when a caught-up item ends its traversable" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    const queue = try top.traversalQueue(Harness.schedule);

    const ending = try Step.make(&harness, 'A', .done);
    ending.action = .end_traversable;
    ending.traversable = top;
    const id = top.id;
    try testing.expect(queue.append(&ending.item));
    try testing.expect(queue.append(&(try Step.make(&harness, 'B', .done)).item));

    TraversalQueue.catchUp(&harness.navigables, id);
    // B was destroyed unrun with the traversable; A once its run returned.
    try testing.expectEqualStrings("A", harness.log.items);
    try testing.expectEqual(@as(usize, 2), harness.destroyed);
    // The service task queued before finds no traversable.
    _ = harness.runTasks();
    try testing.expectEqualStrings("A", harness.log.items);
}

test "catchUp from inside one of the queue's own steps does nothing: the queue never re-enters itself" {
    var harness = Harness.init();
    defer harness.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &harness.navigables);
    defer top.deinit();
    const queue = try top.traversalQueue(Harness.schedule);

    // A's run appends X, and asks for a catch-up while a service task is
    // marked as asked for: B and X are queued, A is on the stack.
    const inside = try Step.make(&harness, 'A', .done);
    inside.action = .catch_up_inside;
    inside.traversable = top;
    inside.next = try Step.make(&harness, 'X', .done);
    try testing.expect(queue.append(&inside.item));
    try testing.expect(queue.append(&(try Step.make(&harness, 'B', .done)).item));

    // One service task: A alone. Nothing ran nested inside its run.
    TraversalQueue.service(&harness.navigables, harness.scheduled.orderedRemove(0));
    try testing.expectEqualStrings("A", harness.log.items);
    try testing.expectEqual(@as(usize, 1), harness.destroyed);
    try testing.expectEqual(@as(usize, 2), queue.items.items.len);

    _ = harness.runTasks();
    try testing.expectEqualStrings("ABX", harness.log.items);
    try testing.expectEqual(@as(usize, 3), harness.destroyed);
}
