//! V8 Engine Interface Implementation
//!
//! This module provides the V8 implementation of the abstract EngineInterface.
//! It bridges the gap between engine-agnostic WebIDL impls and V8-specific code.
//!
//! ## Usage
//!
//! ```zig
//! const v8_engine = @import("v8").engine;
//! const runtime = @import("runtime");
//!
//! // Create context with V8 engine
//! var ctx_data = try runtime.ContextData.init(allocator, .{
//!     .engine = &v8_engine.v8_engine_interface,
//!     .engine_ctx = isolate,  // V8 Isolate pointer
//! });
//! ```

const std = @import("std");
const runtime = @import("runtime");
const EngineInterface = runtime.EngineInterface;
const EngineError = runtime.EngineError;

// V8 FFI and helpers
const ffi = @import("ffi.zig");
const js_scope = @import("js_scope.zig");
const v8_conversions = @import("conversions.zig");
const promise_mod = @import("promise.zig");
const event_loop_mod = @import("event_loop.zig");
const callback_wrapper_mod = @import("callback_wrapper.zig");
const pointer_tag = @import("pointer_tag.zig");
const TaggedPointer = pointer_tag.TaggedPointer;
const DebugAssertions = pointer_tag.DebugAssertions;

// Logging for V8 exceptions
const log = std.log.scoped(.v8_engine);

// ============================================================================
// V8 Exception Logging Helpers
// ============================================================================

/// Log detailed V8 error information
/// Call this when a _Safe function returns an error to get full exception details.
fn logV8Error(error_info: *const ffi.V8ErrorInfo, operation: []const u8) void {
    if (!error_info.has_error) return;

    const message = error_info.getMessage() orelse "Unknown error";
    const resource = error_info.getResourceName() orelse "<unknown>";

    if (error_info.line_number >= 0) {
        log.err("{s} failed at {s}:{d}:{d}: {s}", .{
            operation,
            resource,
            error_info.line_number,
            error_info.column_number,
            message,
        });
    } else {
        log.err("{s} failed: {s}", .{ operation, message });
    }

    // Log source line if available
    if (error_info.getSourceLine()) |source_line| {
        log.err("  Source: {s}", .{source_line});
        // Add caret pointing to error column
        if (error_info.column_number >= 0 and error_info.column_number < 200) {
            var caret_buf: [256]u8 = undefined;
            const col: usize = @intCast(error_info.column_number);
            @memset(caret_buf[0..col], ' ');
            caret_buf[col] = '^';
            log.err("  {s}", .{caret_buf[0 .. col + 1]});
        }
    }

    // Log stack trace if available
    if (error_info.getStackTrace()) |stack| {
        log.err("Stack trace:\n{s}", .{stack});
    }
}

/// V8 implementation of the abstract EngineInterface
pub const v8_engine_interface: EngineInterface = .{
    .wrapAsyncIterator = v8WrapAsyncIterator,
    .createPromise = v8CreatePromise,
    .resolvePromise = v8ResolvePromise,
    .rejectPromise = v8RejectPromise,
    .getPromiseObject = v8GetPromiseObject,
    .destroyPromiseHandle = v8DestroyPromiseHandle,
    .createString = v8CreateString,
    .getPropertyTruthy = v8GetPropertyTruthy,
    .runClassicScript = v8RunClassicScript,
    .performMicrotaskCheckpoint = v8PerformMicrotaskCheckpoint,
    .runTaskInRealm = v8RunTaskInRealm,
    .runInRealm = v8RunInRealm,
    .createDOMException = v8CreateDOMException,
    .releaseValue = v8ReleaseValue,
    .structuredSerializeForStorage = v8StructuredSerializeForStorage,
    .structuredDeserialize = v8StructuredDeserialize,
    .resolvePromiseWithInstance = v8ResolvePromiseWithInstance,
    .rejectPromiseWithValue = v8RejectPromiseWithValue,
    .markPromiseAsHandled = v8MarkPromiseAsHandled,
    .createSequenceOfPlatformObjects = v8CreateSequenceOfPlatformObjects,
    .relevantGlobalObject = v8RelevantGlobalObject,
    // ---- lane: page-realm ----
    // ---- end lane: page-realm ----
    // ---- lane: runtime-impls ----
    .createObservableArray = @import("observable_array.zig").createObservableArray,
    .queueMicrotask = @import("value_construction.zig").queueMicrotask,
    .createResolvedPromise = @import("value_construction.zig").createResolvedPromise,
    .createRejectedPromise = @import("value_construction.zig").createRejectedPromise,
    .createSimpleException = @import("value_construction.zig").createSimpleException,
    .createDictionaryObject = @import("value_construction.zig").createDictionaryObject,
    .currentRealm = @import("current_realm.zig").currentRealm,
    .describeArrayBufferView = @import("array_buffer_views.zig").describeArrayBufferView,
    .writeIntoArrayBufferView = @import("array_buffer_views.zig").writeIntoArrayBufferView,
    .callUserObjectOperation = @import("callback_interfaces.zig").callUserObjectOperation,
    .convertToUnrestrictedDouble = @import("webidl_conversions_numeric.zig").convertToUnrestrictedDouble,
    .takeCallbackFunction = @import("callback_interfaces.zig").takeCallbackFunction,
    // ---- end lane: runtime-impls ----
    .getPropertyBoolean = v8GetPropertyBoolean,
    .getPropertyInstance = v8GetPropertyInstance,
    .createArrayBuffer = v8CreateArrayBuffer,
    .createUint8Array = v8CreateUint8Array,
    .parseJson = v8ParseJson,
    .wrapInstance = v8WrapInstance,
    .isString = v8IsString,
    .extractString = v8ExtractString,
    .setPropertyOnObject = v8SetPropertyOnObject,
    .defineOwnPropertyOnObject = v8DefineOwnPropertyOnObject,
    .convertJSValueToEngine = v8ConvertJSValueToEngine,
    .createStringArray = v8CreateStringArray,
    .createEventLoop = v8CreateEventLoop,
    .destroyEventLoop = v8DestroyEventLoop,
    .createCallbackWrapper = v8CreateCallbackWrapper,
    .invokeCallback = v8InvokeCallback,
    .destroyCallbackWrapper = v8DestroyCallbackWrapper,
    .requestGarbageCollection = v8RequestGarbageCollection,
    .scheduleOnMainThread = v8ScheduleOnMainThread,
    .invokeStreamCallback = v8InvokeStreamCallback,
    .getWrapperForInstance = v8GetWrapperForInstance,
    .chainPromiseHandlers = v8ChainPromiseHandlers,
    .compileScript = v8CompileScript,
    .runScript = v8RunScript,
    .compileModule = v8CompileModule,
    .runModule = v8RunModule,
    .disposeScript = v8DisposeScript,
    .disposeModule = v8DisposeModule,
    .runModuleAsync = v8RunModuleAsync,
    .hasTopLevelAwait = v8HasTopLevelAwait,
    .freeze = v8Freeze,
    .thaw = v8Thaw,
    .isFrozen = v8IsFrozen,
    .invokeForEach = v8InvokeForEach,
    .getCollectionLength = v8GetCollectionLength,
    .getCollectionElement = v8GetCollectionElement,
    .name = "V8",
    .version = "12.x", // TODO: Get actual version from V8
};

/// Promise handle for tracking V8 promise state
const V8PromiseHandle = struct {
    resolver: *ffi.PromiseResolver,
    promise: *ffi.Promise,
    isolate: *ffi.Isolate,
    context: *ffi.Context,
};

/// Wrap a Zig async iterator for V8
///
/// Takes a Zig ReadableStreamAsyncIterator and creates a V8 async iterator
/// object that JavaScript can use with `for await...of` loops.
fn v8WrapAsyncIterator(
    engine_ctx: *anyopaque,
    zig_iterator: *anyopaque,
) EngineError!*anyopaque {
    // ReadableStream's async iterator is built by impls/streams_readable.zig
    // (WebIDL's ongoing-promise machinery over a default reader); nothing
    // wraps a Zig iterator through the engine interface any more.
    _ = engine_ctx;
    _ = zig_iterator;
    return EngineError.AsyncIteratorError;
}

/// Create a V8 Promise that can be resolved/rejected from Zig
fn v8CreatePromise(
    engine_ctx: *anyopaque,
    allocator: std.mem.Allocator,
) EngineError!*anyopaque {
    // engine_ctx is the V8 Context (set by context_manager.zig)
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    // Get current isolate - the context should be entered so this works
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    const resolver = ffi.v8_PromiseResolver_New(context) orelse
        return EngineError.PromiseError;

    const promise = ffi.v8_PromiseResolver_GetPromise(resolver) orelse {
        ffi.v8_PromiseResolver_Dispose(resolver);
        return EngineError.PromiseError;
    };

    // Allocate handle to track the promise
    const handle = allocator.create(V8PromiseHandle) catch
        return EngineError.OutOfMemory;

    handle.* = .{
        .resolver = resolver,
        .promise = promise,
        .isolate = isolate,
        .context = context,
    };

    return @ptrCast(handle);
}

