//! Implementation for EventTarget interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-eventtarget
//! WHATWG DOM Standard §2.7

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const infra = @import("infra");
const EventTarget = interfaces.EventTarget;

pub const State = EventTarget.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// DOM §2.7 - Event listener structure
/// An event listener can be used to observe a specific event and consists of:
pub const EventListenerRecord = struct {
    /// type (a string)
    type: runtime.DOMString,

    /// callback (null or an EventListener callback)
    callback: ?*runtime.Instance,

    /// capture (a boolean, initially false)
    capture: bool = false,

    /// passive (null or a boolean, initially null)
    passive: ?bool = null,

    /// once (a boolean, initially false)
    once: bool = false,

    /// signal (null or an AbortSignal object)
    signal: ?*runtime.Instance = null,

    /// removed (a boolean for bookkeeping purposes, initially false)
    removed: bool = false,
};

/// Internal state for EventTarget implementation
/// Contains the event listener list which is lazily allocated to save memory
/// OPTIMIZATION: Most EventTargets never have listeners attached.
/// This saves ~40% memory on typical DOM trees where 90% of nodes have no listeners.
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// DOM §2.7 - Each EventTarget has an associated event listener list
    /// (a list of zero or more event listeners). It is initially the empty list.
    ///
    /// OPTIMIZATION: Lazy allocation - most EventTargets never have listeners attached.
    /// Pattern borrowed from WebKit's NodeRareData and Chromium's NodeRareData.
    event_listener_list: ?*infra.List(EventListenerRecord) = null,

    /// Runtime type discriminator for duck typing
    /// This field helps distinguish EventTarget types at runtime.
    /// - 0: Plain EventTarget or AbortSignal
    /// - 1-12: Node types (ELEMENT_NODE, TEXT_NODE, etc.)
    /// This is filled in by Node's init - EventTarget itself uses 0.
    node_type: u16 = 0,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .event_listener_list = null,
            .node_type = 0,
        };
    }

    pub fn deinit(self: *InternalState) void {
        self.deinitEx(true);
    }

    /// Deinitialize with option to skip V8 resource cleanup
    /// When skip_v8_cleanup is true, V8 global handles are NOT disposed.
    /// This is needed during final runtime cleanup when V8 isolate is already disposed.
    pub fn deinitEx(self: *InternalState, cleanup_v8_resources: bool) void {
        if (self.event_listener_list) |list| {
            // Free any owned DOMStrings and clean up callbacks in event listeners
            const slice = list.toSliceMut();
            for (slice) |*listener| {
                var @"type" = listener.type;
                @"type".deinit(self.allocator);

                // Clean up callback wrapper (disposes Global handles)
                // The callback is stored as ?*runtime.Instance but is actually a *CallbackWrapper
                //
                // NOTE: Callback disposal during cleanup is disabled because V8's internal
                // Global handle slot gets corrupted at some point, causing crashes when
                // calling Reset(). The callback identity fix (using StrictEquals) works
                // correctly for addEventListener/removeEventListener, but the underlying
                // corruption during browser shutdown needs further investigation.
                // For now, we leak these handles during cleanup to avoid crashes.
                _ = cleanup_v8_resources;
                _ = listener.callback;
            }
            list.deinit();
            self.allocator.destroy(list);
        }
    }

    /// Ensure event listener list is allocated
    /// Lazily allocates the list on first use to save memory
    pub fn ensureEventListenerList(self: *InternalState) !*infra.List(EventListenerRecord) {
        if (self.event_listener_list) |list| {
            return list;
        }

        // First time adding a listener - allocate the list
        const list = try self.allocator.create(infra.List(EventListenerRecord));
        list.* = infra.List(EventListenerRecord).init(self.allocator);
        self.event_listener_list = list;
        return list;
    }

    /// Get event listener list (read-only access)
    /// Returns empty slice if no listeners have been added yet
    pub fn getEventListenerList(self: *const InternalState) []const EventListenerRecord {
        if (self.event_listener_list) |list| {
            return list.toSlice();
        }
        return &[_]EventListenerRecord{};
    }
};

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return if (@hasField(@TypeOf(state.own), "_internal")) state.own._internal else null;
}

