//! Generated from: payment-request.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PaymentMethodChangeEventImpl = @import("impls").PaymentMethodChangeEvent;
const PaymentRequestUpdateEvent = @import("interfaces").PaymentRequestUpdateEvent;
const object = @import("interfaces").object;
const PaymentMethodChangeEventInit = @import("dictionaries").PaymentMethodChangeEventInit;

pub const PaymentMethodChangeEvent = struct {
    pub const Meta = struct {
        pub const name = "PaymentMethodChangeEvent";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *PaymentRequestUpdateEvent;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
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
            methodName: runtime.DOMString = undefined,
            methodDetails: ?anyopaque = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PaymentMethodChangeEvent, .{
        .deinit_fn = &deinit_wrapper,

        .get_AT_TARGET = &PaymentRequestUpdateEvent.get_AT_TARGET,
        .get_BUBBLING_PHASE = &PaymentRequestUpdateEvent.get_BUBBLING_PHASE,
        .get_CAPTURING_PHASE = &PaymentRequestUpdateEvent.get_CAPTURING_PHASE,
        .get_NONE = &PaymentRequestUpdateEvent.get_NONE,
        .get_bubbles = &get_bubbles,
        .get_cancelBubble = &get_cancelBubble,
        .get_cancelable = &get_cancelable,
        .get_composed = &get_composed,
        .get_currentTarget = &get_currentTarget,
        .get_defaultPrevented = &get_defaultPrevented,
        .get_eventPhase = &get_eventPhase,
        .get_isTrusted = &get_isTrusted,
        .get_methodDetails = &get_methodDetails,
        .get_methodName = &get_methodName,
        .get_returnValue = &get_returnValue,
        .get_srcElement = &get_srcElement,
        .get_target = &get_target,
        .get_timeStamp = &get_timeStamp,
        .get_type = &get_type,

        .set_cancelBubble = &set_cancelBubble,
        .set_returnValue = &set_returnValue,

        .call_composedPath = &call_composedPath,
        .call_initEvent = &call_initEvent,
        .call_preventDefault = &call_preventDefault,
        .call_stopImmediatePropagation = &call_stopImmediatePropagation,
        .call_stopPropagation = &call_stopPropagation,
        .call_updateWith = &call_updateWith,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        PaymentMethodChangeEventImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PaymentMethodChangeEventImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, type_: DOMString, eventInitDict: PaymentMethodChangeEventInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try PaymentMethodChangeEventImpl.constructor(instance, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentMethodChangeEventImpl.get_type(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentMethodChangeEventImpl.get_target(instance);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentMethodChangeEventImpl.get_srcElement(instance);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentMethodChangeEventImpl.get_currentTarget(instance);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) anyerror!u16 {
        return try PaymentMethodChangeEventImpl.get_eventPhase(instance);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) anyerror!bool {
        return try PaymentMethodChangeEventImpl.get_cancelBubble(instance);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) anyerror!void {
        try PaymentMethodChangeEventImpl.set_cancelBubble(instance, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) anyerror!bool {
        return try PaymentMethodChangeEventImpl.get_bubbles(instance);
    }

    pub fn get_cancelable(instance: *runtime.Instance) anyerror!bool {
        return try PaymentMethodChangeEventImpl.get_cancelable(instance);
    }

    pub fn get_returnValue(instance: *runtime.Instance) anyerror!bool {
        return try PaymentMethodChangeEventImpl.get_returnValue(instance);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) anyerror!void {
        try PaymentMethodChangeEventImpl.set_returnValue(instance, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) anyerror!bool {
        return try PaymentMethodChangeEventImpl.get_defaultPrevented(instance);
    }

    pub fn get_composed(instance: *runtime.Instance) anyerror!bool {
        return try PaymentMethodChangeEventImpl.get_composed(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) anyerror!bool {
        return try PaymentMethodChangeEventImpl.get_isTrusted(instance);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PaymentMethodChangeEventImpl.get_timeStamp(instance);
    }

    pub fn get_methodName(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentMethodChangeEventImpl.get_methodName(instance);
    }

    pub fn get_methodDetails(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentMethodChangeEventImpl.get_methodDetails(instance);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyerror!void {
        return try PaymentMethodChangeEventImpl.call_stopImmediatePropagation(instance);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: DOMString, bubbles: bool, cancelable: bool) anyerror!void {
        
        return try PaymentMethodChangeEventImpl.call_initEvent(instance, type_, bubbles, cancelable);
    }

    pub fn call_updateWith(instance: *runtime.Instance, detailsPromise: anyopaque) anyerror!void {
        
        return try PaymentMethodChangeEventImpl.call_updateWith(instance, detailsPromise);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentMethodChangeEventImpl.call_composedPath(instance);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyerror!void {
        return try PaymentMethodChangeEventImpl.call_stopPropagation(instance);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyerror!void {
        return try PaymentMethodChangeEventImpl.call_preventDefault(instance);
    }

};
