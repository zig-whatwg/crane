//! Auto-generated mixin: PushManagerAttribute
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const PushManagerAttributeImpl = @import("impls").PushManagerAttribute;

// Re-export types from impl
pub const impl = @import("impls").PushManagerAttribute;

pub fn get_pushManager(instance: *runtime.Instance) !*runtime.Instance {
    return PushManagerAttributeImpl.get_pushManager(instance);
}