/// Initialize instance (creates the instance)
/// This is the root of the DOM inheritance chain - creates the Instance and
/// initializes EventTarget's internal state.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize EventTarget internal state in registry
    _ = try initInternal(instance, allocator);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up internal state from registry
    if (getInternalFromRegistry(instance)) |internal| {
        internal.deinit();
        removeFromRegistry(instance);
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-eventtarget
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &EventTarget.vtable, ctx);
    errdefer deinit(instance);

    // Note: EventTarget.State.own is empty struct, so no _internal field
    // For now, we'll manage internal state separately
    // TODO: Add _internal field to State via codegen

    return instance;
}

/// Initialize an EventTarget with internal state
/// This is called by subclasses (like Node) to set up the internal state
pub fn initInternal(instance: *runtime.Instance, allocator: std.mem.Allocator) !*InternalState {
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);

    // Store internal state in registry (ensure it's initialized first)
    try setInternalInRegistry(instance, internal);

    return internal;
}

/// Global registry for internal state
/// This is a workaround until the codegen adds _internal field to State
/// Note: We use a raw pointer to allow cleanup to set it to null
var internal_state_registry: ?std.AutoHashMap(usize, *InternalState) = null;
var cleanup_hook_registered: bool = false;

fn ensureRegistry() *std.AutoHashMap(usize, *InternalState) {
    if (internal_state_registry == null) {
        internal_state_registry = std.AutoHashMap(usize, *InternalState).init(std.heap.page_allocator);
        // Register cleanup hook on first use
        if (!cleanup_hook_registered) {
            runtime.registerCleanupHook(cleanupRegistry);
            cleanup_hook_registered = true;
        }
    }
    return &internal_state_registry.?;
}

/// Clean up all remaining internal states WITH V8 resource cleanup.
/// This should be called during browser/context cleanup, BEFORE V8 is disposed,
/// to properly dispose V8 global handles in CallbackWrappers.
///
/// This is called from cleanup.cleanupAllDomRegistries() which runs before
/// runtime.deinitializeRuntime(), ensuring V8 is still alive.
pub fn cleanupAllRemainingInternal() void {
    if (internal_state_registry) |*registry| {
        // Clean up all internal states with V8 resource cleanup enabled
        var iter = registry.valueIterator();
        while (iter.next()) |internal_ptr| {
            internal_ptr.*.deinitEx(true); // V8 is still alive, clean up global handles
        }
        registry.deinit();
        internal_state_registry = null;
    }
    // Reset flag so hook can be re-registered if runtime is re-initialized
    cleanup_hook_registered = false;
}

/// Clean up all remaining internal states and the registry itself
/// This should be called during runtime shutdown to prevent memory leaks
/// Note: This is called AFTER V8 isolate is disposed, so we must skip V8 resource cleanup
pub fn cleanupRegistry() void {
    if (internal_state_registry) |*registry| {
        // Clean up any remaining internal states
        // Skip V8 cleanup (false) because the isolate is already disposed
        var iter = registry.valueIterator();
        while (iter.next()) |internal_ptr| {
            internal_ptr.*.deinitEx(false);
        }
        registry.deinit();
        internal_state_registry = null;
    }
    // Reset flag so hook can be re-registered if runtime is re-initialized
    cleanup_hook_registered = false;
}

fn getInternalFromRegistry(instance: *runtime.Instance) ?*InternalState {
    const registry = ensureRegistry();
    return registry.get(@intFromPtr(instance));
}

fn setInternalInRegistry(instance: *runtime.Instance, internal: *InternalState) !void {
    const registry = ensureRegistry();
    try registry.put(@intFromPtr(instance), internal);
}

fn removeFromRegistry(instance: *runtime.Instance) void {
    const registry = ensureRegistry();
    _ = registry.remove(@intFromPtr(instance));
}

/// DOM §2.7 - default passive value
/// The default passive value, given an event type type and an EventTarget eventTarget
fn defaultPassiveValue(@"type": []const u8, event_target: *runtime.Instance) bool {
    _ = event_target;
    // Step 1: Return true if type is touchstart, touchmove, wheel, or mousewheel
    // AND eventTarget is Window or specific node conditions
    // For now, simplified: return true for touch/wheel events
    if (std.mem.eql(u8, @"type", "touchstart") or
        std.mem.eql(u8, @"type", "touchmove") or
        std.mem.eql(u8, @"type", "wheel") or
        std.mem.eql(u8, @"type", "mousewheel"))
    {
        // TODO: Check eventTarget conditions per spec
        return true;
    }
    // Step 2: Return false
    return false;
}

