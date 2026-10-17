//! Implementation for MouseEvent interface
//!
//! Spec: https://w3c.github.io/uievents/#interface-mouseevent
//! MouseEvent inherits from UIEvent which inherits from Event

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const KeptInstance = @import("dom").custom_elements.KeptInstance;
const MouseEvent = interfaces.MouseEvent;
const event_construction = @import("dom").event_construction;

pub const State = MouseEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// The event keeps its related target alive: an edge from the event's
/// wrapper (engine.traceChild, `related_target_slot`), drawn when the target
/// is set - by the constructor or initMouseEvent - and ended in deinit, as
/// FocusEvent keeps its own. Blink: MouseEvent::Trace visits
/// related_target_; WebKit: MouseRelatedEvent's RefPtr<EventTarget>. It was a
/// bare pointer in the generated state, and a held `new MouseEvent(t,
/// {relatedTarget})` read a freed or reissued node once the target's tree was
/// collected (lane ownerdoc, crane/od-event-keeps-its-targets.html).
///
/// `related_target` is the native pointer beside the edge, with its slab
/// generation and realm (KeptInstance): only the teardown net. Made when a
/// related target is first set, so an event with none - most of the ones the
/// engine fires - allocates nothing.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    related_target: ?KeptInstance = null,
};

const related_target_slot: engine.TracedSlot = .{ .name = "relatedTarget" };

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md):
/// PointerEvent and WheelEvent set their relatedTarget through it.
pub fn installHooks() void {
    event_construction.installMouseEvent(.{ .set_related_target = &setRelatedTarget });
}

/// Set the related target the event reports, and keep it: the edge from the
/// event to it replaces the one to the target it had.
fn setRelatedTarget(instance: *runtime.Instance, target: ?*runtime.Instance) error{OutOfMemory}!void {
    const state = instance.getState(State);
    state.own.relatedTarget = target;
    if (target) |t| {
        const internal = state.own._internal orelse made: {
            const allocator = instance.ctx.allocator;
            const internal = try allocator.create(InternalState);
            internal.* = .{ .allocator = allocator };
            state.own._internal = internal;
            break :made internal;
        };
        internal.related_target = KeptInstance.of(t);
        engine.traceChild(instance, t, related_target_slot);
    } else if (state.own._internal) |internal| {
        if (internal.related_target != null) {
            internal.related_target = null;
            engine.forgetTracedChild(instance, related_target_slot);
        }
    }
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Through UIEvent's init, which installs its constructing steps
    // (dom.event_construction) and chains to Event's.
    return interfaces.UIEvent.initWithState(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // An event freed without ever being wrapped lets the hold waiting for
        // its wrapper go; a collected one's edge went with the wrapper.
        if (internal.related_target != null) engine.forgetTracedChild(instance, related_target_slot);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    // Clean up inherited Event state (frees the type DOMString)
    interfaces.Event.deinit(instance);
}

/// Constructor implementation
/// Spec: https://w3c.github.io/uievents/#dom-mouseevent-mouseevent
///
/// The MouseEvent(type, eventInitDict) constructor steps are:
/// 1. Set this's initialized flag.
/// 2. Initialize this with type, bubbles, and cancelable.
/// 3. Initialize mouse event properties from eventInitDict.
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.MouseEventInit)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &MouseEvent.vtable, ctx);
    errdefer deinit(instance);

    // Its state: the UIEvent, MouseEvent and own attributes are set below
    const state = instance.getState(State);

    // Build default dictionary chain
    // MouseEventInit extends EventModifierInit extends UIEventInit extends EventInit
    const default_event_init = dictionaries.EventInit{};
    const default_ui_init = dictionaries.UIEventInit{ .base = default_event_init };
    const default_modifier_init = dictionaries.EventModifierInit{ .base = default_ui_init };
    const default_mouse_init = dictionaries.MouseEventInit{ .base = default_modifier_init };

    const event_init = if (eventInitDict.was_passed) eventInitDict.value else default_mouse_init;

    // Access nested base fields for inherited dictionary properties
    const modifier_init = event_init.base;
    const ui_init = modifier_init.base;
    const base_init = ui_init.base;

    // DOM "inner event creation steps" and the constructor's step 2 - Event's
    // part: its internal state, the initialized flag, the timeStamp,
    // EventInit's members and the type - through Event's own steps
    // (dom.event_construction), never its state's type.
    try event_construction.innerEventCreationSteps(instance, @"type", event_construction.eventInitFrom(base_init));

    // Initialize UIEvent attributes (in state.base.own): view, detail and the
    // legacy which.
    event_construction.initializeUIEvent(instance, event_construction.uiEventInitFrom(ui_init));

    // Initialize MouseEvent attributes (in state.own). MouseEventInit's
    // coordinates are longs (pointerevents.idl, which now defines MouseEvent).
    const screenX: i32 = event_init.screenX orelse 0;
    const screenY: i32 = event_init.screenY orelse 0;
    const clientX: i32 = event_init.clientX orelse 0;
    const clientY: i32 = event_init.clientY orelse 0;

    state.own.screenX = screenX;
    state.own.screenY = screenY;
    state.own.clientX = clientX;
    state.own.clientY = clientY;
    state.own.ctrlKey = modifier_init.ctrlKey orelse false;
    state.own.shiftKey = modifier_init.shiftKey orelse false;
    state.own.altKey = modifier_init.altKey orelse false;
    state.own.metaKey = modifier_init.metaKey orelse false;
    state.own.button = event_init.button orelse 0;
    state.own.buttons = event_init.buttons orelse 0;
    try setRelatedTarget(instance, event_init.relatedTarget orelse null);

    // Initialize additional MouseEvent properties from CSSOM View Module
    state.own.movementX = event_init.movementX orelse 0.0;
    state.own.movementY = event_init.movementY orelse 0.0;

    // Computed properties (these might need layout info, default to clientX/Y)
    state.own.pageX = @floatFromInt(clientX);
    state.own.pageY = @floatFromInt(clientY);
    state.own.x = @floatFromInt(clientX);
    state.own.y = @floatFromInt(clientY);
    state.own.offsetX = @floatFromInt(clientX);
    state.own.offsetY = @floatFromInt(clientY);
    state.own.layerX = clientX;
    state.own.layerY = clientY;

    return instance;
}

