//! Agent operations as V8 implements them (worker_realm.zig): a realm is
//! entered with ITS agent, whichever agent is current; and createAgent,
//! destroyAgent, hasRunningScript, hasPendingEngineWork, runEngineTasks.
//!
//! A worker's realm lives in the worker's own agent (a V8 isolate), and its
//! tasks are fired from the page's event loop - with the page's isolate
//! current. runTaskInRealm used to enter the CURRENT isolate unless the realm
//! had a Realm recording one, and a worker realm has none: a HandleScope of
//! the page's isolate over the worker's context. The context manager now
//! records every realm's agent (ContextData.agent), and entering a realm
//! enters it.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");

/// Two isolates, each with a context and a realm over it, for the whole file.
/// The first stays entered - "the page's"; the second is "the worker's", and
/// is entered only by the operations under test.
var page: ?*ffi.Isolate = null;
var worker: ?*ffi.Isolate = null;
var worker_context: ?*ffi.Context = null;
var worker_realm: ?*runtime.ContextData = null;

fn setup() !void {
    if (page != null) return;
    const p = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(p);
    _ = ffi.v8_HandleScope_New(p);
    const page_context = ffi.v8_Context_New(p) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(page_context);

    // The worker's isolate, entered only to make its context.
    const w = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(w);
    const scope = ffi.v8_HandleScope_New(w);
    const context = ffi.v8_Context_New(w) orelse return error.ContextCreationFailed;
    if (scope) |s| ffi.v8_HandleScope_Dispose(s);
    ffi.v8_Isolate_Exit(w);

    const data = try std.heap.page_allocator.create(runtime.ContextData);
    data.* = try runtime.ContextData.init(std.heap.page_allocator, .{ .engine_ctx = context });
    // What the context manager records for every realm it registers.
    data.agent = @ptrCast(w);

    page = p;
    worker = w;
    worker_context = context;
    worker_realm = data;
}

const Seen = struct {
    current: ?*ffi.Isolate = null,
    running: bool = false,
};

fn observe(data: ?*anyopaque) void {
    const seen: *Seen = @ptrCast(@alignCast(data.?));
    seen.current = ffi.v8_Isolate_GetCurrent();
    seen.running = v8.worker_realm.hasRunningScript(@ptrCast(worker.?));
}

test "a task fired into a realm from another agent runs with the realm's agent entered" {
    try setup();
    try std.testing.expectEqual(page, ffi.v8_Isolate_GetCurrent());

    var seen: Seen = .{};
    try v8.engine.v8RunTaskInRealm(worker_realm.?, observe, &seen);
    try std.testing.expectEqual(worker, seen.current);
    try std.testing.expect(seen.running);
    // And the page's is current again after.
    try std.testing.expectEqual(page, ffi.v8_Isolate_GetCurrent());

    var sync: Seen = .{};
    try v8.engine.v8RunInRealm(worker_realm.?, observe, &sync);
    try std.testing.expectEqual(worker, sync.current);
    try std.testing.expectEqual(page, ffi.v8_Isolate_GetCurrent());
}

test "script runs in the realm's agent, not the current one" {
    try setup();
    const Reports = struct {
        count: usize = 0,
        fn report(host: ?*anyopaque, _: *const protocol.ErrorInfo) void {
            const self: *@This() = @ptrCast(@alignCast(host.?));
            self.count += 1;
        }
    };
    var reports: Reports = .{};
    const reporter: protocol.Reporter = .{ .report = Reports.report, .host = &reports };
    try protocol.runClassicScript(worker_realm.?, .{ .utf8 = "globalThis.inWorker = 41 + 1;" }, "", null, reporter);
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    // The value is in the worker's context: read it there.
    try protocol.runClassicScript(worker_realm.?, .{ .utf8 = "if (globalThis.inWorker !== 42) throw new Error('not here');" }, "", null, reporter);
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    // Not in the page's.
    try std.testing.expectEqual(page, ffi.v8_Isolate_GetCurrent());
}

test "an agent with no script on the stack is not running any" {
    try setup();
    try std.testing.expect(!v8.worker_realm.hasRunningScript(@ptrCast(worker.?)));
    // The current agent is, as far as V8 can tell.
    try std.testing.expect(v8.worker_realm.hasRunningScript(@ptrCast(page.?)));
}

test "a new agent is made and disposed, and an idle one has no engine work" {
    try setup();
    const agent = try v8.worker_realm.createAgent();
    try std.testing.expect(!v8.worker_realm.hasRunningScript(agent));
    try std.testing.expect(!v8.worker_realm.hasPendingEngineWork(agent));
    try std.testing.expect(!v8.worker_realm.runEngineTasks(agent));
    // Neither left the new agent entered.
    try std.testing.expectEqual(page, ffi.v8_Isolate_GetCurrent());
    v8.worker_realm.destroyAgent(agent);
}

// ---- lane: speed ----
// HTML 8.1.4.5 "abort a running script": engine.abortRunningScript from
// another thread, engine.resumeScripts on the agent's own.

