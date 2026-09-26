//! Auto-generated mixin: NavigatorBadge
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorBadgeImpl = @import("impls").NavigatorBadge;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const impl = @import("impls").NavigatorBadge;

pub fn call_clearAppBadge(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return try NavigatorBadgeImpl.call_clearAppBadge(instance);
}

pub fn call_setAppBadge(instance: *runtime.Instance, contents: webidl.Opt(u64)) anyerror!runtime.JSValue {
    // [EnforceRange] on contents
    if (!runtime.isInRange(u64, contents)) return error.TypeError;

    return try NavigatorBadgeImpl.call_setAppBadge(instance, contents);
}

/// WebIDL: operations whose return type is a promise - an exception in
/// their steps becomes a rejected promise.
pub const promise_returning = .{
    "call_clearAppBadge",
    "call_setAppBadge",
};
