//! The page realm's engine half: the V8 side of the Engine operations a
//! Window's realm needs (AGENTS.md, "The engine boundary").
//!
//! The spec half stays with the host - `src/browser/Context.zig` keeps the map
//! of active timers and the animation frame callbacks, and runs HTML's steps
//! over them. What lives here is what only V8 can do: bind a native function
//! to a global, convert its arguments as WebIDL says, and call back into
//! script.

const std = @import("std");
const runtime = @import("runtime");
const ffi = @import("ffi.zig");
const js_scope = @import("js_scope.zig");
const context_manager = @import("context_manager.zig");
const isolate_ownership = @import("isolate_ownership.zig");

const EngineError = runtime.EngineError;
const JSValue = runtime.JSValue;

const log = std.log.scoped(.page_realm);

/// The V8 context a realm runs in, or null for one that has none any more (a
/// retired frame's).
fn contextOf(realm: runtime.Context) ?*ffi.Context {
    const engine_ctx = realm.engine_ctx orelse return null;
    return @ptrCast(@alignCast(engine_ctx));
}

/// An OWNED handle for a `Global<Value>*` this file acquired and hands over.
fn ownedHandle(value: *ffi.Value) JSValue {
    return .{ .handle = .{ .ptr = value, .needs_disposal = true } };
}

/// The V8 value a JSValue names, and whether it was made for the call (and so
/// is the caller's to dispose) or borrowed from the JSValue.
const Converted = struct {
    value: *ffi.Value,
    made: bool,

    fn release(self: Converted) void {
        if (self.made) ffi.v8_Global_Dispose(self.value);
    }
};

fn toV8(isolate: *ffi.Isolate, context: *ffi.Context, value: JSValue) EngineError!Converted {
    const conversions = @import("conversions.zig");
    const v8_value = conversions.toV8Value(JSValue, isolate, context, value) catch
        return EngineError.OperationFailed;
    // toV8Value hands back a handle as it is and an instance's wrapper
    // borrowed from the wrapper cache; anything else is a new Global.
    const made = switch (value) {
        .handle, .instance => false,
        else => true,
    };
    return .{ .value = v8_value, .made = made };
}

// ============================================================================
// invokeCallbackFunction
// ============================================================================

/// WebIDL "invoke a callback function", exception behavior "report".
///
/// The isolate runs microtasks automatically (the browser leaves V8's kAuto
/// policy in place), so when this call is the outermost one V8 performs the
/// checkpoint as `Call` returns - "clean up after running script" - and the
/// report below follows it, in WebIDL's order.
pub fn invokeCallbackFunction(
    realm: runtime.Context,
    callback: JSValue,
    this_arg: runtime.CallbackThis,
    args: []const JSValue,
    report: runtime.ReportExceptionFn,
    host: ?*anyopaque,
) EngineError!void {
    const context = contextOf(realm) orelse return EngineError.OperationFailed;
    const function: *ffi.Value = switch (callback) {
        .handle => |h| @ptrCast(@alignCast(h.ptr)),
        else => return EngineError.TypeError,
    };

    // Callbacks arrive from the event loop, where V8 has opened no
    // HandleScope and entered no context.
    const scope = js_scope.JsScope.initFromV8Context(context) orelse return EngineError.OperationFailed;
    defer scope.deinit();
    const isolate = scope.isolate;
    isolate_ownership.assertOwned(isolate, "page_realm.invokeCallbackFunction");

    // Step: "If ! IsCallable(F) is false" - only a [LegacyTreatNonObjectAsNull]
    // attribute's value can be - return undefined without calling it.
    if (!ffi.v8_Value_IsFunction(function)) return;

    // The callback this value. Null is undefined to v8_Function_CallCatching.
    var global_proxy: ?*ffi.Object = null;
    defer if (global_proxy) |g| ffi.v8_Object_Dispose(g);
    var this_value: ?Converted = null;
    defer if (this_value) |t| t.release();
    const receiver: ?*ffi.Value = switch (this_arg) {
        .undefined => null,
        // Context::Global is the global proxy: a Window realm's WindowProxy.
        .global_this => blk: {
            global_proxy = ffi.v8_Context_Global(context) orelse return EngineError.OperationFailed;
            break :blk @ptrCast(global_proxy.?);
        },
        .value => |v| blk: {
            this_value = try toV8(isolate, context, v);
            break :blk this_value.?.value;
        },
    };

    // The arguments, as V8 values. Most callbacks take one or two; the timer
    // handlers take whatever `any...` was given.
    var inline_buffer: [4]Converted = undefined;
    const converted: []Converted = if (args.len <= inline_buffer.len)
        inline_buffer[0..args.len]
    else
        realm.allocator.alloc(Converted, args.len) catch return EngineError.OutOfMemory;
    defer if (args.len > inline_buffer.len) realm.allocator.free(converted);
    var count: usize = 0;
    defer for (converted[0..count]) |c| c.release();
    for (args) |arg| {
        converted[count] = try toV8(isolate, context, arg);
        count += 1;
    }
    var inline_values: [4]*ffi.Value = undefined;
    const values: []*ffi.Value = if (args.len <= inline_values.len)
        inline_values[0..args.len]
    else
        realm.allocator.alloc(*ffi.Value, args.len) catch return EngineError.OutOfMemory;
    defer if (args.len > inline_values.len) realm.allocator.free(values);
    for (converted, values) |c, *v| v.* = c.value;

    var threw = false;
    // OWNED: the completion value, or what the call threw.
    const completion = ffi.v8_Function_CallCatching(
        context,
        function,
        receiver,
        @intCast(values.len),
        values.ptr,
        &threw,
    ) orelse return;
    defer ffi.v8_Global_Dispose(completion);
    if (!threw) return;

    reportThrown(context, completion, report, host);
}

