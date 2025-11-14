//! Test Event Loop for Deterministic Async Testing
//!
//! This module provides a simple, controllable event loop implementation
//! specifically designed for testing async promise behavior. Unlike production
//! event loops that may integrate with platform APIs, this implementation is
//! purely in-memory and deterministic.
//!
//! ## Use Cases
//!
//! 1. **Unit Testing**: Test async promise behavior without platform dependencies
//! 2. **Integration Testing**: Test stream operations with controlled async flow
//! 3. **Debugging**: Step through async operations one microtask at a time
//!
//! ## Design
//!
//! - **FIFO Queues**: Microtasks and tasks are processed in order
//! - **Deterministic**: Same inputs always produce same execution order
//! - **Manual Control**: Caller decides when to run microtasks/tasks
//! - **Memory Safe**: Proper cleanup with defer, leak detection in tests
//!
//! ## Example Usage
//!
//! ```zig
//! test "async operation" {
//!     const allocator = std.testing.allocator;
//!     var loop = TestEventLoop.init(allocator);
//!     defer loop.deinit();
//!
//!     // Queue some work
//!     loop.eventLoop().queueMicrotask(.{
//!         .callback = myCallback,
//!         .context = &data,
//!     });
//!
//!     // Execute microtasks
//!     loop.eventLoop().runMicrotasks();
//!
//!     // Verify results
//!     try testing.expect(data.completed);
//! }
//! ```
//!
//! ## Thread Safety
//!
//! This implementation is **NOT thread-safe**. It's designed for single-threaded
//! testing only, matching the JavaScript execution model.

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");
const event_loop = @import("event_loop");

