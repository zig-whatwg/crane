//! A Browser's storage sequence (lane prof2): the one thread that writes
//! every profile store of a Browser with a profile directory - localStorage's
//! commit batches, the cookie store's, the HTTP cache's disk level,
//! IndexedDB's transaction commits and database deletions - so the thread
//! that made a change (the window's event loop, a worker's) never waits on
//! disk (kit/sqlite commits with synchronous=FULL: an fsync each).
//!
//! Chromium (BSD; its design reproduced, not its code) never writes a
//! profile store on the thread that changed it: DOM storage commits on its
//! database's sequence (components/services/storage/dom_storage/
//! storage_area_impl.cc, StorageAreaImpl::CommitChanges hands the batch to
//! the AsyncDomStorageDatabase, whose DomStorageDatabase runs on a blocking
//! task runner), the cookie store on SQLitePersistentCookieStore's
//! background runner (net/extras/sqlite/sqlite_persistent_cookie_store.cc,
//! Backend::Commit), the disk cache on its own sequence (net/disk_cache/
//! simple/), IndexedDB on its backing store's (content/browser/indexed_db/:
//! the transaction's commit runs there and its complete event is posted back
//! to the renderer after it). Each is a base::SequencedTaskRunner posted with
//! TaskShutdownBehavior::BLOCK_SHUTDOWN, so what was posted is written before
//! the browser exits. Crane gives each Browser one sequence for all of them:
//! one thread, its jobs run one at a time in the order posted.
//!
//! - Made only for a Browser with a profile directory (src/browser/
//!   profile_stores.zig `attach`): a Browser with none has no sequence and no
//!   thread, and its stores (kit/memory_store) are written inline, as before.
//! - A job is intrusive: its owner embeds a `Job` in what it hands over, so a
//!   post allocates nothing and cannot fail. The sequence takes the job: it
//!   runs it on its thread, or - once stopped - drops it on the poster's
//!   thread. A job owns everything it writes (a copy made when it was
//!   posted): the thread that posted it goes on changing its own state.
//! - `barrier` waits until every job posted before it has run: what a read
//!   that must see those writes does first. Each store says which of its
//!   reads do, and why Chrome's equivalent waits too.
//! - `stop` is the Browser's end (profile_stores.flush): after every store
//!   handed over its last batch, and before the platform state ends, the
//!   thread runs what is queued and is joined - BLOCK_SHUTDOWN's drain.
//!
//! THREADS. `post` and `barrier` from any thread but the sequence's own (a
//! job never waits on its own sequence); `start` and `stop` from the
//! Browser's thread. A job takes no lock that a thread may hold while it waits
//! on this sequence - IndexedDB's server lock, the cookie jar's, the
//! UserAgentStorage's: `barrier` is called under those, so a job that took
//! one would deadlock with it.

const std = @import("std");
const platform = @import("platform");

fn lock(mutex: *std.Io.Mutex) void {
    std.Io.Threaded.mutexLockUncancelable(mutex);
}

fn unlock(mutex: *std.Io.Mutex) void {
    std.Io.Threaded.mutexUnlock(mutex);
}

/// The futex calls' `Io`: a futex wait and wake are plain system calls on an
/// address (runtime.task_sink's choice; the process's own `Io` is reserved
/// for its filesystem bridge).
fn futexIo() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}

/// One piece of work for the sequence, embedded in what its owner hands over
/// (`@fieldParentPtr` finds it again).
pub const Job = struct {
    /// On the sequence's thread. The job is its own from here: free it.
    run: *const fn (job: *Job) void,
    /// It will never run - posted to a sequence that is stopped, or never
    /// started: free it. On the poster's thread.
    drop: *const fn (job: *Job) void,
    /// The queue's link; the sequence's while the job is queued.
    next: ?*Job = null,
};

