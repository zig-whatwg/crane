//! The Engine table's page-realm operations, as V8 implements them
//! (src/runtime/engines/v8/page_realm.zig): invokeCallbackFunction and
//! installWindowOperations.
//!
//! The realm is registered with the context manager, as every Window realm
//! is: the window's natives find the realm they were called in through it.
//! The isolate keeps V8's default microtask policy (kAuto), which is the
//! browser's - the order of a report against the microtask checkpoint
//! depends on it.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

const engine = &v8.engine.v8_engine_interface;

/// One isolate, context and realm for the whole file; V8 is never torn down
/// here (see engine_realm_operations_test.zig).
var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;
var realm_once: ?runtime.Context = null;

fn realm() !runtime.Context {
    if (realm_once) |r| return r;
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    // Already initialized is fine: the manager is per thread, not per test.
    v8.context_manager.init(std.heap.page_allocator) catch {};
    const r = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
    isolate_once = i;
    context_once = context;
    realm_once = r;
    return r;
}

/// Script's value of `expression`, as an integer.
fn scriptInt(expression: []const u8) !i32 {
    const i = isolate_once.?;
    const context = context_once.?;
    const code = ffi.v8_String_NewFromUtf8(i, expression.ptr, @intCast(expression.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(code);
    const script = ffi.v8_Script_Compile(context, code) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    const value = ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, context);
}

/// Script's value of `expression`, as a handle the caller disposes.
fn scriptValue(expression: []const u8) !*ffi.Value {
    const i = isolate_once.?;
    const context = context_once.?;
    const code = ffi.v8_String_NewFromUtf8(i, expression.ptr, @intCast(expression.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(code);
    const script = ffi.v8_Script_Compile(context, code) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.RunFailed;
}

/// `value` as the binding hands an object to an impl: conversions.fromV8Value
/// tags it `.local` - borrowed for the call - over the same Global.
fn borrowed(value: *ffi.Value) runtime.JSValue {
    return v8.conversions.fromV8Value(runtime.JSValue, std.testing.allocator, isolate_once.?, context_once.?, value) catch unreachable;
}

const Reports = struct {
    count: usize = 0,
    message: [256]u8 = undefined,
    message_len: usize = 0,
    had_value: bool = false,
    /// Script to run from inside the report, to observe its ordering.
    run_inside: ?[]const u8 = null,

    fn report(host: ?*anyopaque, info: *const runtime.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        self.message_len = @min(info.message.len, self.message.len);
        @memcpy(self.message[0..self.message_len], info.message[0..self.message_len]);
        self.had_value = info.error_value != null;
        if (self.run_inside) |source| {
            var ignored: Reports = .{};
            engine.runClassicScript.?(realm_once.?, source, null, Reports.report, &ignored) catch {};
        }
    }

    fn messageText(self: *const Reports) []const u8 {
        return self.message[0..self.message_len];
    }
};

fn run(source: []const u8) !Reports {
    var reports: Reports = .{};
    try engine.runClassicScript.?(try realm(), source, null, Reports.report, &reports);
    return reports;
}

// ============================================================================
// invokeCallbackFunction
// ============================================================================

test "a callback is invoked with its arguments and the realm's global as this" {
    const ctx = try realm();
    _ = try run("globalThis.cb = function (a, b) { globalThis.sum = a + b; globalThis.thisIsGlobal = this === globalThis ? 1 : 0; };");
    const cb = try scriptValue("globalThis.cb");
    defer ffi.v8_Value_Dispose(cb);

    var reports: Reports = .{};
    try engine.invokeCallbackFunction.?(ctx, borrowed(cb), .global_this, &.{ .{ .number = 2 }, .{ .number = 3 } }, Reports.report, &reports);
    try std.testing.expectEqual(@as(i32, 5), try scriptInt("globalThis.sum"));
    try std.testing.expectEqual(@as(i32, 1), try scriptInt("globalThis.thisIsGlobal"));
    try std.testing.expectEqual(@as(usize, 0), reports.count);
}

test "a callback's this is undefined, or the value given" {
    const ctx = try realm();
    _ = try run("globalThis.strictCb = function () { 'use strict'; globalThis.seenThis = this === undefined ? -1 : this; };");
    const cb = try scriptValue("globalThis.strictCb");
    defer ffi.v8_Value_Dispose(cb);

    var reports: Reports = .{};
    try engine.invokeCallbackFunction.?(ctx, borrowed(cb), .undefined, &.{}, Reports.report, &reports);
    try std.testing.expectEqual(@as(i32, -1), try scriptInt("globalThis.seenThis"));
    try engine.invokeCallbackFunction.?(ctx, borrowed(cb), .{ .value = .{ .number = 7 } }, &.{}, Reports.report, &reports);
    try std.testing.expectEqual(@as(i32, 7), try scriptInt("globalThis.seenThis"));
}

test "more arguments than fit inline all arrive" {
    const ctx = try realm();
    _ = try run("globalThis.manyCb = function () { globalThis.argCount = arguments.length; globalThis.last = arguments[arguments.length - 1]; };");
    const cb = try scriptValue("globalThis.manyCb");
    defer ffi.v8_Value_Dispose(cb);

    var reports: Reports = .{};
    const args = [_]runtime.JSValue{ .{ .number = 1 }, .{ .number = 2 }, .{ .number = 3 }, .{ .number = 4 }, .{ .number = 5 }, .{ .number = 6 } };
    try engine.invokeCallbackFunction.?(ctx, borrowed(cb), .undefined, &args, Reports.report, &reports);
    try std.testing.expectEqual(@as(i32, 6), try scriptInt("globalThis.argCount"));
    try std.testing.expectEqual(@as(i32, 6), try scriptInt("globalThis.last"));
}

test "what a callback throws is reported, after the microtasks it queued" {
    const ctx = try realm();
    _ = try run("globalThis.order = ''; globalThis.thrower = function () { Promise.resolve().then(() => { globalThis.order += 'm'; }); throw new RangeError('nope'); };");
    const cb = try scriptValue("globalThis.thrower");
    defer ffi.v8_Value_Dispose(cb);

    // WebIDL: "clean up after running script" (the checkpoint) precedes the
    // report, so the report sees the microtask's effect.
    var reports: Reports = .{ .run_inside = "globalThis.order += 'r';" };
    try engine.invokeCallbackFunction.?(ctx, borrowed(cb), .undefined, &.{}, Reports.report, &reports);
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expect(std.mem.indexOf(u8, reports.messageText(), "nope") != null);
    try std.testing.expect(reports.had_value);
    try std.testing.expectEqual(@as(i32, 1), try scriptInt("globalThis.order === 'mr' ? 1 : 0"));
}

test "a callback that is not callable is not called" {
    const ctx = try realm();
    const object = try scriptValue("({})");
    defer ffi.v8_Value_Dispose(object);

    var reports: Reports = .{};
    try engine.invokeCallbackFunction.?(ctx, borrowed(object), .undefined, &.{}, Reports.report, &reports);
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    // A value that is no engine handle at all is a caller's mistake.
    try std.testing.expectError(error.TypeError, engine.invokeCallbackFunction.?(ctx, .{ .number = 1 }, .undefined, &.{}, Reports.report, &reports));
}

// ============================================================================
// installWindowOperations
// ============================================================================

/// What the host's steps were called with, as test WindowOperations record it.
const Seen = struct {
    realm: ?runtime.Context = null,
    timers: usize = 0,
    function_handlers: usize = 0,
    string_source: [64]u8 = undefined,
    string_len: usize = 0,
    timeout: i32 = 0,
    argument_count: usize = 0,
    repeat: bool = false,
    cleared: ?i32 = null,
    frames: usize = 0,
    cancelled: ?u32 = null,

    fn stringSource(self: *const Seen) []const u8 {
        return self.string_source[0..self.string_len];
    }
};

var seen: Seen = .{};

fn testInitializeTimer(r: runtime.Context, handler: runtime.WindowTimerHandler, timeout: i32, arguments: []const runtime.JSValue, repeat: bool) i32 {
    seen.realm = r;
    seen.timers += 1;
    seen.timeout = timeout;
    seen.argument_count = arguments.len;
    seen.repeat = repeat;
    switch (handler) {
        .function => |h| {
            seen.function_handlers += 1;
            engine.releaseValue.?(h);
        },
        .string => |h| {
            const string: *ffi.String = @ptrCast(@alignCast(h.handle.ptr));
            const len: usize = @intCast(ffi.v8_String_Utf8Length(string));
            seen.string_len = @min(len, seen.string_source.len);
            _ = ffi.v8_String_WriteUtf8(string, &seen.string_source, @intCast(seen.string_len));
            engine.releaseValue.?(h);
        },
    }
    // Every argument is the host's to release.
    for (arguments) |argument| engine.releaseValue.?(argument);
    return 41 + @as(i32, @intCast(seen.timers));
}

fn testClearTimer(r: runtime.Context, id: i32) void {
    seen.realm = r;
    seen.cleared = id;
}

fn testRequestAnimationFrame(r: runtime.Context, callback: runtime.JSValue) u32 {
    seen.realm = r;
    seen.frames += 1;
    engine.releaseValue.?(callback);
    return 9;
}

fn testCancelAnimationFrame(r: runtime.Context, handle: u32) void {
    seen.realm = r;
    seen.cancelled = handle;
}

fn testWindowDestroyed(_: runtime.Context) void {}

const test_operations = runtime.WindowOperations{
    .initializeTimer = testInitializeTimer,
    .clearTimer = testClearTimer,
    .requestAnimationFrame = testRequestAnimationFrame,
    .cancelAnimationFrame = testCancelAnimationFrame,
    .windowDestroyed = testWindowDestroyed,
};

fn installed() !runtime.Context {
    const ctx = try realm();
    try engine.installWindowOperations.?(ctx, &test_operations);
    seen = .{};
    return ctx;
}

test "setTimeout and setInterval hand their converted arguments to the host" {
    const ctx = try installed();

    var reports = try run("globalThis.id = setTimeout(function () {}, 5, 'a', 1);");
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    try std.testing.expectEqual(@as(usize, 1), seen.timers);
    try std.testing.expectEqual(@as(usize, 1), seen.function_handlers);
    try std.testing.expectEqual(@as(i32, 5), seen.timeout);
    try std.testing.expectEqual(@as(usize, 2), seen.argument_count);
    try std.testing.expect(!seen.repeat);
    try std.testing.expect(seen.realm.? == ctx);
    // The host's id is what script gets.
    try std.testing.expectEqual(@as(i32, 42), try scriptInt("globalThis.id"));

    // A string handler is converted at the call; the timeout by ToInt32.
    reports = try run("globalThis.id2 = setInterval({ toString() { globalThis.converted = 1; return 'globalThis.ran = 1'; } }, 2 ** 32 + 7);");
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    try std.testing.expectEqual(@as(i32, 1), try scriptInt("globalThis.converted"));
    try std.testing.expectEqualStrings("globalThis.ran = 1", seen.stringSource());
    try std.testing.expectEqual(@as(i32, 7), seen.timeout);
    try std.testing.expect(seen.repeat);
    try std.testing.expectEqual(@as(i32, 43), try scriptInt("globalThis.id2"));
    try std.testing.expectEqual(@as(i32, 1), try scriptInt("setTimeout.length"));
    try std.testing.expectEqual(@as(i32, 0), try scriptInt("clearTimeout.length"));
}

test "setTimeout without a handler, or with one whose ToString throws, throws" {
    _ = try installed();

    var reports = try run("setTimeout();");
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expect(std.mem.indexOf(u8, reports.messageText(), "TypeError") != null);

    reports = try run("setTimeout({ toString() { throw new Error('no string'); } });");
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expect(std.mem.indexOf(u8, reports.messageText(), "no string") != null);
    try std.testing.expectEqual(@as(usize, 0), seen.timers);
}

test "clearTimeout and clearInterval convert the id with ToInt32" {
    const ctx = try installed();
    _ = try run("clearTimeout('5');");
    try std.testing.expectEqual(@as(?i32, 5), seen.cleared);
    try std.testing.expect(seen.realm.? == ctx);
    _ = try run("clearInterval(6.9);");
    try std.testing.expectEqual(@as(?i32, 6), seen.cleared);
}

test "requestAnimationFrame takes a callable; cancelAnimationFrame a handle in range" {
    const ctx = try installed();
    _ = try run("globalThis.handle = requestAnimationFrame(function () {});");
    try std.testing.expectEqual(@as(usize, 1), seen.frames);
    try std.testing.expect(seen.realm.? == ctx);
    try std.testing.expectEqual(@as(i32, 9), try scriptInt("globalThis.handle"));

    _ = try run("globalThis.none = requestAnimationFrame(3);");
    try std.testing.expectEqual(@as(usize, 1), seen.frames);
    try std.testing.expectEqual(@as(i32, 0), try scriptInt("globalThis.none"));

    _ = try run("cancelAnimationFrame(0); cancelAnimationFrame(NaN); cancelAnimationFrame('9');");
    try std.testing.expectEqual(@as(?u32, null), seen.cancelled);
    _ = try run("cancelAnimationFrame(9);");
    try std.testing.expectEqual(@as(?u32, 9), seen.cancelled);
}

// ============================================================================
// What the binding leaves behind
// ============================================================================
//
// Every handle the binding makes is released, or it keeps alive the realm the
// value belongs to - and one handle anywhere into a realm pins its whole heap.
// A thrown TypeError the binding never released kept every frame realm alive
// (docs/lessons/architecture-engine-code-defines-a-realm-s-properties-it-never-assigns-them.md);
// with a realm per navigation, that ran a long WPT sweep out of V8 heap.
// Measured two ways: V8's own count of live global-handle bytes, and the
// native contexts left after a full collection.

/// Native contexts alive after a full collection.
fn liveContexts() usize {
    const isolate = isolate_once.?;
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    var count: usize = 0;
    ffi.v8_Isolate_GetContextCounts(isolate, &count, null);
    return count;
}

/// Script's value of `expression` in `context`, as a handle the caller disposes.
fn scriptValueIn(context: *ffi.Context, expression: []const u8) !*ffi.Value {
    const i = isolate_once.?;
    const code = ffi.v8_String_NewFromUtf8(i, expression.ptr, @intCast(expression.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(code);
    const script = ffi.v8_Script_Compile(context, code) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.RunFailed;
}

/// `globalThis[name] = value` in the test realm.
fn exposeValue(name: []const u8, value: *ffi.Value) !void {
    const context = context_once.?;
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate_once.?, name.ptr, @intCast(name.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    if (!ffi.v8_Object_Set(global, context, @ptrCast(key), value)) return error.SetFailed;
}

/// One call of a conversions throw helper, in `context`, caught.
const Thrower = struct {
    const Kind = enum {
        type_error,
        type_error_from_context,
        range_error,
        plain_error,
        dom_exception,
        dom_exception_from_context,
        webidl_error,
        webidl_error_from_context,
    };

    context: *ffi.Context,
    kind: Kind,

    fn body(data: ?*anyopaque) callconv(.c) void {
        const self: *Thrower = @ptrCast(@alignCast(data.?));
        const isolate = isolate_once.?;
        const conv = v8.conversions;
        // Entered, so the helpers that throw in the current realm throw in this one.
        ffi.v8_Context_Enter(self.context);
        defer ffi.v8_Context_Exit(self.context);
        switch (self.kind) {
            .type_error => conv.throwTypeError(isolate, "a TypeError"),
            .type_error_from_context => conv.throwTypeErrorFromContext(isolate, self.context, "Illegal invocation"),
            .range_error => conv.throwRangeError(isolate, "a RangeError"),
            .plain_error => conv.throwError(isolate, "an Error"),
            .dom_exception => conv.throwDOMException(isolate, "NotFoundError", "not found"),
            .dom_exception_from_context => conv.throwDOMExceptionFromContext(isolate, self.context, "SecurityError", "blocked"),
            .webidl_error => conv.throwWebIDLError(isolate, "TypeError"),
            .webidl_error_from_context => conv.throwWebIDLErrorFromContext(isolate, self.context, "InvalidStateError"),
        }
    }

    /// Throw once and catch it; what was thrown is released.
    fn throwAndCatch(self: *Thrower) !void {
        var thrown: ?*ffi.Value = null;
        if (!ffi.v8_RunCatching(isolate_once.?, body, self, &thrown)) return error.DidNotThrow;
        ffi.v8_Value_Dispose(thrown orelse return error.NothingThrown);
    }
};

test "every conversions throw helper leaves no handle behind" {
    _ = try realm();
    const isolate = isolate_once.?;
    // throwDOMException constructs through the realm's DOMException.
    _ = try run("globalThis.DOMException = class { constructor(m, n) { this.message = m; this.name = n; } };");

    // What one handle costs in V8's count.
    const handle_bytes = blk: {
        const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        const one = ffi.v8_Number_New(isolate, 1);
        const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        ffi.v8_Value_Dispose(@ptrCast(one));
        break :blk with_one - start;
    };
    try std.testing.expect(handle_bytes > 0);

    // A leak is at least one handle per throw (each helper left two to ten).
    // V8 may take a handle of its own once along the way - one appeared, once,
    // over 32 throwDOMException calls - so a quarter of a handle a throw is the
    // line.
    const rounds = 32;
    var leaked = false;
    inline for (std.meta.fields(Thrower.Kind)) |field| {
        var thrower: Thrower = .{ .context = context_once.?, .kind = @enumFromInt(field.value) };
        // The first call may make what every later one reuses.
        try thrower.throwAndCatch();
        const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        for (0..rounds) |_| try thrower.throwAndCatch();
        const after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        if (after -| before >= handle_bytes * rounds / 4) {
            std.debug.print("{s}: global handles {d} -> {d} bytes over {d} throws ({d} bytes a handle)\n", .{ field.name, before, after, rounds, handle_bytes });
            leaked = true;
        }
    }
    if (leaked) return error.HandlesLeaked;
}

test "an exception thrown in a realm does not keep that realm alive" {
    _ = try realm();
    const isolate = isolate_once.?;
    const baseline = liveContexts();

    // The control: a realm nothing refers to any more is collected.
    ffi.v8_Context_Dispose(ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed);
    try std.testing.expectEqual(baseline, liveContexts());

    // Every helper throws in it - the DOMException ones through the fallback,
    // for this realm has no DOMException - and everything thrown is released.
    const other = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
    inline for (std.meta.fields(Thrower.Kind)) |field| {
        var thrower: Thrower = .{ .context = other, .kind = @enumFromInt(field.value) };
        for (0..4) |_| try thrower.throwAndCatch();
    }
    ffi.v8_Context_Dispose(other);
    const after = liveContexts();
    if (after != baseline) {
        std.debug.print("native contexts: {d} before, {d} after the thrower realm was released\n", .{ baseline, after });
        return error.RealmKeptAlive;
    }
}

/// The process-wide pools Instances come from, made once for the file and,
/// like V8 here, never torn down.
var pools_ready = false;

fn ensurePools() void {
    if (pools_ready) return;
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    pools_ready = true;
}

/// A platform object with attribute setters, for the setter tests: an Event,
/// whose cancelBubble setter takes a boolean.
fn eventInRealm() !void {
    _ = try realm();
    ensurePools();
    const context = context_once.?;
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    v8.interface_bindings.Event.registerGlobalFast(isolate_once.?, context, global, "Event");
    const reports = try run("globalThis.e = new Event('x'); e.cancelBubble = false;");
    try std.testing.expectEqual(@as(usize, 0), reports.count);
}

test "an attribute setter releases the handle of the value it converted" {
    try eventInRealm();
    const isolate = isolate_once.?;

    // The same loop assigning an expando - no setter - is the control: what
    // running a script costs, if anything.
    var start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    _ = try run("for (let i = 0; i < 64; i++) e.expando = i % 2 == 0;");
    const control = ffi.v8_Isolate_GetGlobalHandleBytes(isolate) -| start;

    start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const reports = try run("for (let i = 0; i < 64; i++) e.cancelBubble = i % 2 == 0;");
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    const setters = ffi.v8_Isolate_GetGlobalHandleBytes(isolate) -| start;
    if (setters > control) {
        std.debug.print("64 setter calls: {d} bytes of global handles left, against {d} for 64 expando stores\n", .{ setters, control });
        return error.HandlesLeaked;
    }
}

test "a value assigned through an attribute setter does not keep its realm alive" {
    try eventInRealm();
    const isolate = isolate_once.?;
    const baseline = liveContexts();

    // The control: an object of another realm, stored and forgotten, lets it go.
    {
        const other = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
        const object = try scriptValueIn(other, "({})");
        try exposeValue("fromOther", object);
        ffi.v8_Value_Dispose(object);
        _ = try run("e.expando = globalThis.fromOther; delete e.expando; delete globalThis.fromOther;");
        ffi.v8_Context_Dispose(other);
    }
    try std.testing.expectEqual(baseline, liveContexts());

    // The same object handed to a boolean setter: converted, then forgotten.
    const other = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
    const object = try scriptValueIn(other, "({})");
    try exposeValue("fromOther", object);
    ffi.v8_Value_Dispose(object);
    const reports = try run("for (let i = 0; i < 8; i++) e.cancelBubble = globalThis.fromOther; delete globalThis.fromOther;");
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    ffi.v8_Context_Dispose(other);
    const after = liveContexts();
    if (after != baseline) {
        std.debug.print("native contexts: {d} before, {d} after the setter's argument realm was released\n", .{ baseline, after });
        return error.RealmKeptAlive;
    }
}

// ============================================================================
// The interfaces of a realm made without the snapshot
// ============================================================================

test "the interfaces defined on a realm without the snapshot keep none of its handles" {
    _ = try realm();
    ensurePools();
    const isolate = isolate_once.?;
    const handle_bytes = blk: {
        const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        const one = ffi.v8_Number_New(isolate, 1);
        const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        ffi.v8_Value_Dispose(@ptrCast(one));
        break :blk with_one - start;
    };

    const Round = struct {
        /// A context with every interface defined afresh - the no-snapshot
        /// startup path's setup (inheritance, aliases, Intl, toLocaleString
        /// included) - then released.
        fn run(i: *ffi.Isolate) !void {
            const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
            ffi.v8_Context_Enter(context);
            v8.interface_bindings.initializeBindingsWithGlobalTemplate(i, context);
            ffi.v8_Context_Exit(context);
            _ = ffi.v8_Isolate_ContextDisposedNotification(i, true);
            ffi.v8_Context_Dispose(context);
        }
    };
    // The first round makes what every later one reuses (the templates).
    try Round.run(isolate);
    const contexts_before = liveContexts();
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const rounds = 3;
    for (0..rounds) |_| try Round.run(isolate);
    const contexts_after = liveContexts();
    const after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    // Before the fix: about 5,000 handles a realm - a key string, a
    // constructor and a prototype per interface with a parent, and the Intl
    // constructors and toLocaleString methods - and every such realm alive
    // for the life of the process.
    if (after -| before >= handle_bytes or contexts_after != contexts_before) {
        std.debug.print("global handles {d} -> {d} bytes, native contexts {d} -> {d}, over {d} realms ({d} bytes a handle)\n", .{ before, after, contexts_before, contexts_after, rounds, handle_bytes });
        return error.HandlesLeaked;
    }
}

// ============================================================================
// The engine protocol, area 1 (design 4.2-4.3): Window realms, the realms
// named from the running script, and classic scripts - through
// `@import("engine")`, bound to V8 (protocol_realms.zig, protocol_scripts.zig).
// ============================================================================

const protocol = @import("engine");
const interfaces = @import("interfaces");

/// The test's host for a Window realm: it makes the realm's Window.
const WindowHost = struct {
    made: usize = 0,
    realm: ?runtime.Context = null,
    fail: bool = false,

    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        const self: *WindowHost = @ptrCast(@alignCast(host.?));
        // The global is the Window's wrapper, which the adapter's wrapper
        // cache releases at the realm's end.
        std.debug.assert(global_this == .handle);
        if (self.fail) return null;
        self.made += 1;
        self.realm = r;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

/// A Window realm in the file's agent - entered, so made with no script
/// running, as a navigation makes one.
fn windowRealm(host: *WindowHost, from_snapshot: bool, global_this: protocol.GlobalThis) !runtime.Context {
    _ = try realm();
    ensurePools();
    return protocol.createWindowRealm(&.{
        .agent = @ptrCast(isolate_once.?),
        .allocator = std.heap.c_allocator,
        .from_snapshot = from_snapshot,
        .timer = null,
        .origin = "https://example.test",
        .global_this = global_this,
        .create_global_object = WindowHost.createGlobalObject,
        .host = host,
    });
}

/// What the protocol's reporter was handed, copied.
const ProtocolReports = struct {
    count: usize = 0,
    message_buffer: [256]u8 = undefined,
    message_len: usize = 0,
    filename_buffer: [256]u8 = undefined,
    filename_len: usize = 0,
    lineno: u32 = 0,
    colno: u32 = 0,
    had_value: bool = false,
    realm: ?runtime.Context = null,
    /// A global of `realm` to read - without running script - when the
    /// report comes: what had run by then.
    probe: ?[]const u8 = null,
    probe_value: ?i32 = null,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *ProtocolReports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        self.message_len = @min(info.message.len, self.message_buffer.len);
        @memcpy(self.message_buffer[0..self.message_len], info.message[0..self.message_len]);
        self.filename_len = @min(info.filename.len, self.filename_buffer.len);
        @memcpy(self.filename_buffer[0..self.filename_len], info.filename[0..self.filename_len]);
        self.lineno = info.lineno;
        self.colno = info.colno;
        self.had_value = info.error_value == .handle;
        self.realm = info.realm;
        if (self.probe) |name| self.probe_value = if (info.realm) |r| globalInt(r, name) else null;
    }

    fn reporter(self: *ProtocolReports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }

    fn message(self: *const ProtocolReports) []const u8 {
        return self.message_buffer[0..self.message_len];
    }

    fn filename(self: *const ProtocolReports) []const u8 {
        return self.filename_buffer[0..self.filename_len];
    }
};

fn contextOf(r: runtime.Context) *ffi.Context {
    return @ptrCast(@alignCast(r.engine_ctx.?));
}

/// `globalThis[name]` of `r` as an integer, read without running script;
/// null when it is undefined.
fn globalInt(r: runtime.Context, name: []const u8) ?i32 {
    const context = contextOf(r);
    const global = ffi.v8_Context_Global(context) orelse return null;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate_once.?, name.ptr, @intCast(name.len)) orelse return null;
    defer ffi.v8_String_Dispose(key);
    const value = ffi.v8_Object_Get(global, context, @ptrCast(key)) orelse return null;
    defer ffi.v8_Value_Dispose(value);
    if (ffi.v8_Value_IsUndefined(value)) return null;
    return ffi.v8_Value_Int32Value(value, context);
}

/// `globalThis[name] = value` in `r`, `value` a protocol value's handle.
fn setGlobal(r: runtime.Context, name: []const u8, value: runtime.JSValue) !void {
    const context = contextOf(r);
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate_once.?, name.ptr, @intCast(name.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    const handle: *ffi.Value = @ptrCast(@alignCast(value.handle.ptr));
    if (!ffi.v8_Object_Set(global, context, @ptrCast(key), handle)) return error.SetFailed;
}

/// A classic script's completion value, ToString'd; what it throws fails the
/// test.
fn evalString(r: runtime.Context, source: []const u8) ![]u8 {
    var reports: ProtocolReports = .{};
    return protocol.evaluateClassicScriptToString(r, .{ .utf8 = source }, "", null, std.testing.allocator, reports.reporter()) catch |err| {
        if (reports.count > 0) std.debug.print("{s} threw: {s}\n", .{ source, reports.message() });
        return err;
    };
}

fn expectEval(r: runtime.Context, source: []const u8, expected: []const u8) !void {
    const got = try evalString(r, source);
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings(expected, got);
}

fn evalOwned(r: runtime.Context, source: []const u8) !protocol.Owned {
    var reports: ProtocolReports = .{};
    return protocol.evaluateClassicScript(r, .{ .utf8 = source }, "", null, reports.reporter());
}

test "protocol: a Window realm made afresh has the host's Window as its global object" {
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w);

    // HTML "create a new realm": the host made the Window, once, for this realm.
    try std.testing.expectEqual(@as(usize, 1), host.made);
    try std.testing.expectEqual(w, host.realm.?);
    // WebIDL 3.8: the global is a Window, with Window's and EventTarget's
    // members as its own; self and frames are the global, window reaches it.
    try expectEval(w, "globalThis instanceof Window && globalThis instanceof EventTarget", "true");
    try expectEval(w, "[self === globalThis, frames === globalThis, window === globalThis].join()", "true,true,true");
    try expectEval(w, "Object.getOwnPropertyDescriptor(globalThis, 'addEventListener') !== undefined", "true");
    try expectEval(w, "typeof console.log", "function");
    // The realm record, with its intrinsics, is made with the realm.
    try std.testing.expect(w.realm != null);
    try std.testing.expect(w.realm.?.hasIntrinsics());
}

test "protocol: a realm restored from a snapshot the agent lacks is built afresh" {
    // The no-snapshot startup path: an agent made without a snapshot (as on
    // JavaScriptCore, always) still gets a working Window realm.
    var host: WindowHost = .{};
    const w = try windowRealm(&host, true, .new_window_proxy);
    defer protocol.destroyWindowRealm(w);
    try std.testing.expectEqual(@as(usize, 1), host.made);
    try expectEval(w, "globalThis instanceof Window && self === globalThis", "true");
}

test "protocol: a realm whose Window the host could not make is undone" {
    _ = try realm();
    const before = liveContexts();
    var host: WindowHost = .{ .fail = true };
    try std.testing.expectError(error.OperationFailed, windowRealm(&host, false, .new_window_proxy));
    // Its context was exited - the file's context is the entered one again -
    // and released.
    const entered = ffi.v8_Isolate_GetEnteredOrMicrotaskContext(isolate_once.?) orelse return error.NothingEntered;
    defer ffi.v8_Context_Dispose(entered);
    try std.testing.expectEqual(ffi.v8_Context_GetRawAddress(context_once.?), ffi.v8_Context_GetRawAddress(entered));
    try std.testing.expectEqual(before, liveContexts());
}

test "protocol: a realm made around another's WindowProxy is what that WindowProxy reaches" {
    var host_a: WindowHost = .{};
    const a = try windowRealm(&host_a, false, .new_window_proxy);
    const proxy = try evalOwned(a, "globalThis.fromA = 1; globalThis");
    defer proxy.release();

    // [reuse_window_proxy]: a navigation's new Window, behind the same proxy.
    var host_b: WindowHost = .{};
    const b = try windowRealm(&host_b, false, .{ .window_proxy_of = a });
    defer protocol.destroyWindowRealm(b);
    // The old realm ends first, as a navigation's does.
    protocol.destroyWindowRealm(a);
    try std.testing.expectEqual(b, protocol.entryRealm().?);

    // What script held of A's WindowProxy is B's global now; A's own
    // properties went with A's global object.
    try setGlobal(b, "heldProxy", proxy.value);
    try expectEval(b, "[heldProxy === globalThis, self === globalThis, typeof fromA].join()", "true,true,undefined");
}

test "protocol: destroyWindowRealm retires the realm and lets its context go" {
    _ = try realm();
    const baseline = liveContexts();
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    try expectEval(w, "globalThis.kept = [globalThis, self]; kept.length", "2");
    protocol.destroyWindowRealm(w);
    // Retired: the realm can be compared, never entered.
    try std.testing.expect(w.engine_ctx == null);
    const after = liveContexts();
    if (after != baseline) {
        std.debug.print("native contexts: {d} before, {d} after the Window realm ended\n", .{ baseline, after });
        return error.RealmKeptAlive;
    }
}

test "protocol: a Window realm made and ended leaves no global handle behind" {
    _ = try realm();
    const isolate = isolate_once.?;
    // What one handle costs in V8's count.
    const handle_bytes = blk: {
        const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        const one = ffi.v8_Number_New(isolate, 1);
        const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        ffi.v8_Value_Dispose(@ptrCast(one));
        break :blk with_one - start;
    };
    // The first realm makes what every later one reuses (the templates).
    var host: WindowHost = .{};
    protocol.destroyWindowRealm(try windowRealm(&host, false, .new_window_proxy));
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    // The global the host was lent is the Window's wrapper-cache entry's,
    // released at the realm's end with everything else it held.
    const rounds = 3;
    for (0..rounds) |_| protocol.destroyWindowRealm(try windowRealm(&host, false, .new_window_proxy));
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    const after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    if (after -| before >= handle_bytes) {
        std.debug.print("global handles {d} -> {d} bytes over {d} Window realms ({d} bytes a handle)\n", .{ before, after, rounds, handle_bytes });
        return error.HandlesLeaked;
    }
}

/// A frame's Window realm, made as a frame's is: from inside its parent's
/// running script (engine.runInRealm), with the parent named.
const FrameRealm = struct {
    host: WindowHost = .{},
    parent: runtime.Context,
    global_this: protocol.GlobalThis = .new_window_proxy,
    made: ?runtime.Context = null,
    failed: ?anyerror = null,
    /// The entry realm just after the frame's realm was made, still inside
    /// the parent's steps.
    entry_after: ?runtime.Context = null,

    fn make(self: *FrameRealm) !runtime.Context {
        try protocol.runInRealm(self.parent, steps, self);
        if (self.failed) |err| return err;
        return self.made.?;
    }

    fn steps(data: ?*anyopaque) void {
        const self: *FrameRealm = @ptrCast(@alignCast(data.?));
        self.made = protocol.createWindowRealm(&.{
            .agent = @ptrCast(isolate_once.?),
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .global_this = self.global_this,
            .parent = self.parent,
            .create_global_object = WindowHost.createGlobalObject,
            .host = &self.host,
        }) catch |err| {
            self.failed = err;
            return;
        };
        self.entry_after = protocol.entryRealm();
    }
};

test "protocol: a frame's realm is made inside its parent's script and not left entered" {
    var host: WindowHost = .{};
    const parent = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(parent);
    var frame_realm: FrameRealm = .{ .parent = parent };
    const frame = try frame_realm.make();
    defer protocol.destroyWindowRealm(frame);

    // The parent's steps went on in the parent's realm: the frame's context
    // was entered only while it was made.
    try std.testing.expectEqual(parent, frame_realm.entry_after.?);
    try std.testing.expectEqual(parent, protocol.entryRealm().?);
    try std.testing.expectEqual(@as(usize, 1), frame_realm.host.made);
    try expectEval(frame, "globalThis instanceof Window && self === globalThis", "true");
}

test "protocol: a frame's realm shares its parent's security token" {
    var host: WindowHost = .{};
    const parent = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(parent);
    var frame_realm: FrameRealm = .{ .parent = parent };
    const frame = try frame_realm.make();
    defer protocol.destroyWindowRealm(frame);

    try expectEval(frame, "globalThis.fromFrame = 7; fromFrame", "7");
    const frame_global = try evalOwned(frame, "globalThis");
    defer frame_global.release();
    try setGlobal(parent, "frameWindow", frame_global.value);
    // V8 lets script through to another context's global proxy only when the
    // two share a security token; the WindowProxy checks are the host's.
    try expectEval(parent, "frameWindow.fromFrame", "7");
    try expectEval(parent, "delete globalThis.frameWindow", "true");
}

test "protocol: ending a parent's realm ends its frames' realms first" {
    var host: WindowHost = .{};
    const parent = try windowRealm(&host, false, .new_window_proxy);
    var frame_realm: FrameRealm = .{ .parent = parent };
    const frame = try frame_realm.make();
    var nested_realm: FrameRealm = .{ .parent = frame };
    const nested = try nested_realm.make();

    protocol.destroyWindowRealm(parent);
    // Retired, every one: each may only be compared now.
    try std.testing.expect(nested.engine_ctx == null);
    try std.testing.expect(frame.engine_ctx == null);
    try std.testing.expect(parent.engine_ctx == null);
}

test "protocol: a frame's realm whose WindowProxy went on is severed from its Window at its end" {
    var host: WindowHost = .{};
    const parent = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(parent);
    var old_realm: FrameRealm = .{ .parent = parent };
    const old = try old_realm.make();
    // A function of the old realm that reads its Window through its global.
    const reader = try evalOwned(old, "(function () { return typeof name; })");
    defer reader.release();

    // The navigation's new Window, behind the same WindowProxy; the old realm
    // ends, and its Window with it.
    var new_realm: FrameRealm = .{ .parent = parent, .global_this = .{ .window_proxy_of = old } };
    const new = try new_realm.make();
    defer protocol.destroyWindowRealm(new);
    protocol.destroyWindowRealm(old);

    // The old global no longer names the freed Window: reading a Window member
    // through it is a TypeError, not a read of freed memory.
    try setGlobal(parent, "reader", reader.value);
    try expectEval(parent, "(() => { try { reader(); return 'read'; } catch (e) { return e.name; } })()", "TypeError");
    try expectEval(parent, "delete globalThis.reader", "true");
}

test "protocol: performMicrotaskCheckpoint runs the agent's microtasks, whichever realm queued them" {
    var host: WindowHost = .{};
    const parent = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(parent);
    var frame_realm: FrameRealm = .{ .parent = parent };
    const frame = try frame_realm.make();
    defer protocol.destroyWindowRealm(frame);

    // One microtask queued in each realm, from no script: nothing runs them
    // until the agent's checkpoint, which runs both.
    const Ran = struct {
        count: usize = 0,
        fn steps(data: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            self.count += 1;
        }
    };
    var ran: Ran = .{};
    try protocol.queueMicrotask(parent, Ran.steps, &ran);
    try protocol.queueMicrotask(frame, Ran.steps, &ran);
    try std.testing.expectEqual(@as(usize, 0), ran.count);
    try protocol.performMicrotaskCheckpoint(parent.agent.?);
    try std.testing.expectEqual(@as(usize, 2), ran.count);
}

test "protocol: notifyMemoryPressure critical collects what a realm that ended held" {
    _ = try realm();
    const agent: *protocol.Agent = @ptrCast(isolate_once.?);
    const baseline = liveContexts();
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    try expectEval(w, "globalThis.kept = [globalThis, self]; kept.length", "2");
    protocol.destroyWindowRealm(w);
    // What the page held is garbage now: the host asks for it back.
    protocol.notifyMemoryPressure(agent, .critical);
    var count: usize = 0;
    ffi.v8_Isolate_GetContextCounts(isolate_once.?, &count, null);
    if (count != baseline) {
        std.debug.print("native contexts: {d} before, {d} after the realm ended and memory pressure\n", .{ baseline, count });
        return error.RealmKeptAlive;
    }
    // A moderate hint collects nothing it must not, and returns.
    protocol.notifyMemoryPressure(agent, .moderate);
}

test "protocol: the entry and incumbent realms are the innermost prepared realm" {
    // Two realms made here: the context manager names a realm by where its
    // context is, and a full collection (liveContexts, in earlier tests) can
    // move the file's.
    var host_a: WindowHost = .{};
    const a = try windowRealm(&host_a, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(a);
    var host_b: WindowHost = .{};
    const b = try windowRealm(&host_b, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(b);

    const outer = try protocol.prepareToRunScript(a);
    try std.testing.expectEqual(a, protocol.entryRealm().?);
    // No script is running: the incumbent is the entry realm (HTML
    // 8.1.3.3.2 with an empty stack of script-having contexts).
    try std.testing.expectEqual(a, protocol.incumbentRealm().?);
    const inner = try protocol.prepareToRunScript(b);
    try std.testing.expectEqual(b, protocol.entryRealm().?);
    try std.testing.expectEqual(b, protocol.incumbentRealm().?);
    protocol.cleanUpAfterRunningScript(inner);
    try std.testing.expectEqual(a, protocol.entryRealm().?);
    protocol.cleanUpAfterRunningScript(outer);
}

test "protocol: functionRealm follows bound functions and proxies to their target's realm" {
    var host_w: WindowHost = .{};
    const w = try windowRealm(&host_w, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w);
    var host_o: WindowHost = .{};
    const other = try windowRealm(&host_o, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(other);

    const f = try evalOwned(w, "(function f() {})");
    defer f.release();
    try std.testing.expectEqual(w, protocol.functionRealm(f.value).?);
    try setGlobal(other, "fromW", f.value);

    const bound = try evalOwned(other, "fromW.bind(null)");
    defer bound.release();
    try std.testing.expectEqual(w, protocol.functionRealm(bound.value).?);
    const proxied = try evalOwned(other, "new Proxy(fromW, {})");
    defer proxied.release();
    try std.testing.expectEqual(w, protocol.functionRealm(proxied.value).?);
    const own = try evalOwned(other, "(function () {})");
    defer own.release();
    try std.testing.expectEqual(other, protocol.functionRealm(own.value).?);
    // A revoked proxy: GetFunctionRealm throws a TypeError, which the caller
    // answers.
    const revoked = try evalOwned(other, "(() => { const r = Proxy.revocable(fromW, {}); r.revoke(); return r.proxy; })()");
    defer revoked.release();
    try std.testing.expect(protocol.functionRealm(revoked.value) == null);
    try std.testing.expect(protocol.functionRealm(.{ .number = 1 }) == null);
    try expectEval(other, "delete globalThis.fromW", "true");
}

test "protocol: runClassicScript runs a string value, and a parse error names the URL it was given" {
    const base = try realm();
    var reports: ProtocolReports = .{};
    const text = try evalOwned(base, "'globalThis.fromStringSource = 5;'");
    defer text.release();
    try protocol.runClassicScript(base, .{ .string = text.value }, "https://example.test/page.html", null, reports.reporter());
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    try std.testing.expectEqual(@as(?i32, 5), globalInt(base, "fromStringSource"));

    // A timer's string handler: its parse error is reported with the
    // document's URL (location.href), not a script's.
    const broken = try evalOwned(base, "'globalThis.neverSet = 1; 1 +'");
    defer broken.release();
    try std.testing.expectError(error.ExceptionReported, protocol.runClassicScript(base, .{ .string = broken.value }, "https://example.test/page.html", null, reports.reporter()));
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expectEqualStrings("https://example.test/page.html", reports.filename());
    try std.testing.expect(std.mem.indexOf(u8, reports.message(), "SyntaxError") != null);
    try std.testing.expectEqual(@as(?i32, null), globalInt(base, "neverSet"));
}

test "protocol: what a classic script throws is reported before the microtask checkpoint" {
    const base = try realm();
    var reports: ProtocolReports = .{ .probe = "microtaskRan" };
    try std.testing.expectError(error.ExceptionReported, protocol.runClassicScript(
        base,
        .{ .utf8 = "globalThis.microtaskRan = 0;\nPromise.resolve().then(() => { globalThis.microtaskRan = 1; });\n  throw new TypeError('late');" },
        "https://example.test/t.js",
        null,
        reports.reporter(),
    ));
    // HTML 8.1.4.4 step 8.3: 1. report the exception, 2. clean up after
    // running script - whose checkpoint runs the reaction.
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expectEqual(@as(?i32, 0), reports.probe_value);
    try std.testing.expectEqual(@as(?i32, 1), globalInt(base, "microtaskRan"));
    // What the report carries.
    try std.testing.expectEqual(@as(?runtime.Context, base), reports.realm);
    try std.testing.expectEqualStrings("https://example.test/t.js", reports.filename());
    try std.testing.expectEqual(@as(u32, 3), reports.lineno);
    try std.testing.expectEqual(@as(u32, 3), reports.colno);
    try std.testing.expect(reports.had_value);
    try std.testing.expect(std.mem.indexOf(u8, reports.message(), "late") != null);
}

test "protocol: clean up after running script checkpoints only when no script is prepared" {
    const base = try realm();
    var reports: ProtocolReports = .{};
    const outer = try protocol.prepareToRunScript(base);
    try protocol.runClassicScript(base, .{ .utf8 = "globalThis.nested = 0; Promise.resolve().then(() => { globalThis.nested = 1; });" }, "", null, reports.reporter());
    // The outer realm execution context is still on the stack.
    try std.testing.expectEqual(@as(?i32, 0), globalInt(base, "nested"));
    protocol.cleanUpAfterRunningScript(outer);
    try std.testing.expectEqual(@as(?i32, 1), globalInt(base, "nested"));
}

test "protocol: evaluateClassicScript keeps the completion value; ToString's throw is reported" {
    const base = try realm();
    var reports: ProtocolReports = .{};

    const answer = try protocol.evaluateClassicScript(base, .{ .utf8 = "6 * 7" }, "", null, reports.reporter());
    defer answer.release();
    try std.testing.expectEqual(@as(f64, 42), try protocol.convertToUnrestrictedDouble(base, answer.value));

    try expectEval(base, "'caf\u{e9} ' + [1, 2]", "caf\u{e9} 1,2");
    try expectEval(base, "undefined", "undefined");

    try std.testing.expectError(error.ExceptionReported, protocol.evaluateClassicScript(base, .{ .utf8 = "throw 5" }, "", null, reports.reporter()));
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expect(reports.had_value);

    // ToString runs script, and what it throws is reported like the script's.
    try std.testing.expectError(error.ExceptionReported, protocol.evaluateClassicScriptToString(base, .{ .utf8 = "({ toString() { throw new Error('no string'); } })" }, "", null, std.testing.allocator, reports.reporter()));
    try std.testing.expectEqual(@as(usize, 2), reports.count);
    try std.testing.expect(std.mem.indexOf(u8, reports.message(), "no string") != null);
}

test "protocol: compileEventHandler makes the handler's function, or reports why it could not" {
    const base = try realm();
    var reports: ProtocolReports = .{};
    var source: protocol.EventHandlerSource = .{
        .body = "return event + 1;",
        .name = "onclick",
        .url = "https://example.test/doc.html",
        .lineno = 10,
        .parameters = .event,
        .document = null,
        .form_owner = null,
        .element = null,
    };
    const onclick = (try protocol.compileEventHandler(base, &source, reports.reporter())) orelse return error.NoFunction;
    defer onclick.release();
    try setGlobal(base, "handler", onclick.value);
    try expectEval(base, "[handler(1), handler.name, handler.length].join()", "2,onclick,1");

    // A Window's onerror takes the five arguments of the error handler.
    source.body = "return [event, source, lineno, colno, error].join('|');";
    source.name = "onerror";
    source.parameters = .onerror;
    const onerror = (try protocol.compileEventHandler(base, &source, reports.reporter())) orelse return error.NoFunction;
    defer onerror.release();
    try setGlobal(base, "handler", onerror.value);
    try expectEval(base, "handler.length + ':' + handler('m', 's', 1, 2, 'e')", "5:m|s|1|2|e");

    // An SVG element's handlers name their argument `evt`.
    source.body = "return evt;";
    source.parameters = .evt;
    const svg = (try protocol.compileEventHandler(base, &source, reports.reporter())) orelse return error.NoFunction;
    defer svg.release();
    try setGlobal(base, "handler", svg.value);
    try expectEval(base, "handler('x')", "x");

    // The element's scope: its properties are names in the body.
    try eventInRealm();
    const event_value = try evalOwned(base, "globalThis.e");
    defer event_value.release();
    source.body = "return type;";
    source.parameters = .event;
    source.element = protocol.convertToPlatformObject(base, event_value.value) orelse return error.NoPlatformObject;
    const scoped = (try protocol.compileEventHandler(base, &source, reports.reporter())) orelse return error.NoFunction;
    defer scoped.release();
    try setGlobal(base, "handler", scoped.value);
    try expectEval(base, "handler()", "x");
    source.element = null;

    // A body that does not parse: a SyntaxError reported at the attribute's
    // place, and no function.
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    source.body = "return (;";
    try std.testing.expect(try protocol.compileEventHandler(base, &source, reports.reporter()) == null);
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expectEqualStrings("https://example.test/doc.html", reports.filename());
    try std.testing.expectEqual(@as(u32, 10), reports.lineno);
    try std.testing.expect(std.mem.indexOf(u8, reports.message(), "SyntaxError") != null);
    try expectEval(base, "delete globalThis.handler", "true");
}

test "protocol: extractErrorInformation reads an error's message and where it was made" {
    const base = try realm();
    var reports: ProtocolReports = .{};
    const made = try protocol.evaluateClassicScript(base, .{ .utf8 = "\n  new RangeError('far')" }, "https://example.test/e.js", null, reports.reporter());
    defer made.release();
    const info = try protocol.extractErrorInformation(base, made.value, std.testing.allocator);
    defer std.testing.allocator.free(info.message);
    defer std.testing.allocator.free(info.filename);
    try std.testing.expect(std.mem.indexOf(u8, info.message, "far") != null);
    try std.testing.expectEqualStrings("https://example.test/e.js", info.filename);
    try std.testing.expectEqual(@as(u32, 2), info.lineno);
    try std.testing.expectEqual(@as(?runtime.Context, base), info.realm);
    try std.testing.expect(info.error_value == .handle);

    // A value that is no Error still has a message.
    const plain = try protocol.extractErrorInformation(base, .{ .number = 3 }, std.testing.allocator);
    defer std.testing.allocator.free(plain.message);
    defer std.testing.allocator.free(plain.filename);
    try std.testing.expect(plain.message.len > 0);
}

// ----------------------------------------------------------------------------
// 4.1 The engine and its agents
// ----------------------------------------------------------------------------

test "protocol: initializeEngine starts V8 once, and refuses a snapshot this build did not make" {
    _ = try realm();
    try protocol.initializeEngine(.{});
    // No build stamp.
    try std.testing.expectError(error.OperationFailed, protocol.initializeEngine(.{ .snapshot = "not a snapshot" }));
    // Stamped, but not V8's.
    var stamped: [512 + v8.snapshot_loader.stamp_len]u8 = undefined;
    @memset(stamped[0..512], 0xab);
    v8.snapshot_loader.writeStamp(stamped[512..], 1);
    try std.testing.expectError(error.OperationFailed, protocol.initializeEngine(.{ .snapshot = &stamped }));
    // The platform outlives deinitializeEngine: V8 cannot start twice.
    protocol.deinitializeEngine();
    try protocol.initializeEngine(.{});
}

/// A realm of `agent` as the context manager registers every realm: a
/// context of its isolate, registered while it is entered.
const AgentRealm = struct {
    realm: runtime.Context,
    context: *ffi.Context,
    isolate: *ffi.Isolate,

    fn make(agent: *protocol.Agent) !AgentRealm {
        const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
        ffi.v8_Isolate_Enter(isolate);
        defer ffi.v8_Isolate_Exit(isolate);
        const scope = ffi.v8_HandleScope_New(isolate);
        defer if (scope) |s| ffi.v8_HandleScope_Dispose(s);
        const context = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
        v8.context_manager.init(std.heap.page_allocator) catch {};
        const r = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
        return .{ .realm = r, .context = context, .isolate = isolate };
    }

    fn end(self: AgentRealm) void {
        ffi.v8_Isolate_Enter(self.isolate);
        defer ffi.v8_Isolate_Exit(self.isolate);
        const scope = ffi.v8_HandleScope_New(self.isolate);
        defer if (scope) |s| ffi.v8_HandleScope_Dispose(s);
        v8.context_manager.removeContext(self.context);
        ffi.v8_Context_Dispose(self.context);
    }
};

test "protocol: an agent's [[CanBlock]] decides whether Atomics.wait may block" {
    _ = try realm();
    const no_hooks: protocol.HostHooks = .{};
    const blocking = try protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &no_hooks });
    defer protocol.destroyAgent(blocking);
    // No snapshot was given the engine: the agent is made without one.
    const window_agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = true, .hooks = &no_hooks });
    defer protocol.destroyAgent(window_agent);
    // Neither is left entered.
    try std.testing.expectEqual(isolate_once, ffi.v8_Isolate_GetCurrent());

    const in_blocking = try AgentRealm.make(blocking);
    defer in_blocking.end();
    const in_window = try AgentRealm.make(window_agent);
    defer in_window.end();
    const probe = "(() => { try { return Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 0); } catch (e) { return e.name; } })()";
    try expectEval(in_blocking.realm, probe, "timed-out");
    try expectEval(in_window.realm, probe, "TypeError");
}

/// What an agent's host heard through its hooks.
const AgentHost = struct {
    rejected: usize = 0,
    handled: usize = 0,
    realm: ?runtime.Context = null,
    promise_was_object: bool = false,
    /// The last call carried the rejection's value (a reject does; a
    /// handle does not).
    had_reason: bool = false,
    checkpoints: usize = 0,
    agent: ?*protocol.Agent = null,

    fn tracker(host: ?*anyopaque, r: runtime.Context, promise: protocol.Owned, operation: protocol.RejectionOperation, reason: ?protocol.Owned) void {
        const self: *AgentHost = @ptrCast(@alignCast(host.?));
        defer promise.release();
        defer if (reason) |value| value.release();
        switch (operation) {
            .reject => self.rejected += 1,
            .handle => self.handled += 1,
        }
        self.realm = r;
        self.promise_was_object = promise.value == .handle;
        self.had_reason = reason != null;
    }

    fn afterCheckpoint(host: ?*anyopaque, agent: *protocol.Agent) void {
        const self: *AgentHost = @ptrCast(@alignCast(host.?));
        self.checkpoints += 1;
        self.agent = agent;
    }
};

test "protocol: an agent's host hears of rejections, their handling, and each microtask checkpoint" {
    _ = try realm();
    var host: AgentHost = .{};
    const hooks: protocol.HostHooks = .{
        .promiseRejectionTracker = AgentHost.tracker,
        .afterMicrotaskCheckpoint = AgentHost.afterCheckpoint,
    };
    const agent = try protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &hooks, .host = &host });
    defer protocol.destroyAgent(agent);
    const in_agent = try AgentRealm.make(agent);
    defer in_agent.end();

    var reports: ProtocolReports = .{};
    // HostPromiseRejectionTracker(promise, "reject"), in the realm it ran in.
    try protocol.runClassicScript(in_agent.realm, .{ .utf8 = "globalThis.p = Promise.reject(new Error('x'));" }, "", null, reports.reporter());
    try std.testing.expectEqual(@as(usize, 1), host.rejected);
    try std.testing.expectEqual(@as(usize, 0), host.handled);
    try std.testing.expectEqual(in_agent.realm, host.realm.?);
    try std.testing.expect(host.promise_was_object);
    try std.testing.expect(host.had_reason);
    // Clean up after running script performed a checkpoint, and the host
    // was told - with its agent.
    try std.testing.expect(host.checkpoints >= 1);
    try std.testing.expectEqual(agent, host.agent.?);

    // HostPromiseRejectionTracker(promise, "handle").
    try protocol.runClassicScript(in_agent.realm, .{ .utf8 = "p.catch(() => {}); delete globalThis.p;" }, "", null, reports.reporter());
    try std.testing.expectEqual(@as(usize, 1), host.handled);
    try std.testing.expect(!host.had_reason);
    try std.testing.expectEqual(@as(usize, 0), reports.count);

    // Another agent's rejections are not this host's.
    const rejected_before = host.rejected;
    try protocol.runClassicScript(try realm(), .{ .utf8 = "Promise.reject(1).catch(() => {});" }, "", null, reports.reporter());
    try std.testing.expectEqual(rejected_before, host.rejected);
}

// ----------------------------------------------------------------------------
// 4.3 Modules [module_scripts]
// ----------------------------------------------------------------------------

/// A module graph the test host loaded: its records by specifier.
const Graph = struct {
    specifiers: []const []const u8,
    records: []const *protocol.ModuleRecord,
    resolved: usize = 0,

    fn resolve(data: ?*anyopaque, referrer: *protocol.ModuleRecord, request: protocol.ModuleRequest) ?*protocol.ModuleRecord {
        _ = referrer;
        const self: *Graph = @ptrCast(@alignCast(data.?));
        for (self.specifiers, self.records) |specifier, record| {
            if (std.mem.eql(u8, specifier, request.specifier)) {
                self.resolved += 1;
                return record;
            }
        }
        return null;
    }

    fn none(_: ?*anyopaque, _: *protocol.ModuleRecord, _: protocol.ModuleRequest) ?*protocol.ModuleRecord {
        return null;
    }
};

fn parsed(result: protocol.ParseResult) !*protocol.ModuleRecord {
    return switch (result) {
        .record => |record| record,
        .parse_error => |e| {
            e.release();
            return error.DidNotParse;
        },
    };
}

/// What `value` - a thrown value - says, as extract error information gives it.
fn expectErrorMentions(r: runtime.Context, value: runtime.JSValue, needle: []const u8) !void {
    const info = try protocol.extractErrorInformation(r, value, std.testing.allocator);
    defer std.testing.allocator.free(info.message);
    defer std.testing.allocator.free(info.filename);
    if (std.mem.indexOf(u8, info.message, needle) == null) {
        std.debug.print("expected \"{s}\" in: {s}\n", .{ needle, info.message });
        return error.WrongError;
    }
}

test "protocol: a module graph is parsed, its requests read, linked and evaluated" {
    const base = try realm();
    const dep = try parsed(try protocol.parseModule(base, "export const answer = 42;", "https://example.test/dep.js", null));
    defer protocol.releaseModuleRecord(dep);
    const json = try parsed(try protocol.parseJSONModule(base, "{\"n\": 1}", "https://example.test/d.json", null));
    defer protocol.releaseModuleRecord(json);
    const main = try parsed(try protocol.parseModule(
        base,
        "import { answer } from './dep.js';\nimport data from './d.json' with { type: 'json' };\nglobalThis.fromModule = answer + data.n;",
        "https://example.test/main.js",
        null,
    ));
    defer protocol.releaseModuleRecord(main);

    // [[RequestedModules]], in source order, with their type attributes.
    const requests = try protocol.moduleRequests(main, std.testing.allocator);
    defer {
        for (requests) |request| {
            std.testing.allocator.free(request.specifier);
            if (request.type_attribute) |t| std.testing.allocator.free(t);
        }
        std.testing.allocator.free(requests);
    }
    try std.testing.expectEqual(@as(usize, 2), requests.len);
    try std.testing.expectEqualStrings("./dep.js", requests[0].specifier);
    try std.testing.expect(requests[0].type_attribute == null);
    try std.testing.expectEqualStrings("./d.json", requests[1].specifier);
    try std.testing.expectEqualStrings("json", requests[1].type_attribute.?);

    var graph: Graph = .{ .specifiers = &.{ "./dep.js", "./d.json" }, .records = &.{ dep, json } };
    try std.testing.expect(try protocol.linkModule(base, main, Graph.resolve, &graph) == null);
    try std.testing.expectEqual(@as(usize, 2), graph.resolved);

    // HTML "run a module script": prepare, Evaluate(), clean up.
    const scope = try protocol.prepareToRunScript(base);
    const evaluation = try protocol.evaluateModule(base, main);
    protocol.cleanUpAfterRunningScript(scope);
    try std.testing.expect(evaluation == .completed);
    try std.testing.expectEqual(@as(?i32, 43), globalInt(base, "fromModule"));
    try expectEval(base, "delete globalThis.fromModule", "true");
}

test "protocol: what a module graph gets wrong comes back as its parse, link or evaluation error" {
    const base = try realm();

    // A SyntaxError is the parse error, not a throw.
    const broken = try protocol.parseModule(base, "export let = ;", "https://example.test/broken.js", null);
    try std.testing.expect(broken == .parse_error);
    try expectErrorMentions(base, broken.parse_error.value, "SyntaxError");
    broken.parse_error.release();

    // An import attribute other than "type" is a SyntaxError of the script.
    const attribute = try protocol.parseModule(base, "import x from './a.js' with { kind: 'x' };", "https://example.test/attr.js", null);
    try std.testing.expect(attribute == .parse_error);
    try expectErrorMentions(base, attribute.parse_error.value, "Import attribute");
    attribute.parse_error.release();

    // A request the host cannot resolve fails the Link with a TypeError.
    const missing = try parsed(try protocol.parseModule(base, "import './missing.js';", "https://example.test/missing-importer.js", null));
    defer protocol.releaseModuleRecord(missing);
    const link_error = (try protocol.linkModule(base, missing, Graph.none, null)) orelse return error.Linked;
    defer link_error.release();
    try expectErrorMentions(base, link_error.value, "missing.js");

    // A module that throws: Evaluate()'s promise is rejected with it.
    const thrower = try parsed(try protocol.parseModule(base, "throw new RangeError('at top level');", "https://example.test/throws.js", null));
    defer protocol.releaseModuleRecord(thrower);
    try std.testing.expect(try protocol.linkModule(base, thrower, Graph.none, null) == null);
    var scope = try protocol.prepareToRunScript(base);
    const thrown = try protocol.evaluateModule(base, thrower);
    protocol.cleanUpAfterRunningScript(scope);
    try std.testing.expect(thrown == .rejected);
    try expectErrorMentions(base, thrown.rejected.value, "at top level");
    thrown.rejected.release();

    // Top-level await: pending on a promise until the checkpoint of clean up.
    const awaiting = try parsed(try protocol.parseModule(base, "await 0; globalThis.afterAwait = 1;", "https://example.test/tla.js", null));
    defer protocol.releaseModuleRecord(awaiting);
    try std.testing.expect(try protocol.linkModule(base, awaiting, Graph.none, null) == null);
    scope = try protocol.prepareToRunScript(base);
    const pending = try protocol.evaluateModule(base, awaiting);
    try std.testing.expect(pending == .pending);
    pending.pending.release();
    try std.testing.expectEqual(@as(?i32, null), globalInt(base, "afterAwait"));
    protocol.cleanUpAfterRunningScript(scope);
    try std.testing.expectEqual(@as(?i32, 1), globalInt(base, "afterAwait"));
    try expectEval(base, "delete globalThis.afterAwait", "true");
}

/// A module script as the test host keeps one: [[HostDefined]] of its record.
const TestModuleScript = struct { url: []const u8 };

/// The test's host for import() and import.meta.
const ImportHost = struct {
    loads: usize = 0,
    referrer: ?protocol.ImportReferrer = null,
    realm: ?runtime.Context = null,
    specifier_buffer: [64]u8 = undefined,
    specifier_len: usize = 0,
    type_attribute_was_null: bool = true,
    request: ?*protocol.ImportRequest = null,

    fn load(host: ?*anyopaque, r: runtime.Context, referrer: protocol.ImportReferrer, specifier: []const u8, type_attribute: ?[]const u8, request: *protocol.ImportRequest) void {
        const self: *ImportHost = @ptrCast(@alignCast(host.?));
        self.loads += 1;
        self.referrer = referrer;
        self.realm = r;
        self.specifier_len = @min(specifier.len, self.specifier_buffer.len);
        @memcpy(self.specifier_buffer[0..self.specifier_len], specifier[0..self.specifier_len]);
        self.type_attribute_was_null = type_attribute == null;
        self.request = request;
    }

    fn metaUrl(_: ?*anyopaque, module_host_defined: *anyopaque) []const u8 {
        const script: *const TestModuleScript = @ptrCast(@alignCast(module_host_defined));
        return script.url;
    }

    fn specifierText(self: *const ImportHost) []const u8 {
        return self.specifier_buffer[0..self.specifier_len];
    }

    fn takeRequest(self: *ImportHost) !*protocol.ImportRequest {
        const request = self.request orelse return error.NoImport;
        self.request = null;
        return request;
    }
};

test "protocol: import() reaches the agent's host with its referrer, and finishes with the namespace" {
    // The agent's realm is registered (AgentRealm.make) after createAgent
    // installed the protocol's import() - and must not replace it
    // (engine.setDynamicImportHandler).
    _ = try realm();
    var host: ImportHost = .{};
    const hooks: protocol.HostHooks = .{ .loadImportedModule = ImportHost.load, .importMetaUrl = ImportHost.metaUrl };
    const agent = try protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &hooks, .host = &host });
    defer protocol.destroyAgent(agent);
    const in_agent = try AgentRealm.make(agent);
    defer in_agent.end();
    const r = in_agent.realm;
    var reports: ProtocolReports = .{};

    // From a classic script: the referrer is the host's script.
    var classic_script: u8 = 0;
    try protocol.runClassicScript(r, .{ .utf8 = "globalThis.done = 0; import('./m.js').then((ns) => { globalThis.done = ns.value; }, () => { globalThis.done = -1; });" }, "https://example.test/s.js", &classic_script, reports.reporter());
    try std.testing.expectEqual(@as(usize, 1), host.loads);
    try std.testing.expectEqual(r, host.realm.?);
    try std.testing.expectEqualStrings("./m.js", host.specifierText());
    try std.testing.expect(host.type_attribute_was_null);
    try std.testing.expect(host.referrer.? == .script);
    try std.testing.expectEqual(@as(*anyopaque, &classic_script), host.referrer.?.script);

    // The host loads the module, and the engine links, evaluates and settles.
    var module_script: TestModuleScript = .{ .url = "https://example.test/m.js" };
    const m = try parsed(try protocol.parseModule(r, "export const value = 7; globalThis.metaUrl = import.meta.url; import('./n.js');", module_script.url, &module_script));
    defer protocol.releaseModuleRecord(m);
    protocol.finishDynamicImport(try host.takeRequest(), .{ .module = m });
    try protocol.performMicrotaskCheckpoint(r.agent.?);
    // (Read through the protocol: globalInt reads the file's own agent.)
    try expectEval(r, "globalThis.done", "7");
    // HostGetImportMetaProperties: the host's module script's URL.
    try expectEval(r, "globalThis.metaUrl", "https://example.test/m.js");
    // From a module: the referrer is the host's module script.
    try std.testing.expectEqual(@as(usize, 2), host.loads);
    try std.testing.expectEqualStrings("./n.js", host.specifierText());
    try std.testing.expect(host.referrer.? == .module);
    try std.testing.expectEqual(@as(*anyopaque, &module_script), host.referrer.?.module);
    protocol.finishDynamicImport(try host.takeRequest(), .{ .failure = .{ .number = 1 } });

    // A failure rejects the import() with the host's reason.
    try protocol.runClassicScript(r, .{ .utf8 = "import('./x.js', { with: { type: 'json' } }).catch((e) => { globalThis.failed = e; });" }, "https://example.test/s.js", &classic_script, reports.reporter());
    try std.testing.expect(!host.type_attribute_was_null);
    protocol.finishDynamicImport(try host.takeRequest(), .{ .failure = .{ .number = 5 } });
    try protocol.performMicrotaskCheckpoint(r.agent.?);
    try expectEval(r, "globalThis.failed", "5");

    // An event handler's function has no [[ScriptOrModule]]: the referrer is
    // the realm.
    var source: protocol.EventHandlerSource = .{
        .body = "return import('./h.js');",
        .name = "onclick",
        .url = "https://example.test/doc.html",
        .lineno = 1,
        .parameters = .event,
        .document = null,
        .form_owner = null,
        .element = null,
    };
    const handler = (try protocol.compileEventHandler(r, &source, reports.reporter())) orelse return error.NoFunction;
    defer handler.release();
    // (Through the protocol: setGlobal writes in the file's own agent.)
    const global = try evalOwned(r, "globalThis");
    defer global.release();
    try protocol.setProperty(r, global.value, "handler", handler.value);
    try protocol.runClassicScript(r, .{ .utf8 = "handler().catch(() => {});" }, "", null, reports.reporter());
    try std.testing.expect(host.referrer.? == .realm);
    protocol.finishDynamicImport(try host.takeRequest(), .{ .failure = .{ .number = 2 } });
    try protocol.performMicrotaskCheckpoint(r.agent.?);
    try std.testing.expectEqual(@as(usize, 0), reports.count);
}

