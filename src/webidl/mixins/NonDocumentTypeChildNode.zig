//! Auto-generated mixin: NonDocumentTypeChildNode
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NonDocumentTypeChildNodeImpl = @import("impls").NonDocumentTypeChildNode;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Element = @import("interfaces").Element;

pub const impl = @import("impls").NonDocumentTypeChildNode;

pub fn get_previousElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try NonDocumentTypeChildNodeImpl.get_previousElementSibling(instance);
}

pub fn get_nextElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try NonDocumentTypeChildNodeImpl.get_nextElementSibling(instance);
}