/// Resolve a V8 Promise with a value
fn v8ResolvePromise(
    engine_ctx: *anyopaque,
    promise_handle: *anyopaque,
    value: ?*const anyopaque,
) EngineError!void {
    _ = engine_ctx;
    const handle: *V8PromiseHandle = @ptrCast(@alignCast(promise_handle));

    // Convert value to V8 Value, untagging if necessary
    const v8_value: *ffi.Value = if (value) |v| blk: {
        const tagged = TaggedPointer.fromRaw(@intFromPtr(v));
        const result = tagged.untagAs(*ffi.Value);
        DebugAssertions.logPointerUntagging(tagged.raw, @ptrCast(result), tagged.getTag());
        break :blk result;
    } else ffi.v8_Undefined(handle.isolate) orelse return EngineError.OperationFailed;
    // The undefined was made here; a caller's value is the caller's.
    defer if (value == null) ffi.v8_Value_Dispose(v8_value);

    if (!ffi.v8_PromiseResolver_Resolve(handle.resolver, handle.context, v8_value)) {
        return EngineError.PromiseError;
    }
}

/// Reject a V8 Promise with an error
fn v8RejectPromise(
    engine_ctx: *anyopaque,
    promise_handle: *anyopaque,
    err: anyerror,
) EngineError!void {
    _ = engine_ctx;
    const handle: *V8PromiseHandle = @ptrCast(@alignCast(promise_handle));

    // Create error message string
    const err_name = @errorName(err);
    const err_str = ffi.v8_String_NewFromUtf8(
        handle.isolate,
        err_name.ptr,
        @intCast(err_name.len),
    ) orelse return EngineError.OperationFailed;
    defer ffi.v8_String_Dispose(err_str);

    // Create appropriate Error object based on error type
    const err_obj = switch (err) {
        error.SyntaxError => ffi.v8_Exception_SyntaxError(err_str) orelse
            return EngineError.OperationFailed,
        error.TypeError => ffi.v8_Exception_TypeError(err_str) orelse
            return EngineError.OperationFailed,
        error.RangeError => ffi.v8_Exception_RangeError(err_str) orelse
            return EngineError.OperationFailed,
        else => ffi.v8_Exception_Error(err_str) orelse
            return EngineError.OperationFailed,
    };

    // Made here and only handed to Reject, which keeps its own reference.
    defer ffi.v8_Value_Dispose(err_obj);
    if (!ffi.v8_PromiseResolver_Reject(handle.resolver, handle.context, err_obj)) {
        return EngineError.PromiseError;
    }
}

/// Get the V8 Promise object to return to JavaScript
fn v8GetPromiseObject(promise_handle: *anyopaque) *anyopaque {
    const handle: *V8PromiseHandle = @ptrCast(@alignCast(promise_handle));
    return @ptrCast(handle.promise);
}

/// Destroy a V8 Promise handle after use
/// The Promise object itself remains valid (managed by V8 GC), but the
/// handle struct is freed.
fn v8DestroyPromiseHandle(promise_handle: *anyopaque, allocator: std.mem.Allocator) void {
    const handle: *V8PromiseHandle = @ptrCast(@alignCast(promise_handle));
    // The resolver is released here: nothing can settle the promise once its
    // handle is gone, and a Global to the resolver keeps the promise - and its
    // page - alive, whatever the GC would do otherwise. The promise's own
    // handle is not: getPromiseObject gave it to the caller, which returns it.
    ffi.v8_PromiseResolver_Dispose(handle.resolver);
    allocator.destroy(handle);
}

/// Create a V8 String from UTF-8 bytes
fn v8CreateString(
    engine_ctx: *anyopaque,
    bytes: []const u8,
) EngineError!*anyopaque {
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    const v8_string = ffi.v8_String_NewFromUtf8(
        isolate,
        bytes.ptr,
        @intCast(bytes.len),
    ) orelse return EngineError.OperationFailed;

    return @ptrCast(v8_string);
}

/// Read a property off a V8 object and report its ECMAScript truthiness.
///
/// `v8_Value_BooleanValue` IS ToBoolean, so `{capture: 2}` and
/// `{capture: "x"}` are both true, matching what the spec requires of a
/// `boolean` dictionary member.
fn v8GetPropertyTruthy(
    engine_ctx: *anyopaque,
    object: *anyopaque,
    name: []const u8,
    default: bool,
) EngineError!bool {
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return EngineError.OperationFailed;
    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return EngineError.OperationFailed;
    // GetCurrentContext allocates a Global we own - AGENTS.md, the C++ seam.
    defer ffi.v8_Context_Dispose(context);

    const obj: *ffi.Value = @ptrCast(@alignCast(object));
    if (!ffi.v8_Value_IsObject(obj)) return default;

    const key = ffi.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse
        return EngineError.OperationFailed;
    defer ffi.v8_String_Dispose(key);

    const value = ffi.v8_Object_Get(@ptrCast(obj), context, @ptrCast(key)) orelse return default;
    defer ffi.v8_Value_Dispose(value);

    return ffi.v8_Value_BooleanValue(value, isolate);
}

// ============================================================================
// Realm operations (AGENTS.md, "The engine boundary")
// ============================================================================

/// A realm entered: its agent (isolate), when it was not the current one, and
/// a scope on its context.
const EnteredRealm = struct {
    isolate: *ffi.Isolate,
    entered_isolate: bool,
    scope: js_scope.JsScope,

    fn leaveScope(self: EnteredRealm) void {
        self.scope.deinit();
    }

    fn leaveAgent(self: EnteredRealm) void {
        if (self.entered_isolate) ffi.v8_Isolate_Exit(self.isolate);
    }
};

/// Enter `realm`: its isolate - recorded on the realm, which a worker realm on
/// this thread needs, else the current one - then a HandleScope and its context.
fn enterRealm(realm: runtime.Context) EngineError!EnteredRealm {
    const engine_ctx = realm.engine_ctx orelse return EngineError.OperationFailed;
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const current = ffi.v8_Isolate_GetCurrent();
    const recorded: ?*ffi.Isolate = if (realm.realm) |r| (if (r.isolate) |i| @ptrCast(@alignCast(i)) else null) else null;
    const isolate = recorded orelse current orelse return EngineError.OperationFailed;
    const entered = current != isolate;
    if (entered) ffi.v8_Isolate_Enter(isolate);
    const scope = js_scope.JsScope.initFromV8Context(context) orelse {
        if (entered) ffi.v8_Isolate_Exit(isolate);
        return EngineError.OperationFailed;
    };
    return .{ .isolate = isolate, .entered_isolate = entered, .scope = scope };
}

fn v8RunClassicScript(
    realm: runtime.Context,
    source: []const u8,
    source_url: ?[]const u8,
    report: runtime.ReportExceptionFn,
    host: ?*anyopaque,
) EngineError!void {
    const entered = try enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    const isolate = entered.isolate;
    const context = entered.scope.context;

    // The Window whose realm this runs in is the accessor for cross-origin
    // checks while it runs.
    const window = context_manager.getWindowForContext(context);
    if (window) |w| context_manager.pushAccessorWindow(w);
    defer if (window != null) context_manager.popAccessorWindow();

    const text = ffi.v8_String_NewFromUtf8(isolate, source.ptr, @intCast(source.len)) orelse return EngineError.OperationFailed;
    defer ffi.v8_String_Dispose(text);

    // "Create a classic script": a script that does not parse has a parse
    // error, which "run a classic script" step 6 turns into the evaluation
    // status - reported like anything the script throws.
    const compiled = if (source_url) |url| blk: {
        const name = ffi.v8_String_NewFromUtf8(isolate, url.ptr, @intCast(url.len)) orelse return EngineError.OperationFailed;
        defer ffi.v8_String_Dispose(name);
        break :blk ffi.v8_Script_CompileWithOrigin_Safe(context, text, name);
    } else ffi.v8_Script_Compile_Safe(context, text);
    defer ffi.v8_FreeScriptCompileResult(compiled);

    if (compiled.script) |script| {
        defer ffi.v8_Script_Dispose(script);
        // Step 7: ScriptEvaluation. Step 8: report an exception, while the
        // result that owns its error information is alive.
        const run = ffi.v8_Script_Run_Safe(context, script);
        defer ffi.v8_FreeScriptRunResult(run);
        if (run.value) |value| ffi.v8_Global_Dispose(value);
        if (run.error_info) |info| reportException(isolate, info, report, host);
    } else if (compiled.error_info) |info| {
        reportException(isolate, info, report, host);
    }
}

const PendingReport = struct {
    info: *const ffi.V8ErrorInfo,
    report: runtime.ReportExceptionFn,
    host: ?*anyopaque,
};

