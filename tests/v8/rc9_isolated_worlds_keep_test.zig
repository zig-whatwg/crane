//! Lane rc9 Part B.2: engine.keepPlatformObjectAlive across isolated worlds.
//!
//! A platform object whose relevant realm is the main realm (e.g. a
//! PermissionStatus or a ReportingObserver obtained through a world's
//! navigator/window) can be wrapped ONLY in an isolated world while the main
//! realm has no wrapper of it. Before rc9, `holdForPendingActivity` checked
//! only the instance's own realm's WrapperCache (putting the keep in
//! `pending_before_wrap` and leaving the world wrapper weak), so a full
//! collection collected the world's wrapper and dropped the object and its
//! listeners while pending activity was active (lesson
//! architecture-a-has-script-seen-it-check-must-ask-every-world.md).
//!
//! These tests pin every ordering:
//! 1. Wrapped only in an isolated world -> keepPlatformObjectAlive -> GC keeps
//!    the world's wrapper and listener alive -> releasePlatformObject -> GC
//!    collects it.
//! 2. keepPlatformObjectAlive BEFORE wrap -> wrapped only in an isolated world
//!    -> GC keeps the world's wrapper alive -> releasePlatformObject -> GC
//!    collects it.
//! 3. Wrapped in BOTH main realm and isolated world -> keepPlatformObjectAlive
//!    -> GC keeps BOTH wrappers alive -> releasePlatformObject -> GC collects
//!    both.
//! 4. Wrapped in main realm -> keepPlatformObjectAlive -> later wrapped in an
//!    isolated world -> GC keeps BOTH wrappers alive -> releasePlatformObject
//!    -> GC collects both.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const test_process = @import("test_process.zig");
const v8 = @import("v8");

const Host = struct {
    fn window(r: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(testing.allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }
};

fn expect(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    var reports: Reports = .{};
    const got = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = Reports.report, .host = &reports });
    defer testing.allocator.free(got);
    try testing.expectEqual(@as(usize, 0), reports.count);
    if (!std.mem.eql(u8, expected, got)) std.debug.print("{s}\n  -> {s}\n", .{ source, got });
    try testing.expectEqualStrings(expected, got);
}

const Page = struct {
    own_runtime: test_process.OwnRuntime,
    browser: *runtime.BrowserScope,
    agent: *engine.Agent,
    realm: runtime.Context,
    context: *dom.browser_state.BrowsingContext,

    fn make() !Page {
        test_process.start();
        const own_runtime = test_process.OwnRuntime.begin(testing.allocator);
        errdefer own_runtime.end();
        const browser = try testing.allocator.create(runtime.BrowserScope);
        errdefer testing.allocator.destroy(browser);
        browser.* = runtime.BrowserScope.init(testing.allocator);
        errdefer browser.deinit();
        const hooks: *const engine.HostHooks = &.{};
        const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = hooks, .allocator = testing.allocator });
        errdefer engine.destroyAgent(agent);
        const realm = try engine.createWindowRealm(&.{
            .agent_cluster_cross_origin_isolated = true,
            .agent = agent,
            .allocator = testing.allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .browser_scope = browser,
            .create_global_object = Host.window,
        });
        errdefer engine.destroyWindowRealm(realm, .global_detached);
        const record = realm.getRealm() orelse return error.NoWindow;
        const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return error.NoWindow));
        const document = try interfaces.Document.init(testing.allocator, realm);
        try dom.document_internals.setDocumentType(document, .html);
        dom.window_globals.setDocument(window, document);
        dom.document_browsing_context.setWindow(document, window);
        const navigables = dom.browser_state.navigablesOf(realm) orelse return error.NoNavigables;
        const context = try dom.browser_state.BrowsingContext.initTopLevel(testing.allocator, navigables);
        errdefer context.releaseByOwner();
        context.setActiveDocument(document, window);
        return .{ .own_runtime = own_runtime, .browser = browser, .agent = agent, .realm = realm, .context = context };
    }

    fn end(self: *Page) void {
        self.context.releaseByOwner();
        engine.destroyWindowRealm(self.realm, .global_detached);
        engine.destroyAgent(self.agent);
        self.browser.deinit();
        testing.allocator.destroy(self.browser);
        self.own_runtime.end();
    }

    fn world(self: *Page, id: engine.WorldId) !runtime.Context {
        return engine.createWorldRealm(self.realm, &.{ .world = id, .name = "__rc9_keep_world__" });
    }

    fn gc(self: *Page) void {
        for (0..4) |_| engine.requestGarbageCollection(self.agent);
    }

    fn cacheOf(realm: runtime.Context) *v8.WrapperCache {
        return @ptrCast(@alignCast(realm.getV8WrapperCacheStorage().?));
    }
};

