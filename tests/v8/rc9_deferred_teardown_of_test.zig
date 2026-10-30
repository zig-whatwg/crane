//! Lane refcount9: engine.deferredTeardownOf (refcount step 7) hands back the
//! deferred teardown queue an agent was created with
//! (AgentOptions.deferred_teardown) - the host's own pointer, BORROWED, as
//! agentHost hands back AgentOptions.host - and null for an agent made
//! without one. The DOM queues a tree whose counts reached zero there
//! (dom.refcount_teardown.queueOf): it must never find the queue by casting
//! the agent's host pointer, which is only its creator's type (tests make
//! agents with hosts of their own).
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agents.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
}

/// A host of the test's own type: not the html AgentHost.
const ForeignHost = struct { marker: u64 = 0x7263_395f_686f_7374 };

test "an agent made with a deferred teardown queue answers it; one made without answers null" {
    try setup();
    const no_hooks: protocol.HostHooks = .{};
    var queue = runtime.gc.DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var host: ForeignHost = .{};

    const with_queue = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = &host, .deferred_teardown = &queue });
    defer protocol.destroyAgent(with_queue);
    try testing.expectEqual(@as(?*runtime.gc.DeferredTeardown, &queue), protocol.deferredTeardownOf(with_queue));
    // The host is handed back as given, and is not the queue's owner.
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(&host)), protocol.agentHost(with_queue));

    const without = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = &host });
    defer protocol.destroyAgent(without);
    try testing.expect(protocol.deferredTeardownOf(without) == null);
    try testing.expectEqual(ForeignHost{}, host);
}
