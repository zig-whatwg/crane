//! A worker realm's realm record (runtime.Realm), as the V8 adapter's
//! createWorkerRealm makes it (worker_realm.zig).
//!
//! HTML's realm has a global object; the host reaches "the realm's global
//! object" through the record (context_manager.get -> ContextData.realm ->
//! global_object) - report_exception does, to fire `error` at it. A window
//! realm has always had one; a worker realm had none, so an exception an
//! event listener threw in a worker found no global to report to.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const protocol = @import("engine");
const ffi = v8.ffi;

var set_up = false;

fn setup() void {
    if (set_up) return;
    set_up = true;
    runtime.initializeRuntime(std.heap.page_allocator);
    // Already initialized is fine: the manager is per thread, not per test.
    v8.context_manager.init(std.heap.page_allocator) catch {};
}

fn workerRealm(agent: *runtime.Agent) !runtime.WorkerRealm {
    return v8.worker_realm.createWorkerRealm(agent, .{
        .url = "http://web-platform.test:8000/workers/w.js",
        .timer = null,
        .allocator = std.heap.page_allocator,
    });
}

fn sharedWorkerRealm(agent: *runtime.Agent) !runtime.WorkerRealm {
    return v8.worker_realm.createWorkerRealm(agent, .{
        .url = "http://web-platform.test:8000/workers/shared.js",
        .timer = null,
        .global = .shared,
        .allocator = std.heap.page_allocator,
    });
}

/// `code`, run in `realm` of `agent`, as an int32.
fn evalIntIn(agent: *runtime.Agent, realm: runtime.Context, code: []const u8) !i32 {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);
    const scope = ffi.v8_HandleScope_New(isolate) orelse return error.HandleScopeFailed;
    defer ffi.v8_HandleScope_Dispose(scope);
    const context: *ffi.Context = @ptrCast(@alignCast(realm.engine_ctx orelse return error.NoContext));
    ffi.v8_Context_Enter(context);
    defer ffi.v8_Context_Exit(context);
    const text = ffi.v8_String_NewFromUtf8(isolate, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    const value = ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, context);
}

// HTML "run a worker" step 5: for a shared worker, the realm's global object
// is a new SharedWorkerGlobalScope - its record says so, script sees it as
// the global with SharedWorkerGlobalScope's prototype chain, its own members
// (onconnect, name, close) are on it, and the set [Exposed] to a shared
// worker is installed: not DedicatedWorkerGlobalScope, nor its postMessage.
test "a shared worker realm's global object is a SharedWorkerGlobalScope" {
    setup();
    const agent = try v8.worker_realm.createAgent();
    defer v8.worker_realm.destroyAgent(agent);
    const made = try sharedWorkerRealm(agent);
    defer v8.worker_realm.destroyWorkerRealm(made.realm, null, null);

    const record = made.realm.getRealm() orelse return error.NoRealmRecord;
    try std.testing.expectEqual(runtime.realm.ContextType.shared_worker, record.info.context_type);
    try std.testing.expectEqual(@as(?*anyopaque, @ptrCast(made.global_scope)), record.global_object);
    try std.testing.expectEqual(@as(i32, 1), try evalIntIn(agent, made.realm,
        \\Object.getPrototypeOf(self) === SharedWorkerGlobalScope.prototype &&
        \\Object.getPrototypeOf(SharedWorkerGlobalScope.prototype) === WorkerGlobalScope.prototype &&
        \\Object.getPrototypeOf(WorkerGlobalScope.prototype) === EventTarget.prototype &&
        \\self instanceof SharedWorkerGlobalScope && self === globalThis ? 1 : 0
    ));
    try std.testing.expectEqual(@as(i32, 1), try evalIntIn(agent, made.realm,
        \\"onconnect" in self && self.onconnect === null && typeof self.close === "function" && "name" in self ? 1 : 0
    ));
    try std.testing.expectEqual(@as(i32, 0), try evalIntIn(agent, made.realm,
        \\"DedicatedWorkerGlobalScope" in self || "postMessage" in self || "onmessage" in self ? 1 : 0
    ));
}

// The default is unchanged: a worker realm's global is a
// DedicatedWorkerGlobalScope, and SharedWorkerGlobalScope is not exposed to it.
test "a worker realm's global object is a DedicatedWorkerGlobalScope unless asked for a shared one" {
    setup();
    const agent = try v8.worker_realm.createAgent();
    defer v8.worker_realm.destroyAgent(agent);
    const made = try workerRealm(agent);
    defer v8.worker_realm.destroyWorkerRealm(made.realm, null, null);

    try std.testing.expectEqual(@as(i32, 1), try evalIntIn(agent, made.realm,
        \\Object.getPrototypeOf(self) === DedicatedWorkerGlobalScope.prototype &&
        \\"onmessage" in self && !("SharedWorkerGlobalScope" in self) && !("onconnect" in self) ? 1 : 0
    ));
}

