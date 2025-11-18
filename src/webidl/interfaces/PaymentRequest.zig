//! Generated from: payment-request.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PaymentRequestImpl = @import("impls").PaymentRequest;
const EventTarget = @import("interfaces").EventTarget;
const EventHandler = @import("typedefs").EventHandler;
const Promise<boolean> = @import("interfaces").Promise<boolean>;
const Promise<SecurePaymentConfirmationAvailability> = @import("interfaces").Promise<SecurePaymentConfirmationAvailability>;
const PaymentDetailsInit = @import("dictionaries").PaymentDetailsInit;
const Promise<PaymentDetailsUpdate> = @import("interfaces").Promise<PaymentDetailsUpdate>;
const PaymentShippingType = @import("enums").PaymentShippingType;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const ContactAddress = @import("interfaces").ContactAddress;
const Promise<PaymentResponse> = @import("interfaces").Promise<PaymentResponse>;
const PaymentOptions = @import("dictionaries").PaymentOptions;
const DOMString = @import("typedefs").DOMString;

pub const PaymentRequest = struct {
    pub const Meta = struct {
        pub const name = "PaymentRequest";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            id: runtime.DOMString = undefined,
            shippingAddress: ?ContactAddress = null,
            shippingOption: ?runtime.DOMString = null,
            shippingType: ?PaymentShippingType = null,
            onshippingaddresschange: EventHandler = undefined,
            onshippingoptionchange: EventHandler = undefined,
            onpaymentmethodchange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PaymentRequest, .{
        .deinit_fn = &deinit_wrapper,

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
        .call_addEventListener = &call_addEventListener,
        .call_canMakePayment = &call_canMakePayment,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_securePaymentConfirmationAvailability = &call_securePaymentConfirmationAvailability,
        .call_show = &call_show,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        PaymentRequestImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PaymentRequestImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, methodData: anyopaque, details: PaymentDetailsInit, options: PaymentOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try PaymentRequestImpl.constructor(instance, methodData, details, options);
        
        return instance;
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentRequestImpl.get_id(instance);
    }

    pub fn get_shippingAddress(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentRequestImpl.get_shippingAddress(instance);
    }

    pub fn get_shippingOption(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentRequestImpl.get_shippingOption(instance);
    }

    pub fn get_shippingType(instance: *runtime.Instance) anyerror!anyopaque {
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

    pub fn call_securePaymentConfirmationAvailability(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentRequestImpl.call_securePaymentConfirmationAvailability(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try PaymentRequestImpl.call_when(instance, type_, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_show(instance: *runtime.Instance, detailsPromise: anyopaque) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try PaymentRequestImpl.call_show(instance, detailsPromise);
    }

    /// Extended attributes: [NewObject]
    pub fn call_abort(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try PaymentRequestImpl.call_abort(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_canMakePayment(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try PaymentRequestImpl.call_canMakePayment(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try PaymentRequestImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try PaymentRequestImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try PaymentRequestImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
