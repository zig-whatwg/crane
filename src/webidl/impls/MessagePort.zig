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

// V8 engine for event handler invocation
const v8_engine = @import("v8");

// Import streams internal MessagePort for implementation
const message_port = @import("streams_internal");
const InternalMessagePort = message_port.MessagePort;
// Import JSValue from streams common
const streams_common = @import("streams_common");
const JSValue = streams_common.JSValue;

// Import worker threading for cross-thread message queues
const html = @import("html");
const worker_threading = html.workers.worker_threading;
const ThreadSafeMessageQueue = worker_threading.ThreadSafeMessageQueue;
const SerializedMessage = ThreadSafeMessageQueue.SerializedMessage;
const message_channel = html.workers.message_channel;
const SerializedValue = message_channel.SerializedValue;

pub const State = MessagePort.State;

pub const ImplError = error{
    NotImplemented,
    PortClosed,
    NotEntangled,
    OutOfMemory,
    DataCloneError,
    InvalidState,
};

/// Data structure for a MessagePort being transferred across realms.
/// Per HTML spec § 9.4.1, this captures the port's identity and entanglement
/// so it can be reconstructed in the target realm.
pub const TransferredPortData = struct {
    /// ID of this port (for reconstruction)
    port_id: u64,
    /// ID of the entangled port (if any)
    entangled_port_id: ?u64,
    /// Reference to the internal port (for cross-realm transfer)
    internal_port: *InternalMessagePort,
    /// Allocator for cleanup
    allocator: std.mem.Allocator,

    pub fn deinit(self: *TransferredPortData) void {
        // Note: Do NOT deinit internal_port here - it's transferred to the target realm
        self.allocator.destroy(self);
    }
};

/// Internal state for MessagePort implementation
///
/// Contains:
/// - Pointer to streams internal MessagePort for actual message passing
/// - Reference to the WebIDL instance for event dispatch
/// - Allocator for memory management
/// - V8 GlobalHandle for onmessage event handler
pub const InternalState = struct {
    /// Backing implementation from streams internal
    internal_port: *InternalMessagePort,

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    /// Reference to the WebIDL MessagePort instance for event dispatch
    /// This allows us to dispatch events to the correct target when
    /// messages are received from the entangled port
    port_instance: ?*runtime.Instance = null,

    /// V8 GlobalHandle for onmessage event handler
    /// Stored separately for direct V8 invocation after event dispatch
    onmessage_handle: v8_engine.OptionalGlobalHandle = null,

    /// Per HTML spec § 9.4.1, tracks if port has been shipped (transferred).
    /// A shipped port is disentangled and cannot be transferred again.
    shipped: bool = false,

    pub fn deinit(self: *InternalState) void {
        // Dispose V8 GlobalHandle if set
        v8_engine.disposeOptionalGlobalHandle(&self.onmessage_handle);
        self.internal_port.deinit();
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
        .port_instance = instance, // Store reference for event dispatch
    };

    // Store internal state in instance
    var state = instance.getState(State);
    state.own._internal = internal_state;

    // Link internal port back to WebIDL instance for message delivery
    internal_port.webidl_instance = instance;

    // Set cross-thread message handler for messages from other threads
    internal_port.cross_thread_message_handler = handleCrossThreadMessage;

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
        .port_instance = instance, // Store reference for event dispatch
    };

    // Store internal state in instance
    var state = instance.getState(State);
    state.own._internal = internal_state;

    // Link internal port back to WebIDL instance for message delivery
    internal_port.webidl_instance = instance;

    // Set cross-thread message handler for messages from other threads
    internal_port.cross_thread_message_handler = handleCrossThreadMessage;

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

/// Extract GlobalHandle from a tagged callback pointer (from V8 conversion).
/// The V8 conversions layer creates Global handles and tags the pointers.
fn extractEventHandler(handler: ?*const anyopaque) v8_engine.OptionalGlobalHandle {
    std.log.warn("[extractEventHandler] ENTRY handler={?}", .{handler});
    if (handler) |ptr| {
        std.log.warn("[extractEventHandler] ptr=0x{x}", .{@intFromPtr(ptr)});
        const untagged = v8_engine.pointer_tag.untagPointer(ptr);
        std.log.warn("[extractEventHandler] untagged.ptr=0x{x}, tag={s}", .{ @intFromPtr(untagged.ptr), @tagName(untagged.tag) });
        if (untagged.tag == .global_handle or untagged.tag == .untagged) {
            const result_ptr: *v8_engine.ffi.Value = @ptrCast(@alignCast(untagged.ptr));
            std.log.warn("[extractEventHandler] RETURNING GlobalHandle with ptr=0x{x}", .{@intFromPtr(result_ptr)});
            return v8_engine.GlobalHandle{ .ptr = result_ptr };
        }
        std.log.warn("[extractEventHandler] tag not global_handle or untagged, returning null", .{});
    }
    std.log.warn("[extractEventHandler] RETURNING null", .{});
    return null;
}

