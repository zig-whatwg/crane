//! Implementation for NavigatorPlugins interface
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
const NavigatorPlugins = interfaces.NavigatorPlugins;

pub const State = NavigatorPlugins.State;

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

/// Getter for plugins
pub fn get_plugins(instance: *runtime.Instance) ImplError!interfaces.PluginArray {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for mimeTypes
pub fn get_mimeTypes(instance: *runtime.Instance) ImplError!interfaces.MimeTypeArray {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for pdfViewerEnabled
pub fn get_pdfViewerEnabled(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: javaEnabled
pub fn call_javaEnabled(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

