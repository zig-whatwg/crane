//! Auto-generated mixin: NavigatorContentUtils
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorContentUtilsImpl = @import("impls").NavigatorContentUtils;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").NavigatorContentUtils;

/// Extended attributes: [SecureContext]
pub fn call_registerProtocolHandler(instance: *runtime.Instance, scheme: DOMString, url: runtime.USVString) anyerror!void {
    return try NavigatorContentUtilsImpl.call_registerProtocolHandler(instance, scheme, url);
}

/// Extended attributes: [SecureContext]
pub fn call_unregisterProtocolHandler(instance: *runtime.Instance, scheme: DOMString, url: runtime.USVString) anyerror!void {
    return try NavigatorContentUtilsImpl.call_unregisterProtocolHandler(instance, scheme, url);
}
