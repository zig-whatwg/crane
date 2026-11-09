//! A wrap whose wrapper cache insert fails (OutOfMemory) fails: Codex row 15
//! Q22. template_registry.wrapInstanceAsV8Object logged and swallowed a failed
//! WrapperCache.set and handed back the wrapper as if the instance were
//! wrapped - nothing owned the instance, and callers' error paths never ran
//! (row 15's OOM trial leaked a stream graph and an AbortController). The
//! failure now propagates, the wrapper made for it is let go, and the
//! wrapper's counted reference (refcount step 4) is not taken.
//!
//! Since the wrapper redesign's P2 a NODE's wrap inserts into no cache (its
//! wrapper lives in its own slot, its agent's): the cache-insert cases use a
//! Headers, and a node's wrap fails the same way when its agent's node
//! wrappers have ended (engine.releaseNodeWrappers) - nothing taken, the
//! creator's reference still offered.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }
};

/// What every test here needs started: the engine, the process's hooks and
/// the standalone runtime (test_process.zig).
fn setup() !void {
    test_process.start();
}

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        try setup();
        const no_hooks: protocol.HostHooks = .{};
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm };
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn eval(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const held = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
    }

    fn instance(self: Page, source: []const u8) !*runtime.Instance {
        var reports: Reports = .{};
        const held = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
        return protocol.convertToPlatformObject(self.realm, held.value) orelse error.NotAPlatformObject;
    }

    fn instanceOrString(self: Page, source: []const u8) ![]u8 {
        var reports: Reports = .{};
        return protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
    }

    fn collect(self: Page) !void {
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                protocol.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
            }
        };
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
    }

    fn cache(self: Page) *v8.wrapper_cache_mod.WrapperCache {
        return @ptrCast(@alignCast(self.realm.getV8WrapperCacheStorage().?));
    }
};

const xhtml = "http://www.w3.org/1999/xhtml";

const Attempt = struct {
    instance: *runtime.Instance,
    realm: runtime.Context,
    interface: []const u8 = "Headers",
    result: ?anyerror = null,
    wrapped: bool = false,

    fn steps(data: ?*anyopaque) void {
        const self: *Attempt = @ptrCast(@alignCast(data.?));
        const isolate: *v8.ffi.Isolate = v8.ffi.v8_Isolate_GetCurrent().?;
        const context: *v8.ffi.Context = @ptrCast(@alignCast(self.realm.engine_ctx.?));
        if (v8.template_registry.wrapInstanceAsV8Object(self.instance, self.interface, isolate, context)) |_| {
            self.wrapped = true;
        } else |err| self.result = err;
    }
};

test "a wrap whose cache insert runs out of memory fails, and takes nothing" {
    const page = try Page.open();
    defer page.close();
    const headers = try interfaces.Headers.init(testing.allocator, page.realm);
    const cache = page.cache();

    var failing = std.testing.FailingAllocator.init(cache.allocator, .{ .fail_index = 0 });
    const saved = cache.allocator;
    cache.allocator = failing.allocator();
    var attempt: Attempt = .{ .instance = headers, .realm = page.realm };
    try protocol.runInRealm(page.realm, Attempt.steps, &attempt);
    cache.allocator = saved;

    try testing.expectEqual(@as(?anyerror, error.OutOfMemory), attempt.result);
    try testing.expect(!attempt.wrapped);
    // Nothing owns the instance through a wrapper.
    try testing.expect(!protocol.hasWrapper(headers));

    // With memory, the same instance wraps: its wrapper owns it from here
    // (the realm's end frees it).
    var again: Attempt = .{ .instance = headers, .realm = page.realm };
    try protocol.runInRealm(page.realm, Attempt.steps, &again);
    try testing.expect(again.wrapped);
    try testing.expect(protocol.hasWrapper(headers));
}

test "a node wrap after its agent's node wrappers ended fails, and takes nothing" {
    const page = try Page.open();
    defer page.close();
    const document = try page.instance("globalThis.d = new Document(); d");
    const div = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned(xhtml), runtime.DOMString.initInterned("div"), .{ .was_passed = false, .value = undefined });
    const node = dom.instance_bridge.getNodeBase(div).?;
    // The agent runs no more script: no node is wrapped from here on.
    protocol.releaseNodeWrappers(page.agent);
    var attempt: Attempt = .{ .instance = div, .realm = page.realm, .interface = "HTMLDivElement" };
    try protocol.runInRealm(page.realm, Attempt.steps, &attempt);
    try testing.expectEqual(@as(?anyerror, error.AgentEnded), attempt.result);
    try testing.expect(!attempt.wrapped);
    // Nothing owns the node through a wrapper, and the wrapper's counted
    // reference was never taken: its creator still offers its born one.
    try testing.expect(!protocol.hasWrapper(div));
    try testing.expect(node.wrapper.isEmpty());
    try testing.expect(node.rc_flags.creator);
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(node));
    // The creator, done with it unwrapped and uninserted, frees it.
    dom.node_creation.destroyUninserted(div);
}

test "the protocol's wrap (retainValue of an instance) reports the failed insert as OutOfMemory, not an undefined value" {
    const page = try Page.open();
    defer page.close();
    const headers = try interfaces.Headers.init(testing.allocator, page.realm);
    const cache = page.cache();
    var failing = std.testing.FailingAllocator.init(cache.allocator, .{ .fail_index = 0 });
    const saved = cache.allocator;
    cache.allocator = failing.allocator();
    const result = protocol.retainValue(page.realm, .{ .instance = headers });
    cache.allocator = saved;
    if (result) |held| {
        held.release();
        return error.WrapSucceededWithoutTheCache;
    } else |err| try testing.expectEqual(error.OutOfMemory, err);
    try testing.expect(!protocol.hasWrapper(headers));
    // A caller's error path runs: the instance is still the caller's.
    const held = try protocol.retainValue(page.realm, .{ .instance = headers });
    held.release();
    try testing.expect(protocol.hasWrapper(headers));
}

test "a constructor whose wrapper cannot be cached throws, and frees the instance it made" {
    const page = try Page.open();
    defer page.close();
    try page.eval("globalThis.outcome = 'none'; 'ok'");
    const cache = page.cache();
    var failing = std.testing.FailingAllocator.init(cache.allocator, .{ .fail_index = 0 });
    const saved = cache.allocator;
    const before = runtime.BrowserScope.standalone().?.slab.stats().currently_allocated;
    cache.allocator = failing.allocator();
    page.eval("try { globalThis.made = new Headers(); outcome = 'constructed'; } catch (e) { outcome = 'threw'; }") catch |err| {
        cache.allocator = saved;
        return err;
    };
    cache.allocator = saved;
    const after = runtime.BrowserScope.standalone().?.slab.stats().currently_allocated;
    const outcome = try page.instanceOrString("outcome");
    defer testing.allocator.free(outcome);
    try testing.expectEqualStrings("threw", outcome);
    // The Headers it made is freed: no instance is left that nothing owns.
    try testing.expectEqual(before, after);
}
