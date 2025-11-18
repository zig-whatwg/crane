//! Implementation for FileSystemSyncAccessHandle interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemSyncAccessHandle = @import("interfaces").FileSystemSyncAccessHandle;

pub const State = FileSystemSyncAccessHandle.State;

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

/// Operation: read
pub fn call_read(instance: *runtime.Instance, buffer: anyopaque, options: anyopaque) ImplError!u64 {
    _ = instance;
    _ = buffer;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: write
pub fn call_write(instance: *runtime.Instance, buffer: anyopaque, options: anyopaque) ImplError!u64 {
    _ = instance;
    _ = buffer;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: truncate
pub fn call_truncate(instance: *runtime.Instance, newSize: u64) ImplError!void {
    _ = instance;
    _ = newSize;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getSize
pub fn call_getSize(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: flush
pub fn call_flush(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

