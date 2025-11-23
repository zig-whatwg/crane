//! WebIDL dictionary: MLGatherOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLGatherOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    axis: ?u32 = null,
};
