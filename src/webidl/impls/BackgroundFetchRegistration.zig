//! Implementation for BackgroundFetchRegistration interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const BackgroundFetchRegistration = @import("interfaces").BackgroundFetchRegistration;

pub const State = BackgroundFetchRegistration.State;

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

/// Constructor implementation
pub fn constructor(instance: *runtime.Instance) !void {
    _ = instance;
    // TODO: Implement constructor logic
}

/// Getter for id
pub fn get_id(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for uploadTotal
pub fn get_uploadTotal(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for uploaded
pub fn get_uploaded(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for downloadTotal
pub fn get_downloadTotal(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for downloaded
pub fn get_downloaded(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for result
pub fn get_result(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for failureReason
pub fn get_failureReason(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for recordsAvailable
pub fn get_recordsAvailable(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for onprogress
pub fn get_onprogress(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for onprogress
pub fn set_onprogress(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: addEventListener
pub fn call_addEventListener(instance: *runtime.Instance, type: runtime.DOMString, callback: anyopaque, options: anyopaque) ImplError!void {
    _ = instance;
    _ = type;
    _ = callback;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: removeEventListener
pub fn call_removeEventListener(instance: *runtime.Instance, type: runtime.DOMString, callback: anyopaque, options: anyopaque) ImplError!void {
    _ = instance;
    _ = type;
    _ = callback;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: dispatchEvent
pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) ImplError!bool {
    _ = instance;
    _ = event;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: when
pub fn call_when(instance: *runtime.Instance, type: runtime.DOMString, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = type;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: abort
pub fn call_abort(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: match
pub fn call_match(instance: *runtime.Instance, request: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = request;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: matchAll
pub fn call_matchAll(instance: *runtime.Instance, request: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = request;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

