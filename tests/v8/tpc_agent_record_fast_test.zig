//! An agent's record and its host state, found with no lock where it is
//! read on the hot paths (lane tpc; the integrator's design (B), 2026-11-22):
//!
//! - A realm caches its agent's host state when the adapter makes it
//!   (runtime.ContextData.host_state), so html and the DOM reach their
//!   agent's state from the realm in one load (dom.agent_hosts.of /
//!   ofOwnAgent) - equal to what the agent registry answers under its lock
//!   (engine.hostStateOf), for a window realm on the agent's own thread, a
//!   worker's realm, and a second agent's realm on one thread; null for an
//!   agent made with no host state.
//! - Code only V8 reaches (callbacks, bindings) finds the agent's record
//!   with no lock on the thread that has the isolate entered
//!   (protocol_agents.fastRecordOf, through callbackRecordOf), and from the
//!   registry everywhere else (recordOf, which stays pure Zig so that an
//!   executable without V8 - the src/dom module's tests - still links).
//!
//! Before: every per-operation lookup - each [CEReactions] call's agent
//! state, a promise rejection's hook, an HTMLConstructor - took the
//! process-wide registry lock and a hash lookup (about 127 ns).

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const v8 = @import("v8");
const test_process = @import("test_process.zig");

const agents = v8.protocol_agents;
const no_hooks: engine.HostHooks = .{};

/// A stand-in for html's AgentHost: what the agent's host state points at
/// (aligned past anything AgentHost needs, for dom.agent_hosts' cast).
const Marker = struct { word: u64 align(64) = 0x7e57 };

fn newAgent(can_block: bool, state: ?*Marker) !*engine.Agent {
    return engine.createAgent(.{ .can_block = can_block, .from_snapshot = false, .hooks = &no_hooks, .host = null, .host_state = if (state) |s| @ptrCast(s) else null });
}

fn isolateOf(agent: *engine.Agent) *v8.ffi.Isolate {
    return @ptrCast(@alignCast(agent));
}

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

fn windowRealmIn(agent: *engine.Agent) !runtime.Context {
    return engine.createWindowRealm(&.{
        .agent_cluster_cross_origin_isolated = true,
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
}

/// The realm's cached host state is the registry's answer for its agent.
fn expectRealmCache(realm: runtime.Context, agent: *engine.Agent, want: ?*Marker) !void {
    const locked: ?*anyopaque = @ptrCast(engine.hostStateOf(agent));
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(want)), locked);
    try testing.expectEqual(locked, realm.host_state);
}

/// On a thread of its own (tests/v8 is one process; an earlier test may
/// have left an isolate entered on the main one): an agent made with no
/// isolate current is entered for its life; a second agent made on the same
/// thread is not.
fn ownThread() !void {
    var first_state: Marker = .{};
    const first = try newAgent(false, &first_state);
    defer engine.destroyAgent(first);
    const first_isolate = isolateOf(first);
    const locked = agents.recordOf(first_isolate) orelse return error.NoRecord;
    // The agent's own thread: its record with no lock.
    try testing.expectEqual(@as(?*agents.AgentRecord, locked), agents.fastRecordOf(first_isolate));
    try testing.expectEqual(@as(?*agents.AgentRecord, locked), agents.callbackRecordOf(first_isolate));
    // Its window realm caches its host state.
    const first_realm = try windowRealmIn(first);
    defer engine.destroyWindowRealm(first_realm, .global_detached);
    try expectRealmCache(first_realm, first, &first_state);

    // A second agent on the thread, made while the first is current, with
    // no host state: not this thread's current isolate, so no fast record -
    // the registry's - until it is entered.
    const second = try newAgent(false, null);
    defer engine.destroyAgent(second);
    const second_isolate = isolateOf(second);
    const second_locked = agents.recordOf(second_isolate) orelse return error.NoRecord;
    try testing.expectEqual(@as(?*agents.AgentRecord, null), agents.fastRecordOf(second_isolate));
    try testing.expectEqual(@as(?*agents.AgentRecord, second_locked), agents.callbackRecordOf(second_isolate));
    v8.ffi.v8_Isolate_Enter(second_isolate);
    try testing.expectEqual(@as(?*agents.AgentRecord, second_locked), agents.fastRecordOf(second_isolate));
    v8.ffi.v8_Isolate_Exit(second_isolate);
    // Its realm: no host state to cache, which is the registry's answer.
    const second_realm = try windowRealmIn(second);
    defer engine.destroyWindowRealm(second_realm, .global_detached);
    try expectRealmCache(second_realm, second, null);

    // A realm a host made by hand and gave the agent after (an engine-less
    // test's ContextData, as tests/html/xhr_engine_less_owner_test makes):
    // nothing cached, and the DOM's answer is still the agent's host state,
    // from the registry.
    var by_hand = try runtime.createNullContext(std.heap.c_allocator);
    defer by_hand.deinit();
    by_hand.agent = first;
    try testing.expectEqual(@as(?*anyopaque, null), by_hand.host_state);
    try testing.expectEqual(@intFromPtr(&first_state), @intFromPtr(dom.agent_hosts.ofOwnAgent(&by_hand) orelse return error.NoHost));
    try testing.expectEqual(@intFromPtr(&first_state), @intFromPtr(dom.agent_hosts.ofOwnAgent(first_realm) orelse return error.NoHost));
    try testing.expectEqual(@intFromPtr(&first_state), @intFromPtr(dom.agent_hosts.of(first_realm) orelse return error.NoHost));

    // A third agent on the thread, with host state: its realm caches its
    // own agent's, not the thread's current one's.
    var third_state: Marker = .{};
    const third = try newAgent(false, &third_state);
    defer engine.destroyAgent(third);
    const third_realm = try windowRealmIn(third);
    defer engine.destroyWindowRealm(third_realm, .global_detached);
    try expectRealmCache(third_realm, third, &third_state);
}

