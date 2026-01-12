//! Implementation for DedicatedWorkerGlobalScope interface
//!
//! Spec: HTML Standard § 10.2.3.2 The DedicatedWorkerGlobalScope interface
//! https://html.spec.whatwg.org/#dedicatedworkerglobalscope
//!
//! The global scope object inside a dedicated worker. Extends WorkerGlobalScope
//! with dedicated worker-specific functionality like postMessage and close.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const DedicatedWorkerGlobalScope = interfaces.DedicatedWorkerGlobalScope;
const EventTarget = interfaces.EventTarget;
const MessageEvent = interfaces.MessageEvent;

// Import workers infrastructure
const html_core = @import("html_core");
const workers = html_core.workers;
const DedicatedWorker = workers.DedicatedWorker;

// Import structured clone for message passing
const structured_clone = html_core.structured_clone;

// Import V8 engine for callback invocation
const v8_engine = @import("v8");
const template_registry = v8_engine.template_registry;

// Import EventTarget impl for internal state access
const EventTargetImpl = @import("EventTarget.zig");

pub const State = DedicatedWorkerGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
    PostMessageFailed,
    WorkerClosed,
};

/// Internal state for DedicatedWorkerGlobalScope implementation
///
/// Contains a reference to the backing DedicatedWorker and worker-specific state.
pub const InternalState = struct {
    /// Reference to the dedicated worker (not owned)
    dedicated_worker: ?*DedicatedWorker = null,

    /// Worker name
    name: []const u8 = "",

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        // We don't own the dedicated_worker, so don't deinit it
        _ = self;
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Initialize with a backing dedicated worker
pub fn initWithWorker(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    dedicated_worker: *DedicatedWorker,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal state
    const internal_state = try allocator.create(InternalState);
    internal_state.* = .{
        .dedicated_worker = dedicated_worker,
        .name = dedicated_worker.getName(),
        .allocator = allocator,
    };

    // Store internal state
    var state = instance.getState(State);
    state.own._internal = internal_state;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for name
///
/// Spec: HTML Standard § 10.2.3.2
/// "The name attribute must return the DedicatedWorkerGlobalScope object's name."
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.name);
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for onrtctransform
pub fn get_onrtctransform(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onrtctransform;
}

/// Getter for onmessage
pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onmessage;
}

/// Getter for onmessageerror
pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onmessageerror;
}

/// Setter for onrtctransform
pub fn set_onrtctransform(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onrtctransform = value;
}

/// Setter for onmessage
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onmessage = value;
}

/// Setter for onmessageerror
pub fn set_onmessageerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onmessageerror = value;
}

/// Operation: requestAnimationFrame
///
/// Spec: HTML Standard § 10.10.3
/// Request animation frame in worker context (for OffscreenCanvas).
/// Returns a handle that can be used with cancelAnimationFrame.
pub fn call_requestAnimationFrame(instance: *runtime.Instance, callback: callbacks.FrameRequestCallback) anyerror!u32 {
    _ = instance;
    _ = callback;
    // Animation frames in workers require OffscreenCanvas support
    // For now, return a dummy handle
    return 0;
}

/// Operation: cancelAnimationFrame
///
/// Spec: HTML Standard § 10.10.3
/// Cancel a previously requested animation frame.
pub fn call_cancelAnimationFrame(instance: *runtime.Instance, handle: u32) anyerror!void {
    _ = instance;
    _ = handle;
    // Animation frames in workers require OffscreenCanvas support
}

/// Operation: close
///
/// Spec: HTML Standard § 10.2.3.2 close()
/// "The close() method, when invoked, must run these steps:
/// 1. Discard any tasks that have been added to this's relevant agent's event loop's task queues.
/// 2. Set this's closing flag to true."
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.dedicated_worker) |worker| {
            worker.close();
        }
    }
}

