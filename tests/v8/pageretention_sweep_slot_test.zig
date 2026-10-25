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
//! The roots here speak (docs/lessons/debugging-give-the-objects-that-
//! reissue-a-freed-slot-a-voice.md): each root's own teardown first makes an
//! impostor element and records whether it landed in a slot a child had.

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
/// teardown_document_slot_reuse_test.zig); each sweep makes its own realm
/// data and wrapper cache.
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

    /// Wrap `instance` as the binding leaves an object script has seen.
    fn wrap(self: Realm, instance: *runtime.Instance) !void {
        runtime.instance_lifecycle.markWrapped(instance);
        const wrapper = ffi.v8_Object_New(isolate_once.?) orelse return error.ObjectFailed;
        try self.cache.set(instance, @ptrCast(wrapper), @ptrCast(isolate_once.?));
    }
};

const tree_count = 24;

/// What the sweep's root teardowns saw. tests/v8 is one process whose tests
/// run in turn on its main thread.
const Seen = struct {
    realm: ?Realm = null,
    children: [tree_count]*runtime.Instance = undefined,
    child_generations: [tree_count]u64 = undefined,
    impostors: [tree_count]*runtime.Instance = undefined,
    impostor_count: usize = 0,
    /// An impostor took a slot a child of an earlier root had.
    child_slot_reused: bool = false,
    /// Roots torn down after a child of an earlier root had been handled:
    /// the window an inline release would open.
    roots_after_handled_child: usize = 0,
    /// Roots whose child's entry the walk had already reached.
    child_first: usize = 0,
};

var seen: Seen = .{};

fn childIndex(instance: *runtime.Instance) ?usize {
    for (seen.children, 0..) |child, k| if (child == instance) return k;
    return null;
}

fn speakingRootDeinit(instance: *runtime.Instance) void {
    const realm = seen.realm.?;
    // A child of an earlier root already handled: its teardown completed
    // (the flags outlive a freed slot until the slab issues it again).
    for (seen.children) |child| {
        if (runtime.instance_lifecycle.isCleanedUp(child)) {
            seen.roots_after_handled_child += 1;
            break;
        }
    }
    // Its own child's entry gone from the map: the walk reached it first.
    if (dom.instance_bridge.getNodeBase(instance)) |base| if (base.first_child) |child_base| {
        const child: *runtime.Instance = @ptrCast(@alignCast(child_base.owner_instance.?));
        if (realm.cache.cache.get(child) == null) seen.child_first += 1;
    };
    // What a later teardown allocates: never a slot a child still names.
    if (interfaces.HTMLDivElement.init(testing.allocator, realm.data)) |impostor| {
        if (childIndex(impostor)) |_| seen.child_slot_reused = true;
        seen.impostors[seen.impostor_count] = impostor;
        seen.impostor_count += 1;
    } else |_| {}
    interfaces.HTMLElement.deinit(instance);
}

const speaking_root_vtable = blk: {
    var vtable = interfaces.HTMLElement.vtable;
    vtable.deinit = &speakingRootDeinit;
    break :blk vtable;
};

/// One realm teardown holding `tree_count` detached wrapped trees (a wrapped
/// speaking root with one wrapped child). Returns whether both orders came.
fn sweepOnce(coordinator_allocator: std.mem.Allocator, expect_returned: bool) !bool {
    const realm = try Realm.open();
    defer realm.close();
    var coordinator = runtime.CleanupCoordinator.init(coordinator_allocator);
    defer coordinator.deinit();
    runtime.cleanup_coordinator.setActiveCoordinator(&coordinator);
    defer runtime.cleanup_coordinator.setActiveCoordinator(null);
    seen = .{ .realm = realm };

    var roots: [tree_count]*runtime.Instance = undefined;
    var root_generations: [tree_count]u64 = undefined;
    for (&roots, &root_generations, 0..) |*root, *generation, k| {
        root.* = try interfaces.HTMLElement.initWithState(testing.allocator, interfaces.HTMLElement.State, &speaking_root_vtable, realm.data);
        generation.* = runtime.SlabAllocator.generationOf(root.*);
        const child = try interfaces.HTMLDivElement.init(testing.allocator, realm.data);
        _ = try interfaces.Node.call_appendChild(root.*, child);
        seen.children[k] = child;
        seen.child_generations[k] = runtime.SlabAllocator.generationOf(child);
        try realm.wrap(root.*);
        try realm.wrap(child);
    }

    coordinator.beginContextCleanup();
    realm.sweep();
    defer for (seen.impostors[0..seen.impostor_count]) |impostor| runtime.Instance.deinit(impostor);
    try testing.expectEqual(@as(usize, tree_count), seen.impostor_count);

    // No allocation the sweep made took a child's slot, and no child's slot
    // went back before the teardown's last phase.
    try testing.expect(!seen.child_slot_reused);
    for (seen.children, seen.child_generations) |child, generation| {
        try testing.expect(runtime.instance_lifecycle.isCleanedUp(child));
        try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(child));
    }

    coordinator.endContextCleanup();
    coordinator.releaseDeferredStorage();
    // Then each goes back - once - or, when the teardown could not record
    // it, stays with the Browser as before.
    for (seen.children, seen.child_generations) |child, generation| {
        if (expect_returned)
            try testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(child))
        else
            try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(child));
    }
    for (roots, root_generations) |root, generation| try testing.expect(runtime.SlabAllocator.generationOf(root) != generation);
    return seen.child_first > 0 and seen.child_first < tree_count and seen.roots_after_handled_child > 0;
}

test "a detached wrapped tree's nodes give their slots to the teardown, in either sweep order" {
    // Each sweep's hash order is its own; repeat until one put some children
    // before their roots and some roots after a handled child.
    var exercised = false;
    var attempt: usize = 0;
    while (!exercised and attempt < 8) : (attempt += 1) exercised = try sweepOnce(testing.allocator, true);
    try testing.expect(exercised);
}

test "a sweep that cannot record a slot keeps it, as before" {
    // The set-aside list allocates nothing (an entry's own link); only the
    // teardown's record of the slot can fail - then the slot stays with its
    // Browser, never freed twice or early.
    var failing = std.testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
    _ = try sweepOnce(failing.allocator(), false);
    try testing.expect(failing.has_induced_failure);
}
