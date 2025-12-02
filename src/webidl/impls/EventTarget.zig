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
        if (self.event_listener_list) |list| {
            // Free any owned DOMStrings in event listeners
            const slice = list.toSliceMut();
            for (slice) |*listener| {
                var @"type" = listener.type;
                @"type".deinit(self.allocator);
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
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &EventTarget.vtable, ctx);
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
var internal_state_registry: std.AutoHashMap(usize, *InternalState) = undefined;
var registry_initialized: bool = false;

fn ensureRegistry() void {
    if (!registry_initialized) {
        internal_state_registry = std.AutoHashMap(usize, *InternalState).init(std.heap.page_allocator);
        registry_initialized = true;
    }
}

fn getInternalFromRegistry(instance: *runtime.Instance) ?*InternalState {
    ensureRegistry();
    return internal_state_registry.get(@intFromPtr(instance));
}

fn setInternalInRegistry(instance: *runtime.Instance, internal: *InternalState) !void {
    ensureRegistry();
    try internal_state_registry.put(@intFromPtr(instance), internal);
}

fn removeFromRegistry(instance: *runtime.Instance) void {
    ensureRegistry();
    _ = internal_state_registry.remove(@intFromPtr(instance));
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

/// Compare two callbacks for equality (by reference)
fn callbackEquals(a: ?*runtime.Instance, b: ?*runtime.Instance) bool {
    if (a == null and b == null) return true;
    if (a == null or b == null) return false;
    return a.? == b.?;
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
            _ = list.remove(i) catch unreachable;
            return;
        }
        i += 1;
    }
}

/// Operation: addEventListener
/// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-addeventlistener
pub fn call_addEventListener(instance: *runtime.Instance, @"type": runtime.DOMString, callback: ??*runtime.CallbackWrapper, options: webidl.Opt(*const anyopaque)) anyerror!void {
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

    // Create listener record
    const listener = EventListenerRecord{
        .type = @"type",
        .callback = callback_instance,
        .capture = capture,
        .passive = passive,
        .once = once,
        .signal = signal,
    };

    addAnEventListener(internal.?, instance, listener) catch return error.OutOfMemory;
}

/// Operation: removeEventListener
/// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-removeeventlistener
pub fn call_removeEventListener(instance: *runtime.Instance, @"type": runtime.DOMString, callback: ??*runtime.CallbackWrapper, options: webidl.Opt(*const anyopaque)) anyerror!void {
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

        // Invoke matching listeners
        for (listeners) |listener| {
            if (std.mem.eql(u8, listener.type.asSlice(), @"type".asSlice()) and
                !listener.removed)
            {
                // TODO: Actually invoke the callback
                // For now, just mark that we found listeners

                // If listener.once is true, remove it
                if (listener.once) {
                    removeAnEventListener(int, listener);
                }
            }
        }
    }

    // Return !canceled
    return !EventImpl.getCanceledFlag(event);
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
