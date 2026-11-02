//! An agent's realms are its own: another agent's end on the same thread
//! frees none of them.
//!
//! The V8 adapter's context manager kept every realm's record on a
//! `threadlocal` (context_manager.zig `manager_state`), and the thread's host
//! agent - the one made with no isolate entered - took ALL of it down at its
//! end (protocol_agents.endAgent -> isolate_lifecycle.cleanupAll ->
//! context_manager.deinit), the realms other agents on the thread made
//! included (lane v8order1's fifth mechanism, tmp/plans/lane-v8order1-
//! handoff.md). docs/instances.md: state has an owner - process, Browser,
//! Tab, agent or realm - never a thread.
//!
//! The tests run on threads of their own: tests/v8 is one process, and an
//! earlier file may have left an isolate entered on the main one.

const std = @import("std");
const test_process = @import("test_process.zig");
/// Every worker realm has an event loop; these tests drive none.
const inline_task_loop = @import("inline_task_loop.zig");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

const no_hooks: protocol.HostHooks = .{};

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

fn newAgent() !*protocol.Agent {
    return protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &no_hooks, .host = null });
}

fn windowRealmIn(agent: *protocol.Agent) !runtime.Context {
    return protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
}

fn workerRealmIn(agent: *protocol.Agent) !runtime.Context {
    const made = try protocol.createWorkerRealm(agent, &.{
        .url = "https://example.test/worker.js",
        .timer = null,
        .event_loop = inline_task_loop.eventLoop(),
        .allocator = std.heap.c_allocator,
    });
    return made.realm;
}

/// The key the context manager files `realm` under (context_manager.keyOf),
/// read with its agent current.
fn keyOf(agent: *protocol.Agent, realm: runtime.Context) !usize {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);
    const scope = ffi.v8_HandleScope_New(isolate) orelse return error.HandleScopeFailed;
    defer ffi.v8_HandleScope_Dispose(scope);
    const context: *ffi.Context = @ptrCast(@alignCast(realm.engine_ctx orelse return error.NoContext));
    return v8.context_manager.keyOf(context) orelse error.NoKey;
}

/// The realm the context manager has under `key`, asked with `agent` current.
fn realmUnder(agent: *protocol.Agent, key: usize) ?runtime.Context {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);
    return v8.context_manager.getByKey(key);
}

