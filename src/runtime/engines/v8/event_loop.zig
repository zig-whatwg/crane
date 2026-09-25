//! V8 Event Loop Implementation
//!
//! This module provides an EventLoop implementation that integrates with
//! V8's built-in microtask queue and libuv for timer support. This ensures
//! proper interop between V8 promises and our AsyncPromise implementation,
//! as well as support for setTimeout/clearTimeout via AbortSignal.timeout().
//!
//! ## Design
//!
//! V8 provides native microtask management through:
//! - `Isolate::EnqueueMicrotask()` - Add microtask to V8's queue
//! - `Isolate::PerformMicrotaskCheckpoint()` - Run all pending microtasks
//!
//! Timer support is provided by libuv:
//! - Each V8EventLoop owns a LibuvTimerManager
//! - runOnce() polls libuv for ready timer callbacks
//! - setTimeout/clearTimeout APIs available via TimerInterface
//!
//! This implementation wraps those APIs to conform to our EventLoop interface.
//!
//! ## Usage (Legacy API)
//!
//! ```zig
//! const v8_ffi = @import("ffi.zig");
//! const V8EventLoop = @import("event_loop.zig").V8EventLoop;
//!
//! // Create V8EventLoop from V8 isolate
//! var v8_loop = try V8EventLoop.init(isolate, allocator);
//! defer v8_loop.deinit();
//!
//! // Get EventLoop interface
//! const loop = v8_loop.eventLoop();
//!
//! // Use like any EventLoop
//! loop.queueMicrotask(.{
//!     .callback = myCallback,
//!     .context = &data,
//! });
//! loop.runMicrotasks();
//!
//! // Use timers
//! const timer = v8_loop.timerInterface();
//! const id = timer.setTimeout(1000, myTimerCallback, &myData);
//! timer.clearTimeout(id);
//! ```
//!
//! ## Typed Microtask API
//!
//! For type-safe microtasks, use SelfContainedCallback:
//!
//! ```zig
//! const typed_callback = @import("runtime").typed_callback;
//!
//! const PromiseCtx = struct {
//!     resolve_value: JSValue,
//!     resolver: *PromiseResolver,
//! };
//!
//! fn handleResolve(ctx: *PromiseCtx) void {
//!     ctx.resolver.resolve(ctx.resolve_value);
//! }
//!
//! // Create typed microtask
//! var wrapper = try typed_callback.SelfContainedCallback(PromiseCtx, void).create(
//!     allocator,
//!     &handleResolve,
//!     .{ .resolve_value = value, .resolver = resolver },
//! );
//!
//! // Queue via event loop
//! loop.queueMicrotask(.{
//!     .callback = wrapper.getTrampolineCallback(),
//!     .context = wrapper.toAnyopaque(),
//! });
//!
//! // Note: wrapper will be invoked and should clean itself up in the callback
//! ```
//!
//! ## Lifetime Contracts
//!
//! ### Microtask Callbacks
//! - UserData must remain valid until microtask checkpoint executes
//! - Microtasks CANNOT be cancelled once enqueued
//! - After execution, microtask system no longer references data
//! - Microtasks may enqueue more microtasks (all execute before returning)
//!
//! ## Thread Safety
//!
//! This implementation is NOT thread-safe. It must only be used from the
//! thread that owns the V8 isolate, matching JavaScript's single-threaded
//! execution model.

const std = @import("std");
const Allocator = std.mem.Allocator;
const v8_ffi = @import("ffi.zig");
// Phase 7: libuv is gone. The timer backend is native - see native_timer.zig.
const native_timer = @import("native_timer.zig");
const TimerManagerImpl = native_timer.NativeTimerManager;
const runtime = @import("runtime");

// Import the EventLoop interface from streams
const event_loop_mod = @import("event_loop");
const EventLoop = event_loop_mod.EventLoop;
const Microtask = event_loop_mod.Microtask;
const Task = event_loop_mod.Task;

