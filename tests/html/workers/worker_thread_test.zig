//! A worker on a thread of its own (html.WorkerThread, WorkerLink,
//! WorkerEventLoop): the thread makes its agent and realm, runs what its
//! owner posts as tasks of its own loop, ends - and its owner, on another
//! thread, can end it while its script is running.
//!
//! The host here is a test's: it makes a real agent and worker realm on the
//! worker's thread and runs script in it, as the worker host does. tests/html
//! is one executable shared by every file in it: nothing here assumes it
//! starts the engine or owns this thread's state, and every thread a test
//! starts is joined before it returns.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const html = @import("html");
const WorkerLink = html.WorkerLink;
const WorkerThread = html.WorkerThread;
const WorkerRegistry = html.WorkerRegistry;
const TaskSink = runtime.TaskSink;

const allocator = std.heap.page_allocator;

/// The process-wide pieces a worker's platform objects need, as crane.Process
/// starts them - unless a file before this one did.
fn startProcess() void {
    if (runtime.SlabAllocator.tryGet()) |_| {} else |_| runtime.initializeRuntime(allocator);
    @import("interfaces").process_hooks.startHooksForTest();
}

fn ignoreReport(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}
const reporter: engine.Reporter = .{ .report = ignoreReport };

/// An owned timer's payload: whether the loop's end dropped it.
const TimerPayload = struct {
    fired: std.atomic.Value(bool) = .init(false),
    dropped: std.atomic.Value(bool) = .init(false),

    fn fire(data: ?*anyopaque) void {
        const self: *TimerPayload = @ptrCast(@alignCast(data.?));
        self.fired.store(true, .release);
    }

    fn drop(data: ?*anyopaque) void {
        const self: *TimerPayload = @ptrCast(@alignCast(data.?));
        self.dropped.store(true, .release);
    }
};

/// The worker host's part, as a test plays it.
const TestHost = struct {
    /// A script the worker's first task runs, if any.
    script: ?[]const u8 = null,
    /// Close the worker from its own start (close() before the loop turns).
    close_at_start: bool = false,
    /// A timer to arm that will never fire.
    owned_timer: ?*TimerPayload = null,
    /// Queue a host microtask, then terminate the worker from its own start:
    /// the termination is pending, so the agent's end drops the microtask.
    microtask_then_terminate: bool = false,
    microtask_ran: std.atomic.Value(bool) = .init(false),

    agent: ?*engine.Agent = null,
    realm: ?runtime.Context = null,
    thread_id: std.Thread.Id = 0,
    started: std.atomic.Value(bool) = .init(false),
    script_returned: std.atomic.Value(bool) = .init(false),
    realm_ended: std.atomic.Value(bool) = .init(false),
    freed: std.atomic.Value(bool) = .init(false),
    /// What `read` found, posted back by a task (owned by `allocator`).
    answer: ?[]u8 = null,

    fn host(self: *TestHost) WorkerThread.Host {
        return .{ .data = self, .start = start, .end_realm = endRealm, .free = free };
    }

    fn start(data: ?*anyopaque, thread: *WorkerThread) bool {
        const self: *TestHost = @ptrCast(@alignCast(data.?));
        self.thread_id = std.Thread.getCurrentId();
        const agent = engine.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &.{}, .allocator = allocator }) catch return false;
        thread.loop.agent = agent;
        self.agent = agent;
        if (!thread.link.publishAgent(agent)) return false;
        const made = engine.createWorkerRealm(agent, &.{
            .url = "http://web-platform.test:8000/workers/w.js",
            .timer = thread.loop.timerInterface(),
            .event_loop = thread.loop.eventLoop(),
            .allocator = allocator,
        }) catch return false;
        self.realm = made.realm;
        if (self.owned_timer) |payload| {
            _ = thread.loop.timerInterface().setTimeoutOwned(60_000, TimerPayload.fire, payload, TimerPayload.drop);
        }
        if (self.script != null) thread.loop.eventLoop().queueTask(.{ .callback = runScript, .context = self });
        if (self.close_at_start) _ = thread.link.requestClose();
        if (self.microtask_then_terminate) {
            thread.loop.eventLoop().queueMicrotask(.{ .callback = markMicrotaskRan, .context = self });
            _ = thread.link.terminate();
        }
        return true;
    }

    fn markMicrotaskRan(data: ?*anyopaque) void {
        const self: *TestHost = @ptrCast(@alignCast(data.?));
        self.microtask_ran.store(true, .release);
    }

    fn runScript(data: ?*anyopaque) void {
        const self: *TestHost = @ptrCast(@alignCast(data.?));
        self.started.store(true, .release);
        engine.runClassicScript(self.realm.?, .{ .utf8 = self.script.? }, "w.js", null, reporter) catch {};
        self.script_returned.store(true, .release);
    }

    fn endRealm(data: ?*anyopaque, _: *WorkerThread) void {
        const self: *TestHost = @ptrCast(@alignCast(data.?));
        if (self.realm) |realm| engine.destroyWorkerRealm(realm, null, null);
        self.realm = null;
        self.realm_ended.store(true, .release);
    }

    fn free(data: ?*anyopaque) void {
        const self: *TestHost = @ptrCast(@alignCast(data.?));
        self.freed.store(true, .release);
    }
};

