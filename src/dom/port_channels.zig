//! Message channels whose two ends may live on two threads.
//!
//! HTML's MessagePorts come in entangled pairs; each has a port message queue
//! and, once it is enabled, the event loop of the port's realm runs one task
//! per queued message (HTML 9.4.4). A port can be transferred to a realm of
//! another agent - a worker's, on a thread of its own (docs/instances.md,
//! "Decisions") - and its queue and entanglement go with it. So the state the
//! two ports share cannot belong to either port's thread: it is a `Channel`,
//! one per entangled pair, with one mutex for both ends - Blink keeps the
//! same split, a MessagePortDescriptor (the channel's end, which crosses
//! threads) beside the MessagePort object (which does not).
//!
//! An `End` is one side: its queue, whether the queue is enabled, and its
//! owner - the platform object that receives what arrives there (a
//! MessagePort; a Worker's implicit port), with the TaskSink of that object's
//! event loop. The owner is thread-affine: it is dereferenced only by tasks
//! run on its sink's thread. Every other field is the channel's, under its
//! mutex.
//!
//! - post: the message joins the peer end's queue; if the peer has an owner,
//!   is enabled and has no notification pending, a "has messages" task goes
//!   to the owner's sink. That task, on the owner's thread, hands the owner
//!   ONE message (HTML: one task per message) and posts itself again while
//!   more remain.
//! - ship (the transfer steps): the end's owner is unbound - its epoch moves
//!   on, so a notification already in flight finds nothing - and the end
//!   travels inside a PortMessage, to any thread.
//! - receive (the transfer-receiving steps): a new owner binds the end, its
//!   queue disabled until that owner enables it.
//! - disentangle: the channel is no longer entangled; the peer's owner, if
//!   any, gets a `close` task on its sink.
//! - discard: the end's holder lets it go - disentangled, its queue dropped.
//!
//! Lifetime: the channel counts one reference per end still held (by an
//! owner, or inside a message in flight) and one per task in flight. A task
//! that never runs is dropped by its sink, which releases its reference: no
//! notification outlives the loop it was posted to with anything of it.
//!
//! Everything a message carries is engine-neutral: the serialization's bytes,
//! the transferred ArrayBuffers' contents (copied), the transferred ports'
//! ends. Its memory is the channel's allocator's, which must be thread-safe:
//! the receiving thread frees what the sending thread made.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const TaskSink = runtime.TaskSink;

const log = std.log.scoped(.port_channels);

/// One message on its way: what the message port post message steps
/// serialized (step 5), with the transferred ports' ends. OWNED by the queue
/// it waits on, then by the receiver.
pub const PortMessage = struct {
    allocator: Allocator,
    /// The engine's serialization. Owned.
    serialized: []u8,
    /// Each transferred ArrayBuffer's contents, in transfer-list order. Owned.
    array_buffers: [][]u8,
    /// The transferred ports' ends, in transfer-list order: each held by this
    /// message until the receiver takes them (`takeEnds`), discarded with it
    /// otherwise.
    ends: []*End,

    /// A message of `result` (taken: its serialization and buffers - its
    /// platform object list is the caller's) and `ends` (taken).
    pub fn create(allocator: Allocator, result: *runtime.SerializedWithTransfer, ends: []*End) Allocator.Error!*PortMessage {
        const self = try allocator.create(PortMessage);
        self.* = .{
            .allocator = allocator,
            .serialized = result.serialized,
            .array_buffers = result.array_buffers,
            .ends = ends,
        };
        result.serialized = &.{};
        result.array_buffers = &.{};
        return self;
    }

    /// The ends, which the caller now holds (each one to bind or discard).
    /// OWNED slice (`allocator`).
    pub fn takeEnds(self: *PortMessage) []*End {
        const ends = self.ends;
        self.ends = &.{};
        return ends;
    }

    /// Free the message, discarding any end still in it.
    pub fn destroy(self: *PortMessage) void {
        for (self.ends) |end| end.discard();
        self.allocator.free(self.ends);
        self.allocator.free(self.serialized);
        for (self.array_buffers) |contents| self.allocator.free(contents);
        self.allocator.free(self.array_buffers);
        self.allocator.destroy(self);
    }
};