/// Getter for screenX
pub fn get_screenX(instance: *runtime.Instance) anyerror!i32 {
    const state = instance.getState(State);
    return state.own.screenX;
}

/// Getter for screenY
pub fn get_screenY(instance: *runtime.Instance) anyerror!i32 {
    const state = instance.getState(State);
    return state.own.screenY;
}

/// Getter for clientX
pub fn get_clientX(instance: *runtime.Instance) anyerror!i32 {
    const state = instance.getState(State);
    return state.own.clientX;
}

/// Getter for clientY
pub fn get_clientY(instance: *runtime.Instance) anyerror!i32 {
    const state = instance.getState(State);
    return state.own.clientY;
}

/// Getter for layerX
pub fn get_layerX(instance: *runtime.Instance) anyerror!i32 {
    const state = instance.getState(State);
    return state.own.layerX;
}

/// Getter for layerY
pub fn get_layerY(instance: *runtime.Instance) anyerror!i32 {
    const state = instance.getState(State);
    return state.own.layerY;
}

/// Getter for ctrlKey
pub fn get_ctrlKey(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    return state.own.ctrlKey;
}

/// Getter for shiftKey
pub fn get_shiftKey(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    return state.own.shiftKey;
}

/// Getter for altKey
pub fn get_altKey(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    return state.own.altKey;
}

/// Getter for metaKey
pub fn get_metaKey(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    return state.own.metaKey;
}

/// Getter for button
pub fn get_button(instance: *runtime.Instance) anyerror!i16 {
    const state = instance.getState(State);
    return state.own.button;
}