/// The owner's part: hears the worker's end on the owner's loop, and joins.
const TestOwner = struct {
    ended: std.atomic.Value(bool) = .init(false),
    dropped: std.atomic.Value(bool) = .init(false),
    thread_id: std.Thread.Id = 0,

    fn owner(self: *TestOwner) WorkerThread.Owner {
        return .{ .data = self, .ended = onEnded, .drop = onDrop };
    }

    fn onEnded(data: ?*anyopaque, link: *WorkerLink) void {
        const self: *TestOwner = @ptrCast(@alignCast(data.?));
        self.thread_id = std.Thread.getCurrentId();
        link.join();
        self.ended.store(true, .release);
    }

    fn onDrop(data: ?*anyopaque, _: *WorkerLink) void {
        const self: *TestOwner = @ptrCast(@alignCast(data.?));
        self.dropped.store(true, .release);
    }
};

/// The owner's loop, as a test spins it: run what `sink` receives until
/// `done` holds or `ms` pass. Whether it held.
fn spinUntil(sink: *TaskSink, done: *const std.atomic.Value(bool), ms: u64) bool {
    var taken: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
    defer taken.deinit(allocator);
    var waited: u64 = 0;
    while (!done.load(.acquire) and waited < ms) : (waited += 1) {
        sink.takeAll(&taken, allocator) catch {};
        for (taken.items) |task| task.run(task.data);
        taken.clearRetainingCapacity();
        if (done.load(.acquire)) break;
        sink.waitForWork(1 * std.time.ns_per_ms);
    }
    return done.load(.acquire);
}

/// Wait (without running anything) until `flag` holds or `ms` pass.
fn waitFor(flag: *const std.atomic.Value(bool), ms: u64) bool {
    var waited: u64 = 0;
    while (!flag.load(.acquire) and waited < ms) : (waited += 1) @import("clock").sleep(1 * std.time.ns_per_ms);
    return flag.load(.acquire);
}

test "the owner's terminate ends a script spinning on the worker's thread, and the worker ends" {
    startProcess();
    const owner_sink = try TaskSink.create(allocator);
    defer owner_sink.release();
    const link = try WorkerLink.create(allocator, owner_sink);
    defer link.release();

    var host: TestHost = .{ .script = "while (true) {}" };
    var owner: TestOwner = .{};
    try WorkerThread.spawn(allocator, link, host.host(), owner.owner(), null);
    // The owner's loop does not wait for nothing: a running worker may post.
    try testing.expectEqual(@as(u32, 1), owner_sink.sourceCount());

    try testing.expect(waitFor(&host.started, 10_000));
    // Spinning: the owner's thread is free (this test runs on it).
    @import("clock").sleep(20 * std.time.ns_per_ms);
    try testing.expect(!host.script_returned.load(.acquire));
    try testing.expect(link.terminate());

    try testing.expect(spinUntil(owner_sink, &owner.ended, 10_000));
    try testing.expect(host.script_returned.load(.acquire));
    try testing.expect(host.realm_ended.load(.acquire));
    try testing.expect(host.freed.load(.acquire));
    try testing.expectEqual(html.worker_link.State.ended, link.getState());
    try testing.expect(!link.hasThread());
    try testing.expect(host.thread_id != owner.thread_id);
    try testing.expectEqual(@as(u32, 0), owner_sink.sourceCount());
}

