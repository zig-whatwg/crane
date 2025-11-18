//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigateEventImpl = @import("impls").NavigateEvent;
const Event = @import("interfaces").Event;
const Element = @import("interfaces").Element;
const NavigationType = @import("enums").NavigationType;
const NavigateEventInit = @import("dictionaries").NavigateEventInit;
const AbortSignal = @import("interfaces").AbortSignal;
const NavigationInterceptOptions = @import("dictionaries").NavigationInterceptOptions;
const NavigationDestination = @import("interfaces").NavigationDestination;
const FormData = @import("interfaces").FormData;
const DOMString = @import("typedefs").DOMString;

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
        
        // Initialize the instance (Impl receives full instance)
        NavigateEventImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigateEventImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, type_: DOMString, eventInitDict: NavigateEventInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try NavigateEventImpl.constructor(instance, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigateEventImpl.get_type(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigateEventImpl.get_target(instance);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigateEventImpl.get_srcElement(instance);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigateEventImpl.get_currentTarget(instance);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) anyerror!u16 {
        return try NavigateEventImpl.get_eventPhase(instance);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) anyerror!bool {
        return try NavigateEventImpl.get_cancelBubble(instance);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) anyerror!void {
        try NavigateEventImpl.set_cancelBubble(instance, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) anyerror!bool {
        return try NavigateEventImpl.get_bubbles(instance);
    }

    pub fn get_cancelable(instance: *runtime.Instance) anyerror!bool {
        return try NavigateEventImpl.get_cancelable(instance);
    }

    pub fn get_returnValue(instance: *runtime.Instance) anyerror!bool {
        return try NavigateEventImpl.get_returnValue(instance);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) anyerror!void {
        try NavigateEventImpl.set_returnValue(instance, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) anyerror!bool {
        return try NavigateEventImpl.get_defaultPrevented(instance);
    }

    pub fn get_composed(instance: *runtime.Instance) anyerror!bool {
        return try NavigateEventImpl.get_composed(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) anyerror!bool {
        return try NavigateEventImpl.get_isTrusted(instance);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try NavigateEventImpl.get_timeStamp(instance);
    }

    pub fn get_navigationType(instance: *runtime.Instance) anyerror!NavigationType {
        return try NavigateEventImpl.get_navigationType(instance);
    }

    pub fn get_destination(instance: *runtime.Instance) anyerror!NavigationDestination {
        return try NavigateEventImpl.get_destination(instance);
    }

    pub fn get_canIntercept(instance: *runtime.Instance) anyerror!bool {
        return try NavigateEventImpl.get_canIntercept(instance);
    }

    pub fn get_userInitiated(instance: *runtime.Instance) anyerror!bool {
        return try NavigateEventImpl.get_userInitiated(instance);
    }

    pub fn get_hashChange(instance: *runtime.Instance) anyerror!bool {
        return try NavigateEventImpl.get_hashChange(instance);
    }

    pub fn get_signal(instance: *runtime.Instance) anyerror!AbortSignal {
        return try NavigateEventImpl.get_signal(instance);
    }

    pub fn get_formData(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigateEventImpl.get_formData(instance);
    }

    pub fn get_downloadRequest(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigateEventImpl.get_downloadRequest(instance);
    }

    pub fn get_info(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigateEventImpl.get_info(instance);
    }

    pub fn get_hasUAVisualTransition(instance: *runtime.Instance) anyerror!bool {
        return try NavigateEventImpl.get_hasUAVisualTransition(instance);
    }

    pub fn get_sourceElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigateEventImpl.get_sourceElement(instance);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyerror!void {
        return try NavigateEventImpl.call_stopImmediatePropagation(instance);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: DOMString, bubbles: bool, cancelable: bool) anyerror!void {
        
        return try NavigateEventImpl.call_initEvent(instance, type_, bubbles, cancelable);
    }

    pub fn call_scroll(instance: *runtime.Instance) anyerror!void {
        return try NavigateEventImpl.call_scroll(instance);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigateEventImpl.call_composedPath(instance);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyerror!void {
        return try NavigateEventImpl.call_stopPropagation(instance);
    }

    pub fn call_intercept(instance: *runtime.Instance, options: NavigationInterceptOptions) anyerror!void {
        
        return try NavigateEventImpl.call_intercept(instance, options);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyerror!void {
        return try NavigateEventImpl.call_preventDefault(instance);
    }

};
