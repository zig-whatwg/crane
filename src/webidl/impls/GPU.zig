//! Implementation for GPU interface
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
const GPU = interfaces.GPU;

pub const State = GPU.State;

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

/// Getter for wgslLanguageFeatures
pub fn get_wgslLanguageFeatures(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: requestAdapter
pub fn call_requestAdapter(instance: *runtime.Instance, options: dictionaries.GPURequestAdapterOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: getPreferredCanvasFormat
pub fn call_getPreferredCanvasFormat(instance: *runtime.Instance) ImplError!enums.GPUTextureFormat {
    _ = instance;
    return error.NotImplemented;
}

