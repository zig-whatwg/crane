//! Auto-generated mixin: NonElementParentNode
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NonElementParentNodeImpl = @import("impls").NonElementParentNode;

// Re-export types from impl
pub const impl = @import("impls").NonElementParentNode;

pub fn call_getElementById(instance: *runtime.Instance, elementId: typedefs.DOMString) !?*runtime.Instance {
    return NonElementParentNodeImpl.call_getElementById(instance, elementId);
}

