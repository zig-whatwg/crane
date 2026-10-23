//! Timer manager with no libuv dependency.
//!
//! Drop-in replacement for `LibuvTimerManager`, same public API. libuv was linked
//! for exactly one thing - timers ("Link libuv for timer support", build.zig) - and a
//! timer queue needs nothing more than a monotonic clock and a sorted set of
//! deadlines. That is all this is.
//!
//! Why it matters beyond tidiness: the libuv dependency is what forced nine
//! hardcoded `/opt/homebrew/opt/libuv` paths into build.zig, and a host path cannot
//! satisfy an aarch64-ios or Android sysroot. Per the migration plan's M11, removing
//! libuv is a PRECONDITION for cross-compiling at all, not an optimisation.
//!
//! ## Semantics preserved from the libuv implementation
//!
//! - `setTimeout` returns a monotonically increasing id; 0 means failure.
//! - `clearTimeout` returns whether a live timer was actually cancelled. A false
//!   return means the callback may still run, which callers rely on to decide
//!   whether it is safe to free the callback's user_data (see
//!   src/browser/Context.zig).
//! - `poll` fires every timer that is due and reports whether any callback ran.
//! - `getNextTimerDeadline` returns milliseconds until the next timer is due.
//! - `getBackendTimeout` returns -1 for "wait forever", 0 for "do not wait", or a
//!   positive millisecond bound.
//!
//! ## A heap by deadline, beside a map by id
//!
//! Every turn of a loop asks what is due: the next deadline (how long to
//! wait), a poll, the live count. They used to walk the whole id map, and a
//! map never gives capacity back, so one page's burst of 5,000 timers left
//! every later turn of that loop walking 8,192 slots three times (lane
//! timerheap1: 24 slots a turn before the burst, 24,576 after). Timers are
//! now kept as the engines keep them, in a binary min-heap in firing order
//! (`firesBefore`) with each timer's place stored in it, so the next
//! deadline is the top, a poll pops what is due, and clearTimeout takes a
//! timer out in O(log n):
//! - WebKit, Source/WebCore/platform/Timer.cpp and ThreadTimers.cpp: one
//!   heap per thread ordered by (fire time, insertionOrder); each item keeps
//!   its heapIndex (TimerHeapReference::updateHeapIndex), `stop` removes it
//!   by that index (heapDelete); sharedTimerFiredInternal pops while the top
//!   is due at one `fireTime` read before the first callback.
//! - Chromium, base/task/sequence_manager/task_queue_impl.cc: the delayed
//!   incoming queue is an IntrusiveHeap ordered by (latest_delayed_run_time,
//!   sequence_num), and Blink's TimerBase::Stop cancels through its
//!   DelayedTaskHandle, which removes the task by its HeapHandle
//!   (RemoveCancelableTask). Chromium also sweeps cancelled tasks lazily
//!   (SweepCancelledTasks), for closures cancelled by a weak pointer; every
//!   cancellation here is an explicit clearTimeout, so nothing stale is
//!   ever left in the heap.
//! The id map stays for clearTimeout and remainingMs, which look a timer up
//! by the id script holds (`TimerIdMap`).
//!
//! ## Re-entrancy
//!
//! A timer callback may schedule or cancel timers - `setInterval` reschedules itself
//! from inside its own callback, and clearing a timer from within its callback is
//! ordinary JS. So `poll` reads the heap's top afresh before each timer it fires,
//! and fires only timers that were due, and armed, when it began: one that a
//! callback arms - even at 0 ms - waits for the next poll, as it did when poll
//! fired from a snapshot of the due ids.

const std = @import("std");
const builtin = @import("builtin");
const clock = @import("clock");
// Part of the runtime module: its own root, by path.
const runtime = @import("root.zig");

const Allocator = std.mem.Allocator;
const TimerId = runtime.TimerId;
const TimerCallback = runtime.TimerCallback;
const TimerInterface = runtime.TimerInterface;
const TimerVTable = runtime.TimerVTable;
const TimerDrop = runtime.TimerDrop;

const log = std.log.scoped(.native_timer);
const TombstoneGuard = @import("infra").tombstones.TombstoneGuard;

