//! Browser's pre-agent cleanup must release a retired realm's owned callback
//! while never following its dead element pointer. Protocol operations only.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const ce = @import("dom").custom_elements;

fn globalObject(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
    return interfaces.Window.init(testing.allocator, realm) catch null;
}

fn report(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}

fn liveHandles() !i64 {
    if (engine.capabilities.diagnostic_counters == .unsupported) return error.SkipZigTest;
    const counters = try engine.diagnosticCounters(testing.allocator);
    defer testing.allocator.free(counters);
    for (counters) |counter| {
        if (std.mem.eql(u8, counter.name, "global_handle_bytes")) return counter.value;
    }
    return error.SkipZigTest;
}

fn inertRoot(_: void, _: *runtime.Instance) !engine.Owned {
    // The poisoned element stands for an Instance that the realm already
    // freed. The reaction's actual callback is still an owned engine value.
    return .{ .value = .null };
}

fn exercise() !void {
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    interfaces.process_hooks.startHooksForTest();
    try engine.initializeEngine(.{});
    var state = ce.AgentState.init(testing.allocator);
    defer state.deinit();
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &.{}, .allocator = testing.allocator });
    defer engine.destroyAgent(agent);
    defer state.releasePending();
    const parent = try engine.createWindowRealm(&.{
        .agent = agent,
        .allocator = testing.allocator,
        .from_snapshot = false,
        .timer = null,
        .create_global_object = globalObject,
    });
    defer engine.destroyWindowRealm(parent, .global_detached);
    const retired = try engine.createWindowRealm(&.{
        .agent = agent,
        .allocator = testing.allocator,
        .from_snapshot = false,
        .timer = null,
        .parent = parent,
        .create_global_object = globalObject,
    });
    var ended = false;
    defer if (!ended) engine.destroyWindowRealm(retired, .global_detached);
    const callback_value = try engine.evaluateClassicScript(retired, .{ .utf8 = "(function () { throw new Error('must not run'); })" }, "ce-retired.js", null, .{ .report = report });
    defer callback_value.release();
    engine.destroyWindowRealm(retired, .global_detached);
    ended = true;
    try testing.expect(!retired.hasEngine());

    // This is the state a missed realm-cleanup callback leaves. Holding the
    // source function separately makes the baseline stable across the drop.
    const baseline = try liveHandles();
    var reaction = try ce.Reaction.initCallback(testing.allocator, parent, .{
        .function = callback_value,
        .context = retired,
    }, .connected, .none);
    const dead_element: *runtime.Instance = @ptrFromInt(0x1000);
    _ = state.enqueue({}, dead_element, retired, reaction, inertRoot) catch |err| {
        reaction.deinit();
        return err;
    };
    const returned = try engine.retainValue(parent, callback_value.value);
    _ = state.returns.append(retired, returned) catch |err| {
        returned.release();
        return err;
    };
    try testing.expect(try liveHandles() > baseline);
    state.releasePending();
    try testing.expectEqual(baseline, try liveHandles());
    // It is idempotent, as AgentHost.deinit follows the pre-agent drop.
    state.releasePending();
    try testing.expectEqual(baseline, try liveHandles());

    // An explicitly destroyed clone can free its slot while this realm is
    // still live. Cancelling releases both its element root and callback.
    const Hold = struct {
        realm: runtime.Context,
        value: runtime.JSValue,
        fn acquire(self: @This(), _: *runtime.Instance) !engine.Owned {
            return engine.retainValue(self.realm, self.value);
        }
        fn never(_: void, _: *runtime.Instance, _: *ce.Reaction) void {
            unreachable;
        }
    };
    state.begin();
    for (0..2) |_| {
        var queued = try ce.Reaction.initCallback(testing.allocator, parent, .{
            .function = callback_value,
            .context = retired,
        }, .connected, .none);
        _ = state.enqueue(Hold{ .realm = parent, .value = callback_value.value }, dead_element, parent, queued, Hold.acquire) catch |err| {
            queued.deinit();
            return err;
        };
        try testing.expect(try liveHandles() > baseline);
        state.cancelElement(dead_element);
        state.cancelElement(dead_element);
        try testing.expectEqual(baseline, try liveHandles());
    }
    state.end({}, Hold.never);
    try testing.expectEqual(baseline, try liveHandles());
}

test "CE cleanup: retired realm callbacks release their live handles without touching dead instances" {
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
