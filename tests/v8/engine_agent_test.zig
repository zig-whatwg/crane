//! The Engine table's agent operations, as V8 implements them: a realm is
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

const engine = &v8.engine.v8_engine_interface;

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
    data.* = try runtime.ContextData.init(std.heap.page_allocator, .{ .engine = engine, .engine_ctx = context });
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
    seen.running = engine.hasRunningScript.?(@ptrCast(worker.?));
}

test "a task fired into a realm from another agent runs with the realm's agent entered" {
    try setup();
    try std.testing.expectEqual(page, ffi.v8_Isolate_GetCurrent());

    var seen: Seen = .{};
    try engine.runTaskInRealm.?(worker_realm.?, observe, &seen);
    try std.testing.expectEqual(worker, seen.current);
    try std.testing.expect(seen.running);
    // And the page's is current again after.
    try std.testing.expectEqual(page, ffi.v8_Isolate_GetCurrent());

    var sync: Seen = .{};
    try engine.runInRealm.?(worker_realm.?, observe, &sync);
    try std.testing.expectEqual(worker, sync.current);
    try std.testing.expectEqual(page, ffi.v8_Isolate_GetCurrent());
}

test "script runs in the realm's agent, not the current one" {
    try setup();
    const Reports = struct {
        count: usize = 0,
        fn report(host: ?*anyopaque, _: *const runtime.ErrorInfo) void {
            const self: *@This() = @ptrCast(@alignCast(host.?));
            self.count += 1;
        }
    };
    var reports: Reports = .{};
    try engine.runClassicScript.?(worker_realm.?, "globalThis.inWorker = 41 + 1;", null, Reports.report, &reports);
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    // The value is in the worker's context: read it there.
    try engine.runClassicScript.?(worker_realm.?, "if (globalThis.inWorker !== 42) throw new Error('not here');", null, Reports.report, &reports);
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    // Not in the page's.
    try std.testing.expectEqual(page, ffi.v8_Isolate_GetCurrent());
}

test "an agent with no script on the stack is not running any" {
    try setup();
    try std.testing.expect(!engine.hasRunningScript.?(@ptrCast(worker.?)));
    // The current agent is, as far as V8 can tell.
    try std.testing.expect(engine.hasRunningScript.?(@ptrCast(page.?)));
}

test "a new agent is made and disposed, and an idle one has no engine work" {
    try setup();
    const agent = try engine.createAgent.?();
    try std.testing.expect(!engine.hasRunningScript.?(agent));
    try std.testing.expect(!engine.hasPendingEngineWork.?(agent));
    try std.testing.expect(!engine.runEngineTasks.?(agent));
    // Neither left the new agent entered.
    try std.testing.expectEqual(page, ffi.v8_Isolate_GetCurrent());
    engine.destroyAgent.?(agent);
}
