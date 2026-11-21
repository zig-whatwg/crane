//! A connection's outbound FIFO, and a session's link to it.
//!
//! Everything a session sends - responses and events - is produced on the
//! thread of the target it belongs to (the devtools thread for the browser
//! target and tab targets, a Browser's thread for page targets) and appended
//! here; the connection's writer thread takes the messages in order and
//! writes them (tmp/plans/cdp-part1-design.md 2.2: "per-session order is
//! production order"). Chrome does the same through DevToolsSession's
//! client, which posts each message to the IO thread's socket in order
//! (content/browser/devtools/devtools_http_handler.cc, SendOverWebSocket).
//!
//! Both are reference counted: a Browser thread may still hold a session's
//! link after the connection has gone; what it sends then is dropped.

const std = @import("std");
const Allocator = std.mem.Allocator;

fn futexIo() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}

/// A connection's outbound messages, oldest first. Any thread may push; one
/// thread (the connection's writer) takes.
pub const Outbound = struct {
    /// Thread-safe: messages are made on one thread and freed on another.
    allocator: Allocator,
    mutex: std.Io.Mutex = .init,
    queue: std.ArrayList([]u8) = .empty,
    /// Set when the connection ends: pushes are dropped from then on.
    closed: bool = false,
    refs: std.atomic.Value(u32) = .init(1),
    /// Bumped by every push and by close: the futex word the writer waits on.
    wake: std.atomic.Value(u32) = .init(0),

    pub fn create(allocator: Allocator) Allocator.Error!*Outbound {
        const self = try allocator.create(Outbound);
        self.* = .{ .allocator = allocator };
        return self;
    }

    pub fn retain(self: *Outbound) *Outbound {
        _ = self.refs.fetchAdd(1, .monotonic);
        return self;
    }

    pub fn release(self: *Outbound) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.queue.items) |message| self.allocator.free(message);
        self.queue.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Append `message`, which the queue OWNS from here (allocated with
    /// `allocator`). Dropped, and freed, once the connection has closed.
    pub fn push(self: *Outbound, message: []u8) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        if (self.closed) {
            std.Io.Threaded.mutexUnlock(&self.mutex);
            self.allocator.free(message);
            return;
        }
        self.queue.append(self.allocator, message) catch {
            std.Io.Threaded.mutexUnlock(&self.mutex);
            // Out of memory: the message is lost, as a write that failed is.
            self.allocator.free(message);
            return;
        };
        std.Io.Threaded.mutexUnlock(&self.mutex);
        _ = self.wake.fetchAdd(1, .release);
        futexIo().futexWake(u32, &self.wake.raw, 1);
    }

    /// The writer: move every queued message into `out` (in order). The
    /// caller owns them.
    pub fn takeAll(self: *Outbound, out: *std.ArrayList([]u8)) Allocator.Error!void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        try out.appendSlice(self.allocator, self.queue.items);
        self.queue.clearRetainingCapacity();
    }

    /// The writer, with nothing to write: block until a push, the close, or
    /// `timeout_ns` (null: none). Spurious returns are allowed.
    pub fn wait(self: *Outbound, timeout_ns: ?u64) void {
        const seen = self.wake.load(.acquire);
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        const ready = self.queue.items.len != 0 or self.closed;
        std.Io.Threaded.mutexUnlock(&self.mutex);
        if (ready) return;
        const timeout: std.Io.Timeout = if (timeout_ns) |ns| .{ .duration = .{
            .raw = .fromNanoseconds(ns),
            .clock = .awake,
        } } else .none;
        futexIo().futexWaitTimeout(u32, &self.wake.raw, seen, timeout) catch {};
    }

    /// The connection ended: drop what is queued and every later push.
    pub fn close(self: *Outbound) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        self.closed = true;
        for (self.queue.items) |message| self.allocator.free(message);
        self.queue.clearRetainingCapacity();
        std.Io.Threaded.mutexUnlock(&self.mutex);
        _ = self.wake.fetchAdd(1, .release);
        futexIo().futexWake(u32, &self.wake.raw, 1);
    }

    pub fn isClosed(self: *Outbound) bool {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        return self.closed;
    }
};

/// What a session sends through: its connection's FIFO and its id (empty for
/// the browser session, which messages name by leaving "sessionId" out).
/// Reference counted, so a `Reply` kept by a handler stays valid after the
/// session has ended - its answer is then dropped.
pub const SessionLink = struct {
    allocator: Allocator,
    outbound: *Outbound,
    id_buffer: [32]u8 = undefined,
    id_len: u8 = 0,
    /// Set when the session detaches: nothing more is sent.
    ended: std.atomic.Value(bool) = .init(false),
    refs: std.atomic.Value(u32) = .init(1),

    pub fn create(allocator: Allocator, outbound: *Outbound, session_id: []const u8) Allocator.Error!*SessionLink {
        std.debug.assert(session_id.len <= 32);
        const self = try allocator.create(SessionLink);
        self.* = .{ .allocator = allocator, .outbound = outbound.retain() };
        @memcpy(self.id_buffer[0..session_id.len], session_id);
        self.id_len = @intCast(session_id.len);
        return self;
    }

    pub fn retain(self: *SessionLink) *SessionLink {
        _ = self.refs.fetchAdd(1, .monotonic);
        return self;
    }

    pub fn release(self: *SessionLink) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        self.outbound.release();
        self.allocator.destroy(self);
    }

    pub fn sessionId(self: *const SessionLink) []const u8 {
        return self.id_buffer[0..self.id_len];
    }

    /// Send `message` (OWNED, allocated with `allocator`) unless the
    /// session has ended.
    pub fn send(self: *SessionLink, message: []u8) void {
        if (self.ended.load(.acquire)) {
            self.allocator.free(message);
            return;
        }
        self.outbound.push(message);
    }

    pub fn end(self: *SessionLink) void {
        self.ended.store(true, .release);
    }
};

test "pushed messages come out in order and a closed queue drops pushes" {
    const out = try Outbound.create(std.testing.allocator);
    defer out.release();
    out.push(try std.testing.allocator.dupe(u8, "one"));
    out.push(try std.testing.allocator.dupe(u8, "two"));
    var taken: std.ArrayList([]u8) = .empty;
    defer {
        for (taken.items) |m| std.testing.allocator.free(m);
        taken.deinit(std.testing.allocator);
    }
    try out.takeAll(&taken);
    try std.testing.expectEqual(@as(usize, 2), taken.items.len);
    try std.testing.expectEqualStrings("one", taken.items[0]);
    try std.testing.expectEqualStrings("two", taken.items[1]);
    out.close();
    out.push(try std.testing.allocator.dupe(u8, "late"));
    var after: std.ArrayList([]u8) = .empty;
    defer after.deinit(std.testing.allocator);
    try out.takeAll(&after);
    try std.testing.expectEqual(@as(usize, 0), after.items.len);
}

test "a session link outlives its session; an ended link sends nothing" {
    const out = try Outbound.create(std.testing.allocator);
    defer out.release();
    const link = try SessionLink.create(std.testing.allocator, out, "ABC");
    const kept = link.retain();
    link.release();
    try std.testing.expectEqualStrings("ABC", kept.sessionId());
    kept.end();
    kept.send(try std.testing.allocator.dupe(u8, "dropped"));
    kept.release();
    var taken: std.ArrayList([]u8) = .empty;
    defer taken.deinit(std.testing.allocator);
    try out.takeAll(&taken);
    try std.testing.expectEqual(@as(usize, 0), taken.items.len);
}