// ============================================================================
// HTML §8.6 timer initialisation: nesting and the 4ms clamp
// ============================================================================
//
// One implementation, shared by the window and worker bindings. It lived only in
// `src/browser/Context.zig`, which is the WINDOW's binding layer - so nested
// `setTimeout(f, 0)` in a worker was never clamped at all, while the same code in
// a window was. Both paths schedule through this manager, so this is the one place
// both can see.
//
// It is not in `src/html/event_loop/timers.zig`, which also implements these steps
// (`MIN_NESTED_DELAY_MS`, `NESTING_LEVEL_THRESHOLD`): nothing spins that event
// loop, so that copy never runs.

/// The timer nesting state is HTML's, in runtime.timer; these aliases keep
/// this manager's callers and tests compiling. The level itself is
/// `runtime.timer.nesting_level` (a threadlocal var cannot be aliased).
pub const nested_min_delay_ms = runtime.timer.nested_min_delay_ms;
pub const nesting_threshold = runtime.timer.nesting_threshold;
pub const clampTimeout = runtime.timer.clampTimeout;

// ============================================================================
// Giving back what a burst took
// ============================================================================

/// The load below which a table is rebuilt smaller: WTF's HashTable shrinks
/// when keyCount * minLoad < tableSize, minLoad 6 (Source/WTF/wtf/HashTable.h,
/// `shouldShrink`, called from `remove`). With std's growth at 80% that
/// leaves a wide band where neither happens, so a table never ping-pongs.
const min_load = 6;
/// No table is shrunk to fewer slots than this, nor shrunk at all at this
/// size or below: small tables cost little, and a page arming and clearing a
/// few timers should not rebuild one every time.
const shrink_floor = 64;