test "terminate wakes a worker blocked in Atomics.wait" {
    startProcess();
    const owner_sink = try TaskSink.create(allocator);
    defer owner_sink.release();
    const link = try WorkerLink.create(allocator, owner_sink);
    defer link.release();

    var host: TestHost = .{ .script = "Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0);" };
    var owner: TestOwner = .{};
    try WorkerThread.spawn(allocator, link, host.host(), owner.owner(), null);
    try testing.expect(waitFor(&host.started, 10_000));
    @import("clock").sleep(20 * std.time.ns_per_ms);
    try testing.expect(!host.script_returned.load(.acquire));
    _ = link.terminate();
    try testing.expect(spinUntil(owner_sink, &owner.ended, 10_000));
    try testing.expect(host.script_returned.load(.acquire));
}

/// A task the owner posts to the worker: it runs script in the worker's
/// realm, reads a global back, and posts the answer to the owner.
const Probe = struct {
    host: *TestHost,
    owner_sink: *TaskSink,
    thread_id: std.Thread.Id = 0,
    answered: std.atomic.Value(bool) = .init(false),
    answer: [64]u8 = undefined,
    answer_len: usize = 0,

    fn post(self: *Probe, link: *WorkerLink) bool {
        return link.worker_sink.post(.{ .run = run, .drop = drop, .data = self });
    }

    fn run(data: ?*anyopaque) void {
        const self: *Probe = @ptrCast(@alignCast(data.?));
        self.thread_id = std.Thread.getCurrentId();
        const realm = self.host.realm orelse return;
        // A promise reaction queued by this task runs in the checkpoint that
        // follows it, before the next task.
        engine.runClassicScript(realm, .{ .utf8 = "globalThis.order = ['task']; Promise.resolve().then(() => order.push('micro'));" }, "probe.js", null, reporter) catch {};
        const reader = std.heap.page_allocator.create(Reader) catch return;
        reader.* = .{ .probe = self };
        realm.getOptionalEventLoop().?.queueTask(.{ .callback = Reader.run, .context = reader, .drop = Reader.drop });
    }

    fn drop(_: ?*anyopaque) void {}

    const Reader = struct {
        probe: *Probe,

        fn run(data: ?*anyopaque) void {
            const self: *Reader = @ptrCast(@alignCast(data.?));
            defer std.heap.page_allocator.destroy(self);
            const probe = self.probe;
            const realm = probe.host.realm orelse return;
            const text = engine.evaluateClassicScriptToString(realm, .{ .utf8 = "order.join(',')" }, "read.js", null, allocator, reporter) catch return;
            defer allocator.free(text);
            probe.answer_len = @min(text.len, probe.answer.len);
            @memcpy(probe.answer[0..probe.answer_len], text[0..probe.answer_len]);
            _ = probe.owner_sink.post(.{ .run = onAnswered, .drop = onAnswered, .data = probe });
        }

        fn drop(data: ?*anyopaque) void {
            const self: *Reader = @ptrCast(@alignCast(data.?));
            std.heap.page_allocator.destroy(self);
        }
    };

    fn onAnswered(data: ?*anyopaque) void {
        const self: *Probe = @ptrCast(@alignCast(data.?));
        self.answered.store(true, .release);
    }
};

