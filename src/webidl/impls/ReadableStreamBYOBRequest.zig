//! Implementation for ReadableStreamBYOBRequest interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const ReadableStreamBYOBRequest = @import("interfaces").ReadableStreamBYOBRequest;

pub const State = ReadableStreamBYOBRequest.State;

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

/// Getter for view
pub fn get_view(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: respond
pub fn call_respond(instance: *runtime.Instance, bytesWritten: u64) ImplError!void {
    _ = instance;
    _ = bytesWritten;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: respondWithNewView
pub fn call_respondWithNewView(instance: *runtime.Instance, view: anyopaque) ImplError!void {
    _ = instance;
    _ = view;
    // TODO: Implement operation
    return error.NotImplemented;
}