/// Operation: postMessage
///
/// Spec: HTML Standard § 10.2.3.2 postMessage(message, transfer)
/// Posts a message from the worker to the outside (to the owner).
///
/// "The postMessage(message, transfer) and postMessage(message, options) methods
/// on DedicatedWorkerGlobalScope objects act as if, when invoked, it immediately
/// invoked the respective postMessage(message, transfer) and postMessage(message, options)
/// methods on the port that the DedicatedWorkerGlobalScope object's implicit port is
/// entanwith, with the same arguments."
pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
    std.debug.print("[DWGScope.call_postMessage] ENTRY, message type: {s}\n", .{@tagName(message)});
    _ = transfer; // TODO: Handle transfer list properly
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.dedicated_worker) |worker| {
            std.debug.print("[DWGScope.call_postMessage] have internal and worker\n", .{});
            // Convert from runtime.JSValue to structured_clone.JSValue
            // This properly walks V8 objects to create serializable values
            const allocator = internal.allocator;
            const js_value = try runtimeToStructuredClone(allocator, message, instance.ctx);
            std.debug.print("[DWGScope.call_postMessage] converted to structured_clone, type: {s}\n", .{@tagName(js_value)});
            defer freeStructuredCloneValue(allocator, js_value);

            // Use postMessageFromWorker which properly serializes the message
            // and uses thread-safe outbox for cross-thread messaging
            try worker.postMessageFromWorker(&js_value, null);
            std.debug.print("[DWGScope.call_postMessage] postMessageFromWorker returned successfully\n", .{});
        } else {
            std.debug.print("[DWGScope.call_postMessage] dedicated_worker is null\n", .{});
        }
    } else {
        std.debug.print("[DWGScope.call_postMessage] _internal is null\n", .{});
    }
}

/// Error type for structured clone operations
const StructuredCloneError = error{OutOfMemory};

/// Convert a runtime.JSValue to structured_clone.JSValue
///
/// This properly walks V8 objects to create serializable values.
/// For production use - handles all value types including complex objects and arrays.
fn runtimeToStructuredClone(allocator: std.mem.Allocator, value: runtime.JSValue, ctx: runtime.Context) !structured_clone.JSValue {
    return switch (value) {
        .undefined => structured_clone.JSValue.undefined,
        .null => structured_clone.JSValue.null,
        .boolean => |b| .{ .boolean = b },
        .number => |n| .{ .number = n },
        .string => |s| .{ .string = s.data },
        .handle => |h| try handleToStructuredClone(allocator, h, ctx),
        .instance => structured_clone.JSValue.undefined, // Instance references can't be cloned
    };
}

/// Convert a V8 handle (complex object) to structured_clone.JSValue
///
/// Walks the V8 object graph to extract all properties recursively.
fn handleToStructuredClone(allocator: std.mem.Allocator, handle: runtime.JSValue.EngineHandle, ctx: runtime.Context) !structured_clone.JSValue {
    const engine_ctx = ctx.engine_ctx orelse return structured_clone.JSValue.undefined;
    const v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const v8_isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return structured_clone.JSValue.undefined;

    // Create HandleScope for V8 operations
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(v8_isolate);
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    // Get local handle from global/persistent handle
    const v8_value: *v8_engine.ffi.Value = blk: {
        if (handle.handle_scope == .global) {
            const global = v8_engine.GlobalHandle{ .ptr = @ptrCast(handle.ptr) };
            break :blk global.get(v8_isolate) orelse return structured_clone.JSValue.undefined;
        } else {
            break :blk @ptrCast(handle.ptr);
        }
    };

    // Check if it's an array
    if (v8_engine.ffi.v8_Value_IsArray(v8_value)) {
        return try v8ArrayToStructuredClone(allocator, @ptrCast(v8_value), v8_context, v8_isolate, ctx);
    }

    // Check if it's an object
    if (v8_engine.ffi.v8_Value_IsObject(v8_value)) {
        return try v8ObjectToStructuredClone(allocator, @ptrCast(v8_value), v8_context, v8_isolate, ctx);
    }

    // For other types, try to extract primitive value
    if (v8_engine.ffi.v8_Value_IsString(v8_value)) {
        const str = v8_engine.ffi.v8_Value_ToString(v8_value, v8_context) orelse return structured_clone.JSValue.undefined;
        const len: usize = @intCast(v8_engine.ffi.v8_String_Utf8Length(str));
        if (len == 0) return .{ .string = "" };

        const buf = try allocator.alloc(u8, len);
        _ = v8_engine.ffi.v8_String_WriteUtf8(str, buf.ptr, @intCast(len));
        return .{ .string = buf };
    }

    if (v8_engine.ffi.v8_Value_IsNumber(v8_value)) {
        const num = v8_engine.ffi.v8_Value_NumberValue(v8_value, v8_context);
        return .{ .number = num };
    }

    if (v8_engine.ffi.v8_Value_IsBoolean(v8_value)) {
        const b = v8_engine.ffi.v8_Value_BooleanValue(v8_value, v8_isolate);
        return .{ .boolean = b };
    }

    if (v8_engine.ffi.v8_Value_IsNull(v8_value)) {
        return structured_clone.JSValue.null;
    }

    if (v8_engine.ffi.v8_Value_IsUndefined(v8_value)) {
        return structured_clone.JSValue.undefined;
    }

    return structured_clone.JSValue.undefined;
}

