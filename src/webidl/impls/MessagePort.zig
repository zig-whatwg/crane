//! Implementation for MessagePort interface
//!
//! Spec: HTML Standard § 9.3.2 Message ports
//! https://html.spec.whatwg.org/#message-ports
//!
//! This implementation bridges the WebIDL interface to the streams internal
//! MessagePort implementation for cross-realm stream transfer support.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const MessagePort = interfaces.MessagePort;

// Import streams internal MessagePort for implementation
const message_port = @import("streams_internal");
const InternalMessagePort = message_port.MessagePort;
// Import JSValue from streams common
const streams_common = @import("streams_common");
const JSValue = streams_common.JSValue;

pub const State = MessagePort.State;

pub const ImplError = error{
    NotImplemented,
    PortClosed,
    NotEntangled,
    OutOfMemory,
};

/// Context for timer-based cross-isolate message dispatch
/// Stored in the internal port's callback_user_data when onmessage is set
const MessagePortDispatchContext = struct {
    /// The WebIDL MessagePort instance to dispatch to
    instance: *runtime.Instance,
    /// Allocator for creating timer contexts
    allocator: std.mem.Allocator,
    /// Timer interface for scheduling dispatch on main event loop
    timer: ?runtime.TimerInterface,

    pub fn init(allocator: std.mem.Allocator, instance: *runtime.Instance, timer: ?runtime.TimerInterface) !*MessagePortDispatchContext {
        const ctx = try allocator.create(MessagePortDispatchContext);
        ctx.* = .{
            .instance = instance,
            .allocator = allocator,
            .timer = timer,
        };
        return ctx;
    }

    pub fn deinit(self: *MessagePortDispatchContext) void {
        self.allocator.destroy(self);
    }
};

/// Context for timer callback - holds just the instance pointer
/// This is allocated per-dispatch and freed by the callback
const TimerDispatchContext = struct {
    instance: *runtime.Instance,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, instance: *runtime.Instance) !*TimerDispatchContext {
        const ctx = try allocator.create(TimerDispatchContext);
        ctx.* = .{
            .instance = instance,
            .allocator = allocator,
        };
        return ctx;
    }

    pub fn deinit(self: *TimerDispatchContext) void {
        self.allocator.destroy(self);
    }
};

