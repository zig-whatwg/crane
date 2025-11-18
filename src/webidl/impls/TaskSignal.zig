//! Implementation for TaskSignal interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const TaskSignal = @import("interfaces").TaskSignal;

pub const State = TaskSignal.State;

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

/// Getter for aborted
pub fn get_aborted(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for reason
pub fn get_reason(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for onabort
pub fn get_onabort(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for priority
pub fn get_priority(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for onprioritychange
pub fn get_onprioritychange(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for onabort
pub fn set_onabort(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for onprioritychange
pub fn set_onprioritychange(instance: *runtime.Instance, value: anyopaque) ImplError!void {
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
pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = reason;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: timeout
pub fn call_timeout(instance: *runtime.Instance, milliseconds: u64) ImplError!anyopaque {
    _ = instance;
    _ = milliseconds;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: _any
pub fn call__any(instance: *runtime.Instance, signals: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = signals;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: throwIfAborted
pub fn call_throwIfAborted(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: _any
pub fn call__any(instance: *runtime.Instance, signals: anyopaque, init: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = signals;
    _ = init;
    // TODO: Implement operation
    return error.NotImplemented;
}