const clock = @import("clock");

/// Calls abortRunningScript on `agent` from its own thread after `after_ms`.
const Aborter = struct {
    agent: *protocol.Agent,
    after_ms: u64,

    fn run(self: *const Aborter) void {
        clock.sleep(self.after_ms * std.time.ns_per_ms);
        protocol.abortRunningScript(self.agent);
    }
};

const AbortReports = struct {
    count: usize = 0,
    fn report(host: ?*anyopaque, _: *const protocol.ErrorInfo) void {
        const self: *@This() = @ptrCast(@alignCast(host.?));
        self.count += 1;
    }
};

/// A realm of the worker's agent whose allocator is std.testing.allocator, so
/// that whatever an aborted script's host steps allocate and do not free fails
/// the test. Destroyed by the caller.
fn testingRealm() !*runtime.ContextData {
    const w = worker.?;
    ffi.v8_Isolate_Enter(w);
    const scope = ffi.v8_HandleScope_New(w);
    const context = ffi.v8_Context_New(w) orelse return error.ContextCreationFailed;
    if (scope) |s| ffi.v8_HandleScope_Dispose(s);
    ffi.v8_Isolate_Exit(w);
    const data = try std.testing.allocator.create(runtime.ContextData);
    data.* = try runtime.ContextData.init(std.testing.allocator, .{ .engine_ctx = context });
    data.agent = @ptrCast(w);
    return data;
}

fn destroyTestingRealm(data: *runtime.ContextData) void {
    const context: *ffi.Context = @ptrCast(@alignCast(data.engine_ctx.?));
    data.deinit();
    std.testing.allocator.destroy(data);
    ffi.v8_Context_Dispose(context);
}

test "abortRunningScript from another thread ends an infinite loop, and the agent runs script after resumeScripts" {
    try setup();
    const agent: *protocol.Agent = @ptrCast(worker.?);
    const realm = try testingRealm();
    defer destroyTestingRealm(realm);
    var reports: AbortReports = .{};
    const reporter: protocol.Reporter = .{ .report = AbortReports.report, .host = &reports };

    const handle_bytes_before = ffi.v8_Isolate_GetGlobalHandleBytes(worker.?);
    for (0..4) |_| {
        const aborter: Aborter = .{ .agent = agent, .after_ms = 50 };
        const thread = try std.Thread.spawn(.{}, Aborter.run, .{&aborter});
        const started = clock.monotonicMillis();
        // A loop that never ends by itself, and a finally that must not run.
        const outcome = protocol.runClassicScript(realm, .{ .utf8 = "globalThis.spins = 0; globalThis.finallyRan = false; try { for (;;) { spins++; } } finally { finallyRan = true; }" }, "", null, reporter);
        thread.join();
        // Ended, abruptly, and promptly.
        if (outcome) |_| return error.NotAborted else |_| {}
        try std.testing.expect(clock.monotonicMillis() - started < 10_000);

        protocol.resumeScripts(agent);
        // The agent runs script again: the loop ran, and no finally did.
        try protocol.runClassicScript(realm, .{ .utf8 = "if (!(globalThis.spins > 0)) throw new Error('the loop never ran'); if (globalThis.finallyRan) throw new Error('a finally ran');" }, "", null, reporter);
    }
    // Nothing kept per abort. (V8 may keep a node or two of its own as the
    // script tiers up, as engine_webidl_conversions_test allows.)
    try std.testing.expect(ffi.v8_Isolate_GetGlobalHandleBytes(worker.?) <= handle_bytes_before + 64);
    // The page's agent is current again, untouched.
    try std.testing.expectEqual(page, ffi.v8_Isolate_GetCurrent());
}

test "an abort requested while no script runs ends the next script; resumeScripts first lets it run" {
    try setup();
    const agent: *protocol.Agent = @ptrCast(worker.?);
    const realm = try testingRealm();
    defer destroyTestingRealm(realm);
    var reports: AbortReports = .{};
    const reporter: protocol.Reporter = .{ .report = AbortReports.report, .host = &reports };

    // Requested with nothing running: the next script to start is aborted.
    protocol.abortRunningScript(agent);
    const aborted = protocol.runClassicScript(realm, .{ .utf8 = "for (let i = 0; i < 1e9; i++) {} globalThis.ranToEnd = true;" }, "", null, reporter);
    if (aborted) |_| return error.NotAborted else |_| {}
    protocol.resumeScripts(agent);
    try protocol.runClassicScript(realm, .{ .utf8 = "if (globalThis.ranToEnd) throw new Error('the aborted script ran to its end');" }, "", null, reporter);

    // Requested, then resumed before any script: nothing is aborted.
    protocol.abortRunningScript(agent);
    protocol.resumeScripts(agent);
    try protocol.runClassicScript(realm, .{ .utf8 = "globalThis.resumed = 1;" }, "", null, reporter);
    try protocol.runClassicScript(realm, .{ .utf8 = "if (globalThis.resumed !== 1) throw new Error('not run');" }, "", null, reporter);
}
// ---- end lane: speed ----
