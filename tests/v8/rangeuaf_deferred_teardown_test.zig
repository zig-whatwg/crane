//! engine.deferTeardowns / resumeTeardowns (engine_protocol 4.12, lane
//! rangeuaf): while an agent's teardowns are held, its collections still run
//! but no collected platform object is torn down; the release that ends the
//! last hold tears them down, one at a time.
//!
//! The reason: V8 runs every pending second pass in the prologue of the next
//! collection, which any allocating engine call can start, and Crane tears a
//! collected wrapper's instance down there (wrapper_cache.finalizeCollected).
//! The live-range walks call into the engine for each range, so a collection
//! inside one tore down ranges the walk had not reached and the range it was
//! stepping. A hold around the walk makes those teardowns wait for its end.
//!
//! Real V8, a real agent (protocol.createAgent: the holds are its record's)
//! and a Window realm of it. The objects are instances of a mock interface
//! nobody owns, wrapped in the realm's cache as the binding wraps a platform
//! object script has seen; their deinit counts, and leaves the walked list
//! the way Range.deinit leaves its document's. A full collection
//! (LowMemoryNotification) runs every second pass synchronously, the same
//! callback a collection's prologue runs.
//!
//! No script may run inside a hold: in Debug builds the adapter's
//! script-running operations panic while their agent holds (Blink's
//! ScriptForbiddenScope, checked at the entry points; engine.holdTeardowns
//! lists them). A panic cannot be tested in this process, so the tests check
//! the predicate those operations ask, `teardownsHeldInRealm`, and that the
//! teardowns run with it false.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agent.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const v8 = @import("v8");
const dom = @import("dom");
const ffi = v8.ffi;

const List = dom.live_range_list.LiveList(*runtime.Instance);

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

fn reportNothing(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
    std.debug.print("reported: {s}\n", .{info.message});
}

/// An instance as (address, slab generation): a freed slot is reissued.
const Made = struct {
    instance: *runtime.Instance,
    generation: u64,

    fn alive(self: Made) bool {
        return runtime.SlabAllocator.generationOf(self.instance) == self.generation;
    }
};

/// What the mock deinit sees, for the page in use.
const Teardowns = struct {
    /// Each torn-down instance, as it was.
    freed: std.ArrayListUnmanaged(Made) = .empty,
    /// The list a torn-down instance leaves, as a Range leaves its
    /// document's live ranges.
    list: ?*List = null,
    /// Start a full collection from inside the first teardown, once.
    collect_once: bool = false,
    page: ?*Page = null,
    /// A teardown ran while script was still forbidden.
    under_guard: bool = false,

    fn count(self: *const Teardowns, made: Made) usize {
        var n: usize = 0;
        for (self.freed.items) |f| {
            if (f.instance == made.instance and f.generation == made.generation) n += 1;
        }
        return n;
    }
};

/// tests/v8 shares a process, and these tests run on its main thread in
/// turn: one page's teardowns at a time.
var current: Teardowns = .{};

fn countingDeinit(instance: *runtime.Instance) void {
    current.freed.append(std.heap.page_allocator, .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) }) catch {};
    if (current.page) |page| {
        if (v8.wrapper_cache_mod.teardownsHeldInRealm(page.realm)) current.under_guard = true;
    }
    if (current.list) |list| list.remove(instance);
    if (current.collect_once) {
        current.collect_once = false;
        if (current.page) |page| page.collect();
    }
}

const mock_methods: u8 = 0;
/// An interface nobody owns (not a node, not a window's): the weak default.
const mock_vtable = runtime.VTable{
    .name = "MockDeferredTeardown",
    .deinit = countingDeinit,
    .methods_ptr = &mock_methods,
};
var mock_state: u64 = 0;

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
        const realm = try engine.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
        const storage = realm.getV8WrapperCacheStorage() orelse return error.NoWrapperCache;
        ffi.v8_Isolate_Enter(isolate);
        ffi.v8_Context_Enter(@ptrCast(realm.engine_ctx.?));
        return .{ .agent = agent, .realm = realm, .isolate = isolate, .cache = @ptrCast(@alignCast(storage)) };
    }

    fn close(self: *Page) void {
        ffi.v8_Context_Exit(@ptrCast(self.realm.engine_ctx.?));
        ffi.v8_Isolate_Exit(self.isolate);
        engine.destroyWindowRealm(self.realm, .global_detached);
        engine.destroyAgent(self.agent);
        current.freed.deinit(std.heap.page_allocator);
        current = .{};
    }

    /// A new instance of the realm, wrapped and held by nothing: the
    /// collector takes its wrapper at the next full collection.
    fn wrapped(self: *Page) !Made {
        const instance = try runtime.BrowserScope.standalone().?.slab.alloc(&mock_vtable);
        instance.state = @ptrCast(&mock_state);
        instance.ctx = self.realm;
        const wrapper = ffi.v8_Object_New(self.isolate) orelse return error.ObjectFailed;
        try self.cache.set(instance, @ptrCast(wrapper), self.isolate);
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    /// A full collection: every second pass runs before it returns.
    fn collect(self: *Page) void {
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate);
    }

    fn holds(self: *Page) *v8.wrapper_cache_mod.TeardownHolds {
        return v8.protocol_agents.teardownHoldsOf(self.isolate).?;
    }

    /// `source`'s completion value as a string, which must be `expected`.
    fn expectScript(self: *Page, source: []const u8, expected: []const u8) !void {
        const got = try engine.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, std.testing.allocator, .{ .report = reportNothing });
        defer std.testing.allocator.free(got);
        try std.testing.expectEqualStrings(expected, got);
    }
};