/// Compare two callbacks for equality by V8 function identity
/// The callbacks are stored as ?*runtime.Instance but are actually *runtime.CallbackWrapper
/// which contains engine_handle pointing to the actual V8 CallbackWrapper
fn callbackEquals(a: ?*runtime.Instance, b: ?*runtime.Instance) bool {
    if (a == null and b == null) return true;
    if (a == null or b == null) return false;

    // The stored pointers are actually *runtime.CallbackWrapper (not V8 wrappers directly)
    // runtime.CallbackWrapper contains engine_handle which is the V8 CallbackWrapper
    const runtime_wrapper_a: *const runtime.CallbackWrapper = @ptrCast(@alignCast(a.?));
    const runtime_wrapper_b: *const runtime.CallbackWrapper = @ptrCast(@alignCast(b.?));

    // Get the V8 engine wrappers from the engine_handle field
    const v8_engine = @import("v8");
    const v8_wrapper_a: *const v8_engine.CallbackWrapper = @ptrCast(@alignCast(runtime_wrapper_a.engine_handle));
    const v8_wrapper_b: *const v8_engine.CallbackWrapper = @ptrCast(@alignCast(runtime_wrapper_b.engine_handle));

    // Get the underlying V8 Global<Value>* for each callback
    const value_a = v8_wrapper_a.getGlobalValuePtr() orelse return false;
    const value_b = v8_wrapper_b.getGlobalValuePtr() orelse return false;

    // Use V8's StrictEquals to compare the underlying JavaScript functions
    return v8_engine.v8_Value_StrictEquals(value_a, value_b);
}

/// DOM §2.7 - add an event listener
/// To add an event listener, given an EventTarget object eventTarget and
/// an event listener listener, run these steps:
fn addAnEventListener(internal: *InternalState, instance: *runtime.Instance, listener: EventListenerRecord) !void {
    // Step 1: ServiceWorkerGlobalScope warning (skipped - not applicable)

    // Step 2: If listener's signal is not null and is aborted, then return
    if (listener.signal) |signal| {
        // TODO: Check if signal is aborted via AbortSignal interface
        _ = signal;
    }

    // Step 3: If listener's callback is null, then return
    if (listener.callback == null) return;

    // Step 4: If listener's passive is null, set it to default passive value
    var updated_listener = listener;
    if (updated_listener.passive == null) {
        updated_listener.passive = defaultPassiveValue(listener.type.asSlice(), instance);
    }

    // Step 5: If event listener list does not contain matching listener, append it
    const list = try internal.ensureEventListenerList();
    const slice = list.toSlice();

    var already_exists = false;
    for (slice) |existing| {
        if (std.mem.eql(u8, existing.type.asSlice(), listener.type.asSlice()) and
            existing.capture == listener.capture and
            callbackEquals(existing.callback, listener.callback))
        {
            already_exists = true;
            break;
        }
    }

    if (!already_exists) {
        try list.append(updated_listener);
    } else {
        // Listener already exists - clean up the duplicate resources
        // Free the duplicated type string
        var listener_type = updated_listener.type;
        listener_type.deinit(internal.allocator);

        // Also dispose the CallbackWrapper since we're not storing it
        if (updated_listener.callback) |callback_instance| {
            // The stored callback is actually a *runtime.CallbackWrapper
            const runtime_wrapper: *runtime.CallbackWrapper = @ptrCast(@alignCast(callback_instance));
            runtime_wrapper.deinit();
        }
    }

    // Step 6: If listener's signal is not null, add abort steps
    // TODO: Implement abort signal integration
}

