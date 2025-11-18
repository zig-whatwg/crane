//! Implementation for ProtectedAudienceUtilities interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const ProtectedAudienceUtilities = @import("interfaces").ProtectedAudienceUtilities;

pub const State = ProtectedAudienceUtilities.State;

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

/// Operation: encodeUtf8
pub fn call_encodeUtf8(instance: *runtime.Instance, input: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = input;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: decodeUtf8
pub fn call_decodeUtf8(instance: *runtime.Instance, bytes: anyopaque) ImplError!runtime.DOMString {
    _ = instance;
    _ = bytes;
    // TODO: Implement operation
    return error.NotImplemented;
}

