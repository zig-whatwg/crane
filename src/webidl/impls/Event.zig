//! Implementation for Event interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-event
//! WHATWG DOM Standard §2.3

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const infra = @import("infra");
const clock = @import("clock");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const event_dispatch = @import("dom").event_dispatch;
const Event = interfaces.Event;

pub const State = Event.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
};

/// Event's internal state - its flags, path, targets, phase and isTrusted -
/// is `dom.event_dispatch.EventState`: its type lives there so that the
/// dispatcher (EventTarget) works on its fields directly; the state itself is
/// this impl's, created with the event and freed with it.
pub const InternalState = event_dispatch.EventState;

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // The constructing steps every subclass runs (dom.event_construction);
    // each subclass's init chains through this one.
    @import("dom").event_construction.installEvent(.{ .inner_event_creation_steps = &innerEventCreationStepsHook, .dispatch_flag = &dispatchFlag });
    // The state dispatch works on, and what it does to an event that no IDL
    // member does (dom.event_dispatch).
    event_dispatch.install(.{ .state = &stateOf, .swap_type = &swapTypeHook });
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

/// dom.event_dispatch.of: `event`'s state, brand-checked - null for an
/// instance that is not an Event (no unchecked cast) or one that has no state.
fn stateOf(event: *runtime.Instance) ?*InternalState {
    const state = event.stateAs(State) orelse return null;
    return state.own._internal;
}

/// dom.event_dispatch: set `event`'s type attribute value to `event_type`
/// and hand back the value it held - "invoke" step 9's rename and its undo.
fn swapTypeHook(event: *runtime.Instance, event_type: runtime.DOMString) ?runtime.DOMString {
    const state = event.stateAs(State) orelse return null;
    const previous = state.own.type;
    state.own.type = event_type;
    return previous;
}

/// dom.event_construction's inner event creation steps.
fn innerEventCreationStepsHook(event: *runtime.Instance, event_type: runtime.DOMString, init_dict: @import("dom").event_construction.EventInit) anyerror!void {
    return innerEventCreationSteps(event, event_type, .{ .bubbles = init_dict.bubbles, .cancelable = init_dict.cancelable, .composed = init_dict.composed });
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up internal state
    const state = instance.getState(State);

    // Free the cloned event type string (created in call_constructor)
    // DOMString.deinit is safe to call on empty/interned strings
    state.own.type.deinit(instance.ctx.allocator);

    if (state.own._internal) |internal| {
        // An event its wrapper's collection frees has no edge left to end.
        internal.forgetTarget(instance);
        internal.deinit();
        // Note: Internal state memory is managed by arena allocator
        // Return the block itself, not just what it points to. `internal.deinit()`
        // releases what the state OWNS; the state struct was staying allocated for
        // the life of the process.
        runtime.arenaOf(instance).destroy(InternalState, internal);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// Spec: https://dom.spec.whatwg.org/#dom-event-event
///
/// The Event(type, eventInitDict) constructor steps are:
/// 1. Set this's initialized flag.
/// 2. Initialize this with type, bubbles, and cancelable.
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.EventInit)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &Event.vtable, ctx);
    errdefer deinit(instance);

    // Get state and initialize
    const state = instance.getState(State);

    // Create internal state
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = InternalState.init(ctx.allocator);
    state.own._internal = internal;

    // Set the initialized flag
    internal.initialized_flag = true;

    // Initialize event attributes from eventInitDict
    const event_init = if (eventInitDict.was_passed) eventInitDict.value else dictionaries.EventInit{};
    const bubbles = event_init.bubbles orelse false;
    const cancelable = event_init.cancelable orelse false;
    const composed = event_init.composed orelse false;

    // Store event type - clone the string to ensure we own it
    state.own.type = try @"type".clone(ctx.allocator);

    // Initialize from EventInit dictionary
    state.own.bubbles = bubbles;
    state.own.cancelable = cancelable;
    state.own.composed = composed;

    // Initialize other attributes to defaults: the target, currentTarget,
    // eventPhase and isTrusted are the internal state's, initially null,
    // null, NONE and false.
    state.own.cancelBubble = false;
    state.own.returnValue = true; // !canceled_flag
    state.own.defaultPrevented = false;
    state.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(clock.monotonicMillis()));

    return instance;
}