/// Setter for onmessage
/// Spec: § 9.3.2.1 Setting onmessage implicitly calls start()
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onmessage = value;

    // Per spec, setting onmessage implicitly enables the port's message queue
    if (state.own._internal) |internal| {
        // Extract and store the V8 GlobalHandle for direct invocation
        v8_engine.disposeOptionalGlobalHandle(&internal.onmessage_handle);
        internal.onmessage_handle = extractEventHandler(@ptrCast(value));

        const was_enabled = internal.internal_port.queue_enabled;
        internal.internal_port.enableQueue();

        // Flush any pending messages now that the queue is enabled
        if (!was_enabled) {
            flushPendingMessages(instance, internal);
        }
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
        const was_enabled = internal.internal_port.queue_enabled;
        internal.internal_port.enableQueue();

        // Flush any pending messages now that the queue is enabled
        if (!was_enabled) {
            flushPendingMessages(instance, internal);
        }
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

/// Operation: postMessage
/// Spec: HTML Standard § 9.4.1 postMessage(message, transfer)
///
/// Posts a message to the entangled port. The message is delivered
/// asynchronously by creating a MessageEvent and dispatching it
/// to the entangled port's message event target.
pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
    std.log.warn("[MessagePort.call_postMessage] ENTRY, instance={*}", .{instance});
    const state = instance.getState(State);
    const internal = state.own._internal orelse {
        std.log.warn("[MessagePort.call_postMessage] no internal state, returning", .{});
        return;
    };
    const internal_port = internal.internal_port;
    std.log.warn("[MessagePort.call_postMessage] internal_port.id={d}", .{internal_port.id});

    // Extract MessagePort instances from the transfer list
    // Per spec, only MessagePort and ArrayBuffer can be transferred
    const ports = extractTransferredPorts(transfer, internal.allocator) catch runtime.JSValue.jsUndefined;

    // Step 2: Get the entangled port
    const entangled_port = internal_port.entangled_port orelse {
        // Not entangled - silently return per spec
        std.log.warn("[MessagePort.call_postMessage] no entangled port, returning", .{});
        return;
    };
    std.log.warn("[MessagePort.call_postMessage] entangled_port.id={d}", .{entangled_port.id});

    // Check if this is a cross-thread port (entangled port is in another thread)
    // If cross_thread_queue is set, we need to serialize and enqueue the message
    // instead of delivering directly.
    if (internal_port.cross_thread_queue) |queue_ptr| {
        std.log.warn("[MessagePort.call_postMessage] cross-thread message, using queue", .{});
        const queue: *ThreadSafeMessageQueue = @ptrCast(@alignCast(queue_ptr));

        // Use page_allocator for cross-thread messaging - it's inherently thread-safe
        const cross_thread_allocator = std.heap.page_allocator;

        // Serialize the message
        const serialized = serializeMessageForCrossThread(message, cross_thread_allocator) catch |err| {
            std.log.warn("[MessagePort.call_postMessage] failed to serialize: {s}", .{@errorName(err)});
            return ImplError.OutOfMemory;
        };

        // Create a SerializedMessage with target_port_id set for routing
        const msg = cross_thread_allocator.create(SerializedMessage) catch {
            serialized.deinit();
            cross_thread_allocator.destroy(serialized);
            return ImplError.OutOfMemory;
        };
        msg.* = .{
            .data = serialized.*,
            .transfers = null,
            .target_port_id = entangled_port.id, // Route to this port on the receiving thread
            .allocator = cross_thread_allocator,
        };

        // Free the SerializedValue struct (its contents are now owned by msg.data)
        cross_thread_allocator.destroy(serialized);

        // Enqueue to the cross-thread queue
        queue.enqueue(msg) catch |err| {
            std.log.warn("[MessagePort.call_postMessage] failed to enqueue: {s}", .{@errorName(err)});
            msg.deinit();
            return ImplError.OutOfMemory;
        };
        std.log.warn("[MessagePort.call_postMessage] message enqueued to cross-thread queue for port {d}", .{entangled_port.id});
        return;
    }

    // Same-thread delivery path (original code)
    // Get the target port's WebIDL instance for event dispatch
    const target_instance: *runtime.Instance = if (entangled_port.webidl_instance) |inst|
        @ptrCast(@alignCast(inst))
    else {
        // No WebIDL instance - fall back to internal queue for streams
        std.log.warn("[MessagePort.call_postMessage] entangled port has no webidl_instance, using internal queue", .{});
        const msg_value = convertToStreamsJSValue(message, internal.allocator) catch {
            return ImplError.OutOfMemory;
        };
        internal_port.postMessage("chunk", msg_value) catch |err| {
            return switch (err) {
                error.PortClosed => ImplError.PortClosed,
                error.NotEntangled => ImplError.NotEntangled,
                else => ImplError.OutOfMemory,
            };
        };
        return;
    };
    std.log.warn("[MessagePort.call_postMessage] target_instance={*}, queue_enabled={}", .{ target_instance, entangled_port.queue_enabled });

    // Check if target port's queue is enabled
    if (entangled_port.queue_enabled) {
        // Queue is enabled - deliver message now
        std.log.warn("[MessagePort.call_postMessage] delivering message to target with ports={s}", .{@tagName(ports)});
        try deliverMessage(target_instance, message, ports);
        std.log.warn("[MessagePort.call_postMessage] message delivered successfully", .{});
    } else {
        // Queue is disabled - store message for later delivery
        // TODO: Store ports along with message for later delivery
        std.log.warn("[MessagePort.call_postMessage] queue disabled, storing message for later", .{});
        // Clone the message and heap-allocate it for storage
        const cloned_ptr = try internal.allocator.create(runtime.JSValue);
        errdefer internal.allocator.destroy(cloned_ptr);
        cloned_ptr.* = try message.clone(internal.allocator);
        try entangled_port.queuePendingMessage(@ptrCast(cloned_ptr));
        std.log.warn("[MessagePort.call_postMessage] message queued for later delivery", .{});
    }
}

