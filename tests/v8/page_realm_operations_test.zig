//! Page-realm operations as V8 implements them
//! (src/runtime/engines/v8/page_realm.zig): invokeCallbackFunction and
//! installWindowOperations - and, from "protocol:" on, the engine protocol's
//! operations bound to V8.
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
/// makes a `.handle` - borrowed for the call - over the same Global.
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
            protocol.runClassicScript(realm_once.?, .{ .utf8 = source }, "", null, ignored.reporter()) catch {};
        }
    }

    /// The protocol's reporter, into `report`.
    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = fromProtocol, .host = self };
    }

    fn fromProtocol(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const converted: runtime.ErrorInfo = .{
            .message = info.message,
            .filename = info.filename,
            .lineno = info.lineno,
            .colno = info.colno,
            .error_value = if (info.error_value == .undefined) null else info.error_value,
        };
        report(host, &converted);
    }

    fn messageText(self: *const Reports) []const u8 {
        return self.message[0..self.message_len];
    }
};

/// Run `source` as a classic script (the protocol's runClassicScript), what
/// it throws reported into the Reports returned.
fn run(source: []const u8) !Reports {
    var reports: Reports = .{};
    protocol.runClassicScript(try realm(), .{ .utf8 = source }, "", null, reports.reporter()) catch |err| switch (err) {
        error.ExceptionReported => {},
        else => return err,
    };
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
    try v8.page_realm.invokeCallbackFunction(ctx, borrowed(cb), .global_this, &.{ .{ .number = 2 }, .{ .number = 3 } }, Reports.report, &reports);
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
    try v8.page_realm.invokeCallbackFunction(ctx, borrowed(cb), .undefined, &.{}, Reports.report, &reports);
    try std.testing.expectEqual(@as(i32, -1), try scriptInt("globalThis.seenThis"));
    try v8.page_realm.invokeCallbackFunction(ctx, borrowed(cb), .{ .value = .{ .number = 7 } }, &.{}, Reports.report, &reports);
    try std.testing.expectEqual(@as(i32, 7), try scriptInt("globalThis.seenThis"));
}

test "more arguments than fit inline all arrive" {
    const ctx = try realm();
    _ = try run("globalThis.manyCb = function () { globalThis.argCount = arguments.length; globalThis.last = arguments[arguments.length - 1]; };");
    const cb = try scriptValue("globalThis.manyCb");
    defer ffi.v8_Value_Dispose(cb);

    var reports: Reports = .{};
    const args = [_]runtime.JSValue{ .{ .number = 1 }, .{ .number = 2 }, .{ .number = 3 }, .{ .number = 4 }, .{ .number = 5 }, .{ .number = 6 } };
    try v8.page_realm.invokeCallbackFunction(ctx, borrowed(cb), .undefined, &args, Reports.report, &reports);
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
    try v8.page_realm.invokeCallbackFunction(ctx, borrowed(cb), .undefined, &.{}, Reports.report, &reports);
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
    try v8.page_realm.invokeCallbackFunction(ctx, borrowed(object), .undefined, &.{}, Reports.report, &reports);
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    // A value that is no engine handle at all is a caller's mistake.
    try std.testing.expectError(error.TypeError, v8.page_realm.invokeCallbackFunction(ctx, .{ .number = 1 }, .undefined, &.{}, Reports.report, &reports));
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
            v8.engine.v8ReleaseValue(h);
        },
        .string => |h| {
            const string: *ffi.String = @ptrCast(@alignCast(h.handle.ptr));
            const len: usize = @intCast(ffi.v8_String_Utf8Length(string));
            seen.string_len = @min(len, seen.string_source.len);
            _ = ffi.v8_String_WriteUtf8(string, &seen.string_source, @intCast(seen.string_len));
            v8.engine.v8ReleaseValue(h);
        },
    }
    // Every argument is the host's to release.
    for (arguments) |argument| v8.engine.v8ReleaseValue(argument);
    return 41 + @as(i32, @intCast(seen.timers));
}

fn testClearTimer(r: runtime.Context, id: i32) void {
    seen.realm = r;
    seen.cleared = id;
}

