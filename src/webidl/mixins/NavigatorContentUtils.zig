//! Auto-generated mixin: NavigatorContentUtils
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigatorContentUtilsImpl = @import("impls").NavigatorContentUtils;

// Re-export types from impl
pub const impl = @import("impls").NavigatorContentUtils;

pub fn call_registerProtocolHandler(instance: *runtime.Instance, scheme: typedefs.DOMString, url: runtime.JSValue) anyerror!void {
    return NavigatorContentUtilsImpl.call_registerProtocolHandler(instance, scheme, url);
}

pub fn call_unregisterProtocolHandler(instance: *runtime.Instance, scheme: typedefs.DOMString, url: runtime.JSValue) anyerror!void {
    return NavigatorContentUtilsImpl.call_unregisterProtocolHandler(instance, scheme, url);
}

