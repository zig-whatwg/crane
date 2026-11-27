//! Event Loop Interface for Async Operations
//!
//! This module provides the interface for event loop integration required by
//! async promise operations. Users of the Streams library must provide an
//! EventLoop implementation that integrates with their runtime environment
//! (e.g., Zig's event loop, libuv, platform-specific event loops, etc.).
//!
//! ## Design Philosophy
//!
//! The event loop abstraction follows the ECMAScript event loop model:
//! - **Microtasks**: High-priority tasks (promise reactions, observers)
//! - **Tasks**: Normal-priority tasks (I/O callbacks, timers)
//!
//! Microtasks always run to completion before the next task is processed.
//!
//! ## Usage
//!
//! ```zig
//! const event_loop = @import("event_loop.zig");
//!
//! // User provides an implementation
//! var my_loop = MyEventLoop.init();
//! const loop = my_loop.eventLoop();
//!
//! // Library code queues microtasks
//! loop.queueMicrotask(.{
//!     .callback = myCallback,
//!     .context = &my_data,
//! });
//!
//! // User drives the event loop
//! while (loop.runOnce()) {
//!     // Loop until no more work
//! }
//! ```
//!
//! ## Thread Safety
//!
//! This abstraction assumes a **single-threaded event loop** model, matching
//! JavaScript's execution model. Implementations must ensure thread safety if
//! used in multi-threaded contexts.
//!
//! ## References
//!
//! - ECMAScript Event Loop: https://html.spec.whatwg.org/#event-loops
//! - Microtasks: https://html.spec.whatwg.org/#microtask-queue
//! - Tasks: https://html.spec.whatwg.org/#task-queue

const std = @import("std");

/// Microtask - High-priority work (promise reactions, etc.)
///
/// KEEP: anyopaque required - Microtask callbacks need type erasure because the
/// context type varies (promise reactions, mutation observers, etc.)
///
/// Microtasks are queued by promise resolution/rejection and must run
/// before the next task. All pending microtasks are drained before
/// processing the next task.
///
/// Spec: https://html.spec.whatwg.org/#microtask
pub const Microtask = struct {
    /// KEEP: anyopaque required - Callback with type-erased context
    callback: *const fn (context: ?*anyopaque) void,

    /// KEEP: anyopaque required - Type-erased context for callback
    context: ?*anyopaque,
};