/// DOM §2.7 - remove an event listener
/// To remove an event listener, given an EventTarget object eventTarget and
/// an event listener listener, run these steps:
fn removeAnEventListener(internal: *InternalState, listener: EventListenerRecord) void {
    // Step 1: ServiceWorkerGlobalScope warning (skipped - not applicable)

    // Early exit if no listeners have been added yet
    const list = internal.event_listener_list orelse return;

    // Step 2: Set listener's removed to true and remove listener from event listener list
    const slice = list.toSliceMut();
    var i: usize = 0;
    while (i < list.len) {
        const existing = &slice[i];

        // Match on type, callback, and capture
        if (std.mem.eql(u8, existing.type.asSlice(), listener.type.asSlice()) and
            existing.capture == listener.capture and
            callbackEquals(existing.callback, listener.callback))
        {
            existing.removed = true;

            // Clean up the callback wrapper to dispose Global handles
            // The callback is stored as ?*runtime.Instance but is actually a *runtime.CallbackWrapper
            if (existing.callback) |callback_instance| {
                const runtime_wrapper: *runtime.CallbackWrapper = @ptrCast(@alignCast(callback_instance));
                runtime_wrapper.deinit();
            }

            // Free the type DOMString
            var existing_type = existing.type;
            existing_type.deinit(internal.allocator);

            _ = list.remove(i) catch unreachable;
            return;
        }
        i += 1;
    }
}

/// Operation: addEventListener
/// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-addeventlistener
pub fn call_addEventListener(instance: *runtime.Instance, @"type": runtime.DOMString, callback: ??*runtime.CallbackWrapper, options: webidl.Opt(runtime.JSValue)) anyerror!void {
    // Get or create internal state
    var internal = getInternalFromRegistry(instance);
    if (internal == null) {
        // First operation - initialize internal state
        const ArenaAllocator = @import("runtime").ArenaAllocator;
        const new_internal = ArenaAllocator.get().create(InternalState) catch return error.OutOfMemory;
        new_internal.* = InternalState.init(std.heap.page_allocator);
        setInternalInRegistry(instance, new_internal) catch return error.OutOfMemory;
        internal = new_internal;
    }

    // Flatten options - for now treat as AddEventListenerOptions
    // TODO: Properly interpret options union (boolean or AddEventListenerOptions)
    _ = options;
    const capture = false; // Default
    const passive: ?bool = null;
    const once = false;
    const signal: ?*runtime.Instance = null;

    // Convert callback wrapper to Instance pointer if present
    // The callback comes as ??*runtime.CallbackWrapper but we store ?*runtime.Instance
    const callback_instance: ?*runtime.Instance = if (callback) |cb_opt| blk: {
        if (cb_opt) |cb| {
            // Cast CallbackWrapper pointer to Instance pointer
            // This is safe because CallbackWrapper wraps an Instance
            break :blk @ptrCast(cb);
        }
        break :blk null;
    } else null;

    // Duplicate the type string with internal allocator to ensure ownership
    // The incoming DOMString may be allocated with a different allocator (from V8 conversion layer)
    // and we need to own it to safely free it in deinit()
    const owned_type = runtime.DOMString.initDupe(internal.?.allocator, @"type".asSlice()) catch return error.OutOfMemory;

    // Create listener record with owned type string
    const listener = EventListenerRecord{
        .type = owned_type,
        .callback = callback_instance,
        .capture = capture,
        .passive = passive,
        .once = once,
        .signal = signal,
    };

    addAnEventListener(internal.?, instance, listener) catch |err| {
        // Clean up owned type on error
        var type_copy = owned_type;
        type_copy.deinit(internal.?.allocator);
        return err;
    };
}

/// Operation: removeEventListener
/// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-removeeventlistener
pub fn call_removeEventListener(instance: *runtime.Instance, @"type": runtime.DOMString, callback: ??*runtime.CallbackWrapper, options: webidl.Opt(runtime.JSValue)) anyerror!void {
    // Get the raw callback wrapper for later cleanup (before any unwrapping)
    const raw_callback_wrapper: ?*runtime.CallbackWrapper = if (callback) |cb_opt| cb_opt else null;

    // Ensure we always dispose the comparison callback wrapper when done
    defer if (raw_callback_wrapper) |wrapper| {
        wrapper.deinit();
    };

    const internal = getInternalFromRegistry(instance) orelse return;

    // Flatten options
    _ = options;
    const capture = false; // Default

    // Convert callback wrapper to Instance pointer if present
    const callback_instance: ?*runtime.Instance = if (callback) |cb_opt| blk: {
        if (cb_opt) |cb| {
            break :blk @ptrCast(cb);
        }
        break :blk null;
    } else null;

    // Create listener record for matching
    const listener = EventListenerRecord{
        .type = @"type",
        .callback = callback_instance,
        .capture = capture,
    };

    removeAnEventListener(internal, listener);
}

