//! A collection inside an element's teardown never tears the element down
//! a second time.
//!
//! Node.deinitNodeByType arms the element's wrapper weak
//! (engine.platformObjectDestroyed) and then runs the element's own deinit -
//! the one its vtable names, all of the derived levels - before Node.deinit,
//! at the bottom of that chain, used to be the first to record the teardown in
//! runtime.instance_lifecycle. A collection inside that window found the
//! wrapper unreferenced, and its finalizer (wrapper_cache finalizeEntry) freed
//! an instance whose teardown had "not started": the element's deinit ran
//! again, under itself. So the teardown takes the mark FIRST.
//!
//! A node with a parent is its tree's whatever the mark says (treeOwns); the
//! root the parser's adapter frees (dom.node_creation.destroyUninserted) is
//! the case only the mark covers.
//!
//! Real V8, real collections: RequestGarbageCollection is LowMemoryNotification,
//! a full collection whose finalizers (the second pass) run before it returns.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const interfaces = @import("interfaces");
const dom = @import("dom");

const WrapperCache = v8.WrapperCache;

var isolate_once: ?*ffi.Isolate = null;
var data_once: ?*runtime.ContextData = null;
var cache_once: ?*WrapperCache = null;

/// One isolate, context and wrapper cache for the file, never torn down (see
/// engine_pending_activity_test.zig); the node hooks, as a host starts them.
fn setup() !*runtime.ContextData {
    if (data_once) |data| return data;
    interfaces.process_hooks.startHooksForTest();
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(isolate);
    _ = ffi.v8_HandleScope_New(isolate);
    const context = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    const data = try std.heap.page_allocator.create(runtime.ContextData);
    data.* = try runtime.ContextData.init(std.heap.page_allocator, .{ .engine_ctx = context });
    data.agent = @ptrCast(isolate);
    const cache = try std.heap.page_allocator.create(WrapperCache);
    cache.* = try WrapperCache.init(std.heap.page_allocator, @ptrCast(context));
    data.setV8WrapperCacheStorage(@ptrCast(cache));
    isolate_once = isolate;
    data_once = data;
    cache_once = cache;
    return data;
}

/// Wrap `instance` as the binding leaves an object script has seen and then
/// dropped: a real V8 object, held by the cache alone.
fn wrap(instance: *runtime.Instance) !void {
    const wrapper = ffi.v8_Object_New(isolate_once.?) orelse return error.ObjectFailed;
    try cache_once.?.set(instance, @ptrCast(wrapper), @ptrCast(isolate_once.?));
}

/// How often `collectingDeinit` ran, and whether its collection took the
/// element's wrapper (so the test cannot pass without exercising the window).
var deinit_runs: usize = 0;
var wrapper_collected_in_window = false;

/// HTMLElement's deinit, preceded - on its first run - by a full collection:
/// inside the window, before anything of the element is freed.
fn collectingDeinit(instance: *runtime.Instance) void {
    deinit_runs += 1;
    if (deinit_runs == 1) {
        ffi.v8_Isolate_RequestGarbageCollection(isolate_once.?);
        wrapper_collected_in_window = cache_once.?.get(instance) == null;
    }
    interfaces.HTMLElement.deinit(instance);
}

/// HTMLElement's vtable with `collectingDeinit` as the element's own deinit.
const collecting_vtable = blk: {
    var vtable = interfaces.HTMLElement.vtable;
    vtable.deinit = &collectingDeinit;
    break :blk vtable;
};

test "a collection inside a root's teardown does not tear it down again" {
    const ctx = try setup();
    deinit_runs = 0;
    wrapper_collected_in_window = false;

    const root = try interfaces.HTMLElement.initWithState(testing.allocator, interfaces.HTMLElement.State, &collecting_vtable, ctx);
    try wrap(root);
    // The parser's adapter frees a node it made and never inserted - here
    // one script saw (a custom element's constructor can) and let go of.
    dom.node_creation.destroyUninserted(root);

    try testing.expect(wrapper_collected_in_window);
    try testing.expectEqual(@as(usize, 1), deinit_runs);
    try testing.expect(runtime.instance_lifecycle.isCleanedUp(root));
}

test "a collection inside a child's teardown leaves the child to its tree" {
    const ctx = try setup();
    deinit_runs = 0;
    wrapper_collected_in_window = false;

    const parent = try interfaces.HTMLDivElement.init(testing.allocator, ctx);
    const child = try interfaces.HTMLElement.initWithState(testing.allocator, interfaces.HTMLElement.State, &collecting_vtable, ctx);
    _ = try interfaces.Node.call_appendChild(parent, child);
    try wrap(child);
    // The parent's teardown walks the child: the parent's child list holds it
    // until the child's teardown is done.
    interfaces.HTMLDivElement.deinit(parent);

    try testing.expectEqual(@as(usize, 1), deinit_runs);
    try testing.expect(runtime.instance_lifecycle.isCleanedUp(child));
}

test "a node its tree tore down is not freed again by the parser's free" {
    const ctx = try setup();
    deinit_runs = 0;

    const parent = try interfaces.HTMLDivElement.init(testing.allocator, ctx);
    const child = try interfaces.HTMLElement.initWithState(testing.allocator, interfaces.HTMLElement.State, &collecting_vtable, ctx);
    _ = try interfaces.Node.call_appendChild(parent, child);
    interfaces.HTMLDivElement.deinit(parent);
    try testing.expectEqual(@as(usize, 1), deinit_runs);
    // The record of the teardown outlives it until the slot is reissued.
    dom.node_creation.destroyUninserted(child);
    try testing.expectEqual(@as(usize, 1), deinit_runs);
}