/// Getter for buttons
pub fn get_buttons(instance: *runtime.Instance) anyerror!u16 {
    const state = instance.getState(State);
    return state.own.buttons;
}

/// Getter for relatedTarget: the value it was initialized to. The event's
/// edge keeps it; null only past its realm's teardown (the net above).
pub fn get_relatedTarget(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return state.own.relatedTarget;
    const kept = internal.related_target orelse return state.own.relatedTarget;
    return kept.get();
}

/// Getter for movementX
pub fn get_movementX(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.movementX;
}

/// Getter for movementY
pub fn get_movementY(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.movementY;
}

/// Getter for pageX
pub fn get_pageX(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.pageX;
}

/// Getter for pageY
pub fn get_pageY(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.pageY;
}

/// Getter for x
pub fn get_x(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.x;
}

/// Getter for y
pub fn get_y(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.y;
}

/// Getter for offsetX
pub fn get_offsetX(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.offsetX;
}

/// Getter for offsetY
pub fn get_offsetY(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.offsetY;
}

/// Operation: initMouseEvent
/// UI Events 6.1 (legacy event initializers): "Initializes attributes of a
/// MouseEvent object. This method has the same behavior as
/// UIEvent.initUIEvent()" - nothing while the event is being dispatched -
/// and sets screenX, screenY, clientX, clientY, the four modifier keys,
/// button and relatedTarget from its arguments (each defaulting to 0, false
/// or null). Blink's MouseEvent::initMouseEvent and Gecko's do the same; the
/// coordinates derived from clientX/Y follow them as the constructor's do.
pub fn call_initMouseEvent(instance: *runtime.Instance, typeArg: runtime.DOMString, bubblesArg: webidl.Opt(bool), cancelableArg: webidl.Opt(bool), viewArg: webidl.Opt(?*runtime.Instance), detailArg: webidl.Opt(i32), screenXArg: webidl.Opt(i32), screenYArg: webidl.Opt(i32), clientXArg: webidl.Opt(i32), clientYArg: webidl.Opt(i32), ctrlKeyArg: webidl.Opt(bool), altKeyArg: webidl.Opt(bool), shiftKeyArg: webidl.Opt(bool), metaKeyArg: webidl.Opt(bool), buttonArg: webidl.Opt(i16), relatedTargetArg: webidl.Opt(?*runtime.Instance)) anyerror!void {
    if (event_construction.dispatchFlag(instance)) return;
    try interfaces.UIEvent.call_initUIEvent(instance, typeArg, bubblesArg, cancelableArg, viewArg, detailArg);
    const state = instance.getState(State);
    const client_x = clientXArg.getOrDefault(0);
    const client_y = clientYArg.getOrDefault(0);
    state.own.screenX = screenXArg.getOrDefault(0);
    state.own.screenY = screenYArg.getOrDefault(0);
    state.own.clientX = client_x;
    state.own.clientY = client_y;
    state.own.pageX = @floatFromInt(client_x);
    state.own.pageY = @floatFromInt(client_y);
    state.own.x = @floatFromInt(client_x);
    state.own.y = @floatFromInt(client_y);
    state.own.offsetX = @floatFromInt(client_x);
    state.own.offsetY = @floatFromInt(client_y);
    state.own.layerX = client_x;
    state.own.layerY = client_y;
    state.own.ctrlKey = ctrlKeyArg.getOrDefault(false);
    state.own.altKey = altKeyArg.getOrDefault(false);
    state.own.shiftKey = shiftKeyArg.getOrDefault(false);
    state.own.metaKey = metaKeyArg.getOrDefault(false);
    state.own.button = buttonArg.getOrDefault(0);
    try setRelatedTarget(instance, relatedTargetArg.getOrDefault(null));
}

/// Operation: getModifierState
pub fn call_getModifierState(instance: *runtime.Instance, keyArg: runtime.DOMString) anyerror!bool {
    _ = instance;
    _ = keyArg;
    return error.NotImplemented;
}
