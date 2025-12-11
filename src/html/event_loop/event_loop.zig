//! HTML Event Loop
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#event-loops
//! HTML Standard §8.1.7 "Event loops"
//!
//! The event loop is the core of the HTML processing model. It continually
//! runs through steps to:
//! 1. Pick a task from a task queue
//! 2. Run the task
//! 3. Perform a microtask checkpoint
//! 4. Update the rendering (for window event loops)

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");

const task_mod = @import("task.zig");
const Task = task_mod.Task;
const TaskSource = task_mod.TaskSource;
const Microtask = task_mod.Microtask;

const task_queue = @import("task_queue.zig");
const TaskQueue = task_queue.TaskQueue;
const TaskQueueSet = task_queue.TaskQueueSet;

const microtask_mod = @import("microtask.zig");
const MicrotaskQueue = microtask_mod.MicrotaskQueue;
const MicrotaskCheckpointState = microtask_mod.MicrotaskCheckpointState;
const MicrotaskCheckpointCallbacks = microtask_mod.MicrotaskCheckpointCallbacks;
const performMicrotaskCheckpoint = microtask_mod.performMicrotaskCheckpoint;

const timers_mod = @import("timers.zig");
const TimerManager = timers_mod.TimerManager;
const Timer = timers_mod.Timer;
const VisibilityState = timers_mod.VisibilityState;

const platform_mod = @import("platform");
const timer_backend = platform_mod.timer_backend;
const TimerBackend = timer_backend.TimerBackend;

/// Type of event loop.
///
/// HTML Standard §8.1.7 lines 2840-2841:
/// "The event loop of a similar-origin window agent is known as a window event loop.
/// The event loop of a dedicated worker agent, shared worker agent, or service worker
/// agent is known as a worker event loop."
pub const EventLoopType = enum {
    /// Event loop for window contexts.
    window,
    /// Event loop for dedicated/shared/service workers.
    worker,
    /// Event loop for worklets.
    worklet,
};

/// Callbacks for rendering updates in window event loops.
pub const RenderingCallbacks = struct {
    /// Run animation frame callbacks.
    /// HTML Standard §8.1.7.2 step 3.14:
    /// "For each doc of docs, run the animation frame callbacks for doc"
    run_animation_frame_callbacks: ?*const fn (context: ?*anyopaque, timestamp: f64) void,

    /// Update the rendering for a document.
    /// HTML Standard §8.1.7.2 step 3.22:
    /// "For each doc of docs, update the rendering or user interface of doc"
    update_rendering: ?*const fn (context: ?*anyopaque) void,

    /// Resize steps.
    /// HTML Standard §8.1.7.2 step 3.8:
    /// "For each doc of docs, run the resize steps for doc"
    run_resize_steps: ?*const fn (context: ?*anyopaque) void,

    /// Scroll steps.
    /// HTML Standard §8.1.7.2 step 3.9:
    /// "For each doc of docs, run the scroll steps for doc"
    run_scroll_steps: ?*const fn (context: ?*anyopaque) void,

    /// User context.
    context: ?*anyopaque,

    /// Default (no-op) callbacks.
    pub fn noOp() RenderingCallbacks {
        return RenderingCallbacks{
            .run_animation_frame_callbacks = null,
            .update_rendering = null,
            .run_resize_steps = null,
            .run_scroll_steps = null,
            .context = null,
        };
    }
};

