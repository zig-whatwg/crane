//! A queuing strategy's `size` is its realm's one size function, and reading
//! it leaves no handle behind.
//!
//! Streams 7.2.2 and 7.3.2: every global object has a byte length and a count
//! queuing strategy size function, made with CreateBuiltinFunction(steps,
//! length, "size", « », realm), and the `size` getters return this's
//! relevant global object's. Crane's getters returned a Zig function pointer
//! (`callbacks.Function`), which the V8 binding had no conversion for: script
//! read `undefined`, made fresh by v8_Undefined and never released - one
//! Global per read, 165 roots under leaks --atExit over streams/ (lane
//! leaks2). Now codegen types a callback-function attribute as a
//! `runtime.JSValue` (writer.isCallbackFunctionValueAttribute), the impl
//! returns a hold of `engine.globalBuiltinFunction`'s function, and the
//! binding releases it as it does every JSValue a getter returns.
//!
//! The handle tests read V8's own live count against a control that takes the
//! same binding path with nothing to keep
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

fn windowRealmIn(agent: *protocol.Agent) !runtime.Context {
    return protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
}

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        try setup();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        return .{ .agent = agent, .realm = try windowRealmIn(agent) };
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn isolate(self: Page) *ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    fn collect(self: Page) !void {
        for (0..2) |_| try protocol.performMicrotaskCheckpoint(self.agent);
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
        if (reports.count != 0 or !std.mem.eql(u8, got, "ok")) std.debug.print("`{s}` answered {s}\n", .{ source, got });
        try testing.expectEqual(@as(usize, 0), reports.count);
        try testing.expectEqualStrings("ok", got);
    }

    fn handleBytes(self: Page) i64 {
        return @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate()));
    }

    fn oneHandleBytes(self: Page) i64 {
        const start = ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate());
        const one = ffi.v8_Number_New(self.isolate(), 1);
        const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate());
        ffi.v8_Value_Dispose(@ptrCast(one));
        return @intCast(with_one - start);
    }

    /// The global handle bytes 64 runs of `statement` leave once a first
    /// round has made what later ones reuse.
    fn handleBytesLeftBy(self: Page, comptime statement: []const u8) !i64 {
        const loop =
            \\(() => {
            \\  var c = globalThis.cqs ||= new CountQueuingStrategy({ highWaterMark: 1 });
            \\  var b = globalThis.blqs ||= new ByteLengthQueuingStrategy({ highWaterMark: 1 });
            \\  for (var k = 0; k < 64; k++) {
        ++ statement ++
            \\;
            \\  }
            \\  return "ok";
            \\})()
        ;
        try self.run(loop);
        try self.collect();
        const before = self.handleBytes();
        try self.run(loop);
        try self.collect();
        return self.handleBytes() - before;
    }

    /// `statement` leaves no more handles over 64 runs than `control`:
    /// fewer than 8 handles of difference, where one per run is 64.
    fn expectNoMoreThan(self: Page, comptime control: []const u8, comptime statement: []const u8) !void {
        const control_left = try self.handleBytesLeftBy(control);
        const left = try self.handleBytesLeftBy(statement);
        const one = self.oneHandleBytes();
        if (left - control_left >= one * 8) {
            std.debug.print("64 x `{s}` left {d} bytes of global handles; the control `{s}` left {d} ({d} a handle)\n", .{ statement, left, control, control_left, one });
            return error.HandlesLeaked;
        }
    }
};

test "size is the realm's one function: a builtin named size, of the right length, not a constructor" {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\(() => {
        \\  const check = (ok, what) => { if (!ok) throw new Error(what); };
        \\  for (const [Strategy, length] of [[CountQueuingStrategy, 0], [ByteLengthQueuingStrategy, 1]]) {
        \\    const size = new Strategy({ highWaterMark: 5 }).size;
        \\    check(typeof size === "function", Strategy.name + ": a function");
        \\    check(size === new Strategy({ highWaterMark: 10 }).size, Strategy.name + ": the same function for every instance");
        \\    check(size.name === "size", Strategy.name + ": named size");
        \\    check(size.length === length, Strategy.name + ": length " + length);
        \\    check(!("prototype" in size), Strategy.name + ": no prototype property");
        \\    let threw = false;
        \\    try { new size({ byteLength: 1 }); } catch (e) { threw = e instanceof TypeError; }
        \\    check(threw, Strategy.name + ": not a constructor");
        \\    check(/\[native code\]/.test(Function.prototype.toString.call(size)), Strategy.name + ": a built-in function");
        \\  }
        \\  check(new CountQueuingStrategy({ highWaterMark: 1 }).size !== new ByteLengthQueuingStrategy({ highWaterMark: 1 }).size, "two functions");
        \\  return "ok";
        \\})()
    );
}

