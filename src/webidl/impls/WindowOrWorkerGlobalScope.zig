//! Implementation for WindowOrWorkerGlobalScope interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const WindowOrWorkerGlobalScope = @import("interfaces").WindowOrWorkerGlobalScope;

pub const State = WindowOrWorkerGlobalScope.State;

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

/// Getter for origin
pub fn get_origin(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for isSecureContext
pub fn get_isSecureContext(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for crossOriginIsolated
pub fn get_crossOriginIsolated(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for indexedDB
pub fn get_indexedDB(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for trustedTypes
pub fn get_trustedTypes(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for performance
pub fn get_performance(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for caches
pub fn get_caches(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for scheduler
pub fn get_scheduler(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for crypto
pub fn get_crypto(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: reportError
pub fn call_reportError(instance: *runtime.Instance, e: anyopaque) ImplError!void {
    _ = instance;
    _ = e;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: btoa
pub fn call_btoa(instance: *runtime.Instance, data: runtime.DOMString) ImplError!runtime.DOMString {
    _ = instance;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: atob
pub fn call_atob(instance: *runtime.Instance, data: runtime.DOMString) ImplError!runtime.DOMString {
    _ = instance;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setTimeout
pub fn call_setTimeout(instance: *runtime.Instance, handler: anyopaque, timeout: i32, arguments: anyopaque) ImplError!i32 {
    _ = instance;
    _ = handler;
    _ = timeout;
    _ = arguments;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clearTimeout
pub fn call_clearTimeout(instance: *runtime.Instance, id: i32) ImplError!void {
    _ = instance;
    _ = id;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setInterval
pub fn call_setInterval(instance: *runtime.Instance, handler: anyopaque, timeout: i32, arguments: anyopaque) ImplError!i32 {
    _ = instance;
    _ = handler;
    _ = timeout;
    _ = arguments;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clearInterval
pub fn call_clearInterval(instance: *runtime.Instance, id: i32) ImplError!void {
    _ = instance;
    _ = id;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: queueMicrotask
pub fn call_queueMicrotask(instance: *runtime.Instance, callback: anyopaque) ImplError!void {
    _ = instance;
    _ = callback;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createImageBitmap
pub fn call_createImageBitmap(instance: *runtime.Instance, image: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = image;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createImageBitmap
pub fn call_createImageBitmap(instance: *runtime.Instance, image: anyopaque, sx: i32, sy: i32, sw: i32, sh: i32, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = image;
    _ = sx;
    _ = sy;
    _ = sw;
    _ = sh;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: structuredClone
pub fn call_structuredClone(instance: *runtime.Instance, value: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = value;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: fetch
pub fn call_fetch(instance: *runtime.Instance, input: anyopaque, init: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = input;
    _ = init;
    // TODO: Implement operation
    return error.NotImplemented;
}

