//! WebIDL dictionary: MLGruCellOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLGruCellOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    bias: ?anyopaque = null,
    recurrentBias: ?anyopaque = null,
    resetAfter: ?bool = null,
    layout: ?anyopaque = null,
    activations: ?anyopaque = null,
};
