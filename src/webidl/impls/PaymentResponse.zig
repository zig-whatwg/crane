//! Implementation for PaymentResponse interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const PaymentResponse = interfaces.PaymentResponse;

pub const State = PaymentResponse.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Getter for requestId
pub fn get_requestId(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for methodName
pub fn get_methodName(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for details
pub fn get_details(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for shippingAddress
pub fn get_shippingAddress(instance: *runtime.Instance) ImplError!interfaces.ContactAddress {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for shippingOption
pub fn get_shippingOption(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for payerName
pub fn get_payerName(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for payerEmail
pub fn get_payerEmail(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for payerPhone
pub fn get_payerPhone(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpayerdetailchange
pub fn get_onpayerdetailchange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onpayerdetailchange
pub fn set_onpayerdetailchange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: complete
pub fn call_complete(instance: *runtime.Instance, result: enums.PaymentComplete, details: dictionaries.PaymentCompleteDetails) ImplError!*const anyopaque {
    _ = instance;
    _ = result;
    _ = details;
    return error.NotImplemented;
}

/// Operation: toJSON
pub fn call_toJSON(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: retry
pub fn call_retry(instance: *runtime.Instance, errorFields: dictionaries.PaymentValidationErrors) ImplError!*const anyopaque {
    _ = instance;
    _ = errorFields;
    return error.NotImplemented;
}