/// Convert a V8 Array to structured_clone.JSValue.ArrayValue
fn v8ArrayToStructuredClone(
    allocator: std.mem.Allocator,
    v8_array: *v8_engine.ffi.Array,
    v8_context: *v8_engine.ffi.Context,
    v8_isolate: *v8_engine.ffi.Isolate,
    ctx: runtime.Context,
) StructuredCloneError!structured_clone.JSValue {
    const length = v8_engine.ffi.v8_Array_Length(v8_array);
    if (length == 0) {
        return .{ .array = .{ .length = 0, .elements = &[_]?*const structured_clone.JSValue{} } };
    }

    // Allocate array of pointers to JSValue
    const elements = try allocator.alloc(?*const structured_clone.JSValue, length);
    errdefer allocator.free(elements);

    for (0..length) |i| {
        const index_value = v8_engine.ffi.v8_Integer_New(v8_isolate, @intCast(i));
        const element = v8_engine.ffi.v8_Object_Get(@ptrCast(v8_array), v8_context, @ptrCast(index_value));
        if (element) |elem| {
            // Allocate the JSValue and store pointer to it
            const value_ptr = try allocator.create(structured_clone.JSValue);
            value_ptr.* = try v8ValueToStructuredClone(allocator, elem, v8_context, v8_isolate, ctx);
            elements[i] = value_ptr;
        } else {
            elements[i] = null;
        }
    }

    return .{ .array = .{ .length = length, .elements = elements } };
}

/// Convert a V8 Object to structured_clone.JSValue.ObjectValue
fn v8ObjectToStructuredClone(
    allocator: std.mem.Allocator,
    v8_object: *v8_engine.ffi.Object,
    v8_context: *v8_engine.ffi.Context,
    v8_isolate: *v8_engine.ffi.Isolate,
    ctx: runtime.Context,
) StructuredCloneError!structured_clone.JSValue {
    // Get own property names
    const property_names = v8_engine.ffi.v8_Object_GetOwnPropertyNames(v8_context, v8_object) orelse {
        return .{ .object = .{ .properties = &[_]structured_clone.JSValue.ObjectValue.ObjectProperty{} } };
    };

    const prop_count = v8_engine.ffi.v8_Array_Length(property_names);
    if (prop_count == 0) {
        return .{ .object = .{ .properties = &[_]structured_clone.JSValue.ObjectValue.ObjectProperty{} } };
    }

    const properties = try allocator.alloc(structured_clone.JSValue.ObjectValue.ObjectProperty, prop_count);
    errdefer allocator.free(properties);

    var valid_count: usize = 0;
    for (0..prop_count) |i| {
        const index_value = v8_engine.ffi.v8_Integer_New(v8_isolate, @intCast(i));
        const key_value = v8_engine.ffi.v8_Object_Get(@ptrCast(property_names), v8_context, @ptrCast(index_value)) orelse continue;

        // Get key as string
        const key_str = v8_engine.ffi.v8_Value_ToString(key_value, v8_context) orelse continue;
        const key_len: usize = @intCast(v8_engine.ffi.v8_String_Utf8Length(key_str));
        if (key_len == 0) continue;

        const key_buf = try allocator.alloc(u8, key_len);
        _ = v8_engine.ffi.v8_String_WriteUtf8(key_str, key_buf.ptr, @intCast(key_len));

        // Get value
        const prop_value = v8_engine.ffi.v8_Object_Get(v8_object, v8_context, key_value) orelse {
            allocator.free(key_buf);
            continue;
        };

        const converted_value = try v8ValueToStructuredClone(allocator, prop_value, v8_context, v8_isolate, ctx);

        // Allocate the value on heap and store pointer
        const value_ptr = try allocator.create(structured_clone.JSValue);
        value_ptr.* = converted_value;

        properties[valid_count] = .{
            .key = key_buf,
            .value = value_ptr,
        };
        valid_count += 1;
    }

    // Shrink to actual size if needed
    if (valid_count < prop_count) {
        const shrunk = try allocator.realloc(properties, valid_count);
        return .{ .object = .{ .properties = shrunk } };
    }

    return .{ .object = .{ .properties = properties } };
}

