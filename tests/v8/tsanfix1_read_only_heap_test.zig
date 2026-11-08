//! One read-only heap per process (lane tsanfix1, M1 of
//! docs/testing/test-variant-findings-2026-11-02.tsv).
//!
//! With pointer compression in one shared cage, V8 13.1 keeps ONE read-only
//! heap for every isolate of the process: the first live isolate makes it
//! from its snapshot's read-only part, every later one reuses it, and it goes
//! with the last (src/heap/read-only-heap.cc ReadOnlyHeap::SetUp and
//! TearDown). V8's DEBUG build CHECKs that every isolate restores the same
//! read-only snapshot (src/heap/read-only-spaces.cc:76-104,
//! ReadOnlyArtifacts::VerifyChecksum); the release build Crane links does
//! not check, and an isolate restored from Crane's blob while the heap came
//! from V8's built-in snapshot crashed in Isolate::Initialize
//! (SharedHeapDeserializer::DeserializeStringTable, SIGSEGV 0x10488). The
//! adapter now refuses that restore and makes the agent without the snapshot
//! (v8_wrapper.cpp g_read_only_heap), and engine.agentRestoredFromSnapshot
//! answers what the agent is.
//!
//! The other direction - a built-in isolate (every worker's) while the heap
//! came from Crane's blob - stays allowed: it works in the linked release
//! build because Crane's read-only snapshot EXTENDS the built-in one
//! (v8_enable_extensible_ro_snapshot, 13.1 BUILD.gn:436), and only a DEBUG
//! V8's VerifyChecksum would object. The queued follow-up makes every isolate
//! of a process from one blob.
//!
//! Each test must make its process's first isolate, so each skips - saying
//! so - when another isolate is alive, and the many-Browsers variant runs
//! them alone (build.zig suite_configs `alone`: a busy Browser's isolate
//! would be the first).

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const ffi = @import("v8").ffi;
const test_process = @import("test_process.zig");

const snapshot_path = @import("test_snapshot").path;

const no_hooks: engine.HostHooks = .{};

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }
};

fn expectEval(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    var reports: Reports = .{};
    const got = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = Reports.report, .host = &reports });
    defer testing.allocator.free(got);
    try testing.expectEqual(@as(usize, 0), reports.count);
    try testing.expectEqualStrings(expected, got);
}

/// This build's snapshot, lent to the engine for the test; null when another
/// isolate is alive (the test skips: it must make the process's first).
const Engine = struct {
    bytes: []u8,

    fn start() !?Engine {
        test_process.start();
        if (ffi.v8_Process_LiveIsolates() != 0) {
            std.log.warn("skipping: {d} isolate(s) alive in this process; this test must make its first (run it alone: tests-v8 runs at batch 1)", .{ffi.v8_Process_LiveIsolates()});
            return null;
        }
        const io = testing.io;
        const file = try std.Io.Dir.cwd().openFile(io, snapshot_path, .{});
        defer file.close(io);
        const bytes = try std.heap.c_allocator.alloc(u8, (try file.stat(io)).size);
        errdefer std.heap.c_allocator.free(bytes);
        _ = try file.readPositionalAll(io, bytes, 0);
        try test_process.startSnapshot(bytes);
        return .{ .bytes = bytes };
    }

    /// After every agent restored from the snapshot ended.
    fn stop(self: Engine) void {
        test_process.endSnapshot();
        std.heap.c_allocator.free(self.bytes);
    }
};

/// A window agent - asked for the snapshot or not - with a Window realm,
/// made and checked on the calling thread.
const Window = struct {
    scope: *runtime.BrowserScope,
    agent: *engine.Agent,
    realm: runtime.Context,

    fn open(from_snapshot: bool) !Window {
        const scope = try std.heap.page_allocator.create(runtime.BrowserScope);
        errdefer std.heap.page_allocator.destroy(scope);
        scope.* = runtime.BrowserScope.init(std.heap.c_allocator);
        errdefer scope.deinit();
        const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = from_snapshot, .hooks = &no_hooks, .host = null });
        errdefer engine.destroyAgent(agent);
        // Its realms come from the snapshot only when the agent did.
        const realm = try engine.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = engine.agentRestoredFromSnapshot(agent),
            .timer = null,
            .origin = "https://read-only-heap.test",
            .browser_scope = scope,
            .create_global_object = WindowHost.createGlobalObject,
        });
        errdefer engine.destroyWindowRealm(realm, .global_detached);
        // It works, whichever way it was made.
        try expectEval(realm, "[typeof Document, typeof HTMLElement, 6 * 7].join()", "function,function,42");
        return .{ .scope = scope, .agent = agent, .realm = realm };
    }

    fn close(self: Window) void {
        engine.destroyWindowRealm(self.realm, .global_detached);
        engine.destroyAgent(self.agent);
        self.scope.deinit();
        std.heap.page_allocator.destroy(self.scope);
    }
};

