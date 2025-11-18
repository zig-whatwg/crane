//! Generated from: pointerevents.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PointerEventImpl = @import("../impls/PointerEvent.zig");
const MouseEvent = @import("MouseEvent.zig");

pub const PointerEvent = struct {
    pub const Meta = struct {
        pub const name = "PointerEvent";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *MouseEvent;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Properties that cannot be shadowed or deleted (configurable: false)
        pub const legacy_unforgeable_properties = .{
            "isTrusted",
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            pointerId: i32 = undefined,
            width: f64 = undefined,
            height: f64 = undefined,
            pressure: f32 = undefined,
            tangentialPressure: f32 = undefined,
            tiltX: i32 = undefined,
            tiltY: i32 = undefined,
            twist: i32 = undefined,
            altitudeAngle: f64 = undefined,
            azimuthAngle: f64 = undefined,
            pointerType: runtime.DOMString = undefined,
            isPrimary: bool = undefined,
            persistentDeviceId: i32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PointerEvent, .{
        .deinit_fn = &deinit_wrapper,

        .get_AT_TARGET = &MouseEvent.get_AT_TARGET,
        .get_BUBBLING_PHASE = &MouseEvent.get_BUBBLING_PHASE,
        .get_CAPTURING_PHASE = &MouseEvent.get_CAPTURING_PHASE,
        .get_NONE = &MouseEvent.get_NONE,
        .get_altKey = &get_altKey,
        .get_altitudeAngle = &get_altitudeAngle,
        .get_azimuthAngle = &get_azimuthAngle,
        .get_bubbles = &get_bubbles,
        .get_button = &get_button,
        .get_buttons = &get_buttons,
        .get_cancelBubble = &get_cancelBubble,
        .get_cancelable = &get_cancelable,
        .get_clientX = &get_clientX,
        .get_clientX = &get_clientX,
        .get_clientY = &get_clientY,
        .get_clientY = &get_clientY,
        .get_composed = &get_composed,
        .get_ctrlKey = &get_ctrlKey,
        .get_currentTarget = &get_currentTarget,
        .get_defaultPrevented = &get_defaultPrevented,
        .get_detail = &get_detail,
        .get_eventPhase = &get_eventPhase,
        .get_height = &get_height,
        .get_isPrimary = &get_isPrimary,
        .get_isTrusted = &get_isTrusted,
        .get_layerX = &get_layerX,
        .get_layerY = &get_layerY,
        .get_metaKey = &get_metaKey,
        .get_movementX = &get_movementX,
        .get_movementY = &get_movementY,
        .get_offsetX = &get_offsetX,
        .get_offsetY = &get_offsetY,
        .get_pageX = &get_pageX,
        .get_pageY = &get_pageY,
        .get_persistentDeviceId = &get_persistentDeviceId,
        .get_pointerId = &get_pointerId,
        .get_pointerType = &get_pointerType,
        .get_pressure = &get_pressure,
        .get_relatedTarget = &get_relatedTarget,
        .get_returnValue = &get_returnValue,
        .get_screenX = &get_screenX,
        .get_screenX = &get_screenX,
        .get_screenY = &get_screenY,
        .get_screenY = &get_screenY,
        .get_shiftKey = &get_shiftKey,
        .get_sourceCapabilities = &get_sourceCapabilities,
        .get_srcElement = &get_srcElement,
        .get_tangentialPressure = &get_tangentialPressure,
        .get_target = &get_target,
        .get_tiltX = &get_tiltX,
        .get_tiltY = &get_tiltY,
        .get_timeStamp = &get_timeStamp,
        .get_twist = &get_twist,
        .get_type = &get_type,
        .get_view = &get_view,
        .get_which = &get_which,
        .get_width = &get_width,
        .get_x = &get_x,
        .get_y = &get_y,

        .set_cancelBubble = &set_cancelBubble,
        .set_returnValue = &set_returnValue,

        .call_composedPath = &call_composedPath,
        .call_getCoalescedEvents = &call_getCoalescedEvents,
        .call_getModifierState = &call_getModifierState,
        .call_getPredictedEvents = &call_getPredictedEvents,
        .call_initEvent = &call_initEvent,
        .call_initMouseEvent = &call_initMouseEvent,
        .call_initUIEvent = &call_initUIEvent,
        .call_preventDefault = &call_preventDefault,
        .call_stopImmediatePropagation = &call_stopImmediatePropagation,
        .call_stopPropagation = &call_stopPropagation,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        PointerEventImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PointerEventImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, type_: runtime.DOMString, eventInitDict: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try PointerEventImpl.constructor(state, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PointerEventImpl.get_type(state);
    }

    pub fn get_target(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PointerEventImpl.get_target(state);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PointerEventImpl.get_srcElement(state);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PointerEventImpl.get_currentTarget(state);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return PointerEventImpl.get_eventPhase(state);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PointerEventImpl.get_cancelBubble(state);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        PointerEventImpl.set_cancelBubble(state, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PointerEventImpl.get_bubbles(state);
    }

    pub fn get_cancelable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PointerEventImpl.get_cancelable(state);
    }

    pub fn get_returnValue(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PointerEventImpl.get_returnValue(state);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        PointerEventImpl.set_returnValue(state, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PointerEventImpl.get_defaultPrevented(state);
    }

    pub fn get_composed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PointerEventImpl.get_composed(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PointerEventImpl.get_isTrusted(state);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PointerEventImpl.get_timeStamp(state);
    }

    pub fn get_view(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PointerEventImpl.get_view(state);
    }

    pub fn get_detail(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return PointerEventImpl.get_detail(state);
    }

    pub fn get_which(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return PointerEventImpl.get_which(state);
    }

    pub fn get_sourceCapabilities(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PointerEventImpl.get_sourceCapabilities(state);
    }

    pub fn get_screenX(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return PointerEventImpl.get_screenX(state);
    }

    pub fn get_screenY(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return PointerEventImpl.get_screenY(state);
    }

    pub fn get_clientX(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return PointerEventImpl.get_clientX(state);
    }

    pub fn get_clientY(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return PointerEventImpl.get_clientY(state);
    }

    pub fn get_layerX(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return PointerEventImpl.get_layerX(state);
    }

    pub fn get_layerY(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return PointerEventImpl.get_layerY(state);
    }

    pub fn get_ctrlKey(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PointerEventImpl.get_ctrlKey(state);
    }

    pub fn get_shiftKey(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PointerEventImpl.get_shiftKey(state);
    }

    pub fn get_altKey(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PointerEventImpl.get_altKey(state);
    }

    pub fn get_metaKey(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PointerEventImpl.get_metaKey(state);
    }

    pub fn get_button(instance: *runtime.Instance) i16 {
        const state = instance.getState(State);
        return PointerEventImpl.get_button(state);
    }

    pub fn get_buttons(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return PointerEventImpl.get_buttons(state);
    }

    pub fn get_relatedTarget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PointerEventImpl.get_relatedTarget(state);
    }

    pub fn get_movementX(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PointerEventImpl.get_movementX(state);
    }

    pub fn get_movementY(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PointerEventImpl.get_movementY(state);
    }

    pub fn get_screenX(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PointerEventImpl.get_screenX(state);
    }

    pub fn get_screenY(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PointerEventImpl.get_screenY(state);
    }

    pub fn get_pageX(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PointerEventImpl.get_pageX(state);
    }

    pub fn get_pageY(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PointerEventImpl.get_pageY(state);
    }

    pub fn get_clientX(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PointerEventImpl.get_clientX(state);
    }

    pub fn get_clientY(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PointerEventImpl.get_clientY(state);
    }

    pub fn get_x(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PointerEventImpl.get_x(state);
    }

    pub fn get_y(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PointerEventImpl.get_y(state);
    }

    pub fn get_offsetX(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PointerEventImpl.get_offsetX(state);
    }

    pub fn get_offsetY(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PointerEventImpl.get_offsetY(state);
    }

    pub fn get_pointerId(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return PointerEventImpl.get_pointerId(state);
    }

    pub fn get_width(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PointerEventImpl.get_width(state);
    }

    pub fn get_height(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PointerEventImpl.get_height(state);
    }

    pub fn get_pressure(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return PointerEventImpl.get_pressure(state);
    }

    pub fn get_tangentialPressure(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return PointerEventImpl.get_tangentialPressure(state);
    }

    pub fn get_tiltX(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return PointerEventImpl.get_tiltX(state);
    }

    pub fn get_tiltY(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return PointerEventImpl.get_tiltY(state);
    }

    pub fn get_twist(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return PointerEventImpl.get_twist(state);
    }

    pub fn get_altitudeAngle(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PointerEventImpl.get_altitudeAngle(state);
    }

    pub fn get_azimuthAngle(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PointerEventImpl.get_azimuthAngle(state);
    }

    pub fn get_pointerType(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PointerEventImpl.get_pointerType(state);
    }

    pub fn get_isPrimary(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PointerEventImpl.get_isPrimary(state);
    }

    pub fn get_persistentDeviceId(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return PointerEventImpl.get_persistentDeviceId(state);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PointerEventImpl.call_stopImmediatePropagation(state);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: runtime.DOMString, bubbles: bool, cancelable: bool) anyopaque {
        const state = instance.getState(State);
        
        return PointerEventImpl.call_initEvent(state, type_, bubbles, cancelable);
    }

    pub fn call_initMouseEvent(instance: *runtime.Instance, typeArg: runtime.DOMString, bubblesArg: bool, cancelableArg: bool, viewArg: anyopaque, detailArg: i32, screenXArg: i32, screenYArg: i32, clientXArg: i32, clientYArg: i32, ctrlKeyArg: bool, altKeyArg: bool, shiftKeyArg: bool, metaKeyArg: bool, buttonArg: i16, relatedTargetArg: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PointerEventImpl.call_initMouseEvent(state, typeArg, bubblesArg, cancelableArg, viewArg, detailArg, screenXArg, screenYArg, clientXArg, clientYArg, ctrlKeyArg, altKeyArg, shiftKeyArg, metaKeyArg, buttonArg, relatedTargetArg);
    }

    pub fn call_getModifierState(instance: *runtime.Instance, keyArg: runtime.DOMString) bool {
        const state = instance.getState(State);
        
        return PointerEventImpl.call_getModifierState(state, keyArg);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_getCoalescedEvents(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PointerEventImpl.call_getCoalescedEvents(state);
    }

    pub fn call_getPredictedEvents(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PointerEventImpl.call_getPredictedEvents(state);
    }

    pub fn call_initUIEvent(instance: *runtime.Instance, typeArg: runtime.DOMString, bubblesArg: bool, cancelableArg: bool, viewArg: anyopaque, detailArg: i32) anyopaque {
        const state = instance.getState(State);
        
        return PointerEventImpl.call_initUIEvent(state, typeArg, bubblesArg, cancelableArg, viewArg, detailArg);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PointerEventImpl.call_composedPath(state);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PointerEventImpl.call_stopPropagation(state);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PointerEventImpl.call_preventDefault(state);
    }

};
