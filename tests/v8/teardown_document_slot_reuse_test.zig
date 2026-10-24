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

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const interfaces = @import("interfaces");
const dom = @import("dom");

const WrapperCache = v8.WrapperCache;

var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;

/// One isolate and context for the file, never torn down (as
/// teardown_gc_window_test.zig); each test makes its own realm data and
/// wrapper cache, which it sweeps.
fn engine() !void {
    if (isolate_once != null) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.heap.page_allocator);
    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(isolate);
    _ = ffi.v8_HandleScope_New(isolate);
    const context = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    isolate_once = isolate;
    context_once = context;
}

const Realm = struct {
    data: *runtime.ContextData,
    cache: *WrapperCache,

    fn open() !Realm {
        try engine();
        const data = try testing.allocator.create(runtime.ContextData);
        errdefer testing.allocator.destroy(data);
        data.* = try runtime.ContextData.init(testing.allocator, .{ .engine_ctx = context_once.? });
        data.agent = @ptrCast(isolate_once.?);
        const cache = try testing.allocator.create(WrapperCache);
        cache.* = try WrapperCache.init(testing.allocator, @ptrCast(context_once.?));
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
        const wrapper = ffi.v8_Object_New(isolate_once.?) orelse return error.ObjectFailed;
        try self.cache.set(instance, @ptrCast(wrapper), @ptrCast(isolate_once.?));
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

// The same inside the sweep: wrapped detached roots whose own teardown first
// allocates an impostor and records what it found, so whichever of them the
// hash order puts after the Document's entry checks the window.

var sweep_document: ?*runtime.Instance = null;
var sweep_document_generation: u64 = 0;
var sweep_coordinator: ?*runtime.CleanupCoordinator = null;
var impostors: [32]*runtime.Instance = undefined;
var impostor_count: usize = 0;
var roots_after_document: usize = 0;
var document_slot_reused: bool = false;
var document_slot_returned: bool = false;

fn impostorDeinit(instance: *runtime.Instance) void {
    const document = sweep_document.?;
    for (sweep_coordinator.?.deferred_storage.items) |deferred| {
        if (deferred.instance == document) roots_after_document += 1;
    }
    if (runtime.SlabAllocator.generationOf(document) != sweep_document_generation) document_slot_returned = true;
    if (interfaces.Document.init(testing.allocator, instance.ctx)) |impostor| {
        if (impostor == document) document_slot_reused = true;
        impostors[impostor_count] = impostor;
        impostor_count += 1;
    } else |_| {}
    interfaces.HTMLElement.deinit(instance);
}

const impostor_vtable = blk: {
    var vtable = interfaces.HTMLElement.vtable;
    vtable.deinit = &impostorDeinit;
    break :blk vtable;
};

/// One teardown of a realm holding a wrapped Document and `roots.len`
/// wrapped detached roots of it. Whether the hash order put a root after the
/// Document's entry.
fn sweepOnce() !bool {
    const realm = try Realm.open();
    defer realm.close();
    var coordinator = runtime.CleanupCoordinator.init(testing.allocator);
    defer coordinator.deinit();
    runtime.cleanup_coordinator.setActiveCoordinator(&coordinator);
    defer runtime.cleanup_coordinator.setActiveCoordinator(null);
    impostor_count = 0;
    roots_after_document = 0;
    document_slot_reused = false;
    document_slot_returned = false;

    const document = try interfaces.Document.init(testing.allocator, realm.data);
    sweep_document = document;
    sweep_document_generation = runtime.SlabAllocator.generationOf(document);
    sweep_coordinator = &coordinator;
    try realm.wrap(document);
    var roots: [24]*runtime.Instance = undefined;
    for (&roots) |*root| {
        root.* = try detachedRoot(realm.data, document, &impostor_vtable);
        try realm.wrap(root.*);
    }

    coordinator.beginContextCleanup();
    dom.node_creation.destroyUninserted(document);
    realm.sweep();
    defer for (impostors[0..impostor_count]) |impostor| runtime.Instance.deinit(impostor);

    try testing.expectEqual(roots.len, impostor_count);
    try testing.expect(!document_slot_returned);
    try testing.expect(!document_slot_reused);
    for (impostors[0..impostor_count]) |impostor| try testing.expectEqual(@as(u32, 0), referencingNodes(impostor));

    coordinator.endContextCleanup();
    coordinator.releaseDeferredStorage();
    try testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(document));
    return roots_after_document > 0;
}

test "inside the sweep, a root after its Document's entry finds the slot still the Document's" {
    // Each teardown's hash order is its own; a run where every root came
    // before the Document's entry did not exercise the window, so teardowns
    // repeat until one did (each misses with odds 1 in 25).
    var exercised = false;
    var attempt: usize = 0;
    while (!exercised and attempt < 8) : (attempt += 1) exercised = try sweepOnce();
    try testing.expect(exercised);
}