/// Test event loop implementation
///
/// Provides a controllable, deterministic event loop for testing async
/// promise operations without platform dependencies.
///
/// The event loop owns an arena allocator for promise allocation, matching
/// browser semantics where the JavaScript execution context (event loop)
/// manages promise lifetime via garbage collection.
pub const TestEventLoop = struct {
    allocator: Allocator,
    microtasks: infra.List(event_loop.Microtask),
    tasks: infra.List(event_loop.Task),
    promise_arena: std.heap.ArenaAllocator,

    /// Statistics for debugging and verification
    stats: Stats,

    const Self = @This();

    /// Statistics tracked by the test event loop
    pub const Stats = struct {
        /// Total microtasks queued
        microtasks_queued: usize = 0,

        /// Total microtasks executed
        microtasks_executed: usize = 0,

        /// Total tasks queued
        tasks_queued: usize = 0,

        /// Total tasks executed
        tasks_executed: usize = 0,

        /// Total runOnce() calls
        iterations: usize = 0,

        /// Reset all statistics
        pub fn reset(self: *Stats) void {
            self.* = .{};
        }
    };

    /// Initialize a new test event loop
    ///
    /// The allocator is used for internal queue storage. The loop must be
    /// deinitialized with `deinit()` to free resources.
    ///
    /// Example:
    /// ```zig
    /// var loop = TestEventLoop.init(allocator);
    /// defer loop.deinit();
    /// ```
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .microtasks = infra.List(event_loop.Microtask).init(allocator),
            .tasks = infra.List(event_loop.Task).init(allocator),
            .promise_arena = std.heap.ArenaAllocator.init(allocator),
            .stats = .{},
        };
    }

    /// Free all resources
    ///
    /// This clears any pending microtasks and tasks and frees queue memory.
    /// After calling deinit(), the loop cannot be used.
    ///
    /// The promise arena is freed, destroying all promises allocated by this
    /// event loop. This matches browser semantics where the JavaScript execution
    /// context's garbage collector frees all promises when the context is destroyed.
    ///
    /// IMPORTANT: This does NOT execute pending microtasks. Any resources
    /// associated with pending microtasks will leak. Always run the event loop
    /// to completion (via runUntilIdle()) before calling deinit().
    pub fn deinit(self: *Self) void {
        self.microtasks.deinit();
        self.tasks.deinit();
        self.promise_arena.deinit();
    }

    /// Get an EventLoop interface for this test loop
    ///
    /// This returns an EventLoop that can be used with async promise APIs.
    ///
    /// Example:
    /// ```zig
    /// var test_loop = TestEventLoop.init(allocator);
    /// const loop = test_loop.eventLoop();
    /// loop.queueMicrotask(...);
    /// ```
    pub fn eventLoop(self: *Self) event_loop.EventLoop {
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

    /// Get allocator for promise creation
    ///
    /// Returns an arena allocator that owns all promises. Promises allocated
    /// from this allocator are automatically freed when the event loop is destroyed.
    ///
    /// This matches browser semantics where the JavaScript execution context
    /// (event loop) manages promise lifetime via garbage collection.
    pub fn promiseAllocator(ptr: *anyopaque) Allocator {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.promise_arena.allocator();
    }

    /// Check if the event loop is idle (no pending work)
    ///
    /// Returns `true` if there are no pending microtasks or tasks.
    ///
    /// Example:
    /// ```zig
    /// try testing.expect(loop.isIdle());
    /// loop.eventLoop().queueMicrotask(...);
    /// try testing.expect(!loop.isIdle());
    /// ```
    pub fn isIdle(self: *const Self) bool {
        return self.microtasks.len == 0 and self.tasks.len == 0;
    }

    /// Get the number of pending microtasks
    pub fn pendingMicrotasks(self: *const Self) usize {
        return self.microtasks.len;
    }

    /// Get the number of pending tasks
    pub fn pendingTasks(self: *const Self) usize {
        return self.tasks.len;
    }

    /// Clear all pending microtasks and tasks
    ///
    /// This is useful for test cleanup or resetting to a known state.
    ///
    /// Example:
    /// ```zig
    /// loop.clear();
    /// try testing.expect(loop.isIdle());
    /// ```
    pub fn clear(self: *Self) void {
        self.microtasks.clear();
        self.tasks.clear();
    }

    /// Run all pending microtasks and tasks until the loop is idle
    ///
    /// This drains the event loop, executing all queued work. It's primarily
    /// used for cleanup before deinit() to prevent resource leaks from
    /// unexecuted promise reactions.
    ///
    /// IMPORTANT: This has a safety limit of 10000 iterations to prevent
    /// infinite loops. If you hit this limit, you have a bug in your code
    /// (microtasks queuing more microtasks indefinitely).
    ///
    /// Example:
    /// ```zig
    /// loop.runUntilIdle();
    /// try testing.expect(loop.isIdle());
    /// ```
    pub fn runUntilIdle(self: *Self) void {
        var iterations: usize = 0;
        const max_iterations = 10000; // Safety limit
        while (!self.isIdle() and iterations < max_iterations) : (iterations += 1) {
            _ = runOnce(self);
        }
        if (iterations >= max_iterations) {
            @panic("TestEventLoop.runUntilIdle: hit safety limit - infinite loop detected");
        }
    }

    // ========================================================================
    // EventLoop VTable Implementation
    // ========================================================================

    fn queueMicrotask(ptr: *anyopaque, task: event_loop.Microtask) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.microtasks.append(task) catch @panic("TestEventLoop: OOM in queueMicrotask");
        self.stats.microtasks_queued += 1;
    }

    fn queueTask(ptr: *anyopaque, task: event_loop.Task) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.tasks.append(task) catch @panic("TestEventLoop: OOM in queueTask");
        self.stats.tasks_queued += 1;
    }

    fn runMicrotasks(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));

        // Drain all microtasks, including any queued by microtasks themselves
        // This matches the "perform a microtask checkpoint" algorithm
        while (self.microtasks.len > 0) {
            // Take first microtask
            const task = self.microtasks.remove(0) catch unreachable;
            self.stats.microtasks_executed += 1;

            // Execute it
            task.callback(task.context);

            // Loop continues - any microtasks queued during execution will run
        }
    }

    fn runOnce(ptr: *anyopaque) bool {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.stats.iterations += 1;

        // Step 1: Run all pending microtasks
        runMicrotasks(self);

        // Step 2: Run one task (if any)
        if (self.tasks.len > 0) {
            const task = self.tasks.remove(0) catch unreachable;
            self.stats.tasks_executed += 1;
            task.callback(task.context);

            // Step 3: Run microtasks again (may have been queued by task)
            runMicrotasks(self);

            return true; // Work was performed
        }

        // No tasks to run - idle
        return false;
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "TestEventLoop - init and deinit" {
    const allocator = testing.allocator;
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    try testing.expect(loop.isIdle());
    try testing.expectEqual(@as(usize, 0), loop.pendingMicrotasks());
    try testing.expectEqual(@as(usize, 0), loop.pendingTasks());
}

test "TestEventLoop - queue and execute microtask" {
    const allocator = testing.allocator;
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    var executed = false;
    const callback = struct {
        fn cb(ctx: ?*anyopaque) void {
            const flag: *bool = @ptrCast(@alignCast(ctx.?));
            flag.* = true;
        }
    }.cb;

    const event_loop_interface = loop.eventLoop();
    event_loop_interface.queueMicrotask(.{
        .callback = callback,
        .context = &executed,
    });

    // Not executed yet
    try testing.expect(!executed);
    try testing.expectEqual(@as(usize, 1), loop.pendingMicrotasks());
    try testing.expectEqual(@as(usize, 1), loop.stats.microtasks_queued);
    try testing.expectEqual(@as(usize, 0), loop.stats.microtasks_executed);

    // Run microtasks
    event_loop_interface.runMicrotasks();

    // Now executed
    try testing.expect(executed);
    try testing.expectEqual(@as(usize, 0), loop.pendingMicrotasks());
    try testing.expectEqual(@as(usize, 1), loop.stats.microtasks_executed);
    try testing.expect(loop.isIdle());
}

test "TestEventLoop - microtasks can queue more microtasks" {
    const allocator = testing.allocator;
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    const Context = struct {
        count: usize,
        max: usize,
        loop: *TestEventLoop,

        fn increment(ctx: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(ctx.?));
            self.count += 1;

            if (self.count < self.max) {
                // Queue another microtask
                self.loop.eventLoop().queueMicrotask(.{
                    .callback = increment,
                    .context = self,
                });
            }
        }
    };

    var ctx = Context{
        .count = 0,
        .max = 5,
        .loop = &loop,
    };

    loop.eventLoop().queueMicrotask(.{
        .callback = Context.increment,
        .context = &ctx,
    });

    // Run all microtasks (including nested ones)
    loop.eventLoop().runMicrotasks();

    try testing.expectEqual(@as(usize, 5), ctx.count);
    try testing.expectEqual(@as(usize, 5), loop.stats.microtasks_queued);
    try testing.expectEqual(@as(usize, 5), loop.stats.microtasks_executed);
    try testing.expect(loop.isIdle());
}

