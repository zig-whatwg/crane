//! The Browser's event loop (HTML 8.1.7): the host's, for the page's agent.
//!
//! An event loop is the host's - its task queues, its timers, the network
//! it waits on - and runs the engine only through the agent operations: the
//! microtask checkpoint (engine.performMicrotaskCheckpoint), the work the
//! engine posts for itself (engine.runEngineTasks: an asynchronous
//! WebAssembly compile's result, FinalizationRegistry cleanup) and the
//! microtask queue (engine.queueMicrotask). It was the V8 adapter's
//! V8EventLoop; that one stays for the worker realms until they move too.
//!
//! One turn (`runOnceBlocking`) follows the Node.js/Chromium pattern:
//! checkpoint; the tasks queued before the turn began, each followed by a
//! checkpoint; the engine's own tasks; the network; then a wait for the next
//! timer, the deadline, or I/O; timer callbacks; a last checkpoint. A turn
//! that finds no task queued starts an idle period for the windows that asked
//! for one (HTML 8.1.7.3 step 5; requestIdleCallback).
//!
//! ## Bfcache support
//!
//! freeze() suspends all timer and task processing and thaw() resumes it:
//! while frozen, a turn returns at once and runs nothing.

const std = @import("std");
const Allocator = std.mem.Allocator;
const clock = @import("clock");
const engine = @import("engine");
const runtime = @import("runtime");
const dom = @import("dom");
const idle_periods = dom.idle_periods;

const TimerManager = runtime.native_timer.NativeTimerManager;
const Task = runtime.EventLoopTask;
const Microtask = runtime.EventLoopMicrotask;

/// The fetches in flight on this thread - `fetch()`'s, run on the event loop.
const async_fetch = @import("fetch").algorithms.async_fetch;

