//! runtime.gc.releaseFailedConstruction: what the generated constructor's
//! errdefer does with the object it made when the constructor steps fail
//! (lane ctor1; WebIDL 3.7.1, the interface object's steps 1.8-1.9).
//!
//! - Never wrapped: nothing but the construction can reach it, so it is
//!   freed whole at once - destructor chain and storage - and the slab has
//!   the objects it had before.
//! - Wrapped by its own steps: script may still reach it through what the
//!   steps handed out (a controller given to start()), so it is left whole
//!   to its wrapper - it still works - and goes when script lets go of it,
//!   as in a browser, whose collector decides.

const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const testing = std.testing;

/// The live objects of the standalone runtime's slab, which the test's realm
/// (no Browser) makes its objects in.
fn liveObjects() usize {
    const scope = runtime.BrowserScope.standalone() orelse return 0;
    return scope.slab.stats().currently_allocated;
}

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

const no_hooks: protocol.HostHooks = .{};

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        test_process.start();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent_cluster_cross_origin_isolated = true,
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

    /// `source`'s completion value as a string; nothing reported.
    fn expect(self: Page, source: []const u8, expected: []const u8) !void {
        var reports: Reports = .{};
        const got = protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter()) catch |err| {
            std.debug.print("evaluating failed ({s}, {d} reported): {s}\n", .{ @errorName(err), reports.count, source });
            return err;
        };
        defer testing.allocator.free(got);
        try testing.expectEqual(@as(usize, 0), reports.count);
        try testing.expectEqualStrings(expected, got);
    }

    /// Full collections: what script let go of is finalized.
    fn collect(self: Page) !void {
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                protocol.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
            }
        };
        for (0..2) |_| try protocol.runInRealm(self.realm, Collect.steps, self.agent);
    }

    /// `object` as the global property `name`: wrapped, and reachable from
    /// script.
    fn expose(self: Page, name: []const u8, object: *runtime.Instance) !void {
        var reports: Reports = .{};
        const global = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = "globalThis" }, "", null, reports.reporter());
        defer global.release();
        try protocol.setProperty(self.realm, global.value, name, .{ .instance = object });
    }
};

test "a failed construction's object no wrapper took is freed whole at once" {
    const page = try Page.open();
    defer page.close();
    try page.collect();
    const before = liveObjects();
    for (0..64) |_| {
        const made = try interfaces.TextEncoder.call_constructor(page.realm);
        try testing.expectEqual(before + 1, liveObjects());
        runtime.gc.releaseFailedConstruction(made);
        // Its storage is back: no collection needed, none could free it.
        try testing.expectEqual(before, liveObjects());
    }
}

test "a failed construction's object its steps wrapped is left whole to the wrapper while script reaches it" {
    const page = try Page.open();
    defer page.close();
    try page.expect("globalThis.kept = null; 'ready'", "ready");
    try page.collect();
    const before = liveObjects();

    const made = try interfaces.TextEncoder.call_constructor(page.realm);
    // The steps handed it to script before a later step failed.
    try page.expose("kept", made);
    runtime.gc.releaseFailedConstruction(made);

    // Whole: not destroyed (releaseOwned would have run its destructor
    // chain now, under a wrapper script still reaches), not freed - script
    // still uses it.
    try testing.expect(!runtime.instance_lifecycle.isBeingCleanedUp(made));
    try testing.expect(!runtime.instance_lifecycle.isCleanedUp(made));
    try page.collect();
    try testing.expectEqual(before + 1, liveObjects());
    try page.expect("kept.encoding + ' ' + kept.encode('ab').length", "utf-8 2");

    // Its wrapper's end frees it once script lets go.
    try page.expect("globalThis.kept = null; 'dropped'", "dropped");
    try page.collect();
    try testing.expectEqual(before, liveObjects());
}