/// V8 Event Loop Implementation
///
/// Wraps V8's native microtask queue and libuv timer loop to provide
/// EventLoop interface with timer support.
///
/// ## Bfcache Support
///
/// The event loop supports freeze/thaw operations for the back-forward cache:
/// - freeze(): Suspends all timer and task processing
/// - thaw(): Resumes processing
/// - isFrozen(): Check if currently frozen
///
/// When frozen, runOnce() returns immediately without processing any work.
/// At most this many platform tasks run per turn. V8 can post a task from a
/// task, and a turn has to end for the caller to check its deadline, as
/// `runQueuedTasks` bounds the embedder's own queue.
const platform_task_budget = 64;

/// Run the foreground tasks V8 has posted to the platform for `isolate` - an
/// asynchronous WebAssembly compile's result, FinalizationRegistry cleanup -
/// each followed by a microtask checkpoint, since it may have settled a
/// promise. d8's `ProcessMessages` does the same after every task. Call with
/// `isolate` entered. Returns whether any task ran.
pub fn pumpPlatformTasks(isolate: *v8_ffi.Isolate) bool {
    var ran = false;
    var budget: usize = platform_task_budget;
    while (budget > 0 and v8_ffi.v8_Platform_PumpMessageLoop(isolate)) : (budget -= 1) {
        ran = true;
        v8_ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
    }
    return ran;
}

/// The fetches in flight on this thread - `fetch()`'s, run on the event loop.
const async_fetch = @import("fetch").algorithms.async_fetch;

/// The network's share of a turn: every transfer on this thread moves as far
/// as its sockets allow, without waiting, and each fetch that ended is handed
/// to whoever started it - who queues the task that settles it, so that runs
/// on a later turn. Fetches whose realm has gone are ended first. Returns
/// whether anything happened. Costs nothing when no fetch was ever started.
pub fn pumpNetwork() bool {
    return async_fetch.pump();
}

