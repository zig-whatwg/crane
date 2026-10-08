//! `engine.queueResolvedPromiseReaction`: HTML "queue a microtask" scoped to
//! a realm, with the protocol's exactly-once terminal contract (PR-M2,
//! tmp/analysis/fix-list.md; AGENTS.md "The engine boundary" rule 6).
//!
//! Its one caller is media's "await a stable state" (html/media/runtime.zig):
//! it hands the engine a continuation it allocated and must get back exactly
//! once - run at the agent's next microtask checkpoint, or dropped. What the
//! operation exists for, pinned here:
//! - no checkpoint runs inside it: the steps have not run when it returns,
//!   even under V8's automatic policy from a host caller at depth 0;
//! - it is a microtask like any other: FIFO against `engine.queueMicrotask`;
//! - exactly one of fulfilled and dropped runs: dropped when the realm ends
//!   with the job queued, and when the agent's queue is discarded under it
//!   (termination - V8 deletes its microtask ring buffer); never both, never
//!   twice; and nothing of it is left behind (global handles, weak records);
//! - on an ended realm the call fails, runs neither step, and the data stays
//!   the caller's.
//!
//! The values are made as the binding makes them: the realms are page realms
//! (createWindowRealm / destroyWindowRealm), the queue is the agent's own.
//! One isolate and bootstrap context for the file, never torn down; the file
//! shares tests/v8's process, so it starts the engine as any file may.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

var isolate_once: ?*ffi.Isolate = null;
var pools_ready = false;

fn agent() !*ffi.Isolate {
    if (isolate_once) |i| return i;
    try protocol.initializeEngine(.{});
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    // Already initialized is fine: the manager is per thread, not per test.
    v8.context_manager.init(std.heap.page_allocator) catch {};
    _ = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
    if (!pools_ready) {
        interfaces.process_hooks.startHooksForTest();
        runtime.SlabAllocator.init(std.heap.page_allocator);
        runtime.ArenaAllocator.init(std.heap.page_allocator);
        pools_ready = true;
    }
    isolate_once = i;
    return i;
}

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

fn windowRealm() !runtime.Context {
    const isolate = try agent();
    return protocol.createWindowRealm(&.{
        .agent = @ptrCast(isolate),
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .global_this = .new_window_proxy,
        .parent = null,
        .create_global_object = WindowHost.createGlobalObject,
        .host = null,
    });
}

fn collect() void {
    ffi.v8_Isolate_RequestGarbageCollection(isolate_once.?);
}

/// What ran, in order: 'a', 'b', 'c' for the steps of three microtasks.
const Log = struct {
    order: [8]u8 = undefined,
    len: usize = 0,

    fn push(self: *Log, mark: u8) void {
        if (self.len < self.order.len) self.order[self.len] = mark;
        self.len += 1;
    }

    fn slice(self: *const Log) []const u8 {
        return self.order[0..@min(self.len, self.order.len)];
    }
};

/// The host data of one queued microtask: counts its ends.
const Continuation = struct {
    log: ?*Log = null,
    mark: u8 = 'b',
    fulfilled: usize = 0,
    rejected: usize = 0,
    dropped: usize = 0,
    dropped_in_first_pass: bool = false,

    fn onFulfilled(data: ?*anyopaque, _: runtime.JSValue) void {
        const self: *Continuation = @ptrCast(@alignCast(data.?));
        self.fulfilled += 1;
        if (self.log) |log| log.push(self.mark);
    }

    fn onRejected(data: ?*anyopaque, _: runtime.JSValue) void {
        const self: *Continuation = @ptrCast(@alignCast(data.?));
        self.rejected += 1;
    }

    fn onDropped(data: ?*anyopaque) void {
        const self: *Continuation = @ptrCast(@alignCast(data.?));
        self.dropped += 1;
        if (ffi.v8_Debug_InFirstPassWeakCallback()) self.dropped_in_first_pass = true;
    }

    const steps: protocol.PromiseReactionSteps = .{ .fulfilled = onFulfilled, .rejected = onRejected, .dropped = onDropped };

    fn total(self: Continuation) usize {
        return self.fulfilled + self.rejected + self.dropped;
    }
};

