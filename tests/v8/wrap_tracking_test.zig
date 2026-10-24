//! [wrap_tracking]: the V8 adapter marks every instance it binds an engine
//! object to (runtime.instance_lifecycle.markWrapped), on every path that
//! binds one and before any step of the bind can fail - so on V8 an
//! instance without the mark was never reachable from script, in any realm,
//! and a realm's end may free its storage (lane unwrapped1). A path that
//! bound a wrapper without the mark would let that end free a node under a
//! live JavaScript object: each path is pinned here. Custom element
//! construction and upgrade, which need the HTML host hooks a Browser
//! installs, are pinned in tests/html/unwrapped_page_storage_test.zig.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const lifecycle = runtime.instance_lifecycle;

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

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
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

fn nativeDiv(page: Page) !*runtime.Instance {
    const document = try page.instance("globalThis.d = new Document(); d");
    return interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned(xhtml), runtime.DOMString.initInterned("div"), .{ .was_passed = false, .value = undefined });
}

const Attempt = struct {
    instance: *runtime.Instance,
    realm: runtime.Context,
    result: ?anyerror = null,

    fn steps(data: ?*anyopaque) void {
        const self: *Attempt = @ptrCast(@alignCast(data.?));
        const isolate: *v8.ffi.Isolate = v8.ffi.v8_Isolate_GetCurrent().?;
        const context: *v8.ffi.Context = @ptrCast(@alignCast(self.realm.engine_ctx.?));
        _ = v8.template_registry.wrapInstanceAsV8Object(self.instance, "HTMLDivElement", isolate, context) catch |err| {
            self.result = err;
        };
    }
};

test "V8 declares wrap tracking" {
    comptime std.debug.assert(protocol.capabilities.wrap_tracking == .native);
}

test "a node made natively is unmarked until a wrap binds it (wrapInstanceAsV8Object)" {
    const page = try Page.open();
    defer page.close();
    const div = try nativeDiv(page);
    try testing.expect(!lifecycle.wasWrapped(div));
    try testing.expect(lifecycle.provablyUnwrapped(true, div));

    const held = try protocol.retainValue(page.realm, .{ .instance = div });
    held.release();
    try testing.expect(protocol.hasWrapper(div));
    try testing.expect(lifecycle.wasWrapped(div));
    try testing.expect(!lifecycle.provablyUnwrapped(true, div));
}

test "a wrap whose cache insert fails still marks the instance: the mark precedes the cache step" {
    const page = try Page.open();
    defer page.close();
    const div = try nativeDiv(page);
    const cache: *v8.wrapper_cache_mod.WrapperCache = @ptrCast(@alignCast(page.realm.getV8WrapperCacheStorage().?));

    var failing = std.testing.FailingAllocator.init(cache.allocator, .{ .fail_index = 0 });
    const saved = cache.allocator;
    cache.allocator = failing.allocator();
    var attempt: Attempt = .{ .instance = div, .realm = page.realm };
    try protocol.runInRealm(page.realm, Attempt.steps, &attempt);
    cache.allocator = saved;

    try testing.expectEqual(@as(?anyerror, error.OutOfMemory), attempt.result);
    try testing.expect(!protocol.hasWrapper(div));
    // An object reached the instance, if only until it was discarded: the
    // conservative answer keeps the storage.
    try testing.expect(lifecycle.wasWrapped(div));
}

test "a constructed instance is marked (setInstanceWithTypeInfo)" {
    // A constructor binds its instance to the `this` V8 made for it - a node
    // (this bare realm has no window document, so `new Document()`) or any
    // other platform object, through the same path.
    const page = try Page.open();
    defer page.close();
    const document = try page.instance("globalThis.d = new Document(); d");
    try testing.expect(lifecycle.wasWrapped(document));
    const headers = try page.instance("globalThis.h = new Headers(); h");
    try testing.expect(lifecycle.wasWrapped(headers));
}

test "a realm's Window is marked when its global object is bound" {
    const page = try Page.open();
    defer page.close();
    const window = try page.instance("globalThis");
    try testing.expect(lifecycle.wasWrapped(window));
}