/// HTML §8.1.7.2 "Task sources": every task comes from a specific task source,
/// and for each event loop every task source is associated with a specific task
/// queue so tasks from the same source execute in FIFO order.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#task-source
///
/// Inter-source scheduling priority (Golden Rule 2):
/// - Blink (`third_party/blink/renderer/platform/scheduler/main_thread/
///   frame_scheduler_impl.cc` & `base/task/sequence_manager/
///   task_queue_selector.cc`): `TaskType::kUserInteraction` runs at
///   `kHighPriority`, preempting normal-priority sources up to
///   `kMaxStarvationTasks = 5` consecutive tasks when a lower-priority queue
///   has runnable work; DOM manipulation, networking, navigation/history,
///   posted/port/broadcast messages, immediate/low-nesting timers, media,
///   WebSocket, IndexedDB, and performance timeline run at `kNormalPriority`
///   and break ties by monotonic `EnqueueOrder` (FIFO across equal-priority
///   queues).
/// - Gecko (`xpcom/threads/TaskController.cpp`, `PrioritizedEventQueue`):
///   `InputHigh`/`InputNormal` (user interaction) preempts `Normal` (DOM,
///   network, timers, media, IPC/messages) with a consecutive-input cap
///   (`mProcessHighPriorityQueue`) so normal queues never starve.
/// - WebKit (`Source/WebCore/dom/EventLoop.cpp`, `Source/WebCore/dom/
///   TaskSource.h`): per-source queues preserving FIFO per source; user
///   interaction prioritized ahead of timers/normal work without starvation,
///   and equal-priority sources serviced in enqueue order.
pub const TaskSource = enum(u8) {
    /// HTML §8.1.7.3 "The user interaction task source": keyboard, mouse,
    /// focus, visibility, close watchers, HTML image buttons.
    user_interaction,
    /// HTML §8.1.7.3 "The DOM manipulation task source": non-blocking reactions
    /// to DOM mutations, animations, view transitions, inspector revalidation.
    dom_manipulation,
    /// HTML §8.1.7.3 "The networking task source": fetch, XHR, EventSource,
    /// subresource completion.
    networking,
    /// HTML §8.1.7.3 "The navigation and traversal task source": navigation
    /// and session history application steps.
    navigation_and_traversal,
    /// History traversal events (`hashchange`, `popstate`, `history.back/go`).
    history_traversal,
    /// HTML "posted message task source" (`Window.postMessage`).
    posted_message,
    /// HTML "timer task source" (`setTimeout` / `setInterval`).
    timer,
    /// Performance Timeline task source (`PerformanceObserver`).
    performance_timeline,
    /// Fallback task source when a microtask defers to a task queue.
    microtask_fallback,
    /// HTML "media element event task source" (media playback / tracks).
    media_element,
    /// IndexedDB "database access task source".
    database_access,
    /// WebSockets "WebSocket task source".
    websocket,
    /// HTML "broadcast channel task source" (`BroadcastChannel.postMessage`).
    broadcast_channel,
    /// HTML "port message queue" (`MessagePort.postMessage`).
    port_message,
    /// Uncategorized / generic spec task source (default for unspecified callers).
    generic,

    /// Number of distinct HTML task sources (fits in a 32-bit ready bitmask).
    pub const count: usize = std.meta.tags(TaskSource).len;

    /// Scheduling priority tier across task queues (see module doc / Golden Rule 2).
    pub const Priority = enum(u2) {
        high = 0,
        normal = 1,
    };

    /// Maximum consecutive high-priority tasks executed while a normal-priority
    /// queue also has a runnable task waiting before servicing one normal task
    /// (Chromium `TaskQueueSelector::kMaxStarvationTasks = 5`).
    pub const max_starvation_tasks: u8 = 5;

    /// Comptime bitmask of high-priority task sources.
    pub const high_priority_mask: u32 = blk: {
        var mask: u32 = 0;
        for (std.meta.tags(TaskSource)) |src| {
            if (src.priority() == .high) mask |= (@as(u32, 1) << @backingInt(src));
        }
        break :blk mask;
    };

    pub inline fn priority(self: TaskSource) Priority {
        return switch (self) {
            .user_interaction => .high,
            else => .normal,
        };
    }
};

comptime {
    // Per-source queue ready masks use u32 bitsets.
    std.debug.assert(TaskSource.count <= 32);
}

