//! `new ReadableStream(source, strategy)` releases the strategy's `size`
//! callback on every path that throws before the stream takes it.
//!
//! The binding hands a callback member over to the impl
//! (memberHandleIsSafe: a callback member adopts the handle Get made for it),
//! and the impl takes it as its size algorithm (ExtractSizeAlgorithm, Streams
//! 4.2.4 step 5.2). A byte stream takes no size algorithm: step 4.1, "If
//! strategy["size"] exists, throw a RangeError exception". That return, and
//! every throw before step 5.2 - an underlying source that is not an object
//! (step 1's conversion) or whose dictionary conversion throws (step 2) -
//! dropped the callback without releasing it: one Global per construction
//! (3 roots under leaks --atExit over streams/, lane leaks2).
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

test "a byte stream given a size function throws a RangeError and releases the function" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoMoreThan(
        "new ReadableStream({type: 'bytes'}, {highWaterMark: -1})",
        "new ReadableStream({type: 'bytes'}, {size: sizeFn})",
        "RangeError",
    );
}

test "an underlying source that is not an object throws and releases the strategy's size" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoMoreThan(
        "new ReadableStream(5, {highWaterMark: 1})",
        "new ReadableStream(5, {size: sizeFn})",
        "TypeError",
    );
}

test "an underlying source whose conversion throws releases the strategy's size" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoMoreThan(
        "new ReadableStream({get type() { throw new SyntaxError('no'); }}, {highWaterMark: 1})",
        "new ReadableStream({get type() { throw new SyntaxError('no'); }}, {size: sizeFn})",
        "SyntaxError",
    );
}