test "a task the owner posts runs on the worker's thread, with its microtasks after it" {
    startProcess();
    const owner_sink = try TaskSink.create(allocator);
    defer owner_sink.release();
    const link = try WorkerLink.create(allocator, owner_sink);
    defer link.release();

    var host: TestHost = .{};
    var owner: TestOwner = .{};
    // Posted before the thread exists: it waits in the worker's sink.
    var probe: Probe = .{ .host = &host, .owner_sink = owner_sink };
    try testing.expect(probe.post(link));
    try WorkerThread.spawn(allocator, link, host.host(), owner.owner(), null);
    try testing.expect(spinUntil(owner_sink, &probe.answered, 10_000));
    try testing.expectEqualStrings("task,micro", probe.answer[0..probe.answer_len]);
    try testing.expectEqual(host.thread_id, probe.thread_id);

    // close() from the worker's side: the loop sees the flag and ends.
    _ = link.requestClose();
    link.wake();
    try testing.expect(spinUntil(owner_sink, &owner.ended, 10_000));
}

test "a worker closed before its loop turns drops its unfired owned timer, and posts after its end are dropped" {
    startProcess();
    const owner_sink = try TaskSink.create(allocator);
    defer owner_sink.release();
    const link = try WorkerLink.create(allocator, owner_sink);
    defer link.release();

    var payload: TimerPayload = .{};
    var host: TestHost = .{ .close_at_start = true, .owned_timer = &payload };
    var owner: TestOwner = .{};
    try WorkerThread.spawn(allocator, link, host.host(), owner.owner(), null);
    try testing.expect(spinUntil(owner_sink, &owner.ended, 10_000));
    try testing.expect(payload.dropped.load(.acquire));
    try testing.expect(!payload.fired.load(.acquire));
    // The worker's sink is closed: a late post is dropped at once.
    var late: Probe = .{ .host = &host, .owner_sink = owner_sink };
    try testing.expect(!late.post(link));
}

test "the Browser's end terminates every worker and joins every thread" {
    startProcess();
    var scope = runtime.BrowserScope.init(allocator);
    defer scope.deinit();
    const registry = try scope.of(WorkerRegistry);
    const owner_sink = try TaskSink.create(allocator);

    var hosts = [_]TestHost{ .{ .script = "while (true) {}" }, .{ .script = "for (;;) {}" } };
    var owners = [_]TestOwner{ .{}, .{} };
    var links: [2]*WorkerLink = undefined;
    // One after the other: an engine nobody started registers its teardown
    // handlers with the first agent made, and this file does not start it.
    for (&links, &hosts, &owners) |*link, *host, *owner| {
        link.* = try WorkerLink.create(allocator, owner_sink);
        try registry.register(link.*);
        try WorkerThread.spawn(allocator, link.*, host.host(), owner.owner(), registry);
        try testing.expect(waitFor(&host.started, 10_000));
    }

    registry.terminateAll();
    registry.joinAll();
    for (links) |link| {
        try testing.expect(!link.hasThread());
        try testing.expectEqual(html.worker_link.State.ended, link.getState());
    }
    // No worker starts once the Browser is ending.
    const late = try WorkerLink.create(allocator, owner_sink);
    try testing.expectError(error.Closed, registry.register(late));
    late.release();

    // The owner's loop never turns again: its end drops the workers' ends.
    owner_sink.close();
    for (&owners) |*owner| try testing.expect(owner.dropped.load(.acquire));
    owner_sink.release();
    for (links) |link| {
        registry.unregister(link);
        link.release();
    }
}

test "a microtask a terminated worker's agent never ran is freed with the worker's loop" {
    if (comptime engine.capabilities.script_abort == .unsupported) return error.SkipZigTest;
    startProcess();
    // The loop's own allocations, counted: what it leaks shows here.
    var counted: std.heap.DebugAllocator(.{}) = .init;
    const loop_allocator = counted.allocator();
    {
        const owner_sink = try TaskSink.create(loop_allocator);
        defer owner_sink.release();
        const link = try WorkerLink.create(loop_allocator, owner_sink);
        defer link.release();
        var host: TestHost = .{ .microtask_then_terminate = true };
        var owner: TestOwner = .{};
        try WorkerThread.spawn(loop_allocator, link, host.host(), owner.owner(), null);
        try testing.expect(spinUntil(owner_sink, &owner.ended, 10_000));
        try testing.expect(!host.microtask_ran.load(.acquire));
    }
    try testing.expect(counted.deinit() == .ok);
}
