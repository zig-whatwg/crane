//! Service Workers "Handle Fetch", as fetch reaches it.
//!
//! HTTP fetch step 3 hands a request to a service worker and waits for its
//! answer - the response its fetch event was answered with, a network error,
//! or nothing (fetch goes on to the network). Fetch does not know service
//! workers: a request carries a `Route` to its Browser's (the client's, set by
//! "populate request from client" for a controlled client; or the reserved
//! client's, set by the navigation or worker that reserved it), and the route
//! starts Handle Fetch on the fetching thread. When a service worker is to
//! handle the request, the route gives back a `Call`: the rendezvous where the
//! service worker's answer arrives, from whichever thread it runs on.
//!
//! The waiting is the fetch's driver's, as the network's is (fetch_job.zig's
//! `.service_worker` step): `AsyncFetch` asks the call at each turn of its
//! agent's event loop (`take`), the blocking `fetch()` waits for it (`wait`).
//! A response's body crosses threads through a `BodyRelay`: the service
//! worker's side writes the chunks its realm reads, the fetching side drains
//! them into the PipeSource its response's body reads from.
//!
//! Everything here is engine-free and thread-safe; each object is shared by
//! exactly two holders - the fetching side and the service worker side - and
//! goes when both have let it go.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#handle-fetch
//! Spec: https://fetch.spec.whatwg.org/#http-fetch (step 3)

const std = @import("std");
const Allocator = std.mem.Allocator;
const InternalRequest = @import("request.zig").InternalRequest;
const InternalResponse = @import("response.zig").InternalResponse;
const platform = @import("platform");

/// How long a blocking fetch (fetch.zig: a synchronous XMLHttpRequest,
/// importScripts(), a parser-blocking script of a temporary - fragment or
/// XML - parser) waits for a service worker's answer, and then for the rest
/// of its body. The waiting thread runs nothing meanwhile, so a fetch handler
/// that needs it - a reply to a message it posted to the page, which only a
/// task there can send - is never answered: the wait ends here and the
/// request is a network error, instead of the page's thread hanging for
/// good. A hang guard, not behaviour to rely on: long enough that a slow
/// handler on a loaded machine does not trip it. A document parser's
/// parser-blocking script no longer comes here: it is fetched
/// asynchronously while the parser waits and the event loop spins (HTML
/// "spin the event loop until ... the script is ready to be
/// parser-executed"; the case postmessage-to-client-message-queue.https.html
/// exercises). Chromium bounds a fetch event only at 5 minutes
/// (ServiceWorkerVersion's request timeout).
pub const blocking_wait_limit_ms: u64 = 10_000;

/// The time left until `deadline` (the platform's monotonic clock, in
/// nanoseconds), or null once it has passed.
fn remaining(deadline: i128) ?std.Io.Timeout {
    const now: i128 = platform.monotonicNow().ns;
    if (now >= deadline) return null;
    return .{ .duration = .{ .raw = .fromNanoseconds(@intCast(deadline - now)), .clock = .awake } };
}

fn deadlineAfter(limit_ms: u64) i128 {
    return @as(i128, platform.monotonicNow().ns) + @as(i128, limit_ms) * std.time.ns_per_ms;
}
const body_pipe = @import("body_pipe.zig");
const PipeSource = body_pipe.PipeSource;

/// How a request reaches its Browser's service workers. BORROWED by the
/// request: the Browser outlives every fetch it makes.
pub const Route = struct {
    /// The service workers' owner (a Browser's manager), opaque here.
    context: *anyopaque,
    /// The request's client, as the owner names it (0: none) - a subresource
    /// request's client is controlled, or it would have no route.
    client: u64 = 0,
    /// Handle Fetch, started on the fetching thread: whether a service worker
    /// handles `request` (BORROWED for the call: what crosses threads the
    /// owner copies). `.network` is Handle Fetch returning null.
    handle: *const fn (context: *anyopaque, request: *const InternalRequest, client: u64) Allocator.Error!Start,

    pub const Start = union(enum) {
        /// No service worker handles the request: HTTP fetch step 4.
        network,
        /// A service worker's fetch event is under way: wait for the call's
        /// answer. The caller holds one reference.
        call: *Call,
        /// Handle Fetch 13.3.4, a "race-network-and-fetch-handler" source:
        /// the fetch event is under way, and the fetching side fetches the
        /// request from the network beside it (AsyncFetch's race) - the
        /// first usable answer is the fetch's. The caller holds one
        /// reference.
        race: *Call,
    };
};

