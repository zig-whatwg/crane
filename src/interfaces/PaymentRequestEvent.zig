//! Generated from: payment-handler.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PaymentRequestEventImpl = @import("../impls/PaymentRequestEvent.zig");
const ExtendableEvent = @import("ExtendableEvent.zig");

pub const PaymentRequestEvent = struct {
    pub const Meta = struct {
        pub const name = "PaymentRequestEvent";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ExtendableEvent;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };
        
        /// Properties that cannot be shadowed or deleted (configurable: false)
        pub const legacy_unforgeable_properties = .{
            "isTrusted",
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            topOrigin: runtime.USVString = undefined,
            paymentRequestOrigin: runtime.USVString = undefined,
            paymentRequestId: runtime.DOMString = undefined,
            methodData: FrozenArray<PaymentMethodData> = undefined,
            total: anyopaque = undefined,
            modifiers: FrozenArray<PaymentDetailsModifier> = undefined,
            paymentOptions: ?anyopaque = null,
            shippingOptions: ?FrozenArray<PaymentShippingOption> = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PaymentRequestEvent, .{
        .deinit_fn = &deinit_wrapper,

        .get_AT_TARGET = &ExtendableEvent.get_AT_TARGET,
        .get_BUBBLING_PHASE = &ExtendableEvent.get_BUBBLING_PHASE,
        .get_CAPTURING_PHASE = &ExtendableEvent.get_CAPTURING_PHASE,
        .get_NONE = &ExtendableEvent.get_NONE,
        .get_bubbles = &get_bubbles,
        .get_cancelBubble = &get_cancelBubble,
        .get_cancelable = &get_cancelable,
        .get_composed = &get_composed,
        .get_currentTarget = &get_currentTarget,
        .get_defaultPrevented = &get_defaultPrevented,
        .get_eventPhase = &get_eventPhase,
        .get_isTrusted = &get_isTrusted,
        .get_methodData = &get_methodData,
        .get_modifiers = &get_modifiers,
        .get_paymentOptions = &get_paymentOptions,
        .get_paymentRequestId = &get_paymentRequestId,
        .get_paymentRequestOrigin = &get_paymentRequestOrigin,
        .get_returnValue = &get_returnValue,
        .get_shippingOptions = &get_shippingOptions,
        .get_srcElement = &get_srcElement,
        .get_target = &get_target,
        .get_timeStamp = &get_timeStamp,
        .get_topOrigin = &get_topOrigin,
        .get_total = &get_total,
        .get_type = &get_type,

        .set_cancelBubble = &set_cancelBubble,
        .set_returnValue = &set_returnValue,

        .call_changePaymentMethod = &call_changePaymentMethod,
        .call_changeShippingAddress = &call_changeShippingAddress,
        .call_changeShippingOption = &call_changeShippingOption,
        .call_composedPath = &call_composedPath,
        .call_initEvent = &call_initEvent,
        .call_openWindow = &call_openWindow,
        .call_preventDefault = &call_preventDefault,
        .call_respondWith = &call_respondWith,
        .call_stopImmediatePropagation = &call_stopImmediatePropagation,
        .call_stopPropagation = &call_stopPropagation,
        .call_waitUntil = &call_waitUntil,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        PaymentRequestEventImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PaymentRequestEventImpl.deinit(state);
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
        try PaymentRequestEventImpl.constructor(state, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_type(state);
    }

    pub fn get_target(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_target(state);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_srcElement(state);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_currentTarget(state);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_eventPhase(state);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_cancelBubble(state);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        PaymentRequestEventImpl.set_cancelBubble(state, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_bubbles(state);
    }

    pub fn get_cancelable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_cancelable(state);
    }

    pub fn get_returnValue(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_returnValue(state);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        PaymentRequestEventImpl.set_returnValue(state, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_defaultPrevented(state);
    }

    pub fn get_composed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_composed(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_isTrusted(state);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_timeStamp(state);
    }

    pub fn get_topOrigin(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_topOrigin(state);
    }

    pub fn get_paymentRequestOrigin(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_paymentRequestOrigin(state);
    }

    pub fn get_paymentRequestId(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_paymentRequestId(state);
    }

    pub fn get_methodData(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_methodData(state);
    }

    pub fn get_total(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_total(state);
    }

    pub fn get_modifiers(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_modifiers(state);
    }

    pub fn get_paymentOptions(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_paymentOptions(state);
    }

    pub fn get_shippingOptions(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.get_shippingOptions(state);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.call_stopImmediatePropagation(state);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: runtime.DOMString, bubbles: bool, cancelable: bool) anyopaque {
        const state = instance.getState(State);
        
        return PaymentRequestEventImpl.call_initEvent(state, type_, bubbles, cancelable);
    }

    pub fn call_changePaymentMethod(instance: *runtime.Instance, methodName: runtime.DOMString, methodDetails: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PaymentRequestEventImpl.call_changePaymentMethod(state, methodName, methodDetails);
    }

    pub fn call_waitUntil(instance: *runtime.Instance, f: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PaymentRequestEventImpl.call_waitUntil(state, f);
    }

    pub fn call_openWindow(instance: *runtime.Instance, url: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return PaymentRequestEventImpl.call_openWindow(state, url);
    }

    pub fn call_changeShippingOption(instance: *runtime.Instance, shippingOption: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return PaymentRequestEventImpl.call_changeShippingOption(state, shippingOption);
    }

    pub fn call_respondWith(instance: *runtime.Instance, handlerResponsePromise: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PaymentRequestEventImpl.call_respondWith(state, handlerResponsePromise);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.call_composedPath(state);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.call_stopPropagation(state);
    }

    pub fn call_changeShippingAddress(instance: *runtime.Instance, shippingAddress: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PaymentRequestEventImpl.call_changeShippingAddress(state, shippingAddress);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestEventImpl.call_preventDefault(state);
    }

};
