//! Lane wr1 batch 10: V8's idle tasks, in the host's idle periods, as Chrome
//! runs them (the user's ruling, 2026-11-10 06:11 ET).
//!
//! After a full collection V8 does not force, cppgc sweeps lazily: its sweeper
//! posts a task that, on its first run, posts an IDLE task and a regular one
//! 100 ms later (13.1.203 src/heap/cppgc/sweeper.cc SweeperImpl::Start ->
//! SweepForTask, `regular_task_is_delayed_idle_task_`). With no idle tasks the
//! sweep is finalized only by that later task, in 5 ms slices, or by
//! allocation, and until then cppgc refuses every explicit free - each node
//! anchor a scavenge dropped waits (lesson architecture-cppgc-refuses-explicit-
//! frees-until-its-lazy-sweep-is-finalized.md: 6,627,961 refusals in 2,080,000
//! drops with no event loop). Chrome gives the idle task its time: gin's
//! V8Platform answers IdleTasksEnabled per isolate (gin/v8_platform.cc), Blink
//! enables it for the main thread's isolate (bindings/core/v8/
//! v8_initializer.cc: V8PerIsolateData::EnableIdleTasks) and its
//! V8IdleTaskRunner posts each V8 idle task to the scheduler's idle queue,
//! run in an idle period with that period's deadline (bindings/core/v8/
//! v8_idle_task_runner.h; platform/scheduler/common/idle_helper.cc), Chromium
//! 145.0.7608.0.
//!
//! Crane's host does the same through two engine operations: the loop asks
//! `hasEngineIdleTasks` and, in an idle period, gives `runEngineIdleTasks`
//! the time the period has left (src/browser/event_loop.zig step 2d, whose
//! own tests cover the loop's half with an engine stand-in). This file pins
//! the engine's half against V8 itself, turning the agent as the loop does:
//! its posted tasks (runEngineTasks), then its idle time.
//!
//! - an agent made without idle periods is given none: V8 posts no idle task;
//! - one made with them: the lazy sweep posts idle work, an idle period
//!   finishes it, and the anchor frees cppgc refused meanwhile go through -
//!   none waits, none is refused afterwards, each is counted;
//! - the idle time V8 is given and uses is counted, and it uses no more than
//!   it was given.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const clock = @import("clock");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const engine = @import("engine");
const interfaces = @import("interfaces");

const DeferredTeardown = runtime.gc.DeferredTeardown;

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) engine.Reporter {
        return .{ .report = report, .host = self };
    }
};

const Page = struct {
    agent: *engine.Agent,
    realm: runtime.Context,
    queue: *DeferredTeardown,

    fn open(queue: *DeferredTeardown, idle_periods: bool) !Page {
        test_process.start();
        const agent = try engine.createAgent(.{
            .can_block = false,
            .from_snapshot = false,
            .hooks = &test_process.no_hooks,
            .host = null,
            .deferred_teardown = queue,
            .idle_periods = idle_periods,
        });
        errdefer engine.destroyAgent(agent);
        const realm = try engine.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm, .queue = queue };
    }

    fn close(self: Page) void {
        engine.destroyWindowRealm(self.realm, .global_detached);
        engine.destroyAgent(self.agent);
    }

    fn isolate(self: Page) *ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    fn run(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const held = try engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
    }

    fn enter(self: Page) bool {
        const entered = ffi.v8_Isolate_GetCurrent() != self.isolate();
        if (entered) ffi.v8_Isolate_Enter(self.isolate());
        return entered;
    }

    fn leave(self: Page, entered: bool) void {
        if (entered) ffi.v8_Isolate_Exit(self.isolate());
    }

    /// Requested full collections, twice, their releases drained.
    fn fullGC(self: Page) void {
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
        self.queue.drainAll();
    }

    /// At least `n` scavenges, nothing run after them.
    fn scavenge(self: Page, n: u32) !void {
        const entered = self.enter();
        defer self.leave(entered);
        const before = ffi.v8_Debug_MinorGCCount(self.isolate());
        ffi.v8_test_Isolate_MinorGC(self.isolate(), n);
        try testing.expect(ffi.v8_Debug_MinorGCCount(self.isolate()) >= before + n);
    }

    /// A full collection V8 does not force, after which the C++ heap sweeps
    /// lazily (v8_test_Isolate_CollectUnforced): the shape of the
    /// collections V8 schedules for itself in a page that churns.
    fn collectUnforced(self: Page) !void {
        const entered = self.enter();
        defer self.leave(entered);
        try testing.expect(ffi.v8_test_Isolate_CollectUnforced(self.isolate()));
    }

    /// Whether the agent's C++ heap is collecting - sweeping, or marking
    /// again: V8's answer to critical memory pressure may start incremental
    /// marking after its collection (13.1.203 heap.cc
    /// Heap::CollectGarbageOnMemoryPressure), whose own end - finalized by
    /// V8's regular tasks, unforced - sweeps lazily in turn. cppgc refuses
    /// an explicit free in either (explicit-management.cc InGC).
    fn collecting(self: Page) bool {
        const entered = self.enter();
        defer self.leave(entered);
        return ffi.v8_test_CppHeap_IsSweeping(self.isolate()) or ffi.v8_test_Isolate_CppHeapIsMarking(self.isolate());
    }
};