/// A one-shot flag: a job sets it when its work is done, and another thread
/// waits for it or asks (runtime.task_sink.Signal's shape - storage cannot
/// import runtime). Set once; never reset. `set` touches nothing of it after
/// the store but the futex wake, which only names the address.
pub const Done = struct {
    state: std.atomic.Value(u32) = .init(0),

    pub fn set(self: *Done) void {
        self.state.store(1, .release);
        futexIo().futexWake(u32, &self.state.raw, std.math.maxInt(u32));
    }

    pub fn isSet(self: *const Done) bool {
        return self.state.load(.acquire) != 0;
    }

    /// Block until `set`. Spurious wakes are waited out.
    pub fn wait(self: *Done) void {
        while (self.state.load(.acquire) == 0) {
            futexIo().futexWaitTimeout(u32, &self.state.raw, 0, .none) catch {};
        }
    }
};

/// The Browser's storage sequence: a BrowserScope supplement, started by
/// profile_stores.attach for a Browser with a profile directory.
pub const StorageSequence = struct {
    /// Guards the queue, the counts and the state. Never held across a job.
    mutex: std.Io.Mutex = .init,
    head: ?*Job = null,
    tail: ?*Job = null,
    /// Jobs queued since the start, and jobs run since: what `barrier`
    /// compares.
    posted: u64 = 0,
    finished: u64 = 0,
    state: State = .idle,
    /// Bumped by every post and by `stop`: the word the thread waits on.
    work: std.atomic.Value(u32) = .init(0),
    /// Bumped as each job finishes: the word `barrier` waits on.
    progress: std.atomic.Value(u32) = .init(0),
    thread: ?platform.Thread = null,
    /// The sequence thread's id (0 before it started): `onSequence`.
    thread_id: std.atomic.Value(std.Thread.Id) = .init(0),

    const State = enum { idle, running, stopping, stopped };

    /// A BrowserScope supplement's init: no thread yet (`start`).
    pub fn init(allocator: std.mem.Allocator) StorageSequence {
        _ = allocator;
        return .{};
    }

    /// With the Browser's scope. A Browser's end stopped it already
    /// (profile_stores.flush); a Browser whose start failed after its
    /// profile was attached stops it here - supplements end in the reverse
    /// of the order they were made, and the stores' owners and the platform
    /// state were made first (profile_stores.attach), so they still live.
    pub fn deinit(self: *StorageSequence) void {
        self.stop();
    }

    /// Start the thread (profile_stores.attach, Browser.init's). QoS
    /// user-initiated: an IndexedDB complete event and a localStorage first
    /// read wait for what it runs.
    pub fn start(self: *StorageSequence) platform.Error!void {
        lock(&self.mutex);
        std.debug.assert(self.state == .idle);
        self.state = .running;
        unlock(&self.mutex);
        self.thread = platform.spawnThread(.{ .name = .from("crane-storage"), .qos = .user_initiated }, threadMain, self) catch |err| {
            lock(&self.mutex);
            self.state = .idle;
            unlock(&self.mutex);
            return err;
        };
    }

    /// Whether the thread runs what is posted.
    pub fn isRunning(self: *StorageSequence) bool {
        lock(&self.mutex);
        defer unlock(&self.mutex);
        return self.state == .running;
    }

    /// Whether the calling thread is the sequence's.
    pub fn onSequence(self: *const StorageSequence) bool {
        const id = self.thread_id.load(.acquire);
        return id != 0 and id == std.Thread.getCurrentId();
    }

    /// Queue `job`, last. The sequence takes it whatever happens: once the
    /// sequence is stopped (or was never started), its `drop` runs here, on
    /// the caller's thread.
    pub fn post(self: *StorageSequence, job: *Job) void {
        job.next = null;
        lock(&self.mutex);
        if (self.state != .running) {
            unlock(&self.mutex);
            job.drop(job);
            return;
        }
        if (self.tail) |tail| tail.next = job else self.head = job;
        self.tail = job;
        self.posted += 1;
        unlock(&self.mutex);
        _ = self.work.fetchAdd(1, .release);
        futexIo().futexWake(u32, &self.work.raw, 1);
    }

    /// Wait until every job posted before this call has run. At once when
    /// none is pending. Never on the sequence's own thread.
    pub fn barrier(self: *StorageSequence) void {
        std.debug.assert(!self.onSequence());
        lock(&self.mutex);
        const target = self.posted;
        unlock(&self.mutex);
        while (true) {
            // The word first: a job that finishes after the look below has
            // bumped it, and the wait returns at once.
            const seen = self.progress.load(.acquire);
            lock(&self.mutex);
            const reached = self.finished >= target;
            unlock(&self.mutex);
            if (reached) return;
            futexIo().futexWaitTimeout(u32, &self.progress.raw, seen, .none) catch {};
        }
    }

    /// The Browser's end: what is queued runs, then the thread is joined;
    /// a post from here on is dropped. Stopping twice, or a sequence never
    /// started, does nothing more. Never on the sequence's own thread.
    pub fn stop(self: *StorageSequence) void {
        std.debug.assert(!self.onSequence());
        lock(&self.mutex);
        switch (self.state) {
            .running => self.state = .stopping,
            .idle => {
                self.state = .stopped;
                unlock(&self.mutex);
                return;
            },
            .stopping, .stopped => {
                unlock(&self.mutex);
                return;
            },
        }
        unlock(&self.mutex);
        _ = self.work.fetchAdd(1, .release);
        futexIo().futexWake(u32, &self.work.raw, 1);
        platform.joinThread(self.thread.?);
        self.thread = null;
        lock(&self.mutex);
        self.state = .stopped;
        unlock(&self.mutex);
    }

    /// Under the lock: the queue's first job, taken off it.
    fn pop(self: *StorageSequence) ?*Job {
        const job = self.head orelse return null;
        self.head = job.next;
        if (self.head == null) self.tail = null;
        job.next = null;
        return job;
    }

    fn finishOne(self: *StorageSequence) void {
        lock(&self.mutex);
        self.finished += 1;
        unlock(&self.mutex);
        _ = self.progress.fetchAdd(1, .release);
        futexIo().futexWake(u32, &self.progress.raw, std.math.maxInt(u32));
    }

    /// The thread: each job in turn, in the order posted; once stopping and
    /// the queue is empty, the end.
    fn threadMain(context: ?*anyopaque) callconv(.c) void {
        const self: *StorageSequence = @ptrCast(@alignCast(context.?));
        self.thread_id.store(std.Thread.getCurrentId(), .release);
        while (true) {
            // The word before the look: a post after it has bumped it.
            const seen = self.work.load(.acquire);
            lock(&self.mutex);
            const job = self.pop();
            const stopping = self.state == .stopping;
            unlock(&self.mutex);
            if (job) |next| {
                // The job is its own once it runs: never touched after.
                next.run(next);
                self.finishOne();
                continue;
            }
            if (stopping) return;
            futexIo().futexWaitTimeout(u32, &self.work.raw, seen, .none) catch {};
        }
    }
};

