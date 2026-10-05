//! The one object both threads of a worker touch: its owner's (the thread of
//! the Worker object - a window's, or an outer worker's) and its own.
//!
//! Every worker runs its agent on a thread of its own (docs/instances.md,
//! "Decisions"). Its owner never reaches into that thread's objects: it posts
//! tasks to the worker's TaskSink, and the worker posts tasks back to the
//! owner's. What both sides need beyond that is here: the worker's life
//! (`state`), its agent while it exists - so that the owner can abort the
//! script running in it ("terminate a worker") - and the thread, which the
//! owner joins.
//!
//! The agent pointer is Blink's WorkerThread::lock_ ("protects shared states
//! between the parent thread and the worker thread", worker_thread.cc): the
//! owner calls `engine.abortRunningScript` only while holding `agent_lock`,
//! and the worker clears `agent` under the same lock before it destroys the
//! agent, so the owner never touches an agent that is gone. The lock is held
//! for a few instructions, never across a task.
//!
//! The link is reference counted: the owner side holds one, the worker side
//! one, and so does every cross-thread task that carries it (the worker's
//! end, posted to the owner).

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");
const TaskSink = runtime.TaskSink;

/// Where a worker is in its life, as both threads see it.
pub const State = enum(u8) {
    /// The thread is starting: no agent yet, or its script has not run.
    starting,
    /// The worker's event loop is running tasks.
    running,
    /// close() in the worker, or "terminate a worker" from its owner: the
    /// loop runs no further task, and the worker is ending.
    closing,
    /// The thread's work is over: its agent is destroyed.
    ended,
};

