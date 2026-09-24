//! Auto-generated mixin: NavigatorPlugins
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorPluginsImpl = @import("impls").NavigatorPlugins;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MimeTypeArray = @import("interfaces").MimeTypeArray;
const PluginArray = @import("interfaces").PluginArray;

pub const impl = @import("impls").NavigatorPlugins;

/// Extended attributes: [SameObject]
pub fn get_plugins(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try NavigatorPluginsImpl.get_plugins(instance);
}

/// Extended attributes: [SameObject]
pub fn get_mimeTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try NavigatorPluginsImpl.get_mimeTypes(instance);
}

pub fn get_pdfViewerEnabled(instance: *runtime.Instance) anyerror!bool {
    return try NavigatorPluginsImpl.get_pdfViewerEnabled(instance);
}

pub fn call_javaEnabled(instance: *runtime.Instance) anyerror!bool {
    return try NavigatorPluginsImpl.call_javaEnabled(instance);
}