/// Hand a thrown value to the host's "report an exception", with what V8 can
/// say about where it was thrown.
fn reportThrown(context: *ffi.Context, exception: *ffi.Value, report: runtime.ReportExceptionFn, host: ?*anyopaque) void {
    const info = ffi.v8_Exception_GetErrorInfo(context, exception);
    defer ffi.v8_FreeErrorInfo(info);
    var error_info = runtime.ErrorInfo{
        .message = "Uncaught exception",
        .filename = "",
        .lineno = 0,
        .colno = 0,
        // Borrowed: the caller's completion Global outlives the report.
        .error_value = .{ .handle = .{ .ptr = exception, .needs_disposal = false } },
    };
    if (info) |i| {
        if (i.getMessage()) |m| error_info.message = m;
        if (i.getResourceName()) |r| error_info.filename = r;
        if (i.line_number > 0) error_info.lineno = @intCast(i.line_number);
        // V8 counts columns from 0; ErrorEvent.colno counts from 1.
        if (i.column_number >= 0) error_info.colno = @intCast(i.column_number + 1);
    }
    report(host, &error_info);
}

// ============================================================================
// installWindowOperations: the window's native timers and animation frames
// ============================================================================

/// The host's steps for every Window realm of this agent (one agent per
/// thread). Set by installWindowOperations; a frame's realm, created later by
/// context_manager, reads it through the child-window hooks below.
threadlocal var window_operations: ?*const runtime.WindowOperations = null;

const NativeOperation = struct {
    name: []const u8,
    callback: ffi.FunctionCallback,
    length: i32,
};

/// The Window members bound natively (see installWindowOperations'
/// declaration for why these are not the generated binding).
const window_operation_natives = [_]NativeOperation{
    .{ .name = "setTimeout", .callback = setTimeoutCallback, .length = 1 },
    .{ .name = "clearTimeout", .callback = clearTimeoutCallback, .length = 0 },
    .{ .name = "setInterval", .callback = setIntervalCallback, .length = 1 },
    .{ .name = "clearInterval", .callback = clearTimeoutCallback, .length = 0 },
    .{ .name = "requestAnimationFrame", .callback = requestAnimationFrameCallback, .length = 1 },
    .{ .name = "cancelAnimationFrame", .callback = cancelAnimationFrameCallback, .length = 1 },
};

pub fn installWindowOperations(realm: runtime.Context, operations: *const runtime.WindowOperations) EngineError!void {
    const context = contextOf(realm) orelse return EngineError.OperationFailed;
    const scope = js_scope.JsScope.initFromV8Context(context) orelse return EngineError.OperationFailed;
    defer scope.deinit();
    const global = ffi.v8_Context_Global(context) orelse return EngineError.OperationFailed;
    // Owned, and a handle to the global keeps the page alive.
    defer ffi.v8_Object_Dispose(global);

    window_operations = operations;
    try defineNatives(scope.isolate, context, global, &window_operation_natives);

    // Every window created under this one - an iframe's, a popup's - gets the
    // same operations, and gives up its timers when its document goes.
    context_manager.setChildContextGlobalsCallback(defineOnChildWindow);
    context_manager.setChildWindowCleanupCallback(childWindowDestroyed);
}

