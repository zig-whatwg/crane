//! Implementation for FileSystemDirectoryReader interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemDirectoryReader = @import("interfaces").FileSystemDirectoryReader;

pub const State = FileSystemDirectoryReader.State;

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

/// Operation: readEntries
pub fn call_readEntries(instance: *runtime.Instance, successCallback: anyopaque, errorCallback: anyopaque) ImplError!void {
    _ = instance;
    _ = successCallback;
    _ = errorCallback;
    // TODO: Implement operation
    return error.NotImplemented;
}

