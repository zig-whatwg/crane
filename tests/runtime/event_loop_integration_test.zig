//! Event Loop Integration Tests (Phase 1.21)
//!
//! Comprehensive integration tests for concurrent event loop operations.
//!
//! ## Test Categories
//!
//! 1. Multi-threaded task posting
//! 2. Worker pool completion flow
//! 3. Microtask + macrotask ordering
//! 4. Timer + I/O interleaving (simulated)
//! 5. Stress tests
//!
//! ## References
//!
//! - WHATWG HTML Standard: Event loop processing model
//! - https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-processing-model

const std = @import("std");
const event_loop = @import("../../src/runtime/event_loop/root.zig");

const Scheduler = event_loop.Scheduler;
const CrossThreadTask = event_loop.CrossThreadTask;
const TaskNode = event_loop.TaskNode;
const TaskPriority = event_loop.TaskPriority;
const MicrotaskNode = event_loop.MicrotaskNode;
const WorkItem = event_loop.WorkItem;
const ThreadPool = event_loop.ThreadPool;
const TimerWheel = event_loop.TimerWheel;

// ============================================================================
// Test 1: Multi-threaded Task Posting
// ============================================================================

test "Integration - multi-threaded task posting" {
    var scheduler = Scheduler.init();

    const num_threads = 4;
    const tasks_per_thread = 100;

    var counter = std.atomic.Value(usize).init(0);
    var tasks: [num_threads * tasks_per_thread]CrossThreadTask = undefined;

    // Initialize all tasks
    for (&tasks) |*task| {
        task.* = CrossThreadTask.init(atomicIncrementCallback, &counter, .timer);
    }

    // Spawn threads to post tasks concurrently
    var threads: [num_threads]std.Thread = undefined;
    for (0..num_threads) |i| {
        threads[i] = try std.Thread.spawn(.{}, posterThread, .{
            &scheduler,
            tasks[i * tasks_per_thread ..][0..tasks_per_thread],
        });
    }

    // Wait for all threads to finish posting
    for (&threads) |*t| {
        t.join();
    }

    // Run scheduler until empty
    scheduler.runUntilEmpty();

    // Verify all tasks executed
    try std.testing.expectEqual(@as(usize, num_threads * tasks_per_thread), counter.load(.acquire));
    try std.testing.expectEqual(@as(usize, num_threads * tasks_per_thread), scheduler.getStats().cross_thread_tasks_processed);
}

fn posterThread(scheduler: *Scheduler, tasks: []CrossThreadTask) void {
    for (tasks) |*task| {
        scheduler.postTaskFromAnyThread(task);
    }
}

// ============================================================================
// Test 2: Worker Pool Completion Flow
// ============================================================================

test "Integration - worker pool round-trip" {
    var scheduler = try Scheduler.initWithPool(std.testing.allocator, 2);
    defer scheduler.deinit();

    const num_work_items = 20;
    var completions = std.atomic.Value(usize).init(0);
    var work_items: [num_work_items]WorkItem = undefined;

    // Initialize work items
    for (&work_items) |*item| {
        item.* = WorkItem.initWithCompletion(
            simulatedBlockingWork,
            completionCallback,
            &completions,
        );
    }

    // Submit all work
    for (&work_items) |*item| {
        _ = scheduler.submitWork(item);
    }

    // Run scheduler until all completions processed
    var ticks: usize = 0;
    while (completions.load(.acquire) < num_work_items and ticks < 10000) : (ticks += 1) {
        _ = scheduler.tick();
        std.Thread.yield() catch {};
    }

    try std.testing.expectEqual(@as(usize, num_work_items), completions.load(.acquire));
}

fn simulatedBlockingWork(_: ?*anyopaque) void {
    // Simulate some blocking work
    std.time.sleep(1 * std.time.ns_per_ms);
}

fn completionCallback(user_data: ?*anyopaque, _: ?*anyopaque) void {
    const counter: *std.atomic.Value(usize) = @ptrCast(@alignCast(user_data.?));
    _ = counter.fetchAdd(1, .acq_rel);
}

// ============================================================================
// Test 3: Microtask + Macrotask Ordering
// ============================================================================

