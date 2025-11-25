//! Implementation for Event interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-event
//! WHATWG DOM Standard §2.3

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const infra = @import("infra");
const Event = interfaces.Event;

pub const State = Event.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
};

/// EventPath item - used by event dispatch algorithm
/// DOM §2.9.1: Each path struct consists of:
pub const EventPathItem = struct {
    invocation_target: *runtime.Instance,
    invocation_target_in_shadow_tree: bool,
    shadow_adjusted_target: ?*runtime.Instance,
    related_target: ?*runtime.Instance,
    touch_target_list: infra.List(*runtime.Instance),
    root_of_closed_tree: bool,
    slot_in_closed_tree: bool,
};

/// Internal state for Event implementation
/// Contains private data not exposed via WebIDL attributes:
/// - Event flags (DOM §2.3)
/// - Event path
/// - Related target and touch target list
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    // DOM §2.3 - Event flags (initially unset)
    stop_propagation_flag: bool = false,
    stop_immediate_propagation_flag: bool = false,
    canceled_flag: bool = false,
    in_passive_listener_flag: bool = false,
    initialized_flag: bool = false,
    dispatch_flag: bool = false,

    // DOM §2.3 - Event path (initially empty)
    path: infra.List(EventPathItem),

    // DOM §2.3 - Related target (initially null)
    related_target: ?*runtime.Instance = null,

    // DOM §2.3 - Touch target list (initially empty)
    touch_target_list: infra.List(*runtime.Instance),

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .path = infra.List(EventPathItem).init(allocator),
            .touch_target_list = infra.List(*runtime.Instance).init(allocator),
        };
    }

    pub fn deinit(self: *InternalState) void {
        // Deinit touch target lists in path items
        const slice = self.path.toSliceMut();
        for (slice) |*item| {
            item.touch_target_list.deinit();
        }
        self.path.deinit();
        self.touch_target_list.deinit();
    }
};

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // Initialize state will be done in call_constructor
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up internal state
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        // Note: Internal state memory is managed by arena allocator
    }
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
/// Spec: https://dom.spec.whatwg.org/#dom-event-event
///
/// The Event(type, eventInitDict) constructor steps are:
/// 1. Set this's initialized flag.
/// 2. Initialize this with type, bubbles, and cancelable.
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, event_type: runtime.DOMString, eventInitDict: dictionaries.EventInit) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &Event.vtable, ctx);
    errdefer deinit(instance);

    // Get state and initialize
    const state = instance.getState(State);

    // Create internal state
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;

    // Set the initialized flag
    internal.initialized_flag = true;

    // Initialize event attributes from eventInitDict
    const bubbles = eventInitDict.bubbles orelse false;
    const cancelable = eventInitDict.cancelable orelse false;
    const composed = eventInitDict.composed orelse false;

    // Store event type - clone the string to ensure we own it
    state.own.type = try event_type.clone(allocator);

    // Initialize from EventInit dictionary
    state.own.bubbles = bubbles;
    state.own.cancelable = cancelable;
    state.own.composed = composed;

    // Initialize other attributes to defaults
    state.own.target = null;
    state.own.srcElement = null;
    state.own.currentTarget = null;
    state.own.eventPhase = Event.get_NONE(); // NONE = 0
    state.own.cancelBubble = false;
    state.own.returnValue = true; // !canceled_flag
    state.own.defaultPrevented = false;
    state.own.isTrusted = false;
    state.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(std.time.milliTimestamp()));

    return instance;
}

/// Getter for type
/// Spec: https://dom.spec.whatwg.org/#dom-event-type
pub fn get_type(instance: *runtime.Instance) !runtime.DOMString {
    const state = instance.getState(State);
    return state.own.type;
}

/// Getter for target
/// Spec: https://dom.spec.whatwg.org/#dom-event-target
pub fn get_target(instance: *runtime.Instance) !?*runtime.Instance {
    const state = instance.getState(State);
    return state.own.target orelse return error.NotImplemented;
}

/// Getter for srcElement (legacy)
/// Spec: https://dom.spec.whatwg.org/#dom-event-srcelement
/// The srcElement getter steps are to return this's target.
pub fn get_srcElement(instance: *runtime.Instance) !?*runtime.Instance {
    const state = instance.getState(State);
    return state.own.target orelse return error.NotImplemented;
}

/// Getter for currentTarget
/// Spec: https://dom.spec.whatwg.org/#dom-event-currenttarget
pub fn get_currentTarget(instance: *runtime.Instance) !?*runtime.Instance {
    const state = instance.getState(State);
    return state.own.currentTarget orelse return error.NotImplemented;
}