// ==================================================================== tests

const testing = std.testing;

/// A test job: records its index and the thread it ran on, optionally
/// waiting for `gate` first.
const Recorded = struct {
    job: Job = .{ .run = run, .drop = dropped },
    index: usize,
    log: *Log,
    gate: ?*Done = null,

    const Log = struct {
        mutex: std.Io.Mutex = .init,
        ran: std.ArrayListUnmanaged(usize) = .empty,
        threads: std.ArrayListUnmanaged(std.Thread.Id) = .empty,
        drops: usize = 0,

        fn deinit(self: *Log) void {
            self.ran.deinit(testing.allocator);
            self.threads.deinit(testing.allocator);
        }
    };

    fn run(job: *Job) void {
        const self: *Recorded = @fieldParentPtr("job", job);
        if (self.gate) |gate| gate.wait();
        lock(&self.log.mutex);
        defer unlock(&self.log.mutex);
        self.log.ran.append(testing.allocator, self.index) catch {};
        self.log.threads.append(testing.allocator, std.Thread.getCurrentId()) catch {};
    }

    fn dropped(job: *Job) void {
        const self: *Recorded = @fieldParentPtr("job", job);
        lock(&self.log.mutex);
        defer unlock(&self.log.mutex);
        self.log.drops += 1;
    }
};

