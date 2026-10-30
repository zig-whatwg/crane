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
const navigation = @import("navigation.zig");
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
// Thread-local storage for timer interface (mirrors browser_context.zig pattern)
// ============================================================================

threadlocal var current_timer_interface: ?TimerInterface = null;
threadlocal var current_allocator: ?std.mem.Allocator = null;
threadlocal var timer_contexts: ?TimerMap = null;

/// The window's map of active timers (HTML 8.6), by the id script holds.
/// Every timer is a key it never saw - ids only grow - put when armed and
/// removed when it runs its last time or is cleared: a
/// runtime.native_timer.TimerIdMap, which rehashes its tombstones away
/// (before its guard the free slots ran out: a 1,069-file runner sample
/// found none free at capacity 8-16 in 219 of 1,272 samples, and every arm
/// walked the whole table) and gives back what a burst took (lane
/// timerheap1: 5,000 timers armed and cleared left 8,192 slots that every
/// later window's end walked, clearWindowState). Every insert and removal
/// goes through here. Values are `*WindowTimerCallback`, their own
/// allocations; no iteration of the map runs script, so no insert - which
/// only script makes (`scheduleTimer`), and before which alone the map is
/// rehashed or rebuilt - meets a live iterator.
const TimerMap = struct {
    ids: runtime.native_timer.TimerIdMap(*WindowTimerCallback) = .empty,
    allocator: std.mem.Allocator,

    const Ids = runtime.native_timer.TimerIdMap(*WindowTimerCallback);

    fn init(allocator: std.mem.Allocator) TimerMap {
        return .{ .allocator = allocator };
    }

    fn deinit(self: *TimerMap) void {
        self.ids.deinit(self.allocator);
    }

    fn put(self: *TimerMap, id: TimerId, wrapper: *WindowTimerCallback) !void {
        try self.ids.put(self.allocator, id, wrapper);
    }

    fn remove(self: *TimerMap, id: TimerId) bool {
        return self.ids.remove(id);
    }

    fn fetchRemove(self: *TimerMap, id: TimerId) ?Ids.KV {
        return self.ids.fetchRemove(id);
    }

    fn get(self: *const TimerMap, id: TimerId) ?*WindowTimerCallback {
        return self.ids.get(id);
    }

    fn count(self: *const TimerMap) usize {
        return self.ids.count();
    }

    /// The slots a walk of the map reads (clearWindowState,
    /// activeTimerHandles, the suspension and its resumption).
    fn capacity(self: *const TimerMap) usize {
        return self.ids.capacity();
    }

    fn iterator(self: *const TimerMap) Ids.Iterator {
        return self.ids.iterator();
    }

    fn clearRetainingCapacity(self: *TimerMap) void {
        self.ids.clearRetainingCapacity();
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
    const saved_interface = current_timer_interface;
    const saved_allocator = current_allocator;
    const saved_contexts = timer_contexts;
    defer {
        current_timer_interface = saved_interface;
        current_allocator = saved_allocator;
        timer_contexts = saved_contexts;
    }
    const manager = try runtime.native_timer.NativeTimerManager.init(allocator);
    defer manager.deinit();
    current_timer_interface = manager.timerInterface();
    current_allocator = allocator;
    timer_contexts = TimerMap.init(allocator);
    defer timer_contexts.?.deinit();

    const id: TimerId = @intCast(initializeTimer(&realm, .{ .function = .{ .number = 1 } }, 10, &.{}, false));
    const interval: TimerId = @intCast(initializeTimer(&realm, .{ .function = .{ .number = 2 } }, 10, &.{}, true));
    const elsewhere: TimerId = @intCast(initializeTimer(&other, .{ .function = .{ .number = 3 } }, 10, &.{}, false));
    try std.testing.expect(id != 0 and interval != 0 and elsewhere != 0);

    // Both of `realm`'s come due while its window's document is inactive:
    // their native timers have fired, and they are held.
    for ([_]TimerId{ id, interval }) |key| {
        const data = timer_contexts.?.get(key).?.getData();
        try std.testing.expect(manager.clearTimeout(data.current_timer_id));
        holdTimer(data);
        try std.testing.expect(data.held);
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
    try std.testing.expect(timer_contexts.?.get(id) == null);
    // A held interval: the same (clearInterval, or its window's end, which
    // clears the map through the same unregistering).
    clearTimer(&realm, @intCast(interval));
    try std.testing.expect(timer_contexts.?.get(interval) == null);
    // Another window's timer is untouched, and still armed.
    try std.testing.expect(timer_contexts.?.get(elsewhere) != null);
    clearTimer(&other, @intCast(elsewhere));
    try std.testing.expectEqual(@as(usize, 0), timer_contexts.?.count());
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
    const saved_interface = current_timer_interface;
    const saved_allocator = current_allocator;
    const saved_contexts = timer_contexts;
    defer {
        current_timer_interface = saved_interface;
        current_allocator = saved_allocator;
        timer_contexts = saved_contexts;
    }
    const manager = try runtime.native_timer.NativeTimerManager.init(allocator);
    defer manager.deinit();
    current_timer_interface = manager.timerInterface();
    current_allocator = allocator;
    timer_contexts = TimerMap.init(allocator);
    defer timer_contexts.?.deinit();

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
                const map = &timer_contexts.?.ids.map;
                if (!webidl.utils.tombstones.slotCounts(map).halfOfUnusedFree()) starved += 1;
                worst = @max(worst, webidl.utils.tombstones.meanMissProbe(map));
            }
        }
        for (ids) |id| clearTimer(&realm, @intCast(id));
    }
    if (starved != 0 or worst > 8) {
        const counts = webidl.utils.tombstones.slotCounts(&timer_contexts.?.ids.map);
        std.debug.print("timer_contexts: {d} of 400 pages began with fewer than half the unused slots free; worst mean miss {d} (capacity {d}, live {d}, free {d})\n", .{ starved, worst, counts.capacity, counts.live, counts.free });
        return error.TombstonesFilledTheMap;
    }
    // The resident interval is still found after every rehash.
    try std.testing.expect(timer_contexts.?.get(resident) != null);
    try std.testing.expectEqual(@as(usize, 1), timer_contexts.?.count());
}

test "a window's map of active timers gives back what a burst of 5,000 took once the burst is gone" {
    // Lane timerheap1: a map never gives capacity back by itself, and every
    // window's end walks the whole of it (clearWindowState), as do unload
    // (activeTimerHandles) and the back/forward cache's suspension - so one
    // page's burst of timers made every later page's end walk its size.
    const allocator = std.testing.allocator;
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    const saved_interface = current_timer_interface;
    const saved_allocator = current_allocator;
    const saved_contexts = timer_contexts;
    defer {
        current_timer_interface = saved_interface;
        current_allocator = saved_allocator;
        timer_contexts = saved_contexts;
    }
    const manager = try runtime.native_timer.NativeTimerManager.init(allocator);
    defer manager.deinit();
    current_timer_interface = manager.timerInterface();
    current_allocator = allocator;
    timer_contexts = TimerMap.init(allocator);
    defer timer_contexts.?.deinit();

    const resident: TimerId = @intCast(initializeTimer(&realm, .{ .function = .{ .number = 1 } }, 3_600_000, &.{}, true));
    defer clearTimer(&realm, @intCast(resident));
    for (0..16) |_| clearTimer(&realm, initializeTimer(&realm, .{ .function = .{ .number = 2 } }, 60_000, &.{}, false));
    const before = timer_contexts.?.capacity();

    const burst = try allocator.alloc(i32, 5_000);
    defer allocator.free(burst);
    for (burst) |*id| id.* = initializeTimer(&realm, .{ .function = .{ .number = 3 } }, 60_000, &.{}, false);
    for (burst) |id| clearTimer(&realm, id);
    // The next timers the pages that follow set.
    for (0..16) |_| clearTimer(&realm, initializeTimer(&realm, .{ .function = .{ .number = 4 } }, 60_000, &.{}, false));

    const after = timer_contexts.?.capacity();
    if (after > @max(before, 64)) {
        std.debug.print("timer_contexts: capacity {d} after a burst of 5,000 had gone, against {d} before it\n", .{ after, before });
        return error.BurstKeptItsCapacity;
    }
    try std.testing.expect(timer_contexts.?.get(resident) != null);
    try std.testing.expectEqual(@as(usize, 1), timer_contexts.?.count());
}

