//! A loop's inbox for tasks posted from other threads.
//!
//! Every worker runs its agent on a thread of its own (docs/instances.md,
//! "Decisions"), and what crosses between the threads - a message posted to
//! a worker, a port's "has messages", a worker's end - is a task for the
//! RECEIVING thread's event loop. An event loop's task queue is its own
//! thread's (it runs script); this is the one door other threads use. Each
//! event loop owns one sink, takes what was posted at the start of a turn
//! (`takeAll`), runs it as tasks of its own, and closes the sink when it ends.
//!
//! Blink's rule for the same object (worker_thread.h, the worker's task
//! runners): "When the worker global scope is destroyed, the task runner
//! starts failing PostTask calls and discards queued tasks. This function can
//! be called from any threads." So: `post` fails once the sink is closed, and
//! `close` drops what is queued.
//!
//! A posted task is engine-neutral. Its `run` executes on the sink's thread as
//! a task of its loop; its `drop` - for a task that will never run - frees
//! what the task carries and may run on ANY thread, so it touches no engine
//! and no thread-affine object (it frees bytes, discards port ends, releases
//! references).
//!
//! The sink is reference counted: the loop holds one reference, and so does
//! every holder that may post to it later (a worker's link, a port's owner
//! record). Its memory goes with the last reference; a sink outlives its loop
//! while a holder still has it, closed.
//!
//! One mutex protects the inbox and `closed`; it is held for a few
//! instructions and never across a task's `run` or `drop`.

const std = @import("std");
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.task_sink);

/// A task posted to another thread's loop.
pub const CrossThreadTask = struct {
    /// Runs on the sink's thread, as a task of its loop.
    run: *const fn (data: ?*anyopaque) void,
    /// The task will never run: free `data`. May run on any thread.
    drop: *const fn (data: ?*anyopaque) void,
    data: ?*anyopaque,
};

pub const TaskSink = struct {
    /// Thread-safe: a task's data is often freed on another thread than the
    /// one that made it, and the sink itself by its last holder.
    allocator: Allocator,
    /// Protects `inbox` and `closed`. Never held across a task's steps.
    mutex: std.Io.Mutex = .init,
    inbox: std.ArrayListUnmanaged(CrossThreadTask) = .empty,
    /// Set by the loop's end: posts fail from then on.
    closed: bool = false,
    /// The loop's reference and every holder's.
    refs: std.atomic.Value(u32) = .init(1),
    /// Bumped by every post and by close: the futex word the loop waits on.
    wake: std.atomic.Value(u32) = .init(0),
    /// Live sources that may still post to this sink - a running worker whose
    /// owner's loop this is. A loop with a source left is not idle: a worker
    /// that is running may post at any time (`hasPendingWork`).
    sources: std.atomic.Value(u32) = .init(0),

    /// A new sink, its one reference the caller's (the loop's).
    pub fn create(allocator: Allocator) Allocator.Error!*TaskSink {
        const self = try allocator.create(TaskSink);
        self.* = .{ .allocator = allocator };
        return self;
    }

    /// Another reference: a holder that may post later.
    pub fn retain(self: *TaskSink) *TaskSink {
        _ = self.refs.fetchAdd(1, .monotonic);
        return self;
    }

    /// Give a reference back; the last one closes the sink (dropping what it
    /// still holds) and frees it.
    pub fn release(self: *TaskSink) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        self.close();
        self.inbox.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Post `task` to the sink's loop. The sink TAKES the task whatever
    /// happens: when the sink is closed - its loop has ended or is ending -
    /// or the inbox cannot grow, the task's `drop` runs here, on the
    /// poster's thread, and the answer is false. So a caller never frees a
    /// posted task's data itself.
    pub fn post(self: *TaskSink, task: CrossThreadTask) bool {
        std.Io.Threaded.mutexLock(&self.mutex);
        const accepted = if (self.closed) false else if (self.inbox.append(self.allocator, task)) true else |_| blk: {
            log.debug("out of memory posting a task; dropped", .{});
            break :blk false;
        };
        std.Io.Threaded.mutexUnlock(&self.mutex);
        if (!accepted) {
            task.drop(task.data);
            return false;
        }
        self.notify();
        return true;
    }

    /// Wake the loop's wait (`waitForWork`).
    fn notify(self: *TaskSink) void {
        _ = self.wake.fetchAdd(1, .release);
        futexIo().futexWake(u32, &self.wake.raw, 1);
    }

    /// The loop's thread: move everything posted so far to the end of `out`,
    /// in the order it was posted. On OutOfMemory nothing moved, and the
    /// tasks stay for the next call.
    pub fn takeAll(self: *TaskSink, out: *std.ArrayListUnmanaged(CrossThreadTask), out_allocator: Allocator) Allocator.Error!void {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        if (self.inbox.items.len == 0) return;
        try out.appendSlice(out_allocator, self.inbox.items);
        self.inbox.clearRetainingCapacity();
    }

    /// Whether a task waits to be taken.
    pub fn hasPosted(self: *TaskSink) bool {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        return self.inbox.items.len > 0;
    }

    /// The loop's end: posts fail from now on, and every task still queued
    /// is dropped - outside the lock, since a task's `drop` may itself post
    /// (to another sink) or release a reference to this one. Closing twice
    /// does nothing more.
    pub fn close(self: *TaskSink) void {
        std.Io.Threaded.mutexLock(&self.mutex);
        self.closed = true;
        var queued = self.inbox;
        self.inbox = .empty;
        std.Io.Threaded.mutexUnlock(&self.mutex);
        for (queued.items) |task| task.drop(task.data);
        queued.deinit(self.allocator);
        self.notify();
    }

    /// Whether the sink is closed.
    pub fn isClosed(self: *TaskSink) bool {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        return self.closed;
    }

    /// The loop's thread, with nothing to do: block until a task is posted,
    /// the sink is closed, or `timeout_ns` passes (null: no limit). Returns
    /// at once when a task already waits. Spurious returns are allowed - the
    /// caller's loop asks again.
    pub fn waitForWork(self: *TaskSink, timeout_ns: ?u64) void {
        // Read the word before looking at the inbox: a post that lands after
        // the look has bumped it, and the wait below returns at once.
        const seen = self.wake.load(.acquire);
        if (self.hasPosted() or self.isClosed()) return;
        const timeout: std.Io.Timeout = if (timeout_ns) |ns| .{ .duration = .{
            .raw = .fromNanoseconds(ns),
            .clock = .awake,
        } } else .none;
        futexIo().futexWaitTimeout(u32, &self.wake.raw, seen, timeout) catch {};
    }

    /// A source that may post was added (a worker started for this loop).
    pub fn addSource(self: *TaskSink) void {
        _ = self.sources.fetchAdd(1, .monotonic);
    }

    /// A source ended (the worker's end reached this loop).
    pub fn removeSource(self: *TaskSink) void {
        const before = self.sources.fetchSub(1, .monotonic);
        std.debug.assert(before > 0);
    }

    /// How many sources may still post.
    pub fn sourceCount(self: *TaskSink) u32 {
        return self.sources.load(.monotonic);
    }
};

/// The futex calls' `Io`. A futex wait and wake are plain system calls on an
/// address, the same through any `Io.Threaded`; the process's own (the
/// `host` module's) is reserved for its filesystem bridge, so this uses the
/// standard library's static instance, whose missing concurrency and
/// cancelation these calls do not use.
fn futexIo() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}