/// Define each of `natives` on `global`, as functions of `context`'s realm.
fn defineNatives(isolate: *ffi.Isolate, context: *ffi.Context, global: *ffi.Object, natives: []const NativeOperation) EngineError!void {
    for (natives) |native| {
        // Every one of these returns a Global the caller owns; the function
        // keeps its template, and the property keeps the function.
        const template = ffi.v8_FunctionTemplate_New(isolate, native.callback, null) orelse return EngineError.OperationFailed;
        defer ffi.v8_FunctionTemplate_Dispose(template);
        ffi.v8_FunctionTemplate_SetLength(template, native.length);
        const function = ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return EngineError.OperationFailed;
        defer ffi.v8_Function_Dispose(function);
        const key = ffi.v8_String_NewFromUtf8(isolate, native.name.ptr, @intCast(native.name.len)) orelse return EngineError.OperationFailed;
        defer ffi.v8_String_Dispose(key);
        _ = ffi.v8_Object_Set(global, context, @ptrCast(key), @ptrCast(function));
    }
}

/// context_manager's child-context hook: a frame's or a popup's window gets
/// the operations the top-level window has. Without it every frame ran the
/// WebIDL stubs - setTimeout threw NotSupportedError in every iframe.
fn defineOnChildWindow(isolate: *ffi.Isolate, context: *ffi.Context, global: *ffi.Object) void {
    if (window_operations == null) return;
    defineNatives(isolate, context, global, &window_operation_natives) catch |err| {
        log.warn("a frame's window operations were not defined: {}", .{err});
    };
}

/// context_manager's child-window cleanup hook, called while the frame's
/// context is still registered.
fn childWindowDestroyed(context: *ffi.Context) void {
    const operations = window_operations orelse return;
    const realm = context_manager.get(context) orelse return;
    operations.windowDestroyed(realm);
}

/// The realm of the function being called - V8 enters a FunctionTemplate
/// function's own context for the call - and so the Window whose method it is.
fn callingRealm(isolate: *ffi.Isolate) ?runtime.Context {
    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return null;
    // Owned: GetCurrentContext allocates a Global per call.
    defer ffi.v8_Context_Dispose(context);
    return context_manager.get(context);
}

/// `v8_Integer_New` allocates a Global and SetReturnValue only reads it, so
/// the caller still owns it - an undisposed one per return is how 14,774
/// `v8_Number_New` handles leaked in a single timers file.
fn setIntegerReturn(info: *const ffi.FunctionCallbackInfo, isolate: *ffi.Isolate, value: i32) void {
    const boxed = ffi.v8_Integer_New(isolate, value);
    defer ffi.v8_Global_Dispose(@ptrCast(boxed));
    info.setReturnValue(@ptrCast(boxed));
}

fn throwTypeError(isolate: *ffi.Isolate, message: []const u8) void {
    // Both are owned Globals; ThrowException takes its own reference.
    const text = ffi.v8_String_NewFromUtf8(isolate, message.ptr, @intCast(message.len)) orelse return;
    defer ffi.v8_String_Dispose(text);
    const exception = ffi.v8_Exception_TypeError(@ptrCast(text)) orelse return;
    defer ffi.v8_Global_Dispose(exception);
    ffi.v8_Isolate_ThrowException(isolate, exception);
}

fn setTimeoutCallback(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    timerInitializationFromCall(info, false);
}

fn setIntervalCallback(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    timerInitializationFromCall(info, true);
}