test "a suspended timer keeps the wait it had left, and a resumed one is armed for it" {
    const allocator = std.testing.allocator;
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    var other = try runtime.ContextData.init(allocator, .{});
    defer other.deinit();
    const saved_interface = current_timer_interface;
    const saved_allocator = current_allocator;
    const saved_contexts = timer_contexts;
    defer {
        current_timer_interface = saved_interface;
        current_allocator = saved_allocator;
        timer_contexts = saved_contexts;
    }
    const manager = try runtime.native_timer.NativeTimerManager.init(allocator);
    defer manager.deinit();
    current_timer_interface = manager.timerInterface();
    current_allocator = allocator;
    timer_contexts = TimerMap.init(allocator);
    defer timer_contexts.?.deinit();

    const id: TimerId = @intCast(initializeTimer(&realm, .{ .function = .{ .number = 1 } }, 5_000, &.{}, false));
    const elsewhere: TimerId = @intCast(initializeTimer(&other, .{ .function = .{ .number = 2 } }, 5_000, &.{}, false));
    try std.testing.expect(id != 0 and elsewhere != 0);
    const armed = timer_contexts.?.get(id).?.getData().current_timer_id;

    // The page is kept: its timer's native timer is cancelled, and the wait
    // it had left is kept.
    suspendWindowTimers(&realm);
    const data = timer_contexts.?.get(id).?.getData();
    try std.testing.expect(data.held);
    try std.testing.expectEqual(@as(?u64, null), manager.remainingMs(armed));
    try std.testing.expect(data.current_timer_id > 4_000 and data.current_timer_id <= 5_000);
    // Another window's timer is untouched.
    try std.testing.expect(!timer_contexts.?.get(elsewhere).?.getData().held);

    // Restored: armed again for what it had left, not its whole timeout
    // from now and not at once.
    resumeWindowTimers(&realm);
    try std.testing.expect(!data.held);
    const left = manager.remainingMs(data.current_timer_id) orelse return error.NotArmed;
    try std.testing.expect(left > 4_000 and left <= 5_000);

    clearTimer(&realm, @intCast(id));
    clearTimer(&other, @intCast(elsewhere));
    try std.testing.expectEqual(@as(usize, 0), timer_contexts.?.count());
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
// path is this file -> the thread-local TimerInterface -> the Browser's event loop
// (browser/event_loop.zig) -> runtime.native_timer,
// which applied no clamping whatsoever. So the clamp is implemented here, at the
// setTimeout boundary, which is where the spec puts it: initialisation runs before
// the timer is handed to any scheduler.
//
// Thread-local because the nesting level belongs to the agent, and one agent is one
// thread with one isolate.

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
fn resetNestingMicrotask(_: ?*anyopaque) void {
    runtime.timer.nesting_level = 0;
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

/// Set the current timer interface
pub fn setTimerInterface(timer: TimerInterface, allocator: std.mem.Allocator) void {
    current_timer_interface = timer;
    current_allocator = allocator;
    // Initialize timer contexts map if needed
    if (timer_contexts == null) {
        timer_contexts = TimerMap.init(allocator);
    }
}

/// Get the current timer interface
pub fn getTimerInterface() ?TimerInterface {
    return current_timer_interface;
}

/// Clear the timer interface reference and clean up ALL pending timer contexts
/// This properly cancels libuv timers to prevent handle accumulation
pub fn clearTimerInterface() void {
    // Clean up any remaining timer contexts (both one-shot and intervals)
    if (timer_contexts) |*map| {
        var iter = map.iterator();
        while (iter.next()) |entry| {
            const wrapper = entry.value_ptr.*;
            // Cancel the timer at the libuv level to prevent callback from firing
            // and to properly clean up the libuv timer handle.
            //
            // The result is deliberately discarded: this is context teardown, so the
            // timer manager is going away with us and every wrapper must be freed
            // here or leak. Unlike unregisterTimerContext there is no later callback
            // to hand ownership to.
            // (A held one has no native timer: its current_timer_id is a wait.)
            if (current_timer_interface) |timer| if (!wrapper.getData().held) {
                _ = timer.clearTimeout(wrapper.getData().current_timer_id);
            };
            destroyTimer(wrapper);
        }
        map.deinit();
        timer_contexts = null;
    }

    // (The animation frame callbacks end with the page: Context.deinit's
    // rendering.endPage, before this.)

    // (The window operations the page's realm installed end with the realm:
    // destroyWindowRealm.)
    current_timer_interface = null;
    current_allocator = null;
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

    if (timer_contexts) |*map| {
        var doomed: std.ArrayListUnmanaged(TimerId) = .empty;
        defer if (current_allocator) |alloc| doomed.deinit(alloc);
        var iter = map.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.*.getData().realm != realm) continue;
            const alloc = current_allocator orelse break;
            doomed.append(alloc, entry.key_ptr.*) catch break;
        }
        // Not while iterating: unregistering removes from the map.
        for (doomed.items) |id| unregisterTimerContext(id);
    }

    // Its map of animation frame callbacks and its frame requests.
    rendering.windowDestroyed(realm);
}

/// dom.window_documents: the keys of `realm`'s window's map of active timers
/// (HTML "unload a document" step 16), OWNED by the caller - the ids its
/// setTimeout and setInterval returned, held ones included, in no order.
fn activeTimerHandles(realm: runtime.Context, allocator: std.mem.Allocator) error{OutOfMemory}![]TimerId {
    const map = if (timer_contexts) |*m| m else return &.{};
    var handles: std.ArrayListUnmanaged(TimerId) = .empty;
    errdefer handles.deinit(allocator);
    var iter = map.iterator();
    while (iter.next()) |entry| {
        if (entry.value_ptr.*.getData().realm != realm) continue;
        try handles.append(allocator, entry.key_ptr.*);
    }
    return handles.toOwnedSlice(allocator);
}

/// dom.window_documents: the back/forward cache keeps `realm`'s window's
/// document. Each of its timers stops - its native timer cancelled, how
/// long it still had to wait kept - and is HELD (`WindowTimerData.held`):
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
    const map = if (timer_contexts) |*m| m else return;
    const timer = current_timer_interface orelse return;
    var iter = map.iterator();
    while (iter.next()) |entry| {
        const data = entry.value_ptr.*.getData();
        if (data.realm != realm or data.held or data.cancelled or data.executing) continue;
        // The wait still to go, asked of the native timer before it is
        // cancelled - WebKit's SuspendableTimer saves its next-fire interval
        // the same way (m_savedNextFireInterval), and nothing is stored at
        // schedule time. A timer interface that cannot say ("unknown") makes
        // it due at once: it runs as soon as its page is restored.
        const remaining = timer.remainingMs(data.current_timer_id) orelse 0;
        // Not confirmed cancelled: its callback is on its way, and a timer
        // that comes due while its document is inactive is held there
        // (`holdIfInactive`).
        if (!timer.clearTimeout(data.current_timer_id)) continue;
        data.held = true;
        // A held timer's current_timer_id is its wait still to go.
        data.current_timer_id = remaining;
    }
}

/// dom.window_documents: HTML "reactivate" step 2 for `realm`'s window -
/// every held timer is armed again for what it still had to wait (0 for one
/// that came due while its document was inactive), and its animation frame
/// callbacks and pending autofocus candidates get a frame again.
fn resumeWindowTimers(realm: runtime.Context) void {
    if (timer_contexts) |*map| if (current_timer_interface) |timer| {
        var iter = map.iterator();
        while (iter.next()) |entry| {
            const wrapper = entry.value_ptr.*;
            const data = wrapper.getData();
            if (data.realm != realm or !data.held) continue;
            // A held timer's current_timer_id is its wait still to go.
            const id = timer.setTimeout(data.current_timer_id, WindowTimerCallback.getTrampolineCallback(), wrapper.eraseForFFI());
            // Not armed: it stays held, cleared or freed with its window.
            if (id == 0) continue;
            data.held = false;
            data.current_timer_id = id;
        }
    };
    rendering.windowResumed(realm);
}

