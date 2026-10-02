//! engine.parseJsonInNewGlobal: ECMAScript JSON.parse "in the context of a new
//! global object" (WebCrypto "parse a JWK" step 4), as V8 implements it.
//!
//! `engine.parseJsonToValue` uses the intrinsic parser but parses in the
//! caller's realm, so its result inherits the caller's Object.prototype: an
//! unwrapped JSON object with no `kty` would read `Object.prototype.kty =
//! "oct"` and pass "parse a JWK"'s step 6. These pin the new global: its
//! objects are not the caller's, a SyntaxError is the caller's, and the
//! throwaway global is collected once nothing refers to it.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");

var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;
var data_once: ?*runtime.ContextData = null;

/// One isolate and realm for the file, as engine_webidl_conversions_test.zig
/// makes it - V8 is never torn down here.
fn realm() !runtime.Context {
    if (data_once) |d| return d;
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    const data = try std.heap.page_allocator.create(runtime.ContextData);
    data.* = try runtime.ContextData.init(std.heap.page_allocator, .{ .engine_ctx = context });
    data.agent = @ptrCast(i);
    isolate_once = i;
    context_once = context;
    data_once = data;
    return data;
}

fn eval(code: []const u8) !*ffi.Value {
    const context = context_once.?;
    const text = ffi.v8_String_NewFromUtf8(isolate_once.?, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.RunFailed;
}

fn evalInt(code: []const u8) !i32 {
    const value = try eval(code);
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, context_once.?);
}

fn setGlobal(name: []const u8, handle: *anyopaque) !void {
    const context = context_once.?;
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate_once.?, name.ptr, @intCast(name.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    _ = ffi.v8_Object_Set(global, context, @ptrCast(key), @ptrCast(@alignCast(handle)));
}

/// Whether script's `expression` over `name` (bound to `value`) is true.
fn holds(name: []const u8, value: *anyopaque, expression: []const u8) !bool {
    try setGlobal(name, value);
    return try evalInt(expression) == 1;
}

/// Run `body.run()` under a TryCatch; what it threw (OWNED), or null.
fn thrownBy(body: anytype) ?*ffi.Value {
    const Body = @TypeOf(body.*);
    const Trampoline = struct {
        fn call(data: ?*anyopaque) callconv(.c) void {
            const self: *Body = @ptrCast(@alignCast(data.?));
            self.run();
        }
    };
    var thrown: ?*ffi.Value = null;
    _ = ffi.v8_RunCatching(isolate_once.?, Trampoline.call, body, &thrown);
    return thrown;
}

fn nativeContexts() usize {
    var count: usize = 0;
    ffi.v8_Isolate_GetContextCounts(isolate_once.?, &count, null);
    return count;
}

/// Collections enough for a dropped context to go: V8 frees a native context
/// once no object refers to it, which can take more than one full GC.
fn collect() void {
    for (0..4) |_| ffi.v8_Isolate_RequestGarbageCollection(isolate_once.?);
}

test "the result's objects and arrays are the new global's, not the caller's" {
    const ctx = try realm();
    _ = try evalInt("Object.prototype.kty = 'oct'; Array.prototype.polluted = 1; 1");
    defer _ = evalInt("delete Object.prototype.kty; delete Array.prototype.polluted; 1") catch {};
    const parsed = try protocol.parseJsonInNewGlobal(ctx, "{\"a\":[1,2],\"b\":{}}");
    defer parsed.release();
    try std.testing.expect(try holds("fresh", parsed.value.handle.ptr,
        \\Object.getPrototypeOf(fresh) !== Object.prototype &&
        \\Object.getPrototypeOf(fresh.a) !== Array.prototype &&
        \\fresh.kty === undefined && fresh.b.kty === undefined && fresh.a.polluted === undefined &&
        \\fresh.a.length === 2 && fresh.a[1] === 2 ? 1 : 0
    ));
    // parseJsonToValue, the control: the caller's realm shows through.
    const same = try protocol.parseJsonToValue(ctx, "{}");
    defer same.release();
    try std.testing.expect(try holds("same", same.value.handle.ptr, "same.kty === 'oct' ? 1 : 0"));
}

test "a replaced JSON.parse is not what parses, and a BOM is dropped" {
    const ctx = try realm();
    _ = try evalInt("globalThis.savedJSON = JSON; globalThis.JSON = { parse() { return 42; } }; 1");
    defer _ = evalInt("globalThis.JSON = savedJSON; 1") catch {};
    const parsed = try protocol.parseJsonInNewGlobal(ctx, "\xEF\xBB\xBF[\"x\"]");
    defer parsed.release();
    try std.testing.expect(try holds("bom", parsed.value.handle.ptr, "bom.length === 1 && bom[0] === 'x' ? 1 : 0"));
}

test "a SyntaxError is thrown in the caller's realm, with the new global's message" {
    const ctx = try realm();
    var body: struct {
        ctx: runtime.Context,
        result: protocol.Error!protocol.Owned = undefined,
        fn run(self: *@This()) void {
            self.result = protocol.parseJsonInNewGlobal(self.ctx, "{nope");
        }
    } = .{ .ctx = ctx };
    const thrown = thrownBy(&body) orelse return error.NothingThrown;
    defer ffi.v8_Global_Dispose(thrown);
    try std.testing.expectError(error.ExceptionPending, body.result);
    try std.testing.expect(try holds("jsonError", thrown,
        \\jsonError instanceof SyntaxError &&
        \\Object.getPrototypeOf(jsonError) === SyntaxError.prototype &&
        \\typeof jsonError.message === 'string' && jsonError.message.length > 0 ? 1 : 0
    ));
}

test "the new global is collected once the result is dropped, and no handle is left" {
    const ctx = try realm();
    const isolate = isolate_once.?;
    // One first, for what the first parse makes and later ones reuse.
    (try protocol.parseJsonInNewGlobal(ctx, "{}")).release();
    collect();
    const contexts_before = nativeContexts();
    const globals_before = ffi.v8_Debug_LiveContextGlobals();
    const handles_before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    for (0..16) |_| {
        const parsed = try protocol.parseJsonInNewGlobal(ctx, "{\"kty\":\"oct\",\"k\":\"AAAA\"}");
        parsed.release();
    }
    // Held, a result keeps its global alive.
    const kept = try protocol.parseJsonInNewGlobal(ctx, "{\"kept\":true}");
    collect();
    try std.testing.expect(nativeContexts() > contexts_before);
    try std.testing.expect(try holds("kept", kept.value.handle.ptr, "kept.kept === true ? 1 : 0"));
    _ = try evalInt("delete globalThis.kept; 1");
    kept.release();
    collect();
    const contexts_after = nativeContexts();
    if (contexts_after > contexts_before) {
        std.debug.print("native contexts {d} -> {d} after 17 parses dropped\n", .{ contexts_before, contexts_after });
        return error.ContextsLeaked;
    }
    try std.testing.expectEqual(globals_before, ffi.v8_Debug_LiveContextGlobals());
    try std.testing.expect(ffi.v8_Isolate_GetGlobalHandleBytes(isolate) <= handles_before);
}
