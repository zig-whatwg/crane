//! Suspending workers with their back/forward cached owners (lane nav4b2;
//! HTML 10.2.3 "suspendable", "run a worker" step 8, *suspending workers*):
//!
//! - a dedicated worker whose owner Document the cache keeps is suspended
//!   with every worker it owns, and resumed when the Document is shown again
//!   (html.WorkerRegistry.suspendOwnedByRealm / resumeOwnedByRealm); a worker
//!   a suspended worker starts starts suspended;
//! - a suspended worker's loop runs nothing - no task, no timer - until it
//!   is resumed or closing (html.WorkerEventLoop), and its timers' clock
//!   stands still meanwhile (SuspendClock);
//! - a shared worker is suspended while no Document of its owner set is
//!   fully active, and resumed when one is (html.worker_host.
//!   SharedWorkerManager);
//! - a lock request that cannot be granted, or a query, tells each holder of
//!   the lock it contends with (web_locks.Delivery.contention), which is how
//!   a cached page whose worker holds the lock is evicted (Chrome's
//!   LockManager::Observer::OnLockContention).
//!
//! No engine runs here; a loop test spins a WorkerEventLoop with no agent on
//! a thread of its own and joins it before it returns. tests/html is one
//! executable: nothing here assumes it runs first.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const html = @import("html");
const WorkerLink = html.WorkerLink;
const WorkerRegistry = html.WorkerRegistry;
const WorkerEventLoop = html.WorkerEventLoop;
const SharedWorkerManager = html.worker_host.SharedWorkerManager;
const web_locks = html.web_locks;

/// Owner realms: compared, never dereferenced.
var realm_a: u8 = 0;
var realm_b: u8 = 0;
var host_data: u8 = 0;

fn sleepMs(ms: u64) void {
    std.Io.sleep(std.testing.io, .fromMilliseconds(@intCast(ms)), .awake) catch {};
}

// ============================================================================
// The registry: a realm's workers, and theirs
// ============================================================================

test "suspendOwnedByRealm suspends a realm's dedicated workers and the workers they own; resumeOwnedByRealm resumes them" {
    const window_sink = try runtime.TaskSink.create(testing.allocator);
    defer window_sink.release();
    var registry = WorkerRegistry.init(testing.allocator);
    defer registry.deinit();

    // realm_a's worker, its nested worker, and that one's nested worker.
    const outer = try WorkerLink.create(testing.allocator, window_sink);
    defer outer.release();
    outer.owner_realm = &realm_a;
    try registry.register(outer);
    const nested = try WorkerLink.create(testing.allocator, outer.worker_sink);
    defer nested.release();
    nested.owner_realm = &host_data;
    try registry.register(nested);
    const inner = try WorkerLink.create(testing.allocator, nested.worker_sink);
    defer inner.release();
    inner.owner_realm = &host_data;
    try registry.register(inner);
    // realm_b's worker: not realm_a's.
    const other = try WorkerLink.create(testing.allocator, window_sink);
    defer other.release();
    other.owner_realm = &realm_b;
    try registry.register(other);

    try testing.expectEqual(@as(usize, 3), registry.suspendOwnedByRealm(&realm_a));
    try testing.expect(outer.isSuspended());
    try testing.expect(nested.isSuspended());
    try testing.expect(inner.isSuspended());
    try testing.expect(!other.isSuspended());
    // Again: nothing more to suspend.
    try testing.expectEqual(@as(usize, 0), registry.suspendOwnedByRealm(&realm_a));

    // The top of each owner chain.
    const root = registry.ownerChainRoot(inner);
    defer root.release();
    try testing.expectEqual(outer, root);
    const self_root = registry.ownerChainRoot(other);
    defer self_root.release();
    try testing.expectEqual(other, self_root);

    try testing.expectEqual(@as(usize, 3), registry.resumeOwnedByRealm(&realm_a));
    try testing.expect(!outer.isSuspended());
    try testing.expect(!nested.isSuspended());
    try testing.expect(!inner.isSuspended());

    registry.unregister(inner);
    registry.unregister(nested);
    registry.unregister(outer);
    registry.unregister(other);
}

