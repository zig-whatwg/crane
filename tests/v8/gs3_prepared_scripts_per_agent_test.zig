//! HTML's JavaScript execution context stack is each agent's (ECMAScript 9.4:
//! "an agent ... has its own execution context stack"), so "clean up after
//! running script" step 3 - perform a microtask checkpoint when the stack is
//! empty - asks the cleaning agent's stack, and no other agent's (lane
//! gstate3). The V8 adapter counted the open "prepare to run script"s per
//! THREAD (protocol_scripts.zig `prepared_depth`): with one agent's prepared
//! realm open on the thread, another agent's script ran to its end and its
//! clean up skipped the checkpoint, so its promise reactions never ran.
//!
//! The test runs on a thread of its own: tests/v8 is one process, and an
//! earlier file may have left an isolate entered on the main one.

const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
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

const Reports = struct {
    count: usize = 0,
    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        std.debug.print("reported: {s}\n", .{info.message});
        self.count += 1;
    }
};

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

fn otherAgentsCleanUpChecksItsOwnStack() !void {
    const first = try newAgent();
    defer protocol.destroyAgent(first);
    const first_realm = try windowRealmIn(first);
    defer protocol.destroyWindowRealm(first_realm, .global_detached);

    const second = try newAgent();
    defer protocol.destroyAgent(second);
    const second_realm = try windowRealmIn(second);
    defer protocol.destroyWindowRealm(second_realm, .global_detached);

    var reports: Reports = .{};
    const reporter: protocol.Reporter = .{ .report = Reports.report, .host = &reports };

    // The first agent's realm is prepared to run script: a realm execution
    // context on the FIRST agent's stack, open while the second runs.
    const scope = try protocol.prepareToRunScript(first_realm);
    defer protocol.cleanUpAfterRunningScript(scope);

    // The second agent's script queues a promise reaction. Its stack is
    // empty once the script ends, so its clean up performs the checkpoint.
    try protocol.runClassicScript(second_realm, .{ .utf8 = "globalThis.ran = 0; Promise.resolve().then(() => { globalThis.ran = 1; });" }, "", null, reporter);
    const ran = try protocol.evaluateClassicScriptToString(second_realm, .{ .utf8 = "String(globalThis.ran)" }, "", null, std.testing.allocator, reporter);
    defer std.testing.allocator.free(ran);
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    try std.testing.expectEqualStrings("1", ran);
}

test "another agent's clean up after running script checkpoints when ITS stack is empty, whatever this agent has prepared" {
    try runOnThread(otherAgentsCleanUpChecksItsOwnStack);
}
