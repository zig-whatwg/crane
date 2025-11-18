//! Generated from: payment-handler.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PaymentRequestEventImpl = @import("impls").PaymentRequestEvent;
const ExtendableEvent = @import("interfaces").ExtendableEvent;
const Promise<PaymentRequestDetailsUpdate?> = @import("interfaces").Promise<PaymentRequestDetailsUpdate?>;
const Promise<WindowClient?> = @import("interfaces").Promise<WindowClient?>;
const Promise<PaymentHandlerResponse> = @import("interfaces").Promise<PaymentHandlerResponse>;
const object = @import("interfaces").object;
const PaymentRequestEventInit = @import("dictionaries").PaymentRequestEventInit;
const FrozenArray<PaymentMethodData> = @import("interfaces").FrozenArray<PaymentMethodData>;
const FrozenArray<PaymentDetailsModifier> = @import("interfaces").FrozenArray<PaymentDetailsModifier>;
const AddressInit = @import("interfaces").AddressInit;
const FrozenArray<PaymentShippingOption> = @import("interfaces").FrozenArray<PaymentShippingOption>;

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
        
        // Initialize the instance (Impl receives full instance)
        PaymentRequestEventImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PaymentRequestEventImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, type_: DOMString, eventInitDict: PaymentRequestEventInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try PaymentRequestEventImpl.constructor(instance, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentRequestEventImpl.get_type(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentRequestEventImpl.get_target(instance);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentRequestEventImpl.get_srcElement(instance);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentRequestEventImpl.get_currentTarget(instance);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) anyerror!u16 {
        return try PaymentRequestEventImpl.get_eventPhase(instance);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) anyerror!bool {
        return try PaymentRequestEventImpl.get_cancelBubble(instance);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) anyerror!void {
        try PaymentRequestEventImpl.set_cancelBubble(instance, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) anyerror!bool {
        return try PaymentRequestEventImpl.get_bubbles(instance);
    }

    pub fn get_cancelable(instance: *runtime.Instance) anyerror!bool {
        return try PaymentRequestEventImpl.get_cancelable(instance);
    }

    pub fn get_returnValue(instance: *runtime.Instance) anyerror!bool {
        return try PaymentRequestEventImpl.get_returnValue(instance);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) anyerror!void {
        try PaymentRequestEventImpl.set_returnValue(instance, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) anyerror!bool {
        return try PaymentRequestEventImpl.get_defaultPrevented(instance);
    }

    pub fn get_composed(instance: *runtime.Instance) anyerror!bool {
        return try PaymentRequestEventImpl.get_composed(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) anyerror!bool {
        return try PaymentRequestEventImpl.get_isTrusted(instance);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PaymentRequestEventImpl.get_timeStamp(instance);
    }

    pub fn get_topOrigin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PaymentRequestEventImpl.get_topOrigin(instance);
    }

    pub fn get_paymentRequestOrigin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PaymentRequestEventImpl.get_paymentRequestOrigin(instance);
    }

    pub fn get_paymentRequestId(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentRequestEventImpl.get_paymentRequestId(instance);
    }

    pub fn get_methodData(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentRequestEventImpl.get_methodData(instance);
    }

    pub fn get_total(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentRequestEventImpl.get_total(instance);
    }

    pub fn get_modifiers(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentRequestEventImpl.get_modifiers(instance);
    }

    pub fn get_paymentOptions(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentRequestEventImpl.get_paymentOptions(instance);
    }

    pub fn get_shippingOptions(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentRequestEventImpl.get_shippingOptions(instance);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyerror!void {
        return try PaymentRequestEventImpl.call_stopImmediatePropagation(instance);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: DOMString, bubbles: bool, cancelable: bool) anyerror!void {
        
        return try PaymentRequestEventImpl.call_initEvent(instance, type_, bubbles, cancelable);
    }

    pub fn call_changePaymentMethod(instance: *runtime.Instance, methodName: DOMString, methodDetails: anyopaque) anyerror!anyopaque {
        
        return try PaymentRequestEventImpl.call_changePaymentMethod(instance, methodName, methodDetails);
    }

    pub fn call_waitUntil(instance: *runtime.Instance, f: anyopaque) anyerror!void {
        
        return try PaymentRequestEventImpl.call_waitUntil(instance, f);
    }

    pub fn call_openWindow(instance: *runtime.Instance, url: runtime.USVString) anyerror!anyopaque {
        
        return try PaymentRequestEventImpl.call_openWindow(instance, url);
    }

    pub fn call_changeShippingOption(instance: *runtime.Instance, shippingOption: DOMString) anyerror!anyopaque {
        
        return try PaymentRequestEventImpl.call_changeShippingOption(instance, shippingOption);
    }

    pub fn call_respondWith(instance: *runtime.Instance, handlerResponsePromise: anyopaque) anyerror!void {
        
        return try PaymentRequestEventImpl.call_respondWith(instance, handlerResponsePromise);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentRequestEventImpl.call_composedPath(instance);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyerror!void {
        return try PaymentRequestEventImpl.call_stopPropagation(instance);
    }

    pub fn call_changeShippingAddress(instance: *runtime.Instance, shippingAddress: anyopaque) anyerror!anyopaque {
        
        return try PaymentRequestEventImpl.call_changeShippingAddress(instance, shippingAddress);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyerror!void {
        return try PaymentRequestEventImpl.call_preventDefault(instance);
    }

};
