//! Auto-generated mixin: NonDocumentTypeChildNode
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NonDocumentTypeChildNodeImpl = @import("impls").NonDocumentTypeChildNode;

// Re-export types from impl
pub const impl = @import("impls").NonDocumentTypeChildNode;

pub fn get_previousElementSibling(instance: *runtime.Instance) !?*runtime.Instance {
    return NonDocumentTypeChildNodeImpl.get_previousElementSibling(instance);
}

pub fn get_nextElementSibling(instance: *runtime.Instance) !?*runtime.Instance {
    return NonDocumentTypeChildNodeImpl.get_nextElementSibling(instance);
}