/// Convert any V8 value to structured_clone.JSValue
fn v8ValueToStructuredClone(
    allocator: std.mem.Allocator,
    v8_value: *v8_engine.ffi.Value,
    v8_context: *v8_engine.ffi.Context,
    v8_isolate: *v8_engine.ffi.Isolate,
    ctx: runtime.Context,
) StructuredCloneError!structured_clone.JSValue {
    if (v8_engine.ffi.v8_Value_IsUndefined(v8_value)) {
        return structured_clone.JSValue.undefined;
    }
    if (v8_engine.ffi.v8_Value_IsNull(v8_value)) {
        return structured_clone.JSValue.null;
    }
    if (v8_engine.ffi.v8_Value_IsBoolean(v8_value)) {
        return .{ .boolean = v8_engine.ffi.v8_Value_BooleanValue(v8_value, v8_isolate) };
    }
    if (v8_engine.ffi.v8_Value_IsNumber(v8_value)) {
        return .{ .number = v8_engine.ffi.v8_Value_NumberValue(v8_value, v8_context) };
    }
    if (v8_engine.ffi.v8_Value_IsString(v8_value)) {
        const str = v8_engine.ffi.v8_Value_ToString(v8_value, v8_context) orelse return .{ .string = "" };
        const len: usize = @intCast(v8_engine.ffi.v8_String_Utf8Length(str));
        if (len == 0) return .{ .string = "" };

        const buf = try allocator.alloc(u8, len);
        _ = v8_engine.ffi.v8_String_WriteUtf8(str, buf.ptr, @intCast(len));
        return .{ .string = buf };
    }
    if (v8_engine.ffi.v8_Value_IsArray(v8_value)) {
        return try v8ArrayToStructuredClone(allocator, @ptrCast(v8_value), v8_context, v8_isolate, ctx);
    }
    if (v8_engine.ffi.v8_Value_IsObject(v8_value)) {
        return try v8ObjectToStructuredClone(allocator, @ptrCast(v8_value), v8_context, v8_isolate, ctx);
    }

    return structured_clone.JSValue.undefined;
}

/// Free a structured_clone.JSValue that was allocated by runtimeToStructuredClone
fn freeStructuredCloneValue(allocator: std.mem.Allocator, value: structured_clone.JSValue) void {
    switch (value) {
        .string => |s| {
            if (s.len > 0) {
                // Only free if it's a heap-allocated string (not empty or interned)
                // We allocated these in v8ValueToStructuredClone
                allocator.free(s);
            }
        },
        .array => |arr| {
            for (arr.elements) |elem_ptr| {
                if (elem_ptr) |ptr| {
                    freeStructuredCloneValue(allocator, ptr.*);
                    allocator.destroy(ptr);
                }
            }
            if (arr.elements.len > 0) {
                allocator.free(arr.elements);
            }
        },
        .object => |obj| {
            for (obj.properties) |prop| {
                if (prop.key.len > 0) {
                    allocator.free(prop.key);
                }
                freeStructuredCloneValue(allocator, prop.value.*);
                allocator.destroy(prop.value);
            }
            if (obj.properties.len > 0) {
                allocator.free(obj.properties);
            }
        },
        else => {},
    }
}

// ============================================================================
// MessageEvent Dispatch
// ============================================================================

