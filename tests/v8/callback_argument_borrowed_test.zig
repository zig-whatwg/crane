//! A callback-function value the binding converts is BORROWED for the call,
//! as every argument is: the binding releases its Global when the call
//! returns, and an impl that keeps the callback takes a hold of its own
//! (engine.takeCallbackFunction). Lane leaks7, 2026-10-25.
//!
//! The leak: the binding handed a callback-function argument's Global to the
//! impl, and the take ADOPTED it - so an impl that never took it kept it for
//! the agent's life. ResizeObserver's constructor is a stub that drops its
//! callback (`_ = callback;`), so every `new ResizeObserver(fn)` left one
//! 16 B Global (row 117's images leak pass: ROOT malloc in
//! v8_FunctionCallbackInfo_GetArgument <- V8Interface(ResizeObserver)
//! .constructorCallback; leaks --atExit, in-process: 40 constructions, 40
//! leaks). canvas.toBlob(fn) and new Observable(fn) did the same, and so did
//! every stub that drops a callback, every dictionary callback member a stub
//! ignores, and a dictionary whose later member failed after a callback
//! member converted.
//!
//! The fix makes the safe answer the default (AGENTS.md: an ownership gate's
//! default is the safe answer): the binding frees every callback-function
//! value it converted - an argument, a dictionary member, a union arm, a
//! sequence element, an overload variant's argument, an attribute's value -
//! with the rest of the value (interface.freeConvertedArg), and the take
//! moves the function into a Global of the taker's. Blink has the same
//! shape: the argument is a Local of the call, and a callback the impl keeps
//! is a CallbackFunctionBase holding a reference of its own
//! (platform/bindings/callback_function_base.h).
//!
//! Every value here is made the way the binding makes it: a Global per
//! argument as `info.get(i)` makes one (v8_Global_Clone of the script value),
//! converted with the binding's own conversion and freed with its own free.
//! The handle counts are V8's own (docs/lessons/testing-a-handle-leak-test-
//! needs-v8-s-live-count.md).

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

const interface_mod = v8.interface_mod;
const conversions = v8.conversions;
const resolver = interface_mod.overload_resolver;

/// A callback function as codegen types one (callbacks.X = *const fn ...).
const Callback = *const fn (event: *runtime.Instance) runtime.JSValue;

// ============================================================================
// The release rule, pinned
// ============================================================================

test "every callback-function shape the binding converts is freed with its value" {
    const cleans = interface_mod.needsArgCleanup;
    try testing.expect(cleans(Callback));
    try testing.expect(cleans(?Callback));
    try testing.expect(cleans(webidl.Opt(Callback)));
    try testing.expect(cleans(webidl.Opt(?Callback)));
    try testing.expect(cleans(struct { cb: ?Callback = null, n: ?f64 = null }));
    try testing.expect(cleans(union(enum) { domstring: runtime.DOMString, function: Callback }));
    try testing.expect(cleans([]const Callback));
    // The default for a type nobody named stays "nothing to free": freeing
    // what the value does not own is a use-after-free.
    try testing.expect(!cleans(*anyopaque));
    try testing.expect(!cleans(struct { a: u32 = 0 }));
}

test "a callback union's copied arm leaves its handle, its callback arm holds it; a callback sequence never holds the array's" {
    const leaves = interface_mod.conversionLeavesHandle;
    const Arm = union(enum) { domstring: runtime.DOMString, function: Callback };
    var dummy: u64 align(16) = 0;
    const function: Callback = @ptrCast(@alignCast(&dummy));
    try testing.expect(leaves(Arm, .{ .domstring = runtime.DOMString.empty }));
    try testing.expect(!leaves(Arm, .{ .function = function }));
    try testing.expect(leaves(webidl.Opt(Arm), webidl.Opt(Arm).passed(.{ .domstring = runtime.DOMString.empty })));
    try testing.expect(!leaves(webidl.Opt(Arm), webidl.Opt(Arm).passed(.{ .function = function })));
    // A union with an arm nobody named keeps the conservative answer.
    const Unknown = union(enum) { domstring: runtime.DOMString, other: *anyopaque };
    try testing.expect(!leaves(Unknown, .{ .domstring = runtime.DOMString.empty }));
    // Each element of a sequence of callbacks holds its own Get handle.
    try testing.expect(interface_mod.argHandleIsCopied([]const Callback));
    try testing.expect(interface_mod.argHandleIsCopied([]const ?Callback));
    try testing.expect(!interface_mod.argHandleIsCopied(Callback));
    try testing.expect(!interface_mod.argHandleIsCopied([]const *anyopaque));
}

