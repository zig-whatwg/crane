//! HTML Event Loop Microtask Queue and Checkpoint
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#perform-a-microtask-checkpoint
//! HTML Standard §8.1.7 "Event loops" - Microtasks
//!
//! The microtask queue is NOT a task queue. Microtasks are processed after
//! each task and at specific checkpoints during the event loop.

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");
const task_mod = @import("task.zig");
const Microtask = task_mod.Microtask;

/// The microtask queue for an event loop.
///
/// HTML Standard §8.1.7 line 2896:
/// "Each event loop has a microtask queue, which is a queue of microtasks,
/// initially empty. A microtask is a colloquial way of referring to a task
/// that was created via the queue a microtask algorithm."
pub const MicrotaskQueue = struct {
    /// The queue of microtasks.
    queue: infra.Queue(Microtask),

    /// Allocator for memory management.
    allocator: Allocator,

    /// Initialize a new microtask queue.
    pub fn init(allocator: Allocator) MicrotaskQueue {
        return MicrotaskQueue{
            .queue = infra.Queue(Microtask).init(allocator),
            .allocator = allocator,
        };
    }

    /// Free all resources.
    pub fn deinit(self: *MicrotaskQueue) void {
        self.queue.deinit();
    }

    /// Enqueue a microtask.
    ///
    /// HTML Standard §8.1.7.1 "Queuing tasks" lines 2945-2963:
    /// To queue a microtask which performs a series of steps:
    /// 1. Assert: there is a surrounding agent.
    /// 2. Let eventLoop be the surrounding agent's event loop.
    /// 3. If document was not given, set document to the implied document.
    /// 4. Let microtask be a new task.
    /// 5. Set microtask's steps to steps.
    /// 6. Set microtask's source to the microtask task source.
    /// 7. Set microtask's document to document.
    /// 8. Set microtask's script evaluation environment settings object set to an empty set.
    /// 9. Enqueue microtask on eventLoop's microtask queue.
    pub fn enqueue(self: *MicrotaskQueue, microtask: Microtask) !void {
        try self.queue.enqueue(microtask);
    }

    /// Dequeue the oldest microtask.
    pub fn dequeue(self: *MicrotaskQueue) ?Microtask {
        return self.queue.dequeue();
    }

    /// Check if the queue is empty.
    pub fn isEmpty(self: *const MicrotaskQueue) bool {
        return self.queue.isEmpty();
    }
};

/// State for performing microtask checkpoint.
pub const MicrotaskCheckpointState = struct {
    /// Whether a microtask checkpoint is currently in progress.
    /// HTML Standard §8.1.7 line 2898:
    /// "Each event loop has a performing a microtask checkpoint boolean,
    /// which is initially false. It is used to prevent reentrant invocation
    /// of the perform a microtask checkpoint algorithm."
    performing_checkpoint: bool,

    /// Initialize checkpoint state.
    pub fn init() MicrotaskCheckpointState {
        return MicrotaskCheckpointState{
            .performing_checkpoint = false,
        };
    }
};

/// Callbacks for microtask checkpoint integration with the environment.
pub const MicrotaskCheckpointCallbacks = struct {
    /// Notify about rejected promises for a global object.
    /// HTML Standard §8.1.7.2 line 3237:
    /// "For each environment settings object settingsObject whose responsible
    /// event loop is this event loop, notify about rejected promises given
    /// settingsObject's global object."
    notify_rejected_promises: ?*const fn (context: ?*anyopaque) void,

    /// Cleanup IndexedDB transactions.
    /// HTML Standard §8.1.7.2 line 3239:
    /// "Cleanup Indexed Database transactions."
    cleanup_indexeddb: ?*const fn (context: ?*anyopaque) void,

    /// Perform ClearKeptObjects.
    /// HTML Standard §8.1.7.2 line 3241:
    /// "Perform ClearKeptObjects()."
    clear_kept_objects: ?*const fn (context: ?*anyopaque) void,

    /// Record timing info for microtask checkpoint.
    /// HTML Standard §8.1.7.2 line 3247:
    /// "Record timing info for microtask checkpoint."
    record_timing_info: ?*const fn (context: ?*anyopaque) void,

    /// User context for callbacks.
    context: ?*anyopaque,

    /// Default callbacks (no-op).
    pub fn noOp() MicrotaskCheckpointCallbacks {
        return MicrotaskCheckpointCallbacks{
            .notify_rejected_promises = null,
            .cleanup_indexeddb = null,
            .clear_kept_objects = null,
            .record_timing_info = null,
            .context = null,
        };
    }
};