/// Hand a thrown value to the host's "report an exception", with V8's
/// automatic microtask checkpoints held off until it returns: the spec
/// reports before "clean up after running script" performs the checkpoint.
fn reportException(isolate: *ffi.Isolate, info: *const ffi.V8ErrorInfo, report: runtime.ReportExceptionFn, host: ?*anyopaque) void {
    var pending = PendingReport{ .info = info, .report = report, .host = host };
    ffi.v8_RunWithMicrotasksSuppressed(isolate, runPendingReport, &pending);
}

fn runPendingReport(data: ?*anyopaque) callconv(.c) void {
    const pending: *PendingReport = @ptrCast(@alignCast(data orelse return));
    const info = pending.info;
    const error_info = runtime.ErrorInfo{
        .message = info.getMessage() orelse "Uncaught exception",
        .filename = info.getResourceName() orelse "",
        .lineno = if (info.line_number > 0) @intCast(info.line_number) else 0,
        // V8 counts columns from 0; ErrorEvent.colno counts from 1.
        .colno = if (info.column_number >= 0) @intCast(info.column_number + 1) else 0,
        // Borrowed: the error information owns it until this returns.
        .error_value = if (info.exception) |value| runtime.JSValue{ .handle = .{ .ptr = value, .needs_disposal = false } } else null,
    };
    pending.report(pending.host, &error_info);
}

fn v8PerformMicrotaskCheckpoint(realm: runtime.Context) EngineError!void {
    const entered = try enterRealm(realm);
    defer entered.leaveAgent();
    entered.leaveScope();
    ffi.v8_Isolate_PerformMicrotaskCheckpoint(entered.isolate);
}

fn v8RunTaskInRealm(realm: runtime.Context, steps: runtime.RealmSteps, data: ?*anyopaque) EngineError!void {
    const entered = try enterRealm(realm);
    defer entered.leaveAgent();
    {
        defer entered.leaveScope();
        steps(data);
    }
    // The end of the task, with the agent still entered: the realm's own
    // (a worker's event loop does more than a checkpoint); for a window, the
    // host loop's checkpoint follows the task.
    if (realm.end_of_task) |end| end(realm);
}

fn v8RunInRealm(realm: runtime.Context, steps: runtime.RealmSteps, data: ?*anyopaque) EngineError!void {
    const entered = try enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    steps(data);
}

fn v8CreateDOMException(realm: runtime.Context, name: []const u8, message: []const u8) EngineError!runtime.JSValue {
    const entered = try enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    const value = v8_conversions.newDOMExceptionFromContext(entered.isolate, entered.scope.context, name, message) orelse
        return EngineError.OperationFailed;
    return .{ .handle = .{ .ptr = value, .needs_disposal = true } };
}

fn v8StructuredSerializeForStorage(realm: runtime.Context, value: runtime.JSValue, allocator: std.mem.Allocator) EngineError![]u8 {
    const object: *ffi.Value = switch (value) {
        .handle => |h| @ptrCast(@alignCast(h.ptr)),
        // Primitives and strings are the caller's to keep; a platform object
        // arrives wrapped, as a handle, when it is [Serializable].
        else => return EngineError.DataCloneError,
    };
    const entered = try enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    var no_transfer: [1]*ffi.Value = undefined;
    var no_buffers: [1]ffi.ArrayBufferTransferData = undefined;
    var size: usize = 0;
    var code: c_int = 0;
    const bytes = ffi.v8_Value_StructuredSerializeWithTransfer(object, &no_transfer, 0, &size, &no_buffers, &code) orelse
        return if (code == 3) EngineError.ExceptionPending else EngineError.DataCloneError;
    defer ffi.v8_Free_SerializedBuffer(bytes);
    return allocator.dupe(u8, bytes[0..size]) catch EngineError.OutOfMemory;
}

fn v8StructuredDeserialize(realm: runtime.Context, bytes: []const u8) EngineError!runtime.JSValue {
    const entered = try enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    const no_buffers: [1]ffi.ArrayBufferTransferData = undefined;
    var code: c_int = 0;
    const value = ffi.v8_Value_DeserializeWithTransfer_CrossIsolate(bytes.ptr, bytes.len, &no_buffers, 0, &code) orelse
        return EngineError.DataCloneError;
    return .{ .handle = .{ .ptr = value, .needs_disposal = true } };
}

fn v8ResolvePromiseWithInstance(promise_handle: *anyopaque, instance: *runtime.Instance) EngineError!void {
    const handle: *V8PromiseHandle = @ptrCast(@alignCast(promise_handle));
    // The wrapper in the promise's realm: enter it for the lookup.
    const scope = js_scope.JsScope.initFromV8Context(handle.context) orelse return EngineError.OperationFailed;
    defer scope.deinit();
    // Borrowed: the wrapper cache (or, for a Window, the Window) owns it.
    const wrapper = v8_conversions.instanceToV8(handle.isolate, instance);
    if (!ffi.v8_PromiseResolver_Resolve(handle.resolver, handle.context, wrapper)) return EngineError.PromiseError;
}

fn v8RejectPromiseWithValue(promise_handle: *anyopaque, value: runtime.JSValue) EngineError!void {
    const handle: *V8PromiseHandle = @ptrCast(@alignCast(promise_handle));
    const scope = js_scope.JsScope.initFromV8Context(handle.context) orelse return EngineError.OperationFailed;
    defer scope.deinit();
    const reason = v8_conversions.toV8Value(runtime.JSValue, handle.isolate, handle.context, value) catch
        return EngineError.OperationFailed;
    // toV8Value hands back a handle or an instance's wrapper as it is, and
    // makes a new value for anything else - which is released here.
    const made = switch (value) {
        .handle, .instance => false,
        else => true,
    };
    defer if (made) ffi.v8_Value_Dispose(reason);
    if (!ffi.v8_PromiseResolver_Reject(handle.resolver, handle.context, reason)) return EngineError.PromiseError;
}

fn v8MarkPromiseAsHandled(promise_handle: *anyopaque) void {
    const handle: *V8PromiseHandle = @ptrCast(@alignCast(promise_handle));
    ffi.v8_Promise_MarkAsHandled(@ptrCast(handle.promise));
}

fn v8CreateSequenceOfPlatformObjects(realm: runtime.Context, instances: []const *runtime.Instance) EngineError!runtime.JSValue {
    const entered = try enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    const array = ffi.v8_Array_New(entered.isolate, @intCast(instances.len));
    for (instances, 0..) |instance, i| {
        // Borrowed wrappers; Set keeps its own reference.
        const wrapper = v8_conversions.instanceToV8(entered.isolate, instance);
        if (!ffi.v8_Array_Set(array, entered.scope.context, @intCast(i), wrapper)) {
            ffi.v8_Global_Dispose(@ptrCast(array));
            return EngineError.OperationFailed;
        }
    }
    return .{ .handle = .{ .ptr = @ptrCast(array), .needs_disposal = true } };
}

fn v8RelevantGlobalObject(instance: *runtime.Instance) ?*runtime.Instance {
    const engine_ctx = instance.ctx.engine_ctx orelse return null;
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    // A Window realm's Window, as the context manager records it (which also
    // holds for a realm a navigation has since replaced) ...
    if (context_manager.getWindowForContext(context)) |window| return window;
    // ... else whatever global object the realm's global carries - a
    // WorkerGlobalScope.
    const global = ffi.v8_Context_Global(context) orelse return null;
    defer ffi.v8_Object_Dispose(global);
    const ptr = ffi.v8_Object_GetAlignedPointerFromInternalField(global, 0) orelse return null;
    return @ptrCast(@alignCast(ptr));
}

fn v8ReleaseValue(value: runtime.JSValue) void {
    switch (value) {
        .handle => |h| if (h.needs_disposal and h.handle_scope == .global) {
            ffi.v8_Global_Dispose(@ptrCast(@alignCast(h.ptr)));
        },
        else => {},
    }
}

/// Get(object, name) for a dictionary member: the value (owned, the
/// caller disposes), or null when Get threw and the exception is pending.
fn getMember(isolate: *ffi.Isolate, context: *ffi.Context, object: *anyopaque, name: []const u8) EngineError!?*ffi.Value {
    const obj: *ffi.Value = @ptrCast(@alignCast(object));
    if (!ffi.v8_Value_IsObject(obj)) return EngineError.TypeError;
    const key = ffi.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse
        return EngineError.OperationFailed;
    defer ffi.v8_String_Dispose(key);
    return ffi.v8_Object_Get(@ptrCast(obj), context, @ptrCast(key));
}

fn v8GetPropertyBoolean(engine_ctx: *anyopaque, object: *anyopaque, name: []const u8) EngineError!?bool {
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return EngineError.OperationFailed;
    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return EngineError.OperationFailed;
    defer ffi.v8_Context_Dispose(context);

    const value = (try getMember(isolate, context, object, name)) orelse return EngineError.ExceptionPending;
    defer ffi.v8_Value_Dispose(value);
    if (ffi.v8_Value_IsUndefined(value)) return null;
    return ffi.v8_Value_BooleanValue(value, isolate);
}