pub const WorkerLink = struct {
    allocator: Allocator,
    refs: std.atomic.Value(u32) = .init(1),
    state: std.atomic.Value(State) = .init(.starting),

    /// Protects `agent`. Never held across a task or a script.
    agent_lock: std.Io.Mutex = .init,
    /// The worker's agent, while it exists: set by the worker thread once it
    /// has made it, cleared by the worker thread before it destroys it. The
    /// owner reads it only under `agent_lock`.
    agent: ?*engine.Agent = null,

    /// The worker's loop's inbox: what the owner posts to the worker (its
    /// messages, the wake of "terminate a worker"). Made by the owner before
    /// the thread starts, so a message posted before the worker's script ran
    /// simply waits there. A reference.
    worker_sink: *TaskSink,
    /// The owner's loop's inbox: what the worker posts back (its messages,
    /// its errors, its end). A reference; it counts the worker as a source
    /// for as long as the worker may post (`TaskSink.addSource`).
    owner_sink: *TaskSink,

    /// The realm of the Worker object - the worker's owner - as an opaque
    /// key: "terminate a worker" for every worker a realm owns when that
    /// realm ends (`WorkerRegistry.terminateOwnedByRealm`). Compared, never
    /// dereferenced; set by the owner before the thread starts.
    owner_realm: ?*const anyopaque = null,

    /// Protects `thread`.
    thread_lock: std.Io.Mutex = .init,
    /// The worker's thread, until someone joins it (`join`): its owner, at
    /// the worker's end, or the Browser's end.
    thread: ?std.Thread = null,

    /// A link for a worker whose owner's loop posts through `owner_sink`. The
    /// caller holds the one reference (the owner side's); the worker side
    /// takes its own when its thread starts (`retain`).
    pub fn create(allocator: Allocator, owner_sink: *TaskSink) Allocator.Error!*WorkerLink {
        const worker_sink = try TaskSink.create(allocator);
        errdefer worker_sink.release();
        const self = try allocator.create(WorkerLink);
        self.* = .{
            .allocator = allocator,
            .worker_sink = worker_sink,
            .owner_sink = owner_sink.retain(),
        };
        owner_sink.addSource();
        return self;
    }

    pub fn retain(self: *WorkerLink) *WorkerLink {
        _ = self.refs.fetchAdd(1, .monotonic);
        return self;
    }

    /// Give a reference back; the last one frees the link. A thread no one
    /// joined - its owner and its registry let it go without joining, which
    /// only a worker with no Browser does - is detached: it has posted its
    /// end, so it is at its last instructions.
    pub fn release(self: *WorkerLink) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        if (self.thread) |thread| thread.detach();
        self.thread = null;
        std.debug.assert(self.agent == null);
        if (self.state.load(.acquire) != .ended) {
            // A worker that never started (its thread was never spawned):
            // it posts nothing.
            self.owner_sink.removeSource();
        }
        self.worker_sink.release();
        self.owner_sink.release();
        self.allocator.destroy(self);
    }

    pub fn getState(self: *const WorkerLink) State {
        return self.state.load(.acquire);
    }

    /// Whether the worker's loop runs tasks: not once it is closing.
    pub fn runsTasks(self: *const WorkerLink) bool {
        return switch (self.getState()) {
            .starting, .running => true,
            .closing, .ended => false,
        };
    }

    /// The worker thread: its script is about to run - unless the owner
    /// terminated it first. Whether it still runs.
    pub fn markRunning(self: *WorkerLink) bool {
        return self.state.cmpxchgStrong(.starting, .running, .acq_rel, .acquire) == null;
    }

    /// The worker thread has made its agent: from now on the owner can abort
    /// script in it. False when the owner terminated the worker before it
    /// started - the caller runs nothing then, and ends.
    pub fn publishAgent(self: *WorkerLink, agent: *engine.Agent) bool {
        std.Io.Threaded.mutexLock(&self.agent_lock);
        defer std.Io.Threaded.mutexUnlock(&self.agent_lock);
        self.agent = agent;
        return self.runsTasks();
    }

    /// The worker thread is about to destroy its agent: after this the owner
    /// can no longer reach it. The agent, for the caller to destroy.
    pub fn retireAgent(self: *WorkerLink) ?*engine.Agent {
        std.Io.Threaded.mutexLock(&self.agent_lock);
        defer std.Io.Threaded.mutexUnlock(&self.agent_lock);
        const agent = self.agent;
        self.agent = null;
        return agent;
    }

    /// HTML "terminate a worker", the steps that reach the worker's thread,
    /// from the owner (or the Browser's end) on any thread: 1. set the
    /// closing flag; 3. abort the script running in it - V8's termination,
    /// which also wakes an Atomics.wait (callable from any thread while the
    /// agent lives: docs/engine-protocol.md, the thread contract); and wake
    /// its loop, which then sees the flag and ends. Step 2 (discard the
    /// worker's tasks) is the worker loop's own at its end; step 4 (empty
    /// the port queue the worker posts to) is the owner's. Whether this call
    /// moved the worker to closing (false: it was already closing or ended).
    pub fn terminate(self: *WorkerLink) bool {
        const moved = self.requestClose();
        // Only the call that moved the worker to closing aborts its script:
        // a worker already closing - close() in its own script, or an earlier
        // terminate - is past its last task, and an abort requested now would
        // land in its teardown.
        if (moved) {
            std.Io.Threaded.mutexLock(&self.agent_lock);
            defer std.Io.Threaded.mutexUnlock(&self.agent_lock);
            if (self.agent) |agent| {
                if (comptime engine.capabilities.script_abort != .unsupported) engine.abortRunningScript(agent);
            }
        }
        self.wake();
        return moved;
    }

    /// Set the closing flag (close() in the worker, or termination). Whether
    /// it moved: false when the worker was already closing or ended.
    pub fn requestClose(self: *WorkerLink) bool {
        var current = self.state.load(.acquire);
        while (true) {
            switch (current) {
                .closing, .ended => return false,
                .starting, .running => {},
            }
            current = self.state.cmpxchgWeak(current, .closing, .acq_rel, .acquire) orelse return true;
        }
    }

    /// Wake the worker's loop if it waits for work: a post with nothing to
    /// run. A closed sink - the worker already ending - drops it.
    pub fn wake(self: *WorkerLink) void {
        _ = self.worker_sink.post(.{ .run = noop, .drop = noop, .data = null });
    }

    fn noop(_: ?*anyopaque) void {}

    /// The worker thread's last step before its end is posted: the worker
    /// will post nothing more, and its owner's loop no longer waits for it.
    pub fn markEnded(self: *WorkerLink) void {
        self.state.store(.ended, .release);
        self.owner_sink.removeSource();
    }

    /// Record the thread the owner spawned for the worker.
    pub fn setThread(self: *WorkerLink, thread: std.Thread) void {
        std.Io.Threaded.mutexLock(&self.thread_lock);
        defer std.Io.Threaded.mutexUnlock(&self.thread_lock);
        std.debug.assert(self.thread == null);
        self.thread = thread;
    }

    /// Join the worker's thread, if no one has: blocks until it has ended.
    /// Whoever takes the thread joins it - the owner at the worker's end, or
    /// the Browser's end - and a second caller returns at once.
    pub fn join(self: *WorkerLink) void {
        const thread = blk: {
            std.Io.Threaded.mutexLock(&self.thread_lock);
            defer std.Io.Threaded.mutexUnlock(&self.thread_lock);
            const taken = self.thread;
            self.thread = null;
            break :blk taken;
        };
        if (thread) |t| t.join();
    }

    /// Whether a thread is still waiting to be joined.
    pub fn hasThread(self: *WorkerLink) bool {
        std.Io.Threaded.mutexLock(&self.thread_lock);
        defer std.Io.Threaded.mutexUnlock(&self.thread_lock);
        return self.thread != null;
    }
};
