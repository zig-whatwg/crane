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
/// "ok:<n>", n the number of iterations whose checks all held, or the
/// exception's text.
const churn_script =
    \\(function () {
    \\  try {
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
    \\  return "ok:" + ok;
    \\  } catch (e) { return "error: " + e; }
    \\})()
;

const Agent = struct {
    /// Iterations whose checks held, over every round.
    ok: i64 = 0,
    failed: ?anyerror = null,
    /// The first round's answer that was not "ok:<n>": the exception's text.
    report: [256]u8 = undefined,
    report_len: usize = 0,

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
            // Crane's Intl is installed only on window realms today; a
            // worker realm gets it the same way here, so the registries
            // Intl objects live in are shared by both threads, as they are
            // by a page and its frames.
            installIntl(agent, made.realm);
            var answer: [256]u8 = undefined;
            const text = try evalStringIn(agent, made.realm, churn_script, &answer);
            if (std.mem.startsWith(u8, text, "ok:")) {
                self.ok += try std.fmt.parseInt(i64, text[3..], 10);
            } else if (self.report_len == 0) {
                @memcpy(self.report[0..text.len], text);
                self.report_len = text.len;
            }
            // Weak wrappers of what the round dropped are collected, and
            // their callbacks run, while the other agent runs.
            protocol.notifyMemoryPressure(agent, .critical);
            v8.worker_realm.destroyWorkerRealm(made.realm, null, null);
        }
    }
};

/// intl_binding's Intl, on `realm`'s global (as window realms get it).
fn installIntl(agent: *runtime.Agent, realm: runtime.Context) void {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);
    const scope = ffi.v8_HandleScope_New(isolate) orelse return;
    defer ffi.v8_HandleScope_Dispose(scope);
    const context: *ffi.Context = @ptrCast(@alignCast(realm.engine_ctx orelse return));
    ffi.v8_Context_Enter(context);
    defer ffi.v8_Context_Exit(context);
    v8.intl_binding.registerGlobal(isolate, context);
}

/// `code`, run in `realm` of `agent`, as a string in `buffer` (truncated).
fn evalStringIn(agent: *runtime.Agent, realm: runtime.Context, code: []const u8, buffer: []u8) ![]const u8 {
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
    const string = ffi.v8_Value_ToString(value, context) orelse return error.ToStringFailed;
    defer ffi.v8_String_Dispose(string);
    const len: usize = @intCast(@max(ffi.v8_String_Utf8Length(string), 0));
    const take = @min(len, buffer.len);
    _ = ffi.v8_String_WriteUtf8(string, buffer.ptr, @intCast(take));
    return buffer[0..take];
}

test "two agents on two threads make worker realms and churn platform objects at once" {
    // The engine, the process-wide runtime and every src/dom hook start on
    // this thread first, as crane.Process starts them before any Browser or
    // worker thread: the engine's teardown handlers are written once there
    // (two threads making their first agents at once would race on them),
    // and MessageChannel makes its ports through MessagePort's hook. tests/v8
    // runs in one process: each is idempotent, and the runtime starts only if
    // no file before this one started it.
    try protocol.initializeEngine(.{});
    if (runtime.SlabAllocator.tryGet()) |_| {} else |_| runtime.initializeRuntime(std.heap.page_allocator);
    @import("interfaces").process_hooks.startHooksForTest();

    var agents = [_]Agent{ .{}, .{} };
    var threads: [2]std.Thread = undefined;
    for (&threads, &agents) |*thread, *agent| thread.* = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Agent.run, .{agent});
    for (threads) |thread| thread.join();

    for (agents) |agent| {
        if (agent.failed) |err| {
            std.debug.print("agent failed: {s}\n", .{@errorName(err)});
            return err;
        }
        if (agent.report_len > 0) std.debug.print("a round threw: {s}\n", .{agent.report[0..agent.report_len]});
        try std.testing.expectEqual(@as(i64, rounds * 1500), agent.ok);
    }
}
