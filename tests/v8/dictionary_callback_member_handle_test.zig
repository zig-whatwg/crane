//! A dictionary argument whose member is a callback function releases its own
//! handle once converted, and a member or argument that converts to nothing -
//! an absent or null optional, a `webidl.Opt` not passed - releases the handle
//! made for it.
//!
//! `new WritableStream({}, {highWaterMark: 0})` kept two 16-byte Globals per
//! call (leaks --atExit over fetch/api/, lane snapleak's report, item 2): the
//! strategy argument's own (`v8_FunctionCallbackInfo_GetArgument`) and the one
//! Get made for its absent `size` member (`v8_Object_Get`).
//!
//! - The argument: `argHandleIsCopied` walks a dictionary's members, and its
//!   member rule had no case for a callback function. QueuingStrategy's `size`
//!   is `?callbacks.QueuingStrategySize`, a function pointer, so the rule
//!   answered "kept" for the whole dictionary - although a dictionary reads
//!   every member through a Get of its own, and a callback member adopts THAT
//!   handle (conv.fromV8Value's function-pointer branch), never the
//!   dictionary's.
//! - The member: a member whose type is neither copied nor kept in its value
//!   kept its Get handle whatever it converted to. An absent `size` converts
//!   to null in the optional branch, before anything is made from the handle.
//!
//! The same two rules decided every argument of these shapes: ReadableStream's
//! and TransformStream's strategies, and an optional callback argument given
//! null (`addEventListener(type, null)`, `createTreeWalker(root, w, null)`).
//! The worker realms in the report were where fetch/api's
//! `new WritableStream({}, {highWaterMark: 0})` ran under leaks; a window realm
//! kept the same two handles (the tests below run in one).
//!
//! The handle tests read V8's own live count against a control that takes
//! the same binding path with nothing to keep
//! (docs/lessons/testing-a-handle-leak-test-needs-v8-s-live-count.md).

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

const copied = v8.interface_mod.argHandleIsCopied;

/// dictionaries.QueuingStrategy's shape: callbacks.QueuingStrategySize is a
/// function pointer (codegen's type for a callback function).
const StrategyShaped = struct {
    highWaterMark: ?f64 = null,
    size: ?*const fn (chunk: runtime.JSValue) f64 = null,
};

fn ConstructorParam(comptime I: type, comptime index: usize) type {
    return @typeInfo(@TypeOf(I.call_constructor)).@"fn".params[index].type.?;
}

test "a dictionary whose member is a callback function is copied: the callback adopts its own Get handle" {
    try testing.expect(copied(StrategyShaped));
    try testing.expect(copied(webidl.Opt(StrategyShaped)));
    // The real parameters: (optional object, optional QueuingStrategy).
    try testing.expect(copied(ConstructorParam(interfaces.WritableStream, 2)));
    try testing.expect(copied(ConstructorParam(interfaces.ReadableStream, 2)));
    try testing.expect(copied(ConstructorParam(interfaces.TransformStream, 2)));
    try testing.expect(copied(ConstructorParam(interfaces.TransformStream, 3)));
}

test "a callback argument still adopts its handle, and an unknown member keeps the dictionary's" {
    // The default stays the safe answer.
    try testing.expect(!copied(*const fn (chunk: runtime.JSValue) f64));
    try testing.expect(!copied(?*const fn (chunk: runtime.JSValue) f64));
    try testing.expect(!copied(struct { a: ?f64 = null, b: ?*anyopaque = null }));
    try testing.expect(!copied(struct { a: ?f64 = null, b: ?*const fn () void = null, c: *anyopaque }));
}

const leaves = v8.interface_mod.conversionLeavesHandle;
const Callback = ?*const fn (chunk: runtime.JSValue) f64;

test "conversionLeavesHandle - a null optional callback made nothing from its handle; a function is the handle" {
    try testing.expect(leaves(Callback, null));
    var dummy: u64 align(16) = 0;
    const function: Callback = @ptrCast(@alignCast(&dummy));
    try testing.expect(!leaves(Callback, function));
    // EventTarget's `EventListener? callback`: a callback interface, whose
    // wrapper takes the handle over.
    try testing.expect(leaves(??*runtime.CallbackWrapper, null));
    const wrapper: *runtime.CallbackWrapper = @ptrCast(@alignCast(&dummy));
    try testing.expect(!leaves(??*runtime.CallbackWrapper, wrapper));
}

test "conversionLeavesHandle - an optional argument not passed, or passed as null, made nothing" {
    var dummy: u64 align(16) = 0;
    const function: Callback = @ptrCast(@alignCast(&dummy));
    const Optional = webidl.Opt(Callback);
    try testing.expect(leaves(Optional, Optional.notPassed()));
    try testing.expect(leaves(Optional, Optional.passed(null)));
    try testing.expect(!leaves(Optional, Optional.passed(function)));
}

