//! A node whose last wrapper the collector took is unreachable from script,
//! and its tree's teardown returns its slot - only once nothing can read it
//! (lane pageretention1, the integrator's conditions 2 and 5).
//!
//! The finalizer of a wrapper whose instance the host keeps - a node in its
//! tree - lets only the wrapper go (wrapper_cache.finalizeEntry). Its wrap
//! mark stayed: the node's tree, torn down later in a realm's coordinated
//! teardown, found it marked wrapped and kept its slot, with no entry left
//! to return it - every wrapped node of a removed frame's document, which
//! the collector takes whole, stayed until its Browser ended. The adapter
//! now records the release (instance_lifecycle.markWrapperGone) when that
//! wrapper was the instance's last engine object - no other realm's cache
//! wraps it - and the teardown returns such a node's slot after its last
//! phase. A node its tree tore down before its wrapper's finalizer ran, the
//! finalizer hands to the teardown itself.
//!
//! Each test allocates an impostor before the teardown's last phase: the
//! slot is never free while the teardown can still allocate into it.
//!
//! A wrapped node's ancestors are wrapped too (node tracing: the cache's
//! `set` draws the tree's edges, wrapping the root), and the wrapped part of
//! a tree is one cycle the collector keeps or takes whole - so these trees'
//! roots are wrapped, and a root and its child die in one collection, their
//! finalizers in either order.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const v8 = @import("v8");
const dom = @import("dom");
const ffi = v8.ffi;

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

var pools_ready = false;

fn setup() !void {
    try engine.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
}

const no_hooks: engine.HostHooks = .{};

/// An instance as (address, slab generation): a freed slot is reissued.
const Made = struct {
    instance: *runtime.Instance,
    generation: u64,

    fn of(instance: *runtime.Instance) Made {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    fn alive(self: Made) bool {
        return runtime.SlabAllocator.generationOf(self.instance) == self.generation;
    }
};

fn openRealm(agent: *engine.Agent) !runtime.Context {
    return engine.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
}

fn cacheOf(realm: runtime.Context) !*v8.WrapperCache {
    const storage = realm.getV8WrapperCacheStorage() orelse return error.NoWrapperCache;
    return @ptrCast(@alignCast(storage));
}

/// An agent, a Window realm of it entered, and its wrapper cache.
const Page = struct {
    agent: *engine.Agent,
    realm: runtime.Context,
    isolate: *ffi.Isolate,
    cache: *v8.WrapperCache,

    fn open() !Page {
        try setup();
        const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer engine.destroyAgent(agent);
        const realm = try openRealm(agent);
        const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
        ffi.v8_Isolate_Enter(isolate);
        ffi.v8_Context_Enter(@ptrCast(realm.engine_ctx.?));
        return .{ .agent = agent, .realm = realm, .isolate = isolate, .cache = try cacheOf(realm) };
    }

    fn close(self: *Page) void {
        ffi.v8_Context_Exit(@ptrCast(self.realm.engine_ctx.?));
        ffi.v8_Isolate_Exit(self.isolate);
        engine.destroyWindowRealm(self.realm, .global_detached);
        engine.destroyAgent(self.agent);
    }

    /// Give `instance` a wrapper `cache` owns, as the binding leaves an
    /// object script has seen; nothing else holds it.
    fn wrapIn(self: *Page, cache: *v8.WrapperCache, instance: *runtime.Instance) !*ffi.Object {
        runtime.instance_lifecycle.markWrapped(instance);
        const wrapper = ffi.v8_Object_New(self.isolate) orelse return error.ObjectFailed;
        try cache.set(instance, @ptrCast(wrapper), self.isolate);
        return wrapper;
    }

    /// A full collection: every first and second pass runs before it returns.
    fn collect(self: *Page) void {
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate);
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate);
    }
};

/// A detached root the host holds (never wrapped) and one child of it.
const Tree = struct {
    root: *runtime.Instance,
    child: *runtime.Instance,

    fn make(realm: runtime.Context) !Tree {
        const root = try interfaces.HTMLDivElement.init(testing.allocator, realm);
        const child = try interfaces.HTMLSpanElement.init(testing.allocator, realm);
        _ = try interfaces.Node.call_appendChild(root, child);
        return .{ .root = root, .child = child };
    }
};

/// A coordinated realm teardown in progress, as context_manager runs one.
const Teardown = struct {
    coordinator: runtime.CleanupCoordinator,

    fn begin(self: *Teardown) void {
        self.coordinator = runtime.CleanupCoordinator.init(testing.allocator);
        runtime.cleanup_coordinator.setActiveCoordinator(&self.coordinator);
        self.coordinator.beginContextCleanup();
    }

    /// Its last phase is done.
    fn end(self: *Teardown) void {
        self.coordinator.endContextCleanup();
        self.coordinator.releaseDeferredStorage();
        runtime.cleanup_coordinator.setActiveCoordinator(null);
        self.coordinator.deinit();
    }
};

/// Allocate a span impostor in `realm`: it must not take `slot`'s place.
fn expectImpostorElsewhere(realm: runtime.Context, slot: Made) !void {
    const impostor = try interfaces.HTMLSpanElement.init(testing.allocator, realm);
    defer dom.node_creation.destroyUninserted(impostor);
    try testing.expect(impostor != slot.instance);
    try testing.expect(slot.alive());
}

