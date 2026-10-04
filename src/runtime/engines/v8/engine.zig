//! V8 operations the protocol's implementation (protocol*.zig) and the
//! adapter's other files share: entering a realm, promise capabilities,
//! structured serialization for storage, and the like.
//!
//! This file used to hold the V8 implementation of the runtime Engine table
//! (a struct of optional function pointers every realm carried, reached
//! through `ctx.getEngine()`). The table is gone: host code calls the engine
//! protocol, `@import("engine")`, which build.zig binds to protocol.zig.

const std = @import("std");
const runtime = @import("runtime");
const EngineError = runtime.EngineError;

// V8 FFI and helpers
const ffi = @import("ffi.zig");
const js_scope = @import("js_scope.zig");
const v8_conversions = @import("conversions.zig");
const value_operations = @import("value_operations.zig");
const serializable_objects = @import("serializable_objects.zig");
const context_manager = @import("context_manager.zig");
const pointer_tag = @import("pointer_tag.zig");
const TaggedPointer = pointer_tag.TaggedPointer;
const DebugAssertions = pointer_tag.DebugAssertions;

// Logging for V8 exceptions
// ============================================================================
// V8 Exception Logging Helpers
// ============================================================================

/// Promise handle for tracking V8 promise state
pub const V8PromiseHandle = struct {
    resolver: *ffi.PromiseResolver,
    promise: *ffi.Promise,
    isolate: *ffi.Isolate,
    context: *ffi.Context,
};

/// Create a V8 Promise that can be resolved/rejected from Zig
pub fn v8CreatePromise(
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

    errdefer ffi.v8_Global_Dispose(@ptrCast(resolver));
    const promise = ffi.v8_PromiseResolver_GetPromise(resolver) orelse return EngineError.PromiseError;
    errdefer ffi.v8_Global_Dispose(@ptrCast(promise));

    // Allocate handle to track the promise
    const handle = allocator.create(V8PromiseHandle) catch
        return EngineError.OutOfMemory;

    // Both handles are tagged with the realm the promise is made in. If that
    // realm is detached - its navigable destroyed, or its document replaced
    // by a navigation - its detach keeps them by an edge from its global
    // object instead of as roots (protocol_realms,
    // v8_Object_WeakenTaggedHandles): a capability that realm's own objects
    // keep, such as a navigation API method tracker's, which HTML leaves
    // ongoing on a document a cross-document navigation left, must not keep
    // the realm forever. A collected realm's capability then reads empty, and
    // settling it does nothing (no one can observe the promise). Released
    // through v8_Global_Dispose, which untags.
    if (context_manager.keyOf(context)) |key| {
        ffi.v8_Global_TagRealm(@ptrCast(resolver), key);
        ffi.v8_Global_TagRealm(@ptrCast(promise), key);
    }

    handle.* = .{
        .resolver = resolver,
        .promise = promise,
        .isolate = isolate,
        .context = context,
    };

    return @ptrCast(handle);
}

