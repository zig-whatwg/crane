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
//! ## Tasks from other threads
//!
//! Every worker runs on a thread of its own, and what crosses to this loop -
//! a message a worker posted, a port's "has messages", a worker's end - is
//! posted to the loop's TaskSink. Each turn takes what was posted into the
//! task queue (step 2), where it runs as any other task, followed by a
//! checkpoint. A loop that owns a running worker is not idle: the worker
//! may post at any time (`hasPendingWork`). The wait is sliced at 1 ms
//! (native_timer.zig), so a post is seen within a slice.
//!
//! ## Bfcache support
//!
//! A document the back/forward cache holds has its tasks kept in a group of
//! their own (`suspendDocument`, `resumeDocument`, `discardDocument`: WebKit's
//! EventLoopTaskGroup), so a page cached for minutes costs the drain nothing.
//! freeze() suspends all timer and task processing and thaw() resumes it:
//! while frozen, a turn returns at once and runs nothing (unused).

const std = @import("std");
const Allocator = std.mem.Allocator;
const clock = @import("clock");
const engine = @import("engine");
const runtime = @import("runtime");
const dom = @import("dom");
const idle_periods = dom.idle_periods;
const rendering = @import("rendering.zig");

const TimerManager = runtime.native_timer.NativeTimerManager;
const Task = runtime.EventLoopTask;
const Microtask = runtime.EventLoopMicrotask;

/// An agent's fetches on its event loop (on its host: AgentHost.fetches).
const AgentFetches = @import("fetch").algorithms.AgentFetches;