/// Getter for type
/// Spec: https://dom.spec.whatwg.org/#dom-event-type
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    // Return as interned to avoid double-free (state owns the string)
    // The V8 callback cleanup will not free interned strings
    return runtime.DOMString.initInterned(state.own.type.asSlice());
}

/// Getter for target
/// Getter for target
/// Returns the target of this event, or null if the event is not dispatched.
/// Spec: https://dom.spec.whatwg.org/#dom-event-target
pub fn get_target(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return internal.target;
}

/// Getter for srcElement (legacy)
/// Returns the same as target.
/// Spec: https://dom.spec.whatwg.org/#dom-event-srcelement
/// The srcElement getter steps are to return this's target.
pub fn get_srcElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return internal.target;
}

/// Getter for currentTarget
/// Returns the current target of this event, or null.
/// Spec: https://dom.spec.whatwg.org/#dom-event-currenttarget
pub fn get_currentTarget(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return internal.current_target;
}

/// Getter for eventPhase
/// Spec: https://dom.spec.whatwg.org/#dom-event-eventphase
pub fn get_eventPhase(instance: *runtime.Instance) anyerror!u16 {
    const internal = getInternal(instance) orelse return Event.get_NONE();
    return internal.phase;
}

/// Getter for cancelBubble (legacy)
/// Spec: https://dom.spec.whatwg.org/#dom-event-cancelbubble
/// The cancelBubble getter steps are to return true if this's stop propagation
/// flag is set; otherwise false.
pub fn get_cancelBubble(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return internal.stop_propagation_flag;
}

/// Getter for bubbles
/// Spec: https://dom.spec.whatwg.org/#dom-event-bubbles
pub fn get_bubbles(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    return state.own.bubbles;
}

/// Getter for cancelable
/// Spec: https://dom.spec.whatwg.org/#dom-event-cancelable
pub fn get_cancelable(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    return state.own.cancelable;
}

/// Getter for returnValue (legacy)
/// Spec: https://dom.spec.whatwg.org/#dom-event-returnvalue
/// The returnValue getter steps are to return false if this's canceled flag
/// is set; otherwise true.
pub fn get_returnValue(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return true;
    return !internal.canceled_flag;
}

/// Getter for defaultPrevented
/// Spec: https://dom.spec.whatwg.org/#dom-event-defaultprevented
pub fn get_defaultPrevented(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return internal.canceled_flag;
}

/// Getter for composed
/// Spec: https://dom.spec.whatwg.org/#dom-event-composed
pub fn get_composed(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    return state.own.composed;
}

/// Getter for isTrusted
/// Spec: https://dom.spec.whatwg.org/#dom-event-istrusted
pub fn get_isTrusted(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return internal.is_trusted;
}

/// Getter for timeStamp
/// Spec: https://dom.spec.whatwg.org/#dom-event-timestamp
pub fn get_timeStamp(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    const state = instance.getState(State);
    return state.own.timeStamp;
}

/// Setter for cancelBubble (legacy)
/// Spec: https://dom.spec.whatwg.org/#dom-event-cancelbubble
/// The cancelBubble setter steps are to set this's stop propagation flag if
/// the given value is true; otherwise do nothing.
pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) anyerror!void {
    if (value) {
        const internal = getInternal(instance) orelse return;
        internal.stop_propagation_flag = true;
    }
}

/// Setter for returnValue (legacy)
/// Spec: https://dom.spec.whatwg.org/#dom-event-returnvalue
/// The returnValue setter steps are to set the canceled flag with this if
/// the given value is false; otherwise do nothing.
pub fn set_returnValue(instance: *runtime.Instance, value: bool) anyerror!void {
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
    internal.setCanceledFlag(state.own.cancelable);
}

