//! Implementation for ForDebuggingOnly interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const ForDebuggingOnly = @import("interfaces").ForDebuggingOnly;

pub const State = ForDebuggingOnly.State;

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

/// Operation: reportAdAuctionWin
pub fn call_reportAdAuctionWin(instance: *runtime.Instance, url: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = url;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: reportAdAuctionLoss
pub fn call_reportAdAuctionLoss(instance: *runtime.Instance, url: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = url;
    // TODO: Implement operation
    return error.NotImplemented;
}