test "TestEventLoop - queue and execute task" {
    const allocator = testing.allocator;
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    var executed = false;
    const callback = struct {
        fn cb(ctx: ?*anyopaque) void {
            const flag: *bool = @ptrCast(@alignCast(ctx.?));
            flag.* = true;
        }
    }.cb;

    loop.eventLoop().queueTask(.{
        .callback = callback,
        .context = &executed,
    });

    try testing.expect(!executed);
    try testing.expectEqual(@as(usize, 1), loop.pendingTasks());

    // runOnce executes one task
    const did_work = loop.eventLoop().runOnce();

    try testing.expect(did_work);
    try testing.expect(executed);
    try testing.expectEqual(@as(usize, 0), loop.pendingTasks());
    try testing.expect(loop.isIdle());
}

test "TestEventLoop - runOnce order (microtasks before task)" {
    const allocator = testing.allocator;
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    var order = infra.List(u8).init(allocator);
    defer order.deinit();

    const Context = struct {
        list: *infra.List(u8),
    };

    var ctx = Context{
        .list = &order,
    };

    const Callbacks = struct {
        fn microtask(ctx_ptr: ?*anyopaque) void {
            const c: *Context = @ptrCast(@alignCast(ctx_ptr.?));
            c.list.append('M') catch unreachable;
        }

        fn task(ctx_ptr: ?*anyopaque) void {
            const c: *Context = @ptrCast(@alignCast(ctx_ptr.?));
            c.list.append('T') catch unreachable;
        }
    };

    // Queue task first, then microtask
    loop.eventLoop().queueTask(.{ .callback = Callbacks.task, .context = &ctx });
    loop.eventLoop().queueMicrotask(.{ .callback = Callbacks.microtask, .context = &ctx });

    _ = loop.eventLoop().runOnce();

    // Microtask should run before task
    try testing.expectEqual(@as(usize, 2), order.len);
    try testing.expectEqual(@as(u8, 'M'), order.get(0).?);
    try testing.expectEqual(@as(u8, 'T'), order.get(1).?);
}