pub const EventLoop = struct {
    /// The agent whose event loop this is.
    agent: *engine.Agent,

    /// Allocator for the loop's bookkeeping.
    allocator: Allocator,

    /// Arena for promise allocation (owned by this event loop)
    promise_arena: std.heap.ArenaAllocator,

    /// The task queue: the engine has none of its own for the host's tasks.
    /// Its first `waiting` tasks are the ones the last drain left in place
    /// because their documents were not fully active (`drainTasks`).
    tasks: std.ArrayList(Task),

    /// How many tasks at the front of `tasks` the last drain left waiting:
    /// their documents are not fully active, and may be again (HTML 8.1.7.1,
    /// "a task is runnable if its document is either null or fully active").
    /// Exact between drains - nothing but a drain and `deinit` removes from
    /// `tasks`, and queueing appends - so `tasks.len > waiting` is "a
    /// runnable task may be queued" (`runnableQueued`). 0 while a drain runs.
    waiting: usize = 0,

    /// Track if we're inside runOnce to prevent reentrancy
    in_run_once: bool,

    /// The host microtasks queued in the agent and not yet run (each one's
    /// record is linked here until it runs). The loop ends before its agent
    /// (Browser.deinit), whose end still runs what is queued: a record left
    /// at the loop's end is orphaned - it frees itself when the agent runs
    /// it, without its steps, whose context was the loop's promise arena.
    microtasks: ?*QueuedMicrotask = null,

    /// The door other threads post this loop's tasks through (a worker's
    /// messages and its end, a port's "has messages"): taken into `tasks` at
    /// each turn's step 2, closed - what it still holds dropped - when the
    /// loop ends. The loop holds one reference; every poster holds its own.
    sink: *runtime.TaskSink,

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

    /// The agent's deferred teardown queue (the host's AgentHost owns it;
    /// engine.AgentOptions.deferred_teardown): the nodes whose wrappers the
    /// collector took, freed here between tasks, a slice at a time. Null for
    /// a loop whose agent has none.
    deferred_teardown: ?*runtime.gc.DeferredTeardown = null,

    /// The agent's fetches (its host's: AgentHost.fetches), which this loop
    /// pumps each turn - every fetch the agent's realms started, and no
    /// other agent's. Null for a loop whose agent has none.
    fetches: ?*AgentFetches = null,

    /// The documents the back/forward cache holds, each with the tasks that
    /// wait for it (`suspendDocument`), in the order they were suspended.
    suspended: std.ArrayListUnmanaged(SuspendedGroup) = .empty,

    /// The thread the loop runs on - the one that made it.
    owner_thread: std.Thread.Id,

    /// The window event loop's rendering opportunities: the frame clock, the
    /// documents' maps of animation frame callbacks and "update the
    /// rendering" (rendering.zig). Its timer is one of this loop's.
    frames: rendering.Frames,

    const Self = @This();

    /// Default maximum wait time when no explicit timeout is provided.
    /// This allows the event loop to block efficiently while still being responsive.
    const DEFAULT_MAX_WAIT_MS: u64 = 100;

    /// A new event loop for `agent`, with its timers.
    pub fn init(agent: *engine.Agent, allocator: Allocator) !Self {
        const timer_mgr = try TimerManager.init(allocator);
        errdefer timer_mgr.deinit();
        const sink = try runtime.TaskSink.create(allocator);
        errdefer sink.release();

        return .{
            .agent = agent,
            .allocator = allocator,
            .promise_arena = std.heap.ArenaAllocator.init(allocator),
            .tasks = .empty,
            .in_run_once = false,
            .sink = sink,
            .timer_manager = timer_mgr,
            .frozen = false,
            .owner_thread = std.Thread.getCurrentId(),
            .frames = rendering.Frames.init(allocator, monotonicNs()),
        };
    }

    /// Free all resources: the timers (every pending one cancelled, an owned
    /// one's data dropped), the tasks still queued and the ones other threads
    /// posted (each told it will never run), the promise arena. Microtasks
    /// still in the agent's queue are the engine's.
    pub fn deinit(self: *Self) void {
        if (self.timer_manager) |mgr| mgr.deinit();
        // What the page's end left in the maps of animation frame callbacks
        // (nothing, normally: Context.deinit ends the page first) is
        // released while the agent lives.
        self.frames.deinit();
        // Other threads post nothing more; what they posted is dropped.
        self.sink.close();
        // A task still queued will never run: let it free what it carries.
        for (self.tasks.items) |task| {
            if (task.drop) |drop| drop(task.context);
        }
        self.tasks.deinit(self.allocator);
        // So does one waiting for a document the cache still holds (the
        // cache empties itself before the loop ends; this is the net).
        for (self.suspended.items) |*group| {
            for (group.tasks.items) |task| {
                if (task.drop) |drop| drop(task.context);
            }
            group.tasks.deinit(self.allocator);
        }
        self.suspended.deinit(self.allocator);
        // A poster still holding the sink finds it closed.
        self.sink.release();
        // A window still waiting for an idle period is told nothing: its
        // idle callbacks went with its document (Window's unloading cleanup
        // step), and a request holds no data of its own.
        self.idle_requests.deinit(self.allocator);
        // Microtasks the agent has not run: orphaned. Their contexts are the
        // promise arena's, which goes next, so their steps never run; each
        // record frees itself when the agent's end runs it.
        while (self.microtasks) |queued| {
            queued.unlink();
            queued.orphaned = true;
        }
        self.promise_arena.deinit();
    }

    /// The sink other threads post this loop's tasks to. BORROWED: a holder
    /// that keeps it past the call takes a reference (`retain`).
    pub fn taskSink(self: *Self) *runtime.TaskSink {
        return self.sink;
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
    // Suspended documents (the back/forward cache)
    // ========================================================================

    //
    // A document the back/forward cache holds is not fully active for
    // minutes, and its tasks wait for it ("the first runnable task in
    // taskQueue"). Left in the queue, as the transient inactive documents'
    // tasks are, every drain would classify them again. WebKit's task groups
    // (WebCore/dom/EventLoop.cpp EventLoopTaskGroup::suspend, resume and
    // stopAndDiscardAllTasks) give each document's tasks a place of their
    // own; so does this:
    //
    // - `suspendDocument` makes the document's group. It moves nothing: it
    //   runs inside a task the drain is running, and the drain must be the
    //   only thing that removes from the queue while it walks it. The drain
    //   moves each task it classifies inactive that belongs to a group, in
    //   queue order; fully active and gone tasks are handled exactly as
    //   before, so the hot path is unchanged.
    // - `resumeDocument` marks the group; the next drain, before it takes
    //   its budget, puts the group's tasks back at the front of the queue.
    // - `discardDocument` drops the group's tasks unrun.
    //
    // All three run on the loop's own thread (asserted). Another thread's
    // post for a cached document arrives through the sink, joins the queue
    // at a turn's step 2 and reaches the group through a drain like any
    // other task.

    /// The back/forward cache keeps `document` - its Window `window`, for the
    /// global tasks that name the Window (runtime.EventLoopTask.document) -
    /// each with the slab generation it has now: its tasks wait in a group of
    /// their own until `resumeDocument` or `discardDocument`. Suspending a
    /// document whose group is still waiting to be put back keeps the group.
    /// On out of memory nothing changes: its tasks wait in the queue, as any
    /// inactive document's do.
    pub fn suspendDocument(self: *Self, document: *anyopaque, document_generation: u64, window: ?*anyopaque, window_generation: u64) error{OutOfMemory}!void {
        self.assertOwnThread();
        if (self.groupIndexOf(document, document_generation)) |index| {
            self.suspended.items[index].resumed = false;
            return;
        }
        try self.suspended.append(self.allocator, .{
            .document = document,
            .document_generation = document_generation,
            .window = window,
            .window_generation = window_generation,
        });
    }

    /// `document` is fully active again (HTML "reactivate"): the tasks of its
    /// group run first at the next drain - never in the middle of one, whose
    /// walk of the queue they would shift - ahead of every task queued since.
    /// Nothing for a document with no group.
    pub fn resumeDocument(self: *Self, document: *anyopaque, document_generation: u64) void {
        self.assertOwnThread();
        const index = self.groupIndexOf(document, document_generation) orelse return;
        self.suspended.items[index].resumed = true;
    }

    /// `document` leaves the cache to be destroyed (HTML "destroy a document"
    /// step 5: "remove any tasks whose document is document from any task
    /// queue (without running those tasks)"): its group goes, and each task's
    /// `drop` frees what it carries. A `drop` never runs script or a
    /// callback - it frees memory - so this is safe wherever eviction runs,
    /// which is itself a task (src/browser/back_forward_cache.zig), never
    /// inside the collector. Nothing for a document with no group.
    pub fn discardDocument(self: *Self, document: *anyopaque, document_generation: u64) void {
        self.assertOwnThread();
        const index = self.groupIndexOf(document, document_generation) orelse return;
        var group = self.suspended.orderedRemove(index);
        for (group.tasks.items) |task| {
            if (task.drop) |drop| drop(task.context);
        }
        group.tasks.deinit(self.allocator);
    }

    /// The group of `document` as suspended with that generation.
    ///
    /// A linear scan: there is a group per document the Browser's
    /// back/forward cache holds - BrowserConfig.back_forward_cache_size of
    /// them, 2 by default and rarely more - and it runs only for a task the
    /// drain found inactive, never for a runnable one. A Browser configured
    /// with a large cache pays a scan of that many per waiting task, which is
    /// still far less than classifying each waiting task again every drain.
    fn groupIndexOf(self: *const Self, document: *anyopaque, document_generation: u64) ?usize {
        for (self.suspended.items, 0..) |group, index| {
            if (group.document == document and group.document_generation == document_generation) return index;
        }
        return null;
    }

    /// The group `task` belongs to: its document's, or its document's
    /// window's for a global task that names the Window - each matched with
    /// the generation it was queued with, so a task of a document freed and
    /// made again in the same slot is never taken for the cached one's. A
    /// group waiting to be put back takes no more: its document is fully
    /// active, and a task classified inactive is not its.
    noinline fn groupOf(self: *Self, task: Task) ?*SuspendedGroup {
        const document = task.document orelse return null;
        for (self.suspended.items) |*group| {
            if (group.resumed) continue;
            if (group.document == document and group.document_generation == task.document_generation) return group;
            if (group.window) |window| {
                if (window == document and group.window_generation == task.document_generation) return group;
            }
        }
        return null;
    }

    /// Put the resumed groups' tasks back at the front of the queue, in the
    /// order the groups were suspended, each group's in the order its tasks
    /// were queued, and let the groups go. Only between drains (`drainTasks`
    /// calls it before it takes its budget).
    ///
    /// Stated reorder: a task queued for the document WHILE it was cached is
    /// in its group too, so it now runs ahead of another document's task
    /// queued earlier during that time. Only the page that replaced the
    /// cached one can have such a task, and a restore is unloading that page
    /// - its tasks are inactive or gone - so nothing observes the order.
    noinline fn spliceResumed(self: *Self) void {
        var count: usize = 0;
        for (self.suspended.items) |group| {
            if (group.resumed) count += group.tasks.items.len;
        }
        // A group with no tasks goes all the same.
        var back: std.ArrayListUnmanaged(Task) = .empty;
        defer back.deinit(self.allocator);
        if (count > 0) {
            back.ensureTotalCapacityPrecise(self.allocator, count) catch return;
            self.tasks.ensureUnusedCapacity(self.allocator, count) catch return;
        }
        var index: usize = 0;
        while (index < self.suspended.items.len) {
            if (!self.suspended.items[index].resumed) {
                index += 1;
                continue;
            }
            var group = self.suspended.orderedRemove(index);
            back.appendSliceAssumeCapacity(group.tasks.items);
            group.tasks.deinit(self.allocator);
        }
        if (back.items.len > 0) self.tasks.insertSliceAssumeCapacity(0, back.items);
    }

    /// Whether a resumed group waits to be put back: runnable work.
    noinline fn resumedPending(self: *const Self) bool {
        for (self.suspended.items) |group| {
            if (group.resumed) return true;
        }
        return false;
    }

    /// The loop's suspend, resume and discard steps run on its own thread:
    /// its queue and groups are not locked.
    fn assertOwnThread(self: *const Self) void {
        if (std.debug.runtime_safety) std.debug.assert(std.Thread.getCurrentId() == self.owner_thread);
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

        // Step 2: the tasks queued before this turn began - with the ones
        // other threads posted, taken into the queue now.
        self.takePosted();
        if (self.runQueuedTasks()) did_work = true;

        // Step 2b: the tasks the engine has posted for itself (a bounded
        // batch, each followed by a microtask checkpoint, since it may have
        // settled a promise - d8's ProcessMessages does the same).
        if (engine.runEngineTasks(self.agent)) did_work = true;

        // Step 2b': the collected trees the agent queued for teardown -
        // between tasks, never inside script (runtime.gc.DeferredTeardown).
        if (self.runDeferredTeardown()) did_work = true;

        // Step 2c: move the fetches in flight along. A fetch that ended
        // queues its task for the next turn. The wait below is sliced at 1ms
        // (native_timer.zig), and a fetch in flight is pending work, so the
        // loop never sleeps through a response.
        if (self.fetches) |fetches| {
            if (fetches.pump()) did_work = true;
        }

        const now = monotonicNs();
        self.noteWork(work_start, now);

        // Step 2d (HTML 8.1.7.3 step 5): no runnable task, so an idle period
        // for the same-loop windows that asked for one. Each queues its
        // "invoke idle callbacks" task, which the next turn runs.
        if (self.startIdlePeriod(now)) did_work = true;

        // Step 3: how long to wait - until the next timer or max_wait_ms.
        const wait_time = blk: {
            // A task left for the next turn is work waiting now: poll, but
            // do not block. So is one another thread posted meanwhile, and a
            // tree still waiting for its teardown.
            if (self.runnableQueued() or self.sink.hasPosted() or self.deferredPending()) break :blk 0;
            var wait = max_wait_ms;
            if (self.timer_manager) |mgr| {
                if (mgr.getNextTimerDeadline()) |deadline| wait = @min(deadline, wait);
            }
            // A window waiting for an idle period: wake when one can start.
            if (self.idleWaitMs(now)) |idle_wait| wait = @min(idle_wait, wait);
            break :blk wait;
        };

        // Step 3b: what other threads - or this one's channels - posted while
        // this turn ran: a port's message posted by a task above runs before
        // the timers that task armed, as it did when a port's delivery was a
        // 0 ms timer armed at the post, and as browsers deliver a port's
        // message ahead of a setTimeout(0) (one batch: what these post waits
        // for the next turn).
        if (self.runPosted()) did_work = true;

        // Step 4: wait for a timer or I/O, and run the timer callbacks -
        // each a task, followed by a microtask checkpoint (HTML 8.1.7.3).
        if (self.timer_manager) |mgr| {
            const poll_start = monotonicNs();
            if (mgr.pollBlockingEach(wait_time, .{ .context = self, .run = checkpointAfterTimer })) did_work = true;
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

    /// Move what other threads posted to the end of the task queue, in the
    /// order it was posted: each runs as a task of this loop. A task the
    /// queue cannot take is dropped.
    fn takePosted(self: *Self) void {
        var posted: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
        defer posted.deinit(self.allocator);
        self.sink.takeAll(&posted, self.allocator) catch {
            // Left in the sink for the next turn.
            std.log.err("event loop: out of memory taking posted tasks", .{});
            return;
        };
        for (posted.items) |item| {
            queueTask(self, .{ .callback = item.run, .context = item.data, .drop = item.drop });
        }
    }

    /// Run what other threads posted so far - a snapshot: what these tasks
    /// post waits - each followed by a checkpoint. Whether any ran.
    fn runPosted(self: *Self) bool {
        var posted: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
        defer posted.deinit(self.allocator);
        self.sink.takeAll(&posted, self.allocator) catch return false;
        for (posted.items) |task| {
            task.run(task.data);
            self.checkpoint();
        }
        return posted.items.len > 0;
    }

    /// How long one turn frees collected trees at most, past its first slice:
    /// a task that arrives meanwhile waits at most a slice, a timer due
    /// meanwhile at most this - the order of a frame's idle work.
    const deferred_teardown_turn_ns: i64 = 4 * std.time.ns_per_ms;

    /// The agent's deferred teardown, between tasks: a slice, and more while
    /// no task waits and the turn's share lasts - and, past the queue's
    /// `loop_low_water`, down to it whatever waits. Whether any ran.
    fn runDeferredTeardown(self: *Self) bool {
        const DeferredTeardown = runtime.gc.DeferredTeardown;
        const queue = self.deferred_teardown orelse return false;
        if (queue.isEmpty()) return false;
        const start = monotonicNs();
        while (true) {
            _ = queue.runSlice(DeferredTeardown.slice_budget);
            if (queue.isEmpty()) break;
            if (queue.pendingNodes() > DeferredTeardown.loop_low_water) continue;
            if (self.runnableQueued() or self.sink.hasPosted()) break;
            if (monotonicNs() - start >= deferred_teardown_turn_ns) break;
        }
        return true;
    }

    fn deferredPending(self: *const Self) bool {
        const queue = self.deferred_teardown orelse return false;
        return !queue.isEmpty();
    }

    /// HTML "perform a microtask checkpoint", the agent's.
    fn checkpoint(self: *Self) void {
        engine.performMicrotaskCheckpoint(self.agent) catch {};
    }

    /// The checkpoint after a timer's task (NativeTimerManager.AfterEach).
    fn checkpointAfterTimer(context: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(context));
        self.checkpoint();
    }

    /// Run the tasks queued so far, each followed by a microtask checkpoint
    /// (it may have resolved promises). A task they queue waits for the next
    /// turn, as HTML's event loop runs one task per iteration: draining until
    /// the queue was empty let a task that queues a task keep a turn from
    /// ever returning, and with it the deadline its caller checks between
    /// turns. Whether any task ran, or was dropped.
    fn runQueuedTasks(self: *Self) bool {
        return self.drainTasks(classifyTask, checkpointAfterTask);
    }

    /// How a drain classifies a task's document: dom.document_activity's
    /// answer, or a test's.
    const Classify = *const fn (task: Task) dom.document_activity.Activity;

    /// What a drain does after each task it runs: the microtask checkpoint,
    /// or a test's nothing.
    const AfterTask = *const fn (self: *Self) void;

    /// The drain, step 2: each task queued before it began, from the front,
    /// classified by its document (HTML 8.1.7.3 step 2.3, "the first runnable
    /// task in taskQueue"):
    ///
    /// - fully active, or no document: removed and run, then `after`;
    /// - inactive - not fully active, and it may be again: LEFT IN PLACE,
    ///   ahead of every task queued after it, to run once its document is
    ///   fully active again (a task queue is a set, not a queue, for exactly
    ///   this: "grabs the first runnable task ... instead of dequeuing the
    ///   first task");
    /// - gone - it can never be fully active again: removed without running,
    ///   its `drop` freeing what it carries ("destroy a document" step 5
    ///   removes its tasks; here at the first drain after, as before).
    ///
    /// An inactive task of a document the back/forward cache holds goes to
    /// that document's group instead (`suspendDocument`), and a resumed
    /// group's tasks are put back at the front before the drain begins.
    ///
    /// The other waiting tasks - transient: a document not fully active for
    /// the length of a navigation - end up a prefix of the queue, `waiting`
    /// long; every drain classifies them again (O(waiting)). WebKit's EventLoop::run does
    /// the same: a suspended group's tasks are put back, in order, ahead of
    /// those queued meanwhile, a stopped group's are discarded
    /// (WebCore/dom/EventLoop.cpp). Whether any task ran or was dropped.
    fn drainTasks(self: *Self, classify: Classify, after: AfterTask) bool {
        // The tasks of documents a restore made fully active again come
        // first: they were queued before anything queued while they waited.
        if (self.suspended.items.len != 0) self.spliceResumed();
        var budget = self.tasks.items.len;
        // Until this drain is done, any queued task may be runnable.
        self.waiting = 0;
        var index: usize = 0;
        var progressed = false;
        // Tasks the ones run here queue are appended: the budget never
        // reaches them, and nothing else removes from the queue, so
        // `index` is always at a task queued before the drain.
        while (budget > 0 and index < self.tasks.items.len) : (budget -= 1) {
            const task = self.tasks.items[index];
            switch (classify(task)) {
                .inactive => {
                    // A document the back/forward cache holds: into its
                    // group, in queue order. `index` stays: the next task
                    // has moved into this slot.
                    if (self.suspended.items.len != 0) {
                        if (self.groupOf(task)) |group| {
                            if (group.tasks.ensureUnusedCapacity(self.allocator, 1)) {
                                _ = self.tasks.orderedRemove(index);
                                group.tasks.appendAssumeCapacity(task);
                                continue;
                            } else |_| {}
                        }
                    }
                    // Left where it is: the next drain asks again.
                    index += 1;
                },
                .gone => {
                    _ = self.tasks.orderedRemove(index);
                    if (task.drop) |drop| drop(task.context);
                    progressed = true;
                },
                .fully_active => {
                    _ = self.tasks.orderedRemove(index);
                    task.callback(task.context);
                    after(self);
                    progressed = true;
                },
            }
        }
        self.waiting = index;
        return progressed;
    }

    /// HTML 8.1.7.1: "A task is runnable if its document is either null or
    /// fully active" - and when it is not, whether it may be again.
    fn classifyTask(task: Task) dom.document_activity.Activity {
        const document = task.document orelse return .fully_active;
        return dom.document_activity.activity(document, task.document_generation);
    }

    fn checkpointAfterTask(self: *Self) void {
        self.checkpoint();
    }

    /// Whether a task that may be runnable is queued: one the last drain did
    /// not leave waiting, or any while a drain runs - or a resumed document's
    /// group, which the next drain puts back. A suspended group is not.
    fn runnableQueued(self: *const Self) bool {
        return self.tasks.items.len > self.waiting or (self.suspended.items.len != 0 and self.resumedPending());
    }

    /// Whether there is pending work that should keep the loop from idling.
    pub fn hasPendingWork(self: *Self) bool {
        // A task waiting for its document to be fully active again is not
        // work: only a task of this loop can make it so (reactivation), and
        // that task is work of its own (WebKit's
        // EventLoop::hasTasksForFullyActiveDocument).
        if (self.runnableQueued()) return true;
        // Collected trees waiting for their teardown.
        if (self.deferredPending()) return true;
        // Posted by another thread, and not taken yet.
        if (self.sink.hasPosted()) return true;
        // A worker this loop owns is running: it may post at any time.
        if (self.sink.sourceCount() > 0) return true;
        // A window waiting for an idle period: one will start - unless it is
        // a page the back/forward cache keeps.
        if (self.idleRequestsRunnable()) return true;
        // A fetch in flight will queue a task when it ends.
        if (self.fetches) |fetches| if (fetches.inFlight() > 0) return true;
        if (self.timer_manager) |mgr| {
            if (mgr.getActiveTimerCount() > 0) return true;
        }
        return false;
    }

    // ========================================================================
    // Idle periods (HTML 8.1.7.3 step 5; requestIdleCallback)
    // ========================================================================
    //
    // Crane renders nothing, but its rendering opportunities are real: the
    // frame clock (rendering.zig) arms one timer of this loop for the next
    // refresh moment while any window has animation frame callbacks or asked
    // for a frame - computeDeadline's "hasPendingRenders" - and none
    // otherwise. So the loop's timers bound a deadline exactly as
    // computeDeadline step 4's nextRenderDeadline does (WebKit's
    // computeIdleDeadline: the next timer and the next scheduled rendering
    // update). Every timer counts, not only the windows' maps of active
    // timers: the engine's own and idle callbacks' timeouts make deadlines
    // earlier, which a user agent may always do ("The user agent is free to
    // end an idle period early").

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
        if (!self.idleRequestsRunnable()) return false;
        // A runnable task: not idle. Tasks waiting for their documents are
        // not runnable ("has no runnable task").
        if (self.runnableQueued()) return false;
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
        for (requests.items) |request| {
            // A cached page's window keeps asking: its idle callbacks run in
            // an idle period after its restore, not into a page that cannot
            // run script (its "invoke idle callbacks" task names no document).
            if (self.idleRequestSuspended(request)) {
                self.idle_requests.append(self.allocator, request) catch {};
                continue;
            }
            request.start(request.realm, period);
        }
        return true;
    }

    /// Whether a window that asked for an idle period may get one: any that
    /// is not a page the back/forward cache keeps.
    fn idleRequestsRunnable(self: *const Self) bool {
        for (self.idle_requests.items) |request| {
            if (!self.idleRequestSuspended(request)) return true;
        }
        return false;
    }

    /// Whether `request` is of a window whose document this loop holds
    /// suspended (`suspendDocument`): only read while a group exists.
    fn idleRequestSuspended(self: *const Self, request: IdleRequest) bool {
        if (self.suspended.items.len == 0) return false;
        if (!request.realm.hasEngine()) return false;
        const record = request.realm.getRealm() orelse return false;
        const global = record.global_object orelse return false;
        for (self.suspended.items) |group| {
            if (group.resumed) continue;
            if (group.window) |window| {
                // The same address, and still that Window (lane winslot1,
                // kind 9): a kept page's Window whose slot went back and was
                // issued again is another window.
                if (window == @as(*anyopaque, @ptrCast(global)) and
                    runtime.SlabAllocator.generationOf(@ptrCast(@alignCast(global))) == group.window_generation) return true;
            }
        }
        return false;
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
        if (!self.idleRequestsRunnable()) return null;
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
        queued.* = .{ .task = task, .allocator = self.allocator, .list = &self.microtasks };
        queued.link();
        engine.queueMicrotask(self.agent, QueuedMicrotask.run, queued) catch |err| {
            queued.unlink();
            self.allocator.destroy(queued);
            std.log.err("event loop: a microtask was not queued: {}", .{err});
        };
    }

    fn queueTask(ptr: *anyopaque, task: Task) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        // A task with a document may be dropped without running (drainTasks):
        // it must be able to free what it carries.
        std.debug.assert(task.document == null or task.drop != null);
        self.tasks.append(self.allocator, task) catch {
            // The interface cannot fail, so the task is dropped - and a task
            // that will never run frees what it carries, as at the loop's end:
            // a client counting its outstanding tasks hears of this one too.
            if (task.drop) |drop| drop(task.context);
            std.log.debug("event loop: out of memory queueing a task; dropped", .{});
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

/// The tasks of a document the back/forward cache holds.
const SuspendedGroup = struct {
    document: *anyopaque,
    document_generation: u64,
    window: ?*anyopaque,
    window_generation: u64,
    tasks: std.ArrayListUnmanaged(Task) = .empty,
    resumed: bool = false,
};

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
    /// The loop's list head (`EventLoop.microtasks`), while the loop lives.
    list: *?*QueuedMicrotask,
    prev: ?*QueuedMicrotask = null,
    next: ?*QueuedMicrotask = null,
    /// The loop has ended: free this when it runs, and run nothing.
    orphaned: bool = false,

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
        const orphaned = self.orphaned;
        if (!orphaned) self.unlink();
        self.allocator.destroy(self);
        if (orphaned) return;
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
    try testing.expectEqual(dom.document_activity.Activity.fully_active, EventLoop.classifyTask(.{ .callback = &noop, .context = null }));
}

/// What a test task carries: whether it ran or was dropped.
const Tally = struct {
    ran: u32 = 0,
    dropped: u32 = 0,

    fn run(data: ?*anyopaque) void {
        const self: *Tally = @ptrCast(@alignCast(data.?));
        self.ran += 1;
    }

    fn drop(data: ?*anyopaque) void {
        const self: *Tally = @ptrCast(@alignCast(data.?));
        self.dropped += 1;
    }
};

test "a task the queue cannot take is dropped, not leaked" {
    var failing = testing.FailingAllocator.init(testing.allocator, .{});
    var loop = try EventLoop.init(@ptrFromInt(@alignOf(usize)), failing.allocator());
    defer loop.deinit();
    var tally: Tally = .{};
    // The next allocation - the queue's growth - fails.
    failing.fail_index = failing.alloc_index;
    loop.eventLoop().queueTask(.{ .callback = &Tally.run, .context = &tally, .drop = &Tally.drop });
    try testing.expectEqual(@as(usize, 0), loop.tasks.items.len);
    try testing.expectEqual(@as(u32, 1), tally.dropped);
    try testing.expectEqual(@as(u32, 0), tally.ran);
}

/// A task's document, as the drain tests classify it: its activity is
/// whatever the test sets.
const TestDocument = struct {
    activity: dom.document_activity.Activity = .fully_active,

    fn classify(task: Task) dom.document_activity.Activity {
        const document: *TestDocument = @ptrCast(@alignCast(task.document orelse return .fully_active));
        return document.activity;
    }
};

/// The drain tests run no agent: nothing after each task.
fn noCheckpoint(_: *EventLoop) void {}

/// A test task that records the order tasks ran in.
const Ordered = struct {
    log: *std.ArrayListUnmanaged(u8),
    name: u8,
    dropped: bool = false,
    /// A task this one queues when it runs.
    queues: ?*Ordered = null,
    loop: ?*EventLoop = null,

    fn run(data: ?*anyopaque) void {
        const self: *Ordered = @ptrCast(@alignCast(data.?));
        self.log.append(testing.allocator, self.name) catch {};
        if (self.queues) |next| self.loop.?.eventLoop().queueTask(next.task(null));
    }

    fn drop(data: ?*anyopaque) void {
        const self: *Ordered = @ptrCast(@alignCast(data.?));
        self.dropped = true;
    }

    fn task(self: *Ordered, document: ?*TestDocument) Task {
        return .{ .callback = &run, .context = self, .drop = &drop, .document = document, .document_generation = 0 };
    }
};

test "a task whose document is not fully active stays queued, in place, and is not work waiting" {
    var loop = try testLoop();
    defer loop.deinit();
    var log: std.ArrayListUnmanaged(u8) = .empty;
    defer log.deinit(testing.allocator);
    var first: TestDocument = .{ .activity = .inactive };
    var second: TestDocument = .{ .activity = .inactive };
    var a: Ordered = .{ .log = &log, .name = 'a' };
    var b: Ordered = .{ .log = &log, .name = 'b' };
    var c: Ordered = .{ .log = &log, .name = 'c' };
    const queue = loop.eventLoop();
    queue.queueTask(a.task(&first));
    queue.queueTask(b.task(null));
    queue.queueTask(c.task(&second));

    try testing.expect(loop.drainTasks(TestDocument.classify, noCheckpoint));
    try testing.expectEqualStrings("b", log.items);
    // Neither run nor dropped: still queued, in their order, at the front.
    try testing.expect(!a.dropped and !c.dropped);
    try testing.expectEqual(@as(usize, 2), loop.tasks.items.len);
    try testing.expectEqual(@as(?*anyopaque, &a), loop.tasks.items[0].context);
    try testing.expectEqual(@as(?*anyopaque, &c), loop.tasks.items[1].context);
    try testing.expectEqual(@as(usize, 2), loop.waiting);
    // Not work: the loop may idle, and wait, with them queued.
    try testing.expect(!loop.runnableQueued());
    try testing.expect(!loop.hasPendingWork());
    // A drain that finds only waiting tasks did nothing.
    try testing.expect(!loop.drainTasks(TestDocument.classify, noCheckpoint));
    try testing.expectEqualStrings("b", log.items);
}

test "a waiting task runs once its document is fully active again, before the tasks queued after it" {
    var loop = try testLoop();
    defer loop.deinit();
    var log: std.ArrayListUnmanaged(u8) = .empty;
    defer log.deinit(testing.allocator);
    var document: TestDocument = .{ .activity = .inactive };
    var a: Ordered = .{ .log = &log, .name = 'a' };
    var d: Ordered = .{ .log = &log, .name = 'd' };
    const queue = loop.eventLoop();
    queue.queueTask(a.task(&document));
    _ = loop.drainTasks(TestDocument.classify, noCheckpoint);
    try testing.expectEqual(@as(usize, 1), loop.waiting);

    // Queued after it: work again.
    queue.queueTask(d.task(null));
    try testing.expect(loop.hasPendingWork());
    document.activity = .fully_active;
    try testing.expect(loop.drainTasks(TestDocument.classify, noCheckpoint));
    try testing.expectEqualStrings("ad", log.items);
    try testing.expectEqual(@as(usize, 0), loop.tasks.items.len);
    try testing.expectEqual(@as(usize, 0), loop.waiting);
}

test "a waiting task whose document is gone is dropped without running" {
    var loop = try testLoop();
    defer loop.deinit();
    var log: std.ArrayListUnmanaged(u8) = .empty;
    defer log.deinit(testing.allocator);
    var document: TestDocument = .{ .activity = .inactive };
    var a: Ordered = .{ .log = &log, .name = 'a' };
    loop.eventLoop().queueTask(a.task(&document));
    _ = loop.drainTasks(TestDocument.classify, noCheckpoint);
    try testing.expect(!a.dropped);

    // Destroyed: "remove any tasks whose document is document".
    document.activity = .gone;
    try testing.expect(loop.drainTasks(TestDocument.classify, noCheckpoint));
    try testing.expect(a.dropped);
    try testing.expectEqualStrings("", log.items);
    try testing.expectEqual(@as(usize, 0), loop.tasks.items.len);
    try testing.expectEqual(@as(usize, 0), loop.waiting);
}

test "a task whose document is gone is dropped at once, and one with none runs" {
    var loop = try testLoop();
    defer loop.deinit();
    var log: std.ArrayListUnmanaged(u8) = .empty;
    defer log.deinit(testing.allocator);
    var gone: TestDocument = .{ .activity = .gone };
    var a: Ordered = .{ .log = &log, .name = 'a' };
    var b: Ordered = .{ .log = &log, .name = 'b' };
    loop.eventLoop().queueTask(a.task(&gone));
    loop.eventLoop().queueTask(b.task(null));
    try testing.expect(loop.drainTasks(TestDocument.classify, noCheckpoint));
    try testing.expect(a.dropped);
    try testing.expectEqualStrings("b", log.items);
    try testing.expectEqual(@as(usize, 0), loop.tasks.items.len);
}

test "a task queued while waiting tasks are passed over waits for the next drain, behind them" {
    var loop = try testLoop();
    defer loop.deinit();
    var log: std.ArrayListUnmanaged(u8) = .empty;
    defer log.deinit(testing.allocator);
    var document: TestDocument = .{ .activity = .inactive };
    var a: Ordered = .{ .log = &log, .name = 'a' };
    var e: Ordered = .{ .log = &log, .name = 'e' };
    var b: Ordered = .{ .log = &log, .name = 'b', .queues = &e, .loop = &loop };
    const queue = loop.eventLoop();
    queue.queueTask(a.task(&document));
    queue.queueTask(b.task(null));
    _ = loop.drainTasks(TestDocument.classify, noCheckpoint);
    // b ran and queued e; e waits for the next turn, behind a.
    try testing.expectEqualStrings("b", log.items);
    try testing.expectEqual(@as(usize, 1), loop.waiting);
    try testing.expectEqual(@as(usize, 2), loop.tasks.items.len);
    try testing.expectEqual(@as(?*anyopaque, &e), loop.tasks.items[1].context);
    try testing.expect(loop.hasPendingWork());
    _ = loop.drainTasks(TestDocument.classify, noCheckpoint);
    try testing.expectEqualStrings("be", log.items);
    try testing.expectEqual(@as(usize, 1), loop.waiting);
}

test "the loop's end drops a waiting task" {
    var log: std.ArrayListUnmanaged(u8) = .empty;
    defer log.deinit(testing.allocator);
    var document: TestDocument = .{ .activity = .inactive };
    var a: Ordered = .{ .log = &log, .name = 'a' };
    {
        var loop = try testLoop();
        defer loop.deinit();
        loop.eventLoop().queueTask(a.task(&document));
        _ = loop.drainTasks(TestDocument.classify, noCheckpoint);
        try testing.expect(!a.dropped);
    }
    try testing.expect(a.dropped);
    try testing.expectEqualStrings("", log.items);
}

// ----------------------------------------------------------------------------
// Suspended documents (the back/forward cache): a cached document's tasks
// wait in a group of their own, not in the queue every drain walks.
// ----------------------------------------------------------------------------

/// Queue `tasks` in order.
fn queueAll(loop: *EventLoop, tasks: []const Task) void {
    for (tasks) |task| loop.eventLoop().queueTask(task);
}

test "a suspended document's tasks move to its group in order, consecutive ones included, and active ones run" {
    var loop = try testLoop();
    defer loop.deinit();
    var log: std.ArrayListUnmanaged(u8) = .empty;
    defer log.deinit(testing.allocator);
    var cached: TestDocument = .{ .activity = .inactive };
    var a1: Ordered = .{ .log = &log, .name = '1' };
    var x: Ordered = .{ .log = &log, .name = 'x' };
    var a2: Ordered = .{ .log = &log, .name = '2' };
    var a3: Ordered = .{ .log = &log, .name = '3' };
    var a4: Ordered = .{ .log = &log, .name = '4' };
    var y: Ordered = .{ .log = &log, .name = 'y' };
    var a5: Ordered = .{ .log = &log, .name = '5' };
    queueAll(&loop, &.{ a1.task(&cached), x.task(null), a2.task(&cached), a3.task(&cached), a4.task(&cached), y.task(null), a5.task(&cached) });
    try loop.suspendDocument(&cached, 0, null, 0);

    try testing.expect(loop.drainTasks(TestDocument.classify, noCheckpoint));
    try testing.expectEqualStrings("xy", log.items);
    // Out of the queue every drain walks: nothing waits there.
    try testing.expectEqual(@as(usize, 0), loop.tasks.items.len);
    try testing.expectEqual(@as(usize, 0), loop.waiting);
    // All five in the group, in the order they were queued, none dropped.
    try testing.expectEqual(@as(usize, 1), loop.suspended.items.len);
    const group = loop.suspended.items[0].tasks.items;
    try testing.expectEqual(@as(usize, 5), group.len);
    for (group, [_]*Ordered{ &a1, &a2, &a3, &a4, &a5 }) |task, expected| {
        try testing.expectEqual(@as(?*anyopaque, expected), task.context);
    }
    for ([_]*Ordered{ &a1, &a2, &a3, &a4, &a5 }) |task| try testing.expect(!task.dropped);
    // A suspended group is not work: the loop may wait and idle.
    try testing.expect(!loop.runnableQueued());
    try testing.expect(!loop.hasPendingWork());
}

test "a task naming the suspended document's window joins its group" {
    var loop = try testLoop();
    defer loop.deinit();
    var log: std.ArrayListUnmanaged(u8) = .empty;
    defer log.deinit(testing.allocator);
    var cached: TestDocument = .{ .activity = .inactive };
    var window: TestDocument = .{ .activity = .inactive };
    var a: Ordered = .{ .log = &log, .name = 'a' };
    var w: Ordered = .{ .log = &log, .name = 'w' };
    queueAll(&loop, &.{ a.task(&cached), w.task(&window) });
    try loop.suspendDocument(&cached, 0, &window, 0);
    _ = loop.drainTasks(TestDocument.classify, noCheckpoint);
    try testing.expectEqual(@as(usize, 0), loop.tasks.items.len);
    try testing.expectEqual(@as(usize, 1), loop.suspended.items.len);
    try testing.expectEqual(@as(usize, 2), loop.suspended.items[0].tasks.items.len);
}

test "an inactive task of another document, or of another generation, stays in place" {
    var loop = try testLoop();
    defer loop.deinit();
    var log: std.ArrayListUnmanaged(u8) = .empty;
    defer log.deinit(testing.allocator);
    var cached: TestDocument = .{ .activity = .inactive };
    var other: TestDocument = .{ .activity = .inactive };
    var a: Ordered = .{ .log = &log, .name = 'a' };
    var b: Ordered = .{ .log = &log, .name = 'b' };
    var stale = a.task(&cached);
    stale.document_generation = 7;
    queueAll(&loop, &.{ stale, b.task(&other) });
    try loop.suspendDocument(&cached, 0, null, 0);
    _ = loop.drainTasks(TestDocument.classify, noCheckpoint);
    // Both are the transient kind: left in place, as phase A leaves them.
    try testing.expectEqual(@as(usize, 2), loop.tasks.items.len);
    try testing.expectEqual(@as(usize, 2), loop.waiting);
    try testing.expectEqual(@as(usize, 1), loop.suspended.items.len);
    try testing.expectEqual(@as(usize, 0), loop.suspended.items[0].tasks.items.len);
}

test "a resumed group's tasks run first at the next drain, ahead of the tasks queued since" {
    var loop = try testLoop();
    defer loop.deinit();
    var log: std.ArrayListUnmanaged(u8) = .empty;
    defer log.deinit(testing.allocator);
    var cached: TestDocument = .{ .activity = .inactive };
    var a1: Ordered = .{ .log = &log, .name = '1' };
    var a2: Ordered = .{ .log = &log, .name = '2' };
    var a3: Ordered = .{ .log = &log, .name = '3' };
    var z: Ordered = .{ .log = &log, .name = 'z' };
    queueAll(&loop, &.{ a1.task(&cached), a2.task(&cached) });
    try loop.suspendDocument(&cached, 0, null, 0);
    _ = loop.drainTasks(TestDocument.classify, noCheckpoint);
    // Queued while its document is cached: behind the older ones, in its group.
    queueAll(&loop, &.{a3.task(&cached)});
    _ = loop.drainTasks(TestDocument.classify, noCheckpoint);
    try testing.expectEqual(@as(usize, 1), loop.suspended.items.len);
    try testing.expectEqual(@as(usize, 3), loop.suspended.items[0].tasks.items.len);
    // Another document's task, queued while it was cached.
    queueAll(&loop, &.{z.task(null)});

    cached.activity = .fully_active;
    loop.resumeDocument(&cached, 0);
    try testing.expect(loop.runnableQueued());
    try testing.expect(loop.hasPendingWork());
    try testing.expect(loop.drainTasks(TestDocument.classify, noCheckpoint));
    try testing.expectEqualStrings("123z", log.items);
    try testing.expectEqual(@as(usize, 0), loop.suspended.items.len);
    try testing.expectEqual(@as(usize, 0), loop.tasks.items.len);
}

test "a document resumed by a task of the drain waits for the next drain" {
    var loop = try testLoop();
    defer loop.deinit();
    var log: std.ArrayListUnmanaged(u8) = .empty;
    defer log.deinit(testing.allocator);
    var cached: TestDocument = .{ .activity = .inactive };
    var a: Ordered = .{ .log = &log, .name = 'a' };
    queueAll(&loop, &.{a.task(&cached)});
    try loop.suspendDocument(&cached, 0, null, 0);
    _ = loop.drainTasks(TestDocument.classify, noCheckpoint);

    // A traversal task restores it, mid-drain, between two other tasks.
    const Restore = struct {
        loop: *EventLoop,
        document: *TestDocument,
        log: *std.ArrayListUnmanaged(u8),
        fn run(data: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            self.document.activity = .fully_active;
            self.loop.resumeDocument(self.document, 0);
            self.log.append(testing.allocator, 'r') catch {};
        }
    };
    var restore: Restore = .{ .loop = &loop, .document = &cached, .log = &log };
    var b: Ordered = .{ .log = &log, .name = 'b' };
    queueAll(&loop, &.{ .{ .callback = &Restore.run, .context = &restore }, b.task(null) });
    _ = loop.drainTasks(TestDocument.classify, noCheckpoint);
    try testing.expectEqualStrings("rb", log.items);
    // Still in its group until the next drain begins: work, though.
    try testing.expectEqual(@as(usize, 1), loop.suspended.items.len);
    try testing.expect(loop.runnableQueued());
    _ = loop.drainTasks(TestDocument.classify, noCheckpoint);
    try testing.expectEqualStrings("rba", log.items);
    try testing.expectEqual(@as(usize, 0), loop.suspended.items.len);
}

test "suspending a document again before its group was put back keeps the group" {
    var loop = try testLoop();
    defer loop.deinit();
    var log: std.ArrayListUnmanaged(u8) = .empty;
    defer log.deinit(testing.allocator);
    var cached: TestDocument = .{ .activity = .inactive };
    var a: Ordered = .{ .log = &log, .name = 'a' };
    queueAll(&loop, &.{a.task(&cached)});
    try loop.suspendDocument(&cached, 0, null, 0);
    _ = loop.drainTasks(TestDocument.classify, noCheckpoint);
    loop.resumeDocument(&cached, 0);
    try loop.suspendDocument(&cached, 0, null, 0);
    try testing.expect(!loop.runnableQueued());
    _ = loop.drainTasks(TestDocument.classify, noCheckpoint);
    try testing.expectEqualStrings("", log.items);
    try testing.expectEqual(@as(usize, 1), loop.suspended.items.len);
    try testing.expectEqual(@as(usize, 1), loop.suspended.items[0].tasks.items.len);
}

test "discarding a suspended document drops its tasks without running them" {
    var loop = try testLoop();
    defer loop.deinit();
    var log: std.ArrayListUnmanaged(u8) = .empty;
    defer log.deinit(testing.allocator);
    var cached: TestDocument = .{ .activity = .inactive };
    var a: Ordered = .{ .log = &log, .name = 'a' };
    var b: Ordered = .{ .log = &log, .name = 'b' };
    queueAll(&loop, &.{ a.task(&cached), b.task(&cached) });
    try loop.suspendDocument(&cached, 0, null, 0);
    _ = loop.drainTasks(TestDocument.classify, noCheckpoint);
    loop.discardDocument(&cached, 0);
    try testing.expect(a.dropped and b.dropped);
    try testing.expectEqualStrings("", log.items);
    try testing.expectEqual(@as(usize, 0), loop.suspended.items.len);
    // Discarding one with no group is nothing.
    loop.discardDocument(&cached, 0);
}

test "the loop's end drops a suspended group's tasks" {
    var log: std.ArrayListUnmanaged(u8) = .empty;
    defer log.deinit(testing.allocator);
    var cached: TestDocument = .{ .activity = .inactive };
    var a: Ordered = .{ .log = &log, .name = 'a' };
    {
        var loop = try testLoop();
        defer loop.deinit();
        queueAll(&loop, &.{a.task(&cached)});
        try loop.suspendDocument(&cached, 0, null, 0);
        _ = loop.drainTasks(TestDocument.classify, noCheckpoint);
        try testing.expect(!a.dropped);
    }
    try testing.expect(a.dropped);
    try testing.expectEqualStrings("", log.items);
}

test "an idle period starts while only waiting tasks are queued" {
    var loop = try testLoop();
    defer loop.deinit();
    var log: std.ArrayListUnmanaged(u8) = .empty;
    defer log.deinit(testing.allocator);
    var document: TestDocument = .{ .activity = .inactive };
    var a: Ordered = .{ .log = &log, .name = 'a' };
    loop.eventLoop().queueTask(a.task(&document));
    var w: TestWindow = .{};
    loop.requestIdlePeriod(&w.realm, &TestWindow.start);
    // Queued, not yet drained: maybe runnable, so not idle.
    try testing.expect(!loop.startIdlePeriod(1_000 * std.time.ns_per_ms));
    _ = loop.drainTasks(TestDocument.classify, noCheckpoint);
    // "has no runnable task": idle.
    try testing.expect(loop.startIdlePeriod(1_000 * std.time.ns_per_ms));
    try testing.expectEqual(@as(usize, 1), w.starts);
}

/// Posts one task to `sink` from a thread of its own.
const Poster = struct {
    sink: *runtime.TaskSink,
    tally: *Tally,

    fn run(self: *Poster) void {
        defer self.sink.release();
        _ = self.sink.post(.{ .run = &Tally.run, .drop = &Tally.drop, .data = self.tally });
    }
};

test "a task another thread posted joins the task queue at the next turn" {
    var loop = try testLoop();
    defer loop.deinit();
    var tally: Tally = .{};
    var poster: Poster = .{ .sink = loop.taskSink().retain(), .tally = &tally };
    const thread = try std.Thread.spawn(.{}, Poster.run, .{&poster});
    thread.join();

    // Posted and not taken: work is waiting.
    try testing.expect(loop.hasPendingWork());
    loop.takePosted();
    try testing.expectEqual(@as(usize, 1), loop.tasks.items.len);
    const task = loop.tasks.orderedRemove(0);
    task.callback(task.context);
    try testing.expectEqual(@as(u32, 1), tally.ran);
    try testing.expect(!loop.hasPendingWork());
}

test "a loop that owns a running worker is not idle, and its end drops what was posted" {
    var tally: Tally = .{};
    {
        var loop = try testLoop();
        defer loop.deinit();
        const sink = loop.taskSink();
        sink.addSource();
        try testing.expect(loop.hasPendingWork());
        sink.removeSource();
        try testing.expect(!loop.hasPendingWork());
        // Posted in the loop's last turn: never taken.
        try testing.expect(sink.post(.{ .run = &Tally.run, .drop = &Tally.drop, .data = &tally }));
    }
    try testing.expectEqual(@as(u32, 1), tally.dropped);
    try testing.expectEqual(@as(u32, 0), tally.ran);
}

/// A host microtask still queued when its loop ends.
const LateMicrotask = struct {
    ran: bool = false,
    failed: bool = false,
    leaked: bool = false,

    fn markRan(data: ?*anyopaque) void {
        const self: *LateMicrotask = @ptrCast(@alignCast(data.?));
        self.ran = true;
    }

    /// On a thread of its own: its agent is that thread's host agent, and
    /// its end takes down only that thread's engine state.
    fn body(self: *LateMicrotask) void {
        var counted: std.heap.DebugAllocator(.{}) = .init;
        {
            const agent = engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &.{} }) catch {
                self.failed = true;
                return;
            };
            var loop = EventLoop.init(agent, counted.allocator()) catch {
                engine.destroyAgent(agent);
                self.failed = true;
                return;
            };
            loop.eventLoop().queueMicrotask(.{ .callback = markRan, .context = self });
            // The loop ends before its agent (Browser.deinit's order); the
            // agent's end runs its microtask queue.
            loop.deinit();
            engine.destroyAgent(agent);
        }
        self.leaked = counted.deinit() == .leak;
    }
};

