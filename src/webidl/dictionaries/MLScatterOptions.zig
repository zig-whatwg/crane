//! WebIDL dictionary: MLScatterOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLScatterOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    axis: ?u32 = null,
};