/// Wrap `target` (a main-realm EventTarget) into `realm` and drop the handle
/// immediately, leaving only `realm`'s wrapper cache referencing it.
fn wrapAndDrop(realm: runtime.Context, target: *runtime.Instance) !void {
    const held = try engine.retainValue(realm, .{ .instance = target });
    held.release();
}

test "keepPlatformObjectAlive keeps a platform object wrapped ONLY in an isolated world, and releases it after" {
    var page = try Page.make();
    defer page.end();
    const world = try page.world(1);

    const target = try interfaces.EventTarget.init(testing.allocator, page.realm);
    const generation = runtime.SlabAllocator.generationOf(target);

    // Wrap ONLY in the isolated world; main realm has never wrapped it.
    try wrapAndDrop(world, target);
    try testing.expect(Page.cacheOf(page.realm).get(target) == null);
    try testing.expect(Page.cacheOf(world).get(target) != null);

    // Attach a world listener to verify the wrapper + traced listener survive.
    {
        const held = try engine.retainValue(world, .{ .instance = target });
        defer held.release();
        var reports: Reports = .{};
        const global = try engine.evaluateClassicScript(world, .{ .utf8 = "globalThis" }, "", null, .{ .report = Reports.report, .host = &reports });
        defer global.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
        try engine.setProperty(world, global.value, "__target", held.value);
        try expect(world, "globalThis.fired = 0; __target.addEventListener('ping', () => { globalThis.fired++; }); delete globalThis.__target; 'ok'", "ok");
    }

    // Pending activity keep while wrapped ONLY in the world.
    engine.keepPlatformObjectAlive(target);
    page.gc();

    // Must still be alive and wrapped in the world.
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(target));
    try testing.expect(Page.cacheOf(world).get(target) != null);
    try testing.expect(engine.hasWrapper(target));

    // Dispatching an event reaches the world listener that survived GC.
    const event = try interfaces.Event.call_constructor(page.realm, runtime.DOMString.initInterned("ping"), .{ .was_passed = false, .value = undefined });
    const event_gen = runtime.SlabAllocator.generationOf(event);
    _ = try interfaces.EventTarget.call_dispatchEvent(target, event);
    event.releaseIfUnwrapped(event_gen);
    try expect(world, "String(globalThis.fired)", "1");

    // Releasing the keep allows the world wrapper and target to collect.
    engine.releasePlatformObject(target);
    page.gc();
    try testing.expect(runtime.SlabAllocator.generationOf(target) != generation);
}

test "keepPlatformObjectAlive before wrap is adopted when wrapped ONLY in an isolated world" {
    var page = try Page.make();
    defer page.end();
    const world = try page.world(1);

    const target = try interfaces.EventTarget.init(testing.allocator, page.realm);
    const generation = runtime.SlabAllocator.generationOf(target);

    // Keep BEFORE any wrapper exists anywhere.
    engine.keepPlatformObjectAlive(target);
    try wrapAndDrop(world, target);
    try testing.expect(Page.cacheOf(page.realm).get(target) == null);
    try testing.expect(Page.cacheOf(world).get(target) != null);

    page.gc();
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(target));
    try testing.expect(Page.cacheOf(world).get(target) != null);

    engine.releasePlatformObject(target);
    page.gc();
    try testing.expect(runtime.SlabAllocator.generationOf(target) != generation);
}

test "keepPlatformObjectAlive keeps wrappers in BOTH main realm and isolated world (wrapped before and after keep)" {
    var page = try Page.make();
    defer page.end();
    const world1 = try page.world(1);
    const world2 = try page.world(2);

    const target = try interfaces.EventTarget.init(testing.allocator, page.realm);
    const generation = runtime.SlabAllocator.generationOf(target);

    // Main and world1 wrap before keep; world2 wraps after keep.
    try wrapAndDrop(page.realm, target);
    try wrapAndDrop(world1, target);
    engine.keepPlatformObjectAlive(target);
    try wrapAndDrop(world2, target);

    page.gc();
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(target));
    try testing.expect(Page.cacheOf(page.realm).get(target) != null);
    try testing.expect(Page.cacheOf(world1).get(target) != null);
    try testing.expect(Page.cacheOf(world2).get(target) != null);

    engine.releasePlatformObject(target);
    page.gc();
    try testing.expect(runtime.SlabAllocator.generationOf(target) != generation);
}