/// Serialize a runtime.JSValue for cross-thread transfer
fn serializeMessageForCrossThread(message: runtime.JSValue, allocator: std.mem.Allocator) !*SerializedValue {
    // Convert runtime.JSValue to message_channel.JSValue for serialization
    const mc_jsvalue: message_channel.JSValue = switch (message) {
        .undefined => .{ .undefined = {} },
        .null => .{ .null = {} },
        .boolean => |b| .{ .boolean = b },
        .number => |n| .{ .number = n },
        .string => |s| blk: {
            // JSON string needs quotes
            var escaped_len: usize = 2; // for opening and closing quotes
            for (s.data) |c| {
                escaped_len += if (c == '"' or c == '\\') 2 else 1;
            }
            const quoted = try allocator.alloc(u8, escaped_len);
            var pos: usize = 0;
            quoted[pos] = '"';
            pos += 1;
            for (s.data) |c| {
                if (c == '"' or c == '\\') {
                    quoted[pos] = '\\';
                    pos += 1;
                }
                quoted[pos] = c;
                pos += 1;
            }
            quoted[pos] = '"';
            break :blk .{ .string = quoted };
        },
        .handle => |h| blk: {
            // For V8 handles, we need to serialize via JSON.stringify
            // Get the current isolate and context
            const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse {
                break :blk .{ .undefined = {} };
            };
            const v8_context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
                break :blk .{ .undefined = {} };
            };

            // First call to get required buffer size
            var size_buf: [1]u8 = undefined;
            const v8_value: *v8_engine.ffi.Value = @ptrCast(h.ptr);
            const needed_size = v8_engine.ffi.v8_JSON_Stringify_ToBuffer(v8_context, v8_value, &size_buf, 0);
            if (needed_size <= 0) {
                break :blk .{ .undefined = {} };
            }

            // Allocate buffer and stringify
            const buf = try allocator.alloc(u8, @intCast(needed_size));
            const written = v8_engine.ffi.v8_JSON_Stringify_ToBuffer(v8_context, v8_value, buf.ptr, @intCast(buf.len));
            if (written <= 0) {
                allocator.free(buf);
                break :blk .{ .undefined = {} };
            }

            break :blk .{ .string = buf[0..@intCast(written)] };
        },
        .instance => .{ .undefined = {} }, // TODO: Handle instance serialization
    };

    // Use structured serialize
    return message_channel.structuredSerialize(allocator, &mc_jsvalue);
}