// ----------------------------------------------------------------------------
// The legacy import() bridge (TODO(protocol): removed when Browser creates its
// agent with engine.createAgent - navigation lane resume)
// ----------------------------------------------------------------------------

/// An import() as engine.zig's legacy handler takes one - a Global<Context>
/// and a Global<Promise::Resolver> it owns - adopted as the protocol's request
/// and finished; the promise's state and result afterwards.
const LegacyImport = struct {
    state: c_int,
    /// The result's `default`, when it is a namespace; else the number.
    value: ?i32,

    fn run(r: runtime.Context, outcome: protocol.DynamicImportOutcome) !LegacyImport {
        const context = ffi.v8_Isolate_GetCurrentContext(isolate_once.?) orelse return error.NoContext;
        const resolver = ffi.v8_PromiseResolver_New(context) orelse return error.NoResolver;
        const promise = ffi.v8_PromiseResolver_GetPromise(resolver) orelse return error.NoPromise;
        defer ffi.v8_Promise_Dispose(promise);
        // The request owns the pair from here; finishing it releases both.
        const request = try v8.protocol_modules.adoptLegacyImport(@ptrCast(context), @ptrCast(resolver), r);
        protocol.finishDynamicImport(request, outcome);
        ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate_once.?);

        const state = ffi.v8_Promise_State(promise);
        const result = ffi.v8_Promise_Result(promise) orelse return .{ .state = state, .value = null };
        defer ffi.v8_Value_Dispose(result);
        const as_value: runtime.JSValue = .{ .handle = .{ .ptr = @ptrCast(result), .needs_disposal = false } };
        if (protocol.typeOf(r, as_value) == .object) {
            const default = try protocol.getProperty(r, as_value, "default");
            defer default.release();
            return .{ .state = state, .value = @intFromFloat(try protocol.convertToUnrestrictedDouble(r, default.value)) };
        }
        return .{ .state = state, .value = @intFromFloat(try protocol.convertToUnrestrictedDouble(r, as_value)) };
    }
};

