//! The adapter keeps an agent's Window realms on the agent, and their storage
//! goes with it.
//!
//! protocol_realms.zig kept every Window realm's state in a `threadlocal`
//! map on c_allocator. Each realm's end removed its entry, but nothing freed
//! the map's capacity, so a thread that ever made a Window realm left that
//! storage behind when it ended: 192 B a thread, the one ROOT LEAK under
//! `leaks --atExit` of Codex row 56's fresh-thread test
//! (HashMapUnmanaged(Context, *WindowRealmState).put <- createWindowRealm).
//! AGENTS.md "Global state": state has an owner, never a thread. The map is
//! the agent's now (AgentRecord.window_realms, as Blink keeps per-isolate
//! maps on V8PerIsolateData), freed when the agent ends.
//!
//! The first test is the measurement's workload: Window realms made and
//! ended on fresh threads, each with its own agent. It passes on any tree;
//! `leaks --atExit` over this file's binary names one 192-B root per thread
//! on the old one and none now. The others pin who owns the map.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const protocol = @import("engine");
const interfaces = @import("interfaces");

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

fn setup() !void {
    try protocol.initializeEngine(.{});
    interfaces.process_hooks.startHooksForTest();
    if (runtime.BrowserScope.standalone() == null) runtime.initializeRuntime(std.heap.page_allocator);
}

const no_hooks: protocol.HostHooks = .{};

fn newAgent() !*protocol.Agent {
    return protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
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

/// One thread's life: an agent, a Window realm in it, both ended.
fn threadMain(failure: *?anyerror) void {
    run() catch |err| {
        failure.* = err;
    };
}

fn run() !void {
    const agent = try newAgent();
    defer protocol.destroyAgent(agent);
    const realm = try windowRealmIn(agent);
    protocol.destroyWindowRealm(realm, .global_detached);
}

test "Window realms made and ended on fresh threads leave nothing of their threads behind" {
    try setup();
    var failures: [8]?anyerror = @splat(null);
    for (&failures) |*failure| {
        const thread = try std.Thread.spawn(.{}, threadMain, .{failure});
        thread.join();
    }
    for (failures) |failure| if (failure) |err| return err;
}

const Realms = struct {
    agent: *protocol.Agent,

    fn count(self: Realms) usize {
        return v8.protocol_agents.recordOf(@ptrCast(@alignCast(self.agent))).?.window_realms.count();
    }

    fn contains(self: Realms, realm: runtime.Context) bool {
        return v8.protocol_agents.recordOf(@ptrCast(@alignCast(self.agent))).?.window_realms.contains(realm);
    }
};

fn realmsOf(agent: *protocol.Agent) Realms {
    return .{ .agent = agent };
}

fn ownership() !void {
    const first = try newAgent();
    defer protocol.destroyAgent(first);
    const realm = try windowRealmIn(first);
    // A second agent on the same thread, made while the first's realm lives
    // (and is entered): it keeps nothing of that realm. One agent with a live
    // Window realm a thread is what a Browser makes; a second one's realm
    // would be entered under the first's.
    const second = try newAgent();
    defer protocol.destroyAgent(second);

    // The realm is its agent's, and only its agent's.
    try testing.expectEqual(@as(usize, 1), realmsOf(first).count());
    try testing.expect(realmsOf(first).contains(realm));
    try testing.expectEqual(@as(usize, 0), realmsOf(second).count());
    try testing.expect(!realmsOf(second).contains(realm));

    protocol.destroyWindowRealm(realm, .global_detached);
    // Its end takes it out of its agent's map; the map's storage goes with
    // the agent (forgetAgent), whichever thread ends it.
    try testing.expectEqual(@as(usize, 0), realmsOf(first).count());
}

test "an agent keeps its own Window realms, not its thread's" {
    try setup();
    var failure: ?anyerror = null;
    const Run = struct {
        fn main(out: *?anyerror) void {
            ownership() catch |err| {
                out.* = err;
            };
        }
    };
    // A thread of its own: tests/v8 is one process, and an earlier file may
    // have left an isolate entered on the main one.
    const thread = try std.Thread.spawn(.{}, Run.main, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "a bare isolate - not an agent createAgent made - can make no Window realm" {
    try setup();
    var failure: ?anyerror = null;
    const Run = struct {
        fn main(out: *?anyerror) void {
            bare() catch |err| {
                out.* = err;
            };
        }
        fn bare() !void {
            const ffi = v8.ffi;
            const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
            defer ffi.v8_Isolate_Dispose(isolate);
            try testing.expectError(error.OperationFailed, windowRealmIn(@ptrCast(isolate)));
        }
    };
    const thread = try std.Thread.spawn(.{}, Run.main, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
