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
/// Microtasks are queued by promise resolution/rejection and must run
/// before the next task. All pending microtasks are drained before
/// processing the next task.
///
/// Spec: https://html.spec.whatwg.org/#microtask
pub const Microtask = struct {
    /// Callback to execute
    callback: *const fn (context: ?*anyopaque) void,

    /// Optional context pointer passed to callback
    context: ?*anyopaque,
};

/// Task - Normal-priority work (I/O callbacks, timers, etc.)
///
/// Tasks represent normal asynchronous operations like I/O completion,
/// timer callbacks, etc. Only one task is processed per event loop iteration,
/// and microtasks are drained between tasks.
///
/// Spec: https://html.spec.whatwg.org/#concept-task
pub const Task = struct {
    /// Callback to execute
    callback: *const fn (context: ?*anyopaque) void,

    /// Optional context pointer passed to callback
    context: ?*anyopaque,
};

/// Event Loop Interface
///
/// This interface abstracts the event loop mechanism, allowing different
/// implementations (test loops, platform loops, etc.) to be used with
/// the Streams library.
///
/// ## Vtable Pattern
///
/// This uses a vtable (virtual table) pattern for polymorphism:
/// - `ptr`: Pointer to the concrete implementation
/// - `vtable`: Pointer to function table for the implementation
///
/// This allows different event loop implementations without generics or
/// compile-time knowledge of the concrete type.
pub const EventLoop = struct {
    /// Opaque pointer to concrete implementation
    ptr: *anyopaque,

    /// Virtual function table
    vtable: *const VTable,

    /// Virtual function table for EventLoop implementations
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

test "EventLoop - vtable pattern compiles" {
    // This test just verifies the vtable pattern compiles correctly
    // Actual functionality is tested with concrete implementations

    const MockLoop = struct {
        microtask_count: usize = 0,

        const Self = @This();

        fn queueMicrotask(ptr: *anyopaque, task: Microtask) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            _ = task;
            self.microtask_count += 1;
        }

        fn queueTask(ptr: *anyopaque, task: Task) void {
            _ = ptr;
            _ = task;
        }

        fn runMicrotasks(ptr: *anyopaque) void {
            _ = ptr;
        }

        fn runOnce(ptr: *anyopaque) bool {
            _ = ptr;
            return false;
        }

        fn promiseAllocator(ptr: *anyopaque) std.mem.Allocator {
            _ = ptr;
            return std.testing.allocator;
        }

        fn eventLoop(self: *Self) EventLoop {
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
    };

    var mock = MockLoop{};
    const loop = mock.eventLoop();

    loop.queueMicrotask(.{
        .callback = struct {
            fn cb(_: ?*anyopaque) void {}
        }.cb,
        .context = null,
    });

    try testing.expectEqual(@as(usize, 1), mock.microtask_count);
}

test "EventLoop - runUntilIdle helper" {
    const MockLoop = struct {
        iterations: usize = 0,
        max_iterations: usize = 3,

        const Self = @This();

        fn queueMicrotask(_: *anyopaque, _: Microtask) void {}
        fn queueTask(_: *anyopaque, _: Task) void {}
        fn runMicrotasks(_: *anyopaque) void {}

        fn runOnce(ptr: *anyopaque) bool {
            const self: *Self = @ptrCast(@alignCast(ptr));
            if (self.iterations < self.max_iterations) {
                self.iterations += 1;
                return true; // More work
            }
            return false; // Idle
        }

        fn promiseAllocator(ptr: *anyopaque) std.mem.Allocator {
            _ = ptr;
            return std.testing.allocator;
        }

        fn eventLoop(self: *Self) EventLoop {
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
    };

    var mock = MockLoop{};
    const loop = mock.eventLoop();

    loop.runUntilIdle();

    try testing.expectEqual(@as(usize, 3), mock.iterations);
}
