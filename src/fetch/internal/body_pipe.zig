//! A response body still arriving from the network.
//!
//! Fetch hands a response on as soon as its headers are in, and its body's
//! stream fills as the bytes arrive (HTTP-network fetch, step 20: "enqueue
//! bytes into stream" as they are transmitted). This is that stream's source
//! on the Zig side, with no JavaScript in it: the network end pushes bytes
//! and says how the body ended; each reader - the ReadableStream a Response's
//! `body` is, an XMLHttpRequest - takes them when it is told there are some.
//!
//! A clone tees the body, so one network end (`PipeSource`) can feed several
//! readers (`BodyPipe`s, one per body). Each reader has its own copy of what
//! it has not taken yet. The transfer is cancelled when the last reader goes;
//! a reader that goes early takes nothing with it.
//!
//! Blink's equivalent is the BytesConsumer a FetchDataLoader reads, and
//! WebKit's is FetchBodyOwner's ReadableStreamSource: a native producer, a
//! stream-shaped consumer, and cancellation that runs from the consumer back
//! to the network.
//!
//! Single-threaded: both ends run on the thread that runs the page's script.
//!
//! Backpressure: once every reader has `high_water_mark` bytes it has not
//! taken, the producer is asked to pause (the transfer stops reading from
//! its socket, CURLPAUSE_RECV), and once the reader furthest ahead is below
//! `low_water_mark` again, to go on. The reader furthest ahead decides, so
//! a clone nobody reads never stalls the one that is read - its copy grows,
//! as a ReadableStream tee's does. Blink's DataPipe and WebKit's
//! NetworkLoad pause the same way, on a reader that falls behind.

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const State = enum { open, closed, errored };

/// The unread bytes at which the producer is paused - when every reader has
/// this many.
pub const high_water_mark: usize = 1024 * 1024;
/// The unread bytes below which it goes on - when any reader is under.
pub const low_water_mark: usize = 256 * 1024;

/// Why a body ended in error.
pub const Failure = struct {
    kind: Kind,
    /// An abort's reason, opaque here: the realm's value, which only a reader
    /// in that realm can use. Freed with the source, by `release_reason`.
    reason: ?*anyopaque = null,
    release_reason: ?*const fn (reason: *anyopaque) void = null,

    pub const Kind = enum { network, aborted };
};

/// Stops the network end - cancels the transfer - when no reader is left,
/// and holds it back while every reader is behind.
pub const Producer = struct {
    context: *anyopaque,
    /// After this the producer must not touch the source again.
    cancel: *const fn (context: *anyopaque) void,
    /// Stop producing for now: every reader is at the high-water mark. Null
    /// for a producer that must not pause - one whose reader takes nothing
    /// until the end, which would never come.
    pause: ?*const fn (context: *anyopaque) void = null,
    /// Go on after `pause`.
    unpause: ?*const fn (context: *anyopaque) void = null,
};

/// Hears that a reader's pipe has something new: bytes, or its end.
pub const Consumer = struct {
    context: *anyopaque,
    notify: *const fn (context: *anyopaque) void,
};