fn v8GetPropertyInstance(engine_ctx: *anyopaque, object: *anyopaque, name: []const u8) EngineError!?*anyopaque {
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return EngineError.OperationFailed;
    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return EngineError.OperationFailed;
    defer ffi.v8_Context_Dispose(context);

    const value = (try getMember(isolate, context, object, name)) orelse return EngineError.ExceptionPending;
    defer ffi.v8_Value_Dispose(value);
    if (ffi.v8_Value_IsUndefined(value)) return null;
    // The binding's own unwrap rule for an interface-typed value; the
    // allocator is unused for this type.
    const instance = v8_conversions.fromV8Value(*runtime.Instance, std.heap.page_allocator, isolate, context, value) catch
        return EngineError.TypeError;
    return @ptrCast(instance);
}

/// Create a V8 ArrayBuffer from bytes
fn v8CreateArrayBuffer(
    engine_ctx: *anyopaque,
    bytes: []const u8,
) EngineError!*anyopaque {
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Create a new ArrayBuffer with the specified length
    const array_buffer = ffi.v8_ArrayBuffer_New(isolate, bytes.len) orelse
        return EngineError.OperationFailed;

    // Copy the bytes into the ArrayBuffer's backing store
    if (bytes.len > 0) {
        const data = ffi.v8_ArrayBuffer_Data(array_buffer) orelse
            return EngineError.OperationFailed;
        const dest: [*]u8 = @ptrCast(data);
        @memcpy(dest[0..bytes.len], bytes);
    }

    return @ptrCast(array_buffer);
}

/// Create a V8 Uint8Array from bytes
fn v8CreateUint8Array(
    engine_ctx: *anyopaque,
    bytes: []const u8,
) EngineError!*anyopaque {
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Create a backing ArrayBuffer
    const array_buffer = ffi.v8_ArrayBuffer_New(isolate, bytes.len) orelse
        return EngineError.OperationFailed;

    // Copy the bytes into the ArrayBuffer's backing store
    if (bytes.len > 0) {
        const data = ffi.v8_ArrayBuffer_Data(array_buffer) orelse
            return EngineError.OperationFailed;
        const dest: [*]u8 = @ptrCast(data);
        @memcpy(dest[0..bytes.len], bytes);
    }

    // Create Uint8Array view over the ArrayBuffer
    const uint8_array = ffi.v8_Uint8Array_New(isolate, array_buffer, 0, bytes.len) orelse
        return EngineError.OperationFailed;

    return @ptrCast(uint8_array);
}

/// Parse a JSON string and return a V8 value
fn v8ParseJson(
    engine_ctx: *anyopaque,
    json_str: []const u8,
) EngineError!*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // JSON.parse needs the string as a JavaScript string literal
    // Build: JSON.parse('...escaped json...')

    // Escape the JSON for JavaScript string literal (escape backslashes and quotes)
    var escaped: std.ArrayListUnmanaged(u8) = .empty;
    defer escaped.deinit(std.heap.c_allocator);

    // Start with JSON.parse('
    escaped.appendSlice(std.heap.c_allocator, "JSON.parse('") catch return EngineError.OutOfMemory;

    for (json_str) |c| {
        switch (c) {
            '\\' => escaped.appendSlice(std.heap.c_allocator, "\\\\") catch return EngineError.OutOfMemory,
            '\'' => escaped.appendSlice(std.heap.c_allocator, "\\'") catch return EngineError.OutOfMemory,
            '\n' => escaped.appendSlice(std.heap.c_allocator, "\\n") catch return EngineError.OutOfMemory,
            '\r' => escaped.appendSlice(std.heap.c_allocator, "\\r") catch return EngineError.OutOfMemory,
            '\t' => escaped.appendSlice(std.heap.c_allocator, "\\t") catch return EngineError.OutOfMemory,
            else => escaped.append(std.heap.c_allocator, c) catch return EngineError.OutOfMemory,
        }
    }

    // End with ')
    escaped.appendSlice(std.heap.c_allocator, "')") catch return EngineError.OutOfMemory;

    const parse_str = ffi.v8_String_NewFromUtf8(
        isolate,
        escaped.items.ptr,
        @intCast(escaped.items.len),
    ) orelse return EngineError.OperationFailed;

    // Compile using safe variant for error reporting
    const compile_result = ffi.v8_Script_Compile_Safe(context, parse_str);
    defer ffi.v8_FreeScriptCompileResult(compile_result);

    if (compile_result.error_info) |err| {
        logV8Error(err, "JSON.parse compilation");
        return EngineError.OperationFailed;
    }

    const script = compile_result.script orelse
        return EngineError.OperationFailed;
    defer ffi.v8_Script_Dispose(script);

    // Run using safe variant for error reporting
    const run_result = ffi.v8_Script_Run_Safe(context, script);
    defer ffi.v8_FreeScriptRunResult(run_result);

    if (run_result.error_info) |err| {
        logV8Error(err, "JSON.parse execution");
        return EngineError.OperationFailed;
    }

    const result = run_result.value orelse
        return EngineError.OperationFailed;

    return @ptrCast(result);
}

/// Wrap a Zig runtime.Instance as a V8 object
fn v8WrapInstance(
    engine_ctx: *anyopaque,
    instance_ptr: *anyopaque,
) EngineError!*anyopaque {
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));

    // Use the conversions module to wrap the instance
    const conv = @import("conversions.zig");
    const v8_obj = conv.instanceToV8(isolate, instance);

    return @ptrCast(v8_obj);
}

/// Check if a V8 value is a string
fn v8IsString(
    js_value: *const anyopaque,
) bool {
    const tagged = TaggedPointer.fromRaw(@intFromPtr(js_value));
    const value = tagged.untagAs(*ffi.Value);
    DebugAssertions.logPointerUntagging(tagged.raw, @ptrCast(value), tagged.getTag());
    return ffi.v8_Value_IsString(value);
}

/// Extract a string from a V8 value
fn v8ExtractString(
    engine_ctx: *anyopaque,
    js_value: *const anyopaque,
    allocator: std.mem.Allocator,
) EngineError![]const u8 {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    const tagged = TaggedPointer.fromRaw(@intFromPtr(js_value));
    const value = tagged.untagAs(*ffi.Value);
    DebugAssertions.logPointerUntagging(tagged.raw, @ptrCast(value), tagged.getTag());

    // Use the conversions module to extract the string
    const conv = @import("conversions.zig");
    const dom_string = conv.fromV8String(allocator, isolate, context, @ptrCast(value)) catch
        return EngineError.OperationFailed;

    // Extract the slice from DOMString
    // Note: DOMString.asSlice() returns a slice, but the memory is managed by DOMString
    // We need to dupe the bytes to give caller ownership
    const slice = dom_string.asSlice();
    const owned_slice = allocator.dupe(u8, slice) catch
        return EngineError.OutOfMemory;

    return owned_slice;
}

/// Set a property on a V8 object using [[Set]] semantics
///
/// Per WebIDL [PutForwards] extended attribute: the assignment is performed
/// by invoking the [[Set]] internal method with the property name and value.
fn v8SetPropertyOnObject(
    engine_ctx: *anyopaque,
    target: *anyopaque,
    property_name: []const u8,
    value: []const u8,
) EngineError!void {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Cast target to V8 Object
    const target_obj: *ffi.Object = @ptrCast(@alignCast(target));

    // Create V8 String for property name
    const v8_key = ffi.v8_String_NewFromUtf8(isolate, property_name.ptr, @intCast(property_name.len)) orelse
        return EngineError.OperationFailed;

    // Create V8 String for value
    const v8_value = ffi.v8_String_NewFromUtf8(isolate, value.ptr, @intCast(value.len)) orelse
        return EngineError.OperationFailed;

    // Use v8_Object_Set to set the property (this uses [[Set]] semantics)
    const success = ffi.v8_Object_Set(target_obj, context, @ptrCast(v8_key), @ptrCast(v8_value));
    if (!success) {
        return EngineError.OperationFailed;
    }
}

/// Define an own property on a V8 object using [[DefineOwnProperty]] semantics
///
/// Per WebIDL [Replaceable] extended attribute (§4.3.10): the assignment is performed
/// by calling [[DefineOwnProperty]] with PropertyDescriptor{[[Value]]: V,
/// [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: true}
///
/// If [[DefineOwnProperty]] fails (e.g., property is non-configurable), this returns
/// EngineError.TypeError per the WebIDL specification: "If success is false, then throw
/// a TypeError."
fn v8DefineOwnPropertyOnObject(
    engine_ctx: *anyopaque,
    target: *anyopaque,
    property_name: []const u8,
    value: *anyopaque,
) EngineError!void {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Cast target to V8 Object
    const target_obj: *ffi.Object = @ptrCast(@alignCast(target));

    // Cast value to V8 Value
    const v8_value: *ffi.Value = @ptrCast(@alignCast(value));

    // Create V8 String for property name
    const v8_key = ffi.v8_String_NewFromUtf8(isolate, property_name.ptr, @intCast(property_name.len)) orelse
        return EngineError.OperationFailed;
    defer ffi.v8_String_Dispose(v8_key);

    // Use v8_Object_DefineProperty with [[DefineOwnProperty]] semantics
    // For [Replaceable]: writable=true, enumerable=true, configurable=true
    if (!ffi.v8_Object_DefineProperty(target_obj, context, @ptrCast(v8_key), v8_value, true, true, true)) {
        // Per WebIDL spec §4.3.10: "If success is false, then throw a TypeError."
        return EngineError.TypeError;
    }
}

