//! Generated from: payment-handler.idl
//! Generated at: 2025-11-23T14:26:30Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PaymentRequestEventImpl = @import("impls").PaymentRequestEvent;
const ExtendableEvent = @import("interfaces").ExtendableEvent;
const PaymentMethodData = @import("dictionaries").PaymentMethodData;
const WindowClient = @import("interfaces").WindowClient;
const PaymentShippingOption = @import("dictionaries").PaymentShippingOption;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const PaymentRequestEventInit = @import("dictionaries").PaymentRequestEventInit;
const AddressInit = @import("interfaces").AddressInit;
const USVString = @import("interfaces").USVString;
const ExtendableEventInit = @import("dictionaries").ExtendableEventInit;
const EventTarget = @import("interfaces").EventTarget;
const PaymentDetailsModifier = @import("dictionaries").PaymentDetailsModifier;
const EventInit = @import("dictionaries").EventInit;
const PaymentRequestDetailsUpdate = @import("dictionaries").PaymentRequestDetailsUpdate;
const PaymentHandlerResponse = @import("dictionaries").PaymentHandlerResponse;
const DOMString = @import("typedefs").DOMString;

pub const PaymentRequestEvent = struct {
    pub const Meta = struct {
        pub const name = "PaymentRequestEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ExtendableEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "topOrigin", "get_topOrigin", null },
            .{ "paymentRequestOrigin", "get_paymentRequestOrigin", null },
            .{ "paymentRequestId", "get_paymentRequestId", null },
            .{ "methodData", "get_methodData", null },
            .{ "total", "get_total", null },
            .{ "modifiers", "get_modifiers", null },
            .{ "paymentOptions", "get_paymentOptions", null },
            .{ "shippingOptions", "get_shippingOptions", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "openWindow", "call_openWindow", 1 },
            .{ "changePaymentMethod", "call_changePaymentMethod", 1 },
            .{ "changeShippingAddress", "call_changeShippingAddress", 0 },
            .{ "changeShippingOption", "call_changeShippingOption", 1 },
            .{ "respondWith", "call_respondWith", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "openWindow",
            "changePaymentMethod",
            "changeShippingAddress",
            "changeShippingOption",
            "respondWith",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
            "waitUntil",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "topOrigin", "get_topOrigin", null },
            .{ "paymentRequestOrigin", "get_paymentRequestOrigin", null },
            .{ "paymentRequestId", "get_paymentRequestId", null },
            .{ "methodData", "get_methodData", null },
            .{ "total", "get_total", null },
            .{ "modifiers", "get_modifiers", null },
            .{ "paymentOptions", "get_paymentOptions", null },
            .{ "shippingOptions", "get_shippingOptions", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            topOrigin: runtime.USVString = undefined,
            paymentRequestOrigin: runtime.USVString = undefined,
            paymentRequestId: runtime.DOMString = undefined,
            methodData: runtime.FrozenArray(PaymentMethodData) = undefined,
            total: *const anyopaque = undefined,
            modifiers: runtime.FrozenArray(PaymentDetailsModifier) = undefined,
            paymentOptions: ?*const anyopaque = null,
            shippingOptions: ?runtime.FrozenArray(PaymentShippingOption) = null,
            _internal: ?*PaymentRequestEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_methodData = &get_methodData,
        .get_modifiers = &get_modifiers,
        .get_paymentOptions = &get_paymentOptions,
        .get_paymentRequestId = &get_paymentRequestId,
        .get_paymentRequestOrigin = &get_paymentRequestOrigin,
        .get_shippingOptions = &get_shippingOptions,
        .get_topOrigin = &get_topOrigin,
        .get_total = &get_total,

        .call_changePaymentMethod = &call_changePaymentMethod,
        .call_changeShippingAddress = &call_changeShippingAddress,
        .call_changeShippingOption = &call_changeShippingOption,
        .call_openWindow = &call_openWindow,
        .call_respondWith = &call_respondWith,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PaymentRequestEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PaymentRequestEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: PaymentRequestEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PaymentRequestEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
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

    pub fn get_methodData(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PaymentRequestEventImpl.get_methodData(instance);
    }

    pub fn get_total(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PaymentRequestEventImpl.get_total(instance);
    }

    pub fn get_modifiers(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PaymentRequestEventImpl.get_modifiers(instance);
    }

    pub fn get_paymentOptions(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PaymentRequestEventImpl.get_paymentOptions(instance);
    }

    pub fn get_shippingOptions(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PaymentRequestEventImpl.get_shippingOptions(instance);
    }

    pub fn call_changePaymentMethod(instance: *runtime.Instance, methodName: DOMString, methodDetails: *const anyopaque) anyerror!*const anyopaque {
        
        return try PaymentRequestEventImpl.call_changePaymentMethod(instance, methodName, methodDetails);
    }

    pub fn call_respondWith(instance: *runtime.Instance, handlerResponsePromise: *const anyopaque) anyerror!void {
        
        return try PaymentRequestEventImpl.call_respondWith(instance, handlerResponsePromise);
    }

    pub fn call_openWindow(instance: *runtime.Instance, url: runtime.USVString) anyerror!*const anyopaque {
        
        return try PaymentRequestEventImpl.call_openWindow(instance, url);
    }

    pub fn call_changeShippingAddress(instance: *runtime.Instance, shippingAddress: *const anyopaque) anyerror!*const anyopaque {
        
        return try PaymentRequestEventImpl.call_changeShippingAddress(instance, shippingAddress);
    }

    pub fn call_changeShippingOption(instance: *runtime.Instance, shippingOption: DOMString) anyerror!*const anyopaque {
        
        return try PaymentRequestEventImpl.call_changeShippingOption(instance, shippingOption);
    }

};
