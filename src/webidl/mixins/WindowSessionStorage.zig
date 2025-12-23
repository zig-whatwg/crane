//! Auto-generated mixin: WindowSessionStorage
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const WindowSessionStorageImpl = @import("impls").WindowSessionStorage;

// Re-export types from impl
pub const impl = @import("impls").WindowSessionStorage;

pub fn get_sessionStorage(instance: *runtime.Instance) !*runtime.Instance {
    return WindowSessionStorageImpl.get_sessionStorage(instance);
}