/// HTML Event Loop.
///
/// HTML Standard §8.1.7:
/// "To coordinate events, user interaction, scripts, rendering, networking,
/// and so forth, user agents must use event loops"
pub const EventLoop = struct {
    /// Type of this event loop.
    loop_type: EventLoopType,

    /// Task queues for this event loop.
    /// HTML Standard §8.1.7 line 2847:
    /// "An event loop has one or more task queues."
    task_queues: TaskQueueSet,

    /// The microtask queue.
    /// HTML Standard §8.1.7 line 2896:
    /// "Each event loop has a microtask queue"
    microtask_queue: MicrotaskQueue,

    /// State for microtask checkpoint.
    microtask_state: MicrotaskCheckpointState,

    /// The currently running task.
    /// HTML Standard §8.1.7 line 2894:
    /// "Each event loop has a currently running task, which is either a task or null."
    currently_running_task: ?*Task,

    /// Timer manager for setTimeout/setInterval.
    timer_manager: TimerManager,

    /// Platform timer backend.
    platform: TimerBackend,

    /// Last render opportunity time (for window event loops).
    /// HTML Standard §8.1.7 line 2900:
    /// "Each window event loop has a DOMHighResTimeStamp last render opportunity time"
    last_render_opportunity_time: i64,

    /// Last idle period start time (for window event loops).
    /// HTML Standard §8.1.7 line 2902:
    /// "Each window event loop has a DOMHighResTimeStamp last idle period start time"
    last_idle_period_start_time: i64,

    /// Target frame rate in Hz (default 60).
    target_frame_rate: u32,

    /// Next task ID for unique identification.
    next_task_id: u64,

    /// Whether the event loop should continue running.
    running: bool,

    /// Callbacks for microtask checkpoint.
    microtask_callbacks: MicrotaskCheckpointCallbacks,

    /// Callbacks for rendering.
    rendering_callbacks: RenderingCallbacks,

    /// Allocator for memory management.
    allocator: Allocator,

    /// Initialize a new event loop.
    pub fn init(
        allocator: Allocator,
        loop_type: EventLoopType,
        platform: TimerBackend,
    ) !EventLoop {
        return EventLoop{
            .loop_type = loop_type,
            .task_queues = try TaskQueueSet.init(allocator),
            .microtask_queue = MicrotaskQueue.init(allocator),
            .microtask_state = MicrotaskCheckpointState.init(),
            .currently_running_task = null,
            .timer_manager = TimerManager.init(allocator, platform),
            .platform = platform,
            .last_render_opportunity_time = 0,
            .last_idle_period_start_time = 0,
            .target_frame_rate = 60,
            .next_task_id = 1,
            .running = false,
            .microtask_callbacks = MicrotaskCheckpointCallbacks.noOp(),
            .rendering_callbacks = RenderingCallbacks.noOp(),
            .allocator = allocator,
        };
    }

    /// Free all resources.
    pub fn deinit(self: *EventLoop) void {
        self.task_queues.deinit();
        self.microtask_queue.deinit();
        self.timer_manager.deinit();
    }

    /// Set microtask checkpoint callbacks.
    pub fn setMicrotaskCallbacks(self: *EventLoop, callbacks: MicrotaskCheckpointCallbacks) void {
        self.microtask_callbacks = callbacks;
    }

    /// Set rendering callbacks.
    pub fn setRenderingCallbacks(self: *EventLoop, callbacks: RenderingCallbacks) void {
        self.rendering_callbacks = callbacks;
    }

    /// Queue a task on a task source.
    ///
    /// HTML Standard §8.1.7.1 "Queuing tasks" lines 2909-2928:
    /// To queue a task on a task source source, which performs a series of steps steps:
    /// 1. Let task be a new task.
    /// 2. Set task's steps to steps.
    /// 3. Set task's source to source.
    /// 4. Set task's document to the document.
    /// 5. Set task's script evaluation environment settings object set to an empty set.
    /// 6. Let queue be the task queue to which source is associated on event loop.
    /// 7. Append task to queue.
    /// Queue a task on a task source.
    /// The document parameter should be a *runtime.Instance but is kept as
    /// anyopaque due to module dependency constraints (html_core cannot depend on runtime).
    pub fn queueTask(
        self: *EventLoop,
        source: TaskSource,
        steps: Task.TaskSteps,
        context: ?*anyopaque,
        document: ?*anyopaque,
    ) !u64 {
        const task = try self.allocator.create(Task);
        const id = self.next_task_id;
        self.next_task_id += 1;

        task.* = Task.init(
            self.allocator,
            id,
            source,
            steps,
            context,
            document,
        );

        try self.task_queues.queueTask(task);
        return id;
    }

    /// Queue a microtask.
    ///
    /// HTML Standard §8.1.7.1 "Queuing tasks" lines 2945-2963:
    /// To queue a microtask which performs a series of steps steps:
    /// Queue a microtask.
    /// The document parameter should be a *runtime.Instance but is kept as
    /// anyopaque due to module dependency constraints (html_core cannot depend on runtime).
    pub fn queueMicrotask(
        self: *EventLoop,
        steps: Microtask.MicrotaskSteps,
        context: ?*anyopaque,
        document: ?*anyopaque,
    ) !void {
        const microtask = Microtask.init(steps, context, document);
        try self.microtask_queue.enqueue(microtask);
    }

    /// Set a timeout (setTimeout).
    pub fn setTimeout(
        self: *EventLoop,
        callback: Timer.TimerCallback,
        delay_ms: i64,
        context: ?*anyopaque,
    ) !u32 {
        return self.timer_manager.setTimeout(callback, delay_ms, context);
    }

    /// Set an interval (setInterval).
    pub fn setInterval(
        self: *EventLoop,
        callback: Timer.TimerCallback,
        delay_ms: i64,
        context: ?*anyopaque,
    ) !u32 {
        return self.timer_manager.setInterval(callback, delay_ms, context);
    }

    /// Clear a timeout.
    pub fn clearTimeout(self: *EventLoop, id: u32) void {
        self.timer_manager.clearTimeout(id);
    }

    /// Clear an interval.
    pub fn clearInterval(self: *EventLoop, id: u32) void {
        self.timer_manager.clearInterval(id);
    }

    /// Perform a microtask checkpoint.
    ///
    /// HTML Standard §8.1.7.2 "Processing model" lines 3219-3248
    pub fn performMicrotaskCheckpointFn(self: *EventLoop) void {
        performMicrotaskCheckpoint(
            &self.microtask_queue,
            &self.microtask_state,
            self.microtask_callbacks,
        );
    }

    /// Run a single iteration of the event loop.
    ///
    /// HTML Standard §8.1.7.2 "Processing model" lines 2986-3217:
    /// An event loop must continually run through the following steps for as long as it exists.
    pub fn spin(self: *EventLoop) !void {
        const now = self.platform.getCurrentTime();

        // Step 1: Let oldestTask and taskStartTime be null.
        var oldest_task: ?*Task = null;
        var task_start_time: i64 = 0;

        // Process ready timers first (they may queue tasks)
        _ = try self.timer_manager.processReadyTimers(now);

        // Step 2: If the event loop has a task queue with at least one runnable task
        if (self.task_queues.hasRunnableTask()) {
            // Step 2.1: Let taskQueue be one such task queue, chosen in an
            // implementation-defined manner.
            // Step 2.2: Set taskStartTime to the unsafe shared current time.
            task_start_time = now;

            // Step 2.3: Set oldestTask to the first runnable task in taskQueue,
            // and remove it from taskQueue.
            oldest_task = self.task_queues.dequeueRunnable();
        }

        if (oldest_task) |task| {
            // Step 2.4: If oldestTask's document is not null, then record task
            // start time given taskStartTime and oldestTask's document.
            // (TODO: Implement task timing)

            // Step 2.5: Set the event loop's currently running task to oldestTask.
            self.currently_running_task = task;

            // Step 2.6: Perform oldestTask's steps.
            task.run();

            // Step 2.7: Set the event loop's currently running task back to null.
            self.currently_running_task = null;

            // Step 2.8: Perform a microtask checkpoint.
            self.performMicrotaskCheckpointFn();

            // Step 3: Let taskEndTime be the unsafe shared current time.
            // (Used for long task reporting - not yet implemented)
            // const task_end_time = self.platform.getCurrentTime();
            // TODO: Report long tasks using task_start_time and task_end_time

            // Step 4: Report long tasks, record task end time, etc.
            // (TODO: Implement performance monitoring)

            // Clean up the task
            task.deinit();
            self.allocator.destroy(task);
        }

        // Step 5: If this is a window event loop that has no runnable task
        if (self.loop_type == .window and !self.task_queues.hasRunnableTask()) {
            // Step 5.1: Set this event loop's last idle period start time
            self.last_idle_period_start_time = self.platform.getCurrentTime();

            // Step 5.2-3: Compute deadline and start idle period
            // requestIdleCallback infrastructure is implemented in rendering.zig (IdleCallbackManager)
            // and exposed via Window.requestIdleCallback/cancelIdleCallback.
            // Full event loop integration requires the Window to pass its IdleCallbackManager
            // to the event loop, which would then invoke callbacks during this idle period.
            // For now, Window stores callbacks via IdleCallbackManager, and apps using
            // the event loop directly can use IdleCallbackManager for idle scheduling.
        }

        // Step 6: If this is a worker event loop
        if (self.loop_type == .worker) {
            // TODO: Handle worker-specific rendering and closing
        }

        // Check if we should update rendering (window event loops)
        if (self.loop_type == .window) {
            const frame_interval = @divTrunc(@as(i64, 1000), @as(i64, self.target_frame_rate));
            const time_since_last_render = now - self.last_render_opportunity_time;

            if (time_since_last_render >= frame_interval) {
                self.last_render_opportunity_time = now;
                try self.updateRendering();
            }
        }
    }

    /// Update the rendering.
    ///
    /// HTML Standard §8.1.7.2 "Processing model" step 3:
    /// "queue a global task on the rendering task source given navigable's
    /// active window to update the rendering"
    fn updateRendering(self: *EventLoop) !void {
        const now = self.platform.getCurrentTime();
        const timestamp = @as(f64, @floatFromInt(now));

        // Step 3.8: Run resize steps
        if (self.rendering_callbacks.run_resize_steps) |run_resize| {
            run_resize(self.rendering_callbacks.context);
        }

        // Step 3.9: Run scroll steps
        if (self.rendering_callbacks.run_scroll_steps) |run_scroll| {
            run_scroll(self.rendering_callbacks.context);
        }

        // Step 3.14: Run animation frame callbacks
        if (self.rendering_callbacks.run_animation_frame_callbacks) |run_raf| {
            run_raf(self.rendering_callbacks.context, timestamp);
        }

        // Step 3.22: Update the rendering
        if (self.rendering_callbacks.update_rendering) |update| {
            update(self.rendering_callbacks.context);
        }
    }

    /// Run the event loop until stopped or no more work.
    pub fn run(self: *EventLoop) !void {
        self.running = true;

        while (self.running) {
            // Check if there's any work to do
            const has_tasks = self.task_queues.hasRunnableTask();
            const has_microtasks = !self.microtask_queue.isEmpty();
            const has_timers = self.timer_manager.hasPendingTimers();

            if (!has_tasks and !has_microtasks and !has_timers) {
                // No work to do, exit
                break;
            }

            try self.spin();

            // For window event loops, we might want to sleep until next timer
            if (self.loop_type == .window) {
                const next_wake = self.timer_manager.getNextWakeTime();
                if (!has_tasks and !has_microtasks and next_wake != null) {
                    // Sleep until next timer
                    const now = self.platform.getCurrentTime();
                    const sleep_time = next_wake.? - now;
                    if (sleep_time > 0) {
                        _ = self.platform.sleepUntilWakeup(sleep_time);
                    }
                }
            }
        }
    }

    /// Stop the event loop.
    pub fn stop(self: *EventLoop) void {
        self.running = false;
    }

    /// Check if the event loop has any pending work.
    pub fn hasPendingWork(self: *const EventLoop) bool {
        return self.task_queues.hasRunnableTask() or
            !self.microtask_queue.isEmpty() or
            self.timer_manager.hasPendingTimers();
    }
};

