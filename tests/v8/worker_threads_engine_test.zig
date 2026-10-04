//! Two agents on two threads at once, as a page and a worker will run once
//! every worker has a thread of its own (docs/instances.md, "Decisions").
//!
//! V8 lets each isolate run on its own thread with no Locker (v8-isolate.h:
//! "The embedder can create multiple isolates and use them in parallel in
//! multiple threads"). What it does not make safe is the adapter's and the
//! runtime's process-wide state that both agents reach: the slab and arena
//! every platform object comes from, the internal-state and EventTarget
//! registries, the DOM node map the wrapper cache reads for every object,
//! v8_wrapper.cpp's weak-handle maps and its one-isolate async iterator
//! template, ShadowRealm's callback data (each agent's end cleared the
//! process's), the isolate lifecycle handlers registered by every
//! createAgent, the Intl registries. Each thread here makes worker realms in
//! an agent of its own and churns what every worker realm runs - events and
//! listeners, URLs, ports, Blobs, Intl, an async iterator, weak wrappers
//! collected - while the other does the same; then both agents end, one
//! while the other is still running.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");

const rounds = 3;

/// One realm's worth of what a worker realm runs, 1,500 times. The value is
/// the number of iterations whose checks all held.
const churn_script =
    \\(function () {
    \\  let ok = 0;
    \\  for (let i = 0; i < 1500; i++) {
    \\    const target = new EventTarget();
    \\    let hits = 0;
    \\    target.addEventListener("x", () => { hits++; });
    \\    target.dispatchEvent(new Event("x"));
    \\    const url = new URL("https://a.test/p?q=" + i);
    \\    const channel = new MessageChannel();
    \\    channel.port1.close();
    \\    const blob = new Blob(["abc" + i]);
    \\    const params = new URLSearchParams("a=" + i);
    \\    const formatted = new Intl.NumberFormat("en-US").format(i);
    \\    const stream = new ReadableStream();
    \\    const iterator = stream[Symbol.asyncIterator]();
    \\    if (hits === 1 && url.searchParams.get("q") === String(i) &&
    \\        params.get("a") === String(i) && blob.size === 3 + String(i).length &&
    \\        formatted.length > 0 && typeof iterator.next === "function") ok++;
    \\  }
    \\  return ok;
    \\})()
;

const Agent = struct {
    /// Iterations whose checks held, over every round.
    ok: i64 = 0,
    failed: ?anyerror = null,

    fn run(self: *Agent) void {
        self.runRounds() catch |err| {
            self.failed = err;
        };
    }

    fn runRounds(self: *Agent) !void {
        // The context manager is per thread, as each worker thread's will be.
        v8.context_manager.init(std.heap.page_allocator) catch {};
        const agent = try protocol.createAgent(.{
            .can_block = true,
            .from_snapshot = false,
            .hooks = &.{},
            .allocator = std.heap.page_allocator,
        });
        defer protocol.destroyAgent(agent);
        var round: usize = 0;
        while (round < rounds) : (round += 1) {
            const made = try v8.worker_realm.createWorkerRealm(agent, .{
                .url = "http://web-platform.test:8000/workers/w.js",
                .timer = null,
                .allocator = std.heap.page_allocator,
            });
            self.ok += try evalIntIn(agent, made.realm, churn_script);
            // Weak wrappers of what the round dropped are collected, and
            // their callbacks run, while the other agent runs.
            protocol.notifyMemoryPressure(agent, .critical);
            v8.worker_realm.destroyWorkerRealm(made.realm, null, null);
        }
    }
};

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

test "two agents on two threads make worker realms and churn platform objects at once" {
    // The platform and the process-wide runtime start on this thread first,
    // as crane.Process starts them before any Browser or worker thread.
    ffi.v8_Platform_Initialize();
    runtime.initializeRuntime(std.heap.page_allocator);

    var agents = [_]Agent{ .{}, .{} };
    var threads: [2]std.Thread = undefined;
    for (&threads, &agents) |*thread, *agent| thread.* = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Agent.run, .{agent});
    for (threads) |thread| thread.join();

    for (agents) |agent| {
        if (agent.failed) |err| return err;
        try std.testing.expectEqual(@as(i64, rounds * 1500), agent.ok);
    }
}
