//! A worker's event loop (HTML 8.1.7, a worker event loop), on the worker's
//! own thread.
//!
//! Every worker runs its agent on a thread of its own (docs/instances.md,
//! "Decisions"); this is the loop that thread spins. It is a
//! `runtime.EventLoop` - what host algorithms queue their tasks on (streams,
//! Blob, fetch's settle steps) - and it owns the worker realm's timers. What
//! other threads send the worker - its owner's messages, a port's "has
//! messages", the wake of "terminate a worker" - arrives through its
//! TaskSink (`WorkerLink.worker_sink`), which each turn takes into the task
//! queue.
//!
//! It shares no state with the window's loop (src/browser/event_loop.zig;
//! html cannot import the browser layer), and a worker's tasks carry no
//! document: they are always runnable.
//!
//! One turn (`turn`), the window loop's shape:
//! 1. what was posted from other threads joins the task queue;
//! 2. the tasks queued before the turn, each followed by a microtask
//!    checkpoint - stopping as soon as the worker is closing (HTML: a closing
//!    worker's tasks are discarded);
//! 3. the engine's own posted tasks for the agent (V8's platform tasks: an
//!    asynchronous WebAssembly compile settling its promise);
//! 4. this thread's fetches in flight;
//! 5. with nothing queued, a wait: until the next timer, a post, or - while
//!    the engine or the network has work in flight that will not post - at
//!    most a millisecond;
//! 6. the timers that came due, then a checkpoint.
//!
//! `run` turns until the worker is closing. At `deinit` the queued tasks are
//! dropped (each told it will never run), the sink is closed - what other
//! threads post from then on is dropped by their post - and the timers end,
//! an owned timer's data dropped.
//!
//! A suspended worker (HTML "run a worker" step 8, *suspending workers*:
//! WorkerLink.suspended) runs nothing: at its next task boundary the loop
//! parks - what other threads post joins the task queue unrun - until it is
//! resumed or closing (`parkWhileSuspended`). Its timers' clock stands still
//! meanwhile: HTML's timer initialization steps wait "until timeout
//! milliseconds have passed with the worker not suspended (not necessarily
//! consecutively)", and AbortSignal.timeout's "run steps after a timeout" the
//! same (`SuspendClock`).

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");
const WorkerLink = @import("worker_link.zig").WorkerLink;

const TimerManager = runtime.native_timer.NativeTimerManager;
const Task = runtime.EventLoopTask;
const Microtask = runtime.EventLoopMicrotask;

/// An agent's fetches on its event loop (on its host: AgentHost.fetches).
const AgentFetches = @import("fetch").algorithms.AgentFetches;

const log = std.log.scoped(.worker_event_loop);

