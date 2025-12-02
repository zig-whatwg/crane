//! HTML Event Loop Task
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#concept-task
//! HTML Standard §8.1.7 "Event loops" - Task definition
//!
//! A task encapsulates algorithms that are responsible for work such as:
//! - Dispatching events
//! - Parsing HTML
//! - Calling callbacks
//! - Processing fetched resources
//! - Reacting to DOM manipulation

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Task sources used to group and serialize related tasks.
///
/// HTML Standard §8.1.7.3 "Generic task sources"
/// Per its source field, each task is defined as coming from a specific task source.
/// For each event loop, every task source must be associated with a specific task queue.
pub const TaskSource = enum {
    /// The DOM manipulation task source.
    /// Used for features that react to DOM manipulations, such as
    /// things that happen in a non-blocking fashion when an element
    /// is inserted into the document.
    dom_manipulation,

    /// The user interaction task source.
    /// Used for features that react to user interaction, such as
    /// keyboard or mouse input.
    user_interaction,

    /// The networking task source.
    /// Used for features that trigger in response to network activity.
    networking,

    /// The navigation and traversal task source.
    /// Used by the navigation and session history APIs.
    navigation_and_traversal,

    /// The rendering task source.
    /// Used for update the rendering tasks.
    rendering,

    /// Timer task source.
    /// Used for setTimeout/setInterval callbacks.
    timer,

    /// The microtask task source.
    /// Used when a microtask is moved to a regular task queue
    /// (when it spins the event loop during execution).
    microtask,

    /// History traversal task source.
    /// Used for history.back(), history.forward(), history.go().
    history_traversal,

    /// Media element task source.
    /// Used for media playback events.
    media_element,

    /// Canvas blob serialization task source.
    /// Used for canvas.toBlob() callbacks.
    canvas_blob_serialization,

    /// Storage task source.
    /// Used for storage events.
    storage,

    /// MessagePort task source.
    /// Used for postMessage callbacks.
    message_port,

    /// WebSocket task source.
    /// Used for WebSocket events.
    websocket,

    /// IndexedDB task source.
    /// Used for IndexedDB callbacks.
    indexeddb,

    /// Performance timeline task source.
    /// Used for performance observer callbacks.
    performance_timeline,

    /// Idle callback task source.
    /// Used for requestIdleCallback.
    idle_callback,
};

/// A task that can be queued and executed by the event loop.
///
/// HTML Standard §8.1.7 lines 2872-2885:
/// "Formally, a task is a struct which has:
/// - Steps: A series of steps specifying the work to be done by the task.
/// - A source: One of the task sources, used to group and serialize related tasks.
/// - A document: A Document associated with the task, or null for tasks not in a window event loop.
/// - A script evaluation environment settings object set: A set of environment settings objects."
pub const Task = struct {
    /// Unique identifier for tracking/debugging.
    id: u64,

    /// The task source this task came from.
    source: TaskSource,

    /// Document associated with the task, or null for non-window event loops.
    /// A task is "runnable" if its document is either null or fully active.
    document: ?*anyopaque, // TODO: Replace with *Document when available

    /// The steps to execute when this task runs.
    steps: TaskSteps,

    /// User-provided context for the task callback.
    context: ?*anyopaque,

    /// Whether this task has been cancelled.
    cancelled: bool,

    /// Allocator used for this task (for cleanup).
    allocator: Allocator,

    /// Function pointer type for task steps.
    /// The function receives the task context and should perform the task's work.
    pub const TaskSteps = *const fn (context: ?*anyopaque) void;

    /// Initialize a new task.
    pub fn init(
        allocator: Allocator,
        id: u64,
        source: TaskSource,
        steps: TaskSteps,
        context: ?*anyopaque,
        document: ?*anyopaque,
    ) Task {
        return Task{
            .id = id,
            .source = source,
            .document = document,
            .steps = steps,
            .context = context,
            .cancelled = false,
            .allocator = allocator,
        };
    }

    /// Execute this task's steps.
    pub fn run(self: *Task) void {
        if (self.cancelled) return;
        self.steps(self.context);
    }

    /// Cancel this task, preventing it from running.
    pub fn cancel(self: *Task) void {
        self.cancelled = true;
    }

    /// Check if this task is runnable.
    /// HTML Standard §8.1.7 line 2886:
    /// "A task is runnable if its document is either null or fully active."
    pub fn isRunnable(self: *const Task) bool {
        if (self.cancelled) return false;

        // If document is null, task is runnable
        if (self.document == null) return true;

        // TODO: Check if document is fully active
        // For now, assume all documents with non-null pointers are active
        return true;
    }

    /// Free resources associated with this task.
    pub fn deinit(self: *Task) void {
        // Task itself doesn't own the context or document,
        // so we don't free them here.
        _ = self;
    }
};

/// A microtask is a colloquial way of referring to a task that was
/// created via the "queue a microtask" algorithm.
///
/// HTML Standard §8.1.7 line 2896:
/// "The microtask queue is not a task queue."
pub const Microtask = struct {
    /// The steps to execute when this microtask runs.
    steps: MicrotaskSteps,

    /// User-provided context for the microtask callback.
    context: ?*anyopaque,

    /// Document associated with the microtask.
    document: ?*anyopaque,

    /// Function pointer type for microtask steps.
    pub const MicrotaskSteps = *const fn (context: ?*anyopaque) void;

    /// Initialize a new microtask.
    pub fn init(
        steps: MicrotaskSteps,
        context: ?*anyopaque,
        document: ?*anyopaque,
    ) Microtask {
        return Microtask{
            .steps = steps,
            .context = context,
            .document = document,
        };
    }

    /// Execute this microtask's steps.
    pub fn run(self: *Microtask) void {
        self.steps(self.context);
    }
};

test "Task - basic initialization" {
    const allocator = std.testing.allocator;

    var executed = false;
    const task = Task.init(
        allocator,
        1,
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

    try std.testing.expect(!executed);
    try std.testing.expect(task.isRunnable());
    try std.testing.expectEqual(TaskSource.dom_manipulation, task.source);
    try std.testing.expectEqual(@as(u64, 1), task.id);
}

test "Task - execution" {
    const allocator = std.testing.allocator;

    var executed = false;
    var task = Task.init(
        allocator,
        1,
        .timer,
        struct {
            fn steps(ctx: ?*anyopaque) void {
                const flag: *bool = @ptrCast(@alignCast(ctx.?));
                flag.* = true;
            }
        }.steps,
        @ptrCast(&executed),
        null,
    );

    try std.testing.expect(!executed);
    task.run();
    try std.testing.expect(executed);
}

test "Task - cancellation" {
    const allocator = std.testing.allocator;

    var executed = false;
    var task = Task.init(
        allocator,
        1,
        .timer,
        struct {
            fn steps(ctx: ?*anyopaque) void {
                const flag: *bool = @ptrCast(@alignCast(ctx.?));
                flag.* = true;
            }
        }.steps,
        @ptrCast(&executed),
        null,
    );

    task.cancel();
    try std.testing.expect(!task.isRunnable());
    task.run();
    try std.testing.expect(!executed); // Should not execute when cancelled
}

test "Microtask - basic execution" {
    var executed = false;
    var microtask = Microtask.init(
        struct {
            fn steps(ctx: ?*anyopaque) void {
                const flag: *bool = @ptrCast(@alignCast(ctx.?));
                flag.* = true;
            }
        }.steps,
        @ptrCast(&executed),
        null,
    );

    try std.testing.expect(!executed);
    microtask.run();
    try std.testing.expect(executed);
}