/// Extract MessagePort instances from a transfer list
/// Returns a JSValue representing an array of MessagePort instances
fn extractTransferredPorts(transfer: runtime.JSValue, allocator: std.mem.Allocator) !runtime.JSValue {
    _ = allocator;

    // If transfer is undefined/null, return undefined (no ports)
    switch (transfer) {
        .undefined, .null => return runtime.JSValue.jsUndefined,
        .handle => |h| {
            // The transfer list is a JS array - we need to check if it contains MessagePorts
            // For now, just pass the handle through as the ports array
            // The V8 side will see this as a JS array
            return runtime.JSValue{ .handle = h };
        },
        else => return runtime.JSValue.jsUndefined,
    }
}

/// Convert runtime.JSValue to streams internal JSValue
fn convertToStreamsJSValue(message: runtime.JSValue, allocator: std.mem.Allocator) !JSValue {
    return switch (message) {
        .undefined => JSValue.undefined_value(),
        .null => JSValue{ .null = {} },
        .boolean => |b| JSValue{ .boolean = b },
        .number => |n| JSValue{ .number = n },
        .string => |s| JSValue{ .string = s.data },
        .handle => |h| try JSValue.fromEnginePtr(allocator, h.ptr),
        .instance => JSValue{ .object = {} },
    };
}

/// Deliver a message to a port by creating and dispatching a MessageEvent
///
/// Spec: HTML Standard § 9.4.1 step 6 (task steps)
/// 1. Create a MessageEvent with the data
/// 2. Dispatch the event to the port
/// 3. Invoke legacy onmessage handler if set
fn deliverMessage(port_instance: *runtime.Instance, data: runtime.JSValue, ports: runtime.JSValue) !void {
    const allocator = port_instance.ctx.allocator;

    // Create MessageEvent with the data and transferred ports
    const MessageEventImpl = @import("MessageEvent.zig");
    const event = try MessageEventImpl.createPortMessageEvent(allocator, port_instance.ctx, data, ports);
    errdefer interfaces.Event.deinit(event);

    // Dispatch the event to the port via EventTarget (invokes addEventListener listeners)
    const event_dispatch = @import("dom").event_dispatch;
    _ = try event_dispatch.dispatch(event, port_instance, false, null);

    // After dispatchEvent, invoke the legacy onmessage handler if set
    // The dispatchEvent handles listeners registered via addEventListener,
    // but we need to separately handle the legacy onXXX IDL attribute handler
    const state = port_instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.onmessage_handle) |onmessage_global| {
            invokeLegacyOnmessageHandler(port_instance, event, onmessage_global);
        }
    }
}

