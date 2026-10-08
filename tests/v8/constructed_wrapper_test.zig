//! A constructor's result is THE wrapper of its instance (PR-M1's adapter
//! root cause, tmp/analysis/fix-list.md).
//!
//! The binding binds a constructed instance to the object V8 made for
//! NewTarget - the generic constructor path, and [HTMLConstructor]'s
//! `.created` and never-wrapped `.upgrading` answers. Two defects lived there:
//!
//! - An instance its own construction had already wrapped (a template's
//!   establish step traced its content from it) had that wrapper REPLACED, and
//!   every edge drawn on it - the template's content, the element's registry -
//!   went with it. Now the existing wrapper is the result, with NewTarget's
//!   prototype, as for an upgrade; and `WrapperCache.set` refuses to replace
//!   a live wrapper at all, so no edge is ever dropped that way.
//! - A constructed NODE was never given its node's wrapper alias
//!   (`NodeBase.bound_v8_wrapper`), so node tracing drew no tree edges for it:
//!   `f.appendChild(new Text())` left the text's wrapper - its expandos, a
//!   custom element's class - to the next collection.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agents.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

/// The custom elements side: answers `.created` with a new HTMLElement - and,
/// with `prewrap`, wraps it first and traces `child` from that wrapper, as an
/// element whose creation made its wrapper would have.
const Host = struct {
    prewrap: bool = false,
    /// The element's wrapper made during its creation, held until the test
    /// lets go of it.
    early_wrapper: ?protocol.Owned = null,
    element: ?*runtime.Instance = null,
    child: ?*runtime.Instance = null,

    const hooks: protocol.HostHooks = .{ .htmlConstructor = construct };

    fn construct(host: ?*anyopaque, realm: runtime.Context, new_target: runtime.JSValue, interface: []const u8) protocol.Error!protocol.HTMLConstructed {
        _ = new_target;
        _ = interface;
        const self: *Host = @ptrCast(@alignCast(host.?));
        const element = interfaces.HTMLElement.call_constructor(realm) catch return error.OperationFailed;
        self.element = element;
        if (self.prewrap) {
            self.early_wrapper = try protocol.retainValue(realm, .{ .instance = element });
            const child = interfaces.HTMLElement.call_constructor(realm) catch return error.OperationFailed;
            self.child = child;
            protocol.traceChild(element, child, .{ .name = "lf1 early child" });
        }
        return .{ .created = element };
    }

    fn releaseEarlyWrapper(self: *Host) void {
        if (self.early_wrapper) |held| held.release();
        self.early_wrapper = null;
    }
};

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
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    pools_ready = true;
}

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open(hooks: *const protocol.HostHooks, host: ?*anyopaque) !Page {
        try setup();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = hooks, .host = host });
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

    fn expect(self: Page, source: []const u8, expected: []const u8) !void {
        var reports: Reports = .{};
        const got = protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, std.testing.allocator, reports.reporter()) catch |err| {
            std.debug.print("evaluating failed ({s}, {d} reported): {s}\n", .{ @errorName(err), reports.count, source });
            return err;
        };
        defer std.testing.allocator.free(got);
        try std.testing.expectEqual(@as(usize, 0), reports.count);
        try std.testing.expectEqualStrings(expected, got);
    }

    fn value(self: Page, source: []const u8) !protocol.Owned {
        var reports: Reports = .{};
        return protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
    }

    fn instance(self: Page, source: []const u8) !*runtime.Instance {
        const held = try self.value(source);
        defer held.release();
        return protocol.convertToPlatformObject(self.realm, held.value) orelse error.NotAPlatformObject;
    }

    /// Two full collections, inside the realm (the second takes what the
    /// first one's finalizers let go).
    fn collect(self: Page) !void {
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                protocol.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
            }
        };
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
    }
};

test "a node made by its constructor is its node's wrapper: inserted, node tracing keeps it" {
    const no_hooks: protocol.HostHooks = .{};
    const page = try Page.open(&no_hooks, null);
    defer page.close();
    try page.expect(
        \\globalThis.f = new DocumentFragment();
        \\(() => { const t = new Text('t'); t.expando = 7; f.appendChild(t); })();
        \\'ok'
    , "ok");
    try page.collect();
    try page.expect("String(f.firstChild.expando)", "7");
}

