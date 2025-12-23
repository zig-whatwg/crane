//! Auto-generated mixin: DestroyableModel
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const DestroyableModelImpl = @import("impls").DestroyableModel;

// Re-export types from impl
pub const impl = @import("impls").DestroyableModel;

pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
    return DestroyableModelImpl.call_destroy(instance);
}

