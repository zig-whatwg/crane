//! Realm operations as V8 implements them (engine.zig): runTaskInRealm,
//! runInRealm, createDOMException, releaseValue, structured serialization for
//! storage, promise rejection - what the engine protocol's operations of the
//! same names call. (Running a classic script and the microtask checkpoint are
//! the protocol's own, tested in page_realm_operations_test.zig.)

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

/// A live isolate with an entered context and a runtime realm over it, one for
/// the whole file, as in platform_task_pump_test.zig - V8 is never torn down
/// here. Microtasks are explicit, as the browser runs them.
var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;
var realm_once: ?*runtime.Realm = null;
var data_once: ?*runtime.ContextData = null;

fn realm() !runtime.Context {
    if (data_once) |d| return d;
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    ffi.v8_Isolate_SetMicrotasksPolicy(i, @intFromEnum(ffi.MicrotasksPolicy.Explicit));
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    const r = try runtime.Realm.init(std.heap.page_allocator, .{ .engine_realm = context, .agent = @ptrCast(i) });
    const data = try std.heap.page_allocator.create(runtime.ContextData);
    data.* = try runtime.ContextData.init(std.heap.page_allocator, .{
        .engine_ctx = context,
        .realm = r,
    });
    isolate_once = i;
    context_once = context;
    realm_once = r;
    data_once = data;
    return data;
}

