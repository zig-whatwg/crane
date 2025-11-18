//! Implementation for Rewriter interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const Rewriter = @import("interfaces").Rewriter;

pub const State = Rewriter.State;

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

/// Getter for sharedContext
pub fn get_sharedContext(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for tone
pub fn get_tone(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for format
pub fn get_format(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for length
pub fn get_length(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for expectedInputLanguages
pub fn get_expectedInputLanguages(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for expectedContextLanguages
pub fn get_expectedContextLanguages(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for outputLanguage
pub fn get_outputLanguage(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for inputQuota
pub fn get_inputQuota(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: create
pub fn call_create(instance: *runtime.Instance, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: availability
pub fn call_availability(instance: *runtime.Instance, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: rewrite
pub fn call_rewrite(instance: *runtime.Instance, input: runtime.DOMString, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = input;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: rewriteStreaming
pub fn call_rewriteStreaming(instance: *runtime.Instance, input: runtime.DOMString, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = input;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: measureInputUsage
pub fn call_measureInputUsage(instance: *runtime.Instance, input: runtime.DOMString, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = input;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: destroy
pub fn call_destroy(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