pub const EventLoop = struct {
    /// The agent whose event loop this is.
    agent: *engine.Agent,

    /// Allocator for the loop's bookkeeping.
    allocator: Allocator,

    /// Arena for promise allocation (owned by this event loop)
    promise_arena: std.heap.ArenaAllocator,

    /// The task queue: the engine has none of its own for the host's tasks.
    tasks: std.ArrayList(Task),

    /// Track if we're inside runOnce to prevent reentrancy
    in_run_once: bool,

    /// The timers setTimeout/setInterval and the loop's own waits run on.
    timer_manager: ?*TimerManager,

    /// Whether this event loop is frozen (for bfcache)
    frozen: bool,

    /// The same-loop windows that asked for an idle period
    /// (requestIdleCallback), in the order they asked: each runs its "start
    /// an idle period" steps when the next one starts.
    idle_requests: std.ArrayListUnmanaged(IdleRequest) = .empty,

    /// HTML 8.1.7.1: the window event loop's last idle period start time
    /// (clock.monotonicNanos); 0 before the first.
    last_idle_period_start_ns: i64 = 0,

    /// The current idle period's deadline: computeDeadline when it started,
    /// brought forward by timers that came due sooner while it lasted. One
    /// idle period at a time: the next starts once this has passed.
    idle_period_end_ns: i64 = 0,

    /// Which idle period is current (Period.id); 0 before the first.
    idle_period_id: u64 = 0,

    /// No idle period starts before this time: the loop has just run work a
    /// frame long or longer (`noteWork`).
    idle_blocked_until_ns: i64 = 0,

    const Self = @This();

    /// Default maximum wait time when no explicit timeout is provided.
    /// This allows the event loop to block efficiently while still being responsive.
    const DEFAULT_MAX_WAIT_MS: u64 = 100;

    /// A new event loop for `agent`, with its timers.
    pub fn init(agent: *engine.Agent, allocator: Allocator) !Self {
        const timer_mgr = try TimerManager.init(allocator);
        errdefer timer_mgr.deinit();

        return .{
            .agent = agent,
            .allocator = allocator,
            .promise_arena = std.heap.ArenaAllocator.init(allocator),
            .tasks = .empty,
            .in_run_once = false,
            .timer_manager = timer_mgr,
            .frozen = false,
        };
    }

    /// Free all resources: the timers (every pending one cancelled), the
    /// tasks still queued (each told it will never run), the promise arena.
    /// Microtasks still in the agent's queue are the engine's.
    pub fn deinit(self: *Self) void {
        if (self.timer_manager) |mgr| mgr.deinit();
        // A task still queued will never run: let it free what it carries.
        for (self.tasks.items) |task| {
            if (task.drop) |drop| drop(task.context);
        }
        self.tasks.deinit(self.allocator);
        // A window still waiting for an idle period is told nothing: its
        // idle callbacks went with its document (Window's unloading cleanup
        // step), and a request holds no data of its own.
        self.idle_requests.deinit(self.allocator);
        self.promise_arena.deinit();
    }

    /// The timer interface realms schedule on (setTimeout, AbortSignal.timeout).
    pub fn timerInterface(self: *Self) ?runtime.TimerInterface {
        if (self.timer_manager) |mgr| return mgr.timerInterface();
        return null;
    }

    /// Drain all pending timer close callbacks: a cancelled timer's handle is
    /// fully released only once its close callback has run.
    pub fn drainCloseCallbacks(self: *Self) u32 {
        if (self.timer_manager) |mgr| return mgr.drainCloseCallbacks();
        return 0;
    }

    /// The count of pending timers (including those being closed).
    pub fn getPendingTimerCount(self: *Self) usize {
        if (self.timer_manager) |mgr| return mgr.getPendingCount();
        return 0;
    }

    /// The EventLoop interface host algorithms queue on (streams, Blob).
    pub fn eventLoop(self: *Self) runtime.EventLoop {
        return .{ .ptr = self, .vtable = &interface_vtable };
    }

    /// One table for every loop, so that a realm's EventLoop interface tells
    /// whether it is this type's (`of`).
    const interface_vtable: runtime.EventLoop.VTable = .{
        .queueMicrotask = queueMicrotask,
        .queueTask = queueTask,
        .runMicrotasks = runMicrotasks,
        .runOnce = runOnce,
        .promiseAllocator = promiseAllocator,
    };

    /// The Browser event loop `realm` queues on, when it is one (a worker's
    /// realm runs on another kind).
    pub fn of(realm: runtime.Context) ?*Self {
        const loop = realm.getOptionalEventLoop() orelse return null;
        if (loop.vtable != &interface_vtable) return null;
        return @ptrCast(@alignCast(loop.ptr));
    }

    // ========================================================================
    // Bfcache Freeze/Thaw Support
    // ========================================================================

    /// Freeze the event loop for bfcache: a turn runs nothing (timers keep
    /// their remaining times; tasks stay queued) until thaw().
    pub fn freeze(self: *Self) !void {
        if (self.frozen) return error.AlreadyFrozen;
        self.frozen = true;
    }

    /// Thaw the event loop after bfcache restoration.
    pub fn thaw(self: *Self) !void {
        if (!self.frozen) return error.NotFrozen;
        self.frozen = false;
    }

    /// Whether the event loop is currently frozen.
    pub fn isFrozen(self: *Self) bool {
        return self.frozen;
    }

    // ========================================================================
    // A turn
    // ========================================================================

    /// Run one turn of the event loop, blocking at most `max_wait_ms` for a
    /// timer or I/O (0: a non-blocking check). Whether any work was done, or
    /// is waiting for the next turn.
    pub fn runOnceBlocking(self: *Self, max_wait_ms: u64) bool {
        // Don't process tasks or timers when frozen (bfcache support)
        if (self.frozen) return false;

        // Prevent reentrancy
        if (self.in_run_once) return false;
        self.in_run_once = true;
        defer self.in_run_once = false;

        var did_work = false;

        // Step 1: the microtasks pending from before the turn.
        self.checkpoint();

        const work_start = monotonicNs();

        // Step 2: the tasks queued before this turn began.
        if (self.runQueuedTasks()) did_work = true;

        // Step 2b: the tasks the engine has posted for itself (a bounded
        // batch, each followed by a microtask checkpoint, since it may have
        // settled a promise - d8's ProcessMessages does the same).
        if (engine.runEngineTasks(self.agent)) did_work = true;

        // Step 2c: move the fetches in flight along. A fetch that ended
        // queues its task for the next turn. The wait below is sliced at 1ms
        // (native_timer.zig), and a fetch in flight is pending work, so the
        // loop never sleeps through a response.
        if (async_fetch.pump()) did_work = true;

        const now = monotonicNs();
        self.noteWork(work_start, now);

        // Step 2d (HTML 8.1.7.3 step 5): no runnable task, so an idle period
        // for the same-loop windows that asked for one. Each queues its
        // "invoke idle callbacks" task, which the next turn runs.
        if (self.startIdlePeriod(now)) did_work = true;

        // Step 3: how long to wait - until the next timer or max_wait_ms.
        const wait_time = blk: {
            // A task left for the next turn is work waiting now: poll, but
            // do not block.
            if (self.tasks.items.len > 0) break :blk 0;
            var wait = max_wait_ms;
            if (self.timer_manager) |mgr| {
                if (mgr.getNextTimerDeadline()) |deadline| wait = @min(deadline, wait);
            }
            // A window waiting for an idle period: wake when one can start.
            if (self.idleWaitMs(now)) |idle_wait| wait = @min(idle_wait, wait);
            break :blk wait;
        };

        // Step 4: wait for a timer or I/O, and run the timer callbacks.
        if (self.timer_manager) |mgr| {
            const poll_start = monotonicNs();
            if (mgr.pollBlocking(wait_time)) did_work = true;
            // The wait is at most a millisecond slice (native_timer.zig);
            // the rest is timer callbacks.
            self.noteWork(poll_start + std.time.ns_per_ms, monotonicNs());
        }

        // Step 5: the microtasks the timer callbacks queued.
        self.checkpoint();

        // Tasks queued during this turn - by the tasks above or by timer
        // callbacks - wait for the next one, which a non-empty queue makes
        // the caller start at once.
        return did_work or self.hasPendingWork();
    }

    /// HTML "perform a microtask checkpoint", the agent's.
    fn checkpoint(self: *Self) void {
        engine.performMicrotaskCheckpoint(self.agent) catch {};
    }

    /// Run the tasks queued so far, each followed by a microtask checkpoint
    /// (it may have resolved promises). A task they queue waits for the next
    /// turn, as HTML's event loop runs one task per iteration: draining until
    /// the queue was empty let a task that queues a task keep a turn from
    /// ever returning, and with it the deadline its caller checks between
    /// turns. Whether any task ran.
    fn runQueuedTasks(self: *Self) bool {
        var budget = self.tasks.items.len;
        if (budget == 0) return false;
        while (budget > 0 and self.tasks.items.len > 0) : (budget -= 1) {
            const task = self.tasks.orderedRemove(0);
            if (!isRunnable(task)) {
                if (task.drop) |drop| drop(task.context);
                continue;
            }
            task.callback(task.context);
            self.checkpoint();
        }
        return true;
    }

    /// HTML 8.1.7.1: "A task is runnable if its document is either null or
    /// fully active."
    ///
    /// Stated simplification: HTML leaves a task that is not runnable in its
    /// queue, to run once its document is fully active again. Crane keeps no
    /// bfcache, so a document that stops being fully active never becomes
    /// so again, and "destroy a document" (step 6) removes its tasks from
    /// the queues without running them - so the loop drops such a task
    /// (`drop` frees what it carries) instead of keeping it forever.
    fn isRunnable(task: Task) bool {
        const document = task.document orelse return true;
        return dom.document_activity.fullyActive(document, task.document_generation);
    }

    /// Whether there is pending work that should keep the loop from idling.
    pub fn hasPendingWork(self: *Self) bool {
        if (self.tasks.items.len > 0) return true;
        // A window waiting for an idle period: one will start.
        if (self.idle_requests.items.len > 0) return true;
        // A fetch in flight will queue a task when it ends.
        if (async_fetch.inFlight() > 0) return true;
        if (self.timer_manager) |mgr| {
            if (mgr.getActiveTimerCount() > 0) return true;
        }
        return false;
    }

    // ========================================================================
    // Idle periods (HTML 8.1.7.3 step 5; requestIdleCallback)
    // ========================================================================
    //
    // Crane renders nothing. Its rendering opportunities are the animation
    // frame timer (browser/Context.zig, a timer every 16 ms while frame
    // callbacks wait), so the timers bound a deadline as the next rendering
    // opportunity would. Every timer of this loop counts, not only the
    // windows' maps of active timers: the engine's own and the idle
    // callbacks' timeouts make deadlines earlier, which a user agent may
    // always do ("The user agent is free to end an idle period early").

    /// The longest an idle period lasts: "last idle period start time plus
    /// 50" (computeDeadline step 1).
    pub const max_idle_period_ns: i64 = 50 * std.time.ns_per_ms;

    /// Work this long, in one stretch of a turn, keeps idle periods away for
    /// as long again: a frame. HTML lets the user agent delay an idle period
    /// ("start an idle period" step 1); a browser starts one after a frame,
    /// and a long task leaves the frame pipeline behind
    /// (requestidlecallback/callback-timeout-when-busy.html: no idle callback
    /// between the tasks of a busy chain of timers).
    pub const long_work_ns: i64 = 16 * std.time.ns_per_ms;

    /// `realm`'s window asks for an idle period: `start` runs when the next
    /// one starts. Asking again before then is asking once.
    pub fn requestIdlePeriod(self: *Self, realm: runtime.Context, start: idle_periods.StartIdlePeriod) void {
        for (self.idle_requests.items) |request| {
            if (request.realm == realm) return;
        }
        self.idle_requests.append(self.allocator, .{ .realm = realm, .start = start }) catch {
            std.log.err("event loop: out of memory asking for an idle period; dropped", .{});
        };
    }

    /// computeDeadline now (ns) for `period`: its end, brought forward by a
    /// timer due sooner - and by the loop's own record when `period` is the
    /// current one, which kept every timer it saw come due.
    pub fn idleDeadline(self: *Self, period: idle_periods.Period) i64 {
        var deadline = period.end_ns;
        if (period.id == self.idle_period_id) deadline = @min(deadline, self.idle_period_end_ns);
        if (self.nextTimerDueNs(monotonicNs())) |due| deadline = @min(deadline, due);
        return deadline;
    }

    /// Step 5, when this turn has no runnable task: "Set this event loop's
    /// last idle period start time to the unsafe shared current time", and
    /// for each same-loop window, "start an idle period" with
    /// computeDeadline. Whether one started.
    fn startIdlePeriod(self: *Self, now: i64) bool {
        if (self.idle_requests.items.len == 0) return false;
        // A runnable task: not idle.
        if (self.tasks.items.len > 0) return false;
        if (!self.idlePeriodMayStart(now)) return false;

        // Step 5.1.
        self.last_idle_period_start_ns = now;
        // Step 5.2: computeDeadline.
        var end = now + max_idle_period_ns;
        if (self.nextTimerDueNs(now)) |due| end = @min(end, due);
        self.idle_period_id += 1;
        self.idle_period_end_ns = end;
        const period: idle_periods.Period = .{ .id = self.idle_period_id, .end_ns = end };

        // Step 5.3: the windows that asked before now. One that asks while
        // its steps run waits for the next idle period.
        var requests = self.idle_requests;
        self.idle_requests = .empty;
        defer requests.deinit(self.allocator);
        for (requests.items) |request| request.start(request.realm, period);
        return true;
    }

    /// Whether a new idle period may start at `now`: the current one has
    /// ended ("There can only be one idle period active at a given time for
    /// any given Window"), and the loop has not just run long work.
    fn idlePeriodMayStart(self: *Self, now: i64) bool {
        if (now < self.idle_blocked_until_ns) return false;
        if (now >= self.idle_period_end_ns) return true;
        // Still current: a timer due sooner ends it sooner.
        if (self.nextTimerDueNs(now)) |due| self.idle_period_end_ns = @min(self.idle_period_end_ns, due);
        return now >= self.idle_period_end_ns;
    }

    /// How long until a waiting window's idle period can start (ms), when
    /// one is waiting.
    fn idleWaitMs(self: *Self, now: i64) ?u64 {
        if (self.idle_requests.items.len == 0) return null;
        const at = @max(self.idle_blocked_until_ns, self.idle_period_end_ns);
        if (at <= now) return 0;
        return @intCast(@divTrunc(at - now + std.time.ns_per_ms - 1, std.time.ns_per_ms));
    }

    /// Work from `start` to `end` (ns) a frame long or longer keeps idle
    /// periods away for a frame after it.
    fn noteWork(self: *Self, start: i64, end: i64) void {
        if (end - start >= long_work_ns) self.idle_blocked_until_ns = end + long_work_ns;
    }

    /// When the next timer of this loop comes due (ns), if one is armed.
    fn nextTimerDueNs(self: *Self, now: i64) ?i64 {
        const mgr = self.timer_manager orelse return null;
        // Whole milliseconds, rounded down: never later than the timer.
        const due_in_ms = mgr.getNextTimerDeadline() orelse return null;
        return now + @as(i64, @intCast(due_in_ms)) * std.time.ns_per_ms;
    }

    /// dom.idle_periods' loop half: the browser layer installs it at process
    /// start (Context.installHooks).
    pub const idle_period_hooks: idle_periods.Loop = .{
        .request = hookRequestIdlePeriod,
        .deadline = hookIdleDeadline,
    };

    fn hookRequestIdlePeriod(realm: runtime.Context, start: idle_periods.StartIdlePeriod) void {
        const self = of(realm) orelse return;
        self.requestIdlePeriod(realm, start);
    }

    fn hookIdleDeadline(realm: runtime.Context, period: idle_periods.Period) i64 {
        const self = of(realm) orelse return period.end_ns;
        return self.idleDeadline(period);
    }

    // ========================================================================
    // EventLoop Interface Implementation
    // ========================================================================

    fn queueMicrotask(ptr: *anyopaque, task: Microtask) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        const queued = self.allocator.create(QueuedMicrotask) catch {
            // Dropping is better than crashing: the interface cannot fail.
            std.log.err("event loop: out of memory queueing a microtask; dropped", .{});
            return;
        };
        queued.* = .{ .task = task, .allocator = self.allocator };
        engine.queueMicrotask(self.agent, QueuedMicrotask.run, queued) catch |err| {
            self.allocator.destroy(queued);
            std.log.err("event loop: a microtask was not queued: {}", .{err});
        };
    }

    fn queueTask(ptr: *anyopaque, task: Task) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        // A task with a document may be dropped without running (isRunnable):
        // it must be able to free what it carries.
        std.debug.assert(task.document == null or task.drop != null);
        self.tasks.append(self.allocator, task) catch {
            // If allocation fails, log and drop the task
            // This is safer than crashing the runtime
            std.log.err("event loop: out of memory queueing a task; dropped", .{});
        };
    }

    fn runMicrotasks(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.checkpoint();
    }

    fn runOnce(ptr: *anyopaque) bool {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.runOnceBlocking(DEFAULT_MAX_WAIT_MS);
    }

    fn promiseAllocator(ptr: *anyopaque) Allocator {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.promise_arena.allocator();
    }
};