fn testRequestAnimationFrame(r: runtime.Context, callback: runtime.JSValue) u32 {
    seen.realm = r;
    seen.frames += 1;
    v8.engine.v8ReleaseValue(callback);
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
    try v8.page_realm.installWindowOperations(ctx, &test_operations);
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

/// A CustomEvent in the realm as `ce`: `initCustomEvent`'s `detail` and
/// `CustomEventInit.detail` are `any`, and the event keeps a hold of its own
/// on whatever it is given (CustomEvent.setDetail), so anything left over
/// after a call is the binding's.
fn customEventInRealm() !void {
    try eventInRealm();
    const context = context_once.?;
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    v8.interface_bindings.CustomEvent.registerGlobalFast(isolate_once.?, context, global, "CustomEvent");
    const reports = try run("globalThis.ce = new CustomEvent('x');");
    try std.testing.expectEqual(@as(usize, 0), reports.count);
}

/// The primitives an `any` converts to a Zig value of its own: a string (an
/// owned copy), a number, a boolean, null and undefined.
const primitive_details = "['Test cleanup', 'Test cleanup ' + i, i, i % 2 == 0, null, undefined][i % 6]";

test "an `any` argument that converts to a primitive leaves no handle behind" {
    try customEventInRealm();
    const isolate = isolate_once.?;

    // The control: the same values stored as an expando - no conversion.
    var start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    _ = try run("for (let i = 0; i < 64; i++) ce.expando = " ++ primitive_details ++ ";");
    const control = ffi.v8_Isolate_GetGlobalHandleBytes(isolate) -| start;

    // testharness.js calls abortController.abort("Test cleanup") once per
    // subtest: an `any` string, one argument handle kept per call.
    start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const reports = try run("for (let i = 0; i < 64; i++) ce.initCustomEvent('x', false, false, " ++ primitive_details ++ ");");
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    const calls = ffi.v8_Isolate_GetGlobalHandleBytes(isolate) -| start;
    if (calls > control) {
        std.debug.print("64 initCustomEvent calls with a primitive detail: {d} bytes of global handles left, against {d} for 64 expando stores\n", .{ calls, control });
        return error.HandlesLeaked;
    }
}

test "an `any` argument that is an object is released once the call returns" {
    try customEventInRealm();
    const isolate = isolate_once.?;

    // The control: the same objects stored as an expando - no conversion.
    var start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    _ = try run("globalThis.details = []; for (let i = 0; i < 64; i++) details.push({ i }); for (let i = 0; i < 64; i++) ce.expando = details[i];");
    const control = ffi.v8_Isolate_GetGlobalHandleBytes(isolate) -| start;

    // The event takes a hold of its own on each detail and lets go of the
    // one before (CustomEvent.setDetail), so a call leaves nothing of its
    // own behind but the argument's handle - until the binding releases it.
    start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const reports = try run("for (let i = 0; i < 64; i++) ce.initCustomEvent('x', false, false, details[i]);");
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    const calls = ffi.v8_Isolate_GetGlobalHandleBytes(isolate) -| start;
    const detail_kept = try run("if (ce.detail !== details[63]) throw new Error('the event lost its detail');");
    try std.testing.expectEqual(@as(usize, 0), detail_kept.count);
    _ = try run("delete globalThis.details;");
    // What one handle costs in V8's count: the event's hold on its last
    // detail is the one handle the calls may leave.
    const one_handle = blk: {
        const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        const one = ffi.v8_Number_New(isolate, 1);
        const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        ffi.v8_Value_Dispose(@ptrCast(one));
        break :blk with_one - before;
    };
    if (calls > control + one_handle) {
        std.debug.print("64 initCustomEvent calls with an object detail: {d} bytes of global handles left, against {d} for 64 expando stores (+{d} for the event's own hold)\n", .{ calls, control, one_handle });
        return error.HandlesLeaked;
    }
}

test "an `any` dictionary member that converts to a primitive leaves no handle behind" {
    try customEventInRealm();
    const isolate = isolate_once.?;

    // The control: 64 Events, whose EventInit has boolean members only - each
    // converted and its handle released. Every event is wrapped (a weak
    // Global per event either way), so what a CustomEvent loop leaves beyond
    // this is its `detail` member: absent (undefined) or a primitive the
    // event holds by value (retainValue keeps a number, a boolean or null
    // without a Global).
    var start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    _ = try run("globalThis.kept = []; for (let i = 0; i < 64; i++) kept.push(new Event('x', {}));");
    const control = ffi.v8_Isolate_GetGlobalHandleBytes(isolate) -| start;

    start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    var reports = try run("globalThis.kept2 = []; for (let i = 0; i < 64; i++) kept2.push(new CustomEvent('x', {}));");
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    const absent = ffi.v8_Isolate_GetGlobalHandleBytes(isolate) -| start;

    start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    reports = try run("globalThis.kept3 = []; for (let i = 0; i < 64; i++) kept3.push(new CustomEvent('x', { detail: [i, i % 2 == 0, null, 0.5][i % 4] }));");
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    const primitive = ffi.v8_Isolate_GetGlobalHandleBytes(isolate) -| start;
    _ = try run("delete globalThis.kept; delete globalThis.kept2; delete globalThis.kept3;");
    if (absent > control or primitive > control) {
        std.debug.print("64 CustomEvents: {d} bytes of global handles left with no detail, {d} with a primitive detail, against {d} for 64 Events\n", .{ absent, primitive, control });
        return error.HandlesLeaked;
    }
}

test "converting a sequence leaves no handle of its own behind" {
    _ = try realm();
    const isolate = isolate_once.?;
    const context = context_once.?;
    const array = try scriptValue("['a', 'bb', 'ccc', 'dddd', 1, true, null, 'eeeee']");
    defer ffi.v8_Value_Dispose(array);

    // sequence<DOMString>: every element copied out.
    var start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    for (0..32) |_| {
        const strings = try v8.conversions.fromV8Value([]const runtime.DOMString, std.testing.allocator, isolate, context, array);
        for (strings) |s| switch (s) {
            .owned => |bytes| std.testing.allocator.free(bytes),
            else => {},
        };
        std.testing.allocator.free(strings);
    }
    const strings_left = ffi.v8_Isolate_GetGlobalHandleBytes(isolate) -| start;

    // sequence<any> of primitives: each converts to a value of its own.
    start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    for (0..32) |_| {
        const values = try v8.conversions.fromV8Value([]const runtime.JSValue, std.testing.allocator, isolate, context, array);
        for (values) |value| switch (value) {
            .string => |s| if (s.owned) std.testing.allocator.free(s.data),
            else => {},
        };
        std.testing.allocator.free(values);
    }
    const anys_left = ffi.v8_Isolate_GetGlobalHandleBytes(isolate) -| start;

    if (strings_left > 0 or anys_left > 0) {
        std.debug.print("32 conversions of an 8-element array: {d} bytes of global handles left as sequence<DOMString>, {d} as sequence<any>\n", .{ strings_left, anys_left });
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
    defer protocol.destroyWindowRealm(w, .global_detached);

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

test "protocol: a Window's indexed property enumerator leaves no handle behind" {
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);
    const isolate = isolate_once.?;

    // The control: the same enumeration of an ordinary object, no interceptor.
    var start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    try expectEval(w, "let n = 0; for (let i = 0; i < 32; i++) n += Object.getOwnPropertyNames({ a: 1 }).length; n > 0", "true");
    const control = ffi.v8_Isolate_GetGlobalHandleBytes(isolate) -| start;

    // Enumerating the Window's own keys runs its indexed property enumerator
    // (the child navigables, none here), which kept the context Global it
    // asked for and the array it returned: two handles a call.
    start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    try expectEval(w, "let m = 0; for (let i = 0; i < 32; i++) m += Object.getOwnPropertyNames(globalThis).length; m > 0", "true");
    const enumerated = ffi.v8_Isolate_GetGlobalHandleBytes(isolate) -| start;
    if (enumerated > control) {
        std.debug.print("32 enumerations of a Window's own keys: {d} bytes of global handles left, against {d} for an ordinary object\n", .{ enumerated, control });
        return error.HandlesLeaked;
    }
}

test "protocol: a realm restored from a snapshot the agent lacks is built afresh" {
    // The no-snapshot startup path: an agent made without a snapshot (as on
    // JavaScriptCore, always) still gets a working Window realm.
    var host: WindowHost = .{};
    const w = try windowRealm(&host, true, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);
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
    defer protocol.destroyWindowRealm(b, .global_detached);
    // The old realm ends first, as a navigation's does.
    protocol.destroyWindowRealm(a, .global_detached);
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
    protocol.destroyWindowRealm(w, .global_detached);
    // Retired: the realm can be compared, never entered.
    try std.testing.expect(w.engine_ctx == null);
    const after = liveContexts();
    if (after != baseline) {
        std.debug.print("native contexts: {d} before, {d} after the Window realm ended\n", .{ baseline, after });
        return error.RealmKeptAlive;
    }
}

test "protocol: iterating a platform object from another realm leaves no Global<Context> and no extra native context" {
    // A page reading its frame's objects: html5lib_write.html walks each
    // frame's childNodes with for...of from the parent. The iterable callbacks
    // run in the callee's realm - the frame's - and every one of them took
    // that realm's Global<Context> and kept it, with a fresh iterator
    // prototype (and its functions) a call, so every frame the page ever
    // iterated stayed alive: 898 realms, 1.17 GB, for that one file.
    _ = try realm();
    const isolate = isolate_once.?;
    const baseline = liveContexts();

    var page_host: WindowHost = .{};
    const page = try windowRealm(&page_host, false, .new_window_proxy);
    var frame_host: WindowHost = .{};
    const frame = try windowRealm(&frame_host, false, .new_window_proxy);

    // A pair iterable of the frame's, handed to the page.
    const params = try evalOwned(frame, "new URLSearchParams('a=1&b=2&c=3')");
    try setGlobal(page, "fromFrame", params.value);
    params.release();

    // Every iteration method, and next() by hand, from the page.
    const iterate =
        \\(() => {
        \\  let n = 0;
        \\  for (const [k, v] of fromFrame) n++;
        \\  for (const k of fromFrame.keys()) n++;
        \\  for (const v of fromFrame.values()) n++;
        \\  for (const e of fromFrame.entries()) n++;
        \\  fromFrame.forEach(() => n++);
        \\  const it = fromFrame[Symbol.iterator]();
        \\  while (!it.next().done) n++;
        \\  return n;
        \\})()
    ;
    // The first round makes what every later one reuses. Each round's count
    // is checked at the end, after the handle and realm counts are taken.
    var counts_right = true;
    {
        const first = try evalString(page, iterate);
        defer std.testing.allocator.free(first);
        if (!std.mem.eql(u8, first, "18")) {
            std.debug.print("a round of iteration counted {s}, not 18\n", .{first});
            counts_right = false;
        }
    }

    const handle_bytes = blk: {
        const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        const one = ffi.v8_Number_New(isolate, 1);
        const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        ffi.v8_Value_Dispose(@ptrCast(one));
        break :blk with_one - start;
    };
    const rounds = 16;
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    for (0..rounds) |_| {
        const count = try evalString(page, iterate);
        defer std.testing.allocator.free(count);
        if (!std.mem.eql(u8, count, "18")) counts_right = false;
    }
    const after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    // Before the fix: tens of handles a round (13 Global<Context> a cycle in
    // gc_bench's NodeList loop alone).
    const leaked = after -| before >= handle_bytes * rounds / 4;
    if (leaked) std.debug.print("global handles {d} -> {d} bytes over {d} rounds of iteration ({d} bytes a handle)\n", .{ before, after, rounds, handle_bytes });

    // WebIDL 3.7.10: one iterator prototype per interface per realm, with no
    // constructor, tagged "<Interface> Iterator".
    const shape = try evalString(page,
        \\[Object.getPrototypeOf(fromFrame.keys()) === Object.getPrototypeOf(fromFrame.entries()),
        \\ Object.prototype.hasOwnProperty.call(Object.getPrototypeOf(fromFrame.keys()), 'constructor'),
        \\ Object.prototype.toString.call(fromFrame.keys())].join()
    );
    defer std.testing.allocator.free(shape);

    // The page lets go of the frame's object, the frame ends, then the page.
    try expectEval(page, "delete globalThis.fromFrame", "true");
    protocol.destroyWindowRealm(frame, .global_detached);
    protocol.destroyWindowRealm(page, .global_detached);
    const contexts_after = liveContexts();
    if (contexts_after != baseline) std.debug.print("native contexts: {d} before, {d} after both realms ended\n", .{ baseline, contexts_after });

    try std.testing.expect(counts_right);
    try std.testing.expectEqualStrings("true,false,[object URLSearchParams Iterator]", shape);
    if (leaked) return error.HandlesLeaked;
    if (contexts_after != baseline) return error.RealmKeptAlive;
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
    protocol.destroyWindowRealm(try windowRealm(&host, false, .new_window_proxy), .global_detached);
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    // The global the host was lent is the Window's wrapper-cache entry's,
    // released at the realm's end with everything else it held.
    const rounds = 3;
    for (0..rounds) |_| protocol.destroyWindowRealm(try windowRealm(&host, false, .new_window_proxy), .global_detached);
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
    defer protocol.destroyWindowRealm(parent, .global_detached);
    var frame_realm: FrameRealm = .{ .parent = parent };
    const frame = try frame_realm.make();
    defer protocol.destroyWindowRealm(frame, .global_detached);

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
    defer protocol.destroyWindowRealm(parent, .global_detached);
    var frame_realm: FrameRealm = .{ .parent = parent };
    const frame = try frame_realm.make();
    defer protocol.destroyWindowRealm(frame, .global_detached);

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

    protocol.destroyWindowRealm(parent, .global_detached);
    // Retired, every one: each may only be compared now.
    try std.testing.expect(nested.engine_ctx == null);
    try std.testing.expect(frame.engine_ctx == null);
    try std.testing.expect(parent.engine_ctx == null);
}

test "protocol: a frame's realm whose WindowProxy went on lives while script reaches it, and is severed from its Window at its end" {
    const base = try realm();
    var host: WindowHost = .{};
    const parent = try windowRealm(&host, false, .new_window_proxy);
    var old_realm: FrameRealm = .{ .parent = parent };
    const old = try old_realm.make();
    const old_window = Watched.of(try platformObjectIn(old, "globalThis"));
    // A function of the old realm that reads its Window through its global,
    // held by script elsewhere.
    {
        const reader = try evalOwned(old, "(function () { return typeof name; })");
        defer reader.release();
        try setGlobal(base, "reader", reader.value);
    }

    // The navigation's new Window, behind the same WindowProxy. HTML unloads
    // and destroys the old document; the old Window lives on for as long as
    // script reaches anything of its realm - here, the reader.
    var new_realm: FrameRealm = .{ .parent = parent, .global_this = .{ .window_proxy_of = old } };
    const new = try new_realm.make();
    protocol.destroyWindowRealm(old, .global_detached);
    collectTwice();
    try std.testing.expect(old.engine_ctx != null);
    try std.testing.expect(old_window.alive());
    try expectEval(base, "reader()", "string");
    // Its tasks are not run (HTML "destroy a document" step 7).
    const Steps = struct {
        fn steps(_: ?*anyopaque) void {}
    };
    try std.testing.expectError(error.OperationFailed, protocol.runTaskInRealm(old, Steps.steps, null));

    // Its page ends: the old realm ends with it, and its global no longer
    // names the freed Window - reading a Window member through it is a
    // TypeError, not a read of freed memory.
    protocol.destroyWindowRealm(new, .global_detached);
    protocol.destroyWindowRealm(parent, .global_detached);
    try std.testing.expect(old.engine_ctx == null);
    try std.testing.expect(old.getV8WrapperCacheStorage() == null);
    try expectEval(base, "(() => { try { reader(); return 'read'; } catch (e) { return e.name; } })()", "TypeError");
    try expectEval(base, "delete globalThis.reader", "true");
}

test "protocol: a frame's realm a navigation replaced is collected once nothing reaches it" {
    _ = try realm();
    var host: WindowHost = .{};
    const parent = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(parent, .global_detached);
    var old_realm: FrameRealm = .{ .parent = parent };
    const old = try old_realm.make();
    // What the old realm's script leaves behind: objects on its global, a
    // listener whose closure reaches the realm, and an object with pending
    // activity - a wrapper the cache holds strongly.
    try expectEval(old, "globalThis.kept = new Headers([['a', '1']]); globalThis.target = new EventTarget(); target.addEventListener('x', () => kept); 'ok'", "ok");
    const busy = try platformObjectIn(old, "globalThis.busy = new Headers()");
    protocol.keepPlatformObjectAlive(busy);

    var new_realm: FrameRealm = .{ .parent = parent, .global_this = .{ .window_proxy_of = old } };
    const new = try new_realm.make();
    defer protocol.destroyWindowRealm(new, .global_detached);
    // What lives with both realms - and what the new realm's own wrappers
    // add - before the old one is let go.
    try expectEval(new, "globalThis.fresh = new Headers(); 'ok'", "ok");
    const with_both = liveContexts();

    // The old realm is the engine's to end now: nothing Crane holds is a root
    // into it - not its wrappers, its listener, its pending activity, and
    // none of them hung on the NEW realm's global through the shared proxy.
    protocol.destroyWindowRealm(old, .global_detached);
    const after = liveContexts();
    if (after + 1 != with_both) {
        std.debug.print("native contexts: {d} with both realms, {d} after the replaced one was let go\n", .{ with_both, after });
        return error.RealmKeptAlive;
    }
    try std.testing.expect(old.engine_ctx == null);
    // The new realm is untouched.
    try expectEval(new, "fresh instanceof Headers && globalThis.kept === undefined", "true");
}

test "protocol: a destroyed navigable's realm keeps its Window while script holds its WindowProxy, and ends when it is collected" {
    _ = try realm();
    var host: WindowHost = .{};
    const parent = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(parent, .global_detached);
    const baseline = liveContexts();
    var frame_realm: FrameRealm = .{ .parent = parent };
    const frame = try frame_realm.make();
    const window = Watched.of(try platformObjectIn(frame, "globalThis"));
    {
        const frame_global = try evalOwned(frame, "globalThis.kept = new Headers([['a', '1']]); globalThis");
        defer frame_global.release();
        try setGlobal(parent, "frameWindow", frame_global.value);
    }

    // HTML "destroy a child navigable" (an iframe removed): Blink's
    // DisposeContext(kFrameIsDetached) leaves the global attached, and the
    // Window lives on with its WindowProxy.
    protocol.destroyWindowRealm(frame, .navigable_destroyed);
    collectTwice();
    try std.testing.expect(frame.engine_ctx != null);
    try std.testing.expect(window.alive());

    // Its self-references, and every member that needs the Window: the
    // Window is the one it was, with what its realm's script kept on it.
    try expectEval(parent, "[frameWindow.self, frameWindow.frames, frameWindow.globalThis, frameWindow.window].every(w => w === frameWindow)", "true");
    try expectEval(parent, "typeof frameWindow.name", "string");
    try expectEval(parent, "frameWindow.kept.get('a')", "1");

    // Crane holds nothing of the frame's context: once script lets its
    // WindowProxy go, the collector takes the context, and the realm reads
    // ended from then on.
    try expectEval(parent, "delete globalThis.frameWindow", "true");
    const after = liveContexts();
    if (after != baseline) {
        std.debug.print("native contexts: {d} before the frame, {d} after its navigable was destroyed and its WindowProxy dropped\n", .{ baseline, after });
        return error.RealmKeptAlive;
    }
    try std.testing.expect(frame.engine_ctx == null);
    // This test's realms have no event loop to end it from a task: its
    // page's end does, which frees its Window.
}

test "protocol: a listener stored on a destroyed navigable's object, closing over the frame, does not keep it" {
    _ = try realm();
    var host: WindowHost = .{};
    const parent = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(parent, .global_detached);
    const baseline = liveContexts();
    var frame_realm: FrameRealm = .{ .parent = parent };
    const frame = try frame_realm.make();
    {
        const frame_global = try evalOwned(frame, "globalThis.target = new EventTarget(); globalThis");
        defer frame_global.release();
        try setGlobal(parent, "frameWindow", frame_global.value);
    }
    // The parent stores, on the frame's object, callbacks whose closures
    // reach the frame: a listener and an event handler's worth.
    try expectEval(parent, "(() => { const w = frameWindow; w.target.addEventListener('x', () => w.heard = (w.heard || 0) + 1); return 'ok'; })()", "ok");
    try expectEval(parent, "frameWindow.target.dispatchEvent(new frameWindow.Event('x')); frameWindow.heard", "1");

    protocol.destroyWindowRealm(frame, .navigable_destroyed);
    collectTwice();
    // Script that holds the frame still reaches the listener.
    try expectEval(parent, "frameWindow.target.dispatchEvent(new frameWindow.Event('x')); frameWindow.heard", "2");

    // Once script lets the frame go, the listener is no root that keeps it.
    try expectEval(parent, "delete globalThis.frameWindow", "true");
    const after = liveContexts();
    if (after != baseline) {
        std.debug.print("native contexts: {d} before the frame, {d} after it was detached and dropped with a listener closing over it\n", .{ baseline, after });
        return error.RealmKeptAlive;
    }
}

test "protocol: a destroyed navigable's realm that its page outlives is not run, and its page's end frees its Window" {
    var host: WindowHost = .{};
    const parent = try windowRealm(&host, false, .new_window_proxy);
    var frame_realm: FrameRealm = .{ .parent = parent };
    const frame = try frame_realm.make();
    const window = Watched.of(try platformObjectIn(frame, "globalThis"));
    {
        const frame_global = try evalOwned(frame, "globalThis");
        defer frame_global.release();
        try setGlobal(parent, "frameWindow", frame_global.value);
    }
    protocol.destroyWindowRealm(frame, .navigable_destroyed);

    // HTML "destroy a document" step 7: its tasks are not run.
    const Steps = struct {
        var ran = false;
        fn steps(_: ?*anyopaque) void {
            ran = true;
        }
    };
    Steps.ran = false;
    try std.testing.expectError(error.OperationFailed, protocol.runTaskInRealm(frame, Steps.steps, null));
    try std.testing.expect(!Steps.ran);

    // The page ends while script still holds the frame's WindowProxy: the
    // frame's realm ends with it - retired, its wrapper cache gone.
    try std.testing.expect(window.alive());
    protocol.destroyWindowRealm(parent, .global_detached);
    try std.testing.expect(frame.engine_ctx == null);
    try std.testing.expect(frame.getV8WrapperCacheStorage() == null);
}

test "protocol: a wrapper another realm still holds is severed when its realm ends" {
    var host: WindowHost = .{};
    const parent = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(parent, .global_detached);
    var frame_realm: FrameRealm = .{ .parent = parent };
    const frame = try frame_realm.make();
    {
        const held = try evalOwned(frame, "new Headers([['a', '1']])");
        defer held.release();
        try setGlobal(parent, "heldHeaders", held.value);
    }
    try expectEval(parent, "heldHeaders.get('a')", "1");

    // The frame's realm ends (a navigation's end): its wrapper cache frees
    // the Headers, and the parent still holds the wrapper. Reading through it
    // is a TypeError - the wrapper names no instance any more - never a read
    // of the freed one (Headers.call_get unwraps its `_internal` unchecked: a
    // panic, or worse once the slot is reissued).
    protocol.destroyWindowRealm(frame, .global_detached);
    try expectEval(parent, "(() => { try { return String(heldHeaders.get('a')); } catch (e) { return e.name; } })()", "TypeError");
    try expectEval(parent, "delete globalThis.heldHeaders", "true");
}

test "protocol: a namespace operation keeps neither its realm nor its result" {
    _ = try realm();
    // The first realm to call a namespace operation that takes a
    // runtime.Context becomes the process-wide one (namespace.zig's
    // global_context), kept for the process: one page, made here so that
    // the realm under test is not it.
    {
        var first_host: WindowHost = .{};
        const first = try windowRealm(&first_host, false, .new_window_proxy);
        try expectEval(first, "typeof TestUtils.gc()", "object");
        protocol.destroyWindowRealm(first, .global_detached);
    }
    const baseline = liveContexts();
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    // The result - a promise of `w` - and the current context the binding
    // took for the call are each a Global into `w`: kept, either one keeps
    // the page (every page that called TestUtils.gc() stayed for the
    // process: crane/rl-frame-churn-dropped.html, +1 native context a page).
    try expectEval(w, "for (let i = 0; i < 4; i++) TestUtils.gc(); typeof TestUtils.gc()", "object");
    protocol.destroyWindowRealm(w, .global_detached);
    const after = liveContexts();
    if (after != baseline) {
        std.debug.print("native contexts: {d} before the realm, {d} after it called TestUtils.gc() and ended\n", .{ baseline, after });
        return error.RealmKeptAlive;
    }
}

// ============================================================================
// traceChild / forgetTracedChild: an owner keeps a child for as long as the
// owner's wrapper lives - the edge Blink draws by tracing a Member<> field
// (tmp/plans/frame-realm-tracing-design.md, step 1)
// ============================================================================

/// The platform object `expression` evaluates to in `r`, made the way script
/// makes one. The handle script handed back is released here, so only what
/// `r` keeps of the object - a global property, an edge - keeps it alive.
fn platformObjectIn(r: runtime.Context, expression: []const u8) !*runtime.Instance {
    const made = try evalOwned(r, expression);
    defer made.release();
    return protocol.convertToPlatformObject(r, made.value) orelse error.NotAPlatformObject;
}

/// An instance, and whether it is still the object it was when watched: the
/// slab stamps a slot's generation on every alloc and reads it dead after a
/// free, so a freed - or freed and reissued - slot answers false. Never
/// dereferences the instance.
const Watched = struct {
    instance: *runtime.Instance,
    generation: u64,

    fn of(instance: *runtime.Instance) Watched {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    fn alive(self: Watched) bool {
        return runtime.SlabAllocator.generationOf(self.instance) == self.generation;
    }
};

/// Two full collections, as the Crane tests' collectTwice() runs: a wrapper
/// the first one finds unreachable has its weak callback - which frees its
/// instance - run by then.
fn collectTwice() void {
    ffi.v8_Isolate_RequestGarbageCollection(isolate_once.?);
    ffi.v8_Isolate_RequestGarbageCollection(isolate_once.?);
}

test "protocol: a traced child lives as long as its owner's wrapper, and goes with it" {
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);

    // Script keeps the owner, and nothing of either child.
    const owner = Watched.of(try platformObjectIn(w, "globalThis.owner = new Headers()"));
    const traced = Watched.of(try platformObjectIn(w, "new Headers([['traced', '1']])"));
    const untraced = Watched.of(try platformObjectIn(w, "new Headers([['untraced', '1']])"));
    protocol.traceChild(owner.instance, traced.instance, .{ .name = "child" });

    collectTwice();
    // The collections were real: what nothing kept is gone.
    try std.testing.expect(!untraced.alive());
    try std.testing.expect(owner.alive());
    try std.testing.expect(traced.alive());
    try std.testing.expect(protocol.hasWrapper(traced.instance));

    // Script lets the owner go, and the child goes with it: an edge, not a root.
    try expectEval(w, "delete globalThis.owner", "true");
    collectTwice();
    try std.testing.expect(!owner.alive());
    try std.testing.expect(!traced.alive());
}

test "protocol: a slot holds one child; forgetTracedChild lets it go and leaves the other slots" {
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);

    const owner = Watched.of(try platformObjectIn(w, "globalThis.owner = new Headers()"));
    const first = Watched.of(try platformObjectIn(w, "new Headers()"));
    const second = Watched.of(try platformObjectIn(w, "new Headers()"));
    const other = Watched.of(try platformObjectIn(w, "new Headers()"));
    protocol.traceChild(owner.instance, first.instance, .{ .name = "child" });
    protocol.traceChild(owner.instance, other.instance, .{ .name = "other" });
    // Tracing again into the same slot replaces the edge (Selection's range,
    // set anew by addRange after removeAllRanges).
    protocol.traceChild(owner.instance, second.instance, .{ .name = "child" });
    collectTwice();
    try std.testing.expect(!first.alive());
    try std.testing.expect(second.alive());
    try std.testing.expect(other.alive());

    protocol.forgetTracedChild(owner.instance, .{ .name = "child" });
    // Forgetting an empty slot, or one never traced, is a no-op.
    protocol.forgetTracedChild(owner.instance, .{ .name = "child" });
    protocol.forgetTracedChild(owner.instance, .{ .name = "never" });
    collectTwice();
    try std.testing.expect(!second.alive());
    try std.testing.expect(other.alive());
    try std.testing.expect(owner.alive());
    try expectEval(w, "delete globalThis.owner", "true");
}

test "protocol: an owner and a child that trace each other keep each other, and go together" {
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);

    // A shadow root and its host: either keeps the other while script holds
    // it - here script holds only the child.
    const owner = Watched.of(try platformObjectIn(w, "new Headers()"));
    const child = Watched.of(try platformObjectIn(w, "globalThis.child = new Headers()"));
    protocol.traceChild(owner.instance, child.instance, .{ .name = "child" });
    protocol.traceChild(child.instance, owner.instance, .{ .name = "owner" });
    collectTwice();
    try std.testing.expect(owner.alive());
    try std.testing.expect(child.alive());

    // Neither held: the cycle is the collector's, so both go.
    try expectEval(w, "delete globalThis.child", "true");
    collectTwice();
    try std.testing.expect(!owner.alive());
    try std.testing.expect(!child.alive());
}