/// One request handed to a service worker, until its answer is taken.
pub const Call = struct {
    /// Thread-safe (a Browser's): whichever side lets go last frees with it.
    allocator: Allocator,
    mutex: std.Io.Mutex = .init,
    refs: std.atomic.Value(u32) = .init(2),
    state: State = .pending,
    slot: ?Answer = null,
    /// Bumped by `answer`: the futex word `wait` sleeps on.
    wake: std.atomic.Value(u32) = .init(0),
    /// What a blocking wait does around itself (`wait`): set by the service
    /// worker side before the call is handed to fetch, read only by `wait`.
    blocking: ?Blocking = null,

    pub const State = enum { pending, answered, taken, abandoned, lost };

    /// How Handle Fetch ended for the request.
    pub const Answer = union(enum) {
        /// Handle Fetch returned null: fetch goes to the network (HTTP fetch
        /// step 4), as if no service worker had been asked.
        fallback,
        /// Handle Fetch returned a network error (handleFetchFailed, a
        /// respond-with error, a canceled fetch event).
        network_error,
        /// The fetch event's response. OWNED by whoever holds the answer.
        response: Response,
    };

    pub const Response = struct {
        /// Its body is null: the body, if any, arrives through `body`.
        response: *InternalResponse,
        body: ?*BodyRelay = null,
    };

    /// Steps a blocking wait runs on the waiting thread, just before it
    /// sleeps and just after it wakes: the owner keeps what that thread
    /// cannot answer while it sleeps (a window client's data) answerable.
    pub const Blocking = struct {
        context: *anyopaque,
        data: u64,
        before_wait: *const fn (context: *anyopaque, data: u64) void,
        after_wait: *const fn (context: *anyopaque, data: u64) void,
    };

    /// A call held twice: once by the service worker side, once for fetch.
    pub fn create(allocator: Allocator) Allocator.Error!*Call {
        const self = try allocator.create(Call);
        self.* = .{ .allocator = allocator };
        return self;
    }

    /// The service worker side's answer, once. Taken: after fetch gave up
    /// (`abandon`), it is freed here.
    pub fn answer(self: *Call, value: Answer) void {
        lock(&self.mutex);
        if (self.state != .pending) {
            unlock(&self.mutex);
            freeAnswer(value);
            return;
        }
        self.slot = value;
        self.state = .answered;
        unlock(&self.mutex);
        _ = self.wake.fetchAdd(1, .release);
        futexIo().futexWake(u32, &self.wake.raw, 1);
    }

    /// Whether fetch gave up on the call: the service worker side may stop.
    pub fn isAbandoned(self: *Call) bool {
        lock(&self.mutex);
        defer unlock(&self.mutex);
        return self.state == .abandoned;
    }

    /// The fetching side: the answer, if it has come - once.
    pub fn take(self: *Call) ?Answer {
        lock(&self.mutex);
        defer unlock(&self.mutex);
        if (self.state != .answered) return null;
        self.state = .taken;
        const value = self.slot.?;
        self.slot = null;
        return value;
    }

    /// The fetching side, blocking until the answer comes - for at most
    /// `limit_ms` (`blocking_wait_limit_ms`). Null: none came in time; the
    /// caller gives up on the call (`abandon`).
    pub fn wait(self: *Call, limit_ms: u64) ?Answer {
        if (self.blocking) |b| b.before_wait(b.context, b.data);
        defer if (self.blocking) |b| b.after_wait(b.context, b.data);
        const deadline = deadlineAfter(limit_ms);
        while (true) {
            // Read the word before asking: an answer that lands after the
            // ask has bumped it, and the wait returns at once.
            const seen = self.wake.load(.acquire);
            if (self.take()) |value| return value;
            const left = remaining(deadline) orelse return null;
            futexIo().futexWaitTimeout(u32, &self.wake.raw, seen, left) catch {};
        }
    }

    /// The fetching side gives up (its fetch was terminated): an answer
    /// waiting, or one still to come, is freed.
    pub fn abandon(self: *Call) void {
        lock(&self.mutex);
        const waiting = self.slot;
        self.slot = null;
        self.state = .abandoned;
        unlock(&self.mutex);
        if (waiting) |value| freeAnswer(value);
    }

    /// The fetching side no longer wants the answer, but the fetch event is
    /// still to run: the network won Handle Fetch 13.3.4's race (step 13.3.4.5
    /// enqueued its response first) while Create Fetch Event and Dispatch,
    /// which runs in parallel, goes on. Unlike `abandon`, `isAbandoned` stays
    /// false, so the worker's thread still fires the event. An answer
    /// waiting, or one still to come, is freed.
    pub fn lose(self: *Call) void {
        lock(&self.mutex);
        const waiting = self.slot;
        self.slot = null;
        if (self.state != .abandoned) self.state = .lost;
        unlock(&self.mutex);
        if (waiting) |value| freeAnswer(value);
    }

    /// One more holder (the service worker side handing its reference on
    /// while it still uses the call).
    pub fn retain(self: *Call) *Call {
        _ = self.refs.fetchAdd(1, .monotonic);
        return self;
    }

    /// Let go of one reference.
    pub fn release(self: *Call) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        if (self.slot) |value| freeAnswer(value);
        self.allocator.destroy(self);
    }
};

