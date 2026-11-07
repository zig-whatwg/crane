//! Context - one page navigation
//!
//! A page's realm - its Window's - made in the Browser's agent, which every
//! navigation shares, and what the page has beyond its interfaces: its
//! document, navigator, location and performance objects, its timers and
//! animation frames, and host script evaluation (the WPT harness, WebDriver,
//! the REPL). The realm is made and ended through the engine protocol
//! (`@import("engine")`): this file names no engine.
//!
//! ## Specification References
//!
//! - HTML Standard: Browsing contexts https://html.spec.whatwg.org/multipage/document-sequences.html
//! - HTML Standard: Window object https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-window-object
//! - HTML Standard: Creating a new realm https://html.spec.whatwg.org/multipage/webappapis.html#creating-a-new-javascript-realm

const std = @import("std");
const log = std.log.scoped(.browser_context);
const engine = @import("engine");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const fetch = @import("fetch");

const storage_mod = @import("storage/Storage.zig");
const cookiestore = @import("cookiestore");
const Storage = storage_mod.Storage;
const EventLoop = @import("event_loop.zig").EventLoop;
const rendering = @import("rendering.zig");

// Threadlocal state cleanup modules
const dom_mod = @import("dom");
const html_mod = @import("html");
const mutation_observer_algorithms = dom_mod.mutation_observer_algorithms;
const instance_lifecycle = runtime.instance_lifecycle;

// Timer support
const TimerInterface = runtime.TimerInterface;
const TimerId = runtime.TimerId;
const TimerCallback = runtime.TimerCallback;
const typed_callback = runtime.typed_callback;
const SelfContainedWorkCallback = typed_callback.SelfContainedWorkCallback;

// ============================================================================
// Window timers: each Window's own map, run on its agent's loop
// ============================================================================

/// A window's map of active timers (HTML 8.6: "each object that implements
/// WindowOrWorkerGlobalScope has a map of active timers"), by the id script
/// holds: the realm's own (`runtime.ContextData.active_timers`), whose values
/// are this file's `*WindowTimerCallback`s, and whose timers run on the
/// realm's agent's loop (`realm.timer`, its event loop's timer interface).
/// It was one map and one "current timer interface" per THREAD, set by
/// whichever Browser made a realm last: a Browser's setTimeout armed its timer
/// on another Browser's loop, and one Browser's page end cleared every
/// Browser's timers on the thread (tests/html/gs3_agent_state_one_thread_test.zig).
///
/// Every timer is a key the map never saw - ids only grow - put when armed
/// and removed when it runs its last time or is cleared: a
/// runtime.native_timer.TimerIdMap, which rehashes its tombstones away
/// (before its guard the free slots ran out: a 1,069-file runner sample
/// found none free at capacity 8-16 in 219 of 1,272 samples, and every arm
/// walked the whole table) and gives back what a burst took (lane
/// timerheap1: 5,000 timers armed and cleared left 8,192 slots that every
/// later window's end walked, clearWindowState). Every insert and removal
/// goes through here. No iteration of the map runs script, so no insert -
/// which only script makes (`scheduleTimer`), and before which alone the map
/// is rehashed or rebuilt - meets a live iterator.
const TimerMap = struct {
    realm: runtime.Context,

    const Ids = runtime.native_timer.TimerIdMap(*anyopaque);

    /// One timer of the map, as the iterator gives it.
    const Entry = struct { id: TimerId, wrapper: *WindowTimerCallback };

    const Iterator = struct {
        inner: Ids.Iterator,

        fn next(self: *Iterator) ?Entry {
            const entry = self.inner.next() orelse return null;
            return .{ .id = entry.key_ptr.*, .wrapper = @ptrCast(@alignCast(entry.value_ptr.*)) };
        }
    };

    fn of(realm: runtime.Context) TimerMap {
        return .{ .realm = realm };
    }

    fn ids(self: TimerMap) *Ids {
        return &self.realm.active_timers;
    }

    fn put(self: TimerMap, id: TimerId, wrapper: *WindowTimerCallback) !void {
        try self.ids().put(self.realm.allocator, id, wrapper);
    }

    fn remove(self: TimerMap, id: TimerId) bool {
        return self.ids().remove(id);
    }

    fn fetchRemove(self: TimerMap, id: TimerId) ?*WindowTimerCallback {
        const kv = self.ids().fetchRemove(id) orelse return null;
        return @ptrCast(@alignCast(kv.value));
    }

    fn get(self: TimerMap, id: TimerId) ?*WindowTimerCallback {
        const wrapper = self.ids().get(id) orelse return null;
        return @ptrCast(@alignCast(wrapper));
    }

    fn count(self: TimerMap) usize {
        return self.ids().count();
    }

    /// The slots a walk of the map reads (clearWindowState,
    /// activeTimerHandles, the suspension and its resumption).
    fn capacity(self: TimerMap) usize {
        return self.ids().capacity();
    }

    fn iterator(self: TimerMap) Iterator {
        return .{ .inner = self.ids().iterator() };
    }

    /// Give back the map's storage once it is empty: a window whose timers
    /// are all gone - its end, its unload - holds none.
    fn releaseIfEmpty(self: TimerMap) void {
        if (self.count() != 0) return;
        self.ids().deinit(self.realm.allocator);
        self.ids().* = .empty;
    }
};

// Animation frames: the documents' maps of animation frame callbacks and the
// rendering opportunity that runs them are the event loop's (rendering.zig).

test "a held timer stays in its window's map until cleared, and clearing it frees it" {
    const allocator = std.testing.allocator;
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    var other = try runtime.ContextData.init(allocator, .{});
    defer other.deinit();
    const manager = try runtime.native_timer.NativeTimerManager.init(allocator);
    defer manager.deinit();
    // Each window's timers run on its agent's loop: here, the manager.
    realm.timer = manager.timerInterface();
    other.timer = manager.timerInterface();
    const id: TimerId = @intCast(initializeTimer(&realm, .{ .function = .{ .number = 1 } }, 10, &.{}, false));
    const interval: TimerId = @intCast(initializeTimer(&realm, .{ .function = .{ .number = 2 } }, 10, &.{}, true));
    const elsewhere: TimerId = @intCast(initializeTimer(&other, .{ .function = .{ .number = 3 } }, 10, &.{}, false));
    try std.testing.expect(id != 0 and interval != 0 and elsewhere != 0);

    // Both of `realm`'s are held: their window's document went into the
    // back/forward cache (their native timers cancelled, their waits kept).
    suspendWindowTimers(&realm);
    for ([_]TimerId{ id, interval }) |key| {
        const data = TimerMap.of(&realm).get(key).?.getData();
        try std.testing.expectEqual(TimerState.held, data.state);
    }

    // Still in the map of active timers: unload step 16 sees them, and only
    // them for this window.
    const handles = try activeTimerHandles(&realm, allocator);
    defer allocator.free(handles);
    std.mem.sort(TimerId, handles, {}, std.sort.asc(TimerId));
    try std.testing.expectEqualSlices(TimerId, &.{ id, interval }, handles);

    // clearTimeout frees a held timer at once - no native timer is armed to
    // free it later (std.testing.allocator reports a leak otherwise).
    clearTimer(&realm, @intCast(id));
    try std.testing.expect(TimerMap.of(&realm).get(id) == null);
    // A held interval: the same (clearInterval, or its window's end, which
    // clears the map through the same unregistering).
    clearTimer(&realm, @intCast(interval));
    try std.testing.expect(TimerMap.of(&realm).get(interval) == null);
    // Another window's timer is untouched, and still armed.
    try std.testing.expect(TimerMap.of(&other).get(elsewhere) != null);
    clearTimer(&other, @intCast(elsewhere));
    try std.testing.expectEqual(@as(usize, 0), TimerMap.of(&realm).count());
}

test "a window's map of active timers keeps half its unused slots free while timers come and go" {
    // Lane hashmaps1: every timer is a key the map never saw (ids only
    // grow), put when armed and removed when cleared or fired. std's map
    // never counts a tombstone against its load, so without a rehash the
    // free slots run out and every arm walks the whole table
    // (src/infra/tombstones.zig).
    const allocator = std.testing.allocator;
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    const manager = try runtime.native_timer.NativeTimerManager.init(allocator);
    defer manager.deinit();
    // Each window's timers run on its agent's loop: here, the manager.
    realm.timer = manager.timerInterface();
    const resident: TimerId = @intCast(initializeTimer(&realm, .{ .function = .{ .number = 1 } }, 3_600_000, &.{}, true));
    defer clearTimer(&realm, @intCast(resident));
    var starved: usize = 0;
    var worst: usize = 0;
    for (0..400) |_| {
        // A page's debounced work: timers armed, then cleared before due.
        var ids: [12]TimerId = undefined;
        for (&ids, 0..) |*id, i| {
            id.* = @intCast(initializeTimer(&realm, .{ .function = .{ .number = 2 } }, 60_000, &.{}, false));
            if (i == 0) {
                const map = &realm.active_timers.map;
                if (!webidl.utils.tombstones.slotCounts(map).halfOfUnusedFree()) starved += 1;
                worst = @max(worst, webidl.utils.tombstones.meanMissProbe(map));
            }
        }
        for (ids) |id| clearTimer(&realm, @intCast(id));
    }
    if (starved != 0 or worst > 8) {
        const counts = webidl.utils.tombstones.slotCounts(&realm.active_timers.map);
        std.debug.print("active_timers: {d} of 400 pages began with fewer than half the unused slots free; worst mean miss {d} (capacity {d}, live {d}, free {d})\n", .{ starved, worst, counts.capacity, counts.live, counts.free });
        return error.TombstonesFilledTheMap;
    }
    // The resident interval is still found after every rehash.
    try std.testing.expect(TimerMap.of(&realm).get(resident) != null);
    try std.testing.expectEqual(@as(usize, 1), TimerMap.of(&realm).count());
}

test "a window's map of active timers gives back what a burst of 5,000 took once the burst is gone" {
    // Lane timerheap1: a map never gives capacity back by itself, and every
    // window's end walks the whole of it (clearWindowState), as do unload
    // (activeTimerHandles) and the back/forward cache's suspension - so one
    // page's burst of timers made every later page's end walk its size.
    const allocator = std.testing.allocator;
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    const manager = try runtime.native_timer.NativeTimerManager.init(allocator);
    defer manager.deinit();
    // Each window's timers run on its agent's loop: here, the manager.
    realm.timer = manager.timerInterface();
    const resident: TimerId = @intCast(initializeTimer(&realm, .{ .function = .{ .number = 1 } }, 3_600_000, &.{}, true));
    defer clearTimer(&realm, @intCast(resident));
    for (0..16) |_| clearTimer(&realm, initializeTimer(&realm, .{ .function = .{ .number = 2 } }, 60_000, &.{}, false));
    const before = TimerMap.of(&realm).capacity();

    const burst = try allocator.alloc(i32, 5_000);
    defer allocator.free(burst);
    for (burst) |*id| id.* = initializeTimer(&realm, .{ .function = .{ .number = 3 } }, 60_000, &.{}, false);
    for (burst) |id| clearTimer(&realm, id);
    // The next timers the pages that follow set.
    for (0..16) |_| clearTimer(&realm, initializeTimer(&realm, .{ .function = .{ .number = 4 } }, 60_000, &.{}, false));

    const after = TimerMap.of(&realm).capacity();
    if (after > @max(before, 64)) {
        std.debug.print("active_timers: capacity {d} after a burst of 5,000 had gone, against {d} before it\n", .{ after, before });
        return error.BurstKeptItsCapacity;
    }
    try std.testing.expect(TimerMap.of(&realm).get(resident) != null);
    try std.testing.expectEqual(@as(usize, 1), TimerMap.of(&realm).count());
}