test "a worker started by a suspended worker starts suspended" {
    const window_sink = try runtime.TaskSink.create(testing.allocator);
    defer window_sink.release();
    var registry = WorkerRegistry.init(testing.allocator);
    defer registry.deinit();
    const outer = try WorkerLink.create(testing.allocator, window_sink);
    defer outer.release();
    outer.owner_realm = &realm_a;
    try registry.register(outer);
    _ = registry.suspendOwnedByRealm(&realm_a);

    // Its owner is not actively needed: neither is it (HTML 10.2.3).
    const late = try WorkerLink.create(testing.allocator, outer.worker_sink);
    defer late.release();
    try registry.register(late);
    try testing.expect(late.isSuspended());
    // A window's worker started meanwhile is not.
    const fresh = try WorkerLink.create(testing.allocator, window_sink);
    defer fresh.release();
    fresh.owner_realm = &realm_b;
    try registry.register(fresh);
    try testing.expect(!fresh.isSuspended());

    _ = registry.resumeOwnedByRealm(&realm_a);
    try testing.expect(!late.isSuspended());
    registry.unregister(late);
    registry.unregister(fresh);
    registry.unregister(outer);
}

// ============================================================================
// The loop: nothing runs while suspended
// ============================================================================

const Counter = struct {
    ran: std.atomic.Value(u32) = .init(0),
    dropped: std.atomic.Value(u32) = .init(0),

    fn run(data: ?*anyopaque) void {
        const self: *Counter = @ptrCast(@alignCast(data.?));
        _ = self.ran.fetchAdd(1, .acq_rel);
    }

    fn drop(data: ?*anyopaque) void {
        const self: *Counter = @ptrCast(@alignCast(data.?));
        _ = self.dropped.fetchAdd(1, .acq_rel);
    }

    fn task(self: *Counter) runtime.CrossThreadTask {
        return .{ .run = run, .drop = drop, .data = self };
    }

    /// Wait, bounded, until `n` tasks have run.
    fn waitFor(self: *Counter, n: u32) !void {
        var waited: u64 = 0;
        while (self.ran.load(.acquire) < n) : (waited += 1) {
            if (waited > 5000) return error.TimedOut;
            sleepMs(1);
        }
    }
};

const LoopThread = struct {
    loop: *WorkerEventLoop,

    fn main(self: *LoopThread) void {
        self.loop.run();
    }
};

test "a suspended worker's loop runs no task until it is resumed, and drops what waits when it is terminated" {
    const owner_sink = try runtime.TaskSink.create(testing.allocator);
    defer owner_sink.release();
    const link = try WorkerLink.create(testing.allocator, owner_sink);
    defer link.release();
    var loop = try WorkerEventLoop.init(testing.allocator, link);
    var spinner: LoopThread = .{ .loop = &loop };
    const thread = try std.Thread.spawn(.{}, LoopThread.main, .{&spinner});

    var counter: Counter = .{};
    try testing.expect(link.worker_sink.post(counter.task()));
    try counter.waitFor(1);

    // Suspended: what is posted waits.
    try testing.expect(link.suspendExecution());
    try testing.expect(!link.suspendExecution());
    try testing.expect(link.worker_sink.post(counter.task()));
    sleepMs(100);
    try testing.expectEqual(@as(u32, 1), counter.ran.load(.acquire));

    // Resumed: it runs, in order.
    try testing.expect(link.resumeFromSuspension());
    try counter.waitFor(2);

    // Suspended again, then terminated: the loop ends without running it,
    // and its end drops it.
    _ = link.suspendExecution();
    try testing.expect(link.worker_sink.post(counter.task()));
    sleepMs(20);
    _ = link.terminate();
    thread.join();
    try testing.expectEqual(@as(u32, 2), counter.ran.load(.acquire));
    loop.deinit();
    try testing.expectEqual(@as(u32, 1), counter.dropped.load(.acquire));
}

/// A timer armed on the loop's own thread, by a task.
const ArmTimer = struct {
    loop: *WorkerEventLoop,
    fired: std.atomic.Value(bool) = .init(false),
    armed: std.atomic.Value(bool) = .init(false),

    fn run(data: ?*anyopaque) void {
        const self: *ArmTimer = @ptrCast(@alignCast(data.?));
        _ = self.loop.timers.setTimeout(150, fire, self);
        self.armed.store(true, .release);
    }

    fn fire(data: ?*anyopaque) void {
        const self: *ArmTimer = @ptrCast(@alignCast(data.?));
        self.fired.store(true, .release);
    }

    fn noop(_: ?*anyopaque) void {}
};

