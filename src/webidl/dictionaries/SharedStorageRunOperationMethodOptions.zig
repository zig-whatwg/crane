//! WebIDL dictionary: SharedStorageRunOperationMethodOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const SharedStoragePrivateAggregationConfig = @import("SharedStoragePrivateAggregationConfig.zig").SharedStoragePrivateAggregationConfig;

pub const SharedStorageRunOperationMethodOptions = struct {
    data: ?runtime.JSValue = null,
    resolveToConfig: ?bool = null,
    keepAlive: ?bool = null,
    privateAggregationConfig: ?SharedStoragePrivateAggregationConfig = null,
    savedQuery: ?runtime.DOMString = null,
};