/// Free an answer nobody will take.
pub fn freeAnswer(value: Call.Answer) void {
    switch (value) {
        .fallback, .network_error => {},
        .response => |r| {
            r.response.deinit();
            if (r.body) |relay| {
                relay.cancel();
                relay.release();
            }
        },
    }
}

/// A response body on its way from a service worker's thread to the
/// fetching thread. The writer is the service worker side, the reader the
/// fetching side; each holds one reference.
///
/// No backpressure (a stated deviation): what the service worker writes waits
/// here until the fetching side drains it, however much there is.
pub const BodyRelay = struct {
    allocator: Allocator,
    mutex: std.Io.Mutex = .init,
    refs: std.atomic.Value(u32) = .init(2),
    /// Written and not yet drained.
    pending: std.ArrayListUnmanaged(u8) = .empty,
    end: End = .open,
    /// The fetching side has no reader left: the writer may stop.
    cancelled: bool = false,
    /// What the writer asks to hear when the reader goes (`watchCancel`).
    reader_gone: ?ReaderGone = null,
    /// The reader's count of the bytes it has drained: what Resource Timing
    /// reports as the relayed body's size. Touched by the reader only.
    drained: u64 = 0,
    /// Bumped by every write and end: the futex word `collect` sleeps on.
    wake: std.atomic.Value(u32) = .init(0),

    pub const End = enum { open, closed, errored };

    /// The writer's word that the reader went: a writer waiting on its own
    /// source - a stream's read still pending - would otherwise learn of the
    /// cancel only at its next write, which may never come
    /// (fetch-event-respond-with-readable-stream.https.html: a cancel or
    /// abort in the page is observable in the service worker). Exactly one
    /// of the two runs, once: `run` on the reader's thread when it cancels,
    /// `drop` when the relay goes with no cancel.
    pub const ReaderGone = struct {
        context: *anyopaque,
        run: *const fn (context: *anyopaque) void,
        drop: *const fn (context: *anyopaque) void,
    };

    pub fn create(allocator: Allocator) Allocator.Error!*BodyRelay {
        const self = try allocator.create(BodyRelay);
        self.* = .{ .allocator = allocator };
        return self;
    }

    // -- The writer (the service worker side) --------------------------------

    /// More of the body. False when nobody reads any more (or the bytes could
    /// not be kept, which fails the body): the writer stops.
    pub fn write(self: *BodyRelay, bytes: []const u8) bool {
        lock(&self.mutex);
        if (self.cancelled or self.end != .open) {
            unlock(&self.mutex);
            return false;
        }
        const kept = if (self.pending.appendSlice(self.allocator, bytes)) |_| true else |_| blk: {
            self.end = .errored;
            break :blk false;
        };
        unlock(&self.mutex);
        self.bump();
        return kept;
    }

    /// The body has ended.
    pub fn close(self: *BodyRelay) void {
        self.finishWith(.closed);
    }

    /// The body failed: the reader's body errors.
    pub fn fail(self: *BodyRelay) void {
        self.finishWith(.errored);
    }

    /// The writer asks to hear the reader's cancel (`ReaderGone`). A reader
    /// gone already: `hook` runs at once, here.
    pub fn watchCancel(self: *BodyRelay, hook: ReaderGone) void {
        lock(&self.mutex);
        if (self.cancelled) {
            unlock(&self.mutex);
            return hook.run(hook.context);
        }
        const old = self.reader_gone;
        self.reader_gone = hook;
        unlock(&self.mutex);
        if (old) |o| o.drop(o.context);
    }

    /// Whether the reader is gone.
    pub fn isCancelled(self: *BodyRelay) bool {
        lock(&self.mutex);
        defer unlock(&self.mutex);
        return self.cancelled;
    }

    fn finishWith(self: *BodyRelay, end: End) void {
        lock(&self.mutex);
        if (self.end == .open) self.end = end;
        unlock(&self.mutex);
        self.bump();
    }

    fn bump(self: *BodyRelay) void {
        _ = self.wake.fetchAdd(1, .release);
        futexIo().futexWake(u32, &self.wake.raw, 1);
    }

    // -- The reader (the fetching side) --------------------------------------

    /// Hand what was written since the last drain to `source`, and its end
    /// once it has ended. `.open` while more may come.
    pub fn drainInto(self: *BodyRelay, source: *PipeSource) End {
        lock(&self.mutex);
        var taken = self.pending;
        self.pending = .empty;
        const end = self.end;
        unlock(&self.mutex);
        defer taken.deinit(self.allocator);
        self.drained += taken.items.len;
        if (taken.items.len > 0) source.push(taken.items);
        switch (end) {
            .open => {},
            .closed => source.finish(),
            .errored => source.fail(.{ .kind = .network }),
        }
        return end;
    }

    /// Wait for the whole body (the blocking fetch's driver) - for at most
    /// `limit_ms` (`blocking_wait_limit_ms`). OWNED by `allocator`;
    /// error.NetworkError when it failed or had not ended in time (the
    /// caller cancels the relay).
    pub fn collect(self: *BodyRelay, allocator: Allocator, limit_ms: u64) error{ OutOfMemory, NetworkError }![]u8 {
        var bytes: std.ArrayListUnmanaged(u8) = .empty;
        errdefer bytes.deinit(allocator);
        const deadline = deadlineAfter(limit_ms);
        while (true) {
            const seen = self.wake.load(.acquire);
            lock(&self.mutex);
            var taken = self.pending;
            self.pending = .empty;
            const end = self.end;
            unlock(&self.mutex);
            defer taken.deinit(self.allocator);
            try bytes.appendSlice(allocator, taken.items);
            switch (end) {
                .closed => return bytes.toOwnedSlice(allocator),
                .errored => return error.NetworkError,
                .open => {},
            }
            const left = remaining(deadline) orelse return error.NetworkError;
            futexIo().futexWaitTimeout(u32, &self.wake.raw, seen, left) catch {};
        }
    }

    /// The reader is gone: what was written goes, and the writer stops -
    /// told so now if it asked (`watchCancel`).
    pub fn cancel(self: *BodyRelay) void {
        lock(&self.mutex);
        const first = !self.cancelled;
        self.cancelled = true;
        self.pending.clearAndFree(self.allocator);
        const hook = if (first) self.reader_gone else null;
        if (first) self.reader_gone = null;
        unlock(&self.mutex);
        if (hook) |h| h.run(h.context);
    }

    /// Let go of one reference.
    pub fn release(self: *BodyRelay) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        if (self.reader_gone) |h| h.drop(h.context);
        self.pending.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

fn lock(mutex: *std.Io.Mutex) void {
    std.Io.Threaded.mutexLock(mutex);
}

fn unlock(mutex: *std.Io.Mutex) void {
    std.Io.Threaded.mutexUnlock(mutex);
}

/// The futex calls' `Io` (runtime.TaskSink's reasoning: a futex wait and wake
/// are plain system calls on an address, the same through any Io.Threaded).
fn futexIo() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn sleepMs(ms: u64) void {
    futexIo().sleep(.fromNanoseconds(@intCast(ms * std.time.ns_per_ms)), .awake) catch {};
}

fn testResponse(status: u16) !*InternalResponse {
    const response = try InternalResponse.init(testing.allocator);
    response.status = status;
    return response;
}

test "a call's answer is taken once, and not before it comes" {
    const call = try Call.create(testing.allocator);
    defer call.release();
    defer call.release();
    try testing.expect(call.take() == null);
    call.answer(.fallback);
    try testing.expect(call.take().? == .fallback);
    try testing.expect(call.take() == null);
}

test "an answer to a call fetch gave up on is freed, before or after it comes" {
    {
        const call = try Call.create(testing.allocator);
        call.abandon();
        try testing.expect(call.isAbandoned());
        // The response's allocation is freed here (std.testing.allocator
        // would report it leaked otherwise).
        call.answer(.{ .response = .{ .response = try testResponse(200) } });
        call.release();
        call.release();
    }
    {
        const call = try Call.create(testing.allocator);
        const relay = try BodyRelay.create(testing.allocator);
        call.answer(.{ .response = .{ .response = try testResponse(200), .body = relay } });
        call.abandon();
        // The reader's reference went with the answer, cancelled: the writer
        // sees it and lets go of its own.
        try testing.expect(relay.isCancelled());
        relay.release();
        call.release();
        call.release();
    }
    {
        // Never taken, never abandoned: the last release frees it.
        const call = try Call.create(testing.allocator);
        call.answer(.{ .response = .{ .response = try testResponse(204) } });
        call.release();
        call.release();
    }
}

test "a call the network won a race for frees its answer, but its fetch event is not abandoned" {
    const call = try Call.create(testing.allocator);
    call.lose();
    try testing.expect(!call.isAbandoned());
    try testing.expect(call.take() == null);
    // The worker's answer, after the race was lost, is freed here.
    const relay = try BodyRelay.create(testing.allocator);
    call.answer(.{ .response = .{ .response = try testResponse(201), .body = relay } });
    // The reader's reference went with the answer, cancelled.
    try testing.expect(relay.isCancelled());
    relay.release();
    // Abandoned later (the fetch ended): still nothing to take.
    call.abandon();
    call.release();
    call.release();
}

const Waiting = struct {
    calls: u32 = 0,
    before: u32 = 0,
    after: u32 = 0,

    fn beforeWait(context: *anyopaque, data: u64) void {
        const self: *Waiting = @ptrCast(@alignCast(context));
        self.before += @intCast(data);
    }

    fn afterWait(context: *anyopaque, data: u64) void {
        const self: *Waiting = @ptrCast(@alignCast(context));
        self.after += @intCast(data);
    }
};

test "a blocking wait sleeps until another thread answers, with the owner's steps around it" {
    const call = try Call.create(testing.allocator);
    defer call.release();
    var waiting: Waiting = .{};
    call.blocking = .{ .context = &waiting, .data = 1, .before_wait = Waiting.beforeWait, .after_wait = Waiting.afterWait };
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(c: *Call) void {
            sleepMs(5);
            c.answer(.network_error);
            c.release();
        }
    }.run, .{call});
    const value = call.wait(5_000) orelse return error.TestUnexpectedTimeout;
    thread.join();
    try testing.expect(value == .network_error);
    try testing.expectEqual(@as(u32, 1), waiting.before);
    try testing.expectEqual(@as(u32, 1), waiting.after);
}