/// A map keyed by timer id that keeps itself fast and small while timers
/// come and go: the manager's map of armed timers, a window's map of active
/// timers (src/browser/Context.zig `timer_contexts`) and a worker global's
/// (WorkerHost.timers, src/html/worker_host.zig). Ids only grow, so every
/// key is one the map never saw, and two things go wrong with a plain std map:
/// - Its tombstones fill it. std never counts one against the load
///   (lib/std/hash_map.zig `removeByIndex`, `growIfNeeded`), so a map whose
///   puts and removes balance never grows and never clears them, and once
///   the free slots are gone every insert and every miss walks the table.
///   `guard` rehashes in place first (lane hashmaps1, src/infra/tombstones.zig).
/// - It keeps the capacity its biggest moment needed: after a burst of
///   5,000 timers, 8,192 slots that every walk reads (a window's end, unload,
///   the back/forward cache) and that stay allocated. It is rebuilt smaller
///   once fewer than a sixth of its slots are in use (`min_load`).
///
/// Both act only BEFORE AN INSERT - in `ensureUnusedCapacity` and `put`, the
/// points where std's map may grow - never on removal: owners remove entries
/// while they iterate, and an insert during an iteration is already invalid,
/// since it can grow the map. Unlike WTF, which shrinks on removal: its
/// iterators are invalidated by any mutation. A shrink is a fresh table, so
/// it resets the guard; a failed allocation skips it.
///
/// The operations are std's AutoHashMapUnmanaged's, by name and signature,
/// so an owner's call sites read as they did.
pub fn TimerIdMap(comptime V: type) type {
    return struct {
        const Self = @This();
        pub const Map = std.AutoHashMapUnmanaged(TimerId, V);
        pub const KV = Map.KV;
        pub const Size = Map.Size;
        pub const Iterator = Map.Iterator;
        pub const KeyIterator = Map.KeyIterator;

        map: Map = .empty,
        guard: TombstoneGuard = .{},

        pub const empty: Self = .{};

        pub fn deinit(self: *Self, allocator: Allocator) void {
            self.map.deinit(allocator);
            self.* = undefined;
        }

        /// Room for `additional` more entries, as std's: the inserts that
        /// follow (`putAssumeCapacityNoClobber`) cannot fail. A table at
        /// less than a sixth of its slots is rebuilt smaller first; a removal
        /// between this and the insert keeps the room (removals never shrink).
        pub fn ensureUnusedCapacity(self: *Self, allocator: Allocator, additional: Size) Allocator.Error!void {
            self.shrinkIfSparse(allocator);
            try self.map.ensureUnusedCapacity(allocator, additional);
        }

        /// Insert `id`, which is not in the map, into room `ensureUnusedCapacity`
        /// made.
        pub fn putAssumeCapacityNoClobber(self: *Self, id: TimerId, value: V) void {
            self.guard.beforeInsert(&self.map);
            self.map.putAssumeCapacityNoClobber(id, value);
        }

        pub fn put(self: *Self, allocator: Allocator, id: TimerId, value: V) Allocator.Error!void {
            try self.ensureUnusedCapacity(allocator, 1);
            self.guard.beforeInsert(&self.map);
            self.map.putAssumeCapacity(id, value);
        }

        pub fn get(self: *const Self, id: TimerId) ?V {
            return self.map.get(id);
        }

        pub fn contains(self: *const Self, id: TimerId) bool {
            return self.map.contains(id);
        }

        pub fn count(self: *const Self) Size {
            return self.map.count();
        }

        /// The slots a walk of the map reads.
        pub fn capacity(self: *const Self) Size {
            return self.map.capacity();
        }

        pub fn iterator(self: *const Self) Iterator {
            return self.map.iterator();
        }

        pub fn keyIterator(self: *const Self) KeyIterator {
            return self.map.keyIterator();
        }

        pub fn remove(self: *Self, id: TimerId) bool {
            if (!self.map.remove(id)) return false;
            self.guard.noteRemoval(&self.map);
            return true;
        }

        pub fn fetchRemove(self: *Self, id: TimerId) ?KV {
            const kv = self.map.fetchRemove(id) orelse return null;
            self.guard.noteRemoval(&self.map);
            return kv;
        }

        /// Emptied, keeping the table (and so no tombstones); the next insert
        /// gives the slots back if the map was large.
        pub fn clearRetainingCapacity(self: *Self) void {
            self.map.clearRetainingCapacity();
            self.guard.reset();
        }

        /// Rebuild the table for twice its entries (at least `shrink_floor`
        /// slots) once fewer than a sixth of its slots are in use. Each one
        /// at least halves the table, so a burst's slots come back in a few
        /// steps whose cost the burst's own inserts paid for.
        fn shrinkIfSparse(self: *Self, allocator: Allocator) void {
            const slots = self.map.capacity();
            const live = self.map.count();
            if (slots <= shrink_floor or @as(usize, live) * min_load >= slots) return;
            var smaller: Map = .empty;
            // 32 entries fit std's smallest table of `shrink_floor` slots.
            smaller.ensureTotalCapacity(allocator, @max(live * 2, shrink_floor / 2)) catch return;
            var entries = self.map.iterator();
            while (entries.next()) |kv| smaller.putAssumeCapacityNoClobber(kv.key_ptr.*, kv.value_ptr.*);
            self.map.deinit(allocator);
            self.map = smaller;
            // A fresh table: no tombstones.
            self.guard = .{};
        }
    };
}

// ============================================================================
// The manager
// ============================================================================

/// One scheduled timer.
const Entry = struct {
    callback: TimerCallback,
    user_data: ?*anyopaque,
    /// For a timer armed with `setTimeoutOwned`: frees `user_data` when the
    /// manager ends with the timer unfired.
    drop: ?TimerDrop = null,
    id: TimerId,
    /// Absolute monotonic deadline in nanoseconds. Monotonic, NOT wall clock: a
    /// wall-clock deadline moves under an NTP step and the timer fires early or
    /// never. i128 to match the monotonic clock's nanoseconds (`nowNs`).
    deadline_ns: i128,
    /// Its place in `NativeTimerManager.heap`, kept by every move there - what
    /// WebKit's ThreadTimerHeapItem keeps as heapIndex, so that clearTimeout
    /// finds it without a search.
    heap_index: usize,
};