test "legacy bridge: an import() the legacy handler took is finished through the protocol, and its handles go with it" {
    const base = try realm();
    const record = try parsed(try protocol.parseModule(base, "export default 7;", "https://example.test/legacy.js", null));
    defer protocol.releaseModuleRecord(record);
    try std.testing.expect(try protocol.linkModule(base, record, Graph.none, null) == null);

    // FinishLoadingImportedModule with the module: ContinueDynamicImport
    // resolves with its namespace once evaluation settles.
    const fulfilled = try LegacyImport.run(base, .{ .module = record });
    try std.testing.expectEqual(@as(c_int, 1), fulfilled.state);
    try std.testing.expectEqual(@as(?i32, 7), fulfilled.value);

    // With a failure: rejected with that very value.
    const rejected = try LegacyImport.run(base, .{ .failure = runtime.JSValue.fromNumber(3) });
    try std.testing.expectEqual(@as(c_int, 2), rejected.state);
    try std.testing.expectEqual(@as(?i32, 3), rejected.value);

    // The adopted Global pair is released when the request finishes: the
    // live global-handle bytes stay flat over many imports.
    const round = struct {
        fn run(r: runtime.Context, m: *protocol.ModuleRecord) !void {
            _ = try LegacyImport.run(r, .{ .module = m });
            _ = try LegacyImport.run(r, .{ .failure = runtime.JSValue.fromNumber(1) });
        }
    }.run;
    try round(base, record);
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate_once.?);
    for (0..32) |_| try round(base, record);
    try std.testing.expect(ffi.v8_Isolate_GetGlobalHandleBytes(isolate_once.?) <= before + 64);
}