test "conversionLeavesHandle - an any decides by its value, a copied type never answers" {
    try testing.expect(leaves(runtime.JSValue, runtime.JSValue.jsNull));
    try testing.expect(leaves(?runtime.JSValue, null));
    var dummy: u64 align(16) = 0;
    const handle_value: runtime.JSValue = .{ .handle = .{ .ptr = @ptrCast(&dummy) } };
    try testing.expect(!leaves(runtime.JSValue, handle_value));
    try testing.expect(!leaves(?runtime.JSValue, handle_value));
    // Released by the copied rule, whatever the value: answering yes here
    // would release it twice.
    try testing.expect(!leaves(?runtime.DOMString, null));
    try testing.expect(!leaves(StrategyShaped, .{}));
    try testing.expect(!leaves(webidl.Opt(StrategyShaped), webidl.Opt(StrategyShaped).notPassed()));
}

test "conversionLeavesHandle - an unknown type defaults to KEPT" {
    var dummy: u64 align(16) = 0;
    const SomethingNew = struct { a: u32, b: *anyopaque };
    try testing.expect(!leaves(SomethingNew, .{ .a = 0, .b = @ptrCast(&dummy) }));
    const function: *const fn (chunk: runtime.JSValue) f64 = @ptrCast(@alignCast(&dummy));
    try testing.expect(!leaves(*const fn (chunk: runtime.JSValue) f64, function));
    const TimerHandlerShaped = union(enum) { domstring: runtime.DOMString, function: *anyopaque };
    try testing.expect(!leaves(TimerHandlerShaped, .{ .domstring = runtime.DOMString.empty }));
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

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    if (runtime.BrowserScope.standalone() == null) runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
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

    /// The streams' start promises settle, then two full collections.
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

    /// Runs `source`, which must answer "ok" and report nothing.
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
    /// round has made what later ones reuse. `root` is a div of an HTML
    /// document (the realm has no `document` of its own).
    fn handleBytesLeftBy(self: Page, comptime statement: []const u8) !i64 {
        const loop =
            \\(() => {
            \\  var doc = globalThis.probeDocument ||= new Document().implementation.createHTMLDocument("");
            \\  var root = globalThis.probeRoot ||= doc.createElement("div");
            \\  for (var k = 0; k < 64; k++) {
        ++ statement ++
            \\;
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

    /// `statement` leaves no more handles over 64 calls than `control`, a
    /// statement through the same binding with nothing to release: fewer
    /// than 8 handles of difference, where one per call is 64.
    fn expectNoMoreThan(self: Page, comptime control: []const u8, comptime statement: []const u8) !void {
        return self.expectAtMostPerCall(control, statement, 0);
    }

    /// `expectNoMoreThan`, allowing `per_call` handles per call that the
    /// statement keeps on purpose (a size function the stream holds).
    fn expectAtMostPerCall(self: Page, comptime control: []const u8, comptime statement: []const u8, comptime per_call: i64) !void {
        const control_left = try self.handleBytesLeftBy(control);
        const left = try self.handleBytesLeftBy(statement);
        const one = self.oneHandleBytes();
        if (left - control_left >= one * (64 * per_call + 8)) {
            std.debug.print("64 x `{s}` left {d} bytes of global handles; the control `{s}` left {d} ({d} a handle)\n", .{ statement, left, control, control_left, one });
            return error.HandlesLeaked;
        }
    }
};

test "new WritableStream(sink, strategy) leaves no handle per call" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoMoreThan("new WritableStream({})", "new WritableStream({}, {highWaterMark: 0})");
    try page.expectNoMoreThan("new WritableStream({})", "new WritableStream({}, {})");
    try page.expectNoMoreThan("new WritableStream({})", "new WritableStream({}, undefined)");
}

test "new ReadableStream(source, strategy) leaves no handle per call" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoMoreThan("new ReadableStream({})", "new ReadableStream({}, {highWaterMark: 0})");
}

test "new TransformStream(transformer, writableStrategy, readableStrategy) leaves no handle per call" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoMoreThan("new TransformStream({})", "new TransformStream({}, {highWaterMark: 0}, {highWaterMark: 0})");
}

test "a strategy with a size function keeps only the function, which the stream takes" {
    const page = try Page.open();
    defer page.close();
    // The stream takes the size function's handle (its size algorithm) and
    // keeps it as long as the stream lives - which, here, is past the
    // collection: the control's streams leave their own handles too. So
    // one handle per call is the stream's; the dictionary's own was a
    // second (red: 128 handles over 64 calls).
    try page.expectAtMostPerCall("new WritableStream({})", "new WritableStream({}, {size: (globalThis.sizeOne ||= () => 1)})", 1);
}