/// Dispatch a MessageEvent to this DedicatedWorkerGlobalScope
///
/// This is called by the dedicated worker's inside port handler when a message
/// arrives from the main thread. Uses the DOM event dispatch algorithm via
/// EventTarget.dispatchEvent.
///
/// Spec: HTML Standard § 10.2.3
/// "Queue a global task on the messaging task source... fire an event named
/// message at the DedicatedWorkerGlobalScope object."
pub fn dispatchMessageEvent(instance: *runtime.Instance, serialized_data: *structured_clone.SerializedValue, origin: ?[]const u8) anyerror!void {
    std.log.info("[WORKER] dispatchMessageEvent() START", .{});
    std.log.info("[WORKER]   instance: {*}", .{instance});
    std.log.info("[WORKER]   serialized_data: {*}", .{serialized_data});
    std.log.info("[WORKER]   serialized_data.type: {s}", .{@tagName(serialized_data.type)});
    std.log.info("[WORKER]   origin: {?s}", .{origin});

    const state = instance.getState(State);
    const allocator = if (state.own._internal) |internal| internal.allocator else {
        std.log.err("[WORKER] dispatchMessageEvent() ERROR: NotInitialized", .{});
        return error.NotInitialized;
    };

    // Deserialize the message data
    std.log.info("[WORKER] dispatchMessageEvent() deserializing...", .{});
    const deserialized = structured_clone.structuredDeserialize(
        allocator,
        serialized_data,
    ) catch |err| {
        std.log.err("[WORKER] dispatchMessageEvent() deserialization FAILED: {s}", .{@errorName(err)});
        // If deserialization fails, fire 'messageerror' event instead of 'message'
        // Spec: HTML Standard § 9.3.6.2
        // "If this throws an exception, then fire an event named messageerror at the port"
        dispatchMessageErrorEvent(instance, origin) catch |err2| {
            std.log.warn("Failed to dispatch messageerror event: {s}", .{@errorName(err2)});
        };
        return error.DeserializationFailed;
    };
    std.log.info("[WORKER] dispatchMessageEvent() deserialized: {*}", .{deserialized});

    // Create MessageEventInit dictionary
    const init_dict = dictionaries.MessageEventInit{
        .base = .{
            .bubbles = false,
            .cancelable = false,
            .composed = false,
        },
        .data = deserialized.toRuntimeJSValue(),
        .origin = origin orelse "",
        .lastEventId = null,
        .source = null,
        .ports = null,
    };

    // Create MessageEvent via interface
    std.log.info("[WORKER] dispatchMessageEvent() creating MessageEvent...", .{});
    const event = try MessageEvent.call_constructor(
        instance.ctx,
        runtime.DOMString.initInterned("message"),
        webidl.Opt(dictionaries.MessageEventInit).passed(init_dict),
    );
    std.log.info("[WORKER] dispatchMessageEvent() MessageEvent created: {*}", .{event});

    // CRITICAL: Wrap the MessageEvent instance in a V8 object with internal fields
    // This is necessary because call_constructor only creates the Zig instance,
    // but JavaScript property accessors (like .data) need a V8 wrapper with
    // internal fields pointing to the Zig instance.
    const isolate = instance.ctx.isolate;
    const v8_context = instance.ctx.context;
    _ = template_registry.wrapInstanceAsV8Object(event, "MessageEvent", isolate, v8_context) catch |err| {
        std.log.err("[WORKER] dispatchMessageEvent() Failed to wrap MessageEvent: {s}", .{@errorName(err)});
        return err;
    };
    std.log.info("[WORKER] dispatchMessageEvent() MessageEvent wrapped in V8 object", .{});

    // Set isTrusted and target/currentTarget
    {
        var ev_state = event.getState(MessageEvent.State);
        ev_state.base.own.isTrusted = true;
        ev_state.base.own.target = instance;
        ev_state.base.own.currentTarget = instance;
    }

    // Dispatch via EventTarget.dispatchEvent
    // This invokes all addEventListener-registered listeners
    std.log.info("[WORKER] dispatchMessageEvent() dispatching via EventTarget...", .{});
    _ = EventTarget.call_dispatchEvent(instance, event) catch |err| {
        std.log.err("[WORKER] dispatchMessageEvent() EventTarget.dispatchEvent FAILED: {s}", .{@errorName(err)});
    };
    std.log.info("[WORKER] dispatchMessageEvent() EventTarget dispatch complete", .{});

    // Also invoke the legacy onmessage handler if set via IDL attribute
    std.log.info("[WORKER] dispatchMessageEvent() invoking legacy onmessage handler...", .{});
    invokeLegacyOnmessageHandler(instance, event);
    std.log.info("[WORKER] dispatchMessageEvent() COMPLETE", .{});
}

/// Invoke the legacy onmessage IDL attribute handler
///
/// Per HTML spec, the onXXX IDL event handlers are separate from addEventListener.
/// The onmessage property is stored in state.own.onmessage as an EventHandler
/// (which is a tagged pointer to a GlobalHandle).
fn invokeLegacyOnmessageHandler(instance: *runtime.Instance, event: *runtime.Instance) void {
    const state = instance.getState(State);

    // Get the onmessage handler
    const handler = state.own.onmessage orelse return;

    // Get V8 context from the event's runtime context
    const engine_ctx = event.ctx.engine_ctx orelse return;
    const v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const v8_isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return;

    // Create HandleScope
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(v8_isolate);
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    // Untag the pointer to get the GlobalHandle
    const untagged = v8_engine.pointer_tag.untagPointer(handler);
    if (untagged.tag != .global_handle and untagged.tag != .untagged) {
        return; // Not a V8 callback
    }

    const global_handle = v8_engine.GlobalHandle{ .ptr = @ptrCast(@alignCast(untagged.ptr)) };
    const local_value = global_handle.get(v8_isolate) orelse return;

    if (!v8_engine.ffi.v8_Value_IsFunction(@ptrCast(local_value))) {
        return;
    }
    const function: *v8_engine.ffi.Function = @ptrCast(local_value);

    // Wrap the event as a V8 object
    const v8_event = template_registry.wrapInstanceAsV8Object(
        event,
        "MessageEvent",
        v8_isolate,
        v8_context,
    ) catch return;

    // Call the handler
    const undefined_recv = v8_engine.ffi.v8_Undefined(v8_isolate);
    var args = [_]*v8_engine.ffi.Value{@ptrCast(v8_event)};
    _ = v8_engine.ffi.v8_Function_Call(function, v8_context, @ptrCast(undefined_recv), 1, &args);
}