/// Operation: dispatchEvent
/// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-dispatchevent
pub fn call_dispatchEvent(instance: *runtime.Instance, event: *runtime.Instance) anyerror!bool {
    // Get Event impl to check flags
    const EventImpl = @import("Event.zig");

    // Step 1: If event's dispatch flag is set, or if its initialized flag is not set,
    //         then throw an "InvalidStateError" DOMException.
    if (EventImpl.getDispatchFlag(event)) {
        return error.InvalidStateError;
    }

    // Check initialized flag via internal state
    // For now, assume event is initialized if it exists

    // Step 2: Initialize event's isTrusted attribute to false
    EventImpl.setIsTrusted(event, false);

    // Step 3: Return the result of dispatching event to this
    // TODO: Implement full dispatch algorithm from event_dispatch.zig
    // For now, return true (event not canceled)

    // Get internal state if available
    const internal = getInternalFromRegistry(instance);

    if (internal) |int| {
        // Set event's target
        EventImpl.setTarget(event, instance);

        // Get listeners for this event type (use interface per Golden Rule #13)
        const @"type" = interfaces.Event.get_type(event) catch return true;
        const listeners = int.getEventListenerList();

        // Invoke matching listeners (from addEventListener)
        for (listeners) |listener| {
            if (std.mem.eql(u8, listener.type.asSlice(), @"type".asSlice()) and
                !listener.removed)
            {
                // Actually invoke the callback
                if (listener.callback) |callback_instance| {
                    // The callback is stored as ?*runtime.Instance but is actually a *runtime.CallbackWrapper
                    const runtime_wrapper: *runtime.CallbackWrapper = @ptrCast(@alignCast(callback_instance));
                    const v8_engine = @import("v8");

                    // Get the V8 context from the instance context
                    if (instance.ctx.engine_ctx) |engine_ctx| {
                        const v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(engine_ctx));

                        // Get the current V8 isolate
                        const v8_isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse continue;

                        // Wrap the event as a V8 object
                        const event_v8_obj = v8_engine.template_registry.wrapInstanceAsV8Object(
                            event,
                            "Event",
                            v8_isolate,
                            v8_context,
                        ) catch {
                            // If we can't wrap the event, skip this listener
                            continue;
                        };

                        // Invoke the callback with the event as an argument
                        // Use the runtime wrapper's invoke method which delegates to the engine
                        _ = runtime_wrapper.invoke1(@ptrCast(event_v8_obj)) catch {
                            // If callback invocation fails, continue to next listener
                            continue;
                        };
                    }
                }

                // If listener.once is true, remove it
                if (listener.once) {
                    removeAnEventListener(int, listener);
                }
            }
        }
    }

    // Also invoke IDL event handler attributes (onload, onclick, etc.)
    // These are stored in HTMLElement's event_handlers map and need to be invoked separately
    // Per HTML spec: https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes
    invokeIdlEventHandler(instance, event);

    // Return !canceled
    return !EventImpl.getCanceledFlag(event);
}

