//! Pending media selection belongs to the element that requested it.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn makeWindow(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
    return interfaces.Window.init(testing.allocator, realm) catch null;
}

fn audio(realm: runtime.Context) !*runtime.Instance {
    const element = try interfaces.HTMLAudioElement.init(testing.allocator, realm);
    errdefer dom.node_creation.destroyUninserted(element);
    try dom.node_creation.setElementNames(element, "http://www.w3.org/1999/xhtml", "audio");
    return element;
}

const Observe = struct {
    element: *runtime.Instance,
    state: ?u16 = null,

    fn run(data: ?*anyopaque) void {
        const self: *Observe = @ptrCast(@alignCast(data.?));
        self.state = interfaces.HTMLMediaElement.get_networkState(self.element) catch null;
    }
};

fn selectionOrder() !void {
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    interfaces.process_hooks.startHooksForTest();
    try engine.initializeEngine(.{});
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .allocator = testing.allocator, .hooks = &.{} });
    defer engine.destroyAgent(agent);
    const realm = try engine.createWindowRealm(&.{
        .agent = agent,
        .allocator = testing.allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "http://parser.test",
        .create_global_object = makeWindow,
    });
    defer engine.destroyWindowRealm(realm, .global_detached);

    const previous = try audio(realm);
    const generation = runtime.SlabAllocator.generationOf(previous);
    try interfaces.HTMLMediaElement.call_load(previous);
    dom.node_creation.destroyUninserted(previous);
    try testing.expectEqual(@as(u64, 0), runtime.SlabAllocator.generationOf(previous));

    // This realm has no event loop (a host without one): resource selection
    // keeps HTML's stable-state microtask there. With an event loop it runs
    // in a media element task instead, as the browsers do
    // (HTMLMediaElement.zig awaitSelection); this test pins the fallback.
    try testing.expect(realm.getOptionalEventLoop() == null);

    const next = try audio(realm);
    defer dom.node_creation.destroyUninserted(next);
    // The allocator reuses native slots; the pending operation must retain
    // its original identity even when the following element has the same type.
    try testing.expectEqual(previous, next);
    try testing.expect(generation != runtime.SlabAllocator.generationOf(next));
    var observation = Observe{ .element = next };
    try engine.queueMicrotask(agent, Observe.run, &observation);
    try interfaces.HTMLMediaElement.call_load(next);
    try testing.expectEqual(@as(u16, 3), try interfaces.HTMLMediaElement.get_networkState(next));
    try engine.performMicrotaskCheckpoint(agent);
    // The new element's own stable selection follows the observer in FIFO
    // order. The old operation must not select its resource before then.
    try testing.expectEqual(@as(?u16, 3), observation.state);
    try testing.expectEqual(@as(u16, 0), try interfaces.HTMLMediaElement.get_networkState(next));
}

test "parser media teardown does not advance another element's queued selection" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            selectionOrder() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

const Activity = @import("html").media_runtime.Activity;
const Counts = struct {
    called: usize = 0,
    aborted: usize = 0,
    freed: usize = 0,
    observed_realm: bool = true,
    survived_callback: bool = true,
};
const Record = struct {
    activity: Activity,
    counts: *Counts,
    realm: runtime.Context,
    retire_in_callback: bool = false,

    fn init(instance: *runtime.Instance, counts: *Counts) !*Record {
        const self = try testing.allocator.create(Record);
        self.* = .{
            .activity = .{ .allocator = testing.allocator, .instance = instance, .owner = self, .run = runTask, .abort = abort, .free = free },
            .counts = counts,
            .realm = instance.ctx,
        };
        return self;
    }
    fn runTask(_: *anyopaque, _: *@import("html").media_runtime.Task) void {}
    fn abort(data: *anyopaque) void {
        const self: *Record = @ptrCast(@alignCast(data));
        self.counts.aborted += 1;
    }
    fn free(data: *anyopaque) void {
        const self: *Record = @ptrCast(@alignCast(data));
        self.counts.freed += 1;
        self.activity.microtasks.deinit(testing.allocator);
        testing.allocator.destroy(self);
    }
    fn run(data: *anyopaque, _: u64) void {
        const self: *Record = @ptrCast(@alignCast(data));
        self.counts.called += 1;
        self.counts.observed_realm = self.counts.observed_realm and engine.currentRealm() == self.realm;
        if (!self.retire_in_callback) return;
        const node = self.activity.instance.?;
        self.activity.detach();
        dom.node_creation.destroyUninserted(node);
        engine.destroyWindowRealm(self.realm, .global_detached);
        self.activity.maybeFree();
        // The running continuation must hold this native record even after
        // the second continuation drops and the realm has retired.
        self.counts.survived_callback = self.counts.freed == 0;
    }
};