test "an agent's own thread finds its record with no lock and its window realm caches its host state; a second agent's on the thread comes from the registry until entered, and its realm caches its own" {
    test_process.start();
    interfaces.process_hooks.startHooksForTest();
    var failure: ?anyerror = null;
    const Run = struct {
        fn main(out: *?anyerror) void {
            ownThread() catch |err| {
                out.* = err;
            };
        }
    };
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Run.main, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "an agent's end clears its fast record: from then on neither path finds it" {
    test_process.start();
    var failure: ?anyerror = null;
    const Run = struct {
        fn body() !void {
            // The thread's own agent, entered for its life, and a second one
            // whose end the test begins by hand: destroyAgent reads whether
            // it entered the agent for its life from the record, which an
            // agent whose end has begun no longer answers - so the second,
            // not entered for life, is the one forgotten early.
            const first = try newAgent(false, null);
            defer engine.destroyAgent(first);
            const agent = try newAgent(false, null);
            defer engine.destroyAgent(agent);
            const isolate = isolateOf(agent);
            v8.ffi.v8_Isolate_Enter(isolate);
            defer v8.ffi.v8_Isolate_Exit(isolate);
            try testing.expect(agents.fastRecordOf(isolate) != null);
            // The agent's end begins (forgetAgent; destroyAgent repeats it
            // as a no-op): entered, its fast record is gone too.
            agents.forgetAgent(agent);
            try testing.expectEqual(@as(?*agents.AgentRecord, null), agents.fastRecordOf(isolate));
            try testing.expectEqual(@as(?*agents.AgentRecord, null), agents.callbackRecordOf(isolate));
            try testing.expectEqual(@as(?*agents.AgentRecord, null), agents.recordOf(isolate));
        }
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

/// A worker agent - made as worker_host makes one: [[CanBlock]] true - with
/// its worker realm, entered on a thread of its own. It lives until
/// `finish`.
const Worker = struct {
    thread: std.Thread = undefined,
    state: Marker = .{},
    agent: ?*engine.Agent = null,
    fast: ?*agents.AgentRecord = null,
    realm_state: ?*anyopaque = null,
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
        const agent = try newAgent(true, &self.state);
        defer engine.destroyAgent(agent);
        const made = try engine.createWorkerRealm(agent, &.{ .agent_cluster_cross_origin_isolated = true, .global = .dedicated, .url = "https://agent-record.test/worker.js", .allocator = std.heap.c_allocator, .timer = null, .event_loop = @import("inline_task_loop.zig").eventLoop() });
        defer engine.destroyWorkerRealm(made.realm, null, null);
        self.agent = agent;
        self.fast = agents.fastRecordOf(isolateOf(agent));
        self.realm_state = made.realm.host_state;
        self.ready.store(true, .release);
        while (!self.finish_now.load(.acquire)) std.Thread.yield() catch {};
    }
};

fn mainReadsWorker() !void {
    var worker: Worker = .{};
    try worker.start();
    defer worker.finish() catch {};
    if (worker.failure) |err| return err;
    const agent = worker.agent orelse return error.NoAgent;
    const isolate = isolateOf(agent);
    const locked = agents.recordOf(isolate) orelse return error.NoRecord;
    // On its own thread, with no lock: the registry's record.
    try testing.expectEqual(@as(?*agents.AgentRecord, locked), worker.fast);
    // Its worker realm cached its host state: the registry's answer.
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(&worker.state)), worker.realm_state);
    try testing.expectEqual(worker.realm_state, @as(?*anyopaque, @ptrCast(engine.hostStateOf(agent))));
    // From here, where the worker's isolate is not entered: no fast record,
    // the registry's through callbackRecordOf.
    try testing.expectEqual(@as(?*agents.AgentRecord, null), agents.fastRecordOf(isolate));
    try testing.expectEqual(@as(?*agents.AgentRecord, locked), agents.callbackRecordOf(isolate));
}

test "a worker thread finds its agent's record with no lock and its worker realm caches its host state; the main thread reading the worker's agent takes the registry's" {
    test_process.start();
    interfaces.process_hooks.startHooksForTest();
    try mainReadsWorker();
}
