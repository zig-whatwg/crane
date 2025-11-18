//! WebIDL dictionary: MLReverseOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLReverseOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    axes: ?anyopaque = null,
};
