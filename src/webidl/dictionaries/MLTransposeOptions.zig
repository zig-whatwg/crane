//! WebIDL dictionary: MLTransposeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLTransposeOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    permutation: ?[]const *const anyopaque = null,
};