test "a microtask still queued at the loop's end runs nothing and is freed when the agent runs it" {
    try @import("process.zig").Process.ensureStarted(.{});
    var probe: LateMicrotask = .{};
    const thread = try std.Thread.spawn(.{}, LateMicrotask.body, .{&probe});
    thread.join();
    try testing.expect(!probe.failed);
    try testing.expect(!probe.ran);
    try testing.expect(!probe.leaked);
}

/// A tree of `nodes` nodes a deferred teardown frees a budget at a time.
const QueuedTree = struct {
    nodes: usize,
    freed: usize = 0,

    fn run(item: *runtime.gc.DeferredTeardown.Item, budget: usize) runtime.gc.DeferredTeardown.Progress {
        const self: *QueuedTree = @ptrCast(@alignCast(item.data.?));
        const n = @min(budget, self.nodes - self.freed);
        self.freed += n;
        return .{ .freed = n, .done = self.freed == self.nodes };
    }

    const steps: runtime.gc.DeferredTeardown.Steps = .{ .run = run };

    fn queue(self: *QueuedTree, q: *runtime.gc.DeferredTeardown, instance: *runtime.Instance) !void {
        try testing.expect(q.push(.{ .instance = instance, .generation = 1, .owner = null, .steps = &steps, .data = self, .weight = self.nodes }));
    }
};