/// Getter for eventPhase
/// Spec: https://dom.spec.whatwg.org/#dom-event-eventphase
pub fn get_eventPhase(instance: *runtime.Instance) !u16 {
    const state = instance.getState(State);
    return state.own.eventPhase;
}

/// Getter for cancelBubble (legacy)
/// Spec: https://dom.spec.whatwg.org/#dom-event-cancelbubble
/// The cancelBubble getter steps are to return true if this's stop propagation
/// flag is set; otherwise false.
pub fn get_cancelBubble(instance: *runtime.Instance) !bool {
    const internal = getInternal(instance) orelse return false;
    return internal.stop_propagation_flag;
}

/// Getter for bubbles
/// Spec: https://dom.spec.whatwg.org/#dom-event-bubbles
pub fn get_bubbles(instance: *runtime.Instance) !bool {
    const state = instance.getState(State);
    return state.own.bubbles;
}

/// Getter for cancelable
/// Spec: https://dom.spec.whatwg.org/#dom-event-cancelable
pub fn get_cancelable(instance: *runtime.Instance) !bool {
    const state = instance.getState(State);
    return state.own.cancelable;
}

/// Getter for returnValue (legacy)
/// Spec: https://dom.spec.whatwg.org/#dom-event-returnvalue
/// The returnValue getter steps are to return false if this's canceled flag
/// is set; otherwise true.
pub fn get_returnValue(instance: *runtime.Instance) !bool {
    const internal = getInternal(instance) orelse return true;
    return !internal.canceled_flag;
}

/// Getter for defaultPrevented
/// Spec: https://dom.spec.whatwg.org/#dom-event-defaultprevented
pub fn get_defaultPrevented(instance: *runtime.Instance) !bool {
    const internal = getInternal(instance) orelse return false;
    return internal.canceled_flag;
}

/// Getter for composed
/// Spec: https://dom.spec.whatwg.org/#dom-event-composed
pub fn get_composed(instance: *runtime.Instance) !bool {
    const state = instance.getState(State);
    return state.own.composed;
}

/// Getter for isTrusted
/// Spec: https://dom.spec.whatwg.org/#dom-event-istrusted
pub fn get_isTrusted(instance: *runtime.Instance) !bool {
    const state = instance.getState(State);
    return state.own.isTrusted;
}

/// Getter for timeStamp
/// Spec: https://dom.spec.whatwg.org/#dom-event-timestamp
pub fn get_timeStamp(instance: *runtime.Instance) !typedefs.DOMHighResTimeStamp {
    const state = instance.getState(State);
    return state.own.timeStamp;
}

/// Setter for cancelBubble (legacy)
/// Spec: https://dom.spec.whatwg.org/#dom-event-cancelbubble
/// The cancelBubble setter steps are to set this's stop propagation flag if
/// the given value is true; otherwise do nothing.
pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) !void {
    if (value) {
        const internal = getInternal(instance) orelse return;
        internal.stop_propagation_flag = true;
    }
}

/// Setter for returnValue (legacy)
/// Spec: https://dom.spec.whatwg.org/#dom-event-returnvalue
/// The returnValue setter steps are to set the canceled flag with this if
/// the given value is false; otherwise do nothing.
pub fn set_returnValue(instance: *runtime.Instance, value: bool) !void {
    if (!value) {
        setCanceledFlag(instance);
    }
}

/// DOM §2.3 - set the canceled flag
/// To set the canceled flag, given an event event, if event's cancelable
/// attribute value is true and event's in passive listener flag is unset,
/// then set event's canceled flag, and do nothing otherwise.
fn setCanceledFlag(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = getInternal(instance) orelse return;

    if (state.own.cancelable and !internal.in_passive_listener_flag) {
        internal.canceled_flag = true;
    }
}

/// Operation: stopPropagation
/// Spec: https://dom.spec.whatwg.org/#dom-event-stoppropagation
pub fn call_stopPropagation(instance: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return;
    internal.stop_propagation_flag = true;
}

/// Operation: stopImmediatePropagation
/// Spec: https://dom.spec.whatwg.org/#dom-event-stopimmediatepropagation
pub fn call_stopImmediatePropagation(instance: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return;
    internal.stop_propagation_flag = true;
    internal.stop_immediate_propagation_flag = true;
}

/// Operation: preventDefault
/// Spec: https://dom.spec.whatwg.org/#dom-event-preventdefault
/// The preventDefault() method steps are to set the canceled flag with this.
pub fn call_preventDefault(instance: *runtime.Instance) !void {
    setCanceledFlag(instance);
}

