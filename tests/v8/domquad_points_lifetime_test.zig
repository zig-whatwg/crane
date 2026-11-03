//! A DOMQuad's points live as long as the quad, and script's hold on them.
//!
//! The quad makes its four DOMPoints when it is made (Geometry 1, "create a
//! DOMQuad from four DOMPointInit": each point a new DOMPoint) and keeps them
//! as bare pointers. A point script reads through its [SameObject] getter is
//! traced from the quad's wrapper (dom.same_object_cache) and owned by its own
//! wrapper from then on. A point script never read was nobody's but the
//! quad's, and the quad's deinit let it go without freeing it: every quad
//! whose points were not all read left them in the slab until its Browser
//! ended (tests-v8's state survey, lane v8state1: three points of the
//! structuredClone test's quad). WebKit's DOMQuad holds its points by Ref
//! (Source/WebCore/css/DOMQuad.h, `Ref<DOMPoint> m_p1`), so a point no one
//! else holds dies with its quad.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! and makes its own agents.

const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const no_hooks: protocol.HostHooks = .{};

/// Counts what the realm reports; a test expects none.
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

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        test_process.start();
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

    fn expect(self: Page, source: []const u8, expected: []const u8) !void {
        var reports: Reports = .{};
        const got = try protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, std.testing.allocator, reports.reporter());
        defer std.testing.allocator.free(got);
        try std.testing.expectEqual(@as(usize, 0), reports.count);
        try std.testing.expectEqualStrings(expected, got);
    }

    /// A full collection, twice: each quad's wrapper is finalized, and with
    /// it every point only that quad held.
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

/// The platform objects in the standalone runtime's slab, which the test's
/// realm (no Browser) makes its objects in.
fn liveObjects() usize {
    const scope = runtime.BrowserScope.standalone() orelse return 0;
    return scope.slab.stats().currently_allocated;
}

/// Runs `source` (which answers "ok") once to warm up, then again between
/// two collections, and fails when the second run left objects behind.
fn expectNothingLeft(page: Page, source: []const u8) !void {
    try page.expect(source, "ok");
    try page.collect();
    const before = liveObjects();
    try page.expect(source, "ok");
    try page.collect();
    const after = liveObjects();
    if (after != before) {
        std.debug.print("platform objects {d} -> {d}\n", .{ before, after });
        return error.ObjectsLeft;
    }
}

test "a DOMQuad whose points script never read frees them with itself" {
    const page = try Page.open();
    defer page.close();
    try expectNothingLeft(page,
        \\(() => {
        \\  for (let i = 0; i < 64; i++) new DOMQuad({ x: i }, { y: i }, { z: i }, { w: i });
        \\  return 'ok';
        \\})()
    );
}

test "a DOMQuad frees the points script never read, and leaves a read one to its wrapper" {
    const page = try Page.open();
    defer page.close();
    try expectNothingLeft(page,
        \\(() => {
        \\  for (let i = 0; i < 64; i++) {
        \\    const quad = new DOMQuad({ x: i }, { y: i }, { z: i }, { w: i });
        \\    if (quad.p1.x !== i || quad.p3.z !== i) throw new Error('wrong point');
        \\  }
        \\  return 'ok';
        \\})()
    );
}

test "a point script still holds outlives its quad" {
    const page = try Page.open();
    defer page.close();
    try page.expect(
        \\globalThis.kept = new DOMQuad({ x: 1 }, { y: 2 }, { z: 3 }, { w: 4 }).p2;
        \\kept.extra = 'mine';
        \\'ok'
    , "ok");
    try page.collect();
    try page.expect("[kept.y, kept.extra, kept instanceof DOMPoint].join()", "2,mine,true");
    try page.expect("delete globalThis.kept; 'ok'", "ok");
}

test "a quad structuredClone made frees the points script never read" {
    const page = try Page.open();
    defer page.close();
    try expectNothingLeft(page,
        \\(() => {
        \\  const quad = new DOMQuad({ x: 1 }, { y: 2 }, { z: 3 }, { w: 4 });
        \\  for (let i = 0; i < 16; i++) {
        \\    const copy = structuredClone(quad);
        \\    if (copy.p4.w !== 4) throw new Error('wrong point');
        \\  }
        \\  return 'ok';
        \\})()
    );
}