/// Perform a microtask checkpoint.
///
/// HTML Standard §8.1.7.2 "Processing model" lines 3219-3248:
/// When a user agent is to perform a microtask checkpoint:
/// 1. If the event loop's performing a microtask checkpoint is true, then return.
/// 2. Set the event loop's performing a microtask checkpoint to true.
/// 3. While the event loop's microtask queue is not empty:
///    a. Let oldestMicrotask be the result of dequeuing from the event loop's microtask queue.
///    b. Set the event loop's currently running task to oldestMicrotask.
///    c. Run oldestMicrotask.
///    d. Set the event loop's currently running task back to null.
/// 4. For each environment settings object settingsObject whose responsible event loop
///    is this event loop, notify about rejected promises given settingsObject's global object.
/// 5. Cleanup Indexed Database transactions.
/// 6. Perform ClearKeptObjects().
/// 7. Set the event loop's performing a microtask checkpoint to false.
/// 8. Record timing info for microtask checkpoint.
pub fn performMicrotaskCheckpoint(
    queue: *MicrotaskQueue,
    state: *MicrotaskCheckpointState,
    callbacks: MicrotaskCheckpointCallbacks,
) void {
    // Step 1: If already performing checkpoint, return (prevent reentrancy)
    if (state.performing_checkpoint) return;

    // Step 2: Set performing checkpoint flag
    state.performing_checkpoint = true;

    // Step 3: Process all microtasks
    while (!queue.isEmpty()) {
        // Step 3a: Dequeue oldest microtask
        if (queue.dequeue()) |*microtask| {
            // Step 3b: Set currently running task (handled by caller)
            // Step 3c: Run the microtask
            var mt = microtask.*;
            mt.run();
            // Step 3d: Set currently running task back to null (handled by caller)
        }
    }

    // Step 4: Notify about rejected promises
    if (callbacks.notify_rejected_promises) |notify| {
        notify(callbacks.context);
    }

    // Step 5: Cleanup IndexedDB transactions
    if (callbacks.cleanup_indexeddb) |cleanup| {
        cleanup(callbacks.context);
    }

    // Step 6: Perform ClearKeptObjects
    if (callbacks.clear_kept_objects) |clear| {
        clear(callbacks.context);
    }

    // Step 7: Clear performing checkpoint flag
    state.performing_checkpoint = false;

    // Step 8: Record timing info
    if (callbacks.record_timing_info) |record| {
        record(callbacks.context);
    }
}

test "MicrotaskQueue - basic operations" {
    const allocator = std.testing.allocator;

    var queue = MicrotaskQueue.init(allocator);
    defer queue.deinit();

    try std.testing.expect(queue.isEmpty());

    // Enqueue microtasks
    var executed1 = false;
    try queue.enqueue(Microtask.init(
        struct {
            fn steps(ctx: ?*anyopaque) void {
                const flag: *bool = @ptrCast(@alignCast(ctx.?));
                flag.* = true;
            }
        }.steps,
        @ptrCast(&executed1),
        null,
    ));

    try std.testing.expect(!queue.isEmpty());

    // Dequeue and run
    if (queue.dequeue()) |*mt| {
        var microtask = mt.*;
        microtask.run();
    }

    try std.testing.expect(executed1);
    try std.testing.expect(queue.isEmpty());
}