/// Convert an engine-agnostic runtime.JSValue to a V8 Value pointer
///
/// This handles all JSValue variants:
/// - undefined → V8 undefined
/// - null → V8 null
/// - boolean → V8 boolean
/// - number → V8 number
/// - string → V8 string
/// - handle → returns the handle directly
/// - instance → wraps as V8 object
fn v8ConvertJSValueToEngine(
    engine_ctx: *anyopaque,
    value: runtime.JSValue,
) EngineError!*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Use the existing toV8Value conversion which handles all variants
    const v8_value = v8_conversions.toV8Value(runtime.JSValue, isolate, context, value) catch |err| {
        switch (err) {
            error.OutOfMemory => return EngineError.OutOfMemory,
            error.TypeError => return EngineError.TypeError,
            else => return EngineError.OperationFailed,
        }
    };

    return @ptrCast(v8_value);
}

/// Create a V8 array from a slice of strings
fn v8CreateStringArray(
    engine_ctx: *anyopaque,
    strings: []const []const u8,
) EngineError!*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Create a new V8 array with the given length
    const array = ffi.v8_Array_New(isolate, @intCast(strings.len));

    // Add each string to the array
    for (strings, 0..) |str, i| {
        const v8_str = ffi.v8_String_NewFromUtf8(isolate, str.ptr, @intCast(str.len)) orelse
            continue; // Skip on error
        // Set keeps its own reference; this one was made here.
        defer ffi.v8_String_Dispose(v8_str);
        _ = ffi.v8_Array_Set(array, context, @intCast(i), @ptrCast(v8_str));
    }

    return @ptrCast(array);
}

/// Create a V8 event loop
fn v8CreateEventLoop(
    engine_ctx: *anyopaque,
    allocator: std.mem.Allocator,
) EngineError!*anyopaque {
    // engine_ctx is the V8 Context, get the current isolate
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    const v8_loop_ptr = allocator.create(event_loop_mod.V8EventLoop) catch
        return EngineError.OutOfMemory;

    v8_loop_ptr.* = event_loop_mod.V8EventLoop.init(isolate, allocator) catch
        return EngineError.OperationFailed;

    return @ptrCast(v8_loop_ptr);
}

/// Destroy a V8 event loop
fn v8DestroyEventLoop(
    event_loop: *anyopaque,
    allocator: std.mem.Allocator,
) void {
    const v8_loop: *event_loop_mod.V8EventLoop = @ptrCast(@alignCast(event_loop));
    v8_loop.deinit();
    allocator.destroy(v8_loop);
}

// ============================================================================
// Callback Wrapper Implementation
// ============================================================================

/// Create a V8 callback wrapper from a JavaScript value
///
/// Used for WebIDL callback interfaces like EventListener.
/// Supports both direct function callbacks and object callbacks with methods.
fn v8CreateCallbackWrapper(
    engine_ctx: *anyopaque,
    js_value: *anyopaque,
    method_name: [*:0]const u8,
    allocator: std.mem.Allocator,
) EngineError!?*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;
    const value: *ffi.Value = @ptrCast(@alignCast(js_value));

    const wrapper = callback_wrapper_mod.createFromV8Value(
        allocator,
        isolate,
        context,
        value,
        method_name,
    ) catch return EngineError.OutOfMemory;

    if (wrapper) |w| {
        return @ptrCast(w);
    }
    return null;
}

/// Invoke a V8 callback wrapper with arguments
fn v8InvokeCallback(
    engine_ctx: *anyopaque,
    callback_wrapper: *anyopaque,
    args: [*]const *anyopaque,
    args_len: usize,
) EngineError!?*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const wrapper: *callback_wrapper_mod.CallbackWrapper = @ptrCast(@alignCast(callback_wrapper));

    // Convert args to V8 values
    const v8_args: [*]const *ffi.Value = @ptrCast(args);
    const v8_args_slice = v8_args[0..args_len];

    const result = wrapper.callN(context, v8_args_slice);
    if (result) |r| {
        return @ptrCast(r);
    }
    return null;
}

/// Destroy a V8 callback wrapper
fn v8DestroyCallbackWrapper(
    callback_wrapper: *anyopaque,
) void {
    const wrapper: *callback_wrapper_mod.CallbackWrapper = @ptrCast(@alignCast(callback_wrapper));
    wrapper.deinit();
}

// ============================================================================
// Garbage Collection (TestUtils support)
// ============================================================================

/// Request garbage collection via V8
///
/// Uses LowMemoryNotification() which triggers a full GC cycle.
/// Per WHATWG TestUtils spec: "Run implementation-defined steps to perform
/// a garbage collection covering at least the entry Realm."
fn v8RequestGarbageCollection(engine_ctx: *anyopaque) EngineError!void {
    // engine_ctx is the V8 Context, get the current isolate
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Use LowMemoryNotification which triggers a full GC
    // This is more reliable than RequestGarbageCollectionForTesting
    // and doesn't require special build flags
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
}

// ============================================================================
// Main Thread Scheduling
// ============================================================================

/// Schedule a callback on the main thread
///
/// For V8, we execute the callback immediately since we're typically
/// already on the main thread. A full implementation would use
/// platform->GetForegroundTaskRunner(isolate)->PostTask().
fn v8ScheduleOnMainThread(
    _: *anyopaque,
    callback: runtime.MainThreadCallback,
    user_data: *anyopaque,
) EngineError!void {
    // For now, execute immediately (assumes we're on main thread)
    // TODO: Use V8 platform task runner for true async scheduling
    callback(user_data);
}

// ============================================================================
// Stream Algorithm Callback Support
// ============================================================================

/// Invoke a JavaScript callback function for stream algorithms (pull, cancel, etc.)
///
/// This invokes a JS function that was stored during stream construction.
/// The function receives the controller as first argument and optional arg as second.
///
/// Arguments:
///   - engine_ctx: V8 Context pointer
///   - js_callback: V8 Global<Value>* pointing to the JS function
///   - controller_v8: V8 Object* for the controller wrapper (or null)
///   - arg: Optional V8 Value* for additional argument (e.g., cancel reason)
///
/// Returns:
///   - V8 Promise* from calling the function, or null on failure
fn v8InvokeStreamCallback(
    engine_ctx: *anyopaque,
    js_callback: *const anyopaque,
    controller_v8: ?*anyopaque,
    arg: ?*const anyopaque,
) EngineError!?*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Get the JS function value from the Global handle, untagging if necessary
    const tagged_callback = TaggedPointer.fromRaw(@intFromPtr(js_callback));
    const callback_value = tagged_callback.untagAs(*ffi.Value);
    DebugAssertions.logPointerUntagging(tagged_callback.raw, @ptrCast(callback_value), tagged_callback.getTag());

    // Check if it's actually a function
    if (!ffi.v8_Value_IsFunction(callback_value)) {
        return EngineError.TypeError;
    }

    // Build arguments array
    var args: [2]*ffi.Value = undefined;
    var arg_count: usize = 0;

    // First argument: controller (if provided), untag if necessary
    if (controller_v8) |ctrl| {
        args[arg_count] = TaggedPointer.fromRaw(@intFromPtr(ctrl)).untagAs(*ffi.Value);
        arg_count += 1;
    }

    // Second argument: additional arg (if provided), untag if necessary
    if (arg) |a| {
        args[arg_count] = TaggedPointer.fromRaw(@intFromPtr(a)).untagAs(*ffi.Value);
        arg_count += 1;
    }

    // Get 'this' value (undefined for stream callbacks)
    const this_val = ffi.v8_Undefined(isolate) orelse
        return EngineError.OperationFailed;

    // Call the function using safe variant with TryCatch
    // Note: callback_value is already verified to be a function at line 756
    const args_ptr: [*]*ffi.Value = &args;
    const call_result = ffi.v8_Function_Call_Safe(
        callback_value,
        context,
        this_val,
        @intCast(arg_count),
        if (arg_count > 0) args_ptr else null,
    );
    defer ffi.v8_FreeFunctionCallResult(call_result);

    // Check for error
    if (call_result.error_info) |err| {
        logV8Error(err, "Stream callback invocation");
        return null;
    }

    if (call_result.value) |r| {
        // If result is a Promise, return it directly
        if (ffi.v8_Value_IsPromise(r)) {
            return @ptrCast(r);
        }

        // If result is not a Promise, wrap it in a resolved Promise
        // Per spec, stream callbacks can return undefined or a Promise
        const resolver = ffi.v8_PromiseResolver_New(context) orelse
            return EngineError.PromiseError;
        _ = ffi.v8_PromiseResolver_Resolve(resolver, context, r);
        const promise = ffi.v8_PromiseResolver_GetPromise(resolver) orelse
            return EngineError.PromiseError;
        return @ptrCast(promise);
    }

    // Call returned null without error - unexpected
    log.warn("Stream callback returned null without error", .{});
    return null;
}

