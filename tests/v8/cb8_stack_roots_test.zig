//! Refcount step 8's stack roots (runtime.gc.StackRoot, lane rc8): a native
//! frame - an event dispatch in flight - puts a root on its agent's deferred
//! teardown queue, and the engine's collector walks the queue's roots in a
//! full collection's atomic pause (V8: node_wrappers.traceKeeps, the anchors'
//! registry's keep walk), so the frame's nodes keep their wrappers - and the
//! listeners traced from them - while it runs.
//!
//! The pause runs with the mutator stopped and may run on a thread that holds
//! nothing; a lock taken there waits for whichever thread holds it, and the
//! agents' lock is the process's (every Browser's and worker's thread takes
//! it). So the walk reaches the queue as a binding entry does - the isolate's
//! own adapter storage, a data slot - and never through the agents' records.
//! This pins it: another thread holds the agents' lock for the whole
//! collection, and the root's trace must run while it does.
const std = @import("std");
const test_process = @import("test_process.zig");
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

/// A root whose trace records that it ran, and whether the helper thread
/// held the agents' lock at that moment. Atomics only: it runs in the pause.
const Probe = struct {
    root: runtime.gc.StackRoot = .{ .trace = trace },
    holding: *const std.atomic.Value(bool),
    ran: std.atomic.Value(bool) = .init(false),
    ran_while_held: std.atomic.Value(bool) = .init(false),

    fn trace(root: *runtime.gc.StackRoot, tracer: *protocol.Tracer) void {
        _ = tracer;
        const self: *Probe = @fieldParentPtr("root", root);
        self.ran_while_held.store(self.holding.load(.acquire), .release);
        self.ran.store(true, .release);
    }
};

/// Holds the agents' lock, from when the test says `go` until the probe's
/// trace ran or `bound_ms` passed - a pause that waited for the lock then
/// gets it, and the test fails rather than hangs.
const Holder = struct {
    go: std.atomic.Value(bool) = .init(false),
    holding: std.atomic.Value(bool) = .init(false),
    probe: *const Probe,
    const bound_ms = 2000;

    fn run(self: *Holder) void {
        var waited: u64 = 0;
        while (!self.go.load(.acquire) and waited < 10 * bound_ms) : (waited += 1) pause();
        v8.protocol_agents.lockAgentsForTest();
        self.holding.store(true, .release);
        waited = 0;
        while (!self.probe.ran.load(.acquire) and waited < bound_ms) : (waited += 1) pause();
        self.holding.store(false, .release);
        v8.protocol_agents.unlockAgentsForTest();
    }

    fn pause() void {
        std.Io.sleep(std.testing.io, .fromMilliseconds(1), .awake) catch {};
    }
};

/// Inside the realm - entering it consults the agents' records, which is
/// not the collector's business - the helper takes the lock, and only then
/// does a full collection run: the engine's own, as a host asks for one
/// between its steps, with no drain of the queue after it (a drain finds its
/// queue through the agents' records, outside the pause).
const Collect = struct {
    holder: *Holder,
    isolate: *v8.ffi.Isolate,

    fn steps(data: ?*anyopaque) void {
        const self: *Collect = @ptrCast(@alignCast(data.?));
        self.holder.go.store(true, .release);
        var spins: u32 = 0;
        while (!self.holder.holding.load(.acquire) and spins < 2000) : (spins += 1) Holder.pause();
        v8.ffi.v8_Isolate_RequestGarbageCollection(self.isolate);
    }
};

test "a full collection walks the agent's stack roots in its atomic pause without the agents' lock" {
    test_process.start();
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const realm = try protocol.createWindowRealm(&.{
        .agent_cluster_cross_origin_isolated = false,
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
    defer protocol.destroyWindowRealm(realm, .global_detached);
    const isolate: *v8.ffi.Isolate = @ptrCast(@alignCast(agent));
    // The anchors' registry - whose Trace runs the keep walk in every full
    // collection - exists from the agent's first wrap; made here directly.
    v8.node_wrappers.prepareHolderTracing(isolate);
    const queue = protocol.deferredTeardownOf(agent) orelse return error.NoQueue;

    var holder: Holder = .{ .probe = undefined };
    var probe: Probe = .{ .holding = &holder.holding };
    holder.probe = &probe;
    queue.pushStackRoot(&probe.root);
    defer queue.removeStackRoot(&probe.root);

    const thread = try std.Thread.spawn(.{}, Holder.run, .{&holder});
    var collect: Collect = .{ .holder = &holder, .isolate = isolate };
    const ran = protocol.runInRealm(realm, Collect.steps, &collect);
    // The helper ends whatever happened: a failure to enter still says go.
    holder.go.store(true, .release);
    thread.join();
    try ran;

    try testing.expect(probe.ran.load(.acquire));
    try testing.expect(probe.ran_while_held.load(.acquire));
}

test "a stack root leaves the agent's list from anywhere in it, and a second removal changes nothing" {
    var queue: runtime.gc.DeferredTeardown = .init(testing.allocator);
    defer queue.deinit();
    const Root = struct {
        fn trace(_: *runtime.gc.StackRoot, _: *protocol.Tracer) void {}
    };
    var a: runtime.gc.StackRoot = .{ .trace = Root.trace };
    var b: runtime.gc.StackRoot = .{ .trace = Root.trace };
    var c: runtime.gc.StackRoot = .{ .trace = Root.trace };
    queue.pushStackRoot(&a);
    queue.pushStackRoot(&b);
    queue.pushStackRoot(&c);
    // The middle one first: a dispatch's end is not always the innermost.
    queue.removeStackRoot(&b);
    try testing.expectEqual(@as(?*runtime.gc.StackRoot, &c), queue.stack_roots);
    try testing.expectEqual(@as(?*runtime.gc.StackRoot, &a), c.next);
    queue.removeStackRoot(&b);
    queue.removeStackRoot(&c);
    queue.removeStackRoot(&a);
    try testing.expectEqual(@as(?*runtime.gc.StackRoot, null), queue.stack_roots);
}
