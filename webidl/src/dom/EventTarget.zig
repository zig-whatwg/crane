//! EventTarget interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-eventtarget

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");

const Allocator = std.mem.Allocator;
const Event = @import("event").Event;
const AbortSignal = @import("abort_signal").AbortSignal;

/// DOM §2.7 - Event listener structure
/// An event listener can be used to observe a specific event and consists of:
pub const EventListener = struct {
    /// type (a string)
    type: []const u8,

    /// callback (null or an EventListener object)
    callback: ?webidl.JSValue,

    /// capture (a boolean, initially false)
    capture: bool = false,

    /// passive (null or a boolean, initially null)
    passive: ?bool = null,

    /// once (a boolean, initially false)
    once: bool = false,

    /// signal (null or an AbortSignal object)
    signal: ?*AbortSignal = null,

    /// removed (a boolean for bookkeeping purposes, initially false)
    removed: bool = false,
};

/// DOM §2.7 - EventListenerOptions dictionary
pub const EventListenerOptions = struct {
    capture: bool = false,
};

/// DOM §2.7 - AddEventListenerOptions dictionary
pub const AddEventListenerOptions = struct {
    capture: bool = false,
    passive: ?bool = null,
    once: bool = false,
    signal: ?*AbortSignal = null,
};

/// EventTarget WebIDL interface
pub const EventTarget = webidl.interface(struct {
    allocator: Allocator,

    /// DOM §2.7 - Each EventTarget has an associated event listener list
    /// (a list of zero or more event listeners). It is initially the empty list.
    event_listener_list: std.ArrayList(EventListener),

    pub fn init(allocator: Allocator) !EventTarget {
        return .{
            .allocator = allocator,
            .event_listener_list = std.ArrayList(EventListener).init(allocator),
        };
    }

    pub fn deinit(self: *EventTarget) void {
        self.event_listener_list.deinit();
    }

    /// DOM §2.7 - flatten options
    /// To flatten options, run these steps:
    /// 1. If options is a boolean, then return options.
    /// 2. Return options["capture"].
    fn flattenOptions(options: anytype) bool {
        // TODO: Handle boolean or dictionary
        // For now, return false
        _ = options;
        return false;
    }

    /// DOM §2.7 - flatten more options
    /// Returns: capture, passive, once, signal
    fn flattenMoreOptions(options: anytype) struct { capture: bool, passive: ?bool, once: bool, signal: ?*AbortSignal } {
        // TODO: Handle boolean or AddEventListenerOptions dictionary
        // For now, return defaults
        _ = options;
        return .{
            .capture = false,
            .passive = null,
            .once = false,
            .signal = null,
        };
    }

    /// DOM §2.7 - default passive value
    /// The default passive value, given an event type type and an EventTarget eventTarget
    fn defaultPassiveValue(event_type: []const u8, event_target: *EventTarget) bool {
        _ = event_target;
        // Step 1: Return true if type is touchstart, touchmove, wheel, or mousewheel
        // AND eventTarget is Window or specific node conditions
        // For now, simplified: return true for touch/wheel events
        if (std.mem.eql(u8, event_type, "touchstart") or
            std.mem.eql(u8, event_type, "touchmove") or
            std.mem.eql(u8, event_type, "wheel") or
            std.mem.eql(u8, event_type, "mousewheel"))
        {
            // TODO: Check eventTarget conditions per spec
            return true;
        }
        // Step 2: Return false
        return false;
    }

    /// DOM §2.7 - add an event listener
    /// To add an event listener, given an EventTarget object eventTarget and
    /// an event listener listener, run these steps:
    fn addAnEventListener(self: *EventTarget, listener: EventListener) !void {
        // Step 1: ServiceWorkerGlobalScope warning (skipped - not applicable)

        // Step 2: If listener's signal is not null and is aborted, then return
        if (listener.signal) |signal| {
            _ = signal;
            // TODO: Check if signal is aborted
            // if (signal.aborted) return;
        }

        // Step 3: If listener's callback is null, then return
        if (listener.callback == null) return;

        // Step 4: If listener's passive is null, set it to default passive value
        var updated_listener = listener;
        if (updated_listener.passive == null) {
            updated_listener.passive = defaultPassiveValue(listener.type, self);
        }

        // Step 5: If event listener list does not contain matching listener, append it
        const already_exists = for (self.event_listener_list.items) |existing| {
            if (std.mem.eql(u8, existing.type, listener.type) and
                existing.capture == listener.capture)
            {
                // TODO: Compare callbacks properly
                // For now, assume same callback if type and capture match
                break true;
            }
        } else false;

        if (!already_exists) {
            try self.event_listener_list.append(updated_listener);
        }

        // Step 6: If listener's signal is not null, add abort steps
        if (listener.signal) |_| {
            // TODO: Add abort steps to signal to remove listener
        }
    }

    /// addEventListener(type, callback, options)
    /// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-addeventlistener
    /// The addEventListener(type, callback, options) method steps are:
    /// 1. Let capture, passive, once, and signal be the result of flattening more options.
    /// 2. Add an event listener with this and an event listener whose type is type,
    ///    callback is callback, capture is capture, passive is passive, once is once,
    ///    and signal is signal.
    pub fn call_addEventListener(
        self: *EventTarget,
        event_type: []const u8,
        callback: ?webidl.JSValue,
        options: anytype,
    ) !void {
        // Step 1: Flatten more options
        const flattened = flattenMoreOptions(options);

        // Step 2: Add an event listener
        const listener = EventListener{
            .type = event_type,
            .callback = callback,
            .capture = flattened.capture,
            .passive = flattened.passive,
            .once = flattened.once,
            .signal = flattened.signal,
        };

        try self.addAnEventListener(listener);
    }

    /// DOM §2.7 - remove an event listener
    /// To remove an event listener, given an EventTarget object eventTarget and
    /// an event listener listener, run these steps:
    fn removeAnEventListener(self: *EventTarget, listener: EventListener) void {
        // Step 1: ServiceWorkerGlobalScope warning (skipped - not applicable)

        // Step 2: Set listener's removed to true and remove listener from event listener list
        var i: usize = 0;
        while (i < self.event_listener_list.items.len) {
            const existing = &self.event_listener_list.items[i];

            // Match on type, callback, and capture
            if (std.mem.eql(u8, existing.type, listener.type) and
                existing.capture == listener.capture)
            {
                // TODO: Compare callbacks properly
                // For now, assume match if type and capture match
                existing.removed = true;
                _ = self.event_listener_list.orderedRemove(i);
                return;
            }
            i += 1;
        }
    }

    /// removeEventListener(type, callback, options)
    /// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-removeeventlistener
    /// The removeEventListener(type, callback, options) method steps are:
    /// 1. Let capture be the result of flattening options.
    /// 2. If this's event listener list contains an event listener whose type is type,
    ///    callback is callback, and capture is capture, then remove an event listener
    ///    with this and that event listener.
    pub fn call_removeEventListener(
        self: *EventTarget,
        event_type: []const u8,
        callback: ?webidl.JSValue,
        options: anytype,
    ) void {
        // Step 1: Flatten options
        const capture = flattenOptions(options);

        // Step 2: Remove matching listener
        const listener = EventListener{
            .type = event_type,
            .callback = callback,
            .capture = capture,
        };

        self.removeAnEventListener(listener);
    }

    /// dispatchEvent(event)
    /// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-dispatchevent
    /// The dispatchEvent(event) method steps are:
    /// 1. If event's dispatch flag is set, or if its initialized flag is not set,
    ///    then throw an "InvalidStateError" DOMException.
    /// 2. Initialize event's isTrusted attribute to false.
    /// 3. Return the result of dispatching event to this.
    pub fn call_dispatchEvent(self: *EventTarget, event: *Event) !bool {
        // Step 1: Check flags
        if (event.dispatch_flag or !event.initialized_flag) {
            return error.InvalidStateError;
        }

        // Step 2: Initialize isTrusted to false
        event.is_trusted = false;

        // Step 3: Dispatch event to this
        // TODO: Implement dispatch algorithm (see whatwg-cbk)
        _ = self;
        @panic("dispatchEvent - dispatch algorithm not yet implemented (see whatwg-cbk)");
    }
}, .{
    .exposed = &.{.global},
});