/// Get the V8 wrapper for a Zig runtime instance from the cache
///
/// Arguments:
///   - engine_ctx: V8 Context pointer (unused, cache has its own context)
///   - wrapper_cache: WrapperCache pointer
///   - instance: runtime.Instance pointer
///
/// Returns:
///   - V8 Object* if found in cache, null otherwise
fn v8GetWrapperForInstance(
    _: *anyopaque,
    wrapper_cache: *anyopaque,
    instance: *anyopaque,
) ?*anyopaque {
    const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
    const cache: *WrapperCache = @ptrCast(@alignCast(wrapper_cache));
    const inst: *runtime.Instance = @ptrCast(@alignCast(instance));

    if (cache.get(inst)) |wrapper| {
        return @ptrCast(wrapper);
    }
    return null;
}

/// Chain fulfillment/rejection handlers to a V8 Promise
///
/// Creates JavaScript functions that call into Zig when the promise settles.
/// Used to bridge V8 Promises to Zig AsyncPromise.
///
/// Arguments:
///   - engine_ctx: V8 Context pointer
///   - js_promise: V8 Promise* to chain handlers onto
///   - on_fulfill: Zig callback for fulfillment
///   - on_fulfill_ctx: Context passed to fulfillment callback
///   - on_reject: Zig callback for rejection
///   - on_reject_ctx: Context passed to rejection callback
fn v8ChainPromiseHandlers(
    engine_ctx: *anyopaque,
    js_promise: *anyopaque,
    on_fulfill: runtime.PromiseFulfillCallback,
    on_fulfill_ctx: ?*anyopaque,
    on_reject: runtime.PromiseRejectCallback,
    on_reject_ctx: ?*anyopaque,
) EngineError!void {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const promise: *ffi.Promise = @ptrCast(@alignCast(js_promise));

    // Create fulfill handler that calls Zig callback
    const fulfill_handler = ffi.v8_CreateZigFulfillHandler(
        context,
        on_fulfill,
        on_fulfill_ctx,
    ) orelse return EngineError.PromiseError;

    // Create reject handler that calls Zig callback
    const reject_handler = ffi.v8_CreateZigRejectHandler(
        context,
        on_reject,
        on_reject_ctx,
    ) orelse {
        ffi.v8_DisposeZigCallbackHandler(fulfill_handler);
        return EngineError.PromiseError;
    };

    // Chain the handlers onto the promise
    _ = ffi.v8_Promise_Then(promise, context, fulfill_handler, reject_handler) orelse {
        ffi.v8_DisposeZigCallbackHandler(reject_handler);
        ffi.v8_DisposeZigCallbackHandler(fulfill_handler);
        return EngineError.PromiseError;
    };

    // Note: The handlers are now owned by the promise chain
    // The callback data will be cleaned up when the handlers are GC'd
}

// ============================================================================
// Script Execution Support
// ============================================================================

/// Compile a classic script from source using V8
///
/// Compiles JavaScript source code into a V8 Script object.
///
/// Arguments:
///   - engine_ctx: V8 Context pointer
///   - source: UTF-8 encoded JavaScript source code
///   - source_url: Optional URL for error messages and source maps
///
/// Returns:
///   - V8 Script* on success
///   - null if compilation failed (syntax error)
///   - EngineError on engine-level failure
fn v8CompileScript(
    engine_ctx: *anyopaque,
    source: []const u8,
    source_url: ?[]const u8,
) EngineError!?*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Create V8 string from source
    const source_str = ffi.v8_String_NewFromUtf8(
        isolate,
        source.ptr,
        @intCast(source.len),
    ) orelse return EngineError.OutOfMemory;

    // Create resource name if URL provided
    var resource_name: ?*ffi.String = null;
    if (source_url) |url| {
        resource_name = ffi.v8_String_NewFromUtf8(
            isolate,
            url.ptr,
            @intCast(url.len),
        );
    }

    // Compile the script using safe variant with TryCatch
    const compile_result = if (resource_name) |name|
        ffi.v8_Script_CompileWithOrigin_Safe(context, source_str, name)
    else
        ffi.v8_Script_Compile_Safe(context, source_str);
    defer ffi.v8_FreeScriptCompileResult(compile_result);

    // Clean up resource name if created
    if (resource_name) |name| {
        ffi.v8_String_Dispose(name);
    }

    // Check for compilation error
    if (compile_result.error_info) |err| {
        logV8Error(err, "Script compilation");
        return null;
    }

    if (compile_result.script) |s| {
        return @ptrCast(s);
    }

    // Compilation failed without error info - unexpected
    log.warn("Script compilation returned null without error", .{});
    return null;
}

/// Run a compiled V8 script
///
/// Executes a previously compiled script in the current context.
///
/// Arguments:
///   - engine_ctx: V8 Context pointer
///   - script: V8 Script* from v8CompileScript
///
/// Returns:
///   - V8 Value* result on success
///   - null if execution threw an exception
///   - EngineError on engine-level failure
fn v8RunScript(
    engine_ctx: *anyopaque,
    script: *anyopaque,
) EngineError!?*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const v8_script: *ffi.Script = @ptrCast(@alignCast(script));

    // Run script using safe variant with TryCatch
    const run_result = ffi.v8_Script_Run_Safe(context, v8_script);
    defer ffi.v8_FreeScriptRunResult(run_result);

    // Check for execution error
    if (run_result.error_info) |err| {
        logV8Error(err, "Script execution");
        return null;
    }

    if (run_result.value) |r| {
        return @ptrCast(r);
    }

    // Execution returned null without error - unexpected
    log.warn("Script execution returned null without error", .{});
    return null;
}

/// Compile an ES module from source using V8
///
/// Compiles JavaScript module source code into a V8 Module object.
///
/// Arguments:
///   - engine_ctx: V8 Context pointer
///   - source: UTF-8 encoded JavaScript module source code
///   - source_url: URL for the module (required for import resolution)
///
/// Returns:
///   - V8 Module* on success
///   - null if compilation failed
///   - EngineError on engine-level failure
fn v8CompileModule(
    engine_ctx: *anyopaque,
    source: []const u8,
    source_url: []const u8,
) EngineError!?*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Create V8 string from source
    const source_str = ffi.v8_String_NewFromUtf8(
        isolate,
        source.ptr,
        @intCast(source.len),
    ) orelse return EngineError.OutOfMemory;

    // Create resource name (required for modules)
    const resource_name = ffi.v8_String_NewFromUtf8(
        isolate,
        source_url.ptr,
        @intCast(source_url.len),
    );

    // Compile as ES Module using safe variant with TryCatch
    const compile_result = ffi.v8_Module_Compile_Safe(context, source_str, resource_name);
    defer ffi.v8_FreeModuleCompileResult(compile_result);

    // Clean up strings (V8 manages the V8 string memory)
    if (resource_name) |name| {
        ffi.v8_String_Dispose(name);
    }

    // Check for compilation error
    if (compile_result.error_info) |err| {
        logV8Error(err, "Module compilation");
        return null;
    }

    if (compile_result.module) |m| {
        return @ptrCast(m);
    }

    // Compilation failed without error info - unexpected
    log.warn("Module compilation returned null without error", .{});
    return null;
}

/// Instantiate and evaluate a V8 module
///
/// Links module dependencies and executes the module's top-level code.
///
/// Arguments:
///   - engine_ctx: V8 Context pointer
///   - module: V8 Module* from v8CompileModule
///
/// Returns:
///   - void on success
///   - EngineError on instantiation or evaluation failure
fn v8RunModule(
    engine_ctx: *anyopaque,
    module: *anyopaque,
) EngineError!void {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const v8_module: *ffi.Module = @ptrCast(@alignCast(module));

    // Instantiate the module (link imports) using safe variant
    const instantiate_result = ffi.v8_Module_Instantiate_Safe(context, v8_module);
    defer ffi.v8_FreeModuleInstantiateResult(instantiate_result);

    if (instantiate_result.error_info) |err| {
        logV8Error(err, "Module instantiation");
        return EngineError.OperationFailed;
    }

    if (!instantiate_result.success) {
        log.err("Module instantiation failed without error details", .{});
        return EngineError.OperationFailed;
    }

    // Evaluate the module (execute top-level code) using safe variant
    const evaluate_result = ffi.v8_Module_Evaluate_Safe(context, v8_module);
    defer ffi.v8_FreeModuleEvaluateResult(evaluate_result);

    if (evaluate_result.error_info) |err| {
        logV8Error(err, "Module evaluation");
        return EngineError.OperationFailed;
    }

    // Success (value is discarded for sync evaluation)
}

