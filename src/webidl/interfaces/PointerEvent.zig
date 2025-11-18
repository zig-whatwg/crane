//! Generated from: pointerevents.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PointerEventImpl = @import("impls").PointerEvent;
const MouseEvent = @import("interfaces").MouseEvent;
const PointerEventInit = @import("dictionaries").PointerEventInit;

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
        
        // Initialize the instance (Impl receives full instance)
        PointerEventImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PointerEventImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, type_: DOMString, eventInitDict: PointerEventInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try PointerEventImpl.constructor(instance, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try PointerEventImpl.get_type(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!anyopaque {
        return try PointerEventImpl.get_target(instance);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try PointerEventImpl.get_srcElement(instance);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyerror!anyopaque {
        return try PointerEventImpl.get_currentTarget(instance);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) anyerror!u16 {
        return try PointerEventImpl.get_eventPhase(instance);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) anyerror!bool {
        return try PointerEventImpl.get_cancelBubble(instance);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) anyerror!void {
        try PointerEventImpl.set_cancelBubble(instance, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) anyerror!bool {
        return try PointerEventImpl.get_bubbles(instance);
    }

    pub fn get_cancelable(instance: *runtime.Instance) anyerror!bool {
        return try PointerEventImpl.get_cancelable(instance);
    }

    pub fn get_returnValue(instance: *runtime.Instance) anyerror!bool {
        return try PointerEventImpl.get_returnValue(instance);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) anyerror!void {
        try PointerEventImpl.set_returnValue(instance, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) anyerror!bool {
        return try PointerEventImpl.get_defaultPrevented(instance);
    }

    pub fn get_composed(instance: *runtime.Instance) anyerror!bool {
        return try PointerEventImpl.get_composed(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) anyerror!bool {
        return try PointerEventImpl.get_isTrusted(instance);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PointerEventImpl.get_timeStamp(instance);
    }

    pub fn get_view(instance: *runtime.Instance) anyerror!anyopaque {
        return try PointerEventImpl.get_view(instance);
    }

    pub fn get_detail(instance: *runtime.Instance) anyerror!i32 {
        return try PointerEventImpl.get_detail(instance);
    }

    pub fn get_which(instance: *runtime.Instance) anyerror!u32 {
        return try PointerEventImpl.get_which(instance);
    }

    pub fn get_sourceCapabilities(instance: *runtime.Instance) anyerror!anyopaque {
        return try PointerEventImpl.get_sourceCapabilities(instance);
    }

    pub fn get_screenX(instance: *runtime.Instance) anyerror!i32 {
        return try PointerEventImpl.get_screenX(instance);
    }

    pub fn get_screenY(instance: *runtime.Instance) anyerror!i32 {
        return try PointerEventImpl.get_screenY(instance);
    }

    pub fn get_clientX(instance: *runtime.Instance) anyerror!i32 {
        return try PointerEventImpl.get_clientX(instance);
    }

    pub fn get_clientY(instance: *runtime.Instance) anyerror!i32 {
        return try PointerEventImpl.get_clientY(instance);
    }

    pub fn get_layerX(instance: *runtime.Instance) anyerror!i32 {
        return try PointerEventImpl.get_layerX(instance);
    }

    pub fn get_layerY(instance: *runtime.Instance) anyerror!i32 {
        return try PointerEventImpl.get_layerY(instance);
    }

    pub fn get_ctrlKey(instance: *runtime.Instance) anyerror!bool {
        return try PointerEventImpl.get_ctrlKey(instance);
    }

    pub fn get_shiftKey(instance: *runtime.Instance) anyerror!bool {
        return try PointerEventImpl.get_shiftKey(instance);
    }

    pub fn get_altKey(instance: *runtime.Instance) anyerror!bool {
        return try PointerEventImpl.get_altKey(instance);
    }

    pub fn get_metaKey(instance: *runtime.Instance) anyerror!bool {
        return try PointerEventImpl.get_metaKey(instance);
    }

    pub fn get_button(instance: *runtime.Instance) anyerror!i16 {
        return try PointerEventImpl.get_button(instance);
    }

    pub fn get_buttons(instance: *runtime.Instance) anyerror!u16 {
        return try PointerEventImpl.get_buttons(instance);
    }

    pub fn get_relatedTarget(instance: *runtime.Instance) anyerror!anyopaque {
        return try PointerEventImpl.get_relatedTarget(instance);
    }

    pub fn get_movementX(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_movementX(instance);
    }

    pub fn get_movementY(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_movementY(instance);
    }

    pub fn get_screenX(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_screenX(instance);
    }

    pub fn get_screenY(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_screenY(instance);
    }

    pub fn get_pageX(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_pageX(instance);
    }

    pub fn get_pageY(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_pageY(instance);
    }

    pub fn get_clientX(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_clientX(instance);
    }

    pub fn get_clientY(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_clientY(instance);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_y(instance);
    }

    pub fn get_offsetX(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_offsetX(instance);
    }

    pub fn get_offsetY(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_offsetY(instance);
    }

    pub fn get_pointerId(instance: *runtime.Instance) anyerror!i32 {
        return try PointerEventImpl.get_pointerId(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_height(instance);
    }

    pub fn get_pressure(instance: *runtime.Instance) anyerror!f32 {
        return try PointerEventImpl.get_pressure(instance);
    }

    pub fn get_tangentialPressure(instance: *runtime.Instance) anyerror!f32 {
        return try PointerEventImpl.get_tangentialPressure(instance);
    }

    pub fn get_tiltX(instance: *runtime.Instance) anyerror!i32 {
        return try PointerEventImpl.get_tiltX(instance);
    }

    pub fn get_tiltY(instance: *runtime.Instance) anyerror!i32 {
        return try PointerEventImpl.get_tiltY(instance);
    }

    pub fn get_twist(instance: *runtime.Instance) anyerror!i32 {
        return try PointerEventImpl.get_twist(instance);
    }

    pub fn get_altitudeAngle(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_altitudeAngle(instance);
    }

    pub fn get_azimuthAngle(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_azimuthAngle(instance);
    }

    pub fn get_pointerType(instance: *runtime.Instance) anyerror!DOMString {
        return try PointerEventImpl.get_pointerType(instance);
    }

    pub fn get_isPrimary(instance: *runtime.Instance) anyerror!bool {
        return try PointerEventImpl.get_isPrimary(instance);
    }

    pub fn get_persistentDeviceId(instance: *runtime.Instance) anyerror!i32 {
        return try PointerEventImpl.get_persistentDeviceId(instance);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyerror!void {
        return try PointerEventImpl.call_stopImmediatePropagation(instance);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: DOMString, bubbles: bool, cancelable: bool) anyerror!void {
        
        return try PointerEventImpl.call_initEvent(instance, type_, bubbles, cancelable);
    }

    pub fn call_initMouseEvent(instance: *runtime.Instance, typeArg: DOMString, bubblesArg: bool, cancelableArg: bool, viewArg: anyopaque, detailArg: i32, screenXArg: i32, screenYArg: i32, clientXArg: i32, clientYArg: i32, ctrlKeyArg: bool, altKeyArg: bool, shiftKeyArg: bool, metaKeyArg: bool, buttonArg: i16, relatedTargetArg: anyopaque) anyerror!void {
        
        return try PointerEventImpl.call_initMouseEvent(instance, typeArg, bubblesArg, cancelableArg, viewArg, detailArg, screenXArg, screenYArg, clientXArg, clientYArg, ctrlKeyArg, altKeyArg, shiftKeyArg, metaKeyArg, buttonArg, relatedTargetArg);
    }

    pub fn call_getModifierState(instance: *runtime.Instance, keyArg: DOMString) anyerror!bool {
        
        return try PointerEventImpl.call_getModifierState(instance, keyArg);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_getCoalescedEvents(instance: *runtime.Instance) anyerror!anyopaque {
        return try PointerEventImpl.call_getCoalescedEvents(instance);
    }

    pub fn call_getPredictedEvents(instance: *runtime.Instance) anyerror!anyopaque {
        return try PointerEventImpl.call_getPredictedEvents(instance);
    }

    pub fn call_initUIEvent(instance: *runtime.Instance, typeArg: DOMString, bubblesArg: bool, cancelableArg: bool, viewArg: anyopaque, detailArg: i32) anyerror!void {
        
        return try PointerEventImpl.call_initUIEvent(instance, typeArg, bubblesArg, cancelableArg, viewArg, detailArg);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyerror!anyopaque {
        return try PointerEventImpl.call_composedPath(instance);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyerror!void {
        return try PointerEventImpl.call_stopPropagation(instance);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyerror!void {
        return try PointerEventImpl.call_preventDefault(instance);
    }

};