test "protocol: a child traced from a Window lives as long as its realm" {
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);

    // A Window's wrapper is its global object: it lives with the realm.
    const window = try platformObjectIn(w, "globalThis");
    const child = Watched.of(try platformObjectIn(w, "new Headers()"));
    protocol.traceChild(window, child.instance, .{ .name = "child" });
    collectTwice();
    try std.testing.expect(child.alive());
}

test "protocol: a Window whose WindowProxy went on to a new realm traces from its own global object" {
    var host: WindowHost = .{};
    const parent = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(parent, .global_detached);
    var old_realm: FrameRealm = .{ .parent = parent };
    const old = try old_realm.make();
    const old_window = try platformObjectIn(old, "globalThis");

    // A navigation: the new Window behind the same WindowProxy. The old realm
    // lives on (a retired realm, until its page ends), and script that still
    // runs in it can make its Window draw an edge.
    var new_realm: FrameRealm = .{ .parent = parent, .global_this = .{ .window_proxy_of = old } };
    const new = try new_realm.make();
    // The old realm ends first, as a navigation's page would end it.
    defer protocol.destroyWindowRealm(new, .global_detached);
    defer protocol.destroyWindowRealm(old, .global_detached);
    const new_window = try platformObjectIn(new, "globalThis");
    try std.testing.expect(new_window != old_window);

    // The same slot, one child each. Drawn through the shared WindowProxy,
    // the old Window's edge would land on the NEW global object and replace
    // the new Window's: its child freed under it.
    const for_new = Watched.of(try platformObjectIn(new, "new Headers()"));
    protocol.traceChild(new_window, for_new.instance, .{ .name = "child" });
    const for_old = Watched.of(try platformObjectIn(old, "new Headers()"));
    protocol.traceChild(old_window, for_old.instance, .{ .name = "child" });
    collectTwice();
    try std.testing.expect(for_new.alive());
    try std.testing.expect(for_old.alive());
}

