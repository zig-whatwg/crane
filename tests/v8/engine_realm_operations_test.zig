//! The Engine table's realm operations, as V8 implements them:
//! runClassicScript, performMicrotaskCheckpoint, runTaskInRealm, runInRealm,
//! createDOMException and releaseValue.
//!
//! These are the seam code outside the adapter uses instead of V8 (AGENTS.md,
//! "The engine boundary"): named after HTML and WebIDL, taking the realm as a
//! runtime.Context, and handing nothing engine-shaped back except values whose
//! ownership the operation's declaration states.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

const engine = &v8.engine.v8_engine_interface;

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
    const r = try runtime.Realm.init(std.heap.page_allocator, .{ .v8_context = context, .isolate = i });
    const data = try std.heap.page_allocator.create(runtime.ContextData);
    data.* = try runtime.ContextData.init(std.heap.page_allocator, .{
        .engine = engine,
        .engine_ctx = context,
        .realm = r,
    });
    isolate_once = i;
    context_once = context;
    realm_once = r;
    data_once = data;
    return data;
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

const Reports = struct {
    count: usize = 0,
    message: [256]u8 = undefined,
    message_len: usize = 0,
    filename: [256]u8 = undefined,
    filename_len: usize = 0,
    lineno: u32 = 0,
    colno: u32 = 0,
    had_value: bool = false,

    fn report(host: ?*anyopaque, info: *const runtime.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        self.message_len = @min(info.message.len, self.message.len);
        @memcpy(self.message[0..self.message_len], info.message[0..self.message_len]);
        self.filename_len = @min(info.filename.len, self.filename.len);
        @memcpy(self.filename[0..self.filename_len], info.filename[0..self.filename_len]);
        self.lineno = info.lineno;
        self.colno = info.colno;
        self.had_value = info.error_value != null;
    }

    fn messageText(self: *const Reports) []const u8 {
        return self.message[0..self.message_len];
    }
};

test "a classic script runs, and what it throws is reported with its location" {
    const ctx = try realm();
    var reports: Reports = .{};
    try engine.runClassicScript.?(ctx, "globalThis.ran = 7;\nthrow new TypeError('boom');", "https://example.test/s.js", Reports.report, &reports);
    try std.testing.expectEqual(@as(i32, 7), try globalInt("globalThis.ran"));
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expect(std.mem.indexOf(u8, reports.messageText(), "boom") != null);
    try std.testing.expectEqualStrings("https://example.test/s.js", reports.filename[0..reports.filename_len]);
    try std.testing.expectEqual(@as(u32, 2), reports.lineno);
    try std.testing.expect(reports.colno > 0);
    try std.testing.expect(reports.had_value);
}

test "a parse error is reported and nothing runs" {
    const ctx = try realm();
    var reports: Reports = .{};
    try engine.runClassicScript.?(ctx, "globalThis.parsed = 1; )(", null, Reports.report, &reports);
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expect(std.mem.indexOf(u8, reports.messageText(), "SyntaxError") != null);
    try std.testing.expectEqual(@as(i32, 0), try globalInt("globalThis.parsed | 0"));
}

test "a normal completion reports nothing" {
    const ctx = try realm();
    var reports: Reports = .{};
    try engine.runClassicScript.?(ctx, "globalThis.fine = 1;", null, Reports.report, &reports);
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    try std.testing.expectEqual(@as(i32, 1), try globalInt("globalThis.fine"));
}

test "a microtask checkpoint runs the jobs a script queued, and not before" {
    const ctx = try realm();
    var reports: Reports = .{};
    try engine.runClassicScript.?(ctx, "globalThis.job = 0; Promise.resolve().then(() => { globalThis.job = 1; });", null, Reports.report, &reports);
    try std.testing.expectEqual(@as(i32, 0), try globalInt("globalThis.job"));
    try engine.performMicrotaskCheckpoint.?(ctx);
    try std.testing.expectEqual(@as(i32, 1), try globalInt("globalThis.job"));
}

fn setFromTask(data: ?*anyopaque) void {
    const ran: *bool = @ptrCast(@alignCast(data.?));
    ran.* = true;
    // Script runs in the entered realm: a task can call into it.
    var reports: Reports = .{};
    engine.runClassicScript.?(data_once.?, "globalThis.fromTask = 3;", null, Reports.report, &reports) catch {};
}

test "a task and a synchronous step run inside the realm" {
    const ctx = try realm();
    var ran = false;
    try engine.runTaskInRealm.?(ctx, setFromTask, &ran);
    try std.testing.expect(ran);
    try std.testing.expectEqual(@as(i32, 3), try globalInt("globalThis.fromTask"));

    var ran_sync = false;
    try engine.runInRealm.?(ctx, setFromTask, &ran_sync);
    try std.testing.expect(ran_sync);
}