test "Integration - microtask/macrotask ordering" {
    var scheduler = Scheduler.init();

    var order: [20]usize = [_]usize{0} ** 20;
    var order_idx: usize = 0;

    // Create test context
    const TestCtx = struct {
        order: *[20]usize,
        order_idx: *usize,
        id: usize,
    };

    // Scenario: Macrotask enqueues microtask, microtask enqueues another microtask
    // Expected order: macro1 -> micro1 -> micro2 -> macro2

    var ctx1 = TestCtx{ .order = &order, .order_idx = &order_idx, .id = 1 };
    var ctx2 = TestCtx{ .order = &order, .order_idx = &order_idx, .id = 2 };
    var ctx3 = TestCtx{ .order = &order, .order_idx = &order_idx, .id = 3 };
    var ctx4 = TestCtx{ .order = &order, .order_idx = &order_idx, .id = 4 };

    var macro1 = TaskNode.init(orderMacroCallback, &ctx1, .timer);
    var macro2 = TaskNode.init(orderMacroCallback, &ctx4, .timer);
    var micro1 = MicrotaskNode.init(orderMicroCallback, &ctx2);
    var micro2 = MicrotaskNode.init(orderMicroCallback, &ctx3);

    // Enqueue macro1 and macro2
    scheduler.enqueueMacrotask(&macro1, .timer);
    scheduler.enqueueMacrotask(&macro2, .timer);

    // Enqueue micro1 (will be processed after macro1)
    scheduler.enqueueMicrotask(&micro1);

    // First tick: executes macro1, then microtask checkpoint (micro1)
    _ = scheduler.tick();

    // Enqueue micro2 for next checkpoint
    scheduler.enqueueMicrotask(&micro2);

    // Second tick: executes macro2, then microtask checkpoint (micro2)
    _ = scheduler.tick();

    // Verify order
    try std.testing.expectEqual(@as(usize, 1), order[0]); // macro1
    try std.testing.expectEqual(@as(usize, 2), order[1]); // micro1
    try std.testing.expectEqual(@as(usize, 4), order[2]); // macro2
    try std.testing.expectEqual(@as(usize, 3), order[3]); // micro2
}

fn orderMacroCallback(user_data: ?*anyopaque) void {
    const ctx: *@TypeOf(.{
        .order = @as(*[20]usize, undefined),
        .order_idx = @as(*usize, undefined),
        .id = @as(usize, 0),
    }) = @ptrCast(@alignCast(user_data.?));
    ctx.order[ctx.order_idx.*] = ctx.id;
    ctx.order_idx.* += 1;
}

fn orderMicroCallback(user_data: ?*anyopaque) void {
    const ctx: *@TypeOf(.{
        .order = @as(*[20]usize, undefined),
        .order_idx = @as(*usize, undefined),
        .id = @as(usize, 0),
    }) = @ptrCast(@alignCast(user_data.?));
    ctx.order[ctx.order_idx.*] = ctx.id;
    ctx.order_idx.* += 1;
}

// ============================================================================
// Test 4: Timer Wheel Integration
// ============================================================================

test "Integration - timer wheel with scheduler" {
    const allocator = std.testing.allocator;

    var wheel = try TimerWheel.init(allocator);
    defer wheel.deinit();

    var fired_count: usize = 0;

    // Schedule multiple timers
    const timer1 = try wheel.schedule(10, timerCallback, &fired_count, false);
    _ = try wheel.schedule(20, timerCallback, &fired_count, false);
    _ = try wheel.schedule(30, timerCallback, &fired_count, false);

    // Advance time and check
    _ = wheel.advanceAndFire(15); // Should fire timer1
    try std.testing.expectEqual(@as(usize, 1), fired_count);

    // Cancel one timer
    wheel.cancel(timer1); // Already fired, but safe to call

    // Advance more
    _ = wheel.advanceAndFire(25); // Should fire timer2
    try std.testing.expectEqual(@as(usize, 2), fired_count);

    _ = wheel.advanceAndFire(35); // Should fire timer3
    try std.testing.expectEqual(@as(usize, 3), fired_count);
}

fn timerCallback(user_data: ?*anyopaque) void {
    const counter: *usize = @ptrCast(@alignCast(user_data.?));
    counter.* += 1;
}

// ============================================================================
// Test 5: Stress Test
// ============================================================================

test "Integration - stress test (1000 tasks)" {
    var scheduler = Scheduler.init();

    const num_tasks = 1000;
    var counter: usize = 0;
    var tasks: [num_tasks]TaskNode = undefined;

    // Initialize and enqueue all tasks
    for (&tasks, 0..) |*task, i| {
        const priority: TaskPriority = @enumFromInt(@as(u8, @intCast(i % 5)));
        task.* = TaskNode.init(stressCallback, &counter, priority);
        scheduler.enqueueMacrotask(task, priority);
    }

    // Run until empty
    scheduler.runUntilEmpty();

    // Verify all executed
    try std.testing.expectEqual(@as(usize, num_tasks), counter);
    try std.testing.expectEqual(@as(usize, num_tasks), scheduler.getStats().macrotasks_executed);
}

fn stressCallback(user_data: ?*anyopaque) void {
    const counter: *usize = @ptrCast(@alignCast(user_data.?));
    counter.* += 1;
}

// ============================================================================
// Test Helpers
// ============================================================================

fn atomicIncrementCallback(user_data: ?*anyopaque) void {
    const counter: *std.atomic.Value(usize) = @ptrCast(@alignCast(user_data.?));
    _ = counter.fetchAdd(1, .acq_rel);
}