fn expectAllFreedOnce(made: []const Made) !void {
    for (made) |m| try std.testing.expectEqual(@as(usize, 1), current.count(m));
}

fn expectNoneFreed(made: []const Made) !void {
    for (made) |m| {
        try std.testing.expectEqual(@as(usize, 0), current.count(m));
        try std.testing.expect(m.alive());
    }
}

test "without a hold, a full collection tears a collected object down before it returns" {
    var page = try Page.open();
    defer page.close();
    var made: [8]Made = undefined;
    for (&made) |*m| m.* = try page.wrapped();
    page.collect();
    try expectAllFreedOnce(&made);
    try std.testing.expectEqual(@as(usize, 0), page.holds().deferredCount());
}

test "inside a hold, collections tear nothing down; its release tears down what they collected" {
    var page = try Page.open();
    defer page.close();
    current.page = &page;
    var made: [50]Made = undefined;
    for (&made) |*m| m.* = try page.wrapped();
    {
        const hold = engine.holdTeardowns(page.realm);
        defer hold.release();
        page.collect();
        page.collect();
        try expectNoneFreed(&made);
        try std.testing.expectEqual(@as(usize, made.len), page.holds().deferredCount());
        // Collected all the same: the binding no longer reaches them.
        for (made) |m| try std.testing.expect(page.cache.get(m.instance) == null);
        // Script is forbidden for the length of the hold: the predicate the
        // adapter's script-running operations ask (Debug builds panic on it).
        try std.testing.expect(v8.wrapper_cache_mod.teardownsHeldInRealm(page.realm));
        try std.testing.expect(page.holds().forbidsScript());
    }
    try expectAllFreedOnce(&made);
    try std.testing.expectEqual(@as(usize, 0), page.holds().deferredCount());
    try std.testing.expectEqual(@as(u32, 0), page.holds().count);
    // Script was allowed again before the teardowns ran, and it runs.
    try std.testing.expect(!current.under_guard);
    try std.testing.expect(!v8.wrapper_cache_mod.teardownsHeldInRealm(page.realm));
    try page.expectScript("6 * 7", "42");
}

test "holds nest: only the release that ends the outermost one tears down" {
    var page = try Page.open();
    defer page.close();
    var made: [10]Made = undefined;
    for (&made) |*m| m.* = try page.wrapped();
    const outer = engine.holdTeardowns(page.realm);
    {
        const inner = engine.holdTeardowns(page.realm);
        defer inner.release();
        page.collect();
    }
    try expectNoneFreed(&made);
    try std.testing.expectEqual(@as(usize, made.len), page.holds().deferredCount());
    // Script stays forbidden until the outermost hold ends.
    try std.testing.expect(v8.wrapper_cache_mod.teardownsHeldInRealm(page.realm));
    outer.release();
    try std.testing.expect(!v8.wrapper_cache_mod.teardownsHeldInRealm(page.realm));
    try expectAllFreedOnce(&made);
}

test "a walk inside a hold sees no teardown, of the entries ahead of it or the one it is on" {
    var page = try Page.open();
    defer page.close();
    var list: List = .empty;
    defer list.deinit(std.testing.allocator);
    var made: [40]Made = undefined;
    for (&made) |*m| {
        m.* = try page.wrapped();
        try list.add(std.testing.allocator, m.instance);
    }
    current.list = &list;

    var visited: usize = 0;
    {
        const hold = engine.holdTeardowns(page.realm);
        defer hold.release();
        var walk: List.Walk = undefined;
        list.beginWalk(&walk);
        defer list.endWalk(&walk);
        while (walk.nextEntry()) |instance| {
            // A step's engine call starts a collection, here at the third.
            if (visited == 2) page.collect();
            try std.testing.expect(made[visited].instance == instance);
            try std.testing.expect(made[visited].alive());
            try std.testing.expectEqual(made.len, list.count());
            visited += 1;
        }
    }
    try std.testing.expectEqual(made.len, visited);
    // The release tore them down, after the walk: each left the list.
    try expectAllFreedOnce(&made);
    try std.testing.expect(list.isEmpty());
}

test "a teardown the release runs may start a collection; what that collects goes at once, and nothing twice" {
    var page = try Page.open();
    defer page.close();
    // Group A dies inside the hold; group B's wrappers are kept until after
    // the hold's collection, then let go.
    var a: [20]Made = undefined;
    for (&a) |*m| m.* = try page.wrapped();
    var b: [20]Made = undefined;
    var b_holds: [20]*ffi.Value = undefined;
    for (&b, &b_holds) |*m, *strong| {
        m.* = try page.wrapped();
        const wrapper = page.cache.get(m.instance) orelse return error.NotWrapped;
        strong.* = ffi.v8_Global_Clone(@ptrCast(wrapper)) orelse return error.CloneFailed;
    }
    {
        const hold = engine.holdTeardowns(page.realm);
        defer {
            for (b_holds) |strong| ffi.v8_Global_Dispose(strong);
            // The first teardown the release runs starts a full collection:
            // B's wrappers die in it and, no hold left, B is torn down there
            // - inside the release's loop, which must take each next entry
            // afresh.
            current.page = &page;
            current.collect_once = true;
            hold.release();
        }
        page.collect();
        try expectNoneFreed(&a);
        try expectNoneFreed(&b);
        try std.testing.expectEqual(@as(usize, a.len), page.holds().deferredCount());
    }
    try std.testing.expect(!current.collect_once);
    try expectAllFreedOnce(&a);
    try expectAllFreedOnce(&b);
    try std.testing.expectEqual(@as(usize, 0), page.holds().deferredCount());
}