test "protocol: traceChild and forgetTracedChild leave no global handle behind" {
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);
    const isolate = isolate_once.?;
    const handle_bytes = blk: {
        const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        const one = ffi.v8_Number_New(isolate, 1);
        const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        ffi.v8_Value_Dispose(@ptrCast(one));
        break :blk with_one - start;
    };
    const window = try platformObjectIn(w, "globalThis");
    const owner = try platformObjectIn(w, "globalThis.owner = new Headers()");
    const child = try platformObjectIn(w, "globalThis.child = new Headers()");
    // The first round makes what every later one reuses.
    protocol.traceChild(owner, child, .{ .name = "child" });
    protocol.traceChild(window, child, .{ .name = "child" });
    collectTwice();
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const rounds = 32;
    for (0..rounds) |_| {
        protocol.traceChild(owner, child, .{ .name = "child" });
        protocol.traceChild(window, child, .{ .name = "child" });
        protocol.forgetTracedChild(owner, .{ .name = "child" });
        protocol.forgetTracedChild(window, .{ .name = "child" });
    }
    collectTwice();
    const after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    if (after -| before >= handle_bytes) {
        std.debug.print("global handles {d} -> {d} bytes over {d} rounds ({d} bytes a handle)\n", .{ before, after, rounds, handle_bytes });
        return error.HandlesLeaked;
    }
    try expectEval(w, "delete globalThis.owner && delete globalThis.child", "true");
}

/// A Headers made the way an impl makes a platform object (its interface's
/// constructor, from Zig): script has not seen it, so it has no wrapper.
fn unwrappedHeaders(r: runtime.Context) !*runtime.Instance {
    const Init = @typeInfo(@TypeOf(interfaces.Headers.call_constructor)).@"fn".params[1].type.?;
    return interfaces.Headers.call_constructor(r, Init.notPassed());
}

test "protocol: an owner script has not seen keeps its traced child, and draws the edge on its wrapper once made" {
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);

    // A Zig-made event before its dispatch, or a constructor's instance
    // before the binding caches `this`: no wrapper yet.
    const owner = Watched.of(try unwrappedHeaders(w));
    const child = Watched.of(try platformObjectIn(w, "new Headers([['child', '1']])"));
    protocol.traceChild(owner.instance, child.instance, .{ .name = "child" });
    // traceChild makes no wrapper for it - one made now would be the
    // collector's to free the owner with, and a constructor would replace it.
    try std.testing.expect(!protocol.hasWrapper(owner.instance));
    collectTwice();
    try std.testing.expect(owner.alive());
    try std.testing.expect(child.alive());

    // Script sees the owner: the edge is drawn on the wrapper made for it.
    {
        const wrapped = try protocol.retainValue(w, .{ .instance = owner.instance });
        defer wrapped.release();
        try setGlobal(w, "owner", wrapped.value);
    }
    collectTwice();
    try std.testing.expect(owner.alive());
    try std.testing.expect(child.alive());

    // The strong hold went to the edge, so the child goes with the owner.
    try expectEval(w, "delete globalThis.owner", "true");
    collectTwice();
    try std.testing.expect(!owner.alive());
    try std.testing.expect(!child.alive());
}

test "protocol: forgetTracedChild ends an edge that waits for its owner's wrapper, and a slot keeps one child" {
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);

    const owner = Watched.of(try unwrappedHeaders(w));
    const first = Watched.of(try platformObjectIn(w, "new Headers()"));
    const second = Watched.of(try platformObjectIn(w, "new Headers()"));
    const other = Watched.of(try platformObjectIn(w, "new Headers()"));
    protocol.traceChild(owner.instance, first.instance, .{ .name = "child" });
    protocol.traceChild(owner.instance, other.instance, .{ .name = "other" });
    protocol.traceChild(owner.instance, second.instance, .{ .name = "child" });
    collectTwice();
    try std.testing.expect(!first.alive());
    try std.testing.expect(second.alive());
    try std.testing.expect(other.alive());

    protocol.forgetTracedChild(owner.instance, .{ .name = "child" });
    protocol.forgetTracedChild(owner.instance, .{ .name = "never" });
    collectTwice();
    try std.testing.expect(!second.alive());
    try std.testing.expect(other.alive());
    try std.testing.expect(!protocol.hasWrapper(owner.instance));
}