/// Task - Normal-priority work (I/O callbacks, timers, etc.)
///
/// KEEP: anyopaque required - Task callbacks need type erasure because the
/// context type varies (I/O completions, timers, etc.)
///
/// Tasks represent normal asynchronous operations like I/O completion,
/// timer callbacks, etc. Only one task is processed per event loop iteration,
/// and microtasks are drained between tasks.
///
/// Spec: https://html.spec.whatwg.org/#concept-task
pub const Task = struct {
    /// Alias so callers with `runtime.EventLoopTask` can name `TaskSource`.
    pub const Source = TaskSource;

    /// KEEP: anyopaque required - Callback with type-erased context
    callback: *const fn (context: ?*anyopaque) void,

    /// KEEP: anyopaque required - Type-erased context for callback
    context: ?*anyopaque,

    /// Frees `context` for a task that will never run, because its loop is
    /// being torn down with the task still queued. Null for a task whose
    /// context owns nothing.
    ///
    /// Without it, whatever a task carries leaks whenever the page ends before
    /// the loop's next turn - a message posted in the last task, say.
    drop: ?*const fn (context: ?*anyopaque) void = null,

    /// HTML 8.1.7.1: the task's document, or null. A Document - this module
    /// cannot name runtime.Instance - BORROWED: the task does not keep it.
    /// "A task is runnable if its document is either null or fully active":
    /// a window event loop keeps a task whose document is not fully active
    /// but may be again, in its place, and drops one whose document never
    /// can be again - destroyed, freed, its realm or navigable gone -
    /// running its `drop` instead (src/browser/event_loop.zig drainTasks,
    /// dom.document_activity), so a task that sets one MUST have a `drop`
    /// that frees its context. A worker's tasks have no document and are
    /// always runnable.
    ///
    /// A global task on a Window may name the Window instead: its associated
    /// Document when the task runs is then the task's document. Stated
    /// deviation: HTML's "queue a global task" fixes the document when the
    /// task is queued, so a window reused for a new document (the initial
    /// about:blank replaced) would drop it; browsers keep such tasks with
    /// the window (Blink posts them to the frame's task runner), and
    /// webmessaging/without-ports/018.html expects the message delivered.
    document: ?*anyopaque = null,

    /// `document`'s slab generation when the task was queued
    /// (runtime.SlabAllocator.generationOf): the document may be freed, and
    /// its slot reused, while the task waits.
    document_generation: u64 = 0,

    /// HTML §8.1.7.2 task source for this task. Tasks from the same source
    /// share a FIFO queue on their event loop; defaults to `.generic`.
    source: TaskSource = .generic,
};

