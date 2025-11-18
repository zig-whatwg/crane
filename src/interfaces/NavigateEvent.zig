//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigateEventImpl = @import("../impls/NavigateEvent.zig");
const Event = @import("Event.zig");

pub const NavigateEvent = struct {
    pub const Meta = struct {
        pub const name = "NavigateEvent";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
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
            navigationType: NavigationType = undefined,
            destination: NavigationDestination = undefined,
            canIntercept: bool = undefined,
            userInitiated: bool = undefined,
            hashChange: bool = undefined,
            signal: AbortSignal = undefined,
            formData: ?FormData = null,
            downloadRequest: ?runtime.DOMString = null,
            info: anyopaque = undefined,
            hasUAVisualTransition: bool = undefined,
            sourceElement: ?Element = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigateEvent, .{
        .deinit_fn = &deinit_wrapper,

        .get_AT_TARGET = &Event.get_AT_TARGET,
        .get_BUBBLING_PHASE = &Event.get_BUBBLING_PHASE,
        .get_CAPTURING_PHASE = &Event.get_CAPTURING_PHASE,
        .get_NONE = &Event.get_NONE,
        .get_bubbles = &get_bubbles,
        .get_canIntercept = &get_canIntercept,
        .get_cancelBubble = &get_cancelBubble,
        .get_cancelable = &get_cancelable,
        .get_composed = &get_composed,
        .get_currentTarget = &get_currentTarget,
        .get_defaultPrevented = &get_defaultPrevented,
        .get_destination = &get_destination,
        .get_downloadRequest = &get_downloadRequest,
        .get_eventPhase = &get_eventPhase,
        .get_formData = &get_formData,
        .get_hasUAVisualTransition = &get_hasUAVisualTransition,
        .get_hashChange = &get_hashChange,
        .get_info = &get_info,
        .get_isTrusted = &get_isTrusted,
        .get_navigationType = &get_navigationType,
        .get_returnValue = &get_returnValue,
        .get_signal = &get_signal,
        .get_sourceElement = &get_sourceElement,
        .get_srcElement = &get_srcElement,
        .get_target = &get_target,
        .get_timeStamp = &get_timeStamp,
        .get_type = &get_type,
        .get_userInitiated = &get_userInitiated,

        .set_cancelBubble = &set_cancelBubble,
        .set_returnValue = &set_returnValue,

        .call_composedPath = &call_composedPath,
        .call_initEvent = &call_initEvent,
        .call_intercept = &call_intercept,
        .call_preventDefault = &call_preventDefault,
        .call_scroll = &call_scroll,
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
        NavigateEventImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NavigateEventImpl.deinit(state);
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
        try NavigateEventImpl.constructor(state, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NavigateEventImpl.get_type(state);
    }

    pub fn get_target(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigateEventImpl.get_target(state);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigateEventImpl.get_srcElement(state);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigateEventImpl.get_currentTarget(state);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return NavigateEventImpl.get_eventPhase(state);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigateEventImpl.get_cancelBubble(state);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        NavigateEventImpl.set_cancelBubble(state, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigateEventImpl.get_bubbles(state);
    }

    pub fn get_cancelable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigateEventImpl.get_cancelable(state);
    }

    pub fn get_returnValue(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigateEventImpl.get_returnValue(state);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        NavigateEventImpl.set_returnValue(state, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigateEventImpl.get_defaultPrevented(state);
    }

    pub fn get_composed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigateEventImpl.get_composed(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigateEventImpl.get_isTrusted(state);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigateEventImpl.get_timeStamp(state);
    }

    pub fn get_navigationType(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigateEventImpl.get_navigationType(state);
    }

    pub fn get_destination(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigateEventImpl.get_destination(state);
    }

    pub fn get_canIntercept(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigateEventImpl.get_canIntercept(state);
    }

    pub fn get_userInitiated(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigateEventImpl.get_userInitiated(state);
    }

    pub fn get_hashChange(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigateEventImpl.get_hashChange(state);
    }

    pub fn get_signal(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigateEventImpl.get_signal(state);
    }

    pub fn get_formData(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigateEventImpl.get_formData(state);
    }

    pub fn get_downloadRequest(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigateEventImpl.get_downloadRequest(state);
    }

    pub fn get_info(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigateEventImpl.get_info(state);
    }

    pub fn get_hasUAVisualTransition(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigateEventImpl.get_hasUAVisualTransition(state);
    }

    pub fn get_sourceElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigateEventImpl.get_sourceElement(state);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigateEventImpl.call_stopImmediatePropagation(state);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: runtime.DOMString, bubbles: bool, cancelable: bool) anyopaque {
        const state = instance.getState(State);
        
        return NavigateEventImpl.call_initEvent(state, type_, bubbles, cancelable);
    }

    pub fn call_scroll(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigateEventImpl.call_scroll(state);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigateEventImpl.call_composedPath(state);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigateEventImpl.call_stopPropagation(state);
    }

    pub fn call_intercept(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigateEventImpl.call_intercept(state, options);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigateEventImpl.call_preventDefault(state);
    }

};
