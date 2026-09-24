//! Auto-generated mixin: NavigatorCookies
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorCookiesImpl = @import("impls").NavigatorCookies;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const impl = @import("impls").NavigatorCookies;

pub fn get_cookieEnabled(instance: *runtime.Instance) anyerror!bool {
    return try NavigatorCookiesImpl.get_cookieEnabled(instance);
}