/// Event Loop Interface
///
/// KEEP: anyopaque required - This interface uses vtable pattern for polymorphism.
/// Different event loop implementations (test loops, platform loops, V8 integration)
/// can be used without generics or compile-time knowledge of the concrete type.
///
/// ## Vtable Pattern
///
/// This uses a vtable (virtual table) pattern for polymorphism:
/// - `ptr`: Pointer to the concrete implementation (type-erased)
/// - `vtable`: Pointer to function table for the implementation
pub const EventLoop = struct {
    /// KEEP: anyopaque required - Opaque pointer to concrete implementation
    /// (TestEventLoop, V8EventLoop, etc.)
    ptr: *anyopaque,

    /// Virtual function table
    vtable: *const VTable,

    /// KEEP: anyopaque required - Virtual function table for EventLoop implementations
    /// All function signatures use anyopaque for the self pointer
    pub const VTable = struct {
        /// Queue a microtask for execution
        ///
        /// Microtasks are high-priority and must run before the next task.
        /// Multiple microtasks may be queued and will execute in FIFO order.
        ///
        /// This function must not fail - implementations should panic on OOM.
        queueMicrotask: *const fn (ptr: *anyopaque, task: Microtask) void,

        /// Queue a task for execution
        ///
        /// Tasks are normal-priority and execute one per event loop iteration,
        /// with microtask draining between tasks.
        ///
        /// This function must not fail - implementations should panic on OOM.
        queueTask: *const fn (ptr: *anyopaque, task: Task) void,

        /// Run all pending microtasks to completion
        ///
        /// This drains the microtask queue completely. If microtasks queue
        /// additional microtasks, those are also executed before returning.
        ///
        /// This implements the "perform a microtask checkpoint" algorithm:
        /// https://html.spec.whatwg.org/#perform-a-microtask-checkpoint
        runMicrotasks: *const fn (ptr: *anyopaque) void,

        /// Run one iteration of the event loop
        ///
        /// This runs all pending microtasks, then executes one task (if any),
        /// then runs all microtasks again.
        ///
        /// Returns `true` if work was performed, `false` if the event loop
        /// is idle (no tasks or microtasks pending).
        ///
        /// This implements a simplified event loop iteration:
        /// https://html.spec.whatwg.org/#event-loop-processing-model
        runOnce: *const fn (ptr: *anyopaque) bool,

        /// Get allocator for promise creation
        ///
        /// Returns an allocator for creating promises. Promises allocated from
        /// this allocator are owned by the event loop and freed when the event
        /// loop is destroyed.
        ///
        /// This matches browser semantics where the JavaScript execution context
        /// (event loop) manages promise lifetime via garbage collection.
        ///
        /// Implementations should use an arena allocator for simple bulk deallocation.
        promiseAllocator: *const fn (ptr: *anyopaque) std.mem.Allocator,

        /// HTML "destroy a document" step 5: "Remove any tasks whose
        /// document is document from any task queue (without running those
        /// tasks)" - every task this loop holds whose `document` is
        /// `document` at `generation`, each one's `drop` run now, so what it
        /// carries (a counted hold on a node) goes with the document's
        /// destruction and not at the loop's next turn. Safe while the loop
        /// runs a task. Null for a loop whose tasks name no document (a
        /// worker's, a test's): `discardDocumentTasks` then does nothing.
        discardDocumentTasks: ?*const fn (ptr: *anyopaque, document: *anyopaque, generation: u64) void = null,
    };

    /// Queue a microtask for execution
    ///
    /// Example:
    /// ```zig
    /// const ctx = try allocator.create(MyContext);
    /// loop.queueMicrotask(.{
    ///     .callback = myCallback,
    ///     .context = ctx,
    /// });
    /// ```
    pub fn queueMicrotask(self: EventLoop, task: Microtask) void {
        self.vtable.queueMicrotask(self.ptr, task);
    }

    /// Queue a task for execution
    ///
    /// Example:
    /// ```zig
    /// loop.queueTask(.{
    ///     .callback = ioCallback,
    ///     .context = &io_context,
    /// });
    /// ```
    pub fn queueTask(self: EventLoop, task: Task) void {
        self.vtable.queueTask(self.ptr, task);
    }

    /// Run all pending microtasks
    ///
    /// Example:
    /// ```zig
    /// // After resolving a promise
    /// promise.fulfill(value);
    /// loop.runMicrotasks(); // Execute promise reactions
    /// ```
    pub fn runMicrotasks(self: EventLoop) void {
        self.vtable.runMicrotasks(self.ptr);
    }

    /// Run one iteration of the event loop
    ///
    /// Returns `true` if work was performed, `false` if idle.
    ///
    /// Example:
    /// ```zig
    /// // Run until idle
    /// while (loop.runOnce()) {
    ///     // Loop continues while there's work
    /// }
    /// ```
    pub fn runOnce(self: EventLoop) bool {
        return self.vtable.runOnce(self.ptr);
    }

    /// Get allocator for promise creation
    ///
    /// Returns an allocator for creating promises. Promises allocated from
    /// this allocator are owned by the event loop and automatically freed
    /// when the event loop is destroyed.
    ///
    /// This matches browser semantics where the JavaScript execution context
    /// manages promise lifetime via garbage collection.
    ///
    /// Example:
    /// ```zig
    /// const promise_alloc = loop.promiseAllocator();
    /// const promise = try AsyncPromise(void).init(promise_alloc, loop);
    /// // Promise is freed when loop is destroyed
    /// ```
    pub fn promiseAllocator(self: EventLoop) std.mem.Allocator {
        return self.vtable.promiseAllocator(self.ptr);
    }

    /// HTML "destroy a document" step 5 for `document` (its slab generation
    /// `generation`): the tasks this loop holds for it are removed without
    /// running, their `drop` run now (VTable.discardDocumentTasks). Nothing
    /// for a loop that keeps no task with a document.
    pub fn discardDocumentTasks(self: EventLoop, document: *anyopaque, generation: u64) void {
        const discard = self.vtable.discardDocumentTasks orelse return;
        discard(self.ptr, document, generation);
    }

    /// Run the event loop until all work is complete
    ///
    /// This is a convenience method that calls `runOnce()` in a loop
    /// until the event loop is idle.
    ///
    /// Example:
    /// ```zig
    /// // Queue some work
    /// loop.queueTask(.{ .callback = myTask, .context = null });
    ///
    /// // Run until complete
    /// loop.runUntilIdle();
    /// ```
    pub fn runUntilIdle(self: EventLoop) void {
        while (self.runOnce()) {
            // Continue until idle
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
