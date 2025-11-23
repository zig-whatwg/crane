//! Implementation for Rewriter interface
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
const Rewriter = interfaces.Rewriter;

pub const State = Rewriter.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
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

/// Getter for sharedContext
pub fn get_sharedContext(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for tone
pub fn get_tone(instance: *runtime.Instance) ImplError!enums.RewriterTone {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for format
pub fn get_format(instance: *runtime.Instance) ImplError!enums.RewriterFormat {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for length
pub fn get_length(instance: *runtime.Instance) ImplError!enums.RewriterLength {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for expectedInputLanguages
pub fn get_expectedInputLanguages(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for expectedContextLanguages
pub fn get_expectedContextLanguages(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for outputLanguage
pub fn get_outputLanguage(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for inputQuota
pub fn get_inputQuota(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: availability
pub fn call_availability(instance: *runtime.Instance, options: dictionaries.RewriterCreateCoreOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: rewrite
pub fn call_rewrite(instance: *runtime.Instance, input: runtime.DOMString, options: dictionaries.RewriterRewriteOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: rewriteStreaming
pub fn call_rewriteStreaming(instance: *runtime.Instance, input: runtime.DOMString, options: dictionaries.RewriterRewriteOptions) ImplError!*runtime.Instance {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: measureInputUsage
pub fn call_measureInputUsage(instance: *runtime.Instance, input: runtime.DOMString, options: dictionaries.RewriterRewriteOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: destroy
pub fn call_destroy(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: create
pub fn call_create(instance: *runtime.Instance, options: dictionaries.RewriterCreateOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