test "a DOMException is created as an owned value and released" {
    const ctx = try realm();
    var reports: Reports = .{};
    // With no DOMException constructor in the realm, creation fails - it is
    // reported, not papered over.
    try engine.runClassicScript.?(ctx, "delete globalThis.DOMException;", null, Reports.report, &reports);
    try std.testing.expectError(error.OperationFailed, engine.createDOMException.?(ctx, "AbortError", "aborted"));

    // The realm's constructor makes it: `new DOMException(message, name)`.
    try engine.runClassicScript.?(ctx, "globalThis.DOMException = class { constructor(m, n) { this.message = m; this.name = n; } };", null, Reports.report, &reports);
    const made = try engine.createDOMException.?(ctx, "AbortError", "aborted");
    defer engine.releaseValue.?(made);
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
    try std.testing.expectEqual(@as(usize, 0), reports.count);

    // Release takes any value, owned or not.
    engine.releaseValue.?(.undefined);
    engine.releaseValue.?(.{ .number = 1 });
}

test "an object survives StructuredSerializeForStorage and StructuredDeserialize" {
    const ctx = try realm();
    var reports: Reports = .{};
    try engine.runClassicScript.?(ctx, "globalThis.state = { a: 1, b: [2, 3], c: 'x' };", null, Reports.report, &reports);

    // The object, as a handle the caller owns.
    const context = context_once.?;
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate_once.?, "state", 5) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    const state = ffi.v8_Object_Get(global, context, @ptrCast(key)) orelse return error.GetFailed;
    defer ffi.v8_Value_Dispose(state);

    const bytes = try engine.structuredSerializeForStorage.?(ctx, .{ .handle = .{ .ptr = state, .needs_disposal = false } }, std.testing.allocator);
    defer std.testing.allocator.free(bytes);
    try std.testing.expect(bytes.len > 0);

    const copy = try engine.structuredDeserialize.?(ctx, bytes);
    defer engine.releaseValue.?(copy);
    const copy_key = ffi.v8_String_NewFromUtf8(isolate_once.?, "copy", 4) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(copy_key);
    _ = ffi.v8_Object_Set(global, context, @ptrCast(copy_key), @ptrCast(@alignCast(copy.handle.ptr)));
    try std.testing.expectEqual(@as(i32, 1), try globalInt("globalThis.copy !== globalThis.state && globalThis.copy.a === 1 && globalThis.copy.b[1] === 3 && globalThis.copy.c === 'x' ? 1 : 0"));

    // Primitives are the caller's to keep, not the engine's to serialize.
    try std.testing.expectError(error.DataCloneError, engine.structuredSerializeForStorage.?(ctx, .{ .number = 1 }, std.testing.allocator));
}

test "a promise is rejected with any value, and marked as handled" {
    const ctx = try realm();
    const handle = try engine.createPromise(ctx.engine_ctx.?, std.testing.allocator);
    defer engine.destroyPromiseHandle.?(handle, std.testing.allocator);
    engine.markPromiseAsHandled.?(handle);
    try engine.rejectPromiseWithValue.?(handle, .{ .number = 42 });
    const promise: *ffi.Promise = @ptrCast(@alignCast(engine.getPromiseObject(handle)));
    try std.testing.expectEqual(@as(c_int, 2), ffi.v8_Promise_State(promise));
    const result = ffi.v8_Promise_Result(promise) orelse return error.NoResult;
    defer ffi.v8_Value_Dispose(result);
    try std.testing.expectEqual(@as(i32, 42), ffi.v8_Value_Int32Value(result, context_once.?));
}

test "an empty sequence of platform objects is a new empty array" {
    const ctx = try realm();
    const array = try engine.createSequenceOfPlatformObjects.?(ctx, &.{});
    defer engine.releaseValue.?(array);
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

test "the adapter registers its table as the build's configured engine" {
    v8.snapshot_loader.registerConfiguredEngine();
    try std.testing.expect(runtime.configuredEngine() == engine);
}

test "a Uint8Array leaves no handle behind but its own" {
    _ = try realm();
    const isolate = isolate_once.?;
    // V8's own live count, so a leak shows whoever allocated it. Many rounds,
    // so one leaked handle per call cannot hide in anything else's churn.
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    for (0..32) |_| {
        const made = try engine.createUint8Array.?(context_once.?, "crane");
        const array: *ffi.Value = @ptrCast(@alignCast(made));
        try std.testing.expectEqual(@as(usize, 5), ffi.v8_TypedArray_Length(array));
        ffi.v8_Value_Dispose(array);
    }
    try std.testing.expect(ffi.v8_Isolate_GetGlobalHandleBytes(isolate) <= before);
}
