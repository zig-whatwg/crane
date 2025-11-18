//! WebIDL dictionary: MLGruOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLGruOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    bias: ?anyopaque = null,
    recurrentBias: ?anyopaque = null,
    initialHiddenState: ?anyopaque = null,
    resetAfter: ?bool = null,
    returnSequence: ?bool = null,
    direction: ?anyopaque = null,
    layout: ?anyopaque = null,
    activations: ?anyopaque = null,
};