test "protocol: an owner freed unwrapped lets its waiting edges go" {
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);
    const waiting = v8.wrapper_cache_mod.liveDeferredEdgeCount();

    // A Zig-made event that never reaches script: its teardown ends its
    // edges (forgetTracedChild), and it is freed - its child with them.
    const owner = try unwrappedHeaders(w);
    const child = Watched.of(try platformObjectIn(w, "new Headers()"));
    protocol.traceChild(owner, child.instance, .{ .name = "child" });
    try std.testing.expectEqual(waiting + 1, v8.wrapper_cache_mod.liveDeferredEdgeCount());
    protocol.forgetTracedChild(owner, .{ .name = "child" });
    runtime.Instance.releaseIfUnwrapped(owner, runtime.SlabAllocator.generationOf(owner));
    try std.testing.expectEqual(waiting, v8.wrapper_cache_mod.liveDeferredEdgeCount());
    collectTwice();
    try std.testing.expect(!child.alive());

    // An owner freed without ending them: the next edge drawn in its realm
    // finds its slot's generation moved on and lets them go too.
    const careless = try unwrappedHeaders(w);
    const orphan = Watched.of(try platformObjectIn(w, "new Headers()"));
    protocol.traceChild(careless, orphan.instance, .{ .name = "child" });
    runtime.Instance.releaseIfUnwrapped(careless, runtime.SlabAllocator.generationOf(careless));
    const next = try unwrappedHeaders(w);
    const kept = Watched.of(try platformObjectIn(w, "new Headers()"));
    protocol.traceChild(next, kept.instance, .{ .name = "child" });
    try std.testing.expectEqual(waiting + 1, v8.wrapper_cache_mod.liveDeferredEdgeCount());
    collectTwice();
    try std.testing.expect(!orphan.alive());
    try std.testing.expect(kept.alive());
    protocol.forgetTracedChild(next, .{ .name = "child" });
    runtime.Instance.releaseIfUnwrapped(next, runtime.SlabAllocator.generationOf(next));
}

test "protocol: edges waiting for an owner's wrapper leave no global handle behind" {
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);
    const isolate = isolate_once.?;
    const handle_bytes = blk: {
        const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        const one = ffi.v8_Number_New(isolate, 1);
        const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        ffi.v8_Value_Dispose(@ptrCast(one));
        break :blk with_one - start;
    };
    const owner = try unwrappedHeaders(w);
    const child = try platformObjectIn(w, "globalThis.child = new Headers()");
    // The first round makes what every later one reuses.
    protocol.traceChild(owner, child, .{ .name = "child" });
    protocol.forgetTracedChild(owner, .{ .name = "child" });
    collectTwice();
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const rounds = 32;
    for (0..rounds) |_| {
        protocol.traceChild(owner, child, .{ .name = "child" });
        protocol.traceChild(owner, child, .{ .name = "child" });
        protocol.forgetTracedChild(owner, .{ .name = "child" });
    }
    collectTwice();
    const after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    if (after -| before >= handle_bytes) {
        std.debug.print("global handles {d} -> {d} bytes over {d} rounds ({d} bytes a handle)\n", .{ before, after, rounds, handle_bytes });
        return error.HandlesLeaked;
    }
    try expectEval(w, "delete globalThis.child", "true");
}

// ============================================================================
// Promise capabilities and realm lifetime: a capability is tagged with the
// realm its promise is made in, so a detached realm keeps it by an edge from
// its global object - never a root - and a live realm's is untouched.
// ============================================================================

/// The state of `capability`'s promise: 0 pending, 1 fulfilled, 2 rejected.
fn promiseState(capability: *const protocol.PromiseCapability) c_int {
    const handle: *ffi.Promise = @ptrCast(@alignCast(capability.promise.handle.ptr));
    return ffi.v8_Promise_State(handle);
}

test "protocol: a pending promise capability of a live realm survives collections, and settles" {
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);
    // Script holds nothing of either promise: only its capability does.
    var resolved = try protocol.createPromise(w);
    defer protocol.releasePromiseCapability(&resolved);
    var rejected = try protocol.createPromise(w);
    defer protocol.releasePromiseCapability(&rejected);
    protocol.markPromiseAsHandled(w, rejected.promise);
    collectTwice();
    try std.testing.expectEqual(@as(c_int, 0), promiseState(&resolved));
    try protocol.resolvePromise(&resolved, runtime.JSValue.fromNumber(5));
    try protocol.rejectPromise(&rejected, runtime.JSValue.fromNumber(6));
    collectTwice();
    try std.testing.expectEqual(@as(c_int, 1), promiseState(&resolved));
    try std.testing.expectEqual(@as(c_int, 2), promiseState(&rejected));
    // Script reads what it was settled with.
    {
        const held = try protocol.retainValue(w, resolved.promise);
        defer held.release();
        try setGlobal(w, "settled", held.value);
    }
    try expectEval(w, "globalThis.got = 0; settled.then(v => { globalThis.got = v; }); 'ok'", "ok");
    try expectEval(w, "got", "5");
    try expectEval(w, "delete globalThis.settled && delete globalThis.got", "true");
}

test "protocol: a detached realm's promise capability keeps it while reachable, and goes with it" {
    _ = try realm();
    var host: WindowHost = .{};
    const parent = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(parent, .global_detached);
    const baseline = liveContexts();
    var frame_realm: FrameRealm = .{ .parent = parent };
    const frame = try frame_realm.make();
    {
        const frame_global = try evalOwned(frame, "globalThis");
        defer frame_global.release();
        try setGlobal(parent, "frameWindow", frame_global.value);
    }
    // A capability the frame's own objects keep (a navigation API method
    // tracker's): made in the frame's realm, held by the host.
    var kept = try protocol.createPromise(frame);
    defer protocol.releasePromiseCapability(&kept);
    var late = try protocol.createPromise(frame);
    defer protocol.releasePromiseCapability(&late);

    protocol.destroyWindowRealm(frame, .navigable_destroyed);
    // Script still reaches the frame: the capabilities still settle.
    collectTwice();
    try std.testing.expect(frame.engine_ctx != null);
    try protocol.resolvePromise(&kept, runtime.JSValue.fromNumber(1));
    try std.testing.expectEqual(@as(c_int, 1), promiseState(&kept));

    // Script lets the frame go: the capabilities are no root that keeps it.
    try expectEval(parent, "delete globalThis.frameWindow", "true");
    const after = liveContexts();
    if (after != baseline) {
        std.debug.print("native contexts: {d} before the frame, {d} after it was detached and dropped with two capabilities held\n", .{ baseline, after });
        return error.RealmKeptAlive;
    }
    // Settling a collected realm's promise does nothing, and touches no
    // context of the realm.
    try protocol.resolvePromise(&late, runtime.JSValue.fromNumber(2));
    try protocol.rejectPromise(&late, runtime.JSValue.fromNumber(3));
}

test "protocol: creating and releasing promise capabilities leaves no global handle behind" {
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);
    const isolate = isolate_once.?;
    const handle_bytes = blk: {
        const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        const one = ffi.v8_Number_New(isolate, 1);
        const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        ffi.v8_Value_Dispose(@ptrCast(one));
        break :blk with_one - start;
    };
    {
        var first = try protocol.createPromise(w);
        protocol.releasePromiseCapability(&first);
    }
    collectTwice();
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const rounds = 32;
    for (0..rounds) |i| {
        var capability = try protocol.createPromise(w);
        if (i % 2 == 0) try protocol.resolvePromise(&capability, runtime.JSValue.fromNumber(1));
        protocol.releasePromiseCapability(&capability);
    }
    collectTwice();
    const after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    if (after -| before >= handle_bytes) {
        std.debug.print("global handles {d} -> {d} bytes over {d} rounds ({d} bytes a handle)\n", .{ before, after, rounds, handle_bytes });
        return error.HandlesLeaked;
    }
}

// ============================================================================
// traceValue / tracedValue: an owner keeps a JavaScript value for as long as
// its wrapper lives - Blink's TraceWrapperV8Reference - where Crane once held
// an engine.Owned, a root that kept the value's realm whatever became of the
// owner (FileReader.result, CustomEvent.detail, NavigateEvent.info).
// ============================================================================

/// `owner`'s traced value in `slot`, set as the global `name` of `r`; false
/// when the slot holds none.
fn tracedToGlobal(r: runtime.Context, owner: *runtime.Instance, slot: []const u8, name: []const u8) !bool {
    const value = protocol.tracedValue(owner, .{ .name = slot }) orelse return false;
    defer value.release();
    const held = try protocol.retainValue(r, value.value);
    defer held.release();
    if (held.value != .handle) {
        // A primitive kept by value: make it a script value to compare.
        const made = try evalOwned(r, "undefined");
        defer made.release();
        return error.PrimitiveNotAHandle;
    }
    try setGlobal(r, name, held.value);
    return true;
}

test "protocol: a traced value lives as long as its owner's wrapper, and goes with it" {
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);

    // Script keeps the owner, and nothing of either value.
    const owner = Watched.of(try platformObjectIn(w, "globalThis.owner = new Headers()"));
    const traced = Watched.of(try platformObjectIn(w, "new Headers([['traced', '1']])"));
    const untraced = Watched.of(try platformObjectIn(w, "new Headers([['untraced', '1']])"));
    protocol.traceValue(owner.instance, .{ .instance = traced.instance }, .{ .name = "result" });
    {
        // A plain object, made by script and handed over as the binding hands
        // a value: borrowed for the call.
        const object = try evalOwned(w, "({ plain: 7 })");
        defer object.release();
        protocol.traceValue(owner.instance, object.value, .{ .name = "detail" });
    }

    collectTwice();
    try std.testing.expect(!untraced.alive());
    try std.testing.expect(owner.alive());
    try std.testing.expect(traced.alive());
    try std.testing.expect(try tracedToGlobal(w, owner.instance, "detail", "detail"));
    try expectEval(w, "detail.plain", "7");
    try expectEval(w, "delete globalThis.detail", "true");

    // Script lets the owner go, and the values go with it: an edge, not a root.
    try expectEval(w, "delete globalThis.owner", "true");
    collectTwice();
    try std.testing.expect(!owner.alive());
    try std.testing.expect(!traced.alive());
}

