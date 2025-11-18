//! Implementation for SharedStorageWorklet interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const SharedStorageWorklet = @import("interfaces").SharedStorageWorklet;

pub const State = SharedStorageWorklet.State;

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

/// Operation: addModule
pub fn call_addModule(instance: *runtime.Instance, moduleURL: runtime.DOMString, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = moduleURL;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: selectURL
pub fn call_selectURL(instance: *runtime.Instance, name: runtime.DOMString, urls: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = name;
    _ = urls;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: run
pub fn call_run(instance: *runtime.Instance, name: runtime.DOMString, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = name;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