/// `code`, run in `realm` of `agent`, as a string in `buffer` (truncated).
fn evalStringIn(agent: *protocol.Agent, realm: runtime.Context, code: []const u8, buffer: []u8) ![]const u8 {
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

/// Platform objects made, used and dropped in a realm: their constructors
/// find the realm through the context manager (interface.zig's construct
/// path), and an event dispatch runs a callback the realm registered.
const works_script =
    \\(function () {
    \\  try {
    \\    const target = new EventTarget();
    \\    let hits = 0;
    \\    target.addEventListener("x", () => { hits++; });
    \\    target.dispatchEvent(new Event("x"));
    \\    const url = new URL("https://a.test/p?q=7");
    \\    return hits === 1 && url.searchParams.get("q") === "7" ? "ok" : "wrong";
    \\  } catch (e) { return "threw: " + e; }
    \\})()
;

fn runOnThread(comptime body: fn () anyerror!void) !void {
    test_process.start();
    var failure: ?anyerror = null;
    const Run = struct {
        fn main(out: *?anyerror) void {
            body() catch |err| {
                out.* = err;
            };
        }
    };
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Run.main, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

/// Agent `first` is made with nothing entered on the thread - what a Browser
/// does for its page agent - and `second` inside `first`'s realm, as a
/// worker's agent was once made by its owner's script. Each makes a realm.
/// `first` ends while `second`'s realm lives.
fn firstEndsWhileSecondsRealmLives() !void {
    const first = try newAgent();
    var first_ended = false;
    defer if (!first_ended) protocol.destroyAgent(first);
    const first_realm = try windowRealmIn(first);
    var first_realm_ended = false;
    defer if (!first_realm_ended) protocol.destroyWindowRealm(first_realm, .global_detached);

    const second = try newAgent();
    defer protocol.destroyAgent(second);
    const second_realm = try workerRealmIn(second);
    const key = try keyOf(second, second_realm);
    try std.testing.expectEqual(@as(?runtime.Context, second_realm), realmUnder(second, key));

    var buffer: [256]u8 = undefined;
    try std.testing.expectEqualStrings("ok", try evalStringIn(second, second_realm, works_script, &buffer));

    // The first agent's realm, then the agent itself.
    protocol.destroyWindowRealm(first_realm, .global_detached);
    first_realm_ended = true;
    protocol.destroyAgent(first);
    first_ended = true;

    // The second agent's realm is still its agent's: on record, and working.
    // (Freed, it may not be touched again - not even to end it.)
    if (realmUnder(second, key) != second_realm) return error.AnotherAgentsEndFreedTheRealm;
    try std.testing.expectEqualStrings("ok", try evalStringIn(second, second_realm, works_script, &buffer));
    protocol.destroyWorkerRealm(second_realm, null, null);
}

test "an agent's end frees only its own realms: another agent's realm on the thread lives on" {
    try runOnThread(firstEndsWhileSecondsRealmLives);
}

/// The reverse order: the agent made inside another's realm ends first, with
/// a realm still on its record; the outer agent's realm is untouched, and the
/// inner agent's realm went with it.
fn secondEndsWithItsRealm() !void {
    const first = try newAgent();
    defer protocol.destroyAgent(first);
    const first_realm = try windowRealmIn(first);
    defer protocol.destroyWindowRealm(first_realm, .global_detached);
    const first_key = try keyOf(first, first_realm);

    const second = try newAgent();
    const second_realm = try workerRealmIn(second);
    const second_key = try keyOf(second, second_realm);
    protocol.destroyWorkerRealm(second_realm, null, null);
    protocol.destroyAgent(second);

    try std.testing.expectEqual(@as(?runtime.Context, first_realm), realmUnder(first, first_key));
    // The first agent never had the second's realm.
    try std.testing.expectEqual(@as(?runtime.Context, null), realmUnder(first, second_key));
    var buffer: [256]u8 = undefined;
    try std.testing.expectEqualStrings("ok", try evalStringIn(first, first_realm, works_script, &buffer));
}

test "an agent's end leaves the realms of the agent it was made in" {
    try runOnThread(secondEndsWithItsRealm);
}

/// How many callback wrappers `agent` tracks (callback_registry.Live, on its
/// record).
fn callbacksTrackedBy(agent: *protocol.Agent) usize {
    const live = v8.protocol_agents.callbacksOf(@ptrCast(@alignCast(agent))) orelse return 0;
    return live.count();
}

const CallbackWrapper = v8.callback_wrapper_mod.CallbackWrapper;

/// A callback wrapper for a function made in `realm` of `agent`, as the
/// binding makes one for a callback argument.
fn wrapperIn(agent: *protocol.Agent, realm: runtime.Context) !*CallbackWrapper {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);
    const scope = ffi.v8_HandleScope_New(isolate) orelse return error.HandleScopeFailed;
    defer ffi.v8_HandleScope_Dispose(scope);
    const context: *ffi.Context = @ptrCast(@alignCast(realm.engine_ctx orelse return error.NoContext));
    ffi.v8_Context_Enter(context);
    defer ffi.v8_Context_Exit(context);
    const code = "(() => 1)";
    const text = ffi.v8_String_NewFromUtf8(isolate, code.ptr, code.len) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    // The wrapper takes this handle over.
    const function = ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
    errdefer ffi.v8_Value_Dispose(function);
    return CallbackWrapper.initFunction(std.testing.allocator, isolate, context, @ptrCast(function));
}

/// A callback wrapper made in one agent's realm is tracked by that agent -
/// not by the thread, not by the other agent on it - and its realm's end
/// releases its handles.
fn callbacksAreTheAgentsOwn() !void {
    const first = try newAgent();
    defer protocol.destroyAgent(first);
    const first_realm = try windowRealmIn(first);
    defer protocol.destroyWindowRealm(first_realm, .global_detached);
    const second = try newAgent();
    defer protocol.destroyAgent(second);
    const second_realm = try workerRealmIn(second);

    const before_first = callbacksTrackedBy(first);
    const wrapper = try wrapperIn(second, second_realm);
    // Freed by its owner whatever happens to its realm; with the agent
    // current, as the binding frees one.
    defer {
        const isolate: *ffi.Isolate = @ptrCast(@alignCast(second));
        ffi.v8_Isolate_Enter(isolate);
        wrapper.deinit();
        ffi.v8_Isolate_Exit(isolate);
    }
    try std.testing.expectEqual(@as(usize, 1), callbacksTrackedBy(second));
    try std.testing.expectEqual(before_first, callbacksTrackedBy(first));

    // The realm's end releases its handles and stops tracking it.
    protocol.destroyWorkerRealm(second_realm, null, null);
    try std.testing.expect(wrapper.isReleased());
    try std.testing.expectEqual(@as(usize, 0), callbacksTrackedBy(second));
    try std.testing.expectEqual(before_first, callbacksTrackedBy(first));
}

test "an agent tracks the callback wrappers of its realms, and no other agent's" {
    try runOnThread(callbacksAreTheAgentsOwn);
}

/// How many module records `agent` keeps (protocol_modules.Records, on its
/// record): one per distinct identity hash, which is one per record here.
fn modulesKeptBy(agent: *protocol.Agent) usize {
    const records = v8.protocol_agents.modulesOf(@ptrCast(@alignCast(agent))) orelse return 0;
    var count: usize = 0;
    var lists = records.valueIterator();
    while (lists.next()) |list| count += list.items.len;
    return count;
}

/// A module record parsed in one agent's realm is kept by that agent, and
/// by no other agent on the thread; releasing it takes it off.
fn modulesAreTheAgentsOwn() !void {
    const first = try newAgent();
    defer protocol.destroyAgent(first);
    const first_realm = try windowRealmIn(first);
    defer protocol.destroyWindowRealm(first_realm, .global_detached);
    const second = try newAgent();
    defer protocol.destroyAgent(second);
    const second_realm = try workerRealmIn(second);
    defer protocol.destroyWorkerRealm(second_realm, null, null);

    const before_first = modulesKeptBy(first);
    const parsed = try protocol.parseModule(second_realm, "export const x = 1;", .{}, "https://example.test/m.js", null);
    const record = switch (parsed) {
        .record => |r| r,
        .parse_error => |e| {
            e.release();
            return error.ParseFailed;
        },
    };
    try std.testing.expectEqual(@as(usize, 1), modulesKeptBy(second));
    try std.testing.expectEqual(before_first, modulesKeptBy(first));
    protocol.releaseModuleRecord(record);
    try std.testing.expectEqual(@as(usize, 0), modulesKeptBy(second));
}

test "an agent keeps the module records of its realms, and no other agent's" {
    try runOnThread(modulesAreTheAgentsOwn);
}

/// How many worker realms `agent` keeps a record of (worker_realm.Records).
fn workerRealmsKeptBy(agent: *protocol.Agent) usize {
    const records = v8.protocol_agents.workerRealmsOf(@ptrCast(@alignCast(agent))) orelse return 0;
    return records.items.len;
}

/// A worker realm is its agent's record, not its thread's: another agent on
/// the thread keeps none of it, and its end takes it off.
fn workerRealmsAreTheAgentsOwn() !void {
    const first = try newAgent();
    defer protocol.destroyAgent(first);
    const first_realm = try workerRealmIn(first);
    defer protocol.destroyWorkerRealm(first_realm, null, null);
    const second = try newAgent();
    defer protocol.destroyAgent(second);
    const second_realm = try workerRealmIn(second);
    try std.testing.expectEqual(@as(usize, 1), workerRealmsKeptBy(first));
    try std.testing.expectEqual(@as(usize, 1), workerRealmsKeptBy(second));
    protocol.destroyWorkerRealm(second_realm, null, null);
    try std.testing.expectEqual(@as(usize, 0), workerRealmsKeptBy(second));
    try std.testing.expectEqual(@as(usize, 1), workerRealmsKeptBy(first));
}

test "an agent keeps the records of its worker realms, and no other agent's" {
    try runOnThread(workerRealmsAreTheAgentsOwn);
}