/// Resolve a V8 Promise with a value
pub fn v8ResolvePromise(
    engine_ctx: *anyopaque,
    promise_handle: *anyopaque,
    value: ?*const anyopaque,
) EngineError!void {
    _ = engine_ctx;
    const handle: *V8PromiseHandle = @ptrCast(@alignCast(promise_handle));
    // Its realm was collected: the promise with it - nothing to settle.
    if (promiseCollected(handle)) return;

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

/// Whether the capability's promise is gone: its realm was detached and
/// collected, and the handles its detach made weak read empty (see
/// v8CreatePromise). Settling it is then unobservable, and must not enter its
/// realm's context, which may be gone too.
pub fn promiseCollected(handle: *const V8PromiseHandle) bool {
    return ffi.v8_Global_IsEmpty(@ptrCast(handle.resolver));
}

/// Get the V8 Promise object to return to JavaScript
pub fn v8GetPromiseObject(promise_handle: *anyopaque) *anyopaque {
    const handle: *V8PromiseHandle = @ptrCast(@alignCast(promise_handle));
    return @ptrCast(handle.promise);
}

/// Destroy a V8 Promise handle after use
/// The Promise object itself remains valid (managed by V8 GC), but the
/// handle struct is freed.
pub fn v8DestroyPromiseHandle(promise_handle: *anyopaque, allocator: std.mem.Allocator) void {
    const handle: *V8PromiseHandle = @ptrCast(@alignCast(promise_handle));
    // The resolver is released here: nothing can settle the promise once its
    // handle is gone, and a Global to the resolver keeps the promise - and its
    // page - alive, whatever the GC would do otherwise. The promise's own
    // handle is not: getPromiseObject gave it to the caller, which returns it.
    // v8_Global_Dispose, not v8_PromiseResolver_Dispose: it also drops the
    // realm tag v8CreatePromise put on it.
    ffi.v8_Global_Dispose(@ptrCast(handle.resolver));
    allocator.destroy(handle);
}

// ============================================================================
// Realm operations (AGENTS.md, "The engine boundary")
// ============================================================================

/// A realm entered: its agent (isolate), when it was not the current one, and
/// a scope on its context.
pub const EnteredRealm = struct {
    isolate: *ffi.Isolate,
    entered_isolate: bool,
    scope: js_scope.JsScope,

    pub fn leaveScope(self: EnteredRealm) void {
        self.scope.deinit();
    }

    pub fn leaveAgent(self: EnteredRealm) void {
        if (self.entered_isolate) ffi.v8_Isolate_Exit(self.isolate);
    }
};

/// Enter `realm`: its isolate - recorded on the realm, which a worker realm on
/// this thread needs, else the current one - then a HandleScope and its context.
pub fn enterRealm(realm: runtime.Context) EngineError!EnteredRealm {
    const engine_ctx = realm.engine_ctx orelse return EngineError.OperationFailed;
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const current = ffi.v8_Isolate_GetCurrent();
    // The realm's own agent - a worker realm's is never the page's - as the
    // context manager recorded it; else its Realm's; else the current one.
    const recorded: ?*ffi.Isolate = if (realm.agent) |agent| @ptrCast(@alignCast(agent)) else if (realm.realm) |r| (if (r.agent) |a| @ptrCast(@alignCast(a)) else null) else null;
    const isolate = recorded orelse current orelse return EngineError.OperationFailed;
    const entered = current != isolate;
    if (entered) ffi.v8_Isolate_Enter(isolate);
    const scope = js_scope.JsScope.initFromV8Context(context) orelse {
        if (entered) ffi.v8_Isolate_Exit(isolate);
        return EngineError.OperationFailed;
    };
    return .{ .isolate = isolate, .entered_isolate = entered, .scope = scope };
}

pub fn v8RunTaskInRealm(realm: runtime.Context, steps: runtime.RealmSteps, data: ?*anyopaque) EngineError!void {
    // HTML "destroy a document" step 7: the tasks of a document whose
    // navigable was destroyed are removed without running. Its realm lives on
    // while script holds its WindowProxy (protocol_realms detach), and script
    // may still call into it; its tasks never run.
    if (@import("protocol_realms.zig").isDetached(realm)) return EngineError.OperationFailed;
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

pub fn v8RunInRealm(realm: runtime.Context, steps: runtime.RealmSteps, data: ?*anyopaque) EngineError!void {
    const entered = try enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    steps(data);
}

pub fn v8CreateDOMException(realm: runtime.Context, name: []const u8, message: []const u8) EngineError!runtime.JSValue {
    const entered = try enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    const value = v8_conversions.newDOMExceptionFromContext(entered.isolate, entered.scope.context, name, message) orelse
        return EngineError.OperationFailed;
    return .{ .handle = .{ .ptr = value } };
}

pub fn v8StructuredSerializeForStorage(realm: runtime.Context, value: runtime.JSValue, allocator: std.mem.Allocator) EngineError![]u8 {
    const entered = try enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    // HTML StructuredSerializeInternal step 4: a primitive is serialized as
    // it is, forStorage too. The binding hands an `any` primitive over as an
    // inline tag, not a handle, and a bare platform object as its Instance;
    // either is made a value in the realm for the serializer (a platform
    // object: its wrapper, a handle of our own) and released after.
    const made: ?*ffi.Value = switch (value) {
        .handle => null,
        else => value_operations.ownHandle(entered.isolate, entered.scope.context, value) catch
            return EngineError.OperationFailed,
    };
    defer if (made) |v| ffi.v8_Global_Dispose(v);
    const object: *ffi.Value = made orelse @ptrCast(@alignCast(value.handle.ptr));
    var no_transfer: [1]*ffi.Value = undefined;
    var no_buffers: [1]ffi.ArrayBufferTransferData = undefined;
    var size: usize = 0;
    var code: c_int = 0;
    // HTML StructuredSerializeForStorage: StructuredSerializeInternal(value,
    // true) - a platform object runs its interface's serialization steps
    // with forStorage true (serializable_objects.zig).
    var host: serializable_objects.Host = .{ .realm = realm, .for_storage = true, .allocator = allocator };
    const bytes = ffi.v8_Value_StructuredSerializeWithTransfer(object, &no_transfer, 0, &size, &no_buffers, &code, host.hostObjectSteps()) orelse
        return if (code == 3) EngineError.ExceptionPending else EngineError.DataCloneError;
    defer ffi.v8_Free_SerializedBuffer(bytes);
    return allocator.dupe(u8, bytes[0..size]) catch EngineError.OutOfMemory;
}

pub fn v8StructuredDeserialize(realm: runtime.Context, bytes: []const u8) EngineError!runtime.JSValue {
    const entered = try enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    const no_buffers: [1]ffi.ArrayBufferTransferData = undefined;
    var code: c_int = 0;
    // StructuredDeserialize(serialized, targetRealm = `realm`): a platform
    // object is made there by its interface's deserialization steps.
    var host: serializable_objects.Host = .{ .realm = realm, .for_storage = false, .allocator = std.heap.c_allocator };
    const value = ffi.v8_Value_DeserializeWithTransfer_CrossIsolate(bytes.ptr, bytes.len, &no_buffers, 0, &code, host.hostObjectSteps()) orelse
        return EngineError.DataCloneError;
    return .{ .handle = .{ .ptr = value } };
}

pub fn v8RejectPromiseWithValue(promise_handle: *anyopaque, value: runtime.JSValue) EngineError!void {
    const handle: *V8PromiseHandle = @ptrCast(@alignCast(promise_handle));
    // Its realm was collected: the promise with it - nothing to settle.
    if (promiseCollected(handle)) return;
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

/// Release an OWNED value (engine.Owned.release): its handle, if it has one.
/// Only an Owned reaches here - a borrowed JSValue is never released - so a
/// handle is disposed unconditionally.
pub fn v8ReleaseValue(value: runtime.JSValue) void {
    switch (value) {
        .handle => |h| ffi.v8_Global_Dispose(@ptrCast(@alignCast(h.ptr))),
        else => {},
    }
}

/// Create a V8 ArrayBuffer from bytes
pub fn v8CreateArrayBuffer(
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

// ============================================================================
// Wrappers
// ============================================================================

/// Get the V8 wrapper for a Zig runtime instance from the cache
///
/// Arguments:
///   - engine_ctx: V8 Context pointer (unused, cache has its own context)
///   - wrapper_cache: WrapperCache pointer
///   - instance: runtime.Instance pointer
///
/// Returns:
///   - V8 Object* if found in cache, null otherwise
pub fn v8GetWrapperForInstance(
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
