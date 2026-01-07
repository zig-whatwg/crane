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
    _ = transfer; // TODO: Handle transfer list properly
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.dedicated_worker) |worker| {
            // Convert from runtime.JSValue to structured_clone.JSValue
            // This properly walks V8 objects to create serializable values
            const allocator = internal.allocator;
            const js_value = try runtimeToStructuredClone(allocator, message, instance.ctx);
            defer freeStructuredCloneValue(allocator, js_value);

            // Use postMessageFromWorker which properly serializes the message
            // and uses thread-safe outbox for cross-thread messaging
            try worker.postMessageFromWorker(&js_value, null);
        }
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
    const state = instance.getState(State);
    const allocator = if (state.own._internal) |internal| internal.allocator else return error.NotInitialized;

    // Deserialize the message data
    const deserialized = structured_clone.structuredDeserialize(
        allocator,
        serialized_data,
    ) catch {
        // If deserialization fails, fire 'messageerror' event instead of 'message'
        // Spec: HTML Standard § 9.3.6.2
        // "If this throws an exception, then fire an event named messageerror at the port"
        dispatchMessageErrorEvent(instance, origin) catch |err| {
            std.log.warn("Failed to dispatch messageerror event: {s}", .{@errorName(err)});
        };
        return error.DeserializationFailed;
    };

    // Create MessageEventInit dictionary
    const init_dict = dictionaries.MessageEventInit{
        .base = .{
            .bubbles = false,
            .cancelable = false,
            .composed = false,
        },
        .data = @ptrCast(deserialized),
        .origin = origin orelse "",
        .lastEventId = null,
        .source = null,
        .ports = null,
    };

    // Create MessageEvent via interface
    const event = try MessageEvent.call_constructor(
        instance.ctx,
        runtime.DOMString.initInterned("message"),
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
    // This invokes all addEventListener-registered listeners
    _ = EventTarget.call_dispatchEvent(instance, event) catch |err| {
        std.log.warn("Failed to dispatch MessageEvent to worker scope: {s}", .{@errorName(err)});
    };

    // Also invoke the legacy onmessage handler if set via IDL attribute
    invokeLegacyOnmessageHandler(instance, event);
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
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.dedicated_worker) |worker| {
            // Store the instance pointer for use in the callback
            // The callback will dispatch MessageEvent to this scope
            worker.setInsideMessageHandler(struct {
                fn handleMessage(w: *DedicatedWorker, msg: *workers.message_channel.QueuedMessage) void {
                    _ = w;
                    // TODO: Get the instance from w and call dispatchMessageEvent
                    // This requires storing the instance reference in the worker
                    _ = msg;
                }
            }.handleMessage);
        }
    }
}
