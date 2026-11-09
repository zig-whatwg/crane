//! A realm's wrapper-cache sweep returns the slots of a detached wrapped
//! tree's nodes, and never while the teardown can still allocate into them
//! (lane pageretention1, the integrator's conditions 4 and 5).
//!
//! A detached tree script holds when its realm ends - a wrapped root, a
//! wrapped child - is torn down by the sweep (WrapperCache.deinit), in the
//! map's hash order:
//!
//! - ROOT FIRST: the root's teardown (gc.onObjectFreed) frees the child
//!   under its live wrapper; the child's entry, reached later, is "started"
//!   and its storage goes back. It went back INLINE, mid-sweep: the slab's
//!   free list is LIFO, so the next allocation of any type - one a later
//!   teardown of the same sweep makes - landed in it while a reader of the
//!   old node could still come (unwrapped1's rule: a slot goes back only
//!   after the last step that could read it). Now it goes to the teardown,
//!   which returns it after its last phase.
//! - CHILD FIRST: the child is its tree's (treeOwns), so its entry let only
//!   the wrapper go; the root's teardown then freed the child but not its
//!   slot - the child was wrapped, and a wrapped node's storage is its
//!   wrapper's, whose entry was gone. Every such node kept its slot until
//!   the Browser ended. Now the entry waits for the walk's end, and a child
//!   its root freed by then gives its slot to the teardown, severed.
//!
//! (2026-11-09, lane wr1 batch 2, the wrapper redesign's P2: a node's wrapper
//! is in its own slot, its agent's, never in a wrapper cache - so the sweep
//! meets no node, and the two orders above are gone with it. What is pinned
//! now is that rule: the sweep tears down no node, and the agent's end -
//! engine.releaseNodeWrappers, then the drain of its queue - frees the trees
//! only their wrappers held.)

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const interfaces = @import("interfaces");
const dom = @import("dom");
const engine_mod = @import("engine");

const WrapperCache = v8.WrapperCache;

var test_isolate: ?*ffi.Isolate = null;
var test_context: ?*ffi.Context = null;

/// The test's own agent, ended with the test (test_process.TestAgent);
/// `reset` clears what the file caches of it.
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_isolate = null;
    test_context = null;
}

/// The test's isolate and context, its own agent's (test_agent), ended with
/// the test (as teardown_document_slot_reuse_test.zig); each sweep makes its
/// own realm data and wrapper cache.
fn engine() !void {
    const isolate = try test_agent.open(.{ .realm_allocator = testing.allocator });
    if (test_isolate == null) {
        const context = test_agent.context.?;
        test_isolate = isolate;
        test_context = context;
    }
}

const Realm = struct {
    data: *runtime.ContextData,
    cache: *WrapperCache,

    fn open() !Realm {
        try engine();
        const data = try testing.allocator.create(runtime.ContextData);
        errdefer testing.allocator.destroy(data);
        data.* = try runtime.ContextData.init(testing.allocator, .{ .engine_ctx = test_context.? });
        data.agent = @ptrCast(test_isolate.?);
        const cache = try testing.allocator.create(WrapperCache);
        cache.* = try WrapperCache.init(testing.allocator, @ptrCast(test_context.?));
        data.setV8WrapperCacheStorage(@ptrCast(cache));
        return .{ .data = data, .cache = cache };
    }

    /// The cache's sweep, as the realm's end runs it (its wrapper_cache
    /// phase); the cache is gone after it.
    fn sweep(self: Realm) void {
        self.cache.deinit();
        testing.allocator.destroy(self.cache);
        self.data.clearV8WrapperCacheStorage();
    }

    fn close(self: Realm) void {
        self.data.deinit();
        testing.allocator.destroy(self.data);
    }

    /// Wrap `instance` as the binding leaves an object script has seen.
    fn wrap(self: Realm, instance: *runtime.Instance) !void {
        runtime.instance_lifecycle.markWrapped(instance);
        const wrapper = ffi.v8_Object_New(test_isolate.?) orelse return error.ObjectFailed;
        _ = try self.cache.set(instance, @ptrCast(wrapper), @ptrCast(test_isolate.?));
    }
};

const tree_count = 24;

test "a realm's cache sweep tears down no node: its wrapped detached trees are their wrappers', and the agent's end frees them" {
    defer test_agent.close();
    const realm = try Realm.open();
    defer realm.close();
    var roots: [tree_count]*runtime.Instance = undefined;
    var children: [tree_count]*runtime.Instance = undefined;
    var root_generations: [tree_count]u64 = undefined;
    var child_generations: [tree_count]u64 = undefined;
    for (&roots, &children, &root_generations, &child_generations) |*root, *child, *root_generation, *child_generation| {
        root.* = try interfaces.HTMLDivElement.init(testing.allocator, realm.data);
        child.* = try interfaces.HTMLSpanElement.init(testing.allocator, realm.data);
        _ = try interfaces.Node.call_appendChild(root.*, child.*);
        try realm.wrap(root.*);
        try realm.wrap(child.*);
        root_generation.* = runtime.SlabAllocator.generationOf(root.*);
        child_generation.* = runtime.SlabAllocator.generationOf(child.*);
    }

    // The realm's end (its wrapper_cache phase): the nodes' wrappers are
    // their agent's, in their own slots - the cache's sweep meets none.
    realm.sweep();
    for (roots, children, root_generations, child_generations) |root, child, root_generation, child_generation| {
        try testing.expectEqual(root_generation, runtime.SlabAllocator.generationOf(root));
        try testing.expectEqual(child_generation, runtime.SlabAllocator.generationOf(child));
        try testing.expect(!runtime.instance_lifecycle.isCleanupStarted(child));
        try testing.expect(!runtime.lifetime.slotOf(dom.instance_bridge.getNodeBase(child).?).isEmpty());
    }

    // The agent's end (engine.releaseNodeWrappers, before the host's last
    // drain): every wrapper lets its reference go, the trees are garbage,
    // and the agent's queue frees them - each slot back once.
    engine_mod.releaseNodeWrappers(test_agent.agent());
    const queue = engine_mod.deferredTeardownOf(test_agent.agent()) orelse return error.TestExpectedQueue;
    queue.drainAll();
    for (roots, children) |root, child| {
        try testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(root));
        try testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(child));
    }
}