test "a relay drains what was written into a pipe source, then its end" {
    const relay = try BodyRelay.create(testing.allocator);
    defer relay.release();
    const source = try PipeSource.create(testing.allocator);
    const pipe = try source.branch();
    defer pipe.release();

    try testing.expect(relay.write("hello "));
    try testing.expectEqual(BodyRelay.End.open, relay.drainInto(source));
    try testing.expect(relay.write("world"));
    relay.close();
    try testing.expect(!relay.write("late"));
    try testing.expectEqual(BodyRelay.End.closed, relay.drainInto(source));
    relay.release();
    const bytes = try pipe.take();
    defer testing.allocator.free(bytes);
    try testing.expectEqualStrings("hello world", bytes);
    try testing.expectEqual(body_pipe.State.closed, pipe.state);
}

test "a relay that fails errors the pipe; one whose reader is gone stops its writer" {
    {
        const relay = try BodyRelay.create(testing.allocator);
        const source = try PipeSource.create(testing.allocator);
        const pipe = try source.branch();
        defer pipe.release();
        try testing.expect(relay.write("x"));
        relay.fail();
        try testing.expectEqual(BodyRelay.End.errored, relay.drainInto(source));
        try testing.expectEqual(body_pipe.State.errored, pipe.state);
        relay.release();
        relay.release();
    }
    {
        const relay = try BodyRelay.create(testing.allocator);
        try testing.expect(relay.write("unread"));
        relay.cancel();
        try testing.expect(relay.isCancelled());
        try testing.expect(!relay.write("more"));
        relay.release();
        relay.release();
    }
}

