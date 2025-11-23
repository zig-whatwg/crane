//! Implementation for LanguageDetector interface
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
const LanguageDetector = interfaces.LanguageDetector;

pub const State = LanguageDetector.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for this implementation
/// Can be used to store browser-specific data structures
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

/// Getter for expectedInputLanguages
pub fn get_expectedInputLanguages(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for inputQuota
pub fn get_inputQuota(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: availability
pub fn call_availability(instance: *runtime.Instance, options: dictionaries.LanguageDetectorCreateCoreOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: measureInputUsage
pub fn call_measureInputUsage(instance: *runtime.Instance, input: runtime.DOMString, options: dictionaries.LanguageDetectorDetectOptions) ImplError!*const anyopaque {
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

/// Operation: detect
pub fn call_detect(instance: *runtime.Instance, input: runtime.DOMString, options: dictionaries.LanguageDetectorDetectOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: create
pub fn call_create(instance: *runtime.Instance, options: dictionaries.LanguageDetectorCreateOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

