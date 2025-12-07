//! WebIDL dictionary: MLTensorLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const MLRankRange = @import("MLRankRange.zig").MLRankRange;

pub const MLTensorLimits = struct {
    dataTypes: ?typedefs.MLDataTypeList = null,
    rankRange: ?MLRankRange = null,
};