pub const V8EventLoop = struct {
    /// V8 isolate this event loop is bound to
    isolate: *v8_ffi.Isolate,

    /// Allocator for microtask context allocation
    allocator: Allocator,

    /// Arena for promise allocation (owned by this event loop)
    promise_arena: std.heap.ArenaAllocator,

    /// Task queue (V8 doesn't have native task queue, so we implement one)
    tasks: std.ArrayList(Task),

    /// Track if we're inside runOnce to prevent reentrancy
    in_run_once: bool,

    /// libuv-based timer manager for setTimeout/clearTimeout
    timer_manager: ?*TimerManagerImpl,

    /// Whether this event loop is frozen (for bfcache)
    frozen: bool,

    const Self = @This();

    /// Default maximum wait time when no explicit timeout is provided.
    /// This allows the event loop to block efficiently while still being responsive.
    const DEFAULT_MAX_WAIT_MS: u64 = 100;

    /// Initialize a new V8 event loop with timer support
    ///
    /// The event loop will use the provided V8 isolate's microtask queue
    /// and create a libuv-based timer manager for setTimeout/clearTimeout.
    /// The allocator is used for internal bookkeeping and promise allocation.
    ///
    /// Returns error if libuv timer initialization fails.
    ///
    /// Example:
    /// ```zig
    /// var loop = try V8EventLoop.init(isolate, allocator);
    /// defer loop.deinit();
    /// ```
    pub fn init(isolate: *v8_ffi.Isolate, allocator: Allocator) !Self {
        // Create timer manager
        const timer_mgr = try TimerManagerImpl.init(allocator);
        errdefer timer_mgr.deinit();

        return .{
            .isolate = isolate,
            .allocator = allocator,
            .promise_arena = std.heap.ArenaAllocator.init(allocator),
            .tasks = .empty,
            .in_run_once = false,
            .timer_manager = timer_mgr,
            .frozen = false,
        };
    }

    /// Initialize without timer support (for backwards compatibility)
    ///
    /// Use init() instead to get full timer support.
    pub fn initWithoutTimers(isolate: *v8_ffi.Isolate, allocator: Allocator) Self {
        return .{
            .isolate = isolate,
            .allocator = allocator,
            .promise_arena = std.heap.ArenaAllocator.init(allocator),
            .tasks = .empty,
            .in_run_once = false,
            .timer_manager = null,
            .frozen = false,
        };
    }

    /// Free all resources
    ///
    /// This clears any pending tasks, frees the promise arena, and shuts down
    /// the timer manager (cancelling all pending timers).
    /// After calling deinit(), the loop cannot be used.
    ///
    /// IMPORTANT: This does NOT execute pending microtasks in V8's queue.
    /// Those are owned by V8 and will execute when V8 runs its checkpoint.
    pub fn deinit(self: *Self) void {
        // Shutdown timer manager first (cancels all pending timers)
        if (self.timer_manager) |mgr| {
            mgr.deinit();
        }
        // A task still queued will never run: let it free what it carries.
        for (self.tasks.items) |task| {
            if (task.drop) |drop| drop(task.context);
        }
        self.tasks.deinit(self.allocator);
        self.promise_arena.deinit();
    }

    /// Get the timer interface for this event loop.
    ///
    /// Returns null if timer support was not initialized.
    /// Use this to schedule timers for AbortSignal.timeout() etc.
    ///
    /// Example:
    /// ```zig
    /// if (loop.timerInterface()) |timer| {
    ///     const id = timer.setTimeout(1000, myCallback, &data);
    ///     timer.clearTimeout(id);
    /// }
    /// ```
    pub fn timerInterface(self: *Self) ?runtime.TimerInterface {
        if (self.timer_manager) |mgr| {
            return mgr.timerInterface();
        }
        return null;
    }

    /// Drain all pending timer close callbacks.
    ///
    /// When timers are cancelled via clearTimeout(), libuv schedules close callbacks
    /// that must be processed for the handles to be fully released. This method
    /// runs the event loop until all pending timer close callbacks have executed.
    ///
    /// Returns the number of iterations needed to drain all callbacks.
    ///
    /// Example:
    /// ```zig
    /// // After cancelling many timers, ensure they're fully cleaned up
    /// const iterations = v8_loop.drainCloseCallbacks();
    /// ```
    pub fn drainCloseCallbacks(self: *Self) u32 {
        if (self.timer_manager) |mgr| {
            return mgr.drainCloseCallbacks();
        }
        return 0;
    }

    /// Get the count of pending timers (including those being closed).
    pub fn getPendingTimerCount(self: *Self) usize {
        if (self.timer_manager) |mgr| {
            return mgr.getPendingCount();
        }
        return 0;
    }

    /// Get an EventLoop interface for this V8 loop
    ///
    /// This returns an EventLoop that can be used with async promise APIs.
    ///
    /// Example:
    /// ```zig
    /// var v8_loop = V8EventLoop.init(isolate, allocator);
    /// const loop = v8_loop.eventLoop();
    /// loop.queueMicrotask(...);
    /// ```
    pub fn eventLoop(self: *Self) EventLoop {
        return .{
            .ptr = self,
            .vtable = &.{
                .queueMicrotask = queueMicrotask,
                .queueTask = queueTask,
                .runMicrotasks = runMicrotasks,
                .runOnce = runOnce,
                .promiseAllocator = promiseAllocator,
            },
        };
    }

    // ========================================================================
    // Bfcache Freeze/Thaw Support
    // ========================================================================

    /// Freeze the event loop for bfcache
    ///
    /// When frozen:
    /// - runOnce() returns immediately without processing work
    /// - Timers are NOT polled (preserving their remaining times)
    /// - Tasks are NOT executed (preserved in queue)
    /// - New microtasks can still be queued (V8 handles this)
    ///
    /// Returns error if already frozen.
    ///
    /// Example:
    /// ```zig
    /// // When navigating away from page
    /// try event_loop.freeze();
    /// // ... later, when navigating back
    /// try event_loop.thaw();
    /// ```
    pub fn freeze(self: *Self) !void {
        if (self.frozen) {
            return error.AlreadyFrozen;
        }

        self.frozen = true;

        // Note: Timer state is preserved automatically since we stop polling.
        // When thawed, timers will continue from where they left off.
        // For proper time adjustment, FrozenContextManager tracks freeze time.
    }

    /// Thaw the event loop after bfcache restoration
    ///
    /// Resumes normal event loop processing.
    ///
    /// Returns error if not frozen.
    pub fn thaw(self: *Self) !void {
        if (!self.frozen) {
            return error.NotFrozen;
        }

        self.frozen = false;

        // Timer adjustment is handled by FrozenContextManager which knows
        // how long the context was frozen.
    }

    /// Check if the event loop is currently frozen
    pub fn isFrozen(self: *Self) bool {
        return self.frozen;
    }

    // ========================================================================
    // Public Event Loop Methods
    // ========================================================================

    /// Run one iteration of the event loop with explicit timeout.
    ///
    /// This is the recommended method for callers who need to control timing.
    /// It follows the Node.js/Chromium pattern:
    /// 1. Drain microtask queue (Promise reactions, queueMicrotask callbacks)
    /// 2. Calculate optimal wait time based on pending timers and max_wait_ms
    /// 3. Block on libuv until event or timeout
    /// 4. Execute timer/I/O callbacks
    /// 5. Drain microtask queue again
    ///
    /// @param max_wait_ms Maximum time to block waiting for events.
    ///                    Pass 0 for non-blocking check.
    /// @return true if any work was performed, false if loop is idle
    pub fn runOnceBlocking(self: *Self, max_wait_ms: u64) bool {
        // Don't process tasks or timers when frozen (bfcache support)
        if (self.frozen) {
            return false;
        }

        // Prevent reentrancy
        if (self.in_run_once) {
            return false;
        }
        self.in_run_once = true;
        defer self.in_run_once = false;

        var did_work = false;

        // Step 1: Run all pending microtasks FIRST
        // This handles any pending Promise.then() callbacks, queueMicrotask(), etc.
        v8_ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);

        // Step 2: Run the tasks queued before this turn began.
        if (self.runQueuedTasks()) did_work = true;

        // Step 2b: Run the tasks V8 itself has posted to the platform.
        if (pumpPlatformTasks(self.isolate)) did_work = true;

        // Step 2c: Move the fetches in flight along. A fetch that ended
        // queues its task for the next turn. The wait below is sliced at 1ms
        // (native_timer.zig), and a fetch in flight is pending work, so the
        // loop never sleeps through a response.
        if (pumpNetwork()) did_work = true;

        // Step 3: Calculate optimal wait time
        // We want to wake up when the next timer fires OR when max_wait_ms expires
        const wait_time = blk: {
            // A task left for the next turn is work waiting now: poll, but
            // do not block.
            if (self.tasks.items.len > 0) break :blk 0;
            if (self.timer_manager) |mgr| {
                if (mgr.getNextTimerDeadline()) |deadline| {
                    // Wake up at whichever comes first: timer deadline or max wait
                    break :blk @min(deadline, max_wait_ms);
                }
            }
            // No pending timers - use max_wait_ms (or 0 for non-blocking)
            break :blk max_wait_ms;
        };

        // Step 4: Poll libuv for I/O and timer events
        if (self.timer_manager) |mgr| {
            // Use blocking poll with timeout - this waits efficiently for timer/I/O
            // and returns after at most wait_time milliseconds
            const had_callbacks = mgr.pollBlocking(wait_time);
            if (had_callbacks) {
                did_work = true;
            }
        }

        // Step 5: Run microtasks again after timer callbacks
        // Timer callbacks may have scheduled JS callbacks that created Promises
        v8_ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);

        // Tasks queued during this turn - by the tasks above or by timer
        // callbacks - wait for the next one, which a non-empty queue makes
        // the caller start at once.
        return did_work or self.hasPendingWork();
    }

    /// Run the tasks queued so far, each followed by a microtask checkpoint
    /// (it may have resolved promises). A task they queue waits for the next
    /// turn, as HTML's event loop runs one task per iteration. Draining until
    /// the queue was empty let a task that queues a task - a frame whose load
    /// handler navigates the frame, whose next load runs the handler again -
    /// keep a turn from ever returning, and with it the deadline its caller
    /// checks between turns. Returns whether any task ran.
    fn runQueuedTasks(self: *Self) bool {
        var budget = self.tasks.items.len;
        if (budget == 0) return false;
        while (budget > 0 and self.tasks.items.len > 0) : (budget -= 1) {
            const task = self.tasks.orderedRemove(0);
            task.callback(task.context);
            v8_ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);
        }
        return true;
    }

    /// Check if there's pending work that should prevent idle.
    pub fn hasPendingWork(self: *Self) bool {
        if (self.tasks.items.len > 0) return true;
        // A fetch in flight will queue a task when it ends.
        if (async_fetch.inFlight() > 0) return true;
        if (self.timer_manager) |mgr| {
            if (mgr.getActiveTimerCount() > 0) return true;
        }
        return false;
    }

    // ========================================================================
    // EventLoop Interface Implementation
    // ========================================================================

    fn queueMicrotask(ptr: *anyopaque, task: Microtask) void {
        const self: *Self = @ptrCast(@alignCast(ptr));

        // Allocate context for the microtask
        // This will be freed by the callback wrapper
        const ctx = self.allocator.create(MicrotaskContext) catch {
            // If allocation fails, log and drop the microtask
            // This is the safest option since V8's EnqueueMicrotask doesn't return errors
            // and we can't propagate errors through the EventLoop interface.
            // Dropping is better than crashing the entire runtime.
            std.log.err("V8EventLoop: Failed to allocate microtask context (OOM), dropping microtask", .{});
            return;
        };

        ctx.* = .{
            .callback = task.callback,
            .context = task.context,
            .allocator = self.allocator,
        };

        // Enqueue to V8's microtask queue
        // Cast function pointer to opaque for FFI
        const callback_ptr: ?*const anyopaque = @ptrCast(&microtaskTrampoline);
        v8_ffi.v8_Isolate_EnqueueMicrotask(
            self.isolate,
            callback_ptr,
            ctx,
        );
    }

    fn queueTask(ptr: *anyopaque, task: Task) void {
        const self: *Self = @ptrCast(@alignCast(ptr));

        // V8 doesn't have a native task queue, so we maintain our own
        self.tasks.append(self.allocator, task) catch {
            // If allocation fails, log and drop the task
            // This is safer than crashing the runtime
            std.log.err("V8EventLoop: Failed to allocate task (OOM), dropping task", .{});
            return;
        };
    }

    fn runMicrotasks(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));

        // Delegate to V8's microtask checkpoint
        v8_ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);
    }

    fn runOnce(ptr: *anyopaque) bool {
        const self: *Self = @ptrCast(@alignCast(ptr));

        // Use the new blocking implementation with default timeout.
        // This provides efficient blocking on libuv while maintaining
        // responsiveness for the vtable interface.
        //
        // The default timeout allows the loop to block efficiently when idle,
        // waking up when timers fire or the timeout expires.
        return self.runOnceBlocking(DEFAULT_MAX_WAIT_MS);
    }

    fn promiseAllocator(ptr: *anyopaque) Allocator {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.promise_arena.allocator();
    }
};