const Gone = struct {
    runs: u32 = 0,
    drops: u32 = 0,

    fn hook(self: *Gone) BodyRelay.ReaderGone {
        return .{ .context = self, .run = run, .drop = drop };
    }

    fn run(context: *anyopaque) void {
        const self: *Gone = @ptrCast(@alignCast(context));
        self.runs += 1;
    }

    fn drop(context: *anyopaque) void {
        const self: *Gone = @ptrCast(@alignCast(context));
        self.drops += 1;
    }
};

test "a relay's writer hears its reader's cancel once - or its hook is dropped when the relay goes uncancelled" {
    {
        // Cancelled while the writer waits: the hook runs, once.
        var gone: Gone = .{};
        const relay = try BodyRelay.create(testing.allocator);
        relay.watchCancel(gone.hook());
        relay.cancel();
        relay.cancel();
        try testing.expectEqual(@as(u32, 1), gone.runs);
        relay.release();
        relay.release();
        try testing.expectEqual(@as(u32, 0), gone.drops);
    }
    {
        // Cancelled before the writer asked: it hears at once.
        var gone: Gone = .{};
        const relay = try BodyRelay.create(testing.allocator);
        relay.cancel();
        relay.watchCancel(gone.hook());
        try testing.expectEqual(@as(u32, 1), gone.runs);
        relay.release();
        relay.release();
        try testing.expectEqual(@as(u32, 0), gone.drops);
    }
    {
        // Read to its end, never cancelled: the hook is dropped.
        var gone: Gone = .{};
        const relay = try BodyRelay.create(testing.allocator);
        relay.watchCancel(gone.hook());
        relay.close();
        relay.release();
        relay.release();
        try testing.expectEqual(@as(u32, 0), gone.runs);
        try testing.expectEqual(@as(u32, 1), gone.drops);
    }
}