/// Dispose of a compiled V8 script
///
/// Releases resources associated with a compiled script.
///
/// Arguments:
///   - script: V8 Script* from v8CompileScript
fn v8DisposeScript(
    script: *anyopaque,
) void {
    const v8_script: *ffi.Script = @ptrCast(@alignCast(script));
    ffi.v8_Script_Dispose(v8_script);
}

/// Dispose of a compiled V8 module
///
/// Releases resources associated with a compiled module.
///
/// Arguments:
///   - module: V8 Module* from v8CompileModule
fn v8DisposeModule(
    module: *anyopaque,
) void {
    const v8_module: *ffi.Module = @ptrCast(@alignCast(module));
    ffi.v8_Module_Dispose(v8_module);
}

/// Evaluate a V8 module asynchronously (for top-level await support)
///
/// Returns the evaluation Promise that resolves when the module finishes
/// executing, including any top-level await expressions.
///
/// Per HTML Standard "run a module script":
/// - Module.Evaluate() returns a Promise for TLA modules
/// - The Promise resolves with undefined on success
/// - The Promise rejects if there's an error during evaluation
///
/// Arguments:
///   - engine_ctx: V8 Context pointer
///   - module: V8 Module* (must be instantiated)
///
/// Returns:
///   - V8 Promise* that resolves when evaluation completes
///   - null if evaluation cannot start
///   - EngineError on engine-level failure
fn v8RunModuleAsync(
    engine_ctx: *anyopaque,
    module: *anyopaque,
) EngineError!?*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const v8_module: *ffi.Module = @ptrCast(@alignCast(module));

    // Instantiate the module if not already done (idempotent - V8 tracks module status)
    // Using safe variant for detailed error reporting
    const instantiate_result = ffi.v8_Module_Instantiate_Safe(context, v8_module);
    defer ffi.v8_FreeModuleInstantiateResult(instantiate_result);

    if (instantiate_result.error_info) |err| {
        logV8Error(err, "Module instantiation (async)");
        return EngineError.OperationFailed;
    }

    if (!instantiate_result.success) {
        log.err("Module instantiation failed without error details", .{});
        return EngineError.OperationFailed;
    }

    // Evaluate the module using safe variant - returns a Promise for TLA modules
    // For non-TLA modules, the Promise resolves immediately
    const evaluate_result = ffi.v8_Module_Evaluate_Safe(context, v8_module);
    defer ffi.v8_FreeModuleEvaluateResult(evaluate_result);

    if (evaluate_result.error_info) |err| {
        logV8Error(err, "Module evaluation (async)");
        return EngineError.OperationFailed;
    }

    if (evaluate_result.value) |result| {
        // V8's Module::Evaluate() always returns a Promise (as of V8 9.0+)
        // For modules without TLA, it's an already-resolved Promise
        // For modules with TLA, it resolves when async execution completes
        return @ptrCast(result);
    }

    // Evaluation returned null without error - unexpected
    log.warn("Module evaluation returned null without error", .{});
    return null;
}

/// Check if a V8 module contains top-level await
///
/// Uses V8's IsGraphAsync() to check if the module or any of its
/// dependencies contain top-level await, requiring async evaluation.
///
/// Arguments:
///   - module: V8 Module* (must be instantiated)
///
/// Returns:
///   - true if the module graph has TLA
///   - false otherwise
fn v8HasTopLevelAwait(
    module: *anyopaque,
) bool {
    const v8_module: *ffi.Module = @ptrCast(@alignCast(module));
    return ffi.v8_Module_IsGraphAsync(v8_module);
}

// ============================================================================
// Helper functions for V8-specific operations
// ============================================================================

/// Get the V8 Isolate from a runtime Context
///
/// This is a convenience function for code that needs direct V8 access.
/// Prefer using the EngineInterface methods when possible.
pub fn getIsolate(ctx: runtime.Context) ?*ffi.Isolate {
    const engine_ctx = ctx.getEngineContext() orelse return null;
    return @ptrCast(@alignCast(engine_ctx));
}

/// Get the V8 Context from a runtime Context
///
/// This is a convenience function for code that needs direct V8 access.
/// Prefer using the EngineInterface methods when possible.
pub fn getV8Context(ctx: runtime.Context) ?*ffi.Context {
    const isolate = getIsolate(ctx) orelse return null;
    return ffi.v8_Isolate_GetCurrentContext(isolate);
}

// ============================================================================
// Dynamic Import Support
// ============================================================================

/// Callback type for handling dynamic imports
///
/// This is the Zig-side callback that receives dynamic import requests from V8.
/// The callback receives:
///   - ctx: Context passed during registration
///   - referrer: Module specifier of the calling module (may be empty)
///   - specifier: The specifier passed to import()
///   - resolver: Handle to resolve/reject the import promise
///
/// The callback must call resolveDynamicImport or rejectDynamicImport to complete.
pub const DynamicImportHandler = struct {
    callback: *const fn (ctx: ?*anyopaque, referrer: []const u8, specifier: []const u8, resolver: DynamicImportResolver) void,
    context: ?*anyopaque,
};

/// Handle for resolving/rejecting a dynamic import
pub const DynamicImportResolver = struct {
    context: *anyopaque,
    resolver: *anyopaque,

    /// Resolve with a successfully loaded module's namespace
    pub fn resolve(self: DynamicImportResolver, module_namespace: *ffi.Object) void {
        ffi.v8_DynamicImport_Resolve(self.context, self.resolver, module_namespace);
    }

    /// Reject with a value (a Global<Value>* the caller keeps)
    pub fn rejectWithValue(self: DynamicImportResolver, value: ?*ffi.Value) void {
        ffi.v8_DynamicImport_RejectWithValue(self.context, self.resolver, value);
    }

    /// Reject with an error message
    pub fn reject(self: DynamicImportResolver, error_message: []const u8) void {
        ffi.v8_DynamicImport_Reject(
            self.context,
            self.resolver,
            error_message.ptr,
            @intCast(error_message.len),
        );
    }
};

/// Global dynamic import handler (set per isolate)
var g_dynamic_import_handler: ?DynamicImportHandler = null;

/// The embedder's own import() algorithm - HTML's, which loads through the
/// document's module map - consulted BEFORE the per-context handler.
///
/// It returns false to decline (a context it does not serve, e.g. a worker's
/// or a ShadowRealm's), and the per-context handler then runs as before. When
/// it returns true it has taken over `resolver` and will settle the promise.
/// `type_attribute` is the import's "type" attribute, valid for the call.
pub const EmbedderDynamicImport = *const fn (
    context: *anyopaque,
    referrer: []const u8,
    specifier: []const u8,
    type_attribute: ?[]const u8,
    resolver: DynamicImportResolver,
) bool;

pub var embedder_dynamic_import: ?EmbedderDynamicImport = null;

/// FFI callback wrapper that converts C types to Zig types
fn dynamicImportCallbackWrapper(
    user_data: ?*anyopaque,
    context: ?*anyopaque,
    referrer_specifier: ?[*]const u8,
    referrer_len: c_int,
    specifier: [*]const u8,
    specifier_len: c_int,
    promise_resolver: *anyopaque,
    type_attribute: ?[*:0]const u8,
) callconv(.c) void {
    _ = user_data;

    if (embedder_dynamic_import) |embedder| {
        if (context) |ctx| {
            const referrer_slice = if (referrer_specifier) |ref| ref[0..@intCast(referrer_len)] else "";
            const resolver = DynamicImportResolver{ .context = ctx, .resolver = promise_resolver };
            const type_slice: ?[]const u8 = if (type_attribute) |t| std.mem.span(t) else null;
            if (embedder(ctx, referrer_slice, specifier[0..@intCast(specifier_len)], type_slice, resolver)) return;
        }
    }

    const handler = g_dynamic_import_handler orelse {
        // No handler registered, reject with error
        const ctx = context orelse return;
        ffi.v8_DynamicImport_Reject(
            ctx,
            promise_resolver,
            "No dynamic import handler registered".ptr,
            @intCast("No dynamic import handler registered".len),
        );
        return;
    };

    const ctx = context orelse return;

    // Convert referrer to slice
    const referrer = if (referrer_specifier) |ref|
        ref[0..@intCast(referrer_len)]
    else
        "";

    // Convert specifier to slice
    const spec = specifier[0..@intCast(specifier_len)];

    // Create resolver handle
    const resolver = DynamicImportResolver{
        .context = ctx,
        .resolver = promise_resolver,
    };

    // Call the Zig handler
    handler.callback(handler.context, referrer, spec, resolver);
}