/// Operation: stopPropagation
/// Spec: https://dom.spec.whatwg.org/#dom-event-stoppropagation
pub fn call_stopPropagation(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return;
    internal.stop_propagation_flag = true;
}

/// Operation: stopImmediatePropagation
/// Spec: https://dom.spec.whatwg.org/#dom-event-stopimmediatepropagation
pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return;
    internal.stop_propagation_flag = true;
    internal.stop_immediate_propagation_flag = true;
}

/// Operation: preventDefault
/// Spec: https://dom.spec.whatwg.org/#dom-event-preventdefault
/// The preventDefault() method steps are to set the canceled flag with this.
pub fn call_preventDefault(instance: *runtime.Instance) anyerror!void {
    setCanceledFlag(instance);
}

/// DOM §2.3 - initialize an event
/// To initialize an event, with type, bubbles, and cancelable, run these steps:
///
/// Returns an error only if the type string cannot be cloned; every other step
/// is infallible.
fn initializeEvent(instance: *runtime.Instance, @"type": runtime.DOMString, bubbles: bool, cancelable: bool) !void {
    const state = instance.getState(State);
    const internal = getInternal(instance) orelse return;

    // Step 5 is done FIRST because it is the only fallible one: if the clone
    // fails there is nothing to roll back.
    //
    // The clone is the whole point. The WebIDL conversion layer hands an impl a
    // DOMString it owns and frees the moment the call returns, so storing the
    // argument left `event.type` pointing at freed memory - and dispatch, which
    // matches listeners on `event.type`, then matched nothing at all. That is
    // what made registered handlers look like they were never invoked.
    var next_type = try @"type".clone(instance.ctx.allocator);
    errdefer next_type.deinit(instance.ctx.allocator);

    // Step 1: Set event's initialized flag
    internal.initialized_flag = true;

    // Step 2: Unset event's stop propagation flag, stop immediate propagation flag, and canceled flag
    internal.stop_propagation_flag = false;
    internal.stop_immediate_propagation_flag = false;
    internal.canceled_flag = false;

    // Step 3: Set event's isTrusted attribute to false
    internal.is_trusted = false;

    // Step 4: Set event's target to null
    internal.setTarget(instance, null);

    // Step 5: Set event's type attribute to type
    // The previous value was ours, so release it rather than leaking one
    // string per initEvent call.
    state.own.type.deinit(instance.ctx.allocator);
    state.own.type = next_type;

    // Step 6: Set event's bubbles attribute to bubbles
    state.own.bubbles = bubbles;

    // Step 7: Set event's cancelable attribute to cancelable
    state.own.cancelable = cancelable;
}

/// DOM "inner event creation steps", for the constructor of Event or of an
/// interface that inherits from it, followed by that constructor's step 2
/// ("initialize event's type attribute to type"). `instance` is the new object
/// (step 1: its interface's constructor made it); an inheriting interface runs
/// its own event constructing steps - its own dictionary members - after
/// this. `dictionary` is the constructor's dictionary's EventInit part
/// (BORROWED); `type` is copied.
///
/// Spec: https://dom.spec.whatwg.org/#inner-event-creation-steps
fn innerEventCreationSteps(instance: *runtime.Instance, @"type": runtime.DOMString, dictionary: dictionaries.EventInit) !void {
    // An inheriting interface's state contains Event's; find it by offset.
    const state = instance.stateAs(State) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // The event's own copy of the type first: with the Event internal state
    // below, the only fallible steps - nothing is left half-initialized.
    var next_type = try @"type".clone(allocator);
    errdefer next_type.deinit(allocator);
    const internal = state.own._internal orelse blk: {
        const created = try runtime.arenaOf(instance).create(InternalState);
        created.* = InternalState.init(allocator);
        state.own._internal = created;
        break :blk created;
    };

    // 2. Set event's initialized flag.
    internal.initialized_flag = true;

    // 3. Initialize event's timeStamp attribute to the relative high
    //    resolution coarse time given time (now) and event's relevant global
    //    object.
    state.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(clock.monotonicMillis()));

    // 4. For each member -> value of dictionary: if event has an attribute
    //    whose identifier is member, initialize that attribute to value.
    //    EventInit's members, each false by default.
    state.own.bubbles = dictionary.bubbles orelse false;
    state.own.cancelable = dictionary.cancelable orelse false;
    state.own.composed = dictionary.composed orelse false;

    // The attributes no member names keep their initial values.
    internal.setTarget(instance, null);
    internal.current_target = null;
    internal.phase = Event.get_NONE();
    internal.is_trusted = false;
    state.own.cancelBubble = false;
    state.own.returnValue = true;
    state.own.defaultPrevented = false;

    // 5. Run the event constructing steps: Event has none; an inheriting
    //    interface runs its own when this returns.

    // The constructor's step 2: initialize event's type attribute to type.
    state.own.type.deinit(allocator);
    state.own.type = next_type;
}