/// Context passed to V8 microtask callback
///
/// This wraps our callback and context pointer for V8's callback interface.
const MicrotaskContext = struct {
    callback: *const fn (context: ?*anyopaque) void,
    context: ?*anyopaque,
    allocator: Allocator,
};

/// Trampoline function for V8 microtask callbacks
///
/// V8 calls this C function, which unwraps the context and calls the
/// original Zig callback.
///
/// IMPORTANT: Must use callconv(.c) because V8 calls this with C calling convention.
fn microtaskTrampoline(data: ?*anyopaque) callconv(.c) void {
    const ctx: *MicrotaskContext = @ptrCast(@alignCast(data.?));
    defer ctx.allocator.destroy(ctx);

    // Call the original callback
    ctx.callback(ctx.context);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

// Note: These tests require V8 to be initialized and an isolate to be created.
// They are integration tests that should be run with V8 available.

test "V8EventLoop - basic initialization" {
    // Skip if V8 not available
    // This would need actual V8 setup
    if (true) return error.SkipZigTest;

    // const allocator = testing.allocator;
    // const isolate = v8_ffi.v8_Isolate_New();
    // defer v8_ffi.v8_Isolate_Dispose(isolate);
    //
    // var loop = V8EventLoop.init(isolate, allocator);
    // defer loop.deinit();
    //
    // const ev_loop = loop.eventLoop();
    // try testing.expect(ev_loop.ptr != null);
}

test "V8EventLoop - microtask execution" {
    // Skip if V8 not available
    if (true) return error.SkipZigTest;

    // Integration test - would need V8 setup
}