/// Internal state for MessagePort implementation
///
/// Contains:
/// - Pointer to streams internal MessagePort for actual message passing
/// - Event handlers stored as WebIDL callbacks
/// - Reference to entangled WebIDL port for message dispatch
pub const InternalState = struct {
    /// Backing implementation from streams internal
    internal_port: *InternalMessagePort,

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    /// Reference to the entangled WebIDL MessagePort instance
    /// Used for dispatching messages to JavaScript handlers
    entangled_webidl_port: ?*runtime.Instance = null,

    /// Whether this InternalState owns the internal_port
    /// Set to false when port is transferred away (disentangled for transfer)
    owns_port: bool = true,

    pub fn deinit(self: *InternalState) void {
        // Clean up the dispatch context if we created one
        if (self.internal_port.callback_user_data) |user_data| {
            const dispatch_ctx: *MessagePortDispatchContext = @ptrCast(@alignCast(user_data));
            dispatch_ctx.deinit();
            self.internal_port.callback_user_data = null;
            self.internal_port.on_serialized_message = null;
        }

        // Only deinit the port if we own it
        // When a port is transferred, ownership moves to the destination
        if (self.owns_port) {
            self.internal_port.deinit();
        }
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
    errdefer runtime.Instance.deinit(instance);

    // Create internal MessagePort
    const internal_port = try InternalMessagePort.init(allocator);
    errdefer internal_port.deinit();

    // Create internal state
    const internal_state = try allocator.create(InternalState);
    internal_state.* = .{
        .internal_port = internal_port,
        .allocator = allocator,
    };

    // Store internal state in instance
    var state = instance.getState(State);
    state.own._internal = internal_state;

    return instance;
}

/// Initialize instance with existing internal MessagePort
/// Used by MessageChannel to create entangled ports
pub fn initWithInternal(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    internal_port: *InternalMessagePort,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal state with provided port
    const internal_state = try allocator.create(InternalState);
    internal_state.* = .{
        .internal_port = internal_port,
        .allocator = allocator,
    };

    // Store internal state in instance
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

/// Get internal MessagePort (for streams integration)
pub fn getInternalPort(instance: *runtime.Instance) ?*InternalMessagePort {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.internal_port;
    }
    return null;
}

/// Getter for onclose
pub fn get_onclose(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onclose;
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

/// Setter for onclose
pub fn set_onclose(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onclose = value;
}

/// Timer callback for cross-isolate message dispatch
/// This runs on the main event loop and is safe to dispatch from
fn timerDispatchCallback(context_ptr: ?*anyopaque) void {
    const timer_ctx: *TimerDispatchContext = @ptrCast(@alignCast(context_ptr orelse return));
    defer timer_ctx.deinit();

    const instance = timer_ctx.instance;
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        std.log.info("[MessagePort] Timer callback: dispatching pending messages", .{});
        dispatchPendingSerializedMessages(instance, internal);
    }
}

/// Callback function for when serialized messages are queued
/// This gets called from the internal MessagePort when a cross-isolate message arrives
/// Instead of dispatching directly (which may be in wrong V8 context), schedule a timer
fn onSerializedMessageCallback(internal_port: *InternalMessagePort) void {
    // Get the dispatch context which contains the instance and timer interface
    if (internal_port.callback_user_data) |user_data| {
        const dispatch_ctx: *MessagePortDispatchContext = @ptrCast(@alignCast(user_data));

        // Schedule a timer callback to dispatch on the main event loop
        if (dispatch_ctx.timer) |timer| {
            // Create a timer context for this dispatch
            const timer_ctx = TimerDispatchContext.init(dispatch_ctx.allocator, dispatch_ctx.instance) catch {
                std.log.warn("[MessagePort] Failed to allocate timer dispatch context", .{});
                return;
            };

            std.log.info("[MessagePort] Scheduling timer callback for cross-isolate dispatch", .{});
            _ = timer.setTimeout(0, timerDispatchCallback, timer_ctx);
        } else {
            std.log.warn("[MessagePort] No timer interface for cross-isolate dispatch", .{});
        }
    }
}

/// Setter for onmessage
/// Spec: § 9.3.2.1 Setting onmessage implicitly calls start()
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onmessage = value;

    // Per spec, setting onmessage implicitly enables the port's message queue
    if (state.own._internal) |internal| {
        internal.internal_port.enableQueue();

        // Set up callback for when serialized messages arrive (cross-isolate messages)
        // Create dispatch context with timer interface for scheduling on main event loop
        if (internal.internal_port.callback_user_data == null) {
            // Get the timer interface from the runtime context
            const timer = instance.ctx.getOptionalTimer();
            std.log.info("[MessagePort] Setting up cross-isolate callback, timer available: {}", .{timer != null});

            // Create the dispatch context
            const dispatch_ctx = MessagePortDispatchContext.init(internal.allocator, instance, timer) catch |err| {
                std.log.warn("[MessagePort] Failed to create dispatch context: {}", .{err});
                return;
            };

            internal.internal_port.on_serialized_message = onSerializedMessageCallback;
            internal.internal_port.callback_user_data = dispatch_ctx;
        }

        // Check for pending cross-isolate messages and dispatch them
        // This handles the case where messages were queued before the handler was set
        dispatchPendingSerializedMessages(instance, internal);
    }
}

