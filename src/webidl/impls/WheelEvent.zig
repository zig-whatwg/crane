//! Implementation for WheelEvent interface
//!
//! Spec: https://w3c.github.io/uievents/#interface-wheelevent
//! WheelEvent inherits from MouseEvent which inherits from UIEvent which inherits from Event

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const event_construction = @import("dom").event_construction;
const WheelEvent = interfaces.WheelEvent;

pub const State = WheelEvent.State;

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
    // MouseEvent's teardown (the related target it keeps), then Event's.
    interfaces.MouseEvent.deinit(instance);
}

/// Constructor implementation
/// Spec: https://w3c.github.io/uievents/#dom-wheelevent-wheelevent
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.WheelEventInit)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &WheelEvent.vtable, ctx);
    errdefer deinit(instance);

    // Its state: the UIEvent, MouseEvent and own attributes are set below
    const state = instance.getState(State);

    // Build default dictionary chain
    // WheelEventInit extends MouseEventInit extends EventModifierInit extends UIEventInit extends EventInit
    const default_event_init = dictionaries.EventInit{};
    const default_ui_init = dictionaries.UIEventInit{ .base = default_event_init };
    const default_modifier_init = dictionaries.EventModifierInit{ .base = default_ui_init };
    const default_mouse_init = dictionaries.MouseEventInit{ .base = default_modifier_init };
    const default_wheel_init = dictionaries.WheelEventInit{ .base = default_mouse_init };

    const event_init = if (eventInitDict.was_passed) eventInitDict.value else default_wheel_init;

    // Access nested base fields for inherited dictionary properties
    const mouse_init = event_init.base;
    const modifier_init = mouse_init.base;
    const ui_init = modifier_init.base;
    const base_init = ui_init.base;

    // DOM "inner event creation steps" and the constructor's step 2 - Event's
    // part: its internal state, the initialized flag, the timeStamp,
    // EventInit's members and the type - through Event's own steps
    // (dom.event_construction), never its state's type.
    try event_construction.innerEventCreationSteps(instance, @"type", event_construction.eventInitFrom(base_init));

    // Initialize UIEvent attributes (in state.base.base.own)
    state.base.base.own.view = ui_init.view;
    state.base.base.own.detail = ui_init.detail orelse 0;

    // Initialize MouseEvent attributes (in state.base.own)
    const screenX_f = mouse_init.screenX orelse 0.0;
    const screenY_f = mouse_init.screenY orelse 0.0;
    const clientX_f = mouse_init.clientX orelse 0.0;
    const clientY_f = mouse_init.clientY orelse 0.0;

    state.base.own.screenX = @intFromFloat(screenX_f);
    state.base.own.screenY = @intFromFloat(screenY_f);
    state.base.own.clientX = @intFromFloat(clientX_f);
    state.base.own.clientY = @intFromFloat(clientY_f);
    state.base.own.ctrlKey = modifier_init.ctrlKey orelse false;
    state.base.own.shiftKey = modifier_init.shiftKey orelse false;
    state.base.own.altKey = modifier_init.altKey orelse false;
    state.base.own.metaKey = modifier_init.metaKey orelse false;
    state.base.own.button = mouse_init.button orelse 0;
    state.base.own.buttons = mouse_init.buttons orelse 0;
    // MouseEvent keeps it (dom.event_construction): an edge from this event.
    try event_construction.setMouseRelatedTarget(instance, mouse_init.relatedTarget orelse null);
    state.base.own.movementX = mouse_init.movementX orelse 0.0;
    state.base.own.movementY = mouse_init.movementY orelse 0.0;
    state.base.own.pageX = clientX_f;
    state.base.own.pageY = clientY_f;
    state.base.own.x = clientX_f;
    state.base.own.y = clientY_f;
    state.base.own.offsetX = clientX_f;
    state.base.own.offsetY = clientY_f;
    state.base.own.layerX = @intFromFloat(clientX_f);
    state.base.own.layerY = @intFromFloat(clientY_f);

    // Initialize WheelEvent-specific attributes (in state.own)
    state.own.deltaX = event_init.deltaX orelse 0.0;
    state.own.deltaY = event_init.deltaY orelse 0.0;
    state.own.deltaZ = event_init.deltaZ orelse 0.0;
    state.own.deltaMode = event_init.deltaMode orelse 0;

    return instance;
}

/// Getter for deltaX
pub fn get_deltaX(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.deltaX;
}

/// Getter for deltaY
pub fn get_deltaY(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.deltaY;
}

/// Getter for deltaZ
pub fn get_deltaZ(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.deltaZ;
}

/// Getter for deltaMode
pub fn get_deltaMode(instance: *runtime.Instance) anyerror!u32 {
    const state = instance.getState(State);
    return state.own.deltaMode;
}
