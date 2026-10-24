//! A tree's teardown must return descendants' storage even when none of
//! their wrappers remains to run a later finalizer. Cached wrappers keep
//! their storage until the collector releases them. Inside a realm's
//! coordinated teardown, a node no wrapper ever reached ([wrap_tracking])
//! gives its storage back when the teardown ends (lane unwrapped1).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const dom = @import("dom");

const Scenario = enum { collected_tree, uninserted_tree, cached_wrappers, coordinated_teardown, coordinated_teardown_wrapped };

fn runOnFreshThread(scenario: Scenario) !void {
    const Run = struct {
        scenario: Scenario,
        failure: ?anyerror = null,

        fn thread(self: *@This()) void {
            self.body() catch |err| {
                self.failure = err;
            };
        }

        fn body(self: *@This()) !void {
            var browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
            defer browser.deinit();
            try browser.navigate("about:blank", .window);
            const page = browser.current_context orelse return error.TestUnexpectedResult;
            const ctx = page.realm orelse return error.TestUnexpectedResult;
            try testing.expect(ctx.hasEngine());

            const before_instances = browser.scope.slab.stats().currently_allocated;
            const before_states = browser.scope.arena.stats().bytes_in_use;
            const root = try interfaces.HTMLDivElement.init(testing.allocator, ctx);
            const child = try interfaces.HTMLDivElement.init(testing.allocator, ctx);
            const text = try interfaces.Text.init(testing.allocator, ctx);
            _ = try interfaces.Node.call_appendChild(root, child);
            _ = try interfaces.Node.call_appendChild(child, text);
            const root_generation = runtime.SlabAllocator.generationOf(root);
            const child_generation = runtime.SlabAllocator.generationOf(child);
            const text_generation = runtime.SlabAllocator.generationOf(text);
            try testing.expect(!engine.hasWrapper(root));
            try testing.expect(!engine.hasWrapper(child));
            try testing.expect(!engine.hasWrapper(text));

            switch (self.scenario) {
                .collected_tree => {
                    // This is also the order when descendants' wrapper
                    // callbacks already released their entries while the
                    // parent still held the instances.
                    runtime.gc.onObjectFreed(root);
                    try testing.expect(runtime.SlabAllocator.generationOf(child) != child_generation);
                    try testing.expect(runtime.SlabAllocator.generationOf(text) != text_generation);
                },
                .uninserted_tree => {
                    dom.node_creation.destroyUninserted(root);
                    try testing.expect(runtime.SlabAllocator.generationOf(root) != root_generation);
                    // The dead slab slot must not be read or returned twice.
                    dom.node_creation.destroyUninserted(root);
                },
                .cached_wrappers => {
                    const held_root = try engine.retainValue(ctx, .{ .instance = root });
                    var root_held = true;
                    defer if (root_held) held_root.release();
                    const held_child = try engine.retainValue(ctx, .{ .instance = child });
                    var child_held = true;
                    defer if (child_held) held_child.release();
                    try testing.expect(engine.hasWrapper(root));
                    try testing.expect(engine.hasWrapper(child));
                    dom.node_creation.destroyUninserted(root);
                    // The binding still points at each Instance. Its cached
                    // wrapper, rather than the tree, releases this storage.
                    try testing.expectEqual(root_generation, runtime.SlabAllocator.generationOf(root));
                    try testing.expectEqual(child_generation, runtime.SlabAllocator.generationOf(child));
                    try testing.expect(runtime.SlabAllocator.generationOf(text) != text_generation);
                    held_child.release();
                    child_held = false;
                    held_root.release();
                    root_held = false;
                    engine.requestGarbageCollection(page.agent);
                    engine.requestGarbageCollection(page.agent);
                },
                .coordinated_teardown => {
                    var coordinator = runtime.cleanup_coordinator.CleanupCoordinator.init(testing.allocator);
                    defer coordinator.deinit();
                    runtime.cleanup_coordinator.setActiveCoordinator(&coordinator);
                    defer runtime.cleanup_coordinator.setActiveCoordinator(null);
                    coordinator.beginContextCleanup();
                    dom.node_creation.destroyUninserted(root);
                    // Cache teardown may already have disposed some entries:
                    // no wrapper query, and no release while the teardown's
                    // later phases run - each slot stays as it was.
                    try testing.expectEqual(root_generation, runtime.SlabAllocator.generationOf(root));
                    try testing.expectEqual(child_generation, runtime.SlabAllocator.generationOf(child));
                    try testing.expectEqual(text_generation, runtime.SlabAllocator.generationOf(text));
                    // No wrapper ever reached them ([wrap_tracking]): the
                    // teardown's end returns their storage, once.
                    coordinator.endContextCleanup();
                    coordinator.releaseDeferredStorage();
                    try testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(root));
                    try testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(child));
                    try testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(text));
                    coordinator.releaseDeferredStorage();
                },
                .coordinated_teardown_wrapped => {
                    // A node a wrapper reached keeps its storage through the
                    // teardown: its wrapper's owner frees it, never the
                    // coordinator. Wrapping the child wraps its ancestors
                    // too (node tracing), so only the text is unwrapped.
                    const held_child = try engine.retainValue(ctx, .{ .instance = child });
                    held_child.release();
                    try testing.expect(runtime.instance_lifecycle.wasWrapped(child));
                    try testing.expect(runtime.instance_lifecycle.wasWrapped(root));
                    try testing.expect(!runtime.instance_lifecycle.wasWrapped(text));
                    {
                        var coordinator = runtime.cleanup_coordinator.CleanupCoordinator.init(testing.allocator);
                        defer coordinator.deinit();
                        runtime.cleanup_coordinator.setActiveCoordinator(&coordinator);
                        defer runtime.cleanup_coordinator.setActiveCoordinator(null);
                        coordinator.beginContextCleanup();
                        dom.node_creation.destroyUninserted(root);
                        coordinator.endContextCleanup();
                        coordinator.releaseDeferredStorage();
                    }
                    try testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(text));
                    try testing.expectEqual(root_generation, runtime.SlabAllocator.generationOf(root));
                    try testing.expectEqual(child_generation, runtime.SlabAllocator.generationOf(child));
                    try testing.expect(runtime.instance_lifecycle.isCleanedUp(child));
                    // Their wrappers' collection frees them now.
                    engine.requestGarbageCollection(page.agent);
                    engine.requestGarbageCollection(page.agent);
                    try testing.expect(runtime.SlabAllocator.generationOf(root) != root_generation);
                    try testing.expect(runtime.SlabAllocator.generationOf(child) != child_generation);
                },
            }

            try testing.expectEqual(before_instances, browser.scope.slab.stats().currently_allocated);
            try testing.expectEqual(before_states, browser.scope.arena.stats().bytes_in_use);
        }
    };
    var run: Run = .{ .scenario = scenario };
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

test "a collected tree returns every unwrapped descendant to its pools" {
    try runOnFreshThread(.collected_tree);
}

test "an uninserted parser node returns its subtree's storage exactly once" {
    try runOnFreshThread(.uninserted_tree);
}

test "cached node wrappers retain cleaned storage until they are collected" {
    try runOnFreshThread(.cached_wrappers);
}

test "coordinated teardown returns unwrapped storage at its end, never during it" {
    try runOnFreshThread(.coordinated_teardown);
}

test "coordinated teardown leaves a wrapped node's storage to its wrapper" {
    try runOnFreshThread(.coordinated_teardown_wrapped);
}