test "an attribute's callback value is borrowed by the setter" {
    const borrowed = interface_mod.setterValueIsBorrowed;
    try testing.expect(borrowed(Callback));
    try testing.expect(borrowed(?Callback));
    // The `any` shapes stay borrowed, and an unknown type stays handed over.
    try testing.expect(borrowed(runtime.JSValue));
    try testing.expect(!borrowed(*anyopaque));
    try testing.expect(!borrowed(struct { a: ?*anyopaque = null }));
}

// ============================================================================
// A realm to convert in
// ============================================================================

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
        try testing.expectEqual(@as(usize, 0), reports.count);
        if (!std.mem.eql(u8, "ok", got)) std.debug.print("`{s}` answered `{s}`\n", .{ source, got });
        try testing.expectEqualStrings("ok", got);
    }

    /// What script's `source` evaluates to: OWNED.
    fn value(self: Page, source: []const u8) !protocol.Owned {
        var reports: Reports = .{};
        const got = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        try testing.expectEqual(@as(usize, 0), reports.count);
        return got;
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
        try self.collect();
        const before = self.handleBytes();
        try self.run(loop);
        try self.collect();
        return self.handleBytes() - before;
    }

    /// `statement` leaves no more handles over 64 calls than `control`, a
    /// statement through the same kind of path with nothing to keep: fewer
    /// than 8 handles of difference, where one per call is 64.
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

/// The steps of a binding call, run with the realm entered: a conversion
/// from the Global `info.get(0)` would make for `function`, then whatever
/// the impl does, then the binding's free.
const Call = struct {
    function: *ffi.Value,
    /// What the steps should do, and their result.
    kind: Kind,
    take: bool = false,
    taken: ?protocol.CallbackFunction = null,
    failed: ?anyerror = null,

    const Kind = enum { argument, member, union_arm, union_string, sequence };

    const Member = struct { cb: ?Callback = null, n: ?f64 = null };
    const Arm = union(enum) { domstring: runtime.DOMString, function: Callback };

    fn steps(data: ?*anyopaque) void {
        const self: *Call = @ptrCast(@alignCast(data.?));
        self.once() catch |err| {
            self.failed = err;
        };
    }

    fn keep(self: *Call, callback: Callback) void {
        if (self.take) self.taken = protocol.takeCallbackFunction(@ptrCast(callback));
    }

    fn once(self: *Call) !void {
        const isolate = ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
        const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;
        defer ffi.v8_Context_Dispose(context);
        const allocator = testing.allocator;
        switch (self.kind) {
            .argument => {
                // The argument's own Global, as `info.get(0)` makes it.
                const argument = ffi.v8_Global_Clone(self.function) orelse return error.CloneFailed;
                const converted = try interface_mod.convertArgReleasingWith(Callback, .{}, allocator, isolate, context, argument);
                defer interface_mod.freeArgument(Callback, allocator, converted);
                self.keep(converted);
            },
            .member => {
                // A dictionary argument `{ cb: function }`: its member is read
                // through a Get of its own.
                const object = try objectWith(isolate, context, self.function);
                defer ffi.v8_Value_Dispose(object);
                const converted = try conversions.fromV8Value(Member, allocator, isolate, context, object);
                defer interface_mod.freeConvertedArg(Member, allocator, converted);
                self.keep(converted.cb orelse return error.NoMember);
            },
            .union_arm => {
                const argument = ffi.v8_Global_Clone(self.function) orelse return error.CloneFailed;
                const converted = try interface_mod.convertArgReleasingWith(Arm, .{}, allocator, isolate, context, argument);
                defer interface_mod.freeArgument(Arm, allocator, converted);
                switch (converted) {
                    .function => |f| self.keep(f),
                    else => return error.WrongArm,
                }
            },
            .union_string => {
                // TimerHandler's shape given a string: the string arm copies,
                // and the argument's Global is left to the binding.
                const text = ffi.v8_String_NewFromUtf8(isolate, "x", 1) orelse return error.StringFailed;
                const converted = try interface_mod.convertArgReleasingWith(Arm, .{}, allocator, isolate, context, @ptrCast(text));
                defer interface_mod.freeArgument(Arm, allocator, converted);
                if (converted != .domstring) return error.WrongArm;
            },
            .sequence => {
                const array = try arrayOf(isolate, context, self.function);
                const converted = try interface_mod.convertArgReleasingWith([]const Callback, .{}, allocator, isolate, context, array);
                defer interface_mod.freeArgument([]const Callback, allocator, converted);
                if (converted.len != 2) return error.WrongLength;
                self.keep(converted[1]);
            },
        }
    }

    /// `{ cb: function }`, OWNED.
    fn objectWith(isolate: *ffi.Isolate, context: *ffi.Context, function: *ffi.Value) !*ffi.Value {
        const object = ffi.v8_Object_New(isolate) orelse return error.ObjectFailed;
        errdefer ffi.v8_Object_Dispose(object);
        const key = ffi.v8_String_NewFromUtf8(isolate, "cb", 2) orelse return error.StringFailed;
        defer ffi.v8_String_Dispose(key);
        if (!ffi.v8_Object_Set(object, context, @ptrCast(key), function)) return error.SetFailed;
        return @ptrCast(object);
    }

    /// `[function, function]`, OWNED.
    fn arrayOf(isolate: *ffi.Isolate, context: *ffi.Context, function: *ffi.Value) !*ffi.Value {
        const array = ffi.v8_Array_New(isolate, 2);
        errdefer ffi.v8_Value_Dispose(@ptrCast(array));
        if (!ffi.v8_Array_Set(array, context, 0, function)) return error.SetFailed;
        if (!ffi.v8_Array_Set(array, context, 1, function)) return error.SetFailed;
        return @ptrCast(array);
    }
};