test "a suspended worker's timers do not fire; they fire once it is resumed" {
    const owner_sink = try runtime.TaskSink.create(testing.allocator);
    defer owner_sink.release();
    const link = try WorkerLink.create(testing.allocator, owner_sink);
    defer link.release();
    var loop = try WorkerEventLoop.init(testing.allocator, link);
    var spinner: LoopThread = .{ .loop = &loop };
    const thread = try std.Thread.spawn(.{}, LoopThread.main, .{&spinner});
    defer {
        _ = link.terminate();
        thread.join();
        loop.deinit();
    }

    var arm: ArmTimer = .{ .loop = &loop };
    try testing.expect(link.worker_sink.post(.{ .run = ArmTimer.run, .drop = ArmTimer.noop, .data = &arm }));
    var waited: u64 = 0;
    while (!arm.armed.load(.acquire)) : (waited += 1) {
        if (waited > 5000) return error.TimedOut;
        sleepMs(1);
    }
    // Suspended at once, and for longer than the timer's 150 ms: it must
    // not fire. The post wakes the loop, which parks.
    _ = link.suspendExecution();
    link.wake();
    sleepMs(400);
    try testing.expect(!arm.fired.load(.acquire));
    _ = link.resumeFromSuspension();
    waited = 0;
    while (!arm.fired.load(.acquire)) : (waited += 1) {
        if (waited > 5000) return error.TimedOut;
        sleepMs(1);
    }
}

test "the timers' clock stands still while the worker is suspended" {
    var clock: html.worker_event_loop.SuspendClock = .{};
    const before = clock.read();
    clock.stop();
    const stopped = clock.read();
    sleepMs(30);
    try testing.expectEqual(stopped, clock.read());
    clock.start();
    const after = clock.read();
    // Only the time it ran counts: far less than the 30 ms it was stopped.
    try testing.expect(after >= before);
    try testing.expect(after - before < 20 * std.time.ns_per_ms);
}

// ============================================================================
// Shared workers: suspended while no owner is fully active
// ============================================================================

const key: SharedWorkerManager.Key = .{
    .storage_key = "https://web-platform.test:8443",
    .url = "https://web-platform.test:8443/workers/w.js",
    .name = "n",
};
const classic: SharedWorkerManager.Options = .{ .worker_type = .classic, .credentials = .same_origin };

test "a shared worker is suspended when its only owner is cached, and resumed when it is shown again" {
    const sink = try runtime.TaskSink.create(testing.allocator);
    defer sink.release();
    var manager = SharedWorkerManager.init(testing.allocator);
    defer manager.deinit();
    const link = try WorkerLink.create(testing.allocator, sink);
    defer link.release();
    try manager.add(key, classic, link, &host_data, &realm_a);

    {
        var transitions = SharedWorkerManager.Transitions.init(testing.allocator, true);
        defer transitions.deinit();
        manager.ownerInactive(&realm_a, &transitions);
        try testing.expectEqual(@as(usize, 1), transitions.suspend_now.items.len);
        transitions.apply(null);
    }
    try testing.expect(link.isSuspended());
    try testing.expect(!manager.hasActiveOwnerOf(link));
    // Still an owner while cached.
    try testing.expect(manager.hasOwner(&realm_a));

    {
        var transitions = SharedWorkerManager.Transitions.init(testing.allocator, false);
        defer transitions.deinit();
        manager.ownerActive(&realm_a, &transitions);
        try testing.expectEqual(@as(usize, 1), transitions.resume_now.items.len);
        transitions.apply(null);
    }
    try testing.expect(!link.isSuspended());
    try testing.expect(manager.hasActiveOwnerOf(link));
    _ = manager.removeOwner(&realm_a, null, null);
}

test "a shared worker with another fully active owner is not suspended; the last active owner's end suspends it" {
    const sink = try runtime.TaskSink.create(testing.allocator);
    defer sink.release();
    var manager = SharedWorkerManager.init(testing.allocator);
    defer manager.deinit();
    const link = try WorkerLink.create(testing.allocator, sink);
    defer link.release();
    try manager.add(key, classic, link, &host_data, &realm_a);
    const found = (try manager.connect(key, classic, &realm_b)).?;
    found.link.release();
    try testing.expect(!found.resumes);

    {
        var transitions = SharedWorkerManager.Transitions.init(testing.allocator, true);
        defer transitions.deinit();
        manager.ownerInactive(&realm_a, &transitions);
        try testing.expectEqual(@as(usize, 0), transitions.suspend_now.items.len);
    }
    try testing.expect(manager.hasActiveOwnerOf(link));

    // realm_b's Document is destroyed: realm_a, cached, is all that is left.
    {
        var transitions = SharedWorkerManager.Transitions.init(testing.allocator, true);
        defer transitions.deinit();
        try testing.expectEqual(@as(usize, 0), manager.removeOwner(&realm_b, null, &transitions));
        try testing.expectEqual(@as(usize, 1), transitions.suspend_now.items.len);
        transitions.apply(null);
    }
    try testing.expect(link.isSuspended());

    // A new Document connects: the worker is actively needed again.
    const again = (try manager.connect(key, classic, &realm_b)).?;
    again.link.release();
    try testing.expect(again.resumes);
    _ = manager.removeOwner(&realm_a, null, null);
    _ = manager.removeOwner(&realm_b, null, null);
}