/// DOM §2.3 - initialize an event
/// To initialize an event, with type, bubbles, and cancelable, run these steps:
fn initializeEvent(instance: *runtime.Instance, event_type: runtime.DOMString, bubbles: bool, cancelable: bool) void {
    const state = instance.getState(State);
    const internal = getInternal(instance) orelse return;

    // Step 1: Set event's initialized flag
    internal.initialized_flag = true;

    // Step 2: Unset event's stop propagation flag, stop immediate propagation flag, and canceled flag
    internal.stop_propagation_flag = false;
    internal.stop_immediate_propagation_flag = false;
    internal.canceled_flag = false;

    // Step 3: Set event's isTrusted attribute to false
    state.own.isTrusted = false;

    // Step 4: Set event's target to null
    state.own.target = null;

    // Step 5: Set event's type attribute to type
    state.own.type = event_type;

    // Step 6: Set event's bubbles attribute to bubbles
    state.own.bubbles = bubbles;

    // Step 7: Set event's cancelable attribute to cancelable
    state.own.cancelable = cancelable;
}

/// Operation: initEvent (legacy)
/// Spec: https://dom.spec.whatwg.org/#dom-event-initevent
/// The initEvent(type, bubbles, cancelable) method steps are:
/// 1. If this's dispatch flag is set, then return.
/// 2. Initialize this with type, bubbles, and cancelable.
pub fn call_initEvent(instance: *runtime.Instance, event_type: runtime.DOMString, bubbles: bool, cancelable: bool) !void {
    const internal = getInternal(instance) orelse return;

    // Step 1: If dispatch flag is set, return
    if (internal.dispatch_flag) return;

    // Step 2: Initialize this
    initializeEvent(instance, event_type, bubbles, cancelable);
}

/// Operation: composedPath
/// Spec: https://dom.spec.whatwg.org/#dom-event-composedpath
///
/// Returns the invocation target objects of event's path (objects on which
/// listeners will be invoked), except for any nodes in shadow trees of which
/// the shadow root's mode is "closed" that are not reachable from event's
/// currentTarget.
pub fn call_composedPath(instance: *runtime.Instance) !*const anyopaque {
    const internal = getInternal(instance) orelse return error.NotImplemented;
    const state = instance.getState(State);

    // Step 1: Let composedPath be an empty list
    var composed_path = infra.List(*runtime.Instance).init(internal.allocator);

    // Step 2: Let path be this's path
    const path = internal.path.toSlice();

    // Step 3: If path is empty, then return composedPath
    if (path.len == 0) {
        // Return pointer to the list (caller will interpret)
        return @ptrCast(&composed_path);
    }

    // Step 4: Let currentTarget be this's currentTarget attribute value
    const current_target = state.own.currentTarget;

    // Step 5: Assert: currentTarget is an EventTarget object
    if (current_target == null) {
        // Path is not empty but currentTarget is null - shouldn't happen during dispatch
        return @ptrCast(&composed_path);
    }

    // Step 6: Append currentTarget to composedPath
    try composed_path.append(current_target.?);

    // Step 7: Let currentTargetIndex be 0
    var current_target_index: usize = 0;

    // Step 8: Let currentTargetHiddenSubtreeLevel be 0
    var current_target_hidden_subtree_level: i32 = 0;

    // Step 9: Let index be path's size − 1
    var index: i32 = @as(i32, @intCast(path.len)) - 1;

    // Step 10: While index is greater than or equal to 0
    while (index >= 0) : (index -= 1) {
        const path_item = path[@intCast(index)];

        // Step 10.1: If path[index]'s root-of-closed-tree is true,
        // then increase currentTargetHiddenSubtreeLevel by 1
        if (path_item.root_of_closed_tree) {
            current_target_hidden_subtree_level += 1;
        }

        // Step 10.2: If path[index]'s invocation target is currentTarget,
        // then set currentTargetIndex to index and break
        if (path_item.invocation_target == current_target.?) {
            current_target_index = @intCast(index);
            break;
        }

        // Step 10.3: If path[index]'s slot-in-closed-tree is true,
        // then decrease currentTargetHiddenSubtreeLevel by 1
        if (path_item.slot_in_closed_tree) {
            current_target_hidden_subtree_level -= 1;
        }
    }

    // Step 11: Let currentHiddenLevel and maxHiddenLevel be currentTargetHiddenSubtreeLevel
    var current_hidden_level = current_target_hidden_subtree_level;
    var max_hidden_level = current_target_hidden_subtree_level;

    // Step 12: Set index to currentTargetIndex − 1
    index = @as(i32, @intCast(current_target_index)) - 1;

    // Step 13: While index is greater than or equal to 0
    while (index >= 0) : (index -= 1) {
        const path_item = path[@intCast(index)];

        // Step 13.1: If path[index]'s root-of-closed-tree is true,
        // then increase currentHiddenLevel by 1
        if (path_item.root_of_closed_tree) {
            current_hidden_level += 1;
        }

        // Step 13.2: If currentHiddenLevel is less than or equal to maxHiddenLevel,
        // then prepend path[index]'s invocation target to composedPath
        if (current_hidden_level <= max_hidden_level) {
            try composed_path.insert(0, path_item.invocation_target);
        }

        // Step 13.3: If path[index]'s slot-in-closed-tree is true
        if (path_item.slot_in_closed_tree) {
            // Step 13.3.1: Decrease currentHiddenLevel by 1
            current_hidden_level -= 1;

            // Step 13.3.2: If currentHiddenLevel is less than maxHiddenLevel,
            // then set maxHiddenLevel to currentHiddenLevel
            if (current_hidden_level < max_hidden_level) {
                max_hidden_level = current_hidden_level;
            }
        }
    }

    // Step 14: Set currentHiddenLevel and maxHiddenLevel to currentTargetHiddenSubtreeLevel
    current_hidden_level = current_target_hidden_subtree_level;
    max_hidden_level = current_target_hidden_subtree_level;

    // Step 15: Set index to currentTargetIndex + 1
    index = @as(i32, @intCast(current_target_index)) + 1;

    // Step 16: While index is less than path's size
    while (index < path.len) : (index += 1) {
        const path_item = path[@intCast(index)];

        // Step 16.1: If path[index]'s slot-in-closed-tree is true,
        // then increase currentHiddenLevel by 1
        if (path_item.slot_in_closed_tree) {
            current_hidden_level += 1;
        }

        // Step 16.2: If currentHiddenLevel is less than or equal to maxHiddenLevel,
        // then append path[index]'s invocation target to composedPath
        if (current_hidden_level <= max_hidden_level) {
            try composed_path.append(path_item.invocation_target);
        }

        // Step 16.3: If path[index]'s root-of-closed-tree is true
        if (path_item.root_of_closed_tree) {
            // Step 16.3.1: Decrease currentHiddenLevel by 1
            current_hidden_level -= 1;

            // Step 16.3.2: If currentHiddenLevel is less than maxHiddenLevel,
            // then set maxHiddenLevel to currentHiddenLevel
            if (current_hidden_level < max_hidden_level) {
                max_hidden_level = current_hidden_level;
            }
        }
    }

    // Step 17: Return composedPath
    // Note: Returning as opaque pointer - the JS bindings will interpret this
    return @ptrCast(&composed_path);
}

