//! Implementation for BackgroundFetchRegistration interface
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
const BackgroundFetchRegistration = interfaces.BackgroundFetchRegistration;

pub const State = BackgroundFetchRegistration.State;

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

/// Getter for id
pub fn get_id(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for uploadTotal
pub fn get_uploadTotal(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for uploaded
pub fn get_uploaded(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for downloadTotal
pub fn get_downloadTotal(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for downloaded
pub fn get_downloaded(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for result
pub fn get_result(instance: *runtime.Instance) ImplError!enums.BackgroundFetchResult {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for failureReason
pub fn get_failureReason(instance: *runtime.Instance) ImplError!enums.BackgroundFetchFailureReason {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for recordsAvailable
pub fn get_recordsAvailable(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onprogress
pub fn get_onprogress(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onprogress
pub fn set_onprogress(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: matchAll
pub fn call_matchAll(instance: *runtime.Instance, request: typedefs.RequestInfo, options: dictionaries.CacheQueryOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = request;
    _ = options;
    return error.NotImplemented;
}

/// Operation: abort
pub fn call_abort(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: match
pub fn call_match(instance: *runtime.Instance, request: typedefs.RequestInfo, options: dictionaries.CacheQueryOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = request;
    _ = options;
    return error.NotImplemented;
}

