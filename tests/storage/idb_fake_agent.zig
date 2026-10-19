//! An engine-free stand-in for an agent's loop, for the IndexedDB server
//! tests: a task sink other threads post to (`server.SinkOps`), drained by
//! its own thread. Not a test file: the tests of this directory import it.

const std = @import("std");
const idb = @import("storage").indexeddb;
const server = idb.server;

pub const FakeAgent = struct {
    allocator: std.mem.Allocator,
    mutex: std.Io.Mutex = .init,
    inbox: std.ArrayListUnmanaged(server.Task) = .empty,
    closed: bool = false,
    thread: std.Thread.Id,

    /// An agent whose loop runs on the calling thread.
    pub fn init(allocator: std.mem.Allocator) FakeAgent {
        return .{ .allocator = allocator, .thread = std.Thread.getCurrentId() };
    }

    /// The loop's end: what was never run is dropped.
    pub fn deinit(self: *FakeAgent) void {
        self.close();
        self.inbox.deinit(self.allocator);
    }

    pub fn close(self: *FakeAgent) void {
        std.Io.Threaded.mutexLock(&self.mutex);
        self.closed = true;
        var queued = self.inbox;
        self.inbox = .empty;
        std.Io.Threaded.mutexUnlock(&self.mutex);
        for (queued.items) |task| task.drop(task.data);
        queued.deinit(self.allocator);
    }

    /// An endpoint for this agent's records. The fake sink is not counted:
    /// the test owns it and outlives every record.
    pub fn endpoint(self: *FakeAgent) server.Endpoint {
        return .{ .thread = self.thread, .sink = self, .ops = &ops };
    }

    const ops: server.SinkOps = .{ .post = post, .release = release };

    fn post(sink: *anyopaque, task: server.Task) bool {
        const self: *FakeAgent = @ptrCast(@alignCast(sink));
        std.Io.Threaded.mutexLock(&self.mutex);
        const accepted = !self.closed and if (self.inbox.append(self.allocator, task)) true else |_| false;
        std.Io.Threaded.mutexUnlock(&self.mutex);
        if (!accepted) task.drop(task.data);
        return accepted;
    }

    fn release(_: *anyopaque) void {}

    /// On this agent's thread: run every task posted so far. Returns how
    /// many ran.
    pub fn drain(self: *FakeAgent) usize {
        std.debug.assert(self.thread == std.Thread.getCurrentId());
        std.Io.Threaded.mutexLock(&self.mutex);
        var taken = self.inbox;
        self.inbox = .empty;
        std.Io.Threaded.mutexUnlock(&self.mutex);
        defer taken.deinit(self.allocator);
        for (taken.items) |task| task.run(task.data);
        return taken.items.len;
    }

    /// Drain until `flag` is set (by a task this agent runs).
    pub fn runUntil(self: *FakeAgent, flag: *const std.atomic.Value(bool)) void {
        while (!flag.load(.acquire)) {
            if (self.drain() == 0) std.Thread.yield() catch {};
        }
    }
};

/// A client that sets a flag when told `advance` or `wake`.
pub const Signal = struct {
    flag: std.atomic.Value(bool) = .init(false),
    notes: usize = 0,

    pub fn client(self: *Signal) server.Client {
        return .{ .context = self, .call = call };
    }

    fn call(context: *anyopaque, _: server.Note) void {
        const self: *Signal = @ptrCast(@alignCast(context));
        self.notes += 1;
        self.flag.store(true, .release);
    }

    pub fn reset(self: *Signal) void {
        self.flag.store(false, .release);
    }
};
