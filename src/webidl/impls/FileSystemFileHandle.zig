//! Implementation for FileSystemFileHandle interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemFileHandle = @import("interfaces").FileSystemFileHandle;

pub const State = FileSystemFileHandle.State;

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

/// Getter for kind
pub fn get_kind(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for name
pub fn get_name(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: isSameEntry
pub fn call_isSameEntry(instance: *runtime.Instance, other: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = other;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: queryPermission
pub fn call_queryPermission(instance: *runtime.Instance, descriptor: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = descriptor;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: requestPermission
pub fn call_requestPermission(instance: *runtime.Instance, descriptor: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = descriptor;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getFile
pub fn call_getFile(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createWritable
pub fn call_createWritable(instance: *runtime.Instance, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createSyncAccessHandle
pub fn call_createSyncAccessHandle(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

