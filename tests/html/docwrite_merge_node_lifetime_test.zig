//! Merge controls for native storage ownership versus a retired originating realm.
//! A retired realm retains its agent identity, even after its engine context goes.
//! It can ask no wrapper cache, so a torn-down node's storage stays for whatever
//! wrapper may reach it - unless the slot's wrap mark proves none can
//! ([wrap_tracking]: never wrapped, or its last wrapper released), when it goes
//! back at once, as a native context's does (lane pageretention1: frames'
//! retired realms kept every document's html, head and body).
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const Scenario = enum { native, retired, retired_wrapped, coordinated };

fn exercise(scenario: Scenario) !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(std.testing.allocator, .{});
    defer context.deinit();

    // Model retireEntry's inert ContextData without starting an engine: its
    // agent survives, while engine_ctx and its originating wrapper cache do
    // not. This opaque marker is only compared to null, never dereferenced.
    var agent_marker: u64 = 0;
    if (scenario == .retired or scenario == .retired_wrapped) context.agent = @ptrCast(&agent_marker);
    try std.testing.expect(!context.hasEngine());

    var coordinator = runtime.cleanup_coordinator.CleanupCoordinator.init(std.testing.allocator);
    defer coordinator.deinit();
    runtime.cleanup_coordinator.setActiveCoordinator(&coordinator);
    defer runtime.cleanup_coordinator.setActiveCoordinator(null);

    const slots_before = runtime.BrowserScope.standalone().?.slab.stats().currently_allocated;
    const bytes_before = runtime.BrowserScope.standalone().?.arena.stats().bytes_in_use;
    const root = try interfaces.DocumentFragment.init(std.testing.allocator, &context);
    errdefer dom.node_creation.destroyUninserted(root);
    const child = try interfaces.Text.init(std.testing.allocator, &context);
    const root_generation = runtime.SlabAllocator.generationOf(root);
    const child_generation = runtime.SlabAllocator.generationOf(child);
    // Runtime storage release accounts for each Instance's FullState through
    // this metadata. Registry resources use the same arena but are cleaned
    // before the existing owner releases these two state blocks.
    const root_state_bytes = root.vtable.state_size;
    const child_state_bytes = child.vtable.state_size;
    defer {
        // Failure cleanup respects whichever path still owns each slot. Free
        // the root first, because an intact root still owns its descendants.
        if (runtime.SlabAllocator.generationOf(root) == root_generation) {
            if (runtime.instance_lifecycle.isCleanedUp(root)) runtime.gc.releaseStorage(root) else runtime.Instance.deinit(root);
        }
        if (runtime.SlabAllocator.generationOf(child) == child_generation) {
            if (runtime.instance_lifecycle.isCleanedUp(child)) runtime.gc.releaseStorage(child) else runtime.Instance.deinit(child);
        }
    }
    try std.testing.expect(root_state_bytes > 0 and child_state_bytes > 0);
    // A wrapper of some realm reached them: nothing proves them unreachable.
    if (scenario == .retired_wrapped) {
        runtime.instance_lifecycle.markWrapped(root);
        runtime.instance_lifecycle.markWrapped(child);
    }
    _ = try interfaces.Node.call_appendChild(root, child);
    const slots_allocated = runtime.BrowserScope.standalone().?.slab.stats().currently_allocated;
    const bytes_allocated = runtime.BrowserScope.standalone().?.arena.stats().bytes_in_use;
    try std.testing.expectEqual(slots_before + 2, slots_allocated);
    try std.testing.expect(bytes_allocated > bytes_before);

    if (scenario == .coordinated) coordinator.beginContextCleanup();
    dom.node_creation.destroyUninserted(root);
    if (scenario == .native or scenario == .retired) {
        try std.testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(root));
        try std.testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(child));
        // A repeated destruction must reject the returned slot before reading
        // its Instance fields or returning its state block again.
        dom.node_creation.destroyUninserted(root);
    } else {
        // Resource teardown completes, but storage still belongs to an
        // existing wrapper/realm teardown owner. An absent originating cache
        // cannot prove that another live realm has no wrapper of this node,
        // and the wrap mark says one may.
        try std.testing.expectEqual(root_generation, runtime.SlabAllocator.generationOf(root));
        try std.testing.expectEqual(child_generation, runtime.SlabAllocator.generationOf(child));
        try std.testing.expect(runtime.instance_lifecycle.isCleanedUp(root));
        try std.testing.expect(runtime.instance_lifecycle.isCleanedUp(child));
        try std.testing.expectEqual(@as(?*dom.NodeBase, null), dom.instance_bridge.getNodeBase(root));
        try std.testing.expectEqual(@as(?*dom.NodeBase, null), dom.instance_bridge.getNodeBase(child));
        try std.testing.expectEqual(slots_allocated, runtime.BrowserScope.standalone().?.slab.stats().currently_allocated);
        try std.testing.expectEqual(bytes_before + root_state_bytes + child_state_bytes, runtime.BrowserScope.standalone().?.arena.stats().bytes_in_use);
        if (scenario == .coordinated) {
            // No wrapper ever reached them ([wrap_tracking]): the coordinator
            // is that owner, and returns both at the teardown's end, once.
            coordinator.endContextCleanup();
            coordinator.releaseDeferredStorage();
            try std.testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(root));
            try std.testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(child));
            coordinator.releaseDeferredStorage();
        } else {
            // Stand in for that owner's storage phase, after resource cleanup.
            runtime.gc.releaseStorage(child);
            try std.testing.expectEqual(bytes_before + root_state_bytes, runtime.BrowserScope.standalone().?.arena.stats().bytes_in_use);
            runtime.gc.releaseStorage(root);
        }
    }
    // Check before pool shutdown: bulk arena/slab cleanup would hide retention.
    try std.testing.expectEqual(slots_before, runtime.BrowserScope.standalone().?.slab.stats().currently_allocated);
    try std.testing.expectEqual(bytes_before, runtime.BrowserScope.standalone().?.arena.stats().bytes_in_use);
}

fn onFreshThread(scenario: Scenario) !void {
    const Run = struct {
        scenario: Scenario,
        failure: ?anyerror = null,

        fn run(self: *@This()) void {
            exercise(self.scenario) catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{ .scenario = scenario };
    const thread = try std.Thread.spawn(.{}, Run.run, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

test "document.write merge: native subtree storage returns exactly once" {
    try onFreshThread(.native);
}

test "document.write merge: retired originating realm returns the storage no wrapper can reach" {
    try onFreshThread(.retired);
}

test "document.write merge: retired originating realm retains cleaned storage a wrapper may reach" {
    try onFreshThread(.retired_wrapped);
}

test "document.write merge: coordinated native teardown returns unwrapped storage at its end" {
    try onFreshThread(.coordinated);
}
