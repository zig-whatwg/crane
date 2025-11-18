//! Implementation for StorageAccessHandle interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const StorageAccessHandle = @import("interfaces").StorageAccessHandle;

pub const State = StorageAccessHandle.State;

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

/// Getter for sessionStorage
pub fn get_sessionStorage(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for localStorage
pub fn get_localStorage(instance: *runtime.Instance) ImplError!anyopaque {
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

/// Getter for locks
pub fn get_locks(instance: *runtime.Instance) ImplError!anyopaque {
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

/// Operation: getDirectory
pub fn call_getDirectory(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: estimate
pub fn call_estimate(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createObjectURL
pub fn call_createObjectURL(instance: *runtime.Instance, obj: anyopaque) ImplError!runtime.DOMString {
    _ = instance;
    _ = obj;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: revokeObjectURL
pub fn call_revokeObjectURL(instance: *runtime.Instance, url: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = url;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: BroadcastChannel
pub fn call_BroadcastChannel(instance: *runtime.Instance, name: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = name;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: SharedWorker
pub fn call_SharedWorker(instance: *runtime.Instance, scriptURL: runtime.DOMString, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = scriptURL;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