/// Invoke the legacy onmessage IDL attribute handler
///
/// Per HTML spec, the onXXX IDL event handlers are separate from addEventListener.
/// The onmessage property stores a GlobalHandle to a JavaScript function.
/// This function is called after EventTarget.dispatchEvent has handled all
/// addEventListener-registered listeners.
fn invokeLegacyOnmessageHandler(
    port_instance: *runtime.Instance,
    event: *runtime.Instance,
    onmessage_global: v8_engine.GlobalHandle,
) void {
    _ = port_instance; // For future use

    std.log.warn("[invokeLegacyOnmessageHandler] ENTRY onmessage_global.ptr=0x{x}", .{@intFromPtr(onmessage_global.ptr)});

    // Get the V8 isolate and context
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse {
        std.log.warn("MessagePort.invokeLegacyOnmessageHandler: No current isolate", .{});
        return;
    };
    const v8_context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        std.log.warn("MessagePort.invokeLegacyOnmessageHandler: No current context", .{});
        return;
    };

    // Create HandleScope for V8 operations - required when calling V8 APIs
    // that create Local handles outside of a V8-initiated callback
    const scope = v8_engine.ffi.v8_HandleScope_New(isolate);
    defer v8_engine.ffi.v8_HandleScope_Dispose(scope);

    // Verify it's a function (check global handle - v8_Value_IsFunction expects Global<Value>*)
    if (!v8_engine.ffi.v8_Value_IsFunction(onmessage_global.ptr)) {
        std.log.warn("MessagePort.invokeLegacyOnmessageHandler: onmessage is not a function", .{});
        return;
    }

    // Wrap the event as a V8 object
    // IMPORTANT: wrapInstanceAsV8Object returns Global<Object>* (from v8_ObjectTemplate_NewInstance)
    // so we can use it directly in v8_Function_Call without conversion
    const v8_event = v8_engine.template_registry.wrapInstanceAsV8Object(
        event,
        "MessageEvent",
        isolate,
        v8_context,
    ) catch |err| {
        std.log.warn("MessagePort: Failed to wrap MessageEvent as V8 object: {s}", .{@errorName(err)});
        return;
    };

    // Call the V8 function with the MessageEvent as argument
    // v8_Function_Call expects Global handles:
    // - function: Global<Function>* (onmessage_global.ptr is already Global)
    // - context: Global<Context>* (v8_context from GetCurrentContext is Global)
    // - recv: Global<Value>* (v8_Undefined returns Global)
    // - argv: Global<Value>** (v8_event is already Global from wrapInstanceAsV8Object)
    const undefined_recv = v8_engine.ffi.v8_Undefined(isolate);
    var args = [_]*v8_engine.ffi.Value{@ptrCast(v8_event)};
    const function_global: *v8_engine.ffi.Function = @ptrCast(onmessage_global.ptr);
    _ = v8_engine.ffi.v8_Function_Call(function_global, v8_context, @ptrCast(undefined_recv), 1, &args);
}

/// Flush all pending messages from the queue
/// Called when the queue is enabled (via start() or set_onmessage)
fn flushPendingMessages(instance: *runtime.Instance, internal: *InternalState) void {
    const internal_port = internal.internal_port;

    // Deliver all pending messages
    while (internal_port.popPendingMessage()) |pending_ptr| {
        // Cast back from *anyopaque to *runtime.JSValue
        const pending_msg: *runtime.JSValue = @ptrCast(@alignCast(pending_ptr));
        defer {
            // Free the cloned message after delivery
            pending_msg.deinit(internal.allocator);
            internal.allocator.destroy(pending_msg);
        }

        // TODO: Pending messages should also store transferred ports
        // For now, pass undefined (no ports) for pending messages
        deliverMessage(instance, pending_msg.*, runtime.JSValue.jsUndefined) catch |err| {
            // Log error but continue processing queue
            std.log.err("Failed to deliver pending message: {s}", .{@errorName(err)});
        };
    }
}

