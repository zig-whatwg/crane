//! Generated from: payment-request.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PaymentRequestImpl = @import("../impls/PaymentRequest.zig");
const EventTarget = @import("EventTarget.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        PaymentRequestImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PaymentRequestImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, methodData: anyopaque, details: anyopaque, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try PaymentRequestImpl.constructor(state, methodData, details, options);
        
        return instance;
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PaymentRequestImpl.get_id(state);
    }

    pub fn get_shippingAddress(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestImpl.get_shippingAddress(state);
    }

    pub fn get_shippingOption(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestImpl.get_shippingOption(state);
    }

    pub fn get_shippingType(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestImpl.get_shippingType(state);
    }

    pub fn get_onshippingaddresschange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestImpl.get_onshippingaddresschange(state);
    }

    pub fn set_onshippingaddresschange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PaymentRequestImpl.set_onshippingaddresschange(state, value);
    }

    pub fn get_onshippingoptionchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestImpl.get_onshippingoptionchange(state);
    }

    pub fn set_onshippingoptionchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PaymentRequestImpl.set_onshippingoptionchange(state, value);
    }

    pub fn get_onpaymentmethodchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestImpl.get_onpaymentmethodchange(state);
    }

    pub fn set_onpaymentmethodchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PaymentRequestImpl.set_onpaymentmethodchange(state, value);
    }

    pub fn call_securePaymentConfirmationAvailability(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentRequestImpl.call_securePaymentConfirmationAvailability(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PaymentRequestImpl.call_when(state, type_, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_show(instance: *runtime.Instance, detailsPromise: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return PaymentRequestImpl.call_show(state, detailsPromise);
    }

    /// Extended attributes: [NewObject]
    pub fn call_abort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return PaymentRequestImpl.call_abort(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_canMakePayment(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return PaymentRequestImpl.call_canMakePayment(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return PaymentRequestImpl.call_dispatchEvent(state, event);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PaymentRequestImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PaymentRequestImpl.call_removeEventListener(state, type_, callback, options);
    }

};