/// The network end of a body, shared by every reader of it.
pub const PipeSource = struct {
    allocator: Allocator,
    branches: std.ArrayListUnmanaged(*BodyPipe) = .empty,
    producer: ?Producer = null,
    state: State = .open,
    failure: ?Failure = null,
    /// The producer is paused (`pause` ran, `unpause` has not).
    paused: bool = false,

    /// A source with one reader. The producer, if any, is attached next.
    pub fn create(allocator: Allocator) !*PipeSource {
        const self = try allocator.create(PipeSource);
        self.* = .{ .allocator = allocator };
        return self;
    }

    /// A new reader of this source, starting from now.
    pub fn branch(self: *PipeSource) !*BodyPipe {
        const pipe = try self.allocator.create(BodyPipe);
        errdefer self.allocator.destroy(pipe);
        pipe.* = .{ .allocator = self.allocator, .source = self, .state = self.state };
        try self.branches.append(self.allocator, pipe);
        return pipe;
    }

    /// More of the body, for every reader.
    pub fn push(self: *PipeSource, bytes: []const u8) void {
        if (self.state != .open) return;
        // Appended to all first, notified after: a reader's notification may
        // release another reader.
        for (self.branches.items) |pipe| {
            pipe.buffered.appendSlice(pipe.allocator, bytes) catch {
                pipe.state = .errored;
                continue;
            };
            pipe.received += bytes.len;
        }
        self.holdBackIfBehind();
        self.notifyAll();
    }

    /// The least any reader has not taken: what decides backpressure.
    fn leastUnread(self: *const PipeSource) usize {
        if (self.branches.items.len == 0) return 0;
        var least: usize = std.math.maxInt(usize);
        for (self.branches.items) |pipe| least = @min(least, pipe.buffered.items.len);
        return least;
    }

    /// Pause the producer once every reader is at the high-water mark.
    fn holdBackIfBehind(self: *PipeSource) void {
        if (self.paused or self.state != .open) return;
        const producer = self.producer orelse return;
        const pause = producer.pause orelse return;
        if (self.leastUnread() < high_water_mark) return;
        self.paused = true;
        pause(producer.context);
    }

    /// Let the producer go on once a reader is below the low-water mark.
    fn goOnIfCaughtUp(self: *PipeSource) void {
        if (!self.paused) return;
        if (self.leastUnread() >= low_water_mark and self.branches.items.len > 0) return;
        self.paused = false;
        const producer = self.producer orelse return;
        if (producer.unpause) |unpause| unpause(producer.context);
    }

    /// The body ended cleanly. The producer is done with this source.
    pub fn finish(self: *PipeSource) void {
        self.producer = null;
        if (self.state != .open) return self.freeIfUnused();
        self.state = .closed;
        for (self.branches.items) |pipe| {
            if (pipe.state == .open) pipe.state = .closed;
        }
        self.notifyAll();
        self.freeIfUnused();
    }

    /// The body ended in error. The producer is done with this source, and
    /// `failure`'s reason is the source's from here.
    pub fn fail(self: *PipeSource, failure: Failure) void {
        self.producer = null;
        if (self.state != .open) {
            if (failure.reason) |r| if (failure.release_reason) |f| f(r);
            return self.freeIfUnused();
        }
        self.state = .errored;
        self.failure = failure;
        for (self.branches.items) |pipe| {
            if (pipe.state == .open) pipe.state = .errored;
        }
        self.notifyAll();
        self.freeIfUnused();
    }

    fn notifyAll(self: *PipeSource) void {
        // Copied: a notification may release a branch, which edits the list.
        const copy = self.allocator.dupe(*BodyPipe, self.branches.items) catch return;
        defer self.allocator.free(copy);
        for (copy) |pipe| {
            if (!self.contains(pipe)) continue;
            if (pipe.consumer) |c| c.notify(c.context);
        }
    }

    fn contains(self: *const PipeSource, pipe: *const BodyPipe) bool {
        for (self.branches.items) |b| {
            if (b == pipe) return true;
        }
        return false;
    }

    fn detachBranch(self: *PipeSource, pipe: *BodyPipe) void {
        for (self.branches.items, 0..) |b, i| {
            if (b == pipe) {
                _ = self.branches.orderedRemove(i);
                break;
            }
        }
    }

    fn stopIfUnread(self: *PipeSource) void {
        if (self.branches.items.len > 0) return;
        // Nobody is reading: the network can stop.
        if (self.producer) |p| {
            self.producer = null;
            p.cancel(p.context);
        }
        self.freeIfUnused();
    }

    fn freeIfUnused(self: *PipeSource) void {
        if (self.branches.items.len > 0 or self.producer != null) return;
        if (self.failure) |f| {
            if (f.reason) |r| if (f.release_reason) |release| release(r);
        }
        self.branches.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

/// One reader's view of a body arriving from the network.
pub const BodyPipe = struct {
    allocator: Allocator,
    /// Non-null for the pipe's whole life: the source outlives its branches.
    source: *PipeSource,
    /// Received and not yet taken.
    buffered: std.ArrayListUnmanaged(u8) = .empty,
    state: State,
    /// Every byte received so far, taken or not.
    received: u64 = 0,
    consumer: ?Consumer = null,

    /// Take what has arrived since the last take. The bytes are the caller's.
    /// A paused producer goes on once this reader has caught up.
    pub fn take(self: *BodyPipe) ![]u8 {
        const bytes = try self.buffered.toOwnedSlice(self.allocator);
        self.source.goOnIfCaughtUp();
        return bytes;
    }

    /// Whether there is anything to take.
    pub fn hasBytes(self: *const BodyPipe) bool {
        return self.buffered.items.len > 0;
    }

    /// Why the body failed, once `state` is errored.
    pub fn failure(self: *const BodyPipe) Failure {
        return self.source.failure orelse .{ .kind = .network };
    }

    /// A second reader, for a clone: it starts with a copy of what this one
    /// has not taken - all of it, since a clone needs an undisturbed body.
    pub fn tee(self: *BodyPipe) !*BodyPipe {
        const other = try self.source.branch();
        errdefer other.release();
        try other.buffered.appendSlice(other.allocator, self.buffered.items);
        other.received = self.received;
        other.state = self.state;
        return other;
    }

    /// This reader is done - read to the end, cancelled, or its body freed.
    /// The last reader to go stops the network.
    pub fn release(self: *BodyPipe) void {
        const source = self.source;
        self.consumer = null;
        source.detachBranch(self);
        self.buffered.deinit(self.allocator);
        self.allocator.destroy(self);
        // The reader that held it back may be the one that went.
        if (source.branches.items.len > 0) source.goOnIfCaughtUp();
        source.stopIfUnread();
    }
};

// =============================================================================
// Tests
// =============================================================================

const testing = std.testing;

const CountingConsumer = struct {
    notified: usize = 0,
    fn notify(context: *anyopaque) void {
        const self: *CountingConsumer = @ptrCast(@alignCast(context));
        self.notified += 1;
    }
};

const CountingProducer = struct {
    cancelled: usize = 0,
    fn cancel(context: *anyopaque) void {
        const self: *CountingProducer = @ptrCast(@alignCast(context));
        self.cancelled += 1;
    }
};

test "bytes pushed reach the reader, which is told, and the end closes it" {
    const source = try PipeSource.create(testing.allocator);
    var producer: CountingProducer = .{};
    source.producer = .{ .context = &producer, .cancel = CountingProducer.cancel };
    const pipe = try source.branch();
    var consumer: CountingConsumer = .{};
    pipe.consumer = .{ .context = &consumer, .notify = CountingConsumer.notify };

    source.push("ab");
    source.push("cd");
    try testing.expectEqual(@as(usize, 2), consumer.notified);
    const bytes = try pipe.take();
    defer testing.allocator.free(bytes);
    try testing.expectEqualStrings("abcd", bytes);
    try testing.expect(!pipe.hasBytes());

    source.finish();
    try testing.expectEqual(State.closed, pipe.state);
    try testing.expectEqual(@as(usize, 3), consumer.notified);
    pipe.release();
    // The body ended on its own: nothing to cancel.
    try testing.expectEqual(@as(usize, 0), producer.cancelled);
}

test "the last reader to go cancels the producer" {
    const source = try PipeSource.create(testing.allocator);
    var producer: CountingProducer = .{};
    source.producer = .{ .context = &producer, .cancel = CountingProducer.cancel };
    const pipe = try source.branch();
    source.push("abc");
    const clone = try pipe.tee();

    pipe.release();
    try testing.expectEqual(@as(usize, 0), producer.cancelled);
    // The clone still has everything the original had not read.
    try testing.expectEqualStrings("abc", clone.buffered.items);
    clone.release();
    try testing.expectEqual(@as(usize, 1), producer.cancelled);
}

test "a failure reaches every reader, and its reason goes with the source" {
    const Reason = struct {
        var released: usize = 0;
        fn release(_: *anyopaque) void {
            released += 1;
        }
    };
    Reason.released = 0;
    const source = try PipeSource.create(testing.allocator);
    var producer: CountingProducer = .{};
    source.producer = .{ .context = &producer, .cancel = CountingProducer.cancel };
    const a = try source.branch();
    const b = try a.tee();

    var token: u8 = 0;
    source.fail(.{ .kind = .aborted, .reason = &token, .release_reason = Reason.release });
    try testing.expectEqual(State.errored, a.state);
    try testing.expectEqual(State.errored, b.state);
    try testing.expectEqual(Failure.Kind.aborted, a.failure().kind);
    a.release();
    try testing.expectEqual(@as(usize, 0), Reason.released);
    b.release();
    try testing.expectEqual(@as(usize, 1), Reason.released);
    try testing.expectEqual(@as(usize, 0), producer.cancelled);
}
