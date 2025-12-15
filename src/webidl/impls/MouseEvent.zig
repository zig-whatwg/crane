//! Implementation for MouseEvent interface
//!
//! Spec: https://w3c.github.io/uievents/#interface-mouseevent
//! MouseEvent inherits from UIEvent which inherits from Event

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const MouseEvent = interfaces.MouseEvent;
const EventImpl = @import("Event.zig");

pub const State = MouseEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
pub const InternalState = struct {};

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

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
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

    // Get state to initialize inherited Event fields
    const state = instance.getState(State);

    // Create internal state for Event (required for flags like dispatch_flag, initialized_flag)
    // This is stored in the Event's part of the state hierarchy (state.base.base.own._internal)
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(EventImpl.InternalState);
    internal.* = EventImpl.InternalState.init(ctx.allocator);
    // Access the Event's _internal field through the inheritance chain
    // MouseEvent.State.base = UIEvent.State
    // UIEvent.State.base = Event.State
    // Event.State.own._internal = Event's internal state
    state.base.base.own._internal = internal;

    // Set the initialized flag
    internal.initialized_flag = true;

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

    const bubbles = base_init.bubbles orelse false;
    const cancelable = base_init.cancelable orelse false;
    const composed = base_init.composed orelse false;

    // Store event type - clone the string to ensure we own it
    // The type field is in Event.State (state.base.base.own.type)
    state.base.base.own.type = try @"type".clone(ctx.allocator);

    // Initialize Event attributes (in state.base.base.own)
    state.base.base.own.bubbles = bubbles;
    state.base.base.own.cancelable = cancelable;
    state.base.base.own.composed = composed;
    state.base.base.own.target = null;
    state.base.base.own.srcElement = null;
    state.base.base.own.currentTarget = null;
    state.base.base.own.eventPhase = interfaces.Event.get_NONE();
    state.base.base.own.cancelBubble = false;
    state.base.base.own.returnValue = true;
    state.base.base.own.defaultPrevented = false;
    state.base.base.own.isTrusted = false;
    state.base.base.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(std.time.milliTimestamp()));

    // Initialize UIEvent attributes (in state.base.own)
    state.base.own.view = ui_init.view;
    state.base.own.detail = ui_init.detail orelse 0;

    // Initialize MouseEvent attributes (in state.own)
    const screenX_f = event_init.screenX orelse 0.0;
    const screenY_f = event_init.screenY orelse 0.0;
    const clientX_f = event_init.clientX orelse 0.0;
    const clientY_f = event_init.clientY orelse 0.0;

    state.own.screenX = @intFromFloat(screenX_f);
    state.own.screenY = @intFromFloat(screenY_f);
    state.own.clientX = @intFromFloat(clientX_f);
    state.own.clientY = @intFromFloat(clientY_f);
    state.own.ctrlKey = modifier_init.ctrlKey orelse false;
    state.own.shiftKey = modifier_init.shiftKey orelse false;
    state.own.altKey = modifier_init.altKey orelse false;
    state.own.metaKey = modifier_init.metaKey orelse false;
    state.own.button = event_init.button orelse 0;
    state.own.buttons = event_init.buttons orelse 0;
    state.own.relatedTarget = event_init.relatedTarget orelse null;

    // Initialize additional MouseEvent properties from CSSOM View Module
    state.own.movementX = event_init.movementX orelse 0.0;
    state.own.movementY = event_init.movementY orelse 0.0;

    // Computed properties (these might need layout info, default to clientX/Y)
    state.own.pageX = clientX_f;
    state.own.pageY = clientY_f;
    state.own.x = clientX_f;
    state.own.y = clientY_f;
    state.own.offsetX = clientX_f;
    state.own.offsetY = clientY_f;
    state.own.layerX = @intFromFloat(clientX_f);
    state.own.layerY = @intFromFloat(clientY_f);

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

/// Getter for relatedTarget
pub fn get_relatedTarget(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const state = instance.getState(State);
    return state.own.relatedTarget;
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
pub fn call_initMouseEvent(instance: *runtime.Instance, typeArg: runtime.DOMString, bubblesArg: webidl.Opt(bool), cancelableArg: webidl.Opt(bool), viewArg: webidl.Opt(?*runtime.Instance), detailArg: webidl.Opt(i32), screenXArg: webidl.Opt(i32), screenYArg: webidl.Opt(i32), clientXArg: webidl.Opt(i32), clientYArg: webidl.Opt(i32), ctrlKeyArg: webidl.Opt(bool), altKeyArg: webidl.Opt(bool), shiftKeyArg: webidl.Opt(bool), metaKeyArg: webidl.Opt(bool), buttonArg: webidl.Opt(i16), relatedTargetArg: webidl.Opt(?*runtime.Instance)) anyerror!void {
    _ = instance;
    _ = typeArg;
    _ = bubblesArg;
    _ = cancelableArg;
    _ = viewArg;
    _ = detailArg;
    _ = screenXArg;
    _ = screenYArg;
    _ = clientXArg;
    _ = clientYArg;
    _ = ctrlKeyArg;
    _ = altKeyArg;
    _ = shiftKeyArg;
    _ = metaKeyArg;
    _ = buttonArg;
    _ = relatedTargetArg;
    return error.NotImplemented;
}

/// Operation: getModifierState
pub fn call_getModifierState(instance: *runtime.Instance, keyArg: runtime.DOMString) anyerror!bool {
    _ = instance;
    _ = keyArg;
    return error.NotImplemented;
}
