//! Implementation for ReadableStreamBYOBRequest interface
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
const ReadableStreamBYOBRequest = interfaces.ReadableStreamBYOBRequest;

pub const State = ReadableStreamBYOBRequest.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for this implementation
/// Can be used to store browser-specific data structures
pub const InternalState = struct {};

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

/// Getter for view
pub fn get_view(instance: *runtime.Instance) ImplError!typedefs.ArrayBufferView {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: respond
pub fn call_respond(instance: *runtime.Instance, bytesWritten: u64) ImplError!void {
    _ = instance;
    _ = bytesWritten;
    return error.NotImplemented;
}

/// Operation: respondWithNewView
pub fn call_respondWithNewView(instance: *runtime.Instance, view: typedefs.ArrayBufferView) ImplError!void {
    _ = instance;
    _ = view;
    return error.NotImplemented;
}