test "a detached wrapped tree collected during a teardown gives its nodes' slots to that teardown" {
    var page = try Page.open();
    defer page.close();
    const tree = try Tree.make(page.realm);
    _ = try page.wrapIn(page.cache, tree.child);
    try testing.expect(page.cache.get(tree.root) != null);
    const child = Made.of(tree.child);

    var teardown: Teardown = undefined;
    teardown.begin();
    // The collector takes the tree's wrappers: the root's finalizer frees the
    // tree, the child's either finds it torn down (and hands its slot over)
    // or comes first (and records the release, so the root's teardown hands
    // the slot over). Its slot is the teardown's either way - never back yet.
    page.collect();
    try testing.expect(page.cache.get(tree.child) == null);
    try testing.expect(page.cache.get(tree.root) == null);
    try testing.expect(runtime.instance_lifecycle.isCleanedUp(tree.child));
    try expectImpostorElsewhere(page.realm, child);

    teardown.end();
    try testing.expect(!child.alive());
}

test "a node its tree tore down before its wrapper was collected gives its slot to the teardown" {
    var page = try Page.open();
    defer page.close();
    const tree = try Tree.make(page.realm);
    _ = try page.wrapIn(page.cache, tree.child);
    const child = Made.of(tree.child);

    var teardown: Teardown = undefined;
    teardown.begin();
    // The tree goes first, under the child's live wrapper.
    dom.node_creation.destroyUninserted(tree.root);
    try testing.expect(runtime.instance_lifecycle.isCleanedUp(tree.child));
    try testing.expect(child.alive());
    // Then the collector takes the wrapper: its finalizer hands the slot
    // over - never back at once.
    page.collect();
    try testing.expect(page.cache.get(tree.child) == null);
    try expectImpostorElsewhere(page.realm, child);

    teardown.end();
    try testing.expect(!child.alive());
}

test "a node wrapped in two realms is released only when its last wrapper goes" {
    // A template's contents: kept by their live template whatever becomes of
    // their wrappers (wrapper_cache.templateOwns), with no tree edge between
    // their wrappers in two realms - so each realm's wrapper can die alone.
    var page = try Page.open();
    defer page.close();
    const other = try openRealm(page.agent);
    defer engine.destroyWindowRealm(other, .global_detached);
    const other_cache = try cacheOf(other);

    const document = try interfaces.Document.init(testing.allocator, page.realm);
    defer dom.node_creation.destroyUninserted(document);
    try dom.document_internals.setDocumentType(document, .html);
    try dom.document_internals.setContentType(document, "text/html");
    const template = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("template"), .notPassed());
    var template_live = true;
    defer if (template_live) dom.node_creation.destroyUninserted(template);
    // Establishing the contents wraps them here, held for the template until
    // it is wrapped; the template lets that hold go, so only the cache's
    // weak wrapper is left here.
    const content = try interfaces.HTMLTemplateElement.get_content(template);
    try testing.expect(page.cache.get(content) != null);
    engine.forgetTracedChild(template, .{ .name = "content" });
    // The other realm's wrapper, kept by script there.
    const kept_there = try page.wrapIn(other_cache, content);
    const held = ffi.v8_Global_Clone(@ptrCast(kept_there)) orelse return error.HoldFailed;
    var held_live = true;
    defer if (held_live) ffi.v8_Global_Dispose(held);
    const made = Made.of(content);

    // This realm's wrapper is collected: the other realm's still reaches the
    // contents, so they are not released.
    page.collect();
    try testing.expect(page.cache.get(content) == null);
    try testing.expect(other_cache.get(content) != null);
    try testing.expect(made.alive());
    try testing.expect(!runtime.instance_lifecycle.provablyUnwrapped(true, content));

    // The other realm lets its wrapper go: now nothing reaches them.
    ffi.v8_Global_Dispose(held);
    held_live = false;
    page.collect();
    try testing.expect(other_cache.get(content) == null);
    try testing.expect(made.alive());
    try testing.expect(runtime.instance_lifecycle.provablyUnwrapped(true, content));

    // The template's teardown, inside a realm's teardown, frees them - and
    // their slot goes back after the teardown's last phase.
    var teardown: Teardown = undefined;
    teardown.begin();
    template_live = false;
    dom.node_creation.destroyUninserted(template);
    try testing.expect(runtime.instance_lifecycle.isCleanedUp(content));
    try expectImpostorElsewhere(page.realm, made);
    teardown.end();
    try testing.expect(!made.alive());
}

test "a node one realm still wraps keeps its slot through another realm's teardown" {
    var page = try Page.open();
    defer page.close();
    const other = try openRealm(page.agent);
    defer engine.destroyWindowRealm(other, .global_detached);
    const other_cache = try cacheOf(other);

    const tree = try Tree.make(page.realm);
    _ = try page.wrapIn(page.cache, tree.child);
    const kept_there = try page.wrapIn(other_cache, tree.child);
    const held = ffi.v8_Global_Clone(@ptrCast(kept_there)) orelse return error.HoldFailed;
    defer ffi.v8_Global_Dispose(held);
    const child = Made.of(tree.child);

    // Collected here during a teardown, wrapped there: no release, and the
    // tree's teardown leaves the slot to the wrapper that still reaches it.
    var teardown: Teardown = undefined;
    teardown.begin();
    page.collect();
    try testing.expect(!runtime.instance_lifecycle.provablyUnwrapped(true, tree.child));
    dom.node_creation.destroyUninserted(tree.root);
    teardown.end();
    try testing.expect(child.alive());
}