/// Dispatch pending serialized messages from the cross-isolate queue
/// Called when onmessage is set to process any messages that arrived before the handler
fn dispatchPendingSerializedMessages(instance: *runtime.Instance, internal: *InternalState) void {
    const v8_engine = @import("v8");

    // Get V8 context and isolate
    const engine_ctx = instance.ctx.engine_ctx orelse return;
    const v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const v8_isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return;

    // Get the onmessage handler
    const state = instance.getState(State);
    const handler_bytes = @as(*const [@sizeOf(typedefs.EventHandler)]u8, @ptrCast(&state.own.onmessage)).*;
    const handler_addr: usize = @bitCast(handler_bytes);

    if (handler_addr == 0) return;

    const tag = handler_addr & 0x3;
    const untagged_addr = handler_addr & ~@as(usize, 0x3);
    if (tag != 1) return;
    if (untagged_addr < 0x100000000 or untagged_addr > 0x7FFFFFFFFFFF) return;
    if ((untagged_addr & 0x7) != 0) return;

    const callback_global: *v8_engine.ffi.Value = @ptrFromInt(untagged_addr);
    if (!v8_engine.ffi.v8_Value_IsFunction(callback_global)) return;

    // Process all pending serialized messages
    var dispatch_count: usize = 0;
    while (internal.internal_port.popSerializedMessage()) |serialized_msg| {
        defer serialized_msg.deinit();
        dispatch_count += 1;

        // Deserialize the message
        var data_value: ?*v8_engine.ffi.Value = null;

        // Check if it's our custom format or V8 structured clone
        if (serialized_msg.data.len > 0 and serialized_msg.data[0] < 0x10) {
            // Custom format: first byte is type marker (0x00-0x0F)
            const type_marker = serialized_msg.data[0];
            switch (type_marker) {
                0x00 => {
                    // Null/undefined
                    data_value = v8_engine.ffi.v8_Undefined(v8_isolate);
                },
                0x01 => {
                    // String: [type][4 bytes len][data]
                    if (serialized_msg.data.len >= 5) {
                        const str_len = @as(u32, @bitCast(serialized_msg.data[1..5].*));
                        if (serialized_msg.data.len >= 5 + str_len) {
                            const str_data = serialized_msg.data[5..][0..str_len];
                            data_value = @ptrCast(v8_engine.ffi.v8_String_NewFromUtf8(v8_isolate, str_data.ptr, @intCast(str_len)));
                        }
                    }
                },
                0x02 => {
                    // Number: [type][8 bytes f64]
                    if (serialized_msg.data.len >= 9) {
                        const num: f64 = @bitCast(serialized_msg.data[1..9].*);
                        data_value = @ptrCast(v8_engine.ffi.v8_Number_New(v8_isolate, num));
                    }
                },
                0x03 => {
                    // Boolean: [type][1 byte value]
                    if (serialized_msg.data.len >= 2) {
                        const bool_val = serialized_msg.data[1] != 0;
                        data_value = v8_engine.ffi.v8_Boolean_New(v8_isolate, bool_val);
                    }
                },
                else => {},
            }
            std.log.info("[MessagePort] Custom deserialization: type={}, data_value={*}", .{ type_marker, data_value });
        } else {
            // V8 structured clone format
            var error_code: c_int = 0;
            var empty_arraybuffer: [0]v8_engine.ffi.ArrayBufferTransferData = undefined;
            data_value = v8_engine.ffi.v8_Value_DeserializeWithTransfer_CrossIsolate(
                serialized_msg.data.ptr,
                serialized_msg.data.len,
                &empty_arraybuffer,
                0,
                &error_code,
            );

            if (data_value == null or error_code != 0) {
                std.log.warn("[MessagePort] Failed to deserialize V8 structured clone: error_code={}", .{error_code});
            }
        }

        if (data_value == null) {
            std.log.warn("[MessagePort] Failed to deserialize cross-isolate message", .{});
            continue;
        }

        // Create a MessageEvent
        const MessageEventInterface = interfaces.MessageEvent;
        const MessageEventImpl = @import("MessageEvent.zig");

        const msg_event = MessageEventImpl.call_constructor(
            instance.ctx,
            runtime.DOMString.initInterned("message"),
            .notPassed(),
        ) catch {
            std.log.warn("[MessagePort] Failed to create MessageEvent", .{});
            continue;
        };

        // Set the message data
        var msg_event_state = msg_event.getState(MessageEventInterface.State);
        msg_event_state.own.data = runtime.JSValue{
            .handle = .{
                .ptr = @ptrCast(data_value.?),
                .needs_disposal = true,
                .handle_scope = .global,
            },
        };
        msg_event_state.base.own.target = instance;
        msg_event_state.base.own.currentTarget = instance;

        // Wrap the event as a V8 object
        const event_v8_obj = v8_engine.template_registry.wrapInstanceAsV8Object(
            msg_event,
            "MessageEvent",
            v8_isolate,
            v8_context,
        ) catch {
            std.log.warn("[MessagePort] Failed to wrap MessageEvent", .{});
            continue;
        };

        // Call the handler
        const undefined_value = v8_engine.ffi.v8_Undefined(v8_isolate);
        var args: [1]*v8_engine.ffi.Value = .{@ptrCast(event_v8_obj)};
        const result = v8_engine.ffi.v8_Function_Call_Safe(
            callback_global,
            @ptrCast(v8_context),
            @ptrCast(undefined_value),
            1,
            @ptrCast(&args),
        );
        v8_engine.ffi.v8_FreeFunctionCallResult(result);
    }

    if (dispatch_count > 0) {
        std.log.info("[MessagePort] Dispatched {} pending cross-isolate messages", .{dispatch_count});
    }
}

