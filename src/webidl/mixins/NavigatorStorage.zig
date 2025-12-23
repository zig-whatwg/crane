//! Auto-generated mixin: NavigatorStorage
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigatorStorageImpl = @import("impls").NavigatorStorage;

// Re-export types from impl
pub const impl = @import("impls").NavigatorStorage;

pub fn get_storage(instance: *runtime.Instance) !*runtime.Instance {
    return NavigatorStorageImpl.get_storage(instance);
}

