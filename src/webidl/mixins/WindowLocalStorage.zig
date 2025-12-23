//! Auto-generated mixin: WindowLocalStorage
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const WindowLocalStorageImpl = @import("impls").WindowLocalStorage;

// Re-export types from impl
pub const impl = @import("impls").WindowLocalStorage;

pub fn get_localStorage(instance: *runtime.Instance) !*runtime.Instance {
    return WindowLocalStorageImpl.get_localStorage(instance);
}