/// Setter for onmessageerror
pub fn set_onmessageerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onmessageerror = value;
}

/// Operation: start
/// Spec: § 9.3.2.5 start() method
///
/// Enables the port's message queue. Messages received while the queue
/// is disabled are queued and will be dispatched when start() is called.
pub fn call_start(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.internal_port.enableQueue();
    }
}

/// Operation: close
/// Spec: § 9.3.2.6 close() method
///
/// Disconnects the port so it is no longer active.
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.internal_port.close();
    }
}

/// Post message for cross-isolate delivery
/// Used when WebIDL entanglement is broken but internal entanglement exists
/// (i.e., when communicating with a port transferred to a worker)
fn postMessageCrossIsolate(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
    const v8_engine = @import("v8");
    _ = transfer; // TODO: handle transfer list for cross-isolate

    const state = instance.getState(State);
    const internal = state.own._internal orelse return;

    // Get the current V8 context for serialization
    const engine_ctx = instance.ctx.engine_ctx orelse return;
    _ = engine_ctx;

    // Serialize the message for cross-isolate transfer
    var serialized_bytes: ?[]u8 = null;

    // Debug: Log message type
    std.log.info("[MessagePort] postMessageCrossIsolate: message type = {}", .{@as(std.meta.Tag(@TypeOf(message)), message)});

    if (message == .handle) {
        const msg_handle = message.handle;
        const v8_value: *v8_engine.ffi.Value = @ptrCast(@alignCast(msg_handle.ptr));

        var serialized_size: usize = 0;
        var error_code: c_int = 0;
        var empty_transfer: [0]*v8_engine.ffi.Value = undefined;
        var empty_arraybuffer: [0]v8_engine.ffi.ArrayBufferTransferData = undefined;

        // Use simple serialization (no transfer for now)
        const bytes_ptr = v8_engine.ffi.v8_Value_SerializeWithTransfer_CrossIsolate(
            v8_value,
            &empty_transfer,
            0,
            &serialized_size,
            &empty_arraybuffer,
            &error_code,
        );

        std.log.info("[MessagePort] V8 serialization: bytes_ptr={*}, size={}, error_code={}", .{ bytes_ptr, serialized_size, error_code });
        if (bytes_ptr != null and error_code == 0) {
            // Copy the bytes to our allocator
            serialized_bytes = try internal.allocator.alloc(u8, serialized_size);
            @memcpy(serialized_bytes.?, bytes_ptr.?[0..serialized_size]);
            v8_engine.ffi.v8_Free_SerializedBuffer(bytes_ptr.?);
            std.log.info("[MessagePort] V8 serialization succeeded: {} bytes", .{serialized_size});
        } else {
            std.log.warn("[MessagePort] V8 serialization failed: error_code={}", .{error_code});
        }
    } else {
        // For non-handle values (primitives), we need to create a simple serialization
        // For now, let's handle common primitives
        var buf: [64]u8 = undefined;
        var len: usize = 0;

        switch (message) {
            .string => |s| {
                // Serialize as a string marker + length + data
                // Simple format: [1 byte type][4 bytes len][data]
                const str_data = s.data;
                const total_len = 5 + str_data.len;
                if (total_len <= buf.len) {
                    buf[0] = 0x01; // String type
                    const str_len: u32 = @intCast(str_data.len);
                    buf[1..5].* = @bitCast(str_len);
                    @memcpy(buf[5..][0..str_data.len], str_data);
                    len = total_len;
                }
            },
            .number => |n| {
                // Serialize as number marker + f64
                buf[0] = 0x02; // Number type
                const num_bytes: [8]u8 = @bitCast(n);
                buf[1..9].* = num_bytes;
                len = 9;
            },
            .boolean => |b| {
                buf[0] = 0x03; // Boolean type
                buf[1] = if (b) 1 else 0;
                len = 2;
            },
            else => {
                // For undefined/null, use a marker
                buf[0] = 0x00; // Null/undefined type
                len = 1;
            },
        }

        if (len > 0) {
            serialized_bytes = try internal.allocator.alloc(u8, len);
            @memcpy(serialized_bytes.?, buf[0..len]);
        }
    }

    // Queue the serialized message to the entangled port
    if (serialized_bytes) |bytes| {
        defer internal.allocator.free(bytes);
        try internal.internal_port.postSerializedMessage(bytes);
        std.log.info("[MessagePort] Queued cross-isolate message: {} bytes", .{bytes.len});
    }
}