test "a shared worker in extended lifetime is suspended only once the timeout passes with no owner fully active" {
    const sink = try runtime.TaskSink.create(testing.allocator);
    defer sink.release();
    var manager = SharedWorkerManager.init(testing.allocator);
    defer manager.deinit();
    const link = try WorkerLink.create(testing.allocator, sink);
    defer link.release();
    const extended: SharedWorkerManager.Options = .{ .worker_type = .classic, .credentials = .same_origin, .extended_lifetime = true };
    try manager.add(key, extended, link, &host_data, &realm_a);

    var transitions = SharedWorkerManager.Transitions.init(testing.allocator, true);
    defer transitions.deinit();
    manager.ownerInactive(&realm_a, &transitions);
    try testing.expectEqual(@as(usize, 0), transitions.suspend_now.items.len);
    try testing.expectEqual(@as(usize, 1), transitions.delayed.?.items.len);
    const first = transitions.delayed.?.items[0];
    try testing.expect(!link.isSuspended());

    // Shown again and cached again before the timeout: the first timer's
    // epoch is stale.
    var shown = SharedWorkerManager.Transitions.init(testing.allocator, false);
    defer shown.deinit();
    manager.ownerActive(&realm_a, &shown);
    var cached_again = SharedWorkerManager.Transitions.init(testing.allocator, true);
    defer cached_again.deinit();
    manager.ownerInactive(&realm_a, &cached_again);
    try testing.expect(!manager.suspendIfStillInactive(link, first.epoch, null));
    try testing.expect(!link.isSuspended());
    // The second one's timeout: suspended.
    const second = cached_again.delayed.?.items[0];
    try testing.expect(manager.suspendIfStillInactive(link, second.epoch, null));
    try testing.expect(link.isSuspended());
    _ = manager.removeOwner(&realm_a, null, null);
}

test "ownersOf lists a shared worker's owner realms" {
    const sink = try runtime.TaskSink.create(testing.allocator);
    defer sink.release();
    var manager = SharedWorkerManager.init(testing.allocator);
    defer manager.deinit();
    const link = try WorkerLink.create(testing.allocator, sink);
    defer link.release();
    const stranger = try WorkerLink.create(testing.allocator, sink);
    defer stranger.release();
    try manager.add(key, classic, link, &host_data, &realm_a);
    (try manager.connect(key, classic, &realm_b)).?.link.release();
    var owners: std.ArrayListUnmanaged(*const anyopaque) = .empty;
    defer owners.deinit(testing.allocator);
    try testing.expect(try manager.ownersOf(link, &owners, testing.allocator));
    try testing.expectEqual(@as(usize, 2), owners.items.len);
    owners.clearRetainingCapacity();
    try testing.expect(!(try manager.ownersOf(stranger, &owners, testing.allocator)));
    _ = manager.removeOwner(&realm_a, null, null);
    _ = manager.removeOwner(&realm_b, null, null);
}

// ============================================================================
// Lock contention reaches the holder
// ============================================================================

/// A lock environment whose contention hook counts, and answers `doomed`:
/// whether its page can never be restored (lane locks1: the registry then
/// breaks its lock at once).
const Holder = struct {
    contended: usize = 0,
    events: usize = 0,
    granted: usize = 0,
    not_granted: usize = 0,
    doomed: bool = false,

    fn delivery(self: *Holder) web_locks.Delivery {
        return .{ .ctx = self, .post = post, .deinit = deinitCtx, .contention = contention };
    }

    fn post(ctx: *anyopaque, event: web_locks.Event) void {
        const self: *Holder = @ptrCast(@alignCast(ctx));
        self.events += 1;
        switch (event.kind) {
            .granted => self.granted += 1,
            .not_granted => self.not_granted += 1,
            .stolen => {},
        }
    }

    fn deinitCtx(_: *anyopaque) void {}

    fn contention(ctx: *anyopaque) bool {
        const self: *Holder = @ptrCast(@alignCast(ctx));
        self.contended += 1;
        return self.doomed;
    }
};

const origin = "https://web-platform.test:8443";

