//! Implementation for PointerEvent interface
//!
//! Spec: https://w3c.github.io/pointerevents/#pointerevent-interface
//! PointerEvent inherits from MouseEvent which inherits from UIEvent which inherits from Event

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const PointerEvent = interfaces.PointerEvent;
const EventImpl = @import("Event.zig");

pub const State = PointerEvent.State;

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
/// Spec: https://w3c.github.io/pointerevents/#dom-pointerevent-pointerevent
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.PointerEventInit)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &PointerEvent.vtable, ctx);
    errdefer deinit(instance);

    // Get state to initialize inherited Event fields
    const state = instance.getState(State);

    // Create internal state for Event (required for flags like dispatch_flag, initialized_flag)
    // PointerEvent -> MouseEvent -> UIEvent -> Event
    // So state.base.base.base.own._internal is Event's internal state
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(EventImpl.InternalState);
    internal.* = EventImpl.InternalState.init(ctx.allocator);
    state.base.base.base.own._internal = internal;

    // Set the initialized flag
    internal.initialized_flag = true;

    // Build default dictionary chain
    // PointerEventInit extends MouseEventInit extends EventModifierInit extends UIEventInit extends EventInit
    const default_event_init = dictionaries.EventInit{};
    const default_ui_init = dictionaries.UIEventInit{ .base = default_event_init };
    const default_modifier_init = dictionaries.EventModifierInit{ .base = default_ui_init };
    const default_mouse_init = dictionaries.MouseEventInit{ .base = default_modifier_init };
    const default_pointer_init = dictionaries.PointerEventInit{ .base = default_mouse_init };

    const event_init = if (eventInitDict.was_passed) eventInitDict.value else default_pointer_init;

    // Access nested base fields for inherited dictionary properties
    const mouse_init = event_init.base;
    const modifier_init = mouse_init.base;
    const ui_init = modifier_init.base;
    const base_init = ui_init.base;

    const bubbles = base_init.bubbles orelse false;
    const cancelable = base_init.cancelable orelse false;
    const composed = base_init.composed orelse false;

    // Store event type - clone the string to ensure we own it
    // PointerEvent.base = MouseEvent.State, MouseEvent.base = UIEvent.State, UIEvent.base = Event.State
    state.base.base.base.own.type = try @"type".clone(ctx.allocator);

    // Initialize Event attributes (in state.base.base.base.own)
    state.base.base.base.own.bubbles = bubbles;
    state.base.base.base.own.cancelable = cancelable;
    state.base.base.base.own.composed = composed;
    state.base.base.base.own.target = null;
    state.base.base.base.own.srcElement = null;
    state.base.base.base.own.currentTarget = null;
    state.base.base.base.own.eventPhase = interfaces.Event.get_NONE();
    state.base.base.base.own.cancelBubble = false;
    state.base.base.base.own.returnValue = true;
    state.base.base.base.own.defaultPrevented = false;
    state.base.base.base.own.isTrusted = false;
    state.base.base.base.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(std.time.milliTimestamp()));

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
    state.base.own.relatedTarget = mouse_init.relatedTarget orelse null;
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

    // Initialize PointerEvent-specific attributes (in state.own)
    state.own.pointerId = event_init.pointerId orelse 0;
    state.own.width = event_init.width orelse 1.0;
    state.own.height = event_init.height orelse 1.0;
    state.own.pressure = event_init.pressure orelse 0.0;
    state.own.tangentialPressure = event_init.tangentialPressure orelse 0.0;
    state.own.tiltX = event_init.tiltX orelse 0;
    state.own.tiltY = event_init.tiltY orelse 0;
    state.own.twist = event_init.twist orelse 0;
    state.own.altitudeAngle = event_init.altitudeAngle orelse (std.math.pi / 2.0);
    state.own.azimuthAngle = event_init.azimuthAngle orelse 0.0;
    state.own.pointerType = if (event_init.pointerType) |pt| pt else runtime.DOMString.initInterned("");
    state.own.isPrimary = event_init.isPrimary orelse false;
    state.own.persistentDeviceId = event_init.persistentDeviceId orelse 0;

    return instance;
}

/// Getter for pointerId
pub fn get_pointerId(instance: *runtime.Instance) anyerror!i32 {
    const state = instance.getState(State);
    return state.own.pointerId;
}

/// Getter for width
pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.width;
}

/// Getter for height
pub fn get_height(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.height;
}

/// Getter for pressure
pub fn get_pressure(instance: *runtime.Instance) anyerror!f32 {
    const state = instance.getState(State);
    return state.own.pressure;
}

/// Getter for tangentialPressure
pub fn get_tangentialPressure(instance: *runtime.Instance) anyerror!f32 {
    const state = instance.getState(State);
    return state.own.tangentialPressure;
}

/// Getter for tiltX
pub fn get_tiltX(instance: *runtime.Instance) anyerror!i32 {
    const state = instance.getState(State);
    return state.own.tiltX;
}

/// Getter for tiltY
pub fn get_tiltY(instance: *runtime.Instance) anyerror!i32 {
    const state = instance.getState(State);
    return state.own.tiltY;
}

/// Getter for twist
pub fn get_twist(instance: *runtime.Instance) anyerror!i32 {
    const state = instance.getState(State);
    return state.own.twist;
}

/// Getter for altitudeAngle
pub fn get_altitudeAngle(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.altitudeAngle;
}

/// Getter for azimuthAngle
pub fn get_azimuthAngle(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.azimuthAngle;
}

/// Getter for pointerType
pub fn get_pointerType(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    return state.own.pointerType;
}

/// Getter for isPrimary
pub fn get_isPrimary(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    return state.own.isPrimary;
}

/// Getter for persistentDeviceId
pub fn get_persistentDeviceId(instance: *runtime.Instance) anyerror!i32 {
    const state = instance.getState(State);
    return state.own.persistentDeviceId;
}

/// Operation: getCoalescedEvents
pub fn call_getCoalescedEvents(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // Return empty array for now
    _ = instance;
    const v8_engine = @import("v8");
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NotImplemented;
    const v8_array = v8_engine.createEmptyArray(isolate);
    return runtime.JSValue.fromHandle(@ptrCast(v8_array));
}

/// Operation: getPredictedEvents
pub fn call_getPredictedEvents(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // Return empty array for now
    _ = instance;
    const v8_engine = @import("v8");
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NotImplemented;
    const v8_array = v8_engine.createEmptyArray(isolate);
    return runtime.JSValue.fromHandle(@ptrCast(v8_array));
}
