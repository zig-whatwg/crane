//! WebIDL dictionary: SharedStorageRunOperationMethodOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const SharedStorageRunOperationMethodOptions = struct {
    data: ?*const anyopaque = null,
    resolveToConfig: ?bool = null,
    keepAlive: ?bool = null,
    privateAggregationConfig: ?*const anyopaque = null,
    savedQuery: ?runtime.DOMString = null,
};