/// The adapter's counter `name` with the page's isolate entered.
fn counter(page: Page, name: []const u8) !i64 {
    const entered = page.enter();
    defer page.leave(entered);
    const counters = try engine.diagnosticCounters(testing.allocator);
    defer testing.allocator.free(counters);
    for (counters) |c| if (std.mem.eql(u8, c.name, name)) return c.value;
    std.debug.print("the adapter reports no counter named {s}\n", .{name});
    return error.CounterMissing;
}

/// One of the agent's posted tasks, run as the loop's step 2b runs each
/// (src/runtime/engines/v8/event_loop.zig pumpPlatformTasks: the platform's
/// message loop once, then a microtask checkpoint). Whether one ran.
fn pumpOne(page: Page) bool {
    const entered = page.enter();
    defer page.leave(entered);
    const ran = ffi.v8_Platform_PumpMessageLoop(page.isolate());
    if (ran) ffi.v8_Isolate_PerformMicrotaskCheckpoint(page.isolate());
    return ran;
}

/// A lazy sweep with refused anchor frees waiting on it: 100,000 wrappers
/// made dead before a full collection V8 does not force, then 5,000 more
/// dropped in a scavenge while the C++ heap still collects, and the agent's
/// posted tasks run - the sweeper's first task among them, and the drain the
/// scavenge posted, whose frees cppgc refuses. Returns how many anchors wait.
///
/// The tasks run one at a time, and stop as soon as the drain has been
/// refused and - for an agent with idle periods - the sweeper's first task
/// has posted its idle task: the point where the loop's idle period comes.
/// Running on would reach the regular task that first task also posts,
/// 100 ms later (13.1.203 src/heap/cppgc/sweeper.cc SweepForTask,
/// kDelayWhileIdleSweepingMakesProgress), and the drain alone can outlast
/// those 100 ms: it releases the 100,000 wrappers the collection took
/// (~159 ms on chat.local, macOS, 2026-11-10). With no idle progress made by
/// then, that task finishes the sweep itself, in 5 ms slices, before any
/// idle period - V8's own fallback, which the no-idle case below relies on,
/// but not the path this file pins. A run of all the posted tasks at once
/// (runEngineTasks) made the macOS run fail here and the Linux one pass.
fn sweepWithRefusedFrees(page: Page, idle_periods: bool) !i64 {
    try page.run("globalThis.d = new Document();");
    page.fullGC();
    try page.run("globalThis.keep = (() => { const a = []; for (let i = 0; i < 100000; i++) a.push(d.createElement('div')); return a; })();");
    try page.run("globalThis.keep = null;");
    try page.collectUnforced();
    try page.run("{ const make = (n) => { for (let i = 0; i < n; i++) d.createElement('div'); }; make(5000); }");
    try page.scavenge(1);
    // The loop's step 2b, a task at a time.
    const start = clock.monotonicMillis();
    while (clock.monotonicMillis() - start < 3000) {
        const refused = try counter(page, "node_anchor_frees_deferred");
        if (refused > 0 and (!idle_periods or engine.hasEngineIdleTasks(page.agent))) break;
        if (!pumpOne(page)) clock.sleep(std.time.ns_per_ms);
    }
    const waiting = try counter(page, "node_anchors_dropped_waiting");
    try testing.expect(waiting > 0);
    try testing.expect(try counter(page, "node_anchor_frees_deferred") > 0);
    try testing.expectEqual(idle_periods, engine.hasEngineIdleTasks(page.agent));
    try testing.expect(page.collecting());
    return waiting;
}

/// The loop's turns, as src/browser/event_loop.zig takes them while nothing
/// else is queued: the engine's posted tasks, then - when it has idle work -
/// an idle period of `period_ns` given to it; a turn with no idle work waits
/// a millisecond, as the loop waits for its next wake-up (the sweeper's
/// delayed task among them). Until `done` holds or `limit_ms` pass. How many
/// idle periods were given.
fn turnUntil(page: Page, period_ns: u64, limit_ms: i64, done: *const fn (Page) bool) !u64 {
    const start = clock.monotonicMillis();
    var periods: u64 = 0;
    while (!done(page) and clock.monotonicMillis() - start < limit_ms) {
        _ = engine.runEngineTasks(page.agent);
        if (engine.hasEngineIdleTasks(page.agent)) {
            _ = engine.runEngineIdleTasks(page.agent, period_ns);
            periods += 1;
        } else {
            clock.sleep(std.time.ns_per_ms);
        }
    }
    return periods;
}

fn sweptAndFreed(page: Page) bool {
    if (page.collecting()) return false;
    const waiting = counter(page, "node_anchors_dropped_waiting") catch return false;
    return waiting == 0;
}