/// The global handle bytes 64 calls of `kind` leave, the callback untaken.
fn untakenBytes(page: Page, function: *ffi.Value, kind: Call.Kind) !i64 {
    var call: Call = .{ .function = function, .kind = kind };
    // A first round makes what later ones reuse.
    try protocol.runInRealm(page.realm, Call.steps, &call);
    if (call.failed) |err| return err;
    const before = page.handleBytes();
    for (0..64) |_| {
        try protocol.runInRealm(page.realm, Call.steps, &call);
        if (call.failed) |err| return err;
    }
    return page.handleBytes() - before;
}

fn expectUntakenReleased(kind: Call.Kind) !void {
    const page = try Page.open();
    defer page.close();
    const function = try page.value("(function () { return 7; })");
    defer function.release();
    const left = try untakenBytes(page, @ptrCast(@alignCast(function.value.handle.ptr)), kind);
    const one = page.oneHandleBytes();
    if (left >= one * 8) {
        std.debug.print("64 untaken {s} callbacks left {d} bytes of global handles ({d} a handle)\n", .{ @tagName(kind), left, one });
        return error.HandlesLeaked;
    }
}

/// A callback taken through `kind`'s value is the taker's: after the call's
/// free, script dropping its own reference and two collections, it still
/// runs - and it is a hold of its own, never the binding's Global.
fn expectTakenOutlivesTheCall(kind: Call.Kind) !void {
    const page = try Page.open();
    defer page.close();
    const function = try page.value("globalThis.calls = 0; globalThis.made = function () { calls++; return 7; }; made");
    var call: Call = .{ .function = @ptrCast(@alignCast(function.value.handle.ptr)), .kind = kind, .take = true };
    try protocol.runInRealm(page.realm, Call.steps, &call);
    function.release();
    if (call.failed) |err| return err;
    const taken = call.taken orelse return error.NothingTaken;
    defer taken.release();
    try page.run("delete globalThis.made; 'ok'");
    try page.collect();
    const completion = try protocol.invokeCallbackFunction(page.realm, &taken, .undefined, &.{}, .rethrow);
    switch (completion) {
        .normal => |v| v.release(),
        .throw => |e| {
            e.release();
            return error.CallbackThrew;
        },
    }
    try page.run("calls === 1 ? 'ok' : 'calls ' + calls");
}

test "an untaken callback-function argument is released when the call returns" {
    try expectUntakenReleased(.argument);
}

test "an untaken callback member is released with its dictionary" {
    try expectUntakenReleased(.member);
}

test "an untaken callback union arm is released with its union" {
    try expectUntakenReleased(.union_arm);
}

test "a callback union converted to a copied arm leaves no handle" {
    try expectUntakenReleased(.union_string);
}

test "untaken callback sequence elements are released with their sequence" {
    try expectUntakenReleased(.sequence);
}

