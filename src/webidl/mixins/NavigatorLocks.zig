//! Auto-generated mixin: NavigatorLocks
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigatorLocksImpl = @import("impls").NavigatorLocks;

// Re-export types from impl
pub const impl = @import("impls").NavigatorLocks;

pub fn get_locks(instance: *runtime.Instance) !*runtime.Instance {
    return NavigatorLocksImpl.get_locks(instance);
}