test "EventLoop - basic initialization" {
    const allocator = std.testing.allocator;

    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var event_loop = try EventLoop.init(allocator, .window, mock.backend());
    defer event_loop.deinit();

    try std.testing.expectEqual(EventLoopType.window, event_loop.loop_type);
    try std.testing.expect(event_loop.currently_running_task == null);
    try std.testing.expect(!event_loop.hasPendingWork());
}

test "EventLoop - queue and process task" {
    const allocator = std.testing.allocator;

    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var event_loop = try EventLoop.init(allocator, .window, mock.backend());
    defer event_loop.deinit();

    var executed = false;
    _ = try event_loop.queueTask(
        .dom_manipulation,
        struct {
            fn steps(ctx: ?*anyopaque) void {
                const flag: *bool = @ptrCast(@alignCast(ctx.?));
                flag.* = true;
            }
        }.steps,
        @ptrCast(&executed),
        null,
    );

    try std.testing.expect(event_loop.hasPendingWork());
    try std.testing.expect(!executed);

    try event_loop.spin();

    try std.testing.expect(executed);
    try std.testing.expect(!event_loop.hasPendingWork());
}

test "EventLoop - microtasks run after task" {
    const allocator = std.testing.allocator;

    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var event_loop = try EventLoop.init(allocator, .window, mock.backend());
    defer event_loop.deinit();

    var order: u32 = 0;

    // Queue a task that queues a microtask
    _ = try event_loop.queueTask(
        .dom_manipulation,
        struct {
            fn steps(ctx: ?*anyopaque) void {
                const o: *u32 = @ptrCast(@alignCast(ctx.?));
                o.* = o.* * 10 + 1; // Task runs first
            }
        }.steps,
        @ptrCast(&order),
        null,
    );

    // Queue a microtask
    try event_loop.queueMicrotask(
        struct {
            fn steps(ctx: ?*anyopaque) void {
                const o: *u32 = @ptrCast(@alignCast(ctx.?));
                o.* = o.* * 10 + 2; // Microtask runs second
            }
        }.steps,
        @ptrCast(&order),
        null,
    );

    try event_loop.spin();

    // Task (1) then microtask (2)
    try std.testing.expectEqual(@as(u32, 12), order);
}