/// Dispatch a messageerror event to this DedicatedWorkerGlobalScope
///
/// Spec: HTML Standard § 9.3.6.2
/// "If this throws an exception, then fire an event named messageerror at the port,
/// using MessageEvent, with the origin attribute initialized to origin..."
///
/// This is called when structured clone deserialization fails on a received message.
fn dispatchMessageErrorEvent(instance: *runtime.Instance, origin: ?[]const u8) anyerror!void {
    // Create MessageEventInit dictionary for messageerror
    // Per spec, data is undefined for messageerror events
    const init_dict = dictionaries.MessageEventInit{
        .base = .{
            .bubbles = false,
            .cancelable = false,
            .composed = false,
        },
        .data = null, // data is undefined for messageerror
        .origin = origin orelse "",
        .lastEventId = null,
        .source = null,
        .ports = null,
    };

    // Create MessageEvent via interface with type "messageerror"
    const event = try MessageEvent.call_constructor(
        instance.ctx,
        runtime.DOMString.initInterned("messageerror"),
        webidl.Opt(dictionaries.MessageEventInit).passed(init_dict),
    );

    // Set isTrusted and target/currentTarget
    {
        var ev_state = event.getState(MessageEvent.State);
        ev_state.base.own.isTrusted = true;
        ev_state.base.own.target = instance;
        ev_state.base.own.currentTarget = instance;
    }

    // Dispatch via EventTarget.dispatchEvent
    _ = EventTarget.call_dispatchEvent(instance, event) catch |err| {
        std.log.warn("Failed to dispatch messageerror event to worker scope: {s}", .{@errorName(err)});
        return err;
    };

    // Also invoke the legacy onmessageerror handler if set
    invokeLegacyOnmessageerrorHandler(instance, event);
}

/// Invoke the legacy onmessageerror IDL attribute handler
fn invokeLegacyOnmessageerrorHandler(instance: *runtime.Instance, event: *runtime.Instance) void {
    const state = instance.getState(State);

    // Get the onmessageerror handler
    const handler = state.own.onmessageerror orelse return;

    // Get V8 context from the event's runtime context
    const engine_ctx = event.ctx.engine_ctx orelse return;
    const v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const v8_isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return;

    // Create HandleScope
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(v8_isolate);
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    // Untag the pointer to get the GlobalHandle
    const untagged = v8_engine.pointer_tag.untagPointer(handler);
    if (untagged.tag != .global_handle and untagged.tag != .untagged) {
        return; // Not a V8 callback
    }

    const global_handle = v8_engine.GlobalHandle{ .ptr = @ptrCast(@alignCast(untagged.ptr)) };
    const local_value = global_handle.get(v8_isolate) orelse return;

    if (!v8_engine.ffi.v8_Value_IsFunction(@ptrCast(local_value))) {
        return;
    }
    const function: *v8_engine.ffi.Function = @ptrCast(local_value);

    // Wrap the event as a V8 object
    const v8_event = template_registry.wrapInstanceAsV8Object(
        event,
        "MessageEvent",
        v8_isolate,
        v8_context,
    ) catch return;

    // Call the handler
    const undefined_recv = v8_engine.ffi.v8_Undefined(v8_isolate);
    var args = [_]*v8_engine.ffi.Value{@ptrCast(v8_event)};
    _ = v8_engine.ffi.v8_Function_Call(function, v8_context, @ptrCast(undefined_recv), 1, &args);
}

