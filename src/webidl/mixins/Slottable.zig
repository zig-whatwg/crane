//! Auto-generated mixin: Slottable
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SlottableImpl = @import("impls").Slottable;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const HTMLSlotElement = @import("interfaces").HTMLSlotElement;

pub const impl = @import("impls").Slottable;

pub fn get_assignedSlot(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try SlottableImpl.get_assignedSlot(instance);
}
