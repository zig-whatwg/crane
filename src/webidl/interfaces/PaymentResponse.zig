//! Generated from: payment-request.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PaymentResponseImpl = @import("impls").PaymentResponse;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const PaymentComplete = @import("enums").PaymentComplete;
const PaymentValidationErrors = @import("dictionaries").PaymentValidationErrors;
const PaymentCompleteDetails = @import("dictionaries").PaymentCompleteDetails;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const ContactAddress = @import("interfaces").ContactAddress;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const PaymentResponse = struct {
    pub const Meta = struct {
        pub const name = "PaymentResponse";
        pub const is_mixin = false;
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
            .{ "requestId", "get_requestId", null },
            .{ "methodName", "get_methodName", null },
            .{ "details", "get_details", null },
            .{ "shippingAddress", "get_shippingAddress", null },
            .{ "shippingOption", "get_shippingOption", null },
            .{ "payerName", "get_payerName", null },
            .{ "payerEmail", "get_payerEmail", null },
            .{ "payerPhone", "get_payerPhone", null },
            .{ "onpayerdetailchange", "get_onpayerdetailchange", "set_onpayerdetailchange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
            .{ "complete", "call_complete", 0 },
            .{ "retry", "call_retry", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
            "complete",
            "retry",
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
            .{ "requestId", "get_requestId", null },
            .{ "methodName", "get_methodName", null },
            .{ "details", "get_details", null },
            .{ "shippingAddress", "get_shippingAddress", null },
            .{ "shippingOption", "get_shippingOption", null },
            .{ "payerName", "get_payerName", null },
            .{ "payerEmail", "get_payerEmail", null },
            .{ "payerPhone", "get_payerPhone", null },
            .{ "onpayerdetailchange", "get_onpayerdetailchange", "set_onpayerdetailchange" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            requestId: runtime.DOMString = undefined,
            methodName: runtime.DOMString = undefined,
            details: *const anyopaque = undefined,
            shippingAddress: ?*runtime.Instance = null,
            shippingOption: ?runtime.DOMString = null,
            payerName: ?runtime.DOMString = null,
            payerEmail: ?runtime.DOMString = null,
            payerPhone: ?runtime.DOMString = null,
            onpayerdetailchange: EventHandler = undefined,
            _internal: ?*PaymentResponseImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_details = &get_details,
        .get_methodName = &get_methodName,
        .get_onpayerdetailchange = &get_onpayerdetailchange,
        .get_payerEmail = &get_payerEmail,
        .get_payerName = &get_payerName,
        .get_payerPhone = &get_payerPhone,
        .get_requestId = &get_requestId,
        .get_shippingAddress = &get_shippingAddress,
        .get_shippingOption = &get_shippingOption,

        .set_onpayerdetailchange = &set_onpayerdetailchange,

        .call_complete = &call_complete,
        .call_retry = &call_retry,
        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PaymentResponseImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PaymentResponseImpl.deinit(instance);
    }

    pub fn get_requestId(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentResponseImpl.get_requestId(instance);
    }

    pub fn get_methodName(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentResponseImpl.get_methodName(instance);
    }

    pub fn get_details(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PaymentResponseImpl.get_details(instance);
    }

    pub fn get_shippingAddress(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try PaymentResponseImpl.get_shippingAddress(instance);
    }

    pub fn get_shippingOption(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentResponseImpl.get_shippingOption(instance);
    }

    pub fn get_payerName(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentResponseImpl.get_payerName(instance);
    }

    pub fn get_payerEmail(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentResponseImpl.get_payerEmail(instance);
    }

    pub fn get_payerPhone(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentResponseImpl.get_payerPhone(instance);
    }

    pub fn get_onpayerdetailchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try PaymentResponseImpl.get_onpayerdetailchange(instance);
    }

    pub fn set_onpayerdetailchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PaymentResponseImpl.set_onpayerdetailchange(instance, value);
    }

    /// Extended attributes: [NewObject]
    pub fn call_complete(instance: *runtime.Instance, result: PaymentComplete, details: PaymentCompleteDetails) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try PaymentResponseImpl.call_complete(instance, result, details);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PaymentResponseImpl.call_toJSON(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_retry(instance: *runtime.Instance, errorFields: PaymentValidationErrors) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try PaymentResponseImpl.call_retry(instance, errorFields);
    }

};