test "protocol: tracedValue reads back the value itself; a slot holds one; forgetTracedChild empties it" {
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);
    const owner = try platformObjectIn(w, "globalThis.owner = new Headers()");

    // Never set: null.
    try std.testing.expect(protocol.tracedValue(owner, .{ .name = "info" }) == null);
    {
        const first = try evalOwned(w, "globalThis.first = { n: 1 }");
        defer first.release();
        protocol.traceValue(owner, first.value, .{ .name = "info" });
    }
    try std.testing.expect(try tracedToGlobal(w, owner, "info", "back"));
    try expectEval(w, "back === first", "true");
    {
        // A new value in the slot replaces the old.
        const second = try evalOwned(w, "globalThis.second = { n: 2 }");
        defer second.release();
        protocol.traceValue(owner, second.value, .{ .name = "info" });
    }
    try std.testing.expect(try tracedToGlobal(w, owner, "info", "back"));
    try expectEval(w, "back === second", "true");

    // A primitive is kept too, as itself.
    protocol.traceValue(owner, runtime.JSValue.fromNumber(42), .{ .name = "number" });
    {
        const number = protocol.tracedValue(owner, .{ .name = "number" }) orelse return error.NoValue;
        defer number.release();
        try std.testing.expectEqual(@as(f64, 42), try protocol.convertToUnrestrictedDouble(w, number.value));
    }

    protocol.forgetTracedChild(owner, .{ .name = "info" });
    try std.testing.expect(protocol.tracedValue(owner, .{ .name = "info" }) == null);
    try std.testing.expect(protocol.tracedValue(owner, .{ .name = "number" }) != null);
    try expectEval(w, "delete globalThis.owner && delete globalThis.first && delete globalThis.second && delete globalThis.back", "true");
}

test "protocol: a value that reaches back to its owner does not keep it" {
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);

    // A CustomEvent whose detail closes over the event: held as a root, the
    // detail kept the event, and the event the detail, forever.
    const owner = Watched.of(try platformObjectIn(w, "globalThis.owner = new Headers()"));
    {
        const closure = try evalOwned(w, "(() => { const o = owner; return { back: () => o }; })()");
        defer closure.release();
        protocol.traceValue(owner.instance, closure.value, .{ .name = "detail" });
    }
    collectTwice();
    try std.testing.expect(owner.alive());
    try expectEval(w, "delete globalThis.owner", "true");
    collectTwice();
    try std.testing.expect(!owner.alive());
}

test "protocol: an owner script has not seen keeps its traced value, readable before and after its wrapper is made" {
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);

    // A Zig-made event before its dispatch: no wrapper yet.
    const owner = Watched.of(try unwrappedHeaders(w));
    const value = Watched.of(try platformObjectIn(w, "new Headers([['v', '1']])"));
    protocol.traceValue(owner.instance, .{ .instance = value.instance }, .{ .name = "error" });
    try std.testing.expect(!protocol.hasWrapper(owner.instance));
    collectTwice();
    try std.testing.expect(value.alive());
    // Engine code reads it before script ever sees the owner.
    {
        const read = protocol.tracedValue(owner.instance, .{ .name = "error" }) orelse return error.NoValue;
        defer read.release();
        try std.testing.expectEqual(value.instance, protocol.convertToPlatformObject(w, read.value).?);
    }

    // Script sees the owner: the edge is drawn on its wrapper.
    {
        const wrapped = try protocol.retainValue(w, .{ .instance = owner.instance });
        defer wrapped.release();
        try setGlobal(w, "owner", wrapped.value);
    }
    collectTwice();
    try std.testing.expect(value.alive());
    try std.testing.expect(try tracedToGlobal(w, owner.instance, "error", "error"));
    try expectEval(w, "error.get('v')", "1");
    try expectEval(w, "delete globalThis.error && delete globalThis.owner", "true");
    collectTwice();
    try std.testing.expect(!owner.alive());
    try std.testing.expect(!value.alive());
}

test "protocol: traceValue and tracedValue leave no global handle behind" {
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);
    const isolate = isolate_once.?;
    const handle_bytes = blk: {
        const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        const one = ffi.v8_Number_New(isolate, 1);
        const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        ffi.v8_Value_Dispose(@ptrCast(one));
        break :blk with_one - start;
    };
    const window = try platformObjectIn(w, "globalThis");
    const owner = try platformObjectIn(w, "globalThis.owner = new Headers()");
    const unwrapped = try unwrappedHeaders(w);
    const value = try evalOwned(w, "globalThis.value = { v: 1 }");
    defer value.release();
    const round = struct {
        fn run(owners: []const *runtime.Instance, v: runtime.JSValue) void {
            for (owners) |o| {
                protocol.traceValue(o, v, .{ .name = "value" });
                protocol.traceValue(o, runtime.JSValue.fromNumber(3), .{ .name = "number" });
                if (protocol.tracedValue(o, .{ .name = "value" })) |read| read.release();
                if (protocol.tracedValue(o, .{ .name = "number" })) |read| read.release();
                if (protocol.tracedValue(o, .{ .name = "never" })) |read| read.release();
                protocol.forgetTracedChild(o, .{ .name = "value" });
                protocol.forgetTracedChild(o, .{ .name = "number" });
            }
        }
    }.run;
    const owners = [_]*runtime.Instance{ window, owner, unwrapped };
    // The first round makes what every later one reuses.
    round(&owners, value.value);
    collectTwice();
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const rounds = 32;
    for (0..rounds) |_| round(&owners, value.value);
    collectTwice();
    const after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    if (after -| before >= handle_bytes) {
        std.debug.print("global handles {d} -> {d} bytes over {d} rounds ({d} bytes a handle)\n", .{ before, after, rounds, handle_bytes });
        return error.HandlesLeaked;
    }
    try expectEval(w, "delete globalThis.owner && delete globalThis.value", "true");
}

test "a window's indexedDB, when making its IDBFactory fails at any allocation, frees what it made once" {
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);
    // Each allocation the getter makes fails in turn. The allocator under it
    // reports a double free or an invalid free (a panic, or an error log,
    // which fails the test); it is never deinit'd - a Window torn down
    // unwrapped leaves state its realm's end would free, which this test does
    // not measure.
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    var k: usize = 0;
    while (k < 8) : (k += 1) {
        var failing = std.testing.FailingAllocator.init(debug_allocator.allocator(), .{});
        const window = try interfaces.Window.init(failing.allocator(), w);
        failing.fail_index = failing.alloc_index + k;
        _ = interfaces.Window.get_indexedDB(window) catch {};
        runtime.Instance.releaseIfUnwrapped(window, runtime.SlabAllocator.generationOf(window));
    }
}

test "protocol: performMicrotaskCheckpoint runs the agent's microtasks, whichever realm queued them" {
    var host: WindowHost = .{};
    const parent = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(parent, .global_detached);
    var frame_realm: FrameRealm = .{ .parent = parent };
    const frame = try frame_realm.make();
    defer protocol.destroyWindowRealm(frame, .global_detached);

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
    try protocol.queueMicrotask(parent.agent.?, Ran.steps, &ran);
    try protocol.queueMicrotask(frame.agent.?, Ran.steps, &ran);
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
    protocol.destroyWindowRealm(w, .global_detached);
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
    defer protocol.destroyWindowRealm(a, .global_detached);
    var host_b: WindowHost = .{};
    const b = try windowRealm(&host_b, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(b, .global_detached);

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
    defer protocol.destroyWindowRealm(w, .global_detached);
    var host_o: WindowHost = .{};
    const other = try windowRealm(&host_o, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(other, .global_detached);

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

test "protocol: an agent ended while another isolate is entered leaves that isolate's realms working" {
    const base = try realm();
    const no_hooks: protocol.HostHooks = .{};
    // Made with its per-isolate state (templates, allocator, ShadowRealm
    // support), and a realm made and ended in it.
    const agent = try protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &no_hooks });
    {
        const in_agent = try AgentRealm.make(agent);
        defer in_agent.end();
        try expectEval(in_agent.realm, "typeof ShadowRealm === 'function' || typeof ShadowRealm === 'undefined'", "true");
    }
    // Ended while this file's isolate is the entered one: only its own
    // isolate's state goes, not the thread's (the context manager keeps this
    // file's realm).
    protocol.destroyAgent(agent);
    try std.testing.expectEqual(isolate_once, ffi.v8_Isolate_GetCurrent());
    try expectEval(base, "[1, 2, 3].map((x) => x * 2).join()", "2,4,6");
    try std.testing.expect(v8.context_manager.get(context_once.?) != null);
}

test "protocol: an agent made inside another's realm is not the host agent, even when it ends with no isolate entered" {
    const base = try realm();
    const no_hooks: protocol.HostHooks = .{};
    // Made while this file's isolate is entered: as a worker's agent is made,
    // by its owner's script.
    const agent = try protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &no_hooks });
    {
        const in_agent = try AgentRealm.make(agent);
        defer in_agent.end();
    }
    // Ended with NO isolate entered: as a Browser ends its workers once its
    // page realm has exited the page isolate. What is entered at the end says
    // nothing about whose agent this is; it is still not the thread's host,
    // so only its own isolate's state goes - the context manager keeps this
    // file's realm, and its templates still work.
    {
        ffi.v8_Isolate_Exit(isolate_once.?);
        defer ffi.v8_Isolate_Enter(isolate_once.?);
        try std.testing.expect(ffi.v8_Isolate_GetCurrent() == null);
        protocol.destroyAgent(agent);
        try std.testing.expect(ffi.v8_Isolate_GetCurrent() == null);
    }
    try std.testing.expectEqual(isolate_once, ffi.v8_Isolate_GetCurrent());
    try std.testing.expect(v8.context_manager.get(context_once.?) != null);
    try expectEval(base, "[1, 2, 3].map((x) => x * 2).join()", "2,4,6");
}

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

    // CreateDefaultExportSyntheticModule (HTML "create a CSS module script"
    // step 6): a record whose "default" export is the value given, as a CSS
    // module import reads it.
    const sheet = try evalOwned(base, "({ rules: 'the sheet' })");
    defer sheet.release();
    const synthetic = try protocol.createDefaultExportSyntheticModule(base, sheet.value, "https://example.test/s.css", null);
    defer protocol.releaseModuleRecord(synthetic);
    const importer = try parsed(try protocol.parseModule(
        base,
        "import sheet from './s.css' with { type: 'css' };\nglobalThis.fromSynthetic = sheet.rules;",
        "https://example.test/importer.js",
        null,
    ));
    defer protocol.releaseModuleRecord(importer);
    var css_graph: Graph = .{ .specifiers = &.{"./s.css"}, .records = &.{synthetic} };
    try std.testing.expect(try protocol.linkModule(base, importer, Graph.resolve, &css_graph) == null);
    const css_scope = try protocol.prepareToRunScript(base);
    const css_evaluation = try protocol.evaluateModule(base, importer);
    protocol.cleanUpAfterRunningScript(css_scope);
    try std.testing.expect(css_evaluation == .completed);
    try expectEval(base, "globalThis.fromSynthetic", "the sheet");
    try expectEval(base, "delete globalThis.fromSynthetic", "true");
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
    // installed the protocol's import() - and must not replace it (a realm's
    // registration used to install the legacy import() handler).
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

