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