test "a queued timer's task owns its record: suspension skips it, clearing releases its handles, its task or drop frees it" {
    // The ownership rule at WindowTimerData, state .queued, without a Window:
    // what timerFired does on a Window's event loop - the native timer has
    // fired, the task is queued - is set up by hand. std.testing.allocator
    // fails the test on a record freed twice or never.
    const allocator = std.testing.allocator;
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    const manager = try runtime.native_timer.NativeTimerManager.init(allocator);
    defer manager.deinit();
    realm.timer = manager.timerInterface();
    const cleared: TimerId = @intCast(initializeTimer(&realm, .{ .function = .{ .number = 1 } }, 10, &.{}, false));
    const dropped: TimerId = @intCast(initializeTimer(&realm, .{ .function = .{ .number = 2 } }, 10, &.{}, true));
    var queued: [2]*WindowTimerCallback = undefined;
    for ([_]TimerId{ cleared, dropped }, 0..) |key, i| {
        const wrapper = TimerMap.of(&realm).get(key).?;
        try std.testing.expect(manager.clearTimeout(wrapper.getData().current_timer_id));
        wrapper.getData().state = .queued;
        queued[i] = wrapper;
    }

    // The back/forward cache keeps the page: a queued timer's task waits in
    // the event loop's queue, in place - there is nothing to stop.
    suspendWindowTimers(&realm);
    for (queued) |wrapper| try std.testing.expectEqual(TimerState.queued, wrapper.getData().state);

    // clearTimeout: out of the map, cancelled, its handles released - and its
    // record left to its task.
    clearTimer(&realm, @intCast(cleared));
    try std.testing.expect(TimerMap.of(&realm).get(cleared) == null);
    try std.testing.expect(queued[0].getData().cancelled);
    try std.testing.expectEqual(@as(usize, 0), queued[0].getData().arguments.len);
    // Its task: step 8.2 - nothing runs - and the record is freed.
    runQueuedTimer(queued[0]);

    // The other's window is gone: its task is dropped, and the drop takes it
    // out of the map and frees it.
    dropQueuedTimer(queued[1]);
    try std.testing.expectEqual(@as(usize, 0), TimerMap.of(&realm).count());
}

test "a window's end leaves a queued timer's record to its task, holding no handle" {
    const allocator = std.testing.allocator;
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    const manager = try runtime.native_timer.NativeTimerManager.init(allocator);
    defer manager.deinit();
    realm.timer = manager.timerInterface();
    const id: TimerId = @intCast(initializeTimer(&realm, .{ .function = .{ .number = 1 } }, 10, &.{}, false));
    const armed: TimerId = @intCast(initializeTimer(&realm, .{ .function = .{ .number = 2 } }, 10, &.{}, false));
    try std.testing.expect(armed != 0);
    const wrapper = TimerMap.of(&realm).get(id).?;
    try std.testing.expect(manager.clearTimeout(wrapper.getData().current_timer_id));
    wrapper.getData().state = .queued;

    // The page ends (Context.deinit): the armed timer is cancelled and freed;
    // the queued one is cancelled, its handles released while the realm
    // lives, and its record left to its task, which may run after the realm
    // is gone - dropped by the loop, or run and finding it cancelled.
    endWindowTimers(&realm);
    try std.testing.expect(wrapper.getData().cancelled);
    try std.testing.expectEqual(@as(usize, 0), wrapper.getData().arguments.len);
    dropQueuedTimer(wrapper);
}

test "a suspended timer keeps the wait it had left, and a resumed one is armed for it" {
    const allocator = std.testing.allocator;
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    var other = try runtime.ContextData.init(allocator, .{});
    defer other.deinit();
    const manager = try runtime.native_timer.NativeTimerManager.init(allocator);
    defer manager.deinit();
    // Each window's timers run on its agent's loop: here, the manager.
    realm.timer = manager.timerInterface();
    other.timer = manager.timerInterface();
    const id: TimerId = @intCast(initializeTimer(&realm, .{ .function = .{ .number = 1 } }, 5_000, &.{}, false));
    const elsewhere: TimerId = @intCast(initializeTimer(&other, .{ .function = .{ .number = 2 } }, 5_000, &.{}, false));
    try std.testing.expect(id != 0 and elsewhere != 0);
    const armed = TimerMap.of(&realm).get(id).?.getData().current_timer_id;

    // The page is kept: its timer's native timer is cancelled, and the wait
    // it had left is kept.
    suspendWindowTimers(&realm);
    const data = TimerMap.of(&realm).get(id).?.getData();
    try std.testing.expectEqual(TimerState.held, data.state);
    try std.testing.expectEqual(@as(?u64, null), manager.remainingMs(armed));
    try std.testing.expect(data.current_timer_id > 4_000 and data.current_timer_id <= 5_000);
    // Another window's timer is untouched.
    try std.testing.expectEqual(TimerState.armed, TimerMap.of(&other).get(elsewhere).?.getData().state);

    // Restored: armed again for what it had left, not its whole timeout
    // from now and not at once.
    resumeWindowTimers(&realm);
    try std.testing.expectEqual(TimerState.armed, data.state);
    const left = manager.remainingMs(data.current_timer_id) orelse return error.NotArmed;
    try std.testing.expect(left > 4_000 and left <= 5_000);

    clearTimer(&realm, @intCast(id));
    clearTimer(&other, @intCast(elsewhere));
    try std.testing.expectEqual(@as(usize, 0), TimerMap.of(&realm).count());
}

// ============================================================================
// HTML timer initialisation steps (HTML Standard s8.6)
// ============================================================================
//
// setTimeout/setInterval do NOT schedule the delay the author asked for. The spec
// runs "timer initialisation steps" first:
//
//   3. If timeout is less than 0, then set timeout to 0.
//   5. If nesting level is greater than 5, and timeout is less than 4, then set
//      timeout to 4.
//
// and the timer being scheduled records `nesting level + 1`, so a chain of
// self-rescheduling timers is throttled to 4ms once it is more than five deep.
//
// Crane already had a correct implementation of this in
// src/html/event_loop/timers.zig (MIN_NESTED_DELAY_MS, NESTING_LEVEL_THRESHOLD,
// setTimerInternal). It is DEAD CODE - nothing references its TimerManager. The live
// path is this file -> the realm's TimerInterface -> its agent's event loop
// (browser/event_loop.zig) -> runtime.native_timer,
// which applied no clamping whatsoever. So the clamp is implemented here, at the
// setTimeout boundary, which is where the spec puts it: initialisation runs before
// the timer is handed to any scheduler.
//
// The nesting level is the agent's - its event loop's running task's - kept on the
// agent's host (html AgentHost.timer_nesting_level, `timerNestingLevel`). It was
// one per thread.

// HTML §8.6's nesting and clamp live in `runtime.timer`, shared with the worker
// binding - which previously had no clamp at all. Aliases, not a second copy: two
// definitions of a spec constant is how the two paths diverged in the first place.
const clampTimeout = runtime.timer.clampTimeout;

/// Restore the timer nesting level at the start of the microtask checkpoint.
///
/// A plain `defer` around the callback restores too late. The engine drains the
/// microtask queue when the JS call stack empties - which happens INSIDE the
/// callback's invocation - so a microtask queued by a timer callback would still
/// observe the task's nesting level and have its sub-4ms timeout clamped.
///
/// Microtasks run FIFO, so enqueueing this BEFORE invoking the callback puts it
/// ahead of anything the callback enqueues. That lands the reset exactly on the
/// spec boundary: a setTimeout called synchronously from the callback nests one
/// deeper, while one scheduled from a microtask does not inherit the level at all.
/// The checkpoint runs between tasks, so the level there is 0 by definition.
fn resetNestingMicrotask(data: ?*anyopaque) void {
    const level: *u32 = @ptrCast(@alignCast(data orelse return));
    level.* = 0;
}

/// HTML timer initialization step 3's "currently running task"'s timer nesting
/// level, of the agent `realm` belongs to: the agent's, kept on its host
/// (html AgentHost.timer_nesting_level), BORROWED for as long as the agent.
/// Null for a realm with no agent or an agent with no host (a unit test's
/// realm), whose level is always 0.
fn timerNestingLevel(realm: runtime.Context) ?*u32 {
    const agent = realm.agent orelse return null;
    const host: *html_mod.agent_host.AgentHost = @ptrCast(@alignCast(engine.agentHost(agent) orelse return null));
    return &host.timer_nesting_level;
}

/// Give back a value the engine handed over (OWNED).
fn releaseValue(value: runtime.JSValue) void {
    engine.releaseValue(.{ .value = value });
}

/// The Window whose realm `realm` is: its realm record's global object.
pub fn realmWindow(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    const global = record.global_object orelse return null;
    return @ptrCast(@alignCast(global));
}

/// The browsing context whose active window is `window`, `realm`'s global,
/// on the list of `realm`'s Browser - asked of the realm, which stays a
/// readable record after it retires, never of a Window that may be gone.
pub fn realmNavigable(realm: runtime.Context, window: *runtime.Instance) ?*html_mod.BrowsingContext {
    const navigables = dom_mod.browser_state.navigablesOf(realm) orelse return null;
    return navigables.ofWindow(@ptrCast(window));
}