/// Run `source` in the realm's context, as a test's own setup does - not an
/// engine operation.
fn runScript(source: []const u8) !void {
    const i = isolate_once.?;
    const context = context_once.?;
    const code = ffi.v8_String_NewFromUtf8(i, source.ptr, @intCast(source.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(code);
    const script = ffi.v8_Script_Compile(context, code) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    const value = ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
    ffi.v8_Value_Dispose(value);
}

/// A global's value as an integer, read by script.
fn globalInt(name: []const u8) !i32 {
    const i = isolate_once.?;
    const context = context_once.?;
    const code = ffi.v8_String_NewFromUtf8(i, name.ptr, @intCast(name.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(code);
    const script = ffi.v8_Script_Compile(context, code) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    const value = ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, context);
}

fn setFromTask(data: ?*anyopaque) void {
    const ran: *bool = @ptrCast(@alignCast(data.?));
    ran.* = true;
    // Script runs in the entered realm: a task can call into it.
    runScript("globalThis.fromTask = 3;") catch {};
}

test "a task and a synchronous step run inside the realm" {
    const ctx = try realm();
    var ran = false;
    try v8.engine.v8RunTaskInRealm(ctx, setFromTask, &ran);
    try std.testing.expect(ran);
    try std.testing.expectEqual(@as(i32, 3), try globalInt("globalThis.fromTask"));

    var ran_sync = false;
    try v8.engine.v8RunInRealm(ctx, setFromTask, &ran_sync);
    try std.testing.expect(ran_sync);
}

test "a DOMException is created as an owned value and released" {
    const ctx = try realm();
    // With no DOMException constructor in the realm, creation fails - it is
    // reported, not papered over.
    try runScript("delete globalThis.DOMException;");
    try std.testing.expectError(error.OperationFailed, v8.engine.v8CreateDOMException(ctx, "AbortError", "aborted"));

    // The realm's constructor makes it: `new DOMException(message, name)`.
    try runScript("globalThis.DOMException = class { constructor(m, n) { this.message = m; this.name = n; } };");
    const made = try v8.engine.v8CreateDOMException(ctx, "AbortError", "aborted");
    defer v8.engine.v8ReleaseValue(made);
    try std.testing.expect(made == .handle);
    try std.testing.expect(made.handle.needs_disposal);

    // Put it where script can look at it.
    const context = context_once.?;
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate_once.?, "made", 4) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    _ = ffi.v8_Object_Set(global, context, @ptrCast(key), @ptrCast(@alignCast(made.handle.ptr)));
    try std.testing.expectEqual(@as(i32, 1), try globalInt("globalThis.made.name === 'AbortError' && globalThis.made.message === 'aborted' ? 1 : 0"));

    // Release takes any value, owned or not.
    v8.engine.v8ReleaseValue(.undefined);
    v8.engine.v8ReleaseValue(.{ .number = 1 });
}

test "an object survives StructuredSerializeForStorage and StructuredDeserialize" {
    const ctx = try realm();
    try runScript("globalThis.state = { a: 1, b: [2, 3], c: 'x' };");

    // The object, as a handle the caller owns.
    const context = context_once.?;
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate_once.?, "state", 5) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    const state = ffi.v8_Object_Get(global, context, @ptrCast(key)) orelse return error.GetFailed;
    defer ffi.v8_Value_Dispose(state);

    const bytes = try v8.engine.v8StructuredSerializeForStorage(ctx, .{ .handle = .{ .ptr = state, .needs_disposal = false } }, std.testing.allocator);
    defer std.testing.allocator.free(bytes);
    try std.testing.expect(bytes.len > 0);

    const copy = try v8.engine.v8StructuredDeserialize(ctx, bytes);
    defer v8.engine.v8ReleaseValue(copy);
    const copy_key = ffi.v8_String_NewFromUtf8(isolate_once.?, "copy", 4) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(copy_key);
    _ = ffi.v8_Object_Set(global, context, @ptrCast(copy_key), @ptrCast(@alignCast(copy.handle.ptr)));
    try std.testing.expectEqual(@as(i32, 1), try globalInt("globalThis.copy !== globalThis.state && globalThis.copy.a === 1 && globalThis.copy.b[1] === 3 && globalThis.copy.c === 'x' ? 1 : 0"));

    // Primitives are the caller's to keep, not the engine's to serialize.
    try std.testing.expectError(error.DataCloneError, v8.engine.v8StructuredSerializeForStorage(ctx, .{ .number = 1 }, std.testing.allocator));
}

test "a promise is rejected with any value, and marked as handled" {
    const ctx = try realm();
    const handle = try v8.engine.v8CreatePromise(ctx.engine_ctx.?, std.testing.allocator);
    defer v8.engine.v8DestroyPromiseHandle(handle, std.testing.allocator);
    const promise: *ffi.Promise = @ptrCast(@alignCast(v8.engine.v8GetPromiseObject(handle)));
    ffi.v8_Promise_MarkAsHandled(@ptrCast(promise));
    try v8.engine.v8RejectPromiseWithValue(handle, .{ .number = 42 });
    try std.testing.expectEqual(@as(c_int, 2), ffi.v8_Promise_State(promise));
    const result = ffi.v8_Promise_Result(promise) orelse return error.NoResult;
    defer ffi.v8_Value_Dispose(result);
    try std.testing.expectEqual(@as(i32, 42), ffi.v8_Value_Int32Value(result, context_once.?));
}

test "an empty sequence is a new empty array" {
    const ctx = try realm();
    const array = try v8.webidl_conversions.createSequenceOfValues(ctx, &.{});
    defer v8.engine.v8ReleaseValue(array);
    try std.testing.expect(array.handle.needs_disposal);
    try std.testing.expectEqual(@as(u32, 0), ffi.v8_Array_Length(@ptrCast(@alignCast(array.handle.ptr))));
}

test "a realm records its document URL, replacing and forgetting it" {
    const ctx = try realm();
    try std.testing.expect(ctx.documentUrl() == null);
    try ctx.setDocumentUrl("https://example.test/a.html");
    try ctx.setDocumentUrl("https://example.test/b.html");
    try std.testing.expectEqualStrings("https://example.test/b.html", ctx.documentUrl().?);
    ctx.clearDocumentUrl();
    try std.testing.expect(ctx.documentUrl() == null);
}

test "defining an interface object on the global leaves no handle behind" {
    _ = try realm();
    const isolate = isolate_once.?;
    const context = context_once.?;
    // The first definition makes the template and the interface object, which
    // the isolate and the context keep; every later one redefines the same
    // property to the same function.
    v8.interface_bindings.Event.registerGlobal(isolate, context, "Event");
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    for (0..32) |_| v8.interface_bindings.Event.registerGlobal(isolate, context, "Event");
    const after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    if (after > before) {
        std.debug.print("global handles {d} -> {d} bytes over 32 registerGlobal calls\n", .{ before, after });
        return error.HandlesLeaked;
    }
    try std.testing.expectEqual(@as(i32, 1), try globalInt("typeof Event === 'function' ? 1 : 0"));
}

test "a context keeps its registry key across compacting garbage collections" {
    _ = try realm();
    const isolate = isolate_once.?;
    // Contexts interleaved with old-space garbage: once the garbage is gone a
    // full collection evacuates the sparse pages, moving whatever lives there.
    // context_manager keys realms by this value, so it must not move with them.
    var contexts: [16]*ffi.Context = undefined;
    var keys: [16]?*anyopaque = undefined;
    for (&contexts, &keys) |*c, *k| {
        try runScript("globalThis.junk = (globalThis.junk || []).concat(Array.from({ length: 20000 }, (_, i) => ({ i })));");
        ffi.v8_Isolate_RequestGarbageCollection(isolate);
        c.* = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
        k.* = ffi.v8_Context_GetRawAddress(c.*);
    }
    defer for (contexts) |c| ffi.v8_Context_Dispose(c);
    try runScript("globalThis.junk = null;");
    for (0..3) |_| ffi.v8_Isolate_RequestGarbageCollection(isolate);
    for (contexts, keys) |c, k| try std.testing.expectEqual(k, ffi.v8_Context_GetRawAddress(c));
}