test "jobs run one at a time on the sequence's thread, in the order they were posted" {
    var sequence = StorageSequence.init(testing.allocator);
    defer sequence.deinit();
    try sequence.start();
    var log: Recorded.Log = .{};
    defer log.deinit();
    var jobs: [64]Recorded = undefined;
    for (&jobs, 0..) |*job, i| {
        job.* = .{ .index = i, .log = &log };
        sequence.post(&job.job);
    }
    sequence.barrier();
    try testing.expectEqual(jobs.len, log.ran.items.len);
    for (log.ran.items, 0..) |index, i| try testing.expectEqual(i, index);
    // One thread, and not this one.
    for (log.threads.items) |id| {
        try testing.expectEqual(log.threads.items[0], id);
        try testing.expect(id != std.Thread.getCurrentId());
    }
    try testing.expectEqual(@as(usize, 0), log.drops);
}

test "a barrier waits for the jobs posted before it, and only those" {
    var sequence = StorageSequence.init(testing.allocator);
    defer sequence.deinit();
    try sequence.start();
    var log: Recorded.Log = .{};
    defer log.deinit();
    var gate: Done = .{};
    var blocked: Recorded = .{ .index = 0, .log = &log, .gate = &gate };
    sequence.post(&blocked.job);

    // A barrier on another thread waits for the blocked job.
    const Waiter = struct {
        sequence: *StorageSequence,
        passed: Done = .{},
        fn main(context: ?*anyopaque) callconv(.c) void {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            self.sequence.barrier();
            self.passed.set();
        }
    };
    var waiter: Waiter = .{ .sequence = &sequence };
    const thread = try platform.spawnThread(.{ .name = .from("barrier-test") }, Waiter.main, &waiter);
    std.Io.sleep(testing.io, .fromMilliseconds(50), .awake) catch {};
    try testing.expect(!waiter.passed.isSet());
    gate.set();
    platform.joinThread(thread);
    try testing.expect(waiter.passed.isSet());
    try testing.expectEqual(@as(usize, 1), log.ran.items.len);
}

test "stop runs what is queued, then drops what is posted" {
    var sequence = StorageSequence.init(testing.allocator);
    defer sequence.deinit();
    try sequence.start();
    var log: Recorded.Log = .{};
    defer log.deinit();
    var gate: Done = .{};
    var first: Recorded = .{ .index = 0, .log = &log, .gate = &gate };
    var queued: [8]Recorded = undefined;
    sequence.post(&first.job);
    for (&queued, 1..) |*job, i| {
        job.* = .{ .index = i, .log = &log };
        sequence.post(&job.job);
    }
    // Everything above is still queued behind the gate when the stop
    // begins; the stop waits for all of it (BLOCK_SHUTDOWN).
    gate.set();
    sequence.stop();
    try testing.expectEqual(@as(usize, 1 + queued.len), log.ran.items.len);
    try testing.expect(!sequence.isRunning());
    var late: Recorded = .{ .index = 99, .log = &log };
    sequence.post(&late.job);
    try testing.expectEqual(@as(usize, 1), log.drops);
    try testing.expectEqual(@as(usize, 1 + queued.len), log.ran.items.len);
    // A barrier with nothing pending returns at once.
    sequence.barrier();
}

test "a sequence never started runs nothing: a post is dropped, a barrier returns" {
    var sequence = StorageSequence.init(testing.allocator);
    defer sequence.deinit();
    var log: Recorded.Log = .{};
    defer log.deinit();
    var job: Recorded = .{ .index = 0, .log = &log };
    sequence.post(&job.job);
    try testing.expectEqual(@as(usize, 1), log.drops);
    try testing.expectEqual(@as(usize, 0), log.ran.items.len);
    sequence.barrier();
    try testing.expect(sequence.thread == null);
}
