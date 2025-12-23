//! Auto-generated mixin: NavigatorBadge
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigatorBadgeImpl = @import("impls").NavigatorBadge;

// Re-export types from impl
pub const impl = @import("impls").NavigatorBadge;

pub fn call_clearAppBadge(instance: *runtime.Instance) anyerror!void {
    return NavigatorBadgeImpl.call_clearAppBadge(instance);
}

pub fn call_setAppBadge(instance: *runtime.Instance, contents: runtime.JSValue) anyerror!void {
    return NavigatorBadgeImpl.call_setAppBadge(instance, contents);
}

