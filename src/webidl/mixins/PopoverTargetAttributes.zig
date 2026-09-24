//! Auto-generated mixin: PopoverTargetAttributes
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PopoverTargetAttributesImpl = @import("impls").PopoverTargetAttributes;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Element = @import("interfaces").Element;
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").PopoverTargetAttributes;

/// Extended attributes: [CEReactions], [Reflect]
pub fn get_popoverTargetElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try PopoverTargetAttributesImpl.get_popoverTargetElement(instance);
}

/// Extended attributes: [CEReactions], [Reflect]
pub fn set_popoverTargetElement(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    try PopoverTargetAttributesImpl.set_popoverTargetElement(instance, value);
}

/// Extended attributes: [CEReactions]
pub fn get_popoverTargetAction(instance: *runtime.Instance) anyerror!DOMString {
    return try PopoverTargetAttributesImpl.get_popoverTargetAction(instance);
}

/// Extended attributes: [CEReactions]
pub fn set_popoverTargetAction(instance: *runtime.Instance, value: DOMString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    try PopoverTargetAttributesImpl.set_popoverTargetAction(instance, value);
}