test "TestEventLoop - runOnce only runs one task" {
    const allocator = testing.allocator;
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    var count: usize = 0;
    const callback = struct {
        fn cb(ctx: ?*anyopaque) void {
            const counter: *usize = @ptrCast(@alignCast(ctx.?));
            counter.* += 1;
        }
    }.cb;

    // Queue 3 tasks
    loop.eventLoop().queueTask(.{ .callback = callback, .context = &count });
    loop.eventLoop().queueTask(.{ .callback = callback, .context = &count });
    loop.eventLoop().queueTask(.{ .callback = callback, .context = &count });

    // First runOnce - executes 1 task
    _ = loop.eventLoop().runOnce();
    try testing.expectEqual(@as(usize, 1), count);
    try testing.expectEqual(@as(usize, 2), loop.pendingTasks());

    // Second runOnce - executes 1 task
    _ = loop.eventLoop().runOnce();
    try testing.expectEqual(@as(usize, 2), count);
    try testing.expectEqual(@as(usize, 1), loop.pendingTasks());

    // Third runOnce - executes 1 task
    _ = loop.eventLoop().runOnce();
    try testing.expectEqual(@as(usize, 3), count);
    try testing.expect(loop.isIdle());
}

test "TestEventLoop - runUntilIdle" {
    const allocator = testing.allocator;
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    var count: usize = 0;
    const callback = struct {
        fn cb(ctx: ?*anyopaque) void {
            const counter: *usize = @ptrCast(@alignCast(ctx.?));
            counter.* += 1;
        }
    }.cb;

    // Queue multiple tasks
    loop.eventLoop().queueTask(.{ .callback = callback, .context = &count });
    loop.eventLoop().queueTask(.{ .callback = callback, .context = &count });
    loop.eventLoop().queueTask(.{ .callback = callback, .context = &count });

    // Run until idle
    loop.eventLoop().runUntilIdle();

    try testing.expectEqual(@as(usize, 3), count);
    try testing.expect(loop.isIdle());
}

test "TestEventLoop - clear" {
    const allocator = testing.allocator;
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    const noop = struct {
        fn cb(_: ?*anyopaque) void {}
    }.cb;

    loop.eventLoop().queueMicrotask(.{ .callback = noop, .context = null });
    loop.eventLoop().queueTask(.{ .callback = noop, .context = null });

    try testing.expect(!loop.isIdle());

    loop.clear();

    try testing.expect(loop.isIdle());
}

test "TestEventLoop - statistics" {
    const allocator = testing.allocator;
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    const noop = struct {
        fn cb(_: ?*anyopaque) void {}
    }.cb;

    // Queue and execute
    loop.eventLoop().queueMicrotask(.{ .callback = noop, .context = null });
    loop.eventLoop().queueMicrotask(.{ .callback = noop, .context = null });
    loop.eventLoop().queueTask(.{ .callback = noop, .context = null });

    try testing.expectEqual(@as(usize, 2), loop.stats.microtasks_queued);
    try testing.expectEqual(@as(usize, 1), loop.stats.tasks_queued);
    try testing.expectEqual(@as(usize, 0), loop.stats.iterations);

    loop.eventLoop().runUntilIdle();

    try testing.expectEqual(@as(usize, 2), loop.stats.microtasks_executed);
    try testing.expectEqual(@as(usize, 1), loop.stats.tasks_executed);
    // runUntilIdle calls runOnce until false, so: 1 iteration with work + 1 iteration idle = 2
    try testing.expectEqual(@as(usize, 2), loop.stats.iterations);

    // Reset stats
    loop.stats.reset();
    try testing.expectEqual(@as(usize, 0), loop.stats.microtasks_queued);
}
