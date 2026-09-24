//! Auto-generated mixin: NavigatorLocks
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorLocksImpl = @import("impls").NavigatorLocks;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const LockManager = @import("interfaces").LockManager;

pub const impl = @import("impls").NavigatorLocks;

pub fn get_locks(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try NavigatorLocksImpl.get_locks(instance);
}