test "a custom element class constructed with no host hook keeps its wrapper - class and expandos - once inserted" {
    // No HostHooks.htmlConstructor: [HTMLConstructor] constructs as its own
    // constructor does, the generic path, with NewTarget's prototype. (The
    // `.created` answer of a real custom elements side, inserted, is
    // tests/html/template_content_lifetime_test.zig's: this file's test host
    // is no custom elements agent, and [CEReactions] would read it as one.)
    const no_hooks: protocol.HostHooks = .{};
    const page = try Page.open(&no_hooks, null);
    defer page.close();
    try page.expect(
        \\globalThis.X = class X extends HTMLElement {};
        \\globalThis.f = new DocumentFragment();
        \\(() => { const x = new X(); x.expando = 'kept'; f.appendChild(x); })();
        \\'ok'
    , "ok");
    try page.collect();
    try page.expect("String(f.firstChild instanceof X && f.firstChild.expando === 'kept')", "true");
}

test "created: an element its creation already wrapped keeps that wrapper as the result, with its edges" {
    var host: Host = .{ .prewrap = true };
    const page = try Page.open(&Host.hooks, &host);
    defer page.close();
    defer host.releaseEarlyWrapper();

    try page.expect(
        \\globalThis.X = class X extends HTMLElement { constructor() { super(); this.marked = true; } };
        \\globalThis.made = new X();
        \\String(made instanceof X && Object.getPrototypeOf(made) === X.prototype && made.marked === true)
    , "true");
    const element = host.element.?;
    const child = host.child.?;
    const child_generation = runtime.SlabAllocator.generationOf(child);
    try std.testing.expectEqual(element, try page.instance("made"));

    // The result IS the wrapper the element's creation made.
    const made = try page.value("made");
    defer made.release();
    try std.testing.expect(protocol.sameValue(page.realm, made.value, host.early_wrapper.?.value));

    // The edge drawn on that wrapper is the result's: with the early hold
    // gone, the child lives exactly as long as `made` does.
    host.releaseEarlyWrapper();
    try page.collect();
    try std.testing.expectEqual(child_generation, runtime.SlabAllocator.generationOf(child));
    const traced = protocol.tracedValue(element, .{ .name = "lf1 early child" }) orelse return error.EdgeLost;
    defer traced.release();
    try std.testing.expectEqual(child, protocol.convertToPlatformObject(page.realm, traced.value) orelse return error.EdgeLost);
}

test "WrapperCache.set refuses to replace a live wrapper, keeping it and its edges" {
    const no_hooks: protocol.HostHooks = .{};
    const page = try Page.open(&no_hooks, null);
    defer page.close();
    try page.expect("globalThis.e = new Text('a'); e.expando = 1; 'ok'", "ok");
    const text = try page.instance("e");

    const Replace = struct {
        page: Page,
        instance: *runtime.Instance,
        result: ?anyerror = null,
        fn steps(data: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            const other = self.page.value("({})") catch |err| {
                self.result = err;
                return;
            };
            defer other.release();
            const storage = self.instance.ctx.getV8WrapperCacheStorage() orelse {
                self.result = error.NoCache;
                return;
            };
            const cache: *v8.WrapperCache = @ptrCast(@alignCast(storage));
            // A Global of our own for the cache to take - it must not.
            const handle = ffi.v8_Global_Clone(@ptrCast(other.value.handle.ptr)) orelse {
                self.result = error.NoHandle;
                return;
            };
            cache.set(self.instance, @ptrCast(handle), @ptrCast(@alignCast(self.page.agent))) catch |err| {
                ffi.v8_Global_Dispose(handle);
                self.result = err;
                return;
            };
            self.result = error.Replaced;
        }
    };
    var replace: Replace = .{ .page = page, .instance = text };
    try protocol.runInRealm(page.realm, Replace.steps, &replace);
    try std.testing.expectEqual(@as(?anyerror, error.AlreadyWrapped), replace.result);
    try page.collect();
    try page.expect("String(e.expando === 1 && e.data === 'a')", "true");
}