/// Operation: initEvent (legacy)
/// Spec: https://dom.spec.whatwg.org/#dom-event-initevent
/// The initEvent(type, bubbles, cancelable) method steps are:
/// 1. If this's dispatch flag is set, then return.
/// 2. Initialize this with type, bubbles, and cancelable.
pub fn call_initEvent(instance: *runtime.Instance, @"type": runtime.DOMString, bubbles: webidl.Opt(bool), cancelable: webidl.Opt(bool)) anyerror!void {
    const internal = getInternal(instance) orelse return;

    // Step 1: If dispatch flag is set, return
    if (internal.dispatch_flag) return;

    // Step 2: Initialize this
    const bubbles_val = if (bubbles.was_passed) bubbles.value else false;
    const cancelable_val = if (cancelable.was_passed) cancelable.value else false;
    try initializeEvent(instance, @"type", bubbles_val, cancelable_val);
}

/// Operation: composedPath
/// Spec: https://dom.spec.whatwg.org/#dom-event-composedpath
///
/// Returns the invocation target objects of event's path (objects on which
/// listeners will be invoked), except for any nodes in shadow trees of which
/// the shadow root's mode is "closed" that are not reachable from event's
/// currentTarget.
pub fn call_composedPath(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.NotImplemented;

    // Step 1: Let composedPath be an empty list
    var composed_path = infra.List(*runtime.Instance).init(internal.allocator);

    // Step 2: Let path be this's path
    const path = internal.path.toSlice();

    // Step 3: If path is empty, then return composedPath (empty array)
    if (path.len == 0) {
        return sequenceOfEventTargets(instance, &.{});
    }

    // Step 4: Let currentTarget be this's currentTarget attribute value
    const current_target = internal.current_target;

    // Step 5: Assert: currentTarget is an EventTarget object
    if (current_target == null) {
        // Path is not empty but currentTarget is null - shouldn't happen during dispatch
        // Return the empty composedPath
        defer composed_path.deinit();
        return sequenceOfEventTargets(instance, composed_path.toSlice());
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

    // Step 17: Return composedPath, as a sequence<EventTarget>. The array
    // holds its own references to the targets' wrappers; the list is ours.
    defer composed_path.deinit();
    return sequenceOfEventTargets(instance, composed_path.toSlice());
}

/// `targets` converted to a JS value as composedPath's sequence<EventTarget>:
/// a new array of the current realm - the operation's, where WebIDL converts
/// its result - holding each target's wrapper, which is made in the target's
/// own relevant realm. OWNED: the binding takes it.
fn sequenceOfEventTargets(instance: *runtime.Instance, targets: []const *runtime.Instance) !runtime.JSValue {
    const sequence = try engine.createSequenceOfPlatformObjects(engine.currentRealm() orelse instance.ctx, targets);
    return sequence.take();
}

/// dom.event_construction: whether `instance`'s dispatch flag is set (the
/// legacy init*Event() methods' step 1).
fn dispatchFlag(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.dispatch_flag;
}
