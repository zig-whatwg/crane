//! A TransformStream does not keep its startPromise past its construction
//! (lane ctor1; queue item 9 of tmp/plans/queue-0.1-audit.md).
//!
//! Streams 6.2.4, the constructor: step 9 makes startPromise, step 10
//! (InitializeTransformStream) gives both sides a start algorithm that
//! returns it, and step 12 resolves it with what transformer.start()
//! returns - or, when start() throws, the constructor rethrows and nothing
//! ever settles it. startPromise is no internal slot of the stream: once the
//! constructor returns, only the sides' start reactions wait on it, and a
//! browser collects it with them when script lets go of the stream.
//!
//! Crane kept it on the stream (a strong handle), and each side's start
//! reaction holds its controller until the promise settles
//! (dom/streams_js.zig `reactHolding`: a reaction whose promise is collected
//! unsettled gives its hold back). So a startPromise that never settled
//! kept itself alive through the stream that kept it, and with it the whole
//! stream - eight platform objects (the stream, its controller, both sides
//! and their controllers, the writable controller's AbortController and
//! AbortSignal) - until the realm ended: every
//! `new TransformStream({ start() { throw e; } })`, and every one whose
//! start() returns a promise that never settles.

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

    /// Full collections: what script let go of is finalized. A reaction on
    /// a promise collected unsettled gives its hold back from the
    /// collection that took the promise, and what it held goes with the
    /// next one.
    fn collect(self: Page) !void {
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                protocol.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
            }
        };
        for (0..4) |_| try protocol.runInRealm(self.realm, Collect.steps, self.agent);
    }

    /// Runs `source` - which answers `answer` - once to warm up, then again,
    /// and fails when the second run left platform objects in the slab
    /// after the collections.
    fn expectNothingLeft(self: Page, source: []const u8, answer: []const u8) !void {
        try self.expect(source, answer);
        try self.collect();
        const before = liveObjects();
        try self.expect(source, answer);
        try self.collect();
        const after = liveObjects();
        if (after != before) {
            std.debug.print("platform objects {d} -> {d}\n", .{ before, after });
            return error.InstanceLeaked;
        }
    }
};

test "a TransformStream whose transformer's start() throws frees what it made" {
    const page = try Page.open();
    defer page.close();
    // Step 12: the start algorithm's throw is rethrown - after step 10 made
    // the stream (and its readable and writable sides) and step 11 its
    // controller.
    try page.expectNothingLeft(
        \\(() => {
        \\  let n = 0;
        \\  for (let i = 0; i < 64; i++) {
        \\    try { new TransformStream({ start() { throw 7; } }); } catch (e) { if (e === 7) n++; }
        \\  }
        \\  return String(n);
        \\})()
    , "64");
}

// The other two constructors whose steps run start() after the make: no
// startPromise exists when start() throws there (SetUpReadableStream-
// DefaultController step 9, SetUpWritableStreamDefaultController step 15
// rethrow before it is made), so nothing waits on one.

test "a ReadableStream or WritableStream whose start() throws frees what it made" {
    const page = try Page.open();
    defer page.close();
    try page.expectNothingLeft(
        \\(() => {
        \\  let n = 0;
        \\  for (let i = 0; i < 32; i++) {
        \\    try { new ReadableStream({ start() { throw 7; } }); } catch (e) { if (e === 7) n++; }
        \\    try { new WritableStream({ start() { throw 7; } }); } catch (e) { if (e === 7) n++; }
        \\  }
        \\  return String(n);
        \\})()
    , "64");
}

test "a TransformStream whose start() never settles is freed once script lets go of it" {
    const page = try Page.open();
    defer page.close();
    // Step 12 resolves startPromise with a promise that never settles: the
    // sides wait on it for as long as anything reaches them, and nothing
    // does once script drops the stream and the promise.
    try page.expectNothingLeft(
        \\(() => {
        \\  let n = 0;
        \\  for (let i = 0; i < 64; i++) {
        \\    const ts = new TransformStream({ start() { return new Promise(() => {}); } });
        \\    if (ts.readable instanceof ReadableStream) n++;
        \\  }
        \\  return String(n);
        \\})()
    , "64");
}

test "the controller a throwing start() kept still works, and the stream goes once script lets go of it" {
    const page = try Page.open();
    defer page.close();
    // The constructor threw, but script holds the controller start() was
    // given: the stream behind it lives whole while it does (as in a
    // browser, where the collector decides). Its desired size is the
    // readable side's (TransformStreamDefaultController desiredSize: its
    // high-water mark 0 less an empty queue); enqueue and terminate act on
    // the sides.
    try page.expectNothingLeft(
        \\(() => {
        \\  let kept = [];
        \\  for (let i = 0; i < 16; i++) {
        \\    try { new TransformStream({ start(c) { kept.push(c); throw 7; } }); } catch (e) {}
        \\  }
        \\  let ok = 0;
        \\  for (const c of kept) {
        \\    if (c.desiredSize === 0) ok++;
        \\    c.enqueue('x');
        \\    if (c.desiredSize === -1) ok++;
        \\    c.terminate();
        \\  }
        \\  kept = null;
        \\  return String(ok);
        \\})()
    , "32");
}
