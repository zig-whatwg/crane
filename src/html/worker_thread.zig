//! A worker's thread: "run a worker" on a thread of its own, and the end of
//! that thread (workers design 2.3).
//!
//! Every worker runs its agent - isolate, event loop, timers - on a thread of
//! its own, owned by its Browser (docs/instances.md, "Decisions"). The owner
//! (a Worker object's thread) spawns the thread; the thread makes the agent
//! and the realm, runs the script, turns its event loop until the worker is
//! closing, and ends - all on the thread, as Blink makes and disposes a
//! worker's isolate on its backing thread (worker_backing_thread.cc). The
//! owner never touches the thread's objects: it posts to the worker's sink,
//! and aborts its script through the link (WorkerLink.terminate).
//!
//! What the thread runs is the worker host's (`Host`): making the agent and
//! the realm and running the script, and the realm's end. What it does around
//! that is here, in this order at the end (design 2.3 step 6):
//!   a. the closing flag set, the worker's tasks discarded;
//!   b. the workers this worker owns terminated, and their threads joined -
//!      an outer worker does not end before its children (Blink's
//!      PerformShutdownOnWorkerThread: `CHECK(child_threads_.empty())`);
//!   c. the realm's end (the host's), while the agent lives;
//!   d. the agent's end: retired from the link under its lock - the owner can
//!      no longer abort script in it - then destroyed, on this thread;
//!   e. the loop's end - its timers freed, an owned timer's data dropped, and
//!      the microtasks the agent never ran freed (after the agent: its end
//!      may still run some, into the loop's promise arena);
//!   f. what this thread kept for itself: the instance lifecycle registry,
//!      the fetches in flight, the network scheduler;
//!   g. the worker's end posted to its owner, which joins the thread.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");
const fetch = @import("fetch");

const WorkerLink = @import("worker_link.zig").WorkerLink;
const WorkerEventLoop = @import("worker_event_loop.zig").WorkerEventLoop;
const WorkerRegistry = @import("worker_registry.zig").WorkerRegistry;

const log = std.log.scoped(.worker_thread);

/// A worker thread's stack. V8's default stack limit is about 1 MiB below
/// where the isolate is entered, well inside it.
pub const stack_size = 16 * 1024 * 1024;

pub const WorkerThread = struct {
    allocator: Allocator,
    /// The worker side's reference.
    link: *WorkerLink,
    /// The worker's event loop: made on the thread, ended on it.
    loop: WorkerEventLoop = undefined,
    host: Host,
    owner: Owner,
    /// The Browser's live workers: this worker's own nested workers are
    /// ended through it (step b). Null where no Browser runs the worker.
    registry: ?*WorkerRegistry,

    /// The worker host's part, run on the worker's thread.
    pub const Host = struct {
        data: ?*anyopaque,
        /// "Run a worker" steps 4-13 on the thread, its loop made: make the
        /// agent - recorded in `thread.loop.agent` and published through
        /// `thread.link` - and the realm, and run the script. False when the
        /// worker could not start; it ends at once.
        start: *const fn (data: ?*anyopaque, thread: *WorkerThread) bool,
        /// The realm's end (step c), with the agent alive and nothing queued.
        end_realm: *const fn (data: ?*anyopaque, thread: *WorkerThread) void,
        /// The host's last step, after the agent is destroyed: free `data`.
        free: *const fn (data: ?*anyopaque) void,
    };

    /// The owner's part: the worker's end, as a task of the owner's loop.
    pub const Owner = struct {
        data: ?*anyopaque,
        /// On the owner's thread: the worker has ended - its thread is at its
        /// last instruction, so joining it does not wait long.
        ended: *const fn (data: ?*anyopaque, link: *WorkerLink) void,
        /// The end will never reach the owner (its loop ended first): free
        /// `data`; the thread has been joined, or will be by whoever ends
        /// the owner's loop or Browser. Any thread; no engine.
        drop: *const fn (data: ?*anyopaque, link: *WorkerLink) void,
    };

    /// Start the worker's thread. The thread takes a reference to `link`;
    /// on success `host.data` and `owner.data` are the thread's, freed by it
    /// (`free`, and the end's `ended` or `drop`). On failure nothing was
    /// taken.
    pub fn spawn(allocator: Allocator, link: *WorkerLink, host: Host, owner: Owner, registry: ?*WorkerRegistry) !void {
        const self = try allocator.create(WorkerThread);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .link = link.retain(),
            .host = host,
            .owner = owner,
            .registry = registry,
        };
        errdefer link.release();
        const thread = try std.Thread.spawn(.{ .stack_size = stack_size, .allocator = allocator }, main, .{self});
        link.setThread(thread);
    }

    fn main(self: *WorkerThread) void {
        const link = self.link;
        const loop_made = blk: {
            self.loop = WorkerEventLoop.init(self.allocator, link) catch break :blk false;
            break :blk true;
        };
        if (loop_made) {
            if (self.host.start(self.host.data, self) and link.markRunning()) self.loop.run();
            // a. The closing flag, and the worker's tasks discarded.
            _ = link.requestClose();
            self.loop.dropTasks();
            // b. The workers this one owns end first.
            if (self.registry) |registry| {
                registry.terminateOwnedBy(link.worker_sink);
                registry.joinOwnedBy(link.worker_sink);
            }
            // c. The realm's end, while the agent lives.
            self.host.end_realm(self.host.data, self);
        } else {
            _ = link.requestClose();
        }
        // d. The agent's end: retired first, so the owner cannot abort
        // script in it any more.
        if (link.retireAgent()) |agent| engine.destroyAgent(agent);
        // e. The loop's end, now that nothing can run in it.
        if (loop_made) {
            self.loop.agent = null;
            self.loop.deinit();
        }
        self.host.free(self.host.data);
        // f. What this thread kept for itself.
        endThreadState();
        // g. The worker's end, to its owner.
        self.postEnded();
        link.markEnded();
        const allocator = self.allocator;
        allocator.destroy(self);
        link.release();
    }

    /// Per-thread state of the runtime and the network that a worker's
    /// thread made, ended with it - otherwise each worker thread leaks it at
    /// its exit.
    fn endThreadState() void {
        runtime.instance_lifecycle.deinit();
        _ = fetch.algorithms.async_fetch.sweep();
        fetch.network.scheduler.endIdleThreadScheduler();
    }

    /// Post the worker's end to its owner's loop, carrying a link reference.
    fn postEnded(self: *WorkerThread) void {
        const task = self.allocator.create(Ended) catch {
            log.debug("out of memory posting a worker's end; its owner joins it at its own end", .{});
            self.owner.drop(self.owner.data, self.link);
            return;
        };
        task.* = .{ .allocator = self.allocator, .owner = self.owner, .link = self.link.retain() };
        _ = self.link.owner_sink.post(.{ .run = Ended.run, .drop = Ended.drop, .data = task });
    }
};

/// The worker's end, a task of its owner's loop.
const Ended = struct {
    allocator: Allocator,
    owner: WorkerThread.Owner,
    link: *WorkerLink,

    fn run(data: ?*anyopaque) void {
        const self: *Ended = @ptrCast(@alignCast(data.?));
        const owner = self.owner;
        const link = self.link;
        self.allocator.destroy(self);
        defer link.release();
        owner.ended(owner.data, link);
    }

    fn drop(data: ?*anyopaque) void {
        const self: *Ended = @ptrCast(@alignCast(data.?));
        const owner = self.owner;
        const link = self.link;
        self.allocator.destroy(self);
        defer link.release();
        owner.drop(owner.data, link);
    }
};
