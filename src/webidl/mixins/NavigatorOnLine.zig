//! Auto-generated mixin: NavigatorOnLine
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigatorOnLineImpl = @import("impls").NavigatorOnLine;

// Re-export types from impl
pub const impl = @import("impls").NavigatorOnLine;

pub fn get_onLine(instance: *runtime.Instance) anyerror!bool {
    return NavigatorOnLineImpl.get_onLine(instance);
}