const Ending = enum { checkpoint, realm, self_retirement };
fn continuationEnd(ending: Ending) !void {
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    interfaces.process_hooks.startHooksForTest();
    try engine.initializeEngine(.{});
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .allocator = testing.allocator, .hooks = &.{} });
    defer engine.destroyAgent(agent);
    const parent = try engine.createWindowRealm(&.{
        .agent = agent,
        .allocator = testing.allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "http://parser.test",
        .create_global_object = makeWindow,
    });
    defer engine.destroyWindowRealm(parent, .global_detached);
    const realm = try engine.createWindowRealm(&.{
        .agent = agent,
        .allocator = testing.allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "http://parser.test",
        .create_global_object = makeWindow,
        .parent = parent,
    });
    var ended = false;
    defer if (!ended) engine.destroyWindowRealm(realm, .global_detached);
    const node = try audio(realm);
    var counts = Counts{};
    const record = try Record.init(node, &counts);
    record.retire_in_callback = ending == .self_retirement;
    try record.activity.stable(1, Record.run);
    try record.activity.stable(2, Record.run);
    try testing.expect(record.activity.hasStable(1));
    try testing.expect(record.activity.hasStable(2));
    if (ending == .checkpoint or ending == .realm) {
        record.activity.detach();
        dom.node_creation.destroyUninserted(node);
        record.activity.maybeFree();
        try testing.expectEqual(@as(usize, 0), counts.freed);
    }
    if (ending == .realm) {
        engine.destroyWindowRealm(realm, .global_detached);
        ended = true;
    }
    try engine.performMicrotaskCheckpoint(agent);
    if (ending == .self_retirement) ended = true;
    try testing.expectEqual(@as(usize, if (ending == .self_retirement) 1 else 0), counts.called);
    try testing.expectEqual(@as(usize, 1), counts.freed);
    try testing.expectEqual(@as(usize, 0), counts.aborted);
    try testing.expect(counts.observed_realm);
    try testing.expect(counts.survived_callback);
}

fn checkEnd(ending: Ending) !void {
    const Run = struct {
        fn run(value: Ending, result: *?anyerror) void {
            continuationEnd(value) catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{ ending, &result });
    thread.join();
    if (result) |err| return err;
}

test "detached stable owners survive until their queued continuations finish" {
    try checkEnd(.checkpoint);
}

test "realm retirement releases detached pending stable continuations" {
    try checkEnd(.realm);
}

test "a stable callback can retire its own realm before releasing its owner" {
    try checkEnd(.self_retirement);
}

fn failedRegistration(allocator: std.mem.Allocator, node: *runtime.Instance) !void {
    var counts = Counts{};
    const Noop = struct {
        fn task(_: *anyopaque, _: *@import("html").media_runtime.Task) void {}
        fn owner(_: *anyopaque) void {}
        fn stable(_: *anyopaque, _: u64) void {}
    };
    var activity = Activity{
        .allocator = allocator,
        .instance = node,
        .owner = &counts,
        .run = Noop.task,
        .abort = Noop.owner,
        .free = Noop.owner,
    };
    defer activity.microtasks.deinit(allocator);
    activity.stable(7, Noop.stable) catch |err| {
        try testing.expectEqual(@as(usize, 0), activity.microtasks.items.len);
        try testing.expectEqual(@as(usize, 0), activity.running_stable);
        if (err == error.OutOfMemory) return err;
        // An engine-less realm rejects registration after the host payload
        // has been linked. Its failed call retains no callback ownership.
        try testing.expectEqual(error.OperationFailed, err);
        return;
    };
    return error.ExpectedRegistrationFailure;
}

test "stable registration failures roll back their allocations and pending activity" {
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    interfaces.process_hooks.startHooksForTest();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const node = try audio(&context);
    defer dom.node_creation.destroyUninserted(node);
    try testing.checkAllAllocationFailures(testing.allocator, failedRegistration, .{node});
}
