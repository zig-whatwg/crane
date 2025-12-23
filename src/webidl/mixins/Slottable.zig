//! Auto-generated mixin: Slottable
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const SlottableImpl = @import("impls").Slottable;

// Re-export types from impl
pub const impl = @import("impls").Slottable;

pub fn get_assignedSlot(instance: *runtime.Instance) !?*runtime.Instance {
    return SlottableImpl.get_assignedSlot(instance);
}

