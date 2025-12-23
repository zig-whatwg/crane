//! DOM Standard: EventTarget Internal Algorithms (§2.7)
//! https://dom.spec.whatwg.org/#interface-eventtarget
//!
//! This module contains the internal DOM algorithms for EventTarget.
//! The WebIDL impl (src/webidl/impls/EventTarget.zig) delegates to these.

const std = @import("std");
const runtime = @import("runtime");
const infra = @import("infra");

/// DOM §2.7 - Event listener structure
/// An event listener can be used to observe a specific event and consists of:
pub const EventListener = struct {
    /// type (a string)
    type: []const u8,

    /// callback (null or an EventListener callback)
    /// This is actually a *runtime.CallbackWrapper cast to *anyopaque
    /// The EventTarget takes ownership of this callback.
    callback: ?*anyopaque,

    /// capture (a boolean, initially false)
    capture: bool = false,

    /// passive (null or a boolean, initially null)
    passive: ?bool = null,

    /// once (a boolean, initially false)
    once: bool = false,

    /// signal (null or an AbortSignal object)
    signal: ?*anyopaque = null,

    /// removed (a boolean for bookkeeping purposes, initially false)
    removed: bool = false,

    /// Whether this listener owns its callback (for cleanup)
    owns_callback: bool = true,
};

/// Internal state for EventTarget
/// Contains the event listener list and related state.
pub const EventTargetData = struct {
    allocator: std.mem.Allocator,

    /// DOM §2.7 - Each EventTarget has an associated event listener list
    /// (a list of zero or more event listeners). It is initially the empty list.
    event_listeners: std.ArrayList(EventListener),

    /// Runtime type discriminator for duck typing
    /// - 0: Plain EventTarget or AbortSignal
    /// - 1-12: Node types (ELEMENT_NODE, TEXT_NODE, etc.)
    node_type: u16 = 0,

    pub fn init(allocator: std.mem.Allocator) EventTargetData {
        return .{
            .allocator = allocator,
            .event_listeners = std.ArrayList(EventListener).init(allocator),
            .node_type = 0,
        };
    }

    pub fn deinit(self: *EventTargetData) void {
        self.deinitEx(true);
    }

    /// Deinitialize with option to skip V8 resource cleanup
    /// When cleanup_v8_resources is false, V8 global handles are NOT disposed.
    /// This is needed during final runtime cleanup when V8 isolate is already disposed.
    pub fn deinitEx(self: *EventTargetData, cleanup_v8_resources: bool) void {
        for (self.event_listeners.items) |*listener| {
            // Free the owned type string
            self.allocator.free(listener.type);

            // Clean up callback wrapper if we own it
            if (cleanup_v8_resources and listener.owns_callback) {
                if (listener.callback) |callback_ptr| {
                    const v8_engine = @import("v8");
                    const callback_wrapper: *v8_engine.CallbackWrapper = @ptrCast(@alignCast(callback_ptr));
                    callback_wrapper.deinit();
                }
            }
        }
        self.event_listeners.deinit();
    }
};

/// DOM §2.7 - default passive value
/// The default passive value, given an event type and an EventTarget
pub fn defaultPassiveValue(event_type: []const u8, _: *anyopaque) bool {
    // Return true for touch/wheel events (simplified)
    // Full spec: also checks if eventTarget is Window or specific node conditions
    return std.mem.eql(u8, event_type, "touchstart") or
        std.mem.eql(u8, event_type, "touchmove") or
        std.mem.eql(u8, event_type, "wheel") or
        std.mem.eql(u8, event_type, "mousewheel");
}

/// DOM §2.7 - add an event listener
/// To add an event listener, given an EventTarget object eventTarget and
/// an event listener listener, run these steps:
///
/// IMPORTANT: This function takes ownership of listener.callback.
/// The caller must NOT free the callback after calling this.
pub fn addAnEventListener(
    data: *EventTargetData,
    event_target: *anyopaque,
    listener: EventListener,
) !void {
    // Step 1: ServiceWorkerGlobalScope warning (skipped - not applicable)

    // Step 2: If listener's signal is not null and is aborted, then return
    if (listener.signal) |_| {
        // TODO: Check if signal is aborted via AbortSignal interface
    }

    // Step 3: If listener's callback is null, then return
    if (listener.callback == null) return;

    // Step 4: If listener's passive is null, set it to default passive value
    var updated_listener = listener;
    if (updated_listener.passive == null) {
        updated_listener.passive = defaultPassiveValue(listener.type, event_target);
    }

    // Step 5: If event listener list does not contain matching listener, append it
    // Check for existing listener with same type, callback, and capture
    for (data.event_listeners.items) |existing| {
        if (std.mem.eql(u8, existing.type, listener.type) and
            existing.capture == listener.capture and
            existing.callback == listener.callback)
        {
            // Listener already exists - don't add duplicate
            // But we took ownership of the callback, so we need to mark this one
            // as not owning it to avoid double-free
            // Actually, since the callbacks are identical pointers, we should
            // free the type string we allocated and return
            data.allocator.free(listener.type);
            return;
        }
    }

    // Listener doesn't exist - add it
    try data.event_listeners.append(updated_listener);

    // Step 6: If listener's signal is not null, add abort steps
    // TODO: Implement abort signal integration
}

/// DOM §2.7 - remove an event listener
/// To remove an event listener, given an EventTarget object eventTarget and
/// an event listener listener, run these steps:
pub fn removeAnEventListener(
    data: *EventTargetData,
    event_type: []const u8,
    callback: ?*anyopaque,
    capture: bool,
) void {
    // Step 1: ServiceWorkerGlobalScope warning (skipped - not applicable)

    // Step 2: Set listener's removed to true and remove listener from event listener list
    var i: usize = 0;
    while (i < data.event_listeners.items.len) {
        const existing = &data.event_listeners.items[i];

        // Match on type, callback, and capture
        if (std.mem.eql(u8, existing.type, event_type) and
            existing.capture == capture and
            existing.callback == callback)
        {
            existing.removed = true;

            // Clean up the callback wrapper if we own it
            if (existing.owns_callback) {
                if (existing.callback) |callback_ptr| {
                    const v8_engine = @import("v8");
                    const callback_wrapper: *v8_engine.CallbackWrapper = @ptrCast(@alignCast(callback_ptr));
                    callback_wrapper.deinit();
                }
            }

            // Free the type string
            data.allocator.free(existing.type);

            // Remove from list
            _ = data.event_listeners.orderedRemove(i);
            return;
        }
        i += 1;
    }
}

/// Get all event listeners (for event dispatch)
pub fn getEventListeners(data: *const EventTargetData) []const EventListener {
    return data.event_listeners.items;
}

/// Check if an EventTarget has any listeners for a given type
pub fn hasEventListeners(data: *const EventTargetData, event_type: []const u8) bool {
    for (data.event_listeners.items) |listener| {
        if (std.mem.eql(u8, listener.type, event_type) and !listener.removed) {
            return true;
        }
    }
    return false;
}