test "a taken callback-function argument outlives the call and a collection" {
    try expectTakenOutlivesTheCall(.argument);
}

test "a taken callback member outlives its dictionary and a collection" {
    try expectTakenOutlivesTheCall(.member);
}

test "a taken callback union arm outlives its union and a collection" {
    try expectTakenOutlivesTheCall(.union_arm);
}

test "a taken callback sequence element outlives its sequence and a collection" {
    try expectTakenOutlivesTheCall(.sequence);
}

test "the take is a hold of the taker's own: the binding's Global is left to the binding" {
    const page = try Page.open();
    defer page.close();
    const function = try page.value("(function () { return 7; })");
    defer function.release();
    const Steps = struct {
        function: *ffi.Value,
        failed: ?anyerror = null,

        fn run(data: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            self.check() catch |err| {
                self.failed = err;
            };
        }

        fn check(self: *@This()) !void {
            const argument = ffi.v8_Global_Clone(self.function) orelse return error.CloneFailed;
            const taken = protocol.takeCallbackFunction(@ptrCast(argument));
            defer taken.release();
            // Not the argument's own Global: that one the binding frees.
            try testing.expect(@intFromPtr(taken.function.value.handle.ptr) != @intFromPtr(argument));
            try testing.expect(ffi.v8_Global_IsEmpty(@ptrCast(argument)));
            ffi.v8_Value_Dispose(argument);
            // The same function: the binding's Global gave its function up.
            try testing.expect(ffi.v8_Value_StrictEquals(@ptrCast(@alignCast(taken.function.value.handle.ptr)), self.function));
        }
    };
    var steps: Steps = .{ .function = @ptrCast(@alignCast(function.value.handle.ptr)) };
    try protocol.runInRealm(page.realm, Steps.run, &steps);
    if (steps.failed) |err| return err;
}

/// The take moves the handle and what is keyed by its box. Read before the
/// call, after the conversion, after the take, after the binding's free and
/// after the taker's release: V8's global handle bytes (one node per
/// callback, made once and released once) and the realm-tag map (an entry
/// only for the taker's Global, gone with it).
const Bookkeeping = struct {
    function: *ffi.Value,
    shape: Shape,
    failed: ?anyerror = null,

    const Shape = enum { taken, untaken, tagged_before_take, weak_before_take };

    fn run(data: ?*anyopaque) void {
        const self: *Bookkeeping = @ptrCast(@alignCast(data.?));
        self.check() catch |err| {
            self.failed = err;
        };
    }

    fn noteCollected(_: ?*anyopaque, _: usize) callconv(.c) void {}

    fn check(self: *Bookkeeping) !void {
        const isolate = ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
        const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;
        defer ffi.v8_Context_Dispose(context);
        const allocator = testing.allocator;
        const one = handleBytesOfOne(isolate);
        const bytes0: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate));
        const tags0 = ffi.v8_Debug_RealmTaggedHandleCount();

        const argument = ffi.v8_Global_Clone(self.function) orelse return error.CloneFailed;
        const converted = try interface_mod.convertArgReleasingWith(Callback, .{}, allocator, isolate, context, argument);
        try expectBytes(isolate, bytes0 + one);
        switch (self.shape) {
            .untaken => {
                interface_mod.freeArgument(Callback, allocator, converted);
                try expectBytes(isolate, bytes0);
                try testing.expectEqual(tags0, ffi.v8_Debug_RealmTaggedHandleCount());
                return;
            },
            .tagged_before_take => {
                const key = v8.context_manager.keyOf(context) orelse return error.NoRealmKey;
                ffi.v8_Global_TagRealm(argument, key);
                try testing.expectEqual(tags0 + 1, ffi.v8_Debug_RealmTaggedHandleCount());
            },
            .weak_before_take => ffi.v8_Global_SetWeak(@ptrCast(argument), null, noteCollected),
            .taken => {},
        }

        const taken = protocol.takeCallbackFunction(@ptrCast(converted));
        const taken_global: *ffi.Value = @ptrCast(@alignCast(taken.function.value.handle.ptr));
        try testing.expect(taken_global != argument);
        switch (self.shape) {
            .weak_before_take => {
                // Never moved: the taker has a strong Global of its own (one
                // more node), and the weak box keeps its arm.
                try testing.expect(!ffi.v8_Global_IsEmpty(argument));
                try expectBytes(isolate, bytes0 + 2 * one);
            },
            else => {
                // Moved: no node made, and the binding's box is empty.
                try testing.expect(ffi.v8_Global_IsEmpty(argument));
                try expectBytes(isolate, bytes0 + one);
                // The realm tag is the taker's box's only: one entry, never
                // one left keyed by the binding's box.
                try testing.expect(!ffi.v8_Debug_IsRealmTagged(argument));
                try testing.expect(ffi.v8_Debug_IsRealmTagged(taken_global));
                try testing.expectEqual(tags0 + 1, ffi.v8_Debug_RealmTaggedHandleCount());
            },
        }

        // The call returns: the binding frees its box.
        interface_mod.freeArgument(Callback, allocator, converted);
        try expectBytes(isolate, bytes0 + one);
        // The taker lets go.
        taken.release();
        try expectBytes(isolate, bytes0);
        try testing.expectEqual(tags0, ffi.v8_Debug_RealmTaggedHandleCount());
    }

    fn handleBytesOfOne(isolate: *ffi.Isolate) i64 {
        const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        const value = ffi.v8_Number_New(isolate, 1);
        const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        ffi.v8_Value_Dispose(@ptrCast(value));
        return @intCast(with_one - start);
    }

    fn expectBytes(isolate: *ffi.Isolate, expected: i64) !void {
        try testing.expectEqual(expected, @as(i64, @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate))));
    }
};