test "the deferred teardown runs between tasks: slices while nothing waits, one when a task does, down to the mark regardless" {
    var loop = try testLoop();
    defer loop.deinit();
    var q = runtime.gc.DeferredTeardown.init(testing.allocator);
    defer q.deinit();
    loop.deferred_teardown = &q;
    var instance: runtime.Instance = undefined;

    // Nothing queued: nothing to do, and no reason to keep turning.
    try testing.expect(!loop.runDeferredTeardown());
    try testing.expect(!loop.hasPendingWork());

    // A task waiting, and more queued than a turn leaves: down to the
    // turn's mark first, whatever waits.
    const DeferredTeardown = runtime.gc.DeferredTeardown;
    var big: QueuedTree = .{ .nodes = DeferredTeardown.loop_low_water + 10 * DeferredTeardown.slice_budget };
    try big.queue(&q, &instance);
    try testing.expect(loop.hasPendingWork());
    try loop.tasks.append(testing.allocator, .{ .callback = &noop, .context = null });
    try testing.expect(loop.runDeferredTeardown());
    try testing.expect(q.pendingNodes() <= DeferredTeardown.loop_low_water);
    try testing.expect(q.pendingNodes() > DeferredTeardown.loop_low_water - DeferredTeardown.slice_budget);

    // At the mark, with a task waiting: one slice, then the task's turn.
    const at_mark = big.freed;
    try testing.expect(loop.runDeferredTeardown());
    try testing.expectEqual(at_mark + DeferredTeardown.slice_budget, big.freed);
    _ = loop.tasks.orderedRemove(0);

    // Nothing waiting: slices until the queue is empty or the turn's share
    // is spent; every turn makes progress until it is empty.
    var turns: usize = 0;
    while (loop.deferredPending()) : (turns += 1) {
        const before = big.freed;
        try testing.expect(loop.runDeferredTeardown());
        try testing.expect(big.freed > before);
        try testing.expect(turns < 1000);
    }
    try testing.expectEqual(big.nodes, big.freed);
    try testing.expect(!loop.hasPendingWork());
}