/// Clear ALL pending timer contexts but keep the timer interface
/// This is used during test isolation to cancel timers without tearing down the interface
pub fn clearPendingTimers() void {
    if (timer_contexts) |*map| {
        var iter = map.iterator();
        while (iter.next()) |entry| {
            const wrapper = entry.value_ptr.*;
            // Cancel the timer at the libuv level (a held one has none: its
            // current_timer_id is a wait).
            if (current_timer_interface) |timer| if (!wrapper.getData().held) {
                _ = timer.clearTimeout(wrapper.getData().current_timer_id);
            };
            destroyTimer(wrapper);
        }
        map.clearRetainingCapacity();
    }
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
    const map = if (timer_contexts) |*m| m else {
        destroyTimer(wrapper);
        return null;
    };
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
fn unregisterTimerContext(timer_id: TimerId) void {
    if (timer_contexts) |*map| {
        if (map.fetchRemove(timer_id)) |kv| {
            const wrapper = kv.value;
            // Mark as cancelled so interval callbacks know to stop rescheduling.
            // This must happen before anything else: it is the only signal that
            // reaches a callback we could not cancel.
            wrapper.getData().cancelled = true;

            // Cancel at the libuv level so the callback cannot fire.
            //
            // The thread-local TimerInterface belongs to the realm calling
            // clearTimeout, which is NOT necessarily the realm that scheduled the
            // timer. Cross-realm, the id is unknown to this manager and nothing is
            // cancelled - clearTimeout used to return void, so that silent miss was
            // invisible and the wrapper was freed anyway. The armed timer then fired
            // on freed memory and destroyed it a second time: a double free, and a
            // 0xaa-poisoned segfault in destroyChildContext just after.
            //
            // So the wrapper is only freed when cancellation is CONFIRMED. Otherwise
            // ownership passes to the callback, which sees `cancelled` and destroys
            // it when it fires.
            const cancelled = if (wrapper.getData().held)
                // Held (holdIfInactive): no native timer is armed for it, and
                // no callback will come to free it.
                true
            else if (current_timer_interface) |timer|
                timer.clearTimeout(wrapper.getData().current_timer_id)
            else
                false;

            // Never free a wrapper whose callback is on the stack - that handler
            // still reads `data` after the callback returns and frees it itself.
            if (cancelled and !wrapper.getData().executing) destroyTimer(wrapper);
        }
    }
}

// ============================================================================
// Window timers
// ============================================================================

/// Everything one setTimeout or setInterval needs when it fires. The handler
/// and the arguments are OWNED engine handles - handed over by the binding -
/// and `release` returns them all. A timer used to hold its realm's context
/// as a handle too, which kept that page's whole heap alive until the timer
/// was freed; the realm is now the runtime.Context, which holds nothing.
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
    /// `timer_contexts`. Stable for the timer's life (see scheduleTimer).
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
    /// callback runs, `runtime.timer.nesting_level` is set to this, so timers created inside
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
    /// The timer came due while its window's document was not fully active,
    /// and may be again (`holdIfInactive`): it did not run, it stays in the
    /// map of active timers, and no native timer is armed for it - so
    /// clearing it frees it at once, and its window's end frees it with the
    /// rest. Re-armed when the document is reactivated (the back/forward
    /// cache's phase B; HTML "reactivate" step 2).
    held: bool = false,

    /// Return every handle this timer owns. Only `destroyTimer` calls it.
    fn release(self: *WindowTimerData, allocator: std.mem.Allocator) void {
        switch (self.handler) {
            .function, .string => |handle| releaseValue(handle),
        }
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

/// Timer initialization step 8's task, steps 8.3-8.5: run the handler in the
/// timer's realm, at the timer's nesting level. A task runs from the event
/// loop, so the realm is entered for it.
fn runTimerTask(data: *WindowTimerData) void {
    // (No dom.bfcache.assertNotCached here: a cached page's timers are
    // suspended at store - suspendWindowTimers - and one that fires anyway
    // is held by holdIfInactive before it gets here, its document inactive.
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
    const saved_nesting = runtime.timer.nesting_level;
    runtime.timer.nesting_level = data.nesting_level;
    defer runtime.timer.nesting_level = saved_nesting;

    // Runs ahead of any microtask the callback enqueues; see resetNestingMicrotask.
    if (data.realm.agent) |agent| engine.queueMicrotask(agent, resetNestingMicrotask, null) catch {};

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
fn holdIfInactive(data: *WindowTimerData) bool {
    const window = realmWindow(data.realm) orelse return false;
    if (dom_mod.document_activity.activity(window, runtime.SlabAllocator.generationOf(window)) != .inactive) return false;
    holdTimer(data);
    return true;
}

/// Hold a timer whose native timer has just fired (`holdIfInactive`).
fn holdTimer(data: *WindowTimerData) void {
    data.held = true;
    // The native timer that called here has fired: none is armed, and it is
    // due already - it runs as soon as it is armed again (a held timer's
    // current_timer_id is its wait still to go).
    data.current_timer_id = 0;
}

/// Handler function for one-shot timer callbacks (invoked via SelfContainedCallback trampoline)
fn timerHandler(data: *WindowTimerData) void {
    // Held while its window's document is inactive: still in the map, and
    // not run (holdIfInactive).
    if (holdIfInactive(data)) return;

    // Step 8.9: remove global's map[id]. Before the run rather than after, so a
    // clearTimeout(id) from inside the callback finds nothing to free under us.
    if (timer_contexts) |*map| {
        _ = map.remove(data.id);
    }

    runTimerTask(data);

    // Run microtasks after the timer callback (per event loop semantics)
    performMicrotaskCheckpoint(data.realm);

    // Destroy the wrapper - this is a one-shot timer, so clean up after execution
    // Get the wrapper pointer from the data pointer (data is embedded in SelfContainedCallback)
    const wrapper: *WindowTimerCallback = @fieldParentPtr("data", data);
    destroyTimer(wrapper);
}

/// Handler function for interval callbacks (invoked via SelfContainedCallback trampoline)
fn intervalHandler(data: *WindowTimerData) void {
    const wrapper: *WindowTimerCallback = @fieldParentPtr("data", data);

    // Check if interval was cancelled
    if (data.cancelled) {
        // unregisterTimerContext could not confirm cancellation (cross-realm), so it
        // left the wrapper alive and handed ownership here. Free it now - this is the
        // last time the timer system will reference it.
        return destroyTimer(wrapper);
    }

    // Held while its window's document is inactive: not run, and not
    // rescheduled (holdIfInactive).
    if (holdIfInactive(data)) return;

    runTimerTask(data);

    // Run microtasks after the timer callback
    performMicrotaskCheckpoint(data.realm);

    // Steps 8.6-8.8: still in the map - not cleared by the callback or its
    // microtasks - so run the timer initialization steps again, given the
    // same id. Step 3 there: the running task is this timer's, so its nesting
    // level is this one's, and step 5 clamps with it; step 9 nests one deeper.
    if (!data.cancelled) {
        if (getTimerInterface()) |timer| {
            const delay: u64 = @intCast(clampTimeout(data.timeout_ms, data.nesting_level));
            data.nesting_level +|= 1;
            const new_timer_id = timer.setTimeout(delay, WindowTimerCallback.getTrampolineCallback(), wrapper.eraseForFFI());
            if (new_timer_id != 0) {
                // The id script holds stays the key; only the pending run changes.
                data.current_timer_id = new_timer_id;
                return;
            }
        }
    }

    // Cancelled, or it could not be rescheduled: this was its last run.
    if (timer_contexts) |*map| {
        if (map.get(data.id) == wrapper) _ = map.remove(data.id);
    }
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

    const timer = getTimerInterface() orelse return 0;
    const allocator = current_allocator orelse return 0;

    // Step 3: this timer's nesting level is one deeper than the running
    // task's, if that task is a timer's; 0 otherwise.
    const nesting = runtime.timer.nesting_level;
    // Step 4: a negative timeout is 0.
    const timeout_ms: i64 = @max(timeout, 0);

    const kept = allocator.dupe(runtime.JSValue, arguments) catch return 0;
    const wrapper = WindowTimerCallback.create(allocator, if (repeat) &intervalHandler else &timerHandler, .{
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
    // return the id.
    const delay: u64 = @intCast(clampTimeout(timeout_ms, nesting));
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
    const map = if (timer_contexts) |*m| m else return;
    const wrapper = map.get(@intCast(id)) orelse return;
    if (wrapper.getData().realm != realm) return;
    unregisterTimerContext(@intCast(id));
}

/// Context type for determining which globals to register
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
    /// How many of the page's own parses are on the native stack
    /// (parseLoadDocument, parseXmlLoadDocument). A load asked for under one
    /// - a ScriptLoader loading another page - waits until the outermost
    /// returns (`pending_load`): no document is replaced, and no realm
    /// swapped, under a parser of the page or the script it runs. Blink
    /// detaches a document only once its construction site has left the
    /// stack (HTMLTreeBuilder::Detach keeps the open elements "because
    /// HTMLConstructionSite might be on the callstack").
    parse_depth: u32 = 0,
    /// The load asked for while a parse of the page was on the stack, run
    /// when the outermost one returns. OWNED.
    pending_load: ?*PendingLoad = null,
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

    // Debug counter for tracking context lifecycle
    var context_id_counter: u32 = 0;

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
        context_id_counter += 1;
        log.debug("[Context.init] #{d}: {s}", .{ context_id_counter, url });

        const ctx = try allocator.create(Context);
        errdefer allocator.destroy(ctx);

        const url_copy = try allocator.dupe(u8, url);
        errdefer allocator.free(url_copy);

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

        try ctx.createRealm();
        return ctx;
    }

    /// HTML "create a new realm" for the page's Window (engine.createWindowRealm),
    /// then what a Window global has beyond its interfaces: its document,
    /// navigator, location and performance, its timers and animation frames.
    fn createRealm(self: *Context) !void {
        const realm = engine.createWindowRealm(&self.windowRealmOptions(.new_window_proxy, null, self.url)) catch |err| {
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

        // HTML "create a new top-level traversable": the record that keeps
        // the page's browsing context, session history and WindowProxy record
        // from now on, across every Window its loads make.
        if (self.context_type == .window) {
            if (self.window_instance) |window| if (self.browsing_context) |bc| {
                self.traversable = dom_mod.top_level_traversables.create(self.allocator, window, @ptrCast(bc), .{
                    .context = self,
                    .realm_for_document = &realmForTraversableDocument,
                    .committed = &traversableCommitted,
                });
            };
        }

        // The timers this realm's Window sets run on the Browser's loop.
        if (self.timer) |timer| setTimerInterface(timer, self.allocator);

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
            .host = self,
            // HTML 8.1.3.5, for [SecureContext] exposure (WebIDL 3.3.13):
            // the document the realm is made for is this URL's, with no
            // parent or creator (html.secure_context.ofDocument). Out of
            // memory answers not secure - the realm then exposes less, never
            // more. A realm reused for its initial about:blank document's
            // successor keeps this creation answer; the Window's
            // isSecureContext asks its document each time.
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
        // The realm's first document: the top-level traversable's initial
        // about:blank document ("create a new browsing context and
        // document"), its Window's associated Document.
        const doc_instance = interfaces.Document.init(self.allocator, realm) catch |err| {
            log.debug("the initial about:blank document was not made: {}", .{err});
            return;
        };
        initializeInitialAboutBlank(doc_instance);
        self.associateDocument(realm, doc_instance, null);
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

    /// HTML "create a new browsing context and document" for the page's
    /// top-level traversable, the document's own steps: type "html" and
    /// content type "text/html" and "is initial about:blank" (step 15, which
    /// gives it quirks mode, and with it steps 21 and 24: ready for post-load
    /// tasks, completely loaded, readiness "complete"), then step 22,
    /// "populate with html/head/body". Steps 23-24 have nothing to wait for:
    /// a top-level traversable has no container to fire load at.
    fn initializeInitialAboutBlank(document: *runtime.Instance) void {
        dom_mod.document_internals.setDocumentType(document, .html) catch {};
        dom_mod.document_internals.setContentType(document, "text/html") catch {};
        dom_mod.document_lifecycle.markInitialAboutBlank(document);
        populateWithHtmlHeadBody(document) catch |err| {
            log.debug("the initial about:blank document was not populated: {}", .{err});
        };
    }

    /// HTML "populate with html/head/body": "1. Let html be the result of
    /// creating an element given document, "html", and the HTML namespace.
    /// 2. Let head be ... "head" ... 3. Let body be ... "body" ... 4. Append
    /// html to document. 5. Append head to html. 6. Append body to html."
    fn populateWithHtmlHeadBody(document: *runtime.Instance) !void {
        // Each element is appended as soon as it is made - nothing runs
        // script in between - so one that cannot be is freed, never leaked.
        const html = try createHtmlElement(document, "html");
        _ = interfaces.Node.call_appendChild(document, html) catch |err| {
            dom_mod.node_creation.destroyUninserted(html);
            return err;
        };
        for ([_][]const u8{ "head", "body" }) |local_name| {
            const element = try createHtmlElement(document, local_name);
            _ = interfaces.Node.call_appendChild(html, element) catch |err| {
                dom_mod.node_creation.destroyUninserted(element);
                return err;
            };
        }
    }

    /// "Creating an element given document, `local_name`, and the HTML
    /// namespace" - createElement's, for an HTML document.
    fn createHtmlElement(document: *runtime.Instance, local_name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElement(document, runtime.DOMString.initInterned(local_name), webidl.Opt(runtime.JSValue).notPassed());
    }

    /// Make `document` the page's: its Window's associated Document (HTML
    /// "create and initialize a Document object" step 10), which makes it
    /// the browsing context's active document and lets go of the document it
    /// replaces (Window.setDocument, through dom.window_globals); its
    /// browsing context the window's, so `defaultView` answers the window and
    /// the window keeps its wrapper (dom.document_browsing_context);
    /// `__internal.document`; and `document_instance`.
    ///
    /// The session history entries that showed `replaced` - the document it
    /// replaces, of this Window or of the Window before it - show this one:
    /// an entry names its document by pointer, and the replaced one is the
    /// collector's from here (an embedder's load into a Context commits no
    /// entry of its own yet; Browser.navigate makes a new Context).
    fn associateDocument(self: *Context, realm: runtime.Context, document: *runtime.Instance, replaced_document: ?*runtime.Instance) void {
        const window = self.window_instance orelse return;
        const previous = replaced_document;
        dom_mod.window_globals.setDocument(window, document);
        dom_mod.document_browsing_context.setWindow(document, window);
        self.document_instance = document;
        if (engine.getProperty(realm, .{ .instance = window }, "__internal")) |internal| {
            defer internal.release();
            storeInternal(realm, internal.value, "document", document);
        } else |err| log.debug("__internal is not on the global: {}", .{err});
        const replaced = previous orelse return;
        if (replaced == document) return;
        const navigable = dom_mod.browser_state.browsingContextOf(window) orelse return;
        const history = navigable.getTop().joint_history orelse return;
        history.forgetDocument(@ptrCast(replaced));
        // The page's traversable records the new document's own entry
        // (createLoadDocument); with no record, the entry that showed the
        // replaced document shows this one.
        if (self.traversable != null) return;
        if (history.currentEntry(navigable.id)) |entry| history.setDocumentOfState(entry.document_state, @ptrCast(document));
    }

    /// The page's current document goes, because a load replaces it, and
    /// the load keeps its Window (HTML "create and initialize a Document
    /// object" step 6: the initial about:blank document's successor). True
    /// when it was unloaded - and with it destroyed ("unload a document" step
    /// 20) - here; false when it is left for the caller to destroy.
    ///
    /// First HTML "abort a document": its active parser aborted, its
    /// parser-owned scripts discarded, its fetches canceled. Then, as the
    /// browsers do, "unload a document" - pagehide, visibilitychange and
    /// unload, then destroy - only for a document whose load event has run.
    /// Blink's Document::DispatchUnloadEvents stops the parser and returns
    /// at once while load_event_progress_ is kLoadEventNotRun; WebKit's
    /// FrameLoader::dispatchUnloadEvents fires them only after
    /// m_didCallImplicitClose. HTML's "unload" fires unload for any document
    /// that is not salvageable; Crane does what Chrome and Safari do. The
    /// initial about:blank document has completely loaded
    /// (markInitialAboutBlank), so the page's first load unloads it.
    ///
    /// Its storage is never freed here: script may hold its nodes. It is
    /// left to its wrapper (associateDocument made one when it became the
    /// window's), whose collection frees it, or the realm's end. No parser
    /// of it is on the native stack: a load asked for under one waits for it
    /// (`parse_depth`, `pending_load`).
    ///
    /// Not run, stated: the unloading document cleanup steps, keyed on the
    /// realm (dom.unloading_cleanup), which would end the new document's
    /// timers and sockets too - this document's successor keeps its Window.
    /// A load that replaces any other document gives its successor a new
    /// Window (`unloadForNewWindow`), whose old realm's steps all run.
    ///
    /// Abort and unload run script: a load that script starts replaces the
    /// document meanwhile, and that one goes too - the document replaced is
    /// whichever is current when no script runs any more
    /// (docs/lessons/architecture-associate-a-parser-after-the-last-reentrant-step.md).
    fn endCurrentDocument(self: *Context) bool {
        var rounds: usize = 0;
        while (self.document_instance) |previous| : (rounds += 1) {
            if (rounds == max_replaced_documents) return false;
            const may_unload = mayUnloadNow(previous);
            dom_mod.document_lifecycle.abort(previous);
            if (self.document_instance != previous) continue;
            if (!may_unload or dom_mod.document_lifecycle.isUnloading(previous)) return false;
            dom_mod.document_lifecycle.unload(previous);
            if (self.document_instance == previous) return true;
        }
        return false;
    }

    /// HTML "abort a document" and then "unload a document and its
    /// descendants" for the page's current document, whose successor gets a
    /// new Window (HTML "create and initialize a Document object" step 7):
    /// the page's traversable unloads it as any navigable's navigation does -
    /// children first, then the document, each document's unloading cleanup
    /// steps (its window's timers, animation frames, blob URLs, sockets...),
    /// its child navigables destroyed. A document whose load event never ran
    /// is destroyed with no pagehide and no unload (`endCurrentDocument`).
    fn unloadForNewWindow(self: *Context, document: *runtime.Instance) void {
        const may_unload = mayUnloadNow(document);
        dom_mod.document_lifecycle.abort(document);
        if (dom_mod.document_lifecycle.isUnloading(document)) return;
        if (self.traversable) |record| {
            dom_mod.top_level_traversables.unloadActiveDocument(record, may_unload);
            return;
        }
        if (may_unload) dom_mod.document_lifecycle.unload(document) else dom_mod.document_lifecycle.destroy(document);
        if (self.realm) |realm| dom_mod.window_documents.destroyed(realm);
    }

    /// HTML "checking if unloading is canceled" for a navigation of the page
    /// (navigate step 24.1): beforeunload at its current document and each
    /// of its descendants' active documents, before anything is aborted. A
    /// browser UI navigation shows no prompt without sticky activation, and
    /// none is shown here: the navigation continues whatever the handlers do.
    fn fireBeforeUnload(self: *Context, document: *runtime.Instance) void {
        var documents = dom_mod.navigables.inclusiveDescendantDocuments(document, self.allocator);
        defer documents.deinit(self.allocator);
        for (documents.items) |entry| {
            if (runtime.SlabAllocator.generationOf(entry.document) != entry.generation) continue;
            _ = dom_mod.document_lifecycle.fireBeforeUnload(entry.document);
        }
    }

    /// Whether `document` may fire its unload events: its load event has run
    /// - it completely loaded, which document.open() leaves as it was (the
    /// document open steps "do not affect whether a Document is ... completely
    /// loaded").
    fn mayUnloadNow(document: *runtime.Instance) bool {
        return dom_mod.document_lifecycle.isCompletelyLoaded(document);
    }

    const max_replaced_documents = 16;

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

    /// Options for loadPage
    pub const LoadPageOptions = struct {
        /// Optional script loader for external scripts
        script_loader: ?ScriptLoader = null,
    };

    /// Load page content (fetch, parse, execute)
    ///
    /// Navigation flow per HTML Standard:
    /// 1. Fetch URL content via HTTP
    /// 2. Parse HTML into DOM tree
    /// 3. Execute inline and external scripts (in document order)
    /// 4. Fire DOMContentLoaded event
    /// 5. Fire load event
    /// HTML "navigate" the page's top-level traversable to `url` - the
    /// embedder's own "browser UI" navigation of the page it shows, as an
    /// address bar navigates a tab: the same traversable (its session history
    /// gains an entry, its WindowProxy keeps its identity), beforeunload, the
    /// fetch and the commit as the navigation's tasks - run the event loop
    /// for them. The next document gets a new Window unless the page shows
    /// its initial about:blank document (create and initialize a Document
    /// object steps 6-7). error.NoTraversable for a page with no record.
    pub fn navigate(self: *Context, url: []const u8) !void {
        const record = self.traversable orelse return error.NoTraversable;
        const serialized = serializedUrlOf(self.allocator, url);
        defer if (serialized) |s| self.allocator.free(s);
        dom_mod.top_level_traversables.navigate(record, serialized orelse url);
    }

    /// `url` parsed and serialized; null when it does not parse.
    fn serializedUrlOf(allocator: std.mem.Allocator, url: []const u8) ?[]u8 {
        var record = @import("basic_parser").parse(allocator, url, null) catch return null;
        defer record.deinit();
        return @constCast(@import("url_serializer").serialize(allocator, &record, false) catch return null);
    }

    /// dom.top_level_traversables: HTML "create and initialize a Document
    /// object" steps 6-7 for a document of `origin` that one of the page's
    /// own navigations - Location, a hyperlink, a form, a javascript: URL, a
    /// reload, a traversal - is about to commit. Step 6 keeps the Window of
    /// the page's initial about:blank document (the deviation embedder loads
    /// state, `createLoadDocument`); step 7 makes the realm of a new one.
    fn realmForTraversableDocument(context: *anyopaque, origin: html_mod.Origin) bool {
        const self: *Context = @ptrCast(@alignCast(context));
        const shown = self.document_instance orelse return true;
        if (dom_mod.document_lifecycle.isInitialAboutBlank(shown)) return true;
        var buffer: [512]u8 = undefined;
        const serialized: ?[]const u8 = if (origin.is_opaque) null else (if (origin.port) |port|
            std.fmt.bufPrint(&buffer, "{s}://{s}:{d}", .{ origin.scheme, origin.host, port }) catch null
        else
            std.fmt.bufPrint(&buffer, "{s}://{s}", .{ origin.scheme, origin.host }) catch null);
        self.replaceRealm(serialized orelse "about:blank", serialized) catch return false;
        return true;
    }

    /// dom.top_level_traversables: one of the page's navigations committed
    /// `document` - the page's document, and URL, from here.
    fn traversableCommitted(context: *anyopaque, document_ptr: *anyopaque) void {
        const self: *Context = @ptrCast(@alignCast(context));
        const document: *runtime.Instance = @ptrCast(@alignCast(document_ptr));
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

    pub fn loadPage(self: *Context) !void {
        return self.loadPageWithOptions(.{});
    }

    /// Load page content with options
    pub fn loadPageWithOptions(self: *Context, options: LoadPageOptions) !void {
        // For about:blank, just return with empty document
        if (std.mem.eql(u8, self.url, "about:blank")) {
            return;
        }
        // Not under one of the page's own parses (`parse_depth`): a load
        // asked for there waits for it, and only loadHTML can wait.
        if (self.parse_depth > 0) return error.LoadDuringParse;

        // Step 1: Fetch URL content via HTTP
        //
        // Propagate the navigation error rather than flattening it to
        // `NavigationFailed`. The WPT runner prints whatever comes back here,
        // and one catch-all name made a DNS failure, a refused connection, a
        // TLS error and a missing file read identically in the journal.
        var result = try navigation.fetchUrl(self.allocator, self.url, .{
            .cookie_jar = self.cookie_jar,
            // The Browser's network: its connections and TLS options.
            .network = if (self.browser_scope) |scope| scope.of(fetch.network.NetworkContext) catch null else null,
        });
        defer result.deinit();

        // Step 2: HTML "load a document" - the response's type decides which
        // document it makes, as a navigable container's navigation does
        // (html_core.navigation.document_type).
        const document_type = html_mod.navigation.document_type;
        const computed = try document_type.essence(self.allocator, if (result.content_type.len > 0) result.content_type else "text/html");
        defer self.allocator.free(computed);
        const kind = document_type.classify(computed);
        var synthesized: ?[]u8 = null;
        defer if (synthesized) |markup| self.allocator.free(markup);
        // A text document's encoding: its bytes are decoded before the
        // markup that holds them is made.
        var text_encoding: ?[]const u8 = null;
        const sniffing = html_mod.parser.encoding_sniffing;
        const markup: []const u8 = switch (kind) {
            .html => result.body,
            // "Loading an XML document": the response's bytes, which the XML
            // parser reads (parseXmlLoadDocument).
            .xml => result.body,
            // "Loading a text document": one pre holding the text, decoded
            // by the type's rules - a BOM, the charset parameter, else the
            // default (the sniffing algorithm without the prescan).
            .text => blk: {
                const sniffed = sniffing.sniff(result.body, .{
                    .transport = sniffing.transportEncoding(self.allocator, result.content_type),
                    .prescan = false,
                });
                text_encoding = sniffing.canonicalName(sniffed.encoding);
                const text = try sniffing.decode(self.allocator, result.body, sniffed.encoding);
                defer self.allocator.free(text);
                synthesized = try document_type.textDocumentMarkup(self.allocator, text);
                break :blk synthesized.?;
            },
            // "Loading a media document": an img, video or audio hosting the
            // resource.
            .media => blk: {
                synthesized = try document_type.mediaDocumentMarkup(self.allocator, self.url, document_type.mediaHostElement(computed));
                break :blk synthesized.?;
            },
            // Handed to external software: the page keeps its document.
            .multipart, .external => return,
        };

        // Steps 3-5: parse and execute scripts - the full HTML parser with
        // script loading, into the new document "create and initialize a
        // Document object" makes for this load (createLoadDocument). The
        // URL is this load's own copy: a load that script starts - from the
        // replaced document's abort listeners, or from this page's parser -
        // replaces `self.url`.
        const url = try self.allocator.dupe(u8, self.url);
        defer self.allocator.free(url);
        // "Create navigation params by fetching" step 21.10: the final
        // sandboxing flag set - for the host's page, which no container or
        // opener sandboxes, its response policy container's CSP-derived
        // sandboxing flags.
        const sandboxing_flags = if (result.policy_container) |*container|
            dom_mod.sandboxing.cspDerivedSandboxingFlags(&container.csp_list)
        else
            dom_mod.sandboxing.SandboxingFlagSet.empty;
        const html_options: LoadHTMLOptions = .{
            .base_url = url,
            .sandboxing_flags = sandboxing_flags,
            .last_modified = result.last_modified,
            // HTML 8.1.3.4: no script for a document sandboxed without
            // allow-scripts.
            .scripting_enabled = (kind == .html or kind == .xml) and !sandboxing_flags.scripts,
            .script_loader = options.script_loader,
            // An HTML page is its response's bytes, decoded with the encoding
            // HTML's sniffing algorithm determines from them and their
            // Content-Type; the markup made for other types is characters.
            .byte_stream = if (kind == .html or kind == .xml) .{ .content_type = result.content_type } else null,
        };
        const policy_headers = if (result.permissions_policy_headers) |headers| headers.values else @import("dom").policy_containers.permissions_policy.Headers{};
        const made = try self.createLoadDocument(html_options, null, policy_headers);
        const document = made.document;
        const hold = self.holdDocument(document);
        defer if (hold) |held| held.release();
        // HTML "create and initialize a Document object" steps 15-16:
        // Navigation Timing's "create the navigation timing entry" for the
        // new document, in its Window's realm, from the navigation's fetch -
        // before its parser, and any of its script, runs.
        if (result.timing) |*timing| {
            const report: fetch.internal.TimingReport = .{
                .timing_info = &timing.timing_info,
                .url = url,
                .initiator_type = .other,
                .cache_state = "",
                .body_info = .{ .encoded_size = result.body.len, .decoded_size = result.body.len, .content_encoding = timing.content_encoding },
                .response_status = timing.response_status,
            };
            if (self.realm) |realm| dom_mod.performance_timeline.createNavigationTimingEntry(realm, .{
                .report = &report,
                .redirect_count = timing.redirect_count,
                .navigation_type = .navigate,
            }) catch |err| log.debug("the navigation timing entry was not made: {}", .{err});
        }
        // "Create and initialize a Document object" step 9: the document's
        // policy container is the one "determine navigation params policy
        // container" chose - for a top-level page with no initiator, the
        // response's ("create a policy container from a fetch response"), or
        // a new one for a response from no network. It is the document's
        // before any of its script runs.
        if (result.takePolicyContainer()) |container| dom_mod.policy_containers.set(document, container);
        // Step 7: requestsOAC, then "obtain a similar-origin window agent" -
        // the keying of the document's agent cluster, decided once for its
        // origin in the page's browsing context group. Before any of its
        // script runs.
        self.obtainAgentCluster(result.final_url, result.origin_agent_cluster);
        if (kind == .xml) {
            // "Create and initialize a Document object" given "xml" and the
            // response's computed type.
            try dom_mod.document_internals.setDocumentType(document, .xml);
            try dom_mod.document_internals.setContentType(document, computed);
            try self.parseXmlLoadDocument(made, markup, result.content_type, options.script_loader);
            return;
        }
        try self.parseLoadDocument(made, markup, html_options);
        // A load the page's own script started has replaced it.
        if (self.document_instance != document) return;
        if (text_encoding) |name| dom_mod.document_internals.setEncoding(document, name) catch {};
        // "Create and initialize a Document object" step 11: its content type
        // is the response's computed type.
        if (kind == .text or kind == .media) {
            dom_mod.document_internals.setContentType(document, computed) catch {};
        }
    }

    /// HTML "create and initialize a Document object" step 7 for the page's
    /// new document, made from the response to a fetch of `url` whose
    /// `Origin-Agent-Cluster` header list value is `header`:
    ///
    /// "1. Let oacHeader be the result of getting a structured field value
    /// given `Origin-Agent-Cluster` and "item" from navigationParams's
    /// response's header list. 2. Let requestsOAC be true if oacHeader is not
    /// null and oacHeader[0] is the boolean true; otherwise false. 3. If
    /// navigationParams's reserved environment is a non-secure context, then
    /// set requestsOAC to false. 4. Let agent be the result of obtaining a
    /// similar-origin window agent given navigationParams's origin,
    /// browsingContext's group, and requestsOAC."
    ///
    /// A top-level navigation's reserved environment's top-level creation URL
    /// is its own URL. Crane's page keeps one Window for every load, so the
    /// agent is not made here: what is recorded is the keying of the
    /// document's origin in the group (dom.agent_cluster_keys), which the
    /// window's originAgentCluster and its agent cluster read back.
    fn obtainAgentCluster(self: *Context, url: []const u8, header: ?[]const u8) void {
        const window = self.window_instance orelse return;
        const navigable = dom_mod.browser_state.browsingContextOf(window) orelse return;
        const keys = dom_mod.agent_cluster_keys;
        const origin = fetch.internal.origins.serializedOriginOf(self.allocator, url) catch return;
        defer self.allocator.free(origin);
        const requests_oac = keys.requestsOAC(self.allocator, header, keys.isSecureTopLevelCreationUrl(self.allocator, url));
        const isolated = if (dom_mod.global_settings.of(window)) |settings| settings.cross_origin_isolated(window) else false;
        _ = keys.obtain(runtime.BrowserScope.ofInstance(window), navigable.virtual_group_id, origin, requests_oac, isolated);
    }

    // ============================================================================
    // HTML Loading and Parsing
    // ============================================================================

    /// Script loader callback type for external script loading
    /// Returns script content for the given URL, or null if loading failed
    pub const ScriptLoaderFn = @import("html").parser_script_execution.ScriptLoaderFn;

    /// Script loader interface for customizing how external scripts are loaded
    pub const ScriptLoader = @import("html").scripted_parser.ScriptLoader;

    /// Options for HTML loading
    pub const LoadHTMLOptions = struct {
        /// Base URL for resolving relative URLs
        base_url: []const u8,
        /// Enable script execution during parsing (default: true)
        scripting_enabled: bool = true,
        /// Custom script loader (optional)
        /// If null, external scripts will use default HTTP fetch
        script_loader: ?ScriptLoader = null,
        /// The content is the page's byte stream, to decode with the encoding
        /// HTML's encoding sniffing algorithm determines; null when it is
        /// characters already.
        byte_stream: ?html_mod.scripted_parser.ByteStream = null,
        /// The new document's active sandboxing flag set: navigationParams's
        /// final sandboxing flag set ("create and initialize a Document
        /// object" step 9). A top-level page's is its response's CSP-derived
        /// sandboxing flags; with the sandboxed scripts flag its parser runs
        /// no script, and with the sandboxed origin flag its origin is a new
        /// opaque one.
        sandboxing_flags: dom_mod.sandboxing.SandboxingFlagSet = .empty,
        /// HTML lastModified: the source timestamp, null when unknown.
        last_modified: ?@import("platform").WallTime = null,
    };

    /// Load HTML content as the page's new document
    ///
    /// This method:
    /// 1. Aborts the document the page shows, and unloads it if it has
    ///    loaded (never freed here: it is left to whatever still holds it -
    ///    script, or a parser on the stack)
    /// 2. Sets up the document URL and Window origin
    /// 3. Makes a NEW Document, the Window's from then on - every load does
    /// 4. Parses HTML into it (html.dom_parser.parseHTMLWithScripting),
    ///    executing inline and external scripts during parsing
    /// 5. Initializes iframe browsing contexts
    ///
    /// Per HTML Standard §13.2.7 "The end":
    /// - Scripts execute during parsing (inline and deferred)
    /// - DOMContentLoaded fires after parsing completes
    ///
    /// ## Example
    /// ```zig
    /// const html =
    ///     \\<html>
    ///     \\<body>
    ///     \\<div id="test">Hello</div>
    ///     \\<script>
    ///     \\  window.found = document.getElementById('test').textContent;
    ///     \\</script>
    ///     \\</body>
    ///     \\</html>
    /// ;
    /// try ctx.loadHTML(html, .{ .base_url = "about:blank" });
    /// const result = try ctx.evaluateScript("window.found");
    /// // result === "Hello"
    /// ```
    pub fn loadHTML(self: *Context, html_content: []const u8, options: LoadHTMLOptions) !void {
        // Asked for under one of the page's own parses - a ScriptLoader that
        // loads another page: it runs once that parse has returned
        // (`parse_depth`), and the latest such request wins, as a later
        // navigation aborts an earlier one ("set the ongoing navigation").
        if (self.parse_depth > 0) {
            const pending = try PendingLoad.create(self.allocator, html_content, options);
            if (self.pending_load) |earlier| earlier.destroy(self.allocator);
            self.pending_load = pending;
            return;
        }
        const made = try self.createLoadDocument(options, html_content, .{});
        const hold = self.holdDocument(made.document);
        defer if (hold) |held| held.release();
        try self.parseLoadDocument(made, html_content, options);
    }

    /// A load's new document - BORROWED from the Context, which holds it
    /// while it is the page's.
    const LoadDocument = struct {
        document: *runtime.Instance,
    };

    /// HTML "create and initialize a Document object", as much of it as a
    /// page's load is - a "browser UI" navigation of the page's top-level
    /// traversable with a response its embedder gave, committed now:
    ///
    /// 1. "Checking if unloading is canceled" (navigate step 24.1):
    ///    beforeunload at the document the page shows and its descendants'.
    /// 2. That document goes: aborted, then unloaded - with its descendants,
    ///    their cleanup steps run and their child navigables destroyed - or,
    ///    when its load event never ran, destroyed with no unload events.
    /// 3. Step 6: its Window is kept when it is the initial about:blank
    ///    document. Step 7 otherwise: a new realm whose global object is a
    ///    new Window and whose global this binding is the page's WindowProxy
    ///    (`replaceRealm`).
    /// 4. The load's URL and origin become the page's, and a NEW Document
    ///    (step 9) becomes its Window's (step 10, associateDocument) - before
    ///    any parser exists, so the page's own scripts, which the parser
    ///    runs, see the document they are in.
    ///
    /// Stated deviation, as both engines do it and as the engine must: the
    /// new Document and Window are made AFTER the old document unloaded,
    /// where the spec makes them in "populate", before "finalize" and the
    /// unload. Blink's DocumentLoader::CommitNavigation runs once FrameLoader
    /// has detached the old document (it DCHECKs the old document is no
    /// longer active); WebKit's FrameLoader::transitionToCommitted runs
    /// closeURL - the unload - before DocumentWriter::begin makes the new
    /// document, and FrameLoader::clear makes the window after detaching the
    /// old one. And one WindowProxy is attached to one global object at a
    /// time: the new realm can be built around the page's proxy only after
    /// the old document's unload handlers, which still see `window` as the
    /// old Window, have run. Nothing observes the new Document earlier: no
    /// script of it runs before "scripts may run for the newly-created
    /// document".
    fn createLoadDocument(self: *Context, options: LoadHTMLOptions, markup: ?[]const u8, policy_headers: @import("dom").policy_containers.permissions_policy.Headers) !LoadDocument {
        if (self.realm == null or self.window_instance == null) return error.NotInitialized;
        const replaced = self.document_instance;
        // Step 6's condition, read before anything of the document goes.
        const keeps_window = if (replaced) |document| dom_mod.document_lifecycle.isInitialAboutBlank(document) else true;
        // Navigate steps 13-14: a load to the shown document's own URL, or
        // from the initial about:blank document ("the navigation must be a
        // replace"), replaces its session history entry; any other pushes
        // one. The traversable's history has the shown document's entry
        // first.
        const replace_entry = keeps_window or self.showsUrl(options.base_url);
        if (self.traversable) |record| dom_mod.top_level_traversables.prepareHistory(record);
        if (replaced) |document| self.fireBeforeUnload(document);
        if (keeps_window) {
            // Step 6, with a stated deviation: the page's realm-creation
            // about:blank document is opaque, so the text would give its
            // successor a new Window too - step 6 reuses it only when "same
            // origin-domain with navigationParams's origin". It is the
            // embedder's injection point (the WPT runner puts testharness.js
            // in it before the page loads), and nothing of the page can
            // observe the difference: no script of the page ran in it, and
            // what the embedder put there it put there for the page.
            if (!self.endCurrentDocument()) {
                // Not unloaded: its load event never ran. No parser of it is
                // on the stack (`parse_depth`), so it is destroyed now - the
                // re-queued task that waited for its parse is gone.
                if (self.document_instance) |current| if (!dom_mod.document_lifecycle.isUnloading(current)) {
                    dom_mod.document_lifecycle.destroy(current);
                };
            }
        } else {
            if (replaced) |document| self.unloadForNewWindow(document);
            try self.replaceRealm(options.base_url, if (options.sandboxing_flags.origin) null else originPrefix(options.base_url));
        }
        const runtime_ctx = self.realm orelse return error.NotInitialized;

        // The realm's document URL, for fetch's relative URL resolution.
        runtime_ctx.setDocumentUrl(options.base_url) catch |err| {
            log.debug("Warning: Failed to set document URL: {}\n", .{err});
        };

        // Update location object with the document's URL
        try self.setUrl(options.base_url);

        // Set the Window's origin from the base URL for storage access
        // This is needed for sessionStorage/localStorage to work properly
        if (self.window_instance) |win| {
            if (originPrefix(options.base_url)) |origin| {
                dom_mod.window_globals.setOrigin(win, origin) catch |err| {
                    log.debug("Warning: Failed to set Window origin: {}\n", .{err});
                };
            }
        }

        // Step 9: "Let document be a new Document" whose type is "html"
        // ("load an HTML document"); the parser gives it its content type.
        // Its origin: "determining the origin" step 1 makes it a new opaque
        // one when the final sandboxing flag set has the sandboxed origin
        // browsing context flag; else one of its own, from its URL.
        const document_origin = if (options.sandboxing_flags.origin)
            try dom_mod.origin_record.OriginRecord.create(self.allocator, "null")
        else
            try dom_mod.origin_record.OriginRecord.createOwn(self.allocator);
        defer document_origin.release();
        // Permissions Policy §9.5: the response declarations use this same
        // origin record. A parentless document has no inherited restriction.
        var permissions = try dom_mod.policy_containers.permissionsForNavigable(self.allocator, null, document_origin, policy_headers);
        var permissions_taken = false;
        defer if (!permissions_taken) permissions.deinit();
        const document = try interfaces.Document.initWith(self.allocator, runtime_ctx, .{
            .origin = document_origin,
            .permissions_policy = permissions,
            .sandboxing_flags = options.sandboxing_flags,
            // HTML create and initialize a Document, step 9.
            .ready_state = ._loading_,
            .last_modified = options.last_modified,
        });
        permissions_taken = true;
        dom_mod.document_internals.setDocumentType(document, .html) catch {};
        // Step 10: "Set window's associated Document to document." From here
        // the window keeps it, and the document it replaces is unlinked.
        self.associateDocument(runtime_ctx, document, replaced);
        // The traversable's active document's origin, which its next
        // navigation compares with; and its session history entry ("finalize
        // a cross-document navigation" steps 5-10), whose resource is the
        // embedder's markup - a traversal back re-creates the page from it,
        // the embedder never having served its URL - or none, for a page
        // fetched from its URL. Recorded before the parser exists, so the
        // page's own scripts see their entry (lesson
        // architecture-a-commit-that-parses-synchronously-must-record-history-first),
        // and after the old document unloaded (the stated order of runCommit).
        if (self.traversable) |record| {
            const origin = if (options.sandboxing_flags.origin) "null" else originPrefix(options.base_url) orelse "null";
            dom_mod.top_level_traversables.setActiveOrigin(record, origin);
            dom_mod.top_level_traversables.recordLoad(record, @ptrCast(document), options.base_url, origin, markup, replace_entry);
        }
        return .{ .document = document };
    }

    /// Whether the page shows a document at `url` (navigate step 13.1's
    /// "url equals navigable's active document's URL").
    fn showsUrl(self: *Context, url: []const u8) bool {
        const document = self.document_instance orelse return false;
        const current = interfaces.Document.get_URL(document) catch return false;
        defer document.ctx.allocator.free(current);
        return std.mem.eql(u8, current, url);
    }

    /// "scheme://host[:port]" of an http(s) `url`, the origin the page's
    /// Window keeps its storage by; null for any other scheme.
    fn originPrefix(url: []const u8) ?[]const u8 {
        if (!std.mem.startsWith(u8, url, "http://") and !std.mem.startsWith(u8, url, "https://")) return null;
        const scheme_end = std.mem.indexOf(u8, url, "://") orelse return null;
        const after_scheme = url[scheme_end + 3 ..];
        const path_start = std.mem.indexOfAny(u8, after_scheme, "/?#") orelse after_scheme.len;
        return url[0 .. scheme_end + 3 + path_start];
    }

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

    /// One of the page's parses returned: when it was the outermost, the load
    /// asked for under it runs now - Blink's order, the document detached
    /// once its construction site has left the stack.
    fn endParse(self: *Context) void {
        self.parse_depth -= 1;
        if (self.parse_depth != 0) return;
        const pending = self.pending_load orelse return;
        self.pending_load = null;
        defer pending.destroy(self.allocator);
        self.loadHTML(pending.html, pending.loadOptions()) catch |err| {
            log.debug("the load asked for under the page's parse failed: {}", .{err});
        };
    }

    /// Keep `document` alive while a load works on it: a load its own
    /// scripts start replaces it, and only script would hold it then. Null
    /// when the engine cannot hold it; the load then rechecks that the
    /// document is still the page's before touching it.
    fn holdDocument(self: *Context, document: *runtime.Instance) ?engine.Owned {
        const realm = self.realm orelse return null;
        return engine.retainValue(realm, .{ .instance = document }) catch null;
    }

    /// Parse a load's document (createLoadDocument), running its scripts,
    /// and give its iframes their browsing contexts once parsing has stopped
    /// or waits. The caller holds `document` (holdDocument).
    fn parseLoadDocument(self: *Context, made: LoadDocument, html_content: []const u8, options: LoadHTMLOptions) !void {
        const runtime_ctx = self.realm orelse return error.NotInitialized;
        const document = made.document;
        // On the stack from here until the parse returns: a load asked for
        // under it waits for it (`pending_load`).
        self.parse_depth += 1;
        defer self.endParse();
        var parser_canceled = false;
        _ = html_mod.dom_parser.parseHTMLWithScripting(
            self.allocator,
            runtime_ctx,
            html_content,
            .{
                .scripting_enabled = options.scripting_enabled,
                .parser_canceled = &parser_canceled,
                .base_url = options.base_url,
                .script_loader = options.script_loader,
                .document = document,
                .byte_stream = options.byte_stream,
            },
        ) catch |err| {
            log.debug("HTML parse error: {}\n", .{err});
            return error.ParseError;
        };
        // Its parser was aborted, or a load its scripts started replaced it:
        // the page is that load's now.
        if (parser_canceled or self.document_instance != document) return;

        // Initialize browsing contexts for any iframes in the document
        // This is necessary for window.frames[N] to work properly
        self.initializeIframeBrowsingContexts(document) catch |err| {
            // Non-fatal - some iframes may not need initialization
            log.debug("Warning: Failed to initialize iframe browsing contexts: {}\n", .{err});
        };

        // DOMContentLoaded and load (HTML §13.2.7 "the end" steps 6 and 9)
        // are the parser's: it queued them as tasks when parsing stopped, with
        // readiness and pageshow around them (dom.document_lifecycle). Firing
        // load here as well, synchronously, ran every load listener twice.
    }

    /// HTML §7.5.3 "load an XML document": an XML parser for the load's new
    /// document, over the response's `bytes` - decoded by a BOM, the
    /// Content-Type's charset, the XML declaration, else UTF-8
    /// (xml_document_parser.decodeBytes) - with XML scripting support, its
    /// external classic scripts fetched with `script_loader`. Errors are
    /// "reported inline by mutating the Document": the tree up to the first
    /// stays, and Chrome's and Safari's message block goes in
    /// (xml_document_parser.insertErrorMessageBlock says why that shape).
    /// Then "the end", which XML shares with HTML (§14.2).
    fn parseXmlLoadDocument(self: *Context, made: LoadDocument, bytes: []const u8, content_type: []const u8, script_loader: ?ScriptLoader) !void {
        const document = made.document;
        self.parse_depth += 1;
        defer self.endParse();
        const xml_parser = html_mod.xml_document_parser;
        const sniffing = html_mod.parser.encoding_sniffing;
        const transport = if (content_type.len > 0) sniffing.transportEncoding(self.allocator, content_type) else null;
        if (try html_mod.xml_document_encoding.decodeDocumentBytes(self.allocator, bytes, transport)) |decoded| {
            defer self.allocator.free(decoded.text);
            dom_mod.document_internals.setEncoding(document, sniffing.canonicalName(decoded.encoding)) catch {};
            const loader: ?html_mod.script_execution.ParserScriptLoader = if (script_loader) |embedder| .{
                .context = embedder.context,
                .load = embedder.loadScript,
                .allocator = self.allocator,
            } else null;
            const failure = xml_parser.parseInto(document, decoded.text, .{ .scripting = true, .script_loader = loader }) catch |err| {
                log.debug("XML parse stopped: {}\n", .{err});
                return error.ParseError;
            };
            // A load the page's own script started has replaced it.
            if (self.document_instance != document) return;
            if (failure) |found| xml_parser.insertErrorMessageBlock(document, found) catch {};
        } else {
            // XML 1.0 §4.3.3: unsupported encodings and malformed byte
            // sequences use the ordinary XML parsererror document shape.
            var failure: xml_parser.Failure = .{ .line = 1, .column = 1 };
            const message = "Encoding error";
            @memcpy(failure.message_buffer[0..message.len], message);
            failure.message_len = message.len;
            xml_parser.insertErrorMessageBlock(document, failure) catch {};
        }
        self.initializeIframeBrowsingContexts(document) catch |err| {
            log.debug("Warning: Failed to initialize iframe browsing contexts: {}\n", .{err});
        };
        // "The end" (HTML §13.2.7, which XML's parser follows: §14.2):
        // readiness, DOMContentLoaded and load, as tasks.
        dom_mod.document_lifecycle.finishWithoutParser(document);
    }

    /// Initialize browsing contexts for all iframes in a document.
    /// This triggers lazy initialization of iframe browsing contexts by accessing
    /// their contentWindow property, which is required for window.frames[N] to work.
    fn initializeIframeBrowsingContexts(self: *Context, document: *runtime.Instance) !void {
        _ = self;

        // Get all iframe elements using getElementsByTagName
        const iframes = try interfaces.Document.call_getElementsByTagName(
            document,
            runtime.DOMString.initInterned("iframe"),
        );
        // Made here and never handed to script, so nothing else will free it:
        // its teardown AND its storage (runtime.Instance.deinit). The
        // interface's deinit alone - a destructor, not a free - left every
        // page load one HTMLCollection slot until its Browser ended (lane
        // pageretention1).
        defer runtime.Instance.deinit(iframes);

        // Get the collection length
        const length = try interfaces.HTMLCollection.get_length(iframes);
        if (length == 0) return;

        // Access contentWindow on each iframe to trigger browsing context initialization
        var i: u32 = 0;
        while (i < length) : (i += 1) {
            const element = try interfaces.HTMLCollection.call_item(iframes, i);
            if (element) |iframe_elem| {
                // Access contentWindow to trigger IFrameIntegration.ensureBrowsingContext
                _ = interfaces.HTMLIFrameElement.get_contentWindow(iframe_elem) catch |err| {
                    log.debug("Warning: Failed to initialize iframe {d}: {}\n", .{ i, err });
                };
            }
        }
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

    /// The end of the page: its threadlocal state, its timers, then its realm
    /// (engine.destroyWindowRealm, which follows Blink's
    /// LocalWindowProxy::DisposeContext).
    pub fn deinit(self: *Context) void {
        log.debug("[Context.deinit] {s}", .{self.url});

        // Clean up threadlocal state that accumulates across context navigations.
        // These must be cleaned up to prevent state accumulation that causes
        // timeouts in sequential test execution.

        // Clean up custom elements threadlocal state (reactions_stack, element_reaction_queues)

        // Clean up mutation observer threadlocal state (global_agent)
        mutation_observer_algorithms.resetAgent();

        // (Instance lifecycle flags live in each instance's slab slot and go
        // with it: nothing of the page's to clear here.)

        // The page's animation frame callbacks end with it, and the timer
        // interface and every pending timer, before the realm ends, so that
        // none fires into it.
        if (self.realm) |realm| rendering.endPage(realm);
        clearTimerInterface();

        // NOTE: Do NOT explicitly deinit singleton instances here! The
        // realm's end cleans up its wrapper cache, which frees each instance;
        // deinit'ing them here as well is a double free.
        self.document_instance = null;
        self.navigator_instance = null;
        self.location_instance = null;
        self.history_instance = null;
        self.performance_instance = null;
        if (self.pending_load) |pending| pending.destroy(self.allocator);
        self.pending_load = null;

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

// ============================================================================
// A replaced document's end
// ============================================================================

/// A load asked for while one of the page's parses was on the native stack
/// (Context.parse_depth), kept until the outermost returns: the markup, and
/// copies of what its options borrow. The embedder's script loader is held
/// (`acquire`) until then.
const PendingLoad = struct {
    html: []u8,
    base_url: []u8,
    content_type: ?[]u8,
    has_byte_stream: bool,
    scripting_enabled: bool,
    script_loader: ?Context.ScriptLoader,
    sandboxing_flags: dom_mod.sandboxing.SandboxingFlagSet,
    last_modified: ?@import("platform").WallTime,

    fn create(allocator: std.mem.Allocator, html_content: []const u8, options: Context.LoadHTMLOptions) !*PendingLoad {
        const self = try allocator.create(PendingLoad);
        errdefer allocator.destroy(self);
        const html_copy = try allocator.dupe(u8, html_content);
        errdefer allocator.free(html_copy);
        const base_url = try allocator.dupe(u8, options.base_url);
        errdefer allocator.free(base_url);
        const content_type: ?[]u8 = if (options.byte_stream) |stream| (if (stream.content_type) |ct| try allocator.dupe(u8, ct) else null) else null;
        self.* = .{
            .html = html_copy,
            .base_url = base_url,
            .content_type = content_type,
            .has_byte_stream = options.byte_stream != null,
            .scripting_enabled = options.scripting_enabled,
            .script_loader = options.script_loader,
            .sandboxing_flags = options.sandboxing_flags,
            .last_modified = options.last_modified,
        };
        if (options.script_loader) |loader| loader.retain(loader.context);
        return self;
    }

    /// The load's options, borrowing this record.
    fn loadOptions(self: *const PendingLoad) Context.LoadHTMLOptions {
        return .{
            .base_url = self.base_url,
            .scripting_enabled = self.scripting_enabled,
            .script_loader = self.script_loader,
            .byte_stream = if (self.has_byte_stream) .{ .content_type = self.content_type } else null,
            .sandboxing_flags = self.sandboxing_flags,
            .last_modified = self.last_modified,
        };
    }

    fn destroy(self: *PendingLoad, allocator: std.mem.Allocator) void {
        if (self.script_loader) |loader| loader.release(loader.context);
        allocator.free(self.html);
        allocator.free(self.base_url);
        if (self.content_type) |ct| allocator.free(ct);
        allocator.destroy(self);
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
