//! HTML 7.4.1.3 "Centralized modifications of session history": a traversable
//! navigable's session history traversal queue.
//!
//! "All modifications to a traversable navigable's session history entries
//! need to be synchronized ... we use the session history traversal parallel
//! queue structure." Its algorithm set holds algorithm steps and
//! "synchronous navigation steps" (steps that target a navigable), run one
//! after another; synchronous navigation steps may "jump the queue" while
//! "apply the history step" waits (its step 14.1, `takeSyncNavigation`).
//!
//! The spec runs the queue in parallel. Crane runs it on the traversable's
//! agent thread instead, one item per task:
//!
//! - `append` never runs an item inside its caller. When the queue is idle it
//!   asks its `schedule` callback to queue ONE service task on the
//!   traversable's event loop; that task runs the first item.
//! - An item finishes inline (`.done`) or returns `.pending` and the queue
//!   waits: whatever it waits on - a fetch populating an entry, the
//!   per-navigable tasks of "apply the history step", an intercepted
//!   traverse's resumption - calls `completeById` when the wait ends, by
//!   every way it can end (finished, failed, aborted, superseded, its
//!   navigable or document gone). Completion schedules the next service
//!   task, so other tasks interleave with the queue's items, as they do with
//!   a parallel queue, and nothing is polled.
//! - The service task and every waiter carry the traversable's ID - and a
//!   waiter its item's token - never a pointer to the queue or its context:
//!   both are looked up again (`Navigables.byId`), so a traversable freed
//!   meanwhile is simply not found.
//! - A traversable that ends drops its items (`deinit`), each destroyed once:
//!   the running one after its `run` returns, if it is on the stack.
//!
//! No engine has this queue: Blink lets the latest renderer-initiated history
//! navigation win (NavigationControllerImpl::GoToIndex discards the pending
//! entry), WebKit's NavigationScheduler keeps one scheduled history
//! navigation per page (accumulating deltas), and Gecko runs each
//! ChildSHistory::AsyncGo as its own runnable with a per-task epoch. WebKit
//! landed a spec SessionHistoryTraversalQueue in its UI process on
//! 2026-10-21 (bug 326453). The spec's queue came with whatwg/html#6315
//! (2022-10-31; WPT #36364 rewrote overlapping-navigations-and-traversals to
//! it); the integrator's golden-rule-2 ruling of 2026-10-27 (lane nav2,
//! condition 1) reads the engines as lagging.
//!
//! The owner: the top-level BrowsingContext - the traversable - keeps it
//! next to its joint session history (docs/instances.md: the Tab owns
//! session history). Read and written on its Browser's window agent thread
//! only.
//!
//! Spec: https://html.spec.whatwg.org/multipage/document-sequences.html#tn-session-history-traversal-queue

const std = @import("std");
const Allocator = std.mem.Allocator;
const browsing_context = @import("../window/browsing_context.zig");
const Navigables = browsing_context.Navigables;

/// How an item's run ended.
pub const Outcome = enum {
    /// The item is finished: the queue moves on to its next item.
    done,
    /// The item waits: the queue runs nothing else until `completeById`
    /// names it (synchronous navigation steps may still jump in, through
    /// `takeSyncNavigation`, from the waiting item's own steps).
    pending,
};

/// One entry of the algorithm set. The appender allocates it - usually as a
/// field of its own state, reached with @fieldParentPtr - and the queue owns
/// it from `append` until `destroy`, which runs exactly once.
pub const Item = struct {
    /// Non-null: "synchronous navigation steps" whose target navigable has
    /// this ID. Null: algorithm steps.
    target: ?u64 = null,
    /// The steps. `item` stays valid for the whole call, even if the
    /// traversable ends inside it.
    run: *const fn (item: *Item) Outcome,
    /// Frees what the item carries, and the item. Called once: after a
    /// `.done` run, at `completeById`, or when the queue is dropped.
    destroy: *const fn (item: *Item) void,
    /// Set by `append`: what a waiter passes to `completeById`.
    token: u64 = 0,
    /// The traversable ended while this item's run was on the stack: the
    /// service destroys it once the run returns.
    orphaned: bool = false,
    in_run: bool = false,
    /// `completeById` named it while its run was on the stack: finished
    /// whatever the run returns.
    completed: bool = false,
    /// The navigables whose population this item waits for (`waitFor`): a
    /// cross-document traversal's fetch and commit. The item completes when
    /// the last one ends - its population finished, failed, was aborted or
    /// superseded (`populationEnded`), or the navigable was destroyed
    /// (`navigableGone`). Owned by the queue.
    waiting_on: std.ArrayListUnmanaged(u64) = .empty,
};

