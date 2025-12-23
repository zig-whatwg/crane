//! Auto-generated mixin: NavigatorPlugins
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigatorPluginsImpl = @import("impls").NavigatorPlugins;

// Re-export types from impl
pub const impl = @import("impls").NavigatorPlugins;

pub fn get_plugins(instance: *runtime.Instance) !*runtime.Instance {
    return NavigatorPluginsImpl.get_plugins(instance);
}

pub fn get_mimeTypes(instance: *runtime.Instance) !*runtime.Instance {
    return NavigatorPluginsImpl.get_mimeTypes(instance);
}

pub fn get_pdfViewerEnabled(instance: *runtime.Instance) anyerror!bool {
    return NavigatorPluginsImpl.get_pdfViewerEnabled(instance);
}

pub fn call_javaEnabled(instance: *runtime.Instance) anyerror!bool {
    return NavigatorPluginsImpl.call_javaEnabled(instance);
}