fn expectBookkeeping(shape: Bookkeeping.Shape) !void {
    const page = try Page.open();
    defer page.close();
    const function = try page.value("(function () { return 7; })");
    defer function.release();
    var check: Bookkeeping = .{ .function = @ptrCast(@alignCast(function.value.handle.ptr)), .shape = shape };
    try protocol.runInRealm(page.realm, Bookkeeping.run, &check);
    if (check.failed) |err| return err;
}

test "a taken callback: one handle made and released once, its realm tag on the taker's Global only" {
    try expectBookkeeping(.taken);
}

test "an untaken callback: its handle is released by the binding, nothing tagged" {
    try expectBookkeeping(.untaken);
}

test "a take re-keys a realm tag the binding's Global carried, so none is left keyed by a freed box" {
    try expectBookkeeping(.tagged_before_take);
}

test "a take never moves a weak Global: the taker gets one of its own, the box keeps its arm" {
    try expectBookkeeping(.weak_before_take);
}

// ============================================================================
// An overloaded constructor's variant
// ============================================================================

/// An overloaded constructor's arguments, as codegen emits them: a variant
/// per overload, a struct of its arguments.
const Overloads = union(enum) {
    string_callback: struct {
        text: runtime.DOMString,
        callback: Callback,
    },
    /// The control's: the same resolution, nothing kept.
    string_number: struct {
        text: runtime.DOMString,
        number: f64,
    },
};
const overloads = &[_]resolver.Overload{
    .{ .function = "string_callback", .args = &.{ .{ .kinds = &.{.string} }, .{ .kinds = &.{.callback_function} } } },
    .{ .function = "string_number", .args = &.{ .{ .kinds = &.{.string} }, .{ .kinds = &.{.numeric} } } },
};

/// `probe(text, callback)`: resolves `Overloads` from its arguments as
/// the binding's constructor does, takes the callback when `probe_take`,
/// and frees the variant (overload_resolver.freeConstructorOverload).
var probe_take = false;
var probe_taken: ?protocol.CallbackFunction = null;
var probe_failed = false;

fn probeCallback(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        probe_failed = true;
        return;
    };
    defer ffi.v8_Context_Dispose(context);
    const args = resolver.resolveConstructorOverload(Overloads, overloads, .{}, info, testing.allocator, isolate, context) catch {
        probe_failed = true;
        return;
    };
    defer resolver.freeConstructorOverload(Overloads, overloads, testing.allocator, args);
    if (probe_take) switch (args) {
        .string_callback => |variant| probe_taken = protocol.takeCallbackFunction(@ptrCast(variant.callback)),
        .string_number => {},
    };
}

