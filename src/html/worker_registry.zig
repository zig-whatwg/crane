//! A Browser's live workers: a supplement of its scope (runtime.BrowserScope,
//! docs/instances.md rule 2), reached through any realm of the Browser
//! (`ContextData.browser_scope`).
//!
//! Every worker the Browser runs - made by a window, or nested in another
//! worker - has its WorkerLink here from the moment its owner spawns its
//! thread until its end reaches the owner. The Browser's end terminates all
//! of them, then joins every thread (`terminateAll`, `joinAll`), before the
//! page's teardown and before the runtime's allocators go: the slab and arena
//! every platform object comes from must outlive every thread (workers design
//! 2.4). An outer worker's end does the same for the workers it owns
//! (`terminateOwnedBy`, `joinOwnedBy`): Blink's PerformShutdownOnWorkerThread
//! checks `child_threads_.empty()` - an outer worker does not end before its
//! children.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const WorkerLink = @import("worker_link.zig").WorkerLink;

pub const WorkerRegistry = struct {
    allocator: Allocator,
    /// Protects `links` and `closed`. Never held across a join, or across a
    /// link's terminate (which takes the link's own lock).
    mutex: std.Io.Mutex = .init,
    /// Every registered link, each holding a reference.
    links: std.ArrayListUnmanaged(*WorkerLink) = .empty,
    /// The Browser is ending: no worker starts any more.
    closed: bool = false,

    pub fn init(allocator: Allocator) WorkerRegistry {
        return .{ .allocator = allocator };
    }

    /// The scope's end. Every thread was joined (`joinAll`); a link still
    /// registered is let go.
    pub fn deinit(self: *WorkerRegistry) void {
        for (self.links.items) |link| {
            std.debug.assert(!link.hasThread());
            link.release();
        }
        self.links.deinit(self.allocator);
    }

    /// The registry of the Browser `realm` belongs to; null for a realm with
    /// none (a test realm).
    pub fn of(realm: runtime.Context) ?*WorkerRegistry {
        const scope = realm.browser_scope orelse return null;
        return scope.of(WorkerRegistry) catch null;
    }

    /// Record a worker about to start: the registry takes a reference.
    /// error.Closed once the Browser is ending - the worker must not start.
    pub fn register(self: *WorkerRegistry, link: *WorkerLink) error{ Closed, OutOfMemory }!void {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        if (self.closed) return error.Closed;
        try self.links.append(self.allocator, link.retain());
    }

    /// The worker has ended and its owner has joined its thread: forget it.
    pub fn unregister(self: *WorkerRegistry, link: *WorkerLink) void {
        const found = blk: {
            std.Io.Threaded.mutexLock(&self.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.mutex);
            for (self.links.items, 0..) |registered, i| {
                if (registered == link) {
                    _ = self.links.swapRemove(i);
                    break :blk true;
                }
            }
            break :blk false;
        };
        if (found) link.release();
    }

    /// How many workers are registered.
    pub fn count(self: *WorkerRegistry) usize {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        return self.links.items.len;
    }

    /// The Browser's end, first half: no worker starts from now on, and
    /// every running one is terminated ("terminate a worker" - its script
    /// aborted, its loop woken to end).
    pub fn terminateAll(self: *WorkerRegistry) void {
        var links = self.snapshot(null, true) catch return self.terminateEachLocked(null);
        defer self.releaseSnapshot(&links);
        for (links.items) |link| _ = link.terminate();
    }

    /// The Browser's end, second half: join every worker's thread, until none
    /// is left - a worker ending may have started another (before
    /// `terminateAll` closed the registry), and an outer worker joins its
    /// children itself first.
    pub fn joinAll(self: *WorkerRegistry) void {
        while (self.nextWithThread(null)) |link| {
            defer link.release();
            link.join();
        }
    }

    /// An outer worker's end: terminate the workers whose owner's loop posts
    /// through `owner_sink` - its own.
    pub fn terminateOwnedBy(self: *WorkerRegistry, owner_sink: *runtime.TaskSink) void {
        var links = self.snapshot(owner_sink, false) catch return self.terminateEachLocked(owner_sink);
        defer self.releaseSnapshot(&links);
        for (links.items) |link| _ = link.terminate();
    }

    /// An outer worker's end: join the threads of the workers it owns.
    pub fn joinOwnedBy(self: *WorkerRegistry, owner_sink: *runtime.TaskSink) void {
        while (self.nextWithThread(owner_sink)) |link| {
            defer link.release();
            link.join();
        }
    }

    /// The registered links (each retained) whose owner sink is `owner`, or
    /// all of them; `close` closes the registry in the same critical section.
    fn snapshot(self: *WorkerRegistry, owner: ?*runtime.TaskSink, close: bool) Allocator.Error!std.ArrayListUnmanaged(*WorkerLink) {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        if (close) self.closed = true;
        var list: std.ArrayListUnmanaged(*WorkerLink) = .empty;
        errdefer list.deinit(self.allocator);
        try list.ensureTotalCapacity(self.allocator, self.links.items.len);
        for (self.links.items) |link| {
            if (owner) |sink| if (link.owner_sink != sink) continue;
            list.appendAssumeCapacity(link.retain());
        }
        return list;
    }

    fn releaseSnapshot(self: *WorkerRegistry, list: *std.ArrayListUnmanaged(*WorkerLink)) void {
        for (list.items) |link| link.release();
        list.deinit(self.allocator);
    }

    /// No memory for a snapshot: terminate under the registry's lock. A
    /// link's terminate takes only the link's own lock, which no path holds
    /// while taking this one.
    fn terminateEachLocked(self: *WorkerRegistry, owner: ?*runtime.TaskSink) void {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        if (owner == null) self.closed = true;
        for (self.links.items) |link| {
            if (owner) |sink| if (link.owner_sink != sink) continue;
            _ = link.terminate();
        }
    }

    /// A registered link (retained) with a thread nobody has joined.
    fn nextWithThread(self: *WorkerRegistry, owner: ?*runtime.TaskSink) ?*WorkerLink {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        for (self.links.items) |link| {
            if (owner) |sink| if (link.owner_sink != sink) continue;
            if (link.hasThread()) return link.retain();
        }
        return null;
    }
};
