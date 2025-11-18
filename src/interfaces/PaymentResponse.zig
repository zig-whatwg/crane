//! Generated from: payment-request.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PaymentResponseImpl = @import("../impls/PaymentResponse.zig");
const EventTarget = @import("EventTarget.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        PaymentResponseImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PaymentResponseImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_requestId(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PaymentResponseImpl.get_requestId(state);
    }

    pub fn get_methodName(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PaymentResponseImpl.get_methodName(state);
    }

    pub fn get_details(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentResponseImpl.get_details(state);
    }

    pub fn get_shippingAddress(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentResponseImpl.get_shippingAddress(state);
    }

    pub fn get_shippingOption(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentResponseImpl.get_shippingOption(state);
    }

    pub fn get_payerName(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentResponseImpl.get_payerName(state);
    }

    pub fn get_payerEmail(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentResponseImpl.get_payerEmail(state);
    }

    pub fn get_payerPhone(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentResponseImpl.get_payerPhone(state);
    }

    pub fn get_onpayerdetailchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentResponseImpl.get_onpayerdetailchange(state);
    }

    pub fn set_onpayerdetailchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PaymentResponseImpl.set_onpayerdetailchange(state, value);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PaymentResponseImpl.call_when(state, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return PaymentResponseImpl.call_dispatchEvent(state, event);
    }

    /// Extended attributes: [NewObject]
    pub fn call_complete(instance: *runtime.Instance, result: anyopaque, details: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return PaymentResponseImpl.call_complete(state, result, details);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaymentResponseImpl.call_toJSON(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_retry(instance: *runtime.Instance, errorFields: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return PaymentResponseImpl.call_retry(state, errorFields);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PaymentResponseImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PaymentResponseImpl.call_removeEventListener(state, type_, callback, options);
    }

};