/// A module script as a legacy import.meta callback's host finds it.
const MetaScript = struct { url: []const u8 };

/// V8's import.meta callback, as script_execution's shim installs it: the
/// module's record found by the module, its host_defined the host's script.
fn legacyImportMetaUrl(identity_hash: c_int, module: *ffi.Module, len: *usize) callconv(.c) ?[*]const u8 {
    const host_defined = v8.protocol_modules.hostDefinedOf(module, identity_hash) orelse return null;
    const script: *const MetaScript = @ptrCast(@alignCast(host_defined));
    len.* = script.url.len;
    return script.url.ptr;
}

test "legacy bridge: import.meta finds the host's module script through the record's host_defined" {
    const base = try realm();
    ffi.v8_Isolate_SetImportMetaUrlCallback(isolate_once.?, &legacyImportMetaUrl);
    var script: MetaScript = .{ .url = "https://example.test/dir/meta.js" };
    const record = try parsed(try protocol.parseModule(base, "globalThis.metaUrl = import.meta.url;", "https://example.test/dir/meta.js", &script));
    defer protocol.releaseModuleRecord(record);
    try std.testing.expect(try protocol.linkModule(base, record, Graph.none, null) == null);
    const scope = try protocol.prepareToRunScript(base);
    const evaluation = try protocol.evaluateModule(base, record);
    protocol.cleanUpAfterRunningScript(scope);
    try std.testing.expect(evaluation == .completed);
    try expectEval(base, "globalThis.metaUrl", "https://example.test/dir/meta.js");
    try expectEval(base, "delete globalThis.metaUrl", "true");
}
