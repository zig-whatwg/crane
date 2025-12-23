//! Auto-generated mixin: NavigatorStorageBuckets
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigatorStorageBucketsImpl = @import("impls").NavigatorStorageBuckets;

// Re-export types from impl
pub const impl = @import("impls").NavigatorStorageBuckets;

pub fn get_storageBuckets(instance: *runtime.Instance) !*runtime.Instance {
    return NavigatorStorageBucketsImpl.get_storageBuckets(instance);
}