/// Handler for cross-thread messages arriving on this MessagePort.
/// This is set as the cross_thread_message_handler on the internal port
/// and is called when messages arrive from another thread.
///
/// The callback signature matches InternalMessagePort.cross_thread_message_handler:
/// fn(*InternalMessagePort, *anyopaque) void
fn handleCrossThreadMessage(internal_port: *InternalMessagePort, msg_ptr: *anyopaque) void {
    std.log.warn("[MessagePort.handleCrossThreadMessage] called", .{});

    // Get the WebIDL MessagePort instance from the internal port
    const webidl_instance: *runtime.Instance = if (internal_port.webidl_instance) |inst|
        @ptrCast(@alignCast(inst))
    else {
        std.log.warn("[MessagePort.handleCrossThreadMessage] no webidl_instance on internal port", .{});
        // Clean up the message since we can't deliver it
        const serialized_msg: *SerializedMessage = @ptrCast(@alignCast(msg_ptr));
        serialized_msg.deinit();
        return;
    };

    // Get V8 context
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse {
        std.log.warn("[MessagePort.handleCrossThreadMessage] no current isolate", .{});
        const serialized_msg: *SerializedMessage = @ptrCast(@alignCast(msg_ptr));
        serialized_msg.deinit();
        return;
    };
    const v8_context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        std.log.warn("[MessagePort.handleCrossThreadMessage] no current context", .{});
        const serialized_msg: *SerializedMessage = @ptrCast(@alignCast(msg_ptr));
        serialized_msg.deinit();
        return;
    };

    // Create HandleScope for V8 operations
    const scope = v8_engine.ffi.v8_HandleScope_New(isolate);
    defer v8_engine.ffi.v8_HandleScope_Dispose(scope);

    // Cast the msg_ptr to SerializedMessage
    const serialized_msg: *SerializedMessage = @ptrCast(@alignCast(msg_ptr));
    defer serialized_msg.deinit();

    // Deserialize the message data to a V8 value
    var v8_data: ?*v8_engine.ffi.Value = null;
    if (serialized_msg.data.type == .primitive) {
        switch (serialized_msg.data.data.primitive) {
            .string => |json_str| {
                v8_data = v8_engine.ffi.v8_JSON_Parse_FromBuffer(
                    v8_context,
                    json_str.ptr,
                    @intCast(json_str.len),
                );
            },
            .null => {
                v8_data = @ptrCast(v8_engine.ffi.v8_Null(isolate));
            },
            .undefined => {
                v8_data = @ptrCast(v8_engine.ffi.v8_Undefined(isolate));
            },
            else => {
                v8_data = @ptrCast(v8_engine.ffi.v8_Null(isolate));
            },
        }
    } else {
        v8_data = @ptrCast(v8_engine.ffi.v8_Null(isolate));
    }

    // Convert to runtime.JSValue
    // IMPORTANT: v8_data is a LOCAL handle from JSON_Parse. Convert to Global so it persists
    // beyond the HandleScope. Local handles become invalid when HandleScope is disposed.
    const data_jsval = if (v8_data) |d| blk: {
        const global_data = v8_engine.ffi.v8_Value_ToGlobal(isolate, @ptrCast(d)) orelse {
            std.log.warn("[MessagePort.handleCrossThreadMessage] failed to convert data to global handle", .{});
            break :blk runtime.JSValue.jsNull;
        };
        break :blk runtime.JSValue.fromHandle(@ptrCast(global_data));
    } else runtime.JSValue.jsNull;

    std.log.warn("[MessagePort.handleCrossThreadMessage] delivering message to port", .{});

    // Deliver the message (creates MessageEvent and dispatches)
    deliverMessage(webidl_instance, data_jsval, runtime.JSValue.jsUndefined) catch |err| {
        std.log.err("[MessagePort.handleCrossThreadMessage] failed to deliver: {s}", .{@errorName(err)});
    };
}

// =============================================================================
// Transfer Support (HTML spec § 9.4.1 - Transferable objects)
// =============================================================================

/// Disentangle a MessagePort for transfer to another realm.
/// Per HTML spec § 9.4.1, this marks the port as shipped and prepares it for
/// transfer. A shipped port cannot be transferred again.
///
/// Returns TransferredPortData containing the port's identity and entanglement info.
pub fn disentangleForTransfer(instance: *runtime.Instance, allocator: std.mem.Allocator) !*TransferredPortData {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return ImplError.InvalidState;

    // Per HTML spec, attempting to transfer an already-shipped port is a DataCloneError
    if (internal.shipped) {
        return ImplError.DataCloneError;
    }

    // Mark as shipped - port is now disentangled from this realm
    internal.shipped = true;

    // Get entangled port ID if any
    const internal_port = internal.internal_port;
    const entangled_id: ?u64 = if (internal_port.entangled_port) |ep| ep.id else null;

    // Create transfer data
    const transfer_data = try allocator.create(TransferredPortData);
    transfer_data.* = .{
        .port_id = internal_port.id,
        .entangled_port_id = entangled_id,
        .internal_port = internal_port,
        .allocator = allocator,
    };

    // Detach internal port from this instance (it belongs to the transfer now)
    // The port remains entangled with its partner, just owned by transfer_data
    internal.port_instance = null;

    return transfer_data;
}

/// Re-entangle a MessagePort from transfer data in the target realm.
/// Per HTML spec § 9.4.1, this creates a new MessagePort wrapper in the target
/// realm that connects to the same internal port.
///
/// Note: The new port is NOT shipped (can be transferred again).
pub fn entangleFromTransfer(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    transfer_data: *TransferredPortData,
) !*runtime.Instance {
    // Create new MessagePort instance using the transferred internal port
    const instance = try initWithInternal(
        allocator,
        StateType,
        vtable,
        ctx,
        transfer_data.internal_port,
    );

    // Update the internal port's webidl_instance to point to the new wrapper
    transfer_data.internal_port.webidl_instance = instance;

    // Transfer data no longer owns the internal port
    // Don't call transfer_data.deinit() - the caller manages that

    return instance;
}

/// Check if a port has been shipped (transferred)
pub fn isShipped(instance: *runtime.Instance) bool {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.shipped;
    }
    return false;
}