/// HTML "report an exception" for the Window `host`, with the error
/// information the engine extracted (step 2): an ErrorEvent at it,
/// `window.onerror`.
fn reportToWindow(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const window: *runtime.Instance = @ptrCast(@alignCast(host orelse return));
    const extracted = runtime.ErrorInfo{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = html_mod.report_exception.reportErrorInfo(window, &extracted, .{});
}

/// "Report an exception" for `realm`'s Window, as the engine's reporter.
fn windowReporter(realm: runtime.Context) engine.Reporter {
    return .{ .report = reportToWindow, .host = realmWindow(realm) };
}

/// Invoke a timer or animation frame callback, reporting what it throws.
///
/// HTML's timer initialization steps and "run the animation frame callbacks"
/// invoke the callback with "report": an exception is REPORTED for the
/// global - an ErrorEvent at the Window, `window.onerror` - not printed and
/// dropped. The callback this value is the WindowProxy. (For animation frames
/// the spec gives none, so a strict callback should see undefined; the
/// WindowProxy is what this binding has always passed, and is kept.)
pub fn invokeReporting(realm: runtime.Context, callback: runtime.JSValue, args: []const runtime.JSValue) void {
    // BORROWED: the timer or frame entry keeps the function. No callback
    // context was recorded when it was converted.
    const function = engine.CallbackFunction{ .function = .{ .value = callback }, .context = null };
    const completion = engine.invokeCallbackFunction(realm, &function, .global_this, args, .{ .report = windowReporter(realm) }) catch |err| {
        log.debug("a timer or animation frame callback was not invoked: {}", .{err});
        return;
    };
    switch (completion) {
        .normal, .throw => |value| value.release(),
    }
}

/// "Clean up after running script" at the end of a timer or frame task: the
/// microtask checkpoint of the agent `realm` belongs to.
pub fn performMicrotaskCheckpoint(realm: runtime.Context) void {
    engine.performMicrotaskCheckpoint(realm.agent orelse return) catch {};
}

/// The end of `realm`'s window's timers, with its page (Context.deinit):
/// every timer in its map of active timers is cancelled on its agent's loop
/// and freed, and the map's storage given back. Only this window's: another
/// window's timers - a frame's, which end with its realm (clearWindowState),
/// another tab's, another Browser's on the thread - are theirs.
fn endWindowTimers(realm: runtime.Context) void {
    const map = TimerMap.of(realm);
    var iter = map.iterator();
    while (iter.next()) |entry| {
        const wrapper = entry.wrapper;
        // Cancel the timer at the loop's level so its callback cannot fire.
        //
        // The result is deliberately discarded: this is the window's end,
        // and every wrapper must be freed here or leak. Unlike
        // unregisterTimerContext there is no later callback to hand
        // ownership to. (A held one has no native timer: its
        // current_timer_id is a wait.)
        // A queued timer's task holds it (the ownership rule at
        // WindowTimerData): its handles go now, while the realm lives, and
        // the task frees the record.
        if (wrapper.getData().state == .queued) {
            releaseQueued(wrapper);
            continue;
        }
        if (realm.timer) |timer| if (wrapper.getData().state == .armed) {
            _ = timer.clearTimeout(wrapper.getData().current_timer_id);
        };
        destroyTimer(wrapper);
    }
    map.ids().deinit(realm.allocator);
    map.ids().* = .empty;

    // (The animation frame callbacks end with the page: Context.deinit's
    // rendering.endPage, before this. The window operations the page's realm
    // installed end with the realm: destroyWindowRealm.)
}

/// The window's native operations, as the engine binds them: the host's
/// steps behind setTimeout, setInterval, their clears, and the animation
/// frame methods (see `runtime.WindowOperations`).
const window_operations = runtime.WindowOperations{
    .initializeTimer = initializeTimer,
    .clearTimer = clearTimer,
    .requestAnimationFrame = rendering.requestAnimationFrame,
    .cancelAnimationFrame = rendering.cancelAnimationFrame,
    .windowDestroyed = clearWindowState,
};

/// The hooks the browser layer owns (src/dom), installed once, at process
/// start, by crane.Process (docs/instances.md): a removed frame's document
/// takes its window's timers and animation frames with it, while its realm
/// lives on (HTMLIFrameElement asks, through dom.window_documents).
pub fn installHooks() void {
    @import("dom").window_documents.install(.{
        .destroyed = clearWindowState,
        .active_timer_handles = activeTimerHandles,
        .suspend_timers = suspendWindowTimers,
        .resume_timers = resumeWindowTimers,
    });
    // The event loop's half of "update the rendering": its frame requests.
    @import("dom").update_the_rendering.installLoop(rendering.loop_hooks);
    // The Browser's back/forward cache, which the navigation code reaches
    // through dom.bfcache.
    @import("back_forward_cache.zig").installHooks();
    @import("dom").idle_periods.installLoop(@import("event_loop.zig").EventLoop.idle_period_hooks);
}

/// A frame's document is being destroyed, and with it its window's map of
/// active timers (HTML "unloading document cleanup steps": clear window's map
/// of active timers) and its map of animation frame callbacks. Without this a
/// removed frame's timers kept firing, and a destroyed one's fired into a
/// window whose state was freed.
fn clearWindowState(realm: runtime.Context) void {
    // The unloading document cleanup steps other specifications define (the
    // File API's: the window's blob URL entries leave the store).
    dom_mod.unloading_cleanup.run(realm);

    // Its map of active timers - its own, so every entry is this window's.
    const map = TimerMap.of(realm);
    if (map.count() != 0) {
        var doomed: std.ArrayListUnmanaged(TimerId) = .empty;
        defer doomed.deinit(realm.allocator);
        var iter = map.iterator();
        while (iter.next()) |entry| doomed.append(realm.allocator, entry.id) catch break;
        // Not while iterating: unregistering removes from the map.
        for (doomed.items) |id| unregisterTimerContext(realm, id);
    }
    // A timer whose callback is on the stack stays until it returns; with
    // none, the map's storage goes with its last timer.
    map.releaseIfEmpty();

    // Its map of animation frame callbacks and its frame requests.
    rendering.windowDestroyed(realm);
}

/// dom.window_documents: the keys of `realm`'s window's map of active timers
/// (HTML "unload a document" step 16), OWNED by the caller - the ids its
/// setTimeout and setInterval returned, held ones included, in no order.
fn activeTimerHandles(realm: runtime.Context, allocator: std.mem.Allocator) error{OutOfMemory}![]TimerId {
    const map = TimerMap.of(realm);
    var handles: std.ArrayListUnmanaged(TimerId) = .empty;
    errdefer handles.deinit(allocator);
    var iter = map.iterator();
    while (iter.next()) |entry| try handles.append(allocator, entry.id);
    return handles.toOwnedSlice(allocator);
}

/// dom.window_documents: the back/forward cache keeps `realm`'s window's
/// document. Each of its timers stops - its native timer cancelled, how
/// long it still had to wait kept - and is HELD (`TimerState.held`):
/// still in the map of active timers, cleared by clearTimeout at once, freed
/// with its window. WebKit suspends a cached document's timers the same way
/// (EventLoopTaskGroup::suspend, EventLoopTimer::suspend keeps the remaining
/// interval); HTML keeps each timer's due time and "reactivate" step 2 moves
/// it by the time the document was suspended, which is the same wait.
/// Chrome fires them early instead (back-forward-cache/timers.html: Firefox
/// and Safari pass, Chrome fails, wpt.fyi 23b0b89b1a). Its animation frame
/// callbacks wait too, without a frame scheduled for them (rendering.zig
/// arms no rendering opportunity for a cached page).
fn suspendWindowTimers(realm: runtime.Context) void {
    const timer = realm.timer orelse return;
    var iter = TimerMap.of(realm).iterator();
    while (iter.next()) |entry| {
        const data = entry.wrapper.getData();
        // A queued timer's task waits in place while its document is
        // inactive (the event loop keeps it): nothing to stop.
        if (data.state != .armed or data.cancelled or data.executing) continue;
        // The wait still to go, asked of the native timer before it is
        // cancelled - WebKit's SuspendableTimer saves its next-fire interval
        // the same way (m_savedNextFireInterval), and nothing is stored at
        // schedule time. A timer interface that cannot say ("unknown") makes
        // it due at once: it runs as soon as its page is restored.
        const remaining = timer.remainingMs(data.current_timer_id) orelse 0;
        // Not confirmed cancelled: its callback is on its way, and the task
        // it queues waits in place while its document is inactive.
        if (!timer.clearTimeout(data.current_timer_id)) continue;
        data.state = .held;
        // A held timer's current_timer_id is its wait still to go.
        data.current_timer_id = remaining;
    }
}

/// dom.window_documents: HTML "reactivate" step 2 for `realm`'s window -
/// every held timer is armed again for what it still had to wait (a timer
/// that came due while its document was inactive has its task waiting in
/// place, which runs now), and its animation frame
/// callbacks and pending autofocus candidates get a frame again.
fn resumeWindowTimers(realm: runtime.Context) void {
    if (realm.timer) |timer| {
        var iter = TimerMap.of(realm).iterator();
        while (iter.next()) |entry| {
            const wrapper = entry.wrapper;
            const data = wrapper.getData();
            if (data.state != .held) continue;
            // A held timer's current_timer_id is its wait still to go.
            const id = timer.setTimeout(data.current_timer_id, WindowTimerCallback.getTrampolineCallback(), wrapper.eraseForFFI());
            // Not armed: it stays held, cleared or freed with its window.
            if (id == 0) continue;
            data.state = .armed;
            data.current_timer_id = id;
        }
    }
    rendering.windowResumed(realm);
}

/// Schedule `wrapper`'s first run and enter it in the map of active timers
/// under the id returned to script. Null when either fails, in which case
/// the wrapper has been freed.
///
/// The id is the manager's id for this FIRST run, and it stays the timer's id
/// for its whole life: an interval's repeats get new manager ids, but the timer
/// initialization steps run again "given ... id", so clearInterval must keep
/// working with the id setInterval returned. It used to be re-keyed to each
/// repeat's manager id, so after the first repeat clearInterval(id) found
/// nothing and the interval ran until the page went away.
fn scheduleTimer(timer: TimerInterface, wrapper: *WindowTimerCallback, delay_ms: u64) ?TimerId {
    const map = TimerMap.of(wrapper.getData().realm);
    const id = timer.setTimeout(delay_ms, WindowTimerCallback.getTrampolineCallback(), wrapper.eraseForFFI());
    if (id == 0) {
        destroyTimer(wrapper);
        return null;
    }
    wrapper.getData().id = id;
    wrapper.getData().current_timer_id = id;
    map.put(id, wrapper) catch {
        // Untracked, it could never be cleared or cleaned up. Cancel before
        // freeing: a scheduled timer holds the wrapper.
        _ = timer.clearTimeout(id);
        destroyTimer(wrapper);
        return null;
    };
    return id;
}

/// Unregister a timer context (cancels and destroys it)
///
/// Timer IDs are looked up in the map and nowhere else. Passing script's number
/// straight to the manager, as clearTimeout used to, cancelled whatever manager
/// timer had that id - an animation frame, an AbortSignal timeout.
fn unregisterTimerContext(realm: runtime.Context, timer_id: TimerId) void {
    const wrapper = TimerMap.of(realm).fetchRemove(timer_id) orelse return;
    // Mark as cancelled so interval callbacks know to stop rescheduling.
    // This must happen before anything else: it is the only signal that
    // reaches a callback we could not cancel.
    wrapper.getData().cancelled = true;

    // Cancel at the loop's level so the callback cannot fire - on the loop
    // of the agent the timer's window belongs to (`realm.timer`), the one
    // that armed it.
    //
    // A timer interface the timer was not armed on knows nothing of its id
    // and cancels nothing (the old thread-wide interface was whichever
    // realm's was set last), and the wrapper must then not be freed: the
    // armed timer would fire on freed memory and destroy it a second time
    // (a double free, and a 0xaa-poisoned segfault in destroyChildContext
    // just after). So the wrapper is only freed when cancellation is
    // CONFIRMED. Otherwise ownership passes to the callback, which sees
    // `cancelled` and destroys it when it fires.
    // Queued: its task holds the record and frees it (step 8.2 runs
    // nothing); its handles go now.
    if (wrapper.getData().state == .queued) return releaseQueued(wrapper);
    const cancelled = if (wrapper.getData().state == .held)
        // Held (suspendWindowTimers): no native timer is armed for it, and
        // no callback will come to free it.
        true
    else if (realm.timer) |timer|
        timer.clearTimeout(wrapper.getData().current_timer_id)
    else
        false;

    // Never free a wrapper whose callback is on the stack - that handler
    // still reads `data` after the callback returns and frees it itself.
    if (cancelled and !wrapper.getData().executing) destroyTimer(wrapper);
}

// ============================================================================
// Window timers
// ============================================================================

/// A window timer's phase, and with it who owns its record
/// (`WindowTimerData`).
const TimerState = enum(u8) {
    /// A native timer is armed for it (`current_timer_id`), whose callback
    /// (`timerFired`) holds the record.
    armed,
    /// Its timeout completed and its task is queued on the event loop
    /// (`timerFired`; a zero timeout's at the call, `queueAtCall`): the task
    /// - run (`runQueuedTimer`) or dropped (`dropQueuedTimer`) - holds the
    /// record, and only it frees it. No native timer stands behind it
    /// (`current_timer_id` 0).
    queued,
    /// Its window's document is in the back/forward cache
    /// (`suspendWindowTimers`): no native timer is armed, and
    /// `current_timer_id` is the wait still to go; the map holds the record,
    /// so clearing it frees it at once, and its window's end frees it with
    /// the rest. Re-armed when the document is reactivated (HTML
    /// "reactivate" step 2).
    held,
};

/// Everything one setTimeout or setInterval needs when it fires. The handler
/// and the arguments are OWNED engine handles - handed over by the binding -
/// and `release` returns them all. A timer used to hold its realm's context
/// as a handle too, which kept that page's whole heap alive until the timer
/// was freed; the realm is now the runtime.Context, which holds nothing.
///
/// OWNERSHIP of the record (lane loadpath1), by `state`:
/// - .armed: its native timer's callback holds it; the window's map of
///   active timers names it by id. clearTimeout removes it from the map, marks
///   it `cancelled` and cancels the native timer - and frees it when the
///   cancel is confirmed and its handler is not on the stack (`executing`);
///   an unconfirmed cancel leaves it to the callback, which frees it.
/// - .queued: its task holds it. clearTimeout removes it from the map, marks
///   it `cancelled` and releases its handles, but never frees it; its window's
///   end does the same. The task frees it: run (`runQueuedTimer`: step 8.2,
///   a cancelled timer runs nothing) or dropped with a window that is gone
///   (`dropQueuedTimer`). So a task never reads a freed record, and a record
///   outliving its realm holds no engine handle.
/// - .held: the map holds it alone (no native timer, no task): clearing it,
///   or its window's end, frees it at once.
/// While its handler runs (`executing`), the running task owns it, whatever
/// clears it meanwhile.
const WindowTimerData = struct {
    /// The converted TimerHandler: a callable, or the string ToString made of
    /// anything else when setTimeout was called.
    handler: runtime.WindowTimerHandler,
    /// `any... arguments`, passed to a Function handler on every run. OWNED
    /// handles, in a slice from the wrapper's allocator.
    arguments: []runtime.JSValue,
    /// The realm the timer was set in - the Window whose method was called.
    /// Not owned: the context manager keeps a realm until teardown, and a
    /// destroyed window's timers go with it (clearWindowState).
    realm: runtime.Context,
    /// Whether this is an interval (repeating) timer - affects cleanup
    is_interval: bool,
    /// The timeout after conversion and step 4 (negative becomes 0), before
    /// the nesting clamp: an interval re-runs the timer initialization steps
    /// with it, and each repeat clamps afresh.
    timeout_ms: i64 = 0,
    /// The id setTimeout/setInterval returned, and this timer's key in
    /// its window's map of active timers. Stable for the timer's life (see scheduleTimer).
    id: TimerId = 0,
    /// The manager's id for the pending run. An interval gets a new one per
    /// repeat. While `held`, no native timer is armed and this is the wait
    /// still to go, in ms, instead: what was left when its document was
    /// suspended (`suspendWindowTimers`), 0 for one that came due inactive -
    /// kept here, not in a field of its own, so that the record stays the
    /// size a setTimeout(0) burst allocates 50,000 of.
    current_timer_id: TimerId = 0,
    /// For intervals: whether the interval has been cancelled
    cancelled: bool = false,
    /// This timer's nesting level, per the timer initialisation steps. While its
    /// callback runs, its agent's timer nesting level is set to this, so timers created inside
    /// nest one deeper and eventually trip the 4ms clamp.
    nesting_level: u32 = 0,
    /// True while this timer's callback is on the stack.
    ///
    /// A callback may cancel ITSELF - `clearInterval(id)` from inside the interval
    /// is ordinary JS, and testharness cleanups do it routinely. The handler is
    /// still executing on this wrapper at that moment, and destroys it again when
    /// the callback returns, so an unconditional free in unregisterTimerContext is
    /// a double free (and the freed wrapper's context pointer then surfaced as a
    /// 0xaa-poisoned segfault in destroyChildContext).
    ///
    /// While this is set, the running handler owns the wrapper and is the only
    /// thing allowed to free it.
    executing: bool = false,
    /// Where the timer is between its arming and its run (the ownership rule
    /// above). The size of the `held` flag it replaced: the record may not
    /// grow (the test below).
    state: TimerState = .armed,

    /// Return every handle this timer owns - once: a released record holds
    /// none (its handler is left a number), so `destroyTimer` after an early
    /// release (a queued timer cleared, `releaseQueued`) releases nothing.
    fn release(self: *WindowTimerData, allocator: std.mem.Allocator) void {
        switch (self.handler) {
            .function, .string => |handle| releaseValue(handle),
        }
        self.handler = .{ .function = .{ .number = 0 } };
        for (self.arguments) |argument| releaseValue(argument);
        allocator.free(self.arguments);
        self.arguments = &.{};
    }
};

/// WindowTimerData's shape before the back/forward cache (phase A): the
/// record a suspension may not grow (`WindowTimerData` test below).
const TimerDataBaseShape = struct {
    handler: runtime.WindowTimerHandler,
    arguments: []runtime.JSValue,
    realm: runtime.Context,
    is_interval: bool,
    timeout_ms: i64,
    id: TimerId,
    current_timer_id: TimerId,
    cancelled: bool,
    nesting_level: u32,
    executing: bool,
    held: bool,
};

test "a window timer's record is no larger than before the back/forward cache" {
    // A setTimeout(0) burst allocates 50,000 of these at once
    // (crane/bfa-cost-timers.html): 16 more bytes each measured 4-8%
    // slower there. A suspension asks the native timer for the wait still
    // to go (TimerInterface.remainingMs) instead of storing a due time.
    try std.testing.expectEqual(@sizeOf(TimerDataBaseShape), @sizeOf(WindowTimerData));
}

/// Type-safe timer callback wrapper for window timers.
///
/// Uses SelfContainedWorkCallback to bundle the callback function and context data
/// together, providing compile-time type safety and eliminating manual
/// anyopaque casts in callback functions. The work callback variant stores
/// the allocator internally for no-argument destroy().
const WindowTimerCallback = SelfContainedWorkCallback(WindowTimerData);

/// Free a timer wrapper and every handle it owns. EVERY path that frees one
/// goes through here; `wrapper.destroy()` alone leaks the handles.
fn destroyTimer(wrapper: *WindowTimerCallback) void {
    wrapper.getData().release(wrapper.allocator);
    wrapper.destroy();
}

/// A queued timer cleared - by clearTimeout, or its window's end: marked
/// `cancelled` (its task runs nothing, step 8.2) and its handles released
/// now, while its realm lives; its task frees the record (the ownership rule
/// at WindowTimerData). Never while its handler runs: a running timer is
/// .armed again.
fn releaseQueued(wrapper: *WindowTimerCallback) void {
    const data = wrapper.getData();
    data.cancelled = true;
    data.release(wrapper.allocator);
}

/// Timer initialization step 8's task, steps 8.3-8.5: run the handler in the
/// timer's realm, at the timer's nesting level. A task runs from the event
/// loop, so the realm is entered for it.
fn runTimerTask(data: *WindowTimerData) void {
    // (No dom.bfcache.assertNotCached here: a cached page's timers are
    // suspended at store - suspendWindowTimers - and one that fires anyway
    // waits in the event loop's queue while its document is inactive.
    // That guard is the check, and the assertion's cost showed on the
    // setTimeout(0) burst cost page.)
    engine.runTaskInRealm(data.realm, runTimerSteps, data) catch |err| {
        log.debug("a timer's task did not run: {}", .{err});
    };
}

fn runTimerSteps(opaque_data: ?*anyopaque) void {
    const data: *WindowTimerData = @ptrCast(@alignCast(opaque_data orelse return));

    // Step 8.4: "Let settings object be global's relevant settings object.
    // If scripting is disabled for settings object, then abort these
    // steps" - for a Window whose document is sandboxed without
    // allow-scripts, whoever set the timer (an embedder reaching in with
    // allow-same-origin, through frame.contentWindow.setTimeout).
    if (realmWindow(data.realm)) |window| {
        if (interfaces.Window.get_document(window) catch null) |document| {
            if (dom_mod.document_scripts.scriptsSandboxed(document)) return;
        }
    }

    // The "current timer nesting level" is this timer's level for the DURATION OF
    // THE CALLBACK ONLY, so timers the callback creates nest one deeper. It is
    // restored before the microtask checkpoint the caller performs: per HTML the
    // checkpoint runs after the task's callback returns, so a timer scheduled from a
    // microtask must NOT inherit the task's nesting level and must not be clamped to
    // 4ms. (wpt: html/webappapis/timers/timer-nesting-not-inherited-in-microtask.html)
    const level = timerNestingLevel(data.realm);
    const saved_nesting = if (level) |l| l.* else 0;
    if (level) |l| l.* = data.nesting_level;
    defer if (level) |l| {
        l.* = saved_nesting;
    };

    // Runs ahead of any microtask the callback enqueues; see resetNestingMicrotask.
    if (level) |l| if (data.realm.agent) |agent| engine.queueMicrotask(agent, resetNestingMicrotask, l) catch {};

    // This handler owns the wrapper for the duration of the callback, so a
    // clearTimeout/clearInterval from inside it defers the free to us.
    data.executing = true;
    defer data.executing = false;

    switch (data.handler) {
        // Step 8.4: invoke handler given arguments and "report", with callback
        // this value set to thisArg (the WindowProxy).
        .function => |function| invokeReporting(data.realm, function, data.arguments),
        // Step 8.5: create a classic script from the string - with the
        // settings object's API base URL, for a Window its document's base
        // URL, which is also where its errors are reported from - and run it.
        .string => |source| {
            const window = realmWindow(data.realm) orelse return;
            // Step 10.8.2's CSP check ran at the call instead
            // (initializeTimer, a stated deviation): a handler here was
            // allowed then.
            const base_url = apiBaseUrl(data.realm, window);
            defer base_url.deinit();
            engine.runClassicScript(data.realm, .{ .string = source }, base_url.url, null, windowReporter(data.realm)) catch |err| switch (err) {
                // Reported for the Window already (step 8.3).
                error.ExceptionReported => {},
                else => log.debug("a timer's string handler did not run: {}", .{err}),
            };
        },
    }
}

/// A Window's API base URL: its document's base URL (HTML 8.1.3.2) - the
/// frozen base URL of its first `<base href>`, else the document's URL - and
/// for an about:blank document, the URL its realm was navigated to.
const ApiBaseUrl = struct {
    url: []const u8,
    /// Set when `url` is a copy the document's allocator made.
    allocator: ?std.mem.Allocator = null,

    fn deinit(self: ApiBaseUrl) void {
        if (self.allocator) |a| a.free(self.url);
    }
};

fn apiBaseUrl(realm: runtime.Context, window: *runtime.Instance) ApiBaseUrl {
    const fallback = ApiBaseUrl{ .url = realm.documentUrl() orelse "" };
    const document = interfaces.Window.get_document(window) catch return fallback;
    const base = interfaces.Node.get_baseURI(document) catch return fallback;
    if (base.len == 0 or std.mem.eql(u8, base, "about:blank")) {
        document.ctx.allocator.free(base);
        return fallback;
    }
    return .{ .url = base, .allocator = document.ctx.allocator };
}

/// HTML "run steps after a timeout" step 4.1: a Window's timer waits "until
/// global's associated Document has been fully active for a further
/// milliseconds milliseconds (not necessarily consecutively)", and the task
/// its completion step queues is a global task, not runnable while that
/// document is not fully active. So a timer that comes due while its
/// window's document is inactive - not fully active, and it may be again
/// (dom.document_activity) - is HELD: its handler does not run, and it keeps
/// its place in the map of active timers, with no native timer behind it,
/// until reactivation re-arms it (phase B) or its window's map is cleared.
/// Whether it was held. WebKit suspends a document's timers the same way,
/// keeping each one's remaining interval (EventLoopTaskGroup::suspend,
/// EventLoopTimer::suspend). A gone document's timers are as before: its
/// destroy clears its window's map (clearWindowState).
/// Timer initialization steps 10-13: the timer's timeout has completed -
/// its native timer fired (runtime.native_timer, polled by the event loop's
/// step 4) - so "queue a global task on the timer task source given global to
/// run task" (step 13; step 12's ordering wait is the native timers'
/// deadline order). The task's document is the Window (a global task on a
/// Window: its associated Document decides when it runs, and an inactive one
/// keeps it in place - the back/forward cache - while a gone one drops it,
/// HTML 8.1.7.1). From here the task owns the timer's run and its record
/// (`WindowTimerData.state` .queued; the ownership rule is at
/// `WindowTimerData`). A timer used to run its handler right here, from the
/// poll, ahead of every task the running task had queued before it -
/// Chromium's sequence manager gives a delayed task its place in the queue
/// when it becomes ready (DOMTimer posts to the timer task runner), after the
/// running task, so those come first.
fn timerFired(data: *WindowTimerData) void {
    const wrapper: *WindowTimerCallback = @fieldParentPtr("data", data);
    // Cleared while its native timer could not be confirmed cancelled
    // (`unregisterTimerContext`): the record was handed to this callback.
    if (data.cancelled) return destroyTimer(wrapper);
    // A realm with no Window or no event loop - an engine test's - has no
    // task queue to queue on: the task runs now.
    if (!queueTimerTask(wrapper)) runQueuedTimer(wrapper);
}

/// Timer initialization step 13 for `wrapper`: "queue a global task on the
/// timer task source given global to run task" - the task's document is the
/// Window, whose associated Document decides when it runs (an inactive one
/// keeps it in place, the back/forward cache; a gone one drops it, HTML
/// 8.1.7.1). From here the task holds the record (`TimerState.queued`).
/// False, queueing nothing, for a realm with no Window or no event loop.
fn queueTimerTask(wrapper: *WindowTimerCallback) bool {
    const data = wrapper.getData();
    const window = realmWindow(data.realm) orelse return false;
    const loop = data.realm.getOptionalEventLoop() orelse return false;
    data.state = .queued;
    // No native timer stands behind a queued one.
    data.current_timer_id = 0;
    loop.queueTask(.{
        .callback = &runQueuedTimer,
        .context = wrapper,
        .drop = &dropQueuedTimer,
        .document = window,
        .document_generation = runtime.SlabAllocator.generationOf(window),
    });
    return true;
}

/// Timer initialization steps 11-13 for a timer whose timeout is 0 after
/// step 5's clamp: "run steps after a timeout" has nothing to wait for, so
/// its completion step - queueing the task - happens now, at the call, and
/// the task takes its place among the tasks queued so far: after every task
/// queued before setTimeout was called, before every task queued after.
/// Chromium and Gecko do this: Blink's DOMTimer gives a zero timeout
/// TaskType::kJavascriptTimerImmediate, TimerBase::Start gives it a null
/// fire time, and the sequence manager posts a task with no delay as an
/// immediate one (TaskQueueImpl::PostTask: PostedTask::is_delayed() false,
/// PostImmediateTaskImpl), queued at the call; Gecko's
/// TimeoutExecutor::Schedule dispatches its runnable at once when the
/// deadline has passed (ScheduleImmediate). WebKit fires a run-loop timer
/// instead (EventLoopTimer::fired). A timer that waits - a timeout above 0,
/// or one clamped to 4 ms - is armed, and queues its task when it fires
/// (`timerFired`). Step 4.2's order holds: every zero-timeout timer set
/// before this one was queued at its own call.
///
/// The id is reserved from the agent's timer manager (TimerInterface
/// .reserveId), the counter armed timers take theirs from, so the window's
/// map never has one id twice. The id, entered in the map; 0 when the map
/// could not take it (the wrapper is freed); null when this realm cannot
/// queue it now (no Window, no event loop, no id to reserve) - the caller
/// arms it.
fn queueAtCall(timer: TimerInterface, wrapper: *WindowTimerCallback) ?TimerId {
    const data = wrapper.getData();
    if (realmWindow(data.realm) == null or data.realm.getOptionalEventLoop() == null) return null;
    const id = timer.reserveId() orelse return null;
    data.id = id;
    TimerMap.of(data.realm).put(id, wrapper) catch {
        destroyTimer(wrapper);
        return 0;
    };
    _ = queueTimerTask(wrapper);
    return id;
}

/// The timer's task (timer initialization step 8, run from the event loop).
fn runQueuedTimer(context: ?*anyopaque) void {
    const wrapper: *WindowTimerCallback = @ptrCast(@alignCast(context orelse return));
    const data = wrapper.getData();
    data.state = .armed;
    // Step 8.2: "If id does not exist in global's map of setTimeout and
    // setInterval IDs, then abort these steps" - cleared while its task
    // waited, or its window ended (whose end released its handles already).
    if (data.cancelled) return destroyTimer(wrapper);
    if (data.is_interval) intervalSteps(data) else timeoutSteps(data);
}

/// The timer's task will never run: its window is gone (HTML 8.1.7.1), or
/// its event loop ended with the task queued.
fn dropQueuedTimer(context: ?*anyopaque) void {
    const wrapper: *WindowTimerCallback = @ptrCast(@alignCast(context orelse return));
    const data = wrapper.getData();
    // Not cleared: its window's map still names it, and that map is alive - a
    // window's end clears the map first, cancelling every timer in it
    // (`clearWindowState`, `endWindowTimers`).
    if (!data.cancelled) {
        const map = TimerMap.of(data.realm);
        if (map.get(data.id) == wrapper) _ = map.remove(data.id);
    }
    destroyTimer(wrapper);
}

/// Steps 8.3-8.9 for a setTimeout timer's task.
fn timeoutSteps(data: *WindowTimerData) void {
    // Step 8.9: remove global's map[id]. Before the run rather than after, so a
    // clearTimeout(id) from inside the callback finds nothing to free under us.
    _ = TimerMap.of(data.realm).remove(data.id);

    // Steps 8.3-8.5. The handler's microtasks run inside them: invoking it,
    // or running its string, ends with "clean up after running script",
    // whose step 3 performs the microtask checkpoint when the JavaScript
    // execution context stack is empty, as it is in a task (WebIDL "invoke
    // a callback function" step 14; HTML "run a classic script" step 9).
    // The event loop's own checkpoint follows the task (HTML 8.1.7.3, the
    // drain's checkpointAfterTask). A third, here, found the queue empty on
    // every firing: one checkpoint per timer more than main ran, and part of
    // the setTimeout(0) burst's cost (lane loadpath1).
    runTimerTask(data);

    // Destroy the wrapper - this is a one-shot timer, so clean up after execution
    // Get the wrapper pointer from the data pointer (data is embedded in SelfContainedCallback)
    const wrapper: *WindowTimerCallback = @fieldParentPtr("data", data);
    destroyTimer(wrapper);
}

/// Steps 8.3-8.8 for a setInterval timer's task: the handler, then, if the
/// id is still in the map, the timer initialization steps again.
fn intervalSteps(data: *WindowTimerData) void {
    const wrapper: *WindowTimerCallback = @fieldParentPtr("data", data);

    // Steps 8.3-8.5, the handler's microtasks included (`timeoutSteps`).
    runTimerTask(data);

    // Steps 8.6-8.8: still in the map - not cleared by the callback or its
    // microtasks - so run the timer initialization steps again, given the
    // same id. Step 3 there: the running task is this timer's, so its nesting
    // level is this one's, and step 5 clamps with it; step 9 nests one deeper.
    if (!data.cancelled) {
        if (data.realm.timer) |timer| {
            const delay: u64 = @intCast(clampTimeout(data.timeout_ms, data.nesting_level));
            data.nesting_level +|= 1;
            // A zero timeout: the task is queued again now (`queueAtCall`),
            // under the same id.
            if (delay == 0 and queueTimerTask(wrapper)) return;
            const new_timer_id = timer.setTimeout(delay, WindowTimerCallback.getTrampolineCallback(), wrapper.eraseForFFI());
            if (new_timer_id != 0) {
                // The id script holds stays the key; only the pending run changes.
                data.current_timer_id = new_timer_id;
                return;
            }
        }
    }

    // Cancelled, or it could not be rescheduled: this was its last run.
    const map = TimerMap.of(data.realm);
    if (map.get(data.id) == wrapper) _ = map.remove(data.id);
    destroyTimer(wrapper);
}

/// The timer initialization steps for setTimeout and setInterval, after the
/// engine's WebIDL conversion (`runtime.WindowOperations.initializeTimer`).
/// `handler` and every element of `arguments` are handed over.
///
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#timer-initialisation-steps
fn initializeTimer(realm: runtime.Context, handler: runtime.WindowTimerHandler, timeout: i32, arguments: []const runtime.JSValue, repeat: bool) i32 {
    // Owned until the timer takes them.
    var owned = true;
    defer if (owned) {
        switch (handler) {
            .function, .string => |handle| releaseValue(handle),
        }
        for (arguments) |argument| releaseValue(argument);
    };

    // Not in the spec, stated: a string handler is checked by CSP here, at
    // the call, and not by step 10.8.2 when the timer fires
    // (EnsureCSPDoesNotBlockStringCompilation(realm, « », handler, handler,
    // timer, « », handler), whose EvalError the spec reports for the
    // global). An enforced policy that blocks it reports its violation and
    // the call returns 0, scheduling nothing and reporting no exception; a
    // report-only one reports and the timer is set. That is what all three
    // engines do - Blink's DOMTimer::setTimeout/setInterval (IsAllowed:
    // ContentSecurityPolicy::AllowEval, kReport, kWillNotThrowException,
    // then `return 0`), Gecko's nsGlobalWindowInner::SetTimeoutOrInterval
    // (CSPEvalChecker::CheckForWindow: GetAllowsEval, LogViolationDetails,
    // `return 0`) and WebKit's LocalDOMWindow::setTimeout/setInterval
    // (ContentSecurityPolicy::allowEval, `return 0`) - and what WPT asserts:
    // unsafe-eval/eval-scripts-set{Timeout,Interval}-blocked.sub.html expect
    // the id 0, and files that call setTimeout(string) under such a policy
    // expect no error event (the spec's report made testharness end them
    // in ERROR). A blocked interval is thereby checked once, as the engines
    // do. (Step 1's Trusted Types step is not run yet: a TrustedScript
    // reaches here already a string.)
    switch (handler) {
        .function => {},
        .string => |source| if (realmWindow(realm)) |window| {
            const text = engine.convertToDOMString(realm, source, window.ctx.allocator) catch return 0;
            defer window.ctx.allocator.free(text);
            if (!html_mod.code_generation.timerHandlerAllowed(window, text)) return 0;
        },
    }

    // The window's timers run on its agent's loop, and are its realm's.
    const timer = realm.timer orelse return 0;
    const allocator = realm.allocator;

    // Step 3: this timer's nesting level is one deeper than the running
    // task's, if that task is a timer's; 0 otherwise.
    const nesting: u32 = if (timerNestingLevel(realm)) |level| level.* else 0;
    // Step 4: a negative timeout is 0.
    const timeout_ms: i64 = @max(timeout, 0);

    const kept = allocator.dupe(runtime.JSValue, arguments) catch return 0;
    const wrapper = WindowTimerCallback.create(allocator, &timerFired, .{
        .handler = handler,
        .arguments = kept,
        .realm = realm,
        .is_interval = repeat,
        .timeout_ms = timeout_ms,
        // Steps 9-10.
        .nesting_level = nesting + 1,
    }) catch {
        allocator.free(kept);
        return 0;
    };
    // The wrapper owns them now; destroyTimer releases them.
    owned = false;

    // Step 5: the 4ms clamp past nesting level 5. Steps 11-14: schedule, and
    // return the id - a zero timeout's task queued now (`queueAtCall`).
    const delay: u64 = @intCast(clampTimeout(timeout_ms, nesting));
    if (delay == 0) {
        if (queueAtCall(timer, wrapper)) |queued| return @intCast(@as(u32, @truncate(queued)));
    }
    const id = scheduleTimer(timer, wrapper, delay) orelse return 0;
    return @intCast(@as(u32, @truncate(id)));
}

/// clearTimeout(id) and clearInterval(id): one algorithm, "clear the timer
/// with id from the map of setTimeout and setInterval IDs", so either clears
/// either kind.
fn clearTimer(realm: runtime.Context, id: i32) void {
    if (id <= 0) return;
    // The map, and nothing but the map, decides what an id names - and it is
    // THIS window's map: an id another window's timer holds names nothing
    // here. The function's realm is the window whose method this is.
    if (TimerMap.of(realm).get(@intCast(id)) == null) return;
    unregisterTimerContext(realm, @intCast(id));
}

/// Context type for determining which globals to register
/// The condition `spinEventLoopUntil` waits for: `met(context)` is asked
/// between turns of the event loop. It must not run script.
pub const SpinGoal = struct {
    context: *anyopaque,
    met: *const fn (context: *anyopaque) bool,
};

/// How `spinEventLoopUntil` ended.
pub const SpinOutcome = enum {
    /// The goal was met.
    met,
    /// `timeout_ms` passed first.
    timed_out,
};

/// HTML "spin the event loop" until `goal` is met (8.1.7.3), for a host
/// that waits from outside any task (Browser.spinEventLoopUntil says how):
/// the loop's turns run until `goal` is met or `timeout_ms` (real time)
/// passes. error.Reentrant from inside a turn of the loop.
pub fn spinEventLoopUntil(event_loop: *EventLoop, goal: SpinGoal, timeout_ms: u64) !SpinOutcome {
    if (event_loop.in_run_once) return error.Reentrant;
    // Real time, whatever the Browser's clock: a virtual clock stands
    // still while nothing is due, and a goal nothing will meet must still
    // end (lesson architecture-a-clock-that-stands-still-must-be-woken-
    // to-the-exact-deadline.md).
    const platform = @import("platform");
    const deadline_ns = platform.monotonicNow().ns +| timeout_ms *| std.time.ns_per_ms;
    while (true) {
        if (goal.met(goal.context)) return .met;
        const now_ns = platform.monotonicNow().ns;
        if (now_ns >= deadline_ns) return .timed_out;
        _ = event_loop.runOnceBlocking(std.math.divCeil(u64, deadline_ns - now_ns, std.time.ns_per_ms) catch 1);
    }
}

pub const ContextType = enum {
    /// Window context (for HTML pages)
    window,
    /// Dedicated worker context
    worker,
    /// Shared worker context
    shared_worker,
    /// Service worker context
    service_worker,
};

/// One page navigation: its realm - a Window's - made in the Browser's agent,
/// which every navigation shares.
pub const Context = struct {
    allocator: std.mem.Allocator,
    /// The agent the page's realm lives in: the Browser's (BORROWED).
    agent: *engine.Agent,
    /// The page's realm, a Window's; null only while it is being made.
    realm: ?runtime.Context = null,
    /// Storage subsystem (shared across navigations)
    storage: *Storage,
    /// The Browser's cookie jar (BORROWED): the page's top-level browsing
    /// context gets it as its Window is made.
    cookie_jar: ?*cookiestore.CookieJar,
    /// Current URL
    url: []const u8,
    /// Context type
    context_type: ContextType,
    /// Whether context is ready for execution
    initialized: bool,
    /// The Browser's timers and event loop, shared by all its pages
    /// (BORROWED); the realm records both.
    timer: ?runtime.TimerInterface,
    event_loop: ?runtime.EventLoop,
    /// Make the realm from the engine's snapshot, when the agent has one.
    from_snapshot: bool,
    /// The Browser's scope and its loop's cross-thread inbox, which the realm
    /// carries (runtime.ContextData.browser_scope, .task_sink). BORROWED.
    browser_scope: ?*runtime.BrowserScope = null,
    task_sink: ?*runtime.TaskSink = null,

    // Singleton instances for cleanup
    window_instance: ?*runtime.Instance = null,
    document_instance: ?*runtime.Instance = null,
    navigator_instance: ?*runtime.Instance = null,
    location_instance: ?*runtime.Instance = null,
    history_instance: ?*runtime.Instance = null,
    performance_instance: ?*runtime.Instance = null,
    /// How many documents the page's navigations have committed
    /// (`traversableCommitted`): an embedder's load waits for it to move.
    commits: u64 = 0,
    /// Whether the last of them was a network error's error page.
    committed_error_page: bool = false,
    /// The page's top-level browsing context, which its first Window made
    /// and handed over: every Window of the page shows it. Owned by
    /// `traversable` once that exists; by the Context only when no record
    /// could be made.
    browsing_context: ?*html_mod.BrowsingContext = null,
    /// The page's top-level traversable (dom.top_level_traversables): the
    /// navigable record that owns its top-level browsing context, session
    /// history and WindowProxy record across every Window its loads make.
    /// OWNED; null for a worker page, or when no record could be made.
    traversable: ?*anyopaque = null,

    /// Make the page's realm in `agent` and give it what a page's Window has.
    ///
    /// `agent` is the Browser's agent and `event_loop` its event loop (whose
    /// timers the realm shares; browser/event_loop.zig). `from_snapshot`
    /// restores the realm from the engine's snapshot, when the agent was made
    /// from one; otherwise every interface is defined afresh.
    pub fn init(
        allocator: std.mem.Allocator,
        agent: anytype,
        storage: *Storage,
        cookie_jar: ?*cookiestore.CookieJar,
        url: []const u8,
        event_loop: anytype,
        context_type: ContextType,
        from_snapshot: bool,
        browser_scope: ?*runtime.BrowserScope,
    ) !*Context {
        log.debug("[Context.init] {s}", .{url});

        const ctx = try allocator.create(Context);
        errdefer allocator.destroy(ctx);

        const url_copy = try allocator.dupe(u8, url);

        ctx.* = Context{
            .allocator = allocator,
            .agent = @ptrCast(agent),
            .storage = storage,
            .cookie_jar = cookie_jar,
            .url = url_copy,
            .context_type = context_type,
            .initialized = false,
            .timer = if (event_loop) |ev| ev.timerInterface() else null,
            .event_loop = if (event_loop) |ev| ev.eventLoop() else null,
            .from_snapshot = from_snapshot,
            .browser_scope = browser_scope,
            .task_sink = if (event_loop) |ev| ev.taskSink() else null,
        };

        // A realm, or a traversable, made before a later step failed ends
        // with the page (`deinit` frees what exists, and the URL).
        ctx.createRealm() catch |err| {
            ctx.deinit();
            return err;
        };
        return ctx;
    }

    /// HTML "create a new realm" for the page's Window (engine.createWindowRealm),
    /// then what a Window global has beyond its interfaces: its document,
    /// navigator, location and performance, its timers and animation frames.
    fn createRealm(self: *Context) !void {
        // The realm of the initial about:blank document (HTML "create a new
        // browsing context and document" step 10): its creation URL is
        // about:blank, whatever URL the page will navigate to.
        const realm = engine.createWindowRealm(&self.windowRealmOptions(.new_window_proxy, null, "about:blank")) catch |err| {
            log.debug("the page's realm was not made: {}", .{err});
            return error.ContextCreateFailed;
        };
        self.realm = realm;
        // The inbox other threads post the realm's tasks to.
        realm.task_sink = self.task_sink;

        // __internal and GLOBAL, before the singletons stored in __internal.
        self.setupGlobalAliases() catch |err| {
            log.debug("setupGlobalAliases failed: {} - continuing", .{err});
        };

        try self.registerBrowserGlobals(realm);

        self.initialized = true;
    }

    /// HTML "create a new realm" for a Window of the page whose global this
    /// is `global_this` - a new WindowProxy (the page's first realm), or the
    /// page's WindowProxy (a later document's: "create and initialize a
    /// Document object" step 7) - made for a document at `document_url` whose
    /// origin is `origin` (serialized; null for an opaque one).
    fn windowRealmOptions(self: *Context, global_this: engine.GlobalThis, origin: ?[]const u8, document_url: []const u8) engine.WindowRealmOptions {
        return .{
            .agent = self.agent,
            .allocator = self.allocator,
            .from_snapshot = self.from_snapshot,
            .timer = self.timer,
            .event_loop = self.event_loop,
            .origin = origin,
            .global_this = global_this,
            // The realm's Browser, recorded before its Window is made.
            .browser_scope = self.browser_scope,
            .create_global_object = createWindow,
            // HTML IsPlatformObjectSameOrigin, which the engine asks on every
            // access to this realm's WindowProxy or Locations from another
            // realm [cross_origin_objects]; without it, the Window's own
            // checks (Window.get_document).
            .is_platform_object_same_origin = if (engine.capabilities.cross_origin_objects != .unsupported) dom_mod.cross_origin.isPlatformObjectSameOrigin else null,
            .report_window_access = if (engine.capabilities.window_access_reporting != .unsupported) dom_mod.coop_reporting.checkAccess else null,
            .host = self,
            // HTML 8.1.3.5, for [SecureContext] exposure (WebIDL 3.3.13):
            // the document the realm is made for is this URL's, with no
            // parent or creator (html.secure_context.ofDocument). Out of
            // memory answers not secure - the realm then exposes less, never
            // more. A realm kept for its initial about:blank document's
            // successor ("create and initialize a Document object" step 6)
            // keeps this creation answer; the Window's isSecureContext asks
            // its document each time.
            .secure_context = html_mod.secure_context.ofDocument(self.allocator, .{ .url = document_url, .parent = null, .creator = null }) catch false,
        };
    }

    /// HTML "create a new realm", the customization for the global object: the
    /// page's Window, bound to `global_this` (BORROWED until the realm ends).
    fn createWindow(realm: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        const self: *Context = @ptrCast(@alignCast(host orelse return null));
        const window = interfaces.Window.init(self.allocator, realm) catch |err| {
            log.debug("the page's Window was not made: {}", .{err});
            return null;
        };
        self.window_instance = window;

        // HTML 7.3.1.2: the page's top-level browsing context - its first
        // Window made it and hands it over, for it outlives every Window the
        // page's loads make (dom.top_level_traversables) - with this Window
        // its active window: what frames[index], contentWindow.parent and the
        // WindowProxy's [[GetOwnProperty]] read.
        if (self.browsing_context == null) {
            self.browsing_context = @ptrCast(@alignCast(dom_mod.window_globals.releaseBrowsingContext(window)));
        }
        if (self.browsing_context) |bc| {
            dom_mod.window_globals.adoptBrowsingContext(window, @ptrCast(bc));
            // The page's top-level browsing context has the Browser's
            // cookie jar; its frames reach it through it.
            bc.cookie_jar = self.cookie_jar;
        }
        // The global the Window is bound to, for cross-realm access.
        switch (global_this) {
            .handle => |h| dom_mod.window_globals.bind(window, h.ptr),
            else => {},
        }
        return window;
    }

    fn registerBrowserGlobals(self: *Context, realm: runtime.Context) !void {
        const window = self.window_instance orelse return error.NotInitialized;
        const global: runtime.JSValue = .{ .instance = window };

        switch (self.context_type) {
            .window => try self.registerWindowGlobals(realm, global),
            .worker => try self.registerWorkerGlobals(realm, global),
            else => {},
        }

        // Register common globals (setTimeout, fetch, console, etc.)
        try registerCommonGlobals(realm);
    }

    /// The Window's singletons - Document, Navigator, Location, Performance -
    /// linked to it, and each stored in `__internal` as well (see
    /// setupGlobalAliases). History is made by Window.get_history on first
    /// use, linked to the window's browsing context, whose traversable keeps
    /// the session history (HTML 7.2.5).
    fn registerWindowGlobals(self: *Context, realm: runtime.Context, global: runtime.JSValue) !void {
        // HTML "create a new top-level traversable": the record that keeps
        // the page's browsing context, session history and WindowProxy
        // record from now on, across every Window its loads make - and its
        // step 3, "create a new browsing context and document" given a null
        // creator: the initial about:blank document, made by the same steps
        // as every navigable's (an iframe's, a popup's), of a new opaque
        // origin ("determining the origin" given about:blank and a null
        // creatorOrigin), as a new tab's initial empty document is in
        // Chrome, Firefox and Safari. It is the browsing context's active
        // document, and its Window's associated Document.
        const window = self.window_instance orelse return error.NotInitialized;
        const bc = self.browsing_context orelse return error.NotInitialized;
        self.traversable = dom_mod.top_level_traversables.create(self.allocator, window, @ptrCast(bc), .{
            .context = self,
            .create_window_realm = &realmForTraversableDocument,
            .document_created = &traversableDocumentCreated,
            .committed = &traversableCommitted,
        }) orelse return error.ContextCreateFailed;
        const document: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveDocument() orelse return error.ContextCreateFailed));
        self.showInitialDocument(realm, document);
        try self.registerWindowSingletons(realm, global);
    }

    /// What a Window of the page has from its realm's creation: its
    /// Navigator, Location (HTML 7.2.1: made with the Window, in its realm)
    /// and Performance - each made by the Window's own getter, so in its
    /// realm and kept by it - also stored in `__internal`, and the
    /// HTMLDocument alias of Document.
    fn registerWindowSingletons(self: *Context, realm: runtime.Context, global: runtime.JSValue) !void {
        const internal = engine.getProperty(realm, global, "__internal") catch |err| {
            log.debug("__internal is not on the global: {}", .{err});
            return error.ObjectNotFound;
        };
        defer internal.release();

        const win = self.window_instance orelse return error.NotInitialized;

        const nav_instance = interfaces.Window.get_navigator(win) catch |err| {
            log.debug("the navigator was not made: {}", .{err});
            return;
        };
        self.navigator_instance = nav_instance;
        storeInternal(realm, internal.value, "navigator", nav_instance);

        const loc_instance = interfaces.Window.get_location(win) catch |err| {
            log.debug("the location was not made: {}", .{err});
            return;
        };
        self.location_instance = loc_instance;
        storeInternal(realm, internal.value, "location", loc_instance);

        const perf_instance = interfaces.Window.get_performance(win) catch |err| {
            log.debug("the performance object was not made: {}", .{err});
            return;
        };
        self.performance_instance = perf_instance;
        storeInternal(realm, internal.value, "performance", perf_instance);

        const document_interface = engine.getProperty(realm, global, "Document") catch return;
        defer document_interface.release();
        engine.defineOwnProperty(realm, global, "HTMLDocument", document_interface.value, .{
            .writable = true,
            .enumerable = false,
            .configurable = true,
        }) catch |err| log.debug("HTMLDocument was not defined: {}", .{err});
    }

    fn storeInternal(realm: runtime.Context, internal: runtime.JSValue, name: []const u8, instance: *runtime.Instance) void {
        engine.setProperty(realm, internal, name, .{ .instance = instance }) catch |err| {
            log.debug("__internal.{s} was not stored: {}", .{ name, err });
        };
    }

    /// The page's initial about:blank `document` (HTML "create a new
    /// browsing context and document"): `document_instance` and
    /// `__internal.document`. Every later document is a navigation's
    /// (`showDocument`).
    fn showInitialDocument(self: *Context, realm: runtime.Context, document: *runtime.Instance) void {
        const window = self.window_instance orelse return;
        self.document_instance = document;
        if (engine.getProperty(realm, .{ .instance = window }, "__internal")) |internal| {
            defer internal.release();
            storeInternal(realm, internal.value, "document", document);
        } else |err| log.debug("__internal is not on the global: {}", .{err});
    }

    fn registerWorkerGlobals(self: *Context, realm: runtime.Context, global: runtime.JSValue) !void {
        engine.defineOwnProperty(realm, global, "self", global, .{
            .writable = true,
            .enumerable = true,
            .configurable = true,
        }) catch |err| log.debug("self was not defined: {}", .{err});

        const nav_instance = interfaces.WorkerNavigator.init(self.allocator, realm) catch |err| {
            log.debug("the worker navigator was not made: {}", .{err});
            return;
        };
        engine.setProperty(realm, global, "navigator", .{ .instance = nav_instance }) catch |err| {
            log.debug("navigator was not stored: {}", .{err});
        };
    }

    /// Register common globals (setTimeout, fetch, console, etc.)
    fn registerCommonGlobals(realm: runtime.Context) !void {
        // setTimeout, setInterval, their clears and the animation frame
        // methods, bound by the engine over this file's steps - on this window
        // and on every frame's.
        try engine.installWindowOperations(realm, &window_operations);

        // NOTE: console object is registered via WebIDL namespace binding in snapshot
        // (see bindings.zig initializeNamespaces -> Console.registerGlobal)
        // The native binding provides proper console.log/error/etc with output to stderr

        // NOTE: getComputedStyle is now properly defined on Window.prototype via WebIDL binding.
        // The Window.call_getComputedStyle implementation creates a proper CSSStyleDeclaration
        // with named property handlers for CSS property access (e.g., style.borderStyle).
        // Do NOT register a stub here - it would shadow the proper implementation.

        // addEventListener, removeEventListener and dispatchEvent are EventTarget's
        // WebIDL operations, own properties of the global (WebIDL 3.8, [Global]) as
        // on every frame's window. Native bindings used to overwrite them here -
        // from before those operations were on the global - and they resolved the
        // Window from the realm rather than `this`, returned true for a
        // dispatchEvent argument that is no Event, and swallowed InvalidStateError.
    }

    /// Set up global aliases via JavaScript
    /// Per WebIDL spec, window properties use accessor properties with proper this validation
    fn setupGlobalAliases(self: *Context) !void {
        const setup_script = switch (self.context_type) {
            .window =>
            // Window context: Set up __internal for singleton storage and GLOBAL for WPT tests
            // NOTE: Do NOT set self or window here! They are accessor properties registered by
            // registerPropertiesAsOwnOnObject() via the Window interface. Setting them here
            // would overwrite the accessor with a data property, breaking the getter mechanism.
            // NOTE: Do NOT try to set parent, top, opener, frames, length here!
            // These are read-only accessor properties defined by Window interface bindings.
            // The Window impl handles returning the correct values for these properties.
            \\globalThis.__internal = globalThis.__internal || { isSecureContext: false };
            \\globalThis.GLOBAL = {
            \\  isWindow: function() { return true; },
            \\  isWorker: function() { return false; },
            \\  isShadowRealm: function() { return false; }
            \\};
            \\
            \\// NOTE: document, navigator, location, history, performance are exposed via
            \\// the Window interface's attribute getters. We only set up __internal for
            \\// storage, and the Window impl's getters retrieve from there.
            ,
            .worker =>
            // Dedicated worker context: self, navigator, location
            \\function __checkGlobalThis(thisArg, propName) {
            \\  if (thisArg === null || thisArg === undefined) {
            \\    return globalThis;
            \\  }
            \\  if (thisArg === globalThis) {
            \\    return globalThis;
            \\  }
            \\  throw new TypeError("'" + propName + "' called on an object that does not implement interface DedicatedWorkerGlobalScope.");
            \\}
            \\
            \\Object.defineProperty(globalThis, 'self', {
            \\  get: function() { return __checkGlobalThis(this, 'self'); },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Set up GLOBAL object for WPT tests - WORKER context
            \\globalThis.GLOBAL = {
            \\  isWindow: function() { return false; },
            \\  isWorker: function() { return true; },
            \\  isShadowRealm: function() { return false; },
            \\};
            ,
            .shared_worker, .service_worker =>
            // Shared/Service worker context: only self, no window
            \\function __checkGlobalThis(thisArg, propName) {
            \\  if (thisArg === null || thisArg === undefined) {
            \\    return globalThis;
            \\  }
            \\  if (thisArg === globalThis) {
            \\    return globalThis;
            \\  }
            \\  throw new TypeError("'" + propName + "' called on an object that does not implement interface WorkerGlobalScope.");
            \\}
            \\
            \\Object.defineProperty(globalThis, 'self', {
            \\  get: function() { return __checkGlobalThis(this, 'self'); },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Set up GLOBAL object for WPT tests - WORKER context
            \\globalThis.GLOBAL = {
            \\  isWindow: function() { return false; },
            \\  isWorker: function() { return true; },
            \\  isShadowRealm: function() { return false; },
            \\};
            ,
        };

        self.runScript(setup_script) catch |err| {
            log.debug("ERROR: Failed to set up global aliases: {}\n", .{err});
            return err;
        };
    }

    /// HTML "navigate" the page's top-level traversable to `url` - the
    /// embedder's own "browser UI" navigation of the page it shows, as an
    /// address bar navigates a tab: the same traversable (its session history
    /// gains an entry, its WindowProxy keeps its identity), beforeunload, the
    /// fetch and the commit as the navigation's tasks - run the event loop
    /// for them (`loadPage` and `loadHTML` wait for them). The next document
    /// gets a new Window unless the page shows its initial about:blank
    /// document of the same origin (create and initialize a Document object
    /// steps 6-7). error.NoTraversable for a page with no record.
    pub fn navigate(self: *Context, url: []const u8) !void {
        const record = self.traversable orelse return error.NoTraversable;
        const serialized = serializedUrlOf(self.allocator, url);
        defer if (serialized) |s| self.allocator.free(s);
        dom_mod.top_level_traversables.navigate(record, serialized orelse url, .{});
    }

    /// `url` parsed and serialized; null when it does not parse.
    fn serializedUrlOf(allocator: std.mem.Allocator, url: []const u8) ?[]u8 {
        var record = @import("basic_parser").parse(allocator, url, null) catch return null;
        defer record.deinit();
        return @constCast(@import("url_serializer").serialize(allocator, &record, false) catch return null);
    }

    /// dom.top_level_traversables: HTML "create and initialize a Document
    /// object" step 7 for a document of `origin` that one of the page's
    /// navigations - the embedder's own, Location, a hyperlink, a form, a
    /// javascript: URL, a reload, a traversal - is about to commit: the realm
    /// of a new Window around the page's WindowProxy (`replaceRealm`). Step
    /// 6, keeping the initial about:blank's Window for a document same
    /// origin-domain with it, is the record's, as for every navigable.
    fn realmForTraversableDocument(context: *anyopaque, origin: html_mod.Origin, url: []const u8) bool {
        const self: *Context = @ptrCast(@alignCast(context));
        var buffer: [512]u8 = undefined;
        const serialized: ?[]const u8 = if (origin.is_opaque) null else (if (origin.port) |port|
            std.fmt.bufPrint(&buffer, "{s}://{s}:{d}", .{ origin.scheme, origin.host, port }) catch null
        else
            std.fmt.bufPrint(&buffer, "{s}://{s}", .{ origin.scheme, origin.host }) catch null);
        // The realm's creation URL is the new document's: its secure context
        // answer ([SecureContext] exposure) is that URL's, sandboxed to an
        // opaque origin or not.
        self.replaceRealm(url, serialized) catch return false;
        return true;
    }

    /// dom.top_level_traversables: one of the page's navigations made
    /// `document` its Window's associated Document ("create and initialize a
    /// Document object" step 10), before its parser runs - the page's
    /// document, and URL, from here.
    fn traversableDocumentCreated(context: *anyopaque, document_ptr: *anyopaque) void {
        const self: *Context = @ptrCast(@alignCast(context));
        self.showDocument(@ptrCast(@alignCast(document_ptr)));
    }

    /// dom.top_level_traversables: one of the page's navigations committed
    /// `document`. `error_page`: the navigation's response was a network
    /// error, whose document is an error page.
    fn traversableCommitted(context: *anyopaque, document_ptr: *anyopaque, error_page: bool) void {
        const self: *Context = @ptrCast(@alignCast(context));
        self.commits +%= 1;
        self.committed_error_page = error_page;
        self.showDocument(@ptrCast(@alignCast(document_ptr)));
    }

    /// `document` is the page's: `document_instance`, `__internal.document`
    /// and the page's URL.
    fn showDocument(self: *Context, document: *runtime.Instance) void {
        self.document_instance = document;
        if (self.realm) |realm| if (self.window_instance) |window| {
            if (engine.getProperty(realm, .{ .instance = window }, "__internal")) |internal| {
                defer internal.release();
                storeInternal(realm, internal.value, "document", document);
            } else |_| {}
        };
        const url = interfaces.Document.get_URL(document) catch return;
        defer document.ctx.allocator.free(url);
        self.setUrl(url) catch {};
    }

    /// Script loader callback type for external script loading
    /// Returns script content for the given URL, or null if loading failed
    pub const ScriptLoaderFn = @import("html").parser_script_execution.ScriptLoaderFn;

    /// Script loader interface for customizing how external scripts are loaded
    pub const ScriptLoader = @import("html").scripted_parser.ScriptLoader;

    /// How long an embedder's load waits, in real time, for its navigation
    /// by default: as long as a page load may take in a WebDriver session
    /// (its default page load timeout, 300,000 ms).
    pub const default_load_timeout_ms: u64 = 300_000;

    /// Options for loadPage
    pub const LoadPageOptions = struct {
        /// The embedder's answer for the external classic scripts of the
        /// document the load commits (not its frames' - html.embedder_scripts
        /// answers for those): the WPT runner's testharnessreport.js, as
        /// wptrunner's server answers that path.
        script_loader: ?ScriptLoader = null,
        /// How long to wait for the navigation, in real time.
        timeout_ms: u64 = default_load_timeout_ms,
    };

    /// The page's load of its own URL (`url`, given to `init`): HTML
    /// "navigate" its top-level traversable there with user involvement
    /// "browser UI" (`loadByNavigating`). A page at about:blank stays on its
    /// initial about:blank document, as a browser's new tab opened at
    /// about:blank does.
    pub fn loadPage(self: *Context) !void {
        return self.loadPageWithOptions(.{});
    }

    /// `loadPage` with options.
    pub fn loadPageWithOptions(self: *Context, options: LoadPageOptions) !void {
        if (std.mem.eql(u8, self.url, "about:blank")) return;
        const url = try self.allocator.dupe(u8, self.url);
        defer self.allocator.free(url);
        return self.loadByNavigating(url, null, options.script_loader, options.timeout_ms);
    }

    /// Options for HTML loading
    pub const LoadHTMLOptions = struct {
        /// The URL of the document the markup makes.
        base_url: []const u8,
        /// The embedder's answer for the document's external classic
        /// scripts (LoadPageOptions.script_loader).
        script_loader: ?ScriptLoader = null,
        /// How long to wait for the navigation, in real time.
        timeout_ms: u64 = default_load_timeout_ms,
    };

    /// The page's load of markup the embedder supplies, as a document at
    /// `options.base_url`: HTML "navigate" its top-level traversable there
    /// with user involvement "browser UI" and the markup as the navigation's
    /// response (navigate's `response` argument) - never fetched - as
    /// WebKit's loadHTMLString (SubstituteData) and Chromium's
    /// LoadDataWithBaseURL load a page their embedder supplies
    /// (`loadByNavigating`).
    ///
    /// ## Example
    /// ```zig
    /// try ctx.loadHTML("<div id=test>Hello</div><script>window.found = document.getElementById('test').textContent;</script>", .{ .base_url = "https://example.test/" });
    /// const result = try ctx.evaluateScriptToString("window.found", allocator); // "Hello"
    /// ```
    pub fn loadHTML(self: *Context, html_content: []const u8, options: LoadHTMLOptions) !void {
        return self.loadByNavigating(options.base_url, html_content, options.script_loader, options.timeout_ms);
    }

    /// An embedder's load of the page: HTML "navigate" its top-level
    /// traversable to `url` with user involvement "browser UI" - no
    /// sourceDocument, the user agent's own navigation (navigate step 5) -
    /// and `markup` as its response when the embedder supplies the document,
    /// then the event loop run until the traversable settles: no navigation
    /// in flight - this one, or one the page's script started as it loaded -
    /// and the page's document parsed as far as its parser can go (its
    /// readiness no longer "loading", or its parser waiting for a pending
    /// parsing-blocking script: `LoadWait`), or the navigation ended
    /// without a document (a 204, a download), or
    /// `timeout_ms` passed. As CDP's Page.navigate, a navigation that commits
    /// a network error's error page fails with error.NetworkError.
    ///
    /// This is the one way the page gets a document: the first one is a
    /// navigation from the initial about:blank document "create a new
    /// top-level traversable" made, as Chrome, Firefox and Safari load a new
    /// tab - its Window is kept only when that document's origin is same
    /// origin-domain with the new one's ("create and initialize a Document
    /// object" step 6), which an embedder's traversable's opaque initial
    /// about:blank never is. A load asked for from inside a task of the
    /// page's loop - a script loader the parser called - only starts the
    /// navigation: its tasks run after the one that asked.
    fn loadByNavigating(self: *Context, url: []const u8, markup: ?[]const u8, script_loader: ?ScriptLoader, timeout_ms: u64) !void {
        const record = self.traversable orelse return error.NoTraversable;
        const serialized = serializedUrlOf(self.allocator, url);
        defer if (serialized) |s| self.allocator.free(s);
        const before = self.commits;
        dom_mod.top_level_traversables.navigate(record, serialized orelse url, .{
            .markup = markup,
            .script_loader = if (script_loader) |loader| dom_mod.top_level_traversables.ScriptLoader{ .context = loader.context, .load = loader.loadScript, .retain = loader.retain, .release = loader.release } else null,
        });
        const realm = self.realm orelse return error.NotInitialized;
        const loop = EventLoop.of(realm) orelse return;
        if (loop.in_run_once) return;
        var wait: LoadWait = .{ .context = self, .record = record, .before = before };
        switch (try spinEventLoopUntil(loop, .{ .context = &wait, .met = LoadWait.met }, timeout_ms)) {
            .met => {},
            .timed_out => return error.NavigationTimedOut,
        }
        if (self.commits == before) return error.NavigationAborted;
        if (self.committed_error_page) return error.NetworkError;
    }

    /// What `loadByNavigating` waits for.
    const LoadWait = struct {
        context: *Context,
        record: *anyopaque,
        /// The page's commit count when the navigation started.
        before: u64,

        fn met(opaque_self: *anyopaque) bool {
            const self: *LoadWait = @ptrCast(@alignCast(opaque_self));
            // A navigation in flight - this one, or one the page's own
            // script started as it loaded (WebDriver's page load waits for an
            // ongoing navigation to mature the same way) - is waited for.
            if (dom_mod.top_level_traversables.isNavigating(self.record)) return false;
            // None: it ended without a document, or the page's document has
            // committed and its parser has run as far as it can - through
            // every byte of the response, to readiness "interactive" ("the
            // end" step 1) or later, or to a pending parsing-blocking script
            // it waits for (HTML "an end tag whose tag name is script": the
            // parser spins the event loop there until the script is ready,
            // which may be never - a stylesheet blocking it that nobody
            // answers). The host's wait ends where its parser's would, as it
            // did when the embedder's load parsed in place: what the page does
            // after that is the event loop's, which the host runs.
            if (self.context.commits == self.before) return true;
            const document = self.context.document_instance orelse return true;
            const state = interfaces.Document.get_readyState(document) catch return true;
            if (state != ._loading_) return true;
            const scripts = dom_mod.document_scripts.of(document) orelse return false;
            return scripts.pending_parsing_blocking_script != null;
        }
    };

    /// HTML "create and initialize a Document object" step 7 for the page's
    /// next document, at `url` and of origin `origin` (serialized; null for
    /// an opaque one): "create a new realm" whose global object is a new
    /// Window and whose global this binding is the page's WindowProxy
    /// (engine.createWindowRealm .window_proxy_of: V8 detaches the proxy from
    /// the old context and builds the new one around it - Blink's
    /// LocalWindowProxy::DisposeContext(kGlobalObjectIsDetached), then
    /// CreateContext with its saved global_proxy_; WebKit's
    /// WindowProxy::setDOMWindow). Every holder of the WindowProxy - a
    /// popup's opener, a MessageEvent's source, a saved `window` - reaches
    /// the new Window from here. The new Window shows the page's browsing
    /// context, and the traversable's documents and navigations go in its
    /// realm.
    ///
    /// The old realm is handed to the engine: its document was unloaded and
    /// destroyed first, its Window lives on while script reaches anything of
    /// the realm, and the engine ends it once the collector takes it or with
    /// the page (engine.WindowRealmEnd.global_detached) - winslot1 returns
    /// its Window's slot then.
    ///
    /// [reuse_window_proxy] unsupported (JavaScriptCore, QuickJS): the
    /// declared fallback keeps the page's one Window.
    fn replaceRealm(self: *Context, url: []const u8, origin: ?[]const u8) !void {
        if (comptime engine.capabilities.reuse_window_proxy == .unsupported) return;
        const old = self.realm orelse return error.NotInitialized;
        const old_window = self.window_instance;
        const realm = engine.createWindowRealm(&self.windowRealmOptions(.{ .window_proxy_of = old }, origin, url)) catch |err| {
            self.window_instance = old_window;
            log.debug("the page's next realm was not made: {}", .{err});
            return error.ContextCreateFailed;
        };
        self.realm = realm;
        // The inbox other threads post the realm's tasks to.
        realm.task_sink = self.task_sink;
        self.document_instance = null;
        self.navigator_instance = null;
        self.location_instance = null;
        self.history_instance = null;
        self.performance_instance = null;
        // __internal and GLOBAL, then what a Window of the page has from its
        // realm's creation, then the window operations.
        self.setupGlobalAliases() catch |err| {
            log.debug("setupGlobalAliases failed: {} - continuing", .{err});
        };
        if (self.window_instance) |window| try self.registerWindowSingletons(realm, .{ .instance = window });
        try registerCommonGlobals(realm);
        if (self.traversable) |record| dom_mod.top_level_traversables.attachRealm(record, realm);
        // The popups the old Window opened move with the page's navigable:
        // the new Window keeps them, and their next realms are made under the
        // new realm (lane newwin1, B7).
        if (old_window) |from| if (self.window_instance) |to| dom_mod.window_globals.moveAuxiliaryNavigables(from, to);
        engine.destroyWindowRealm(old, .global_detached);
    }

    /// Set the context URL (updates location object)
    fn setUrl(self: *Context, url: []const u8) !void {
        // Update internal URL
        // IMPORTANT: Check if url points to self.url (same slice) to avoid use-after-free.
        // This can happen when loadHTML is called with base_url = self.url.
        // An equal URL keeps the slice too: loadPage passes its own copy, and
        // a slice of self.url borrowed before the load stays valid.
        if (url.ptr == self.url.ptr or std.mem.eql(u8, url, self.url)) {
            // URL is already set to this value, nothing to do
            return;
        }
        // Duplicate first, then free old to avoid use-after-free if url somehow
        // references memory that would be affected by the free
        const new_url = try self.allocator.dupe(u8, url);
        self.allocator.free(self.url);
        self.url = new_url;

        // Note: Location object URL is set during context initialization
        // and via JavaScript. Direct impl access would require Location.setHref
        // which isn't currently exposed. For now, the URL is tracked in Context.url.
        _ = self.location_instance;
    }

    /// Evaluate `script` - host code: the harness, WebDriver, the REPL - for
    /// its effects. What it throws is logged, and fails the call with
    /// `error.ExceptionReported`.
    pub fn runScript(self: *Context, script: []const u8) !void {
        const realm = self.realm orelse return error.NotInitialized;
        try engine.runClassicScript(realm, .{ .utf8 = script }, "", null, hostScriptReporter());
    }

    /// Evaluate `script` (host code) and return its completion value, OWNED:
    /// `release` it - a leaked one that holds an object keeps the page alive.
    /// Use `runScript` to discard it. What it throws is logged, and fails the
    /// call with `error.ExceptionReported`.
    pub fn evaluateScript(self: *Context, script: []const u8) !engine.Owned {
        const realm = self.realm orelse return error.NotInitialized;
        return engine.evaluateClassicScript(realm, .{ .utf8 = script }, "", null, hostScriptReporter());
    }

    /// Evaluate `script` (host code) and return its completion value's
    /// ToString, allocated with `allocator`.
    pub fn evaluateScriptToString(self: *Context, script: []const u8, allocator: std.mem.Allocator) ![]u8 {
        const realm = self.realm orelse return error.NotInitialized;
        return engine.evaluateClassicScriptToString(realm, .{ .utf8 = script }, "", null, allocator, hostScriptReporter());
    }

    /// A host script is not the page's: what it throws is a runner-level
    /// failure, logged at warn - the runner's level - and never reported to
    /// the page's Window.
    fn hostScriptReporter() engine.Reporter {
        return .{ .report = logHostScriptException };
    }

    fn logHostScriptException(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
        log.warn("a host script threw: {s} ({s}:{d}:{d})", .{ info.message, info.filename, info.lineno, info.colno });
    }

    /// The end of the page: its agent's mutation observer state, its timers,
    /// then its realm
    /// (engine.destroyWindowRealm, which follows Blink's
    /// LocalWindowProxy::DisposeContext).
    pub fn deinit(self: *Context) void {
        log.debug("[Context.deinit] {s}", .{self.url});

        // The page's agent's pending mutation observers and signal slots go
        // while their nodes live - the page is every window of the Browser's
        // agent - so that nothing accumulates across navigations. The agent's
        // only (AgentHost.mutation_observers): another Browser's on the thread
        // is its own.
        if (self.realm) |realm| mutation_observer_algorithms.resetAgent(realm);

        // (Instance lifecycle flags live in each instance's slab slot and go
        // with it: nothing of the page's to clear here.)

        // The page's animation frame callbacks end with it, and its window's
        // timers - its own map of active timers, and no other window's -
        // before the realm ends, so that none fires into it.
        if (self.realm) |realm| {
            rendering.endPage(realm);
            endWindowTimers(realm);
        }

        // NOTE: Do NOT explicitly deinit singleton instances here! The
        // realm's end cleans up its wrapper cache, which frees each instance;
        // deinit'ing them here as well is a double free.
        self.document_instance = null;
        self.navigator_instance = null;
        self.location_instance = null;
        self.history_instance = null;
        self.performance_instance = null;

        // The end of the page's realm (engine.destroyWindowRealm): its
        // Window, document and frames torn down, its WindowProxy detached,
        // its context released - Blink's LocalWindowProxy::DisposeContext
        // order. Its document is destroyed first: the unloading document
        // cleanup steps other specifications define run for it (its frames'
        // run as their realms end, clearWindowState).
        if (self.realm) |realm| {
            dom_mod.unloading_cleanup.run(realm);
            engine.destroyWindowRealm(realm, .global_detached);
            self.realm = null;
        }
        // The traversable goes once every Window it showed is gone: it frees
        // the browsing context they read - or, with no record, the Context
        // does.
        if (self.traversable) |record| {
            dom_mod.top_level_traversables.destroy(record);
        } else if (self.browsing_context) |bc| bc.deinit();
        self.traversable = null;
        self.browsing_context = null;

        self.allocator.free(self.url);
        self.initialized = false;
    }
};

test "a browser started without a snapshot builds its realm afresh and runs a page" {
    // JavaScriptCore has no snapshots, so this is the startup path it runs on:
    // every WebIDL interface defined afresh on the realm's global
    // (engine.createWindowRealm with from_snapshot false). The WebDriver
    // session starts its browser this way too.
    const allocator = std.testing.allocator;
    const Browser = @import("Browser.zig").Browser;
    const browser = try Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try std.testing.expect(!browser.isUsingSnapshot());

    const ctx = browser.current_context orelse return error.NoContext;
    try ctx.loadHTML(
        \\<!doctype html><title>start</title><div id=d>parsed</div>
        \\<script>
        \\  var seen = document.getElementById('d').textContent;
        \\  setTimeout(function () {
        \\    seen += '|timer';
        \\    requestAnimationFrame(function (now) {
        \\      globalThis.result = document.title + '|' + seen + '|frame:' + typeof now;
        \\    });
        \\  }, 0);
        \\</script>
    , .{ .base_url = "https://example.test/page.html" });
    try browser.runEventLoop(500);
    // The parser, a timer and an animation frame ran in the page's realm.
    const result = try ctx.evaluateScriptToString("globalThis.result", allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("start|parsed|timer|frame:number", result);

    // The global is the page's Window, its members its own (WebIDL 3.8).
    const shape = try ctx.evaluateScriptToString("[globalThis instanceof Window, self === globalThis, typeof addEventListener, document instanceof Document].join()", allocator);
    defer allocator.free(shape);
    try std.testing.expectEqualStrings("true,true,function,true", shape);
}
