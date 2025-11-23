//! V8 Event Loop Implementation
//!
//! This module provides an EventLoop implementation that integrates with
//! V8's built-in microtask queue. This ensures proper interop between
//! V8 promises and our AsyncPromise implementation.
//!
//! ## Design
//!
//! V8 provides native microtask management through:
//! - `Isolate::EnqueueMicrotask()` - Add microtask to V8's queue
//! - `Isolate::PerformMicrotaskCheckpoint()` - Run all pending microtasks
//!
//! This implementation wraps those APIs to conform to our EventLoop interface.
//!
//! ## Usage
//!
//! ```zig
//! const v8_ffi = @import("ffi.zig");
//! const V8EventLoop = @import("event_loop.zig").V8EventLoop;
//!
//! // Create V8EventLoop from V8 isolate
//! var v8_loop = V8EventLoop.init(isolate, allocator);
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
//! ```
//!
//! ## Thread Safety
//!
//! This implementation is NOT thread-safe. It must only be used from the
//! thread that owns the V8 isolate, matching JavaScript's single-threaded
//! execution model.

const std = @import("std");
const Allocator = std.mem.Allocator;
const v8_ffi = @import("ffi.zig");

// Import the EventLoop interface from streams
const event_loop_mod = @import("event_loop");
const EventLoop = event_loop_mod.EventLoop;
const Microtask = event_loop_mod.Microtask;
const Task = event_loop_mod.Task;

/// V8 Event Loop Implementation
///
/// Wraps V8's native microtask queue to provide EventLoop interface.
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

    const Self = @This();

    /// Initialize a new V8 event loop
    ///
    /// The event loop will use the provided V8 isolate's microtask queue.
    /// The allocator is used for internal bookkeeping and promise allocation.
    ///
    /// Example:
    /// ```zig
    /// var loop = V8EventLoop.init(isolate, allocator);
    /// defer loop.deinit();
    /// ```
    pub fn init(isolate: *v8_ffi.Isolate, allocator: Allocator) Self {
        return .{
            .isolate = isolate,
            .allocator = allocator,
            .promise_arena = std.heap.ArenaAllocator.init(allocator),
            .tasks = std.ArrayList(Task){},
            .in_run_once = false,
        };
    }

    /// Free all resources
    ///
    /// This clears any pending tasks and frees the promise arena.
    /// After calling deinit(), the loop cannot be used.
    ///
    /// IMPORTANT: This does NOT execute pending microtasks in V8's queue.
    /// Those are owned by V8 and will execute when V8 runs its checkpoint.
    pub fn deinit(self: *Self) void {
        self.tasks.deinit(self.allocator);
        self.promise_arena.deinit();
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
    // EventLoop Interface Implementation
    // ========================================================================

    fn queueMicrotask(ptr: *anyopaque, task: Microtask) void {
        const self: *Self = @ptrCast(@alignCast(ptr));

        // Allocate context for the microtask
        // This will be freed by the callback wrapper
        const ctx = self.allocator.create(MicrotaskContext) catch {
            // If allocation fails, we have no choice but to panic
            // V8's EnqueueMicrotask doesn't return errors
            @panic("Out of memory allocating microtask context");
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
            @panic("Out of memory allocating task");
        };
    }

    fn runMicrotasks(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));

        // Delegate to V8's microtask checkpoint
        v8_ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);
    }

    fn runOnce(ptr: *anyopaque) bool {
        const self: *Self = @ptrCast(@alignCast(ptr));

        // Prevent reentrancy
        if (self.in_run_once) {
            return false;
        }
        self.in_run_once = true;
        defer self.in_run_once = false;

        var did_work = false;

        // Step 1: Run all pending microtasks
        v8_ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);

        // V8 doesn't tell us if microtasks ran, but we assume they might have
        // We could track this by checking IsExecutingMicrotasks before/after

        // Step 2: Run one task (if any)
        if (self.tasks.items.len > 0) {
            const task = self.tasks.orderedRemove(0);
            task.callback(task.context);
            did_work = true;

            // Step 3: Run microtasks again after task
            v8_ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);
        }

        return did_work;
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
fn microtaskTrampoline(data: ?*anyopaque) void {
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