pub const WorkerEventLoop = struct {
    allocator: Allocator,
    /// Whose closing flag ends the loop. BORROWED: the worker thread holds a
    /// reference for as long as the loop exists.
    link: *WorkerLink,
    /// The agent, once the worker thread has made it; the microtask
    /// checkpoint and the engine's posted tasks are its.
    agent: ?*engine.Agent = null,
    /// The agent's deferred teardown queue (its AgentHost's; engine.
    /// AgentOptions.deferred_teardown), set with `agent`: the nodes whose
    /// wrappers the collector took, freed here between tasks, a slice a turn.
    deferred_teardown: ?*runtime.gc.DeferredTeardown = null,
    /// The worker agent's fetches (its AgentHost's), set with `agent`: every
    /// fetch the worker's realm started, pumped here each turn.
    fetches: ?*AgentFetches = null,
    /// The worker's inbox (the link's worker_sink). A reference.
    sink: *runtime.TaskSink,
    timers: *TimerManager,
    /// The clock `timers` reads: the monotonic clock less the time the
    /// worker spent suspended. Its own allocation: the loop is returned by
    /// value, and the timer manager keeps a pointer to it.
    suspend_clock: *SuspendClock,
    /// The task queue. Every task here is the worker's: no document.
    tasks: std.ArrayListUnmanaged(Task) = .empty,
    /// For promise allocation (the interface's promiseAllocator).
    promise_arena: std.heap.ArenaAllocator,
    in_turn: bool = false,
    /// The host microtasks queued in the agent and not yet run (each one's
    /// record is linked here until it runs). The engine drops a microtask it
    /// never runs - a terminated agent's queue is cleared - and frees nothing
    /// of it, so the loop's end frees what is still linked; it ends after
    /// the agent (WorkerThread), when nothing can run them any more.
    microtasks: ?*QueuedMicrotask = null,

    /// The most a turn waits while the engine or the network has work in
    /// flight that will finish without posting to the sink.
    const busy_slice_ns: u64 = 1 * std.time.ns_per_ms;

    pub fn init(allocator: Allocator, link: *WorkerLink) Allocator.Error!WorkerEventLoop {
        const suspend_clock = try allocator.create(SuspendClock);
        errdefer allocator.destroy(suspend_clock);
        suspend_clock.* = .{};
        const timers = TimerManager.initWithClock(allocator, suspend_clock.clock()) catch return error.OutOfMemory;
        return .{
            .allocator = allocator,
            .link = link,
            .sink = link.worker_sink.retain(),
            .timers = timers,
            .suspend_clock = suspend_clock,
            .promise_arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    /// The loop's end, on the worker thread, after the agent's: HTML close()
    /// and "terminate a worker" discard the worker's tasks - each queued task
    /// is told it will never run, the sink closes (dropping what it holds),
    /// the timers end (an owned timer's data dropped), and the records of
    /// microtasks the agent never ran are freed. The promise arena goes last:
    /// a microtask the agent's end ran may have used it.
    pub fn deinit(self: *WorkerEventLoop) void {
        self.dropTasks();
        self.sink.close();
        self.timers.deinit();
        self.allocator.destroy(self.suspend_clock);
        self.tasks.deinit(self.allocator);
        self.sink.release();
        self.freeDroppedMicrotasks();
        self.promise_arena.deinit();
    }

    /// Free the records of host microtasks the agent dropped unrun. Call
    /// once the agent has ended: a record still linked then never runs.
    fn freeDroppedMicrotasks(self: *WorkerEventLoop) void {
        while (self.microtasks) |queued| {
            queued.unlink();
            self.allocator.destroy(queued);
        }
    }

    /// Drop every task queued and every task posted: none will run.
    pub fn dropTasks(self: *WorkerEventLoop) void {
        self.takePosted();
        var tasks = self.tasks;
        self.tasks = .empty;
        for (tasks.items) |task| {
            if (task.drop) |drop| drop(task.context);
        }
        tasks.deinit(self.allocator);
    }

    /// The EventLoop interface the worker's realm records
    /// (WorkerRealmOptions.event_loop).
    pub fn eventLoop(self: *WorkerEventLoop) runtime.EventLoop {
        return .{ .ptr = self, .vtable = &interface_vtable };
    }

    /// The timers the worker's realm schedules on (setTimeout, AbortSignal).
    pub fn timerInterface(self: *WorkerEventLoop) runtime.TimerInterface {
        return self.timers.timerInterface();
    }

    /// The loop `realm` queues on, when it is a worker loop.
    pub fn of(realm: runtime.Context) ?*WorkerEventLoop {
        const loop = realm.getOptionalEventLoop() orelse return null;
        if (loop.vtable != &interface_vtable) return null;
        return @ptrCast(@alignCast(loop.ptr));
    }

    /// Turn until the worker is closing.
    pub fn run(self: *WorkerEventLoop) void {
        while (self.link.runsTasks()) _ = self.turn();
    }

    /// One turn (see the file's header). Whether any work was done.
    pub fn turn(self: *WorkerEventLoop) bool {
        if (self.in_turn) return false;
        self.in_turn = true;
        defer self.in_turn = false;
        var did_work = false;

        // A suspended worker runs nothing until it is resumed or closing.
        if (self.parkWhileSuspended()) did_work = true;
        if (!self.link.runsTasks()) return did_work;

        // 1. What other threads posted joins the task queue.
        self.takePosted();

        // 2. The tasks queued before this turn, each followed by a
        // checkpoint; a task they queue waits for the next turn.
        var budget = self.tasks.items.len;
        while (budget > 0 and self.tasks.items.len > 0) : (budget -= 1) {
            // A closing worker runs nothing more: the rest are discarded at
            // the loop's end.
            if (!self.link.runsTasks()) return true;
            // Suspended meanwhile (a task boundary): the rest wait, and the
            // next turn parks.
            if (self.link.isSuspended()) return true;
            const task = self.tasks.orderedRemove(0);
            task.callback(task.context);
            self.checkpoint();
            did_work = true;
        }
        if (!self.link.runsTasks()) return did_work;
        if (self.link.isSuspended()) return did_work;

        // 3. The engine's own posted tasks.
        if (self.agent) |agent| {
            if (engine.runEngineTasks(agent)) did_work = true;
        }

        // 3b. The collected trees the agent queued for teardown - between
        // tasks, never inside script (runtime.gc.DeferredTeardown).
        // A slice a turn - and past the queue's mark, down to it.
        if (self.deferred_teardown) |queue| {
            if (!queue.isEmpty()) {
                while (true) {
                    _ = queue.runSlice(runtime.gc.DeferredTeardown.slice_budget);
                    if (queue.pendingNodes() <= runtime.gc.DeferredTeardown.loop_low_water) break;
                }
                did_work = true;
            }
        }

        // 4. The worker agent's fetches.
        if (self.fetches) |fetches| {
            if (fetches.pump()) did_work = true;
        }

        // 5. Nothing queued: wait for a post, the next timer, or - with work
        // in flight that will not post - a slice.
        if (self.tasks.items.len == 0) {
            if (self.waitBound()) |bound| {
                if (bound > 0) self.sink.waitForWork(bound);
            } else self.sink.waitForWork(null);
        }

        // 6. The timers that came due - each a task, followed by a
        // checkpoint (HTML 8.1.7.3) - then a checkpoint. Not while the
        // worker is suspended: they come due on its clock, which stands
        // still until it is resumed.
        if (self.link.runsTasks() and !self.link.isSuspended()) {
            if (self.timers.pollEach(.{ .context = self, .run = checkpointAfterTimer })) did_work = true;
            self.checkpoint();
        }
        return did_work;
    }

    /// HTML "run a worker" step 8, *suspending workers*: "whenever worker
    /// global scope's closing flag is false and it is suspendable, the user
    /// agent suspends execution of script in worker global scope until such
    /// time as either the closing flag switches to true or worker global
    /// scope stops being suspendable." At a task boundary - nothing of the
    /// worker's runs while it waits: no task, no timer, no engine task, no
    /// fetch pumped. What other threads post meanwhile joins the task queue
    /// in order, unrun (a lock granted to it, a message: they run once it is
    /// resumed - web-locks: weblocks-worker.https.window.js). Its timers'
    /// clock stops for as long (`SuspendClock`). Whether it parked.
    ///
    /// The wake: WorkerLink.resumeFromSuspension clears the flag before it
    /// posts, and terminate sets the closing flag before it wakes, so a
    /// check that finds the flag still set is followed by a wait that the
    /// post ends (TaskSink.waitForWork returns at once when the post is
    /// already there).
    fn parkWhileSuspended(self: *WorkerEventLoop) bool {
        if (!self.link.isSuspended() or !self.link.runsTasks()) return false;
        self.suspend_clock.stop();
        defer self.suspend_clock.start();
        while (true) {
            if (!self.link.isSuspended() or !self.link.runsTasks()) break;
            self.takePosted();
            if (!self.link.isSuspended() or !self.link.runsTasks()) break;
            self.sink.waitForWork(null);
        }
        return true;
    }

    /// How long a turn may wait (ns): 0 not at all, null with no limit.
    fn waitBound(self: *WorkerEventLoop) ?u64 {
        if (self.sink.hasPosted()) return 0;
        // A tree still waiting for its teardown: the next turn frees more.
        if (self.deferred_teardown) |queue| if (!queue.isEmpty()) return 0;
        var bound: ?u64 = null;
        // To the nanosecond: whole milliseconds, rounded down, read a timer
        // due in under one as "do not wait", and the loop then turned
        // without a wait until it was due (the window's loop did the same:
        // src/browser/event_loop.zig step 4).
        if (self.timers.nextDeadlineNs()) |deadline| {
            const now = self.timers.nowNs();
            bound = if (deadline > now) @intCast(@min(deadline - now, std.math.maxInt(u64))) else 0;
        }
        if (self.agent) |agent| if (engine.nextEngineTaskDelay(agent)) |ns| {
            bound = @min(bound orelse ns, ns);
        };
        const busy = (if (self.fetches) |fetches| fetches.inFlight() > 0 else false) or
            (if (self.agent) |agent| engine.hasPendingEngineWork(agent) else false);
        if (busy) bound = @min(bound orelse busy_slice_ns, busy_slice_ns);
        return bound;
    }

    /// Move what other threads posted to the end of the task queue, in the
    /// order it was posted. A task the queue cannot take is dropped.
    fn takePosted(self: *WorkerEventLoop) void {
        var posted: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
        defer posted.deinit(self.allocator);
        self.sink.takeAll(&posted, self.allocator) catch {
            // Left in the sink for the next turn.
            log.debug("out of memory taking posted tasks", .{});
            return;
        };
        for (posted.items) |item| {
            queueTask(self, .{ .callback = item.run, .context = item.data, .drop = item.drop });
        }
    }

    /// HTML "perform a microtask checkpoint", the worker agent's.
    fn checkpoint(self: *WorkerEventLoop) void {
        const agent = self.agent orelse return;
        engine.performMicrotaskCheckpoint(agent) catch {};
    }

    /// The checkpoint after a timer's task (NativeTimerManager.AfterEach).
    fn checkpointAfterTimer(context: *anyopaque) void {
        const self: *WorkerEventLoop = @ptrCast(@alignCast(context));
        self.checkpoint();
    }

    // ========================================================================
    // The EventLoop interface
    // ========================================================================

    const interface_vtable: runtime.EventLoop.VTable = .{
        .queueMicrotask = queueMicrotask,
        .queueTask = queueTask,
        .runMicrotasks = runMicrotasks,
        .runOnce = runOnce,
        .promiseAllocator = promiseAllocator,
    };

    fn queueMicrotask(ptr: *anyopaque, task: Microtask) void {
        const self: *WorkerEventLoop = @ptrCast(@alignCast(ptr));
        const agent = self.agent orelse {
            log.debug("a microtask queued before the agent exists; dropped", .{});
            return;
        };
        const queued = self.allocator.create(QueuedMicrotask) catch {
            log.debug("out of memory queueing a microtask; dropped", .{});
            return;
        };
        queued.* = .{ .task = task, .allocator = self.allocator, .list = &self.microtasks };
        queued.link();
        engine.queueMicrotask(agent, QueuedMicrotask.run, queued) catch {
            queued.unlink();
            self.allocator.destroy(queued);
            log.debug("a microtask was not queued", .{});
        };
    }

    /// Queue a task; a closing worker's, or one the queue cannot take, is
    /// dropped at once - told it will never run.
    fn queueTask(ptr: *anyopaque, task: Task) void {
        const self: *WorkerEventLoop = @ptrCast(@alignCast(ptr));
        if (!self.link.runsTasks()) {
            if (task.drop) |drop| drop(task.context);
            return;
        }
        self.tasks.append(self.allocator, task) catch {
            if (task.drop) |drop| drop(task.context);
            log.debug("out of memory queueing a task; dropped", .{});
        };
    }

    fn runMicrotasks(ptr: *anyopaque) void {
        const self: *WorkerEventLoop = @ptrCast(@alignCast(ptr));
        self.checkpoint();
    }

    fn runOnce(ptr: *anyopaque) bool {
        const self: *WorkerEventLoop = @ptrCast(@alignCast(ptr));
        return self.turn();
    }

    fn promiseAllocator(ptr: *anyopaque) Allocator {
        const self: *WorkerEventLoop = @ptrCast(@alignCast(ptr));
        return self.promise_arena.allocator();
    }
};

/// The clock a worker's timers read: the platform's monotonic clock less the
/// time the worker has spent suspended, so a timer waits its timeout "with
/// the worker not suspended (not necessarily consecutively)" (HTML timer
/// initialization steps, step 11's worker branch; "run steps after a
/// timeout" for AbortSignal.timeout). While the worker is suspended it
/// stands still. Read and moved only on the worker's thread.
pub const SuspendClock = struct {
    /// The time spent suspended before the current suspension (ns).
    suspended_ns: u64 = 0,
    /// When the current suspension began (the platform clock's ns), while
    /// one lasts.
    stopped_at: ?u64 = null,

    pub fn clock(self: *SuspendClock) runtime.native_timer.Clock {
        return .{ .context = self, .monotonic_now = now };
    }

    /// The worker is suspended from now on.
    pub fn stop(self: *SuspendClock) void {
        if (self.stopped_at == null) self.stopped_at = platformNow();
    }

    /// The worker runs again: the suspension's length no longer counts.
    pub fn start(self: *SuspendClock) void {
        const since = self.stopped_at orelse return;
        self.stopped_at = null;
        self.suspended_ns += platformNow() -| since;
    }

    /// The clock now (ns): stands at the suspension's start while one lasts.
    pub fn read(self: *const SuspendClock) u64 {
        const at = self.stopped_at orelse platformNow();
        return at -| self.suspended_ns;
    }

    fn now(context: ?*anyopaque) callconv(.c) u64 {
        const self: *const SuspendClock = @ptrCast(@alignCast(context.?));
        return self.read();
    }

    fn platformNow() u64 {
        return @import("platform").monotonicNow().ns;
    }
};

/// A host microtask in the agent's queue, until it runs - linked into its
/// loop's list (`WorkerEventLoop.microtasks`), which frees it if the agent
/// ends without running it.
const QueuedMicrotask = struct {
    task: Microtask,
    allocator: Allocator,
    /// The loop's list head. The loop outlives every run: it ends after the
    /// agent.
    list: *?*QueuedMicrotask,
    prev: ?*QueuedMicrotask = null,
    next: ?*QueuedMicrotask = null,

    fn link(self: *QueuedMicrotask) void {
        self.next = self.list.*;
        if (self.next) |next| next.prev = self;
        self.list.* = self;
    }

    fn unlink(self: *QueuedMicrotask) void {
        if (self.prev) |prev| prev.next = self.next else self.list.* = self.next;
        if (self.next) |next| next.prev = self.prev;
        self.prev = null;
        self.next = null;
    }

    fn run(data: ?*anyopaque) void {
        const self: *QueuedMicrotask = @ptrCast(@alignCast(data.?));
        const task = self.task;
        self.unlink();
        self.allocator.destroy(self);
        task.callback(task.context);
    }
};