test "MicrotaskQueue - FIFO ordering" {
    const allocator = std.testing.allocator;

    var queue = MicrotaskQueue.init(allocator);
    defer queue.deinit();

    var order: u32 = 0;

    // Enqueue three microtasks
    try queue.enqueue(Microtask.init(
        struct {
            fn steps(ctx: ?*anyopaque) void {
                const o: *u32 = @ptrCast(@alignCast(ctx.?));
                o.* = o.* * 10 + 1;
            }
        }.steps,
        @ptrCast(&order),
        null,
    ));

    try queue.enqueue(Microtask.init(
        struct {
            fn steps(ctx: ?*anyopaque) void {
                const o: *u32 = @ptrCast(@alignCast(ctx.?));
                o.* = o.* * 10 + 2;
            }
        }.steps,
        @ptrCast(&order),
        null,
    ));

    try queue.enqueue(Microtask.init(
        struct {
            fn steps(ctx: ?*anyopaque) void {
                const o: *u32 = @ptrCast(@alignCast(ctx.?));
                o.* = o.* * 10 + 3;
            }
        }.steps,
        @ptrCast(&order),
        null,
    ));

    // Run all in order
    while (queue.dequeue()) |*mt| {
        var microtask = mt.*;
        microtask.run();
    }

    // Should be 123 (1 first, then 2, then 3)
    try std.testing.expectEqual(@as(u32, 123), order);
}

test "performMicrotaskCheckpoint - basic" {
    const allocator = std.testing.allocator;

    var queue = MicrotaskQueue.init(allocator);
    defer queue.deinit();

    var state = MicrotaskCheckpointState.init();

    var executed = false;
    try queue.enqueue(Microtask.init(
        struct {
            fn steps(ctx: ?*anyopaque) void {
                const flag: *bool = @ptrCast(@alignCast(ctx.?));
                flag.* = true;
            }
        }.steps,
        @ptrCast(&executed),
        null,
    ));

    performMicrotaskCheckpoint(&queue, &state, MicrotaskCheckpointCallbacks.noOp());

    try std.testing.expect(executed);
    try std.testing.expect(queue.isEmpty());
    try std.testing.expect(!state.performing_checkpoint);
}

test "performMicrotaskCheckpoint - reentrancy prevention" {
    const allocator = std.testing.allocator;

    var queue = MicrotaskQueue.init(allocator);
    defer queue.deinit();

    var state = MicrotaskCheckpointState.init();

    // Simulate reentrancy by setting the flag
    state.performing_checkpoint = true;

    var executed = false;
    try queue.enqueue(Microtask.init(
        struct {
            fn steps(ctx: ?*anyopaque) void {
                const flag: *bool = @ptrCast(@alignCast(ctx.?));
                flag.* = true;
            }
        }.steps,
        @ptrCast(&executed),
        null,
    ));

    // Should return early due to reentrancy flag
    performMicrotaskCheckpoint(&queue, &state, MicrotaskCheckpointCallbacks.noOp());

    // Microtask should NOT have been executed
    try std.testing.expect(!executed);
    try std.testing.expect(!queue.isEmpty());

    // Reset flag and try again
    state.performing_checkpoint = false;
    performMicrotaskCheckpoint(&queue, &state, MicrotaskCheckpointCallbacks.noOp());

    try std.testing.expect(executed);
    try std.testing.expect(queue.isEmpty());
}

test "performMicrotaskCheckpoint - callbacks invoked" {
    const allocator = std.testing.allocator;

    var queue = MicrotaskQueue.init(allocator);
    defer queue.deinit();

    var state = MicrotaskCheckpointState.init();

    var callback_count: u32 = 0;

    const callbacks = MicrotaskCheckpointCallbacks{
        .notify_rejected_promises = struct {
            fn callback(ctx: ?*anyopaque) void {
                const count: *u32 = @ptrCast(@alignCast(ctx.?));
                count.* += 1;
            }
        }.callback,
        .cleanup_indexeddb = struct {
            fn callback(ctx: ?*anyopaque) void {
                const count: *u32 = @ptrCast(@alignCast(ctx.?));
                count.* += 1;
            }
        }.callback,
        .clear_kept_objects = struct {
            fn callback(ctx: ?*anyopaque) void {
                const count: *u32 = @ptrCast(@alignCast(ctx.?));
                count.* += 1;
            }
        }.callback,
        .record_timing_info = struct {
            fn callback(ctx: ?*anyopaque) void {
                const count: *u32 = @ptrCast(@alignCast(ctx.?));
                count.* += 1;
            }
        }.callback,
        .context = @ptrCast(&callback_count),
    };

    performMicrotaskCheckpoint(&queue, &state, callbacks);

    // All 4 callbacks should have been invoked
    try std.testing.expectEqual(@as(u32, 4), callback_count);
}
