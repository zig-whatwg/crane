//! Generated from: payment-request.idl
//! Generated at: 2025-11-28T03:24:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PaymentRequestImpl = @import("impls").PaymentRequest;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const EventHandler = @import("typedefs").EventHandler;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const PaymentMethodData = @import("dictionaries").PaymentMethodData;
const PaymentShippingType = @import("enums").PaymentShippingType;
const SecurePaymentConfirmationAvailability = @import("enums").SecurePaymentConfirmationAvailability;
const PaymentOptions = @import("dictionaries").PaymentOptions;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const PaymentDetailsInit = @import("dictionaries").PaymentDetailsInit;
const EventListener = @import("interfaces").EventListener;
const PaymentResponse = @import("interfaces").PaymentResponse;
const ContactAddress = @import("interfaces").ContactAddress;
const DOMString = @import("typedefs").DOMString;
const PaymentDetailsUpdate = @import("dictionaries").PaymentDetailsUpdate;

pub const PaymentRequest = struct {
    pub const Meta = struct {
        pub const name = "PaymentRequest";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "id", "get_id", null },
            .{ "shippingAddress", "get_shippingAddress", null },
            .{ "shippingOption", "get_shippingOption", null },
            .{ "shippingType", "get_shippingType", null },
            .{ "onshippingaddresschange", "get_onshippingaddresschange", "set_onshippingaddresschange" },
            .{ "onshippingoptionchange", "get_onshippingoptionchange", "set_onshippingoptionchange" },
            .{ "onpaymentmethodchange", "get_onpaymentmethodchange", "set_onpaymentmethodchange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "show", "call_show", 0 },
            .{ "abort", "call_abort", 0 },
            .{ "canMakePayment", "call_canMakePayment", 0 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "securePaymentConfirmationAvailability", "call_securePaymentConfirmationAvailability", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "show",
            "abort",
            "canMakePayment",
            "securePaymentConfirmationAvailability",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "id", "get_id", null },
            .{ "shippingAddress", "get_shippingAddress", null },
            .{ "shippingOption", "get_shippingOption", null },
            .{ "shippingType", "get_shippingType", null },
            .{ "onshippingaddresschange", "get_onshippingaddresschange", "set_onshippingaddresschange" },
            .{ "onshippingoptionchange", "get_onshippingoptionchange", "set_onshippingoptionchange" },
            .{ "onpaymentmethodchange", "get_onpaymentmethodchange", "set_onpaymentmethodchange" },
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
            id: runtime.DOMString = undefined,
            shippingAddress: ?*runtime.Instance = null,
            shippingOption: ?runtime.DOMString = null,
            shippingType: ?PaymentShippingType = null,
            onshippingaddresschange: EventHandler = undefined,
            onshippingoptionchange: EventHandler = undefined,
            onpaymentmethodchange: EventHandler = undefined,
            _internal: ?*PaymentRequestImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_id = &get_id,
        .get_onpaymentmethodchange = &get_onpaymentmethodchange,
        .get_onshippingaddresschange = &get_onshippingaddresschange,
        .get_onshippingoptionchange = &get_onshippingoptionchange,
        .get_shippingAddress = &get_shippingAddress,
        .get_shippingOption = &get_shippingOption,
        .get_shippingType = &get_shippingType,

        .set_onpaymentmethodchange = &set_onpaymentmethodchange,
        .set_onshippingaddresschange = &set_onshippingaddresschange,
        .set_onshippingoptionchange = &set_onshippingoptionchange,

        .call_abort = &call_abort,
        .call_canMakePayment = &call_canMakePayment,
        .call_securePaymentConfirmationAvailability = &call_securePaymentConfirmationAvailability,
        .call_show = &call_show,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PaymentRequestImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PaymentRequestImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, methodData: *const anyopaque, details: PaymentDetailsInit, options: PaymentOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PaymentRequestImpl.call_constructor(allocator, ctx, methodData, details, options);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentRequestImpl.get_id(instance);
    }

    pub fn get_shippingAddress(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try PaymentRequestImpl.get_shippingAddress(instance);
    }

    pub fn get_shippingOption(instance: *runtime.Instance) anyerror!?DOMString {
        return try PaymentRequestImpl.get_shippingOption(instance);
    }

    pub fn get_shippingType(instance: *runtime.Instance) anyerror!?PaymentShippingType {
        return try PaymentRequestImpl.get_shippingType(instance);
    }

    pub fn get_onshippingaddresschange(instance: *runtime.Instance) anyerror!EventHandler {
        return try PaymentRequestImpl.get_onshippingaddresschange(instance);
    }

    pub fn set_onshippingaddresschange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PaymentRequestImpl.set_onshippingaddresschange(instance, value);
    }

    pub fn get_onshippingoptionchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try PaymentRequestImpl.get_onshippingoptionchange(instance);
    }

    pub fn set_onshippingoptionchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PaymentRequestImpl.set_onshippingoptionchange(instance, value);
    }

    pub fn get_onpaymentmethodchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try PaymentRequestImpl.get_onpaymentmethodchange(instance);
    }

    pub fn set_onpaymentmethodchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PaymentRequestImpl.set_onpaymentmethodchange(instance, value);
    }

    /// Extended attributes: [NewObject]
    pub fn call_abort(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try PaymentRequestImpl.call_abort(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_show(instance: *runtime.Instance, detailsPromise: *const anyopaque) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try PaymentRequestImpl.call_show(instance, detailsPromise);
    }

    /// Extended attributes: [NewObject]
    pub fn call_canMakePayment(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try PaymentRequestImpl.call_canMakePayment(instance);
    }

    pub fn call_securePaymentConfirmationAvailability(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PaymentRequestImpl.call_securePaymentConfirmationAvailability(instance);
    }

};