test "a worker realm's record is a dedicated worker's, its global object the global scope, its intrinsics populated" {
    setup();
    const agent = try v8.worker_realm.createAgent();
    defer v8.worker_realm.destroyAgent(agent);
    const made = try workerRealm(agent);
    defer v8.worker_realm.destroyWorkerRealm(made.realm, null, null);

    const record = made.realm.getRealm() orelse return error.NoRealmRecord;
    try std.testing.expectEqual(runtime.realm.ContextType.dedicated_worker, record.info.context_type);
    try std.testing.expectEqual(@as(?*anyopaque, @ptrCast(made.global_scope)), record.global_object);
    try std.testing.expect(record.getIntrinsics().isPopulated());
}

/// The agent's native contexts, after a full collection: how many realms are
/// still alive in it.
fn liveRealms(agent: *runtime.Agent) usize {
    protocol.requestGarbageCollection(agent);
    return protocol.heapStatistics(agent).realm_count;
}

/// One realm record's life, as a worker realm's: a context the manager hosts,
/// the record made for it (worker_realm.recordRealm), then the context removed
/// and disposed.
fn recordRound(isolate: *ffi.Isolate) !void {
    const scope = ffi.v8_HandleScope_New(isolate) orelse return error.HandleScopeFailed;
    defer ffi.v8_HandleScope_Dispose(scope);
    const context = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
    defer ffi.v8_Context_Dispose(context);
    ffi.v8_Context_Enter(context);
    defer ffi.v8_Context_Exit(context);
    const realm = try v8.context_manager.getOrCreateWithExternalEventLoop(context, null, null, std.heap.page_allocator);
    // Stands in for the DedicatedWorkerGlobalScope: the record keeps only its address.
    var global_scope: runtime.Instance = undefined;
    try v8.worker_realm.recordRealm(isolate, context, realm, &global_scope, .dedicated_worker);
    try std.testing.expect(realm.getRealm().?.getIntrinsics().isPopulated());
    v8.context_manager.removeContext(context);
}

// The record holds its intrinsics (%TypeError%, %Object%, ...) as Globals of
// the realm's own constructors, and one Global into a context keeps the whole
// context alive. The live-handle counters do not see them (they are Values,
// not the counted String/Object/Context Globals), so what is measured is what
// a forgotten one would cost: the context outliving its realm.
//
// Not a whole worker realm round (createWorkerRealm + destroyWorkerRealm): that
// leaves ~3,700 String and 11 Object Globals per realm, with or without the
// record - installing the [Exposed] interfaces, not the record.
test "a worker realm's record lets its context go when the context is removed" {
    setup();
    const agent = try v8.worker_realm.createAgent();
    defer v8.worker_realm.destroyAgent(agent);
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);

    try recordRound(isolate);
    const start = liveRealms(agent);
    for (0..3) |_| try recordRound(isolate);
    try std.testing.expectEqual(start, liveRealms(agent));
}

// A whole worker realm, made and destroyed in one agent: every Global the
// realm took - its interface objects, the names they were defined under, its
// global scope - goes with it, and so does its context. Measured as V8 counts
// them (global handle bytes: every live Global's slot) and as native
// contexts after a full collection; the adapter's live counters count only
// some kinds of Global.
test "a worker realm made and destroyed leaves no global handle behind, and lets its context go" {
    setup();
    const agent = try v8.worker_realm.createAgent();
    defer v8.worker_realm.destroyAgent(agent);
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    // What one handle costs in V8's count.
    const handle_bytes = blk: {
        ffi.v8_Isolate_Enter(isolate);
        defer ffi.v8_Isolate_Exit(isolate);
        const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        const one = ffi.v8_Number_New(isolate, 1);
        const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        ffi.v8_Value_Dispose(@ptrCast(one));
        break :blk with_one - start;
    };
    // The first realm makes what every later one reuses.
    {
        const made = try workerRealm(agent);
        v8.worker_realm.destroyWorkerRealm(made.realm, null, null);
    }
    const contexts_before = liveRealms(agent);
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const rounds = 3;
    for (0..rounds) |_| {
        const made = try workerRealm(agent);
        v8.worker_realm.destroyWorkerRealm(made.realm, null, null);
    }
    const contexts_after = liveRealms(agent);
    const after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    if (after -| before >= handle_bytes or contexts_after != contexts_before) {
        std.debug.print("global handles {d} -> {d} bytes ({d} a handle), native contexts {d} -> {d}, over {d} worker realms\n", .{ before, after, handle_bytes, contexts_before, contexts_after, rounds });
        return error.HandlesLeaked;
    }
}