/// The test's host for import.meta.resolve: what it was asked, and its
/// answer - the specifier appended to the base URL, or failure for "bad".
const ResolveHost = struct {
    calls: usize = 0,
    realm: ?runtime.Context = null,
    base_buffer: [64]u8 = undefined,
    base_len: usize = 0,

    fn resolve(host: ?*anyopaque, r: runtime.Context, base_url: []const u8, specifier: []const u8, allocator: std.mem.Allocator) ?[]u8 {
        const self: *ResolveHost = @ptrCast(@alignCast(host.?));
        self.calls += 1;
        self.realm = r;
        self.base_len = @min(base_url.len, self.base_buffer.len);
        @memcpy(self.base_buffer[0..self.base_len], base_url[0..self.base_len]);
        if (std.mem.eql(u8, specifier, "bad")) return null;
        return std.fmt.allocPrint(allocator, "{s}?{s}", .{ base_url, specifier }) catch null;
    }
};

test "protocol: import.meta.resolve is a builtin that asks the host with the module's realm and base URL" {
    _ = try realm();
    var host: ResolveHost = .{};
    const hooks: protocol.HostHooks = .{ .importMetaUrl = ImportHost.metaUrl, .importMetaResolve = ResolveHost.resolve };
    const agent = try protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &hooks, .host = &host });
    defer protocol.destroyAgent(agent);
    const in_agent = try AgentRealm.make(agent);
    defer in_agent.end();
    const r = in_agent.realm;

    // A module whose import.meta the engine initializes on first use; its
    // resolve is kept on the global, to be called from a classic script.
    var module_script: TestModuleScript = .{ .url = "https://example.test/m.js" };
    const m = try parsed(try protocol.parseModule(r, "globalThis.resolve = import.meta.resolve; globalThis.meta = import.meta;", module_script.url, &module_script));
    defer protocol.releaseModuleRecord(m);
    try std.testing.expect(try protocol.linkModule(r, m, Graph.none, null) == null);
    const scope = try protocol.prepareToRunScript(r);
    const evaluation = try protocol.evaluateModule(r, m);
    protocol.cleanUpAfterRunningScript(scope);
    try std.testing.expect(evaluation == .completed);

    // CreateBuiltinFunction(steps, 1, "resolve", « »): not a constructor, a
    // writable, enumerable, configurable data property beside url.
    try expectEval(r, "typeof resolve + ' ' + resolve.name + ' ' + resolve.length", "function resolve 1");
    try expectEval(r, "Object.getPrototypeOf(resolve) === Function.prototype", "true");
    try expectEval(r, "try { new resolve('x'); 'constructed' } catch (e) { e.constructor.name }", "TypeError");
    try expectEval(r, "Object.keys(meta).join()", "url,resolve");
    try expectEval(r, "(() => { const d = Object.getOwnPropertyDescriptor(meta, 'resolve'); return d.writable && d.enumerable && d.configurable; })()", "true");

    // Its steps: ToString the argument, then the host's answer, given the
    // module's realm and its base URL (import.meta.url).
    try expectEval(r, "resolve({ toString() { return './x'; } })", "https://example.test/m.js?./x");
    try std.testing.expectEqual(r, host.realm.?);
    try std.testing.expectEqualStrings("https://example.test/m.js", host.base_buffer[0..host.base_len]);
    try expectEval(r, "resolve()", "https://example.test/m.js?undefined");
    // ToString throws for a Symbol, before the host is asked.
    const calls = host.calls;
    try expectEval(r, "try { resolve(Symbol('s')); 'resolved' } catch (e) { e.constructor.name }", "TypeError");
    try std.testing.expectEqual(calls, host.calls);
    // The host's failure is a TypeError.
    try expectEval(r, "try { resolve('bad'); 'resolved' } catch (e) { e.constructor.name }", "TypeError");
    try expectEval(r, "delete globalThis.resolve && delete globalThis.meta", "true");
}

test "constructing a DOMException leaves no handle behind, as constructing an Event does" {
    _ = try realm();
    ensurePools();
    const isolate = isolate_once.?;
    // DOMException's interface object, and Event's for the control.
    v8.interface_bindings.registerAllInterfaces(isolate, context_once.?);

    // What one handle costs in V8's count.
    const handle_bytes = blk: {
        const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        const one = ffi.v8_Number_New(isolate, 1);
        const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        ffi.v8_Value_Dispose(@ptrCast(one));
        break :blk with_one - start;
    };

    // Construct `rounds` of one interface, collect them, and return the
    // global-handle bytes left. The first construction may make what the rest
    // reuse, so it runs first.
    const rounds = 32;
    const Measure = struct {
        fn leftAfter(i: *ffi.Isolate, comptime construction: []const u8) !usize {
            var reports = try run("void (" ++ construction ++ ");");
            try std.testing.expectEqual(@as(usize, 0), reports.count);
            ffi.v8_Isolate_RequestGarbageCollection(i);
            const before = ffi.v8_Isolate_GetGlobalHandleBytes(i);
            reports = try run("for (let i = 0; i < 32; i++) void (" ++ construction ++ ");");
            try std.testing.expectEqual(@as(usize, 0), reports.count);
            ffi.v8_Isolate_RequestGarbageCollection(i);
            return ffi.v8_Isolate_GetGlobalHandleBytes(i) -| before;
        }
    };
    // The control: the same constructor path, cache and all, without a stack.
    const events = try Measure.leftAfter(isolate, "new Event('x')");
    // A DOMException gets a `stack` (WebIDL: when the implementation gives
    // errors one), captured by running a script in its realm: that script,
    // the global object it went through, and its completion value were three
    // Globals left per construction, and the global object is the whole page.
    const exceptions = try Measure.leftAfter(isolate, "new DOMException('m', 'AbortError')");
    if (exceptions -| events >= handle_bytes * rounds / 4) {
        std.debug.print("{d} DOMExceptions left {d} bytes of global handles; {d} Events left {d} ({d} bytes a handle)\n", .{ rounds, exceptions, rounds, events, handle_bytes });
        return error.HandlesLeaked;
    }
    // And it still has its stack.
    const reports = try run("if (typeof new DOMException('m').stack !== 'string') throw new Error('no stack');");
    try std.testing.expectEqual(@as(usize, 0), reports.count);
}

test "protocol: listeners added and removed in a loop leave no callback wrapper behind" {
    // WebIDL: a callback interface argument (EventListener) is the call's; a
    // listener the target keeps is its own callback interface value. Every
    // wrapper the binding makes for the argument must be gone once the call
    // returns - std.testing.allocator fails the test on any that outlives it.
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);
    const saved = v8.conversions.callback_allocator;
    v8.conversions.callback_allocator = std.testing.allocator;
    defer v8.conversions.callback_allocator = saved;
    try expectEval(w,
        \\const f = () => {};
        \\const o = { handleEvent() {} };
        \\let heard = 0;
        \\const g = () => { heard++; };
        \\for (let i = 0; i < 10; i++) {
        \\  addEventListener('x', f); removeEventListener('x', f);
        \\  addEventListener('y', o, true); removeEventListener('y', o, true);
        \\}
        \\addEventListener('z', g);
        \\dispatchEvent(new Event('z'));
        \\removeEventListener('z', g);
        \\dispatchEvent(new Event('z'));
        \\String(heard)
    , "1");
}

test "protocol: what a getter returns is the binding's - a kept value reads the same, and no read leaves a handle" {
    // AGENTS.md "The engine boundary", rule 3: the binding releases every
    // value an impl returns. A value the object keeps goes back as a hold of
    // the binding's own (engine.retainValue(...).take()), so it reads the same
    // every time and survives the binding's release; a value made for the
    // read is released with it.
    // `io` takes the default threshold: the constructor does not parse
    // options.threshold yet (it always keeps [0]), and what this test pins is
    // the frozen array's identity, not the parse.
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);
    try expectEval(w,
        \\const e = new ErrorEvent('x');
        \\const c = new CustomEvent('x', { detail: { a: 1 } });
        \\const s = AbortSignal.abort({ why: 1 });
        \\const p = new PopStateEvent('x', { state: { b: 2 } });
        \\const m = new MessageEvent('x', { data: { d: 4 } });
        \\const k = new CookieChangeEvent('change', { changed: [{ name: 'a', value: 'b' }] });
        \\const io = new IntersectionObserver(() => {});
        \\globalThis.reads = () => {
        \\  void e.error; void c.detail; void s.reason; void p.state; void m.data;
        \\  void k.changed; void k.deleted; void io.thresholds;
        \\};
        \\[
        \\  e.error === undefined,
        \\  c.detail === c.detail && c.detail.a === 1,
        \\  s.reason === s.reason && s.reason.why === 1,
        \\  p.state === p.state && p.state.b === 2,
        \\  m.data === m.data && m.data.d === 4,
        \\  k.changed === k.changed && k.changed[0].name === 'a',
        \\  k.deleted === k.deleted && k.deleted.length === 0,
        \\  io.thresholds === io.thresholds && Object.isFrozen(io.thresholds) && io.thresholds.join() === '0',
        \\].join()
    , "true,true,true,true,true,true,true,true");

    const isolate = isolate_once.?;
    // What one handle costs in V8's count.
    const handle_bytes = blk: {
        const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        const one = ffi.v8_Number_New(isolate, 1);
        const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        ffi.v8_Value_Dispose(@ptrCast(one));
        break :blk with_one - start;
    };
    try std.testing.expect(handle_bytes > 0);

    // Eight reads a round; a leak is at least one handle a round. The same
    // loop without the reads is the control for what running script costs.
    const rounds = 64;
    try expectEval(w, "reads(); reads(); 'warm'", "warm");
    var start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    try expectEval(w, "for (let n = 0; n < 64; n++) {} 'control'", "control");
    const control = ffi.v8_Isolate_GetGlobalHandleBytes(isolate) -| start;
    start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    try expectEval(w, "for (let n = 0; n < 64; n++) reads(); 'read'", "read");
    const read = ffi.v8_Isolate_GetGlobalHandleBytes(isolate) -| start;
    if (read -| control >= handle_bytes * rounds / 4) {
        std.debug.print("{d} rounds of getter reads left {d} bytes of global handles; the control {d} ({d} bytes a handle)\n", .{ rounds, read, control, handle_bytes });
        return error.HandlesLeaked;
    }
}