/// What an owner does with what reaches its end. Both run on the owner's
/// sink's thread, as tasks of its loop; `receiver` and `generation` are what
/// the owner bound (`Owner`).
pub const ReceiverHooks = struct {
    /// A message waits at the end: take it with `delivery.next()` - or not,
    /// when the receiver cannot run the task now (its document is not fully
    /// active); it stays queued then.
    deliver: *const fn (receiver: *anyopaque, generation: u64, delivery: *Delivery) void,
    /// The entangled end was disentangled (HTML "disentangle" step 4: fire
    /// `close` at the other port).
    closed: *const fn (receiver: *anyopaque, generation: u64) void,
};

/// The platform object an end delivers to, while one has it.
pub const Owner = struct {
    /// Its event loop's inbox. The end holds a reference while bound.
    sink: *TaskSink,
    /// Thread-affine: dereferenced only on `sink`'s thread, by the hooks.
    receiver: *anyopaque,
    /// The receiver's slab generation (or any stamp the hooks check): a
    /// collected receiver's slot can be reissued.
    generation: u64,
    hooks: *const ReceiverHooks,
};

/// The end's state, read under the lock for a decision on the owner's thread
/// (a port's pending activity).
pub const EndState = struct {
    enabled: bool,
    entangled: bool,
    queued: usize,
};

pub const Channel = struct {
    allocator: Allocator,
    /// Protects every field of both ends and `entangled`. Never held across
    /// a post to a sink, a task's steps, or a message's destruction.
    mutex: std.Io.Mutex = .init,
    /// One per end still held, one per task in flight.
    refs: std.atomic.Value(u32) = .init(2),
    entangled: bool = true,
    ends: [2]End,

    /// A new channel, its two ends entangled and held by the caller (each
    /// to bind, or to discard).
    pub fn create(allocator: Allocator) Allocator.Error!*Channel {
        const self = try allocator.create(Channel);
        self.* = .{
            .allocator = allocator,
            .ends = .{ .{ .channel = self, .side = 0 }, .{ .channel = self, .side = 1 } },
        };
        return self;
    }

    pub fn end(self: *Channel, side: u1) *End {
        return &self.ends[side];
    }

    fn retain(self: *Channel) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }

    fn release(self: *Channel) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        // Both ends discarded and no task in flight: nothing can reach it.
        for (&self.ends) |*e| {
            std.debug.assert(e.queue.items.len == 0);
            std.debug.assert(e.owner == null);
            e.queue.deinit(self.allocator);
        }
        self.allocator.destroy(self);
    }

    fn lock(self: *Channel) void {
        std.Io.Threaded.mutexLock(&self.mutex);
    }

    fn unlock(self: *Channel) void {
        std.Io.Threaded.mutexUnlock(&self.mutex);
    }
};