const InstallProbe = struct {
    failed: ?anyerror = null,

    fn run(data: ?*anyopaque) void {
        const self: *InstallProbe = @ptrCast(@alignCast(data.?));
        install() catch |err| {
            self.failed = err;
        };
    }

    fn install() !void {
        const isolate = ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
        const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;
        defer ffi.v8_Context_Dispose(context);
        const template = ffi.v8_FunctionTemplate_New(isolate, probeCallback, null) orelse return error.TemplateFailed;
        defer ffi.v8_FunctionTemplate_Dispose(template);
        const function = ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return error.FunctionFailed;
        defer ffi.v8_Function_Dispose(function);
        const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
        defer ffi.v8_Object_Dispose(global);
        const key = ffi.v8_String_NewFromUtf8(isolate, "probe", 5) orelse return error.StringFailed;
        defer ffi.v8_String_Dispose(key);
        if (!ffi.v8_Object_Set(global, context, @ptrCast(key), @ptrCast(function))) return error.SetFailed;
    }
};

fn pageWithProbe() !Page {
    const page = try Page.open();
    errdefer page.close();
    var install: InstallProbe = .{};
    try protocol.runInRealm(page.realm, InstallProbe.run, &install);
    if (install.failed) |err| return err;
    return page;
}

test "an overload variant's untaken callback argument is released with the variant" {
    const page = try pageWithProbe();
    defer page.close();
    probe_take = false;
    probe_failed = false;
    try page.expectNoMoreThan("probe('a', 1)", "probe('a', () => 7)");
    try testing.expect(!probe_failed);
}

test "an overload variant's taken callback outlives the variant and a collection" {
    const page = try pageWithProbe();
    defer page.close();
    probe_take = true;
    probe_failed = false;
    defer probe_take = false;
    try page.run("globalThis.calls = 0; probe('a', function () { calls++; return 7; }); 'ok'");
    try testing.expect(!probe_failed);
    const taken = probe_taken orelse return error.NothingTaken;
    probe_taken = null;
    defer taken.release();
    try page.collect();
    const completion = try protocol.invokeCallbackFunction(page.realm, &taken, .undefined, &.{}, .rethrow);
    switch (completion) {
        .normal => |v| v.release(),
        .throw => |e| {
            e.release();
            return error.CallbackThrew;
        },
    }
    try page.run("calls === 1 ? 'ok' : 'calls ' + calls");
}

// ============================================================================
// Through the generated bindings
// ============================================================================

test "new ResizeObserver(callback) leaves no handle: its stub never takes the callback" {
    const page = try Page.open();
    defer page.close();
    // The control: a constructor whose argument is copied.
    try page.expectNoMoreThan("new Event('x')", "new ResizeObserver(() => {})");
}

test "canvas.toBlob(callback) leaves no handle when its stub throws without taking it" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoMoreThan(
        "try { root.ownerDocument.createElement('canvas').getContext('none') } catch (e) {}",
        "try { root.ownerDocument.createElement('canvas').toBlob(() => {}) } catch (e) {}",
    );
}

test "an impl that throws after taking its callback releases its own hold" {
    const page = try Page.open();
    defer page.close();
    // define() takes the constructor, then throws: a SyntaxError for the name,
    // a TypeError for a callable that is no constructor.
    try page.expectNoMoreThan(
        "try { new CustomElementRegistry().get('x-y') } catch (e) {}",
        "try { new CustomElementRegistry().define('not valid', class {}) } catch (e) { if (e.name !== 'SyntaxError') throw e }",
    );
    try page.expectNoMoreThan(
        "try { new CustomElementRegistry().get('x-y') } catch (e) {}",
        "try { new CustomElementRegistry().define('x-y', () => {}) } catch (e) { if (e.name !== 'TypeError') throw e }",
    );
}

test "el.onclick = f: the getter returns f, after a collection too, and a second assignment releases the first" {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\(() => {
        \\  var doc = globalThis.probeDocument ||= new Document().implementation.createHTMLDocument("");
        \\  var root = globalThis.probeRoot ||= doc.createElement("div");
        \\  globalThis.handler = function () { return 7; };
        \\  root.onclick = handler;
        \\  return root.onclick === handler ? "ok" : "a different function";
        \\})()
    );
    try page.collect();
    try page.run("probeRoot.onclick === handler ? 'ok' : 'lost after a collection'");
    try page.run("probeRoot.onclick = handler; probeRoot.onclick === handler ? 'ok' : 'lost on reassignment'");
    // 64 assignments keep one handler, not 64.
    try page.expectNoMoreThan("root.title = 'x'", "root.onclick = function () {}");
    try page.run("probeRoot.onclick = null; probeRoot.onclick === null ? 'ok' : 'still set'");
}
