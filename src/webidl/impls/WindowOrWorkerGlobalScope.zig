//! Implementation for WindowOrWorkerGlobalScope interface
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
const WindowOrWorkerGlobalScope = interfaces.WindowOrWorkerGlobalScope;

pub const State = WindowOrWorkerGlobalScope.State;

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

/// Getter for origin
pub fn get_origin(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for isSecureContext
pub fn get_isSecureContext(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for crossOriginIsolated
pub fn get_crossOriginIsolated(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for indexedDB
pub fn get_indexedDB(instance: *runtime.Instance) ImplError!interfaces.IDBFactory {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for trustedTypes
pub fn get_trustedTypes(instance: *runtime.Instance) ImplError!interfaces.TrustedTypePolicyFactory {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for performance
pub fn get_performance(instance: *runtime.Instance) ImplError!interfaces.Performance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for caches
pub fn get_caches(instance: *runtime.Instance) ImplError!interfaces.CacheStorage {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for scheduler
pub fn get_scheduler(instance: *runtime.Instance) ImplError!interfaces.Scheduler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for crypto
pub fn get_crypto(instance: *runtime.Instance) ImplError!interfaces.Crypto {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: reportError
pub fn call_reportError(instance: *runtime.Instance, e: *const anyopaque) ImplError!void {
    _ = instance;
    _ = e;
    return error.NotImplemented;
}

/// Operation: setInterval
pub fn call_setInterval(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: i32, arguments: *const anyopaque) ImplError!i32 {
    _ = instance;
    _ = handler;
    _ = timeout;
    _ = arguments;
    return error.NotImplemented;
}

/// Operation: atob
pub fn call_atob(instance: *runtime.Instance, data: runtime.DOMString) ImplError!runtime.ByteString {
    _ = instance;
    _ = data;
    return error.NotImplemented;
}

/// Operation: btoa
pub fn call_btoa(instance: *runtime.Instance, data: runtime.DOMString) ImplError!runtime.DOMString {
    _ = instance;
    _ = data;
    return error.NotImplemented;
}

/// Operation: createImageBitmap
pub fn call_createImageBitmap(instance: *runtime.Instance, image: typedefs.ImageBitmapSource, options: dictionaries.ImageBitmapOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = image;
    _ = options;
    return error.NotImplemented;
}

/// Operation: clearInterval
pub fn call_clearInterval(instance: *runtime.Instance, id: i32) ImplError!void {
    _ = instance;
    _ = id;
    return error.NotImplemented;
}

/// Operation: queueMicrotask
pub fn call_queueMicrotask(instance: *runtime.Instance, callback: callbacks.VoidFunction) ImplError!void {
    _ = instance;
    _ = callback;
    return error.NotImplemented;
}

/// Operation: structuredClone
pub fn call_structuredClone(instance: *runtime.Instance, value: *const anyopaque, options: dictionaries.StructuredSerializeOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = value;
    _ = options;
    return error.NotImplemented;
}

/// Operation: setTimeout
pub fn call_setTimeout(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: i32, arguments: *const anyopaque) ImplError!i32 {
    _ = instance;
    _ = handler;
    _ = timeout;
    _ = arguments;
    return error.NotImplemented;
}

/// Operation: clearTimeout
pub fn call_clearTimeout(instance: *runtime.Instance, id: i32) ImplError!void {
    _ = instance;
    _ = id;
    return error.NotImplemented;
}

/// Operation: fetch
pub fn call_fetch(instance: *runtime.Instance, input: typedefs.RequestInfo, init_data: dictionaries.RequestInit) ImplError!*const anyopaque {
    _ = instance;
    _ = input;
    _ = init_data;
    return error.NotImplemented;
}

