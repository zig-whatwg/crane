//! WebIDL dictionary: MLGruCellOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLGruCellOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    bias: ?*const anyopaque = null,
    recurrentBias: ?*const anyopaque = null,
    resetAfter: ?bool = null,
    layout: ?*const anyopaque = null,
    activations: ?*const anyopaque = null,
};