/// The monotonic clock, in nanoseconds (the idle periods' time base).
fn monotonicNs() i64 {
    return @intCast(clock.monotonicNanos());
}

/// A same-loop window waiting for an idle period. Its realm is BORROWED: work
/// on the realm's own agent may keep it across turns, and the start steps
/// check `hasEngine()` before they reach the window.
const IdleRequest = struct {
    realm: runtime.Context,
    start: idle_periods.StartIdlePeriod,
};

/// A host microtask in the agent's queue, until it runs.
const QueuedMicrotask = struct {
    task: Microtask,
    allocator: Allocator,

    fn run(data: ?*anyopaque) void {
        const self: *QueuedMicrotask = @ptrCast(@alignCast(data.?));
        const task = self.task;
        self.allocator.destroy(self);
        task.callback(task.context);
    }
};

// ============================================================================
// Tests: the idle period step, without an engine (no turn is run - a turn's
// microtask checkpoint needs the agent).
// ============================================================================

const testing = std.testing;

/// A loop over no agent: the idle period steps never reach it.
fn testLoop() !EventLoop {
    return EventLoop.init(@ptrFromInt(@alignOf(usize)), testing.allocator);
}

/// A window, as the idle period steps see it: its realm, and what its start
/// steps were given.
const TestWindow = struct {
    realm: runtime.ContextData = undefined,
    starts: usize = 0,
    period: idle_periods.Period = undefined,

    fn start(realm: runtime.Context, period: idle_periods.Period) void {
        const self: *TestWindow = @fieldParentPtr("realm", realm);
        self.starts += 1;
        self.period = period;
    }
};

