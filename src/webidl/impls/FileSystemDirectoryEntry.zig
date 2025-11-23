//! Implementation for FileSystemDirectoryEntry interface
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
const FileSystemDirectoryEntry = interfaces.FileSystemDirectoryEntry;

pub const State = FileSystemDirectoryEntry.State;

pub const ImplError = error{
    NotImplemented,
};

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

/// Operation: getDirectory
pub fn call_getDirectory(instance: *runtime.Instance, path: runtime.USVString, options: dictionaries.FileSystemFlags, successCallback: callbacks.FileSystemEntryCallback, errorCallback: callbacks.ErrorCallback) ImplError!void {
    _ = instance;
    _ = path;
    _ = options;
    _ = successCallback;
    _ = errorCallback;
    return error.NotImplemented;
}

/// Operation: getFile
pub fn call_getFile(instance: *runtime.Instance, path: runtime.USVString, options: dictionaries.FileSystemFlags, successCallback: callbacks.FileSystemEntryCallback, errorCallback: callbacks.ErrorCallback) ImplError!void {
    _ = instance;
    _ = path;
    _ = options;
    _ = successCallback;
    _ = errorCallback;
    return error.NotImplemented;
}

/// Operation: createReader
pub fn call_createReader(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

