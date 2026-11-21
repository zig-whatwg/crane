//! HTML "create a new realm" step 5: a realm whose agent cluster's
//! cross-origin isolation mode is "none" has no SharedArrayBuffer global -
//! `! global.[[Delete]]("SharedArrayBuffer")` once the global object exists
//! - while the constructor stays reachable through
//! `new WebAssembly.Memory({ shared:true, initial:0, maximum:0 }).buffer.constructor`.
//!
//! The host passes the mode as `agent_cluster_cross_origin_isolated` in
//! engine.WindowRealmOptions and runtime.WorkerRealmOptions (the V8 adapter's
//! shared_array_buffer_exposure.zig). Every realm exposed the global until
//! then: a noopener popup that was not cross-origin isolated read
//! `typeof SharedArrayBuffer` "function" (html/cross-origin-opener-policy/
//! noopener-popup-cross-origin-isolation.https.html; Chrome and Firefox read
//! "undefined"). An isolated realm keeps it - the control.

const std = @import("std");
const test_process = @import("test_process.zig");
/// Every worker realm has an event loop; this test drives none.
const inline_task_loop = @import("inline_task_loop.zig");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

/// The hooks of the file's agent: none.
const window_agent_hooks: protocol.HostHooks = .{};

var test_isolate: ?*ffi.Isolate = null;

/// The test's own agent, ended with the test (test_process.TestAgent);
/// `reset` clears what the file caches of it.
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_isolate = null;
}

fn agent() !*ffi.Isolate {
    const i = try test_agent.open(.{ .hooks = &window_agent_hooks });
    if (test_isolate == null) {
        const context = test_agent.context.?;
        _ = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
        test_isolate = i;
    }
    return test_isolate.?;
}

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

fn windowRealm(isolated: bool) !runtime.Context {
    const isolate = try agent();
    return protocol.createWindowRealm(&.{
        .agent_cluster_cross_origin_isolated = isolated,
        .agent = @ptrCast(isolate),
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .global_this = .new_window_proxy,
        .create_global_object = WindowHost.createGlobalObject,
        .host = null,
    });
}

const Ignored = struct {
    fn report(_: ?*anyopaque, _: *const protocol.ErrorInfo) void {}
    const reporter: protocol.Reporter = .{ .report = report, .host = null };
};

fn expectEval(r: runtime.Context, source: []const u8, expected: []const u8) !void {
    const got = try protocol.evaluateClassicScriptToString(r, .{ .utf8 = source }, "", null, std.testing.allocator, Ignored.reporter);
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings(expected, got);
}

/// The global's own SharedArrayBuffer, its type, and the constructor a shared
/// WebAssembly.Memory's buffer still has.
const probe =
    \\[Object.prototype.hasOwnProperty.call(globalThis, 'SharedArrayBuffer'), typeof SharedArrayBuffer,
    \\ new WebAssembly.Memory({ shared: true, initial: 0, maximum: 0 }).buffer.constructor.name].join()
;

test "a Window realm whose agent cluster is not cross-origin isolated has no SharedArrayBuffer global" {
    defer test_agent.close();
    const page = try windowRealm(false);
    defer protocol.destroyWindowRealm(page, .global_detached);
    try expectEval(page, probe, "false,undefined,SharedArrayBuffer");
}

test "a Window realm whose agent cluster is cross-origin isolated keeps it" {
    defer test_agent.close();
    const page = try windowRealm(true);
    defer protocol.destroyWindowRealm(page, .global_detached);
    try expectEval(page, probe, "true,function,SharedArrayBuffer");
}

/// `code`, run in `realm` of `worker_agent`, as an int32.
fn evalIntIn(worker_agent: *runtime.Agent, realm: runtime.Context, code: []const u8) !i32 {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(worker_agent));
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

/// 1 when the worker's global has no SharedArrayBuffer and a shared
/// WebAssembly.Memory's buffer still has the constructor; 2 when the global
/// has it; 0 otherwise.
const worker_probe =
    \\(() => {
    \\  const viaMemory = new WebAssembly.Memory({ shared: true, initial: 0, maximum: 0 }).buffer.constructor.name === 'SharedArrayBuffer';
    \\  if (!viaMemory) return 0;
    \\  if (!Object.prototype.hasOwnProperty.call(self, 'SharedArrayBuffer') && typeof SharedArrayBuffer === 'undefined') return 1;
    \\  return typeof SharedArrayBuffer === 'function' ? 2 : 0;
    \\})()
;

fn workerRealm(worker_agent: *runtime.Agent, global: runtime.WorkerRealmOptions.WorkerGlobal, isolated: bool) !runtime.WorkerRealm {
    return v8.worker_realm.createWorkerRealm(worker_agent, .{
        .agent_cluster_cross_origin_isolated = isolated,
        .url = "https://web-platform.test:8443/workers/w.js",
        .timer = null,
        .event_loop = inline_task_loop.eventLoop(),
        .global = global,
        .allocator = std.heap.c_allocator,
    });
}

test "a worker realm takes its agent cluster's mode: deleted when none, kept when isolated" {
    test_process.start();
    const worker_agent = try protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &test_process.no_hooks });
    defer protocol.destroyAgent(worker_agent);
    inline for (.{ .dedicated, .shared, .service }) |global| {
        {
            const made = try workerRealm(worker_agent, global, false);
            defer v8.worker_realm.destroyWorkerRealm(made.realm, null, null);
            try std.testing.expectEqual(@as(i32, 1), try evalIntIn(worker_agent, made.realm, worker_probe));
        }
        {
            const made = try workerRealm(worker_agent, global, true);
            defer v8.worker_realm.destroyWorkerRealm(made.realm, null, null);
            try std.testing.expectEqual(@as(i32, 2), try evalIntIn(worker_agent, made.realm, worker_probe));
        }
    }
}
