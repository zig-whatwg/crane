//! WebIDL dictionary: SharedStorageUrlWithMetadata
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const SharedStorageUrlWithMetadata = struct {
    url: runtime.USVString,
    reportingMetadata: ?v8.JSValue = null,
};
