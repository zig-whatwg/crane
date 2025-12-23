//! Auto-generated mixin: NavigatorML
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigatorMLImpl = @import("impls").NavigatorML;

// Re-export types from impl
pub const impl = @import("impls").NavigatorML;

pub fn get_ml(instance: *runtime.Instance) !*runtime.Instance {
    return NavigatorMLImpl.get_ml(instance);
}

