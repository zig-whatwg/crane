//! Implementation for DeprecationReportBody interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const DeprecationReportBody = @import("interfaces").DeprecationReportBody;

pub const State = DeprecationReportBody.State;

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

/// Getter for id
pub fn get_id(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for anticipatedRemoval
pub fn get_anticipatedRemoval(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for message
pub fn get_message(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for sourceFile
pub fn get_sourceFile(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for lineNumber
pub fn get_lineNumber(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for columnNumber
pub fn get_columnNumber(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: toJSON
pub fn call_toJSON(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