pub const End = struct {
    channel: *Channel,
    side: u1,
    /// The port message queue of this end, oldest first.
    queue: std.ArrayListUnmanaged(*PortMessage) = .empty,
    /// Enabled by its owner's start() (or onmessage); a received end starts
    /// disabled.
    enabled: bool = false,
    owner: ?Owner = null,
    /// A "has messages" task is posted and has not run.
    notify_pending: bool = false,
    /// Moves on whenever the owner changes: a task posted for an earlier
    /// owner finds a different epoch and does nothing.
    epoch: u64 = 0,
    /// Discarded: the holder let it go, and it holds a reference no longer.
    discarded: bool = false,

    fn peer(self: *End) *End {
        return &self.channel.ends[1 - self.side];
    }

    /// Bind `owner` (HTML's transfer-receiving steps, or a new port on a
    /// fresh channel): it receives what arrives here from now on, once it
    /// enables the queue. Takes a reference to `owner.sink`.
    pub fn bind(self: *End, owner: Owner) void {
        const channel = self.channel;
        _ = owner.sink.retain();
        channel.lock();
        const previous = self.owner;
        self.owner = owner;
        self.epoch +%= 1;
        self.notify_pending = false;
        self.enabled = false;
        channel.unlock();
        if (previous) |old| old.sink.release();
    }

    /// The owner lets go of the end without discarding it - it is shipped
    /// (the transfer steps), or its realm ends. A notification in flight for
    /// it finds nothing.
    pub fn unbind(self: *End) void {
        const channel = self.channel;
        channel.lock();
        const previous = self.owner;
        self.owner = null;
        self.epoch +%= 1;
        self.notify_pending = false;
        channel.unlock();
        if (previous) |old| old.sink.release();
    }

    /// Enable the end's queue (start()): what waits there - and what arrives
    /// later - is delivered to its owner.
    pub fn enable(self: *End) void {
        const channel = self.channel;
        channel.lock();
        self.enabled = true;
        const notify = self.claimNotify();
        channel.unlock();
        if (notify) |n| n.send();
    }

    /// The message port post message steps' step 7, from this end: `message`
    /// joins the queue of the end this one is entangled with. Taken: a
    /// message with nowhere to go - the channel is not entangled - is freed.
    pub fn post(self: *End, message: *PortMessage) void {
        const channel = self.channel;
        channel.lock();
        if (!channel.entangled or self.discarded) {
            channel.unlock();
            message.destroy();
            return;
        }
        const target = self.peer();
        target.queue.append(channel.allocator, message) catch {
            channel.unlock();
            log.warn("out of memory queueing a message; dropped", .{});
            message.destroy();
            return;
        };
        const notify = target.claimNotify();
        channel.unlock();
        if (notify) |n| n.send();
    }

    /// HTML "disentangle", from this end: the channel is no longer entangled,
    /// and the other end's owner hears `close` from a task of its own loop.
    /// Messages already queued stay where they are.
    pub fn disentangle(self: *End) void {
        const channel = self.channel;
        channel.lock();
        if (!channel.entangled) {
            channel.unlock();
            return;
        }
        channel.entangled = false;
        const other = self.peer();
        var close: ?Notify = null;
        if (other.owner) |owner| {
            if (!other.discarded) close = .{ .channel = channel, .side = other.side, .epoch = other.epoch, .sink = owner.sink.retain(), .kind = .close };
        }
        if (close != null) channel.retain();
        channel.unlock();
        if (close) |n| n.send();
    }

    /// The holder lets the end go for good: disentangled, unbound, its queue
    /// dropped, and its reference on the channel released. Call once.
    pub fn discard(self: *End) void {
        self.disentangle();
        const channel = self.channel;
        channel.lock();
        std.debug.assert(!self.discarded);
        self.discarded = true;
        const previous = self.owner;
        self.owner = null;
        self.epoch +%= 1;
        self.notify_pending = false;
        var queue = self.queue;
        self.queue = .empty;
        channel.unlock();
        if (previous) |old| old.sink.release();
        for (queue.items) |message| message.destroy();
        queue.deinit(channel.allocator);
        channel.release();
    }

    /// Drop every message queued at this end ("terminate a worker" step 4:
    /// empty the port message queue).
    pub fn clearQueue(self: *End) void {
        const channel = self.channel;
        channel.lock();
        var queue = self.queue;
        self.queue = .empty;
        channel.unlock();
        for (queue.items) |message| message.destroy();
        queue.deinit(channel.allocator);
    }

    /// The end's state now, for a decision its owner makes on its own thread.
    pub fn state(self: *End) EndState {
        const channel = self.channel;
        channel.lock();
        defer channel.unlock();
        return .{ .enabled = self.enabled, .entangled = channel.entangled, .queued = self.queue.items.len };
    }

    /// Whether `other` is the end this one is entangled with.
    pub fn isEntangledWith(self: *End, other: *End) bool {
        if (other.channel != self.channel or other.side == self.side) return false;
        const channel = self.channel;
        channel.lock();
        defer channel.unlock();
        return channel.entangled;
    }

    /// Under the lock: if this end should be told it has messages, mark the
    /// notification pending and return it (sent after the unlock).
    fn claimNotify(self: *End) ?Notify {
        if (self.notify_pending or !self.enabled or self.discarded) return null;
        if (self.queue.items.len == 0) return null;
        const owner = self.owner orelse return null;
        self.notify_pending = true;
        self.channel.retain();
        return .{ .channel = self.channel, .side = self.side, .epoch = self.epoch, .sink = owner.sink.retain(), .kind = .messages };
    }
};

/// A delivery in progress: the owner's hook takes the next message from it.
pub const Delivery = struct {
    end: *End,
    epoch: u64,
    taken: bool = false,

    /// The next message for the receiver - null when the end is no longer
    /// its own (shipped, discarded) or has none. Taken: the receiver frees it
    /// (`PortMessage.destroy`).
    pub fn next(self: *Delivery) ?*PortMessage {
        if (self.taken) return null;
        const channel = self.end.channel;
        channel.lock();
        defer channel.unlock();
        if (self.end.epoch != self.epoch or self.end.queue.items.len == 0) return null;
        self.taken = true;
        return self.end.queue.orderedRemove(0);
    }
};

