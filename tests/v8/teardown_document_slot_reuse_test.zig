//! A realm's end never returns a torn-down node's slot while the teardown can
//! still read it (lane unwrapped1, the integrator's condition on (a2)).
//!
//! The realm's tree teardown tears its Document down first, under the
//! Document's live wrapper (markAsCleanedUp). WrapperCache.deinit's sweep
//! then reaches that entry - and a detached root of the same document may be
//! torn down LATER in the same teardown (after it in the sweep's hash order,
//! or by a later phase), reading its node document as it goes. Returning the
//! Document's slot in the sweep would let any allocation the rest of the
//! teardown makes take it (the slab's free list is LIFO: the next object of
//! any type lands exactly there), and the root's teardown would act on the
//! impostor. So the sweep hands the slot to the coordinator, which returns it
//! after the teardown's last phase.
//!
//! The impostor announces itself (docs/lessons/debugging-give-the-objects-
//! that-reissue-a-freed-slot-a-voice.md): a Document whose referencing-node
//! count would move if a root's teardown released its count on it.
//!
//! (2026-11-09, lane wr1 batch 2, the wrapper redesign's P2: a node's wrapper
//! is in its own slot, never in a wrapper cache, so the sweep meets no node
//! and the hash-order case - a wrapped root swept after its Document's entry -
//! is gone with it; tests/v8/pageretention_sweep_slot_test.zig pins that the
//! sweep tears down no node. The Document torn down under its live wrapper
//! below has the wrapper severed and its slot handed to the coordinator by
//! its own teardown.)

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const interfaces = @import("interfaces");
const dom = @import("dom");

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
/// the test (as teardown_gc_window_test.zig); each test makes its own realm
/// data and wrapper cache, which it sweeps.
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

    /// Wrap `instance` as the binding leaves an object script has seen: a
    /// real V8 object, held by the cache.
    fn wrap(self: Realm, instance: *runtime.Instance) !void {
        runtime.instance_lifecycle.markWrapped(instance);
        const wrapper = ffi.v8_Object_New(test_isolate.?) orelse return error.ObjectFailed;
        _ = try self.cache.set(instance, @ptrCast(wrapper), @ptrCast(test_isolate.?));
    }
};

fn referencingNodes(document: *runtime.Instance) u32 {
    const counts = dom.refcount.documentCounts(document) orelse return 0;
    return counts.referencing_nodes;
}

/// A detached root of `document` with one child, both naming it.
fn detachedRoot(ctx: runtime.Context, document: *runtime.Instance, vtable: ?*const runtime.VTable) !*runtime.Instance {
    const root = if (vtable) |own|
        try interfaces.HTMLElement.initWithState(testing.allocator, interfaces.HTMLElement.State, own, ctx)
    else
        try interfaces.HTMLDivElement.init(testing.allocator, ctx);
    const child = try interfaces.Text.init(testing.allocator, ctx);
    _ = try interfaces.Node.call_appendChild(root, child);
    try dom.node_document.set(root, document);
    try dom.node_document.set(child, document);
    return root;
}

test "a torn-down Document's slot survives the sweep: an allocation after it never lands there" {
    defer test_agent.close();
    const realm = try Realm.open();
    defer realm.close();
    var coordinator = runtime.CleanupCoordinator.init(testing.allocator);
    defer coordinator.deinit();
    runtime.cleanup_coordinator.setActiveCoordinator(&coordinator);
    defer runtime.cleanup_coordinator.setActiveCoordinator(null);

    const document = try interfaces.Document.init(testing.allocator, realm.data);
    const document_generation = runtime.SlabAllocator.generationOf(document);
    try realm.wrap(document);
    // Torn down later in the same teardown: never wrapped, as an orphan of
    // the realm is - its teardown reads its node document.
    const root = try detachedRoot(realm.data, document, null);
    try testing.expectEqual(@as(u32, 2), referencingNodes(document));

    coordinator.beginContextCleanup();
    // The dom_tree phase: the Document goes under its live wrapper.
    dom.node_creation.destroyUninserted(document);
    try testing.expect(runtime.instance_lifecycle.isCleanedUp(document));
    // The wrapper_cache phase.
    realm.sweep();
    try testing.expectEqual(document_generation, runtime.SlabAllocator.generationOf(document));

    // What the rest of the teardown allocates takes a slot of its own.
    const impostor = try interfaces.Document.init(testing.allocator, realm.data);
    defer runtime.Instance.deinit(impostor);
    try testing.expect(impostor != document);
    const impostor_references = referencingNodes(impostor);

    // The root's teardown reads its torn-down document - never the impostor.
    dom.node_creation.destroyUninserted(root);
    try testing.expectEqual(impostor_references, referencingNodes(impostor));

    // The teardown's last phase is done: now the slot goes back, once.
    coordinator.endContextCleanup();
    coordinator.releaseDeferredStorage();
    try testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(document));
    try testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(root));
}