/// Register a dynamic import handler for the given isolate
///
/// This enables import() expressions in JavaScript. When JavaScript calls import(),
/// V8 will invoke the handler which must:
/// 1. Fetch the requested module
/// 2. Compile and instantiate it
/// 3. Call resolver.resolve(namespace) or resolver.reject(error)
///
/// Example:
/// ```zig
/// fn handleDynamicImport(ctx: ?*anyopaque, referrer: []const u8, specifier: []const u8, resolver: DynamicImportResolver) void {
///     // Fetch and compile module...
///     const module = try compileModule(specifier);
///     const namespace = ffi.v8_Module_GetModuleNamespace(module);
///     resolver.resolve(namespace.?);
/// }
///
/// setDynamicImportHandler(isolate, .{
///     .callback = handleDynamicImport,
///     .context = my_context,
/// });
/// ```
pub fn setDynamicImportHandler(isolate: *ffi.Isolate, handler: DynamicImportHandler) void {
    g_dynamic_import_handler = handler;
    ffi.v8_Isolate_SetHostImportModuleDynamicallyCallback(
        isolate,
        handler.context,
        dynamicImportCallbackWrapper,
    );
}

/// Clear the dynamic import handler
pub fn clearDynamicImportHandler() void {
    g_dynamic_import_handler = null;
}

// ============================================================================
// Bfcache Freeze/Thaw Support
// ============================================================================

// Import the context manager for accessing event loops
const context_manager = @import("context_manager.zig");

/// Freeze a V8 context for the back-forward cache
///
/// This freezes the event loop associated with the context, stopping
/// all timer and task processing.
fn v8Freeze(
    engine_ctx: *anyopaque,
    context_handle: *anyopaque,
) EngineError!void {
    _ = context_handle;

    // engine_ctx is the V8 Context
    const v8_ctx: *ffi.Context = @ptrCast(@alignCast(engine_ctx));

    // Get the context entry which contains the event loop
    const ctx = context_manager.get(v8_ctx) orelse
        return EngineError.OperationFailed;

    // Get the event loop from context (use optional version for graceful handling)
    if (ctx.getOptionalEventLoop()) |ev_loop| {
        const event_loop_ptr = ev_loop.ptr;
        const v8_event_loop: *event_loop_mod.V8EventLoop = @ptrCast(@alignCast(event_loop_ptr));
        v8_event_loop.freeze() catch return EngineError.OperationFailed;
    }

    // Mark context as frozen (v8::Context::Exit is called by FrozenContextManager)
}

/// Thaw a V8 context from the back-forward cache
///
/// This resumes the event loop associated with the context.
fn v8Thaw(
    engine_ctx: *anyopaque,
    context_handle: *anyopaque,
) EngineError!void {
    _ = context_handle;

    // engine_ctx is the V8 Context
    const v8_ctx: *ffi.Context = @ptrCast(@alignCast(engine_ctx));

    // Re-enter the V8 context
    ffi.v8_Context_Enter(v8_ctx);

    // Get the context entry which contains the event loop
    const ctx = context_manager.get(v8_ctx) orelse
        return EngineError.OperationFailed;

    // Thaw the event loop (use optional version for graceful handling)
    if (ctx.getOptionalEventLoop()) |ev_loop| {
        const event_loop_ptr = ev_loop.ptr;
        const v8_event_loop: *event_loop_mod.V8EventLoop = @ptrCast(@alignCast(event_loop_ptr));
        v8_event_loop.thaw() catch return EngineError.OperationFailed;
    }
}

/// Check if a V8 context is currently frozen
fn v8IsFrozen(
    engine_ctx: *anyopaque,
    context_handle: *anyopaque,
) bool {
    _ = context_handle;

    // engine_ctx is the V8 Context
    const v8_ctx: *ffi.Context = @ptrCast(@alignCast(engine_ctx));

    // Get the context entry which contains the event loop
    const ctx = context_manager.get(v8_ctx) orelse return false;

    // Check if event loop is frozen (use optional version for graceful handling)
    if (ctx.getOptionalEventLoop()) |ev_loop| {
        const event_loop_ptr = ev_loop.ptr;
        const v8_event_loop: *event_loop_mod.V8EventLoop = @ptrCast(@alignCast(event_loop_ptr));
        return v8_event_loop.isFrozen();
    }

    return false;
}

// ============================================================================
// ForEach Callback Support (Collection Iteration)
// ============================================================================

/// Invoke a forEach-style callback for each element in a V8 collection
///
/// Iterates over arrays, Sets, Maps, or array-like objects and calls the
/// provided callback for each element.
///
/// TODO: Full implementation requires V8 FFI for Array.forEach, Map.forEach, etc.
/// For now, this is a stub that returns NoEngine to indicate the feature
/// is not yet fully implemented.
fn v8InvokeForEach(
    _: *anyopaque,
    _: *anyopaque,
    _: runtime.ForEachCallback,
    _: *anyopaque,
) EngineError!void {
    // TODO: Implement V8 forEach iteration
    // This requires:
    // 1. Check if collection is Array, Set, Map, or array-like
    // 2. Get iterator or use indexed access
    // 3. For each element, convert to opaque pointer and call callback
    // 4. Handle callback return value for early termination
    log.warn("v8InvokeForEach not yet implemented", .{});
    return EngineError.OperationFailed;
}

/// Get the length/size of a V8 collection
///
/// Returns the length property for arrays and array-likes, or size for Set/Map.
fn v8GetCollectionLength(
    engine_ctx: *anyopaque,
    collection: *anyopaque,
) u32 {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const value: *ffi.Value = @ptrCast(@alignCast(collection));

    // Check if it's an array - use fast path
    if (ffi.v8_Value_IsArray(value)) {
        const array: *ffi.Array = @ptrCast(value);
        return ffi.v8_Array_Length(array);
    }

    // For other collection types (Set, Map, NodeList), try to get .length or .size property
    if (ffi.v8_Value_IsObject(value)) {
        const object: *ffi.Object = @ptrCast(value);
        const isolate = ffi.v8_Isolate_GetCurrent() orelse return 0;

        // Try "length" property first (arrays, NodeList, etc.)
        const length_key = ffi.v8_String_NewFromUtf8(isolate, "length", 6);
        if (length_key) |key| {
            defer ffi.v8_String_Dispose(key);
            if (ffi.v8_Object_Get(object, context, @ptrCast(key))) |length_value| {
                if (ffi.v8_Value_IsNumber(length_value)) {
                    const int_val = ffi.v8_Value_NumberValue(length_value, context);
                    if (int_val >= 0 and int_val <= @as(f64, @floatFromInt(std.math.maxInt(u32)))) {
                        return @intFromFloat(int_val);
                    }
                }
            }
        }

        // Try "size" property (Set, Map)
        const size_key = ffi.v8_String_NewFromUtf8(isolate, "size", 4);
        if (size_key) |key| {
            defer ffi.v8_String_Dispose(key);
            if (ffi.v8_Object_Get(object, context, @ptrCast(key))) |size_value| {
                if (ffi.v8_Value_IsNumber(size_value)) {
                    const int_val = ffi.v8_Value_NumberValue(size_value, context);
                    if (int_val >= 0 and int_val <= @as(f64, @floatFromInt(std.math.maxInt(u32)))) {
                        return @intFromFloat(int_val);
                    }
                }
            }
        }
    }

    return 0;
}

/// Get an element from a V8 collection by index
///
/// For arrays and array-like objects, returns the element at the given index.
fn v8GetCollectionElement(
    engine_ctx: *anyopaque,
    collection: *anyopaque,
    index: u32,
) ?*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const value: *ffi.Value = @ptrCast(@alignCast(collection));

    // Check if it's an array - use fast path
    if (ffi.v8_Value_IsArray(value)) {
        const array: *ffi.Array = @ptrCast(value);
        if (ffi.v8_Array_Get(context, array, index)) |element| {
            return @ptrCast(element);
        }
        return null;
    }

    // For objects with numeric index access (NodeList, etc.), use Integer key
    if (ffi.v8_Value_IsObject(value)) {
        const object: *ffi.Object = @ptrCast(value);
        const isolate = ffi.v8_Isolate_GetCurrent() orelse return null;

        // Create integer key for index access
        const index_key: *ffi.Value = @ptrCast(ffi.v8_Integer_New(isolate, @intCast(index)));
        if (ffi.v8_Object_Get(object, context, index_key)) |element| {
            return @ptrCast(element);
        }
    }

    return null;
}

// ============================================================================
// Tests
// ============================================================================

test "v8_engine_interface - has all required functions" {
    const testing = std.testing;

    try testing.expect(v8_engine_interface.wrapAsyncIterator != null);
    try testing.expect(v8_engine_interface.createPromise != null);
    try testing.expect(v8_engine_interface.resolvePromise != null);
    try testing.expect(v8_engine_interface.rejectPromise != null);
    try testing.expect(v8_engine_interface.getPromiseObject != null);
    try testing.expect(v8_engine_interface.createEventLoop != null);
    try testing.expect(v8_engine_interface.destroyEventLoop != null);
    try testing.expect(v8_engine_interface.createCallbackWrapper != null);
    try testing.expect(v8_engine_interface.invokeCallback != null);
    try testing.expect(v8_engine_interface.destroyCallbackWrapper != null);
    try testing.expectEqualStrings("V8", v8_engine_interface.name);
}
