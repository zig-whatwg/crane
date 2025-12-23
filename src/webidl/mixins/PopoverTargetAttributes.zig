//! Auto-generated mixin: PopoverTargetAttributes
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const PopoverTargetAttributesImpl = @import("impls").PopoverTargetAttributes;

// Re-export types from impl
pub const impl = @import("impls").PopoverTargetAttributes;

pub fn get_popoverTargetElement(instance: *runtime.Instance) !?*runtime.Instance {
    return PopoverTargetAttributesImpl.get_popoverTargetElement(instance);
}

pub fn set_popoverTargetElement(instance: *runtime.Instance, value: *runtime.Instance) !void {
    return PopoverTargetAttributesImpl.set_popoverTargetElement(instance, value);
}

pub fn get_popoverTargetAction(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return PopoverTargetAttributesImpl.get_popoverTargetAction(instance);
}

pub fn set_popoverTargetAction(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return PopoverTargetAttributesImpl.set_popoverTargetAction(instance, value);
}

