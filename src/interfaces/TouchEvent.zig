//! Generated from: touch-events.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TouchEventImpl = @import("../impls/TouchEvent.zig");
const UIEvent = @import("UIEvent.zig");

pub const TouchEvent = struct {
    pub const Meta = struct {
        pub const name = "TouchEvent";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *UIEvent;
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
            touches: TouchList = undefined,
            targetTouches: TouchList = undefined,
            changedTouches: TouchList = undefined,
            altKey: bool = undefined,
            metaKey: bool = undefined,
            ctrlKey: bool = undefined,
            shiftKey: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TouchEvent, .{
        .deinit_fn = &deinit_wrapper,

        .get_AT_TARGET = &UIEvent.get_AT_TARGET,
        .get_BUBBLING_PHASE = &UIEvent.get_BUBBLING_PHASE,
        .get_CAPTURING_PHASE = &UIEvent.get_CAPTURING_PHASE,
        .get_NONE = &UIEvent.get_NONE,
        .get_altKey = &get_altKey,
        .get_bubbles = &get_bubbles,
        .get_cancelBubble = &get_cancelBubble,
        .get_cancelable = &get_cancelable,
        .get_changedTouches = &get_changedTouches,
        .get_composed = &get_composed,
        .get_ctrlKey = &get_ctrlKey,
        .get_currentTarget = &get_currentTarget,
        .get_defaultPrevented = &get_defaultPrevented,
        .get_detail = &get_detail,
        .get_eventPhase = &get_eventPhase,
        .get_isTrusted = &get_isTrusted,
        .get_metaKey = &get_metaKey,
        .get_returnValue = &get_returnValue,
        .get_shiftKey = &get_shiftKey,
        .get_sourceCapabilities = &get_sourceCapabilities,
        .get_srcElement = &get_srcElement,
        .get_target = &get_target,
        .get_targetTouches = &get_targetTouches,
        .get_timeStamp = &get_timeStamp,
        .get_touches = &get_touches,
        .get_type = &get_type,
        .get_view = &get_view,
        .get_which = &get_which,

        .set_cancelBubble = &set_cancelBubble,
        .set_returnValue = &set_returnValue,

        .call_composedPath = &call_composedPath,
        .call_getModifierState = &call_getModifierState,
        .call_initEvent = &call_initEvent,
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
        TouchEventImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        TouchEventImpl.deinit(state);
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
        try TouchEventImpl.constructor(state, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return TouchEventImpl.get_type(state);
    }

    pub fn get_target(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TouchEventImpl.get_target(state);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TouchEventImpl.get_srcElement(state);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TouchEventImpl.get_currentTarget(state);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return TouchEventImpl.get_eventPhase(state);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return TouchEventImpl.get_cancelBubble(state);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        TouchEventImpl.set_cancelBubble(state, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return TouchEventImpl.get_bubbles(state);
    }

    pub fn get_cancelable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return TouchEventImpl.get_cancelable(state);
    }

    pub fn get_returnValue(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return TouchEventImpl.get_returnValue(state);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        TouchEventImpl.set_returnValue(state, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return TouchEventImpl.get_defaultPrevented(state);
    }

    pub fn get_composed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return TouchEventImpl.get_composed(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return TouchEventImpl.get_isTrusted(state);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TouchEventImpl.get_timeStamp(state);
    }

    pub fn get_view(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TouchEventImpl.get_view(state);
    }

    pub fn get_detail(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return TouchEventImpl.get_detail(state);
    }

    pub fn get_which(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return TouchEventImpl.get_which(state);
    }

    pub fn get_sourceCapabilities(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TouchEventImpl.get_sourceCapabilities(state);
    }

    pub fn get_touches(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TouchEventImpl.get_touches(state);
    }

    pub fn get_targetTouches(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TouchEventImpl.get_targetTouches(state);
    }

    pub fn get_changedTouches(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TouchEventImpl.get_changedTouches(state);
    }

    pub fn get_altKey(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return TouchEventImpl.get_altKey(state);
    }

    pub fn get_metaKey(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return TouchEventImpl.get_metaKey(state);
    }

    pub fn get_ctrlKey(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return TouchEventImpl.get_ctrlKey(state);
    }

    pub fn get_shiftKey(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return TouchEventImpl.get_shiftKey(state);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TouchEventImpl.call_stopImmediatePropagation(state);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: runtime.DOMString, bubbles: bool, cancelable: bool) anyopaque {
        const state = instance.getState(State);
        
        return TouchEventImpl.call_initEvent(state, type_, bubbles, cancelable);
    }

    pub fn call_getModifierState(instance: *runtime.Instance, keyArg: runtime.DOMString) bool {
        const state = instance.getState(State);
        
        return TouchEventImpl.call_getModifierState(state, keyArg);
    }

    pub fn call_initUIEvent(instance: *runtime.Instance, typeArg: runtime.DOMString, bubblesArg: bool, cancelableArg: bool, viewArg: anyopaque, detailArg: i32) anyopaque {
        const state = instance.getState(State);
        
        return TouchEventImpl.call_initUIEvent(state, typeArg, bubblesArg, cancelableArg, viewArg, detailArg);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TouchEventImpl.call_composedPath(state);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TouchEventImpl.call_stopPropagation(state);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TouchEventImpl.call_preventDefault(state);
    }

};
