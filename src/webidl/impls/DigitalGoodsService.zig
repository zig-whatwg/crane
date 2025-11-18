//! Implementation for DigitalGoodsService interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const DigitalGoodsService = @import("interfaces").DigitalGoodsService;

pub const State = DigitalGoodsService.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance
pub fn init(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Initialize your instance state here
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Clean up your instance resources here
}

/// Operation: getDetails
pub fn call_getDetails(instance: *runtime.Instance, itemIds: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = itemIds;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: listPurchases
pub fn call_listPurchases(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: listPurchaseHistory
pub fn call_listPurchaseHistory(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: consume
pub fn call_consume(instance: *runtime.Instance, purchaseToken: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = purchaseToken;
    // TODO: Implement operation
    return error.NotImplemented;
}