/// Whether `a` fires before `b`: by deadline, then by id.
///
/// HTML "run steps after a timeout" step 4.2: wait until every invocation
/// with the same global and orderingIdentifier that started before this one,
/// and whose milliseconds is less than or equal to this one's, has
/// completed. That is a partial order, and (deadline, then id) is a linear
/// extension of it: ids increase in the order timers are armed, so if A
/// started before B with A's milliseconds <= B's, then A's deadline (its
/// start plus its milliseconds) is <= B's, equal only when both read the
/// same clock and have the same milliseconds - and then A's id is the
/// smaller. One order for every global on the loop serves each global's,
/// since it is a linear extension of each. It is WebKit's (fire time, then
/// insertionOrder, TimerHeapLessThanFunction) and Chromium's
/// (latest_delayed_run_time, then sequence_num) too.
fn firesBefore(a: *const Entry, b: *const Entry) bool {
    if (a.deadline_ns != b.deadline_ns) return a.deadline_ns < b.deadline_ns;
    return a.id < b.id;
}

/// What the manager reads to find the timers that are due, counted in test
/// builds only (lane timerheap1): `slots` is every slot a poll, a
/// next-deadline query or a live count reads - of the heap now, of the
/// whole id map before it - and `polls` the polls. Their ratio is the cost
/// of one loop turn's search, which the tests hold flat across a burst.
pub const Probe = if (builtin.is_test) struct {
    polls: u64 = 0,
    slots: u64 = 0,
} else struct {};

/// The monotonic clock every deadline here is read against, in one place:
/// arming, polling, the next deadline and a suspension's remaining wait
/// (`remainingMs`).
fn nowNs() i128 {
    return clock.monotonicNanos();
}