test "a request that cannot be granted, or a query, tells the holders of the lock it contends with" {
    var registry = web_locks.Registry.init(testing.allocator);
    defer registry.deinit();
    var holder: Holder = .{};
    var asker: Holder = .{};
    const client_holder = try registry.register(&realm_a, &realm_a, origin, holder.delivery());
    const client_asker = try registry.register(&realm_b, &realm_b, origin, asker.delivery());

    _ = try registry.request(client_holder, "res", .{});
    try testing.expectEqual(@as(usize, 0), holder.contended);
    // Another name: no contention.
    _ = try registry.request(client_asker, "other", .{});
    try testing.expectEqual(@as(usize, 0), holder.contended);
    // The same name, not grantable: the holder hears it.
    _ = try registry.request(client_asker, "res", .{});
    try testing.expectEqual(@as(usize, 1), holder.contended);
    // ifAvailable, not grantable: so does it.
    _ = try registry.request(client_asker, "res", .{ .if_available = true });
    try testing.expectEqual(@as(usize, 2), holder.contended);
    // A query: every holder it lists - the holder of "res", and the asker,
    // which holds "other".
    var snapshot = try registry.snapshot(client_asker, testing.allocator);
    snapshot.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 3), holder.contended);
    try testing.expectEqual(@as(usize, 1), asker.contended);
    // Shared with shared is grantable: no contention.
    var shared_holder: Holder = .{};
    var realm_c: u8 = 0;
    const client_shared = try registry.register(&realm_c, &realm_c, origin, shared_holder.delivery());
    _ = try registry.request(client_shared, "shared", .{ .mode = .shared });
    _ = try registry.request(client_asker, "shared", .{ .mode = .shared });
    try testing.expectEqual(@as(usize, 0), shared_holder.contended);
    registry.unregister(client_shared);
    registry.unregister(client_asker);
    registry.unregister(client_holder);
}

test "locks1: a doomed holder's lock breaks at once - a request, an ifAvailable one too, is granted; a query breaks nothing" {
    var registry = web_locks.Registry.init(testing.allocator);
    defer registry.deinit();
    var holder: Holder = .{};
    var asker: Holder = .{};
    const client_holder = try registry.register(&realm_a, &realm_a, origin, holder.delivery());
    const client_asker = try registry.register(&realm_b, &realm_b, origin, asker.delivery());

    _ = try registry.request(client_holder, "res", .{});
    _ = try registry.request(client_holder, "kept", .{});
    try testing.expectEqual(@as(usize, 2), holder.granted);
    // Not doomed: an ifAvailable request is refused, and nothing breaks.
    _ = try registry.request(client_asker, "res", .{ .if_available = true });
    try testing.expectEqual(@as(usize, 1), asker.not_granted);
    try testing.expectEqual(@as(usize, 0), asker.granted);
    // Doomed (its page can never be restored): a query tells it, and
    // breaks nothing - the snapshot lists both of its locks.
    holder.doomed = true;
    var snapshot = try registry.snapshot(client_asker, testing.allocator);
    try testing.expectEqual(@as(usize, 2), snapshot.held.len);
    snapshot.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 3), holder.contended);
    // An ifAvailable request: the doomed holder's lock breaks at once, and
    // the request is granted - its other lock stays.
    _ = try registry.request(client_asker, "res", .{ .if_available = true });
    try testing.expectEqual(@as(usize, 1), asker.not_granted);
    try testing.expectEqual(@as(usize, 1), asker.granted);
    snapshot = try registry.snapshot(client_holder, testing.allocator);
    try testing.expectEqual(@as(usize, 2), snapshot.held.len);
    for (snapshot.held) |info| try testing.expect(std.mem.eql(u8, info.name, "res") == std.mem.eql(u8, &info.client_id, &client_asker.id));
    snapshot.deinit(testing.allocator);
    // A plain request breaks it too, and a request that waited behind the
    // broken lock since before its holder was doomed is granted first, in
    // queue order.
    holder.doomed = false;
    _ = try registry.request(client_asker, "kept", .{});
    try testing.expectEqual(@as(usize, 1), asker.granted);
    holder.doomed = true;
    var third: Holder = .{};
    var realm_c: u8 = 0;
    const client_third = try registry.register(&realm_c, &realm_c, origin, third.delivery());
    _ = try registry.request(client_third, "kept", .{});
    try testing.expectEqual(@as(usize, 2), asker.granted);
    try testing.expectEqual(@as(usize, 0), third.granted);
    registry.unregister(client_third);
    registry.unregister(client_asker);
    registry.unregister(client_holder);
}