test "the size functions' steps: 1, and GetV(chunk, byteLength)" {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\(() => {
        \\  const check = (ok, what) => { if (!ok) throw new Error(what); };
        \\  const count = new CountQueuingStrategy({ highWaterMark: 5 }).size;
        \\  for (const chunk of [undefined, null, "potato", {}, { byteLength: 1024 }]) check(count(chunk) === 1, "count size of " + chunk);
        \\  check(count() === 1, "count size of nothing");
        \\  const bytes = new ByteLengthQueuingStrategy({ highWaterMark: 5 }).size;
        \\  check(bytes({ byteLength: 1024 }) === 1024, "a chunk's byteLength");
        \\  check(bytes({ get byteLength() { return 7; } }) === 7, "a getter's");
        \\  check(bytes(new Uint8Array(3)) === 3, "a view's");
        \\  check(bytes({}) === undefined, "an object without one");
        \\  check(bytes("potato") === undefined, "a primitive");
        \\  for (const chunk of [undefined, null]) {
        \\    let threw = false;
        \\    try { bytes(chunk); } catch (e) { threw = e instanceof TypeError; }
        \\    check(threw, "ToObject(" + chunk + ") throws a TypeError");
        \\  }
        \\  const error = new Error("wow!");
        \\  let thrown;
        \\  try { bytes({ get byteLength() { throw error; } }); } catch (e) { thrown = e; }
        \\  check(thrown === error, "the getter's exception, as it is");
        \\  // A function, not a method: `this` is not read.
        \\  check(bytes.call(42, { byteLength: 2 }) === 2, "called with any this");
        \\  return "ok";
        \\})()
    );
}

test "reading size leaves no handle per read" {
    const page = try Page.open();
    defer page.close();
    // The getter rule: the binding releases the JSValue a getter returns -
    // here a hold of the realm's function - and nothing is released twice
    // (the same function on every read).
    try page.expectNoMoreThan("c.highWaterMark", "c.size");
    try page.expectNoMoreThan("b.highWaterMark", "b.size");
    try page.expectNoMoreThan("c.highWaterMark", "c.size(k)");
    try page.expectNoMoreThan("b.highWaterMark", "b.size({ byteLength: k })");
}

/// engine.globalBuiltinFunction's steps for the test: the realm's answer is
/// its data, a number.
fn answerSteps(data: ?*anyopaque, arguments: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
    _ = arguments;
    const answer: *const f64 = @ptrCast(@alignCast(data.?));
    return runtime.JSValue.fromNumber(answer.*);
}

const forty_two: f64 = 42;
const answer_function: runtime.BuiltinFunction = .{ .steps = answerSteps, .data = @ptrCast(@constCast(&forty_two)) };

fn expectFunctionOf(page: Page, function: protocol.JSValue) !void {
    try testing.expect(protocol.isCallable(page.realm, function));
    try testing.expect(!protocol.isConstructor(page.realm, function));
    try testing.expect(!try protocol.hasOwnProperty(page.realm, function, "prototype"));
    const name = try protocol.getProperty(page.realm, function, "name");
    defer name.release();
    try testing.expect(name.value == .handle or name.value == .string);
    const length = try protocol.getProperty(page.realm, function, "length");
    defer length.release();
    const length_value = try protocol.convertToUnrestrictedDouble(page.realm, length.value);
    try testing.expectEqual(@as(f64, 3), length_value);
}

test "globalBuiltinFunction answers one function per realm and key, and leaves no handle after the realm" {
    const page = try Page.open();
    defer page.close();
    // A realm whose life is measured, against one that never asks.
    const warm = try windowRealmIn(page.agent);
    protocol.destroyWindowRealm(warm, .global_detached);

    try page.collect();
    const before_control = page.handleBytes();
    {
        const control = try windowRealmIn(page.agent);
        protocol.destroyWindowRealm(control, .global_detached);
    }
    try page.collect();
    const after_control = page.handleBytes();

    {
        const realm = try windowRealmIn(page.agent);
        defer protocol.destroyWindowRealm(realm, .global_detached);
        const first = try protocol.globalBuiltinFunction(realm, "crane:test answer", "answer", 3, &answer_function);
        defer first.release();
        // The same function on every call for the key, and a hold each time.
        for (0..64) |_| {
            const again = try protocol.globalBuiltinFunction(realm, "crane:test answer", "answer", 3, &answer_function);
            defer again.release();
            try testing.expect(protocol.sameValue(realm, first.value, again.value));
        }
        // Another key is another function; another realm, another one too.
        const other = try protocol.globalBuiltinFunction(realm, "crane:test other answer", "answer", 3, &answer_function);
        defer other.release();
        try testing.expect(!protocol.sameValue(realm, first.value, other.value));
        const elsewhere = try protocol.globalBuiltinFunction(page.realm, "crane:test answer", "answer", 3, &answer_function);
        defer elsewhere.release();
        try testing.expect(!protocol.sameValue(realm, first.value, elsewhere.value));
        try expectFunctionOf(.{ .agent = page.agent, .realm = realm }, first.value);
    }
    try page.collect();
    const after = page.handleBytes();
    const one = page.oneHandleBytes();
    if ((after - after_control) - (after_control - before_control) >= one * 4) {
        std.debug.print("a realm that made functions left {d} bytes of global handles; one that made none left {d} ({d} a handle)\n", .{ after - after_control, after_control - before_control, one });
        return error.HandlesLeaked;
    }
}