test "protocol: engine code that reads a kept value through its getter releases the hold it gets" {
    // A getter's result is a hold of the caller's own (retainValue().take()),
    // for engine code that calls the getter through `interfaces` as much as
    // for the binding. The special error event handling reads
    // ErrorEvent.error for onerror's fifth argument (EventTarget's
    // ErrorEventArguments) and must release it, or every onerror call leaks a
    // handle. The control takes the same path with a primitive error, which
    // retainValue holds by value, with no handle - so only the object's hold
    // is left to count. (fetch() and pipeTo read AbortSignal.reason the same
    // way; this realm's global fails fetch's brand check, and a stream keeps
    // its stored error, so gc_bench measures those.)
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);
    try expectEval(w,
        \\globalThis.seen = [];
        \\onerror = (message, filename, lineno, colno, error) => { seen.push(error); };
        \\globalThis.object = { o: 1 };
        \\globalThis.errorEvent = new ErrorEvent('error', { error: object });
        \\globalThis.primitiveEvent = new ErrorEvent('error', { error: 1 });
        \\dispatchEvent(errorEvent); dispatchEvent(primitiveEvent);
        \\[seen.length, seen[0] === object ? 'object' : String(seen[0]), String(seen[1])].join()
    , "2,object,1");

    const isolate = isolate_once.?;
    const handle_bytes = blk: {
        const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        const one = ffi.v8_Number_New(isolate, 1);
        const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        ffi.v8_Value_Dispose(@ptrCast(one));
        break :blk with_one - start;
    };
    try std.testing.expect(handle_bytes > 0);

    // 64 onerror calls a run; a leak is a handle a call. Both runs are warmed
    // first, then each is measured on its own.
    const rounds = 64;
    const control_run = "seen.length = 0; for (let n = 0; n < 64; n++) dispatchEvent(primitiveEvent); String(seen.length)";
    const read_run = "seen.length = 0; for (let n = 0; n < 64; n++) dispatchEvent(errorEvent); String(seen.length)";
    try expectEval(w, control_run, "64");
    try expectEval(w, read_run, "64");
    var start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    try expectEval(w, control_run, "64");
    const control = ffi.v8_Isolate_GetGlobalHandleBytes(isolate) -| start;
    start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    try expectEval(w, read_run, "64");
    const read = ffi.v8_Isolate_GetGlobalHandleBytes(isolate) -| start;
    if (read -| control >= handle_bytes * rounds / 4) {
        std.debug.print("{d} onerror calls with an object error left {d} bytes of global handles; with a number, {d} ({d} bytes a handle)\n", .{ rounds, read, control, handle_bytes });
        return error.HandlesLeaked;
    }
}

test "protocol: a MessageEvent made with ports keeps one frozen array, the one every read returns" {
    // FrozenArray: the constructor makes the event's ports array at once
    // (the array is what keeps the ports) and keeps it; every read returns a
    // hold of that array, before a collection and after it. The WeakMap marks
    // the array without keeping it: only the event's own hold does.
    //
    // The constructor used to make the array by calling get_ports and
    // dropping the result - a hold of its caller's own under part B - which
    // left one handle per event. That is measured by gc_bench, not here: the
    // argument conversion of `ports` leaves handles of its own (one per
    // sequence and two per element, on main as well), so a handle count
    // after a collection cannot single the constructor out.
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);
    try expectEval(w,
        \\globalThis.port = new MessageChannel().port1;
        \\globalThis.withPorts = new MessageEvent('x', { ports: [port] });
        \\globalThis.marks = new WeakMap([[withPorts.ports, 1]]);
        \\[withPorts.ports === withPorts.ports, withPorts.ports[0] === port, Object.isFrozen(withPorts.ports)].join()
    , "true,true,true");
    ffi.v8_Isolate_RequestGarbageCollection(isolate_once.?);
    try expectEval(w, "[marks.has(withPorts.ports), withPorts.ports === withPorts.ports, withPorts.ports[0] === port].join()", "true,true,true");
}

/// Bytes of global handles `source` leaves behind in `w` (it must evaluate
/// to "ok").
fn handleBytesLeftBy(w: runtime.Context, source: []const u8) !usize {
    const isolate = isolate_once.?;
    const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    try expectEval(w, source, "ok");
    return ffi.v8_Isolate_GetGlobalHandleBytes(isolate) -| start;
}

test "protocol: the indexed and named property interceptors release the handles they return" {
    // A string a named getter returns (`el.dataset.x`) is converted to a
    // Global that setReturnValue only reads: kept, it was one handle per read,
    // and encoding/legacy-mb-*-decode read 60,000 a page - a megabyte of
    // strings a page that no collection could free. The indexed getter
    // (`classList[0]`), the named descriptor and the named query made the
    // same kind of value the same way.
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);
    try expectEval(w,
        \\globalThis.el = new Document().createElementNS('http://www.w3.org/1999/xhtml', 'span');
        \\el.setAttribute('data-bytes', 'E1 78');
        \\el.className = 'a b';
        \\el.plain = 'E1 78';
        \\[el.dataset.bytes, el.classList[0], el.plain].join()
    , "E1 78,a,E1 78");

    // The control: the same loop over an own data property - what running
    // the script costs, if anything.
    const control = try handleBytesLeftBy(w, "for (let i = 0; i < 64; i++) el.plain.length; 'ok'");
    const named = try handleBytesLeftBy(w, "for (let i = 0; i < 64; i++) el.dataset.bytes.length; 'ok'");
    const indexed = try handleBytesLeftBy(w, "for (let i = 0; i < 64; i++) el.classList[0].length; 'ok'");
    const descriptor = try handleBytesLeftBy(w, "for (let i = 0; i < 64; i++) Object.getOwnPropertyDescriptor(el.dataset, 'bytes').value.length; 'ok'");
    const query = try handleBytesLeftBy(w, "for (let i = 0; i < 64; i++) 'bytes' in el.dataset; 'ok'");
    if (named > control or indexed > control or descriptor > control or query > control) {
        std.debug.print("64 reads left global handle bytes: named getter {d}, indexed getter {d}, named descriptor {d}, named query {d}; an own property {d}\n", .{ named, indexed, descriptor, query, control });
        return error.HandlesLeaked;
    }
}

test "protocol: a trusted animation event reaches a listener for its legacy webkit type, renamed, and keeps its own type" {
    // The hooks this test's objects reach (no Browser here: crane.Process is not started).
    @import("interfaces").process_hooks.startHooksForTest();
    // DOM "invoke" step 9: when no listener on a target matched a trusted
    // event's type, a legacy-mapped type (animationend -> webkitAnimationEnd,
    // ...) is tried, with the event's type attribute renamed while those
    // listeners run and restored afterwards. Script cannot make a trusted
    // event, so the dispatch is the user agent's: dom.fire_event.
    var host: WindowHost = .{};
    const w = try windowRealm(&host, false, .new_window_proxy);
    defer protocol.destroyWindowRealm(w, .global_detached);
    try expectEval(w,
        \\globalThis.seen = [];
        \\globalThis.legacyOnly = new EventTarget();
        \\legacyOnly.addEventListener('webkitAnimationEnd', e => seen.push('legacy:' + e.type + ':' + e.isTrusted));
        \\globalThis.both = new EventTarget();
        \\both.addEventListener('animationend', e => seen.push('unprefixed:' + e.type));
        \\both.addEventListener('webkitAnimationEnd', e => seen.push('legacy-on-both'));
        \\globalThis.animationEvent = new AnimationEvent('animationend');
        \\'ok'
    , "ok");

    const legacy_only = try evalOwned(w, "legacyOnly");
    defer legacy_only.release();
    const both = try evalOwned(w, "both");
    defer both.release();
    const event = try evalOwned(w, "animationEvent");
    defer event.release();
    const legacy_target = protocol.convertToPlatformObject(w, legacy_only.value) orelse return error.NotAPlatformObject;
    const both_target = protocol.convertToPlatformObject(w, both.value) orelse return error.NotAPlatformObject;
    const event_instance = protocol.convertToPlatformObject(w, event.value) orelse return error.NotAPlatformObject;

    const dom = @import("dom");
    _ = try dom.fire_event.dispatchTrusted(legacy_target, event_instance);
    // Step 9.4: the type is the event's own again once the listeners ran.
    try expectEval(w, "[seen.join(), animationEvent.type].join('|')", "legacy:webkitAnimationEnd:true|animationend");

    // A target with a listener for the type itself never reaches the legacy
    // one: found is true.
    try expectEval(w, "seen.length = 0; 'ok'", "ok");
    _ = try dom.fire_event.dispatchTrusted(both_target, event_instance);
    try expectEval(w, "[seen.join(), animationEvent.type].join('|')", "unprefixed:animationend|animationend");

    // An untrusted dispatch is never renamed.
    try expectEval(w, "seen.length = 0; legacyOnly.dispatchEvent(new AnimationEvent('animationend')); String(seen.length)", "0");
}
