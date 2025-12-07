//! WebIDL dictionary: SharedStoragePrivateAggregationConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const SharedStoragePrivateAggregationConfig = struct {
    aggregationCoordinatorOrigin: ?runtime.USVString = null,
    contextId: ?runtime.USVString = null,
    filteringIdMaxBytes: ?u64 = null,
    maxContributions: ?u64 = null,
};
