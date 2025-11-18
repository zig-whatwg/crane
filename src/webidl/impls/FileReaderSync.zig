//! Implementation for FileReaderSync interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const FileReaderSync = @import("interfaces").FileReaderSync;

pub const State = FileReaderSync.State;

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

/// Operation: readAsArrayBuffer
pub fn call_readAsArrayBuffer(instance: *runtime.Instance, blob: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = blob;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: readAsBinaryString
pub fn call_readAsBinaryString(instance: *runtime.Instance, blob: anyopaque) ImplError!runtime.DOMString {
    _ = instance;
    _ = blob;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: readAsText
pub fn call_readAsText(instance: *runtime.Instance, blob: anyopaque, encoding: runtime.DOMString) ImplError!runtime.DOMString {
    _ = instance;
    _ = blob;
    _ = encoding;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: readAsDataURL
pub fn call_readAsDataURL(instance: *runtime.Instance, blob: anyopaque) ImplError!runtime.DOMString {
    _ = instance;
    _ = blob;
    // TODO: Implement operation
    return error.NotImplemented;
}