/// A plain `engine.queueMicrotask` microtask that logs its mark.
const Plain = struct {
    log: *Log,
    mark: u8,

    fn run(data: ?*anyopaque) void {
        const self: *Plain = @ptrCast(@alignCast(data.?));
        self.log.push(self.mark);
    }
};

test "the steps run at the agent's next checkpoint, never inside the call that queues them" {
    const w = try windowRealm();
    defer protocol.destroyWindowRealm(w, .global_detached);
    var continuation: Continuation = .{};
    // From the host, outside any script: the depth at which V8's automatic
    // policy checkpoints when an API call returns.
    try protocol.queueResolvedPromiseReaction(w, &Continuation.steps, &continuation);
    try std.testing.expectEqual(@as(usize, 0), continuation.total());
    // Other host work that enters V8 and returns to depth 0 does not run it
    // either: it waits for the checkpoint.
    const promise = try protocol.createResolvedPromise(w, .undefined);
    promise.release();
    try protocol.performMicrotaskCheckpoint(w.agent.?);
    try std.testing.expectEqual(@as(usize, 1), continuation.fulfilled);
    try std.testing.expectEqual(@as(usize, 1), continuation.total());
    // Once.
    try protocol.performMicrotaskCheckpoint(w.agent.?);
    collect();
    try std.testing.expectEqual(@as(usize, 1), continuation.total());
}

test "it is a microtask like any other: first in, first out with engine.queueMicrotask" {
    const w = try windowRealm();
    defer protocol.destroyWindowRealm(w, .global_detached);
    var log: Log = .{};
    var a: Plain = .{ .log = &log, .mark = 'a' };
    var b: Continuation = .{ .log = &log, .mark = 'b' };
    var c: Plain = .{ .log = &log, .mark = 'c' };
    try protocol.queueMicrotask(w.agent.?, Plain.run, &a);
    try protocol.queueResolvedPromiseReaction(w, &Continuation.steps, &b);
    try protocol.queueMicrotask(w.agent.?, Plain.run, &c);
    try std.testing.expectEqualStrings("", log.slice());
    try protocol.performMicrotaskCheckpoint(w.agent.?);
    try std.testing.expectEqualStrings("abc", log.slice());
    try std.testing.expectEqual(@as(usize, 1), b.total());
}

test "queued when its realm ends: dropped exactly once, and a later checkpoint runs nothing" {
    const w = try windowRealm();
    var continuation: Continuation = .{};
    try protocol.queueResolvedPromiseReaction(w, &Continuation.steps, &continuation);
    protocol.destroyWindowRealm(w, .global_detached);
    try std.testing.expectEqual(@as(usize, 1), continuation.dropped);
    try std.testing.expectEqual(@as(usize, 1), continuation.total());
    try std.testing.expect(!continuation.dropped_in_first_pass);

    // The job may still be in the agent's queue: it finds nothing to run.
    const isolate = try agent();
    ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
    collect();
    try std.testing.expectEqual(@as(usize, 1), continuation.total());
}

/// A microtask that aborts the agent's script. The abort is seen at the next
/// interrupt check in JavaScript - a native microtask and an API reaction
/// function make none - so `queueAbortingCheckpoint` follows it with a
/// script job: the checkpoint is terminated there, and V8 deletes the rest of
/// the queue (microtask-queue.cc, RunMicrotasks: `delete[] ring_buffer_` when
/// execution is terminating) - what a worker's termination does to it.
const Abort = struct {
    agent: *protocol.Agent,
    ran: bool = false,

    fn run(data: ?*anyopaque) void {
        const self: *Abort = @ptrCast(@alignCast(data.?));
        self.ran = true;
        protocol.abortRunningScript(self.agent);
    }
};