/// A dedicated worker's agent - made as worker_host makes one: [[CanBlock]]
/// true, never from the snapshot - with its worker realm, on a thread of its
/// own. It lives until `finish`.
const Worker = struct {
    thread: std.Thread = undefined,
    ready: std.atomic.Value(bool) = .init(false),
    finish_now: std.atomic.Value(bool) = .init(false),
    failure: ?anyerror = null,

    fn start(self: *Worker) !void {
        self.thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, run, .{self});
        while (!self.ready.load(.acquire)) std.Thread.yield() catch {};
    }

    fn finish(self: *Worker) !void {
        self.finish_now.store(true, .release);
        self.thread.join();
        if (self.failure) |err| return err;
    }

    fn run(self: *Worker) void {
        self.body() catch |err| {
            self.failure = err;
            self.ready.store(true, .release);
        };
    }

    fn body(self: *Worker) !void {
        const agent = try engine.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        defer engine.destroyAgent(agent);
        try testing.expect(!engine.agentRestoredFromSnapshot(agent));
        const made = try engine.createWorkerRealm(agent, &.{ .global = .dedicated, .url = "https://read-only-heap.test/worker.js", .allocator = std.heap.c_allocator, .timer = null, .event_loop = @import("inline_task_loop.zig").eventLoop() });
        defer engine.destroyWorkerRealm(made.realm, null, null);
        try expectEval(made.realm, "[typeof WorkerGlobalScope, typeof Document, 6 * 7].join()", "function,undefined,42");
        self.ready.store(true, .release);
        while (!self.finish_now.load(.acquire)) std.Thread.yield() catch {};
    }
};

test "an agent asked for the snapshot while a snapshotless isolate is the process's first is made without it, and works" {
    const started = (try Engine.start()) orelse return error.SkipZigTest;
    defer started.stop();
    // The first live isolate: V8's built-in snapshot makes the read-only heap.
    const first = try Window.open(false);
    defer first.close();
    try testing.expect(!engine.agentRestoredFromSnapshot(first.agent));
    try testing.expectEqual(ffi.ReadOnlyHeapOrigin.builtin, ffi.readOnlyHeapOrigin(started.bytes[0 .. started.bytes.len - @import("v8").snapshot_loader.stamp_len]));
    // Restoring Crane's blob now crashed V8; it is refused, and the agent is
    // made without it - its realms afresh.
    const second = try Window.open(true);
    defer second.close();
    try testing.expect(!engine.agentRestoredFromSnapshot(second.agent));
}

test "a snapshotless agent made while a snapshot agent is the process's first: each is what it asked for" {
    const started = (try Engine.start()) orelse return error.SkipZigTest;
    defer started.stop();
    // The first live isolate: Crane's blob makes the read-only heap.
    const first = try Window.open(true);
    defer first.close();
    try testing.expect(engine.agentRestoredFromSnapshot(first.agent));
    // V8's built-in snapshot on Crane's read-only heap: the extensible
    // read-only snapshot keeps the built-in objects where they were (only a
    // DEBUG V8's VerifyChecksum objects).
    const second = try Window.open(false);
    defer second.close();
    try testing.expect(!engine.agentRestoredFromSnapshot(second.agent));
    // And a second snapshot agent still restores: the heap is its blob's.
    const third = try Window.open(true);
    defer third.close();
    try testing.expect(engine.agentRestoredFromSnapshot(third.agent));
}

test "a dedicated worker's agent started while a snapshot window agent lives: both work, the window restored" {
    const started = (try Engine.start()) orelse return error.SkipZigTest;
    defer started.stop();
    // A Browser's window agent first, as in every snapshot process.
    const window = try Window.open(true);
    defer window.close();
    try testing.expect(engine.agentRestoredFromSnapshot(window.agent));
    var worker: Worker = .{};
    try worker.start();
    var finished = false;
    defer if (!finished) worker.finish() catch {};
    // A second window agent while the worker lives still restores.
    const other = try Window.open(true);
    defer other.close();
    try testing.expect(engine.agentRestoredFromSnapshot(other.agent));
    finished = true;
    try worker.finish();
}

test "a snapshot window agent made while a worker's agent is the process's first is made without the snapshot, and works" {
    const started = (try Engine.start()) orelse return error.SkipZigTest;
    defer started.stop();
    var worker: Worker = .{};
    try worker.start();
    var finished = false;
    defer if (!finished) worker.finish() catch {};
    // The worker's isolate made the read-only heap from V8's built-in
    // snapshot: Crane's blob is refused, and the window agent is made
    // without it.
    const window = try Window.open(true);
    defer window.close();
    try testing.expect(!engine.agentRestoredFromSnapshot(window.agent));
    finished = true;
    try worker.finish();
}
