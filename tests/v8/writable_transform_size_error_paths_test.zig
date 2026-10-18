//! `new WritableStream(sink, strategy)` and `new TransformStream(transformer,
//! writableStrategy, readableStrategy)` release each strategy's `size`
//! callback on every path that throws before the stream takes it.
//!
//! The binding hands a callback member over to the impl
//! (memberHandleIsSafe: a callback member adopts the handle Get made for it),
//! and only ExtractSizeAlgorithm takes it (Streams 5.2.4 step 5; 6.2.4 steps
//! 6 and 8). Every throw before that dropped it with its Global for the
//! agent's life, as ReadableStream's did (lane leaks4, c12bba6177d):
//!
//! - WritableStream: step 1, an underlying sink that is not an object; step
//!   2, its dictionary conversion throwing (a getter, a member that is not
//!   callable); step 3, a present `type` (RangeError).
//! - TransformStream: step 1; steps 2-4, the conversion and a present
//!   readableType or writableType (RangeError); step 5, the readable
//!   strategy's ExtractHighWaterMark (RangeError) - before either size is
//!   taken; step 7, the writable strategy's - after the readable size was
//!   taken and before the writable one is.
//!
//! Each test reads V8's own live handle count over 64 constructions against
//! a control that takes the same path with no size function
//! (docs/lessons/testing-a-handle-leak-test-needs-v8-s-live-count.md).

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

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

fn setup() !void {
    try protocol.initializeEngine(.{});
    interfaces.process_hooks.startHooksForTest();
    if (runtime.BrowserScope.standalone() == null) runtime.initializeRuntime(std.heap.page_allocator);
}

const no_hooks: protocol.HostHooks = .{};

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        try setup();
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

    fn isolate(self: Page) *ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    fn settleAndCollect(self: Page) !void {
        for (0..4) |_| try protocol.performMicrotaskCheckpoint(self.agent);
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                protocol.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
            }
        };
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
    }

    fn run(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const got = protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter()) catch |err| {
            std.debug.print("evaluating failed ({s}, {d} reported): {s}\n", .{ @errorName(err), reports.count, source });
            return err;
        };
        defer testing.allocator.free(got);
        try testing.expectEqual(@as(usize, 0), reports.count);
        try testing.expectEqualStrings("ok", got);
    }

    /// The global handle bytes 64 runs of `statement` leave once a first
    /// round has made what later ones reuse. `statement` must throw a
    /// `expected` error; anything else fails the run.
    fn handleBytesLeftBy(self: Page, comptime statement: []const u8, comptime expected: []const u8) !i64 {
        const loop =
            \\(() => {
            \\  globalThis.sizeFn ||= function size() { return 1; };
            \\  for (var k = 0; k < 64; k++) {
            \\    let threw = null;
            \\    try {
        ++ statement ++
            \\;
            \\    } catch (e) { threw = e; }
            \\    if (threw === null) return "did not throw";
            \\    if (threw.name !== "
        ++ expected ++
            \\") return "threw " + threw;
            \\  }
            \\  return "ok";
            \\})()
        ;
        try self.run(loop);
        try self.settleAndCollect();
        const before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate()));
        try self.run(loop);
        try self.settleAndCollect();
        const after: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate()));
        return after - before;
    }

    fn oneHandleBytes(self: Page) i64 {
        const start = ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate());
        const one = ffi.v8_Number_New(self.isolate(), 1);
        const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate());
        ffi.v8_Value_Dispose(@ptrCast(one));
        return @intCast(with_one - start);
    }

    /// `statement` leaves no more handles over 64 throws than `control`,
    /// which throws the same way with no size function: fewer than 8
    /// handles of difference, where one per call is 64.
    fn expectNoMoreThan(self: Page, comptime control: []const u8, comptime statement: []const u8, comptime expected: []const u8) !void {
        const control_left = try self.handleBytesLeftBy(control, expected);
        const left = try self.handleBytesLeftBy(statement, expected);
        const one = self.oneHandleBytes();
        if (left - control_left >= one * 8) {
            std.debug.print("64 x `{s}` left {d} bytes of global handles; the control `{s}` left {d} ({d} a handle)\n", .{ statement, left, control, control_left, one });
            return error.HandlesLeaked;
        }
    }
};

test "an underlying sink that is not an object throws and releases the strategy's size" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoMoreThan(
        "new WritableStream(5, {highWaterMark: 1})",
        "new WritableStream(5, {size: sizeFn})",
        "TypeError",
    );
}

test "an underlying sink whose conversion throws releases the strategy's size" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoMoreThan(
        "new WritableStream({get write() { throw new SyntaxError('no'); }}, {highWaterMark: 1})",
        "new WritableStream({get write() { throw new SyntaxError('no'); }}, {size: sizeFn})",
        "SyntaxError",
    );
}

test "an underlying sink member that is not callable releases the strategy's size" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoMoreThan(
        "new WritableStream({write: 5}, {highWaterMark: 1})",
        "new WritableStream({write: 5}, {size: sizeFn})",
        "TypeError",
    );
}

test "an underlying sink with a type throws a RangeError and releases the strategy's size" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoMoreThan(
        "new WritableStream({type: 'bytes'}, {highWaterMark: 1})",
        "new WritableStream({type: 'bytes'}, {size: sizeFn})",
        "RangeError",
    );
}

test "a writable stream's bad high water mark throws after taking the size, and releases it" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoMoreThan(
        "new WritableStream({}, {highWaterMark: -1})",
        "new WritableStream({}, {size: sizeFn, highWaterMark: -1})",
        "RangeError",
    );
}

test "a transformer that is not an object throws and releases both strategies' sizes" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoMoreThan(
        "new TransformStream(5, {highWaterMark: 1}, {highWaterMark: 1})",
        "new TransformStream(5, {size: sizeFn}, {size: sizeFn})",
        "TypeError",
    );
}

test "a transformer whose conversion throws releases both strategies' sizes" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoMoreThan(
        "new TransformStream({get transform() { throw new SyntaxError('no'); }}, {highWaterMark: 1}, {highWaterMark: 1})",
        "new TransformStream({get transform() { throw new SyntaxError('no'); }}, {size: sizeFn}, {size: sizeFn})",
        "SyntaxError",
    );
}

test "a transformer with a readableType throws a RangeError and releases both strategies' sizes" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoMoreThan(
        "new TransformStream({readableType: 'bytes'}, {highWaterMark: 1}, {highWaterMark: 1})",
        "new TransformStream({readableType: 'bytes'}, {size: sizeFn}, {size: sizeFn})",
        "RangeError",
    );
}

test "a transformer with a writableType throws a RangeError and releases both strategies' sizes" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoMoreThan(
        "new TransformStream({writableType: 'bytes'}, {highWaterMark: 1}, {highWaterMark: 1})",
        "new TransformStream({writableType: 'bytes'}, {size: sizeFn}, {size: sizeFn})",
        "RangeError",
    );
}

test "a bad readable high water mark throws before either size is taken, and releases both" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoMoreThan(
        "new TransformStream({}, {highWaterMark: 1}, {highWaterMark: -1})",
        "new TransformStream({}, {size: sizeFn}, {size: sizeFn, highWaterMark: -1})",
        "RangeError",
    );
}

test "a bad writable high water mark throws between the two sizes, and releases both" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoMoreThan(
        "new TransformStream({}, {highWaterMark: -1}, {highWaterMark: 1})",
        "new TransformStream({}, {size: sizeFn, highWaterMark: -1}, {size: sizeFn})",
        "RangeError",
    );
}