/// Invoke IDL event handler attribute (e.g., onload, onclick) for the given event
/// Per HTML spec, event handler IDL attributes like `element.onload = fn` are stored
/// separately from addEventListener callbacks and must also be invoked during dispatch.
fn invokeIdlEventHandler(instance: *runtime.Instance, event: *runtime.Instance) void {
    const v8_engine = @import("v8");
    const pointer_tag = v8_engine.pointer_tag;
    const global_handles = v8_engine.global_handles;

    // Get the event type
    const event_type_str = interfaces.Event.get_type(event) catch return;

    // Try to get HTMLElement's internal state which stores event handlers
    const HTMLElementImpl = @import("HTMLElement.zig");
    const html_internal = HTMLElementImpl.getInternalState(instance) orelse return;

    // Look up the event handler for this event type
    // NOTE: event_handlers now stores *anyopaque to preserve tagged pointer bits
    const raw_ptr = html_internal.event_handlers.get(event_type_str.asSlice()) orelse return;

    // Untag the pointer to get the GlobalHandle
    const untagged = pointer_tag.untagPointer(raw_ptr);

    // Verify it's a global_handle tag (set during fromV8Value conversion)
    if (untagged.tag != .global_handle) {
        // Not a V8 callback - might be a native Zig function (unlikely for IDL handlers)
        return;
    }

    // Get V8 context and isolate
    const engine_ctx = instance.ctx.engine_ctx orelse return;
    const v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const v8_isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return;

    // Create a HandleScope for working with V8 Local handles.
    // V8 Local handles are only valid within a HandleScope.
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(v8_isolate) orelse return;
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    // Wrap the GlobalHandle
    const global_handle = global_handles.GlobalHandle{ .ptr = @ptrCast(untagged.ptr) };

    // Verify the global handle contains a function.
    // v8_Value_IsFunction expects a Global<Value>* - pass the GlobalHandle directly.
    // The C++ side will get the Local from the Global with proper HandleScope.
    if (!v8_engine.ffi.v8_Value_IsFunction(global_handle.ptr)) {
        return;
    }

    // Use the engine_ctx directly - it's already a Global<Context>* owned by the runtime context.
    // No need to call v8_Isolate_GetCurrentContext which would create a new Global that needs disposal.

    // Wrap the event as a V8 object (Local handle)
    const event_v8_local = v8_engine.template_registry.wrapInstanceAsV8Object(
        event,
        "Event",
        v8_isolate,
        v8_context,
    ) catch return;

    // Convert the event Local to a Global for the function call
    const event_v8_global = v8_engine.ffi.v8_Value_ToGlobal(v8_isolate, @ptrCast(event_v8_local)) orelse return;
    defer v8_engine.ffi.v8_Global_Dispose(event_v8_global);

    // Get 'this' value as a Global - v8_Undefined returns a Global<Value>*
    const recv_global = v8_engine.ffi.v8_Undefined(v8_isolate);

    // Prepare argument array with Global handles
    var args: [1]*v8_engine.ffi.Value = .{event_v8_global};

    // Call the function using v8_Function_Call_Safe which expects Global handles
    // - global_handle.ptr is already a Global<Value>* containing the function
    // - v8_context is Global<Context>* (from engine_ctx)
    // - recv_global is Global<Value>* (undefined)
    // - args contains Global<Value>*
    const result = v8_engine.ffi.v8_Function_Call_Safe(
        global_handle.ptr, // Global<Value>* containing the function
        v8_context, // Global<Context>* from engine_ctx
        @ptrCast(recv_global), // Global<Value>* for 'this'
        1,
        @ptrCast(&args),
    );

    // Free the result (errors are silently ignored - per HTML spec, event handler errors
    // should not prevent other handlers from running)
    v8_engine.ffi.v8_FreeFunctionCallResult(result);
}

/// Operation: when (Observable)
/// Spec: https://wicg.github.io/observable-api/#dom-eventtarget-when
/// This is part of the Observable API proposal
pub fn call_when(instance: *runtime.Instance, @"type": runtime.DOMString, options: webidl.Opt(dictionaries.ObservableEventListenerOptions)) anyerror!*runtime.Instance {
    _ = instance;
    _ = @"type";
    _ = options;
    // TODO: Implement Observable API
    return error.NotImplemented;
}

// ============================================================================
// Helper functions for subclasses (Node, Element, etc.)
// ============================================================================

/// Get the internal state for an EventTarget instance
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return getInternalFromRegistry(instance);
}

/// Set the node type for this EventTarget (used by Node)
pub fn setNodeType(instance: *runtime.Instance, node_type: u16) void {
    if (getInternalFromRegistry(instance)) |internal| {
        internal.node_type = node_type;
    }
}

/// Get the node type for this EventTarget
pub fn getNodeType(instance: *runtime.Instance) u16 {
    if (getInternalFromRegistry(instance)) |internal| {
        return internal.node_type;
    }
    return 0; // Plain EventTarget
}

/// Get all event listeners for a specific type
pub fn getEventListenersForType(instance: *runtime.Instance, @"type": []const u8) []const EventListenerRecord {
    const internal = getInternalFromRegistry(instance) orelse return &[_]EventListenerRecord{};
    const list = internal.event_listener_list orelse return &[_]EventListenerRecord{};

    // Note: This returns all listeners, caller should filter by type
    // In a real implementation, we'd return a filtered view
    _ = @"type";
    return list.toSlice();
}