test "wr10 b10: an agent made without idle periods is given none - V8 posts no idle task and sweeps in its own tasks" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue, false);
    defer page.close();
    _ = try sweepWithRefusedFrees(page, false);
    // V8 finishes its collection and sweep in its own tasks - posting
    // nothing for idle time on the way (its runner says idle tasks are
    // off), so the loop never starts an idle period for it.
    _ = try turnUntil(page, 50 * std.time.ns_per_ms, 3000, struct {
        fn f(p: Page) bool {
            return !p.collecting();
        }
    }.f);
    try testing.expect(!page.collecting());
    try testing.expect(!engine.hasEngineIdleTasks(page.agent));
    try testing.expect(!engine.runEngineIdleTasks(page.agent, 50 * std.time.ns_per_ms));
    try testing.expectEqual(@as(i64, 0), try counter(page, "engine_idle_periods"));
    try testing.expectEqual(@as(i64, 0), try counter(page, "engine_idle_tasks_run"));
    // The waiting anchors go at the next drain - here the next full
    // collection's.
    page.fullGC();
    try testing.expectEqual(@as(i64, 0), try counter(page, "node_anchors_dropped_waiting"));
}

test "wr10 b10: a lazy sweep posts idle work; idle periods finish it, and the anchor frees cppgc refused go through - counted" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue, true);
    defer page.close();
    const freed_before = try counter(page, "node_anchors_freed");
    const waiting = try sweepWithRefusedFrees(page, true);
    const refused = try counter(page, "node_anchor_frees_deferred");

    // The idle period of the turn whose tasks sweepWithRefusedFrees ran (the
    // loop's step 2d after its 2b): 50 ms, computeDeadline's cap with no
    // timer due. V8's idle task - posted by its lazy sweep's first task,
    // 13.1.203 sweeper.cc SweepForTask -> ScheduleIdleIncrementalSweeping -
    // sweeps in it; once it has made progress, the sweeper's regular task
    // only reschedules itself (SweepForTask: `saved_idle_task_count_ !=
    // idle_task_count_`).
    var given: u64 = 0;
    if (engine.hasEngineIdleTasks(page.agent)) {
        _ = engine.runEngineIdleTasks(page.agent, 50 * std.time.ns_per_ms);
        given += 1;
    }
    // Then the loop's turns: V8's tasks, and idle periods while it has idle
    // work, until the C++ heap is done collecting and nothing waits.
    given += try turnUntil(page, 50 * std.time.ns_per_ms, 3000, sweptAndFreed);
    const freed = try counter(page, "node_anchors_freed") - freed_before;
    const idle_runs = try counter(page, "engine_idle_tasks_run");
    const given_us = try counter(page, "engine_idle_given_us");
    const used_us = try counter(page, "engine_idle_used_us");
    std.debug.print("wr10 b10 fact: {d} anchors waited on the collection, {d} frees refused; {d} idle periods given ({d} us), {d} idle tasks ran in {d} us; {d} anchors freed; collecting {}\n", .{
        waiting, refused, given, given_us, idle_runs, used_us, freed, page.collecting(),
    });
    // The sweep was finished in idle time, by V8's own idle task.
    try testing.expect(!page.collecting());
    try testing.expect(given > 0);
    try testing.expect(idle_runs > 0);
    // Every refused free went through once the sweep was done: nothing
    // waits, each waiting anchor was freed, and no free was refused after.
    try testing.expectEqual(@as(i64, 0), try counter(page, "node_anchors_dropped_waiting"));
    try testing.expect(freed >= waiting);
    try testing.expectEqual(refused, try counter(page, "node_anchor_frees_deferred"));
    // V8 used no more idle time than it was given (a millisecond of slack
    // for the call around it).
    try testing.expect(given_us > 0);
    try testing.expect(used_us <= given_us + 1000 * @as(i64, @intCast(given)));
    // And once its work is done, no idle work is left.
    try testing.expect(!engine.hasEngineIdleTasks(page.agent));
}

test "wr10 b10: idle work given no time does none, and a later period still finds it" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue, true);
    defer page.close();
    // V8's tasks until its sweep has posted idle work (sweepWithRefusedFrees
    // stops there).
    _ = try sweepWithRefusedFrees(page, true);
    const runs_before = try counter(page, "engine_idle_tasks_run");
    // A period already over: V8 runs nothing in it (default-platform.cc
    // RunIdleTasks pops a task only while the deadline is ahead).
    try testing.expect(!engine.runEngineIdleTasks(page.agent, 0));
    try testing.expectEqual(runs_before, try counter(page, "engine_idle_tasks_run"));
    try testing.expect(engine.hasEngineIdleTasks(page.agent));
    // The next period - at once, before the turn's tasks - finds it and
    // does the work; the loop's turns finish what is left.
    try testing.expect(engine.runEngineIdleTasks(page.agent, 50 * std.time.ns_per_ms));
    try testing.expect(try counter(page, "engine_idle_tasks_run") > runs_before);
    _ = try turnUntil(page, 50 * std.time.ns_per_ms, 3000, sweptAndFreed);
    try testing.expect(!page.collecting());
    try testing.expectEqual(@as(i64, 0), try counter(page, "node_anchors_dropped_waiting"));
}
