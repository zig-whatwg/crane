//! Auto-generated mixin: NavigatorUA
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigatorUAImpl = @import("impls").NavigatorUA;

// Re-export types from impl
pub const impl = @import("impls").NavigatorUA;

pub fn get_userAgentData(instance: *runtime.Instance) !*runtime.Instance {
    return NavigatorUAImpl.get_userAgentData(instance);
}