/// A task for an end's owner, posted to its sink: "has messages", or the
/// peer's `close`. Holds a channel reference and a sink reference.
const Notify = struct {
    channel: *Channel,
    side: u1,
    epoch: u64,
    sink: *TaskSink,
    kind: enum { messages, close },

    /// Post the task (outside the channel's lock). A closed sink drops it.
    fn send(self: Notify) void {
        const sink = self.sink;
        defer sink.release();
        const task = self.channel.allocator.create(Notify) catch {
            log.warn("out of memory notifying a port; dropped", .{});
            drop(self);
            return;
        };
        task.* = self;
        _ = sink.post(.{ .run = run, .drop = dropTask, .data = task });
    }

    fn run(data: ?*anyopaque) void {
        const task: *Notify = @ptrCast(@alignCast(data.?));
        const self = task.*;
        self.channel.allocator.destroy(task);
        defer self.channel.release();
        const channel = self.channel;
        const end = &channel.ends[self.side];

        channel.lock();
        const owner = if (end.epoch == self.epoch) end.owner else null;
        channel.unlock();
        const current = owner orelse return;

        switch (self.kind) {
            .close => current.hooks.closed(current.receiver, current.generation),
            .messages => {
                var delivery: Delivery = .{ .end = end, .epoch = self.epoch };
                current.hooks.deliver(current.receiver, current.generation, &delivery);
                // One message per task: while more wait, the next task goes
                // out; a receiver that took none leaves the queue to the next
                // post or enable, as a task that could not run does.
                channel.lock();
                var again: ?Notify = null;
                if (end.epoch == self.epoch) {
                    end.notify_pending = false;
                    if (delivery.taken) again = end.claimNotify();
                }
                channel.unlock();
                if (again) |n| n.send();
            },
        }
    }

    /// The task will never run (its sink closed): its references go, and the
    /// end may be told again by a later owner.
    fn dropTask(data: ?*anyopaque) void {
        const task: *Notify = @ptrCast(@alignCast(data.?));
        const self = task.*;
        self.channel.allocator.destroy(task);
        // `sink` was released by `send`.
        self.channel.release();
    }

    /// `send` could not even make the task.
    fn drop(self: Notify) void {
        const channel = self.channel;
        if (self.kind == .messages) {
            channel.lock();
            const end = &channel.ends[self.side];
            if (end.epoch == self.epoch) end.notify_pending = false;
            channel.unlock();
        }
        channel.release();
    }
};

// ============================================================================
// Tests: one thread (the threads are tests/dom/port_channels_test.zig's)
// ============================================================================

const testing = std.testing;

/// A receiver that records what reached it.
const Recorder = struct {
    delivered: std.ArrayListUnmanaged(u8) = .empty,
    closes: u32 = 0,
    /// Take nothing while false (a document not fully active).
    ready: bool = true,

    const hooks: ReceiverHooks = .{ .deliver = deliver, .closed = closed };

    fn deliver(receiver: *anyopaque, _: u64, delivery: *Delivery) void {
        const self: *Recorder = @ptrCast(@alignCast(receiver));
        if (!self.ready) return;
        const message = delivery.next() orelse return;
        defer message.destroy();
        self.delivered.append(testing.allocator, message.serialized[0]) catch {};
    }

    fn closed(receiver: *anyopaque, _: u64) void {
        const self: *Recorder = @ptrCast(@alignCast(receiver));
        self.closes += 1;
    }

    fn owner(self: *Recorder, sink: *TaskSink) Owner {
        return .{ .sink = sink, .receiver = self, .generation = 0, .hooks = &hooks };
    }
};

fn testMessage(byte: u8) !*PortMessage {
    var result: runtime.SerializedWithTransfer = .{
        .serialized = try testing.allocator.dupe(u8, &.{byte}),
        .array_buffers = &.{},
        .platform_objects = &.{},
    };
    return PortMessage.create(testing.allocator, &result, &.{});
}

/// Run what `sink` holds, as its loop would, until nothing is posted.
fn drain(sink: *TaskSink) !void {
    var taken: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
    defer taken.deinit(testing.allocator);
    while (sink.hasPosted()) {
        try sink.takeAll(&taken, testing.allocator);
        for (taken.items) |task| task.run(task.data);
        taken.clearRetainingCapacity();
    }
}

