//! WebIDL dictionary: MLLstmCellOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLLstmCellOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    bias: ?anyopaque = null,
    recurrentBias: ?anyopaque = null,
    peepholeWeight: ?anyopaque = null,
    layout: ?anyopaque = null,
    activations: ?anyopaque = null,
};