/// Queue one service task - `TraversalQueue.service(navigables, id)` - on the
/// traversable's event loop, never inline. False when no task could be
/// queued (no loop to queue on, out of memory): the item stays queued, and
/// the next `append` or completion asks again.
pub const Schedule = *const fn (navigables: *Navigables, traversable_id: u64) bool;

pub const TraversalQueue = struct {
    allocator: Allocator,
    /// The Browser's browsing contexts, where the service task and waiters
    /// look the traversable up. BORROWED: it outlives every context on it.
    navigables: *Navigables,
    traversable_id: u64,
    schedule: Schedule,
    /// The algorithm set, in order. Owned items.
    items: std.ArrayListUnmanaged(*Item) = .empty,
    /// The item whose run started and has not completed.
    running: ?*Item = null,
    /// "Running nested apply history step": synchronous navigation steps are
    /// running from inside a waiting traversal (apply step 14.1).
    running_nested_apply: bool = false,
    /// A service task is queued and has not run yet.
    service_queued: bool = false,
    next_token: u64 = 1,

    pub fn init(allocator: Allocator, navigables: *Navigables, traversable_id: u64, schedule: Schedule) TraversalQueue {
        return .{ .allocator = allocator, .navigables = navigables, .traversable_id = traversable_id, .schedule = schedule };
    }

    /// The traversable ends: every item is destroyed - a waiting one now
    /// (its waiter's `completeById` will find no queue), the one whose run
    /// is on the stack once that run returns.
    pub fn deinit(self: *TraversalQueue) void {
        if (self.running) |item| {
            self.running = null;
            if (item.in_run) {
                // Destroyed by the service once its run returns.
                item.waiting_on.deinit(self.allocator);
                item.waiting_on = .empty;
                item.orphaned = true;
            } else self.release(item);
        }
        const items = self.items;
        self.items = .empty;
        for (items.items) |item| self.release(item);
        var list = items;
        list.deinit(self.allocator);
    }

    /// Destroy `item`, and what the queue keeps for it.
    fn release(self: *TraversalQueue, item: *Item) void {
        item.waiting_on.deinit(self.allocator);
        item.waiting_on = .empty;
        item.destroy(item);
    }

    /// HTML "append session history traversal steps" (`item.target` null) or
    /// "append session history synchronous navigation steps" (non-null).
    /// Takes `item`; out of memory, it is destroyed unrun and false is
    /// returned, as a task that could not be queued.
    pub fn append(self: *TraversalQueue, item: *Item) bool {
        item.token = self.next_token;
        self.next_token += 1;
        item.orphaned = false;
        item.in_run = false;
        item.completed = false;
        item.waiting_on = .empty;
        self.items.append(self.allocator, item) catch {
            item.destroy(item);
            return false;
        };
        self.wake();
        return true;
    }

    /// Ask for a service task if one is wanted and none is queued.
    fn wake(self: *TraversalQueue) void {
        if (self.running != null or self.service_queued or self.items.items.len == 0) return;
        if (self.schedule(self.navigables, self.traversable_id)) self.service_queued = true;
    }

    /// The service task: run the first item of `traversable_id`'s queue, if
    /// the traversable is still there and no item is waiting.
    pub fn service(navigables: *Navigables, traversable_id: u64) void {
        const self = queueOf(navigables, traversable_id) orelse return;
        self.service_queued = false;
        if (self.running != null) return;
        if (self.items.items.len == 0) return;
        const item = self.items.orderedRemove(0);
        self.running = item;
        item.in_run = true;
        const outcome = item.run(item);
        item.in_run = false;
        // The run may have ended the traversable (script ran): look it up again.
        if (item.orphaned) {
            item.destroy(item);
            return;
        }
        if (outcome == .done or item.completed) {
            item.completed = false;
            completeById(navigables, traversable_id, item.token);
        }
    }

    /// The running item `token` of `traversable_id`'s queue waits for
    /// `navigable`'s population: it stays running until that ends
    /// (`populationEnded` or `navigableGone`). Looked up by IDs - the item's
    /// run may have ended the traversable. False when the traversable or the
    /// item is gone, or it could not be recorded (out of memory): the item
    /// does not wait for it.
    pub fn waitFor(navigables: *Navigables, traversable_id: u64, token: u64, navigable: u64) bool {
        const self = queueOf(navigables, traversable_id) orelse return false;
        const item = self.running orelse return false;
        if (item.token != token) return false;
        if (std.mem.indexOfScalar(u64, item.waiting_on.items, navigable) != null) return true;
        item.waiting_on.append(self.allocator, navigable) catch return false;
        return true;
    }

    /// The population of `navigable` that the item `token` of
    /// `traversable_id`'s queue waits for has ended - committed, failed,
    /// aborted or superseded: when it was the last, the item completes.
    /// Nothing happens when the traversable or the item is gone.
    pub fn populationEnded(navigables: *Navigables, traversable_id: u64, token: u64, navigable: u64) void {
        const self = queueOf(navigables, traversable_id) orelse return;
        const item = self.running orelse return;
        if (item.token != token) return;
        self.stopWaiting(item, navigable);
    }

    /// `navigable` was destroyed: the running item of `traversable_id`'s
    /// queue no longer waits for its population.
    pub fn navigableGone(navigables: *Navigables, traversable_id: u64, navigable: u64) void {
        const self = queueOf(navigables, traversable_id) orelse return;
        const item = self.running orelse return;
        self.stopWaiting(item, navigable);
    }

    fn stopWaiting(self: *TraversalQueue, item: *Item, navigable: u64) void {
        const index = std.mem.indexOfScalar(u64, item.waiting_on.items, navigable) orelse return;
        _ = item.waiting_on.swapRemove(index);
        if (item.waiting_on.items.len == 0) completeById(self.navigables, self.traversable_id, item.token);
    }

    /// The waiting item `token` of `traversable_id`'s queue is finished: it
    /// is destroyed and the queue moves on. Nothing happens when the
    /// traversable or the item is gone, or `token` is not the running item's.
    pub fn completeById(navigables: *Navigables, traversable_id: u64, token: u64) void {
        const self = queueOf(navigables, traversable_id) orelse return;
        const item = self.running orelse return;
        if (item.token != token) return;
        if (item.in_run) {
            // Completed from inside its own run: the service finishes it
            // once the run returns.
            item.completed = true;
            return;
        }
        self.running = null;
        self.release(item);
        self.wake();
    }

    /// Whether `token` is the item the queue is waiting on.
    pub fn isRunning(navigables: *Navigables, traversable_id: u64, token: u64) bool {
        const self = queueOf(navigables, traversable_id) orelse return false;
        const item = self.running orelse return false;
        return item.token == token;
    }

    /// "Apply the history step" step 14.1.1-2: remove and return the first
    /// synchronous navigation steps whose target navigable is not in
    /// `excluded`, or null. The caller runs it with `running_nested_apply`
    /// set, then destroys it.
    pub fn takeSyncNavigation(self: *TraversalQueue, excluded: []const u64) ?*Item {
        for (self.items.items, 0..) |item, i| {
            const target = item.target orelse continue;
            if (std.mem.indexOfScalar(u64, excluded, target) != null) continue;
            return self.items.orderedRemove(i);
        }
        return null;
    }

    fn queueOf(navigables: *Navigables, traversable_id: u64) ?*TraversalQueue {
        const traversable = navigables.byId(traversable_id) orelse return null;
        return traversable.traversal_queue;
    }
};
