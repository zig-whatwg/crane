//! Generated from: uievents.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WheelEventImpl = @import("../impls/WheelEvent.zig");
const MouseEvent = @import("MouseEvent.zig");

pub const WheelEvent = struct {
    pub const Meta = struct {
        pub const name = "WheelEvent";
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
            deltaX: f64 = undefined,
            deltaY: f64 = undefined,
            deltaZ: f64 = undefined,
            deltaMode: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned long DOM_DELTA_PIXEL = 0;
    pub fn get_DOM_DELTA_PIXEL() u32 {
        return 0;
    }

    /// WebIDL constant: const unsigned long DOM_DELTA_LINE = 1;
    pub fn get_DOM_DELTA_LINE() u32 {
        return 1;
    }

    /// WebIDL constant: const unsigned long DOM_DELTA_PAGE = 2;
    pub fn get_DOM_DELTA_PAGE() u32 {
        return 2;
    }

    pub const vtable = runtime.buildVTable(WheelEvent, .{
        .deinit_fn = &deinit_wrapper,

        .get_AT_TARGET = &MouseEvent.get_AT_TARGET,
        .get_BUBBLING_PHASE = &MouseEvent.get_BUBBLING_PHASE,
        .get_CAPTURING_PHASE = &MouseEvent.get_CAPTURING_PHASE,
        .get_DOM_DELTA_LINE = &get_DOM_DELTA_LINE,
        .get_DOM_DELTA_PAGE = &get_DOM_DELTA_PAGE,
        .get_DOM_DELTA_PIXEL = &get_DOM_DELTA_PIXEL,
        .get_NONE = &MouseEvent.get_NONE,
        .get_altKey = &get_altKey,
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
        .get_deltaMode = &get_deltaMode,
        .get_deltaX = &get_deltaX,
        .get_deltaY = &get_deltaY,
        .get_deltaZ = &get_deltaZ,
        .get_detail = &get_detail,
        .get_eventPhase = &get_eventPhase,
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
        .get_relatedTarget = &get_relatedTarget,
        .get_returnValue = &get_returnValue,
        .get_screenX = &get_screenX,
        .get_screenX = &get_screenX,
        .get_screenY = &get_screenY,
        .get_screenY = &get_screenY,
        .get_shiftKey = &get_shiftKey,
        .get_sourceCapabilities = &get_sourceCapabilities,
        .get_srcElement = &get_srcElement,
        .get_target = &get_target,
        .get_timeStamp = &get_timeStamp,
        .get_type = &get_type,
        .get_view = &get_view,
        .get_which = &get_which,
        .get_x = &get_x,
        .get_y = &get_y,

        .set_cancelBubble = &set_cancelBubble,
        .set_returnValue = &set_returnValue,

        .call_composedPath = &call_composedPath,
        .call_getModifierState = &call_getModifierState,
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
        WheelEventImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WheelEventImpl.deinit(state);
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
        try WheelEventImpl.constructor(state, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return WheelEventImpl.get_type(state);
    }

    pub fn get_target(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WheelEventImpl.get_target(state);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WheelEventImpl.get_srcElement(state);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WheelEventImpl.get_currentTarget(state);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return WheelEventImpl.get_eventPhase(state);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WheelEventImpl.get_cancelBubble(state);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        WheelEventImpl.set_cancelBubble(state, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WheelEventImpl.get_bubbles(state);
    }

    pub fn get_cancelable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WheelEventImpl.get_cancelable(state);
    }

    pub fn get_returnValue(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WheelEventImpl.get_returnValue(state);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        WheelEventImpl.set_returnValue(state, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WheelEventImpl.get_defaultPrevented(state);
    }

    pub fn get_composed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WheelEventImpl.get_composed(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WheelEventImpl.get_isTrusted(state);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WheelEventImpl.get_timeStamp(state);
    }

    pub fn get_view(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WheelEventImpl.get_view(state);
    }

    pub fn get_detail(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return WheelEventImpl.get_detail(state);
    }

    pub fn get_which(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return WheelEventImpl.get_which(state);
    }

    pub fn get_sourceCapabilities(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WheelEventImpl.get_sourceCapabilities(state);
    }

    pub fn get_screenX(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return WheelEventImpl.get_screenX(state);
    }

    pub fn get_screenY(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return WheelEventImpl.get_screenY(state);
    }

    pub fn get_clientX(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return WheelEventImpl.get_clientX(state);
    }

    pub fn get_clientY(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return WheelEventImpl.get_clientY(state);
    }

    pub fn get_layerX(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return WheelEventImpl.get_layerX(state);
    }

    pub fn get_layerY(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return WheelEventImpl.get_layerY(state);
    }

    pub fn get_ctrlKey(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WheelEventImpl.get_ctrlKey(state);
    }

    pub fn get_shiftKey(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WheelEventImpl.get_shiftKey(state);
    }

    pub fn get_altKey(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WheelEventImpl.get_altKey(state);
    }

    pub fn get_metaKey(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WheelEventImpl.get_metaKey(state);
    }

    pub fn get_button(instance: *runtime.Instance) i16 {
        const state = instance.getState(State);
        return WheelEventImpl.get_button(state);
    }

    pub fn get_buttons(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return WheelEventImpl.get_buttons(state);
    }

    pub fn get_relatedTarget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WheelEventImpl.get_relatedTarget(state);
    }

    pub fn get_movementX(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WheelEventImpl.get_movementX(state);
    }

    pub fn get_movementY(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WheelEventImpl.get_movementY(state);
    }

    pub fn get_screenX(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WheelEventImpl.get_screenX(state);
    }

    pub fn get_screenY(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WheelEventImpl.get_screenY(state);
    }

    pub fn get_pageX(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WheelEventImpl.get_pageX(state);
    }

    pub fn get_pageY(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WheelEventImpl.get_pageY(state);
    }

    pub fn get_clientX(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WheelEventImpl.get_clientX(state);
    }

    pub fn get_clientY(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WheelEventImpl.get_clientY(state);
    }

    pub fn get_x(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WheelEventImpl.get_x(state);
    }

    pub fn get_y(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WheelEventImpl.get_y(state);
    }

    pub fn get_offsetX(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WheelEventImpl.get_offsetX(state);
    }

    pub fn get_offsetY(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WheelEventImpl.get_offsetY(state);
    }

    pub fn get_deltaX(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WheelEventImpl.get_deltaX(state);
    }

    pub fn get_deltaY(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WheelEventImpl.get_deltaY(state);
    }

    pub fn get_deltaZ(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WheelEventImpl.get_deltaZ(state);
    }

    pub fn get_deltaMode(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return WheelEventImpl.get_deltaMode(state);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WheelEventImpl.call_stopImmediatePropagation(state);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: runtime.DOMString, bubbles: bool, cancelable: bool) anyopaque {
        const state = instance.getState(State);
        
        return WheelEventImpl.call_initEvent(state, type_, bubbles, cancelable);
    }

    pub fn call_initMouseEvent(instance: *runtime.Instance, typeArg: runtime.DOMString, bubblesArg: bool, cancelableArg: bool, viewArg: anyopaque, detailArg: i32, screenXArg: i32, screenYArg: i32, clientXArg: i32, clientYArg: i32, ctrlKeyArg: bool, altKeyArg: bool, shiftKeyArg: bool, metaKeyArg: bool, buttonArg: i16, relatedTargetArg: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WheelEventImpl.call_initMouseEvent(state, typeArg, bubblesArg, cancelableArg, viewArg, detailArg, screenXArg, screenYArg, clientXArg, clientYArg, ctrlKeyArg, altKeyArg, shiftKeyArg, metaKeyArg, buttonArg, relatedTargetArg);
    }

    pub fn call_getModifierState(instance: *runtime.Instance, keyArg: runtime.DOMString) bool {
        const state = instance.getState(State);
        
        return WheelEventImpl.call_getModifierState(state, keyArg);
    }

    pub fn call_initUIEvent(instance: *runtime.Instance, typeArg: runtime.DOMString, bubblesArg: bool, cancelableArg: bool, viewArg: anyopaque, detailArg: i32) anyopaque {
        const state = instance.getState(State);
        
        return WheelEventImpl.call_initUIEvent(state, typeArg, bubblesArg, cancelableArg, viewArg, detailArg);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WheelEventImpl.call_composedPath(state);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WheelEventImpl.call_stopPropagation(state);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WheelEventImpl.call_preventDefault(state);
    }

};