pub const NativeTimerManager = struct {
    const Self = @This();

    allocator: Allocator,
    /// Every armed timer by id, for clearTimeout and remainingMs. Every
    /// timer is a key the map never saw - ids only grow - put when it is
    /// armed and removed when it fires or is cleared, for every page the
    /// Browser's loop runs: `TimerIdMap` keeps its tombstones and its size
    /// in check (before its guard, a 1,069-file runner sample found it at
    /// cap 32 with none free in 3,126 of 3,455 samples). Values are `*Entry`,
    /// their own allocations, so a rehash or a shrink moves nothing anyone
    /// holds, and nothing iterates the map but `deinit`.
    timers: TimerIdMap(*Entry) = .empty,
    /// Every armed timer, as a binary min-heap in firing order
    /// (`firesBefore`): `heap[0]` fires first, and each entry's `heap_index`
    /// is its place. Given back after a burst as the id map is
    /// (`reserveHeapSlot`).
    heap: std.ArrayListUnmanaged(*Entry) = .empty,
    probe: Probe = .{},
    next_id: TimerId,
    callback_invoked: bool,
    initialized: bool,

    pub fn init(allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            // Start at 1: 0 is the "invalid id" sentinel the API returns on failure.
            .next_id = 1,
            .callback_invoked = false,
            .initialized = true,
        };
        return self;
    }

    /// The manager's end: every timer still armed will never fire. One armed
    /// with `setTimeoutOwned` has its user_data dropped now; a plain one's is
    /// left to whoever armed it, as it always was.
    pub fn deinit(self: *Self) void {
        // Take the timers first: a drop may free something whose own
        // teardown reaches this manager (a clearTimeout of a sibling timer),
        // which then finds nothing.
        var heap = self.heap;
        var timers = self.timers;
        self.heap = .empty;
        self.timers = .empty;
        self.initialized = false;
        for (heap.items) |entry| {
            if (entry.drop) |drop| drop(entry.user_data);
            self.allocator.destroy(entry);
        }
        heap.deinit(self.allocator);
        timers.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Schedule a one-shot timer. Returns 0 on failure.
    pub fn setTimeout(self: *Self, ms: u64, callback: TimerCallback, user_data: ?*anyopaque) TimerId {
        return self.arm(ms, callback, user_data, null);
    }

    /// Schedule a one-shot timer that owns `user_data`: `drop(user_data)`
    /// runs if this manager ends with the timer unfired (`deinit`). Returns
    /// 0 on failure, and the caller still owns `user_data`.
    pub fn setTimeoutOwned(self: *Self, ms: u64, callback: TimerCallback, user_data: ?*anyopaque, drop: TimerDrop) TimerId {
        return self.arm(ms, callback, user_data, drop);
    }

    fn arm(self: *Self, ms: u64, callback: TimerCallback, user_data: ?*anyopaque, drop: ?TimerDrop) TimerId {
        if (!self.initialized) return 0;

        // Room in both first: a timer is in both or in neither.
        self.timers.ensureUnusedCapacity(self.allocator, 1) catch return 0;
        self.reserveHeapSlot() catch return 0;
        const id = self.next_id;
        const entry = self.allocator.create(Entry) catch return 0;
        entry.* = .{
            .callback = callback,
            .user_data = user_data,
            .drop = drop,
            .id = id,
            .deadline_ns = nowNs() + @as(i128, @intCast(ms)) * std.time.ns_per_ms,
            .heap_index = undefined,
        };
        self.timers.putAssumeCapacityNoClobber(id, entry);
        self.heapPushAssumeCapacity(entry);

        // Only consume the id once the timer is actually registered, so a failed
        // schedule does not burn one.
        self.next_id += 1;
        return id;
    }

    /// Cancel a pending timer.
    ///
    /// Returns true only if a live timer with this id was found and cancelled.
    /// False means "not mine, or already gone" - the caller must NOT assume the
    /// callback will not run, and in particular must not free its user_data.
    pub fn clearTimeout(self: *Self, id: TimerId) bool {
        if (!self.initialized) return false;
        if (id == 0) return false;

        const kv = self.timers.fetchRemove(id) orelse return false;
        const entry = kv.value;
        _ = self.heapRemove(entry.heap_index);
        self.allocator.destroy(entry);
        return true;
    }

    /// What an event loop runs after each timer callback: its microtask
    /// checkpoint. Each timer is a task of its own - HTML "run steps after a
    /// timeout" queues one per timer - and the event loop processing model
    /// performs a microtask checkpoint after every task it runs (8.1.7.3).
    /// A callback that settles a promise from native code does not perform
    /// one itself (v8_wrapper.cpp, NativeStepScope), so without this its
    /// reactions would wait behind the next due timer's callback.
    pub const AfterEach = struct {
        context: *anyopaque,
        run: *const fn (context: *anyopaque) void,
    };

    /// Fire every timer whose deadline has passed. Returns whether any callback ran.
    pub fn poll(self: *Self) bool {
        return self.pollEach(null);
    }

    /// `poll`, running `after_each` after every callback it fires.
    pub fn pollEach(self: *Self, after_each: ?AfterEach) bool {
        if (!self.initialized) return false;
        self.callback_invoked = false;
        if (builtin.is_test) self.probe.polls += 1;

        // What was due, and armed, when the poll began: the clock is read
        // once, before the first callback (WebKit's fireTime), and a timer
        // armed by a callback - its id is past `armed_before` - waits for
        // the next poll however short its timeout. Nothing due can sit
        // behind such a timer at the top: its deadline is at least `now`.
        const now = nowNs();
        const armed_before = self.next_id;
        var invoked = false;

        while (self.heap.items.len > 0) {
            // The top afresh each time: an earlier callback may have cleared
            // or armed timers.
            const entry = self.heap.items[0];
            self.noteSlots(1);
            if (entry.deadline_ns > now or entry.id >= armed_before) break;

            const cb = entry.callback;
            const data = entry.user_data;

            // Remove and free BEFORE invoking. One-shot timers must not be visible
            // to clearTimeout from inside their own callback, and the callback may
            // reschedule under a new id.
            self.noteSlots(self.heapRemove(0));
            _ = self.timers.remove(entry.id);
            self.allocator.destroy(entry);

            invoked = true;
            self.callback_invoked = true;
            cb(data);
            if (after_each) |hook| hook.run(hook.context);
        }

        self.callback_invoked = invoked;
        return invoked;
    }

    /// Longest this backend will block the caller's event loop in one call.
    ///
    /// libuv's pollBlocking ran the WHOLE loop and returned as soon as any handle
    /// became ready, so a long timeout never starved I/O. This backend knows about
    /// timers and nothing else, so sleeping for the caller's full timeout would
    /// monopolise the loop and stall everything that is not a timer - script
    /// loading, worker message dispatch, microtask progress. Observed symptom: the
    /// test file completes with NO subtest results at all.
    ///
    /// So the wait is sliced. The caller re-drives us in its own loop, so the total
    /// wait is still honoured; it just becomes interruptible.
    const max_block_ms: u64 = 1;

    /// Wait (briefly) for a timer to come due, then fire what is due.
    pub fn pollBlocking(self: *Self, timeout_ms: u64) bool {
        return self.pollBlockingEach(timeout_ms, null);
    }

    /// `pollBlocking`, running `after_each` after every callback it fires.
    pub fn pollBlockingEach(self: *Self, timeout_ms: u64, after_each: ?AfterEach) bool {
        if (!self.initialized) return false;
        if (timeout_ms == 0) return self.pollEach(after_each);

        // Anything already due: fire it now rather than sleeping first.
        if (self.pollEach(after_each)) return true;

        // Sleep until the earliest of: the next deadline, the caller's bound, and
        // max_block_ms - see above for why that last cap exists.
        const next = self.getNextTimerDeadline() orelse timeout_ms;
        // Explicit u64: @min against a comptime-known bound narrows the result type
        // (to u1 for max_block_ms = 1), and the ns_per_ms multiply then overflows it.
        const wait_ms: u64 = @min(@min(next, timeout_ms), max_block_ms);

        if (wait_ms > 0) clock.sleep(wait_ms *| std.time.ns_per_ms);
        return self.pollEach(after_each);
    }

    pub fn timerInterface(self: *Self) TimerInterface {
        return .{ .vtable = &vtable, .ctx = self };
    }

    const vtable: TimerVTable = .{
        .setTimeout = setTimeoutVTable,
        .setTimeoutOwned = setTimeoutOwnedVTable,
        .clearTimeout = clearTimeoutVTable,
        .remainingMs = remainingMsVTable,
    };

    fn remainingMsVTable(ctx: *anyopaque, id: TimerId) ?u64 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.remainingMs(id);
    }

    /// How long until the pending timer `id` is due, in whole milliseconds
    /// rounded up, 0 when it is due already; null for an id that fired, was
    /// cancelled, or was never this manager's. What a suspension keeps of a
    /// timer (the back/forward cache: WebKit's SuspendableTimer saves its
    /// next-fire interval the same way, m_savedNextFireInterval).
    pub fn remainingMs(self: *Self, id: TimerId) ?u64 {
        if (!self.initialized or id == 0) return null;
        // A fired timer left the map before its callback ran (`pollEach`).
        const entry = self.timers.get(id) orelse return null;
        const now = nowNs();
        if (entry.deadline_ns <= now) return 0;
        const left_ns: u128 = @intCast(entry.deadline_ns - now);
        return @intCast((left_ns + std.time.ns_per_ms - 1) / std.time.ns_per_ms);
    }

    fn setTimeoutVTable(ctx: *anyopaque, ms: u64, callback: TimerCallback, user_data: ?*anyopaque) TimerId {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.setTimeout(ms, callback, user_data);
    }

    fn setTimeoutOwnedVTable(ctx: *anyopaque, ms: u64, callback: TimerCallback, user_data: ?*anyopaque, drop: TimerDrop) TimerId {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.setTimeoutOwned(ms, callback, user_data, drop);
    }

    fn clearTimeoutVTable(ctx: *anyopaque, id: TimerId) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.clearTimeout(id);
    }

    pub fn getPendingCount(self: *Self) usize {
        return self.getActiveTimerCount();
    }

    /// Milliseconds until the next live timer is due, or null if none. 0 means one
    /// is already due. The heap's top.
    pub fn getNextTimerDeadline(self: *Self) ?u64 {
        if (!self.initialized) return null;
        if (self.heap.items.len == 0) return null;
        const first = self.heap.items[0];
        self.noteSlots(1);
        const now = nowNs();
        const due_in_ns: i128 = if (first.deadline_ns <= now) 0 else first.deadline_ns - now;
        return @intCast(@divTrunc(due_in_ns, std.time.ns_per_ms));
    }

    /// -1 = wait forever (nothing scheduled), 0 = do not wait, else millisecond bound.
    pub fn getBackendTimeout(self: *Self) c_int {
        if (!self.initialized) return 0;
        const due_in = self.getNextTimerDeadline() orelse return -1;
        if (due_in == 0) return 0;
        return std.math.cast(c_int, due_in) orelse std.math.maxInt(c_int);
    }

    pub fn getActiveTimerCount(self: *Self) usize {
        if (!self.initialized) return 0;
        return self.heap.items.len;
    }

    /// Present for API compatibility. libuv needed extra loop turns to run close
    /// callbacks for its handles; there are no handles here, so nothing to drain.
    pub fn drainCloseCallbacks(self: *Self) u32 {
        _ = self;
        return 0;
    }

    /// Whether the heap and the id map agree: the same timers, each at its
    /// `heap_index`, none firing before its parent. For tests.
    pub fn isConsistent(self: *const Self) bool {
        const items = self.heap.items;
        if (items.len != self.timers.count()) return false;
        for (items, 0..) |entry, i| {
            if (entry.heap_index != i) return false;
            if (self.timers.get(entry.id) != entry) return false;
            if (i > 0 and firesBefore(entry, items[(i - 1) / 2])) return false;
        }
        return true;
    }

    // ------------------------------------------------------------------------
    // The heap
    // ------------------------------------------------------------------------

    fn noteSlots(self: *Self, slots: usize) void {
        if (builtin.is_test) self.probe.slots += slots;
    }

    /// Room for one more timer in the heap. An array at less than a sixth of
    /// its capacity is copied into a smaller one first, as `TimerIdMap`
    /// rebuilds its table: positions, and so `heap_index`es, stay.
    fn reserveHeapSlot(self: *Self) Allocator.Error!void {
        const len = self.heap.items.len;
        if (self.heap.capacity > shrink_floor and len * min_load < self.heap.capacity) {
            if (self.allocator.alloc(*Entry, @max(len * 2, shrink_floor))) |smaller| {
                @memcpy(smaller[0..len], self.heap.items);
                self.heap.deinit(self.allocator);
                self.heap = .{ .items = smaller[0..len], .capacity = smaller.len };
            } else |_| {}
        }
        try self.heap.ensureUnusedCapacity(self.allocator, 1);
    }

    fn heapPushAssumeCapacity(self: *Self, entry: *Entry) void {
        entry.heap_index = self.heap.items.len;
        self.heap.appendAssumeCapacity(entry);
        _ = self.siftUp(entry.heap_index);
    }

    /// Take the entry at `index` out of the heap: the last entry takes its
    /// place and moves up or down to where it belongs. The slots the move
    /// compared.
    fn heapRemove(self: *Self, index: usize) usize {
        const last = self.heap.pop().?;
        if (index == self.heap.items.len) return 0;
        self.heap.items[index] = last;
        last.heap_index = index;
        if (index > 0 and firesBefore(last, self.heap.items[(index - 1) / 2])) return self.siftUp(index);
        return self.siftDown(index);
    }

    fn siftUp(self: *Self, start: usize) usize {
        const items = self.heap.items;
        const entry = items[start];
        var i = start;
        var steps: usize = 0;
        while (i > 0) : (steps += 1) {
            const parent = (i - 1) / 2;
            if (!firesBefore(entry, items[parent])) break;
            items[i] = items[parent];
            items[i].heap_index = i;
            i = parent;
        }
        items[i] = entry;
        entry.heap_index = i;
        return steps;
    }

    fn siftDown(self: *Self, start: usize) usize {
        const items = self.heap.items;
        const entry = items[start];
        var i = start;
        var steps: usize = 0;
        while (true) : (steps += 2) {
            const left = 2 * i + 1;
            if (left >= items.len) break;
            const right = left + 1;
            const child = if (right < items.len and firesBefore(items[right], items[left])) right else left;
            if (!firesBefore(items[child], entry)) break;
            items[i] = items[child];
            items[i].heap_index = i;
            i = child;
        }
        items[i] = entry;
        entry.heap_index = i;
        return steps;
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

var fired: usize = 0;
var fired_ids: [8]u64 = undefined;

fn countingCallback(data: ?*anyopaque) void {
    _ = data;
    fired += 1;
}

test "setTimeout ids are non-zero and increasing; 0 is the failure sentinel" {
    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();

    const a = mgr.setTimeout(10, countingCallback, null);
    const b = mgr.setTimeout(10, countingCallback, null);
    try testing.expect(a != 0);
    try testing.expect(b > a);
}

test "a due timer fires exactly once and is then gone" {
    fired = 0;
    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();

    _ = mgr.setTimeout(0, countingCallback, null);
    try testing.expectEqual(@as(usize, 1), mgr.getActiveTimerCount());

    try testing.expect(mgr.poll());
    try testing.expectEqual(@as(usize, 1), fired);
    try testing.expectEqual(@as(usize, 0), mgr.getActiveTimerCount());

    // Polling again must not re-fire it.
    try testing.expect(!mgr.poll());
    try testing.expectEqual(@as(usize, 1), fired);
}

test "a not-yet-due timer does not fire" {
    fired = 0;
    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();

    _ = mgr.setTimeout(60_000, countingCallback, null);
    try testing.expect(!mgr.poll());
    try testing.expectEqual(@as(usize, 0), fired);
}

test "clearTimeout reports whether it actually cancelled something" {
    fired = 0;
    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();

    const id = mgr.setTimeout(60_000, countingCallback, null);

    // A live timer: true, and it must not fire afterwards.
    try testing.expect(mgr.clearTimeout(id));
    try testing.expect(!mgr.poll());
    try testing.expectEqual(@as(usize, 0), fired);

    // Already cleared, unknown id, and the 0 sentinel: all false. Callers use this
    // to decide whether freeing the callback's user_data is safe.
    try testing.expect(!mgr.clearTimeout(id));
    try testing.expect(!mgr.clearTimeout(99999));
    try testing.expect(!mgr.clearTimeout(0));
}

test "a callback may schedule another timer without corrupting the map" {
    // setInterval reschedules from inside its own callback, so this must be safe.
    const Rescheduler = struct {
        var mgr_ptr: ?*NativeTimerManager = null;
        var rounds: usize = 0;
        fn cb(data: ?*anyopaque) void {
            _ = data;
            rounds += 1;
            if (rounds < 3) {
                if (mgr_ptr) |m| _ = m.setTimeout(0, cb, null);
            }
        }
    };

    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();
    Rescheduler.mgr_ptr = mgr;
    Rescheduler.rounds = 0;

    _ = mgr.setTimeout(0, Rescheduler.cb, null);
    // Each poll fires the batch that was due when it started; the reschedule lands
    // in the next one.
    _ = mgr.poll();
    _ = mgr.poll();
    _ = mgr.poll();
    try testing.expectEqual(@as(usize, 3), Rescheduler.rounds);
}

test "getNextTimerDeadline and getBackendTimeout agree about emptiness" {
    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();

    // Nothing scheduled: no deadline, and "wait forever".
    try testing.expectEqual(@as(?u64, null), mgr.getNextTimerDeadline());
    try testing.expectEqual(@as(c_int, -1), mgr.getBackendTimeout());

    _ = mgr.setTimeout(0, countingCallback, null);
    // Already due.
    try testing.expectEqual(@as(?u64, 0), mgr.getNextTimerDeadline());
    try testing.expectEqual(@as(c_int, 0), mgr.getBackendTimeout());
}

test "timers fire in deadline order, not insertion order" {
    const Order = struct {
        var seq: [4]u8 = .{ 0, 0, 0, 0 };
        var n: usize = 0;
        fn mk(comptime tag: u8) fn (?*anyopaque) void {
            return struct {
                fn f(_: ?*anyopaque) void {
                    seq[n] = tag;
                    n += 1;
                }
            }.f;
        }
    };
    Order.n = 0;

    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();

    // Scheduled c first but due last; a and b due together, in the order they
    // were scheduled. One poll fires all three - in that order, as HTML's "run
    // steps after a timeout" requires, whatever order the map iterates in.
    _ = mgr.setTimeout(5, Order.mk('c'), null);
    _ = mgr.setTimeout(0, Order.mk('a'), null);
    _ = mgr.setTimeout(0, Order.mk('b'), null);
    clock.sleep(10 * std.time.ns_per_ms);
    _ = mgr.poll();
    try testing.expectEqual(@as(usize, 3), Order.n);
    try testing.expectEqualStrings("abc", Order.seq[0..3]);
}

test "deinit frees pending timers without leaking" {
    // std.testing.allocator fails the test if anything is left allocated.
    var mgr = try NativeTimerManager.init(testing.allocator);
    _ = mgr.setTimeout(60_000, countingCallback, null);
    _ = mgr.setTimeout(60_000, countingCallback, null);
    mgr.deinit();
}
