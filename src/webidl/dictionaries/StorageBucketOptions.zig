//! WebIDL dictionary: StorageBucketOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const StorageBucketOptions = struct {
    persisted: ?bool = null,
    quota: ?u64 = null,
    expires: ?typedefs.DOMHighResTimeStamp = null,
};