test "messages wait for an enabled queue and arrive one per task, in order" {
    const sink = try TaskSink.create(testing.allocator);
    defer sink.release();
    const channel = try Channel.create(testing.allocator);
    var a: Recorder = .{};
    var b: Recorder = .{};
    defer a.delivered.deinit(testing.allocator);
    defer b.delivered.deinit(testing.allocator);
    channel.end(0).bind(a.owner(sink));
    channel.end(1).bind(b.owner(sink));

    channel.end(0).post(try testMessage('x'));
    channel.end(0).post(try testMessage('y'));
    // Disabled: nothing is posted to the loop.
    try testing.expect(!sink.hasPosted());
    channel.end(1).enable();
    try testing.expect(sink.hasPosted());
    // One task delivers one message, and posts the next.
    var taken: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
    defer taken.deinit(testing.allocator);
    try sink.takeAll(&taken, testing.allocator);
    try testing.expectEqual(@as(usize, 1), taken.items.len);
    taken.items[0].run(taken.items[0].data);
    try testing.expectEqualStrings("x", b.delivered.items);
    try drain(sink);
    try testing.expectEqualStrings("xy", b.delivered.items);

    channel.end(0).discard();
    try drain(sink);
    // The peer's owner heard `close`.
    try testing.expectEqual(@as(u32, 1), b.closes);
    channel.end(1).discard();
}

test "a shipped end's queue goes with it, and its old owner hears nothing" {
    const sink = try TaskSink.create(testing.allocator);
    defer sink.release();
    const channel = try Channel.create(testing.allocator);
    var old: Recorder = .{};
    var new: Recorder = .{};
    defer old.delivered.deinit(testing.allocator);
    defer new.delivered.deinit(testing.allocator);
    channel.end(1).bind(old.owner(sink));
    channel.end(1).enable();
    channel.end(0).post(try testMessage('m'));
    // Shipped before the notification ran: it finds a new epoch.
    channel.end(1).unbind();
    try drain(sink);
    try testing.expectEqual(@as(usize, 0), old.delivered.items.len);
    // Received: disabled until the new owner enables it.
    channel.end(1).bind(new.owner(sink));
    try drain(sink);
    try testing.expectEqual(@as(usize, 0), new.delivered.items.len);
    channel.end(1).enable();
    try drain(sink);
    try testing.expectEqualStrings("m", new.delivered.items);
    channel.end(0).discard();
    channel.end(1).discard();
}

test "a receiver that takes nothing keeps its message, and a later post delivers both" {
    const sink = try TaskSink.create(testing.allocator);
    defer sink.release();
    const channel = try Channel.create(testing.allocator);
    var r: Recorder = .{ .ready = false };
    defer r.delivered.deinit(testing.allocator);
    channel.end(1).bind(r.owner(sink));
    channel.end(1).enable();
    channel.end(0).post(try testMessage('a'));
    try drain(sink);
    try testing.expectEqual(@as(usize, 1), channel.end(1).state().queued);
    r.ready = true;
    channel.end(0).post(try testMessage('b'));
    try drain(sink);
    try testing.expectEqualStrings("ab", r.delivered.items);
    // Discarding frees what is still queued (nothing here) and the channel.
    channel.end(1).discard();
    channel.end(0).discard();
}

test "a message carrying an end discards it with itself; a closed sink drops its tasks" {
    const sink = try TaskSink.create(testing.allocator);
    const channel = try Channel.create(testing.allocator);
    const carried = try Channel.create(testing.allocator);
    var r: Recorder = .{};
    defer r.delivered.deinit(testing.allocator);
    channel.end(1).bind(r.owner(sink));
    channel.end(1).enable();

    // One of `carried`'s ends travels in a message; the other is held.
    var result: runtime.SerializedWithTransfer = .{
        .serialized = try testing.allocator.dupe(u8, "p"),
        .array_buffers = &.{},
        .platform_objects = &.{},
    };
    const ends = try testing.allocator.alloc(*End, 1);
    ends[0] = carried.end(0);
    channel.end(0).post(try PortMessage.create(testing.allocator, &result, ends));
    // The loop ends before the notification runs: the sink drops it.
    sink.close();
    sink.release();
    // The queued message - and the end in it - go with the channel's ends.
    channel.end(1).discard();
    channel.end(0).discard();
    carried.end(1).discard();
}