/// Wire up the message handler on the dedicated worker's inside port
///
/// This should be called after the DedicatedWorkerGlobalScope is created
/// and linked to its DedicatedWorker.
pub fn setupMessageHandler(instance: *runtime.Instance) void {
    std.log.info("[WORKER] setupMessageHandler() called, instance: {*}", .{instance});
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        std.log.info("[WORKER] setupMessageHandler() has internal state: {*}", .{internal});
        if (internal.dedicated_worker) |worker| {
            std.log.info("[WORKER] setupMessageHandler() has dedicated_worker: {*}", .{worker});
            std.log.info("[WORKER]   inside_port: {*}", .{worker.port_pair.inside_port});
            std.log.info("[WORKER]   outside_port: {*}", .{worker.port_pair.outside_port});
            // Store the instance pointer in worker.user_data for use in the callback
            worker.user_data = instance;
            std.log.info("[WORKER] setupMessageHandler() stored instance in user_data", .{});

            // Set up the message handler callback
            // When a message arrives from the main thread, this dispatches a MessageEvent
            worker.setInsideMessageHandler(struct {
                fn handleMessage(w: *DedicatedWorker, msg: *workers.message_channel.QueuedMessage) void {
                    std.log.info("[WORKER] handleMessage() CALLBACK INVOKED!", .{});
                    std.log.info("[WORKER]   worker ptr: {*}", .{w});
                    std.log.info("[WORKER]   msg ptr: {*}", .{msg});
                    std.log.info("[WORKER]   user_data: {?*}", .{w.user_data});

                    // Retrieve the DedicatedWorkerGlobalScope instance from user_data
                    const scope_instance: *runtime.Instance = @ptrCast(@alignCast(w.user_data orelse {
                        std.log.err("[WORKER] handleMessage() ERROR: user_data is null!", .{});
                        return;
                    }));
                    std.log.info("[WORKER]   scope_instance: {*}", .{scope_instance});

                    // Get the serialized data from the queued message
                    const serialized_data = msg.data orelse {
                        std.log.err("[WORKER] handleMessage() ERROR: msg.data is null!", .{});
                        return;
                    };
                    std.log.info("[WORKER]   serialized_data type: {s}", .{@tagName(serialized_data.type)});

                    // Dispatch the MessageEvent to this scope
                    // This deserializes the data and fires a 'message' event
                    std.log.info("[WORKER] handleMessage() calling dispatchMessageEvent...", .{});
                    dispatchMessageEvent(scope_instance, serialized_data, null) catch |err| {
                        std.log.err("[WORKER] handleMessage() dispatchMessageEvent FAILED: {s}", .{@errorName(err)});
                    };
                    std.log.info("[WORKER] handleMessage() COMPLETE", .{});
                }
            }.handleMessage);
            std.log.info("[WORKER] setupMessageHandler() callback registered", .{});
        } else {
            std.log.warn("[WORKER] setupMessageHandler() dedicated_worker is null!", .{});
        }
    } else {
        std.log.warn("[WORKER] setupMessageHandler() internal state is null!", .{});
    }
}

/// Set up message handler directly on a DedicatedWorker without requiring a runtime.Instance
/// This is used during worker initialization when we don't have a full instance yet.
/// The callback stores the runtime context and invokes onmessage handlers via JavaScript.
pub fn setupMessageHandlerDirect(dedicated_worker: *DedicatedWorker, runtime_ctx: runtime.Context) void {
    std.log.info("[WORKER] setupMessageHandlerDirect() called", .{});
    std.log.info("[WORKER]   dedicated_worker: {*}", .{dedicated_worker});
    std.log.info("[WORKER]   inside_port: {*}", .{dedicated_worker.port_pair.inside_port});

    // Store the runtime context pointer in user_data for the callback
    // We use a simple struct to hold both the context and worker
    const CallbackData = struct {
        ctx: runtime.Context,
        worker: *DedicatedWorker,
    };

    const callback_data = runtime_ctx.allocator.create(CallbackData) catch {
        std.log.err("[WORKER] setupMessageHandlerDirect() failed to allocate callback data", .{});
        return;
    };
    callback_data.* = .{
        .ctx = runtime_ctx,
        .worker = dedicated_worker,
    };

    dedicated_worker.user_data = callback_data;
    std.log.info("[WORKER] setupMessageHandlerDirect() stored callback data in user_data", .{});

    // Set up the message handler callback
    dedicated_worker.setInsideMessageHandler(struct {
        fn handleMessage(w: *DedicatedWorker, msg: *workers.message_channel.QueuedMessage) void {
            std.log.info("[WORKER] handleMessageDirect() CALLBACK INVOKED!", .{});

            const data: *CallbackData = @ptrCast(@alignCast(w.user_data orelse {
                std.log.err("[WORKER] handleMessageDirect() ERROR: user_data is null!", .{});
                return;
            }));

            // msg.data is non-optional *SerializedValue
            const serialized_data = msg.data;
            std.log.info("[WORKER] handleMessageDirect() serialized_data type: {s}", .{@tagName(serialized_data.type)});

            // Dispatch the message event using the V8 context
            dispatchMessageEventDirect(data.ctx, serialized_data) catch |err| {
                std.log.err("[WORKER] handleMessageDirect() dispatchMessageEventDirect FAILED: {s}", .{@errorName(err)});
            };
            std.log.info("[WORKER] handleMessageDirect() COMPLETE", .{});
        }
    }.handleMessage);
    std.log.info("[WORKER] setupMessageHandlerDirect() callback registered", .{});
}