/// The binding of `long setTimeout(TimerHandler handler, optional long
/// timeout = 0, any... arguments)` and of setInterval: WebIDL argument
/// conversion, then the host's timer initialization steps.
fn timerInitializationFromCall(info: *const ffi.FunctionCallbackInfo, repeat: bool) void {
    const isolate = info.getIsolate();
    const argc: usize = @intCast(@max(info.length(), 0));

    // `handler` is required: WebIDL throws a TypeError for a call without it.
    if (argc < 1) {
        return throwTypeError(isolate, if (repeat)
            "Failed to execute 'setInterval' on 'Window': 1 argument required, but only 0 present."
        else
            "Failed to execute 'setTimeout' on 'Window': 1 argument required, but only 0 present.");
    }

    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer ffi.v8_Context_Dispose(context);

    // TimerHandler is (TrustedScript or DOMString or Function). A callable
    // is the Function member; anything else is converted by ToString HERE, at
    // the call - which runs script (evil-spec-example.any.js has a toString()
    // that itself calls setTimeout) and can throw. A null from ToString means
    // it threw: the exception is pending, and returning rethrows it.
    const handler_value = info.get(0);
    const handler: runtime.WindowTimerHandler = if (ffi.v8_Value_IsFunction(handler_value))
        .{ .function = ownedHandle(handler_value) }
    else blk: {
        defer ffi.v8_Global_Dispose(handler_value);
        const source = ffi.v8_Value_ToString(handler_value, context) orelse return;
        // A Global<Value> of the string for the host, which releases it with
        // releaseValue; the Global<String> goes back through its own dispose,
        // which keeps the live-string counter balanced.
        defer ffi.v8_String_Dispose(source);
        const value = ffi.v8_Global_Clone(@ptrCast(source)) orelse return;
        break :blk .{ .string = ownedHandle(value) };
    };
    var handler_owned = true;
    defer if (handler_owned) switch (handler) {
        .function, .string => |h| ffi.v8_Global_Dispose(@ptrCast(@alignCast(h.handle.ptr))),
    };

    // `optional long timeout = 0` is ToInt32: ToNumber - script again, and it
    // can throw - then modulo 2^32, so 2**32 is 0 rather than 49 days.
    var timeout: i32 = 0;
    if (argc >= 2) {
        const timeout_value = info.get(1);
        defer ffi.v8_Global_Dispose(timeout_value);
        if (!ffi.v8_Value_IsUndefined(timeout_value) and
            !ffi.v8_Value_ToInt32(timeout_value, context, &timeout)) return;
    }

    const operations = window_operations orelse return setIntegerReturn(info, isolate, 0);
    const realm = context_manager.get(context) orelse return setIntegerReturn(info, isolate, 0);

    // `any... arguments`, for every run of a Function handler. Each is an
    // owned Global handed to the host; the slice is only lent for the call.
    const arguments = realm.allocator.alloc(JSValue, argc -| 2) catch return setIntegerReturn(info, isolate, 0);
    defer realm.allocator.free(arguments);
    for (arguments, 2..) |*argument, i| argument.* = ownedHandle(info.get(@intCast(i)));

    handler_owned = false;
    const id = operations.initializeTimer(realm, handler, timeout, arguments, repeat);
    setIntegerReturn(info, isolate, id);
}

/// clearTimeout(id) and clearInterval(id): one algorithm, "clear the timer
/// with id from the map of setTimeout and setInterval IDs", so either clears
/// either kind.
fn clearTimeoutCallback(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    if (info.length() < 1) return;

    const id_value = info.get(0);
    defer ffi.v8_Global_Dispose(id_value);
    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer ffi.v8_Context_Dispose(context);

    // `optional long id = 0`: ToInt32, like the timeout - so "5" is 5, and a
    // throwing valueOf propagates.
    var id: i32 = 0;
    if (!ffi.v8_Value_ToInt32(id_value, context, &id)) return;

    const operations = window_operations orelse return;
    // The function's realm: an id names a timer in THIS window's map only.
    const realm = context_manager.get(context) orelse return;
    operations.clearTimer(realm, id);
}

/// requestAnimationFrame(callback).
fn requestAnimationFrameCallback(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();

    // A missing or non-callable argument is a TypeError per WebIDL, but these
    // natives report argument problems by returning the 0 sentinel rather than
    // throwing, and a lone thrower here would be the odd one out.
    if (info.length() < 1) return setIntegerReturn(info, isolate, 0);

    // OWNED from here: handed to the host, or disposed on the way out.
    const callback_value = info.get(0);
    if (!ffi.v8_Value_IsFunction(callback_value)) {
        ffi.v8_Global_Dispose(callback_value);
        return setIntegerReturn(info, isolate, 0);
    }
    const operations = window_operations orelse {
        ffi.v8_Global_Dispose(callback_value);
        return setIntegerReturn(info, isolate, 0);
    };
    // The function's realm: this window's map of animation frame callbacks.
    const realm = callingRealm(isolate) orelse {
        ffi.v8_Global_Dispose(callback_value);
        return setIntegerReturn(info, isolate, 0);
    };

    const handle = operations.requestAnimationFrame(realm, ownedHandle(callback_value));
    setIntegerReturn(info, isolate, @intCast(handle));
}

/// cancelAnimationFrame(handle). An unknown handle must do nothing.
fn cancelAnimationFrameCallback(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    if (info.length() < 1) return;
    const operations = window_operations orelse return;

    const handle_value = info.get(0);
    defer ffi.v8_Global_Dispose(handle_value);
    if (!ffi.v8_Value_IsNumber(handle_value)) return;
    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer ffi.v8_Context_Dispose(context);
    const as_f64 = ffi.v8_Value_NumberValue(handle_value, context);
    if (std.math.isNan(as_f64) or as_f64 < 1 or as_f64 > @as(f64, @floatFromInt(std.math.maxInt(u32)))) return;

    const realm = context_manager.get(context) orelse return;
    operations.cancelAnimationFrame(realm, @intFromFloat(as_f64));
}
