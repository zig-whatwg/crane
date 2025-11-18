//! Generated from: payment-request.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PaymentResponseImpl = @import("impls").PaymentResponse;
const EventTarget = @import("interfaces").EventTarget;
const PaymentValidationErrors = @import("dictionaries").PaymentValidationErrors;
const EventHandler = @import("typedefs").EventHandler;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const ContactAddress = @import("interfaces").ContactAddress;
const PaymentComplete = @import("enums").PaymentComplete;
const DOMString = @import("typedefs").DOMString;
const PaymentCompleteDetails = @import("dictionaries").PaymentCompleteDetails;

pub const PaymentResponse = struct {
    pub const Meta = struct {
        pub const name = "PaymentResponse";
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
            requestId: runtime.DOMString = undefined,
            methodName: runtime.DOMString = undefined,
            details: anyopaque = undefined,
            shippingAddress: ?ContactAddress = null,
            shippingOption: ?runtime.DOMString = null,
            payerName: ?runtime.DOMString = null,
            payerEmail: ?runtime.DOMString = null,
            payerPhone: ?runtime.DOMString = null,
            onpayerdetailchange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PaymentResponse, .{
        .deinit_fn = &deinit_wrapper,

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

        .call_addEventListener = &call_addEventListener,
        .call_complete = &call_complete,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_retry = &call_retry,
        .call_toJSON = &call_toJSON,
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
        PaymentResponseImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PaymentResponseImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_requestId(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentResponseImpl.get_requestId(instance);
    }

    pub fn get_methodName(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentResponseImpl.get_methodName(instance);
    }

    pub fn get_details(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentResponseImpl.get_details(instance);
    }

    pub fn get_shippingAddress(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentResponseImpl.get_shippingAddress(instance);
    }

    pub fn get_shippingOption(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentResponseImpl.get_shippingOption(instance);
    }

    pub fn get_payerName(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentResponseImpl.get_payerName(instance);
    }

    pub fn get_payerEmail(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentResponseImpl.get_payerEmail(instance);
    }

    pub fn get_payerPhone(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentResponseImpl.get_payerPhone(instance);
    }

    pub fn get_onpayerdetailchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try PaymentResponseImpl.get_onpayerdetailchange(instance);
    }

    pub fn set_onpayerdetailchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PaymentResponseImpl.set_onpayerdetailchange(instance, value);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try PaymentResponseImpl.call_when(instance, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try PaymentResponseImpl.call_dispatchEvent(instance, event);
    }

    /// Extended attributes: [NewObject]
    pub fn call_complete(instance: *runtime.Instance, result: PaymentComplete, details: PaymentCompleteDetails) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try PaymentResponseImpl.call_complete(instance, result, details);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try PaymentResponseImpl.call_toJSON(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_retry(instance: *runtime.Instance, errorFields: PaymentValidationErrors) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try PaymentResponseImpl.call_retry(instance, errorFields);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try PaymentResponseImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try PaymentResponseImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