/// Operation: postMessage
/// Spec: § 9.3.2.1 postMessage(message, transfer)
///
/// Posts a message to the entangled port. Creates a MessageEvent and
/// dispatches it to the entangled port's onmessage handler.
pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
    const v8_engine = @import("v8");

    const state = instance.getState(State);
    const internal = state.own._internal orelse return;

    // Check if port is closed
    if (internal.internal_port.closed) return ImplError.PortClosed;

    // Check for cross-isolate case: WebIDL entanglement is broken but internal entanglement exists
    // This happens when a port is transferred to a worker
    if (internal.entangled_webidl_port == null) {
        // Check if internal entanglement exists (cross-isolate)
        if (internal.internal_port.entangled_port != null) {
            // Cross-isolate messaging: serialize and queue for the other isolate
            return postMessageCrossIsolate(instance, message, transfer);
        }
        return ImplError.NotEntangled;
    }

    // Check the entangled port's state
    const entangled_port = internal.entangled_webidl_port.?;
    const entangled_state = entangled_port.getState(State);
    const entangled_internal = entangled_state.own._internal orelse return;

    // Check if the entangled port has been transferred to another isolate
    // If so, use cross-isolate messaging instead of direct WebIDL dispatch
    if (entangled_internal.internal_port.transferred) {
        // The entangled port was transferred - use cross-isolate messaging
        return postMessageCrossIsolate(instance, message, transfer);
    }

    // Same-isolate case: direct WebIDL dispatch

    // Only dispatch if queue is enabled (set when onmessage is assigned)
    if (!entangled_internal.internal_port.queue_enabled) return;

    // Get the onmessage handler - check if it's actually set (not undefined/garbage)
    // The handler is stored as a tagged pointer to a V8 GlobalHandle, but it's stored
    // in a function pointer type which has strict alignment requirements. We need to
    // extract the raw address without triggering alignment checks.
    //
    // EventHandler type is ?*const fn(...) - we get the raw memory contents as usize
    // using @as to read the bytes directly, avoiding Zig's alignment checks on optionals.
    const handler_bytes = @as(*const [@sizeOf(typedefs.EventHandler)]u8, @ptrCast(&entangled_state.own.onmessage)).*;
    const handler_addr: usize = @bitCast(handler_bytes);

    // Check for null (0) - zero-initialized memory
    if (handler_addr == 0) {
        return;
    }

    // Extract tag from low 2 bits and untagged address
    const tag = handler_addr & 0x3;
    const untagged_addr = handler_addr & ~@as(usize, 0x3);

    // Verify it's a global_handle tag (tag == 1)
    if (tag != 1) {
        return; // Not a global_handle tag
    }

    // Sanity check: verify the untagged address looks like a valid heap pointer
    // On 64-bit macOS, user-space heap is typically below 0x800000000000
    // and above some minimum (e.g., 0x100000000)
    if (untagged_addr < 0x100000000 or untagged_addr > 0x7FFFFFFFFFFF) {
        return; // Invalid address range - corrupted pointer
    }

    // Verify alignment - Global<Value>* should be 8-byte aligned
    if ((untagged_addr & 0x7) != 0) {
        return; // Misaligned pointer
    }

    // Get V8 context and isolate
    const engine_ctx = entangled_port.ctx.engine_ctx orelse return;
    const v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const v8_isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return;

    // The untagged_addr IS the Global<Value>* - we can use it directly with v8_Function_Call_Safe
    // which expects Global handles
    const callback_global: *v8_engine.ffi.Value = @ptrFromInt(untagged_addr);

    // Check if it's a function using the Global-accepting version
    if (!v8_engine.ffi.v8_Value_IsFunction(callback_global)) {
        return;
    }

    // Clone the message using V8's structured clone with transfer
    // This properly handles ArrayBuffer transfer (copies data, then detaches original)
    var cloned_message: runtime.JSValue = undefined;

    // Track transferred MessagePorts - store Zig instances (will be wrapped fresh in get_ports)
    var transferred_port_instances: [16]*runtime.Instance = undefined;
    var transferred_port_count: usize = 0;

    // Track ArrayBuffers for structured clone transfer
    var array_buffer_transfers: [64]*v8_engine.ffi.Value = undefined;
    var array_buffer_count: usize = 0;

    // FIRST: Process transfer list to extract MessagePorts and ArrayBuffers
    // This must be done regardless of message type, as MessagePorts can be
    // transferred even when the message itself is a primitive
    if (transfer == .handle) {
        const transfer_handle = transfer.handle;
        const src_ctx = instance.ctx.engine_ctx orelse return;
        const src_v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(src_ctx));

        const transfer_value: *v8_engine.ffi.Value = @ptrCast(transfer_handle.ptr);
        if (v8_engine.ffi.v8_Value_IsArray(transfer_value)) {
            const transfer_array: *v8_engine.ffi.Array = @ptrCast(transfer_value);
            const length = v8_engine.ffi.v8_Array_Length(transfer_array);

            // Separate MessagePorts from ArrayBuffers in the transfer list
            for (0..length) |i| {
                if (v8_engine.ffi.v8_Array_Get(src_v8_context, transfer_array, @intCast(i))) |item| {
                    if (v8_engine.ffi.v8_Value_IsArrayBuffer(item)) {
                        // ArrayBuffer - add to transfer list for structured clone
                        if (array_buffer_count < 64) {
                            array_buffer_transfers[array_buffer_count] = item;
                            array_buffer_count += 1;
                        }
                    } else if (v8_engine.ffi.v8_Value_IsObject(item)) {
                        // Check if it's a MessagePort by looking at internal fields
                        const v8_obj: *v8_engine.ffi.Object = @ptrCast(item);
                        const field_count = v8_engine.ffi.v8_Object_InternalFieldCount(v8_obj);
                        if (field_count >= 2) {
                            // Has internal fields - check if it's a MessagePort
                            if (v8_engine.wrapper_type_info_mod.getTypeInfo(v8_obj)) |type_info| {
                                if (std.mem.eql(u8, std.mem.span(type_info.interface_name), "MessagePort")) {
                                    // It's a MessagePort - extract the Zig instance
                                    // Instance is stored in internal field 0
                                    if (v8_engine.ffi.v8_Object_GetAlignedPointerFromInternalField(v8_obj, 0)) |instance_ptr| {
                                        if (transferred_port_count < 16) {
                                            transferred_port_instances[transferred_port_count] = @ptrCast(@alignCast(instance_ptr));
                                            transferred_port_count += 1;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // SECOND: Clone the message appropriately based on type and ArrayBuffer transfers
    if (message == .handle) {
        const msg_handle = message.handle;
        const v8_value: *v8_engine.ffi.Value = @ptrCast(@alignCast(msg_handle.ptr));

        // Clone message with ArrayBuffer transfers if needed
        if (array_buffer_count > 0) {
            var error_code: c_int = 0;
            const cloned = v8_engine.ffi.v8_Value_StructuredCloneWithTransfer(
                v8_value,
                &array_buffer_transfers,
                array_buffer_count,
                &error_code,
            );

            if (cloned == null or error_code != 0) {
                return; // Clone with transfer failed
            }

            cloned_message = runtime.JSValue{
                .handle = .{
                    .ptr = @ptrCast(cloned.?),
                    .needs_disposal = true,
                    .handle_scope = .global,
                },
            };
        } else {
            // No ArrayBuffers to transfer - use simple clone
            const cloned = v8_engine.ffi.v8_Value_StructuredClone(v8_value);
            if (cloned == null) {
                return; // Clone failed
            }
            cloned_message = runtime.JSValue{
                .handle = .{
                    .ptr = @ptrCast(cloned.?),
                    .needs_disposal = true,
                    .handle_scope = .global,
                },
            };
        }
    } else {
        // For primitives, just clone directly
        cloned_message = message.clone(entangled_port.ctx.allocator) catch return;
    }

    // Create a MessageEvent with the cloned message data
    const MessageEventInterface = @import("interfaces").MessageEvent;
    const MessageEventImpl = @import("MessageEvent.zig");

    const msg_event = MessageEventImpl.call_constructor(
        entangled_port.ctx,
        runtime.DOMString.initInterned("message"),
        .notPassed(),
    ) catch return;

    // Set the message data on the event
    var msg_event_state = msg_event.getState(MessageEventInterface.State);
    msg_event_state.own.data = cloned_message;

    // Set the target to the receiving port (entangled_port)
    // This is per DOM spec: when an event is dispatched, its target should be set
    msg_event_state.base.own.target = entangled_port;
    msg_event_state.base.own.currentTarget = entangled_port;

    // Store the transferred port instances in the MessageEvent's internal state
    // The get_ports getter will wrap them fresh when accessed, ensuring correct prototype chain
    if (msg_event_state.own._internal) |msg_internal| {
        msg_internal.transferred_port_count = transferred_port_count;
        for (0..transferred_port_count) |i| {
            msg_internal.transferred_ports[i] = transferred_port_instances[i];
        }
    }
    // Also set ports to undefined initially (get_ports will create the array on access)
    msg_event_state.own.ports = runtime.JSValue.jsUndefined;

    // Wrap the event as a V8 object - this returns a Global<Object>*
    const event_v8_obj = v8_engine.template_registry.wrapInstanceAsV8Object(
        msg_event,
        "MessageEvent",
        v8_isolate,
        v8_context,
    ) catch return;

    // Create undefined value for the receiver
    const undefined_value = v8_engine.ffi.v8_Undefined(v8_isolate);

    // Call the handler function using the Safe version which takes Global handles
    var args: [1]*v8_engine.ffi.Value = .{@ptrCast(event_v8_obj)};
    const result = v8_engine.ffi.v8_Function_Call_Safe(
        callback_global, // Global<Value>* function
        @ptrCast(v8_context), // Global<Context>*
        @ptrCast(undefined_value), // Global<Value>* receiver
        1, // argc
        @ptrCast(&args), // Global<Value>** argv
    );

    // Clean up the result
    v8_engine.ffi.v8_FreeFunctionCallResult(result);
}