fn noop(_: ?*anyopaque) void {}

test "an idle period starts only with no task queued, for each window that asked, once" {
    var loop = try testLoop();
    defer loop.deinit();
    var a: TestWindow = .{};
    var b: TestWindow = .{};

    loop.requestIdlePeriod(&a.realm, &TestWindow.start);
    loop.requestIdlePeriod(&a.realm, &TestWindow.start);
    loop.requestIdlePeriod(&b.realm, &TestWindow.start);
    try testing.expectEqual(@as(usize, 2), loop.idle_requests.items.len);
    try testing.expect(loop.hasPendingWork());

    // A runnable task: the loop is not idle.
    try loop.tasks.append(testing.allocator, .{ .callback = &noop, .context = null });
    try testing.expect(!loop.startIdlePeriod(1_000 * std.time.ns_per_ms));
    try testing.expectEqual(@as(usize, 0), a.starts);
    _ = loop.tasks.orderedRemove(0);

    const now: i64 = 1_000 * std.time.ns_per_ms;
    try testing.expect(loop.startIdlePeriod(now));
    try testing.expectEqual(@as(usize, 1), a.starts);
    try testing.expectEqual(@as(usize, 1), b.starts);
    // computeDeadline with no timer: the 50 ms cap.
    try testing.expectEqual(now + EventLoop.max_idle_period_ns, a.period.end_ns);
    try testing.expectEqual(a.period.id, b.period.id);
    try testing.expectEqual(now, loop.last_idle_period_start_ns);
    // Every request was answered.
    try testing.expectEqual(@as(usize, 0), loop.idle_requests.items.len);
    try testing.expect(!loop.startIdlePeriod(now + EventLoop.max_idle_period_ns));
}