test "the blocking driver collects a relay written from another thread, chunk by chunk" {
    const relay = try BodyRelay.create(testing.allocator);
    defer relay.release();
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(r: *BodyRelay) void {
            for ([_][]const u8{ "a", "bc", "def" }) |chunk| {
                sleepMs(1);
                _ = r.write(chunk);
            }
            r.close();
            r.release();
        }
    }.run, .{relay});
    const bytes = try relay.collect(testing.allocator, 5_000);
    defer testing.allocator.free(bytes);
    thread.join();
    try testing.expectEqualStrings("abcdef", bytes);
}

test "a blocking wait no answer reaches within its limit gives up, with the owner's steps around it; the late answer is freed" {
    const call = try Call.create(testing.allocator);
    defer call.release();
    var waiting: Waiting = .{};
    call.blocking = .{ .context = &waiting, .data = 1, .before_wait = Waiting.beforeWait, .after_wait = Waiting.afterWait };
    // The service worker side answers long after the limit.
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(c: *Call) void {
            sleepMs(60);
            const late = InternalResponse.init(testing.allocator) catch unreachable;
            c.answer(.{ .response = .{ .response = late } });
            c.release();
        }
    }.run, .{call});
    try testing.expect(call.wait(10) == null);
    // The fetching side gives up on it: the late answer is freed, not kept.
    call.abandon();
    thread.join();
    try testing.expectEqual(@as(u32, 1), waiting.before);
    try testing.expectEqual(@as(u32, 1), waiting.after);
}

test "the blocking driver gives up on a body that has not ended within its limit" {
    const relay = try BodyRelay.create(testing.allocator);
    defer relay.release();
    try testing.expect(relay.write("part"));
    try testing.expectError(error.NetworkError, relay.collect(testing.allocator, 10));
    // The writer that never ended it lets go.
    relay.cancel();
    try testing.expect(!relay.write("late"));
    relay.release();
}
