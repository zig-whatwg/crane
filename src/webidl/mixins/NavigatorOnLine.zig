//! Auto-generated mixin: NavigatorOnLine
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorOnLineImpl = @import("impls").NavigatorOnLine;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const impl = @import("impls").NavigatorOnLine;

pub fn get_onLine(instance: *runtime.Instance) anyerror!bool {
    return try NavigatorOnLineImpl.get_onLine(instance);
}