// ============================================================================
// Helper functions for event dispatch (used by event_dispatch.zig)
// ============================================================================

/// Set the dispatch flag (called by dispatch algorithm)
pub fn setDispatchFlag(instance: *runtime.Instance, value: bool) void {
    const internal = getInternal(instance) orelse return;
    internal.dispatch_flag = value;
}

/// Get the dispatch flag
pub fn getDispatchFlag(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.dispatch_flag;
}

/// Set the stop propagation flag
pub fn getStopPropagationFlag(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.stop_propagation_flag;
}

/// Get the stop immediate propagation flag
pub fn getStopImmediatePropagationFlag(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.stop_immediate_propagation_flag;
}

/// Set the in passive listener flag
pub fn setInPassiveListenerFlag(instance: *runtime.Instance, value: bool) void {
    const internal = getInternal(instance) orelse return;
    internal.in_passive_listener_flag = value;
}

/// Get the event path
pub fn getPath(instance: *runtime.Instance) ?*infra.List(EventPathItem) {
    const internal = getInternal(instance) orelse return null;
    return &internal.path;
}

/// Set the target
pub fn setTarget(instance: *runtime.Instance, target: ?*runtime.Instance) void {
    const state = instance.getState(State);
    state.own.target = target;
    state.own.srcElement = target;
}

/// Set the current target
pub fn setCurrentTarget(instance: *runtime.Instance, current_target: ?*runtime.Instance) void {
    const state = instance.getState(State);
    state.own.currentTarget = current_target;
}

/// Set the event phase
pub fn setEventPhase(instance: *runtime.Instance, phase: u16) void {
    const state = instance.getState(State);
    state.own.eventPhase = phase;
}

/// Set the isTrusted flag
pub fn setIsTrusted(instance: *runtime.Instance, value: bool) void {
    const state = instance.getState(State);
    state.own.isTrusted = value;
}

/// Get the canceled flag
pub fn getCanceledFlag(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.canceled_flag;
}

/// Set the related target
pub fn setRelatedTarget(instance: *runtime.Instance, target: ?*runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.related_target = target;
}

/// Get the related target
pub fn getRelatedTarget(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return internal.related_target;
}

/// Get the touch target list
pub fn getTouchTargetList(instance: *runtime.Instance) ?*infra.List(*runtime.Instance) {
    const internal = getInternal(instance) orelse return null;
    return &internal.touch_target_list;
}