/// Queue, in order: `abort`, then a script job that loops (its back edges
/// check for interrupts). The script runs with checkpoints suppressed, so its
/// job only waits in the queue.
fn queueAbortingCheckpoint(w: runtime.Context, abort: *Abort) !void {
    try protocol.queueMicrotask(w.agent.?, Abort.run, abort);
    const Queue = struct {
        realm: runtime.Context,
        failed: bool = false,
        fn run(raw: ?*anyopaque) callconv(.c) void {
            const self: *@This() = @ptrCast(@alignCast(raw.?));
            const Ignored = struct {
                fn report(_: ?*anyopaque, _: *const protocol.ErrorInfo) void {}
            };
            protocol.runClassicScript(self.realm, .{ .utf8 = "Promise.resolve().then(() => { for (let i = 0; i < 1e6; i++) {} });" }, "", null, .{ .report = Ignored.report, .host = null }) catch {
                self.failed = true;
            };
        }
    };
    var queue: Queue = .{ .realm = w };
    ffi.v8_RunWithMicrotasksSuppressed(@ptrCast(@alignCast(w.agent.?)), Queue.run, &queue);
    if (queue.failed) return error.ScriptFailed;
}

test "queued when the agent's queue is discarded under it: dropped exactly once, never run" {
    const w = try windowRealm();
    var abort: Abort = .{ .agent = w.agent.? };
    var continuation: Continuation = .{};
    try queueAbortingCheckpoint(w, &abort);
    try protocol.queueResolvedPromiseReaction(w, &Continuation.steps, &continuation);
    protocol.performMicrotaskCheckpoint(w.agent.?) catch {};
    protocol.resumeScripts(w.agent.?);
    try std.testing.expect(abort.ran);
    try std.testing.expectEqual(@as(usize, 0), continuation.fulfilled);

    // Its job is gone with the queue. Whichever comes first - the collector
    // taking the orphaned reaction, or the realm's end - drops it, once.
    collect();
    protocol.destroyWindowRealm(w, .global_detached);
    collect();
    try std.testing.expectEqual(@as(usize, 0), continuation.fulfilled);
    try std.testing.expectEqual(@as(usize, 1), continuation.dropped);
    try std.testing.expectEqual(@as(usize, 1), continuation.total());
    try std.testing.expect(!continuation.dropped_in_first_pass);
}

test "on a realm that has ended it fails, runs neither step, and the data stays the caller's" {
    const w = try windowRealm();
    protocol.destroyWindowRealm(w, .global_detached);
    var continuation: Continuation = .{};
    try std.testing.expect(std.meta.isError(protocol.queueResolvedPromiseReaction(w, &Continuation.steps, &continuation)));
    const isolate = try agent();
    ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
    collect();
    try std.testing.expectEqual(@as(usize, 0), continuation.total());
}

test "run, dropped by the realm's end, or dropped with the queue: no global handle or weak record left" {
    const isolate = try agent();
    const round = struct {
        fn run(ends: *[3]Continuation) !void {
            const w = try windowRealm();
            // Run.
            try protocol.queueResolvedPromiseReaction(w, &Continuation.steps, &ends[0]);
            try protocol.performMicrotaskCheckpoint(w.agent.?);
            // Discarded with the queue.
            var abort: Abort = .{ .agent = w.agent.? };
            try queueAbortingCheckpoint(w, &abort);
            try protocol.queueResolvedPromiseReaction(w, &Continuation.steps, &ends[1]);
            protocol.performMicrotaskCheckpoint(w.agent.?) catch {};
            protocol.resumeScripts(w.agent.?);
            // Queued when the realm ends.
            try protocol.queueResolvedPromiseReaction(w, &Continuation.steps, &ends[2]);
            protocol.destroyWindowRealm(w, .global_detached);
        }
    }.run;
    var ends: [3]Continuation = .{ .{}, .{}, .{} };
    try round(&ends);
    collect();
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const records_before = ffi.v8_Debug_LiveWeakCallbackData();
    const rounds = 16;
    for (0..rounds) |_| try round(&ends);
    collect();
    const after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const records_after = ffi.v8_Debug_LiveWeakCallbackData();
    for (ends) |end| try std.testing.expectEqual(@as(usize, rounds + 1), end.total());
    try std.testing.expectEqual(@as(usize, rounds + 1), ends[0].fulfilled);
    try std.testing.expectEqual(@as(usize, rounds + 1), ends[1].dropped);
    try std.testing.expectEqual(@as(usize, rounds + 1), ends[2].dropped);
    if (after > before or records_after > records_before) {
        std.debug.print("global handles {d} -> {d} bytes, weak records {d} -> {d}, over {d} rounds\n", .{ before, after, records_before, records_after, rounds });
        return error.HandlesLeaked;
    }
}
