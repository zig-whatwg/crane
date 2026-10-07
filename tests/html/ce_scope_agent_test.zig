//! The generated bracket's end needs the agent, not a surviving receiver or realm.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const ce = @import("dom").custom_elements;
const AgentHost = @import("html_core").agent_host.AgentHost;

fn makeWindow(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
    return interfaces.Window.init(testing.allocator, realm) catch null;
}
fn report(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}
fn acquire(_: void, element: *runtime.Instance) !engine.Owned {
    return engine.retainValue(element.ctx, .{ .instance = element });
}

fn exercise() !void {
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    interfaces.process_hooks.startHooksForTest();
    try engine.initializeEngine(.{});
    var host = AgentHost.init(testing.allocator);
    defer host.deinit();
    const agent = try engine.createAgent(.{
        .can_block = false,
        .from_snapshot = false,
        .allocator = testing.allocator,
        .host = &host,
        .hooks = &.{},
    });
    defer engine.destroyAgent(agent);
    defer host.custom_elements.releasePending();
    const parent = try engine.createWindowRealm(&.{
        .agent = agent,
        .allocator = testing.allocator,
        .from_snapshot = false,
        .timer = null,
        .create_global_object = makeWindow,
    });
    defer engine.destroyWindowRealm(parent, .global_detached);
    const retired = try engine.createWindowRealm(&.{
        .agent = agent,
        .allocator = testing.allocator,
        .from_snapshot = false,
        .timer = null,
        .parent = parent,
        .create_global_object = makeWindow,
    });
    var realm_ended = false;
    defer if (!realm_ended) engine.destroyWindowRealm(retired, .global_detached);

    const callback = try engine.evaluateClassicScript(parent, .{
        .utf8 = "globalThis.seen = 0; (function () { seen++; })",
    }, "ce-scope-agent.js", null, .{ .report = report });
    defer callback.release();
    const element = try interfaces.HTMLElement.init(testing.allocator, parent);
    const element_root = try engine.retainValue(parent, .{ .instance = element });
    defer element_root.release();
    var reaction = try ce.Reaction.initCallback(testing.allocator, parent, .{
        .function = callback,
        .context = parent,
    }, .connected, .none);
    var queued = false;
    defer if (!queued) reaction.deinit();

    // begin needs only the Instance's context. Explicitly destroy this native
    // receiver before end, independently of the adapter's wrapper cleanup.
    const receiver = try testing.allocator.create(runtime.Instance);
    receiver.* = .{ .vtable = undefined, .state = undefined, .ctx = retired };
    const scope = runtime.CEReactions.begin(receiver);
    testing.allocator.destroy(receiver);
    var scope_ended = false;
    defer if (!scope_ended) runtime.CEReactions.end(scope);
    try testing.expectEqual(@as(?*runtime.Agent, agent), scope.agent);
    try testing.expectEqual(@as(usize, 1), host.custom_elements.queues.depth);
    _ = try host.custom_elements.enqueue({}, element, parent, reaction, acquire);
    queued = true;

    engine.destroyWindowRealm(retired, .global_detached);
    realm_ended = true;
    try testing.expect(!retired.hasEngine());
    runtime.CEReactions.end(scope);
    scope_ended = true;
    try testing.expectEqual(@as(usize, 0), host.custom_elements.queues.depth);
    const observed = try engine.evaluateClassicScript(parent, .{ .utf8 = "seen === 1" }, "ce-scope-observed.js", null, .{ .report = report });
    defer observed.release();
    try testing.expect(engine.toBoolean(parent, observed.value));
}

test "CE scope: end invokes a live realm after the captured receiver and realm end" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
