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
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const interfaces = @import("interfaces");
const dom = @import("dom");

const WrapperCache = v8.WrapperCache;

var test_isolate: ?*ffi.Isolate = null;
var test_data: ?*runtime.ContextData = null;
var test_cache: ?*WrapperCache = null;

/// The test's own agent, ended with the test (test_process.TestAgent);
/// `reset` clears what the file caches of it.
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_isolate = null;
    test_data = null;
    test_cache = null;
}

/// The test's isolate, context and wrapper cache, its own agent's
/// (test_agent), ended with the test (see engine_pending_activity_test.zig);
/// the node hooks, as a host starts them.
fn setup() !*runtime.ContextData {
    const isolate = try test_agent.open(.{ .realm_allocator = testing.allocator });
    if (test_data == null) {
        const context = test_agent.context.?;
        const data = try test_agent.contextData(testing.allocator, .{ .engine_ctx = context });
        data.agent = @ptrCast(isolate);
        const cache = try std.heap.page_allocator.create(WrapperCache);
        cache.* = try WrapperCache.init(std.heap.page_allocator, @ptrCast(context));
        data.setV8WrapperCacheStorage(@ptrCast(cache));
        test_agent.endWith(.{ .call = .{ .call = endCache, .data = cache } });
        test_isolate = isolate;
        test_data = data;
        test_cache = cache;
    }
    return test_data.?;
}

/// The test's wrapper cache ends before its realm's data and its agent, as a
/// realm's end takes its cache down (context_manager): every wrapper's weak
/// callback cleared, every instance torn down, and the cache out of the
/// thread's live caches (`wrappedElsewhere` reads every one of them).
fn endCache(cache: ?*anyopaque) void {
    const self: *WrapperCache = @ptrCast(@alignCast(cache.?));
    self.deinit();
    std.heap.page_allocator.destroy(self);
}

/// Wrap `instance` as the binding leaves an object script has seen and then
/// dropped: a real V8 object, held by the cache alone.
fn wrap(instance: *runtime.Instance) !void {
    // A node's wrapper is an API object (P4: its anchor is Wrapped onto it).
    const wrapper = test_process.nodeWrapperObject(test_isolate.?, test_agent.context.?) orelse return error.ObjectFailed;
    _ = try test_cache.?.set(instance, @ptrCast(wrapper), @ptrCast(test_isolate.?));
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
        ffi.v8_Isolate_RequestGarbageCollection(test_isolate.?);
        wrapper_collected_in_window = test_cache.?.get(instance) == null;
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
    defer test_agent.close();
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
    defer test_agent.close();
    const ctx = try setup();
    deinit_runs = 0;
    wrapper_collected_in_window = false;

    const parent = try interfaces.HTMLDivElement.init(testing.allocator, ctx);
    const child = try interfaces.HTMLElement.initWithState(testing.allocator, interfaces.HTMLElement.State, &collecting_vtable, ctx);
    _ = try interfaces.Node.call_appendChild(parent, child);
    try wrap(child);
    // The parent's teardown walks the child: the parent's child list holds it
    // until the child's teardown is done. The parent is freed as a native
    // creator frees a root it never inserted (the parser's adapter):
    // interfaces.HTMLDivElement.deinit alone is its destructor, which left
    // the parent's slot in the slab (docs/lessons/architecture-an-
    // interfaces-deinit-is-a-destructor-not-a-free.md).
    dom.node_creation.destroyUninserted(parent);

    try testing.expectEqual(@as(usize, 1), deinit_runs);
    try testing.expect(runtime.instance_lifecycle.isCleanedUp(child));
}

test "a node its tree tore down is not freed again by the parser's free" {
    defer test_agent.close();
    const ctx = try setup();
    deinit_runs = 0;

    const parent = try interfaces.HTMLDivElement.init(testing.allocator, ctx);
    const child = try interfaces.HTMLElement.initWithState(testing.allocator, interfaces.HTMLElement.State, &collecting_vtable, ctx);
    _ = try interfaces.Node.call_appendChild(parent, child);
    dom.node_creation.destroyUninserted(parent);
    try testing.expectEqual(@as(usize, 1), deinit_runs);
    // The record of the teardown outlives it until the slot is reissued.
    dom.node_creation.destroyUninserted(child);
    try testing.expectEqual(@as(usize, 1), deinit_runs);
}