test "EventLoop - setTimeout integration" {
    const allocator = std.testing.allocator;

    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var event_loop = try EventLoop.init(allocator, .window, mock.backend());
    defer event_loop.deinit();

    var executed = false;
    _ = try event_loop.setTimeout(
        struct {
            fn callback(ctx: ?*anyopaque) void {
                const flag: *bool = @ptrCast(@alignCast(ctx.?));
                flag.* = true;
            }
        }.callback,
        100,
        @ptrCast(&executed),
    );

    try std.testing.expect(event_loop.hasPendingWork());

    // Spin without advancing time
    try event_loop.spin();
    try std.testing.expect(!executed);

    // Advance time and spin again
    _ = mock.advanceTime(150);
    try event_loop.spin();
    try std.testing.expect(executed);
}

test "EventLoop - run until complete" {
    const allocator = std.testing.allocator;

    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var event_loop = try EventLoop.init(allocator, .window, mock.backend());
    defer event_loop.deinit();

    var count: u32 = 0;

    // Queue multiple tasks
    _ = try event_loop.queueTask(
        .dom_manipulation,
        struct {
            fn steps(ctx: ?*anyopaque) void {
                const c: *u32 = @ptrCast(@alignCast(ctx.?));
                c.* += 1;
            }
        }.steps,
        @ptrCast(&count),
        null,
    );

    _ = try event_loop.queueTask(
        .networking,
        struct {
            fn steps(ctx: ?*anyopaque) void {
                const c: *u32 = @ptrCast(@alignCast(ctx.?));
                c.* += 1;
            }
        }.steps,
        @ptrCast(&count),
        null,
    );

    _ = try event_loop.queueTask(
        .timer,
        struct {
            fn steps(ctx: ?*anyopaque) void {
                const c: *u32 = @ptrCast(@alignCast(ctx.?));
                c.* += 1;
            }
        }.steps,
        @ptrCast(&count),
        null,
    );

    // Run until all tasks complete
    try event_loop.run();

    try std.testing.expectEqual(@as(u32, 3), count);
    try std.testing.expect(!event_loop.hasPendingWork());
}
