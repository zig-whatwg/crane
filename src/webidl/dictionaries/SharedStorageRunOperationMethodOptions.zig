//! WebIDL dictionary: SharedStorageRunOperationMethodOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const SharedStoragePrivateAggregationConfig = @import("SharedStoragePrivateAggregationConfig.zig").SharedStoragePrivateAggregationConfig;

pub const SharedStorageRunOperationMethodOptions = struct {
    data: ?v8.JSValue = null,
    resolveToConfig: ?bool = null,
    keepAlive: ?bool = null,
    privateAggregationConfig: ?SharedStoragePrivateAggregationConfig = null,
    savedQuery: ?runtime.DOMString = null,
};
