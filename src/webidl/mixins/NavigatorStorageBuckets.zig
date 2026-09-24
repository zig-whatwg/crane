//! Auto-generated mixin: NavigatorStorageBuckets
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorStorageBucketsImpl = @import("impls").NavigatorStorageBuckets;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const StorageBucketManager = @import("interfaces").StorageBucketManager;

pub const impl = @import("impls").NavigatorStorageBuckets;

/// Extended attributes: [SameObject]
pub fn get_storageBuckets(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try NavigatorStorageBucketsImpl.get_storageBuckets(instance);
}