/// Dispatch a MessageEvent directly using the V8 context (without runtime.Instance)
///
/// This function creates a REAL MessageEvent via the WebIDL interface constructor,
/// wraps it properly in V8, and dispatches it through the proper event system.
/// This ensures MessageEvent.prototype.data accessor works correctly.
pub fn dispatchMessageEventDirect(ctx: runtime.Context, serialized_data: *structured_clone.SerializedValue) !void {
    std.log.info("[WORKER] dispatchMessageEventDirect() called", .{});

    // Get allocator from context
    const allocator = ctx.allocator;

    // Deserialize the structured clone data to a JSValue
    std.log.info("[WORKER] dispatchMessageEventDirect() deserializing...", .{});
    const deserialized = structured_clone.structuredDeserialize(
        allocator,
        serialized_data,
    ) catch |err| {
        std.log.err("[WORKER] dispatchMessageEventDirect() deserialization FAILED: {s}", .{@errorName(err)});
        return err;
    };
    std.log.info("[WORKER] dispatchMessageEventDirect() deserialized successfully", .{});

    // Convert structured_clone.JSValue to runtime.JSValue
    // This handles primitive types directly; complex types need V8 value creation
    const runtime_js_value: runtime.JSValue = switch (deserialized.*) {
        .undefined => runtime.JSValue.jsUndefined,
        .null => runtime.JSValue.jsNull,
        .boolean => |b| runtime.JSValue{ .boolean = b },
        .number => |n| runtime.JSValue{ .number = n },
        .string => |s| runtime.JSValue{ .string = .{ .data = s, .owned = false } },
        // Complex types that need V8 value creation - return undefined for now
        // TODO: Implement proper V8 value creation for these complex types
        else => runtime.JSValue.jsUndefined,
    };

    // Create MessageEventInit dictionary with the deserialized data
    const init_dict = dictionaries.MessageEventInit{
        .base = .{
            .bubbles = false,
            .cancelable = false,
            .composed = false,
        },
        .data = runtime_js_value,
        .origin = "",
        .lastEventId = null,
        .source = null,
        .ports = null,
    };

    // Get V8 isolate and context
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse {
        std.log.err("[WORKER] dispatchMessageEventDirect() failed to get isolate", .{});
        return error.NoIsolate;
    };
    const v8_context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        std.log.err("[WORKER] dispatchMessageEventDirect() failed to get context", .{});
        return error.NoContext;
    };

    // Create a REAL MessageEvent via the WebIDL interface constructor
    std.log.info("[WORKER] dispatchMessageEventDirect() creating real MessageEvent...", .{});
    const message_event = try MessageEvent.call_constructor(
        ctx,
        runtime.DOMString.initInterned("message"),
        webidl.Opt(dictionaries.MessageEventInit).passed(init_dict),
    );
    std.log.info("[WORKER] dispatchMessageEventDirect() MessageEvent created: {*}", .{message_event});

    // Wrap the MessageEvent instance in a V8 object with proper prototype chain
    // This is CRITICAL - without this, JavaScript cannot access MessageEvent.prototype.data
    const v8_event = template_registry.wrapInstanceAsV8Object(
        message_event,
        "MessageEvent",
        isolate,
        v8_context,
    ) catch |err| {
        std.log.err("[WORKER] dispatchMessageEventDirect() Failed to wrap MessageEvent: {s}", .{@errorName(err)});
        return err;
    };
    std.log.info("[WORKER] dispatchMessageEventDirect() MessageEvent wrapped in V8 object: {*}", .{v8_event});

    // Set isTrusted to true since this event is fired by the browser
    {
        var event_state = message_event.getState(MessageEvent.State);
        event_state.base.own.isTrusted = true;
    }

    // Get the onmessage handler from the global object
    const global = v8_engine.ffi.v8_Context_Global(v8_context) orelse {
        std.log.err("[WORKER] dispatchMessageEventDirect() failed to get global object", .{});
        return error.NoGlobal;
    };

    const onmessage_key = v8_engine.ffi.v8_String_NewFromUtf8(isolate, "onmessage", 9) orelse {
        std.log.err("[WORKER] dispatchMessageEventDirect() failed to create onmessage key", .{});
        return error.StringCreationFailed;
    };
    const onmessage_value = v8_engine.ffi.v8_Object_Get(global, v8_context, @ptrCast(onmessage_key)) orelse {
        std.log.info("[WORKER] dispatchMessageEventDirect() no onmessage property found", .{});
        return;
    };

    if (!v8_engine.ffi.v8_Value_IsFunction(onmessage_value)) {
        std.log.info("[WORKER] dispatchMessageEventDirect() no onmessage handler set", .{});
        return;
    }

    std.log.info("[WORKER] dispatchMessageEventDirect() found onmessage handler, calling it...", .{});

    // Call onmessage(event) with the real MessageEvent
    const onmessage_fn: *v8_engine.ffi.Function = @ptrCast(onmessage_value);
    var args = [_]*v8_engine.ffi.Value{@ptrCast(v8_event)};
    _ = v8_engine.ffi.v8_Function_Call(onmessage_fn, v8_context, @ptrCast(global), 1, &args);
    std.log.info("[WORKER] dispatchMessageEventDirect() onmessage handler returned", .{});
}