test "the next idle period waits for the current one's deadline" {
    var loop = try testLoop();
    defer loop.deinit();
    var a: TestWindow = .{};
    const t0: i64 = 1_000 * std.time.ns_per_ms;

    loop.requestIdlePeriod(&a.realm, &TestWindow.start);
    try testing.expect(loop.startIdlePeriod(t0));
    const first = a.period;
    // Asked again from inside the period: it waits for the next one.
    loop.requestIdlePeriod(&a.realm, &TestWindow.start);
    try testing.expect(!loop.startIdlePeriod(t0 + 10 * std.time.ns_per_ms));
    try testing.expectEqual(@as(?u64, 40), loop.idleWaitMs(t0 + 10 * std.time.ns_per_ms));
    try testing.expect(loop.startIdlePeriod(t0 + EventLoop.max_idle_period_ns));
    try testing.expectEqual(@as(usize, 2), a.starts);
    try testing.expect(a.period.id > first.id);
}

test "the next timer brings an idle period's deadline forward" {
    var loop = try testLoop();
    defer loop.deinit();
    var a: TestWindow = .{};
    const mgr = loop.timer_manager.?;
    const id = mgr.setTimeout(20, &noop, null);
    defer _ = mgr.clearTimeout(id);

    const now = monotonicNs();
    loop.requestIdlePeriod(&a.realm, &TestWindow.start);
    try testing.expect(loop.startIdlePeriod(now));
    const end = a.period.end_ns;
    try testing.expect(end <= now + 20 * std.time.ns_per_ms);
    try testing.expect(end < now + EventLoop.max_idle_period_ns);
    // Asked again, the deadline is no later than it was.
    try testing.expect(loop.idleDeadline(a.period) <= end);
    // A timer armed during the period, due sooner, brings it forward.
    const sooner = mgr.setTimeout(1, &noop, null);
    defer _ = mgr.clearTimeout(sooner);
    try testing.expect(loop.idleDeadline(a.period) <= monotonicNs() + 1 * std.time.ns_per_ms);
}

test "work a frame long keeps idle periods away for a frame" {
    var loop = try testLoop();
    defer loop.deinit();
    var a: TestWindow = .{};
    const ms = std.time.ns_per_ms;

    // Short work changes nothing.
    loop.noteWork(1_000 * ms, 1_005 * ms);
    loop.requestIdlePeriod(&a.realm, &TestWindow.start);
    try testing.expect(loop.startIdlePeriod(1_005 * ms));

    // Long work: none until a frame after it ends.
    loop.noteWork(2_000 * ms, 2_020 * ms);
    loop.requestIdlePeriod(&a.realm, &TestWindow.start);
    try testing.expect(!loop.startIdlePeriod(2_030 * ms));
    try testing.expectEqual(@as(?u64, 6), loop.idleWaitMs(2_030 * ms));
    try testing.expect(loop.startIdlePeriod(2_036 * ms));
}

test "a task with no document is runnable" {
    try testing.expect(EventLoop.isRunnable(.{ .callback = &noop, .context = null }));
}
