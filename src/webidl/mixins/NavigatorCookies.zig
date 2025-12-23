//! Auto-generated mixin: NavigatorCookies
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigatorCookiesImpl = @import("impls").NavigatorCookies;

// Re-export types from impl
pub const impl = @import("impls").NavigatorCookies;

pub fn get_cookieEnabled(instance: *runtime.Instance) anyerror!bool {
    return NavigatorCookiesImpl.get_cookieEnabled(instance);
}

